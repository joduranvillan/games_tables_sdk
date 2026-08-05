use serde::{Deserialize, Serialize};

/// Una casilla del tablero, 0-indexada. Solo las casillas "oscuras"
/// (`(row + col)` impar) se usan en damas — el `RuleEngine` rechaza
/// cualquier movimiento hacia/desde una casilla clara.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Position {
    pub row: u8,
    pub col: u8,
}

impl Position {
    pub fn new(row: u8, col: u8) -> Self {
        Self { row, col }
    }

    pub fn is_on_board(&self) -> bool {
        self.row < 8 && self.col < 8
    }

    pub fn is_dark_square(&self) -> bool {
        (self.row + self.col) % 2 == 1
    }

    /// Diferencia de fila y columna hacia `other`, con signo.
    pub fn diff(&self, other: Position) -> (i8, i8) {
        (
            other.row as i8 - self.row as i8,
            other.col as i8 - self.col as i8,
        )
    }

    /// La casilla intermedia entre `self` y `other`, asumiendo que están
    /// a distancia diagonal de 2 (un salto de captura).
    pub fn midpoint(&self, other: Position) -> Position {
        Position {
            row: ((self.row as i8 + other.row as i8) / 2) as u8,
            col: ((self.col as i8 + other.col as i8) / 2) as u8,
        }
    }
}
