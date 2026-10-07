//! Monopoly estándar de 40 casillas:
//! - 28 propiedades (22 calles + 4 estaciones + 2 suministros)
//! - GO, Cárcel (visita), Parking Gratuito, Ve a la Cárcel
//! - 6 casillas de Suerte/Arca Comunitaria (3 cada una)
//! - Impuesto sobre la Renta (200$), Impuesto de Lujo (100$)

pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod resources;
pub mod rules;

pub use ai::{
    best_move, completes_color_group, space_market_price, MonopolyCommand, MonopolyState,
};
pub use board::{
    board_layout, ChanceCard, CommunityChestCard, Space, SpaceKind, BOARD_SIZE, GO_BONUS,
    GO_TO_JAIL_SPACE, JAIL_SPACE, STARTING_MONEY,
};
pub use commands::{AuctionBidCommand, BuyPropertyCommand, PayJailFeeCommand, RollAndMoveCommand};
pub use events::{
    AuctionStartedEvent, AuctionWonEvent, BankruptcyEvent, ChanceCardDrawnEvent,
    CommunityChestCardDrawnEvent, GameOverEvent, JailedEvent, PlayerMovedEvent,
    PropertyPurchasedEvent, RailroadRentPaidEvent, RentPaidEvent, TaxPaidEvent,
    UtilityRentPaidEvent,
};
pub use resources::{
    AuctionResource, BoardResource, JailResource, PendingPurchaseResource, PlayersResource,
};
pub use rules::{apply_land_effect, build_monopoly_rules};

use open_table_engine::prelude::*;

pub fn new_monopoly_session(
    session_id: SessionId,
    seed: u64,
    player_a: PlayerId,
    player_b: PlayerId,
) -> Session {
    let players = vec![player_a, player_b];
    let mut session = Session::new_with_metadata(
        session_id,
        "Monopoly",
        seed,
        players.clone(),
        build_monopoly_rules(),
    );
    session.world_mut().insert_resource(BoardResource::new());
    session
        .world_mut()
        .insert_resource(PlayersResource::new(&players));
    session
        .world_mut()
        .insert_resource(PendingPurchaseResource::default());
    session.world_mut().insert_resource(JailResource::default());
    session
        .world_mut()
        .insert_resource(AuctionResource::default());
    session
}
