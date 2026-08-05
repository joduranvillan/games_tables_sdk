/// Un `Resource` es estado global único dentro de la `Session` (el mazo,
/// el tablero, las reglas activas). Igual que `Component`, se define acá
/// solo como contrato mínimo; el mapeo real a `bevy_ecs::Resource` vive en
/// `open_table_engine`.
pub trait Resource: Send + Sync + 'static {}
