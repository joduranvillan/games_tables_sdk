// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

pub use crate::board::BOARD_SIZE;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Position {
    pub row: u8,
    pub col: u8,
}

impl Position {
    pub fn new(row: u8, col: u8) -> Self {
        Self { row, col }
    }

    pub fn is_on_board(&self) -> bool {
        self.row < BOARD_SIZE && self.col < BOARD_SIZE
    }
}
