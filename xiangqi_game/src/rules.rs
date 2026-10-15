pub use crate::board::XiangqiHistoryResource;
use crate::board::BoardResource;
use crate::commands::{MovePieceCommand, ResignCommand};
use crate::events::{GameOverEvent, PieceMovedEvent};
use crate::movement::{check_flying_general, is_in_check, is_legal_move};
use bevy_ecs::world::World;
use open_table_engine::prelude::*;

pub fn all_legal_moves_for(world: &World, player: PlayerId) -> Vec<MovePieceCommand> {
    let Some(board) = world.get_resource::<BoardResource>() else {
        return Vec::new();
    };
    let mut legal_moves = Vec::new();

    for (&from, piece) in &board.squares {
        if piece.owner == player {
            for tx in 0..9 {
                for ty in 0..10 {
                    let to = (tx, ty);
                    if is_legal_move(board, from, to, player) {
                        let mut test_board = board.clone();
                        let p = test_board.squares.remove(&from).unwrap();
                        test_board.squares.insert(to, p);
                        if !is_in_check(&test_board, player) && !check_flying_general(&test_board) {
                            legal_moves.push(MovePieceCommand { player, from, to });
                        }
                    }
                }
            }
        }
    }

    legal_moves
}

pub struct XiangqiLegalMoveGenerator;

impl LegalMoveGenerator for XiangqiLegalMoveGenerator {
    fn generate(&self, world: &World, player: PlayerId) -> Vec<Box<dyn Command>> {
        if let Some(go) = world.get_resource::<GameOverResource>() {
            if go.0 {
                return Vec::new();
            }
        }
        if let Some(turn) = world.get_resource::<TurnResource>() {
            if !turn.0.is_current(player) {
                return Vec::new();
            }
        }
        all_legal_moves_for(world, player)
            .into_iter()
            .map(|c| Box::new(c) as Box<dyn Command>)
            .collect()
    }
}

