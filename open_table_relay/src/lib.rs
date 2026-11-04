// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Microservidor standalone de salas, retransmisión WebSocket y servicio ELO para OpenTable SDK.
//!
//! Protocolo JSON WebSocket (puerto 8080):
//! - `{"op": "create"}` -> `{"op": "created", "room_code": "XKCD"}`
//! - `{"op": "join", "room_code": "XKCD"}` -> `{"op": "joined", "player_id": 2}`
//! - `{"op": "relay", "data": "..."}` -> retransmite el payload a los demás participantes
//! - `{"op": "report_result", "winner": "player1", "loser": "player2", "game_id": "chess"}` -> actualiza ELO (K=32)
//! - `{"op": "leave"}` / desconexión -> notifica a los participantes restantes (`peer_left`)
//!
//! API HTTP (puerto 8081):
//! - `GET /rankings/:game_id` -> JSON con top-50 jugadores por ELO
//! - `GET /player/:player_id` -> JSON con todos los ratings del jugador por juego

#![allow(
    clippy::needless_range_loop,
    clippy::large_enum_variant,
    clippy::too_many_arguments,
    clippy::type_complexity
)]

pub mod anticheat;
pub mod api;
pub mod auth;
pub mod elo;
pub mod metrics;
pub mod rate_limit;
pub mod room;
pub mod tls;
pub mod tournament;

use api::run_http_api_server;
use auth::{AuthConfig, AUTH_HANDSHAKE_TIMEOUT_SECS};
use elo::EloStore;
use futures_util::{SinkExt, StreamExt};
use metrics::global_metrics;
use rate_limit::{RateLimitDecision, RelayRateLimiter};
use room::{
    AuthoritativeMatchOutcome, ClientSender, ConnectionId, ReportResultCheck, RoomError,
    RoomManager,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tls::TlsConfig;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, Mutex};
use tokio_tungstenite::tungstenite::Message;
use tournament::{Tournament, TournamentManager};

/// Estado compartido entre todas las conexiones WebSocket del Relay.
#[derive(Clone)]
pub struct RelaySharedState {
    /// Gestor de salas activas.
    pub manager: Arc<Mutex<RoomManager>>,
    /// Almacén persistente de ELO.
    pub elo_store: Arc<Mutex<EloStore>>,
    /// Gestor de torneos.
    pub tournaments: Arc<Mutex<TournamentManager>>,
    /// Limitador de velocidad por IP y por sala.
    pub rate_limiter: Arc<Mutex<RelayRateLimiter>>,
    /// Configuración de autenticación JWT.
    pub auth_config: AuthConfig,
    /// Configuración TLS opcional cargada desde entorno.
    pub tls_config: Option<TlsConfig>,
}

/// Solicitud entrante enviada por un cliente WebSocket al servidor Relay.
#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum RelayRequest {
    /// Autentica la conexión mediante un token JWT (`HS256`).
    Auth {
        /// Token JWT firmado con `JWT_SECRET`.
        token: String,
    },
    /// Crea una nueva sala y registra al cliente como anfitrión (`player_id = 1`).
    #[serde(alias = "create_room")]
    Create {
        /// Identificador opcional del juego.
        #[serde(default)]
        game_id: Option<String>,
        /// Indica si la sala es pública (por defecto `true`).
        #[serde(default = "default_true")]
        is_public: bool,
        /// Tiempo máximo por turno en segundos (`120` por defecto; presets: `30`, `60`, `120`, `0` en salas privadas).
        #[serde(default)]
        turn_timeout_secs: Option<u64>,
    },
    /// Encola al jugador en una partida de matchmaking público (`turn_timeout_secs = 60`).
    #[serde(alias = "matchmaking")]
    Queue {
        /// Identificador opcional del juego.
        #[serde(default)]
        game_id: Option<String>,
    },
    /// Une al cliente a una sala existente mediante su código.
    Join {
        /// Código de la sala.
        room_code: String,
    },
    /// Reconecta a un jugador desconectado a su asiento original dentro de la ventana de gracia de 90 segundos.
    #[serde(alias = "rejoin")]
    RejoinRoom {
        /// Código de la sala activa.
        room_code: String,
        /// Identificador canónico opcional del jugador (si se omite, se emplea el del JWT autenticado).
        #[serde(default)]
        player_id: Option<String>,
    },
    /// Une al cliente como espectador de solo lectura a una sala existente.
    JoinSpectator {
        /// Código de la sala.
        room_code: String,
    },
    /// Retransmite `data` a todos los demás participantes de la sala actual.
    Relay {
        /// Payload arbitrario a retransmitir.
        data: Value,
    },
    /// Reporta el resultado de una partida para actualizar el ELO persistente (K=32).
    ReportResult {
        /// Identificador del jugador ganador.
        winner: String,
        /// Identificador del jugador perdedor.
        loser: String,
        /// Identificador del juego (ej. `"chess"`).
        game_id: String,
    },
    /// Crea un nuevo torneo de eliminación simple (4, 8 o 16 jugadores).
    CreateTournament {
        /// Identificador del juego.
        game_id: String,
        /// Capacidad máxima de participantes (`4`, `8` o `16`).
        max_players: usize,
    },
    /// Une a un participante a un torneo existente.
    JoinTournament {
        /// Identificador del torneo (ej. `"T-AB12"`).
        tournament_id: String,
        /// Identificador opcional del jugador.
        #[serde(default)]
        player_id: Option<String>,
    },
    /// Reporta el ganador de un enfrentamiento de torneo y avanza a la siguiente ronda.
    ReportTournamentMatch {
        /// Identificador del torneo.
        tournament_id: String,
        /// Índice de ronda.
        round: usize,
        /// Índice de enfrentamiento dentro de la ronda.
        match_index: usize,
        /// Identificador del jugador ganador.
        winner: String,
    },
    /// Abandona voluntariamente la sala actual.
    Leave,
    /// Se rinde en la partida activa y adjudica inmediatamente la victoria al oponente.
    Resign,
    /// Ping de mantenimiento de conexión.
    Ping,
}

fn default_true() -> bool {
    true
}

