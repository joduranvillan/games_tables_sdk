// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

/// Variante de juego (estándar o personalizada).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum GameVariant {
    Standard,
    Custom(String),
}
