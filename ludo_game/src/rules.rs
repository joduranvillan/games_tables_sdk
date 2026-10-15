use open_table_engine::prelude::*;

use crate::board::{
    ConsecutiveSixesResource, LudoRulesConfigResource, PendingRollResource, TokensResource,
    MAX_STEPS,
};
use crate::commands::{MoveTokenCommand, ResignCommand, RollDiceCommand, SetLudoRulesCommand};
use crate::events::{DiceRolledEvent, GameOverEvent, NoValidMovesEvent, TokenMovedEvent};

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

pub fn build_ludo_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<SetLudoRulesCommand, _>(|cmd, world| {
        if !world.contains_resource::<LudoRulesConfigResource>() {
            world.insert_resource(LudoRulesConfigResource::default());
        }
        world.insert_resource(LudoRulesConfigResource {
            star_safe_squares: cmd.star_safe_squares,
            bonus_roll_on_capture_and_goal: cmd.bonus_roll_on_capture_and_goal,
            three_sixes_penalty: cmd.three_sixes_penalty,
        });
        Ok(vec![])
    });

    rules.register::<RollDiceCommand, _>(|cmd, world| {
        if !world.contains_resource::<ConsecutiveSixesResource>() {
            world.insert_resource(ConsecutiveSixesResource::default());
        }
        if !world.contains_resource::<LudoRulesConfigResource>() {
            world.insert_resource(LudoRulesConfigResource::default());
        }

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

        let (three_sixes_triggered, current_six_count) = {
            let config = world
                .get_resource::<LudoRulesConfigResource>()
                .copied()
                .unwrap_or_default();
            let mut sixes = world.resource_mut::<ConsecutiveSixesResource>();
            if value == 6 {
                let entry = sixes.count.entry(cmd.player).or_insert(0);
                *entry += 1;
                if *entry == 3 && config.three_sixes_penalty {
                    *entry = 0;
                    (true, 3)
                } else {
                    (false, *entry)
                }
            } else {
                sixes.count.insert(cmd.player, 0);
                (false, 0)
            }
        };

        if three_sixes_triggered {
            world
                .resource_mut::<PendingRollResource>()
                .pending
                .remove(&cmd.player);
            world.resource_mut::<TurnResource>().0.advance();
            let events: Vec<Box<dyn Event>> = vec![
                Box::new(DiceRolledEvent {
                    player: cmd.player,
                    value,
                }),
                Box::new(NoValidMovesEvent {
                    player: cmd.player,
                    value: 6,
                }),
            ];
            return Ok(events);
        }

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

        let _ = current_six_count;
        Ok(events)
    });

    rules.register::<MoveTokenCommand, _>(|cmd, world| {
        if !world.contains_resource::<ConsecutiveSixesResource>() {
            world.insert_resource(ConsecutiveSixesResource::default());
        }
        if !world.contains_resource::<LudoRulesConfigResource>() {
            world.insert_resource(LudoRulesConfigResource::default());
        }

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

        if !world.resource::<TokensResource>().is_valid_move_for_token(
            cmd.player,
            cmd.token_index,
            roll,
        ) {
            return Err(invalid("movimiento inválido para la ficha seleccionada"));
        }

        world
            .resource_mut::<PendingRollResource>()
            .pending
            .remove(&cmd.player);

        let config = world
            .get_resource::<LudoRulesConfigResource>()
            .copied()
            .unwrap_or_default();

        let mut tokens = world.resource_mut::<TokensResource>();
        let current_steps = tokens.tokens[&cmd.player][cmd.token_index];

        let new_steps = if current_steps == 0 {
            1 // entra al tablero
        } else {
            current_steps + roll
        };

        // Captura: si la nueva posición coincide con una ficha rival en
        // el tramo compartido, esa ficha vuelve a la base. Nunca aplica
        // en la base, tramo final o en casillas seguras (salidas y estrellas si configurado).
        let mut captured = None;
        if let Some(landing) = tokens.board_position(cmd.player, new_steps) {
            let is_safe = tokens.is_safe_square_with_config(landing, config.star_safe_squares);
            if !is_safe {
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

        // Determinar si gana turno extra:
        // - Sacar 6 siempre da turno extra
        // - Si bonus_roll_on_capture_and_goal está activo, capturar o terminar una ficha da turno extra
        let gains_bonus_turn = roll == 6
            || (config.bonus_roll_on_capture_and_goal && (captured.is_some() || finished));

        if !all_finished && !gains_bonus_turn {
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

        Ok(vec![Box::new(GameOverEvent {
            winner: opponent,
        })])
    });

    rules
}

