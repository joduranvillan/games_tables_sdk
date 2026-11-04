// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;
use open_table_macros::GameEvent;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct StonePlacedEvent {
    pub player: PlayerId,
    pub x: usize,
    pub y: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct StonesCapturedEvent {
    pub player: PlayerId, // player who captured
    pub count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PassedEvent {
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: Option<PlayerId>,
    pub reason: String,
    #[serde(default)]
    pub black_score: f32,
    #[serde(default)]
    pub white_score: f32,
}
