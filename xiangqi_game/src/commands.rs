// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct MovePieceCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: (usize, usize),
    pub to: (usize, usize),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
