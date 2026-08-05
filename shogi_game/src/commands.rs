use open_table_macros::GameCommand;
use open_table_core::ids::PlayerId;
use crate::board::PieceKind;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct MovePieceCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: (usize, usize),
    pub to: (usize, usize),
    pub promote: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct DropPieceCommand {
    #[issuer]
    pub player: PlayerId,
    pub piece: PieceKind,
    pub to: (usize, usize),
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
