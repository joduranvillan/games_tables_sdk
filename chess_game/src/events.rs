use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

use crate::position::{PieceKind, Position};

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct PieceMovedEvent {
    pub player: PlayerId,
    pub from: Position,
    pub to: Position,
    pub captured: Option<PieceKind>,
    pub promoted: bool,
    pub opponent_in_check: bool,
    #[serde(default)]
    pub castled: bool,
    #[serde(default)]
    pub promoted_to: Option<PieceKind>,
}

/// `winner: None` significa tablas (ahogado: el rival no está en jaque
/// pero no tiene ningún movimiento legal).
#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: Option<PlayerId>,
}
