use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Hazard {
    FlatTire,
    OutOfGas,
    Accident,
    SpeedLimit,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Safety {
    RightOfWay,
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
