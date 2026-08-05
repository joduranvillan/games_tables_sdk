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
    pub use crate::GameResult;
}
