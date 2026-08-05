//! Monopoly muy simplificado: séptimo juego de referencia. Ejercita una
//! decisión de jugador que SUSPENDE el avance de turno hasta que
//! responde (comprar o no la propiedad donde cayó) — patrón útil para
//! cualquier juego con una decisión intermedia dentro del mismo turno,
//! distinto del patrón roll-then-act de Ludo/Backgammon (ahí siempre hay
//! que actuar, acá la decisión es opcional).
//!
//! Simplificaciones grandes respecto al juego real: tablero de 16
//! casillas (no 40), sin casas/hoteles, sin cartas de Suerte/Caja de
//! Comunidad, sin cárcel, sin subastas, sin hipotecas, sin intercambios
//! entre jugadores. Bancarrota simplificada: si el dinero queda negativo
//! tras pagar una renta, se termina la partida (2 jugadores).

pub mod board;
pub mod commands;
pub mod events;
pub mod resources;
pub mod rules;

pub use board::{Space, GO_BONUS, GO_TO_JAIL_SPACE, JAIL_SPACE, STARTING_MONEY};
pub use commands::{AuctionBidCommand, BuyPropertyCommand, PayJailFeeCommand, RollAndMoveCommand};
pub use events::{
    AuctionStartedEvent, AuctionWonEvent, BankruptcyEvent, GameOverEvent, JailedEvent, PlayerMovedEvent,
    PropertyPurchasedEvent, RailroadRentPaidEvent, RentPaidEvent, UtilityRentPaidEvent,
};
pub use resources::{
    AuctionResource, BoardResource, JailResource, PendingPurchaseResource, PlayersResource,
};
pub use rules::build_monopoly_rules;

use open_table_engine::prelude::*;

pub fn new_monopoly_session(session_id: SessionId, seed: u64, player_a: PlayerId, player_b: PlayerId) -> Session {
    let players = vec![player_a, player_b];
    let mut session = Session::new_with_metadata(
        session_id,
        "Monopoly",
        seed,
        players.clone(),
        build_monopoly_rules(),
    );
    session.world_mut().insert_resource(BoardResource::new());
    session.world_mut().insert_resource(PlayersResource::new(&players));
    session
        .world_mut()
        .insert_resource(PendingPurchaseResource::default());
    session.world_mut().insert_resource(JailResource::default());
    session.world_mut().insert_resource(AuctionResource::default());
    session
}
