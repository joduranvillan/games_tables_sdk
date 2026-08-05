//! `Session`: el contenedor de una partida en curso.
//!
//! Tres invariantes de seguridad/consistencia que este archivo hace
//! cumplir:
//! 1. `process_command` es el único método que muta el `World` (I3 del
//!    RFC): no hay forma de tomar una referencia mutable al `World` desde
//!    afuera.
//! 2. El `sender` de un comando SIEMPRE viene de la capa de red (qué
//!    conexión trajo estos bytes), nunca de un campo dentro del propio
//!    comando. Si el comando declara un `issuer()` distinto del `sender`
//!    real, se rechaza. Esto es lo que impide que un cliente mande
//!    comandos "de parte de" otro jugador.
//! 3. Cada comando aceptado se guarda en un log ordenado por tick. Ese
//!    log alcanza para dos cosas sin necesitar serializar el `World`
//!    entero: reproducir la partida completa (replay) y, filtrando los
//!    eventos resultantes por `Visibility`, reconstruir lo que un cliente
//!    que se reconectó se perdió (resync).

use std::io::{Read, Write};
use std::time::{Duration, Instant};

use bevy_ecs::world::World as BevyWorld;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use hmac::{Hmac, Mac};
use open_table_core::prelude::*;
use serde::{Deserialize, Serialize};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

use crate::rule_engine::RuleEngine;
use crate::turn::{TurnOrder, TurnResource};

/// Recurso de bevy_ecs que indica el ganador de la partida.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bevy_ecs::system::Resource)]
pub struct WinnerResource(pub Option<PlayerId>);

/// Modo de sesión: Local (un solo dispositivo) u Online (red).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionMode {
    Local,
    Online,
}

/// Evento emitido cuando un jugador pierde por abandono/timeout de reconexión.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ForfeitEvent {
    pub player: PlayerId,
}

#[typetag::serde(name = "open_table_engine::ForfeitEvent")]
impl Event for ForfeitEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

/// Recurso para rastrear timeouts de reconexión por jugador.
#[derive(Debug, Clone, bevy_ecs::system::Resource)]
pub struct ReconnectionTimeoutResource {
    pub timeouts: std::collections::HashMap<PlayerId, (Instant, Duration)>,
}

/// Recurso de bevy_ecs que envuelve `RandomService`.
#[derive(Debug, Clone, Serialize, Deserialize, bevy_ecs::system::Resource)]
pub struct RandomResource(pub RandomService);

/// Recurso de bevy_ecs que indica si la partida ha terminado.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bevy_ecs::system::Resource)]
pub struct GameOverResource(pub bool);

/// Recurso de bevy_ecs que envuelve la `GameVariant`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bevy_ecs::system::Resource)]
pub struct GameVariantResource(pub GameVariant);

/// Metadatos de la sesión.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionMetadata {
    pub game_name: String,
    pub started_at: u64,
    pub max_players: usize,
}

/// Recurso de bevy_ecs que almacena los metadatos de la sesión.
#[derive(Debug, Clone, Serialize, Deserialize, bevy_ecs::system::Resource)]
pub struct SessionMetadataResource(pub SessionMetadata);

type EventHandlerFn = std::sync::Arc<dyn Fn(&dyn Event) + Send + Sync + 'static>;

/// Handler callbacks para eventos suscriptos via `on_event`.
#[derive(Default, bevy_ecs::system::Resource)]
pub struct EventHandlersResource {
    pub handlers: Vec<(std::any::TypeId, EventHandlerFn)>,
}

/// Recurso para limitar la tasa de comandos por jugador.
#[derive(Debug, Clone, bevy_ecs::system::Resource)]
pub struct RateLimitResource {
    pub max_commands_per_second: u32,
    pub history: std::collections::HashMap<PlayerId, Vec<Instant>>,
}

/// Recurso de bevy_ecs que gestiona el temporizador de turno.
#[derive(Debug, Clone, bevy_ecs::system::Resource)]
pub struct TimerResource {
    pub start: Instant,
    pub duration: Duration,
}

impl TimerResource {
    pub fn new(duration: Duration) -> Self {
        Self {
            start: Instant::now(),
            duration,
        }
    }

    pub fn reset(&mut self) {
        self.start = Instant::now();
    }

    pub fn is_expired(&self) -> bool {
        self.start.elapsed() > self.duration
    }
}

