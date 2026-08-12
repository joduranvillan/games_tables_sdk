use open_table_engine::prelude::*;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PieceKind {
    General,
    Advisor,
    Elephant,
    Horse,
    Chariot,
    Cannon,
    Soldier,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Piece {
    pub kind: PieceKind,
    pub owner: PlayerId,
}

#[derive(GameResource, Clone)]
pub struct BoardResource {
    pub squares: HashMap<(usize, usize), Piece>,
    pub red: PlayerId,
    pub black: PlayerId,
}

impl BoardResource {
    pub fn new(red: PlayerId, black: PlayerId) -> Self {
        Self {
            squares: HashMap::new(),
            red,
            black,
        }
    }

    pub fn standard_setup(red: PlayerId, black: PlayerId) -> Self {
        let mut board = Self::new(red, black);

        // Simplified setup just for testing
        board.squares.insert(
            (4, 9),
            Piece {
                kind: PieceKind::General,
                owner: red,
            },
        );
        board.squares.insert(
            (4, 0),
            Piece {
                kind: PieceKind::General,
                owner: black,
            },
        );

        board.squares.insert(
            (4, 6),
            Piece {
                kind: PieceKind::Soldier,
                owner: red,
            },
        );
        board.squares.insert(
            (4, 3),
            Piece {
                kind: PieceKind::Soldier,
                owner: black,
            },
        );

        board
    }
}
