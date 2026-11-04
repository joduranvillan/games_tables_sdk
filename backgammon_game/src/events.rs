// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct DiceRolledEvent {
    pub player: PlayerId,
    pub values: Vec<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct CheckerMovedEvent {
    pub player: PlayerId,
    pub from: Option<usize>,
    /// `None` si la ficha se sacó del tablero (bear-off) en este
    /// movimiento.
    pub to: Option<usize>,
    pub captured_opponent: bool,
    pub borne_off: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct NoValidMovesEvent {
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
    pub gammon: bool,
    pub backgammon: bool,
    pub score: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct DoubleOfferedEvent {
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct DoubleAcceptedEvent {
    pub player: PlayerId,
    pub value: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct DoubleRejectedEvent {
    pub player: PlayerId,
    pub value: u32,
}
