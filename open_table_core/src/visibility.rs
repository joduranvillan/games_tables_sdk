// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

use crate::ids::{PlayerId, SpectatorId};

/// Visibilidad específica para espectadores de la sesión.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum SpectatorVisibility {
    /// Todos los espectadores de la sesión lo ven.
    AllSpectators,
    /// Solo estos espectadores específicos lo ven.
    Spectators(Vec<SpectatorId>),
}

/// A quién le llega un `Event`. Esto es lo que permite que el mismo core
/// sirva tanto para un juego sin información oculta (Monopoly: todo es
/// `Public`) como para uno con manos privadas (cartas: `Owner`) o zonas
/// parcialmente visibles (fog of war: `Players`).
///
/// El host filtra los eventos según esta visibilidad antes de hacer
/// `broadcast`. Ningún cliente recibe nunca un evento fuera de su alcance:
/// no es un filtro de UI, es un filtro de red.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Visibility {
    /// Todos los jugadores de la sesión lo ven.
    Public,
    /// Solo estos jugadores lo ven (ej: los jugadores de una alianza).
    Players(Vec<PlayerId>),
    /// Solo los jugadores pertenecientes al grupo específico lo ven.
    PrivateToGroup(Vec<PlayerId>),
    /// Solo un jugador lo ve (ej: "estas son tus cartas").
    Owner(PlayerId),
    /// Nadie más que el host lo ve (uso interno / debug / replay).
    HostOnly,
    /// Visible para espectadores según la regla especificada.
    Spectators(SpectatorVisibility),
}

impl Visibility {
    pub fn includes(&self, player: PlayerId) -> bool {
        match self {
            Visibility::Public => true,
            Visibility::Players(list) => list.contains(&player),
            Visibility::PrivateToGroup(list) => list.contains(&player),
            Visibility::Owner(owner) => *owner == player,
            Visibility::HostOnly => false,
            Visibility::Spectators(_) => false,
        }
    }

    pub fn includes_spectator(&self, spectator: SpectatorId) -> bool {
        match self {
            Visibility::Public => true,
            Visibility::Spectators(SpectatorVisibility::AllSpectators) => true,
            Visibility::Spectators(SpectatorVisibility::Spectators(list)) => {
                list.contains(&spectator)
            }
            Visibility::Players(_)
            | Visibility::PrivateToGroup(_)
            | Visibility::Owner(_)
            | Visibility::HostOnly => false,
        }
    }
}
