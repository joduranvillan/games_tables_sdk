// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;

use crate::board::{
    resolve_landing, GooseBoardResource, PendingRollResource, GARDEN_SQUARE, WELL_SQUARE,
};
use crate::commands::{MoveTokenCommand, ResignCommand, RollDiceCommand};
use crate::events::{DiceRolledEvent, GameOverEvent, GooseMovedEvent, TurnSkippedEvent};

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

fn ensure_goose_resources(world: &mut BevyWorld) {
    if !world.contains_resource::<GooseBoardResource>() {
        let players = world.resource::<TurnResource>().0.players().to_vec();
        world.insert_resource(GooseBoardResource::new(&players));
    }
    if !world.contains_resource::<PendingRollResource>() {
        world.insert_resource(PendingRollResource::default());
    }
}

/// Avanza el turno al siguiente jugador disponible, descontando automáticamente
/// turnos de penalización (Posada, Pozo, Cárcel) si el jugador entrante está retenido.
fn advance_turn_skipping_penalized(world: &mut BevyWorld, events: &mut Vec<Box<dyn Event>>) {
    let player_count = world.resource::<TurnResource>().0.players().len().max(1);
    world.resource_mut::<TurnResource>().0.advance();

    for _ in 0..(player_count * 4) {
        let candidate = world.resource::<TurnResource>().0.current_player();
        let wait = world
            .resource::<GooseBoardResource>()
            .wait_turns_of(candidate);
        if wait == 0 {
            break;
        }
        let new_wait = wait.saturating_sub(1);
        world
            .resource_mut::<GooseBoardResource>()
            .wait_turns
            .insert(candidate, new_wait);
        events.push(Box::new(TurnSkippedEvent {
            player: candidate,
            remaining_wait: new_wait,
        }));
        world.resource_mut::<TurnResource>().0.advance();
    }
}

pub fn build_goose_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<RollDiceCommand, _>(|cmd, world| {
        ensure_goose_resources(world);

        if world.resource::<GooseBoardResource>().winner.is_some() {
            return Err(invalid("la partida ya ha terminado"));
        }

        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        if world
            .resource::<PendingRollResource>()
            .pending
            .contains_key(&cmd.player)
        {
            return Err(invalid(
                "ya tenés una tirada pendiente, avanzá tu ficha antes de volver a tirar",
            ));
        }

        let value = {
            let mut rng = world.resource_mut::<RandomResource>();
            rng.0.roll_die(6) as u8
        };

        world
            .resource_mut::<PendingRollResource>()
            .pending
            .insert(cmd.player, value);

        Ok(vec![Box::new(DiceRolledEvent {
            player: cmd.player,
            value,
        })])
    });

    rules.register::<MoveTokenCommand, _>(|cmd, world| {
        ensure_goose_resources(world);

        if world.resource::<GooseBoardResource>().winner.is_some() {
            return Err(invalid("la partida ya ha terminado"));
        }

        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let roll = world
            .resource::<PendingRollResource>()
            .pending
            .get(&cmd.player)
            .copied()
            .ok_or_else(|| invalid("todavía no tiraste el dado en este turno"))?;

        world
            .resource_mut::<PendingRollResource>()
            .pending
            .remove(&cmd.player);

        let from_square = world
            .resource::<GooseBoardResource>()
            .position_of(cmd.player);
        let resolution = resolve_landing(from_square, roll);
        let finished = resolution.final_square == GARDEN_SQUARE;

        {
            let mut board = world.resource_mut::<GooseBoardResource>();
            // Si alguien cae en el Pozo (31), libera a cualquier otro jugador que estuviera en el Pozo
            if resolution.final_square == WELL_SQUARE {
                let trapped: Vec<PlayerId> = board
                    .positions
                    .iter()
                    .filter_map(|(&p, &sq)| {
                        if p != cmd.player && sq == WELL_SQUARE {
                            Some(p)
                        } else {
                            None
                        }
                    })
                    .collect();
                for p in trapped {
                    board.wait_turns.insert(p, 0);
                }
            }

            board.positions.insert(cmd.player, resolution.final_square);
            if resolution.wait_turns > 0 {
                board.wait_turns.insert(cmd.player, resolution.wait_turns);
            }
            board.last_effect = resolution.description.clone();
            if finished {
                board.winner = Some(cmd.player);
            }
        }

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(GooseMovedEvent {
            player: cmd.player,
            from_square,
            raw_square: resolution.raw_square,
            to_square: resolution.final_square,
            bonus_turn: resolution.bonus_turn,
            wait_turns: resolution.wait_turns,
            effect: resolution.description,
            finished,
        })];

        if finished {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(Some(cmd.player)));
            events.push(Box::new(GameOverEvent { winner: cmd.player }));
        } else if !resolution.bonus_turn {
            advance_turn_skipping_penalized(world, &mut events);
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        ensure_goose_resources(world);

        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(invalid("no sos un jugador de esta partida"));
        }
        let opponent = players
            .into_iter()
            .find(|&p| p != cmd.player)
            .unwrap_or(cmd.player);

        world.resource_mut::<GooseBoardResource>().winner = Some(opponent);
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent { winner: opponent })])
    });

    rules
}
