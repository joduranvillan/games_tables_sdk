// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Lado host de `Transport` sobre TCP. Topología estrella: el host acepta
//! N conexiones, cada una identificada por un `PlayerId`.
//!
//! Cada conexión nueva pasa por un handshake (`Join` o `Reconnect`, ver
//! `handshake.rs`) antes de poder mandar comandos. Esto es lo que permite
//! distinguir "un jugador nuevo" de "un jugador que se había caído y
//! volvió" sin confiar en un `PlayerId` que el cliente simplemente
//! reclama.
//!
//! Además, una desconexión no deja la sesión abierta para siempre: si el
//! jugador no vuelve dentro de `reconnect_timeout`, su `reconnect_token`
//! se invalida y se emite `ConnectionEvent::TimedOut` para que el juego
//! decida qué hacer (terminar la partida, declarar forfeit, lo que sea).
//!
//! Nota de diseño: esta implementación maneja UNA sala por puerto a
//! propósito — es el equivalente desktop de "cada `TcpListener::bind`
//! es una mesa". Si en algún momento hiciera falta que un mismo proceso
//! sirva varias salas a la vez, la forma natural de resolverlo es correr
//! varios `TcpHostTransport` (uno por sala, cada uno en su puerto), no
//! multiplexar salas dentro de un mismo listener.

use std::collections::{HashMap, VecDeque};
use std::io;
use std::net::{SocketAddr, TcpListener, TcpStream, ToSocketAddrs};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;

use crate::framing::{read_frame, write_frame};
use crate::handshake::{HandshakeRequest, HandshakeResponse};

static NEXT_CONN_ID: AtomicU64 = AtomicU64::new(1);

type IncomingQueue = Arc<Mutex<VecDeque<(PlayerId, Vec<u8>)>>>;
type Connections = Arc<Mutex<HashMap<PlayerId, (u64, TcpStream)>>>;
/// PlayerId -> token vigente. Se conserva incluso después de que el
/// jugador se desconecta, precisamente para poder validar su próxima
/// reconexión — hasta que pasa `reconnect_timeout`, momento en el que se
/// purga (ver `check_timeouts`).
type Sessions = Arc<Mutex<HashMap<PlayerId, String>>>;
type PlayerNames = Arc<Mutex<HashMap<PlayerId, String>>>;
type ConnectionEvents = Arc<Mutex<VecDeque<ConnectionEvent>>>;
/// PlayerId -> instante en que se desconectó. Solo tiene entradas para
/// jugadores actualmente caídos; se limpia al reconectar o al expirar.
type DisconnectTimes = Arc<Mutex<HashMap<PlayerId, Instant>>>;

const DEFAULT_RECONNECT_TIMEOUT: Duration = Duration::from_secs(60);

/// Lo que le pasó a una conexión. No es parte del trait `Transport`
/// genérico (Nearby Connections/Multipeer van a tener su propia noción de
/// esto) — es una capacidad extra específica de esta implementación,
/// consumida por quien maneja el loop del host para decidir cuándo
/// disparar un resync o dar por perdido a un jugador.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectionEvent {
    Joined {
        player: PlayerId,
    },
    Reconnected {
        player: PlayerId,
    },
    Disconnected {
        player: PlayerId,
    },
    /// El jugador se desconectó y no volvió dentro de `reconnect_timeout`.
    /// Su `reconnect_token` ya fue invalidado: un intento de reconexión
    /// posterior con ese token va a ser rechazado.
    TimedOut {
        player: PlayerId,
    },
}

pub struct TcpHostTransport {
    local_addr: SocketAddr,
    incoming: IncomingQueue,
    connections: Connections,
    connection_events: ConnectionEvents,
    sessions: Sessions,
    player_names: PlayerNames,
    disconnect_times: DisconnectTimes,
    reconnect_timeout: Duration,
}

impl TcpHostTransport {
    /// Usa el timeout de reconexión por defecto (60 segundos).
    pub fn bind(addr: impl ToSocketAddrs) -> io::Result<Self> {
        Self::bind_with_timeout(addr, DEFAULT_RECONNECT_TIMEOUT)
    }

