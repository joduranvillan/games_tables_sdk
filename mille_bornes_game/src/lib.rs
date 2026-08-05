//! Mil Millas (Mille Bornes): juego de cartas de referencia.
//! Maneja manos privadas, descarte de cartas, restricción por límite
//! de velocidad (máximo 50 km), rebarajado de la pila de descarte al vaciarse
//! el mazo, peligros, remedios y avance hasta la meta.

pub mod card;
pub mod commands;
pub mod deck;
pub mod events;
pub mod rules;

pub use card::{Card, Hazard, Safety};
pub use commands::{
    CoupFourreCommand, DiscardCardCommand, DrawCardCommand, PlayCardCommand, PlayDistanceCommand,
    PlayHazardCommand, PlaySafetyCommand, SetupDeckCommand,
};
pub use deck::{DeckResource, MAX_HAND_SIZE, TARGET_DISTANCE};
pub use events::{
    CardDiscardedEvent, CardDrawnEvent, DistancePlayedEvent, GameOverEvent, HazardPlayedEvent,
    RemedyPlayedEvent, SafetyPlayedEvent, TripExtendedEvent,
};
pub use rules::{build_mille_bornes_rules, RightOfWayResource, SpeedLimitResource};

use open_table_engine::prelude::*;

/// Arma la Session y la deja lista para jugar: ya corrió el
/// `SetupDeckCommand` (mazo barajado, manos iniciales repartidas).
pub fn new_mille_bornes_session(session_id: SessionId, seed: u64, player_a: PlayerId, player_b: PlayerId) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Mille Bornes",
        seed,
        vec![player_a, player_b],
        build_mille_bornes_rules(),
    );
    session.world_mut().insert_resource(DeckResource::default());
    session.world_mut().insert_resource(SpeedLimitResource::default());
    session.world_mut().insert_resource(RightOfWayResource::default());

    // El comando de setup no tiene issuer, así que cualquier "sender" es
    // válido para la validación de identidad — usamos el primer jugador
    // por convención, no importa cuál, ya que `issuer()` es `None` acá.
    session
        .process_command(player_a, Box::new(SetupDeckCommand))
        .expect("el setup del mazo no debería poder fallar");

    session
}
