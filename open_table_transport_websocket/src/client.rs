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

/// Número máximo de intentos de reconexión automática antes de declarar desconexión definitiva.
pub const MAX_RECONNECT_ATTEMPTS: u32 = 5;

/// Secuencia de backoff exponencial por intento en milisegundos (`500ms`, `1s`, `2s`, `4s`, hasta 5 intentos).
pub const RECONNECT_BACKOFF_MS: [u64; 5] = [500, 1000, 2000, 4000, 4000];

/// Devuelve la duración de espera de backoff para el intento `attempt` (`1..=5`).
pub const fn reconnect_backoff_duration(attempt: u32) -> Duration {
    let idx = if attempt == 0 {
        0
    } else if (attempt as usize) <= RECONNECT_BACKOFF_MS.len() {
        (attempt as usize) - 1
    } else {
        RECONNECT_BACKOFF_MS.len() - 1
    };
    Duration::from_millis(RECONNECT_BACKOFF_MS[idx])
}

/// Estado de reconexión automática del cliente WebSocket Relay.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReconnectState {
    /// Conexión establecida normalmente.
    Connected,
    /// Reconectando automáticamente con backoff exponencial (`attempt` de `1` a `max_attempts`).
    Reconnecting { attempt: u32, max_attempts: u32 },
    /// Desconectado definitivamente (sin sala activa o tras agotar los `max_attempts` intentos).
    Disconnected,
}

/// Política configurable de reconexión con backoff exponencial para [`WsRelayClient`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReconnectPolicy {
    pub max_attempts: u32,
    pub backoff_ms: [u64; 5],
}

impl Default for ReconnectPolicy {
    fn default() -> Self {
        Self {
            max_attempts: MAX_RECONNECT_ATTEMPTS,
            backoff_ms: RECONNECT_BACKOFF_MS,
        }
    }
}

impl ReconnectPolicy {
    /// Duración de espera antes de ejecutar el intento `attempt` (`1..=max_attempts`).
    pub fn delay_for_attempt(&self, attempt: u32) -> Duration {
        if self.backoff_ms.is_empty() {
            return Duration::from_millis(500);
        }
        let idx = attempt
            .saturating_sub(1)
            .min((self.backoff_ms.len() - 1) as u32) as usize;
        Duration::from_millis(self.backoff_ms[idx])
    }
}

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
    /// Intento de reconexión automática en curso (`attempt` en `1..=max_attempts`).
    Reconnecting { attempt: u32, max_attempts: u32 },
    /// Conexión restaurada exitosamente mediante `rejoin_room`.
    ConnectionRestored {
        room_code: String,
        player_id: PlayerId,
        seed: u64,
        commands: Vec<Value>,
    },
    /// Desconexión definitiva del servidor Relay (tras agotar los intentos o sin partida activa).
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
type CreateReplySender = oneshot::Sender<Result<String, String>>;
type JoinReplySender = oneshot::Sender<Result<u32, String>>;
type RejoinReplyPayload = (u32, u64, Vec<Value>);
type RejoinReplySender = oneshot::Sender<Result<RejoinReplyPayload, String>>;

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
        reply: CreateReplySender,
    },
    Join {
        room_code: String,
        reply: JoinReplySender,
    },
    Rejoin {
        room_code: String,
        player_id: Option<String>,
        reply: RejoinReplySender,
    },
    Relay {
        data: Value,
    },
    Leave,
}

