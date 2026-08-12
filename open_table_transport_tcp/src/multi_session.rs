use std::collections::{HashMap, VecDeque};
use std::io;
use std::net::{SocketAddr, TcpListener, TcpStream, ToSocketAddrs};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::{PlayerId, SessionId};
use open_table_core::transport::Transport;

use crate::framing::{read_frame, write_frame};
use crate::handshake::{HandshakeRequest, HandshakeResponse, PROTOCOL_VERSION};
use crate::host::ConnectionEvent;

type IncomingQueue = Arc<Mutex<VecDeque<(PlayerId, Vec<u8>)>>>;
type Connections = Arc<Mutex<HashMap<PlayerId, TcpStream>>>;
type Sessions = Arc<Mutex<HashMap<PlayerId, String>>>;
type PlayerNames = Arc<Mutex<HashMap<PlayerId, String>>>;
type ConnectionEvents = Arc<Mutex<VecDeque<ConnectionEvent>>>;
type DisconnectTimes = Arc<Mutex<HashMap<PlayerId, Instant>>>;

/// Transport para una sesión individual dentro del `MultiSessionServer`.
#[derive(Clone)]
pub struct SessionHostTransport {
    session_id: SessionId,
    incoming: IncomingQueue,
    connections: Connections,
    connection_events: ConnectionEvents,
    sessions: Sessions,
    player_names: PlayerNames,
    disconnect_times: DisconnectTimes,
    next_id: Arc<Mutex<u32>>,
}

impl SessionHostTransport {
    pub fn new(session_id: SessionId) -> Self {
        Self {
            session_id,
            incoming: Arc::new(Mutex::new(VecDeque::new())),
            connections: Arc::new(Mutex::new(HashMap::new())),
            connection_events: Arc::new(Mutex::new(VecDeque::new())),
            sessions: Arc::new(Mutex::new(HashMap::new())),
            player_names: Arc::new(Mutex::new(HashMap::new())),
            disconnect_times: Arc::new(Mutex::new(HashMap::new())),
            next_id: Arc::new(Mutex::new(1)),
        }
    }

    pub fn session_id(&self) -> SessionId {
        self.session_id
    }

    pub fn poll_connection_events(&mut self) -> Vec<ConnectionEvent> {
        self.connection_events
            .lock()
            .expect("lock de connection_events envenenado")
            .drain(..)
            .collect()
    }

    pub fn player_names(&self) -> HashMap<PlayerId, String> {
        self.player_names
            .lock()
            .expect("lock de player_names envenenado")
            .clone()
    }

    pub fn handle_connection(&self, mut stream: TcpStream, request: HandshakeRequest) {
        if request.protocol_version() != PROTOCOL_VERSION {
            let response = HandshakeResponse::UnsupportedProtocolVersion {
                expected: PROTOCOL_VERSION.to_string(),
                got: request.protocol_version().to_string(),
            };
            if let Ok(bytes) = serde_json::to_vec(&response) {
                let _ = write_frame(&mut stream, &bytes);
            }
            return;
        }

        let outcome = self.resolve_handshake(request);

        let (player_id, token, event) = match outcome {
            Ok(tuple) => tuple,
            Err(reason) => {
                let response = HandshakeResponse::Rejected { reason };
                if let Ok(bytes) = serde_json::to_vec(&response) {
                    let _ = write_frame(&mut stream, &bytes);
                }
                return;
            }
        };

        let response = HandshakeResponse::Welcome {
            player_id,
            reconnect_token: token,
            protocol_version: PROTOCOL_VERSION.to_string(),
        };
        let Ok(response_bytes) = serde_json::to_vec(&response) else {
            return;
        };
        if write_frame(&mut stream, &response_bytes).is_err() {
            return;
        }

        let Ok(read_stream) = stream.try_clone() else {
            return;
        };

        self.disconnect_times
            .lock()
            .expect("lock de disconnect_times envenenado")
            .remove(&player_id);

        self.connections
            .lock()
            .expect("lock de connections envenenado")
            .insert(player_id, stream);
        self.connection_events
            .lock()
            .expect("lock de connection_events envenenado")
            .push_back(event);

        let incoming = Arc::clone(&self.incoming);
        let connections = Arc::clone(&self.connections);
        let disconnect_times = Arc::clone(&self.disconnect_times);
        let events = Arc::clone(&self.connection_events);

        let mut read_stream = read_stream;
        loop {
            match read_frame(&mut read_stream) {
                Ok(bytes) => {
                    incoming
                        .lock()
                        .expect("lock de incoming envenenado")
                        .push_back((player_id, bytes));
                }
                Err(_) => {
                    connections
                        .lock()
                        .expect("lock de connections envenenado")
                        .remove(&player_id);
                    disconnect_times
                        .lock()
                        .expect("lock de disconnect_times envenenado")
                        .insert(player_id, Instant::now());
                    events
                        .lock()
                        .expect("lock de connection_events envenenado")
                        .push_back(ConnectionEvent::Disconnected { player: player_id });
                    break;
                }
            }
        }
    }

