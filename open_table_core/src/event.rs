use serde::{Deserialize, Serialize};

use crate::ids::Tick;
use crate::visibility::Visibility;

/// Un `Event` representa un hecho consumado ("se pagó el alquiler", "se
/// reveló esta carta"). Es inmutable y, como `Command`, se define como
/// trait object serializable para que cada juego registre los suyos sin
/// tocar el core.
///
/// La diferencia clave respecto al `Event` del RFC original es el método
/// `visibility()`: sin esto, cualquier juego con información oculta (casi
/// todos los juegos de cartas) sería imposible de implementar sobre el
/// core, porque todo evento llegaría a todos los clientes.
#[typetag::serde(tag = "event_type")]
pub trait Event: std::fmt::Debug + Send + Sync {
    /// A quién le llega este evento. Por defecto público (Monopoly, Catan,
    /// ajedrez: casi todo es público). Un juego de cartas sobreescribe esto
    /// para las cartas de mano.
    fn visibility(&self) -> Visibility {
        Visibility::Public
    }

    /// Igual que en `Command`: permite hacer downcast a la struct
    /// concreta sin que `open_table_core` la conozca. `#[derive(GameEvent)]`
    /// de `open_table_macros` lo genera solo.
    fn as_any(&self) -> &dyn std::any::Any;
}

/// Sobre de red para un evento saliente del host.
#[derive(Debug, Serialize, Deserialize)]
pub struct EventEnvelope {
    pub tick: Tick,
    pub payload: Box<dyn Event>,
}
