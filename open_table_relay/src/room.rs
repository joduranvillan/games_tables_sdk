// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Gestión de salas y generación de códigos legibles para `open_table_relay`.
//!
//! Administra salas públicas/privadas en memoria y asigna códigos alfanuméricos
//! de 4 caracteres sin caracteres ambiguos (`O`, `0`, `I`, `1`).

use crate::anticheat::AntiCheatSession;
use serde_json::Value;
use std::collections::HashMap;
use std::time::{Duration, Instant};
use tokio::sync::mpsc;

/// Alfabeto legible de 32 caracteres: excluye `O`, `0`, `I`, `1` para evitar confusiones visuales.
pub const ROOM_CODE_ALPHABET: &[u8; 32] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/// Longitud estándar de los códigos de sala.
pub const ROOM_CODE_LEN: usize = 4;

/// Canal de envío hacia un cliente WebSocket conectado.
pub type ClientSender = mpsc::UnboundedSender<String>;

/// Identificador único de conexión interna asignado por el servidor.
pub type ConnectionId = u64;

/// Identificador de jugador dentro de una sala (1 = host, 2..N = invitados, 0 = espectador).
pub type RoomPlayerId = u32;

/// Límite máximo de espectadores permitidos por sala.
pub const MAX_SPECTATORS_PER_ROOM: usize = 10;

/// Ventana de gracia por defecto en segundos para que un jugador desconectado se reconecte (`90`).
pub const DEFAULT_REJOIN_GRACE_SECONDS: u64 = 90;

/// Preset Blitz de tiempo por turno en segundos (`30`).
pub const TURN_TIMEOUT_BLITZ_SECS: u64 = 30;

/// Preset Rápido de tiempo por turno en segundos (`60`).
pub const TURN_TIMEOUT_RAPID_SECS: u64 = 60;

/// Preset Estándar de tiempo por turno en segundos (`120`).
pub const TURN_TIMEOUT_STANDARD_SECS: u64 = 120;

/// Preset Sin límite de tiempo por turno (`0`, permitido únicamente en salas privadas).
pub const TURN_TIMEOUT_UNLIMITED_SECS: u64 = 0;

/// Tiempo por turno fijo para partidas de matchmaking (`60` segundos).
pub const TURN_TIMEOUT_MATCHMAKING_SECS: u64 = 60;

/// Tiempo por turno por defecto al crear una sala (`120` segundos).
pub const DEFAULT_TURN_TIMEOUT_SECS: u64 = TURN_TIMEOUT_STANDARD_SECS;

/// Tiempo máximo de inactividad de una sala antes de su recolección automática (`30` minutos = `1800` segundos).
pub const DEFAULT_MAX_ROOM_IDLE_SECS: u64 = 30 * 60;

/// Intervalo en segundos del recolector periódico de salas inactivas (`60` segundos).
pub const ROOM_PRUNE_INTERVAL_SECS: u64 = 60;

/// Normaliza el tiempo por turno solicitado según si la sala es pública o privada.
///
/// - Si es `None`, aplica `120` segundos (`DEFAULT_TURN_TIMEOUT_SECS`).
/// - Si es `Some(0)` y la sala es privada (`!is_public`), permite `0` (sin límite).
/// - Si es `Some(0)` y la sala es pública (`is_public`), aplica `120` segundos.
/// - En cualquier otro caso positivo, devuelve los segundos indicados.
pub fn resolve_turn_timeout_secs(requested: Option<u64>, is_public: bool) -> u64 {
    match requested {
        None => DEFAULT_TURN_TIMEOUT_SECS,
        Some(0) => {
            if is_public {
                DEFAULT_TURN_TIMEOUT_SECS
            } else {
                TURN_TIMEOUT_UNLIMITED_SECS
            }
        }
        Some(secs) => secs,
    }
}

/// Rol de un participante dentro de una sala Relay.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ParticipantRole {
    /// Jugador activo con permisos de escritura/retransmisión.
    Player,
    /// Espectador de solo lectura (sin permisos para emitir `op: "relay"`).
    Spectator,
}

/// Estado de conexión de un participante dentro de una sala.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ParticipantConnectionState {
    /// Participante conectado activamente.
    Connected,
    /// Jugador desconectado temporalmente dentro de la ventana de gracia de reconexión.
    Disconnected {
        /// Instante en que se registró la desconexión del socket.
        since: Instant,
    },
}

pub use ParticipantConnectionState::Disconnected;

/// Información de un participante conectado o en ventana de reconexión dentro de una sala.
#[derive(Debug, Clone)]
pub struct Participant {
    /// Identificador único de la conexión.
    pub conn_id: ConnectionId,
    /// Identificador de jugador dentro de la sala (1-indexed para jugadores, 0 para espectadores).
    pub player_id: RoomPlayerId,
    /// Identificador canónico autenticado del jugador (ej. `"guest_a1b2c3d4"` o `"player1"`).
    pub authenticated_player_id: Option<String>,
    /// Rol del participante en la sala (`Player` o `Spectator`).
    pub role: ParticipantRole,
    /// Estado de conexión actual (`Connected` o `Disconnected { since }`).
    pub state: ParticipantConnectionState,
    /// Canal para enviar mensajes JSON serializados al cliente.
    pub sender: ClientSender,
}

/// Datos de estado devueltos al reconectar exitosamente un jugador con `rejoin_room`.
#[derive(Debug, Clone, PartialEq)]
pub struct RejoinOutcome {
    /// Código normalizado de la sala.
    pub room_code: String,
    /// Identificador de asiento original recuperado (`1` o `2`).
    pub player_id: RoomPlayerId,
    /// Semilla determinista de la sala.
    pub seed: u64,
    /// Lista ordenada de comandos validados aplicados hasta el momento.
    pub commands: Vec<Value>,
}

/// Resultado autoritativo listo para persistirse en `EloStore` y notificarse con `op: "elo_updated"`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthoritativeMatchOutcome {
    /// Código de la sala donde concluyó la partida.
    pub room_code: String,
    /// Identificador del juego.
    pub game_id: String,
    /// Identificador canónico del jugador ganador.
    pub winner: String,
    /// Identificador canónico del jugador perdedor.
    pub loser: String,
}

/// Resultado de validar si un cliente puede reportar manualmente el resultado con `op: "report_result"`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReportResultCheck {
    /// El reporte manual está permitido (sala sin Anti-Cheat, partida terminada no reportada o cliente fuera de sala).
    Allowed,
    /// La sala tiene una sesión Anti-Cheat activa que aún no ha finalizado (`match_not_finished`).
    MatchNotFinished,
    /// El ELO de esta sala ya fue actualizado previamente (`elo_reported == true`).
    AlreadyReported,
}

/// Representa una sala activa en el servidor Relay.
#[derive(Debug)]
pub struct Room {
    /// Código único de 4 caracteres de la sala.
    pub code: String,
    /// Identificador opcional del juego (ej. `"chess"`, `"go"`).
    pub game_id: Option<String>,
    /// Semilla determinista generada por el servidor para sincronizar dados y mazos.
    pub seed: u64,
    /// Indica si la sala es pública o privada.
    pub is_public: bool,
    /// Tiempo máximo permitido por turno en segundos (`0` = sin límite en salas privadas).
    pub turn_timeout_secs: u64,
    /// Instante en el que se registró el último movimiento válido (o inicio de partida).
    pub last_move_at: Instant,
    /// Instante en el que se registró la última actividad en la sala (creación, unión, movimiento o reconexión).
    pub last_activity_at: Instant,
    /// Asiento (`1` o `2`) que posee actualmente el turno activo.
    pub active_turn_seat: u32,
    /// Indica si el ELO de esta sala ya fue reportado y persistido (garantiza idempotencia).
    pub elo_reported: bool,
    /// Buffer ordenado de comandos validados aplicados en la partida.
    pub command_log: Vec<Value>,
    /// Contador incremental para asignar `player_id` a nuevos participantes.
    next_player_id: RoomPlayerId,
    /// Participantes activos o en ventana de gracia indexados por `ConnectionId`.
    pub participants: HashMap<ConnectionId, Participant>,
    /// Sesión autoritativa opcional para validación Anti-Cheat de los 13 juegos.
    pub anticheat: Option<AntiCheatSession>,
    /// Rating ELO opcional del anfitrión cuando la sala fue abierta mediante la cola de matchmaking.
    pub host_elo: Option<i32>,
    /// Ventana máxima de diferencia de ELO aceptada para el matchmaking en esta sala.
    pub max_elo_delta: Option<i32>,
}

