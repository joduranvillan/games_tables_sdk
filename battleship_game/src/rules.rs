// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;

use crate::commands::{
    FireShotCommand, PlaceFleetCommand, RematchCommand, ResignCommand, SetBattleshipRulesCommand,
};
use crate::events::{
    FleetPlacedEvent, GameOverEvent, ShotResult, ShotResultEvent, SunkenShipEvent,
};
use crate::fleet::{
    BattleshipConfigResource, FleetResource, RematchResource, Ship, ShotsResource,
    EXPECTED_SHIP_SIZES,
};
use crate::position::Position;

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

fn are_adjacent(p1: Position, p2: Position) -> bool {
    p1.row.abs_diff(p2.row) <= 1 && p1.col.abs_diff(p2.col) <= 1
}

/// Valida que un barco sea una línea recta contigua de casillas, todas
/// dentro del tablero.
fn validate_ship_shape(ship: &Ship) -> Result<(), EngineError> {
    if !ship.iter().all(Position::is_on_board) {
        return Err(invalid("un barco tiene casillas fuera del tablero"));
    }
    let same_row = ship.iter().all(|p| p.row == ship[0].row);
    let same_col = ship.iter().all(|p| p.col == ship[0].col);
    if !same_row && !same_col {
        return Err(invalid("un barco tiene que ser una línea recta"));
    }
    let mut coords: Vec<u8> = if same_row {
        ship.iter().map(|p| p.col).collect()
    } else {
        ship.iter().map(|p| p.row).collect()
    };
    coords.sort_unstable();
    for window in coords.windows(2) {
        if window[1] != window[0] + 1 {
            return Err(invalid("un barco tiene que ser contiguo, sin huecos"));
        }
    }
    Ok(())
}

pub fn build_battleship_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<SetBattleshipRulesCommand, _>(|cmd, world| {
        if !world.contains_resource::<BattleshipConfigResource>() {
            world.insert_resource(BattleshipConfigResource::default());
        }
        world.insert_resource(BattleshipConfigResource {
            extra_turn_on_hit: cmd.extra_turn_on_hit,
        });
        Ok(vec![])
    });

    rules.register::<PlaceFleetCommand, _>(|cmd, world| {
        if !world.contains_resource::<BattleshipConfigResource>() {
            world.insert_resource(BattleshipConfigResource::default());
        }
        let mut fleet = world.resource_mut::<FleetResource>();

        if fleet.has_placed_fleet(cmd.player) {
            return Err(invalid("ya colocaste tu flota, no se puede cambiar"));
        }

        let mut sizes: Vec<usize> = cmd.ships.iter().map(|s| s.len()).collect();
        sizes.sort_unstable();
        let mut expected = EXPECTED_SHIP_SIZES.to_vec();
        expected.sort_unstable();
        if sizes != expected {
            return Err(invalid(format!(
                "la flota tiene que tener barcos de tamaños {expected:?}, se recibió {sizes:?}"
            )));
        }

        for ship in &cmd.ships {
            validate_ship_shape(ship)?;
        }

        // Ningún barco puede tocar a otro (8 direcciones: horizontal, vertical, diagonal).
        for i in 0..cmd.ships.len() {
            for j in (i + 1)..cmd.ships.len() {
                for cell1 in &cmd.ships[i] {
                    for cell2 in &cmd.ships[j] {
                        if are_adjacent(*cell1, *cell2) {
                            return Err(invalid(
                                "los barcos no pueden tocarse ni ser adyacentes (incluyendo diagonales)",
                            ));
                        }
                    }
                }
            }
        }

        fleet.ships.insert(cmd.player, cmd.ships.clone());
        fleet.hits.insert(cmd.player, Vec::new());

        Ok(vec![Box::new(FleetPlacedEvent { player: cmd.player }) as Box<dyn Event>])
    });

    rules.register::<FireShotCommand, _>(|cmd, world| {
        if !world.contains_resource::<BattleshipConfigResource>() {
            world.insert_resource(BattleshipConfigResource::default());
        }
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }
        if !cmd.target.is_on_board() {
            return Err(invalid("ese disparo cae fuera del tablero"));
        }

        let opponent = world.resource::<TurnResource>().0.peek_next();

        {
            let fleet = world.resource::<FleetResource>();
            if !fleet.has_placed_fleet(cmd.player) || !fleet.has_placed_fleet(opponent) {
                return Err(invalid("todavía no terminó la fase de colocar flotas"));
            }
        }

        {
            let mut shots = world.resource_mut::<ShotsResource>();
            if shots.has_shot(cmd.player, cmd.target) {
                return Err(invalid("ya disparaste a esa casilla previamente"));
            }
            shots.record_shot(cmd.player, cmd.target);
        }

        let mut fleet = world.resource_mut::<FleetResource>();

        let ship_hit = fleet.ship_at(opponent, cmd.target);
        fleet.hits.entry(opponent).or_default().push(cmd.target);

        let result = match &ship_hit {
            None => ShotResult::Miss,
            Some(ship) if fleet.is_ship_sunk(opponent, ship) => ShotResult::Sunk,
            Some(_) => ShotResult::Hit,
        };

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(ShotResultEvent {
            shooter: cmd.player,
            target: cmd.target,
            result,
        })];

        if result == ShotResult::Sunk {
            if let Some(ship) = &ship_hit {
                events.push(Box::new(SunkenShipEvent {
                    player: opponent,
                    ship_type: ship.len(),
                    positions: ship.clone(),
                }));
            }
        }

        let game_over = fleet.all_ships_sunk(opponent);
        if game_over {
            events.push(Box::new(GameOverEvent {
                winner: Some(cmd.player),
            }));
        }
        let _ = fleet;

        if game_over {
            world.insert_resource(GameOverResource(true));
            world.insert_resource(WinnerResource(Some(cmd.player)));
        }

        let extra_turn_on_hit = world
            .get_resource::<BattleshipConfigResource>()
            .map(|c| c.extra_turn_on_hit)
            .unwrap_or(false);

        if !(extra_turn_on_hit && result != ShotResult::Miss && !game_over) {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        if !world.contains_resource::<BattleshipConfigResource>() {
            world.insert_resource(BattleshipConfigResource::default());
        }
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(invalid("no sos un jugador de esta partida"));
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

    rules.register::<RematchCommand, _>(|cmd, world| {
        if !world.contains_resource::<BattleshipConfigResource>() {
            world.insert_resource(BattleshipConfigResource::default());
        }
        let players_count = world.resource::<TurnResource>().0.players().len();

        let should_reset = {
            let mut rematch = world.resource_mut::<RematchResource>();
            rematch.requested.insert(cmd.player);
            rematch.requested.len() == players_count
        };

        if should_reset {
            world.resource_mut::<RematchResource>().requested.clear();

            let mut fleet = world.resource_mut::<FleetResource>();
            fleet.ships.clear();
            fleet.hits.clear();

            let mut shots = world.resource_mut::<ShotsResource>();
            shots.shots.clear();

            world.insert_resource(GameOverResource(false));
            world.insert_resource(WinnerResource(None));

            let mut turn = world.resource_mut::<TurnResource>();
            let players = turn.0.players().to_vec();
            turn.0 = TurnOrder::new(players);

            if let Some(mut rng) = world.get_resource_mut::<RandomResource>() {
                let next_seed = rng.0.next_u32() as u64;
                rng.0 = RandomService::from_seed(next_seed);
            }
        }

        Ok(vec![])
    });

    rules
}
