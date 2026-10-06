//! # `open_table_core`
//!
//! Core traits and types for deterministic turn-based board game engines.
//!
//! # Examples
//!
//! ```rust
//! use open_table_core::prelude::*;
//!
//! let p1 = PlayerId(1);
//! let p2 = PlayerId(2);
//! let diff = AiDifficulty::from_i64(2);
//! assert_eq!(diff, AiDifficulty::Hard);
//! assert_eq!(diff.max_depth(), 3);
//! assert!(diff.use_opening_book());
//!
//! let result = GameResult {
//!     winner: Some(p1),
//!     duration_ms: 15_000,
//!     total_moves: 42,
//!     players: vec![p1, p2],
//!     game_name: "chess".to_string(),
//! };
//! assert_eq!(result.winner, Some(PlayerId(1)));
//! ```
#![doc = include_str!("../README.md")]

use serde::{Deserialize, Serialize};

pub mod command;
pub mod component;
pub mod error;
pub mod event;
pub mod game_variant;
pub mod ids;
pub mod random;
pub mod resource;
pub mod time;
pub mod transport;
pub mod visibility;

/// Nivel de dificultad parametrizable para los motores de IA locales.
///
/// # Examples
///
/// ```rust
/// use open_table_core::AiDifficulty;
///
/// let difficulty = AiDifficulty::from_i64(3);
/// assert_eq!(difficulty, AiDifficulty::Expert);
/// assert_eq!(difficulty.max_depth(), 4);
/// assert_eq!(difficulty.rollouts(), 300);
/// assert!(difficulty.use_opening_book());
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
pub enum AiDifficulty {
    /// Nivel Fácil (profundidad 1, 50 rollouts, errores ocasionales 1 de cada 4 jugadas).
    Easy = 0,
    /// Nivel Medio (profundidad 2, 120 rollouts).
    #[default]
    Medium = 1,
    /// Nivel Difícil (profundidad 3, 200 rollouts).
    Hard = 2,
    /// Nivel Experto (profundidad 4, 300 rollouts).
    Expert = 3,
}

impl AiDifficulty {
    /// Convierte un entero (`0=Easy, 1=Medium, 2=Hard, 3=Expert`) en `AiDifficulty` (por defecto `Medium`).
    pub fn from_i64(value: i64) -> Self {
        match value {
            0 => Self::Easy,
            1 => Self::Medium,
            2 => Self::Hard,
            3 => Self::Expert,
            _ => Self::Medium,
        }
    }

    /// Profundidad máxima de búsqueda para algoritmos Minimax.
    pub fn max_depth(self) -> u8 {
        match self {
            Self::Easy => 1,
            Self::Medium => 2,
            Self::Hard => 3,
            Self::Expert => 4,
        }
    }

    /// Presupuesto total de simulaciones (rollouts) para MCTS / Monte Carlo.
    pub fn rollouts(self) -> usize {
        match self {
            Self::Easy => 50,
            Self::Medium => 120,
            Self::Hard => 200,
            Self::Expert => 300,
        }
    }

    /// Indica si este nivel de dificultad consulta el libro de aperturas teóricas (`Hard` y `Expert`).
    pub fn use_opening_book(self) -> bool {
        matches!(self, Self::Hard | Self::Expert)
    }
}

/// Resultado final de una partida.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GameResult {
    pub winner: Option<ids::PlayerId>,
    pub duration_ms: u64,
    pub total_moves: u32,
    pub players: Vec<ids::PlayerId>,
    pub game_name: String,
}

/// Import único que necesita cualquier juego para arrancar:
/// `use open_table_core::prelude::*;`
pub mod prelude {
    pub use crate::command::{Command, CommandEnvelope};
    pub use crate::component::Component;
    pub use crate::error::{EngineError, EngineResult};
    pub use crate::event::{Event, EventEnvelope};
    pub use crate::game_variant::GameVariant;
    pub use crate::ids::{EntityId, PlayerId, SessionId, SpectatorId, Tick};
    pub use crate::random::RandomService;
    pub use crate::resource::Resource;
    pub use crate::time::GameClock;
    pub use crate::transport::Transport;
    pub use crate::visibility::{SpectatorVisibility, Visibility};
    pub use crate::{AiDifficulty, GameResult};
}
