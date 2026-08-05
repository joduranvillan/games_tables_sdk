//! `open_table_transport_tcp`: implementación de `Transport` sobre TCP
//! para desktop, con reconexión autenticada.

mod client;
mod framing;
mod handshake;
mod host;
mod lobby;
mod multi_session;

pub use client::{reconnect_to_host, RetryPolicy, TcpClientTransport, HOST_PLAYER_ID};
pub use handshake::{HandshakeRequest, HandshakeResponse, PROTOCOL_VERSION};
pub use host::{ConnectionEvent, TcpHostTransport};
pub use lobby::{JoinedPlayer, TcpLobby};
pub use multi_session::{MultiSessionServer, SessionHostTransport};
