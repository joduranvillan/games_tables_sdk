//! Inteligencia Artificial para Batalla Naval (Battleship) con Probabilistic Targeting.
//!
//! Niveles de dificultad (`AiDifficulty`):
//! - `Easy`: disparo pseudoaleatorio en celdas no disparadas.
//! - `Medium`: modo Hunt/Target — disparo aleatorio en celdas no disparadas, pero
//!   prioriza celdas ortogonalmente adyacentes si existe algún impacto sin hundir.
//! - `Hard` / `Expert`: mapa de densidad de probabilidad (*probability density map*) —
//!   cuenta cuántas orientaciones válidas de barcos aún no hundidos pueden cubrir cada
//!   celda no disparada (ponderando fuertemente las alineaciones que cubren impactos
//!   activos sin hundir) y dispara a la celda de mayor densidad.

#![allow(clippy::needless_range_loop)]

use open_table_engine::prelude::*;

use crate::board::BOARD_SIZE;
use crate::commands::{FireShotCommand, PlaceFleetCommand};
use crate::fleet::{FleetResource, Ship, ShotsResource, EXPECTED_SHIP_SIZES};
use crate::position::Position;

/// Alias del estado de partida de Batalla Naval para `best_move`.
pub type BattleshipState = Session;

/// Alias del comando de disparo devuelto por la IA de Batalla Naval.
pub type BattleshipCommand = FireShotCommand;

/// Generador pseudoaleatorio determinista (XorShift64) para desempates y modo `Easy`/`Medium`.
struct FastRng {
    state: u64,
}

impl FastRng {
    fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 0x9e37_79b9_7f4a_7c15 } else { seed },
        }
    }

    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }

    fn next_usize(&mut self, bound: usize) -> usize {
        if bound == 0 {
            0
        } else {
            (self.next_u64() % (bound as u64)) as usize
        }
    }
}

/// Flota inicial válida por defecto para el jugador IA (5 barcos de tamaños 5, 4, 3, 3, 2 sin tocarse).
pub fn default_ai_fleet() -> Vec<Ship> {
    vec![
        vec![
            Position::new(0, 0),
            Position::new(0, 1),
            Position::new(0, 2),
            Position::new(0, 3),
            Position::new(0, 4),
        ],
        vec![
            Position::new(2, 0),
            Position::new(2, 1),
            Position::new(2, 2),
            Position::new(2, 3),
        ],
        vec![
            Position::new(4, 0),
            Position::new(4, 1),
            Position::new(4, 2),
        ],
        vec![
            Position::new(6, 0),
            Position::new(6, 1),
            Position::new(6, 2),
        ],
        vec![Position::new(8, 0), Position::new(8, 1)],
    ]
}

/// Crea el comando `PlaceFleetCommand` con la flota inicial por defecto para `ai_player`.
pub fn default_ai_place_fleet_command(ai_player: PlayerId) -> PlaceFleetCommand {
    PlaceFleetCommand {
        player: ai_player,
        ships: default_ai_fleet(),
    }
}

/// Determina el `PlayerId` del oponente a partir del estado de la sesión.
fn resolve_opponent(state: &BattleshipState, ai_player: PlayerId) -> PlayerId {
    if let Some(turn) = state.world().get_resource::<TurnResource>() {
        if let Some(&other) = turn.0.players().iter().find(|&&p| p != ai_player) {
            return other;
        }
    }
    if let Some(fleet) = state.world().get_resource::<FleetResource>() {
        if let Some(&other) = fleet.ships.keys().find(|&&p| p != ai_player) {
            return other;
        }
        if let Some(&other) = fleet.hits.keys().find(|&&p| p != ai_player) {
            return other;
        }
    }
    if ai_player.0 == 1 {
        PlayerId(2)
    } else {
        PlayerId(1)
    }
}

