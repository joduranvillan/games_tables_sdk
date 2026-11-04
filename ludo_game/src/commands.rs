// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct RollDiceCommand {
    #[issuer]
    pub player: PlayerId,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct MoveTokenCommand {
    #[issuer]
    pub player: PlayerId,
    pub token_index: usize,
}

/// Permite configurar dinámicamente las reglas opcionales de Ludo
/// (tres 6 seguidos, turno extra por captura/meta, casillas estrella).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct SetLudoRulesCommand {
    #[serde(default)]
    pub star_safe_squares: bool,
    #[serde(default)]
    pub bonus_roll_on_capture_and_goal: bool,
    #[serde(default)]
    pub three_sixes_penalty: bool,
}

/// Permite a un jugador rendirse y conceder la partida.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