impl Room {
    /// Crea una nueva sala con el anfitrión inicial (`player_id = 1`) y una semilla generada por el servidor.
    pub fn new(
        code: String,
        host_conn_id: ConnectionId,
        host_sender: ClientSender,
        game_id: Option<String>,
        is_public: bool,
    ) -> Self {
        Self::with_seed_and_timeout(
            code,
            host_conn_id,
            host_sender,
            game_id,
            is_public,
            generate_room_seed(),
            None,
        )
    }

    /// Crea una nueva sala con una semilla explícita (`seed`) para la sesión autoritativa.
    pub fn with_seed(
        code: String,
        host_conn_id: ConnectionId,
        host_sender: ClientSender,
        game_id: Option<String>,
        is_public: bool,
        seed: u64,
    ) -> Self {
        Self::with_seed_and_timeout(
            code,
            host_conn_id,
            host_sender,
            game_id,
            is_public,
            seed,
            None,
        )
    }

    /// Crea una nueva sala con semilla explícita y configuración opcional de `turn_timeout_secs`.
    pub fn with_seed_and_timeout(
        code: String,
        host_conn_id: ConnectionId,
        host_sender: ClientSender,
        game_id: Option<String>,
        is_public: bool,
        seed: u64,
        turn_timeout_secs: Option<u64>,
    ) -> Self {
        let mut participants = HashMap::new();
        participants.insert(
            host_conn_id,
            Participant {
                conn_id: host_conn_id,
                player_id: 1,
                authenticated_player_id: None,
                role: ParticipantRole::Player,
                state: ParticipantConnectionState::Connected,
                sender: host_sender,
            },
        );
        let anticheat = AntiCheatSession::for_game_with_seed(game_id.as_deref(), seed);
        let active_turn_seat = anticheat
            .as_ref()
            .map(|ac| ac.active_turn_seat())
            .unwrap_or(1);
        let now = Instant::now();
        Self {
            code,
            game_id,
            seed,
            is_public,
            turn_timeout_secs: resolve_turn_timeout_secs(turn_timeout_secs, is_public),
            last_move_at: now,
            last_activity_at: now,
            active_turn_seat,
            elo_reported: false,
            command_log: Vec::new(),
            next_player_id: 2,
            participants,
            anticheat,
            host_elo: None,
            max_elo_delta: None,
        }
    }

    /// Añade un participante jugador a la sala y devuelve el `player_id` asignado.
    pub fn add_participant(&mut self, conn_id: ConnectionId, sender: ClientSender) -> RoomPlayerId {
        if let Some(existing) = self.participants.get(&conn_id) {
            if existing.role == ParticipantRole::Player {
                return existing.player_id;
            }
        }
        let assigned_id = self.next_player_id;
        self.next_player_id += 1;
        self.participants.insert(
            conn_id,
            Participant {
                conn_id,
                player_id: assigned_id,
                authenticated_player_id: None,
                role: ParticipantRole::Player,
                state: ParticipantConnectionState::Connected,
                sender,
            },
        );
        let now = Instant::now();
        self.last_move_at = now;
        self.last_activity_at = now;
        assigned_id
    }

    /// Añade un espectador (solo lectura) a la sala y devuelve el `player_count` actual.
    /// Falla con `RoomError::SpectatorLimit` si ya hay 10 espectadores en la sala.
    pub fn add_spectator(
        &mut self,
        conn_id: ConnectionId,
        sender: ClientSender,
    ) -> Result<usize, RoomError> {
        if let Some(existing) = self.participants.get(&conn_id) {
            if existing.role == ParticipantRole::Spectator {
                return Ok(self.player_count());
            }
        }
        if self.spectator_count() >= MAX_SPECTATORS_PER_ROOM {
            return Err(RoomError::SpectatorLimit);
        }
        self.participants.insert(
            conn_id,
            Participant {
                conn_id,
                player_id: 0,
                authenticated_player_id: None,
                role: ParticipantRole::Spectator,
                state: ParticipantConnectionState::Connected,
                sender,
            },
        );
        self.last_activity_at = Instant::now();
        Ok(self.player_count())
    }

    /// Cantidad de jugadores (conectados o en ventana de reconexión) en la sala.
    pub fn player_count(&self) -> usize {
        self.participants
            .values()
            .filter(|p| p.role == ParticipantRole::Player)
            .count()
    }

    /// Cantidad de jugadores actualmente conectados en la sala.
    pub fn connected_player_count(&self) -> usize {
        self.participants
            .values()
            .filter(|p| {
                p.role == ParticipantRole::Player
                    && matches!(p.state, ParticipantConnectionState::Connected)
            })
            .count()
    }

    /// Cantidad de espectadores activos en la sala.
    pub fn spectator_count(&self) -> usize {
        self.participants
            .values()
            .filter(|p| p.role == ParticipantRole::Spectator)
            .count()
    }

    /// Elimina un participante de la sala y devuelve su `player_id` si estaba presente.
    pub fn remove_participant(&mut self, conn_id: ConnectionId) -> Option<RoomPlayerId> {
        self.participants.remove(&conn_id).map(|p| p.player_id)
    }

    /// Envía un mensaje JSON a todos los participantes conectados excepto `exclude_conn`.
    pub fn broadcast_except(&self, exclude_conn: ConnectionId, message: &str) {
        for (&cid, participant) in &self.participants {
            if cid != exclude_conn
                && matches!(participant.state, ParticipantConnectionState::Connected)
            {
                let _ = participant.sender.send(message.to_string());
            }
        }
    }

    /// Envía un mensaje JSON a todos los participantes conectados de la sala (incluyendo al emisor).
    pub fn broadcast_all(&self, message: &str) {
        for participant in self.participants.values() {
            if matches!(participant.state, ParticipantConnectionState::Connected) {
                let _ = participant.sender.send(message.to_string());
            }
        }
    }

    /// Resuelve el identificador canónico de un jugador por su `player_id` de sala (1 o 2).
    pub fn resolve_player_identity(&self, room_player_id: RoomPlayerId) -> String {
        self.participants
            .values()
            .find(|p| p.role == ParticipantRole::Player && p.player_id == room_player_id)
            .and_then(|p| p.authenticated_player_id.clone())
            .filter(|s| !s.trim().is_empty())
            .unwrap_or_else(|| format!("player{room_player_id}"))
    }

    /// Devuelve `true` si no quedan participantes en la sala.
    pub fn is_empty(&self) -> bool {
        self.participants.is_empty()
    }

    /// Devuelve `true` si no queda ningún participante en estado `Connected`.
    pub fn has_no_connected_participants(&self) -> bool {
        !self
            .participants
            .values()
            .any(|p| matches!(p.state, ParticipantConnectionState::Connected))
    }
}

/// Genera una semilla determinista de 64 bits no nula en el servidor.
pub fn generate_room_seed() -> u64 {
    let mut buf = [0u8; 8];
    if getrandom::fill(&mut buf).is_ok() {
        let val = u64::from_le_bytes(buf);
        if val != 0 {
            return val;
        }
    }
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(42)
        .max(1)
}

/// Genera un código de sala aleatorio de 4 caracteres usando [`ROOM_CODE_ALPHABET`].
pub fn generate_room_code() -> String {
    let mut buf = [0u8; ROOM_CODE_LEN];
    if getrandom::fill(&mut buf).is_err() {
        // Fallback determinista seguro en caso de fallo del generador del SO
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(0xA5A5_5A5A);
        for (i, byte) in buf.iter_mut().enumerate() {
            *byte = ((ts >> (i * 8)) & 0xFF) as u8;
        }
    }
    buf.iter()
        .map(|&b| ROOM_CODE_ALPHABET[(b as usize) % ROOM_CODE_ALPHABET.len()] as char)
        .collect()
}

/// Valida que un código de sala tenga exactamente 4 caracteres del alfabeto permitido.
pub fn is_valid_room_code(code: &str) -> bool {
    code.len() == ROOM_CODE_LEN
        && code
            .bytes()
            .all(|b| ROOM_CODE_ALPHABET.contains(&b.to_ascii_uppercase()))
}

