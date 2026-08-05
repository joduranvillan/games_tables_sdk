use std::collections::VecDeque;
use std::io::{self, ErrorKind};
use std::net::ToSocketAddrs;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;
use tokio::sync::mpsc;
use tokio_tungstenite::connect_async;

use crate::framing::{extract_bytes, wrap_binary};
use crate::handshake::{HandshakeRequest, HandshakeResponse, PROTOCOL_VERSION};

pub const HOST_PLAYER_ID: PlayerId = PlayerId(0);

type IncomingQueue = Arc<Mutex<VecDeque<(PlayerId, Vec<u8>)>>>;

pub struct WsClientTransport {
    tx: mpsc::UnboundedSender<Vec<u8>>,
    incoming: IncomingQueue,
    _runtime_thread: Option<thread::JoinHandle<()>>,
}

impl WsClientTransport {
    pub fn connect_as_new_player(
        addr: impl ToSocketAddrs,
        player_name: &str,
    ) -> io::Result<(Self, PlayerId, String)> {
        let sock_addr = addr
            .to_socket_addrs()?
            .next()
            .ok_or_else(|| io::Error::new(ErrorKind::InvalidInput, "Dirección inválida"))?;

        let url = format!("ws://{sock_addr}");
        let (tx_to_ws, mut rx_from_client) = mpsc::unbounded_channel::<Vec<u8>>();
        let (tx_handshake, mut rx_handshake) = mpsc::unbounded_channel::<io::Result<(PlayerId, String)>>();

        let incoming: IncomingQueue = Arc::new(Mutex::new(VecDeque::new()));
        let incoming_clone = Arc::clone(&incoming);
        let player_name = player_name.to_string();

        let handle = thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to build Tokio runtime");

            rt.block_on(async move {
                let ws_stream = match connect_async(&url).await {
                    Ok((ws, _)) => ws,
                    Err(e) => {
                        let _ = tx_handshake.send(Err(io::Error::new(ErrorKind::ConnectionRefused, e)));
                        return;
                    }
                };

                let (mut ws_sender, mut ws_receiver) = ws_stream.split();

                // Send Handshake
                let req = HandshakeRequest::Join {
                    player_name,
                    protocol_version: PROTOCOL_VERSION.to_string(),
                    route: None,
                };
                let req_bytes = serde_json::to_vec(&req).unwrap();
                if ws_sender.send(wrap_binary(&req_bytes)).await.is_err() {
                    let _ = tx_handshake.send(Err(io::Error::new(ErrorKind::ConnectionReset, "Send error")));
                    return;
                }

                // Wait for response
                let resp_msg = match ws_receiver.next().await {
                    Some(Ok(msg)) => extract_bytes(&msg),
                    _ => None,
                };

                let (player_id, token) = match resp_msg {
                    Some(bytes) => match serde_json::from_slice::<HandshakeResponse>(&bytes) {
                        Ok(HandshakeResponse::Welcome { player_id, reconnect_token, .. }) => {
                            (player_id, reconnect_token)
                        }
                        Ok(HandshakeResponse::Rejected { reason }) => {
                            let _ = tx_handshake.send(Err(io::Error::new(ErrorKind::PermissionDenied, reason)));
                            return;
                        }
                        _ => {
                            let _ = tx_handshake.send(Err(io::Error::new(ErrorKind::InvalidData, "Respuesta inválida")));
                            return;
                        }
                    },
                    None => {
                        let _ = tx_handshake.send(Err(io::Error::new(ErrorKind::UnexpectedEof, "EOF handshake")));
                        return;
                    }
                };

                let _ = tx_handshake.send(Ok((player_id, token)));

                let send_task = tokio::spawn(async move {
                    while let Some(bytes) = rx_from_client.recv().await {
                        if ws_sender.send(wrap_binary(&bytes)).await.is_err() {
                            break;
                        }
                    }
                });

                while let Some(msg) = ws_receiver.next().await {
                    match msg {
                        Ok(m) => {
                            if let Some(bytes) = extract_bytes(&m) {
                                incoming_clone.lock().unwrap().push_back((HOST_PLAYER_ID, bytes));
                            }
                        }
                        Err(_) => break,
                    }
                }

                send_task.abort();
            });
        });

        match rx_handshake.blocking_recv() {
            Some(Ok((player_id, token))) => Ok((
                Self {
                    tx: tx_to_ws,
                    incoming,
                    _runtime_thread: Some(handle),
                },
                player_id,
                token,
            )),
            Some(Err(err)) => Err(err),
            None => Err(io::Error::new(ErrorKind::ConnectionAborted, "Canal cerrado")),
        }
    }

    pub fn send_command(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        self.send(peer, bytes)
    }

    pub fn poll_events(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        self.poll_received()
    }
}

impl Transport for WsClientTransport {
    fn send(&mut self, _peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        self.tx
            .send(bytes.to_vec())
            .map_err(|e| EngineError::Network(e.to_string()))
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        self.send(HOST_PLAYER_ID, bytes)
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        let mut queue = self.incoming.lock().unwrap();
        queue.drain(..).collect()
    }

    fn health_check(&mut self) -> EngineResult<Duration> {
        Ok(Duration::ZERO)
    }
}
