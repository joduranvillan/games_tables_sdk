// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::HashMap;

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};

pub const GARDEN_SQUARE: u8 = 63;
pub const GOOSE_SQUARES: [u8; 13] = [5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59];
pub const BRIDGE_A: u8 = 6;
pub const BRIDGE_B: u8 = 12;
pub const INN_SQUARE: u8 = 19;
pub const DICE_A: u8 = 26;
pub const DICE_B: u8 = 53;
pub const WELL_SQUARE: u8 = 31;
pub const LABYRINTH_SQUARE: u8 = 42;
pub const LABYRINTH_TARGET: u8 = 30;
pub const PRISON_SQUARE: u8 = 52;
pub const SKULL_SQUARE: u8 = 58;
pub const SKULL_TARGET: u8 = 1;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SpecialSquareKind {
    Normal,
    Goose,
    Bridge,
    Inn,
    Dice,
    Well,
    Labyrinth,
    Prison,
    Skull,
    Garden,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LandingResolution {
    pub raw_square: u8,
    pub final_square: u8,
    pub bonus_turn: bool,
    pub wait_turns: u8,
    pub kind: SpecialSquareKind,
    pub description: String,
}

pub fn is_goose_square(sq: u8) -> bool {
    GOOSE_SQUARES.contains(&sq)
}

pub fn next_goose_square(sq: u8) -> u8 {
    for &g in &GOOSE_SQUARES {
        if g > sq {
            return g;
        }
    }
    GARDEN_SQUARE
}

/// Calcula la casilla tras aplicar el avance y el rebote exacto en la casilla 63.
pub fn compute_raw_square(from: u8, roll: u8) -> u8 {
    let target = from.saturating_add(roll);
    if target <= GARDEN_SQUARE {
        target
    } else {
        let excess = target - GARDEN_SQUARE;
        GARDEN_SQUARE.saturating_sub(excess)
    }
}

/// Resuelve las reglas clásicas de las 63 casillas de El Juego de la Oca.
pub fn resolve_landing(from: u8, roll: u8) -> LandingResolution {
    let raw_square = compute_raw_square(from, roll);

    if raw_square == GARDEN_SQUARE {
        return LandingResolution {
            raw_square,
            final_square: GARDEN_SQUARE,
            bonus_turn: false,
            wait_turns: 0,
            kind: SpecialSquareKind::Garden,
            description: "¡Jardín de la Oca (63)! Victoria exacta.".to_string(),
        };
    }

    if is_goose_square(raw_square) {
        let dest = next_goose_square(raw_square);
        let is_win = dest == GARDEN_SQUARE;
        return LandingResolution {
            raw_square,
            final_square: dest,
            bonus_turn: !is_win,
            wait_turns: 0,
            kind: if is_win {
                SpecialSquareKind::Garden
            } else {
                SpecialSquareKind::Goose
            },
            description: if is_win {
                format!("¡De Oca ({raw_square}) al Jardín de la Oca (63)! Victoria.")
            } else {
                format!("¡De oca ({raw_square}) a oca ({dest}) y tiro porque me toca!")
            },
        };
    }

    match raw_square {
        BRIDGE_A => LandingResolution {
            raw_square,
            final_square: BRIDGE_B,
            bonus_turn: true,
            wait_turns: 0,
            kind: SpecialSquareKind::Bridge,
            description: "¡De puente (6) a puente (12) y tiro porque me lleva la corriente!"
                .to_string(),
        },
        BRIDGE_B => LandingResolution {
            raw_square,
            final_square: BRIDGE_A,
            bonus_turn: true,
            wait_turns: 0,
            kind: SpecialSquareKind::Bridge,
            description: "¡De puente (12) a puente (6) y tiro porque me lleva la corriente!"
                .to_string(),
        },
        INN_SQUARE => LandingResolution {
            raw_square,
            final_square: INN_SQUARE,
            bonus_turn: false,
            wait_turns: 1,
            kind: SpecialSquareKind::Inn,
            description: "La Posada (19): descansas 1 turno.".to_string(),
        },
        DICE_A => LandingResolution {
            raw_square,
            final_square: DICE_B,
            bonus_turn: true,
            wait_turns: 0,
            kind: SpecialSquareKind::Dice,
            description: "¡De dado (26) a dado (53) y tiro porque me ha tocado!".to_string(),
        },
        DICE_B => LandingResolution {
            raw_square,
            final_square: DICE_A,
            bonus_turn: true,
            wait_turns: 0,
            kind: SpecialSquareKind::Dice,
            description: "¡De dado (53) a dado (26) y tiro porque me ha tocado!".to_string(),
        },
        WELL_SQUARE => LandingResolution {
            raw_square,
            final_square: WELL_SQUARE,
            bonus_turn: false,
            wait_turns: 2,
            kind: SpecialSquareKind::Well,
            description: "El Pozo (31): esperas 2 turnos (o hasta que otro jugador te rescate)."
                .to_string(),
        },
        LABYRINTH_SQUARE => LandingResolution {
            raw_square,
            final_square: LABYRINTH_TARGET,
            bonus_turn: false,
            wait_turns: 0,
            kind: SpecialSquareKind::Labyrinth,
            description: "El Laberinto (42): te pierdes y retrocedes a la casilla 30.".to_string(),
        },
        PRISON_SQUARE => LandingResolution {
            raw_square,
            final_square: PRISON_SQUARE,
            bonus_turn: false,
            wait_turns: 3,
            kind: SpecialSquareKind::Prison,
            description: "La Cárcel (52): retenido durante 3 turnos.".to_string(),
        },
        SKULL_SQUARE => LandingResolution {
            raw_square,
            final_square: SKULL_TARGET,
            bonus_turn: false,
            wait_turns: 0,
            kind: SpecialSquareKind::Skull,
            description: "La Calavera (58): vuelves a empezar desde la casilla 1.".to_string(),
        },
        _ => LandingResolution {
            raw_square,
            final_square: raw_square,
            bonus_turn: false,
            wait_turns: 0,
            kind: SpecialSquareKind::Normal,
            description: format!("Avanza a la casilla {raw_square}."),
        },
    }
}

#[derive(GameResource, Debug, Clone)]
pub struct GooseBoardResource {
    pub positions: HashMap<PlayerId, u8>,
    pub wait_turns: HashMap<PlayerId, u8>,
    pub winner: Option<PlayerId>,
    pub last_effect: String,
}

impl GooseBoardResource {
    pub fn new(players: &[PlayerId]) -> Self {
        let mut positions = HashMap::new();
        let mut wait_turns = HashMap::new();
        for &p in players {
            positions.insert(p, 0);
            wait_turns.insert(p, 0);
        }
        Self {
            positions,
            wait_turns,
            winner: None,
            last_effect: String::new(),
        }
    }

    pub fn position_of(&self, player: PlayerId) -> u8 {
        self.positions.get(&player).copied().unwrap_or(0)
    }

    pub fn wait_turns_of(&self, player: PlayerId) -> u8 {
        self.wait_turns.get(&player).copied().unwrap_or(0)
    }
}

#[derive(GameResource, Default, Debug, Clone)]
pub struct PendingRollResource {
    pub pending: HashMap<PlayerId, u8>,
}
