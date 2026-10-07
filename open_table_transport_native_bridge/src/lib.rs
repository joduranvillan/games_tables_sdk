//! `open_table_transport_native_bridge`: la capa de protocolo que
//! comparten TODOS los transportes móviles nativos (Nearby Connections
//! en Android, MultipeerConnectivity en iOS, y cualquier otro que
//! aparezca). El plugin nativo real solo necesita implementar
//! `RawByteLink` — mover bytes hacia/desde un `peer_tag` — y toda la
//! lógica de handshake, identidad, reconexión y timeout se hereda
//! gratis, ya escrita y probada, sin duplicar nada en Kotlin/Swift.

mod client;
mod handshake;
mod host;
mod link;

pub use client::{HandshakeStatus, NativeClientTransport, HOST_PLAYER_ID};
pub use handshake::{generate_token, HandshakeRequest, HandshakeResponse};
pub use host::{ConnectionEvent, NativeHostTransport};
pub use link::{RawByteLink, RawLinkEvent};

use open_table_core::error::EngineResult;
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;

/// Transporte P2P unificado (Host o Client) parametrizado sobre cualquier `RawByteLink`
/// (por ejemplo `GodotRawByteLink` en `open_table_godot`).
pub enum NativeBridgeTransport<L: RawByteLink> {
    Host(NativeHostTransport<L>),
    Client(NativeClientTransport<L>),
}

impl<L: RawByteLink> NativeBridgeTransport<L> {
    pub fn new_host(link: L) -> Self {
        Self::Host(NativeHostTransport::new(link))
    }

    pub fn new_client(link: L, player_name: &str) -> EngineResult<Self> {
        Ok(Self::Client(NativeClientTransport::begin_join(
            link,
            player_name,
        )?))
    }

    pub fn into_host(self) -> Option<NativeHostTransport<L>> {
        match self {
            Self::Host(h) => Some(h),
            Self::Client(_) => None,
        }
    }

    pub fn into_client(self) -> Option<NativeClientTransport<L>> {
        match self {
            Self::Client(c) => Some(c),
            Self::Host(_) => None,
        }
    }

    pub fn as_host_mut(&mut self) -> Option<&mut NativeHostTransport<L>> {
        match self {
            Self::Host(h) => Some(h),
            Self::Client(_) => None,
        }
    }

    pub fn as_client_mut(&mut self) -> Option<&mut NativeClientTransport<L>> {
        match self {
            Self::Client(c) => Some(c),
            Self::Host(_) => None,
        }
    }
}

impl<L: RawByteLink> Transport for NativeBridgeTransport<L> {
    fn send(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        match self {
            Self::Host(h) => h.send(peer, bytes),
            Self::Client(c) => c.send(peer, bytes),
        }
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        match self {
            Self::Host(h) => h.broadcast(bytes),
            Self::Client(c) => c.broadcast(bytes),
        }
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        match self {
            Self::Host(h) => h.poll_received(),
            Self::Client(c) => c.poll_received(),
        }
    }

    fn health_check(&mut self) -> EngineResult<std::time::Duration> {
        match self {
            Self::Host(h) => h.health_check(),
            Self::Client(c) => c.health_check(),
        }
    }
}
