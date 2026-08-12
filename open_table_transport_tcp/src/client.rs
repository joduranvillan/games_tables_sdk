//! Lado cliente de `Transport` sobre TCP.
//!
//! Dos formas de conectarse: `connect_as_new_player` (primera vez, el
//! host asigna un `PlayerId` nuevo y entrega un `reconnect_token`) y
//! `reconnect` (usando un `PlayerId`/token que el cliente ya tenía
//! guardado de una conexión anterior). Guardar ese token es
//! responsabilidad de quien use este crate (en Godot, por ejemplo,
//! `user://reconnect_token.json`) — este crate no lo persiste solo.

use std::collections::VecDeque;
use std::io::{self, ErrorKind};
use std::net::{TcpStream, ToSocketAddrs};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;
use serde::{Deserialize, Serialize};

use crate::framing::{read_frame, write_frame};
use crate::handshake::{HandshakeRequest, HandshakeResponse};

/// Política de reintentos para conexiones/reconexiones TCP.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct RetryPolicy {
    pub max_attempts: u32,
    pub base_backoff_ms: u64,
    pub max_backoff_ms: u64,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            max_attempts: 3,
            base_backoff_ms: 100,
            max_backoff_ms: 1000,
        }
    }
}

/// Identidad que usa el cliente para etiquetar todo lo que recibe: no hay
/// ambigüedad posible porque el cliente solo tiene una conexión (al
/// host), nunca a otros clientes.
pub const HOST_PLAYER_ID: PlayerId = PlayerId(0);

type IncomingQueue = Arc<Mutex<VecDeque<(PlayerId, Vec<u8>)>>>;

pub struct TcpClientTransport {
    stream: TcpStream,
    incoming: IncomingQueue,
    retry_policy: RetryPolicy,
}

impl TcpClientTransport {
    /// Configura la política de reintentos en el cliente.
    pub fn with_retry_policy(mut self, policy: RetryPolicy) -> Self {
        self.retry_policy = policy;
        self
    }

    pub fn retry_policy(&self) -> RetryPolicy {
        self.retry_policy
    }

    /// Reconecta al host aplicando una política de reintentos con backoff exponencial y jitter.
    pub fn reconnect_to_host(
        addr: impl ToSocketAddrs + Clone,
        player_id: PlayerId,
        reconnect_token: String,
        policy: RetryPolicy,
    ) -> io::Result<Self> {
        let mut attempt = 0;
        loop {
            attempt += 1;
            match Self::reconnect(addr.clone(), player_id, reconnect_token.clone()) {
                Ok(transport) => return Ok(transport.with_retry_policy(policy)),
                Err(err) => {
                    if attempt >= policy.max_attempts {
                        return Err(err);
                    }
                    let exp = policy.base_backoff_ms.saturating_mul(1 << (attempt - 1));
                    let backoff = exp.min(policy.max_backoff_ms);
                    let jitter = (attempt as u64 * 7) % 5;
                    thread::sleep(Duration::from_millis(backoff + jitter));
                }
            }
        }
    }

    /// Primera conexión: el host asigna un `PlayerId` nuevo. Devuelve el
    /// transporte junto con ese `PlayerId` y el `reconnect_token` — el
    /// llamador es responsable de guardar ambos para poder usar
    /// `reconnect` si la conexión se cae más adelante.
    pub fn connect_as_new_player(
        addr: impl ToSocketAddrs,
        player_name: &str,
    ) -> io::Result<(Self, PlayerId, String)> {
        Self::connect_as_new_player_with_route(addr, player_name, None)
    }

    pub fn connect_to_session(
        addr: impl ToSocketAddrs,
        session_id: open_table_core::ids::SessionId,
        player_name: &str,
    ) -> io::Result<(Self, PlayerId, String)> {
        Self::connect_as_new_player_with_route(addr, player_name, Some(format!("/session/{}", session_id.0)))
    }

    pub fn connect_as_new_player_with_route(
        addr: impl ToSocketAddrs,
        player_name: &str,
        route: Option<String>,
    ) -> io::Result<(Self, PlayerId, String)> {
        let mut stream = TcpStream::connect(addr)?;
        let request = HandshakeRequest::Join {
            player_name: player_name.to_string(),
            protocol_version: crate::handshake::PROTOCOL_VERSION.to_string(),
            route,
        };
        perform_handshake(&mut stream, &request)?;

        match read_handshake_response(&mut stream)? {
            HandshakeResponse::Welcome {
                player_id,
                reconnect_token,
                protocol_version,
            } => {
                if protocol_version != crate::handshake::PROTOCOL_VERSION {
                    return Err(io::Error::new(
                        ErrorKind::InvalidData,
                        format!(
                            "versión de protocolo no soportada: se esperaba {}, se recibió {}",
                            crate::handshake::PROTOCOL_VERSION,
                            protocol_version
                        ),
                    ));
                }
                let transport = Self::from_connected_stream(stream)?;
                Ok((transport, player_id, reconnect_token))
            }
            HandshakeResponse::UnsupportedProtocolVersion { expected, got } => Err(io::Error::new(
                ErrorKind::InvalidData,
                format!("versión de protocolo no soportada: se esperaba {expected}, se recibió {got}"),
            )),
            HandshakeResponse::Rejected { reason } => {
                Err(io::Error::new(ErrorKind::PermissionDenied, reason))
            }
        }
    }

