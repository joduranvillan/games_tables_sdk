use serde::{Deserialize, Serialize};

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

/// Tablero de 8x8 (más chico que el oficial de 10x10, para partidas más
/// rápidas — no cambia ninguna mecánica, solo el tamaño).
pub const BOARD_SIZE: u8 = 8;
