use crate::board::{
    BoardResource, Piece, PieceKind, ShogiHistoryResource, ShogiRulesConfigResource,
};
use crate::commands::{DropPieceCommand, MovePieceCommand, ResignCommand, SetShogiRulesCommand};
use crate::events::{GameOverEvent, PieceDroppedEvent, PieceMovedEvent};
use crate::movement::{
    can_promote, is_checkmate, is_in_check, is_legal_drop, is_legal_move, must_promote,
    must_promote_fesa,
};
use open_table_engine::prelude::*;

pub struct ShogiLegalMoveGenerator;

impl ShogiLegalMoveGenerator {
    pub fn generate_for_board(
        board: &BoardResource,
        player: PlayerId,
        strict_fesa: bool,
    ) -> Vec<Box<dyn Command>> {
        if player != board.sente && player != board.gote {
            return vec![];
        }

        let opponent = if player == board.sente {
            board.gote
        } else {
            board.sente
        };

        let mut moves: Vec<Box<dyn Command>> = Vec::new();

        for fx in 0..9 {
            for fy in 0..9 {
                let from = (fx, fy);
                let Some(piece) = board.squares.get(&from).copied() else {
                    continue;
                };
                if piece.owner != player {
                    continue;
                }

                for tx in 0..9 {
                    for ty in 0..9 {
                        let to = (tx, ty);
                        if !is_legal_move(board, from, to, player) {
                            continue;
                        }

                        let mut test_board = board.clone();
                        test_board.squares.remove(&from);
                        test_board.squares.insert(to, piece);
                        if is_in_check(&test_board, player) {
                            continue;
                        }

                        let can_pro = can_promote(board, piece.kind, from, to, player);
                        let must_pro = if strict_fesa {
                            must_promote_fesa(board, piece.kind, to, player)
                        } else {
                            must_promote(board, piece.kind, to, player)
                        };

                        if can_pro {
                            moves.push(Box::new(MovePieceCommand {
                                player,
                                from,
                                to,
                                promote: true,
                            }));
                        }
                        if !must_pro {
                            moves.push(Box::new(MovePieceCommand {
                                player,
                                from,
                                to,
                                promote: false,
                            }));
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
                        if !is_legal_drop(board, piece_kind, to, player) {
                            continue;
                        }

                        let mut test_board = board.clone();
                        test_board.squares.insert(
                            to,
                            Piece {
                                kind: piece_kind,
                                owner: player,
                            },
                        );
                        if is_in_check(&test_board, player) {
                            continue;
                        }
                        if piece_kind == PieceKind::Pawn && is_checkmate(&test_board, opponent) {
                            continue;
                        }

                        moves.push(Box::new(DropPieceCommand {
                            player,
                            piece: piece_kind,
                            to,
                        }));
                    }
                }
            }
        }

        moves
    }
}

impl LegalMoveGenerator for ShogiLegalMoveGenerator {
    fn generate(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        if world
            .get_resource::<GameOverResource>()
            .is_some_and(|g| g.0)
        {
            return vec![];
        }
        let Some(board) = world.get_resource::<BoardResource>() else {
            return vec![];
        };
        let strict_fesa = world
            .get_resource::<ShogiRulesConfigResource>()
            .map(|c| c.strict_fesa_promotion)
            .unwrap_or(false);

        Self::generate_for_board(board, player, strict_fesa)
    }
}

fn record_state_and_check_sennichite(
    world: &mut BevyWorld,
    pre_hash: u64,
    next_player: PlayerId,
) -> bool {
    let post_hash = world
        .resource::<BoardResource>()
        .compute_state_hash(next_player);

    if !world.contains_resource::<ShogiHistoryResource>() {
        world.insert_resource(ShogiHistoryResource::default());
    }

    let mut history = world.resource_mut::<ShogiHistoryResource>();
    if history.counts.is_empty()
        || (history.counts.len() == 1 && !history.counts.contains_key(&pre_hash))
    {
        history.counts.clear();
        history.counts.insert(pre_hash, 1);
    }

    let count = history.counts.entry(post_hash).or_insert(0);
    *count += 1;
    *count >= 4
}

pub fn build_shogi_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.set_legal_move_generator(Box::new(ShogiLegalMoveGenerator));

    rules.register::<MovePieceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        let strict_fesa = world
            .get_resource::<ShogiRulesConfigResource>()
            .map(|cfg| cfg.strict_fesa_promotion)
            .unwrap_or(false);

        let board_backup = world.resource::<BoardResource>().clone();
        let pre_hash = board_backup.compute_state_hash(cmd.player);

