use open_table_core::command::CommandEnvelope;

/// Convierte un `CommandEnvelope` del log de comandos a una representación en texto legible.
pub fn format_command(envelope: &CommandEnvelope) -> String {
    let player_str = match envelope.payload.issuer() {
        Some(p) => format!("Player {}", p.0),
        None => "System".to_string(),
    };
    format!("Tick {} | {} | {:?}", envelope.tick.0, player_str, envelope.payload)
}
