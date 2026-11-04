// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;

use crate::board::{BoardResource, PieceKind};
use crate::commands::{DropPieceCommand, MovePieceCommand};
use crate::movement::{can_promote, is_in_check, is_legal_drop, is_legal_move, must_promote};

#[derive(Clone, Debug)]
pub enum ShogiAction {
    Move(MovePieceCommand),
    Drop(DropPieceCommand),
}

impl ShogiAction {
    pub fn to_command(&self) -> Box<dyn Command> {
        match self {
            ShogiAction::Move(cmd) => Box::new(cmd.clone()),
            ShogiAction::Drop(cmd) => Box::new(cmd.clone()),
        }
    }
}

/// Genera la lista completa de acciones candidatas (movimientos y drops) para `player`.
pub fn generate_shogi_candidates(board: &BoardResource, player: PlayerId) -> Vec<ShogiAction> {
    let mut candidates = Vec::new();

    // 1. Movimientos de piezas en el tablero
    for (&from, piece) in &board.squares {
        if piece.owner == player {
            for tx in 0..9 {
                for ty in 0..9 {
                    let to = (tx, ty);
                    if is_legal_move(board, from, to, player) {
                        let can_pro = can_promote(board, piece.kind, from, to, player);
                        let must_pro = must_promote(board, piece.kind, to, player);
                        if can_pro {
                            candidates.push(ShogiAction::Move(MovePieceCommand {
                                player,
                                from,
                                to,
                                promote: true,
                            }));
                        }
                        if !must_pro {
                            candidates.push(ShogiAction::Move(MovePieceCommand {
                                player,
                                from,
                                to,
                                promote: false,
                            }));
                        }
                    }
                }
            }
        }
    }

    // 2. Drops de mano (todas las piezas en mano a casillas legales)
    if let Some(hand) = board.hands.get(&player) {
        let mut unique_kinds = hand.clone();
        unique_kinds.sort_by_key(|k| *k as u8);
        unique_kinds.dedup();

        for &piece_kind in &unique_kinds {
            for tx in 0..9 {
                for ty in 0..9 {
                    let to = (tx, ty);
                    if is_legal_drop(board, piece_kind, to, player) {
                        candidates.push(ShogiAction::Drop(DropPieceCommand {
                            player,
                            piece: piece_kind,
                            to,
                        }));
                    }
                }
            }
        }
    }

    candidates
}

/// Valor material de las piezas de Shogi:
/// Peón=1, Caballo=3, Alfil/Torre=5, General/Oro/Plata=4, Lanza=2, Rey=1000.
/// Bonus +1 por pieza promovida.
pub fn piece_value(kind: PieceKind) -> f32 {
    match kind {
        PieceKind::Pawn => 1.0,
        PieceKind::PromotedPawn => 2.0, // 1 + 1
        PieceKind::Lance => 2.0,
        PieceKind::PromotedLance => 3.0, // 2 + 1
        PieceKind::Knight => 3.0,
        PieceKind::PromotedKnight => 4.0, // 3 + 1
        PieceKind::Silver => 4.0,
        PieceKind::PromotedSilver => 5.0, // 4 + 1
        PieceKind::Gold => 4.0,
        PieceKind::Bishop => 5.0,
        PieceKind::PromotedBishop => 6.0, // 5 + 1
        PieceKind::Rook => 5.0,
        PieceKind::PromotedRook => 6.0, // 5 + 1
        PieceKind::King => 1000.0,
    }
}

/// Evaluación estática material para el jugador `player`.
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

    let opponent = if player == board.sente {
        board.gote
    } else {
        board.sente
    };

    let mut score = 0.0f32;

    // Piezas en el tablero
    for piece in board.squares.values() {
        let val = piece_value(piece.kind);
        if piece.owner == player {
            score += val;
        } else if piece.owner == opponent {
            score -= val;
        }
    }

    // Piezas en mano
    if let Some(hand) = board.hands.get(&player) {
        for &k in hand {
            score += piece_value(k);
        }
    }
    if let Some(hand) = board.hands.get(&opponent) {
        for &k in hand {
            score -= piece_value(k);
        }
    }

    score
}

