// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use thiserror::Error;

use crate::ids::PlayerId;

/// Único tipo de error de todo el SDK. Ningún módulo público devuelve
/// `Box<dyn Error>` ni un tipo de error propio: todo se mapea a esta enum.
#[derive(Debug, Error)]
pub enum EngineError {
    #[error("comando inválido: {reason}")]
    InvalidCommand { reason: String },

    #[error("jugador {0:?} no tiene permiso para esta acción")]
    Unauthorized(PlayerId),

    #[error("error de serialización: {0}")]
    Serialization(String),

    #[error("error de red: {0}")]
    Network(String),

    #[error("error de plugin '{plugin}': {reason}")]
    Plugin { plugin: String, reason: String },

    #[error("asset no encontrado")]
    AssetMissing,

    #[error("la partida ya ha terminado")]
    GameAlreadyOver,

    #[error("versión de protocolo no soportada: se esperaba {expected}, se recibió {got}")]
    UnsupportedProtocolVersion { expected: String, got: String },

    #[error("la sesión está pausada")]
    SessionPaused,

    #[error("límite de velocidad excedido para el jugador {0:?}")]
    RateLimitExceeded(PlayerId),

    #[error("error de e/s: {0}")]
    IoError(String),

    #[error("error de replay: {0}")]
    Replay(String),

    #[error("error interno: {0}")]
    Internal(String),
}

pub type EngineResult<T> = Result<T, EngineError>;
