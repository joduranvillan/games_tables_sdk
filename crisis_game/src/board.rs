use open_table_core::ids::PlayerId;
use serde::{Deserialize, Serialize};

use crate::resources::{EliminatedPlayersResource, TerritoryStateResource};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct TerritoryId(pub u8);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ContinentId(pub u8);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Territory {
    pub id: TerritoryId,
    pub name: &'static str,
    pub continent: ContinentId,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Continent {
    pub id: ContinentId,
    pub name: &'static str,
    pub bonus_armies: u8,
    pub territories: &'static [TerritoryId],
}

pub const CONTINENT_SOUTH_AMERICA: ContinentId = ContinentId(0);
pub const CONTINENT_NORTH_AMERICA: ContinentId = ContinentId(1);
pub const CONTINENT_EUROPE: ContinentId = ContinentId(2);
pub const CONTINENT_AFRICA: ContinentId = ContinentId(3);
pub const CONTINENT_ASIA: ContinentId = ContinentId(4);
pub const CONTINENT_OCEANIA: ContinentId = ContinentId(5);

pub const TERRITORIES: &[Territory] = &[
    // América del Sur (5)
    Territory {
        id: TerritoryId(0),
        name: "Argentina",
        continent: CONTINENT_SOUTH_AMERICA,
    },
    Territory {
        id: TerritoryId(1),
        name: "Brasil",
        continent: CONTINENT_SOUTH_AMERICA,
    },
    Territory {
        id: TerritoryId(2),
        name: "Chile",
        continent: CONTINENT_SOUTH_AMERICA,
    },
    Territory {
        id: TerritoryId(3),
        name: "Colombia",
        continent: CONTINENT_SOUTH_AMERICA,
    },
    Territory {
        id: TerritoryId(4),
        name: "Perú",
        continent: CONTINENT_SOUTH_AMERICA,
    },
    // América del Norte (4)
    Territory {
        id: TerritoryId(5),
        name: "México",
        continent: CONTINENT_NORTH_AMERICA,
    },
    Territory {
        id: TerritoryId(6),
        name: "California",
        continent: CONTINENT_NORTH_AMERICA,
    },
    Territory {
        id: TerritoryId(7),
        name: "Nueva York",
        continent: CONTINENT_NORTH_AMERICA,
    },
    Territory {
        id: TerritoryId(8),
        name: "Canadá",
        continent: CONTINENT_NORTH_AMERICA,
    },
    // Europa (5)
    Territory {
        id: TerritoryId(9),
        name: "Gran Bretaña",
        continent: CONTINENT_EUROPE,
    },
    Territory {
        id: TerritoryId(10),
        name: "España",
        continent: CONTINENT_EUROPE,
    },
    Territory {
        id: TerritoryId(11),
        name: "Francia",
        continent: CONTINENT_EUROPE,
    },
    Territory {
        id: TerritoryId(12),
        name: "Alemania",
        continent: CONTINENT_EUROPE,
    },
    Territory {
        id: TerritoryId(13),
        name: "Rusia",
        continent: CONTINENT_EUROPE,
    },
    // África (4)
    Territory {
        id: TerritoryId(14),
        name: "Sahara",
        continent: CONTINENT_AFRICA,
    },
    Territory {
        id: TerritoryId(15),
        name: "Egipto",
        continent: CONTINENT_AFRICA,
    },
    Territory {
        id: TerritoryId(16),
        name: "Congo",
        continent: CONTINENT_AFRICA,
    },
    Territory {
        id: TerritoryId(17),
        name: "Sudáfrica",
        continent: CONTINENT_AFRICA,
    },
    // Asia (8)
    Territory {
        id: TerritoryId(18),
        name: "Aral",
        continent: CONTINENT_ASIA,
    },
    Territory {
        id: TerritoryId(19),
        name: "Tartaria",
        continent: CONTINENT_ASIA,
    },
    Territory {
        id: TerritoryId(20),
        name: "Taymir",
        continent: CONTINENT_ASIA,
    },
    Territory {
        id: TerritoryId(21),
        name: "Siberia",
        continent: CONTINENT_ASIA,
    },
    Territory {
        id: TerritoryId(22),
        name: "Kamchatka",
        continent: CONTINENT_ASIA,
    },
    Territory {
        id: TerritoryId(23),
        name: "China",
        continent: CONTINENT_ASIA,
    },
    Territory {
        id: TerritoryId(24),
        name: "India",
        continent: CONTINENT_ASIA,
    },
    Territory {
        id: TerritoryId(25),
        name: "Japón",
        continent: CONTINENT_ASIA,
    },
    // Oceanía (4)
    Territory {
        id: TerritoryId(26),
        name: "Australia",
        continent: CONTINENT_OCEANIA,
    },
    Territory {
        id: TerritoryId(27),
        name: "Java",
        continent: CONTINENT_OCEANIA,
    },
    Territory {
        id: TerritoryId(28),
        name: "Sumatra",
        continent: CONTINENT_OCEANIA,
    },
    Territory {
        id: TerritoryId(29),
        name: "Borneo",
        continent: CONTINENT_OCEANIA,
    },
];

pub const TERRITORY_CENTERS: &[(f32, f32)] = &[
    // América del Sur (0..=4)
    (180.0, 520.0), // 0: Argentina
    (240.0, 440.0), // 1: Brasil
    (150.0, 480.0), // 2: Chile
    (170.0, 390.0), // 3: Colombia
    (160.0, 430.0), // 4: Perú
    // América del Norte (5..=8)
    (140.0, 280.0), // 5: México
    (120.0, 200.0), // 6: California
    (200.0, 190.0), // 7: Nueva York
    (160.0, 110.0), // 8: Canadá
    // Europa (9..=13)
    (360.0, 130.0), // 9: Gran Bretaña
    (350.0, 220.0), // 10: España
    (400.0, 190.0), // 11: Francia
    (450.0, 170.0), // 12: Alemania
    (520.0, 140.0), // 13: Rusia
    // África (14..=17)
    (380.0, 320.0), // 14: Sahara
    (450.0, 310.0), // 15: Egipto
    (430.0, 400.0), // 16: Congo
    (440.0, 490.0), // 17: Sudáfrica
    // Asia (18..=25)
    (540.0, 210.0), // 18: Aral
    (600.0, 150.0), // 19: Tartaria
    (650.0, 100.0), // 20: Taymir
    (690.0, 140.0), // 21: Siberia
    (730.0, 120.0), // 22: Kamchatka
    (620.0, 240.0), // 23: China
    (560.0, 290.0), // 24: India
    (730.0, 220.0), // 25: Japón
    // Oceanía (26..=29)
    (700.0, 480.0), // 26: Australia
    (650.0, 380.0), // 27: Java
    (600.0, 350.0), // 28: Sumatra
    (660.0, 340.0), // 29: Borneo
];

pub const CONTINENTS: &[Continent] = &[
    Continent {
        id: CONTINENT_SOUTH_AMERICA,
        name: "América del Sur",
        bonus_armies: 2,
        territories: &[
            TerritoryId(0),
            TerritoryId(1),
            TerritoryId(2),
            TerritoryId(3),
            TerritoryId(4),
        ],
    },
    Continent {
        id: CONTINENT_NORTH_AMERICA,
        name: "América del Norte",
        bonus_armies: 3,
        territories: &[
            TerritoryId(5),
            TerritoryId(6),
            TerritoryId(7),
            TerritoryId(8),
        ],
    },
    Continent {
        id: CONTINENT_EUROPE,
        name: "Europa",
        bonus_armies: 5,
        territories: &[
            TerritoryId(9),
            TerritoryId(10),
            TerritoryId(11),
            TerritoryId(12),
            TerritoryId(13),
        ],
    },
    Continent {
        id: CONTINENT_AFRICA,
        name: "África",
        bonus_armies: 3,
        territories: &[
            TerritoryId(14),
            TerritoryId(15),
            TerritoryId(16),
            TerritoryId(17),
        ],
    },
    Continent {
        id: CONTINENT_ASIA,
        name: "Asia",
        bonus_armies: 7,
        territories: &[
            TerritoryId(18),
            TerritoryId(19),
            TerritoryId(20),
            TerritoryId(21),
            TerritoryId(22),
            TerritoryId(23),
            TerritoryId(24),
            TerritoryId(25),
        ],
    },
    Continent {
        id: CONTINENT_OCEANIA,
        name: "Oceanía",
        bonus_armies: 2,
        territories: &[
            TerritoryId(26),
            TerritoryId(27),
            TerritoryId(28),
            TerritoryId(29),
        ],
    },
];

pub const ADJACENCIES: &[(TerritoryId, TerritoryId)] = &[
    // América del Sur
    (TerritoryId(0), TerritoryId(1)),
    (TerritoryId(0), TerritoryId(2)),
    (TerritoryId(0), TerritoryId(4)),
    (TerritoryId(1), TerritoryId(2)),
    (TerritoryId(1), TerritoryId(3)),
    (TerritoryId(1), TerritoryId(4)),
    (TerritoryId(1), TerritoryId(14)),
    (TerritoryId(2), TerritoryId(4)),
    (TerritoryId(2), TerritoryId(26)),
    (TerritoryId(3), TerritoryId(4)),
    (TerritoryId(3), TerritoryId(5)),
    // América del Norte
    (TerritoryId(5), TerritoryId(6)),
    (TerritoryId(6), TerritoryId(7)),
    (TerritoryId(6), TerritoryId(8)),
    (TerritoryId(7), TerritoryId(8)),
    (TerritoryId(7), TerritoryId(10)),
    (TerritoryId(8), TerritoryId(22)),
    // Europa
    (TerritoryId(9), TerritoryId(10)),
    (TerritoryId(9), TerritoryId(11)),
    (TerritoryId(9), TerritoryId(12)),
    (TerritoryId(10), TerritoryId(11)),
    (TerritoryId(10), TerritoryId(14)),
    (TerritoryId(11), TerritoryId(12)),
    (TerritoryId(12), TerritoryId(13)),
    (TerritoryId(13), TerritoryId(18)),
    (TerritoryId(13), TerritoryId(19)),
    // África
    (TerritoryId(14), TerritoryId(15)),
    (TerritoryId(14), TerritoryId(16)),
    (TerritoryId(15), TerritoryId(16)),
    (TerritoryId(15), TerritoryId(17)),
    (TerritoryId(15), TerritoryId(18)),
    (TerritoryId(16), TerritoryId(17)),
    // Asia
    (TerritoryId(18), TerritoryId(19)),
    (TerritoryId(18), TerritoryId(24)),
    (TerritoryId(19), TerritoryId(20)),
    (TerritoryId(19), TerritoryId(21)),
    (TerritoryId(19), TerritoryId(23)),
    (TerritoryId(20), TerritoryId(21)),
    (TerritoryId(21), TerritoryId(22)),
    (TerritoryId(21), TerritoryId(23)),
    (TerritoryId(22), TerritoryId(25)),
    (TerritoryId(23), TerritoryId(24)),
    (TerritoryId(23), TerritoryId(25)),
    (TerritoryId(23), TerritoryId(28)),
    (TerritoryId(24), TerritoryId(28)),
    // Oceanía
    (TerritoryId(26), TerritoryId(27)),
    (TerritoryId(27), TerritoryId(29)),
    (TerritoryId(28), TerritoryId(29)),
];

pub fn are_adjacent(a: TerritoryId, b: TerritoryId) -> bool {
    ADJACENCIES
        .iter()
        .any(|&(x, y)| (x == a && y == b) || (x == b && y == a))
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ObjectiveCard {
    ConquerContinent(ContinentId),
    ConquerTwoSmallContinents,
    Exterminate(PlayerId),
    ConquerTerritories(u8),
}

pub fn check_objective(
    objective: &ObjectiveCard,
    map: &TerritoryStateResource,
    _players: &[PlayerId],
    eliminated: &EliminatedPlayersResource,
    player: PlayerId,
) -> bool {
    match objective {
        ObjectiveCard::ConquerContinent(continent_id) => {
            if let Some(continent) = CONTINENTS.iter().find(|c| c.id == *continent_id) {
                map.owns_continent(continent, player)
            } else {
                false
            }
        }
        ObjectiveCard::ConquerTwoSmallContinents => {
            let small_continents_owned = CONTINENTS
                .iter()
                .filter(|c| c.territories.len() <= 5 && map.owns_continent(c, player))
                .count();
            small_continents_owned >= 2
        }
        ObjectiveCard::Exterminate(target) => {
            if *target == player {
                let count = map.owners.values().filter(|&&o| o == player).count();
                count >= 24
            } else if eliminated.is_eliminated(*target) {
                if eliminated.eliminated_by.get(target) == Some(&player) {
                    true
                } else {
                    let count = map.owners.values().filter(|&&o| o == player).count();
                    count >= 24
                }
            } else {
                false
            }
        }
        ObjectiveCard::ConquerTerritories(count_required) => {
            let count = map
                .owners
                .iter()
                .filter(|&(t_id, &owner)| {
                    owner == player && map.armies.get(t_id).copied().unwrap_or(0) >= 2
                })
                .count();
            count >= (*count_required as usize)
        }
    }
}

pub fn check_continent_bonus(
    map: &TerritoryStateResource,
    player: PlayerId,
    continents: &[Continent],
) -> u32 {
    let mut bonus = 0;
    for continent in continents {
        if map.owns_continent(continent, player) {
            bonus += continent.bonus_armies as u32;
        }
    }
    bonus
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_board_counts() {
        assert_eq!(TERRITORIES.len(), 30);
        assert_eq!(CONTINENTS.len(), 6);
    }

    #[test]
    fn test_continent_territories_match() {
        let total_in_continents: usize = CONTINENTS.iter().map(|c| c.territories.len()).sum();
        assert_eq!(total_in_continents, 30);
    }

    #[test]
    fn test_are_adjacent() {
        assert!(are_adjacent(TerritoryId(0), TerritoryId(1)));
        assert!(are_adjacent(TerritoryId(1), TerritoryId(0)));
        assert!(are_adjacent(TerritoryId(0), TerritoryId(2)));
        assert!(are_adjacent(TerritoryId(1), TerritoryId(14)));
        assert!(!are_adjacent(TerritoryId(0), TerritoryId(25)));
    }
}
