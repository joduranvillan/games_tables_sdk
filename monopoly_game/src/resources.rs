use std::collections::{HashMap, HashSet};

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

use crate::board::{board_layout, Space, STARTING_MONEY};

#[derive(GameResource)]
pub struct BoardResource {
    pub spaces: Vec<Space>,
}

impl BoardResource {
    pub fn new() -> Self {
        Self {
            spaces: board_layout(),
        }
    }
}

#[derive(GameResource)]
pub struct PlayersResource {
    pub position: HashMap<PlayerId, usize>,
    pub money: HashMap<PlayerId, i64>,
    /// Índice de casilla -> dueño.
    pub properties: HashMap<usize, PlayerId>,
    pub bankrupt: HashSet<PlayerId>,
}

impl PlayersResource {
    pub fn new(players: &[PlayerId]) -> Self {
        let mut position = HashMap::new();
        let mut money = HashMap::new();
        for player in players {
            position.insert(*player, 0);
            money.insert(*player, STARTING_MONEY);
        }
        Self {
            position,
            money,
            properties: HashMap::new(),
            bankrupt: HashSet::new(),
        }
    }

    /// Verifica si un jugador posee todas las propiedades de un grupo de color.
    pub fn owns_full_group(&self, board_spaces: &[Space], player: PlayerId, group: &str) -> bool {
        let group_total = board_spaces
            .iter()
            .filter(|s| match s {
                Space::Property { group: g, .. } => g == group,
                _ => false,
            })
            .count();

        if group_total == 0 {
            return false;
        }

        let owned_in_group = board_spaces
            .iter()
            .enumerate()
            .filter(|(idx, s)| match s {
                Space::Property { group: g, .. } => g == group && self.properties.get(idx) == Some(&player),
                _ => false,
            })
            .count();

        group_total == owned_in_group
    }

    pub fn count_utilities(&self, board_spaces: &[Space], owner: PlayerId) -> u32 {
        board_spaces
            .iter()
            .enumerate()
            .filter(|(idx, s)| matches!(s, Space::Utility { .. }) && self.properties.get(idx) == Some(&owner))
            .count() as u32
    }

    pub fn count_railroads(&self, board_spaces: &[Space], owner: PlayerId) -> u32 {
        board_spaces
            .iter()
            .enumerate()
            .filter(|(idx, s)| matches!(s, Space::Railroad { .. }) && self.properties.get(idx) == Some(&owner))
            .count() as u32
    }
}

#[derive(Debug, Clone, Copy)]
pub struct PendingDecision {
    pub space: usize,
    pub is_doubles: bool,
}

/// Decisión de compra pendiente: el jugador cayó en una propiedad sin
/// dueño y todavía no dijo si la compra o no. El turno NO avanza hasta
/// que responda con `BuyPropertyCommand`.
#[derive(GameResource, Default)]
pub struct PendingPurchaseResource {
    pub pending: HashMap<PlayerId, PendingDecision>,
}

#[derive(GameResource, Default)]
pub struct JailResource {
    pub jailed: HashMap<PlayerId, u8>,
}

#[derive(Debug, Clone)]
pub struct AuctionState {
    pub space: usize,
    pub current_bid: u32,
    pub highest_bidder: Option<PlayerId>,
    pub passed: HashSet<PlayerId>,
}

#[derive(GameResource, Default)]
pub struct AuctionResource {
    pub state: Option<AuctionState>,
}

