//! Inteligencia Artificial MCTS ligero para Damas Chinas (Chinese Checkers).
//!
//! - Ejecuta `difficulty.rollouts()` simulaciones aleatorias (playouts).
//! - Función de evaluación: distancia total hexagonal de los peones del jugador al objetivo
//!   (minimizar suma de distancias al vértice objetivo).

#![allow(clippy::needless_range_loop)]

use std::collections::{HashSet, VecDeque};

use open_table_engine::prelude::*;

use crate::board::BoardResource;
use crate::commands::MovePegCommand;
use crate::position::{Position, DIRECTIONS};

/// Estado de partida de Damas Chinas.
pub type ChineseCheckersState = Session;

/// Comando devuelto por la IA de Damas Chinas.
pub type ChineseCheckersCommand = MovePegCommand;

/// Generador pseudoaleatorio rápido (XorShift64) para rollouts MCTS.
struct FastRng {
    state: u64,
}

impl FastRng {
    fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 {
                0x243f_6a88_85a3_08d3
            } else {
                seed
            },
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

/// Distancia hexagonal en coordenadas axiales `(q, r)`.
pub fn hex_distance(a: Position, b: Position) -> i32 {
    let dq = a.q - b.q;
    let dr = a.r - b.r;
    (dq.abs() + dr.abs() + (dq + dr).abs()) / 2
}

/// Obtiene la casilla vértice (más alejada del centro) de la esquina objetivo de `player`.
pub fn goal_apex(board: &BoardResource, player: PlayerId) -> Position {
    board
        .targets
        .get(&player)
        .and_then(|cells| {
            cells
                .iter()
                .copied()
                .max_by_key(|pos| hex_distance(*pos, Position::new(0, 0)))
        })
        .unwrap_or(Position::new(0, 0))
}

/// Calcula la distancia total de todos los peones de `player` hacia su objetivo (a minimizar).
pub fn total_distance_to_goal(board: &BoardResource, player: PlayerId) -> i32 {
    let apex = goal_apex(board, player);
    board
        .pegs
        .iter()
        .filter(|(_, &owner)| owner == player)
        .map(|(&pos, _)| hex_distance(pos, apex))
        .sum()
}

/// Genera todos los movimientos legales (`MovePegCommand`) para `player` en `board`,
/// incluyendo pasos adyacentes y cadenas de saltos.
pub fn generate_legal_moves(board: &BoardResource, player: PlayerId) -> Vec<MovePegCommand> {
    let mut moves = Vec::new();
    let mut player_pegs: Vec<Position> = board
        .pegs
        .iter()
        .filter_map(|(&pos, &owner)| if owner == player { Some(pos) } else { None })
        .collect();
    player_pegs.sort_by_key(|p| (p.q, p.r));

    for from in player_pegs {
        // 1. Pasos simples a casillas adyacentes vacías
        for &dir in &DIRECTIONS {
            let to = from.add(dir);
            if to.is_on_board() && !board.pegs.contains_key(&to) {
                moves.push(MovePegCommand {
                    player,
                    from,
                    to,
                    path: vec![to],
                });
            }
        }

        // 2. Saltos simples y encadenados (BFS)
        let mut visited = HashSet::new();
        visited.insert(from);
        let mut queue: VecDeque<(Position, Vec<Position>)> = VecDeque::new();
        queue.push_back((from, Vec::new()));

        while let Some((curr, path_so_far)) = queue.pop_front() {
            for &dir in &DIRECTIONS {
                let mid = curr.add(dir);
                let land = curr.add((dir.0 * 2, dir.1 * 2));
                if land.is_on_board()
                    && board.pegs.contains_key(&mid)
                    && !board.pegs.contains_key(&land)
                    && visited.insert(land)
                {
                    let mut next_path = path_so_far.clone();
                    next_path.push(land);
                    moves.push(MovePegCommand {
                        player,
                        from,
                        to: land,
                        path: next_path.clone(),
                    });
                    queue.push_back((land, next_path));
                }
            }
        }
    }

    moves
}

/// Selecciona el mejor movimiento para `ai` usando MCTS ligero con `difficulty.rollouts()` simulaciones
/// aleatorias y evaluación por distancia total al objetivo (minimizar suma).
pub fn best_move(
    state: &ChineseCheckersState,
    ai: PlayerId,
    difficulty: AiDifficulty,
) -> Option<ChineseCheckersCommand> {
    let board = state.world().get_resource::<BoardResource>()?;
    let candidates = generate_legal_moves(board, ai);
    if candidates.is_empty() {
        return None;
    }

    let apex = goal_apex(board, ai);
    let initial_total_dist = total_distance_to_goal(board, ai);

    // Filtrar candidatos que no empeoren innecesariamente la distancia si existen movimientos de avance
    let advancing_candidates: Vec<MovePegCommand> = candidates
        .iter()
        .filter(|cmd| hex_distance(cmd.to, apex) < hex_distance(cmd.from, apex))
        .cloned()
        .collect();

    let pool = if !advancing_candidates.is_empty() {
        advancing_candidates
    } else {
        candidates
    };

    let rollouts = difficulty.rollouts().max(1);
    let mut rng = FastRng::new((state.id.0 ^ ((ai.0 as u64) << 16) ^ (rollouts as u64)).max(1));

    let mut visit_counts = vec![0u32; pool.len()];
    let mut total_scores = vec![0.0f64; pool.len()];

    for r in 0..rollouts {
        let idx = r % pool.len();
        let candidate = &pool[idx];

        let mut sim_pegs = board.pegs.clone();
        sim_pegs.remove(&candidate.from);
        sim_pegs.insert(candidate.to, ai);

        // Playout corto aleatorio de hasta 3 pasos adicionales para estimar potencial futuro
        for _step in 0..3 {
            let my_pegs: Vec<Position> = sim_pegs
                .iter()
                .filter_map(|(&pos, &owner)| if owner == ai { Some(pos) } else { None })
                .collect();
            if my_pegs.is_empty() {
                break;
            }
            let peg = my_pegs[rng.next_usize(my_pegs.len())];
            let dir = DIRECTIONS[rng.next_usize(DIRECTIONS.len())];
            let next_pos = peg.add(dir);
            if next_pos.is_on_board()
                && !sim_pegs.contains_key(&next_pos)
                && hex_distance(next_pos, apex) <= hex_distance(peg, apex)
            {
                sim_pegs.remove(&peg);
                sim_pegs.insert(next_pos, ai);
            }
        }

        let sim_dist: i32 = sim_pegs
            .iter()
            .filter(|(_, &owner)| owner == ai)
            .map(|(&pos, _)| hex_distance(pos, apex))
            .sum();

        let immediate_gain =
            (hex_distance(candidate.from, apex) - hex_distance(candidate.to, apex)) as f64;
        let rollout_gain = (initial_total_dist - sim_dist) as f64;

        visit_counts[idx] += 1;
        // Damos peso principal a la reducción real de distancia total de peones al objetivo
        total_scores[idx] += immediate_gain * 10.0 + rollout_gain;
    }

    let mut best_idx = 0;
    let mut best_avg = f64::NEG_INFINITY;

    for i in 0..pool.len() {
        let avg = if visit_counts[i] > 0 {
            total_scores[i] / (visit_counts[i] as f64)
        } else {
            let cmd = &pool[i];
            (hex_distance(cmd.from, apex) - hex_distance(cmd.to, apex)) as f64 * 10.0
        };
        if avg > best_avg {
            best_avg = avg;
            best_idx = i;
        }
    }

    Some(pool[best_idx].clone())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_chinese_checkers_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn chinese_checkers_ai_moves_toward_goal() {
        let mut session = new_chinese_checkers_session(SessionId(1), 42, vec![P1, P2]);

        let dist_before = {
            let board = session.world().resource::<BoardResource>();
            total_distance_to_goal(board, P1)
        };

        let cmd = best_move(&session, P1, AiDifficulty::Medium).unwrap();
        assert_eq!(cmd.player, P1);

        session.process_command(P1, Box::new(cmd)).unwrap();

        let dist_after = {
            let board = session.world().resource::<BoardResource>();
            total_distance_to_goal(board, P1)
        };

        assert!(
            dist_after < dist_before,
            "La distancia total al objetivo debe disminuir tras el movimiento de la IA (antes={dist_before}, después={dist_after})"
        );
    }
}
