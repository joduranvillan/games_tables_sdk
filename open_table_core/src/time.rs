// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};
use std::time::Instant;

use crate::ids::Tick;

/// Reloj lógico de la simulación. Nunca `Instant::now()` ni `SystemTime`:
/// el avance del juego se mide en ticks discretos, no en tiempo real, para
/// que el replay sea exacto sin importar cuánto tardó cada dispositivo en
/// procesar un tick.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GameClock {
    current: Tick,
    pub elapsed_millis: u64,
    #[serde(skip, default = "Instant::now")]
    start_time: Instant,
}

impl Default for GameClock {
    fn default() -> Self {
        Self::new()
    }
}

impl GameClock {
    pub fn new() -> Self {
        Self {
            current: Tick::ZERO,
            elapsed_millis: 0,
            start_time: Instant::now(),
        }
    }

    pub fn current(&self) -> Tick {
        self.current
    }

    pub fn elapsed_millis(&self) -> u64 {
        self.elapsed_millis
    }

    /// Avanza un tick y devuelve el nuevo valor.
    pub fn advance(&mut self) -> Tick {
        self.current = self.current.next();
        self.elapsed_millis = self.start_time.elapsed().as_millis() as u64;
        self.current
    }
}
