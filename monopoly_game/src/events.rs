use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

use crate::board::{ChanceCard, CommunityChestCard};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PlayerMovedEvent {
    pub player: PlayerId,
    pub roll: u32,
    pub d1: u32,
    pub d2: u32,
    pub is_doubles: bool,
    pub new_position: usize,
    pub passed_go: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct RentPaidEvent {
    pub payer: PlayerId,
    pub owner: PlayerId,
    pub space: usize,
    pub amount: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PropertyPurchasedEvent {
    pub player: PlayerId,
    pub space: usize,
    pub price: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct JailedEvent {
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct AuctionStartedEvent {
    pub space: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct AuctionWonEvent {
    pub player: PlayerId,
    pub space: usize,
    pub price: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct UtilityRentPaidEvent {
    pub player: PlayerId,
    pub owner: PlayerId,
    pub multiplier: u32,
    pub dice_total: u32,
    pub amount: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct RailroadRentPaidEvent {
    pub player: PlayerId,
    pub owner: PlayerId,
    pub railroads_owned: u32,
    pub amount: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct BankruptcyEvent {
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct TaxPaidEvent {
    pub player: PlayerId,
    pub space: usize,
    pub name: String,
    pub amount: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct ChanceCardDrawnEvent {
    pub player: PlayerId,
    pub card: ChanceCard,
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct CommunityChestCardDrawnEvent {
    pub player: PlayerId,
    pub card: CommunityChestCard,
    pub description: String,
}
