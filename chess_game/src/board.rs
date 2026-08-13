use std::collections::HashMap;

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

use crate::position::{Piece, PieceKind, Position};

#[derive(GameResource, Default, Clone, Debug, PartialEq, Eq)]
pub struct DrawOfferedResource(pub Option<PlayerId>);

#[derive(GameResource, Default, Clone, Debug, PartialEq, Eq)]
pub struct HalfMoveClockResource(pub u32);

#[derive(GameResource, Default, Clone, Debug)]
pub struct PositionHistoryResource {
    pub history: HashMap<u64, usize>,
}

#[derive(GameResource, Clone, Default)]
pub struct BoardResource {
    pub pieces: HashMap<Position, Piece>,
    pub en_passant_target: Option<Position>,
    pub white_king_moved: bool,
    pub white_rook_a_moved: bool,
    pub white_rook_h_moved: bool,
    pub black_king_moved: bool,
    pub black_rook_a_moved: bool,
    pub black_rook_h_moved: bool,
}

impl BoardResource {
    pub fn get(&self, pos: Position) -> Option<Piece> {
        self.pieces.get(&pos).copied()
    }

    pub fn standard_setup(white: PlayerId, black: PlayerId) -> Self {
        let mut pieces = HashMap::new();
        let back_rank = [
            PieceKind::Rook,
            PieceKind::Knight,
            PieceKind::Bishop,
            PieceKind::Queen,
            PieceKind::King,
            PieceKind::Bishop,
            PieceKind::Knight,
            PieceKind::Rook,
        ];
        for (col, kind) in back_rank.iter().enumerate() {
            pieces.insert(
                Position::new(0, col as u8),
                Piece {
                    owner: white,
                    kind: *kind,
                },
            );
            pieces.insert(
                Position::new(7, col as u8),
                Piece {
                    owner: black,
                    kind: *kind,
                },
            );
        }
        for col in 0..8u8 {
            pieces.insert(
                Position::new(1, col),
                Piece {
                    owner: white,
                    kind: PieceKind::Pawn,
                },
            );
            pieces.insert(
                Position::new(6, col),
                Piece {
                    owner: black,
                    kind: PieceKind::Pawn,
                },
            );
        }
        Self {
            pieces,
            en_passant_target: None,
            white_king_moved: false,
            white_rook_a_moved: false,
            white_rook_h_moved: false,
            black_king_moved: false,
            black_rook_a_moved: false,
            black_rook_h_moved: false,
        }
    }

    pub fn find_king(&self, player: PlayerId) -> Option<Position> {
        self.pieces
            .iter()
            .find(|(_, piece)| piece.owner == player && piece.kind == PieceKind::King)
            .map(|(pos, _)| *pos)
    }

    pub fn compute_hash(&self, current_player: PlayerId) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();

        let mut piece_vec: Vec<_> = self.pieces.iter().collect();
        piece_vec.sort_by_key(|(pos, _)| (pos.row, pos.col));
        for (pos, piece) in piece_vec {
            pos.row.hash(&mut hasher);
            pos.col.hash(&mut hasher);
            piece.owner.hash(&mut hasher);
            (piece.kind as u8).hash(&mut hasher);
        }

        current_player.hash(&mut hasher);

        self.en_passant_target
            .map(|p| (p.row, p.col))
            .hash(&mut hasher);

        self.white_king_moved.hash(&mut hasher);
        self.white_rook_a_moved.hash(&mut hasher);
        self.white_rook_h_moved.hash(&mut hasher);
        self.black_king_moved.hash(&mut hasher);
        self.black_rook_a_moved.hash(&mut hasher);
        self.black_rook_h_moved.hash(&mut hasher);

        hasher.finish()
    }
}

#[derive(GameResource, Clone, Copy, Debug, PartialEq, Eq)]
pub struct Sides {
    pub white: PlayerId,
    pub black: PlayerId,
}

impl Sides {
    pub fn forward_direction(&self, player: PlayerId) -> i32 {
        if player == self.white {
            1
        } else {
            -1
        }
    }

    pub fn pawn_start_row(&self, player: PlayerId) -> u8 {
        if player == self.white {
            1
        } else {
            6
        }
    }

    pub fn promotion_row(&self, player: PlayerId) -> u8 {
        if player == self.white {
            7
        } else {
            0
        }
    }

    pub fn opponent_of(&self, player: PlayerId) -> PlayerId {
        if player == self.white {
            self.black
        } else {
            self.white
        }
    }
}

fn in_bounds(row: i32, col: i32) -> bool {
    (0..8).contains(&row) && (0..8).contains(&col)
}

fn sliding_moves(
    board: &BoardResource,
    from: Position,
    piece: Piece,
    directions: &[(i32, i32)],
) -> Vec<Position> {
    let mut moves = Vec::new();
    for &(dr, dc) in directions {
        let mut row = from.row as i32 + dr;
        let mut col = from.col as i32 + dc;
        while in_bounds(row, col) {
            let pos = Position::new(row as u8, col as u8);
            match board.get(pos) {
                None => moves.push(pos),
                Some(other) => {
                    if other.owner != piece.owner {
                        moves.push(pos);
                    }
                    break;
                }
            }
            row += dr;
            col += dc;
        }
    }
    moves
}

