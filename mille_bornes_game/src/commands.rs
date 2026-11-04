// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;

use crate::card::{Hazard, Safety};

/// Comando de sistema (sin `#[issuer]`, así que `issuer()` devuelve
/// `None`): arma y baraja el mazo, reparte las manos iniciales. Se manda
/// una sola vez, al arrancar la partida — pasar esto por el `RuleEngine`
/// en vez de hacerlo "afuera" antes de crear la `Session` es lo que
/// permite que el barajado quede en el log de comandos y el replay lo
/// reproduzca exactamente igual.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct SetupDeckCommand;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct DrawCardCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlayCardCommand {
    #[issuer]
    pub player: PlayerId,
    pub card_index: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlayDistanceCommand {
    #[issuer]
    pub player: PlayerId,
    pub distance: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlayHazardCommand {
    #[issuer]
    pub player: PlayerId,
    pub target: PlayerId,
    pub hazard: Hazard,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlaySafetyCommand {
    #[issuer]
    pub player: PlayerId,
    pub safety: Safety,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct DiscardCardCommand {
    #[issuer]
    pub player: PlayerId,
    pub card_index: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct CoupFourreCommand {
    #[issuer]
    pub player: PlayerId,
}
