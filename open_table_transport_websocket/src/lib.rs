// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! `open_table_transport_websocket`: implementación de `Transport` sobre WebSocket
//! usando `tokio-tungstenite`.

mod client;
mod framing;
mod handshake;
mod host;

pub use client::{
    reconnect_backoff_duration, ReconnectPolicy, ReconnectState, RelayClientEvent,
    WsClientTransport, WsRelayClient, HEARTBEAT_INTERVAL, HOST_PLAYER_ID, MAX_RECONNECT_ATTEMPTS,
    RECONNECT_BACKOFF_MS,
};
pub use handshake::{HandshakeRequest, HandshakeResponse, PROTOCOL_VERSION};
pub use host::{ConnectionEvent, WsHostTransport};
