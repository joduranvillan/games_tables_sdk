use serde::{Deserialize, Serialize};

use crate::ids::Tick;
use crate::ids::PlayerId;

/// Un `Command` es la intención de un jugador ("quiero tirar el dado",
/// "quiero jugar esta carta"). Es solo datos: nunca contiene lógica.
///
/// Se define como trait object serializable (`#[typetag::serde]`) en lugar
/// de una enum cerrada a propósito: así, el crate de un juego nuevo (ej.
/// `chess_plugin`) puede declarar sus propios comandos concretos sin que
/// `open_table_core` necesite conocerlos ni recompilarse.
#[typetag::serde(tag = "command_type")]
pub trait Command: std::fmt::Debug + Send + Sync {
    /// Clona el comando envuelto en un Box. Necesario para clonar `Box<dyn Command>`.
    fn clone_box(&self) -> Box<dyn Command>;

    /// Jugador que el propio comando DICE que lo emite. Esto es una
    /// afirmación del payload, no una verificación — por eso `Session`
    /// (en `open_table_engine`) exige que coincida con el `sender` real
    /// que vino de la conexión de red antes de ejecutar nada. Ver
    /// `Session::process_command`.
    fn issuer(&self) -> Option<PlayerId> {
        None
    }

    /// Necesario para que el rule engine (en `open_table_engine`) pueda
    /// hacer downcast a la struct concreta sin que `open_table_core` la
    /// conozca. `#[derive(GameCommand)]` de `open_table_macros` lo genera
    /// solo.
    fn as_any(&self) -> &dyn std::any::Any;
}

impl Clone for Box<dyn Command> {
    fn clone(&self) -> Self {
        self.as_ref().clone_box()
    }
}

/// Sobre de red para un comando. A propósito NO tiene un campo `sender`:
/// quién mandó el comando lo determina la capa de `Transport` (qué
/// conexión trajo estos bytes), nunca algo que viaja dentro del propio
/// mensaje — un campo `sender` acá sería trivial de falsificar para
/// cualquier cliente. Ver `Session::process_command` para la validación
/// real (contrasta `Command::issuer()` contra el sender verificado).
#[derive(Debug, Serialize, Deserialize)]
pub struct CommandEnvelope {
    pub tick: Tick,
    pub payload: Box<dyn Command>,
}
