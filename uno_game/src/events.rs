use open_table_engine::prelude::*;
use open_table_macros::GameEvent;
use serde::{Deserialize, Serialize};
use crate::board::{Card, CardColor};

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct CardPlayedEvent {
    pub player: PlayerId,
    pub card: Card,
    pub new_color: CardColor,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct CardsDrawnEvent {
    pub player: PlayerId,
    pub count: usize,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct TurnReversedEvent;

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct PlayerSkippedEvent {
    pub skipped_player: PlayerId,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct DrewAndPlayedEvent {
    pub player: PlayerId,
    pub card: Card,
    pub new_color: CardColor,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct InterceptedEvent {
    pub player: PlayerId,
    pub card: Card,
}