/// Devuelve `true` si la celda `pos` ya fue disparada por `ai_player` o ya figura impactada en `opponent`.
fn is_cell_touched(
    shots: Option<&ShotsResource>,
    fleet: Option<&FleetResource>,
    ai_player: PlayerId,
    opponent: PlayerId,
    pos: Position,
) -> bool {
    let shot_recorded = shots.map(|s| s.has_shot(ai_player, pos)).unwrap_or(false);
    let hit_recorded = fleet.map(|f| f.is_hit(opponent, pos)).unwrap_or(false);
    shot_recorded || hit_recorded
}

/// Devuelve `true` si `pos` es un impacto en el tablero de `opponent` que pertenece a un barco aún NO hundido.
fn is_unsunk_hit(fleet: Option<&FleetResource>, opponent: PlayerId, pos: Position) -> bool {
    let Some(fleet) = fleet else {
        return false;
    };
    if !fleet.is_hit(opponent, pos) {
        return false;
    }
    match fleet.ship_at(opponent, pos) {
        Some(ship) => !fleet.is_ship_sunk(opponent, &ship),
        None => true,
    }
}

/// Devuelve `true` si `pos` fue disparada pero resultó en agua (`Miss`), o pertenece a un barco ya hundido (`Sunk`).
/// Ningún barco aún no hundido puede solaparse con una celda bloqueada.
fn is_blocked_for_unsunk_ship(
    shots: Option<&ShotsResource>,
    fleet: Option<&FleetResource>,
    ai_player: PlayerId,
    opponent: PlayerId,
    pos: Position,
) -> bool {
    let touched = is_cell_touched(shots, fleet, ai_player, opponent, pos);
    if !touched {
        return false;
    }
    // Si fue tocada y NO es un impacto sin hundir, entonces es agua (Miss) o barco ya hundido (Sunk).
    !is_unsunk_hit(fleet, opponent, pos)
}

/// Obtiene los tamaños de los barcos del oponente que aún no han sido hundidos.
fn remaining_unsunk_ship_sizes(fleet: Option<&FleetResource>, opponent: PlayerId) -> Vec<usize> {
    if let Some(fleet) = fleet {
        if let Some(ships) = fleet.ships.get(&opponent) {
            let unsunk: Vec<usize> = ships
                .iter()
                .filter(|ship| !fleet.is_ship_sunk(opponent, ship))
                .map(|ship| ship.len())
                .collect();
            if !unsunk.is_empty() {
                return unsunk;
            }
        }
    }
    EXPECTED_SHIP_SIZES.to_vec()
}

