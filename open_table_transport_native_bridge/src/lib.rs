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
