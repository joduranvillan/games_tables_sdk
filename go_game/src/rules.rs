use crate::board::{BoardHistoryResource, BoardResource, DeadMarkingResource, Stone};
use crate::commands::{
    ConfirmDeadCommand, MarkDeadCommand, PassCommand, PlaceHandicapCommand, PlaceStoneCommand,
    ResignCommand, SetKomiCommand,
};
use crate::events::{GameOverEvent, PassedEvent, StonePlacedEvent, StonesCapturedEvent};
use bevy_ecs::world::World as BevyWorld;
use open_table_engine::prelude::*;

pub struct GoLegalMoveGenerator;

impl GoLegalMoveGenerator {
    pub fn is_legal_placement(
        board: &BoardResource,
        history: Option<&BoardHistoryResource>,
        player: PlayerId,
        x: usize,
        y: usize,
    ) -> bool {
        if x >= board.size || y >= board.size {
            return false;
        }
        if board.get_stone(x, y).is_some() {
            return false;
        }
        if board.ko_point == Some((x, y)) {
            return false;
        }

        let stone_color = if player == board.black_player {
            Stone::Black
        } else if player == board.white_player {
            Stone::White
        } else {
            return false;
        };
        let enemy_color = if stone_color == Stone::Black {
            Stone::White
        } else {
            Stone::Black
        };

        let current_hash = board.compute_hash();
        let mut test_board = board.clone();
        test_board.set_stone(x, y, Some(stone_color));

        let neighbors = test_board.get_neighbors(x, y);
        for (nx, ny) in neighbors {
            if test_board.get_stone(nx, ny) == Some(enemy_color) {
                let (group, liberties) = test_board.get_group_and_liberties(nx, ny);
                if liberties == 0 {
                    for &(gx, gy) in &group {
                        test_board.set_stone(gx, gy, None);
                    }
                }
            }
        }

        let (_, liberties) = test_board.get_group_and_liberties(x, y);
        if liberties == 0 {
            return false;
        }

        let test_hash = test_board.compute_hash();
        if test_hash == current_hash {
            return false;
        }
        if let Some(hist) = history {
            if hist.history.contains(&test_hash) {
                return false;
            }
        }

        true
    }
}

impl LegalMoveGenerator for GoLegalMoveGenerator {
    fn generate(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        if world
            .get_resource::<GameOverResource>()
            .is_some_and(|g| g.0)
        {
            return vec![];
        }
        if world
            .get_resource::<DeadMarkingResource>()
            .is_some_and(|d| d.active)
        {
            return vec![];
        }
        let Some(board) = world.get_resource::<BoardResource>() else {
            return vec![];
        };
        if player != board.black_player && player != board.white_player {
            return vec![];
        }
        let history = world.get_resource::<BoardHistoryResource>();

        let mut moves: Vec<Box<dyn Command>> = Vec::new();
        for y in 0..board.size {
            for x in 0..board.size {
                if Self::is_legal_placement(board, history, player, x, y) {
                    moves.push(Box::new(PlaceStoneCommand { player, x, y }));
                }
            }
        }
        moves.push(Box::new(PassCommand { player }));
        moves
    }
}