pub fn build_xiangqi_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.set_legal_move_generator(Box::new(XiangqiLegalMoveGenerator));

    rules.register::<MovePieceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        let pre_move_hash = world
            .resource::<BoardResource>()
            .compute_state_hash(cmd.player);

        let (captured_kind, invalid_move) = {
            let mut board = world.resource_mut::<BoardResource>();

            let piece_for_check = board.squares.get(&cmd.from).copied();
            if let Some(piece) = piece_for_check {
                if piece.owner == cmd.player && piece.kind == crate::board::PieceKind::Elephant {
                    let is_red = piece.owner == board.red;
                    if (is_red && cmd.to.1 < 5) || (!is_red && cmd.to.1 > 4) {
                        return Err(EngineError::InvalidCommand {
                            reason: "Elephant cannot cross the river".into(),
                        });
                    }

                    let eye_x = (cmd.from.0 + cmd.to.0) / 2;
                    let eye_y = (cmd.from.1 + cmd.to.1) / 2;
                    if board.squares.contains_key(&(eye_x, eye_y)) {
                        return Err(EngineError::InvalidCommand {
                            reason: "Elephant's eye is blocked".into(),
                        });
                    }
                } else if piece.owner == cmd.player && piece.kind == crate::board::PieceKind::Horse
                {
                    let dx = (cmd.to.0 as isize - cmd.from.0 as isize).abs();
                    let dy = (cmd.to.1 as isize - cmd.from.1 as isize).abs();
                    if (dx == 1 && dy == 2) || (dx == 2 && dy == 1) {
                        let block_x = if dx == 2 {
                            (cmd.from.0 + cmd.to.0) / 2
                        } else {
                            cmd.from.0
                        };
                        let block_y = if dy == 2 {
                            (cmd.from.1 + cmd.to.1) / 2
                        } else {
                            cmd.from.1
                        };
                        if board.squares.contains_key(&(block_x, block_y)) {
                            return Err(EngineError::InvalidCommand {
                                reason: "Horse's leg is blocked".into(),
                            });
                        }
                    }
                } else if piece.owner == cmd.player && piece.kind == crate::board::PieceKind::Cannon
                {
                    let target_has_piece = board.squares.contains_key(&cmd.to);
                    let dx = (cmd.to.0 as isize - cmd.from.0 as isize).abs();
                    let dy = (cmd.to.1 as isize - cmd.from.1 as isize).abs();
                    let mut count = 0;
                    if dx != 0 && dy == 0 {
                        let min = cmd.from.0.min(cmd.to.0);
                        let max = cmd.from.0.max(cmd.to.0);
                        for x in min + 1..max {
                            if board.squares.contains_key(&(x, cmd.from.1)) {
                                count += 1;
                            }
                        }
                    } else if dy != 0 && dx == 0 {
                        let min = cmd.from.1.min(cmd.to.1);
                        let max = cmd.from.1.max(cmd.to.1);
                        for y in min + 1..max {
                            if board.squares.contains_key(&(cmd.from.0, y)) {
                                count += 1;
                            }
                        }
                    }
                    if !target_has_piece && count > 0 {
                        return Err(EngineError::InvalidCommand {
                            reason: "Cannon cannot jump when not capturing".into(),
                        });
                    } else if target_has_piece && count != 1 {
                        return Err(EngineError::InvalidCommand {
                            reason: "Cannon capture requires exactly one platform piece".into(),
                        });
                    }
                } else if piece.owner == cmd.player
                    && piece.kind == crate::board::PieceKind::Advisor
                {
                    let is_red = piece.owner == board.red;
                    let dx = (cmd.to.0 as isize - cmd.from.0 as isize).abs();
                    let dy = (cmd.to.1 as isize - cmd.from.1 as isize).abs();
                    if dx != 1 || dy != 1 {
                        return Err(EngineError::InvalidCommand {
                            reason: "Advisor must move diagonally one step".into(),
                        });
                    }
                    if !(3..=5).contains(&cmd.to.0)
                        || (is_red && !(7..=9).contains(&cmd.to.1))
                        || (!is_red && cmd.to.1 > 2)
                    {
                        return Err(EngineError::InvalidCommand {
                            reason: "Advisor must stay within the palace".into(),
                        });
                    }
                }
            }

            if !is_legal_move(&board, cmd.from, cmd.to, cmd.player) {
                return Err(EngineError::InvalidCommand {
                    reason: "Illegal move for this piece".into(),
                });
            }

            let target = board.squares.get(&cmd.to).copied();
            let captured_kind = target.map(|t| t.kind);

            let piece = board.squares.remove(&cmd.from).unwrap();
            board.squares.insert(cmd.to, piece);

            if check_flying_general(&board) || is_in_check(&board, cmd.player) {
                board.squares.remove(&cmd.to);
                board.squares.insert(cmd.from, piece);
                if let Some(t) = target {
                    board.squares.insert(cmd.to, t);
                }
                (captured_kind, true)
            } else {
                (captured_kind, false)
            }
        }; // board dropped here

        if invalid_move {
            return Err(EngineError::InvalidCommand {
                reason: "Move leaves General in check or facing enemy General".into(),
            });
        }

        world.resource_mut::<TurnResource>().0.advance();

        let (opponent, post_move_hash) = {
            let board = world.resource::<BoardResource>();
            let opp = if cmd.player == board.red {
                board.black
            } else {
                board.red
            };
            (opp, board.compute_state_hash(opp))
        };

        if world.get_resource::<XiangqiHistoryResource>().is_none() {
            world.insert_resource(XiangqiHistoryResource::default());
        }
        let repetition_count = {
            let mut history = world.resource_mut::<XiangqiHistoryResource>();
            if history.counts.is_empty() {
                history.record_hash(pre_move_hash);
            }
            history.record_hash(post_move_hash)
        };

        // En Xiangqi tanto el jaque mate (Jiangsi) como el ahogado (Kunbi) son victoria para cmd.player
        let is_mate_or_kunbi = all_legal_moves_for(world, opponent).is_empty();

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            captured: captured_kind,
        })];

        if is_mate_or_kunbi {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(Some(cmd.player)));
            events.push(Box::new(GameOverEvent {
                winner: Some(cmd.player),
            }));
        } else if repetition_count >= 3 {
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

    rules
}

