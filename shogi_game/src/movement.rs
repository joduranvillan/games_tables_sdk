// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use crate::board::{BoardResource, Piece, PieceKind};
use open_table_engine::prelude::*;

pub fn is_legal_move(
    board: &BoardResource,
    from: (usize, usize),
    to: (usize, usize),
    player: PlayerId,
) -> bool {
    let piece = match board.squares.get(&from) {
        Some(p) if p.owner == player => p,
        _ => return false,
    };

    if board.squares.get(&to).map(|p| p.owner) == Some(player) {
        return false;
    }

    let (fx, fy) = from;
    let (tx, ty) = to;
    let dx = (tx as isize - fx as isize).abs();
    let dy = ty as isize - fy as isize; // Directional!

    if tx > 8 || ty > 8 {
        return false;
    }

    let is_sente = player == board.sente;
    let forward = if is_sente { -1 } else { 1 };

    // Check if path is clear for sliding pieces
    let check_slide = |dx: isize, dy: isize| -> bool {
        let step_x = dx.signum();
        let step_y = dy.signum();
        let mut cx = fx as isize + step_x;
        let mut cy = fy as isize + step_y;
        while (cx, cy) != (tx as isize, ty as isize) {
            if board.squares.contains_key(&(cx as usize, cy as usize)) {
                return false;
            }
            cx += step_x;
            cy += step_y;
        }
        true
    };

    let ady = dy.abs();

    match piece.kind {
        PieceKind::King => dx <= 1 && ady <= 1,
        PieceKind::Rook => (dx == 0 || ady == 0) && check_slide(tx as isize - fx as isize, dy),
        PieceKind::Bishop => dx == ady && check_slide(tx as isize - fx as isize, dy),
        PieceKind::Gold
        | PieceKind::PromotedSilver
        | PieceKind::PromotedKnight
        | PieceKind::PromotedLance
        | PieceKind::PromotedPawn => dx <= 1 && ady <= 1 && !(dx == 1 && dy == -forward),
        PieceKind::Silver => {
            dx <= 1 && ady <= 1 && !((dx == 0 && dy == -forward) || (dx == 1 && dy == 0))
        }
        PieceKind::Knight => dx == 1 && dy == forward * 2,
        PieceKind::Lance => dx == 0 && dy.signum() == forward && check_slide(0, dy),
        PieceKind::Pawn => dx == 0 && dy == forward,
        PieceKind::PromotedRook => {
            if dx <= 1 && ady <= 1 {
                true
            } else {
                (dx == 0 || ady == 0) && check_slide(tx as isize - fx as isize, dy)
            }
        }
        PieceKind::PromotedBishop => {
            if dx <= 1 && ady <= 1 {
                true
            } else {
                dx == ady && check_slide(tx as isize - fx as isize, dy)
            }
        }
    }
}

pub fn is_legal_drop(
    board: &BoardResource,
    piece_kind: PieceKind,
    to: (usize, usize),
    player: PlayerId,
) -> bool {
    if board.squares.contains_key(&to) {
        return false;
    }
    if to.0 > 8 || to.1 > 8 {
        return false;
    }

    let is_sente = player == board.sente;

    // Nifu (Two pawns)
    if piece_kind == PieceKind::Pawn {
        for y in 0..=8 {
            if let Some(p) = board.squares.get(&(to.0, y)) {
                if p.kind == PieceKind::Pawn && p.owner == player {
                    return false;
                }
            }
        }
    }

    // Dropping where piece has no legal moves
    let rank = to.1;
    if is_sente {
        if rank == 0
            && (piece_kind == PieceKind::Pawn
                || piece_kind == PieceKind::Lance
                || piece_kind == PieceKind::Knight)
        {
            return false;
        }
        !(rank == 1 && piece_kind == PieceKind::Knight)
    } else {
        if rank == 8
            && (piece_kind == PieceKind::Pawn
                || piece_kind == PieceKind::Lance
                || piece_kind == PieceKind::Knight)
        {
            return false;
        }
        !(rank == 7 && piece_kind == PieceKind::Knight)
    }
}

