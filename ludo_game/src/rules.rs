use open_table_engine::prelude::*;

use crate::board::{PendingRollResource, TokensResource, MAX_STEPS};
use crate::commands::{MoveTokenCommand, RollDiceCommand};
use crate::events::{DiceRolledEvent, GameOverEvent, NoValidMovesEvent, TokenMovedEvent};

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

pub fn build_ludo_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<RollDiceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        {
            let pending = world.resource::<PendingRollResource>();
            if pending.pending.contains_key(&cmd.player) {
                return Err(invalid(
                    "ya tenés una tirada pendiente, movela antes de tirar de nuevo",
                ));
            }
        }

        let value = {
            let mut rng = world.resource_mut::<RandomResource>();
            rng.0.roll_die(6)
        };

        let has_moves = world
            .resource::<TokensResource>()
            .has_any_valid_move(cmd.player, value);

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(DiceRolledEvent {
            player: cmd.player,
            value,
        })];

        if has_moves {
            world
                .resource_mut::<PendingRollResource>()
                .pending
                .insert(cmd.player, value);
        } else {
            events.push(Box::new(NoValidMovesEvent {
                player: cmd.player,
                value,
            }));
            if value != 6 {
                world.resource_mut::<TurnResource>().0.advance();
            }
        }

        Ok(events)
    });

    rules.register::<MoveTokenCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        if cmd.token_index >= crate::board::TOKENS_PER_PLAYER {
            return Err(invalid("ese índice de ficha no existe"));
        }

        let roll = world
            .resource::<PendingRollResource>()
            .pending
            .get(&cmd.player)
            .copied()
            .ok_or_else(|| invalid("todavía no tiraste el dado este turno"))?;

        if !world
            .resource::<TokensResource>()
            .is_valid_move_for_token(cmd.player, cmd.token_index, roll)
        {
            return Err(invalid("movimiento inválido para la ficha seleccionada"));
        }

        world
            .resource_mut::<PendingRollResource>()
            .pending
            .remove(&cmd.player);

        let mut tokens = world.resource_mut::<TokensResource>();
        let current_steps = tokens.tokens[&cmd.player][cmd.token_index];

        let new_steps = if current_steps == 0 {
            1 // entra al tablero
        } else {
            current_steps + roll
        };

        // Captura: si la nueva posición coincide con una ficha rival en
        // el tramo compartido, esa ficha vuelve a la base. Nunca aplica
        // en la base, tramo final o en casillas seguras (salidas).
        let mut captured = None;
        if let Some(landing) = tokens.board_position(cmd.player, new_steps) {
            if !tokens.is_safe_square(landing) {
                let other_players: Vec<PlayerId> = tokens.tokens.keys().copied().collect();
                for other in other_players {
                    if other == cmd.player {
                        continue;
                    }
                    let their_steps_list = tokens.tokens[&other];
                    for (idx, &their_steps) in their_steps_list.iter().enumerate() {
                        if tokens.board_position(other, their_steps) == Some(landing) {
                            tokens.tokens.get_mut(&other).unwrap()[idx] = 0;
                            captured = Some((other, idx));
                        }
                    }
                }
            }
        }

        tokens.tokens.get_mut(&cmd.player).unwrap()[cmd.token_index] = new_steps;
        let finished = new_steps == MAX_STEPS;
        let all_finished = tokens.all_finished(cmd.player);

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(TokenMovedEvent {
            player: cmd.player,
            token_index: cmd.token_index,
            from_steps: current_steps,
            to_steps: new_steps,
            captured,
            finished,
        })];

        if all_finished {
            events.push(Box::new(GameOverEvent { winner: cmd.player }));
        }

        // Un 6 da turno extra: no se avanza el turno en ese caso.
        if roll != 6 {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules
}
