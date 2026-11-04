// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Piece {
    pub owner: PlayerId,
    /// Si ya llegó a la última fila del rival y se coronó. Una dama se
    /// puede mover (y capturar) en cualquier dirección diagonal, no solo
    /// hacia adelante.
    pub is_king: bool,
}
