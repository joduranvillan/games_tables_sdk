use open_table_core::ids::PlayerId;
use open_table_macros::GameEvent;
use serde::{Deserialize, Serialize};

use crate::board::TerritoryId;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CardType {
    Infantry,
    Cavalry,
    Cannon,
    Wild,
}

pub type CardSymbol = CardType;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TerritoryCard {
    pub territory: TerritoryId,
    pub card_type: CardType,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct TerritoryClaimedEvent {
    pub player: PlayerId,
    pub territory: TerritoryId,
    pub armies: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct ArmiesPlacedEvent {
    pub player: PlayerId,
    pub territory: TerritoryId,
    pub count: u32,
    pub armies_remaining: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct AttackDeclaredEvent {
    pub attacker: PlayerId,
    pub from: TerritoryId,
    pub to: TerritoryId,
    pub dice: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct AttackResolvedEvent {
    pub attacker: PlayerId,
    pub defender: PlayerId,
    pub from: TerritoryId,
    pub to: TerritoryId,
    pub attacker_rolls: Vec<u32>,
    pub defender_rolls: Vec<u32>,
    pub attacker_losses: u32,
    pub defender_losses: u32,
    pub territory_conquered: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct TerritoryConqueredEvent {
    pub player: PlayerId,
    pub territory: TerritoryId,
    pub from: TerritoryId,
    pub from_armies: u32,
    pub to_armies: u32,
    pub card_drawn: Option<TerritoryCard>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PlayerEliminatedEvent {
    pub player: PlayerId,
    pub by: PlayerId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct FortifiedEvent {
    pub player: PlayerId,
    pub from: TerritoryId,
    pub to: TerritoryId,
    pub armies: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct CardsExchangedEvent {
    pub player: PlayerId,
    pub armies_gained: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct PhaseChangedEvent {
    pub player: PlayerId,
    pub new_phase: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameEvent)]
pub struct TegGameOverEvent {
    pub winner: PlayerId,
    pub objective: String,
}