        let (promoted, captured_kind) = {
            let mut board = world.resource_mut::<BoardResource>();

            if !is_legal_move(&board, cmd.from, cmd.to, cmd.player) {
                return Err(EngineError::InvalidCommand {
                    reason: "Illegal move for this piece".into(),
                });
            }

            let piece = board.squares.get(&cmd.from).copied().unwrap();
            let target = board.squares.get(&cmd.to).copied();

            let mut captured_kind = None;
            if let Some(t) = target {
                let hand_piece = match t.kind {
                    PieceKind::PromotedPawn => PieceKind::Pawn,
                    PieceKind::PromotedRook => PieceKind::Rook,
                    PieceKind::PromotedBishop => PieceKind::Bishop,
                    PieceKind::PromotedSilver => PieceKind::Silver,
                    PieceKind::PromotedLance => PieceKind::Lance,
                    PieceKind::PromotedKnight => PieceKind::Knight,
                    k => k,
                };
                board.hands.get_mut(&cmd.player).unwrap().push(hand_piece);
                captured_kind = Some(hand_piece);
            }

            let can_pro = can_promote(&board, piece.kind, cmd.from, cmd.to, cmd.player);
            let must_pro = if strict_fesa {
                must_promote_fesa(&board, piece.kind, cmd.to, cmd.player)
            } else {
                must_promote(&board, piece.kind, cmd.to, cmd.player)
            };

            if must_pro && !cmd.promote {
                return Err(EngineError::InvalidCommand {
                    reason: "Must promote this piece".into(),
                });
            }

            let mut moving_piece = piece;
            if cmd.promote {
                if !can_pro {
                    return Err(EngineError::InvalidCommand {
                        reason: "Cannot promote here".into(),
                    });
                }
                moving_piece.kind = match moving_piece.kind {
                    PieceKind::Pawn => PieceKind::PromotedPawn,
                    PieceKind::Silver => PieceKind::PromotedSilver,
                    PieceKind::Knight => PieceKind::PromotedKnight,
                    PieceKind::Lance => PieceKind::PromotedLance,
                    PieceKind::Bishop => PieceKind::PromotedBishop,
                    PieceKind::Rook => PieceKind::PromotedRook,
                    k => k,
                };
            }

            board.squares.remove(&cmd.from);
            board.squares.insert(cmd.to, moving_piece);
            (cmd.promote, captured_kind)
        }; // board dropped here

        if is_in_check(world.resource::<BoardResource>(), cmd.player) {
            *world.resource_mut::<BoardResource>() = board_backup;
            return Err(EngineError::InvalidCommand {
                reason: "Move leaves king in check".into(),
            });
        }

        world.resource_mut::<TurnResource>().0.advance();

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            promoted,
            captured: captured_kind,
        })];

        let opponent = {
            let board = world.resource::<BoardResource>();
            if cmd.player == board.sente {
                board.gote
            } else {
                board.sente
            }
        };

        let is_sennichite = record_state_and_check_sennichite(world, pre_hash, opponent);

        if is_checkmate(world.resource::<BoardResource>(), opponent) {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(Some(cmd.player)));
            events.push(Box::new(GameOverEvent {
                winner: Some(cmd.player),
            }));
        } else if is_sennichite {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(None));
            events.push(Box::new(GameOverEvent { winner: None }));
        }

        Ok(events)
    });

    rules.register::<DropPieceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        let board_backup = world.resource::<BoardResource>().clone();
        let pre_hash = board_backup.compute_state_hash(cmd.player);

        let piece_placed = {
            let mut board = world.resource_mut::<BoardResource>();

            if !is_legal_drop(&board, cmd.piece, cmd.to, cmd.player) {
                return Err(EngineError::InvalidCommand {
                    reason: "Illegal drop (occupied, nifu, or no legal moves)".into(),
                });
            }

            if cmd.piece == PieceKind::Pawn {
                let opponent = if cmd.player == board.sente {
                    board.gote
                } else {
                    board.sente
                };
                let mut test_board = board.clone();
                test_board.squares.insert(
                    cmd.to,
                    Piece {
                        kind: PieceKind::Pawn,
                        owner: cmd.player,
                    },
                );
                if is_checkmate(&test_board, opponent) {
                    return Err(EngineError::InvalidCommand {
                        reason: "Uchifuzume: Pawn drop causing checkmate is illegal".into(),
                    });
                }
            }

            let hand = board.hands.get_mut(&cmd.player).unwrap();
            if let Some(pos) = hand.iter().position(|&p| p == cmd.piece) {
                hand.remove(pos);
                board.squares.insert(
                    cmd.to,
                    Piece {
                        kind: cmd.piece,
                        owner: cmd.player,
                    },
                );
                true
            } else {
                false
            }
        }; // board dropped here

        if !piece_placed {
            return Err(EngineError::InvalidCommand {
                reason: "Piece not in hand".into(),
            });
        }

        if is_in_check(world.resource::<BoardResource>(), cmd.player) {
            *world.resource_mut::<BoardResource>() = board_backup;
            return Err(EngineError::InvalidCommand {
                reason: "Drop leaves king in check".into(),
            });
        }

        world.resource_mut::<TurnResource>().0.advance();

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceDroppedEvent {
            player: cmd.player,
            piece: cmd.piece,
            to: cmd.to,
        })];

        let opponent = {
            let board = world.resource::<BoardResource>();
            if cmd.player == board.sente {
                board.gote
            } else {
                board.sente
            }
        };

        let is_sennichite = record_state_and_check_sennichite(world, pre_hash, opponent);

        if is_checkmate(world.resource::<BoardResource>(), opponent) {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(Some(cmd.player)));
            events.push(Box::new(GameOverEvent {
                winner: Some(cmd.player),
            }));
        } else if is_sennichite {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(None));
            events.push(Box::new(GameOverEvent { winner: None }));
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not a player in this session".into(),
            });
        }
        let opponent = players
            .into_iter()
            .find(|&p| p != cmd.player)
            .unwrap_or(cmd.player);
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent {
            winner: Some(opponent),
        })])
    });

    rules.register::<SetShogiRulesCommand, _>(|cmd, world| {
        world.insert_resource(ShogiRulesConfigResource {
            strict_fesa_promotion: cmd.strict_fesa_promotion,
        });
        Ok(vec![])
    });

    rules
}
