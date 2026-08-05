use open_table_macros::GameCommand;
use open_table_core::ids::PlayerId;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct PlaceStoneCommand {
    #[issuer]
    pub player: PlayerId,
    pub x: usize,
    pub y: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct PassCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct PlaceHandicapCommand {
    #[issuer]
    pub player: PlayerId,
    pub positions: Vec<(u8, u8)>,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct MarkDeadCommand {
    #[issuer]
    pub player: PlayerId,
    pub positions: Vec<(u8, u8)>,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct ConfirmDeadCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
