use crate::board::{BoardHistoryResource, BoardResource, DeadMarkingResource};
use crate::commands::{PassCommand, PlaceStoneCommand};
use open_table_engine::prelude::*;

/// Generador de números pseudoaleatorios rápido (XorShift64).
struct FastRng {
    state: u64,
}

impl FastRng {
    fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 0x853c49e6748fea9b } else { seed },
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

/// Clona una sesión de Go replicando su estado de recursos.
pub fn clone_go_session(session: &Session) -> Session {
    let (black, white) = session
        .world()
        .get_resource::<BoardResource>()
        .map(|b| (b.black_player, b.white_player))
        .unwrap_or((PlayerId(1), PlayerId(2)));

    let mut new_session = crate::new_go_session(session.id, 0, black, white);

    if let Some(board) = session.world().get_resource::<BoardResource>() {
        new_session.world_mut().insert_resource(board.clone());
    }
    if let Some(history) = session.world().get_resource::<BoardHistoryResource>() {
        new_session.world_mut().insert_resource(history.clone());
    }
    if let Some(dead_marking) = session.world().get_resource::<DeadMarkingResource>() {
        new_session
            .world_mut()
            .insert_resource(dead_marking.clone());
    }
    if let Some(turn) = session.world().get_resource::<TurnResource>() {
        new_session.world_mut().insert_resource(turn.clone());
    }
    if let Some(game_over) = session.world().get_resource::<GameOverResource>() {
        new_session.world_mut().insert_resource(*game_over);
    }
    if let Some(winner) = session.world().get_resource::<WinnerResource>() {
        new_session.world_mut().insert_resource(*winner);
    }

    new_session
}

/// Genera todas las intersecciones vacías donde colocar una piedra sea un movimiento legal
/// (sin suicidio ni violación de superko).
pub fn generate_legal_moves(session: &Session, player: PlayerId) -> Vec<PlaceStoneCommand> {
    let board = match session.world().get_resource::<BoardResource>() {
        Some(b) => b,
        None => return Vec::new(),
    };

    let mut legal_moves = Vec::new();
    for y in 0..board.size {
        for x in 0..board.size {
            if board.get_stone(x, y).is_none() {
                let cmd = PlaceStoneCommand { player, x, y };
                let mut trial = clone_go_session(session);
                if trial.process_command(player, Box::new(cmd.clone())).is_ok() {
                    legal_moves.push(cmd);
                }
            }
        }
    }
    legal_moves
}

/// Calcula el territorio para cada jugador en el tablero actual usando flood-fill.
pub fn count_territory(board: &BoardResource) -> (usize, usize) {
    board.calculate_territory()
}

/// Selecciona el mejor movimiento para `player` en `session` usando Monte Carlo con presupuesto de 200 rollouts.
pub fn go_ai_pick_move(session: &Session, player: PlayerId) -> Option<PlaceStoneCommand> {
    best_move(session, player, AiDifficulty::Hard)
}

