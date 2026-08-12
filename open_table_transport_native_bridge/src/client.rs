use std::collections::VecDeque;

use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;

use crate::handshake::{HandshakeRequest, HandshakeResponse};
use crate::link::RawByteLink;

/// Identidad que usa el cliente para etiquetar todo lo que recibe del
/// host — mismo valor que `open_table_transport_tcp::HOST_PLAYER_ID`,
/// por consistencia entre transportes.
pub const HOST_PLAYER_ID: PlayerId = PlayerId(0);

/// El handshake acá es asincrónico a propósito: conectar por Bluetooth/
/// Nearby no es instantáneo como un `TcpStream::connect`, así que en vez
/// de bloquear esperando la respuesta, quien use este transporte hace
/// polling con `poll_handshake()` hasta obtener un resultado — encaja
/// natural con el loop de ticks de un juego.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HandshakeStatus {
    Pending,
    Established {
        player_id: PlayerId,
        reconnect_token: String,
    },
    Rejected {
        reason: String,
    },
}

enum InternalStatus {
    Pending,
    Established {
        player_id: PlayerId,
        reconnect_token: String,
    },
    Rejected,
}

pub struct NativeClientTransport<L: RawByteLink> {
    link: L,
    status: InternalStatus,
    incoming: VecDeque<(PlayerId, Vec<u8>)>,
}

impl<L: RawByteLink> NativeClientTransport<L> {
    /// Primera conexión: pide un `PlayerId` nuevo. Llamar a
    /// `poll_handshake()` hasta obtener `Established`/`Rejected`.
    pub fn begin_join(mut link: L, player_name: &str) -> EngineResult<Self> {
        let request = HandshakeRequest::Join {
            player_name: player_name.to_string(),
        };
        let bytes =
            serde_json::to_vec(&request).map_err(|e| EngineError::Serialization(e.to_string()))?;
        link.broadcast_raw(&bytes)?;

        Ok(Self {
            link,
            status: InternalStatus::Pending,
            incoming: VecDeque::new(),
        })
    }

    /// Reconexión: prueba identidad con el token que el host dio antes.
    pub fn begin_reconnect(
        mut link: L,
        player_id: PlayerId,
        reconnect_token: String,
    ) -> EngineResult<Self> {
        let request = HandshakeRequest::Reconnect {
            player_id,
            reconnect_token,
        };
        let bytes =
            serde_json::to_vec(&request).map_err(|e| EngineError::Serialization(e.to_string()))?;
        link.broadcast_raw(&bytes)?;

        Ok(Self {
            link,
            status: InternalStatus::Pending,
            incoming: VecDeque::new(),
        })
    }

    /// Hay que llamarlo en el loop de ticks hasta que devuelva algo
    /// distinto de `Pending`. Una vez `Established`, este transporte ya
    /// funciona con `Transport::send`/`poll_received` normalmente.
    ///
    /// Importante: guardá el `reconnect_token` que devuelve acá — es lo
    /// único que te va a permitir reconectarte si la conexión se cae
    /// más adelante. Este transporte no lo persiste por vos.
    pub fn poll_handshake(&mut self) -> HandshakeStatus {
        self.drain_link();
        match &self.status {
            InternalStatus::Pending => HandshakeStatus::Pending,
            InternalStatus::Established {
                player_id,
                reconnect_token,
            } => HandshakeStatus::Established {
                player_id: *player_id,
                reconnect_token: reconnect_token.clone(),
            },
            InternalStatus::Rejected => HandshakeStatus::Rejected {
                reason: "conexión rechazada por el host".to_string(),
            },
        }
    }

    fn drain_link(&mut self) {
        for (_, bytes) in self.link.poll_raw_received() {
            if matches!(self.status, InternalStatus::Pending) {
                if let Ok(response) = serde_json::from_slice::<HandshakeResponse>(&bytes) {
                    match response {
                        HandshakeResponse::Welcome {
                            player_id,
                            reconnect_token,
                        } => {
                            self.status = InternalStatus::Established {
                                player_id,
                                reconnect_token,
                            };
                        }
                        HandshakeResponse::Rejected { .. } => {
                            self.status = InternalStatus::Rejected;
                        }
                    }
                    continue;
                }
            }
            // Ya establecido (o un mensaje que no es la respuesta de
            // handshake): es tráfico normal del juego.
            self.incoming.push_back((HOST_PLAYER_ID, bytes));
        }
    }
}

impl<L: RawByteLink> Transport for NativeClientTransport<L> {
    fn send(&mut self, _peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        self.link.broadcast_raw(bytes)
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        self.link.broadcast_raw(bytes)
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        self.drain_link();
        self.incoming.drain(..).collect()
    }

    fn health_check(&mut self) -> EngineResult<std::time::Duration> {
        Ok(std::time::Duration::ZERO)
    }
}
