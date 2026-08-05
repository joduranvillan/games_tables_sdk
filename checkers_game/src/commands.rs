use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;

use crate::position::Position;

/// El único comando de damas: mover una ficha de una casilla a otra. La
/// misma estructura sirve tanto para un paso simple (distancia diagonal
/// de 1) como para una captura (distancia diagonal de 2, saltando una
/// ficha rival) — el `RuleEngine` distingue cuál es cuál según la
/// distancia.
#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct MovePieceCommand {
    #[issuer]
    pub player: PlayerId,
    pub from: Position,
    pub to: Position,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}
