use open_table_engine::prelude::*;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum PieceKind {
    General,
    Advisor,
    Elephant,
    Horse,
    Chariot,
    Cannon,
    Soldier,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
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

    pub fn compute_state_hash(&self, current_player: PlayerId) -> u64 {
        let mut hasher = DefaultHasher::new();
        for x in 0..9 {
            for y in 0..10 {
                self.squares.get(&(x, y)).hash(&mut hasher);
            }
        }
        current_player.hash(&mut hasher);
        hasher.finish()
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

#[derive(GameResource, Clone, Debug, Default)]
pub struct XiangqiHistoryResource {
    pub counts: HashMap<u64, u32>,
}

impl XiangqiHistoryResource {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn record_hash(&mut self, hash: u64) -> u32 {
        let count = self.counts.entry(hash).or_insert(0);
        *count += 1;
        *count
    }

    pub fn record_state(&mut self, board: &BoardResource, current_player: PlayerId) -> u32 {
        let hash = board.compute_state_hash(current_player);
        self.record_hash(hash)
    }
}
