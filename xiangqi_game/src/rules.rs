use open_table_engine::prelude::*;
use bevy_ecs::world::World;
use crate::board::BoardResource;
use crate::commands::{MovePieceCommand, ResignCommand};
use crate::events::{PieceMovedEvent, GameOverEvent};
use crate::movement::{is_legal_move, check_flying_general, is_in_check};

pub fn all_legal_moves_for(world: &World, player: PlayerId) -> Vec<MovePieceCommand> {
    let board = world.resource::<BoardResource>();
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
                            legal_moves.push(MovePieceCommand {
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

    legal_moves
}

pub fn build_xiangqi_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<MovePieceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand { reason: "Not your turn".into() });
        }

        let (captured_kind, invalid_move) = {
            let mut board = world.resource_mut::<BoardResource>();

            let piece_for_check = board.squares.get(&cmd.from).copied();
            if let Some(piece) = piece_for_check {
                if piece.owner == cmd.player && piece.kind == crate::board::PieceKind::Elephant {
                    let is_red = piece.owner == board.red;
                    if (is_red && cmd.to.1 < 5) || (!is_red && cmd.to.1 > 4) {
                        return Err(EngineError::InvalidCommand { reason: "Elephant cannot cross the river".into() });
                    }

                    let eye_x = (cmd.from.0 + cmd.to.0) / 2;
                    let eye_y = (cmd.from.1 + cmd.to.1) / 2;
                    if board.squares.contains_key(&(eye_x, eye_y)) {
                        return Err(EngineError::InvalidCommand { reason: "Elephant's eye is blocked".into() });
                    }
                } else if piece.owner == cmd.player && piece.kind == crate::board::PieceKind::Horse {
                    let dx = (cmd.to.0 as isize - cmd.from.0 as isize).abs();
                    let dy = (cmd.to.1 as isize - cmd.from.1 as isize).abs();
                    if (dx == 1 && dy == 2) || (dx == 2 && dy == 1) {
                        let block_x = if dx == 2 { (cmd.from.0 + cmd.to.0) / 2 } else { cmd.from.0 };
                        let block_y = if dy == 2 { (cmd.from.1 + cmd.to.1) / 2 } else { cmd.from.1 };
                        if board.squares.contains_key(&(block_x, block_y)) {
                            return Err(EngineError::InvalidCommand { reason: "Horse's leg is blocked".into() });
                        }
                    }
                } else if piece.owner == cmd.player && piece.kind == crate::board::PieceKind::Cannon {
                    let target_has_piece = board.squares.contains_key(&cmd.to);
                    let dx = (cmd.to.0 as isize - cmd.from.0 as isize).abs();
                    let dy = (cmd.to.1 as isize - cmd.from.1 as isize).abs();
                    let mut count = 0;
                    if dx != 0 && dy == 0 {
                        let min = cmd.from.0.min(cmd.to.0);
                        let max = cmd.from.0.max(cmd.to.0);
                        for x in min + 1..max {
                            if board.squares.contains_key(&(x, cmd.from.1)) { count += 1; }
                        }
                    } else if dy != 0 && dx == 0 {
                        let min = cmd.from.1.min(cmd.to.1);
                        let max = cmd.from.1.max(cmd.to.1);
                        for y in min + 1..max {
                            if board.squares.contains_key(&(cmd.from.0, y)) { count += 1; }
                        }
                    }
                    if !target_has_piece && count > 0 {
                        return Err(EngineError::InvalidCommand { reason: "Cannon cannot jump when not capturing".into() });
                    } else if target_has_piece && count != 1 {
                        return Err(EngineError::InvalidCommand { reason: "Cannon capture requires exactly one platform piece".into() });
                    }
                } else if piece.owner == cmd.player && piece.kind == crate::board::PieceKind::Advisor {
                    let is_red = piece.owner == board.red;
                    let dx = (cmd.to.0 as isize - cmd.from.0 as isize).abs();
                    let dy = (cmd.to.1 as isize - cmd.from.1 as isize).abs();
                    if dx != 1 || dy != 1 {
                        return Err(EngineError::InvalidCommand { reason: "Advisor must move diagonally one step".into() });
                    }
                    if !(3..=5).contains(&cmd.to.0) || (is_red && !(7..=9).contains(&cmd.to.1)) || (!is_red && cmd.to.1 > 2) {
                        return Err(EngineError::InvalidCommand { reason: "Advisor must stay within the palace".into() });
                    }
                }
            }

            if !is_legal_move(&board, cmd.from, cmd.to, cmd.player) {
                return Err(EngineError::InvalidCommand { reason: "Illegal move for this piece".into() });
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

        let opponent = {
            let board = world.resource::<BoardResource>();
            if cmd.player == board.red { board.black } else { board.red }
        };

        let is_mate = {
            let board = world.resource::<BoardResource>();
            is_in_check(board, opponent) && all_legal_moves_for(world, opponent).is_empty()
        };

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            captured: captured_kind,
        })];

        if is_mate {
            events.push(Box::new(GameOverEvent {
                winner: Some(cmd.player),
            }));
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(EngineError::InvalidCommand { reason: "Not a player in this session".into() });
        }
        let opponent = players.into_iter().find(|&p| p != cmd.player).unwrap_or(cmd.player);
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent { winner: Some(opponent) })])
    });

    rules
}