/// Calcula el mapa de densidad de probabilidad (`10x10`) para `ai_player`:
/// Para cada tamaño de barco aún no hundido, cuenta cuántas ubicaciones horizontales y
/// verticales válidas cubren cada celda no disparada. Si una ubicación válida pasa además
/// por uno o más impactos sin hundir (`unsunk_hits`), recibe una ponderación adicional
/// proporcional para priorizar el hundimiento del barco detectado.
pub fn compute_probability_density_map(
    state: &BattleshipState,
    ai_player: PlayerId,
) -> [[u32; BOARD_SIZE as usize]; BOARD_SIZE as usize] {
    let size = BOARD_SIZE as usize;
    let mut density = [[0u32; BOARD_SIZE as usize]; BOARD_SIZE as usize];

    let opponent = resolve_opponent(state, ai_player);
    let shots = state.world().get_resource::<ShotsResource>();
    let fleet = state.world().get_resource::<FleetResource>();
    let ship_sizes = remaining_unsunk_ship_sizes(fleet, opponent);

    for &ship_len in &ship_sizes {
        if ship_len == 0 || ship_len > size {
            continue;
        }

        // Orientaciones horizontales
        for r in 0..size {
            for start_c in 0..=(size - ship_len) {
                let mut valid = true;
                let mut hits_covered = 0u32;

                for offset in 0..ship_len {
                    let pos = Position::new(r as u8, (start_c + offset) as u8);
                    if is_blocked_for_unsunk_ship(shots, fleet, ai_player, opponent, pos) {
                        valid = false;
                        break;
                    }
                    if is_unsunk_hit(fleet, opponent, pos) {
                        hits_covered += 1;
                    }
                }

                if valid {
                    let weight = 1 + hits_covered * 50;
                    for offset in 0..ship_len {
                        let c = start_c + offset;
                        let pos = Position::new(r as u8, c as u8);
                        if !is_cell_touched(shots, fleet, ai_player, opponent, pos) {
                            density[r][c] += weight;
                        }
                    }
                }
            }
        }

        // Orientaciones verticales
        if ship_len > 1 {
            for start_r in 0..=(size - ship_len) {
                for c in 0..size {
                    let mut valid = true;
                    let mut hits_covered = 0u32;

                    for offset in 0..ship_len {
                        let pos = Position::new((start_r + offset) as u8, c as u8);
                        if is_blocked_for_unsunk_ship(shots, fleet, ai_player, opponent, pos) {
                            valid = false;
                            break;
                        }
                        if is_unsunk_hit(fleet, opponent, pos) {
                            hits_covered += 1;
                        }
                    }

                    if valid {
                        let weight = 1 + hits_covered * 50;
                        for offset in 0..ship_len {
                            let r = start_r + offset;
                            let pos = Position::new(r as u8, c as u8);
                            if !is_cell_touched(shots, fleet, ai_player, opponent, pos) {
                                density[r][c] += weight;
                            }
                        }
                    }
                }
            }
        }
    }

    density
}

