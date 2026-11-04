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

/// `from = None` significa "entrar desde la barra". `die` es el valor
/// de dado pendiente que se usa para este movimiento — el destino se
/// calcula solo a partir de `from` + dirección del jugador + `die`
/// (o el punto de entrada, si viene de la barra).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct MoveCheckerCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: Option<usize>,
    pub die: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct OfferDoubleCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct AcceptDoubleCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct RejectDoubleCommand {
    #[issuer]
    pub player: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
