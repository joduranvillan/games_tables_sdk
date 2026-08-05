//! Batalla Naval: juego de referencia para 2 jugadores.
//! Maneja información oculta (ubicación de barcos), fase de colocación
//! de flotas y disparos por turnos.

pub mod commands;
pub mod events;
pub mod fleet;
pub mod position;
pub mod rules;

pub use commands::{FireShotCommand, PlaceFleetCommand, RematchCommand};
pub use events::{FleetPlacedEvent, GameOverEvent, ShotResult, ShotResultEvent, SunkenShipEvent};
pub use fleet::{FleetResource, RematchResource, Ship, ShotsResource, EXPECTED_SHIP_SIZES};
pub use position::{Position, BOARD_SIZE};
pub use rules::build_battleship_rules;

use open_table_engine::prelude::*;

pub fn new_battleship_session(session_id: SessionId, seed: u64, player_a: PlayerId, player_b: PlayerId) -> Session {
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
}

