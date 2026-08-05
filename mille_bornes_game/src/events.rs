use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;

use crate::card::{Card, Hazard, Safety};

/// Privado a propósito: solo el dueño de la mano sabe qué carta robó.
#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct CardDrawnEvent {
    #[owner]
    pub player: PlayerId,
    pub card: Card,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct DistancePlayedEvent {
    pub player: PlayerId,
    pub value: u32,
    pub new_distance: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct HazardPlayedEvent {
    pub player: PlayerId,
    pub target: PlayerId,
    pub hazard: Hazard,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct RemedyPlayedEvent {
    pub player: PlayerId,
    pub hazard: Hazard,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct SafetyPlayedEvent {
    pub player: PlayerId,
    pub safety: Safety,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct TripExtendedEvent {
    pub new_target: u32,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct CardDiscardedEvent {
    pub player: PlayerId,
    pub card: Card,
}

#[derive(Debug, Serialize, Deserialize, GameEvent)]
pub struct GameOverEvent {
    pub winner: PlayerId,
}
