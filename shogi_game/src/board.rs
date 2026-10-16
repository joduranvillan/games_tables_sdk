use open_table_engine::prelude::*;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum PieceKind {
    King,
    Rook,
    Bishop,
    Gold,
    Silver,
    Knight,
    Lance,
    Pawn,
    PromotedRook,
    PromotedBishop,
    PromotedSilver,
    PromotedKnight,
    PromotedLance,
    PromotedPawn,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Piece {
    pub kind: PieceKind,
    pub owner: PlayerId,
}

#[derive(GameResource, Clone, Copy, Default, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShogiRulesConfigResource {
    pub strict_fesa_promotion: bool,
}

impl ShogiRulesConfigResource {
    pub fn new(strict_fesa_promotion: bool) -> Self {
        Self {
            strict_fesa_promotion,
        }
    }

    pub fn fesa() -> Self {
        Self {
            strict_fesa_promotion: true,
        }
    }
}

#[derive(GameResource, Clone, Default, Debug)]
pub struct ShogiHistoryResource {
    pub counts: HashMap<u64, u32>,
}

impl ShogiHistoryResource {
    pub fn new() -> Self {
        Self {
            counts: HashMap::new(),
        }
    }

    pub fn compute_hash(board: &BoardResource, current_player: PlayerId) -> u64 {
        board.compute_state_hash(current_player)
    }

    pub fn record(&mut self, board: &BoardResource, current_player: PlayerId) -> u32 {
        let hash = board.compute_state_hash(current_player);
        let count = self.counts.entry(hash).or_insert(0);
        *count += 1;
        *count
    }

    pub fn count_for(&self, board: &BoardResource, current_player: PlayerId) -> u32 {
        let hash = board.compute_state_hash(current_player);
        self.counts.get(&hash).copied().unwrap_or(0)
    }
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

    pub fn compute_state_hash(&self, current_player: PlayerId) -> u64 {
        let mut hasher = DefaultHasher::new();

        let mut sq_list: Vec<((usize, usize), Piece)> = self
            .squares
            .iter()
            .map(|(&pos, &piece)| (pos, piece))
            .collect();
        sq_list.sort_by_key(|&(pos, _)| pos);
        sq_list.hash(&mut hasher);

        let mut hand_list: Vec<(u32, Vec<PieceKind>)> = self
            .hands
            .iter()
            .map(|(&player, pieces)| {
                let mut sorted_pieces = pieces.clone();
                sorted_pieces.sort();
                (player.0, sorted_pieces)
            })
            .filter(|(_, pieces)| !pieces.is_empty())
            .collect();
        hand_list.sort_by_key(|&(pid, _)| pid);
        hand_list.hash(&mut hasher);

        current_player.0.hash(&mut hasher);

        hasher.finish()
    }

    pub fn standard_setup(sente: PlayerId, gote: PlayerId) -> Self {
        let mut board = Self::new(sente, gote);
        board.hands.insert(sente, vec![]);
        board.hands.insert(gote, vec![]);

        // Very simplified setup just for demonstration
        board.squares.insert(
            (4, 8),
            Piece {
                kind: PieceKind::King,
                owner: sente,
            },
        );
        board.squares.insert(
            (4, 0),
            Piece {
                kind: PieceKind::King,
                owner: gote,
            },
        );

        board.squares.insert(
            (4, 6),
            Piece {
                kind: PieceKind::Pawn,
                owner: sente,
            },
        );
        board.squares.insert(
            (4, 2),
            Piece {
                kind: PieceKind::Pawn,
                owner: gote,
            },
        );

        board
    }
}