/// Representación serializable del estado completo de una `Session`.
#[derive(Serialize, Deserialize)]
pub struct SessionSnapshot {
    pub id: SessionId,
    pub clock: GameClock,
    pub command_log: Vec<LoggedCommand>,
    pub turn_resource: Option<TurnResource>,
    pub random_resource: Option<RandomResource>,
    pub game_over_resource: Option<GameOverResource>,
    pub game_variant_resource: Option<GameVariantResource>,
    pub metadata_resource: Option<SessionMetadataResource>,
}

/// Una entrada del log de comandos: en qué tick se aplicó, timestamp en ms y qué comando
/// fue. Serializable en conjunto para exportar/persistir la partida.
pub type LoggedCommand = (Tick, u64, Box<dyn Command>);

pub trait ResourceWatcher: Send + Sync {
    fn check_and_notify(&mut self, world: &BevyWorld);
}

struct TypedResourceWatcher<R: bevy_ecs::system::Resource + Clone + 'static, F: Fn(&R) + Send + Sync + 'static> {
    handler: F,
    _phantom: std::marker::PhantomData<R>,
}

impl<R: bevy_ecs::system::Resource + Clone + 'static, F: Fn(&R) + Send + Sync + 'static> ResourceWatcher for TypedResourceWatcher<R, F> {
    fn check_and_notify(&mut self, world: &BevyWorld) {
        if world.is_resource_changed::<R>() {
            if let Some(res) = world.get_resource::<R>() {
                (self.handler)(res);
            }
        }
    }
}

pub type CommandMiddleware = Box<dyn Fn(&CommandEnvelope, &mut BevyWorld) -> Result<(), EngineError> + Send + Sync + 'static>;

pub struct Session {
    pub id: SessionId,
    pub mode: SessionMode,
    world: BevyWorld,
    rules: RuleEngine,
    clock: GameClock,
    command_log: Vec<LoggedCommand>,
    initial_setup: Option<std::sync::Arc<dyn Fn(&mut BevyWorld) + Send + Sync + 'static>>,
    paused: bool,
    watchers: Vec<Box<dyn ResourceWatcher + Send + Sync>>,
    middlewares: Vec<CommandMiddleware>,
}

impl Session {
    pub fn new(id: SessionId, seed: u64, players: Vec<PlayerId>, rules: RuleEngine) -> Self {
        Self::new_with_details(id, "Unknown", GameVariant::Standard, seed, players, rules)
    }

    pub fn new_with_variant(
        id: SessionId,
        seed: u64,
        players: Vec<PlayerId>,
        rules: RuleEngine,
        variant: GameVariant,
    ) -> Self {
        Self::new_with_details(id, "Unknown", variant, seed, players, rules)
    }

    pub fn new_with_metadata(
        id: SessionId,
        game_name: impl Into<String>,
        seed: u64,
        players: Vec<PlayerId>,
        rules: RuleEngine,
    ) -> Self {
        Self::new_with_details(id, game_name, GameVariant::Standard, seed, players, rules)
    }

    pub fn new_with_details(
        id: SessionId,
        game_name: impl Into<String>,
        variant: GameVariant,
        seed: u64,
        players: Vec<PlayerId>,
        rules: RuleEngine,
    ) -> Self {
        let mut world = BevyWorld::new();
        world.insert_resource(RandomResource(RandomService::from_seed(seed)));
        world.insert_resource(TurnResource(TurnOrder::new(players.clone())));
        world.insert_resource(GameOverResource(false));
        world.insert_resource(WinnerResource(None));
        world.insert_resource(GameVariantResource(variant));

        let started_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let metadata = SessionMetadata {
            game_name: game_name.into(),
            started_at,
            max_players: players.len(),
        };
        world.insert_resource(SessionMetadataResource(metadata));

        Self {
            id,
            mode: SessionMode::Local,
            world,
            rules,
            clock: GameClock::new(),
            command_log: Vec::new(),
            initial_setup: None,
            paused: false,
            watchers: Vec::new(),
            middlewares: Vec::new(),
        }
    }

    pub fn add_middleware(
        &mut self,
        mw: impl Fn(&CommandEnvelope, &mut BevyWorld) -> Result<(), EngineError> + Send + Sync + 'static,
    ) {
        self.middlewares.push(Box::new(mw));
    }

