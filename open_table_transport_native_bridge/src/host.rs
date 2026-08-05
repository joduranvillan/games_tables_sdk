use std::collections::{HashMap, VecDeque};
use std::time::{Duration, Instant};

use open_table_core::error::{EngineError, EngineResult};
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;

use crate::handshake::{generate_token, HandshakeRequest, HandshakeResponse};
use crate::link::{RawByteLink, RawLinkEvent};

const DEFAULT_RECONNECT_TIMEOUT: Duration = Duration::from_secs(60);

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConnectionEvent {
    Joined { player: PlayerId },
    Reconnected { player: PlayerId },
    Disconnected { player: PlayerId },
    TimedOut { player: PlayerId },
}

/// Mismo rol que `TcpHostTransport`, pero genérico sobre CUALQUIER
/// `RawByteLink` — no sabe ni le importa si abajo hay un socket TCP,
/// Nearby Connections, o MultipeerConnectivity. El plugin nativo real
/// (Kotlin/Swift) solo tiene que implementar `RawByteLink`; toda esta
/// lógica de por acá ya está escrita y probada.
pub struct NativeHostTransport<L: RawByteLink> {
    link: L,
    next_id: u32,
    /// PlayerId -> token vigente. Sobrevive a la desconexión hasta que
    /// expira el timeout.
    sessions: HashMap<PlayerId, String>,
    peer_to_player: HashMap<String, PlayerId>,
    player_to_peer: HashMap<PlayerId, String>,
    disconnect_times: HashMap<PlayerId, Instant>,
    reconnect_timeout: Duration,
    incoming: VecDeque<(PlayerId, Vec<u8>)>,
    connection_events: VecDeque<ConnectionEvent>,
}

impl<L: RawByteLink> NativeHostTransport<L> {
    pub fn new(link: L) -> Self {
        Self::with_timeout(link, DEFAULT_RECONNECT_TIMEOUT)
    }

    pub fn with_timeout(link: L, reconnect_timeout: Duration) -> Self {
        Self {
            link,
            next_id: 1,
            sessions: HashMap::new(),
            peer_to_player: HashMap::new(),
            player_to_peer: HashMap::new(),
            disconnect_times: HashMap::new(),
            reconnect_timeout,
            incoming: VecDeque::new(),
            connection_events: VecDeque::new(),
        }
    }

    pub fn poll_connection_events(&mut self) -> Vec<ConnectionEvent> {
        self.tick();
        self.connection_events.drain(..).collect()
    }

    /// Acceso mutable al `RawByteLink` subyacente. Hace falta porque
    /// conectar un peer nuevo (ej. `NearbyPlugin.connect(tag)`) es una
    /// operación específica de cada plataforma que este crate no conoce
    /// — vive en el link, no acá.
    pub fn link_mut(&mut self) -> &mut L {
        &mut self.link
    }

    /// Procesa todo lo que llegó del link desde el último tick: mensajes
    /// crudos (handshake o datos de juego, según si ya conocemos al
    /// peer) y eventos de desconexión. Se llama al principio de
    /// cualquier operación pública, igual que `check_timeouts` en
    /// `TcpHostTransport`.
    fn tick(&mut self) {
        for event in self.link.poll_link_events() {
            match event {
                RawLinkEvent::Disconnected(peer_tag) => {
                    if let Some(player) = self.peer_to_player.remove(&peer_tag) {
                        self.player_to_peer.remove(&player);
                        self.disconnect_times.insert(player, Instant::now());
                        self.connection_events
                            .push_back(ConnectionEvent::Disconnected { player });
                    }
                }
            }
        }

        for (peer_tag, bytes) in self.link.poll_raw_received() {
            if let Some(&player) = self.peer_to_player.get(&peer_tag) {
                self.incoming.push_back((player, bytes));
                continue;
            }
            self.handle_handshake(&peer_tag, &bytes);
        }

        self.check_timeouts();
    }

    fn handle_handshake(&mut self, peer_tag: &str, bytes: &[u8]) {
        let Ok(request) = serde_json::from_slice::<HandshakeRequest>(bytes) else {
            return; // mensaje corrupto/no reconocido antes de identificarse: se ignora
        };

        let outcome = match request {
            HandshakeRequest::Join { .. } => {
                let player = PlayerId(self.next_id);
                self.next_id += 1;
                let token = generate_token();
                self.sessions.insert(player, token.clone());
                Ok((player, token, ConnectionEvent::Joined { player }))
            }
            HandshakeRequest::Reconnect {
                player_id,
                reconnect_token,
            } => match self.sessions.get(&player_id) {
                Some(existing) if *existing == reconnect_token => Ok((
                    player_id,
                    reconnect_token,
                    ConnectionEvent::Reconnected { player: player_id },
                )),
                Some(_) => Err("token de reconexión inválido".to_string()),
                None => Err(format!(
                    "no existe una sesión previa para {player_id:?} (¿expiró el plazo de reconexión?)"
                )),
            },
        };

        match outcome {
            Ok((player, token, event)) => {
                let response = HandshakeResponse::Welcome {
                    player_id: player,
                    reconnect_token: token,
                };
                if let Ok(bytes) = serde_json::to_vec(&response) {
                    let _ = self.link.send_raw(peer_tag, &bytes);
                }
                self.peer_to_player.insert(peer_tag.to_string(), player);
                self.player_to_peer.insert(player, peer_tag.to_string());
                self.disconnect_times.remove(&player);
                self.connection_events.push_back(event);
            }
            Err(reason) => {
                let response = HandshakeResponse::Rejected { reason };
                if let Ok(bytes) = serde_json::to_vec(&response) {
                    let _ = self.link.send_raw(peer_tag, &bytes);
                }
            }
        }
    }

    fn check_timeouts(&mut self) {
        let now = Instant::now();
        let expired: Vec<PlayerId> = self
            .disconnect_times
            .iter()
            .filter(|(_, since)| now.duration_since(**since) >= self.reconnect_timeout)
            .map(|(player, _)| *player)
            .collect();

        for player in expired {
            self.disconnect_times.remove(&player);
            self.sessions.remove(&player);
            self.connection_events
                .push_back(ConnectionEvent::TimedOut { player });
        }
    }
}

impl<L: RawByteLink> Transport for NativeHostTransport<L> {
    fn send(&mut self, peer: PlayerId, bytes: &[u8]) -> EngineResult<()> {
        self.tick();
        let tag = self
            .player_to_peer
            .get(&peer)
            .ok_or_else(|| EngineError::Network(format!("jugador {peer:?} no está conectado")))?;
        self.link.send_raw(tag, bytes)
    }

    fn broadcast(&mut self, bytes: &[u8]) -> EngineResult<()> {
        self.tick();
        self.link.broadcast_raw(bytes)
    }

    fn poll_received(&mut self) -> Vec<(PlayerId, Vec<u8>)> {
        self.tick();
        self.incoming.drain(..).collect()
    }

    fn health_check(&mut self) -> EngineResult<Duration> {
        Ok(Duration::ZERO)
    }
}
