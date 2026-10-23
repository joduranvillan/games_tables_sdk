use crate::board::{Continent, ObjectiveCard, Territory, TerritoryId, CONTINENTS, TERRITORIES};
use crate::events::{CardType, TerritoryCard};
use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type TerritoryMapResource = TerritoryStateResource;
pub type PlayerHandResource = PlayerCardsResource;
pub type TurnPhaseResource = TurnStateResource;

#[derive(GameResource)]
pub struct BoardResource {
    pub territories: &'static [Territory],
    pub continents: &'static [Continent],
}

impl BoardResource {
    pub fn new() -> Self {
        Self {
            territories: TERRITORIES,
            continents: CONTINENTS,
        }
    }
}

impl Default for BoardResource {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(GameResource, Default, Clone)]
pub struct TerritoryStateResource {
    pub owners: HashMap<TerritoryId, PlayerId>,
    pub armies: HashMap<TerritoryId, u32>,
}

impl TerritoryStateResource {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_owner_and_armies(&mut self, territory: TerritoryId, owner: PlayerId, armies: u32) {
        self.owners.insert(territory, owner);
        self.armies.insert(territory, armies);
    }

    pub fn owns_continent(&self, continent: &Continent, player: PlayerId) -> bool {
        continent
            .territories
            .iter()
            .all(|&t_id| self.owners.get(&t_id) == Some(&player))
    }
}

#[derive(GameResource, Default)]
pub struct PlayersResource {
    pub players: Vec<PlayerId>,
}

impl PlayersResource {
    pub fn new(players: &[PlayerId]) -> Self {
        Self {
            players: players.to_vec(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum TurnPhase {
    PlaceArmies { armies_remaining: u32 },
    Attack,
    Fortify,
    EndTurn,
}

#[derive(GameResource, Debug, Clone)]
pub struct TurnStateResource {
    pub phase: TurnPhase,
    pub fortified: bool,
}

impl Default for TurnStateResource {
    fn default() -> Self {
        Self {
            phase: TurnPhase::PlaceArmies {
                armies_remaining: 5,
            },
            fortified: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PendingAttack {
    pub attacker: PlayerId,
    pub from: TerritoryId,
    pub to: TerritoryId,
    pub dice: u8,
}

#[derive(GameResource, Default, Debug, Clone)]
pub struct PendingAttackResource {
    pub attack: Option<PendingAttack>,
}

#[derive(GameResource, Default, Debug, Clone)]
pub struct EliminatedPlayersResource {
    pub eliminated: Vec<PlayerId>,
    pub eliminated_by: HashMap<PlayerId, PlayerId>,
}

impl EliminatedPlayersResource {
    pub fn is_eliminated(&self, player: PlayerId) -> bool {
        self.eliminated.contains(&player)
    }

    pub fn eliminate(&mut self, player: PlayerId, by: PlayerId) {
        if !self.is_eliminated(player) {
            self.eliminated.push(player);
            self.eliminated_by.insert(player, by);
        }
    }
}

#[derive(GameResource, Default, Debug, Clone)]
pub struct ExchangeCountResource {
    pub count: u32,
}

impl ExchangeCountResource {
    pub fn next_bonus(&mut self) -> u32 {
        self.count += 1;
        match self.count {
            1 => 4,
            2 => 6,
            3 => 8,
            n => 8 + (n - 3) * 5,
        }
    }
}

pub fn default_card_deck() -> Vec<TerritoryCard> {
    let mut deck = Vec::new();
    for i in 0..30u8 {
        let card_type = match i % 3 {
            0 => CardType::Infantry,
            1 => CardType::Cavalry,
            _ => CardType::Cannon,
        };
        deck.push(TerritoryCard {
            territory: TerritoryId(i),
            card_type,
        });
    }
    deck
}

#[derive(GameResource, Debug, Clone)]
pub struct PlayerCardsResource {
    pub cards: HashMap<PlayerId, Vec<TerritoryCard>>,
    pub card_deck: Vec<TerritoryCard>,
    pub conquered_this_turn: bool,
}

impl Default for PlayerCardsResource {
    fn default() -> Self {
        Self {
            cards: HashMap::new(),
            card_deck: default_card_deck(),
            conquered_this_turn: false,
        }
    }
}

#[derive(GameResource, Default, Debug, Clone)]
pub struct ConquestTrackerResource {
    pub conquered_this_turn: bool,
}

#[derive(GameResource, Default, Debug, Clone)]
pub struct PlayerObjectivesResource {
    pub objectives: HashMap<PlayerId, ObjectiveCard>,
}