/// Gestor central de salas activas y membresía de conexiones.
#[derive(Debug)]
pub struct RoomManager {
    /// Salas activas por código (en mayúsculas).
    rooms: HashMap<String, Room>,
    /// Mapa inverso de `ConnectionId` al código de sala en el que participa.
    conn_to_room: HashMap<ConnectionId, String>,
    /// Canales de todos los clientes WebSocket conectados (incluyendo los que aún están en el lobby).
    connected_clients: HashMap<ConnectionId, ClientSender>,
    /// Ventana de gracia máxima para reconexión (`90s` por defecto).
    rejoin_grace_duration: Duration,
}

impl Default for RoomManager {
    fn default() -> Self {
        Self {
            rooms: HashMap::new(),
            conn_to_room: HashMap::new(),
            connected_clients: HashMap::new(),
            rejoin_grace_duration: Duration::from_secs(DEFAULT_REJOIN_GRACE_SECONDS),
        }
    }
}

/// Errores posibles en las operaciones de sala.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RoomError {
    /// El código de sala solicitado no existe.
    RoomNotFound,
    /// El código de sala tiene un formato inválido.
    InvalidRoomCode,
    /// El cliente no se encuentra actualmente en ninguna sala.
    NotInRoom,
    /// El movimiento fue rechazado por el validador Anti-Cheat del motor.
    IllegalMove,
    /// Un espectador intentó enviar un mensaje `relay`.
    SpectatorCannotRelay,
    /// Se superó el límite de 10 espectadores en la sala.
    SpectatorLimit,
    /// No existe un asiento desconectado asociado al jugador en la sala indicada.
    SeatNotFound,
    /// La ventana de gracia de 90 segundos para reconectarse ha expirado.
    RejoinExpired,
}

impl RoomManager {
    /// Crea un nuevo gestor de salas vacío con ventana de gracia de 90 segundos.
    pub fn new() -> Self {
        Self::default()
    }

    /// Devuelve la duración configurada para la ventana de gracia de reconexión.
    pub fn rejoin_grace_duration(&self) -> Duration {
        self.rejoin_grace_duration
    }

    /// Configura la duración de la ventana de gracia de reconexión (útil para pruebas deterministas).
    pub fn set_rejoin_grace_duration(&mut self, duration: Duration) {
        self.rejoin_grace_duration = duration;
    }

    /// Crea una nueva sala con un código único de 4 caracteres y registra al anfitrión (`turn_timeout_secs = 120` por defecto).
    pub fn create_room(
        &mut self,
        host_conn_id: ConnectionId,
        host_sender: ClientSender,
        game_id: Option<String>,
        is_public: bool,
    ) -> String {
        self.create_room_with_timeout(host_conn_id, host_sender, game_id, is_public, None)
    }

    /// Crea una nueva sala configurando explícitamente el reloj de turno (`turn_timeout_secs`).
    pub fn create_room_with_timeout(
        &mut self,
        host_conn_id: ConnectionId,
        host_sender: ClientSender,
        game_id: Option<String>,
        is_public: bool,
        turn_timeout_secs: Option<u64>,
    ) -> String {
        // Si el cliente ya estaba en otra sala, lo sacamos primero limpiamente
        let _ = self.leave_room(host_conn_id);

        let code = loop {
            let candidate = generate_room_code();
            if !self.rooms.contains_key(&candidate) {
                break candidate;
            }
        };

        let room = Room::with_seed_and_timeout(
            code.clone(),
            host_conn_id,
            host_sender,
            game_id,
            is_public,
            generate_room_seed(),
            turn_timeout_secs,
        );
        self.rooms.insert(code.clone(), room);
        self.conn_to_room.insert(host_conn_id, code.clone());
        code
    }

    /// Empareja al jugador en una partida de matchmaking público (`turn_timeout_secs = 60`).
    ///
    /// Devuelve `(room_code, player_id_asignado, es_sala_nueva)`.
    pub fn queue_matchmaking(
        &mut self,
        conn_id: ConnectionId,
        sender: ClientSender,
        game_id: Option<String>,
    ) -> (String, RoomPlayerId, bool) {
        self.queue_matchmaking_with_elo(conn_id, sender, game_id, None, None)
    }

    /// Empareja al jugador en una partida de matchmaking público aplicando filtro de ventana ELO si se especifica.
    ///
    /// Si tanto la sala en espera como el nuevo jugador definen `elo`, verifica que
    /// `|elo_sala - elo_jugador| <= min(max_delta_sala, max_delta_jugador)` (por defecto `300`).
    pub fn queue_matchmaking_with_elo(
        &mut self,
        conn_id: ConnectionId,
        sender: ClientSender,
        game_id: Option<String>,
        elo: Option<i32>,
        max_elo_delta: Option<i32>,
    ) -> (String, RoomPlayerId, bool) {
        let _ = self.leave_room(conn_id);

        let waiting_code = self
            .rooms
            .iter()
            .find(|(_, r)| {
                if !(r.is_public
                    && !r.elo_reported
                    && r.player_count() == 1
                    && r.connected_player_count() == 1
                    && r.game_id == game_id)
                {
                    return false;
                }
                match (r.host_elo, elo) {
                    (Some(h_elo), Some(p_elo)) => {
                        let h_tol = r.max_elo_delta.unwrap_or(300).max(50);
                        let p_tol = max_elo_delta.unwrap_or(300).max(50);
                        let allowed_delta = h_tol.min(p_tol);
                        (h_elo - p_elo).abs() <= allowed_delta
                    }
                    _ => true,
                }
            })
            .map(|(c, _)| c.clone());

        if let Some(code) = waiting_code {
            if let Some(room) = self.rooms.get_mut(&code) {
                room.turn_timeout_secs = TURN_TIMEOUT_MATCHMAKING_SECS;
                let pid = room.add_participant(conn_id, sender);
                self.conn_to_room.insert(conn_id, code.clone());
                return (code, pid, false);
            }
        }

        let code = self.create_room_with_timeout(
            conn_id,
            sender,
            game_id,
            true,
            Some(TURN_TIMEOUT_MATCHMAKING_SECS),
        );
        if let Some(room) = self.rooms.get_mut(&code) {
            room.host_elo = elo;
            room.max_elo_delta = max_elo_delta;
        }
        (code, 1, true)
    }

    /// Une un cliente a una sala existente por su código.
    ///
    /// Devuelve `(room_code_normalizado, player_id_asignado)`.
    pub fn join_room(
        &mut self,
        conn_id: ConnectionId,
        sender: ClientSender,
        raw_code: &str,
    ) -> Result<(String, RoomPlayerId), RoomError> {
        let normalized = raw_code.trim().to_ascii_uppercase();
        if !is_valid_room_code(&normalized) {
            return Err(RoomError::InvalidRoomCode);
        }

        if !self.rooms.contains_key(&normalized) {
            return Err(RoomError::RoomNotFound);
        }

        // Si estaba en otra sala distinta, salir primero
        if let Some(prev_code) = self.conn_to_room.get(&conn_id) {
            if prev_code != &normalized {
                let _ = self.leave_room(conn_id);
            }
        }

        let room = self
            .rooms
            .get_mut(&normalized)
            .ok_or(RoomError::RoomNotFound)?;
        let player_id = room.add_participant(conn_id, sender);
        self.conn_to_room.insert(conn_id, normalized.clone());

        Ok((normalized, player_id))
    }

    /// Une un cliente como espectador de solo lectura a una sala existente por su código.
    ///
    /// Devuelve `(room_code_normalizado, player_count)`.
    pub fn join_spectator(
        &mut self,
        conn_id: ConnectionId,
        sender: ClientSender,
        raw_code: &str,
    ) -> Result<(String, usize), RoomError> {
        let normalized = raw_code.trim().to_ascii_uppercase();
        if !is_valid_room_code(&normalized) {
            return Err(RoomError::InvalidRoomCode);
        }

        if !self.rooms.contains_key(&normalized) {
            return Err(RoomError::RoomNotFound);
        }

        if let Some(prev_code) = self.conn_to_room.get(&conn_id) {
            if prev_code != &normalized {
                let _ = self.leave_room(conn_id);
            }
        }

        let room = self
            .rooms
            .get_mut(&normalized)
            .ok_or(RoomError::RoomNotFound)?;
        let player_count = room.add_spectator(conn_id, sender)?;
        self.conn_to_room.insert(conn_id, normalized.clone());

        Ok((normalized, player_count))
    }

