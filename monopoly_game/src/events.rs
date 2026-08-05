use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct PlayerMovedEvent {
    pub player: PlayerId,
    pub roll: u32,
    pub d1: u32,
    pub d2: u32,
    pub is_doubles: bool,
    pub new_position: usize,
    pub passed_go: bool,
}


#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct RentPaidEvent {
    pub payer: PlayerId,
    pub owner: PlayerId,
    pub space: usize,
    pub amount: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct PropertyPurchasedEvent {
    pub player: PlayerId,
    pub space: usize,
    pub price: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct JailedEvent {
    pub player: PlayerId,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct AuctionStartedEvent {
    pub space: usize,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct AuctionWonEvent {
    pub player: PlayerId,
    pub space: usize,
    pub price: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct UtilityRentPaidEvent {
    pub player: PlayerId,
    pub owner: PlayerId,
    pub multiplier: u32,
    pub dice_total: u32,
    pub amount: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct RailroadRentPaidEvent {
    pub player: PlayerId,
    pub owner: PlayerId,
    pub railroads_owned: u32,
    pub amount: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct BankruptcyEvent {
    pub player: PlayerId,
}
