use std::collections::{HashMap, VecDeque};
use std::io::{self, ErrorKind};
use std::net::ToSocketAddrs;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::thread;
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tokio::sync::{mpsc, oneshot};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message;

use crate::framing::{extract_bytes, wrap_binary};
use crate::handshake::{HandshakeRequest, HandshakeResponse, PROTOCOL_VERSION};

pub const HOST_PLAYER_ID: PlayerId = PlayerId(0);

/// Intervalo de heartbeat ping/pong (15 segundos) para mantener vivas las conexiones
/// detrás de proxies reversos y routers NAT.
pub const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(15);

/// Alfabeto legible de 32 caracteres (sin `O`, `0`, `I`, `1`).
const RELAY_CODE_ALPHABET: &[u8; 32] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

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
        let (tx_handshake, mut rx_handshake) =
            mpsc::unbounded_channel::<io::Result<(PlayerId, String)>>();

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
                        let _ =
                            tx_handshake.send(Err(io::Error::new(ErrorKind::ConnectionRefused, e)));
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
                    let _ = tx_handshake.send(Err(io::Error::new(
                        ErrorKind::ConnectionReset,
                        "Send error",
                    )));
                    return;
                }

                // Wait for response
                let resp_msg = match ws_receiver.next().await {
                    Some(Ok(msg)) => extract_bytes(&msg),
                    _ => None,
                };

                let (player_id, token) = match resp_msg {
                    Some(bytes) => match serde_json::from_slice::<HandshakeResponse>(&bytes) {
                        Ok(HandshakeResponse::Welcome {
                            player_id,
                            reconnect_token,
                            ..
                        }) => (player_id, reconnect_token),
                        Ok(HandshakeResponse::Rejected { reason }) => {
                            let _ = tx_handshake
                                .send(Err(io::Error::new(ErrorKind::PermissionDenied, reason)));
                            return;
                        }
                        _ => {
                            let _ = tx_handshake.send(Err(io::Error::new(
                                ErrorKind::InvalidData,
                                "Respuesta inválida",
                            )));
                            return;
                        }
                    },
                    None => {
                        let _ = tx_handshake.send(Err(io::Error::new(
                            ErrorKind::UnexpectedEof,
                            "EOF handshake",
                        )));
                        return;
                    }
                };

                let _ = tx_handshake.send(Ok((player_id, token)));

                let send_task = tokio::spawn(async move {
                    let mut heartbeat = tokio::time::interval(HEARTBEAT_INTERVAL);
                    // El primer tick ocurre inmediatamente; lo consumimos para esperar 15s reales.
                    heartbeat.tick().await;

                    loop {
                        tokio::select! {
                            maybe_bytes = rx_from_client.recv() => {
                                match maybe_bytes {
                                    Some(bytes) => {
                                        if ws_sender.send(wrap_binary(&bytes)).await.is_err() {
                                            break;
                                        }
                                    }
                                    None => break,
                                }
                            }
                            _ = heartbeat.tick() => {
                                if ws_sender.send(Message::Ping(Vec::new().into())).await.is_err() {
                                    break;
                                }
                            }
                        }
                    }
                });

                while let Some(msg) = ws_receiver.next().await {
                    match msg {
                        Ok(m) => {
                            if let Some(bytes) = extract_bytes(&m) {
                                incoming_clone
                                    .lock()
                                    .unwrap()
                                    .push_back((HOST_PLAYER_ID, bytes));
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
            None => Err(io::Error::new(
                ErrorKind::ConnectionAborted,
                "Canal cerrado",
            )),
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

// ============================================================================
// CLIENTE RELAY WEBSOCKET CON HEARTBEAT 15s Y HUB IN-PROCESS DE RESPALDO
// ============================================================================

/// Eventos de protocolo emitidos por [`WsRelayClient`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RelayClientEvent {
    /// Sala creada exitosamente con su código de 4 caracteres.
    RoomCreated { room_code: String },
    /// Resultado de intento de unión a una sala.
    RoomJoined {
        success: bool,
        player_id: PlayerId,
        room_code: String,
    },
    /// Un nuevo par se ha unido a la sala actual.
    PeerJoined { player_id: PlayerId },
    /// Un par existente ha salido o se ha desconectado de la sala.
    PeerLeft { player_id: PlayerId },
    /// Datos binarios/JSON recibidos desde otro participante a través del Relay.
    PayloadReceived { from: PlayerId, data: Vec<u8> },
    /// Respuesta Pong recibida del servidor Relay.
    PongReceived,
    /// Desconexión del servidor Relay.
    Disconnected,
    /// Mensaje de error reportado por el Relay.
    Error { message: String },
}

#[derive(Debug, Serialize, Deserialize)]
struct EncodedRelayPayload {
    #[serde(rename = "__ot_b64_hex")]
    hex: String,
}

fn encode_bytes_to_value(bytes: &[u8]) -> Value {
    if let Ok(s) = std::str::from_utf8(bytes) {
        if let Ok(json_val) = serde_json::from_str::<Value>(s) {
            return json_val;
        }
        return Value::String(s.to_string());
    }
    let mut hex = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        use std::fmt::Write;
        let _ = write!(&mut hex, "{b:02x}");
    }
    serde_json::to_value(EncodedRelayPayload { hex }).unwrap_or(Value::Null)
}

fn decode_value_to_bytes(val: &Value) -> Vec<u8> {
    if let Ok(encoded) = serde_json::from_value::<EncodedRelayPayload>(val.clone()) {
        let mut out = Vec::with_capacity(encoded.hex.len() / 2);
        let bytes = encoded.hex.as_bytes();
        let mut i = 0;
        while i + 1 < bytes.len() {
            if let Ok(s) = std::str::from_utf8(&bytes[i..i + 2]) {
                if let Ok(b) = u8::from_str_radix(s, 16) {
                    out.push(b);
                }
            }
            i += 2;
        }
        return out;
    }
    match val {
        Value::String(s) => s.as_bytes().to_vec(),
        other => serde_json::to_vec(other).unwrap_or_default(),
    }
}

fn generate_fallback_room_code() -> String {
    let mut buf = [0u8; 4];
    if getrandom::fill(&mut buf).is_err() {
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(0x5A5A_A5A5);
        for (i, b) in buf.iter_mut().enumerate() {
            *b = ((ts >> (i * 8)) & 0xFF) as u8;
        }
    }
    buf.iter()
        .map(|&b| RELAY_CODE_ALPHABET[(b as usize) % RELAY_CODE_ALPHABET.len()] as char)
        .collect()
}

fn is_valid_relay_code(code: &str) -> bool {
    code.len() == 4
        && code
            .bytes()
            .all(|b| RELAY_CODE_ALPHABET.contains(&b.to_ascii_uppercase()))
}

type RelayEventQueue = Arc<Mutex<VecDeque<RelayClientEvent>>>;
type RoomMemberEntry = (u64, PlayerId, RelayEventQueue);

// Hub local en memoria para permitir que múltiples instancias de `WsRelayClient`
// dentro del mismo proceso (por ejemplo, tests headless de Godot sin daemon externo)
// se comuniquen de forma transparente si el servidor WebSocket remoto no está activo.
struct InProcessRoom {
    next_player_id: u32,
    members: Vec<RoomMemberEntry>,
}

static LOCAL_HUB_CLIENT_ID: AtomicU64 = AtomicU64::new(1);

fn local_relay_hub() -> &'static Mutex<HashMap<String, InProcessRoom>> {
    static HUB: OnceLock<Mutex<HashMap<String, InProcessRoom>>> = OnceLock::new();
    HUB.get_or_init(|| Mutex::new(HashMap::new()))
}

enum OutboundRelayCommand {
    Auth {
        token: String,
    },
    Create {
        game_id: String,
        reply: oneshot::Sender<Result<String, String>>,
    },
    Join {
        room_code: String,
        reply: oneshot::Sender<Result<u32, String>>,
    },
    Relay {
        data: Value,
    },
    Leave,
}

/// Cliente de transporte WebSocket preparado para comunicarse con `open_table_relay`.
///
/// Incluye un bucle de heartbeat automático cada [`HEARTBEAT_INTERVAL`] (15 segundos)
/// enviando `{"op":"ping"}` y tramas `Ping` de WebSocket para evitar cierres por inactividad.
pub struct WsRelayClient {
    client_id: u64,
    relay_url: String,
    cmd_tx: Option<mpsc::UnboundedSender<OutboundRelayCommand>>,
    events: Arc<Mutex<VecDeque<RelayClientEvent>>>,
    incoming_payloads: IncomingQueue,
    connected_remote: Arc<AtomicBool>,
    current_room: Option<String>,
    player_id: PlayerId,
    _worker: Option<thread::JoinHandle<()>>,
}

impl WsRelayClient {
    /// Conecta al servidor Relay en `relay_url` (ej. `"ws://127.0.0.1:8080"`).
    ///
    /// Si el servidor WebSocket responde, mantiene una tarea asíncrona con heartbeat
    /// cada 15 segundos. Si no hay servidor remoto escuchando, habilita el hub local
    /// en memoria como fallback determinista.
    pub fn connect(relay_url: &str) -> Self {
        let env_token = std::env::var("OPEN_TABLE_JWT_TOKEN")
            .ok()
            .filter(|t| !t.trim().is_empty());
        Self::connect_with_token(relay_url, env_token.as_deref())
    }

    /// Conecta al servidor Relay en `relay_url` y, si se provee `auth_token`, envía
    /// automáticamente `{"op": "auth", "token": "<jwt>"}` como primer mensaje al conectar.
    pub fn connect_with_token(relay_url: &str, auth_token: Option<&str>) -> Self {
        let client_id = LOCAL_HUB_CLIENT_ID.fetch_add(1, Ordering::Relaxed);
        let url = relay_url.trim().to_string();
        let initial_token = auth_token
            .map(str::trim)
            .filter(|t| !t.is_empty())
            .map(ToOwned::to_owned);
        let events: Arc<Mutex<VecDeque<RelayClientEvent>>> = Arc::new(Mutex::new(VecDeque::new()));
        let incoming_payloads: IncomingQueue = Arc::new(Mutex::new(VecDeque::new()));
        let connected_remote = Arc::new(AtomicBool::new(false));

        let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<OutboundRelayCommand>();
        let (conn_init_tx, conn_init_rx) = oneshot::channel::<bool>();

        let events_clone = Arc::clone(&events);
        let incoming_clone = Arc::clone(&incoming_payloads);
        let connected_flag = Arc::clone(&connected_remote);
        let url_for_thread = url.clone();

        let worker = thread::spawn(move || {
            let rt = match tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
            {
                Ok(rt) => rt,
                Err(_) => {
                    let _ = conn_init_tx.send(false);
                    return;
                }
            };

            rt.block_on(async move {
                let connect_fut = connect_async(&url_for_thread);
                let ws_stream =
                    match tokio::time::timeout(Duration::from_millis(400), connect_fut).await {
                        Ok(Ok((ws, _))) => {
                            connected_flag.store(true, Ordering::SeqCst);
                            let _ = conn_init_tx.send(true);
                            ws
                        }
                        _ => {
                            connected_flag.store(false, Ordering::SeqCst);
                            let _ = conn_init_tx.send(false);
                            return;
                        }
                    };

                let (mut ws_sink, mut ws_source) = ws_stream.split();
                if let Some(tok) = initial_token {
                    let auth_msg = serde_json::json!({
                        "op": "auth",
                        "token": tok,
                    })
                    .to_string();
                    if ws_sink.send(Message::Text(auth_msg.into())).await.is_err() {
                        connected_flag.store(false, Ordering::SeqCst);
                        return;
                    }
                }
                let mut heartbeat = tokio::time::interval(HEARTBEAT_INTERVAL);
                heartbeat.tick().await;

                let mut pending_create: Option<oneshot::Sender<Result<String, String>>> = None;
                let mut pending_join: Option<(String, oneshot::Sender<Result<u32, String>>)> = None;

                loop {
                    tokio::select! {
                        maybe_cmd = cmd_rx.recv() => {
                            match maybe_cmd {
                                Some(OutboundRelayCommand::Auth { token }) => {
                                    let msg = serde_json::json!({
                                        "op": "auth",
                                        "token": token,
                                    }).to_string();
                                    if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                                        break;
                                    }
                                }
                                Some(OutboundRelayCommand::Create { game_id, reply }) => {
                                    pending_create = Some(reply);
                                    let msg = serde_json::json!({
                                        "op": "create",
                                        "game_id": game_id,
                                        "is_public": true,
                                    }).to_string();
                                    if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                                        if let Some(r) = pending_create.take() {
                                            let _ = r.send(Err("websocket send failed".to_string()));
                                        }
                                        break;
                                    }
                                }
                                Some(OutboundRelayCommand::Join { room_code, reply }) => {
                                    pending_join = Some((room_code.clone(), reply));
                                    let msg = serde_json::json!({
                                        "op": "join",
                                        "room_code": room_code,
                                    }).to_string();
                                    if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                                        if let Some((_, r)) = pending_join.take() {
                                            let _ = r.send(Err("websocket send failed".to_string()));
                                        }
                                        break;
                                    }
                                }
                                Some(OutboundRelayCommand::Relay { data }) => {
                                    let msg = serde_json::json!({
                                        "op": "relay",
                                        "data": data,
                                    }).to_string();
                                    if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                                        break;
                                    }
                                }
                                Some(OutboundRelayCommand::Leave) => {
                                    let msg = r#"{"op":"leave"}"#.to_string();
                                    let _ = ws_sink.send(Message::Text(msg.into())).await;
                                }
                                None => break,
                            }
                        }
                        _ = heartbeat.tick() => {
                            // Enviamos ping de aplicación y trama Ping WebSocket cada 15s
                            let ping_json = r#"{"op":"ping"}"#.to_string();
                            if ws_sink.send(Message::Text(ping_json.into())).await.is_err() {
                                break;
                            }
                            if ws_sink.send(Message::Ping(Vec::new().into())).await.is_err() {
                                break;
                            }
                        }
                        maybe_ws = ws_source.next() => {
                            match maybe_ws {
                                Some(Ok(Message::Text(text))) => {
                                    if let Ok(val) = serde_json::from_str::<Value>(&text) {
                                        let op = val.get("op").and_then(|v| v.as_str()).unwrap_or("");
                                        match op {
                                            "created" => {
                                                let code = val.get("room_code")
                                                    .and_then(|v| v.as_str())
                                                    .unwrap_or("")
                                                    .to_string();
                                                if let Some(reply) = pending_create.take() {
                                                    let _ = reply.send(Ok(code.clone()));
                                                }
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::RoomCreated { room_code: code }
                                                );
                                            }
                                            "joined" => {
                                                let pid = val.get("player_id")
                                                    .and_then(|v| v.as_u64())
                                                    .unwrap_or(2) as u32;
                                                let code = pending_join
                                                    .as_ref()
                                                    .map(|(c, _)| c.clone())
                                                    .unwrap_or_default();
                                                if let Some((_, reply)) = pending_join.take() {
                                                    let _ = reply.send(Ok(pid));
                                                }
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::RoomJoined {
                                                        success: true,
                                                        player_id: PlayerId(pid),
                                                        room_code: code,
                                                    }
                                                );
                                            }
                                            "peer_joined" => {
                                                let pid = val.get("player_id")
                                                    .and_then(|v| v.as_u64())
                                                    .unwrap_or(2) as u32;
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::PeerJoined {
                                                        player_id: PlayerId(pid),
                                                    }
                                                );
                                            }
                                            "peer_left" => {
                                                let pid = val.get("player_id")
                                                    .and_then(|v| v.as_u64())
                                                    .unwrap_or(0) as u32;
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::PeerLeft {
                                                        player_id: PlayerId(pid),
                                                    }
                                                );
                                            }
                                            "relay" => {
                                                let from = val.get("from")
                                                    .and_then(|v| v.as_u64())
                                                    .unwrap_or(0) as u32;
                                                let bytes = val.get("data")
                                                    .map(decode_value_to_bytes)
                                                    .unwrap_or_default();
                                                incoming_clone.lock().unwrap().push_back((PlayerId(from), bytes.clone()));
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::PayloadReceived {
                                                        from: PlayerId(from),
                                                        data: bytes,
                                                    }
                                                );
                                            }
                                            "pong" => {
                                                events_clone.lock().unwrap().push_back(RelayClientEvent::PongReceived);
                                            }
                                            "error" => {
                                                let msg = val.get("message")
                                                    .and_then(|v| v.as_str())
                                                    .unwrap_or("relay error")
                                                    .to_string();
                                                if let Some(reply) = pending_create.take() {
                                                    let _ = reply.send(Err(msg.clone()));
                                                }
                                                if let Some((code, reply)) = pending_join.take() {
                                                    let _ = reply.send(Err(msg.clone()));
                                                    events_clone.lock().unwrap().push_back(
                                                        RelayClientEvent::RoomJoined {
                                                            success: false,
                                                            player_id: PlayerId(0),
                                                            room_code: code,
                                                        }
                                                    );
                                                }
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::Error { message: msg }
                                                );
                                            }
                                            _ => {}
                                        }
                                    }
                                }
                                Some(Ok(Message::Pong(_))) => {
                                    events_clone.lock().unwrap().push_back(RelayClientEvent::PongReceived);
                                }
                                Some(Ok(Message::Close(_))) | None | Some(Err(_)) => {
                                    connected_flag.store(false, Ordering::SeqCst);
                                    events_clone.lock().unwrap().push_back(RelayClientEvent::Disconnected);
                                    break;
                                }
                                _ => {}
                            }
                        }
                    }
                }
            });
        });

        let _ = conn_init_rx.blocking_recv();

        Self {
            client_id,
            relay_url: url,
            cmd_tx: Some(cmd_tx),
            events,
            incoming_payloads,
            connected_remote,
            current_room: None,
            player_id: PlayerId(0),
            _worker: Some(worker),
        }
    }

    /// URL del servidor Relay configurado.
    pub fn relay_url(&self) -> &str {
        &self.relay_url
    }

    /// Indica si está conectado a un servidor WebSocket remoto activo.
    pub fn is_remote_connected(&self) -> bool {
        self.connected_remote.load(Ordering::SeqCst)
    }

    /// Código de sala actual (si el cliente creó o se unió a una sala).
    pub fn room_code(&self) -> Option<&str> {
        self.current_room.as_deref()
    }

    /// `PlayerId` asignado en la sala actual (`PlayerId(1)` para host, `PlayerId(2..)` para invitado).
    pub fn player_id(&self) -> PlayerId {
        self.player_id
    }

    /// Envía el mensaje de autenticación `{"op": "auth", "token": "<jwt>"}` al servidor Relay.
    pub fn authenticate(&mut self, token: &str) -> EngineResult<()> {
        let trimmed = token.trim();
        if trimmed.is_empty() {
            return Ok(());
        }
        if self.is_remote_connected() {
            if let Some(tx) = &self.cmd_tx {
                return tx
                    .send(OutboundRelayCommand::Auth {
                        token: trimmed.to_string(),
                    })
                    .map_err(|e| EngineError::Network(e.to_string()));
            }
        }
        Ok(())
    }

    /// Solicita la creación de una sala para `game_id` y devuelve el código de 4 caracteres.
    pub fn create_room(&mut self, game_id: &str) -> EngineResult<String> {
        if self.is_remote_connected() {
            if let Some(tx) = &self.cmd_tx {
                let (reply_tx, reply_rx) = oneshot::channel();
                if tx
                    .send(OutboundRelayCommand::Create {
                        game_id: game_id.to_string(),
                        reply: reply_tx,
                    })
                    .is_ok()
                {
                    if let Ok(Ok(code)) = reply_rx.blocking_recv() {
                        self.current_room = Some(code.clone());
                        self.player_id = PlayerId(1);
                        return Ok(code);
                    }
                }
            }
        }

        // Fallback en hub local en memoria
        self.leave_local_hub();
        let mut hub = local_relay_hub().lock().unwrap();
        let code = loop {
            let candidate = generate_fallback_room_code();
            if !hub.contains_key(&candidate) {
                break candidate;
            }
        };
        hub.insert(
            code.clone(),
            InProcessRoom {
                next_player_id: 2,
                members: vec![(self.client_id, PlayerId(1), Arc::clone(&self.events))],
            },
        );
        drop(hub);

        self.current_room = Some(code.clone());
        self.player_id = PlayerId(1);
        self.events
            .lock()
            .unwrap()
            .push_back(RelayClientEvent::RoomCreated {
                room_code: code.clone(),
            });
        Ok(code)
    }

    /// Solicita unirse a la sala con código `code` y devuelve el `PlayerId` asignado.
    pub fn join_room(&mut self, code: &str) -> EngineResult<PlayerId> {
        let normalized = code.trim().to_ascii_uppercase();
        if !is_valid_relay_code(&normalized) {
            self.events
                .lock()
                .unwrap()
                .push_back(RelayClientEvent::RoomJoined {
                    success: false,
                    player_id: PlayerId(0),
                    room_code: normalized,
                });
            return Err(EngineError::Network("Código de sala inválido".to_string()));
        }

        if self.is_remote_connected() {
            if let Some(tx) = &self.cmd_tx {
                let (reply_tx, reply_rx) = oneshot::channel();
                if tx
                    .send(OutboundRelayCommand::Join {
                        room_code: normalized.clone(),
                        reply: reply_tx,
                    })
                    .is_ok()
                {
                    match reply_rx.blocking_recv() {
                        Ok(Ok(pid)) => {
                            let player = PlayerId(pid);
                            self.current_room = Some(normalized);
                            self.player_id = player;
                            return Ok(player);
                        }
                        Ok(Err(err)) => {
                            return Err(EngineError::Network(err));
                        }
                        Err(_) => {}
                    }
                }
            }
        }

        // Fallback en hub local en memoria
        self.leave_local_hub();
        let mut hub = local_relay_hub().lock().unwrap();
        let Some(room) = hub.get_mut(&normalized) else {
            drop(hub);
            self.events
                .lock()
                .unwrap()
                .push_back(RelayClientEvent::RoomJoined {
                    success: false,
                    player_id: PlayerId(0),
                    room_code: normalized,
                });
            return Err(EngineError::Network("Sala no encontrada".to_string()));
        };

        let assigned_pid = PlayerId(room.next_player_id);
        room.next_player_id += 1;
        for (_, _, member_events) in &room.members {
            member_events
                .lock()
                .unwrap()
                .push_back(RelayClientEvent::PeerJoined {
                    player_id: assigned_pid,
                });
        }
        room.members
            .push((self.client_id, assigned_pid, Arc::clone(&self.events)));
        drop(hub);

        self.current_room = Some(normalized.clone());
        self.player_id = assigned_pid;
        self.events
            .lock()
            .unwrap()
            .push_back(RelayClientEvent::RoomJoined {
                success: true,
                player_id: assigned_pid,
                room_code: normalized,
            });
        Ok(assigned_pid)
    }

    /// Envía datos a los demás participantes de la sala actual a través del Relay.
    pub fn send_relay_data(&mut self, bytes: &[u8]) -> EngineResult<()> {
        if self.is_remote_connected() {
            if let Some(tx) = &self.cmd_tx {
                let data_val = encode_bytes_to_value(bytes);
                return tx
                    .send(OutboundRelayCommand::Relay { data: data_val })
                    .map_err(|e| EngineError::Network(e.to_string()));
            }
        }

        let Some(code) = &self.current_room else {
            return Err(EngineError::Network(
                "El cliente no está en una sala".into(),
            ));
        };
        let hub = local_relay_hub().lock().unwrap();
        if let Some(room) = hub.get(code) {
            for (cid, _, member_events) in &room.members {
                if *cid != self.client_id {
                    member_events
                        .lock()
                        .unwrap()
                        .push_back(RelayClientEvent::PayloadReceived {
                            from: self.player_id,
                            data: bytes.to_vec(),
                        });
                }
            }
            Ok(())
        } else {
            Err(EngineError::Network("Sala no encontrada".into()))
        }
    }

    /// Abandona la sala actual y notifica a los participantes restantes.
    pub fn leave_room(&mut self) -> EngineResult<()> {
        if self.is_remote_connected() {
            if let Some(tx) = &self.cmd_tx {
                let _ = tx.send(OutboundRelayCommand::Leave);
            }
        }
        self.leave_local_hub();
        self.current_room = None;
        self.player_id = PlayerId(0);
        Ok(())
    }

    fn leave_local_hub(&mut self) {
        let Some(code) = self.current_room.take() else {
            return;
        };
        let mut hub = local_relay_hub().lock().unwrap();
        let mut remove_room = false;
        if let Some(room) = hub.get_mut(&code) {
            room.members.retain(|(cid, _, _)| *cid != self.client_id);
            for (_, _, member_events) in &room.members {
                member_events
                    .lock()
                    .unwrap()
                    .push_back(RelayClientEvent::PeerLeft {
                        player_id: self.player_id,
                    });
            }
            remove_room = room.members.is_empty();
        }
        if remove_room {
            hub.remove(&code);
        }
    }

    /// Extrae todos los eventos pendientes recibidos desde el Relay.
    pub fn poll_relay_events(&mut self) -> Vec<RelayClientEvent> {
        let mut q = self.events.lock().unwrap();
        q.drain(..).collect()
    }
}

