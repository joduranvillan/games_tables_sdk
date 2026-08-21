use serde::{Deserialize, Serialize};

/// Coordenadas axiales de hexágono (q, r).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Position {
    pub q: i32,
    pub r: i32,
}

pub const BOARD_RADIUS: i32 = 4;

/// Las 6 direcciones de un paso en un tablero hexagonal axial.
pub const DIRECTIONS: [(i32, i32); 6] = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];

impl Position {
    pub fn new(q: i32, r: i32) -> Self {
        Self { q, r }
    }

    pub fn is_on_board(&self) -> bool {
        if self.q.abs().max(self.r.abs()).max((self.q + self.r).abs()) <= BOARD_RADIUS {
            return true;
        }
        (0..6).any(|corner| corner_cells(corner).contains(self))
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

/// Devuelve las 10 casillas de la esquina especificada (0 a 5), desplazadas hacia afuera del hexágono central.
pub fn corner_cells(corner: usize) -> Vec<Position> {
    let base = vec![
        Position::new(-5, 1),
        Position::new(-5, 2),
        Position::new(-5, 3),
        Position::new(-6, 2),
        Position::new(-6, 3),
        Position::new(-6, 4),
        Position::new(-7, 3),
        Position::new(-7, 4),
        Position::new(-8, 4),
        Position::new(-5, 4),
    ];
    base.into_iter().map(|p| rotate_60(p, corner)).collect()
}

pub fn home_cells_a() -> Vec<Position> {
    corner_cells(0)
}

pub fn home_cells_b() -> Vec<Position> {
    corner_cells(3)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tablero_tiene_exactamente_121_casillas_validas() {
        let mut count = 0;
        for q in -15..=15 {
            for r in -15..=15 {
                if Position::new(q, r).is_on_board() {
                    count += 1;
                }
            }
        }
        assert_eq!(
            count, 121,
            "El tablero de estrella de 6 puntas debe tener exactamente 121 casillas"
        );
    }

    #[test]
    fn test_las_6_puntas_no_se_superponen_con_el_hexagono_central() {
        for corner in 0..6 {
            let cells = corner_cells(corner);
            assert_eq!(cells.len(), 10);
            for pos in cells {
                let in_central_hex =
                    pos.q.abs().max(pos.r.abs()).max((pos.q + pos.r).abs()) <= BOARD_RADIUS;
                assert!(
                    !in_central_hex,
                    "La casilla {:?} de la punta {} no debe superponerse con el hexágono central (radio <= 4)",
                    pos, corner
                );
            }
        }
    }
}
