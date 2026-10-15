use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;
use open_table_macros::GameCommand;

use crate::fleet::Ship;
use crate::position::Position;

/// Coloca la flota entera de una vez. A propósito NO pasa por
/// `TurnOrder`: colocar la flota es una fase de setup simultánea, no un
/// turno de juego — cada jugador la manda una sola vez, en cualquier
/// orden, y el `RuleEngine` la rechaza si ya la había mandado antes.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct PlaceFleetCommand {
    #[issuer]
    pub player: PlayerId,
    pub ships: Vec<Ship>,
}

/// Dispara a una casilla del tablero rival. Esta sí respeta `TurnOrder`
/// — es la fase de juego real, por turnos.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct FireShotCommand {
    #[issuer]
    pub player: PlayerId,
    pub target: Position,
}

/// Comando para solicitar revancha. Cuando ambos jugadores lo envían,
/// se reinicia la partida a la fase de colocación.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct RematchCommand {
    #[issuer]
    pub player: PlayerId,
}

/// Configura las reglas opcionales de Batalla Naval (ej. turno extra al acertar).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct SetBattleshipRulesCommand {
    #[serde(default)]
    pub extra_turn_on_hit: bool,
}

/// Comando para rendirse y conceder la partida al oponente.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, GameCommand)]
pub struct ResignCommand {
    #[issuer]
    pub player: PlayerId,
}

