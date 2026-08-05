use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct DiceRolledEvent {
    pub player: PlayerId,
    pub value: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct TokenMovedEvent {
    pub player: PlayerId,
    pub token_index: usize,
    pub from_steps: u32,
    pub to_steps: u32,
    /// Si esta jugada mandó una ficha rival de vuelta a la base.
    pub captured: Option<(PlayerId, usize)>,
    pub finished: bool,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct NoValidMovesEvent {
    pub player: PlayerId,
    pub value: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}
