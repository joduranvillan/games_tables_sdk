use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;

use crate::position::Position;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct MovePegCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: Position,
    pub to: Position,
    #[serde(default)]
    pub path: Vec<Position>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
