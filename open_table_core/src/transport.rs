// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use std::time::Duration;

use crate::error::EngineResult;
use crate::ids::PlayerId;

/// Abstracción total de la red. `open_table_core` no sabe qué hay del otro
/// lado: puede ser Nearby Connections en Android, MultipeerConnectivity en
/// iOS, o un socket TCP en desktop para testing. Quien implementa este
/// trait vive fuera de este crate (en el puente de Godot o en un mock de
/// tests), nunca acá.
///
/// Los bytes que entran y salen ya son el resultado de serializar un
/// `CommandEnvelope` o `EventEnvelope` (ver `command.rs` / `event.rs`).
pub trait Transport: Send {
    /// Envía bytes a un jugador específico (el host respondiendo a un
    /// cliente en particular).
    fn send(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()>;

    /// Envía bytes a todos los jugadores conectados (el host difundiendo
    /// eventos).
    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()>;

    /// Vacía la cola de mensajes recibidos desde el último poll. Se llama
    /// una vez por tick desde el scheduler, nunca bloqueante.
    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)>;

    /// Chequeo de salud / latencia round-trip del transporte.
    fn health_check(&mut self) -> EngineResult<Duration> {
        Ok(Duration::ZERO)
    }
}