/// Respuesta o evento enviado por el servidor Relay a los clientes.
#[derive(Debug, Serialize, Deserialize, PartialEq)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum RelayResponse {
    /// Confirmación de autenticación JWT exitosa.
    AuthOk {
        /// Identificador canónico (`sub`) extraído del JWT.
        player_id: String,
    },
    /// Error de autenticación JWT (`expired`, `invalid_signature`, `malformed_token`).
    AuthError {
        /// Motivo del rechazo.
        reason: String,
    },
    /// Notificación de límite de velocidad superado.
    RateLimited {
        /// Tiempo recomendado antes de reintentar en milisegundos (`1000`).
        retry_after_ms: u64,
    },
    /// Notificación de movimiento rechazado por el validador Anti-Cheat.
    MoveRejected {
        /// Motivo del rechazo (`"illegal_move"`).
        reason: String,
    },
    /// Confirmación de creación de sala.
    Created {
        /// Código asignado a la sala.
        room_code: String,
        /// Semilla generada por el servidor para sincronización determinista de dados y mazos.
        #[serde(default)]
        seed: u64,
    },
    /// Confirmación de unión exitosa a una sala.
    Joined {
        /// Identificador de jugador asignado dentro de la sala (2..N).
        player_id: u32,
        /// Semilla generada por el servidor para sincronización determinista de dados y mazos.
        #[serde(default)]
        seed: u64,
    },
    /// Confirmación de reconexión exitosa a una sala activa con el historial de comandos validados.
    Rejoined {
        /// Código de la sala.
        room_code: String,
        /// Asiento original recuperado (`1` o `2`).
        #[serde(default)]
        player_id: u32,
        /// Semilla determinista de la sala.
        seed: u64,
        /// Lista ordenada de comandos validados hasta el momento.
        commands: Vec<Value>,
    },
    /// Notificación al rival cuando el oponente se desconecta durante la partida (90s de gracia).
    OpponentDisconnected {
        /// Segundos de gracia antes de adjudicar victoria por abandono (`90`).
        grace_seconds: u64,
    },
    /// Notificación al rival cuando el oponente desconectado recupera su asiento.
    OpponentReconnected,
    /// Notificación emitida cuando el jugador en turno supera `turn_timeout_secs` sin jugar.
    MatchTimeout {
        /// Asiento ganador (`1` o `2`).
        winner_seat: u32,
        /// Motivo del fin por tiempo (`"turn_timeout"`).
        reason: String,
    },
    /// Confirmación de unión exitosa como espectador a una sala.
    Spectating {
        /// Cantidad de jugadores activos en la sala.
        player_count: usize,
    },
    /// Notificación a los miembros existentes cuando un nuevo jugador entra a la sala.
    PeerJoined {
        /// Identificador del nuevo jugador.
        player_id: u32,
    },
    /// Mensaje retransmitido desde otro participante de la sala.
    Relay {
        /// Payload retransmitido.
        data: Value,
        /// Identificador del jugador que originó el mensaje.
        #[serde(skip_serializing_if = "Option::is_none")]
        from: Option<u32>,
    },
    /// Notificación automática de actualización de ELO emitida por el servidor tras finalizar una partida autoritativa o rendición.
    EloUpdated {
        /// Identificador del ganador.
        winner: String,
        /// Identificador del perdedor.
        loser: String,
        /// Nuevo ELO del ganador.
        winner_elo: i32,
        /// Nuevo ELO del perdedor.
        loser_elo: i32,
    },
    /// Confirmación de actualización de ELO tras reportar un resultado.
    ResultReported {
        /// Identificador del juego.
        game_id: String,
        /// Identificador del ganador.
        winner: String,
        /// Nuevo ELO del ganador.
        winner_elo: i32,
        /// Identificador del perdedor.
        loser: String,
        /// Nuevo ELO del perdedor.
        loser_elo: i32,
    },
    /// Confirmación de creación de torneo.
    TournamentCreated {
        /// Identificador único del torneo (ej. `"T-AB12"`).
        tournament_id: String,
    },
    /// Estado actualizado del bracket del torneo.
    TournamentUpdated {
        /// Estado completo del torneo y sus rondas.
        tournament: Tournament,
    },
    /// Confirmación al cliente que solicitó salir de la sala.
    Left {
        /// Código de la sala abandonada.
        room_code: String,
    },
    /// Notificación a los participantes restantes cuando alguien se desconecta o sale.
    PeerLeft {
        /// Código de la sala.
        room_code: String,
        /// Identificador del jugador que salió.
        player_id: u32,
    },
    /// Respuesta a `{"op": "ping"}`.
    Pong,
    /// Notificación enviada a todos los clientes conectados antes de un apagado ordenado (`SIGINT`/`SIGTERM`).
    ServerShuttingDown,
    /// Error de protocolo o de estado de sala.
    Error {
        /// Código estructurado del motivo del error (`"spectator_cannot_relay"`, `"spectator_limit"`, etc.).
        #[serde(skip_serializing_if = "Option::is_none")]
        reason: Option<String>,
        /// Descripción legible del error.
        #[serde(skip_serializing_if = "Option::is_none")]
        message: Option<String>,
    },
}

impl RelayResponse {
    pub fn error_reason(reason: impl Into<String>) -> Self {
        Self::Error {
            reason: Some(reason.into()),
            message: None,
        }
    }

    pub fn error_message(message: impl Into<String>) -> Self {
        Self::Error {
            reason: None,
            message: Some(message.into()),
        }
    }
}

/// Espera una señal de parada del sistema (`SIGINT` / `Ctrl+C` o `SIGTERM` en contenedores Docker/Unix).
pub async fn wait_for_shutdown_signal() {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{signal, SignalKind};
        match signal(SignalKind::terminate()) {
            Ok(mut sigterm) => {
                tokio::select! {
                    _ = tokio::signal::ctrl_c() => {},
                    _ = sigterm.recv() => {},
                }
            }
            Err(_) => {
                let _ = tokio::signal::ctrl_c().await;
            }
        }
    }
    #[cfg(not(unix))]
    {
        let _ = tokio::signal::ctrl_c().await;
    }
}

/// Ejecuta el protocolo de apagado ordenado (Graceful Shutdown):
/// 1. Envía `{"op": "server_shutting_down"}` a todos los clientes conectados.
/// 2. Ejecuta flush completo y sincronización de almacenamiento de SQLite (`wal_checkpoint_and_flush`).
pub async fn perform_graceful_shutdown(state: &RelaySharedState) -> std::io::Result<()> {
    if let Ok(shutdown_json) = serde_json::to_string(&RelayResponse::ServerShuttingDown) {
        let mgr = state.manager.lock().await;
        mgr.broadcast_all_rooms(&shutdown_json);
    }
    tokio::time::sleep(Duration::from_millis(25)).await;
    let mut store = state.elo_store.lock().await;
    store.wal_checkpoint_and_flush()
}

/// Inicia el servidor Relay sobre un `TcpListener` ya enlazado usando la base de datos por defecto.
pub async fn run_relay_server(listener: TcpListener) -> std::io::Result<()> {
    let db_path =
        std::env::var("OPEN_TABLE_RATINGS_DB").unwrap_or_else(|_| "./data/ratings.db".to_string());
    let elo_store = Arc::new(Mutex::new(EloStore::new(db_path)?));
    run_relay_server_with_store(listener, elo_store).await
}

/// Inicia el servidor Relay compartiendo una instancia de `EloStore` con el servidor HTTP.
pub async fn run_relay_server_with_store(
    listener: TcpListener,
    elo_store: Arc<Mutex<EloStore>>,
) -> std::io::Result<()> {
    let tls_config = TlsConfig::from_env()?;
    let auth_config = AuthConfig::from_env();
    run_relay_server_with_config(listener, elo_store, auth_config, tls_config).await
}

/// Inicia el servidor Relay con configuración explícita de `AuthConfig` y `TlsConfig`.
pub async fn run_relay_server_with_config(
    listener: TcpListener,
    elo_store: Arc<Mutex<EloStore>>,
    auth_config: AuthConfig,
    tls_config: Option<TlsConfig>,
) -> std::io::Result<()> {
    let state = RelaySharedState {
        manager: Arc::new(Mutex::new(RoomManager::new())),
        elo_store,
        tournaments: Arc::new(Mutex::new(TournamentManager::new())),
        rate_limiter: Arc::new(Mutex::new(RelayRateLimiter::new())),
        auth_config,
        tls_config,
    };
    run_relay_server_with_state(listener, state).await
}

/// Inicia el servidor Relay a partir de un [`RelaySharedState`] preconfigurado,
/// deteniéndose limpiamente ante `SIGINT` o `SIGTERM`.
pub async fn run_relay_server_with_state(
    listener: TcpListener,
    state: RelaySharedState,
) -> std::io::Result<()> {
    run_relay_server_with_state_until(listener, state, wait_for_shutdown_signal()).await
}

/// Inicia el servidor Relay a partir de un [`RelaySharedState`] preconfigurado y ejecuta
/// apagado ordenado cuando se resuelve la señal `shutdown_signal`.
pub async fn run_relay_server_with_state_until<F>(
    listener: TcpListener,
    state: RelaySharedState,
    shutdown_signal: F,
) -> std::io::Result<()>
where
    F: std::future::Future<Output = ()>,
{
    let next_conn_id = Arc::new(AtomicU64::new(1));
    let accept_state = state.clone();
    let ticker_state = state.clone();
    let gc_state = state.clone();

    let accept_loop = async move {
        loop {
            let (stream, peer_addr) = listener.accept().await?;
            let conn_id = next_conn_id.fetch_add(1, Ordering::Relaxed);
            let state_clone = accept_state.clone();

            tokio::spawn(async move {
                handle_connection(stream, peer_addr.ip(), conn_id, state_clone).await;
            });
        }
        #[allow(unreachable_code)]
        Ok::<(), std::io::Error>(())
    };

    // Tarea periódica cada 1s que verifica timeouts de turno y desconexiones expiradas
    let periodic_watchdog = async move {
        let mut interval = tokio::time::interval(Duration::from_secs(1));
        loop {
            interval.tick().await;
            let outcomes = {
                let mut mgr = ticker_state.manager.lock().await;
                let mut out = mgr.expire_turn_timeouts();
                out.extend(mgr.expire_disconnected_seats());
                global_metrics().set_rooms_active(mgr.active_room_count());
                out
            };
            for outcome in outcomes {
                persist_and_broadcast_elo_outcome(outcome, &ticker_state).await;
            }
        }
    };

    // Recolector periódico cada 60s para salas inactivas (>30m) y cada 5m para RateLimitManager
    let periodic_collector = async move {
        let mut room_gc_interval =
            tokio::time::interval(Duration::from_secs(room::ROOM_PRUNE_INTERVAL_SECS));
        let mut rate_limit_gc_interval = tokio::time::interval(Duration::from_secs(
            rate_limit::RATE_LIMIT_CLEANUP_INTERVAL_SECS,
        ));
        loop {
            tokio::select! {
                _ = room_gc_interval.tick() => {
                    let mut mgr = gc_state.manager.lock().await;
                    mgr.prune_stale_rooms(Duration::from_secs(room::DEFAULT_MAX_ROOM_IDLE_SECS));
                    global_metrics().set_rooms_active(mgr.active_room_count());
                }
                _ = rate_limit_gc_interval.tick() => {
                    let mut limiter = gc_state.rate_limiter.lock().await;
                    limiter.prune_expired_now();
                }
            }
        }
    };

    tokio::select! {
        res = accept_loop => res,
        _ = periodic_watchdog => Ok(()),
        _ = periodic_collector => Ok(()),
        _ = shutdown_signal => {
            perform_graceful_shutdown(&state).await?;
            Ok(())
        }
    }
}

