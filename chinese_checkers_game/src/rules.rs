use open_table_engine::prelude::*;

use crate::board::BoardResource;
use crate::commands::MovePegCommand;
use crate::events::{GameOverEvent, PegMovedEvent};
use crate::position::DIRECTIONS;

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

pub fn build_chinese_checkers_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<MovePegCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        if !cmd.from.is_on_board() || !cmd.to.is_on_board() {
            return Err(invalid("esa posición está fuera del tablero"));
        }

        let mut board = world.resource_mut::<BoardResource>();

        if board.pegs.get(&cmd.from) != Some(&cmd.player) {
            return Err(invalid("no tenés una ficha tuya en esa posición"));
        }
        if board.pegs.contains_key(&cmd.to) {
            return Err(invalid("la casilla de destino ya está ocupada"));
        }

        let mut steps = vec![cmd.from];
        if !cmd.path.is_empty() {
            for &p in &cmd.path {
                if steps.last() != Some(&p) {
                    steps.push(p);
                }
            }
        } else {
            steps.push(cmd.to);
        }

        if steps.last() != Some(&cmd.to) {
            return Err(invalid("el camino especificado no termina en la posición de destino"));
        }

        let was_jump = if steps.len() == 2 {
            let from = steps[0];
            let to = steps[1];
            let delta = from.delta_to(to);
            let is_step = DIRECTIONS.contains(&delta);
            let is_even = delta.0 % 2 == 0 && delta.1 % 2 == 0;
            let is_jump = is_even && DIRECTIONS.contains(&(delta.0 / 2, delta.1 / 2));

            if is_step {
                false
            } else if is_jump {
                let mid = from.add((delta.0 / 2, delta.1 / 2));
                if !board.pegs.contains_key(&mid) {
                    return Err(invalid("un salto tiene que pasar por encima de una ficha"));
                }
                true
            } else {
                return Err(invalid(
                    "movimiento inválido: tiene que ser un paso a una casilla adyacente o un salto sobre una ficha",
                ));
            }
        } else {
            // Chained jumps: every segment must be a valid jump
            for i in 0..steps.len() - 1 {
                let curr = steps[i];
                let next = steps[i + 1];

                if !next.is_on_board() {
                    return Err(invalid("una casilla intermedia está fuera del tablero"));
                }
                if next != cmd.to && board.pegs.contains_key(&next) {
                    return Err(invalid("una casilla intermedia está ocupada"));
                }

                let delta = curr.delta_to(next);
                let is_even = delta.0 % 2 == 0 && delta.1 % 2 == 0;
                let is_jump = is_even && DIRECTIONS.contains(&(delta.0 / 2, delta.1 / 2));

                if !is_jump {
                    return Err(invalid("cada paso en una cadena de saltos debe ser un salto válido sobre una ficha"));
                }

                let mid = curr.add((delta.0 / 2, delta.1 / 2));
                if !board.pegs.contains_key(&mid) {
                    return Err(invalid("cada salto debe pasar por encima de una ficha"));
                }
            }
            true
        };

        board.pegs.remove(&cmd.from);
        board.pegs.insert(cmd.to, cmd.player);

        let won = board.has_won(cmd.player);

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PegMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            was_jump,
        })];

        if won {
            events.push(Box::new(GameOverEvent {
                winner: Some(cmd.player),
            }));
        }

        world.resource_mut::<TurnResource>().0.advance();

        Ok(events)
    });

    rules
}
