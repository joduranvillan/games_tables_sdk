// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use bevy_ecs::world::World as BevyWorld;
use open_table_core::prelude::*;
use open_table_engine::prelude::*;

use crate::board::{BoardResource, MultiCaptureResource, Sides};
use crate::commands::MovePieceCommand;
use crate::position::Position;

pub struct CheckersLegalMoveGenerator;

impl CheckersLegalMoveGenerator {
    pub fn generate_moves(world: &BevyWorld, player: PlayerId) -> Vec<MovePieceCommand> {
        let Some(board) = world.get_resource::<BoardResource>() else {
            return vec![];
        };
        let Some(sides) = world.get_resource::<Sides>() else {
            return vec![];
        };

        let mut candidates: Vec<MovePieceCommand> = Vec::new();
        let captures = board.get_all_available_captures(sides, player);
        let mandatory_captures = !captures.is_empty();

        let active_jumper = world
            .get_resource::<MultiCaptureResource>()
            .and_then(|m| m.active_piece);

        if mandatory_captures {
            for (from, to) in captures {
                if let Some(req) = active_jumper {
                    if from != req {
                        continue;
                    }
                }
                candidates.push(MovePieceCommand { player, from, to });
            }
        } else {
            if active_jumper.is_some() {
                return vec![];
            }
            let forward = sides.forward_direction(player);
            for r in 0..8u8 {
                for c in 0..8u8 {
                    let from = Position::new(r, c);
                    if let Some(piece) = board.get(from) {
                        if piece.owner != player {
                            continue;
                        }

                        let offsets: &[(i8, i8)] = if piece.is_king {
                            &[(-1, -1), (-1, 1), (1, -1), (1, 1)]
                        } else if forward == 1 {
                            &[(1, -1), (1, 1)]
                        } else {
                            &[(-1, -1), (-1, 1)]
                        };

                        for &(dr, dc) in offsets {
                            let nr = r as i8 + dr;
                            let nc = c as i8 + dc;
                            if (0..8).contains(&nr) && (0..8).contains(&nc) {
                                let to = Position::new(nr as u8, nc as u8);
                                if to.is_dark_square() && board.get(to).is_none() {
                                    candidates.push(MovePieceCommand {
                                        player,
                                        from,
                                        to,
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }

        candidates
    }
}

impl LegalMoveGenerator for CheckersLegalMoveGenerator {
    fn generate(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        Self::generate_moves(world, player)
            .into_iter()
            .map(|cmd| Box::new(cmd) as Box<dyn Command>)
            .collect()
    }
}