async fn handle_connection(
    stream: TcpStream,
    peer_ip: IpAddr,
    conn_id: ConnectionId,
    state: RelaySharedState,
) {
    {
        let mut limiter = state.rate_limiter.lock().await;
        if limiter.is_ip_banned(peer_ip) {
            return;
        }
    }

    let ws_stream = match tokio_tungstenite::accept_async(stream).await {
        Ok(ws) => ws,
        Err(_) => return,
    };

    global_metrics().inc_connections_active();

    let (mut ws_sink, mut ws_source) = ws_stream.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<String>();

    {
        let mut mgr = state.manager.lock().await;
        mgr.register_client(conn_id, tx.clone());
    }

    let writer_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                break;
            }
        }
    });

    let mut canonical_player_id: Option<String> = None;

    if state.auth_config.is_enabled() {
        let first_frame = tokio::time::timeout(
            Duration::from_secs(AUTH_HANDSHAKE_TIMEOUT_SECS),
            ws_source.next(),
        )
        .await;

        let Some(Some(Ok(Message::Text(first_text)))) = first_frame.ok() else {
            send_response(
                &tx,
                &RelayResponse::AuthError {
                    reason: "auth_timeout".to_string(),
                },
            );
            tokio::time::sleep(Duration::from_millis(20)).await;
            writer_task.abort();
            return;
        };

        let Ok(RelayRequest::Auth { token }) = serde_json::from_str::<RelayRequest>(&first_text)
        else {
            send_response(
                &tx,
                &RelayResponse::AuthError {
                    reason: "auth_required".to_string(),
                },
            );
            tokio::time::sleep(Duration::from_millis(20)).await;
            writer_task.abort();
            return;
        };

        match state.auth_config.verify_token(&token) {
            Ok(claims) => {
                canonical_player_id = Some(claims.sub.clone());
                send_response(
                    &tx,
                    &RelayResponse::AuthOk {
                        player_id: claims.sub,
                    },
                );
            }
            Err(err) => {
                send_response(
                    &tx,
                    &RelayResponse::AuthError {
                        reason: err.reason().to_string(),
                    },
                );
                tokio::time::sleep(Duration::from_millis(20)).await;
                writer_task.abort();
                return;
            }
        }
    }

    while let Some(Ok(msg)) = ws_source.next().await {
        match msg {
            Message::Text(text) => {
                let current_room = {
                    let mgr = state.manager.lock().await;
                    mgr.participant_info(conn_id).map(|(code, _)| code)
                };
                let decision = {
                    let mut limiter = state.rate_limiter.lock().await;
                    limiter.check_message(peer_ip, current_room.as_deref())
                };
                if let RateLimitDecision::Limited {
                    retry_after_ms,
                    disconnect,
                } = decision
                {
                    send_response(&tx, &RelayResponse::RateLimited { retry_after_ms });
                    if disconnect {
                        tokio::time::sleep(Duration::from_millis(20)).await;
                        break;
                    }
                    continue;
                }

                process_text_message(&text, conn_id, &mut canonical_player_id, &tx, &state).await;
            }
            Message::Ping(payload) => {
                let _ = tx.send(
                    serde_json::to_string(&RelayResponse::Pong)
                        .unwrap_or_else(|_| r#"{"op":"pong"}"#.to_string()),
                );
                let _ = payload;
            }
            Message::Close(_) => {
                break;
            }
            _ => {}
        }
    }

    let maybe_grace = {
        let mut mgr = state.manager.lock().await;
        mgr.unregister_client(conn_id);
        let disconnected = mgr.disconnect_participant(conn_id);
        global_metrics().set_rooms_active(mgr.active_room_count());
        disconnected.map(|_| mgr.rejoin_grace_duration())
    };

    if let Some(grace_duration) = maybe_grace {
        let state_for_timer = state.clone();
        tokio::spawn(async move {
            tokio::time::sleep(grace_duration).await;
            let outcomes = {
                let mut mgr = state_for_timer.manager.lock().await;
                let expired = mgr.expire_disconnected_seats();
                global_metrics().set_rooms_active(mgr.active_room_count());
                expired
            };
            for outcome in outcomes {
                persist_and_broadcast_elo_outcome(outcome, &state_for_timer).await;
            }
        });
    }

    global_metrics().dec_connections_active();
    writer_task.abort();
}

