use bevy_ecs::world::World as BevyWorld;
use open_table_core::prelude::*;
use open_table_engine::prelude::*;

use crate::board::{is_legal_move, piece_moves, BoardResource, Sides};
use crate::commands::MovePieceCommand;
use crate::position::{PieceKind, Position};

pub struct ChessLegalMoveGenerator;

impl ChessLegalMoveGenerator {
    pub fn generate_moves(world: &BevyWorld, player: PlayerId) -> Vec<MovePieceCommand> {
        let Some(board) = world.get_resource::<BoardResource>() else {
            return vec![];
        };
        let Some(sides) = world.get_resource::<Sides>() else {
            return vec![];
        };

        let mut candidates: Vec<MovePieceCommand> = Vec::new();

        let own_pieces: Vec<(Position, crate::position::Piece)> = board
            .pieces
            .iter()
            .filter(|(_, piece)| piece.owner == player)
            .map(|(&pos, &piece)| (pos, piece))
            .collect();

        for (from, piece) in own_pieces {
            let moves = piece_moves(board, sides, from, piece);
            for to in moves {
                if is_legal_move(board, sides, player, from, to) {
                    if piece.kind == PieceKind::Pawn && to.row == sides.promotion_row(player) {
                        for kind in [
                            PieceKind::Queen,
                            PieceKind::Rook,
                            PieceKind::Bishop,
                            PieceKind::Knight,
                        ] {
                            candidates.push(MovePieceCommand {
                                player,
                                from,
                                to,
                                promote_to: Some(kind),
                            });
                        }
                    } else {
                        candidates.push(MovePieceCommand {
                            player,
                            from,
                            to,
                            promote_to: None,
                        });
                    }
                }
            }
        }

        candidates
    }
}

impl LegalMoveGenerator for ChessLegalMoveGenerator {
    fn generate(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        Self::generate_moves(world, player)
            .into_iter()
            .map(|cmd| Box::new(cmd) as Box<dyn Command>)
            .collect()
    }
}