/// Clona una sesión de Shogi replicando su estado de recursos.
pub fn clone_shogi_session(session: &Session) -> Session {
    let (sente, gote) = session
        .world()
        .get_resource::<BoardResource>()
        .map(|b| (b.sente, b.gote))
        .unwrap_or((PlayerId(1), PlayerId(2)));

    let mut new_session = crate::new_shogi_session(session.id, 0, sente, gote);

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
        .get_resource::<crate::board::ShogiHistoryResource>()
    {
        new_session.world_mut().insert_resource(history.clone());
    }
    if let Some(cfg) = session
        .world()
        .get_resource::<crate::board::ShogiRulesConfigResource>()
    {
        new_session.world_mut().insert_resource(*cfg);
    }

    new_session
}

/// Minimax con poda alfa-beta para Shogi.
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
    let board = match session.world().get_resource::<BoardResource>() {
        Some(b) => b,
        None => return 0.0,
    };

    let candidates = generate_shogi_candidates(board, current);
    let mut has_legal = false;

    if maximizing {
        let mut max_eval = f32::NEG_INFINITY;
        for action in candidates {
            let mut next_session = clone_shogi_session(session);
            if next_session
                .process_command(current, action.to_command())
                .is_ok()
            {
                has_legal = true;
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
        if !has_legal {
            let in_chk = is_in_check(board, current);
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
        max_eval
    } else {
        let mut min_eval = f32::INFINITY;
        for action in candidates {
            let mut next_session = clone_shogi_session(session);
            if next_session
                .process_command(current, action.to_command())
                .is_ok()
            {
                has_legal = true;
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
        if !has_legal {
            let in_chk = is_in_check(board, current);
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
        min_eval
    }
}

/// Selecciona la mejor jugada legal para `player` en `session` usando Minimax a depth=2.
pub fn shogi_ai_pick_move(session: &Session, player: PlayerId) -> Option<Box<dyn Command>> {
    best_move(session, player, AiDifficulty::Medium)
}

/// Selecciona la mejor jugada legal para `player` en `session` usando `difficulty.max_depth()`.
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<Box<dyn Command>> {
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
    let mut candidates = generate_shogi_candidates(board, player);
    if candidates.is_empty() {
        return None;
    }

    // Ordenamiento heurístico: capturas y promociones primero
    candidates.sort_by_key(|action| match action {
        ShogiAction::Move(cmd) => {
            let is_capture = board.squares.contains_key(&cmd.to);
            if is_capture || cmd.promote {
                0
            } else {
                1
            }
        }
        ShogiAction::Drop(_) => 2,
    });

    let depth = difficulty.max_depth().clamp(1, 2);
    let mut best_action = None;
    let mut best_score = f32::NEG_INFINITY;
    let mut alpha = f32::NEG_INFINITY;
    let beta = f32::INFINITY;

    for action in candidates {
        let mut next_session = clone_shogi_session(session);
        if next_session
            .process_command(player, action.to_command())
            .is_ok()
        {
            let score = minimax(&next_session, depth - 1, alpha, beta, false, player);
            if score > best_score || best_action.is_none() {
                best_score = score;
                best_action = Some(action);
            }
            if score > alpha {
                alpha = score;
            }
        }
    }

    best_action.map(|a| a.to_command())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_shogi_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn test_shogi_ai_devuelve_movimiento_en_posicion_inicial() {
        let session = new_shogi_session(SessionId(1), 1, P1, P2);
        let mv = shogi_ai_pick_move(&session, P1);
        assert!(
            mv.is_some(),
            "La IA de Shogi debe devolver un movimiento en la posición inicial"
        );

        let mut test_session = clone_shogi_session(&session);
        assert!(
            test_session.process_command(P1, mv.unwrap()).is_ok(),
            "El movimiento seleccionado por la IA de Shogi debe ser legal"
        );
    }
}
