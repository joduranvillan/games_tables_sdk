use std::collections::HashMap;

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

/// Valores de dado que todavía quedan por usar este turno. Simplificado
/// respecto al backgammon real: sacar dobles siempre da los mismos 2
/// movimientos que cualquier tirada (no los 4 movimientos que otorgan
/// los dobles en la variante oficial) — alcanza para probar el
/// mecanismo sin esa regla especial.
#[derive(GameResource, Default)]
pub struct PendingDiceResource {
    pub pending: HashMap<PlayerId, Vec<u32>>,
}
