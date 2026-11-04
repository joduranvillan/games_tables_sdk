// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use crate::board::{Card, CardColor};
use open_table_engine::prelude::*;
use open_table_macros::GameEvent;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct CardPlayedEvent {
    pub player: PlayerId,
    pub card: Card,
    pub new_color: CardColor,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct CardsDrawnEvent {
    pub player: PlayerId,
    pub count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct TurnReversedEvent;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PlayerSkippedEvent {
    pub skipped_player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct DrewAndPlayedEvent {
    pub player: PlayerId,
    pub card: Card,
    pub new_color: CardColor,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct InterceptedEvent {
    pub player: PlayerId,
    pub card: Card,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct UnoCalledEvent {
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct UnoPenaltyEvent {
    pub target: PlayerId,
    pub accuser: PlayerId,
    pub drawn: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct WildDrawFourChallengedEvent {
    pub challenger: PlayerId,
    pub target: PlayerId,
    pub was_illegal: bool,
    pub penalty_player: PlayerId,
    pub cards_drawn: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct ColorChangedEvent {
    pub color: CardColor,
}
