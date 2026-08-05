use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

use crate::position::Position;

/// Damas no tiene información oculta: este evento es público (visibilidad
/// default de `#[derive(GameEvent)]`, todos los jugadores lo ven).
#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct PieceMovedEvent {
    pub player: PlayerId,
    pub from: Position,
    pub to: Position,
    pub captured: Option<Position>,
    pub promoted: bool,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}
