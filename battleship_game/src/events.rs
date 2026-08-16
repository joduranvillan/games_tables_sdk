use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

use crate::position::Position;

/// Público a propósito, pero SIN las coordenadas de los barcos — solo
/// confirma que la fase de setup avanzó. Comparar con `checkers_game`,
/// donde no hace falta este cuidado porque no hay nada que ocultar.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct FleetPlacedEvent {
    pub player: PlayerId,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ShotResult {
    Miss,
    Hit,
    Sunk,
}

/// Público: en batalla naval, todos los jugadores ven dónde disparó cada
/// uno y si acertó — lo único oculto es la posición de los barcos que
/// TODAVÍA no fueron tocados.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct ShotResultEvent {
    pub shooter: PlayerId,
    pub target: Position,
    pub result: ShotResult,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct SunkenShipEvent {
    pub player: PlayerId,
    pub ship_type: usize,
    pub positions: Vec<Position>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: Option<PlayerId>,
}
