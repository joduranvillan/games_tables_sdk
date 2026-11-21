// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

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

/// Evalúa heurísticamente el tablero de Damas para `player` (material, damas coronadas, avance y centro).
pub fn evaluate_checkers_board(session: &Session, player: PlayerId) -> f32 {
    let Some(board) = session.world().get_resource::<BoardResource>() else {
        return 0.0;
    };
    let sides = session
        .world()
        .get_resource::<Sides>()
        .copied()
        .unwrap_or(Sides {
            increasing: PlayerId(1),
            decreasing: PlayerId(2),
        });
    let mut score = 0.0f32;
    for r in 0..8u8 {
        for c in 0..8u8 {
            if let Some(piece) = board.get(Position::new(r, c)) {
                let base = if piece.is_king { 2.6 } else { 1.0 };
                let adv = if piece.owner == sides.increasing {
                    f32::from(r) * 0.05
                } else {
                    f32::from(7u8.saturating_sub(r)) * 0.05
                };
                let center = (3.5 - (f32::from(c) - 3.5).abs()).max(0.0) * 0.02;
                let edge_safe = if c == 0 || c == 7 { 0.04 } else { 0.0 };
                let total = base + adv + center + edge_safe;
                if piece.owner == player {
                    score += total;
                } else {
                    score -= total;
                }
            }
        }
    }
    score
}

fn generate_checkers_moves(world: &BevyWorld, player: PlayerId) -> Vec<MovePieceCommand> {
    let Some(board) = world.get_resource::<BoardResource>() else {
        return vec![];
    };
    let Some(sides) = world.get_resource::<Sides>() else {
        return vec![];
    };

    let mut candidates: Vec<MovePieceCommand> = Vec::new();
    let captures = board.get_all_available_captures(sides, player);
    let active_jumper = world
        .get_resource::<MultiCaptureResource>()
        .and_then(|m| m.active_piece);

    if !captures.is_empty() {
        for (from, to) in captures {
            if let Some(req) = active_jumper {
                if from != req {
                    continue;
                }
            }
            candidates.push(MovePieceCommand { player, from, to });
        }
    } else if active_jumper.is_none() {
        let forward = sides.forward_direction(player);
        for r in 0..8u8 {
            for c in 0..8u8 {
                let from = Position::new(r, c);
                if let Some(piece) = board.get(from) {
                    if piece.owner != player {
                        continue;
                    }
                    let offsets: &[(i8, i8)] = if piece.is_king {
                        &[(-1, -1), (-1, 1), (1, -1), (1, 1)]
                    } else if forward == 1 {
                        &[(1, -1), (1, 1)]
                    } else {
                        &[(-1, -1), (-1, 1)]
                    };
                    for &(dr, dc) in offsets {
                        let nr = r as i8 + dr;
                        let nc = c as i8 + dc;
                        if (0..8).contains(&nr) && (0..8).contains(&nc) {
                            let to = Position::new(nr as u8, nc as u8);
                            if to.is_dark_square() && board.get(to).is_none() {
                                candidates.push(MovePieceCommand { player, from, to });
                            }
                        }
                    }
                }
            }
        }
    }

    candidates
}

/// Selecciona la mejor jugada legal en Damas ajustando la evaluación según `AiDifficulty`.
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<MovePieceCommand> {
    best_move_with_randomness(session, player, difficulty, 0, 0)
}

/// Selecciona la mejor jugada legal en Damas con factor de aleatoriedad (`randomness_pct`, `0..=100`).
pub fn best_move_with_randomness(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
    randomness_pct: u8,
    seed: u64,
) -> Option<MovePieceCommand> {
    if difficulty == AiDifficulty::Easy && randomness_pct == 0 {
        return checkers_ai_pick_move(session, player);
    }
    let legal = generate_checkers_moves(session.world(), player);
    if legal.is_empty() {
        return checkers_ai_pick_move(session, player);
    }
    let mut scored_cmds = Vec::with_capacity(legal.len());
    let mut scores = Vec::with_capacity(legal.len());

    for cmd in legal {
        let mut next_session = clone_checkers_session(session);
        if next_session
            .process_command(player, Box::new(cmd.clone()))
            .is_ok()
        {
            let mut score = evaluate_checkers_board(&next_session, player);
            if matches!(difficulty, AiDifficulty::Hard | AiDifficulty::Expert) {
                let opp = next_session.current_player();
                if opp != player {
                    let opp_moves = generate_checkers_moves(next_session.world(), opp);
                    let mut worst_reply = score;
                    for opp_cmd in opp_moves.into_iter().take(8) {
                        let mut reply_sess = clone_checkers_session(&next_session);
                        if reply_sess.process_command(opp, Box::new(opp_cmd)).is_ok() {
                            let reply_eval = evaluate_checkers_board(&reply_sess, player);
                            if reply_eval < worst_reply {
                                worst_reply = reply_eval;
                            }
                        }
                    }
                    score = worst_reply;
                }
            }
            scored_cmds.push(cmd);
            scores.push(score);
        }
    }

    let safety_band = match difficulty {
        AiDifficulty::Easy => 1.5,
        AiDifficulty::Medium => 0.65,
        AiDifficulty::Hard => 0.30,
        AiDifficulty::Expert => 0.15,
    };
    if let Some(idx) = AiDifficulty::select_top_k_with_noise(
        &scores,
        randomness_pct,
        safety_band,
        seed ^ session.current_tick().0 ^ session.id.0,
    ) {
        return scored_cmds.into_iter().nth(idx);
    }
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