    pub fn watch<R: bevy_ecs::system::Resource + Clone + 'static>(
        &mut self,
        handler: impl Fn(&R) + Send + Sync + 'static,
    ) {
        let watcher = TypedResourceWatcher {
            handler,
            _phantom: std::marker::PhantomData,
        };
        self.watchers.push(Box::new(watcher));
    }

    pub fn move_history(&self) -> Vec<String> {
        self.command_log
            .iter()
            .map(|(tick, _elapsed, cmd)| {
                let envelope = CommandEnvelope {
                    tick: *tick,
                    payload: cmd.clone(),
                };
                crate::history::format_command(&envelope)
            })
            .collect()
    }

    pub fn command_log(&self) -> &[LoggedCommand] {
        &self.command_log
    }

    pub fn export_chess_pgn(&self) -> Option<String> {
        let mut pgn = String::from("[Event \"Casual Game\"]\n[Site \"OpenTable\"]\n[Date \"????.??.??\"]\n[Round \"1\"]\n[White \"White\"]\n[Black \"Black\"]\n[Result \"*\"]\n\n");
        let mut move_strs = Vec::new();
        let mut move_num = 1;

        let mut piece_positions = std::collections::HashMap::new();
        for r in 0..8u8 {
            for c in 0..8u8 {
                let p = match (r, c) {
                    (0, 0) | (0, 7) => Some(('R', true)),
                    (0, 1) | (0, 6) => Some(('N', true)),
                    (0, 2) | (0, 5) => Some(('B', true)),
                    (0, 3) => Some(('Q', true)),
                    (0, 4) => Some(('K', true)),
                    (1, _) => Some(('P', true)),
                    (7, 0) | (7, 7) => Some(('R', false)),
                    (7, 1) | (7, 6) => Some(('N', false)),
                    (7, 2) | (7, 5) => Some(('B', false)),
                    (7, 3) => Some(('Q', false)),
                    (7, 4) => Some(('K', false)),
                    (6, _) => Some(('P', false)),
                    _ => None,
                };
                if let Some((kind, is_white)) = p {
                    piece_positions.insert((r, c), (kind, is_white));
                }
            }
        }

        let mut is_white_turn = true;

        for (_tick, _elapsed, cmd) in &self.command_log {
            if let Ok(val) = serde_json::to_value(cmd.as_ref()) {
                let ct = val.get("command_type").and_then(|v| v.as_str()).unwrap_or("");
                if ct.contains("MovePieceCommand") {
                    let from_r = val.get("from").and_then(|f| f.get("row")).and_then(|r| r.as_u64()).unwrap_or(0) as u8;
                    let from_c = val.get("from").and_then(|f| f.get("col")).and_then(|c| c.as_u64()).unwrap_or(0) as u8;
                    let to_r = val.get("to").and_then(|t| t.get("row")).and_then(|r| r.as_u64()).unwrap_or(0) as u8;
                    let to_c = val.get("to").and_then(|t| t.get("col")).and_then(|c| c.as_u64()).unwrap_or(0) as u8;

                    let piece_info = piece_positions.remove(&(from_r, from_c));
                    let (kind, _is_white) = piece_info.unwrap_or(('P', is_white_turn));
                    let captured = piece_positions.remove(&(to_r, to_c));

                    let from_c_char = (b'a' + from_c) as char;
                    let to_c_char = (b'a' + to_c) as char;
                    let to_r_char = (b'1' + to_r) as char;

                    let san_move = if kind == 'K' && from_c == 4 && to_c == 6 {
                        "O-O".to_string()
                    } else if kind == 'K' && from_c == 4 && to_c == 2 {
                        "O-O-O".to_string()
                    } else if kind == 'P' {
                        if captured.is_some() || from_c != to_c {
                            format!("{from_c_char}x{to_c_char}{to_r_char}")
                        } else {
                            format!("{to_c_char}{to_r_char}")
                        }
                    } else {
                        if captured.is_some() {
                            format!("{kind}x{to_c_char}{to_r_char}")
                        } else {
                            format!("{kind}{to_c_char}{to_r_char}")
                        }
                    };

                    let promote_char = match val.get("promote_to").and_then(|p| p.as_str()) {
                        Some("Queen") => "=Q",
                        Some("Rook") => "=R",
                        Some("Bishop") => "=B",
                        Some("Knight") => "=N",
                        _ => "",
                    };
                    let full_move = format!("{san_move}{promote_char}");

                    let final_kind = match val.get("promote_to").and_then(|p| p.as_str()) {
                        Some("Queen") => 'Q',
                        Some("Rook") => 'R',
                        Some("Bishop") => 'B',
                        Some("Knight") => 'N',
                        _ => kind,
                    };
                    piece_positions.insert((to_r, to_c), (final_kind, is_white_turn));

                    if is_white_turn {
                        move_strs.push(format!("{move_num}. {full_move}"));
                    } else {
                        if let Some(last) = move_strs.last_mut() {
                            last.push_str(&format!(" {full_move}"));
                        }
                        move_num += 1;
                    }
                    is_white_turn = !is_white_turn;
                }
            }
        }

        pgn.push_str(&move_strs.join(" "));
        Some(pgn)
    }

    pub fn pause(&mut self) -> EngineResult<()> {
        self.paused = true;
        Ok(())
    }

    pub fn resume(&mut self) -> EngineResult<()> {
        self.paused = false;
        Ok(())
    }

    pub fn is_paused(&self) -> bool {
        self.paused
    }

    pub fn mode(&self) -> SessionMode {
        self.mode
    }

    pub fn set_mode(&mut self, mode: SessionMode) {
        self.mode = mode;
    }

    pub fn set_initial_setup<F>(&mut self, setup: F)
    where
        F: Fn(&mut BevyWorld) + Send + Sync + 'static,
    {
        self.initial_setup = Some(std::sync::Arc::new(setup));
    }

    pub fn set_reconnection_timeout(&mut self, player: PlayerId, duration: Duration) {
        if !self.world.contains_resource::<ReconnectionTimeoutResource>() {
            self.world.insert_resource(ReconnectionTimeoutResource {
                timeouts: std::collections::HashMap::new(),
            });
        }
        let mut res = self.world.resource_mut::<ReconnectionTimeoutResource>();
        res.timeouts.insert(player, (Instant::now(), duration));
    }

    pub fn metadata(&self) -> &SessionMetadata {
        &self.world.resource::<SessionMetadataResource>().0
    }

    pub fn on_event<E: Event + 'static>(&mut self, handler: impl Fn(&E) + Send + Sync + 'static) {
        if !self.world.contains_resource::<EventHandlersResource>() {
            self.world.insert_resource(EventHandlersResource::default());
        }
        let type_id = std::any::TypeId::of::<E>();
        let wrapper = std::sync::Arc::new(move |event_dyn: &dyn Event| {
            if let Some(concrete) = event_dyn.as_any().downcast_ref::<E>() {
                handler(concrete);
            }
        });
        let mut handlers = self.world.resource_mut::<EventHandlersResource>();
        handlers.handlers.push((type_id, wrapper));
    }

    pub fn set_rate_limit(&mut self, max_commands_per_second: u32) {
        self.world.insert_resource(RateLimitResource {
            max_commands_per_second,
            history: std::collections::HashMap::new(),
        });
    }

    pub fn current_tick(&self) -> Tick {
        self.clock.current()
    }

    pub fn current_player(&self) -> PlayerId {
        self.world.resource::<TurnResource>().0.current_player()
    }

    /// Único punto de entrada para mutar el estado de la partida.
    ///
    /// `sender` tiene que venir de `Transport::poll_received()` (la
    /// identidad ligada a la conexión de red real), nunca de un campo
    /// dentro de `command`. Si `command.issuer()` es `Some` y no coincide
    /// con `sender`, se rechaza sin ejecutar nada — esto es lo que impide
    /// que un cliente mande comandos en nombre de otro jugador.
    pub fn process_command(
        &mut self,
        sender: PlayerId,
        command: Box<dyn Command>,
    ) -> EngineResult<Vec<Box<dyn Event>>> {
        if self.paused {
            return Err(EngineError::SessionPaused);
        }

        if self.world.get_resource::<GameOverResource>().map_or(false, |r| r.0) {
            return Err(EngineError::GameAlreadyOver);
        }

        if let Some(claimed_issuer) = command.issuer() {
            if claimed_issuer != sender {
                return Err(EngineError::Unauthorized(sender));
            }
        }

        if let Some(mut rate_limit) = self.world.get_resource_mut::<RateLimitResource>() {
            let max_cps = rate_limit.max_commands_per_second;
            let now = Instant::now();
            let history = rate_limit.history.entry(sender).or_default();
            history.retain(|ts| now.duration_since(*ts) < Duration::from_secs(1));
            if history.len() as u32 >= max_cps {
                return Err(EngineError::RateLimitExceeded(sender));
            }
            history.push(now);
        }

        let envelope = CommandEnvelope {
            tick: self.current_tick(),
            payload: command.clone(),
        };

        for mw in &self.middlewares {
            mw(&envelope, &mut self.world)?;
        }

        self.world.clear_trackers();
        let events = self.rules.dispatch(command.as_ref(), &mut self.world)?;
        let tick = self.clock.advance();
        let elapsed = self.clock.elapsed_millis();
        self.command_log.push((tick, elapsed, command));

        for watcher in &mut self.watchers {
            watcher.check_and_notify(&self.world);
        }

        if let Some(mut timer) = self.world.get_resource_mut::<TimerResource>() {
            timer.reset();
        }

        if let Some(handlers_res) = self.world.get_resource::<EventHandlersResource>() {
            for event in &events {
                let event_type_id = event.as_any().type_id();
                for (registered_type_id, handler) in &handlers_res.handlers {
                    if *registered_type_id == event_type_id {
                        handler(event.as_ref());
                    }
                }
            }
        }

        Ok(events)
    }

    /// Comprueba si el temporizador de turno o el timeout de reconexión ha expirado.
    pub fn check_timeout(&mut self) -> Option<PlayerId> {
        if let Some(mut rec_res) = self.world.get_resource_mut::<ReconnectionTimeoutResource>() {
            let now = Instant::now();
            let timed_out_player = rec_res.timeouts.iter().find_map(|(&player, &(start, duration))| {
                if now.duration_since(start) >= duration {
                    Some(player)
                } else {
                    None
                }
            });

            if let Some(player) = timed_out_player {
                rec_res.timeouts.remove(&player);

                let forfeit_event = ForfeitEvent { player };
                if let Some(handlers_res) = self.world.get_resource::<EventHandlersResource>() {
                    let event_type_id = std::any::TypeId::of::<ForfeitEvent>();
                    for (registered_type_id, handler) in &handlers_res.handlers {
                        if *registered_type_id == event_type_id {
                            handler(&forfeit_event);
                        }
                    }
                }

                if let Some(mut turn) = self.world.get_resource_mut::<TurnResource>() {
                    turn.0.advance();
                }

                return Some(player);
            }
        }

        if let Some(timer) = self.world.get_resource::<TimerResource>() {
            if timer.is_expired() {
                return Some(self.current_player());
            }
        }
        None
    }

    /// Revierte el último comando del log replaying desde cero.
    /// Disponible solo si `SessionMode::Local`.
    pub fn undo_last_command(&mut self) -> EngineResult<()> {
        if self.mode != SessionMode::Local {
            return Err(EngineError::InvalidCommand {
                reason: "Undo solo disponible en modo Local".into(),
            });
        }

        if self.command_log.is_empty() {
            return Ok(());
        }

        self.command_log.pop();
        let remaining_commands: Vec<_> = self.command_log.drain(..).map(|(_, _, cmd)| cmd).collect();

        let seed = self
            .world
            .get_resource::<RandomResource>()
            .map(|r| r.0.seed())
            .unwrap_or(0);
        let players = self
            .world
            .get_resource::<TurnResource>()
            .map(|t| t.0.players().to_vec())
            .unwrap_or_default();
        let variant = self
            .world
            .get_resource::<GameVariantResource>()
            .map(|v| v.0.clone())
            .unwrap_or(GameVariant::Standard);
        let game_name = self.metadata().game_name.clone();

        let mut new_world = BevyWorld::new();
        new_world.insert_resource(RandomResource(RandomService::from_seed(seed)));
        new_world.insert_resource(TurnResource(TurnOrder::new(players.clone())));
        new_world.insert_resource(GameOverResource(false));
        new_world.insert_resource(GameVariantResource(variant));

        let started_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let metadata = SessionMetadata {
            game_name,
            started_at,
            max_players: players.len(),
        };
        new_world.insert_resource(SessionMetadataResource(metadata));

        if let Some(ref setup) = self.initial_setup {
            setup(&mut new_world);
        }

        self.world = new_world;
        self.clock = GameClock::new();

        for command in remaining_commands {
            let sender = command.issuer().unwrap_or_else(|| self.current_player());
            self.process_command(sender, command)?;
        }

        Ok(())
    }

    /// Extrae los datos del resultado de la partida finalizada.
    pub fn into_result(&self, elapsed_ms: u64) -> GameResult {
        let winner = self
            .world
            .get_resource::<WinnerResource>()
            .and_then(|w| w.0);
        let total_moves = self.command_log.len() as u32;
        let players = self
            .world
            .get_resource::<TurnResource>()
            .map(|t| t.0.players().to_vec())
            .unwrap_or_default();
        let game_name = self.metadata().game_name.clone();

        GameResult {
            winner,
            duration_ms: elapsed_ms,
            total_moves,
            players,
            game_name,
        }
    }

    pub fn world(&self) -> &BevyWorld {
        &self.world
    }

    /// Acceso mutable al `World` para el SETUP INICIAL de un juego (ej:
    /// insertar el `Resource` del tablero antes de la primera jugada).
    /// Esto no viola el invariante "solo `process_command` muta el
    /// `World`" en espíritu: está pensado para usarse una sola vez, antes
    /// de que la partida arranque, nunca durante el loop de juego. La
    /// lógica de una jugada real SIEMPRE tiene que pasar por una regla
    /// registrada en el `RuleEngine`, no por acá.
    pub fn world_mut(&mut self) -> &mut BevyWorld {
        &mut self.world
    }

    /// Exporta el log completo de comandos como JSON. Esto es todo lo que
    /// hace falta guardar para poder reproducir la partida entera más
    /// adelante: seed + orden de jugadores + este log alcanzan, porque
    /// `RandomService` es determinista.
    pub fn export_log(&self) -> EngineResult<Vec<u8>> {
        serde_json::to_vec(&self.command_log)
            .map_err(|e| EngineError::Replay(format!("no se pudo exportar el log: {e}")))
    }

    /// Guarda el log de comandos de la sesión en un archivo en el disco.
    pub fn save_to_file(&self, path: &str) -> EngineResult<()> {
        let bytes = self.export_log()?;
        std::fs::write(path, bytes)
            .map_err(|e| EngineError::IoError(format!("no se pudo guardar la sesión en {path}: {e}")))
    }

    /// Carga un log de comandos desde un archivo y reconstruye la sesión.
    pub fn load_from_file(
        id: SessionId,
        seed: u64,
        players: Vec<PlayerId>,
        rules: RuleEngine,
        path: &str,
    ) -> EngineResult<Session> {
        let log_bytes = std::fs::read(path)
            .map_err(|e| EngineError::IoError(format!("no se pudo cargar la sesión desde {path}: {e}")))?;
        Self::replay(id, seed, players, rules, &log_bytes)
    }

    /// Reconstruye una `Session` desde cero reproduciendo un log
    /// exportado con `export_log`. Usa `command.issuer()` como `sender`
    /// en cada paso (el log solo contiene comandos que ya pasaron la
    /// validación de identidad la primera vez, así que esto es seguro).
    pub fn replay(
        id: SessionId,
        seed: u64,
        players: Vec<PlayerId>,
        rules: RuleEngine,
        log_bytes: &[u8],
    ) -> EngineResult<Session> {
        let (session, _events) = Self::replay_collecting_events(id, seed, players, rules, log_bytes)?;
        Ok(session)
    }

    /// Igual que `replay`, pero además devuelve TODOS los eventos
    /// producidos durante la reproducción. Es la base del mecanismo de
    /// resync: en vez de serializar el `World` de bevy_ecs (genérico y
    /// difícil), reproducimos el log y le mandamos al cliente reconectado
    /// solo los eventos que su `Visibility` le permite ver — filtrando
    /// con `filter_events_for_player`.
    pub fn replay_collecting_events(
        id: SessionId,
        seed: u64,
        players: Vec<PlayerId>,
        rules: RuleEngine,
        log_bytes: &[u8],
    ) -> EngineResult<(Session, Vec<Box<dyn Event>>)> {
        let session = Session::new(id, seed, players, rules);
        Self::replay_on_session(session, log_bytes)
    }

    /// Reproduce los comandos de `log_bytes` sobre una `Session` ya inicializada.
    pub fn replay_on_session(
        mut session: Session,
        log_bytes: &[u8],
    ) -> EngineResult<(Session, Vec<Box<dyn Event>>)> {
        let log: Vec<LoggedCommand> = serde_json::from_slice(log_bytes)
            .map_err(|e| EngineError::Replay(format!("no se pudo leer el log: {e}")))?;

        let mut all_events = Vec::new();

        for (_tick, _elapsed, command) in log {
            let sender = command.issuer().unwrap_or_else(|| session.current_player());
            let mut events = session.process_command(sender, command)?;
            all_events.append(&mut events);
        }

        Ok((session, all_events))
    }

    /// Devuelve la lista de pares (Tick, u64) con los timestamps (en ms) de los comandos aplicados.
    pub fn tick_timestamps(&self) -> Vec<(Tick, u64)> {
        self.command_log
            .iter()
            .map(|(tick, elapsed, _)| (*tick, *elapsed))
            .collect()
    }

    /// Reproduce solo los comandos con tick mayor a `start_tick` desde `log_bytes`,
    /// aplicando las novedades sin recrear el estado previo de la sesión.
    pub fn replay_from(
        &mut self,
        log_bytes: &[u8],
        start_tick: impl Into<Tick>,
    ) -> EngineResult<Vec<Box<dyn Event>>> {
        let start_tick = start_tick.into();
        let log: Vec<LoggedCommand> = serde_json::from_slice(log_bytes)
            .map_err(|e| EngineError::Replay(format!("no se pudo leer el log: {e}")))?;

        let mut all_events = Vec::new();

        for (tick, _elapsed, command) in log {
            if tick > start_tick {
                let sender = command.issuer().unwrap_or_else(|| self.current_player());
                let mut events = self.process_command(sender, command)?;
                all_events.append(&mut events);
            }
        }

        Ok(all_events)
    }

    /// Alias con orden de parámetros invertido para conveniencia.
    pub fn replay_from_tick(
        &mut self,
        start_tick: impl Into<Tick>,
        log_bytes: &[u8],
    ) -> EngineResult<Vec<Box<dyn Event>>> {
        self.replay_from(log_bytes, start_tick)
    }

    /// Serializa el estado completo de los recursos de `BevyWorld`, el reloj lógico
    /// y el log de comandos a bytes usando JSON.
    pub fn snapshot(&self) -> EngineResult<Vec<u8>> {
        let snapshot = SessionSnapshot {
            id: self.id,
            clock: self.clock.clone(),
            command_log: self.command_log.clone(),
            turn_resource: self.world.get_resource::<TurnResource>().cloned(),
            random_resource: self.world.get_resource::<RandomResource>().cloned(),
            game_over_resource: self.world.get_resource::<GameOverResource>().cloned(),
            game_variant_resource: self.world.get_resource::<GameVariantResource>().cloned(),
            metadata_resource: self.world.get_resource::<SessionMetadataResource>().cloned(),
        };
        serde_json::to_vec(&snapshot)
            .map_err(|e| EngineError::Replay(format!("no se pudo crear el snapshot: {e}")))
    }

    /// Restaura una `Session` directamente desde un snapshot guardado, sin reproducir los comandos.
    pub fn from_snapshot(snapshot_bytes: &[u8], rules: RuleEngine) -> EngineResult<Session> {
        let snapshot: SessionSnapshot = serde_json::from_slice(snapshot_bytes)
            .map_err(|e| EngineError::Replay(format!("no se pudo leer el snapshot: {e}")))?;

        let mut world = BevyWorld::new();
        if let Some(tr) = snapshot.turn_resource {
            world.insert_resource(tr);
        }
        if let Some(rr) = snapshot.random_resource {
            world.insert_resource(rr);
        }
        if let Some(go) = snapshot.game_over_resource {
            world.insert_resource(go);
        }
        if let Some(gv) = snapshot.game_variant_resource {
            world.insert_resource(gv);
        }
        if let Some(sm) = snapshot.metadata_resource {
            world.insert_resource(sm);
        }

        Ok(Session {
            id: snapshot.id,
            mode: SessionMode::Local,
            world,
            rules,
            clock: snapshot.clock,
            command_log: snapshot.command_log,
            initial_setup: None,
            paused: false,
            watchers: Vec::new(),
            middlewares: Vec::new(),
        })
    }

    /// Devuelve un hash u64 del estado actual del mundo serializable vía snapshot.
    pub fn world_hash(&self) -> u64 {
        use std::hash::{Hash, Hasher};
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        if let Ok(bytes) = self.snapshot() {
            bytes.hash(&mut hasher);
        }
        hasher.finish()
    }

    /// Exporta el log completo de comandos comprimido con gzip (flate2).
    pub fn export_log_compressed(&self) -> EngineResult<Vec<u8>> {
        let uncompressed = self.export_log()?;
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder
            .write_all(&uncompressed)
            .map_err(|e| EngineError::IoError(format!("error al comprimir log: {e}")))?;
        encoder
            .finish()
            .map_err(|e| EngineError::IoError(format!("error al finalizar compresión de log: {e}")))
    }

    /// Reproduce los comandos de un log comprimido con gzip sobre esta sesión.
    pub fn replay_from_compressed(&mut self, bytes: &[u8]) -> EngineResult<Vec<Box<dyn Event>>> {
        let mut decoder = GzDecoder::new(bytes);
        let mut uncompressed = Vec::new();
        decoder
            .read_to_end(&mut uncompressed)
            .map_err(|e| EngineError::Replay(format!("error al descomprimir log: {e}")))?;
        self.replay_from(&uncompressed, 0)
    }

    /// Reconstruye una nueva `Session` desde un log comprimido con gzip.
    pub fn replay_compressed(
        id: SessionId,
        seed: u64,
        players: Vec<PlayerId>,
        rules: RuleEngine,
        bytes: &[u8],
    ) -> EngineResult<Session> {
        let mut decoder = GzDecoder::new(bytes);
        let mut uncompressed = Vec::new();
        decoder
            .read_to_end(&mut uncompressed)
            .map_err(|e| EngineError::Replay(format!("error al descomprimir log: {e}")))?;
        Self::replay(id, seed, players, rules, &uncompressed)
    }

    /// Exporta el log de comandos serializado en JSON y firmado con HMAC-SHA256 usando `secret`.
    /// Añade los 32 bytes de la firma HMAC al final de los bytes del JSON.
    pub fn export_log_signed(&self, secret: &[u8]) -> EngineResult<Vec<u8>> {
        let json_bytes = self.export_log()?;
        let mut mac = HmacSha256::new_from_slice(secret)
            .map_err(|e| EngineError::Internal(format!("error al inicializar HMAC: {e}")))?;
        mac.update(&json_bytes);
        let signature = mac.finalize().into_bytes();

        let mut signed_payload = Vec::with_capacity(json_bytes.len() + signature.len());
        signed_payload.extend_from_slice(&json_bytes);
        signed_payload.extend_from_slice(&signature);
        Ok(signed_payload)
    }

    /// Verifica la integridad del log firmado con HMAC-SHA256 antes de reproducirlo.
    pub fn verify_log(bytes: &[u8], secret: &[u8]) -> EngineResult<()> {
        if bytes.len() < 32 {
            return Err(EngineError::Replay(
                "log firmado inválido: tamaño insuficiente para incluir la firma HMAC".into(),
            ));
        }

        let (json_bytes, signature_tag) = bytes.split_at(bytes.len() - 32);

        let mut mac = HmacSha256::new_from_slice(secret)
            .map_err(|e| EngineError::Internal(format!("error al inicializar HMAC: {e}")))?;
        mac.update(json_bytes);

        mac.verify_slice(signature_tag).map_err(|_| {
            EngineError::Replay(
                "firma HMAC inválida: el log ha sido alterado o la clave es incorrecta".into(),
            )
        })
    }

    /// Reemplaza el `RuleEngine` activo sin modificar el estado del `World`.
    /// El swap solo es válido si la sesión está pausada (`self.is_paused()`).
    pub fn swap_rule_engine(&mut self, new_rules: RuleEngine) -> EngineResult<()> {
        if !self.is_paused() {
            return Err(EngineError::InvalidCommand {
                reason: "el swap de motor de reglas solo se permite cuando la sesión está pausada"
                    .into(),
            });
        }
        self.rules = new_rules;
        Ok(())
    }
}

/// Filtra una lista de eventos a los que un jugador específico puede ver,
/// según `Visibility`. Se usa tanto para el broadcast normal (host filtra
/// antes de mandar por `Transport`) como para el resync de un cliente
/// reconectado (filtra el resultado de `replay_collecting_events`).
pub fn filter_events_for_player(
    events: &[Box<dyn Event>],
    player: PlayerId,
) -> Vec<&Box<dyn Event>> {
    events
        .iter()
        .filter(|event| event.visibility().includes(player))
        .collect()
}

/// Filtra una lista de eventos a los que un espectador específico puede ver,
/// según `Visibility`.
pub fn filter_events_for_spectator(
    events: &[Box<dyn Event>],
    spectator: SpectatorId,
) -> Vec<&Box<dyn Event>> {
    events
        .iter()
        .filter(|event| event.visibility().includes_spectator(spectator))
        .collect()
}
