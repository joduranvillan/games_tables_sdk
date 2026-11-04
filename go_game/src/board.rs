// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;
use open_table_macros::GameResource;
use std::collections::hash_map::DefaultHasher;
use std::collections::HashSet;
use std::hash::{Hash, Hasher};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Stone {
    Black,
    White,
}

#[derive(GameResource, Clone)]
pub struct BoardResource {
    pub size: usize,
    pub grid: Vec<Option<Stone>>,
    pub black_player: PlayerId,
    pub white_player: PlayerId,
    pub passes: usize,
    pub ko_point: Option<(usize, usize)>,
    pub black_prisoners: usize,
    pub white_prisoners: usize,
    pub komi_half_points: u32,
}

#[derive(GameResource, Default, Clone, Debug)]
pub struct BoardHistoryResource {
    pub history: HashSet<u64>,
}

impl BoardHistoryResource {
    pub fn new() -> Self {
        Self {
            history: HashSet::new(),
        }
    }
}

#[derive(GameResource, Default, Clone, Debug)]
pub struct DeadMarkingResource {
    pub active: bool,
    pub dead_stones: HashSet<(usize, usize)>,
    pub confirmed_players: HashSet<PlayerId>,
}

impl DeadMarkingResource {
    pub fn new() -> Self {
        Self::default()
    }
}

impl BoardResource {
    pub fn new(size: usize, black_player: PlayerId, white_player: PlayerId) -> Self {
        Self {
            size,
            grid: vec![None; size * size],
            black_player,
            white_player,
            passes: 0,
            ko_point: None,
            black_prisoners: 0,
            white_prisoners: 0,
            komi_half_points: 13,
        }
    }

    pub fn with_komi(mut self, komi_half_points: u32) -> Self {
        self.komi_half_points = komi_half_points;
        self
    }

    pub fn calculate_final_scores(&self) -> (f32, f32) {
        let (black_territory, white_territory) = self.calculate_territory();
        let black_total = (black_territory + self.black_prisoners) as f32;
        let white_total =
            (white_territory + self.white_prisoners) as f32 + (self.komi_half_points as f32 / 2.0);
        (black_total, white_total)
    }

    pub fn compute_hash(&self) -> u64 {
        let mut hasher = DefaultHasher::new();
        self.grid.hash(&mut hasher);
        hasher.finish()
    }

    pub fn get_stone(&self, x: usize, y: usize) -> Option<Stone> {
        if x < self.size && y < self.size {
            self.grid[y * self.size + x]
        } else {
            None
        }
    }

    pub fn set_stone(&mut self, x: usize, y: usize, stone: Option<Stone>) {
        if x < self.size && y < self.size {
            self.grid[y * self.size + x] = stone;
        }
    }

    pub fn get_neighbors(&self, x: usize, y: usize) -> Vec<(usize, usize)> {
        let mut neighbors = Vec::new();
        if x > 0 {
            neighbors.push((x - 1, y));
        }
        if x + 1 < self.size {
            neighbors.push((x + 1, y));
        }
        if y > 0 {
            neighbors.push((x, y - 1));
        }
        if y + 1 < self.size {
            neighbors.push((x, y + 1));
        }
        neighbors
    }

    pub fn get_group_and_liberties(&self, x: usize, y: usize) -> (HashSet<(usize, usize)>, usize) {
        let mut group = HashSet::new();
        let mut liberties = HashSet::new();
        let mut stack = vec![(x, y)];
        let stone = self.get_stone(x, y);

        if stone.is_none() {
            return (group, 0);
        }

        while let Some((cx, cy)) = stack.pop() {
            if group.insert((cx, cy)) {
                for (nx, ny) in self.get_neighbors(cx, cy) {
                    let n_stone = self.get_stone(nx, ny);
                    if n_stone == stone {
                        if !group.contains(&(nx, ny)) {
                            stack.push((nx, ny));
                        }
                    } else if n_stone.is_none() {
                        liberties.insert((nx, ny));
                    }
                }
            }
        }
        (group, liberties.len())
    }

    pub fn calculate_territory(&self) -> (usize, usize) {
        let mut visited = vec![false; self.size * self.size];
        let mut black_territory = 0;
        let mut white_territory = 0;

        for y in 0..self.size {
            for x in 0..self.size {
                if self.get_stone(x, y).is_none() && !visited[y * self.size + x] {
                    let mut region_size = 0;
                    let mut touches_black = false;
                    let mut touches_white = false;
                    let mut queue = vec![(x, y)];
                    visited[y * self.size + x] = true;

                    while let Some((cx, cy)) = queue.pop() {
                        region_size += 1;
                        for (nx, ny) in self.get_neighbors(cx, cy) {
                            match self.get_stone(nx, ny) {
                                Some(Stone::Black) => touches_black = true,
                                Some(Stone::White) => touches_white = true,
                                None => {
                                    let idx = ny * self.size + nx;
                                    if !visited[idx] {
                                        visited[idx] = true;
                                        queue.push((nx, ny));
                                    }
                                }
                            }
                        }
                    }

                    if touches_black && !touches_white {
                        black_territory += region_size;
                    } else if touches_white && !touches_black {
                        white_territory += region_size;
                    }
                }
            }
        }

        (black_territory, white_territory)
    }
}
