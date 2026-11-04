// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use crate::board::PieceKind;
use open_table_engine::prelude::*;
use open_table_macros::GameEvent;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PieceMovedEvent {
    pub player: PlayerId,
    pub from: (usize, usize),
    pub to: (usize, usize),
    pub promoted: bool,
    pub captured: Option<PieceKind>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PieceDroppedEvent {
    pub player: PlayerId,
    pub piece: PieceKind,
    pub to: (usize, usize),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: Option<PlayerId>,
}
