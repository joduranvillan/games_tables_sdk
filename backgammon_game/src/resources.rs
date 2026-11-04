// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

#[derive(Debug, Clone, GameResource)]
pub struct DoublingCubeResource {
    pub value: u32,
    pub owner: Option<PlayerId>,
    pub offered: bool,
    pub offered_by: Option<PlayerId>,
}

impl Default for DoublingCubeResource {
    fn default() -> Self {
        Self {
            value: 1,
            owner: None,
            offered: false,
            offered_by: None,
        }
    }
}

#[derive(Debug, Clone, Default, GameResource)]
pub struct MatchStateResource {
    pub match_points: u32,
    pub scores: std::collections::HashMap<PlayerId, u32>,
    pub crawford_game: bool,
}
