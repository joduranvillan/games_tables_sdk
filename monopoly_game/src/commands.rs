use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct RollAndMoveCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct BuyPropertyCommand {
    #[issuer]
    pub player: PlayerId,
    pub buy: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PayJailFeeCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct AuctionBidCommand {
    #[issuer]
    pub player: PlayerId,
    pub amount: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct BuildHouseCommand {
    #[issuer]
    pub player: PlayerId,
    pub space: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct SellHouseCommand {
    #[issuer]
    pub player: PlayerId,
    pub space: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct MortgagePropertyCommand {
    #[issuer]
    pub player: PlayerId,
    pub space: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct UnmortgagePropertyCommand {
    #[issuer]
    pub player: PlayerId,
    pub space: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct UseJailCardCommand {
    #[issuer]
    pub player: PlayerId,
}