/// Selecciona el mejor disparo para `ai_player` según `difficulty`:
/// - `Easy`: disparo aleatorio en celdas no disparadas.
/// - `Medium`: disparo aleatorio pero prioriza celdas ortogonalmente adyacentes si hay un impacto sin hundir.
/// - `Hard` / `Expert`: probability density map — cuenta cuántas orientaciones de barcos no hundidos
///   pueden cubrir cada celda y dispara a la de mayor densidad.
pub fn best_move(
    state: &BattleshipState,
    ai_player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<BattleshipCommand> {
    let opponent = resolve_opponent(state, ai_player);
    let shots = state.world().get_resource::<ShotsResource>();
    let fleet = state.world().get_resource::<FleetResource>();

    let mut untouched = Vec::new();
    let mut unsunk_hits = Vec::new();

    for r in 0..BOARD_SIZE {
        for c in 0..BOARD_SIZE {
            let pos = Position::new(r, c);
            if !is_cell_touched(shots, fleet, ai_player, opponent, pos) {
                untouched.push(pos);
            } else if is_unsunk_hit(fleet, opponent, pos) {
                unsunk_hits.push(pos);
            }
        }
    }

    if untouched.is_empty() {
        return None;
    }

    // Semilla determinista derivada del estado actual para selecciones en Easy/Medium
    let touched_count = (BOARD_SIZE as usize * BOARD_SIZE as usize) - untouched.len();
    let mix = (touched_count as u64).wrapping_mul(0x517cc1b727220a95);
    let seed = (state.id.0 ^ ((ai_player.0 as u64) << 32) ^ mix).max(1);
    let mut rng = FastRng::new(seed);

    let target = match difficulty {
        AiDifficulty::Easy => {
            let idx = rng.next_usize(untouched.len());
            untouched[idx]
        }
        AiDifficulty::Medium => {
            let mut adjacent_targets = Vec::new();
            for hit in &unsunk_hits {
                let neighbors = [
                    (hit.row.checked_sub(1), Some(hit.col)),
                    (Some(hit.row + 1), Some(hit.col)),
                    (Some(hit.row), hit.col.checked_sub(1)),
                    (Some(hit.row), Some(hit.col + 1)),
                ];
                for (nr, nc) in neighbors {
                    if let (Some(r), Some(c)) = (nr, nc) {
                        let candidate = Position::new(r, c);
                        if candidate.is_on_board()
                            && !is_cell_touched(shots, fleet, ai_player, opponent, candidate)
                            && !adjacent_targets.contains(&candidate)
                        {
                            adjacent_targets.push(candidate);
                        }
                    }
                }
            }

            if !adjacent_targets.is_empty() {
                let idx = rng.next_usize(adjacent_targets.len());
                adjacent_targets[idx]
            } else {
                let idx = rng.next_usize(untouched.len());
                untouched[idx]
            }
        }
        AiDifficulty::Hard | AiDifficulty::Expert => {
            let density = compute_probability_density_map(state, ai_player);
            let mut best_pos = untouched[0];
            let mut best_score = 0u32;

            for &pos in &untouched {
                let score = density[pos.row as usize][pos.col as usize];
                if score > best_score {
                    best_score = score;
                    best_pos = pos;
                }
            }
            best_pos
        }
    };

    Some(FireShotCommand {
        player: ai_player,
        target,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_battleship_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn easy_ai_fires_untouched_cell() {
        let mut session = new_battleship_session(SessionId(1), 42, P1, P2);
        let untouched_target = Position::new(7, 8);

        {
            let mut shots = session.world_mut().resource_mut::<ShotsResource>();
            for r in 0..BOARD_SIZE {
                for c in 0..BOARD_SIZE {
                    let pos = Position::new(r, c);
                    if pos != untouched_target {
                        shots.record_shot(P1, pos);
                    }
                }
            }
        }

        let cmd = best_move(&session, P1, AiDifficulty::Easy).unwrap();
        assert_eq!(cmd.player, P1);
        assert_eq!(cmd.target, untouched_target);
    }

    #[test]
    fn medium_ai_hunts_after_hit() {
        let mut session = new_battleship_session(SessionId(1), 7, P1, P2);
        let hit_pos = Position::new(5, 5);

        {
            let mut fleet = session.world_mut().resource_mut::<FleetResource>();
            fleet.ships.insert(
                P2,
                vec![vec![
                    Position::new(5, 5),
                    Position::new(5, 6),
                    Position::new(5, 7),
                ]],
            );
            fleet.hits.insert(P2, vec![hit_pos]);
        }
        {
            let mut shots = session.world_mut().resource_mut::<ShotsResource>();
            shots.record_shot(P1, hit_pos);
        }

        let cmd = best_move(&session, P1, AiDifficulty::Medium).unwrap();

        let expected_neighbors = [
            Position::new(4, 5),
            Position::new(6, 5),
            Position::new(5, 4),
            Position::new(5, 6),
        ];
        assert!(
            expected_neighbors.contains(&cmd.target),
            "Se esperaba un vecino ortogonal de (5,5), pero se obtuvo {:?}",
            cmd.target
        );
    }

    #[test]
    fn hard_ai_prefers_high_density() {
        let mut session = new_battleship_session(SessionId(1), 99, P1, P2);

        // Aislar la esquina (0,0) con fallos en (0,1) y (1,0) para que ningún barco de tamaño >= 2 quepa allí.
        {
            let mut shots = session.world_mut().resource_mut::<ShotsResource>();
            shots.record_shot(P1, Position::new(0, 1));
            shots.record_shot(P1, Position::new(1, 0));
        }

        let density = compute_probability_density_map(&session, P1);
        assert_eq!(
            density[0][0], 0,
            "La celda aislada (0,0) no puede alojar ningún barco de tamaño >= 2"
        );

        let cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();

        let chosen_density = density[cmd.target.row as usize][cmd.target.col as usize];
        let max_density = density.iter().flatten().copied().max().unwrap_or(0);

        assert_eq!(
            chosen_density, max_density,
            "Hard AI debe elegir una celda con la densidad máxima ({max_density})"
        );
        assert!(
            chosen_density > density[0][9],
            "La celda central elegida debe tener mayor densidad que una esquina"
        );
    }
}