fn stepping_moves(
    board: &BoardResource,
    from: Position,
    piece: Piece,
    deltas: &[(i32, i32)],
) -> Vec<Position> {
    deltas
        .iter()
        .filter_map(|&(dr, dc)| {
            let row = from.row as i32 + dr;
            let col = from.col as i32 + dc;
            if !in_bounds(row, col) {
                return None;
            }
            let pos = Position::new(row as u8, col as u8);
            match board.get(pos) {
                None => Some(pos),
                Some(other) if other.owner != piece.owner => Some(pos),
                _ => None,
            }
        })
        .collect()
}

const ROOK_DIRS: [(i32, i32); 4] = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const BISHOP_DIRS: [(i32, i32); 4] = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
const QUEEN_DIRS: [(i32, i32); 8] = [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, 1),
    (1, -1),
    (-1, 1),
    (-1, -1),
];
const KNIGHT_DELTAS: [(i32, i32); 8] = [
    (1, 2),
    (2, 1),
    (-1, 2),
    (-2, 1),
    (1, -2),
    (2, -1),
    (-1, -2),
    (-2, -1),
];
const KING_DELTAS: [(i32, i32); 8] = [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, 1),
    (1, -1),
    (-1, 1),
    (-1, -1),
];

/// Movimientos pseudo-legales de una pieza: respetan el tablero y no
/// pisan piezas propias, pero NO validan si dejan al propio rey en
/// jaque — eso se chequea aparte (`is_legal_move`), simulando la jugada.
pub fn piece_moves(
    board: &BoardResource,
    sides: &Sides,
    from: Position,
    piece: Piece,
) -> Vec<Position> {
    match piece.kind {
        PieceKind::Rook => sliding_moves(board, from, piece, &ROOK_DIRS),
        PieceKind::Bishop => sliding_moves(board, from, piece, &BISHOP_DIRS),
        PieceKind::Queen => sliding_moves(board, from, piece, &QUEEN_DIRS),
        PieceKind::Knight => stepping_moves(board, from, piece, &KNIGHT_DELTAS),
        PieceKind::King => {
            let mut moves = stepping_moves(board, from, piece, &KING_DELTAS);

            // Enroque blanco
            if piece.owner == sides.white && from == Position::new(0, 4) {
                if !board.white_king_moved
                    && !board.white_rook_h_moved
                    && matches!(board.get(Position::new(0, 7)), Some(r) if r.owner == sides.white && r.kind == PieceKind::Rook)
                    && board.get(Position::new(0, 5)).is_none()
                    && board.get(Position::new(0, 6)).is_none()
                {
                    moves.push(Position::new(0, 6));
                }
                if !board.white_king_moved
                    && !board.white_rook_a_moved
                    && matches!(board.get(Position::new(0, 0)), Some(r) if r.owner == sides.white && r.kind == PieceKind::Rook)
                    && board.get(Position::new(0, 1)).is_none()
                    && board.get(Position::new(0, 2)).is_none()
                    && board.get(Position::new(0, 3)).is_none()
                {
                    moves.push(Position::new(0, 2));
                }
            }

            // Enroque negro
            if piece.owner == sides.black && from == Position::new(7, 4) {
                if !board.black_king_moved
                    && !board.black_rook_h_moved
                    && matches!(board.get(Position::new(7, 7)), Some(r) if r.owner == sides.black && r.kind == PieceKind::Rook)
                    && board.get(Position::new(7, 5)).is_none()
                    && board.get(Position::new(7, 6)).is_none()
                {
                    moves.push(Position::new(7, 6));
                }
                if !board.black_king_moved
                    && !board.black_rook_a_moved
                    && matches!(board.get(Position::new(7, 0)), Some(r) if r.owner == sides.black && r.kind == PieceKind::Rook)
                    && board.get(Position::new(7, 1)).is_none()
                    && board.get(Position::new(7, 2)).is_none()
                    && board.get(Position::new(7, 3)).is_none()
                {
                    moves.push(Position::new(7, 2));
                }
            }

            moves
        }
        PieceKind::Pawn => {
            let forward = sides.forward_direction(piece.owner);
            let mut moves = Vec::new();

            let one_row = from.row as i32 + forward;
            if in_bounds(one_row, from.col as i32) {
                let one_pos = Position::new(one_row as u8, from.col);
                if board.get(one_pos).is_none() {
                    moves.push(one_pos);
                    if from.row == sides.pawn_start_row(piece.owner) {
                        let two_row = from.row as i32 + 2 * forward;
                        let two_pos = Position::new(two_row as u8, from.col);
                        if board.get(two_pos).is_none() {
                            moves.push(two_pos);
                        }
                    }
                }
            }
            for dc in [-1, 1] {
                let row = from.row as i32 + forward;
                let col = from.col as i32 + dc;
                if in_bounds(row, col) {
                    let pos = Position::new(row as u8, col as u8);
                    if let Some(other) = board.get(pos) {
                        if other.owner != piece.owner {
                            moves.push(pos);
                        }
                    } else if board.en_passant_target == Some(pos) {
                        moves.push(pos);
                    }
                }
            }
            moves
        }
    }
}