/// Selecciona el mejor movimiento para `player` en `session` usando `difficulty.rollouts()` simulaciones MCTS.
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<PlaceStoneCommand> {
    if session
        .world()
        .get_resource::<GameOverResource>()
        .is_some_and(|r| r.0)
    {
        return None;
    }

    if session.current_player() != player {
        return None;
    }

    let _board = session.world().get_resource::<BoardResource>()?;
    let candidates = generate_legal_moves(session, player);
    if candidates.is_empty() {
        return None;
    }

    let total_budget: usize = difficulty.rollouts();
    let n = candidates.len();
    let rollouts_per_candidate = (total_budget / n).max(5);

    let mut rng = FastRng::new(
        (session.id.0 ^ session.current_tick().0)
            .wrapping_mul(0x9e3779b97f4a7c15)
            .wrapping_add(1),
    );

    let mut best_move = None;
    let mut best_win_rate = -1.0f32;
    let mut best_net_score = f32::NEG_INFINITY;

    for candidate in &candidates {
        let mut wins = 0.0f32;
        let mut total_score_diff = 0.0f32;

        for _ in 0..rollouts_per_candidate {
            let mut sim_session = clone_go_session(session);
            // Ejecutar el movimiento candidato
            if sim_session
                .process_command(player, Box::new(candidate.clone()))
                .is_err()
            {
                continue;
            }

            // Simulación aleatoria hasta 50 movimientos o fin de juego
            let max_rollout_steps = 50;
            let mut consecutive_passes = 0;

            for _ in 0..max_rollout_steps {
                let current_p = sim_session.current_player();
                let sim_board = match sim_session.world().get_resource::<BoardResource>() {
                    Some(b) => b,
                    None => break,
                };

                let mut empty_positions = Vec::new();
                for y in 0..sim_board.size {
                    for x in 0..sim_board.size {
                        if sim_board.get_stone(x, y).is_none() {
                            empty_positions.push((x, y));
                        }
                    }
                }

                if empty_positions.is_empty() {
                    let _ = sim_session
                        .process_command(current_p, Box::new(PassCommand { player: current_p }));
                    consecutive_passes += 1;
                    if consecutive_passes >= 2 {
                        break;
                    }
                    continue;
                }

                // Intentar hasta 10 posiciones vacías al azar
                let mut played = false;
                let attempts = empty_positions.len().min(10);
                for _ in 0..attempts {
                    let idx = rng.next_usize(empty_positions.len());
                    let (x, y) = empty_positions[idx];
                    let cmd = PlaceStoneCommand {
                        player: current_p,
                        x,
                        y,
                    };
                    if sim_session
                        .process_command(current_p, Box::new(cmd))
                        .is_ok()
                    {
                        played = true;
                        consecutive_passes = 0;
                        break;
                    }
                }

                if !played {
                    let _ = sim_session
                        .process_command(current_p, Box::new(PassCommand { player: current_p }));
                    consecutive_passes += 1;
                    if consecutive_passes >= 2 {
                        break;
                    }
                }
            }

            // Evaluar territorio al final del rollout
            if let Some(final_board) = sim_session.world().get_resource::<BoardResource>() {
                let (black_t, white_t) = count_territory(final_board);
                let (my_score, opp_score) = if player == final_board.black_player {
                    (black_t as f32, white_t as f32)
                } else {
                    (white_t as f32, black_t as f32)
                };

                total_score_diff += my_score - opp_score;
                if my_score > opp_score {
                    wins += 1.0;
                } else if (my_score - opp_score).abs() < 1e-3 {
                    wins += 0.5;
                }
            }
        }

        let win_rate = wins / (rollouts_per_candidate as f32);
        let avg_score_diff = total_score_diff / (rollouts_per_candidate as f32);

        if win_rate > best_win_rate
            || ((win_rate - best_win_rate).abs() < 1e-4 && avg_score_diff > best_net_score)
            || best_move.is_none()
        {
            best_win_rate = win_rate;
            best_net_score = avg_score_diff;
            best_move = Some(candidate.clone());
        }
    }

    best_move
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_go_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn test_go_ai_devuelve_movimiento_o_none_en_posicion_inicial() {
        let start = std::time::Instant::now();
        let session = new_go_session(SessionId(1), 42, P1, P2);

        let mv = go_ai_pick_move(&session, P1);
        let duration = start.elapsed();

        assert!(
            mv.is_some(),
            "La IA de Go debe devolver un movimiento en posición inicial"
        );
        let chosen = mv.unwrap();
        assert!(chosen.x < 9 && chosen.y < 9);
        // En debug mode con bevy_ecs 0.19 (recursos como entidades) el overhead es mayor.
        // 10s es suficiente para detectar un loop infinito sin fallos espurios.
        assert!(
            duration.as_secs_f32() < 10.0,
            "La selección de jugada debe tomar menos de 10 segundos, tomó: {:?}",
            duration
        );
    }
}
