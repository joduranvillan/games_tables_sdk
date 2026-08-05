//! IDs fundamentales. Todos son newtypes sobre enteros: sin punteros, sin
//! referencias, para que cualquier `Command`/`Event` que los contenga sea
//! trivialmente serializable y determinista entre plataformas.

use serde::{Deserialize, Serialize};

/// Identifica a un jugador dentro de una `Session`. Asignado por el host al
/// aceptar la conexión, nunca por el propio cliente.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct PlayerId(pub u32);

/// Identifica a un espectador dentro de una `Session`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct SpectatorId(pub u32);

/// Identifica una partida/sala completa.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct SessionId(pub u64);

/// Identifica una entidad dentro del ECS (jugador, propiedad, carta, ficha...).
/// Definido acá y no en el motor para que los `Command`/`Event` puedan
/// referenciar entidades sin depender del crate de ECS.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EntityId(pub u64);

/// Tick lógico de simulación. Nunca tiempo de reloj real (ver `time.rs`).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct Tick(pub u64);

impl Tick {
    pub const ZERO: Tick = Tick(0);

    pub fn next(self) -> Tick {
        Tick(self.0 + 1)
    }
}

impl From<u64> for Tick {
    fn from(val: u64) -> Self {
        Tick(val)
    }
}