/// Casillas que un peón "controla" (para jaque), distinto de a dónde
/// puede MOVERSE: un peón ataca en diagonal aunque esa casilla esté
/// vacía (controla la casilla, aunque no pueda "moverse" ahí sin
/// capturar). El resto de las piezas no tienen esta distinción: su
/// patrón de movimiento y de ataque es el mismo.
fn pawn_attack_squares(sides: &Sides, from: Position, piece: Piece) -> Vec<Position> {
    let forward = sides.forward_direction(piece.owner);
    let mut squares = Vec::new();
    for dc in [-1, 1] {
        let row = from.row as i32 + forward;
        let col = from.col as i32 + dc;
        if in_bounds(row, col) {
            squares.push(Position::new(row as u8, col as u8));
        }
    }
    squares
}

pub fn is_square_attacked(
    board: &BoardResource,
    sides: &Sides,
    target: Position,
    by_player: PlayerId,
) -> bool {
    for (&pos, &piece) in board.pieces.iter() {
        if piece.owner != by_player {
            continue;
        }
        let attacks = if piece.kind == PieceKind::Pawn {
            pawn_attack_squares(sides, pos, piece)
        } else {
            piece_moves(board, sides, pos, piece)
        };
        if attacks.contains(&target) {
            return true;
        }
    }
    false
}

pub fn is_in_check(board: &BoardResource, sides: &Sides, player: PlayerId) -> bool {
    match board.find_king(player) {
        Some(king_pos) => is_square_attacked(board, sides, king_pos, sides.opponent_of(player)),
        None => false,
    }
}

/// Simula `from -> to` en una COPIA del tablero (nunca muta el real) y
/// dice si esa jugada deja al propio rey en jaque — la regla que separa
/// "movimiento pseudo-legal" de "movimiento legal de verdad".
pub fn is_legal_move(
    board: &BoardResource,
    sides: &Sides,
    player: PlayerId,
    from: Position,
    to: Position,
) -> bool {
    let Some(piece) = board.get(from) else {
        return false;
    };
    if piece.owner != player {
        return false;
    }
    if !piece_moves(board, sides, from, piece).contains(&to) {
        return false;
    }

    let opponent = sides.opponent_of(player);

    // Validación especial de enroque: el rey no puede estar en jaque ni pasar por casillas atacadas.
    if piece.kind == PieceKind::King && (from.col as i32 - to.col as i32).abs() == 2 {
        if is_in_check(board, sides, player) {
            return false;
        }
        if (to.col == 6
            && (is_square_attacked(board, sides, Position::new(from.row, 5), opponent)
                || is_square_attacked(board, sides, Position::new(from.row, 6), opponent)))
            || (to.col == 2
                && (is_square_attacked(board, sides, Position::new(from.row, 3), opponent)
                    || is_square_attacked(board, sides, Position::new(from.row, 2), opponent)))
        {
            return false;
        }
    }

    let mut simulated = board.clone();

    if piece.kind == PieceKind::Pawn
        && board.en_passant_target == Some(to)
        && from.col != to.col
        && board.get(to).is_none()
    {
        simulated.pieces.remove(&from);
        simulated.pieces.insert(to, piece);
        simulated.pieces.remove(&Position::new(from.row, to.col));
    } else if piece.kind == PieceKind::King && (from.col as i32 - to.col as i32).abs() == 2 {
        simulated.pieces.remove(&from);
        simulated.pieces.insert(to, piece);
        if to.col == 6 {
            if let Some(rook) = simulated.pieces.remove(&Position::new(from.row, 7)) {
                simulated.pieces.insert(Position::new(from.row, 5), rook);
            }
        } else if to.col == 2 {
            if let Some(rook) = simulated.pieces.remove(&Position::new(from.row, 0)) {
                simulated.pieces.insert(Position::new(from.row, 3), rook);
            }
        }
    } else {
        simulated.pieces.remove(&from);
        simulated.pieces.insert(to, piece);
    }

    !is_in_check(&simulated, sides, player)
}

pub fn has_any_legal_move(board: &BoardResource, sides: &Sides, player: PlayerId) -> bool {
    let own_pieces: Vec<Position> = board
        .pieces
        .iter()
        .filter(|(_, piece)| piece.owner == player)
        .map(|(pos, _)| *pos)
        .collect();

    for from in own_pieces {
        let piece = board.get(from).unwrap();
        for to in piece_moves(board, sides, from, piece) {
            if is_legal_move(board, sides, player, from, to) {
                return true;
            }
        }
    }
    false
}
