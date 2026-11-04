// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_core::error::EngineResult;

/// Lo mínimo que un plugin nativo (Nearby Connections en Android,
/// MultipeerConnectivity en iOS) tiene que poder hacer, visto desde
/// Rust. A propósito NO sabe nada de `PlayerId`, `Command`, ni
/// handshake — eso vive en `NativeHostTransport`/`NativeClientTransport`,
/// que envuelven cualquier `RawByteLink` sin importar qué hay debajo.
///
/// `peer_tag` es el identificador que da la plataforma nativa: el
/// `endpointId` de Nearby Connections, o el `displayName`/hash de un
/// `MCPeerID` de MultipeerConnectivity. Es un string opaco — este crate
/// nunca intenta interpretarlo.
pub trait RawByteLink: Send {
    fn send_raw(&mut self, peer_tag: &str, bytes: &[u8]) -> EngineResult<()>;
    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()>;

    /// Vacía la cola de mensajes crudos recibidos desde el último poll.
    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)>;

    /// Vacía la cola de eventos de conexión (por ahora solo
    /// desconexión — ni Nearby ni Multipeer necesitan que este crate
    /// sepa de "descubrimiento", eso lo maneja la UI de Godot).
    fn poll_link_events(&mut self) -> Vec<RawLinkEvent>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RawLinkEvent {
    Disconnected(String),
}
