// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::{HashMap, HashSet};

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};

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

impl Default for BoardResource {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(GameResource)]
pub struct PlayersResource {
    pub position: HashMap<PlayerId, usize>,
    pub money: HashMap<PlayerId, i64>,
    /// Índice de casilla -> dueño.
    pub properties: HashMap<usize, PlayerId>,
    pub bankrupt: HashSet<PlayerId>,
    pub mortgaged: HashSet<usize>,
    pub jail_free_cards: HashMap<PlayerId, u8>,
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
            mortgaged: HashSet::new(),
            jail_free_cards: HashMap::new(),
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
                Space::Property { group: g, .. } => {
                    g == group && self.properties.get(idx) == Some(&player)
                }
                _ => false,
            })
            .count();

        group_total == owned_in_group
    }

    pub fn count_utilities(&self, board_spaces: &[Space], owner: PlayerId) -> u32 {
        board_spaces
            .iter()
            .enumerate()
            .filter(|(idx, s)| {
                matches!(s, Space::Utility { .. }) && self.properties.get(idx) == Some(&owner)
            })
            .count() as u32
    }

    pub fn count_railroads(&self, board_spaces: &[Space], owner: PlayerId) -> u32 {
        board_spaces
            .iter()
            .enumerate()
            .filter(|(idx, s)| {
                matches!(s, Space::Railroad { .. }) && self.properties.get(idx) == Some(&owner)
            })
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

#[derive(GameResource, Default, Clone, Debug)]
pub struct JailResource {
    pub jailed: HashMap<PlayerId, u8>,
    pub consecutive_doubles: HashMap<PlayerId, u8>,
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

#[derive(GameResource, Default, Clone, Debug)]
pub struct BuildingsResource {
    pub buildings: HashMap<usize, u8>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TradeOffer {
    pub from: PlayerId,
    pub to: PlayerId,
    pub offered_spaces: Vec<usize>,
    pub requested_spaces: Vec<usize>,
    pub offered_cash: u32,
    pub requested_cash: u32,
}

#[derive(GameResource, Default, Clone, Debug)]
pub struct TradeOfferResource {
    pub offer: Option<TradeOffer>,
    pub current_offer: Option<TradeOffer>,
}

impl TradeOfferResource {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_offer(&mut self, offer: TradeOffer) {
        self.offer = Some(offer.clone());
        self.current_offer = Some(offer);
    }

    pub fn clear(&mut self) {
        self.offer = None;
        self.current_offer = None;
    }
}
