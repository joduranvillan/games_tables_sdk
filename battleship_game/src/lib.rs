// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Batalla Naval: juego de referencia para 2 jugadores.
//! Maneja información oculta (ubicación de barcos), fase de colocación
//! de flotas y disparos por turnos.

pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod fleet;
pub mod position;
pub mod rules;

pub use ai::{
    best_move, compute_probability_density_map, default_ai_fleet, default_ai_place_fleet_command,
    BattleshipCommand, BattleshipState,
};
pub use board::BOARD_SIZE;
pub use commands::{
    FireShotCommand, PlaceFleetCommand, RematchCommand, ResignCommand, SetBattleshipRulesCommand,
};
pub use events::{FleetPlacedEvent, GameOverEvent, ShotResult, ShotResultEvent, SunkenShipEvent};
pub use fleet::{
    BattleshipConfigResource, FleetResource, RematchResource, Ship, ShotsResource,
    EXPECTED_SHIP_SIZES,
};
pub use position::Position;
pub use rules::build_battleship_rules;

use open_table_engine::prelude::*;

pub fn new_battleship_session(
    session_id: SessionId,
    seed: u64,
    player_a: PlayerId,
    player_b: PlayerId,
) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Battleship",
        seed,
        vec![player_a, player_b],
        build_battleship_rules(),
    );
    session.world_mut().insert_resource(FleetResource::new());
    session.world_mut().insert_resource(ShotsResource::new());
    session.world_mut().insert_resource(RematchResource::new());
    session
        .world_mut()
        .insert_resource(BattleshipConfigResource::default());
    session
}