    /// Retransmite un mensaje JSON a los demás miembros de la sala donde está `conn_id`.
    ///
    /// Devuelve el `(room_code, player_id)` del emisor.
    pub fn relay_to_peers(
        &self,
        conn_id: ConnectionId,
        outbound_json: &str,
    ) -> Result<(String, RoomPlayerId), RoomError> {
        let code = self
            .conn_to_room
            .get(&conn_id)
            .ok_or(RoomError::NotInRoom)?;
        let room = self.rooms.get(code).ok_or(RoomError::RoomNotFound)?;
        let participant = room
            .participants
            .get(&conn_id)
            .ok_or(RoomError::NotInRoom)?;
        if participant.role == ParticipantRole::Spectator {
            return Err(RoomError::SpectatorCannotRelay);
        }
        let sender_player_id = participant.player_id;

        room.broadcast_except(conn_id, outbound_json);
        Ok((code.clone(), sender_player_id))
    }

    /// Valida el payload con `AntiCheatSession` (si aplica a la sala), registra el comando en `command_log`
    /// y retransmite a los demás participantes conectados.
    pub fn validate_and_relay(
        &mut self,
        conn_id: ConnectionId,
        payload: &Value,
        outbound_json: &str,
    ) -> Result<(String, RoomPlayerId), RoomError> {
        let code = self
            .conn_to_room
            .get(&conn_id)
            .cloned()
            .ok_or(RoomError::NotInRoom)?;
        let room = self.rooms.get_mut(&code).ok_or(RoomError::RoomNotFound)?;
        let participant = room
            .participants
            .get(&conn_id)
            .ok_or(RoomError::NotInRoom)?;
        if participant.role == ParticipantRole::Spectator {
            return Err(RoomError::SpectatorCannotRelay);
        }
        let sender_player_id = participant.player_id;

        let now = Instant::now();
        if let Some(ac) = room.anticheat.as_mut() {
            let is_control = AntiCheatSession::is_control_or_sync_payload(payload);
            if ac.validate_and_apply(sender_player_id, payload).is_err() {
                return Err(RoomError::IllegalMove);
            }
            if !is_control {
                room.active_turn_seat = ac.active_turn_seat();
                room.last_move_at = now;
                room.command_log.push(payload.clone());
            }
        } else {
            room.active_turn_seat = if sender_player_id == 1 { 2 } else { 1 };
            room.last_move_at = now;
            room.command_log.push(payload.clone());
        }

        room.last_activity_at = now;
        room.broadcast_except(conn_id, outbound_json);
        Ok((code, sender_player_id))
    }

    /// Devuelve el `turn_timeout_secs` configurado para una sala activa.
    pub fn room_turn_timeout_secs(&self, raw_code: &str) -> Option<u64> {
        let normalized = raw_code.trim().to_ascii_uppercase();
        self.rooms.get(&normalized).map(|r| r.turn_timeout_secs)
    }

    /// Obtiene el `player_id` y código de sala de un cliente conectado.
    pub fn participant_info(&self, conn_id: ConnectionId) -> Option<(String, RoomPlayerId)> {
        let code = self.conn_to_room.get(&conn_id)?;
        let room = self.rooms.get(code)?;
        let participant = room.participants.get(&conn_id)?;
        Some((code.clone(), participant.player_id))
    }

    /// Devuelve la semilla (`seed`) de una sala activa por su código.
    pub fn room_seed(&self, raw_code: &str) -> Option<u64> {
        let normalized = raw_code.trim().to_ascii_uppercase();
        self.rooms.get(&normalized).map(|r| r.seed)
    }

    /// Devuelve el ganador autoritativo (`AntiCheatSession::winner`) de una sala si la partida ha terminado.
    pub fn room_winner(&self, raw_code: &str) -> Option<open_table_core::ids::PlayerId> {
        let normalized = raw_code.trim().to_ascii_uppercase();
        self.rooms
            .get(&normalized)
            .and_then(|r| r.anticheat.as_ref())
            .and_then(|ac| ac.winner())
    }

    /// Asocia el `authenticated_player_id` canónico al participante conectado en su sala actual.
    pub fn set_authenticated_player_id(
        &mut self,
        conn_id: ConnectionId,
        authenticated_id: Option<String>,
    ) {
        let Some(code) = self.conn_to_room.get(&conn_id).cloned() else {
            return;
        };
        if let Some(room) = self.rooms.get_mut(&code) {
            if let Some(participant) = room.participants.get_mut(&conn_id) {
                participant.authenticated_player_id = authenticated_id;
            }
        }
    }

    /// Si la `AntiCheatSession` de la sala donde está `conn_id` ya tiene un ganador y aún no se ha
    /// reportado el ELO (`elo_reported == false`), marca `elo_reported = true` y devuelve el resultado.
    pub fn claim_authoritative_outcome(
        &mut self,
        conn_id: ConnectionId,
    ) -> Option<AuthoritativeMatchOutcome> {
        let code = self.conn_to_room.get(&conn_id)?.clone();
        let room = self.rooms.get_mut(&code)?;
        if room.elo_reported {
            return None;
        }
        let winner_pid = room.anticheat.as_ref()?.winner()?.0;
        let loser_pid = if winner_pid == 1 { 2 } else { 1 };
        let game_id = room
            .anticheat
            .as_ref()
            .map(|ac| ac.game_id().to_string())
            .or_else(|| room.game_id.clone())
            .unwrap_or_else(|| "chess".to_string());
        let winner = room.resolve_player_identity(winner_pid);
        let loser = room.resolve_player_identity(loser_pid);
        room.elo_reported = true;
        Some(AuthoritativeMatchOutcome {
            room_code: code,
            game_id,
            winner,
            loser,
        })
    }

    /// Procesa la rendición (`op: "resign"`) del participante `conn_id`, adjudicando la victoria al oponente.
    /// Garantiza idempotencia: si `elo_reported` ya era `true`, devuelve `Ok(None)`.
    pub fn resign(
        &mut self,
        conn_id: ConnectionId,
    ) -> Result<Option<AuthoritativeMatchOutcome>, RoomError> {
        let code = self
            .conn_to_room
            .get(&conn_id)
            .cloned()
            .ok_or(RoomError::NotInRoom)?;
        let room = self.rooms.get_mut(&code).ok_or(RoomError::RoomNotFound)?;
        let participant = room
            .participants
            .get(&conn_id)
            .ok_or(RoomError::NotInRoom)?;
        if participant.role == ParticipantRole::Spectator {
            return Err(RoomError::SpectatorCannotRelay);
        }
        let resigning_pid = participant.player_id;

        if room.elo_reported {
            return Ok(None);
        }

        let winner_pid = if let Some(ac) = room.anticheat.as_mut() {
            ac.force_resign(resigning_pid).0
        } else if resigning_pid == 1 {
            2
        } else {
            1
        };

        let game_id = room
            .anticheat
            .as_ref()
            .map(|ac| ac.game_id().to_string())
            .or_else(|| room.game_id.clone())
            .unwrap_or_else(|| "chess".to_string());
        let winner = room.resolve_player_identity(winner_pid);
        let loser = room.resolve_player_identity(resigning_pid);
        room.elo_reported = true;
        room.last_activity_at = Instant::now();

        Ok(Some(AuthoritativeMatchOutcome {
            room_code: code,
            game_id,
            winner,
            loser,
        }))
    }

