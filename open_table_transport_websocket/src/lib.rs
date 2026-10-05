//! `open_table_transport_websocket`: implementación de `Transport` sobre WebSocket
//! usando `tokio-tungstenite`.

mod client;
mod framing;
mod handshake;
mod host;

pub use client::{
    RelayClientEvent, WsClientTransport, WsRelayClient, HEARTBEAT_INTERVAL, HOST_PLAYER_ID,
};
pub use handshake::{HandshakeRequest, HandshakeResponse, PROTOCOL_VERSION};
pub use host::{ConnectionEvent, WsHostTransport};