impl Drop for WsRelayClient {
    fn drop(&mut self) {
        self.leave_local_hub();
    }
}

impl Transport for WsRelayClient {
    fn send(&mut self, _peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        self.send_relay_data(bytes)
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        self.send_relay_data(bytes)
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        let mut out: Vec<(PlayerId, Vec<u8>)> =
            self.incoming_payloads.lock().unwrap().drain(..).collect();
        let mut ev_queue = self.events.lock().unwrap();
        let mut remaining = VecDeque::new();
        while let Some(ev) = ev_queue.pop_front() {
            if let RelayClientEvent::PayloadReceived { from, data } = ev {
                out.push((from, data));
            } else {
                remaining.push_back(ev);
            }
        }
        *ev_queue = remaining;
        out
    }

    fn health_check(&mut self) -> EngineResult<Duration> {
        Ok(Duration::ZERO)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_heartbeat_interval_is_15_seconds() {
        assert_eq!(HEARTBEAT_INTERVAL, Duration::from_secs(15));
    }

    #[test]
    fn test_ws_relay_client_room_flow_and_events() {
        let mut host_client = WsRelayClient::connect("ws://127.0.0.1:9");
        let mut guest_client = WsRelayClient::connect("ws://127.0.0.1:9");

        let code = host_client.create_room("chess").unwrap();
        assert_eq!(code.len(), 4);
        assert!(is_valid_relay_code(&code));
        assert_eq!(host_client.player_id(), PlayerId(1));

        let host_events = host_client.poll_relay_events();
        assert!(host_events.contains(&RelayClientEvent::RoomCreated {
            room_code: code.clone()
        }));

        let guest_pid = guest_client.join_room(&code).unwrap();
        assert_eq!(guest_pid, PlayerId(2));

        let guest_events = guest_client.poll_relay_events();
        assert!(guest_events.contains(&RelayClientEvent::RoomJoined {
            success: true,
            player_id: PlayerId(2),
            room_code: code.clone(),
        }));

        let host_events = host_client.poll_relay_events();
        assert!(host_events.contains(&RelayClientEvent::PeerJoined {
            player_id: PlayerId(2)
        }));

        host_client.send_relay_data(b"hello_relay").unwrap();
        let guest_events = guest_client.poll_relay_events();
        assert!(guest_events.contains(&RelayClientEvent::PayloadReceived {
            from: PlayerId(1),
            data: b"hello_relay".to_vec(),
        }));

        guest_client.leave_room().unwrap();
        let host_events = host_client.poll_relay_events();
        assert!(host_events.contains(&RelayClientEvent::PeerLeft {
            player_id: PlayerId(2)
        }));
    }
}