pub fn can_promote(
    board: &BoardResource,
    piece_kind: PieceKind,
    from: (usize, usize),
    to: (usize, usize),
    player: PlayerId,
) -> bool {
    let is_sente = player == board.sente;
    let promo_zone = if is_sente {
        from.1 <= 2 || to.1 <= 2
    } else {
        from.1 >= 6 || to.1 >= 6
    };

    if !promo_zone {
        return false;
    }

    matches!(
        piece_kind,
        PieceKind::Rook
            | PieceKind::Bishop
            | PieceKind::Silver
            | PieceKind::Knight
            | PieceKind::Lance
            | PieceKind::Pawn
    )
}

pub fn must_promote(
    board: &BoardResource,
    piece_kind: PieceKind,
    to: (usize, usize),
    player: PlayerId,
) -> bool {
    let is_sente = player == board.sente;
    let rank = to.1;

    let in_promo_zone = if is_sente { rank <= 2 } else { rank >= 6 };

    in_promo_zone
        && matches!(
            piece_kind,
            PieceKind::Rook
                | PieceKind::Bishop
                | PieceKind::Silver
                | PieceKind::Knight
                | PieceKind::Lance
                | PieceKind::Pawn
        )
}

/// Regla oficial FESA de promoción obligatoria por fila de destino:
/// - `Pawn` y `Lance`: obligados a promocionar únicamente en la última fila (`0` para Sente, `8` para Gote).
/// - `Knight`: obligado a promocionar en las dos últimas filas (`0..=1` para Sente, `7..=8` para Gote).
/// - `Silver`, `Rook`, `Bishop` (y el resto): promoción siempre opcional dentro de la zona de promoción.
pub fn must_promote_fesa(
    board: &BoardResource,
    piece_kind: PieceKind,
    to: (usize, usize),
    player: PlayerId,
) -> bool {
    let is_sente = player == board.sente;
    let rank = to.1;

    if is_sente {
        match piece_kind {
            PieceKind::Pawn | PieceKind::Lance => rank == 0,
            PieceKind::Knight => rank <= 1,
            _ => false,
        }
    } else {
        match piece_kind {
            PieceKind::Pawn | PieceKind::Lance => rank == 8,
            PieceKind::Knight => rank >= 7,
            _ => false,
        }
    }
}

pub fn find_king(board: &BoardResource, player: PlayerId) -> Option<(usize, usize)> {
    board.squares.iter().find_map(|(&pos, piece)| {
        if piece.kind == PieceKind::King && piece.owner == player {
            Some(pos)
        } else {
            None
        }
    })
}

pub fn is_in_check(board: &BoardResource, player: PlayerId) -> bool {
    let king_pos = match find_king(board, player) {
        Some(pos) => pos,
        None => return false,
    };

    let opponent = if player == board.sente {
        board.gote
    } else {
        board.sente
    };

    for (&pos, piece) in &board.squares {
        if piece.owner == opponent && is_legal_move(board, pos, king_pos, opponent) {
            return true;
        }
    }

    false
}

pub fn has_any_legal_move(board: &BoardResource, player: PlayerId) -> bool {
    for (&from, piece) in &board.squares {
        if piece.owner == player {
            for tx in 0..9 {
                for ty in 0..9 {
                    let to = (tx, ty);
                    if is_legal_move(board, from, to, player) {
                        let mut test_board = board.clone();
                        let moving_piece = test_board.squares.remove(&from).unwrap();
                        test_board.squares.insert(to, moving_piece);
                        if !is_in_check(&test_board, player) {
                            return true;
                        }
                    }
                }
            }
        }
    }

    if let Some(hand) = board.hands.get(&player) {
        let mut unique_kinds = hand.clone();
        unique_kinds.sort_by_key(|k| *k as u8);
        unique_kinds.dedup();

        for &piece_kind in &unique_kinds {
            for tx in 0..9 {
                for ty in 0..9 {
                    let to = (tx, ty);
                    if is_legal_drop(board, piece_kind, to, player) {
                        let mut test_board = board.clone();
                        test_board.squares.insert(
                            to,
                            Piece {
                                kind: piece_kind,
                                owner: player,
                            },
                        );
                        if !is_in_check(&test_board, player) {
                            return true;
                        }
                    }
                }
            }
        }
    }

    false
}

pub fn is_checkmate(board: &BoardResource, player: PlayerId) -> bool {
    is_in_check(board, player) && !has_any_legal_move(board, player)
}
