// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;
use serde::{Deserialize, Serialize};

use crate::board::TerritoryId;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlaceArmiesCommand {
    #[issuer]
    pub player: PlayerId,
    pub territory: TerritoryId,
    pub count: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct DeclareAttackCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: TerritoryId,
    pub to: TerritoryId,
    pub dice: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct RollAttackCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct FortifyCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: TerritoryId,
    pub to: TerritoryId,
    pub armies: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct EndPhaseCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ExchangeCardsCommand {
    #[issuer]
    pub player: PlayerId,
    pub card_indices: [usize; 3],
}
