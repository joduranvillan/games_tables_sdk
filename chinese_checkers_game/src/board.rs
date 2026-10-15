use std::collections::HashMap;

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

use crate::position::{corner_cells, Position};

#[derive(GameResource)]
pub struct BoardResource {
    pub pegs: HashMap<Position, PlayerId>,
    /// A dónde tiene que llevar sus fichas cada jugador para ganar: la
    /// casa del RIVAL opuesto.
    pub targets: HashMap<PlayerId, Vec<Position>>,
}

impl BoardResource {
    pub fn new(players: Vec<PlayerId>) -> Self {
        let mut pegs = HashMap::new();
        let mut targets = HashMap::new();

        let corners = match players.len() {
            2 => vec![0, 3],
            3 => vec![0, 2, 4],
            4 => vec![0, 1, 3, 4],
            6 => vec![0, 1, 2, 3, 4, 5],
            _ => vec![0, 3],
        };

        for (i, &player) in players.iter().enumerate() {
            let start_corner = corners[i % corners.len()];
            let target_corner = (start_corner + 3) % 6;

            for pos in corner_cells(start_corner) {
                pegs.insert(pos, player);
            }
            targets.insert(player, corner_cells(target_corner));
        }

        Self { pegs, targets }
    }

    pub fn has_won(&self, player: PlayerId) -> bool {
        let target = match self.targets.get(&player) {
            Some(t) => t,
            None => return false,
        };
        target.iter().all(|pos| self.pegs.contains_key(pos))
            && target.iter().any(|pos| self.pegs.get(pos) == Some(&player))
    }
}
