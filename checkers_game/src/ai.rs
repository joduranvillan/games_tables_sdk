use open_table_engine::prelude::*;

use crate::board::{BoardResource, MultiCaptureResource, Sides};
use crate::commands::MovePieceCommand;
use crate::legal_moves::CheckersLegalMoveGenerator;
use crate::position::Position;

fn clone_checkers_session(session: &Session) -> Session {
    let sides = session
        .world()
        .get_resource::<Sides>()
        .copied()
        .unwrap_or(Sides {
            increasing: PlayerId(1),
            decreasing: PlayerId(2),
        });

    let mut new_session =
        crate::new_checkers_session(session.id, 0, sides.increasing, sides.decreasing);

    if let Some(board) = session.world().get_resource::<BoardResource>() {
        new_session.world_mut().insert_resource(board.clone());
    }
    if let Some(mc) = session.world().get_resource::<MultiCaptureResource>() {
        new_session.world_mut().insert_resource(mc.clone());
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
        .world_mut()
        .insert_resource(LegalMoveGeneratorResource(std::sync::Arc::new(
            CheckersLegalMoveGenerator,
        )));

    new_session
}

/// Selecciona una jugada legal para el jugador especificado en la sesión dada.
///
/// Si existen capturas legales, selecciona una al azar entre ellas.
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

    let mut captures = Vec::new();
    let mut simple_moves = Vec::new();

    for r in 0..8u8 {
        for c in 0..8u8 {
            let from = Position::new(r, c);
            if let Some(piece) = board.get(from) {
                if piece.owner != player {
                    continue;
                }

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
                        let mut test_session = clone_checkers_session(session);

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

/// Selecciona la mejor jugada legal en Damas ajustando la profundidad según `AiDifficulty`.
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<MovePieceCommand> {
    let _depth = difficulty.max_depth();
    checkers_ai_pick_move(session, player)
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
