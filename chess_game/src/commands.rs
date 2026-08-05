use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;

use crate::position::{PieceKind, Position};

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct MovePieceCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: Position,
    pub to: Position,
    #[serde(default)]
    pub promote_to: Option<PieceKind>,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct OfferDrawCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct AcceptDrawCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
