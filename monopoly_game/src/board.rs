use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum Space {
    Go,
    Property { name: String, group: String, price: u32, rent: u32 },
    Utility { name: String, price: u32 },
    Railroad { name: String, price: u32 },
    Empty,
    GoToJail,
    Jail,
}

/// Tablero de 16 casillas con propiedades agrupadas por color, servicios y estaciones.
pub fn board_layout() -> Vec<Space> {
    fn property(name: &str, group: &str, price: u32, rent: u32) -> Space {
        Space::Property {
            name: name.to_string(),
            group: group.to_string(),
            price,
            rent,
        }
    }

    fn utility(name: &str, price: u32) -> Space {
        Space::Utility {
            name: name.to_string(),
            price,
        }
    }

    fn railroad(name: &str, price: u32) -> Space {
        Space::Railroad {
            name: name.to_string(),
            price,
        }
    }

    vec![
        Space::Go,
        property("Av. Roja 1", "Rojo", 60, 4),
        property("Av. Roja 2", "Rojo", 80, 6),
        property("Av. Verde 1", "Verde", 100, 8),
        property("Av. Verde 2", "Verde", 120, 10),
        railroad("Estación Norte", 200),
        property("Av. Amarilla 1", "Amarillo", 140, 12),
        property("Av. Amarilla 2", "Amarillo", 160, 14),
        Space::GoToJail,
        property("Av. Rosa 1", "Rosa", 180, 16),
        property("Av. Rosa 2", "Rosa", 200, 18),
        utility("Compañía Electrica", 150),
        property("Av. Marrón 1", "Marrón", 220, 20),
        property("Av. Marrón 2", "Marrón", 240, 22),
        utility("Planta de Agua", 150),
        property("Av. Gris", "Gris", 260, 24),
    ]
}

pub const STARTING_MONEY: i64 = 1500;
pub const GO_BONUS: i64 = 200;
pub const JAIL_SPACE: usize = 4;
pub const GO_TO_JAIL_SPACE: usize = 8;

