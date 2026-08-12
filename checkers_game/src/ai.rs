use open_table_engine::prelude::*;

use crate::board::BoardResource;
use crate::commands::MovePieceCommand;
use crate::position::Position;

/// Selecciona una jugada legal para el jugador especificado en la sesión dada.
///
/// Evalúa los movimientos posibles (capturas y pasos simples) mediante
/// prueba y error llamando a `session.process_command` en una copia temporal
/// de la sesión. Si existen capturas legales, selecciona una al azar entre ellas.
/// Si no hay capturas, selecciona al azar entre los movimientos simples legales.
/// Devuelve `None` si la partida ha terminado, si no es el turno del jugador o
/// si no hay movimientos legales disponibles.
pub fn checkers_ai_pick_move(session: &Session, player: PlayerId) -> Option<MovePieceCommand> {
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

    let board = session.world().get_resource::<BoardResource>()?;

    let players = session
        .world()
        .get_resource::<TurnResource>()
        .map(|t| t.0.players().to_vec())
        .unwrap_or_default();
    if players.is_empty() {
        return None;
    }
    let p1 = players[0];
    let p2 = players.get(1).copied().unwrap_or(p1);

    // Recreamos el estado actual en una sesión base de prueba
    let mut base_trial = crate::new_checkers_session(session.id, 0, p1, p2);
    for (_tick, _elapsed, cmd) in session.command_log() {
        let sender = cmd.issuer().unwrap_or_else(|| base_trial.current_player());
        let _ = base_trial.process_command(sender, cmd.clone());
    }

    let mut captures = Vec::new();
    let mut simple_moves = Vec::new();

    // Recorremos las fichas del jugador
    for r in 0..8u8 {
        for c in 0..8u8 {
            let from = Position::new(r, c);
            if let Some(piece) = board.get(from) {
                if piece.owner != player {
                    continue;
                }

                // Generar posiciones de destino candidatas (diagonales 1 y 2)
                let offsets: &[(i8, i8)] = &[
                    (-1, -1),
                    (-1, 1),
                    (1, -1),
                    (1, 1),
                    (-2, -2),
                    (-2, 2),
                    (2, -2),
                    (2, 2),
                ];

                for &(dr, dc) in offsets {
                    let nr = r as i8 + dr;
                    let nc = c as i8 + dc;
                    if (0..8).contains(&nr) && (0..8).contains(&nc) {
                        let to = Position::new(nr as u8, nc as u8);
                        if !to.is_dark_square() {
                            continue;
                        }

                        let candidate_cmd = MovePieceCommand { player, from, to };

                        // Probar el comando sobre una copia de base_trial
                        let mut test_session = crate::new_checkers_session(session.id, 0, p1, p2);
                        for (_tick, _elapsed, cmd) in base_trial.command_log() {
                            let sender = cmd
                                .issuer()
                                .unwrap_or_else(|| test_session.current_player());
                            let _ = test_session.process_command(sender, cmd.clone());
                        }

                        if test_session
                            .process_command(player, Box::new(candidate_cmd.clone()))
                            .is_ok()
                        {
                            if dr.abs() == 2 {
                                captures.push(candidate_cmd);
                            } else {
                                simple_moves.push(candidate_cmd);
                            }
                        }
                    }
                }
            }
        }
    }

    let candidate_pool = if !captures.is_empty() {
        &captures
    } else if !simple_moves.is_empty() {
        &simple_moves
    } else {
        return None;
    };

    let idx = if let Some(rand_res) = session.world().get_resource::<RandomResource>() {
        let mut rng = rand_res.0.clone();
        (rng.next_u32() as usize) % candidate_pool.len()
    } else {
        (session.current_tick().0 as usize + candidate_pool.len()) % candidate_pool.len()
    };

    Some(candidate_pool[idx].clone())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_checkers_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn test_ai_always_returns_a_move_when_board_not_over() {
        let mut session = new_checkers_session(SessionId(1), 42, P1, P2);

        // La partida está recién iniciada (no ha terminado)
        let is_over = session
            .world()
            .get_resource::<GameOverResource>()
            .map_or(false, |r| r.0);
        assert!(!is_over, "El tablero no debe estar terminado");

        let current_player = session.current_player();
        let mv = checkers_ai_pick_move(&session, current_player);

        assert!(
            mv.is_some(),
            "La IA debe retornar un movimiento cuando la partida no ha terminado"
        );

        let chosen_move = mv.unwrap();
        assert_eq!(chosen_move.player, current_player);

        // Comprobamos que el movimiento seleccionado por la IA es realmente aplicable en la sesión
        let res = session.process_command(current_player, Box::new(chosen_move));
        assert!(
            res.is_ok(),
            "El movimiento retornado por la IA debe ser válido"
        );
    }

    #[test]
    fn test_ai_returns_none_when_game_over() {
        let mut session = new_checkers_session(SessionId(1), 42, P1, P2);
        session.world_mut().insert_resource(GameOverResource(true));

        let mv = checkers_ai_pick_move(&session, P1);
        assert!(
            mv.is_none(),
            "La IA debe retornar None cuando la partida terminó"
        );
    }

    #[test]
    fn test_ai_returns_none_when_not_player_turn() {
        let session = new_checkers_session(SessionId(1), 42, P1, P2);
        assert_eq!(session.current_player(), P1);

        let mv = checkers_ai_pick_move(&session, P2);
        assert!(
            mv.is_none(),
            "La IA debe retornar None si no es el turno del jugador"
        );
    }
}
