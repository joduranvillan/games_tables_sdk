use open_table_engine::prelude::*;
use open_table_macros::GameEvent;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct StonePlacedEvent {
    pub player: PlayerId,
    pub x: usize,
    pub y: usize,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct StonesCapturedEvent {
    pub player: PlayerId, // player who captured
    pub count: usize,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct PassedEvent {
    pub player: PlayerId,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: Option<PlayerId>,
    pub reason: String,
}
