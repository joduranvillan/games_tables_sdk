use open_table_macros::GameCommand;
use open_table_core::ids::PlayerId;
use crate::board::CardColor;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct PlayCardCommand {
    #[issuer]
    pub player: PlayerId,
    pub card_index: usize,
    pub chosen_color: Option<CardColor>,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct DrawCardCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct InterceptCommand {
    #[issuer]
    pub player: PlayerId,
    pub card_index: usize,
}
