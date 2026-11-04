// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use bevy_ecs::world::World;
use open_table_engine::prelude::*;

use crate::board::{must_use_larger_die_check, BoardResource, Sides, CHECKERS_PER_PLAYER, POINTS};
use crate::commands::{
    AcceptDoubleCommand, MoveCheckerCommand, OfferDoubleCommand, RejectDoubleCommand,
    ResignCommand, RollDiceCommand,
};
use crate::dice::PendingDiceResource;
use crate::events::{
    CheckerMovedEvent, DiceRolledEvent, DoubleAcceptedEvent, DoubleOfferedEvent,
    DoubleRejectedEvent, GameOverEvent, NoValidMovesEvent,
};
pub use crate::resources::{DoublingCubeResource, MatchStateResource};

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

pub struct BackgammonLegalMoveGenerator;

impl LegalMoveGenerator for BackgammonLegalMoveGenerator {
    fn generate(&self, world: &World, player: PlayerId) -> Vec<Box<dyn Command>> {
        if let Some(go) = world.get_resource::<GameOverResource>() {
            if go.0 {
                return Vec::new();
            }
        }

        if let Some(cube) = world.get_resource::<DoublingCubeResource>() {
            if let Some(offerer) = cube.offered_by {
                if let Some(sides) = world.get_resource::<Sides>() {
                    if player == sides.opponent_of(offerer) {
                        return vec![
                            Box::new(AcceptDoubleCommand { player }),
                            Box::new(RejectDoubleCommand { player }),
                        ];
                    }
                }
                return Vec::new();
            }
        }

        if let Some(turn) = world.get_resource::<TurnResource>() {
            if !turn.0.is_current(player) {
                return Vec::new();
            }
        }

        let Some(board) = world.get_resource::<BoardResource>() else {
            return Vec::new();
        };
        let Some(sides) = world.get_resource::<Sides>() else {
            return Vec::new();
        };

        let pending_dice = world
            .get_resource::<PendingDiceResource>()
            .and_then(|p| p.pending.get(&player))
            .cloned()
            .unwrap_or_default();

        if pending_dice.is_empty() {
            return vec![Box::new(RollDiceCommand { player })];
        }

        let mut unique_dice = pending_dice.clone();
        unique_dice.sort_unstable();
        unique_dice.dedup();

        let owner_sign = sides.owner_sign(player);
        let on_bar = *board.bar.get(&player).unwrap_or(&0);
        let mut moves: Vec<Box<dyn Command>> = Vec::new();

        if on_bar > 0 {
            for &die in &unique_dice {
                if sides.simulate_step(board, player, None, die).is_some()
                    && must_use_larger_die_check(sides, board, player, &pending_dice, None, die)
                        .is_ok()
                {
                    moves.push(Box::new(MoveCheckerCommand {
                        player,
                        from: None,
                        die,
                    }));
                }
            }
        } else {
            for from in 0..POINTS {
                if board.points[from] * owner_sign > 0 {
                    for &die in &unique_dice {
                        if sides
                            .simulate_step(board, player, Some(from), die)
                            .is_some()
                            && must_use_larger_die_check(
                                sides,
                                board,
                                player,
                                &pending_dice,
                                Some(from),
                                die,
                            )
                            .is_ok()
                        {
                            moves.push(Box::new(MoveCheckerCommand {
                                player,
                                from: Some(from),
                                die,
                            }));
                        }
                    }
                }
            }
        }

        moves
    }
}

