use open_table_engine::prelude::*;
use crate::board::{BoardResource, PieceKind};

pub fn is_legal_move(board: &BoardResource, from: (usize, usize), to: (usize, usize), player: PlayerId) -> bool {
    let piece = match board.squares.get(&from) {
        Some(p) if p.owner == player => p,
        _ => return false,
    };
    
    if board.squares.get(&to).is_some_and(|p| p.owner == player) {
        return false;
    }

    let (fx, fy) = from;
    let (tx, ty) = to;
    let dx = (tx as isize - fx as isize).abs();
    let dy = (ty as isize - fy as isize).abs();
    
    if tx > 8 || ty > 9 { return false; }

    let is_red = player == board.red;

    match piece.kind {
        PieceKind::General => {
            if dx + dy != 1 { return false; }
            if !(3..=5).contains(&tx) { return false; }
            if is_red {
                if ty < 7 { return false; }
            } else {
                if ty > 2 { return false; }
            }
            true
        },
        PieceKind::Advisor => {
            if dx != 1 || dy != 1 { return false; }
            if !(3..=5).contains(&tx) { return false; }
            if is_red {
                if ty < 7 { return false; }
            } else {
                if ty > 2 { return false; }
            }
            true
        },
        PieceKind::Elephant => {
            if dx != 2 || dy != 2 { return false; }
            if is_red {
                if ty < 5 { return false; }
            } else {
                if ty > 4 { return false; }
            }
            let eye_x = (fx + tx) / 2;
            let eye_y = (fy + ty) / 2;
            if board.squares.contains_key(&(eye_x, eye_y)) { return false; }
            true
        },
        PieceKind::Horse => {
            if (dx == 1 && dy == 2) || (dx == 2 && dy == 1) {
                let block_x = if dx == 2 { (fx + tx) / 2 } else { fx };
                let block_y = if dy == 2 { (fy + ty) / 2 } else { fy };
                if board.squares.contains_key(&(block_x, block_y)) { return false; }
                true
            } else {
                false
            }
        },
        PieceKind::Chariot => {
            if dx != 0 && dy != 0 { return false; }
            let mut count = 0;
            if dx != 0 {
                let min = fx.min(tx);
                let max = fx.max(tx);
                for x in min + 1..max {
                    if board.squares.contains_key(&(x, fy)) { count += 1; }
                }
            } else {
                let min = fy.min(ty);
                let max = fy.max(ty);
                for y in min + 1..max {
                    if board.squares.contains_key(&(fx, y)) { count += 1; }
                }
            }
            count == 0
        },
        PieceKind::Cannon => {
            if dx != 0 && dy != 0 { return false; }
            let mut count = 0;
            if dx != 0 {
                let min = fx.min(tx);
                let max = fx.max(tx);
                for x in min + 1..max {
                    if board.squares.contains_key(&(x, fy)) { count += 1; }
                }
            } else {
                let min = fy.min(ty);
                let max = fy.max(ty);
                for y in min + 1..max {
                    if board.squares.contains_key(&(fx, y)) { count += 1; }
                }
            }
            let target_has_piece = board.squares.contains_key(&to);
            if target_has_piece {
                count == 1
            } else {
                count == 0
            }
        },
        PieceKind::Soldier => {
            let forward_dy = if is_red { -1 } else { 1 };
            let real_dy = ty as isize - fy as isize;
            
            let past_river = if is_red { fy <= 4 } else { fy >= 5 };
            
            if real_dy == forward_dy && dx == 0 {
                return true;
            }
            if past_river && real_dy == 0 && dx == 1 {
                return true;
            }
            false
        }
    }
}

pub fn check_flying_general(board: &BoardResource) -> bool {
    let mut red_gen = None;
    let mut black_gen = None;
    for (&(x, y), piece) in &board.squares {
        if piece.kind == PieceKind::General {
            if piece.owner == board.red {
                red_gen = Some((x, y));
            } else {
                black_gen = Some((x, y));
            }
        }
    }
    
    if let (Some((rx, ry)), Some((bx, by))) = (red_gen, black_gen) {
        if rx == bx {
            let min_y = ry.min(by);
            let max_y = ry.max(by);
            let mut pieces_between = 0;
            for y in min_y + 1..max_y {
                if board.squares.contains_key(&(rx, y)) {
                    pieces_between += 1;
                }
            }
            if pieces_between == 0 {
                return true;
            }
        }
    }
    false
}

pub fn is_in_check(board: &BoardResource, player: PlayerId) -> bool {
    let mut general_pos = None;
    for (&pos, piece) in &board.squares {
        if piece.kind == PieceKind::General && piece.owner == player {
            general_pos = Some(pos);
            break;
        }
    }

    let g_pos = match general_pos {
        Some(pos) => pos,
        None => return false,
    };

    let opponent = if player == board.red { board.black } else { board.red };

    for (&from, piece) in &board.squares {
        if piece.owner == opponent && is_legal_move(board, from, g_pos, opponent) {
            return true;
        }
    }

    false
}

