#![doc = include_str!("../README.md")]

pub mod history;
pub mod rule_engine;
pub mod session;
pub mod test_helpers;
pub mod turn;

pub use history::format_command;
pub use turn::TurnResource;

pub mod prelude {
    pub use crate::rule_engine::RuleEngine;
    pub use crate::session::{
        filter_events_for_player, filter_events_for_spectator, CommandMiddleware,
        EventHandlersResource, ForfeitEvent, GameOverResource, GameVariantResource,
        LegalMoveGenerator, LegalMoveGeneratorResource, RandomResource, RateLimitResource,
        ReconnectionTimeoutResource, Session, SessionMetadata, SessionMetadataResource,
        SessionMode, TimerResource, WinnerResource,
    };
    pub use crate::turn::{TurnOrder, TurnResource};
    pub use crate::{advance_turn, force_turn};
    pub use bevy_ecs::world::World;
    pub use bevy_ecs::world::World as BevyWorld;
    pub use open_table_core::prelude::*;
}
