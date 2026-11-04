// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Hazard {
    FlatTire,
    OutOfGas,
    Accident,
    SpeedLimit,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Safety {
    RightOfWay,
    ExtraTank,
    PunctureProof,
    DrivingAce,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Card {
    Distance(u32),
    Hazard(Hazard),
    /// Cura el `Hazard` del mismo tipo.
    Remedy(Hazard),
    Safety(Safety),
    RightOfWay,
}