    fn resolve_handshake(
        &self,
        request: HandshakeRequest,
    ) -> Result<(PlayerId, String, ConnectionEvent), String> {
        let mut sessions = self.sessions.lock().expect("lock de sessions envenenado");

        match request {
            HandshakeRequest::Join { player_name, .. } => {
                let player_id = {
                    let mut guard = self.next_id.lock().expect("lock de next_id envenenado");
                    let id = PlayerId(*guard);
                    *guard += 1;
                    id
                };
                let token = generate_token();
                sessions.insert(player_id, token.clone());
                self.player_names
                    .lock()
                    .expect("lock de player_names envenenado")
                    .insert(player_id, player_name);
                Ok((player_id, token, ConnectionEvent::Joined { player: player_id }))
            }
            HandshakeRequest::Reconnect {
                player_id,
                reconnect_token,
                ..
            } => match sessions.get(&player_id) {
                Some(existing_token) if *existing_token == reconnect_token => Ok((
                    player_id,
                    reconnect_token,
                    ConnectionEvent::Reconnected { player: player_id },
                )),
                Some(_) => Err("token de reconexión inválido".to_string()),
                None => Err(format!(
                    "no existe una sesión previa para {player_id:?} (¿expiró el plazo de reconexión?)"
                )),
            },
        }
    }
}

fn generate_token() -> String {
    let mut bytes = [0u8; 16];
    getrandom::fill(&mut bytes).expect("getrandom failed");
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

impl Transport for SessionHostTransport {
    fn send(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        let mut conns = self
            .connections
            .lock()
            .expect("lock de connections envenenado");
        let stream = conns
            .get_mut(&peer)
            .ok_or_else(|| EngineError::Network(format!("jugador {peer:?} no está conectado")))?;
        write_frame(stream, bytes).map_err(|e| EngineError::Network(e.to_string()))
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        let mut conns = self
            .connections
            .lock()
            .expect("lock de connections envenenado");
        for stream in conns.values_mut() {
            write_frame(stream, bytes).map_err(|e| EngineError::Network(e.to_string()))?;
        }
        Ok(())
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        let mut queue = self.incoming.lock().expect("lock de incoming envenenado");
        queue.drain(..).collect()
    }

    fn health_check(&mut self) -> EngineResult<Duration> {
        Ok(Duration::ZERO)
    }
}

pub struct MultiSessionServer {
    local_addr: SocketAddr,
    sessions: Arc<Mutex<HashMap<SessionId, SessionHostTransport>>>,
}

impl MultiSessionServer {
    pub fn bind(addr: impl ToSocketAddrs) -> io::Result<Self> {
        let listener = TcpListener::bind(addr)?;
        let local_addr = listener.local_addr()?;
        let sessions: Arc<Mutex<HashMap<SessionId, SessionHostTransport>>> =
            Arc::new(Mutex::new(HashMap::new()));

        let sessions_top = Arc::clone(&sessions);

        thread::spawn(move || {
            for stream_result in listener.incoming() {
                let Ok(mut stream) = stream_result else {
                    continue;
                };

                let sessions = Arc::clone(&sessions_top);

                thread::spawn(move || {
                    let Ok(request_bytes) = read_frame(&mut stream) else {
                        return;
                    };
                    let Ok(request) = serde_json::from_slice::<HandshakeRequest>(&request_bytes)
                    else {
                        return;
                    };

                    let target_session_id = parse_route(request.route());
                    let session_transport = {
                        let map = sessions.lock().expect("lock de sessions envenenado");
                        map.get(&target_session_id).cloned()
                    };

                    match session_transport {
                        Some(transport) => {
                            transport.handle_connection(stream, request);
                        }
                        None => {
                            let response = HandshakeResponse::Rejected {
                                reason: format!("Sesión {target_session_id:?} no encontrada"),
                            };
                            if let Ok(bytes) = serde_json::to_vec(&response) {
                                let _ = write_frame(&mut stream, &bytes);
                            }
                        }
                    }
                });
            }
        });

        Ok(Self {
            local_addr,
            sessions,
        })
    }

    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    pub fn create_session(&self, session_id: SessionId) -> SessionHostTransport {
        let transport = SessionHostTransport::new(session_id);
        self.sessions
            .lock()
            .expect("lock de sessions envenenado")
            .insert(session_id, transport.clone());
        transport
    }

    pub fn get_session(&self, session_id: SessionId) -> Option<SessionHostTransport> {
        self.sessions
            .lock()
            .expect("lock de sessions envenenado")
            .get(&session_id)
            .cloned()
    }
}

fn parse_route(route: Option<&str>) -> SessionId {
    if let Some(r) = route {
        let clean = r.trim_start_matches("/session/").trim_start_matches('/');
        if let Ok(id) = clean.parse::<u64>() {
            return SessionId(id);
        }
    }
    SessionId(1)
}
