// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;

use crate::board::{BoardResource, PieceKind};
use crate::commands::MovePieceCommand;
use crate::movement::{check_flying_general, is_in_check};
use crate::rules::all_legal_moves_for;

/// Comprueba si un Cañón en la posición `(cx, cy)` dispone de al menos una pieza en su fila o columna
/// que pueda servir como pantalla / plataforma de salto.
pub fn cannon_has_screen(board: &BoardResource, cx: usize, cy: usize) -> bool {
    for &(x, y) in board.squares.keys() {
        if (x == cx && y != cy) || (y == cy && x != cx) {
            return true;
        }
    }
    false
}

/// Valor material de las piezas de Xiangqi:
/// Peón (Soldier)=1, Caballo (Horse)=4, Alfil (Elephant)/Consejero (Advisor)=2,
/// Torre (Chariot)=9, Cañón (Cannon)=4.5, General=1000.
pub fn piece_value(kind: PieceKind) -> f32 {
    match kind {
        PieceKind::Soldier => 1.0,
        PieceKind::Advisor => 2.0,
        PieceKind::Elephant => 2.0,
        PieceKind::Horse => 4.0,
        PieceKind::Cannon => 4.5,
        PieceKind::Chariot => 9.0,
        PieceKind::General => 1000.0,
    }
}

/// Evaluación estática material y posicional para Xiangqi.
/// Incluye bonus de +0.5 si el Cañón tiene al menos 1 pantalla disponible.
pub fn evaluate_position(session: &Session, player: PlayerId) -> f32 {
    if let Some(game_over) = session.world().get_resource::<GameOverResource>() {
        if game_over.0 {
            if let Some(winner) = session
                .world()
                .get_resource::<WinnerResource>()
                .and_then(|w| w.0)
            {
                return if winner == player {
                    100_000.0
                } else {
                    -100_000.0
                };
            } else {
                return 0.0;
            }
        }
    }

    let Some(board) = session.world().get_resource::<BoardResource>() else {
        return 0.0;
    };

    let opponent = if player == board.red {
        board.black
    } else {
        board.red
    };

    let mut score = 0.0f32;

    for (&(x, y), piece) in &board.squares {
        let mut val = piece_value(piece.kind);
        if piece.kind == PieceKind::Cannon && cannon_has_screen(board, x, y) {
            val += 0.5;
        }

        if piece.owner == player {
            score += val;
        } else if piece.owner == opponent {
            score -= val;
        }
    }

    score
}

/// Clona una sesión de Xiangqi copiando sus recursos relevantes.
pub fn clone_xiangqi_session(session: &Session) -> Session {
    let (red, black) = session
        .world()
        .get_resource::<BoardResource>()
        .map(|b| (b.red, b.black))
        .unwrap_or((PlayerId(1), PlayerId(2)));

    let mut new_session = crate::new_xiangqi_session(session.id, 0, red, black);

    if let Some(board) = session.world().get_resource::<BoardResource>() {
        new_session.world_mut().insert_resource(board.clone());
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
    if let Some(history) = session
        .world()
        .get_resource::<crate::board::XiangqiHistoryResource>()
    {
        new_session.world_mut().insert_resource(history.clone());
    }

    new_session
}

/// Minimax con poda alfa-beta para Xiangqi.
pub fn minimax(
    session: &Session,
    depth: u8,
    mut alpha: f32,
    mut beta: f32,
    maximizing: bool,
    player: PlayerId,
) -> f32 {
    if let Some(game_over) = session.world().get_resource::<GameOverResource>() {
        if game_over.0 {
            if let Some(winner) = session
                .world()
                .get_resource::<WinnerResource>()
                .and_then(|w| w.0)
            {
                return if winner == player {
                    100_000.0
                } else {
                    -100_000.0
                };
            } else {
                return 0.0;
            }
        }
    }

    if depth == 0 {
        return evaluate_position(session, player);
    }

    let current = session.current_player();
    let candidates = all_legal_moves_for(session.world(), current);

    if candidates.is_empty() {
        let board = match session.world().get_resource::<BoardResource>() {
            Some(b) => b,
            None => return 0.0,
        };
        let in_chk = is_in_check(board, current) || check_flying_general(board);
        return if in_chk {
            if current == player {
                f32::NEG_INFINITY
            } else {
                f32::INFINITY
            }
        } else {
            0.0
        };
    }

    if maximizing {
        let mut max_eval = f32::NEG_INFINITY;
        for mv in candidates {
            let mut next_session = clone_xiangqi_session(session);
            if next_session.process_command(current, Box::new(mv)).is_ok() {
                let eval = minimax(&next_session, depth - 1, alpha, beta, false, player);
                if eval > max_eval {
                    max_eval = eval;
                }
                if eval > alpha {
                    alpha = eval;
                }
                if beta <= alpha {
                    break;
                }
            }
        }
        max_eval
    } else {
        let mut min_eval = f32::INFINITY;
        for mv in candidates {
            let mut next_session = clone_xiangqi_session(session);
            if next_session.process_command(current, Box::new(mv)).is_ok() {
                let eval = minimax(&next_session, depth - 1, alpha, beta, true, player);
                if eval < min_eval {
                    min_eval = eval;
                }
                if eval < beta {
                    beta = eval;
                }
                if beta <= alpha {
                    break;
                }
            }
        }
        min_eval
    }
}

/// Selecciona la mejor jugada legal para `player` en `session` usando Minimax a depth=2.
pub fn xiangqi_ai_pick_move(session: &Session, player: PlayerId) -> Option<MovePieceCommand> {
    best_move(session, player, AiDifficulty::Medium)
}

/// Selecciona la mejor jugada legal para `player` en `session` usando `difficulty.max_depth()`.
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<MovePieceCommand> {
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
    let mut candidates = all_legal_moves_for(session.world(), player);
    if candidates.is_empty() {
        return None;
    }

    // Ordenamiento heurístico: capturas primero
    candidates.sort_by_key(|cmd| {
        if board.squares.contains_key(&cmd.to) {
            0
        } else {
            1
        }
    });

    let depth = difficulty.max_depth().clamp(1, 2);
    let mut best_move = None;
    let mut best_score = f32::NEG_INFINITY;
    let mut alpha = f32::NEG_INFINITY;
    let beta = f32::INFINITY;

    for mv in candidates {
        let mut next_session = clone_xiangqi_session(session);
        if next_session
            .process_command(player, Box::new(mv.clone()))
            .is_ok()
        {
            let score = minimax(&next_session, depth - 1, alpha, beta, false, player);
            if score > best_score || best_move.is_none() {
                best_score = score;
                best_move = Some(mv);
            }
            if score > alpha {
                alpha = score;
            }
        }
    }

    best_move
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_xiangqi_session;

    const P_RED: PlayerId = PlayerId(1);
    const P_BLACK: PlayerId = PlayerId(2);

    #[test]
    fn test_xiangqi_ai_devuelve_movimiento_en_posicion_inicial() {
        let session = new_xiangqi_session(SessionId(1), 1, P_RED, P_BLACK);
        let mv = xiangqi_ai_pick_move(&session, P_RED);
        assert!(
            mv.is_some(),
            "La IA de Xiangqi debe devolver un movimiento en la posición inicial"
        );

        let mut test_session = clone_xiangqi_session(&session);
        assert!(
            test_session
                .process_command(P_RED, Box::new(mv.unwrap()))
                .is_ok(),
            "El movimiento seleccionado por la IA de Xiangqi debe ser legal"
        );
    }
}
