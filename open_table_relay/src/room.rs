//! Gestión de salas y generación de códigos legibles para `open_table_relay`.
//!
//! Administra salas públicas/privadas en memoria y asigna códigos alfanuméricos
//! de 4 caracteres sin caracteres ambiguos (`O`, `0`, `I`, `1`).

use crate::anticheat::AntiCheatSession;
use serde_json::Value;
use std::collections::HashMap;
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

/// Rol de un participante dentro de una sala Relay.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ParticipantRole {
    /// Jugador activo con permisos de escritura/retransmisión.
    Player,
    /// Espectador de solo lectura (sin permisos para emitir `op: "relay"`).
    Spectator,
}

/// Información de un participante conectado a una sala.
#[derive(Debug, Clone)]
pub struct Participant {
    /// Identificador único de la conexión.
    pub conn_id: ConnectionId,
    /// Identificador de jugador dentro de la sala (1-indexed para jugadores, 0 para espectadores).
    pub player_id: RoomPlayerId,
    /// Rol del participante en la sala (`Player` o `Spectator`).
    pub role: ParticipantRole,
    /// Canal para enviar mensajes JSON serializados al cliente.
    pub sender: ClientSender,
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
    /// Contador incremental para asignar `player_id` a nuevos participantes.
    next_player_id: RoomPlayerId,
    /// Participantes activos indexados por `ConnectionId`.
    pub participants: HashMap<ConnectionId, Participant>,
    /// Sesión autoritativa opcional para validación Anti-Cheat de los 13 juegos.
    pub anticheat: Option<AntiCheatSession>,
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
        Self::with_seed(
            code,
            host_conn_id,
            host_sender,
            game_id,
            is_public,
            generate_room_seed(),
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
        let mut participants = HashMap::new();
        participants.insert(
            host_conn_id,
            Participant {
                conn_id: host_conn_id,
                player_id: 1,
                role: ParticipantRole::Player,
                sender: host_sender,
            },
        );
        let anticheat = AntiCheatSession::for_game_with_seed(game_id.as_deref(), seed);
        Self {
            code,
            game_id,
            seed,
            is_public,
            next_player_id: 2,
            participants,
            anticheat,
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
                role: ParticipantRole::Player,
                sender,
            },
        );
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
                role: ParticipantRole::Spectator,
                sender,
            },
        );
        Ok(self.player_count())
    }

    /// Cantidad de jugadores activos (no espectadores) en la sala.
    pub fn player_count(&self) -> usize {
        self.participants
            .values()
            .filter(|p| p.role == ParticipantRole::Player)
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

    /// Envía un mensaje JSON a todos los participantes (jugadores y espectadores) excepto `exclude_conn`.
    pub fn broadcast_except(&self, exclude_conn: ConnectionId, message: &str) {
        for (&cid, participant) in &self.participants {
            if cid != exclude_conn {
                let _ = participant.sender.send(message.to_string());
            }
        }
    }

    /// Devuelve `true` si no quedan participantes conectados en la sala.
    pub fn is_empty(&self) -> bool {
        self.participants.is_empty()
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
#[derive(Debug, Default)]
pub struct RoomManager {
    /// Salas activas por código (en mayúsculas).
    rooms: HashMap<String, Room>,
    /// Mapa inverso de `ConnectionId` al código de sala en el que participa.
    conn_to_room: HashMap<ConnectionId, String>,
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
}

impl RoomManager {
    /// Crea un nuevo gestor de salas vacío.
    pub fn new() -> Self {
        Self::default()
    }

    /// Crea una nueva sala con un código único de 4 caracteres y registra al anfitrión.
    pub fn create_room(
        &mut self,
        host_conn_id: ConnectionId,
        host_sender: ClientSender,
        game_id: Option<String>,
        is_public: bool,
    ) -> String {
        // Si el cliente ya estaba en otra sala, lo sacamos primero limpiamente
        let _ = self.leave_room(host_conn_id);

        let code = loop {
            let candidate = generate_room_code();
            if !self.rooms.contains_key(&candidate) {
                break candidate;
            }
        };

        let room = Room::new(code.clone(), host_conn_id, host_sender, game_id, is_public);
        self.rooms.insert(code.clone(), room);
        self.conn_to_room.insert(host_conn_id, code.clone());
        code
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

    /// Valida el payload con `AntiCheatSession` (si aplica a la sala) y retransmite a los demás participantes.
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

        if let Some(ac) = room.anticheat.as_mut() {
            if ac.validate_and_apply(sender_player_id, payload).is_err() {
                return Err(RoomError::IllegalMove);
            }
        }

        room.broadcast_except(conn_id, outbound_json);
        Ok((code, sender_player_id))
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

    /// Retira a un cliente de su sala actual (por `{"op": "leave"}` o desconexión)
    /// y notifica a los participantes restantes.
    ///
    /// Si la sala queda vacía, se elimina de memoria automáticamente.
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
            should_remove_room = room.is_empty();
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
}