    /// Igual que `bind`, pero con un `reconnect_timeout` explícito —
    /// útil para tests (timeouts cortos) o para juegos que quieran dar
    /// más o menos margen antes de dar por perdido a un jugador caído.
    pub fn bind_with_timeout(
        addr: impl ToSocketAddrs,
        reconnect_timeout: Duration,
    ) -> io::Result<Self> {
        let listener = TcpListener::bind(addr)?;
        let local_addr = listener.local_addr()?;

        let incoming: IncomingQueue = Arc::new(Mutex::new(VecDeque::new()));
        let connections: Connections = Arc::new(Mutex::new(HashMap::new()));
        let sessions: Sessions = Arc::new(Mutex::new(HashMap::new()));
        let player_names: PlayerNames = Arc::new(Mutex::new(HashMap::new()));
        let connection_events: ConnectionEvents = Arc::new(Mutex::new(VecDeque::new()));
        let disconnect_times: DisconnectTimes = Arc::new(Mutex::new(HashMap::new()));
        let next_id = Arc::new(Mutex::new(1u32));

        let incoming_top = Arc::clone(&incoming);
        let connections_top = Arc::clone(&connections);
        let sessions_top = Arc::clone(&sessions);
        let player_names_top = Arc::clone(&player_names);
        let events_top = Arc::clone(&connection_events);
        let disconnect_times_top = Arc::clone(&disconnect_times);

        thread::spawn(move || {
            for stream_result in listener.incoming() {
                let Ok(stream) = stream_result else {
                    continue;
                };

                let incoming = Arc::clone(&incoming_top);
                let connections = Arc::clone(&connections_top);
                let sessions = Arc::clone(&sessions_top);
                let player_names = Arc::clone(&player_names_top);
                let events = Arc::clone(&events_top);
                let disconnect_times = Arc::clone(&disconnect_times_top);
                let next_id = Arc::clone(&next_id);

                // Cada conexión (handshake + lectura posterior) vive en su
                // propio thread para no bloquear el accept-loop mientras
                // se negocia con un cliente lento.
                thread::spawn(move || {
                    handle_connection(
                        stream,
                        incoming,
                        connections,
                        sessions,
                        player_names,
                        events,
                        disconnect_times,
                        next_id,
                    );
                });
            }
        });

        Ok(Self {
            local_addr,
            incoming,
            connections,
            connection_events,
            sessions,
            player_names,
            disconnect_times,
            reconnect_timeout,
        })
    }

    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    /// Vacía la cola de "qué pasó con las conexiones" desde el último
    /// poll: quién se unió, quién se reconectó, quién se cayó, y a quién
    /// ya se le venció el plazo para volver. Se llama junto con
    /// `poll_received()` en el mismo loop de ticks del host.
    pub fn poll_connection_events(&mut self) -> Vec<ConnectionEvent> {
        self.check_timeouts();
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

    pub fn get_player_name(&self, player: PlayerId) -> Option<String> {
        self.player_names
            .lock()
            .expect("lock de player_names envenenado")
            .get(&player)
            .cloned()
    }

    /// Revisa quién lleva desconectado más de `reconnect_timeout` y, si
    /// lo encuentra, invalida su token (para que un intento de
    /// reconexión tardío se rechace limpiamente) y encola un
    /// `ConnectionEvent::TimedOut`.
    fn check_timeouts(&self) {
        let now = Instant::now();
        let mut disconnect_times = self
            .disconnect_times
            .lock()
            .expect("lock de disconnect_times envenenado");
        let expired: Vec<PlayerId> = disconnect_times
            .iter()
            .filter(|(_, since)| now.duration_since(**since) >= self.reconnect_timeout)
            .map(|(player, _)| *player)
            .collect();

        if expired.is_empty() {
            return;
        }

        let mut sessions = self.sessions.lock().expect("lock de sessions envenenado");
        let mut events = self
            .connection_events
            .lock()
            .expect("lock de connection_events envenenado");

        for player in expired {
            disconnect_times.remove(&player);
            sessions.remove(&player); // token invalidado: ya no se puede reconectar
            events.push_back(ConnectionEvent::TimedOut { player });
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn handle_connection(
    mut stream: TcpStream,
    incoming: IncomingQueue,
    connections: Connections,
    sessions: Sessions,
    player_names: PlayerNames,
    events: ConnectionEvents,
    disconnect_times: DisconnectTimes,
    next_id: Arc<Mutex<u32>>,
) {
    let Ok(request_bytes) = read_frame(&mut stream) else {
        return; // se cayó antes de completar el handshake
    };
    let Ok(request) = serde_json::from_slice::<HandshakeRequest>(&request_bytes) else {
        return; // handshake corrupto/no reconocido
    };

    if request.protocol_version() != crate::handshake::PROTOCOL_VERSION {
        let response = HandshakeResponse::UnsupportedProtocolVersion {
            expected: crate::handshake::PROTOCOL_VERSION.to_string(),
            got: request.protocol_version().to_string(),
        };
        if let Ok(bytes) = serde_json::to_vec(&response) {
            let _ = write_frame(&mut stream, &bytes);
        }
        return;
    }

    let outcome = resolve_handshake(request, &sessions, &player_names, &next_id);

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
        protocol_version: crate::handshake::PROTOCOL_VERSION.to_string(),
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

    let conn_id = NEXT_CONN_ID.fetch_add(1, Ordering::Relaxed);

    // Si estaba en la lista de "desconectados esperando timeout", volvió
    // a tiempo: se cancela la cuenta regresiva.
    disconnect_times
        .lock()
        .expect("lock de disconnect_times envenenado")
        .remove(&player_id);

    connections
        .lock()
        .expect("lock de connections envenenado")
        .insert(player_id, (conn_id, stream));
    events
        .lock()
        .expect("lock de connection_events envenenado")
        .push_back(event);

    // Loop de lectura normal: de acá en más, todo lo que llegue por esta
    // conexión son CommandEnvelope reales del juego.
    let mut read_stream = read_stream;
    while let Ok(bytes) = read_frame(&mut read_stream) {
        incoming
            .lock()
            .expect("lock de incoming envenenado")
            .push_back((player_id, bytes));
    }

    let mut conns = connections.lock().expect("lock de connections envenenado");
    if let Some((id, _)) = conns.get(&player_id) {
        if *id == conn_id {
            conns.remove(&player_id);
            disconnect_times
                .lock()
                .expect("lock de disconnect_times envenenado")
                .insert(player_id, Instant::now());
            events
                .lock()
                .expect("lock de connection_events envenenado")
                .push_back(ConnectionEvent::Disconnected { player: player_id });
        }
    }
}

/// Decide qué hacer con un handshake entrante. Devuelve
/// `(player_id, token, evento)` si se acepta, o el motivo del rechazo.
/// Si `sessions` ya no tiene al `player_id` (porque `check_timeouts` lo
/// purgó), un `Reconnect` se rechaza igual que si el token fuera
/// incorrecto — desde la perspectiva del cliente, "llegaste tarde" y
/// "token inválido" son el mismo caso: no hay sesión que reclamar.
fn resolve_handshake(
    request: HandshakeRequest,
    sessions: &Sessions,
    player_names: &PlayerNames,
    next_id: &Arc<Mutex<u32>>,
) -> Result<(PlayerId, String, ConnectionEvent), String> {
    let mut sessions = sessions.lock().expect("lock de sessions envenenado");

    match request {
        HandshakeRequest::Join { player_name, .. } => {
            let player_id = {
                let mut guard = next_id.lock().expect("lock de next_id envenenado");
                let id = PlayerId(*guard);
                *guard += 1;
                id
            };
            let token = generate_token();
            sessions.insert(player_id, token.clone());
            player_names
                .lock()
                .expect("lock de player_names envenenado")
                .insert(player_id, player_name);
            Ok((
                player_id,
                token,
                ConnectionEvent::Joined { player: player_id },
            ))
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

/// Token de reconexión, generado con el CSPRNG del sistema operativo
/// (vía `getrandom`) — 128 bits de entropía, codificados en hex. A
/// diferencia de una versión anterior de este archivo (tiempo del
/// sistema + contador), esto sí es apto para producción: no es
/// adivinable ni repetible entre procesos.
fn generate_token() -> String {
    let mut bytes = [0u8; 16];
    getrandom::fill(&mut bytes).expect(
        "el sistema operativo debería poder darnos bytes aleatorios; \
         si esto falla, algo está muy mal a nivel de SO",
    );
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

impl Transport for TcpHostTransport {
    fn send(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        let mut conns = self
            .connections
            .lock()
            .expect("lock de connections envenenado");
        let (_id, stream) = conns
            .get_mut(&peer)
            .ok_or_else(|| EngineError::Network(format!("jugador {peer:?} no está conectado")))?;
        write_frame(stream, bytes).map_err(|e| EngineError::Network(e.to_string()))
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        let mut conns = self
            .connections
            .lock()
            .expect("lock de connections envenenado");
        for (_id, stream) in conns.values_mut() {
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

#[cfg(test)]
mod tests {
    use super::generate_token;

    #[test]
    fn los_tokens_generados_son_distintos_y_de_128_bits_en_hex() {
        let a = generate_token();
        let b = generate_token();
        assert_ne!(a, b, "dos tokens generados no deberían coincidir jamás");
        assert_eq!(a.len(), 32, "128 bits en hex son 32 caracteres");
        assert!(a.chars().all(|c| c.is_ascii_hexdigit()));
    }
}
