use serde::{Deserialize, Serialize};

/// Coordenadas axiales de hexágono (q, r).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Position {
    pub q: i32,
    pub r: i32,
}

pub const BOARD_RADIUS: i32 = 4;

/// Las 6 direcciones de un paso en un tablero hexagonal axial.
pub const DIRECTIONS: [(i32, i32); 6] = [
    (1, 0),
    (1, -1),
    (0, -1),
    (-1, 0),
    (-1, 1),
    (0, 1),
];

impl Position {
    pub fn new(q: i32, r: i32) -> Self {
        Self { q, r }
    }

    pub fn is_on_board(&self) -> bool {
        self.q.abs().max(self.r.abs()).max((self.q + self.r).abs()) <= BOARD_RADIUS
    }

    pub fn add(&self, delta: (i32, i32)) -> Position {
        Position::new(self.q + delta.0, self.r + delta.1)
    }

    pub fn delta_to(&self, other: Position) -> (i32, i32) {
        (other.q - self.q, other.r - self.r)
    }
}

pub fn rotate_60(p: Position, times: usize) -> Position {
    let mut curr = p;
    for _ in 0..(times % 6) {
        curr = Position::new(-curr.r, curr.q + curr.r);
    }
    curr
}

/// Devuelve las 10 casillas de la esquina especificada (0 a 5).
pub fn corner_cells(corner: usize) -> Vec<Position> {
    let base = vec![
        Position::new(-4, 4),
        Position::new(-4, 3),
        Position::new(-4, 2),
        Position::new(-4, 1),
        Position::new(-3, 3),
        Position::new(-3, 2),
        Position::new(-3, 1),
        Position::new(-2, 2),
        Position::new(-2, 1),
        Position::new(-1, 1),
    ];
    base.into_iter().map(|p| rotate_60(p, corner)).collect()
}

pub fn home_cells_a() -> Vec<Position> {
    corner_cells(0)
}

pub fn home_cells_b() -> Vec<Position> {
    corner_cells(3)
}
