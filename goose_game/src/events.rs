// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct DiceRolledEvent {
    pub player: PlayerId,
    pub value: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GooseMovedEvent {
    pub player: PlayerId,
    pub from_square: u8,
    pub raw_square: u8,
    pub to_square: u8,
    pub bonus_turn: bool,
    pub wait_turns: u8,
    pub effect: String,
    pub finished: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct TurnSkippedEvent {
    pub player: PlayerId,
    pub remaining_wait: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}