    /// Valida si un cliente puede reportar manualmente un resultado (`op: "report_result"`).
    ///
    /// - Si la sala tiene `AntiCheatSession` activa y aún no ha finalizado, devuelve `MatchNotFinished`.
    /// - Si la sala ya reportó su ELO (`elo_reported == true`), devuelve `AlreadyReported`.
    /// - En caso contrario, marca `elo_reported = true` (si está en sala) y devuelve `Allowed`.
    pub fn check_manual_report_result(&mut self, conn_id: ConnectionId) -> ReportResultCheck {
        let Some(code) = self.conn_to_room.get(&conn_id).cloned() else {
            return ReportResultCheck::Allowed;
        };
        let Some(room) = self.rooms.get_mut(&code) else {
            return ReportResultCheck::Allowed;
        };
        if room
            .participants
            .get(&conn_id)
            .is_some_and(|p| p.role == ParticipantRole::Spectator)
        {
            return ReportResultCheck::MatchNotFinished;
        }
        if room.elo_reported {
            return ReportResultCheck::AlreadyReported;
        }
        if let Some(ac) = room.anticheat.as_ref() {
            if ac.winner().is_none() {
                return ReportResultCheck::MatchNotFinished;
            }
        }
        room.elo_reported = true;
        room.last_activity_at = Instant::now();
        ReportResultCheck::Allowed
    }

    /// Registra un canal de cliente conectado para notificaciones globales (ej. `server_shutting_down`).
    pub fn register_client(&mut self, conn_id: ConnectionId, sender: ClientSender) {
        self.connected_clients.insert(conn_id, sender);
    }

    /// Elimina el canal de un cliente al cerrarse su conexión WebSocket.
    pub fn unregister_client(&mut self, conn_id: ConnectionId) {
        self.connected_clients.remove(&conn_id);
    }

    /// Envía un mensaje JSON a todos los miembros de la sala `raw_code`.
    pub fn broadcast_to_room(&self, raw_code: &str, message: &str) {
        let normalized = raw_code.trim().to_ascii_uppercase();
        if let Some(room) = self.rooms.get(&normalized) {
            room.broadcast_all(message);
        }
    }

    /// Envía un mensaje JSON a todos los clientes conectados al servidor (en salas o en el lobby).
    pub fn broadcast_all_rooms(&self, message: &str) {
        for sender in self.connected_clients.values() {
            let _ = sender.send(message.to_string());
        }
        for room in self.rooms.values() {
            for (&cid, participant) in &room.participants {
                if !self.connected_clients.contains_key(&cid)
                    && matches!(participant.state, ParticipantConnectionState::Connected)
                {
                    let _ = participant.sender.send(message.to_string());
                }
            }
        }
    }

    /// Marca el asiento de un jugador como `Disconnected { since: Instant::now() }` al cerrarse su socket
    /// sin destruir la sala, y notifica al rival `{"op": "opponent_disconnected", "grace_seconds": 90}`.
    pub fn disconnect_participant(
        &mut self,
        conn_id: ConnectionId,
    ) -> Option<(String, RoomPlayerId)> {
        let code = self.conn_to_room.remove(&conn_id)?;
        let grace_secs = self.rejoin_grace_duration.as_secs().max(1);
        let mut should_remove_room = false;
        let mut disconnected_player_id = None;

        if let Some(room) = self.rooms.get_mut(&code) {
            let role_and_pid = room
                .participants
                .get(&conn_id)
                .map(|p| (p.role, p.player_id));
            match role_and_pid {
                Some((ParticipantRole::Spectator, _)) => {
                    room.remove_participant(conn_id);
                    should_remove_room = room.is_empty();
                }
                Some((ParticipantRole::Player, pid)) => {
                    let now = Instant::now();
                    if let Some(participant) = room.participants.get_mut(&conn_id) {
                        participant.state = Disconnected { since: now };
                    }
                    room.last_activity_at = now;
                    disconnected_player_id = Some(pid);
                    let notice = serde_json::json!({
                        "op": "opponent_disconnected",
                        "grace_seconds": grace_secs,
                    })
                    .to_string();
                    room.broadcast_except(conn_id, &notice);
                    if self.rejoin_grace_duration.is_zero() && room.has_no_connected_participants()
                    {
                        should_remove_room = true;
                    }
                }
                None => {}
            }
        }

        if should_remove_room {
            self.rooms.remove(&code);
        }

        disconnected_player_id.map(|pid| (code, pid))
    }

    /// Permite a un jugador desconectado recuperar su asiento original (`1` o `2`) antes de que
    /// expire la ventana de gracia (90 segundos), devolviendo la semilla y el `command_log` acumulado.
    pub fn rejoin_room(
        &mut self,
        conn_id: ConnectionId,
        sender: ClientSender,
        raw_code: &str,
        authenticated_player_id: Option<&str>,
    ) -> Result<RejoinOutcome, RoomError> {
        let normalized = raw_code.trim().to_ascii_uppercase();
        if !is_valid_room_code(&normalized) {
            return Err(RoomError::InvalidRoomCode);
        }

        if let Some(prev_code) = self.conn_to_room.get(&conn_id).cloned() {
            if prev_code != normalized {
                let _ = self.leave_room(conn_id);
            }
        }

        let grace = self.rejoin_grace_duration;
        let room = self
            .rooms
            .get_mut(&normalized)
            .ok_or(RoomError::RoomNotFound)?;

        let req_id = authenticated_player_id
            .map(str::trim)
            .filter(|s| !s.is_empty());

        let mut matched_conn: Option<(ConnectionId, Participant)> = None;

        // 1. Buscar asiento desconectado cuyo authenticated_player_id o alias ("player1"/"player2") coincida
        let mut candidates: Vec<(ConnectionId, Participant)> = room
            .participants
            .iter()
            .filter(|(_, p)| p.role == ParticipantRole::Player)
            .map(|(&cid, p)| (cid, p.clone()))
            .collect();
        candidates.sort_by_key(|(_, p)| p.player_id);

        if let Some(target_id) = req_id {
            for (cid, p) in &candidates {
                let is_disconnected = matches!(p.state, Disconnected { .. });
                let exact_match = p.authenticated_player_id.as_deref() == Some(target_id);
                let fallback_match = p.authenticated_player_id.is_none()
                    && (target_id == format!("player{}", p.player_id)
                        || target_id == p.player_id.to_string());
                if is_disconnected && (exact_match || fallback_match) {
                    matched_conn = Some((*cid, p.clone()));
                    break;
                }
            }
            // Si el asiento se desconectó antes de asociar authenticated_player_id, enlazar al asiento desconectado libre
            if matched_conn.is_none() {
                for (cid, p) in &candidates {
                    if matches!(p.state, Disconnected { .. }) && p.authenticated_player_id.is_none()
                    {
                        matched_conn = Some((*cid, p.clone()));
                        break;
                    }
                }
            }
            // Reconexión rápida antes de que el socket previo notificara cierre TCP
            if matched_conn.is_none() {
                for (cid, p) in &candidates {
                    if p.authenticated_player_id.as_deref() == Some(target_id) {
                        matched_conn = Some((*cid, p.clone()));
                        break;
                    }
                }
            }
        } else {
            for (cid, p) in &candidates {
                if matches!(p.state, Disconnected { .. }) {
                    matched_conn = Some((*cid, p.clone()));
                    break;
                }
            }
        }

        let Some((old_conn_id, prev_participant)) = matched_conn else {
            return Err(RoomError::SeatNotFound);
        };

        if let Disconnected { since } = prev_participant.state {
            if since.elapsed() > grace {
                return Err(RoomError::RejoinExpired);
            }
        }

        room.participants.remove(&old_conn_id);
        self.conn_to_room.remove(&old_conn_id);

        let resolved_auth = prev_participant
            .authenticated_player_id
            .or_else(|| req_id.map(str::to_string));

        let recovered_player_id = prev_participant.player_id;
        room.participants.insert(
            conn_id,
            Participant {
                conn_id,
                player_id: recovered_player_id,
                authenticated_player_id: resolved_auth,
                role: ParticipantRole::Player,
                state: ParticipantConnectionState::Connected,
                sender,
            },
        );
        room.last_activity_at = Instant::now();
        self.conn_to_room.insert(conn_id, normalized.clone());

        let notice = serde_json::json!({
            "op": "opponent_reconnected",
        })
        .to_string();
        room.broadcast_except(conn_id, &notice);

        Ok(RejoinOutcome {
            room_code: normalized,
            player_id: recovered_player_id,
            seed: room.seed,
            commands: room.command_log.clone(),
        })
    }