async fn process_text_message(
    raw_text: &str,
    conn_id: ConnectionId,
    canonical_player_id: &mut Option<String>,
    tx: &ClientSender,
    state: &RelaySharedState,
) {
    let parsed: Result<RelayRequest, _> = serde_json::from_str(raw_text);
    let request = match parsed {
        Ok(req) => req,
        Err(err) => {
            send_response(
                tx,
                &RelayResponse::error_message(format!("invalid json request: {err}")),
            );
            return;
        }
    };

    match request {
        RelayRequest::Auth { token } => match state.auth_config.verify_token(&token) {
            Ok(claims) => {
                *canonical_player_id = Some(claims.sub.clone());
                {
                    let mut mgr = state.manager.lock().await;
                    mgr.set_authenticated_player_id(conn_id, canonical_player_id.clone());
                }
                send_response(
                    tx,
                    &RelayResponse::AuthOk {
                        player_id: claims.sub,
                    },
                );
            }
            Err(err) => {
                send_response(
                    tx,
                    &RelayResponse::AuthError {
                        reason: err.reason().to_string(),
                    },
                );
            }
        },
        RelayRequest::Create {
            game_id,
            is_public,
            turn_timeout_secs,
        } => {
            global_metrics().inc_messages_total(game_id.as_deref());
            let mut mgr = state.manager.lock().await;
            let room_code = mgr.create_room_with_timeout(
                conn_id,
                tx.clone(),
                game_id,
                is_public,
                turn_timeout_secs,
            );
            mgr.set_authenticated_player_id(conn_id, canonical_player_id.clone());
            let seed = mgr.room_seed(&room_code).unwrap_or(42);
            global_metrics().set_rooms_active(mgr.active_room_count());
            send_response(tx, &RelayResponse::Created { room_code, seed });
        }
        RelayRequest::Queue { game_id } => {
            global_metrics().inc_messages_total(game_id.as_deref());
            let mut mgr = state.manager.lock().await;
            let (room_code, player_id, is_new) =
                mgr.queue_matchmaking(conn_id, tx.clone(), game_id);
            mgr.set_authenticated_player_id(conn_id, canonical_player_id.clone());
            let seed = mgr.room_seed(&room_code).unwrap_or(42);
            global_metrics().set_rooms_active(mgr.active_room_count());
            if is_new {
                send_response(tx, &RelayResponse::Created { room_code, seed });
            } else {
                send_response(tx, &RelayResponse::Joined { player_id, seed });
                if let Ok(peer_notice) =
                    serde_json::to_string(&RelayResponse::PeerJoined { player_id })
                {
                    let _ = mgr.relay_to_peers(conn_id, &peer_notice);
                }
            }
        }
        RelayRequest::Join { room_code } => {
            let mut mgr = state.manager.lock().await;
            match mgr.join_room(conn_id, tx.clone(), &room_code) {
                Ok((normalized_code, player_id)) => {
                    mgr.set_authenticated_player_id(conn_id, canonical_player_id.clone());
                    let seed = mgr.room_seed(&normalized_code).unwrap_or(42);
                    send_response(tx, &RelayResponse::Joined { player_id, seed });
                    if let Ok(peer_notice) =
                        serde_json::to_string(&RelayResponse::PeerJoined { player_id })
                    {
                        let _ = mgr.relay_to_peers(conn_id, &peer_notice);
                    }
                }
                Err(RoomError::InvalidRoomCode) => {
                    send_response(
                        tx,
                        &RelayResponse::error_message("invalid room code format"),
                    );
                }
                Err(RoomError::RoomNotFound) => {
                    send_response(tx, &RelayResponse::error_message("room not found"));
                }
                Err(_) => {
                    send_response(tx, &RelayResponse::error_message("not in room"));
                }
            }
        }
        RelayRequest::RejoinRoom {
            room_code,
            player_id,
        } => {
            if let (Some(auth_id), Some(req_id)) = (&canonical_player_id, &player_id) {
                let trimmed = req_id.trim();
                if !trimmed.is_empty() && trimmed != auth_id {
                    send_response(tx, &RelayResponse::error_reason("seat_not_found"));
                    return;
                }
            }
            let effective_id = canonical_player_id.clone().or(player_id);
            let mut expired_outcomes = Vec::new();
            let rejoin_res = {
                let mut mgr = state.manager.lock().await;
                let res = mgr.rejoin_room(conn_id, tx.clone(), &room_code, effective_id.as_deref());
                if matches!(res, Err(RoomError::RejoinExpired)) {
                    expired_outcomes = mgr.expire_disconnected_seats();
                }
                res
            };
            for outcome in expired_outcomes {
                persist_and_broadcast_elo_outcome(outcome, state).await;
            }
            match rejoin_res {
                Ok(outcome) => {
                    if canonical_player_id.is_none() && effective_id.is_some() {
                        *canonical_player_id = effective_id;
                    }
                    send_response(
                        tx,
                        &RelayResponse::Rejoined {
                            room_code: outcome.room_code,
                            player_id: outcome.player_id,
                            seed: outcome.seed,
                            commands: outcome.commands,
                        },
                    );
                }
                Err(RoomError::RejoinExpired) => {
                    send_response(tx, &RelayResponse::error_reason("rejoin_expired"));
                }
                Err(RoomError::InvalidRoomCode) => {
                    send_response(
                        tx,
                        &RelayResponse::error_message("invalid room code format"),
                    );
                }
                Err(RoomError::RoomNotFound) => {
                    send_response(tx, &RelayResponse::error_message("room not found"));
                }
                Err(_) => {
                    send_response(tx, &RelayResponse::error_reason("seat_not_found"));
                }
            }
        }
        RelayRequest::JoinSpectator { room_code } => {
            let mut mgr = state.manager.lock().await;
            match mgr.join_spectator(conn_id, tx.clone(), &room_code) {
                Ok((_normalized_code, player_count)) => {
                    send_response(tx, &RelayResponse::Spectating { player_count });
                }
                Err(RoomError::SpectatorLimit) => {
                    send_response(tx, &RelayResponse::error_reason("spectator_limit"));
                }
                Err(RoomError::InvalidRoomCode) => {
                    send_response(
                        tx,
                        &RelayResponse::error_message("invalid room code format"),
                    );
                }
                Err(RoomError::RoomNotFound) => {
                    send_response(tx, &RelayResponse::error_message("room not found"));
                }
                Err(_) => {
                    send_response(tx, &RelayResponse::error_message("not in room"));
                }
            }
        }
        RelayRequest::Relay { data } => {
            let mut maybe_outcome = None;
            {
                let mut mgr = state.manager.lock().await;
                let from_player = mgr.participant_info(conn_id).map(|(_, pid)| pid);
                let outbound = RelayResponse::Relay {
                    data: data.clone(),
                    from: from_player,
                };
                if let Ok(serialized) = serde_json::to_string(&outbound) {
                    match mgr.validate_and_relay(conn_id, &data, &serialized) {
                        Ok(_) => {
                            maybe_outcome = mgr.claim_authoritative_outcome(conn_id);
                        }
                        Err(RoomError::SpectatorCannotRelay) => {
                            send_response(
                                tx,
                                &RelayResponse::error_reason("spectator_cannot_relay"),
                            );
                        }
                        Err(RoomError::IllegalMove) => {
                            send_response(
                                tx,
                                &RelayResponse::MoveRejected {
                                    reason: "illegal_move".to_string(),
                                },
                            );
                        }
                        Err(_) => {
                            send_response(
                                tx,
                                &RelayResponse::error_message("client is not in a room"),
                            );
                        }
                    }
                }
            }
            if let Some(outcome) = maybe_outcome {
                persist_and_broadcast_elo_outcome(outcome, state).await;
            }
        }
        RelayRequest::Resign => {
            let resign_res = {
                let mut mgr = state.manager.lock().await;
                mgr.resign(conn_id)
            };
            match resign_res {
                Ok(Some(outcome)) => {
                    persist_and_broadcast_elo_outcome(outcome, state).await;
                }
                Ok(None) => {}
                Err(RoomError::SpectatorCannotRelay) => {
                    send_response(tx, &RelayResponse::error_reason("spectator_cannot_relay"));
                }
                Err(_) => {
                    send_response(tx, &RelayResponse::error_message("client is not in a room"));
                }
            }
        }
        RelayRequest::ReportResult {
            winner,
            loser,
            game_id,
        } => {
            let report_check = {
                let mut mgr = state.manager.lock().await;
                mgr.check_manual_report_result(conn_id)
            };
            match report_check {
                ReportResultCheck::MatchNotFinished => {
                    send_response(tx, &RelayResponse::error_reason("match_not_finished"));
                    return;
                }
                ReportResultCheck::AlreadyReported => {
                    return;
                }
                ReportResultCheck::Allowed => {}
            }
            global_metrics().inc_messages_total(Some(&game_id));
            let mut store = state.elo_store.lock().await;
            match store.report_result(&winner, &loser, &game_id) {
                Ok((w_rating, l_rating)) => {
                    global_metrics().inc_elo_updates_total();
                    send_response(
                        tx,
                        &RelayResponse::ResultReported {
                            game_id,
                            winner,
                            winner_elo: w_rating.elo,
                            loser,
                            loser_elo: l_rating.elo,
                        },
                    );
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::error_message(format!(
                            "failed to persist ELO result: {err}"
                        )),
                    );
                }
            }
        }
        RelayRequest::CreateTournament {
            game_id,
            max_players,
        } => {
            let mut tm = state.tournaments.lock().await;
            match tm.create_tournament(game_id, max_players) {
                Ok(tournament_id) => {
                    send_response(tx, &RelayResponse::TournamentCreated { tournament_id });
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::error_message(format!(
                            "invalid tournament configuration: {err:?}"
                        )),
                    );
                }
            }
        }
        RelayRequest::JoinTournament {
            tournament_id,
            player_id,
        } => {
            let mut tm = state.tournaments.lock().await;
            let pid = canonical_player_id
                .clone()
                .or(player_id)
                .unwrap_or_else(|| format!("player_{conn_id}"));
            match tm.join_tournament(&tournament_id, pid) {
                Ok((tournament, _started)) => {
                    send_response(tx, &RelayResponse::TournamentUpdated { tournament });
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::error_message(format!(
                            "failed to join tournament: {err:?}"
                        )),
                    );
                }
            }
        }
        RelayRequest::ReportTournamentMatch {
            tournament_id,
            round,
            match_index,
            winner,
        } => {
            let mut tm = state.tournaments.lock().await;
            match tm.report_match(&tournament_id, round, match_index, &winner) {
                Ok(tournament) => {
                    send_response(tx, &RelayResponse::TournamentUpdated { tournament });
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::error_message(format!(
                            "failed to report tournament match: {err:?}"
                        )),
                    );
                }
            }
        }
        RelayRequest::Leave => {
            let mut mgr = state.manager.lock().await;
            if let Some((room_code, _player_id)) = mgr.leave_room(conn_id) {
                send_response(tx, &RelayResponse::Left { room_code });
            } else {
                send_response(tx, &RelayResponse::error_message("client is not in a room"));
            }
        }
        RelayRequest::Ping => {
            send_response(tx, &RelayResponse::Pong);
        }
    }
}

async fn persist_and_broadcast_elo_outcome(
    outcome: AuthoritativeMatchOutcome,
    state: &RelaySharedState,
) {
    global_metrics().inc_messages_total(Some(&outcome.game_id));
    let elo_res = {
        let mut store = state.elo_store.lock().await;
        store.report_result(&outcome.winner, &outcome.loser, &outcome.game_id)
    };
    if let Ok((w_rating, l_rating)) = elo_res {
        global_metrics().inc_elo_updates_total();
        let response = RelayResponse::EloUpdated {
            winner: outcome.winner,
            loser: outcome.loser,
            winner_elo: w_rating.elo,
            loser_elo: l_rating.elo,
        };
        if let Ok(json_str) = serde_json::to_string(&response) {
            let mgr = state.manager.lock().await;
            mgr.broadcast_to_room(&outcome.room_code, &json_str);
        }
    }
}

