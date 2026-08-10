use std::collections::{HashMap, VecDeque};
use std::io;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;
use tokio::sync::mpsc;
use tokio_tungstenite::accept_async;

use crate::framing::{extract_bytes, wrap_binary};
use crate::handshake::{HandshakeRequest, HandshakeResponse, PROTOCOL_VERSION};

type IncomingQueue = Arc<Mutex<VecDeque<(PlayerId, Vec<u8>)>>>;
type Connections = Arc<Mutex<HashMap<PlayerId, mpsc::UnboundedSender<Vec<u8>>>>>;
type Sessions = Arc<Mutex<HashMap<PlayerId, String>>>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConnectionEvent {
    Connected { player: PlayerId },
    Reconnected { player: PlayerId },
    Disconnected { player: PlayerId },
}

pub struct WsHostTransport {
    local_addr: SocketAddr,
    connections: Connections,
    incoming: IncomingQueue,
    _runtime_thread: Option<thread::JoinHandle<()>>,
}

fn generate_token() -> String {
    let mut bytes = [0u8; 16];
    let _ = getrandom::fill(&mut bytes);
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

impl WsHostTransport {
    pub fn bind(addr: &str) -> io::Result<Self> {
        let std_listener = std::net::TcpListener::bind(addr)?;
        std_listener.set_nonblocking(true)?;
        let local_addr = std_listener.local_addr()?;

        let connections: Connections = Arc::new(Mutex::new(HashMap::new()));
        let incoming: IncomingQueue = Arc::new(Mutex::new(VecDeque::new()));
        let sessions: Sessions = Arc::new(Mutex::new(HashMap::new()));

        let connections_clone = Arc::clone(&connections);
        let incoming_clone = Arc::clone(&incoming);
        let sessions_clone = Arc::clone(&sessions);

        let handle = thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to create Tokio runtime");

            rt.block_on(async move {
                let listener = tokio::net::TcpListener::from_std(std_listener)
                    .expect("Failed to convert TcpListener");

                let mut next_player_id = 1u32;

                while let Ok((stream, _peer_addr)) = listener.accept().await {
                    let connections = Arc::clone(&connections_clone);
                    let incoming = Arc::clone(&incoming_clone);
                    let sessions = Arc::clone(&sessions_clone);

                    let player_id = PlayerId(next_player_id);
                    next_player_id += 1;

                    tokio::spawn(async move {
                        let ws_stream = match accept_async(stream).await {
                            Ok(ws) => ws,
                            Err(_) => return,
                        };

                        let (mut ws_sender, mut ws_receiver) = ws_stream.split();

                        // Perform handshake
                        let handshake_req = match ws_receiver.next().await {
                            Some(Ok(msg)) => {
                                if let Some(bytes) = extract_bytes(&msg) {
                                    serde_json::from_slice::<HandshakeRequest>(&bytes).ok()
                                } else {
                                    None
                                }
                            }
                            _ => None,
                        };

                        let assigned_player = match handshake_req {
                            Some(HandshakeRequest::Join { player_name: _, protocol_version, .. }) => {
                                if protocol_version != PROTOCOL_VERSION {
                                    let resp = HandshakeResponse::UnsupportedProtocolVersion {
                                        expected: PROTOCOL_VERSION.to_string(),
                                        got: protocol_version,
                                    };
                                    let bytes = serde_json::to_vec(&resp).unwrap();
                                    let _ = ws_sender.send(wrap_binary(&bytes)).await;
                                    return;
                                }
                                let token = generate_token();
                                sessions.lock().unwrap().insert(player_id, token.clone());
                                let resp = HandshakeResponse::Welcome {
                                    player_id,
                                    reconnect_token: token,
                                    protocol_version: PROTOCOL_VERSION.to_string(),
                                };
                                let bytes = serde_json::to_vec(&resp).unwrap();
                                if ws_sender.send(wrap_binary(&bytes)).await.is_err() {
                                    return;
                                }
                                player_id
                            }
                            Some(HandshakeRequest::Reconnect { player_id: recon_id, reconnect_token, protocol_version, .. }) => {
                                if protocol_version != PROTOCOL_VERSION {
                                    let resp = HandshakeResponse::UnsupportedProtocolVersion {
                                        expected: PROTOCOL_VERSION.to_string(),
                                        got: protocol_version,
                                    };
                                    let bytes = serde_json::to_vec(&resp).unwrap();
                                    let _ = ws_sender.send(wrap_binary(&bytes)).await;
                                    return;
                                }
                                let valid = {
                                    let s = sessions.lock().unwrap();
                                    s.get(&recon_id) == Some(&reconnect_token)
                                };
                                if !valid {
                                    let resp = HandshakeResponse::Rejected {
                                        reason: "Token de reconexión inválido".to_string(),
                                    };
                                    let bytes = serde_json::to_vec(&resp).unwrap();
                                    let _ = ws_sender.send(wrap_binary(&bytes)).await;
                                    return;
                                }
                                let resp = HandshakeResponse::Welcome {
                                    player_id: recon_id,
                                    reconnect_token,
                                    protocol_version: PROTOCOL_VERSION.to_string(),
                                };
                                let bytes = serde_json::to_vec(&resp).unwrap();
                                if ws_sender.send(wrap_binary(&bytes)).await.is_err() {
                                    return;
                                }
                                recon_id
                            }
                            None => return,
                        };

                        let (tx, mut rx) = mpsc::unbounded_channel::<Vec<u8>>();
                        connections.lock().unwrap().insert(assigned_player, tx);

                        let mut ws_sender = ws_sender;
                        let send_task = tokio::spawn(async move {
                            while let Some(bytes) = rx.recv().await {
                                if ws_sender.send(wrap_binary(&bytes)).await.is_err() {
                                    break;
                                }
                            }
                        });

                        while let Some(msg) = ws_receiver.next().await {
                            match msg {
                                Ok(msg) => {
                                    if let Some(bytes) = extract_bytes(&msg) {
                                        incoming.lock().unwrap().push_back((assigned_player, bytes));
                                    }
                                }
                                Err(_) => break,
                            }
                        }

                        send_task.abort();
                        connections.lock().unwrap().remove(&assigned_player);
                    });
                }
            });
        });

        Ok(Self {
            local_addr,
            connections,
            incoming,
            _runtime_thread: Some(handle),
        })
    }

    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    pub fn send_command(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        self.send(peer, bytes)
    }

    pub fn poll_events(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        self.poll_received()
    }
}

impl Transport for WsHostTransport {
    fn send(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        let conns = self.connections.lock().unwrap();
        if let Some(tx) = conns.get(&peer) {
            tx.send(bytes.to_vec())
                .map_err(|e| EngineError::Network(e.to_string()))?;
            Ok(())
        } else {
            Err(EngineError::Network(format!("Jugador {peer:?} no conectado")))
        }
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        let conns = self.connections.lock().unwrap();
        for tx in conns.values() {
            let _ = tx.send(bytes.to_vec());
        }
        Ok(())
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        let mut queue = self.incoming.lock().unwrap();
        queue.drain(..).collect()
    }

    fn health_check(&mut self) -> EngineResult<Duration> {
        Ok(Duration::ZERO)
    }
}