    /// Elimina automáticamente todas las salas cuya última actividad (`last_activity_at`) supere `max_idle`
    /// (por defecto 30 minutos en el recolector periódico) y limpia el índice inverso `conn_to_room`.
    ///
    /// Devuelve la cantidad de salas inactivas eliminadas.
    pub fn prune_stale_rooms(&mut self, max_idle: Duration) -> usize {
        let stale_codes: Vec<String> = self
            .rooms
            .iter()
            .filter_map(|(code, room)| {
                if room.last_activity_at.elapsed() >= max_idle {
                    Some(code.clone())
                } else {
                    None
                }
            })
            .collect();

        let removed_count = stale_codes.len();
        for code in stale_codes {
            if let Some(room) = self.rooms.remove(&code) {
                for cid in room.participants.keys() {
                    self.conn_to_room.remove(cid);
                }
            }
        }

        self.conn_to_room
            .retain(|_, room_code| self.rooms.contains_key(room_code));

        removed_count
    }

    /// Verifica todos los asientos desconectados cuyo tiempo en `Disconnected { since }` haya
    /// alcanzado o superado la ventana de gracia (`90s` por defecto).
    ///
    /// Si expiran los 90 segundos sin reconexión, el jugador conectado gana por abandono.
    pub fn expire_disconnected_seats(&mut self) -> Vec<AuthoritativeMatchOutcome> {
        let grace = self.rejoin_grace_duration;
        let mut outcomes = Vec::new();
        let mut empty_rooms = Vec::new();

        for (code, room) in &mut self.rooms {
            let mut expired_conns: Vec<(ConnectionId, RoomPlayerId)> = room
                .participants
                .values()
                .filter_map(|p| match p.state {
                    Disconnected { since }
                        if p.role == ParticipantRole::Player && since.elapsed() >= grace =>
                    {
                        Some((p.conn_id, p.player_id))
                    }
                    _ => None,
                })
                .collect();
            expired_conns.sort_by_key(|(_, pid)| *pid);

            if expired_conns.is_empty() {
                continue;
            }

            let connected_player = room
                .participants
                .values()
                .find(|p| {
                    p.role == ParticipantRole::Player
                        && matches!(p.state, ParticipantConnectionState::Connected)
                })
                .map(|p| p.player_id);

            if !room.elo_reported {
                if let Some(winner_pid) = connected_player {
                    let loser_pid = expired_conns
                        .iter()
                        .map(|(_, pid)| *pid)
                        .find(|&pid| pid != winner_pid)
                        .unwrap_or(if winner_pid == 1 { 2 } else { 1 });

                    if let Some(ac) = room.anticheat.as_mut() {
                        ac.force_resign(loser_pid);
                    }

                    let game_id = room
                        .anticheat
                        .as_ref()
                        .map(|ac| ac.game_id().to_string())
                        .or_else(|| room.game_id.clone())
                        .unwrap_or_else(|| "chess".to_string());
                    let winner = room.resolve_player_identity(winner_pid);
                    let loser = room.resolve_player_identity(loser_pid);
                    room.elo_reported = true;

                    outcomes.push(AuthoritativeMatchOutcome {
                        room_code: code.clone(),
                        game_id,
                        winner,
                        loser,
                    });
                }
            }

            for (exp_cid, _) in expired_conns {
                room.participants.remove(&exp_cid);
                self.conn_to_room.remove(&exp_cid);
            }

            if room.has_no_connected_participants() {
                empty_rooms.push(code.clone());
            }
        }

        for code in empty_rooms {
            self.rooms.remove(&code);
        }

        outcomes
    }

    /// Verifica todas las salas activas con al menos 2 jugadores cuyo reloj de turno (`turn_timeout_secs > 0`)
    /// haya sido superado sin recibir un movimiento válido (`last_move_at.elapsed() >= turn_timeout_secs`).
    ///
    /// Declara ganador al oponente del jugador en turno (`active_turn_seat`), emite
    /// `{"op": "match_timeout", "winner_seat": ..., "reason": "turn_timeout"}` a la sala y devuelve
    /// los `AuthoritativeMatchOutcome` para actualizar ELO.
    pub fn expire_turn_timeouts(&mut self) -> Vec<AuthoritativeMatchOutcome> {
        let mut outcomes = Vec::new();

        for (code, room) in &mut self.rooms {
            if room.elo_reported || room.turn_timeout_secs == 0 || room.player_count() < 2 {
                continue;
            }
            if room.last_move_at.elapsed() < Duration::from_secs(room.turn_timeout_secs) {
                continue;
            }

            let timed_out_seat = room.active_turn_seat;
            let winner_seat = if timed_out_seat == 1 { 2 } else { 1 };

            if let Some(ac) = room.anticheat.as_mut() {
                ac.force_resign(timed_out_seat);
            }

            let game_id = room
                .anticheat
                .as_ref()
                .map(|ac| ac.game_id().to_string())
                .or_else(|| room.game_id.clone())
                .unwrap_or_else(|| "chess".to_string());
            let winner = room.resolve_player_identity(winner_seat);
            let loser = room.resolve_player_identity(timed_out_seat);
            room.elo_reported = true;

            let timeout_notice = serde_json::json!({
                "op": "match_timeout",
                "winner_seat": winner_seat,
                "reason": "turn_timeout",
            })
            .to_string();
            room.broadcast_all(&timeout_notice);

            outcomes.push(AuthoritativeMatchOutcome {
                room_code: code.clone(),
                game_id,
                winner,
                loser,
            });
        }

        outcomes
    }

    /// Retira a un cliente de su sala actual (por `{"op": "leave"}` voluntario)
    /// y notifica a los participantes restantes.
    ///
    /// Si la sala queda sin participantes conectados, se elimina de memoria automáticamente.
    pub fn leave_room(&mut self, conn_id: ConnectionId) -> Option<(String, RoomPlayerId)> {
        let code = self.conn_to_room.remove(&conn_id)?;
        let mut should_remove_room = false;
        let mut removed_player_id = None;

        if let Some(room) = self.rooms.get_mut(&code) {
            if let Some(pid) = room.remove_participant(conn_id) {
                removed_player_id = Some(pid);
                if pid > 0 {
                    let notification = serde_json::json!({
                        "op": "peer_left",
                        "room_code": code,
                        "player_id": pid,
                    })
                    .to_string();
                    room.broadcast_except(conn_id, &notification);
                }
            }
            should_remove_room = room.has_no_connected_participants();
        }

        if should_remove_room {
            self.rooms.remove(&code);
        }

        removed_player_id.map(|pid| (code, pid))
    }