fn send_response(tx: &ClientSender, response: &RelayResponse) {
    if let Ok(json) = serde_json::to_string(response) {
        let _ = tx.send(json);
    }
}

/// Punto de entrada principal del ejecutable `open_table_relay`.
pub async fn run_cli_main() -> std::io::Result<()> {
    let _ = IpAddr::V4(Ipv4Addr::LOCALHOST);
    let ws_addr: SocketAddr = std::env::var("OPEN_TABLE_RELAY_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8080".to_string())
        .parse()
        .expect("OPEN_TABLE_RELAY_ADDR debe ser un SocketAddr válido (ej. 0.0.0.0:8080)");

    let http_addr: SocketAddr = std::env::var("OPEN_TABLE_HTTP_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8081".to_string())
        .parse()
        .expect("OPEN_TABLE_HTTP_ADDR debe ser un SocketAddr válido (ej. 0.0.0.0:8081)");

    let db_path =
        std::env::var("OPEN_TABLE_RATINGS_DB").unwrap_or_else(|_| "./data/ratings.db".to_string());
    let elo_store = Arc::new(Mutex::new(EloStore::new(Path::new(&db_path))?));

    let ws_listener = TcpListener::bind(ws_addr).await?;
    let http_listener = TcpListener::bind(http_addr).await?;

    println!("open_table_relay WebSocket listening on ws://{ws_addr}");
    println!("open_table_relay HTTP ELO API listening on http://{http_addr}");

    let relay_fut = run_relay_server_with_store(ws_listener, Arc::clone(&elo_store));
    let http_fut = run_http_api_server(http_listener, Arc::clone(&elo_store));

    tokio::select! {
        res = relay_fut => {
            res?;
        }
        res = http_fut => {
            res?;
        }
    }

    let mut store = elo_store.lock().await;
    let _ = store.wal_checkpoint_and_flush();
    drop(store);
    std::process::exit(0);
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio_tungstenite::connect_async;

    #[tokio::test]
    async fn test_websocket_relay_end_to_end() {
        let db_file =
            std::env::temp_dir().join(format!("opentable_ratings_ws_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let server_handle = tokio::spawn(async move {
            let _ = run_relay_server_with_store(listener, elo_store).await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        // 1. Host crea sala: {"op": "create"} -> {"op": "created", "room_code": "XXXXXX"}
        ws_host
            .send(Message::Text(r#"{"op":"create"}"#.into()))
            .await
            .unwrap();
        let created_msg = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let created_val: Value = serde_json::from_str(&created_msg).unwrap();
        assert_eq!(created_val["op"], "created");
        let room_code = created_val["room_code"].as_str().unwrap().to_string();
        assert!(room::is_valid_room_code(&room_code));

        // 2. Guest se une: {"op": "join", "room_code": "..."} -> {"op": "joined", "player_id": 2}
        let join_cmd = serde_json::json!({
            "op": "join",
            "room_code": room_code,
        })
        .to_string();
        ws_guest.send(Message::Text(join_cmd.into())).await.unwrap();

        let joined_msg = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let joined_val: Value = serde_json::from_str(&joined_msg).unwrap();
        assert_eq!(joined_val["op"], "joined");
        assert_eq!(joined_val["player_id"], 2);

        let host_notice = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let host_notice_val: Value = serde_json::from_str(&host_notice).unwrap();
        assert_eq!(host_notice_val["op"], "peer_joined");
        assert_eq!(host_notice_val["player_id"], 2);

        // 3. Host envía {"op": "relay", "data": "move_e2e4"} -> Guest lo recibe
        ws_host
            .send(Message::Text(r#"{"op":"relay","data":"move_e2e4"}"#.into()))
            .await
            .unwrap();
        let relayed_msg = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let relayed_val: Value = serde_json::from_str(&relayed_msg).unwrap();
        assert_eq!(relayed_val["op"], "relay");
        assert_eq!(relayed_val["data"], "move_e2e4");
        assert_eq!(relayed_val["from"], 1);

        // 4. Guest envía {"op": "leave"} -> Host recibe notificación peer_left
        ws_guest
            .send(Message::Text(r#"{"op":"leave"}"#.into()))
            .await
            .unwrap();
        let left_confirm = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let left_confirm_val: Value = serde_json::from_str(&left_confirm).unwrap();
        assert_eq!(left_confirm_val["op"], "left");

        let peer_left_msg = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let peer_left_val: Value = serde_json::from_str(&peer_left_msg).unwrap();
        assert_eq!(peer_left_val["op"], "peer_left");
        assert_eq!(peer_left_val["player_id"], 2);

        server_handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_elo_report_result_and_http_api() {
        let db_file =
            std::env::temp_dir().join(format!("opentable_ratings_elo_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let ws_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let ws_addr = ws_listener.local_addr().unwrap();

        let http_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let http_addr = http_listener.local_addr().unwrap();

        let store_ws = Arc::clone(&elo_store);
        let ws_handle = tokio::spawn(async move {
            let _ = run_relay_server_with_store(ws_listener, store_ws).await;
        });

        let store_http = Arc::clone(&elo_store);
        let http_handle = tokio::spawn(async move {
            let _ = run_http_api_server(http_listener, store_http).await;
        });

        // Reportar resultado por WebSocket: player1 vence a player2 en chess (K=32: 1200 -> 1216 / 1184)
        let (mut ws_client, _) = connect_async(&format!("ws://{ws_addr}")).await.unwrap();
        ws_client
            .send(Message::Text(
                r#"{"op":"report_result","winner":"player1","loser":"player2","game_id":"chess"}"#
                    .into(),
            ))
            .await
            .unwrap();

        let resp_txt = ws_client
            .next()
            .await
            .unwrap()
            .unwrap()
            .into_text()
            .unwrap();
        let resp_val: Value = serde_json::from_str(&resp_txt).unwrap();
        assert_eq!(resp_val["op"], "result_reported");
        assert_eq!(resp_val["winner_elo"], 1216);
        assert_eq!(resp_val["loser_elo"], 1184);

        // Consultar GET /rankings/chess por HTTP
        let mut stream = TcpStream::connect(http_addr).await.unwrap();
        stream
            .write_all(b"GET /rankings/chess HTTP/1.1\r\nHost: localhost\r\n\r\n")
            .await
            .unwrap();
        let mut buf = Vec::new();
        stream.read_to_end(&mut buf).await.unwrap();
        let http_resp = String::from_utf8_lossy(&buf);
        assert!(http_resp.contains("200 OK"));
        assert!(http_resp.contains("\"player1\""));
        assert!(http_resp.contains("1216"));

        // Consultar GET /player/player1 por HTTP
        let mut stream2 = TcpStream::connect(http_addr).await.unwrap();
        stream2
            .write_all(b"GET /player/player1 HTTP/1.1\r\nHost: localhost\r\n\r\n")
            .await
            .unwrap();
        let mut buf2 = Vec::new();
        stream2.read_to_end(&mut buf2).await.unwrap();
        let http_resp2 = String::from_utf8_lossy(&buf2);
        assert!(http_resp2.contains("200 OK"));
        assert!(http_resp2.contains("\"chess\""));

        ws_handle.abort();
        http_handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_auth_jwt_expired_and_valid_over_websocket() {
        let db_file =
            std::env::temp_dir().join(format!("opentable_ratings_auth_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let secret = "relay_jwt_secret_123";
        let auth_cfg = AuthConfig::with_secret(secret);

        let handle = tokio::spawn(async move {
            let _ = run_relay_server_with_config(listener, elo_store, auth_cfg, None).await;
        });

        let url = format!("ws://{addr}");

        // 1. Token expirado -> {"op": "auth_error", "reason": "expired"}
        let expired_token = auth::encode_jwt_hs256(
            &auth::JwtClaims {
                sub: "alice".to_string(),
                exp: 100,
            },
            secret,
        );
        let (mut ws_exp, _) = connect_async(&url).await.unwrap();
        let auth_msg = serde_json::json!({
            "op": "auth",
            "token": expired_token,
        })
        .to_string();
        ws_exp.send(Message::Text(auth_msg.into())).await.unwrap();
        let exp_resp = ws_exp.next().await.unwrap().unwrap().into_text().unwrap();
        let exp_val: Value = serde_json::from_str(&exp_resp).unwrap();
        assert_eq!(exp_val["op"], "auth_error");
        assert_eq!(exp_val["reason"], "expired");

        // 2. Token válido -> {"op": "auth_ok", "player_id": "alice_canonical"}
        let valid_token = auth::encode_jwt_hs256(
            &auth::JwtClaims {
                sub: "alice_canonical".to_string(),
                exp: auth::current_unix_timestamp() + 3600,
            },
            secret,
        );
        let (mut ws_ok, _) = connect_async(&url).await.unwrap();
        let ok_msg = serde_json::json!({
            "op": "auth",
            "token": valid_token,
        })
        .to_string();
        ws_ok.send(Message::Text(ok_msg.into())).await.unwrap();
        let ok_resp = ws_ok.next().await.unwrap().unwrap().into_text().unwrap();
        let ok_val: Value = serde_json::from_str(&ok_resp).unwrap();
        assert_eq!(ok_val["op"], "auth_ok");
        assert_eq!(ok_val["player_id"], "alice_canonical");

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_anticheat_websocket_rejects_illegal_chess_move() {
        let db_file =
            std::env::temp_dir().join(format!("opentable_ratings_ac_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let handle = tokio::spawn(async move {
            let _ = run_relay_server_with_config(listener, elo_store, AuthConfig::default(), None)
                .await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        ws_host
            .send(Message::Text(r#"{"op":"create","game_id":"chess"}"#.into()))
            .await
            .unwrap();
        let created_txt = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let created_val: Value = serde_json::from_str(&created_txt).unwrap();
        let room_code = created_val["room_code"].as_str().unwrap().to_string();
        let host_seed = created_val["seed"].as_u64().unwrap();
        assert!(host_seed > 0);

        let join_msg = serde_json::json!({
            "op": "join",
            "room_code": room_code,
        })
        .to_string();
        ws_guest.send(Message::Text(join_msg.into())).await.unwrap();
        let joined_txt = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let joined_val: Value = serde_json::from_str(&joined_txt).unwrap();
        assert_eq!(joined_val["seed"].as_u64().unwrap(), host_seed);

        // Consumir peer_joined en el host
        let _ = ws_host.next().await.unwrap().unwrap();

        // Enviar movimiento ilegal en Ajedrez (rey e1 -> e5)
        let illegal_relay = serde_json::json!({
            "op": "relay",
            "data": {
                "player": 1,
                "from": { "row": 0, "col": 4 },
                "to": { "row": 4, "col": 4 }
            }
        })
        .to_string();
        ws_host
            .send(Message::Text(illegal_relay.into()))
            .await
            .unwrap();

        let rej_txt = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let rej_val: Value = serde_json::from_str(&rej_txt).unwrap();
        assert_eq!(rej_val["op"], "move_rejected");
        assert_eq!(rej_val["reason"], "illegal_move");

        // Enviar movimiento fuera de turno desde Guest (P2 intenta mover en turno de P1)
        let out_of_turn = serde_json::json!({
            "op": "relay",
            "data": {
                "player": 2,
                "from": { "row": 6, "col": 4 },
                "to": { "row": 4, "col": 4 }
            }
        })
        .to_string();
        ws_guest
            .send(Message::Text(out_of_turn.into()))
            .await
            .unwrap();

        let rej_guest_txt = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let rej_guest_val: Value = serde_json::from_str(&rej_guest_txt).unwrap();
        assert_eq!(rej_guest_val["op"], "move_rejected");
        assert_eq!(rej_guest_val["reason"], "illegal_move");

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_websocket_spectator_flow_and_limits() {
        let db_file =
            std::env::temp_dir().join(format!("opentable_ratings_spec_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let handle = tokio::spawn(async move {
            let _ = run_relay_server_with_config(listener, elo_store, AuthConfig::default(), None)
                .await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        // 1. Host crea sala y Guest se une (player_count = 2)
        ws_host
            .send(Message::Text(r#"{"op":"create"}"#.into()))
            .await
            .unwrap();
        let created_msg = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let created_val: Value = serde_json::from_str(&created_msg).unwrap();
        let room_code = created_val["room_code"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({ "op": "join", "room_code": room_code })
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap();
        let _ = ws_host.next().await.unwrap().unwrap(); // peer_joined

        // 2. Conectar 10 espectadores con {"op": "join_spectator", "room_code": ...}
        let mut spectators = Vec::new();
        for _ in 0..room::MAX_SPECTATORS_PER_ROOM {
            let (mut ws_spec, _) = connect_async(&url).await.unwrap();
            ws_spec
                .send(Message::Text(
                    serde_json::json!({
                        "op": "join_spectator",
                        "room_code": room_code,
                    })
                    .to_string()
                    .into(),
                ))
                .await
                .unwrap();

            let spec_resp = ws_spec.next().await.unwrap().unwrap().into_text().unwrap();
            let spec_val: Value = serde_json::from_str(&spec_resp).unwrap();
            assert_eq!(spec_val["op"], "spectating");
            assert_eq!(spec_val["player_count"], 2);
            spectators.push(ws_spec);
        }

        // 3. El 11.º espectador supera el límite -> {"op": "error", "reason": "spectator_limit"}
        let (mut ws_spec_11, _) = connect_async(&url).await.unwrap();
        ws_spec_11
            .send(Message::Text(
                serde_json::json!({
                    "op": "join_spectator",
                    "room_code": room_code,
                })
                .to_string()
                .into(),
            ))
            .await
            .unwrap();
        let limit_resp = ws_spec_11
            .next()
            .await
            .unwrap()
            .unwrap()
            .into_text()
            .unwrap();
        let limit_val: Value = serde_json::from_str(&limit_resp).unwrap();
        assert_eq!(limit_val["op"], "error");
        assert_eq!(limit_val["reason"], "spectator_limit");

        // 4. Host envía {"op": "relay", "data": "move_1"} -> espectadores reciben el evento en tiempo real
        ws_host
            .send(Message::Text(r#"{"op":"relay","data":"move_1"}"#.into()))
            .await
            .unwrap();
        let sp_relayed = spectators[0]
            .next()
            .await
            .unwrap()
            .unwrap()
            .into_text()
            .unwrap();
        let sp_relayed_val: Value = serde_json::from_str(&sp_relayed).unwrap();
        assert_eq!(sp_relayed_val["op"], "relay");
        assert_eq!(sp_relayed_val["data"], "move_1");

        // 5. Espectador intenta enviar {"op": "relay"} -> {"op": "error", "reason": "spectator_cannot_relay"}
        spectators[0]
            .send(Message::Text(
                r#"{"op":"relay","data":"forged_move"}"#.into(),
            ))
            .await
            .unwrap();
        let err_resp = spectators[0]
            .next()
            .await
            .unwrap()
            .unwrap()
            .into_text()
            .unwrap();
        let err_val: Value = serde_json::from_str(&err_resp).unwrap();
        assert_eq!(err_val["op"], "error");
        assert_eq!(err_val["reason"], "spectator_cannot_relay");

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_elo_autoverify_on_gameover_resign_and_anti_spoofing() {
        let db_file = std::env::temp_dir().join(format!(
            "opentable_ratings_elo_autoverify_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let store_clone = Arc::clone(&elo_store);
        let handle = tokio::spawn(async move {
            let _ =
                run_relay_server_with_config(listener, store_clone, AuthConfig::default(), None)
                    .await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        // Autenticar ambos jugadores con identidades canónicas
        let host_token = auth::AuthConfig::default()
            .issue_guest_token("device-host-1")
            .token;
        let guest_token = auth::AuthConfig::default()
            .issue_guest_token("device-guest-2")
            .token;

        ws_host
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": host_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let host_auth_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let host_id = host_auth_val["player_id"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": guest_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let guest_auth_val: Value =
            serde_json::from_str(&ws_guest.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let guest_id = guest_auth_val["player_id"].as_str().unwrap().to_string();

        // Crear sala de ajedrez con Anti-Cheat activo
        ws_host
            .send(Message::Text(r#"{"op":"create","game_id":"chess"}"#.into()))
            .await
            .unwrap();
        let created_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let room_code = created_val["room_code"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "join", "room_code": room_code})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap();
        let _ = ws_host.next().await.unwrap().unwrap(); // peer_joined

        // 1. Intento de spoofing: Guest envía report_result antes de que la partida termine -> match_not_finished
        let spoof_msg = serde_json::json!({
            "op": "report_result",
            "winner": guest_id,
            "loser": host_id,
            "game_id": "chess"
        })
        .to_string();
        ws_guest
            .send(Message::Text(spoof_msg.into()))
            .await
            .unwrap();
        let spoof_resp: Value =
            serde_json::from_str(&ws_guest.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(spoof_resp["op"], "error");
        assert_eq!(spoof_resp["reason"], "match_not_finished");

        // 2. Host envía {"op": "resign"} -> servidor adjudica victoria a Guest y emite elo_updated a toda la sala
        ws_host
            .send(Message::Text(r#"{"op":"resign"}"#.into()))
            .await
            .unwrap();

        let host_elo_msg: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(host_elo_msg["op"], "elo_updated");
        assert_eq!(host_elo_msg["winner"], guest_id);
        assert_eq!(host_elo_msg["loser"], host_id);
        assert_eq!(host_elo_msg["winner_elo"], 1216);
        assert_eq!(host_elo_msg["loser_elo"], 1184);

        let guest_elo_msg: Value =
            serde_json::from_str(&ws_guest.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(guest_elo_msg["op"], "elo_updated");
        assert_eq!(guest_elo_msg["winner"], guest_id);
        assert_eq!(guest_elo_msg["loser"], host_id);
        assert_eq!(guest_elo_msg["winner_elo"], 1216);
        assert_eq!(guest_elo_msg["loser_elo"], 1184);

        // 3. Idempotencia: segundos envíos de resign o report_result no alteran el ELO en SQLite
        ws_host
            .send(Message::Text(r#"{"op":"resign"}"#.into()))
            .await
            .unwrap();
        ws_guest
            .send(Message::Text(
                serde_json::json!({
                    "op": "report_result",
                    "winner": guest_id,
                    "loser": host_id,
                    "game_id": "chess"
                })
                .to_string()
                .into(),
            ))
            .await
            .unwrap();
        tokio::time::sleep(Duration::from_millis(30)).await;

        {
            let store = elo_store.lock().await;
            let ratings = store.get_rankings("chess", 10);
            let winner_entry = ratings.iter().find(|r| r.player_id == guest_id).unwrap();
            let loser_entry = ratings.iter().find(|r| r.player_id == host_id).unwrap();
            assert_eq!(winner_entry.elo, 1216);
            assert_eq!(winner_entry.wins, 1);
            assert_eq!(loser_entry.elo, 1184);
            assert_eq!(loser_entry.losses, 1);
        }

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_elo_autoverify_on_fools_mate_checkmate() {
        let db_file = std::env::temp_dir().join(format!(
            "opentable_ratings_elo_autoverify_mate_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let store_clone = Arc::clone(&elo_store);
        let handle = tokio::spawn(async move {
            let _ =
                run_relay_server_with_config(listener, store_clone, AuthConfig::default(), None)
                    .await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        let host_token = auth::AuthConfig::default()
            .issue_guest_token("device-fools-white")
            .token;
        let guest_token = auth::AuthConfig::default()
            .issue_guest_token("device-fools-black")
            .token;

        ws_host
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": host_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let host_auth_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let host_id = host_auth_val["player_id"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": guest_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let guest_auth_val: Value =
            serde_json::from_str(&ws_guest.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let guest_id = guest_auth_val["player_id"].as_str().unwrap().to_string();

        // Host crea sala de ajedrez y Guest se une
        ws_host
            .send(Message::Text(r#"{"op":"create","game_id":"chess"}"#.into()))
            .await
            .unwrap();
        let created_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let room_code = created_val["room_code"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "join", "room_code": room_code})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap(); // joined
        let _ = ws_host.next().await.unwrap().unwrap(); // peer_joined

        // Mate del Loco (Fool's Mate):
        // 1. f2 -> f3 (P1: row 1 col 5 -> row 2 col 5)
        ws_host
            .send(Message::Text(
                serde_json::json!({
                    "op": "relay",
                    "data": {
                        "player": 1,
                        "from": { "row": 1, "col": 5 },
                        "to": { "row": 2, "col": 5 }
                    }
                })
                .to_string()
                .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap(); // relay 1

        // 2. e7 -> e5 (P2: row 6 col 4 -> row 4 col 4)
        ws_guest
            .send(Message::Text(
                serde_json::json!({
                    "op": "relay",
                    "data": {
                        "player": 2,
                        "from": { "row": 6, "col": 4 },
                        "to": { "row": 4, "col": 4 }
                    }
                })
                .to_string()
                .into(),
            ))
            .await
            .unwrap();
        let _ = ws_host.next().await.unwrap().unwrap(); // relay 2

        // 3. g2 -> g4 (P1: row 1 col 6 -> row 3 col 6)
        ws_host
            .send(Message::Text(
                serde_json::json!({
                    "op": "relay",
                    "data": {
                        "player": 1,
                        "from": { "row": 1, "col": 6 },
                        "to": { "row": 3, "col": 6 }
                    }
                })
                .to_string()
                .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap(); // relay 3

        // 4. Qd8 -> h4# (P2: row 7 col 3 -> row 3 col 7) -> Jaque mate autoritativo
        ws_guest
            .send(Message::Text(
                serde_json::json!({
                    "op": "relay",
                    "data": {
                        "player": 2,
                        "from": { "row": 7, "col": 3 },
                        "to": { "row": 3, "col": 7 }
                    }
                })
                .to_string()
                .into(),
            ))
            .await
            .unwrap();

        // Host recibe primero el movimiento retransmitido y luego elo_updated
        let host_relay_4: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(host_relay_4["op"], "relay");

        let host_elo_msg: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(host_elo_msg["op"], "elo_updated");
        assert_eq!(host_elo_msg["winner"], guest_id);
        assert_eq!(host_elo_msg["loser"], host_id);
        assert_eq!(host_elo_msg["winner_elo"], 1216);
        assert_eq!(host_elo_msg["loser_elo"], 1184);

        // Guest (emisor del jaque mate) recibe elo_updated
        let guest_elo_msg: Value =
            serde_json::from_str(&ws_guest.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(guest_elo_msg["op"], "elo_updated");
        assert_eq!(guest_elo_msg["winner"], guest_id);
        assert_eq!(guest_elo_msg["loser"], host_id);
        assert_eq!(guest_elo_msg["winner_elo"], 1216);
        assert_eq!(guest_elo_msg["loser_elo"], 1184);

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_websocket_rejoin_room_restores_seat_and_command_log() {
        let db_file = std::env::temp_dir().join(format!(
            "opentable_ratings_rejoin_ws_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let handle = tokio::spawn(async move {
            let _ = run_relay_server_with_config(listener, elo_store, AuthConfig::default(), None)
                .await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        let host_token = auth::AuthConfig::default()
            .issue_guest_token("device-rejoin-host")
            .token;
        let guest_token = auth::AuthConfig::default()
            .issue_guest_token("device-rejoin-guest")
            .token;

        ws_host
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": host_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_host.next().await.unwrap().unwrap();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": guest_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap();

        // Host crea sala de ajedrez y Guest se une
        ws_host
            .send(Message::Text(r#"{"op":"create","game_id":"chess"}"#.into()))
            .await
            .unwrap();
        let created_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let room_code = created_val["room_code"].as_str().unwrap().to_string();
        let seed = created_val["seed"].as_u64().unwrap();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "join", "room_code": room_code})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap(); // joined
        let _ = ws_host.next().await.unwrap().unwrap(); // peer_joined

        // 1. Host juega e2 -> e4
        let move_1 = serde_json::json!({
            "player": 1,
            "from": { "row": 1, "col": 4 },
            "to": { "row": 3, "col": 4 }
        });
        ws_host
            .send(Message::Text(
                serde_json::json!({ "op": "relay", "data": move_1 })
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap();

        // 2. Guest juega e7 -> e5
        let move_2 = serde_json::json!({
            "player": 2,
            "from": { "row": 6, "col": 4 },
            "to": { "row": 4, "col": 4 }
        });
        ws_guest
            .send(Message::Text(
                serde_json::json!({ "op": "relay", "data": move_2 })
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_host.next().await.unwrap().unwrap();

        // 3. Guest sufre caída accidental del socket -> Host recibe opponent_disconnected (90s)
        let _ = ws_guest.close(None).await;
        drop(ws_guest);

        let disc_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(disc_val["op"], "opponent_disconnected");
        assert_eq!(disc_val["grace_seconds"], 90);

        // 4. Guest se reconecta en un nuevo socket, se autentica y envía rejoin_room
        let (mut ws_guest_reconn, _) = connect_async(&url).await.unwrap();
        ws_guest_reconn
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": guest_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest_reconn.next().await.unwrap().unwrap();

        ws_guest_reconn
            .send(Message::Text(
                serde_json::json!({"op": "rejoin_room", "room_code": room_code})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();

        let rejoined_val: Value = serde_json::from_str(
            &ws_guest_reconn
                .next()
                .await
                .unwrap()
                .unwrap()
                .into_text()
                .unwrap(),
        )
        .unwrap();
        assert_eq!(rejoined_val["op"], "rejoined");
        assert_eq!(rejoined_val["room_code"], room_code);
        assert_eq!(rejoined_val["player_id"], 2);
        assert_eq!(rejoined_val["seed"], seed);
        let cmds = rejoined_val["commands"].as_array().unwrap();
        assert_eq!(cmds.len(), 2);
        assert_eq!(cmds[0], move_1);
        assert_eq!(cmds[1], move_2);

        // 5. Host recibe {"op": "opponent_reconnected"}
        let reconn_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(reconn_val["op"], "opponent_reconnected");

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_websocket_rejoin_grace_timeout_awards_victory_by_abandonment() {
        let db_file = std::env::temp_dir().join(format!(
            "opentable_ratings_rejoin_timeout_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let mut room_mgr = RoomManager::new();
        room_mgr.set_rejoin_grace_duration(Duration::from_millis(60));
        let state = RelaySharedState {
            manager: Arc::new(Mutex::new(room_mgr)),
            elo_store: Arc::clone(&elo_store),
            tournaments: Arc::new(Mutex::new(TournamentManager::new())),
            rate_limiter: Arc::new(Mutex::new(RelayRateLimiter::new())),
            auth_config: AuthConfig::default(),
            tls_config: None,
        };

        let handle = tokio::spawn(async move {
            let _ = run_relay_server_with_state(listener, state).await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        let host_token = auth::AuthConfig::default()
            .issue_guest_token("device-timeout-host")
            .token;
        let guest_token = auth::AuthConfig::default()
            .issue_guest_token("device-timeout-guest")
            .token;

        ws_host
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": host_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let host_auth: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let host_id = host_auth["player_id"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": guest_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let guest_auth: Value =
            serde_json::from_str(&ws_guest.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let guest_id = guest_auth["player_id"].as_str().unwrap().to_string();

        ws_host
            .send(Message::Text(r#"{"op":"create","game_id":"chess"}"#.into()))
            .await
            .unwrap();
        let created_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let room_code = created_val["room_code"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "join", "room_code": room_code})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap();
        let _ = ws_host.next().await.unwrap().unwrap(); // peer_joined

        // Guest se desconecta y no vuelve a conectarse dentro de la ventana de gracia
        let _ = ws_guest.close(None).await;
        drop(ws_guest);

        let disc_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(disc_val["op"], "opponent_disconnected");

        // Al expirar la ventana de gracia, Host gana por abandono y recibe elo_updated
        let elo_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(elo_val["op"], "elo_updated");
        assert_eq!(elo_val["winner"], host_id);
        assert_eq!(elo_val["loser"], guest_id);
        assert_eq!(elo_val["winner_elo"], 1216);
        assert_eq!(elo_val["loser_elo"], 1184);

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_websocket_turn_timeout_awards_victory_and_updates_elo() {
        let db_file = std::env::temp_dir().join(format!(
            "opentable_ratings_turn_timeout_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let store_clone = Arc::clone(&elo_store);
        let handle = tokio::spawn(async move {
            let _ =
                run_relay_server_with_config(listener, store_clone, AuthConfig::default(), None)
                    .await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        let host_token = auth::AuthConfig::default()
            .issue_guest_token("device-afk-host")
            .token;
        let guest_token = auth::AuthConfig::default()
            .issue_guest_token("device-afk-guest")
            .token;

        ws_host
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": host_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let host_auth: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let host_id = host_auth["player_id"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "auth", "token": guest_token})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let guest_auth: Value =
            serde_json::from_str(&ws_guest.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let guest_id = guest_auth["player_id"].as_str().unwrap().to_string();

        // Host crea sala con turn_timeout_secs = 1 segundo
        ws_host
            .send(Message::Text(
                r#"{"op":"create","game_id":"chess","turn_timeout_secs":1}"#.into(),
            ))
            .await
            .unwrap();
        let created_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        let room_code = created_val["room_code"].as_str().unwrap().to_string();

        ws_guest
            .send(Message::Text(
                serde_json::json!({"op": "join", "room_code": room_code})
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap();
        let _ = ws_host.next().await.unwrap().unwrap(); // peer_joined

        // Host (P1) juega e2 -> e4; ahora el turno activo pasa a Guest (asiento 2)
        ws_host
            .send(Message::Text(
                serde_json::json!({
                    "op": "relay",
                    "data": {
                        "player": 1,
                        "from": { "row": 1, "col": 4 },
                        "to": { "row": 3, "col": 4 }
                    }
                })
                .to_string()
                .into(),
            ))
            .await
            .unwrap();
        let _ = ws_guest.next().await.unwrap().unwrap(); // relay 1

        // Guest se queda AFK (>1s) -> el reloj autoritativo del servidor declara ganador a Host (winner_seat: 1)
        let host_timeout_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(host_timeout_val["op"], "match_timeout");
        assert_eq!(host_timeout_val["winner_seat"], 1);
        assert_eq!(host_timeout_val["reason"], "turn_timeout");

        let host_elo_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(host_elo_val["op"], "elo_updated");
        assert_eq!(host_elo_val["winner"], host_id);
        assert_eq!(host_elo_val["loser"], guest_id);
        assert_eq!(host_elo_val["winner_elo"], 1216);
        assert_eq!(host_elo_val["loser_elo"], 1184);

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_prune_stale_rooms_and_graceful_shutdown_notifies_clients_and_flushes_wal() {
        let db_file = std::env::temp_dir().join(format!(
            "opentable_ratings_shutdown_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let state = RelaySharedState {
            manager: Arc::new(Mutex::new(RoomManager::new())),
            elo_store: Arc::clone(&elo_store),
            tournaments: Arc::new(Mutex::new(TournamentManager::new())),
            rate_limiter: Arc::new(Mutex::new(RelayRateLimiter::new())),
            auth_config: AuthConfig::default(),
            tls_config: None,
        };

        let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel::<()>();
        let state_for_server = state.clone();
        let handle = tokio::spawn(async move {
            run_relay_server_with_state_until(listener, state_for_server, async move {
                let _ = shutdown_rx.await;
            })
            .await
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_lobby, _) = connect_async(&url).await.unwrap();

        // Host crea una sala mientras ws_lobby permanece conectado en el lobby
        ws_host
            .send(Message::Text(r#"{"op":"create","game_id":"chess"}"#.into()))
            .await
            .unwrap();
        let created_val: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(created_val["op"], "created");

        // Registrar un resultado en EloStore antes de apagar
        {
            let mut store = elo_store.lock().await;
            store
                .report_result("shutdown_winner", "shutdown_loser", "chess")
                .unwrap();
        }

        // Disparar señal de parada (equivalente a SIGINT/SIGTERM)
        let _ = shutdown_tx.send(());

        // Ambos clientes reciben {"op": "server_shutting_down"}
        let host_shutdown: Value =
            serde_json::from_str(&ws_host.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(host_shutdown["op"], "server_shutting_down");

        let lobby_shutdown: Value =
            serde_json::from_str(&ws_lobby.next().await.unwrap().unwrap().into_text().unwrap())
                .unwrap();
        assert_eq!(lobby_shutdown["op"], "server_shutting_down");

        // El servidor finaliza limpiamente con Ok(()) tras hacer flush de SQLite
        let server_res = handle.await.unwrap();
        assert!(server_res.is_ok());

        // Verificar que la base de datos en disco tiene el checkpoint persistido
        let reopened = EloStore::new(&db_file).unwrap();
        let rankings = reopened.get_rankings("chess", 10);
        assert_eq!(rankings.len(), 2);
        assert_eq!(rankings[0].player_id, "shutdown_winner");
        assert_eq!(rankings[0].elo, 1216);

        let _ = std::fs::remove_file(&db_file);
    }
}
