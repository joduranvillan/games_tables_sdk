// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! # `open_table_core`
//!
//! Core traits and types for deterministic turn-based board game engines.
//!
//! # Examples
//!
//! ```rust
//! use open_table_core::prelude::*;
//!
//! let p1 = PlayerId(1);
//! let p2 = PlayerId(2);
//! let diff = AiDifficulty::from_i64(2);
//! assert_eq!(diff, AiDifficulty::Hard);
//! assert_eq!(diff.max_depth(), 3);
//! assert!(diff.use_opening_book());
//!
//! let result = GameResult {
//!     winner: Some(p1),
//!     duration_ms: 15_000,
//!     total_moves: 42,
//!     players: vec![p1, p2],
//!     game_name: "chess".to_string(),
//! };
//! assert_eq!(result.winner, Some(PlayerId(1)));
//! ```
#![doc = include_str!("../README.md")]

use serde::{Deserialize, Serialize};

pub mod command;
pub mod component;
pub mod error;
pub mod event;
pub mod game_variant;
pub mod ids;
pub mod random;
pub mod resource;
pub mod time;
pub mod transport;
pub mod visibility;

/// Nivel de dificultad parametrizable para los motores de IA locales.
///
/// # Examples
///
/// ```rust
/// use open_table_core::AiDifficulty;
///
/// let difficulty = AiDifficulty::from_i64(3);
/// assert_eq!(difficulty, AiDifficulty::Expert);
/// assert_eq!(difficulty.max_depth(), 4);
/// assert_eq!(difficulty.rollouts(), 300);
/// assert!(difficulty.use_opening_book());
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
pub enum AiDifficulty {
    /// Nivel Fácil (profundidad 1, 50 rollouts, errores ocasionales 1 de cada 4 jugadas).
    Easy = 0,
    /// Nivel Medio (profundidad 2, 120 rollouts).
    #[default]
    Medium = 1,
    /// Nivel Difícil (profundidad 3, 200 rollouts).
    Hard = 2,
    /// Nivel Experto (profundidad 4, 300 rollouts).
    Expert = 3,
}

impl AiDifficulty {
    /// Convierte un entero (`0=Easy, 1=Medium, 2=Hard, 3=Expert`) en `AiDifficulty` (por defecto `Medium`).
    pub fn from_i64(value: i64) -> Self {
        match value {
            0 => Self::Easy,
            1 => Self::Medium,
            2 => Self::Hard,
            3 => Self::Expert,
            _ => Self::Medium,
        }
    }

    /// Profundidad máxima de búsqueda para algoritmos Minimax.
    pub fn max_depth(self) -> u8 {
        match self {
            Self::Easy => 1,
            Self::Medium => 2,
            Self::Hard => 3,
            Self::Expert => 4,
        }
    }

    /// Presupuesto total de simulaciones (rollouts) para MCTS / Monte Carlo.
    pub fn rollouts(self) -> usize {
        match self {
            Self::Easy => 50,
            Self::Medium => 120,
            Self::Hard => 200,
            Self::Expert => 300,
        }
    }

    /// Indica si este nivel de dificultad consulta el libro de aperturas teóricas (`Hard` y `Expert`).
    pub fn use_opening_book(self) -> bool {
        matches!(self, Self::Hard | Self::Expert)
    }

    /// Factor de aleatoriedad/ruido predeterminado (`0..=100%`) auto-escalado por nivel de dificultad.
    ///
    /// - `Easy`: `45%` (mayor exploración y variedad).
    /// - `Medium`: `25%` (variedad moderada entre jugadas competitivas).
    /// - `Hard`: `12%` (rotación controlada entre líneas principales equivalentes).
    /// - `Expert`: `5%` (micro-perturbación para desempatar jugadas de élite sin perder precisión).
    pub fn default_randomness_pct(self) -> u8 {
        match self {
            Self::Easy => 45,
            Self::Medium => 25,
            Self::Hard => 12,
            Self::Expert => 5,
        }
    }