    /// Cantidad de salas activas actualmente.
    pub fn active_room_count(&self) -> usize {
        self.rooms.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_room_code_generation_format_and_no_ambiguous_chars() {
        for _ in 0..200 {
            let code = generate_room_code();
            assert_eq!(code.len(), 4);
            assert!(is_valid_room_code(&code));
            assert!(!code.contains('O'));
            assert!(!code.contains('0'));
            assert!(!code.contains('I'));
            assert!(!code.contains('1'));
        }
    }

    #[test]
    fn test_room_lifecycle_create_join_relay_leave() {
        let mut manager = RoomManager::new();
        let (tx1, mut rx1) = mpsc::unbounded_channel();
        let (tx2, mut rx2) = mpsc::unbounded_channel();

        let code = manager.create_room(100, tx1, Some("chess".to_string()), true);
        assert_eq!(manager.active_room_count(), 1);

        let (joined_code, player_id) = manager.join_room(200, tx2, &code).unwrap();
        assert_eq!(joined_code, code);
        assert_eq!(player_id, 2);

        // Cliente 1 envía relay -> solo Cliente 2 lo recibe
        manager
            .relay_to_peers(100, r#"{"op":"relay","data":"e2e4"}"#)
            .unwrap();
        assert_eq!(rx2.try_recv().unwrap(), r#"{"op":"relay","data":"e2e4"}"#);
        assert!(rx1.try_recv().is_err());

        // Cliente 2 abandona la sala -> Cliente 1 recibe notificación peer_left
        let (_, left_pid) = manager.leave_room(200).unwrap();
        assert_eq!(left_pid, 2);
        let msg = rx1.try_recv().unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&msg).unwrap();
        assert_eq!(parsed["op"], "peer_left");
        assert_eq!(parsed["player_id"], 2);
        assert_eq!(manager.active_room_count(), 1);

        // Cliente 1 abandona -> la sala se elimina por quedar vacía
        manager.leave_room(100);
        assert_eq!(manager.active_room_count(), 0);
    }

    #[test]
    fn test_room_spectator_join_relay_and_limit() {
        let mut manager = RoomManager::new();
        let (tx_host, _rx_host) = mpsc::unbounded_channel();
        let (tx_guest, _rx_guest) = mpsc::unbounded_channel();

        let code = manager.create_room(1, tx_host, Some("chess".to_string()), true);
        let (_, guest_pid) = manager.join_room(2, tx_guest, &code).unwrap();
        assert_eq!(guest_pid, 2);

        // Unir hasta 10 espectadores
        let mut spec_rxs = Vec::new();
        for i in 0..MAX_SPECTATORS_PER_ROOM {
            let (tx_spec, rx_spec) = mpsc::unbounded_channel();
            let conn_id = 1000 + (i as u64);
            let (joined_code, player_count) =
                manager.join_spectator(conn_id, tx_spec, &code).unwrap();
            assert_eq!(joined_code, code);
            assert_eq!(player_count, 2);
            spec_rxs.push(rx_spec);
        }

        // El 11.º espectador supera el límite de 10 y recibe SpectatorLimit
        let (tx_spec_overflow, _rx_spec_overflow) = mpsc::unbounded_channel();
        let overflow_res = manager.join_spectator(2000, tx_spec_overflow, &code);
        assert_eq!(overflow_res, Err(RoomError::SpectatorLimit));

        // El host envía relay -> los espectadores lo reciben
        manager
            .relay_to_peers(1, r#"{"op":"relay","data":"e2e4"}"#)
            .unwrap();
        for rx_spec in &mut spec_rxs {
            assert_eq!(
                rx_spec.try_recv().unwrap(),
                r#"{"op":"relay","data":"e2e4"}"#
            );
        }

        // Un espectador intenta hacer relay -> recibe SpectatorCannotRelay
        let illegal_msg = r#"{"op":"relay","data":"illegal"}"#;
        let spec_relay_res = manager.relay_to_peers(1000, illegal_msg);
        assert_eq!(spec_relay_res, Err(RoomError::SpectatorCannotRelay));
    }

    #[test]
    fn test_room_elo_autoverify_gameover_and_idempotency() {
        let mut manager = RoomManager::new();
        let (tx_host, _rx_host) = mpsc::unbounded_channel();
        let (tx_guest, _rx_guest) = mpsc::unbounded_channel();

        let code = manager.create_room(10, tx_host, Some("chess".to_string()), true);
        manager.set_authenticated_player_id(10, Some("guest_11111111".to_string()));
        manager.join_room(20, tx_guest, &code).unwrap();
        manager.set_authenticated_player_id(20, Some("guest_22222222".to_string()));

        // Antes de terminar la partida, report_result manual es rechazado con MatchNotFinished
        assert_eq!(
            manager.check_manual_report_result(10),
            ReportResultCheck::MatchNotFinished
        );

        // Movimiento de rendición válido dentro del motor autoritativo de Ajedrez
        let resign_payload = serde_json::json!({
            "player": 1,
            "resign": true
        });
        manager
            .validate_and_relay(10, &resign_payload, r#"{"op":"relay"}"#)
            .unwrap();

        let outcome = manager.claim_authoritative_outcome(10).unwrap();
        assert_eq!(outcome.game_id, "chess");
        assert_eq!(outcome.winner, "guest_22222222");
        assert_eq!(outcome.loser, "guest_11111111");

        // Idempotencia: una segunda llamada a claim_authoritative_outcome o resign devuelve None
        assert!(manager.claim_authoritative_outcome(10).is_none());
        assert_eq!(manager.resign(10).unwrap(), None);
        assert_eq!(
            manager.check_manual_report_result(10),
            ReportResultCheck::AlreadyReported
        );
    }

    #[test]
    fn test_room_rejoin_within_grace_window_and_command_log() {
        let mut manager = RoomManager::new();
        let (tx_host, mut rx_host) = mpsc::unbounded_channel();
        let (tx_guest, _rx_guest) = mpsc::unbounded_channel();

        let code = manager.create_room(10, tx_host, Some("chess".to_string()), true);
        let seed = manager.room_seed(&code).unwrap();
        manager.set_authenticated_player_id(10, Some("guest_11111111".to_string()));
        manager.join_room(20, tx_guest, &code).unwrap();
        manager.set_authenticated_player_id(20, Some("guest_22222222".to_string()));

        // Aplicar jugada válida de P1 (e2 -> e4)
        let move_1 = serde_json::json!({
            "player": 1,
            "from": { "row": 1, "col": 4 },
            "to": { "row": 3, "col": 4 }
        });
        manager
            .validate_and_relay(10, &move_1, r#"{"op":"relay"}"#)
            .unwrap();

        // Guest (conn 20, player_id 2) se desconecta accidentalmente
        let (_, disc_pid) = manager.disconnect_participant(20).unwrap();
        assert_eq!(disc_pid, 2);

        // Host recibe {"op": "opponent_disconnected", "grace_seconds": 90}
        let disc_msg: Value = serde_json::from_str(&rx_host.try_recv().unwrap()).unwrap();
        assert_eq!(disc_msg["op"], "opponent_disconnected");
        assert_eq!(disc_msg["grace_seconds"], 90);

        // Guest se reconecta con nuevo conn_id = 30 antes de 90s y recupera asiento 2 + command_log
        let (tx_rejoin, _rx_rejoin) = mpsc::unbounded_channel();
        let rejoin_outcome = manager
            .rejoin_room(30, tx_rejoin, &code, Some("guest_22222222"))
            .unwrap();
        assert_eq!(rejoin_outcome.room_code, code);
        assert_eq!(rejoin_outcome.player_id, 2);
        assert_eq!(rejoin_outcome.seed, seed);
        assert_eq!(rejoin_outcome.commands.len(), 1);
        assert_eq!(rejoin_outcome.commands[0], move_1);

        // Host recibe {"op": "opponent_reconnected"}
        let reconn_msg: Value = serde_json::from_str(&rx_host.try_recv().unwrap()).unwrap();
        assert_eq!(reconn_msg["op"], "opponent_reconnected");

        // Guest puede enviar su jugada del turno 2 desde la nueva conexión 30
        let move_2 = serde_json::json!({
            "player": 2,
            "from": { "row": 6, "col": 4 },
            "to": { "row": 4, "col": 4 }
        });
        manager
            .validate_and_relay(30, &move_2, r#"{"op":"relay"}"#)
            .unwrap();
    }

    #[test]
    fn test_room_rejoin_expired_awards_abandonment_victory() {
        let mut manager = RoomManager::new();
        manager.set_rejoin_grace_duration(Duration::from_millis(10));

        let (tx_host, _rx_host) = mpsc::unbounded_channel();
        let (tx_guest, _rx_guest) = mpsc::unbounded_channel();

        let code = manager.create_room(10, tx_host, Some("chess".to_string()), true);
        manager.set_authenticated_player_id(10, Some("guest_host_win".to_string()));
        manager.join_room(20, tx_guest, &code).unwrap();
        manager.set_authenticated_player_id(20, Some("guest_drop_lose".to_string()));

        manager.disconnect_participant(20).unwrap();
        std::thread::sleep(Duration::from_millis(20));

        // Intentar rejoin tras expirar la ventana de gracia falla con RejoinExpired
        let (tx_late, _rx_late) = mpsc::unbounded_channel();
        assert_eq!(
            manager.rejoin_room(30, tx_late, &code, Some("guest_drop_lose")),
            Err(RoomError::RejoinExpired)
        );

        // Expirar asientos adjudica la victoria por abandono al jugador conectado
        let outcomes = manager.expire_disconnected_seats();
        assert_eq!(outcomes.len(), 1);
        assert_eq!(outcomes[0].room_code, code);
        assert_eq!(outcomes[0].winner, "guest_host_win");
        assert_eq!(outcomes[0].loser, "guest_drop_lose");
    }

    #[test]
    fn test_room_turn_timeout_presets_and_matchmaking_queue() {
        let mut manager = RoomManager::new();
        let (tx1, _rx1) = mpsc::unbounded_channel();
        let (tx2, _rx2) = mpsc::unbounded_channel();
        let (tx3, _rx3) = mpsc::unbounded_channel();
        let (tx4, _rx4) = mpsc::unbounded_channel();
        let (tx5, _rx5) = mpsc::unbounded_channel();
        let (tx6, _rx6) = mpsc::unbounded_channel();

        // Por defecto = 120s Estándar
        let c_default = manager.create_room(1, tx1, Some("chess".to_string()), true);
        assert_eq!(manager.room_turn_timeout_secs(&c_default), Some(120));

        // Preset Blitz = 30s
        let c_blitz =
            manager.create_room_with_timeout(2, tx2, Some("chess".to_string()), true, Some(30));
        assert_eq!(manager.room_turn_timeout_secs(&c_blitz), Some(30));

        // Preset Sin límite (0s) en sala privada (!is_public)
        let c_priv =
            manager.create_room_with_timeout(3, tx3, Some("chess".to_string()), false, Some(0));
        assert_eq!(manager.room_turn_timeout_secs(&c_priv), Some(0));

        // 0s en sala pública se normaliza a 120s
        let c_pub_zero =
            manager.create_room_with_timeout(4, tx4, Some("chess".to_string()), true, Some(0));
        assert_eq!(manager.room_turn_timeout_secs(&c_pub_zero), Some(120));

        // Matchmaking (queue) fija turn_timeout_secs = 60
        let (q_code, q_pid, is_new) = manager.queue_matchmaking(5, tx5, Some("go".to_string()));
        assert!(is_new);
        assert_eq!(q_pid, 1);
        assert_eq!(manager.room_turn_timeout_secs(&q_code), Some(60));

        let (q_code_2, q_pid_2, is_new_2) =
            manager.queue_matchmaking(6, tx6, Some("go".to_string()));
        assert!(!is_new_2);
        assert_eq!(q_code_2, q_code);
        assert_eq!(q_pid_2, 2);
        assert_eq!(manager.room_turn_timeout_secs(&q_code), Some(60));
    }

    #[test]
    fn test_room_turn_timeout_awards_victory_and_emits_match_timeout() {
        let mut manager = RoomManager::new();
        let (tx_host, mut rx_host) = mpsc::unbounded_channel();
        let (tx_guest, mut rx_guest) = mpsc::unbounded_channel();

        let code =
            manager.create_room_with_timeout(10, tx_host, Some("chess".to_string()), true, Some(1));
        manager.set_authenticated_player_id(10, Some("guest_p1".to_string()));
        manager.join_room(20, tx_guest, &code).unwrap();
        manager.set_authenticated_player_id(20, Some("guest_p2".to_string()));

        // P1 realiza un movimiento válido (e2 -> e4); ahora el turno activo pasa al asiento 2
        let move_1 = serde_json::json!({
            "player": 1,
            "from": { "row": 1, "col": 4 },
            "to": { "row": 3, "col": 4 }
        });
        manager
            .validate_and_relay(10, &move_1, r#"{"op":"relay"}"#)
            .unwrap();
        let _ = rx_guest.try_recv().unwrap();

        // Simular que el jugador en turno (asiento 2) supera turn_timeout_secs (1s)
        if let Some(room) = manager.rooms.get_mut(&code) {
            assert_eq!(room.active_turn_seat, 2);
            room.last_move_at = Instant::now() - Duration::from_secs(2);
        }

        let outcomes = manager.expire_turn_timeouts();
        assert_eq!(outcomes.len(), 1);
        assert_eq!(outcomes[0].winner, "guest_p1");
        assert_eq!(outcomes[0].loser, "guest_p2");

        // Ambos jugadores reciben {"op": "match_timeout", "winner_seat": 1, "reason": "turn_timeout"}
        let msg_host: Value = serde_json::from_str(&rx_host.try_recv().unwrap()).unwrap();
        assert_eq!(msg_host["op"], "match_timeout");
        assert_eq!(msg_host["winner_seat"], 1);
        assert_eq!(msg_host["reason"], "turn_timeout");

        let msg_guest: Value = serde_json::from_str(&rx_guest.try_recv().unwrap()).unwrap();
        assert_eq!(msg_guest["op"], "match_timeout");
        assert_eq!(msg_guest["winner_seat"], 1);
        assert_eq!(msg_guest["reason"], "turn_timeout");
    }

    #[test]
    fn test_prune_stale_rooms_removes_idle_and_preserves_active() {
        let mut manager = RoomManager::new();
        let (tx_stale, _rx_stale) = mpsc::unbounded_channel();
        let (tx_active, _rx_active) = mpsc::unbounded_channel();

        let stale_code = manager.create_room(100, tx_stale, Some("chess".to_string()), true);
        let active_code = manager.create_room(200, tx_active, Some("go".to_string()), true);
        assert_eq!(manager.active_room_count(), 2);

        // Simular que stale_code lleva 31 minutos sin actividad (> 30 minutos)
        if let Some(stale_room) = manager.rooms.get_mut(&stale_code) {
            stale_room.last_activity_at =
                Instant::now() - Duration::from_secs(DEFAULT_MAX_ROOM_IDLE_SECS + 60);
        }

        let removed = manager.prune_stale_rooms(Duration::from_secs(DEFAULT_MAX_ROOM_IDLE_SECS));
        assert_eq!(removed, 1);
        assert_eq!(manager.active_room_count(), 1);
        assert!(manager.participant_info(100).is_none());
        assert_eq!(
            manager.participant_info(200),
            Some((active_code.clone(), 1))
        );
    }

    #[test]
    fn test_elo_range_matchmaking_pairs_compatible_and_separates_outliers() {
        let mut manager = RoomManager::new();
        let (tx1, _rx1) = mpsc::unbounded_channel();
        let (tx2, _rx2) = mpsc::unbounded_channel();
        let (tx3, _rx3) = mpsc::unbounded_channel();

        // Jugador 1 (ELO 1200 ±150) entra en cola para "chess"
        let (code_1, pid_1, is_new_1) = manager.queue_matchmaking_with_elo(
            1,
            tx1,
            Some("chess".to_string()),
            Some(1200),
            Some(150),
        );
        assert!(is_new_1);
        assert_eq!(pid_1, 1);

        // Jugador 2 (ELO 1700 ±150) está fuera del rango de Jugador 1 -> crea nueva sala en espera
        let (code_2, pid_2, is_new_2) = manager.queue_matchmaking_with_elo(
            2,
            tx2,
            Some("chess".to_string()),
            Some(1700),
            Some(150),
        );
        assert!(is_new_2);
        assert_eq!(pid_2, 1);
        assert_ne!(code_1, code_2);

        // Jugador 3 (ELO 1280 ±150) está dentro del rango de Jugador 1 (|1200 - 1280| = 80 <= 150) -> se une a code_1
        let (code_3, pid_3, is_new_3) = manager.queue_matchmaking_with_elo(
            3,
            tx3,
            Some("chess".to_string()),
            Some(1280),
            Some(150),
        );
        assert!(!is_new_3);
        assert_eq!(code_3, code_1);
        assert_eq!(pid_3, 2);
    }

    #[test]
    fn test_control_message_does_not_reset_turn_clock_or_pollute_command_log() {
        let mut manager = RoomManager::new();
        let (tx1, _rx1) = mpsc::unbounded_channel();
        let (tx2, _rx2) = mpsc::unbounded_channel();

        let code =
            manager.create_room_with_timeout(1, tx1, Some("chess".to_string()), false, Some(10));
        manager.join_room(2, tx2, &code).unwrap();

        let past = Instant::now() - Duration::from_secs(12);
        if let Some(room) = manager.rooms.get_mut(&code) {
            room.last_move_at = past;
        }

        // Un mensaje de control no-JSON no debe reiniciar last_move_at ni agregarse al command_log
        let control_payload = serde_json::json!("ping_keepalive");
        manager
            .validate_and_relay(1, &control_payload, r#"{"op":"relay"}"#)
            .unwrap();

        let room = manager.rooms.get(&code).unwrap();
        assert!(room.command_log.is_empty());
        assert_eq!(room.last_move_at, past);

        // El reloj de turno sigue expirado porque el mensaje de control no lo reinició
        let timed_out = manager.expire_turn_timeouts();
        assert_eq!(timed_out.len(), 1);
        assert_eq!(timed_out[0].winner, "player2");
    }
}
