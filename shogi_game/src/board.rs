use open_table_engine::prelude::*;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PieceKind {
    King, Rook, Bishop, Gold, Silver, Knight, Lance, Pawn,
    PromotedRook, PromotedBishop, PromotedSilver, PromotedKnight, PromotedLance, PromotedPawn
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Piece {
    pub kind: PieceKind,
    pub owner: PlayerId,
}

#[derive(GameResource, Clone)]
pub struct BoardResource {
    pub squares: HashMap<(usize, usize), Piece>,
    pub hands: HashMap<PlayerId, Vec<PieceKind>>,
    pub sente: PlayerId,
    pub gote: PlayerId,
}

impl BoardResource {
    pub fn new(sente: PlayerId, gote: PlayerId) -> Self {
        Self {
            squares: HashMap::new(),
            hands: HashMap::new(),
            sente,
            gote,
        }
    }

    pub fn standard_setup(sente: PlayerId, gote: PlayerId) -> Self {
        let mut board = Self::new(sente, gote);
        board.hands.insert(sente, vec![]);
        board.hands.insert(gote, vec![]);
        
        // Very simplified setup just for demonstration
        board.squares.insert((4, 8), Piece { kind: PieceKind::King, owner: sente });
        board.squares.insert((4, 0), Piece { kind: PieceKind::King, owner: gote });
        
        board.squares.insert((4, 6), Piece { kind: PieceKind::Pawn, owner: sente });
        board.squares.insert((4, 2), Piece { kind: PieceKind::Pawn, owner: gote });

        board
    }
}