    /// Genera un valor pseudoaleatorio determinista en `[0.0, 1.0]` a partir de `(seed, index, salt)`.
    pub fn noise_unit_float(seed: u64, index: usize, salt: u64) -> f32 {
        let mut x = seed
            .wrapping_add((index as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15))
            .wrapping_add(salt.wrapping_mul(0xBF58_476D_1CE4_E5B9))
            .wrapping_add(0x9E37_79B9_7F4A_7C15);
        x = (x ^ (x >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        x = (x ^ (x >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        x ^= x >> 31;
        ((x >> 40) as u32 as f32) / ((1u32 << 24) as f32)
    }

    /// Selecciona un índice entre las mejores jugadas dentro de la banda de seguridad (`safety_band`)
    /// aplicando perturbación controlada proporcional a `randomness_pct` (`0..=100`).
    ///
    /// - Si `randomness_pct == 0`, devuelve de forma 100% determinista el primer candidato con `max_score`.
    /// - Si `randomness_pct > 0`, filtra únicamente los candidatos cuyo score está a lo sumo a
    ///   `safety_band * (randomness_pct / 100.0)` del mejor score (evitando errores graves o blunders),
    ///   y aplica ruido pseudoaleatorio acotado dentro de esa ventana Top-K.
    pub fn select_top_k_with_noise(
        scores: &[f32],
        randomness_pct: u8,
        safety_band: f32,
        seed: u64,
    ) -> Option<usize> {
        if scores.is_empty() {
            return None;
        }
        let mut max_score = f32::NEG_INFINITY;
        let mut best_idx = 0usize;
        for (i, &s) in scores.iter().enumerate() {
            if s > max_score {
                max_score = s;
                best_idx = i;
            }
        }
        if randomness_pct == 0 || scores.len() <= 1 || safety_band <= 0.0 || !max_score.is_finite() {
            return Some(best_idx);
        }
        let pct = f32::from(randomness_pct.min(100)) / 100.0;
        let effective_band = (safety_band * pct).max(1e-4);

        let mut chosen_idx = best_idx;
        let mut best_perturbed = f32::NEG_INFINITY;
        for (i, &s) in scores.iter().enumerate() {
            if !s.is_finite() || (max_score - s) > effective_band + 1e-4 {
                continue;
            }
            let jitter = Self::noise_unit_float(seed, i, u64::from(randomness_pct)) * effective_band * 1.25;
            let perturbed = s + jitter;
            if perturbed > best_perturbed {
                best_perturbed = perturbed;
                chosen_idx = i;
            }
        }
        Some(chosen_idx)
    }

    /// Cuenta cuántos candidatos de `scores` entran dentro de la ventana Top-K (`safety_band * (randomness_pct / 100.0)`).
    pub fn count_top_k_candidates(scores: &[f32], randomness_pct: u8, safety_band: f32) -> usize {
        if scores.is_empty() {
            return 0;
        }
        let mut max_score = f32::NEG_INFINITY;
        for &s in scores {
            if s > max_score {
                max_score = s;
            }
        }
        if !max_score.is_finite() {
            return 1;
        }
        if randomness_pct == 0 || scores.len() <= 1 || safety_band <= 0.0 {
            return 1;
        }
        let pct = f32::from(randomness_pct.min(100)) / 100.0;
        let effective_band = (safety_band * pct).max(1e-4);
        let count = scores
            .iter()
            .filter(|&&s| s.is_finite() && (max_score - s) <= effective_band + 1e-4)
            .count();
        count.max(1)
    }
}

/// Telemetría determinista y diagnóstico de rendimiento de la última decisión de IA.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AiMoveTelemetry {
    pub game_type: String,
    pub ai_player: u32,
    pub tick: u64,
    pub difficulty: i64,
    pub randomness_pct: u8,
    pub seed: u64,
    pub evaluated_candidates: usize,
    pub top_k_candidates: usize,
    pub chosen_index: usize,
    pub chosen_score: f32,
    pub best_raw_score: f32,
    pub strategy_profile: String,
    pub command_summary: String,
    pub elapsed_us: u64,
}

/// Calcula un hash determinista FNV-1a de 64 bits sobre una secuencia de bytes.
/// Idéntico en todas las arquitecturas (Rust nativo, WASM32 y TypeScript).
pub fn deterministic_fnv1a_64(bytes: &[u8]) -> u64 {
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    for &b in bytes {
        hash ^= u64::from(b);
        hash = hash.wrapping_mul(0x0100_0000_01b3);
    }
    hash
}

/// Formatea un hash FNV-1a de 64 bits como cadena hexadecimal canónica (`0x0123456789abcdef`).
pub fn format_fnv1a_hex(hash: u64) -> String {
    format!("0x{hash:016x}")
}

/// Resultado final de una partida.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GameResult {
    pub winner: Option<ids::PlayerId>,
    pub duration_ms: u64,
    pub total_moves: u32,
    pub players: Vec<ids::PlayerId>,
    pub game_name: String,
}

/// Import único que necesita cualquier juego para arrancar:
/// `use open_table_core::prelude::*;`
pub mod prelude {
    pub use crate::command::{Command, CommandEnvelope};
    pub use crate::component::Component;
    pub use crate::error::{EngineError, EngineResult};
    pub use crate::event::{Event, EventEnvelope};
    pub use crate::game_variant::GameVariant;
    pub use crate::ids::{EntityId, PlayerId, SessionId, SpectatorId, Tick};
    pub use crate::random::RandomService;
    pub use crate::resource::Resource;
    pub use crate::time::GameClock;
    pub use crate::transport::Transport;
    pub use crate::visibility::{SpectatorVisibility, Visibility};
    pub use crate::{
        deterministic_fnv1a_64, format_fnv1a_hex, AiDifficulty, AiMoveTelemetry, GameResult,
    };
}