/// Cliente de transporte WebSocket preparado para comunicarse con `open_table_relay`.
///
/// Incluye un bucle de heartbeat automático cada [`HEARTBEAT_INTERVAL`] (15 segundos)
/// enviando `{"op":"ping"}` y tramas `Ping` de WebSocket para evitar cierres por inactividad,
/// así como reconexión automática con backoff exponencial (`500ms`, `1s`, `2s`, `4s`, hasta 5 intentos)
/// enviando `{"op": "rejoin_room"}` cuando la conexión cae durante una partida activa.
pub struct WsRelayClient {
    client_id: u64,
    relay_url: String,
    cmd_tx: Option<mpsc::UnboundedSender<OutboundRelayCommand>>,
    events: Arc<Mutex<VecDeque<RelayClientEvent>>>,
    incoming_payloads: IncomingQueue,
    connected_remote: Arc<AtomicBool>,
    reconnect_state: Arc<Mutex<ReconnectState>>,
    shutdown_flag: Arc<AtomicBool>,
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
        Self::connect_with_policy(relay_url, auth_token, ReconnectPolicy::default())
    }

    /// Conecta al servidor Relay en `relay_url` con token opcional y una [`ReconnectPolicy`] específica.
    pub fn connect_with_policy(
        relay_url: &str,
        auth_token: Option<&str>,
        policy: ReconnectPolicy,
    ) -> Self {
        let client_id = LOCAL_HUB_CLIENT_ID.fetch_add(1, Ordering::Relaxed);
        let url = relay_url.trim().to_string();
        let initial_token = auth_token
            .map(str::trim)
            .filter(|t| !t.is_empty())
            .map(ToOwned::to_owned);
        let events: Arc<Mutex<VecDeque<RelayClientEvent>>> = Arc::new(Mutex::new(VecDeque::new()));
        let incoming_payloads: IncomingQueue = Arc::new(Mutex::new(VecDeque::new()));
        let connected_remote = Arc::new(AtomicBool::new(false));
        let reconnect_state = Arc::new(Mutex::new(ReconnectState::Connected));
        let shutdown_flag = Arc::new(AtomicBool::new(false));

        let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<OutboundRelayCommand>();
        let (conn_init_tx, conn_init_rx) = oneshot::channel::<bool>();

        let events_clone = Arc::clone(&events);
        let incoming_clone = Arc::clone(&incoming_payloads);
        let connected_flag = Arc::clone(&connected_remote);
        let reconnect_state_clone = Arc::clone(&reconnect_state);
        let shutdown_flag_clone = Arc::clone(&shutdown_flag);
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
                            *reconnect_state_clone.lock().unwrap() = ReconnectState::Connected;
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
                let mut current_auth_token = initial_token;
                if let Some(ref tok) = current_auth_token {
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

                let mut pending_create: Option<CreateReplySender> = None;
                let mut pending_join: Option<(String, JoinReplySender)> = None;
                let mut pending_rejoin: Option<RejoinReplySender> = None;

                let mut active_room_code: Option<String> = None;
                let mut active_player_id: u32 = 0;
                let mut intentional_leave = false;

                loop {
                    let connection_dropped = tokio::select! {
                        maybe_cmd = cmd_rx.recv() => {
                            match maybe_cmd {
                                Some(OutboundRelayCommand::Auth { token }) => {
                                    current_auth_token = Some(token.clone());
                                    let msg = serde_json::json!({
                                        "op": "auth",
                                        "token": token,
                                    }).to_string();
                                    ws_sink.send(Message::Text(msg.into())).await.is_err()
                                }
                                Some(OutboundRelayCommand::Create { game_id, reply }) => {
                                    intentional_leave = false;
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
                                        true
                                    } else {
                                        false
                                    }
                                }
                                Some(OutboundRelayCommand::Join { room_code, reply }) => {
                                    intentional_leave = false;
                                    pending_join = Some((room_code.clone(), reply));
                                    let msg = serde_json::json!({
                                        "op": "join",
                                        "room_code": room_code,
                                    }).to_string();
                                    if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                                        if let Some((_, r)) = pending_join.take() {
                                            let _ = r.send(Err("websocket send failed".to_string()));
                                        }
                                        true
                                    } else {
                                        false
                                    }
                                }
                                Some(OutboundRelayCommand::Rejoin { room_code, player_id, reply }) => {
                                    intentional_leave = false;
                                    pending_rejoin = Some(reply);
                                    let msg = match player_id {
                                        Some(pid) if !pid.trim().is_empty() => serde_json::json!({
                                            "op": "rejoin_room",
                                            "room_code": room_code,
                                            "player_id": pid,
                                        }),
                                        _ => serde_json::json!({
                                            "op": "rejoin_room",
                                            "room_code": room_code,
                                        }),
                                    }.to_string();
                                    if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                                        if let Some(r) = pending_rejoin.take() {
                                            let _ = r.send(Err("websocket send failed".to_string()));
                                        }
                                        true
                                    } else {
                                        false
                                    }
                                }
                                Some(OutboundRelayCommand::Relay { data }) => {
                                    let msg = serde_json::json!({
                                        "op": "relay",
                                        "data": data,
                                    }).to_string();
                                    ws_sink.send(Message::Text(msg.into())).await.is_err()
                                }
                                Some(OutboundRelayCommand::Leave) => {
                                    intentional_leave = true;
                                    active_room_code = None;
                                    active_player_id = 0;
                                    let msg = r#"{"op":"leave"}"#.to_string();
                                    let _ = ws_sink.send(Message::Text(msg.into())).await;
                                    false
                                }
                                None => {
                                    break;
                                }
                            }
                        }
                        _ = heartbeat.tick() => {
                            let ping_json = r#"{"op":"ping"}"#.to_string();
                            if ws_sink.send(Message::Text(ping_json.into())).await.is_err() {
                                true
                            } else {
                                ws_sink.send(Message::Ping(Vec::new().into())).await.is_err()
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
                                                active_room_code = Some(code.clone());
                                                active_player_id = 1;
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
                                                    .or_else(|| active_room_code.clone())
                                                    .unwrap_or_default();
                                                if !code.is_empty() {
                                                    active_room_code = Some(code.clone());
                                                }
                                                active_player_id = pid;
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
                                            "rejoined" => {
                                                let pid = val.get("player_id")
                                                    .and_then(|v| v.as_u64())
                                                    .map(|p| p as u32)
                                                    .unwrap_or_else(|| active_player_id.max(1));
                                                let code = val.get("room_code")
                                                    .and_then(|v| v.as_str())
                                                    .map(ToOwned::to_owned)
                                                    .or_else(|| active_room_code.clone())
                                                    .unwrap_or_default();
                                                let seed = val.get("seed")
                                                    .and_then(|v| v.as_u64())
                                                    .unwrap_or(1);
                                                let commands = val.get("commands")
                                                    .and_then(|v| v.as_array())
                                                    .cloned()
                                                    .unwrap_or_default();
                                                if !code.is_empty() {
                                                    active_room_code = Some(code.clone());
                                                }
                                                active_player_id = pid;
                                                if let Some(reply) = pending_rejoin.take() {
                                                    let _ = reply.send(Ok((pid, seed, commands.clone())));
                                                }
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::ConnectionRestored {
                                                        room_code: code,
                                                        player_id: PlayerId(pid),
                                                        seed,
                                                        commands,
                                                    }
                                                );
                                            }
                                            "peer_joined" | "opponent_reconnected" => {
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
                                                    .or_else(|| val.get("reason"))
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
                                                if let Some(reply) = pending_rejoin.take() {
                                                    let _ = reply.send(Err(msg.clone()));
                                                }
                                                events_clone.lock().unwrap().push_back(
                                                    RelayClientEvent::Error { message: msg }
                                                );
                                            }
                                            _ => {}
                                        }
                                    }
                                    false
                                }
                                Some(Ok(Message::Pong(_))) => {
                                    events_clone.lock().unwrap().push_back(RelayClientEvent::PongReceived);
                                    false
                                }
                                Some(Ok(Message::Close(_))) | None | Some(Err(_)) => true,
                                _ => false,
                            }
                        }
                    };

                    if !connection_dropped {
                        continue;
                    }

                    connected_flag.store(false, Ordering::SeqCst);

                    // Si no hay partida activa o el cierre fue voluntario, desconectar inmediatamente.
                    let Some(target_room) = active_room_code.clone() else {
                        *reconnect_state_clone.lock().unwrap() = ReconnectState::Disconnected;
                        events_clone
                            .lock()
                            .unwrap()
                            .push_back(RelayClientEvent::Disconnected);
                        break;
                    };
                    if intentional_leave || shutdown_flag_clone.load(Ordering::SeqCst) {
                        *reconnect_state_clone.lock().unwrap() = ReconnectState::Disconnected;
                        events_clone
                            .lock()
                            .unwrap()
                            .push_back(RelayClientEvent::Disconnected);
                        break;
                    }

                    // Intentar reconexión automática con backoff exponencial (hasta max_attempts = 5)
                    let mut restored = false;
                    let max_attempts = policy.max_attempts.max(1);
                    for attempt in 1..=max_attempts {
                        if shutdown_flag_clone.load(Ordering::SeqCst) {
                            break;
                        }
                        *reconnect_state_clone.lock().unwrap() = ReconnectState::Reconnecting {
                            attempt,
                            max_attempts,
                        };
                        events_clone
                            .lock()
                            .unwrap()
                            .push_back(RelayClientEvent::Reconnecting {
                                attempt,
                                max_attempts,
                            });

                        let delay = policy.delay_for_attempt(attempt);
                        tokio::time::sleep(delay).await;
                        if shutdown_flag_clone.load(Ordering::SeqCst) {
                            break;
                        }

                        let Ok(Ok((new_ws, _))) = tokio::time::timeout(
                            Duration::from_millis(600),
                            connect_async(&url_for_thread),
                        )
                        .await
                        else {
                            continue;
                        };

                        let (mut new_sink, mut new_source) = new_ws.split();

                        if let Some(ref tok) = current_auth_token {
                            let auth_msg = serde_json::json!({
                                "op": "auth",
                                "token": tok,
                            })
                            .to_string();
                            if new_sink.send(Message::Text(auth_msg.into())).await.is_err() {
                                continue;
                            }
                        }

                        let rejoin_msg = match (&current_auth_token, active_player_id) {
                            (None, pid) if pid > 0 => serde_json::json!({
                                "op": "rejoin_room",
                                "room_code": target_room,
                                "player_id": format!("player{pid}"),
                            }),
                            _ => serde_json::json!({
                                "op": "rejoin_room",
                                "room_code": target_room,
                            }),
                        }
                        .to_string();

                        if new_sink
                            .send(Message::Text(rejoin_msg.into()))
                            .await
                            .is_err()
                        {
                            continue;
                        }

                        // Esperar respuesta `rejoined` del servidor Relay
                        let wait_deadline =
                            tokio::time::Instant::now() + Duration::from_millis(800);
                        let mut attempt_rejoined = None;
                        while let Ok(Some(Ok(msg))) =
                            tokio::time::timeout_at(wait_deadline, new_source.next()).await
                        {
                            if let Message::Text(text) = msg {
                                if let Ok(val) = serde_json::from_str::<Value>(&text) {
                                    let op = val.get("op").and_then(|v| v.as_str()).unwrap_or("");
                                    if op == "rejoined" {
                                        let pid = val
                                            .get("player_id")
                                            .and_then(|v| v.as_u64())
                                            .map(|p| p as u32)
                                            .unwrap_or_else(|| active_player_id.max(1));
                                        let r_code = val
                                            .get("room_code")
                                            .and_then(|v| v.as_str())
                                            .unwrap_or(&target_room)
                                            .to_string();
                                        let seed =
                                            val.get("seed").and_then(|v| v.as_u64()).unwrap_or(1);
                                        let commands = val
                                            .get("commands")
                                            .and_then(|v| v.as_array())
                                            .cloned()
                                            .unwrap_or_default();
                                        attempt_rejoined = Some((r_code, pid, seed, commands));
                                        break;
                                    } else if op == "error" {
                                        break;
                                    }
                                }
                            } else if matches!(msg, Message::Close(_)) {
                                break;
                            }
                        }

                        if let Some((r_code, pid, seed, commands)) = attempt_rejoined {
                            ws_sink = new_sink;
                            ws_source = new_source;
                            active_room_code = Some(r_code.clone());
                            active_player_id = pid;
                            connected_flag.store(true, Ordering::SeqCst);
                            *reconnect_state_clone.lock().unwrap() = ReconnectState::Connected;
                            events_clone.lock().unwrap().push_back(
                                RelayClientEvent::ConnectionRestored {
                                    room_code: r_code,
                                    player_id: PlayerId(pid),
                                    seed,
                                    commands,
                                },
                            );
                            heartbeat.reset();
                            restored = true;
                            break;
                        }
                    }

                    if !restored {
                        connected_flag.store(false, Ordering::SeqCst);
                        *reconnect_state_clone.lock().unwrap() = ReconnectState::Disconnected;
                        events_clone
                            .lock()
                            .unwrap()
                            .push_back(RelayClientEvent::Disconnected);
                        break;
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
            reconnect_state,
            shutdown_flag,
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

    /// Devuelve el estado de reconexión actual del cliente (`Connected`, `Reconnecting`, `Disconnected`).
    pub fn reconnect_state(&self) -> ReconnectState {
        *self.reconnect_state.lock().unwrap()
    }

    /// Indica si el cliente se encuentra intentando reconectar automáticamente con backoff exponencial.
    pub fn is_reconnecting(&self) -> bool {
        matches!(self.reconnect_state(), ReconnectState::Reconnecting { .. })
    }

    /// Devuelve el número de intento de reconexión actual (`1..=5`), o `0` si no está reconectando.
    pub fn reconnect_attempt(&self) -> u32 {
        match self.reconnect_state() {
            ReconnectState::Reconnecting { attempt, .. } => attempt,
            _ => 0,
        }
    }

    /// Código de sala actual (si el cliente creó o se unió a una sala).
    pub fn room_code(&self) -> Option<&str> {
        self.current_room.as_deref()
    }

    /// `PlayerId` asignado en la sala actual (`PlayerId(1)` para host, `PlayerId(2..)` para invitado).
    pub fn player_id(&self) -> PlayerId {
        self.player_id
    }

    /// Solicita reconectar explícitamente al asiento previo en la sala `code` enviando `{"op": "rejoin_room"}`.
    pub fn rejoin_room(&mut self, code: &str) -> EngineResult<PlayerId> {
        let normalized = code.trim().to_ascii_uppercase();
        if !is_valid_relay_code(&normalized) {
            return Err(EngineError::Network("Código de sala inválido".to_string()));
        }
        if self.is_remote_connected() {
            if let Some(tx) = &self.cmd_tx {
                let (reply_tx, reply_rx) = oneshot::channel();
                let pid_hint = if self.player_id.0 > 0 {
                    Some(format!("player{}", self.player_id.0))
                } else {
                    None
                };
                if tx
                    .send(OutboundRelayCommand::Rejoin {
                        room_code: normalized.clone(),
                        player_id: pid_hint,
                        reply: reply_tx,
                    })
                    .is_ok()
                {
                    match reply_rx.blocking_recv() {
                        Ok(Ok((pid, _seed, _commands))) => {
                            let player = PlayerId(pid);
                            self.current_room = Some(normalized);
                            self.player_id = player;
                            return Ok(player);
                        }
                        Ok(Err(err)) => {
                            if self.current_room.as_deref() == Some(normalized.as_str())
                                && self.player_id.0 > 0
                            {
                                return Ok(self.player_id);
                            }
                            return Err(EngineError::Network(err));
                        }
                        Err(e) => return Err(EngineError::Network(e.to_string())),
                    }
                }
            }
        }

        // Fallback en hub local en memoria
        let mut hub = local_relay_hub().lock().unwrap();
        if let Some(room) = hub.get_mut(&normalized) {
            let assigned_pid = if self.player_id.0 > 0 {
                self.player_id
            } else {
                let pid = PlayerId(room.next_player_id);
                room.next_player_id += 1;
                pid
            };
            if !room
                .members
                .iter()
                .any(|(cid, _, _)| *cid == self.client_id)
            {
                room.members
                    .push((self.client_id, assigned_pid, Arc::clone(&self.events)));
            }
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
            return Ok(assigned_pid);
        }
        drop(hub);

        Err(EngineError::Network(
            "No conectado a un servidor Relay remoto".to_string(),
        ))
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
        self.shutdown_flag.store(true, Ordering::SeqCst);
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

    #[test]
    fn test_reconnect_backoff_schedule_is_500ms_1s_2s_4s_up_to_5_attempts() {
        let policy = ReconnectPolicy::default();
        assert_eq!(policy.max_attempts, 5);
        assert_eq!(policy.delay_for_attempt(1), Duration::from_millis(500));
        assert_eq!(policy.delay_for_attempt(2), Duration::from_millis(1000));
        assert_eq!(policy.delay_for_attempt(3), Duration::from_millis(2000));
        assert_eq!(policy.delay_for_attempt(4), Duration::from_millis(4000));
        assert_eq!(policy.delay_for_attempt(5), Duration::from_millis(4000));

        assert_eq!(reconnect_backoff_duration(1), Duration::from_millis(500));
        assert_eq!(reconnect_backoff_duration(2), Duration::from_secs(1));
        assert_eq!(reconnect_backoff_duration(3), Duration::from_secs(2));
        assert_eq!(reconnect_backoff_duration(4), Duration::from_secs(4));
    }

    #[test]
    fn test_auto_reconnect_with_exponential_backoff_sends_rejoin_room_and_restores() {
        use tokio::net::TcpListener;
        use tokio_tungstenite::accept_async;

        // Servidor WebSocket de prueba que cierra el primer socket tras crear la sala,
        // rechaza el intento 1 de reconexión y acepta `rejoin_room` en el intento 2.
        let (addr_tx, addr_rx) = std::sync::mpsc::channel();
        let (drop_tx, drop_rx) = tokio::sync::oneshot::channel::<()>();

        let server_thread = thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();
            rt.block_on(async move {
                let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
                let addr = listener.local_addr().unwrap();
                addr_tx.send(addr).unwrap();

                // Conexión inicial: recibe `create`, responde `created` y luego cierra abruptamente
                let (stream1, _) = listener.accept().await.unwrap();
                let mut ws1 = accept_async(stream1).await.unwrap();
                if let Some(Ok(Message::Text(text))) = ws1.next().await {
                    let v: Value = serde_json::from_str(&text).unwrap();
                    assert_eq!(v["op"], "create");
                    let created = serde_json::json!({
                        "op": "created",
                        "room_code": "K9M2",
                        "seed": 77777
                    })
                    .to_string();
                    ws1.send(Message::Text(created.into())).await.unwrap();
                }
                let _ = drop_rx.await;
                let _ = ws1.close(None).await;
                drop(ws1);

                // Intento 1 de reconexión: simulamos fallo de red cerrando inmediatamente
                let (stream2, _) = listener.accept().await.unwrap();
                let mut ws2 = accept_async(stream2).await.unwrap();
                let _ = ws2.close(None).await;
                drop(ws2);

                // Intento 2 de reconexión: recibe `rejoin_room` para `K9M2` y responde `rejoined`
                let (stream3, _) = listener.accept().await.unwrap();
                let mut ws3 = accept_async(stream3).await.unwrap();
                if let Some(Ok(Message::Text(text))) = ws3.next().await {
                    let v: Value = serde_json::from_str(&text).unwrap();
                    assert_eq!(v["op"], "rejoin_room");
                    assert_eq!(v["room_code"], "K9M2");
                    let rejoined = serde_json::json!({
                        "op": "rejoined",
                        "room_code": "K9M2",
                        "player_id": 1,
                        "seed": 77777,
                        "commands": [{"command_type": "checkers_game::MovePieceCommand"}]
                    })
                    .to_string();
                    ws3.send(Message::Text(rejoined.into())).await.unwrap();
                }
                tokio::time::sleep(Duration::from_millis(200)).await;
            });
        });

        let addr = addr_rx.recv().unwrap();
        let url = format!("ws://{addr}");
        let fast_policy = ReconnectPolicy {
            max_attempts: 5,
            backoff_ms: [40, 80, 160, 320, 320],
        };
        let mut client = WsRelayClient::connect_with_policy(&url, None, fast_policy);
        assert!(client.is_remote_connected());

        let room_code = client.create_room("checkers").unwrap();
        assert_eq!(room_code, "K9M2");
        let _ = client.poll_relay_events();

        // Provocar caída inesperada del socket durante la partida activa
        let _ = drop_tx.send(());

        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        let mut seen_attempts = Vec::new();
        let mut restored_event = None;
        let mut prematurely_disconnected = false;

        while std::time::Instant::now() < deadline {
            for ev in client.poll_relay_events() {
                match ev {
                    RelayClientEvent::Reconnecting {
                        attempt,
                        max_attempts,
                    } => {
                        assert_eq!(max_attempts, 5);
                        seen_attempts.push(attempt);
                    }
                    RelayClientEvent::ConnectionRestored {
                        room_code: r_code,
                        player_id,
                        seed,
                        commands,
                    } => {
                        restored_event = Some((r_code, player_id, seed, commands));
                    }
                    RelayClientEvent::Disconnected => {
                        if restored_event.is_none() {
                            prematurely_disconnected = true;
                        }
                    }
                    _ => {}
                }
            }
            if restored_event.is_some() {
                break;
            }
            thread::sleep(Duration::from_millis(15));
        }

        assert!(
            !prematurely_disconnected,
            "No debe emitir Disconnected antes de agotar los 5 intentos"
        );
        assert_eq!(seen_attempts, vec![1, 2]);
        let (r_code, pid, seed, cmds) =
            restored_event.expect("Debe emitir ConnectionRestored tras rejoin_room");
        assert_eq!(r_code, "K9M2");
        assert_eq!(pid, PlayerId(1));
        assert_eq!(seed, 77777);
        assert_eq!(cmds.len(), 1);
        assert_eq!(client.reconnect_state(), ReconnectState::Connected);

        let _ = server_thread.join();
    }

    #[test]
    fn test_auto_reconnect_emits_disconnected_only_after_5_failed_attempts() {
        use tokio::net::TcpListener;
        use tokio_tungstenite::accept_async;

        let (addr_tx, addr_rx) = std::sync::mpsc::channel();
        let (drop_tx, drop_rx) = tokio::sync::oneshot::channel::<()>();

        let server_thread = thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();
            rt.block_on(async move {
                let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
                let addr = listener.local_addr().unwrap();
                addr_tx.send(addr).unwrap();

                let (stream1, _) = listener.accept().await.unwrap();
                let mut ws1 = accept_async(stream1).await.unwrap();
                if let Some(Ok(Message::Text(_))) = ws1.next().await {
                    let created = serde_json::json!({
                        "op": "created",
                        "room_code": "Z8X4",
                        "seed": 42
                    })
                    .to_string();
                    ws1.send(Message::Text(created.into())).await.unwrap();
                }
                let _ = drop_rx.await;
                let _ = ws1.close(None).await;
                drop(ws1);
                // Cerramos el listener para que los 5 intentos de reconexión fallen
                drop(listener);
            });
        });

        let addr = addr_rx.recv().unwrap();
        let url = format!("ws://{addr}");
        let fast_policy = ReconnectPolicy {
            max_attempts: 5,
            backoff_ms: [20, 40, 80, 120, 120],
        };
        let mut client = WsRelayClient::connect_with_policy(&url, None, fast_policy);
        let code = client.create_room("chess").unwrap();
        assert_eq!(code, "Z8X4");
        let _ = client.poll_relay_events();

        let _ = drop_tx.send(());

        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        let mut attempts = Vec::new();
        let mut disconnected_after_all = false;

        while std::time::Instant::now() < deadline {
            for ev in client.poll_relay_events() {
                match ev {
                    RelayClientEvent::Reconnecting {
                        attempt,
                        max_attempts,
                    } => {
                        assert_eq!(max_attempts, 5);
                        attempts.push(attempt);
                    }
                    RelayClientEvent::Disconnected => {
                        disconnected_after_all = true;
                    }
                    _ => {}
                }
            }
            if disconnected_after_all {
                break;
            }
            thread::sleep(Duration::from_millis(15));
        }

        assert_eq!(attempts, vec![1, 2, 3, 4, 5]);
        assert!(disconnected_after_all);
        assert_eq!(client.reconnect_state(), ReconnectState::Disconnected);

        let _ = server_thread.join();
    }
}
