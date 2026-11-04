// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::{HashMap, HashSet};

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

use crate::position::Position;

/// Un barco es simplemente la lista de casillas que ocupa.
pub type Ship = Vec<Position>;

/// Tamaños de flota estándar de Batalla Naval:
/// - Portaaviones: 5 casillas
/// - Acorazado: 4 casillas
/// - Crucero: 3 casillas
/// - Submarino: 3 casillas
/// - Destructor: 2 casillas
pub const EXPECTED_SHIP_SIZES: [usize; 5] = [5, 4, 3, 3, 2];

#[derive(GameResource, Default)]
pub struct FleetResource {
    /// La flota de cada jugador. Nadie más que su dueño debería conocer
    /// estas coordenadas exactas — el `RuleEngine` nunca las incluye en
    /// un `Event` público, se quedan solo acá adentro del `Resource`.
    pub ships: HashMap<PlayerId, Vec<Ship>>,
    /// Casillas ya impactadas en el tablero de cada jugador. Esto SÍ es
    /// información pública (ambos jugadores ven dónde pegaron los tiros),
    /// a diferencia de `ships`.
    pub hits: HashMap<PlayerId, Vec<Position>>,
}

impl FleetResource {
    pub fn new() -> Self {
        Self {
            ships: HashMap::new(),
            hits: HashMap::new(),
        }
    }

    pub fn has_placed_fleet(&self, player: PlayerId) -> bool {
        self.ships.contains_key(&player)
    }

    /// Todas las casillas ocupadas por la flota de `player`, sin importar
    /// a qué barco pertenecen.
    pub fn occupied_cells(&self, player: PlayerId) -> Vec<Position> {
        self.ships
            .get(&player)
            .map(|ships| ships.iter().flatten().copied().collect())
            .unwrap_or_default()
    }

    pub fn is_hit(&self, player: PlayerId, pos: Position) -> bool {
        self.hits
            .get(&player)
            .map(|hits| hits.contains(&pos))
            .unwrap_or(false)
    }

    /// Un barco está hundido si todas sus casillas ya fueron impactadas.
    pub fn ship_at(&self, player: PlayerId, pos: Position) -> Option<Ship> {
        self.ships
            .get(&player)?
            .iter()
            .find(|ship| ship.contains(&pos))
            .cloned()
    }

    pub fn is_ship_sunk(&self, player: PlayerId, ship: &Ship) -> bool {
        ship.iter().all(|cell| self.is_hit(player, *cell))
    }

    pub fn all_ships_sunk(&self, player: PlayerId) -> bool {
        match self.ships.get(&player) {
            Some(ships) => {
                !ships.is_empty() && ships.iter().all(|ship| self.is_ship_sunk(player, ship))
            }
            None => false,
        }
    }
}

#[derive(GameResource, Default)]
pub struct ShotsResource {
    pub shots: HashMap<PlayerId, HashSet<(u8, u8)>>,
}

impl ShotsResource {
    pub fn new() -> Self {
        Self {
            shots: HashMap::new(),
        }
    }

    pub fn has_shot(&self, player: PlayerId, target: Position) -> bool {
        self.shots
            .get(&player)
            .map(|set| set.contains(&(target.row, target.col)))
            .unwrap_or(false)
    }

    pub fn record_shot(&mut self, player: PlayerId, target: Position) {
        self.shots
            .entry(player)
            .or_default()
            .insert((target.row, target.col));
    }
}

#[derive(GameResource, Default)]
pub struct RematchResource {
    pub requested: HashSet<PlayerId>,
}

impl RematchResource {
    pub fn new() -> Self {
        Self {
            requested: HashSet::new(),
        }
    }
}

#[derive(GameResource, Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct BattleshipConfigResource {
    pub extra_turn_on_hit: bool,
}

impl BattleshipConfigResource {
    pub fn new(extra_turn_on_hit: bool) -> Self {
        Self { extra_turn_on_hit }
    }
}
