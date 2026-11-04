// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlaceStoneCommand {
    #[issuer]
    pub player: PlayerId,
    pub x: usize,
    pub y: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PassCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlaceHandicapCommand {
    #[issuer]
    pub player: PlayerId,
    pub positions: Vec<(u8, u8)>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct MarkDeadCommand {
    #[issuer]
    pub player: PlayerId,
    pub positions: Vec<(u8, u8)>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ConfirmDeadCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct SetKomiCommand {
    #[issuer]
    pub player: PlayerId,
    pub komi_half_points: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct SetBoardSizeCommand {
    #[issuer]
    pub player: PlayerId,
    pub size: usize,
}