pub fn build_go_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.set_legal_move_generator(Box::new(GoLegalMoveGenerator));

    rules.register::<PlaceStoneCommand, _>(|cmd, world| {
        if !world.contains_resource::<BoardHistoryResource>() {
            world.insert_resource(BoardHistoryResource::default());
        }
        if !world.contains_resource::<DeadMarkingResource>() {
            world.insert_resource(DeadMarkingResource::default());
        }

        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        if let Some(dead_marking) = world.get_resource::<DeadMarkingResource>() {
            if dead_marking.active {
                return Err(EngineError::InvalidCommand {
                    reason: "Game is in dead marking phase".into(),
                });
            }
        }

        let (captured_count, new_hash) = {
            let (stone_color, enemy_color, current_hash, test_board_initial) = {
                let board = world.resource::<BoardResource>();
                let stone_color = if cmd.player == board.black_player {
                    Stone::Black
                } else {
                    Stone::White
                };
                let enemy_color = if stone_color == Stone::Black {
                    Stone::White
                } else {
                    Stone::Black
                };

                if cmd.x >= board.size || cmd.y >= board.size {
                    return Err(EngineError::InvalidCommand {
                        reason: "Out of bounds".into(),
                    });
                }
                if board.get_stone(cmd.x, cmd.y).is_some() {
                    return Err(EngineError::InvalidCommand {
                        reason: "Space occupied".into(),
                    });
                }
                if board.ko_point == Some((cmd.x, cmd.y)) {
                    return Err(EngineError::InvalidCommand {
                        reason: "Ko rule violation".into(),
                    });
                }

                let current_hash = board.compute_hash();
                (stone_color, enemy_color, current_hash, board.clone())
            };

            // Ensure current board hash is in history
            if let Some(mut history) = world.get_resource_mut::<BoardHistoryResource>() {
                history.history.insert(current_hash);
            }

            let mut test_board = test_board_initial;
            test_board.set_stone(cmd.x, cmd.y, Some(stone_color));
            let mut captured_stones = 0;
            let mut last_captured_stone = None;

            let neighbors = test_board.get_neighbors(cmd.x, cmd.y);
            for (nx, ny) in neighbors {
                if test_board.get_stone(nx, ny) == Some(enemy_color) {
                    let (group, liberties) = test_board.get_group_and_liberties(nx, ny);
                    if liberties == 0 {
                        captured_stones += group.len();
                        for &(gx, gy) in &group {
                            test_board.set_stone(gx, gy, None);
                            last_captured_stone = Some((gx, gy));
                        }
                    }
                }
            }

            let (_, liberties) = test_board.get_group_and_liberties(cmd.x, cmd.y);
            if liberties == 0 {
                return Err(EngineError::InvalidCommand {
                    reason: "Suicide is not allowed".into(),
                });
            }

            let test_hash = test_board.compute_hash();
            if let Some(history) = world.get_resource::<BoardHistoryResource>() {
                if history.history.contains(&test_hash) {
                    return Err(EngineError::InvalidCommand {
                        reason: "Superko rule violation".into(),
                    });
                }
            }

            if captured_stones > 0 {
                match stone_color {
                    Stone::Black => test_board.black_prisoners += captured_stones,
                    Stone::White => test_board.white_prisoners += captured_stones,
                }
            }

            if captured_stones == 1 {
                test_board.ko_point = last_captured_stone;
            } else {
                test_board.ko_point = None;
            }

            test_board.passes = 0;

            let mut board = world.resource_mut::<BoardResource>();
            *board = test_board;
            (captured_stones, test_hash)
        }; // board dropped here

        if let Some(mut history) = world.get_resource_mut::<BoardHistoryResource>() {
            history.history.insert(new_hash);
        }

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(StonePlacedEvent {
            player: cmd.player,
            x: cmd.x,
            y: cmd.y,
        })];
        if captured_count > 0 {
            events.push(Box::new(StonesCapturedEvent {
                player: cmd.player,
                count: captured_count,
            }));
        }

        world.resource_mut::<TurnResource>().0.advance();
        Ok(events)
    });

    rules.register::<PlaceHandicapCommand, _>(|cmd, world| {
        if !world.contains_resource::<BoardHistoryResource>() {
            world.insert_resource(BoardHistoryResource::default());
        }
        if !world.contains_resource::<DeadMarkingResource>() {
            world.insert_resource(DeadMarkingResource::default());
        }

        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        if let Some(dead_marking) = world.get_resource::<DeadMarkingResource>() {
            if dead_marking.active {
                return Err(EngineError::InvalidCommand {
                    reason: "Game is in dead marking phase".into(),
                });
            }
        }

        if world.resource::<TurnResource>().0.turn_number() != 0 {
            return Err(EngineError::InvalidCommand {
                reason: "Handicap stones can only be placed before game start".into(),
            });
        }

        let mut events: Vec<Box<dyn Event>> = Vec::new();
        let new_hash = {
            let mut board = world.resource_mut::<BoardResource>();
            if cmd.player != board.black_player {
                return Err(EngineError::InvalidCommand {
                    reason: "Only Black player can place handicap stones".into(),
                });
            }

            for &(x, y) in &cmd.positions {
                let x_usize = x as usize;
                let y_usize = y as usize;
                if x_usize >= board.size || y_usize >= board.size {
                    return Err(EngineError::InvalidCommand {
                        reason: "Out of bounds".into(),
                    });
                }
                if board.get_stone(x_usize, y_usize).is_some() {
                    return Err(EngineError::InvalidCommand {
                        reason: "Space occupied".into(),
                    });
                }
                board.set_stone(x_usize, y_usize, Some(Stone::Black));
                events.push(Box::new(StonePlacedEvent {
                    player: cmd.player,
                    x: x_usize,
                    y: y_usize,
                }));
            }
            board.compute_hash()
        };

        if let Some(mut history) = world.get_resource_mut::<BoardHistoryResource>() {
            history.history.insert(new_hash);
        }

        world.resource_mut::<TurnResource>().0.advance();
        Ok(events)
    });

    rules.register::<PassCommand, _>(|cmd, world| {
        if !world.contains_resource::<DeadMarkingResource>() {
            world.insert_resource(DeadMarkingResource::default());
        }

        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        if let Some(dead_marking) = world.get_resource::<DeadMarkingResource>() {
            if dead_marking.active {
                return Err(EngineError::InvalidCommand {
                    reason: "Game is in dead marking phase".into(),
                });
            }
        }

        let is_double_pass = {
            let mut board = world.resource_mut::<BoardResource>();
            board.passes += 1;
            board.ko_point = None;
            board.passes >= 2
        }; // board dropped here

        let events: Vec<Box<dyn Event>> = vec![Box::new(PassedEvent { player: cmd.player })];

        if is_double_pass {
            if let Some(mut dead_marking) = world.get_resource_mut::<DeadMarkingResource>() {
                dead_marking.active = true;
                dead_marking.dead_stones.clear();
                dead_marking.confirmed_players.clear();
            }
        } else {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<MarkDeadCommand, _>(|cmd, world| {
        let is_active = world
            .get_resource::<DeadMarkingResource>()
            .map(|d| d.active)
            .unwrap_or(false);

        if !is_active {
            return Err(EngineError::InvalidCommand {
                reason: "Not in dead marking phase".into(),
            });
        }

        {
            let board = world.resource::<BoardResource>();
            if cmd.player != board.black_player && cmd.player != board.white_player {
                return Err(EngineError::InvalidCommand {
                    reason: "Invalid player".into(),
                });
            }

            for &(x, y) in &cmd.positions {
                let x_u = x as usize;
                let y_u = y as usize;
                if x_u >= board.size || y_u >= board.size {
                    return Err(EngineError::InvalidCommand {
                        reason: "Out of bounds".into(),
                    });
                }
                if board.get_stone(x_u, y_u).is_none() {
                    return Err(EngineError::InvalidCommand {
                        reason: "No stone at position".into(),
                    });
                }
            }
        }

        if let Some(mut dead_marking) = world.get_resource_mut::<DeadMarkingResource>() {
            for &(x, y) in &cmd.positions {
                let pos = (x as usize, y as usize);
                if !dead_marking.dead_stones.insert(pos) {
                    dead_marking.dead_stones.remove(&pos);
                }
            }
            dead_marking.confirmed_players.clear();
        }

        Ok(vec![])
    });

    rules.register::<ConfirmDeadCommand, _>(|cmd, world| {
        let is_active = world
            .get_resource::<DeadMarkingResource>()
            .map(|d| d.active)
            .unwrap_or(false);

        if !is_active {
            return Err(EngineError::InvalidCommand {
                reason: "Not in dead marking phase".into(),
            });
        }

        let (black_p, white_p) = {
            let board = world.resource::<BoardResource>();
            (board.black_player, board.white_player)
        };

        if cmd.player != black_p && cmd.player != white_p {
            return Err(EngineError::InvalidCommand {
                reason: "Invalid player".into(),
            });
        }

        let mut both_confirmed = false;
        if let Some(mut dead_marking) = world.get_resource_mut::<DeadMarkingResource>() {
            dead_marking.confirmed_players.insert(cmd.player);
            if dead_marking.confirmed_players.contains(&black_p)
                && dead_marking.confirmed_players.contains(&white_p)
            {
                both_confirmed = true;
            }
        }

        if both_confirmed {
            let dead_positions: Vec<(usize, usize)> = world
                .get_resource::<DeadMarkingResource>()
                .map(|d| d.dead_stones.iter().copied().collect())
                .unwrap_or_default();

            let (winner, black_total, white_total) = {
                let mut board = world.resource_mut::<BoardResource>();
                for (x, y) in dead_positions {
                    if let Some(stone) = board.get_stone(x, y) {
                        match stone {
                            Stone::Black => board.white_prisoners += 1,
                            Stone::White => board.black_prisoners += 1,
                        }
                    }
                    board.set_stone(x, y, None);
                }

                let (black_territory, white_territory) = board.calculate_territory();
                let black_total = (black_territory + board.black_prisoners) as f32;
                let white_total = (white_territory + board.white_prisoners) as f32
                    + (board.komi_half_points as f32 / 2.0);

                let winner = if black_total > white_total {
                    Some(board.black_player)
                } else if white_total > black_total {
                    Some(board.white_player)
                } else {
                    None
                };
                (winner, black_total, white_total)
            };

            if let Some(mut dead_marking) = world.get_resource_mut::<DeadMarkingResource>() {
                dead_marking.active = false;
            }

            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(winner));

            Ok(vec![Box::new(GameOverEvent {
                winner,
                reason: "Two consecutive passes and confirmed dead stones".into(),
                black_score: black_total,
                white_score: white_total,
            })])
        } else {
            Ok(vec![])
        }
    });

    rules.register::<SetKomiCommand, _>(|cmd, world| {
        let mut board = world.resource_mut::<BoardResource>();
        if cmd.player != board.black_player && cmd.player != board.white_player {
            return Err(EngineError::InvalidCommand {
                reason: "Invalid player".into(),
            });
        }
        board.komi_half_points = cmd.komi_half_points;
        Ok(vec![])
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
            reason: "Resignation".into(),
            black_score: 0.0,
            white_score: 0.0,
        })])
    });

    rules
}