    /// Reconexión: prueba identidad con el `reconnect_token` que el host
    /// dio la primera vez. Si el host no reconoce el `player_id` o el
    /// token no coincide, devuelve error (`PermissionDenied`) en vez de
    /// dejar pasar la conexión — el mismo principio de no confiar en una
    /// identidad simplemente declarada que ya aplicamos a los comandos.
    pub fn reconnect(
        addr: impl ToSocketAddrs,
        player_id: PlayerId,
        reconnect_token: String,
    ) -> io::Result<Self> {
        let mut stream = TcpStream::connect(addr)?;
        let request = HandshakeRequest::Reconnect {
            player_id,
            reconnect_token,
            protocol_version: crate::handshake::PROTOCOL_VERSION.to_string(),
            route: None,
        };
        perform_handshake(&mut stream, &request)?;

        match read_handshake_response(&mut stream)? {
            HandshakeResponse::Welcome { protocol_version, .. } => {
                if protocol_version != crate::handshake::PROTOCOL_VERSION {
                    return Err(io::Error::new(
                        ErrorKind::InvalidData,
                        format!(
                            "versión de protocolo no soportada: se esperaba {}, se recibió {}",
                            crate::handshake::PROTOCOL_VERSION,
                            protocol_version
                        ),
                    ));
                }
                Self::from_connected_stream(stream)
            }
            HandshakeResponse::UnsupportedProtocolVersion { expected, got } => Err(io::Error::new(
                ErrorKind::InvalidData,
                format!("versión de protocolo no soportada: se esperaba {expected}, se recibió {got}"),
            )),
            HandshakeResponse::Rejected { reason } => {
                Err(io::Error::new(ErrorKind::PermissionDenied, reason))
            }
        }
    }

    fn from_connected_stream(stream: TcpStream) -> io::Result<Self> {
        let read_stream = stream.try_clone()?;
        let incoming: IncomingQueue = Arc::new(Mutex::new(VecDeque::new()));
        let incoming_for_reader = Arc::clone(&incoming);

        thread::spawn(move || {
            let mut read_stream = read_stream;
            while let Ok(bytes) = read_frame(&mut read_stream) {
                incoming_for_reader
                    .lock()
                    .expect("lock de incoming envenenado")
                    .push_back((HOST_PLAYER_ID, bytes));
            }
        });

        Ok(Self {
            stream,
            incoming,
            retry_policy: RetryPolicy::default(),
        })
    }

    /// Cierra la conexión activamente. Importante: el thread de lectura
    /// en background tiene su propio clon del socket (`try_clone`), así
    /// que simplemente hacer `drop()` de este struct NO alcanza para
    /// cerrar la conexión del todo — `shutdown()` afecta a todos los
    /// clones del mismo socket subyacente, incluido el que usa ese
    /// thread, y es lo que hace que el host detecte la desconexión.
    pub fn disconnect(&self) -> io::Result<()> {
        self.stream.shutdown(std::net::Shutdown::Both)
    }
}

pub fn reconnect_to_host(
    addr: impl ToSocketAddrs + Clone,
    player_id: PlayerId,
    reconnect_token: String,
    policy: RetryPolicy,
) -> io::Result<TcpClientTransport> {
    TcpClientTransport::reconnect_to_host(addr, player_id, reconnect_token, policy)
}

fn perform_handshake(stream: &mut TcpStream, request: &HandshakeRequest) -> io::Result<()> {
    let bytes = serde_json::to_vec(request)
        .map_err(|e| io::Error::new(ErrorKind::InvalidData, e.to_string()))?;
    write_frame(stream, &bytes)
}

fn read_handshake_response(stream: &mut TcpStream) -> io::Result<HandshakeResponse> {
    let bytes = read_frame(stream)?;
    serde_json::from_slice(&bytes).map_err(|e| io::Error::new(ErrorKind::InvalidData, e.to_string()))
}

impl Transport for TcpClientTransport {
    fn send(&mut self, _peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        // El parámetro `peer` se ignora a propósito: un cliente solo
        // tiene una conexión posible (al host).
        write_frame(&mut self.stream, bytes).map_err(|e| EngineError::Network(e.to_string()))
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        self.send(HOST_PLAYER_ID, bytes)
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        let mut queue = self.incoming.lock().expect("lock de incoming envenenado");
        queue.drain(..).collect()
    }

    fn health_check(&mut self) -> EngineResult<std::time::Duration> {
        Ok(std::time::Duration::ZERO)
    }
}
