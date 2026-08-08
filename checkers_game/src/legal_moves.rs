use bevy_ecs::world::World as BevyWorld;
use open_table_core::prelude::*;
use open_table_engine::prelude::*;

use crate::board::BoardResource;
use crate::commands::MovePieceCommand;
use crate::position::Position;

pub struct CheckersLegalMoveGenerator;

impl LegalMoveGenerator for CheckersLegalMoveGenerator {
    fn generate(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        let Some(board) = world.get_resource::<BoardResource>() else {
            return vec![];
        };

        let mut candidates: Vec<Box<dyn Command>> = Vec::new();

        for r in 0..8u8 {
            for c in 0..8u8 {
                let from = Position::new(r, c);
                if let Some(piece) = board.get(from) {
                    if piece.owner != player {
                        continue;
                    }

                    let offsets: &[(i8, i8)] = &[
                        (-1, -1), (-1, 1), (1, -1), (1, 1),
                        (-2, -2), (-2, 2), (2, -2), (2, 2),
                    ];

                    for &(dr, dc) in offsets {
                        let nr = r as i8 + dr;
                        let nc = c as i8 + dc;
                        if (0..8).contains(&nr) && (0..8).contains(&nc) {
                            let to = Position::new(nr as u8, nc as u8);
                            if to.is_dark_square() {
                                candidates.push(Box::new(MovePieceCommand { player, from, to }));
                            }
                        }
                    }
                }
            }
        }

        candidates
    }
}