pub fn build_backgammon_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.set_legal_move_generator(Box::new(BackgammonLegalMoveGenerator));

    rules.register::<OfferDoubleCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        if world
            .get_resource::<MatchStateResource>()
            .map(|m| m.crawford_game)
            .unwrap_or(false)
        {
            return Err(invalid("no se puede doblar en el juego Crawford"));
        }

        {
            let pending = world.resource::<PendingDiceResource>();
            if pending
                .pending
                .get(&cmd.player)
                .map(|d| !d.is_empty())
                .unwrap_or(false)
            {
                return Err(invalid("no podés doblar si ya tiraste los dados"));
            }
        }

        let cube = world.resource::<DoublingCubeResource>();
        if let Some(owner) = cube.owner {
            if owner != cmd.player {
                return Err(invalid("no tenés la posesión del dado de doblaje"));
            }
        }
        if cube.offered || cube.offered_by.is_some() {
            return Err(invalid("ya hay una oferta de doblaje en curso"));
        }

        let mut cube_mut = world.resource_mut::<DoublingCubeResource>();
        cube_mut.offered = true;
        cube_mut.offered_by = Some(cmd.player);

        Ok(vec![Box::new(DoubleOfferedEvent { player: cmd.player })])
    });

    rules.register::<AcceptDoubleCommand, _>(|cmd, world| {
        let offerer = {
            let cube = world.resource::<DoublingCubeResource>();
            cube.offered_by
                .ok_or_else(|| invalid("no hay ninguna oferta de doblaje pendiente"))?
        };

        let opponent = world.resource::<Sides>().opponent_of(offerer);
        if cmd.player != opponent {
            return Err(invalid("solo el oponente puede aceptar el doblaje"));
        }

        let mut cube = world.resource_mut::<DoublingCubeResource>();
        cube.value *= 2;
        cube.owner = Some(cmd.player);
        cube.offered = false;
        cube.offered_by = None;
        let new_val = cube.value;

        Ok(vec![Box::new(DoubleAcceptedEvent {
            player: cmd.player,
            value: new_val,
        })])
    });

    rules.register::<RejectDoubleCommand, _>(|cmd, world| {
        let offerer = {
            let cube = world.resource::<DoublingCubeResource>();
            cube.offered_by
                .ok_or_else(|| invalid("no hay ninguna oferta de doblaje pendiente"))?
        };

        let opponent = world.resource::<Sides>().opponent_of(offerer);
        if cmd.player != opponent {
            return Err(invalid("solo el oponente puede rechazar el doblaje"));
        }

        let current_val = world.resource::<DoublingCubeResource>().value;
        let mut cube_mut = world.resource_mut::<DoublingCubeResource>();
        cube_mut.offered = false;
        cube_mut.offered_by = None;
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(offerer)));

        let events: Vec<Box<dyn Event>> = vec![
            Box::new(DoubleRejectedEvent {
                player: cmd.player,
                value: current_val,
            }),
            Box::new(GameOverEvent {
                winner: offerer,
                gammon: false,
                backgammon: false,
                score: current_val,
            }),
        ];

        Ok(events)
    });

    rules.register::<RollDiceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        if world
            .resource::<DoublingCubeResource>()
            .offered_by
            .is_some()
        {
            return Err(invalid(
                "hay una propuesta de doblaje pendiente; debe aceptarse o rechazarse primero",
            ));
        }
        {
            let pending = world.resource::<PendingDiceResource>();
            if pending
                .pending
                .get(&cmd.player)
                .map(|d| !d.is_empty())
                .unwrap_or(false)
            {
                return Err(invalid(
                    "todavía tenés dados sin usar de la tirada anterior",
                ));
            }
        }

        let values = {
            let mut rng = world.resource_mut::<RandomResource>();
            let d1 = rng.0.roll_die(6);
            let d2 = rng.0.roll_die(6);
            if d1 == d2 {
                vec![d1, d1, d1, d1]
            } else {
                vec![d1, d2]
            }
        };

        let board = world.resource::<BoardResource>();
        let sides = world.resource::<Sides>();
        let has_moves = sides.has_any_valid_move(board, cmd.player, &values);

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(DiceRolledEvent {
            player: cmd.player,
            values: values.clone(),
        })];

        if has_moves {
            world
                .resource_mut::<PendingDiceResource>()
                .pending
                .insert(cmd.player, values);
        } else {
            events.push(Box::new(NoValidMovesEvent { player: cmd.player }));
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<MoveCheckerCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        if world.resource::<DoublingCubeResource>().offered_by.is_some() {
            return Err(invalid("hay una propuesta de doblaje pendiente; debe aceptarse o rechazarse primero"));
        }

        let die_index = {
            let pending = world.resource::<PendingDiceResource>();
            let dice = pending
                .pending
                .get(&cmd.player)
                .ok_or_else(|| invalid("todavía no tiraste los dados"))?;
            dice.iter()
                .position(|&d| d == cmd.die)
                .ok_or_else(|| invalid("ese valor de dado no está disponible"))?
        };

        let opponent = world.resource::<Sides>().opponent_of(cmd.player);
        let on_bar = *world
            .resource::<BoardResource>()
            .bar
            .get(&cmd.player)
            .unwrap_or(&0);

        if on_bar > 0 && cmd.from.is_some() {
            return Err(invalid("tenés fichas en la barra, tenés que entrarlas primero"));
        }
        if on_bar == 0 && cmd.from.is_none() {
            return Err(invalid("no tenés fichas en la barra para entrar"));
        }

        let sides = *world.resource::<Sides>();
        let owner_sign = sides.owner_sign(cmd.player);
        let direction = sides.forward_direction(cmd.player);

        let destination: Option<usize> = match cmd.from {
            None => Some(sides.entry_point(cmd.player, cmd.die)),
            Some(from) => {
                if from >= POINTS {
                    return Err(invalid("esa posición no existe en el tablero"));
                }
                let board = world.resource::<BoardResource>();
                if board.points[from] * owner_sign <= 0 {
                    return Err(invalid("no tenés una ficha tuya en esa posición"));
                }
                let raw = from as i32 + direction * cmd.die as i32;
                if raw < 0 || raw >= POINTS as i32 {
                    if !sides.all_checkers_home(board, cmd.player) {
                        return Err(invalid(
                            "no podés sacar fichas todavía: no están todas en tu cuadrante final",
                        ));
                    }
                    let distance = if cmd.player == sides.increasing {
                        24 - from as i32
                    } else {
                        from as i32 + 1
                    };
                    if cmd.die as i32 > distance && sides.has_checkers_behind_die_exit(board, cmd.player, from, cmd.die) {
                        return Err(invalid(
                            "no podés sacar esta ficha con un dado mayor porque tenés fichas más atrás",
                        ));
                    }
                    None
                } else {
                    Some(raw as usize)
                }
            }
        };

        if let Some(dest) = destination {
            let board = world.resource::<BoardResource>();
            let opponent_sign = -owner_sign;
            if board.points[dest] * opponent_sign > 1 {
                return Err(invalid("ese punto está bloqueado por el rival"));
            }
        }

        {
            let board = world.resource::<BoardResource>();
            let pending_dice = &world.resource::<PendingDiceResource>().pending[&cmd.player];
            if let Err(reason) =
                must_use_larger_die_check(&sides, board, cmd.player, pending_dice, cmd.from, cmd.die)
            {
                return Err(invalid(reason));
            }
        }

        let mut board = world.resource_mut::<BoardResource>();
        let mut captured_opponent = false;
        let mut borne_off = false;

        match destination {
            None => {
                borne_off = true;
                *board.borne_off.entry(cmd.player).or_insert(0) += 1;
                if let Some(from) = cmd.from {
                    board.points[from] -= owner_sign;
                }
            }
            Some(dest) => {
                let opponent_sign = -owner_sign;
                let dest_count = board.points[dest];
                if dest_count * opponent_sign > 1 {
                    return Err(invalid("ese punto está bloqueado por el rival"));
                }
                if dest_count * opponent_sign == 1 {
                    captured_opponent = true;
                    *board.bar.entry(opponent).or_insert(0) += 1;
                    board.points[dest] = 0;
                }
                board.points[dest] += owner_sign;
                match cmd.from {
                    Some(from) => board.points[from] -= owner_sign,
                    None => {
                        *board.bar.get_mut(&cmd.player).unwrap() -= 1;
                    }
                }
            }
        }

        let total_borne_off = *board.borne_off.get(&cmd.player).unwrap_or(&0);
        let opponent = sides.opponent_of(cmd.player);
        let opponent_borne_off = *board.borne_off.get(&opponent).unwrap_or(&0);
        let opponent_bar = *board.bar.get(&opponent).unwrap_or(&0);
        let opponent_sign = sides.owner_sign(opponent);
        let opponent_in_winner_home = (0..POINTS).any(|idx| {
            sides.is_home_point(cmd.player, idx) && board.points[idx] * opponent_sign > 0
        });
        let _ = board; // release mutable borrow before accessing other resources

        world
            .resource_mut::<PendingDiceResource>()
            .pending
            .get_mut(&cmd.player)
            .unwrap()
            .remove(die_index);
        let remaining_dice = world.resource::<PendingDiceResource>().pending[&cmd.player].clone();

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(CheckerMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: destination,
            captured_opponent,
            borne_off,
        })];

        if total_borne_off == CHECKERS_PER_PLAYER {
            let gammon = opponent_borne_off == 0;
            let backgammon = gammon && (opponent_bar > 0 || opponent_in_winner_home);
            let board_points = if backgammon { 3 } else if gammon { 2 } else { 1 };
            let cube_val = world.resource::<DoublingCubeResource>().value;
            let score = board_points * cube_val;

            events.push(Box::new(GameOverEvent {
                winner: cmd.player,
                gammon,
                backgammon,
                score,
            }));
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(Some(cmd.player)));
        }

        if !remaining_dice.is_empty() {
            if !sides.has_any_valid_move(world.resource::<BoardResource>(), cmd.player, &remaining_dice) {
                world
                    .resource_mut::<PendingDiceResource>()
                    .pending
                    .get_mut(&cmd.player)
                    .unwrap()
                    .clear();
                events.push(Box::new(NoValidMovesEvent { player: cmd.player }));
                world.resource_mut::<TurnResource>().0.advance();
            }
        } else {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(invalid("no sos un jugador de esta partida"));
        }
        let opponent = players
            .into_iter()
            .find(|&p| p != cmd.player)
            .unwrap_or(cmd.player);
        let cube_val = world.resource::<DoublingCubeResource>().value;
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent {
            winner: opponent,
            gammon: false,
            backgammon: false,
            score: cube_val,
        })])
    });

    rules
}
