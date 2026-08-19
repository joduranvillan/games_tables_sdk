//! Puente unificado entre los motores Rust (`open_table_engine`, juegos) y Godot/Redot.
//!
//! Expone un único nodo Godot (`OpenTableBridge`) con dispatch interno por modo:
//! - Local: partida hotseat en un solo dispositivo (`start_local_match_*`).
//! - Host: servidor TCP local que procesa comandos y transmite eventos (`start_hosting`).
//! - Client: cliente TCP que envía comandos y recibe eventos (`connect_to_host`, `reconnect_to_host`).
//! - NativeHost: servidor P2P nativo (Nearby Connections / MultipeerConnectivity).
//! - NativeClient: cliente P2P nativo con handshake de token automático (`start_native_client`, `reconnect_native`).

use godot::classes::{INode, Node};
use godot::prelude::*;

pub use godot;

use backgammon_game::new_backgammon_session;
use battleship_game::{new_battleship_session, ShotResult, ShotResultEvent};
use checkers_game::{
    new_checkers_session, GameOverEvent, MovePieceCommand, PieceMovedEvent, Position,
};
use chess_game::new_chess_session;
use chinese_checkers_game::new_chinese_checkers_session;
use crisis_game::{
    new_crisis_session, ArmiesPlacedEvent, AttackResolvedEvent, CardsExchangedEvent,
    PhaseChangedEvent, PlayerEliminatedEvent, TegGameOverEvent, TerritoryConqueredEvent,
};
use go_game::new_go_session;
use ludo_game::new_ludo_session;
use mille_bornes_game::new_mille_bornes_session;
use monopoly_game::new_monopoly_session;
use shogi_game::new_shogi_session;
use uno_game::new_uno_session;
use xiangqi_game::new_xiangqi_session;

use open_table_engine::prelude::*;
use open_table_transport_native_bridge::{
    HandshakeStatus, NativeClientTransport, NativeHostTransport, RawByteLink, RawLinkEvent,
};
use open_table_transport_tcp::{ConnectionEvent, TcpClientTransport, TcpHostTransport};
use std::sync::{Arc, Mutex};

struct OpenTableExtension;

#[gdextension]
unsafe impl ExtensionLibrary for OpenTableExtension {}

#[derive(Clone, Default)]
pub struct SharedLinkQueue {
    pub incoming: Vec<(String, Vec<u8>)>,
    pub events: Vec<RawLinkEvent>,
    pub outgoing_sends: Vec<(String, Vec<u8>)>,
    pub outgoing_broadcasts: Vec<Vec<u8>>,
}

pub struct GodotNearbyLink {
    pub queue: Arc<Mutex<SharedLinkQueue>>,
}

impl RawByteLink for GodotNearbyLink {
    fn send_raw(&mut self, peer_tag: &str, bytes: &[u8]) -> EngineResult<()> {
        let mut q = self.queue.lock().unwrap();
        q.outgoing_sends
            .push((peer_tag.to_string(), bytes.to_vec()));
        Ok(())
    }

    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()> {
        let mut q = self.queue.lock().unwrap();
        q.outgoing_broadcasts.push(bytes.to_vec());
        Ok(())
    }

    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)> {
        let mut q = self.queue.lock().unwrap();
        std::mem::take(&mut q.incoming)
    }

    fn poll_link_events(&mut self) -> Vec<RawLinkEvent> {
        let mut q = self.queue.lock().unwrap();
        std::mem::take(&mut q.events)
    }
}

#[derive(Clone)]
struct TournamentMatch {
    player1: PlayerId,
    player2: PlayerId,
    round: usize,
}

enum BridgeMode {
    None,
    Local {
        session: Session,
        ai_player: Option<PlayerId>,
    },
    Host {
        session: Session,
        transport: TcpHostTransport,
    },
    Client {
        transport: TcpClientTransport,
        player_id: PlayerId,
        client_current_player: i64,
    },
    Spectator {
        transport: TcpClientTransport,
    },
    NativeHost {
        session: Session,
        transport: NativeHostTransport<GodotNearbyLink>,
        queue: Arc<Mutex<SharedLinkQueue>>,
    },
    NativeClient {
        transport: NativeClientTransport<GodotNearbyLink>,
        player_id: PlayerId,
        queue: Arc<Mutex<SharedLinkQueue>>,
        handshake_complete: bool,
    },
    Replay {
        session: Session,
        pending_commands: Vec<open_table_engine::session::LoggedCommand>,
    },
    Tournament {
        game_type: String,
        #[allow(dead_code)]
        players: Vec<PlayerId>,
        #[allow(dead_code)]
        rounds: usize,
        matches: Vec<TournamentMatch>,
        current_match_idx: usize,
        session: Session,
        scores: std::collections::HashMap<PlayerId, i32>,
    },
    MultiSession {
        sessions: Vec<(String, Session)>,
        active: usize,
    },
}

fn create_session_for_players(game_type: &str, p1: PlayerId, p2: PlayerId) -> Option<Session> {
    let id = SessionId(1);
    let seed = 1;
    match game_type.to_lowercase().as_str() {
        "checkers" => Some(new_checkers_session(id, seed, p1, p2)),
        "chess" => Some(new_chess_session(id, seed, p1, p2)),
        "shogi" => Some(new_shogi_session(id, seed, p1, p2)),
        "xiangqi" => Some(new_xiangqi_session(id, seed, p1, p2)),
        "go" => Some(new_go_session(id, seed, p1, p2)),
        "uno" => Some(new_uno_session(id, seed, vec![p1, p2])),
        "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => {
            Some(new_chinese_checkers_session(id, seed, vec![p1, p2]))
        }
        "mille_bornes" | "mille-bornes" | "millebornes" => {
            Some(new_mille_bornes_session(id, seed, p1, p2))
        }
        "backgammon" => Some(new_backgammon_session(id, seed, p1, p2)),
        "monopoly" => Some(new_monopoly_session(id, seed, p1, p2)),
        "ludo" => Some(new_ludo_session(id, seed, vec![p1, p2])),
        "battleship" => Some(new_battleship_session(id, seed, p1, p2)),
        _ => None,
    }
}

fn create_initial_session(game_type: &str) -> Option<Session> {
    let id = SessionId(1);
    let seed = 1;
    let p1 = PlayerId(1);
    let p2 = PlayerId(2);
    match game_type.to_lowercase().as_str() {
        "checkers" => Some(new_checkers_session(id, seed, p1, p2)),
        "chess" => Some(new_chess_session(id, seed, p1, p2)),
        "shogi" => Some(new_shogi_session(id, seed, p1, p2)),
        "xiangqi" => Some(new_xiangqi_session(id, seed, p1, p2)),
        "go" => Some(new_go_session(id, seed, p1, p2)),
        "uno" => Some(new_uno_session(id, seed, vec![p1, p2])),
        "crisis" => new_crisis_session(id, seed, &[p1, p2]).ok(),
        "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => {
            Some(new_chinese_checkers_session(id, seed, vec![p1, p2]))
        }
        "mille_bornes" | "mille-bornes" | "millebornes" => {
            Some(new_mille_bornes_session(id, seed, p1, p2))
        }
        "backgammon" => Some(new_backgammon_session(id, seed, p1, p2)),
        "monopoly" => Some(new_monopoly_session(id, seed, p1, p2)),
        "ludo" => Some(new_ludo_session(id, seed, vec![p1, p2])),
        "battleship" => Some(new_battleship_session(id, seed, p1, p2)),
        _ => None,
    }
}

fn parse_command_json(
    json_str: &str,
    current_game_type: &str,
) -> Result<Box<dyn Command>, serde_json::Error> {
    if let Ok(cmd) = serde_json::from_str::<Box<dyn Command>>(json_str) {
        return Ok(cmd);
    }

    if let Ok(mut val) = serde_json::from_str::<serde_json::Value>(json_str) {
        if let Some(obj) = val.as_object_mut() {
            if !obj.contains_key("command_type") {
                if let Some(t) = obj.get("type").cloned() {
                    obj.insert("command_type".to_string(), t);
                }
            }
            if let Some(serde_json::Value::String(ct)) = obj.get("command_type").cloned() {
                if !ct.contains("::") {
                    let dynamic_prefix = if !current_game_type.is_empty() {
                        format!("{current_game_type}_game::")
                    } else {
                        String::new()
                    };
                    let base_prefixes = [
                        "chess_game::",
                        "checkers_game::",
                        "backgammon_game::",
                        "shogi_game::",
                        "xiangqi_game::",
                        "go_game::",
                        "uno_game::",
                        "crisis_game::",
                        "ludo_game::",
                        "chinese_checkers_game::",
                        "mille_bornes_game::",
                        "monopoly_game::",
                        "battleship_game::",
                        "open_table_engine::",
                        "open_table_core::",
                    ];
                    let mut prefixes = Vec::new();
                    if !dynamic_prefix.is_empty() {
                        prefixes.push(dynamic_prefix.as_str());
                    }
                    for p in base_prefixes {
                        if p != dynamic_prefix {
                            prefixes.push(p);
                        }
                    }
                    for prefix in prefixes {
                        let mut test_val = val.clone();
                        if let Some(test_obj) = test_val.as_object_mut() {
                            test_obj.insert(
                                "command_type".to_string(),
                                serde_json::Value::String(format!("{prefix}{ct}")),
                            );
                        }
                        if let Ok(new_str) = serde_json::to_string(&test_val) {
                            if let Ok(cmd) = serde_json::from_str::<Box<dyn Command>>(&new_str) {
                                return Ok(cmd);
                            }
                        }
                    }
                } else if let Ok(new_str) = serde_json::to_string(&val) {
                    if let Ok(cmd) = serde_json::from_str::<Box<dyn Command>>(&new_str) {
                        return Ok(cmd);
                    }
                }
            }
        }
    }

    serde_json::from_str::<Box<dyn Command>>(json_str)
}

#[derive(GodotClass)]
#[class(base=Node)]
pub struct OpenTableBridge {
    base: Base<Node>,
    mode: BridgeMode,
    current_game_type: String,
    undone_commands: Vec<(PlayerId, String)>,
    recent_events: Vec<Dictionary>,
    chess_ai_depth: u8,
}

#[godot_api]
impl INode for OpenTableBridge {
    fn init(base: Base<Node>) -> Self {
        Self {
            base,
            mode: BridgeMode::None,
            current_game_type: String::from("checkers"),
            undone_commands: Vec::new(),
            recent_events: Vec::new(),
            chess_ai_depth: 3,
        }
    }

    fn process(&mut self, _delta: f64) {
        self.poll_events();
    }
}

#[godot_api]
impl OpenTableBridge {
    // --- SIGNALS ---
    #[signal]
    fn piece_moved(
        player: i64,
        from_row: i64,
        from_col: i64,
        to_row: i64,
        to_col: i64,
        captured_row: i64,
        captured_col: i64,
        promoted: bool,
    );

    #[signal]
    fn token_moved(player: i64, token_index: i64, from_steps: i64, to_steps: i64, finished: bool);

    #[signal]
    fn checker_moved(player: i64, from: i64, to: i64, captured_opponent: bool, borne_off: bool);

    #[signal]
    fn shot_result(player: i64, row: i64, col: i64, is_hit: bool);

    #[signal]
    fn game_over(winner: i64);

    #[signal]
    fn move_rejected(reason: GString);

    #[signal]
    fn peer_joined(player_id: i64);

    #[signal]
    fn player_joined(player_id: i64);

    #[signal]
    fn peer_disconnected(player_id: i64);

    #[signal]
    fn connected(player_id: i64);

    #[signal]
    fn disconnected();

    #[signal]
    fn native_send_requested(peer_tag: GString, bytes: PackedByteArray);

    #[signal]
    fn native_broadcast_requested(bytes: PackedByteArray);

    #[signal]
    fn native_handshake_established(player_id: i64, token: GString);

    #[signal]
    fn event_json(json: GString);

    #[signal]
    fn turn_changed(player_id: i64);

    #[signal]
    fn spectator_event_received(event_json: GString);

    #[signal]
    fn territory_conquered(player_id: i64, territory_id: i64, from_armies: i64, to_armies: i64);

    #[signal]
    fn attack_resolved(
        from_id: i64,
        to_id: i64,
        attacker_rolls: VariantArray,
        defender_rolls: VariantArray,
        attacker_losses: i64,
        defender_losses: i64,
    );

    #[signal]
    fn armies_placed(player_id: i64, territory_id: i64, count: i64, remaining: i64);

    #[signal]
    fn player_eliminated(player_id: i64, by_player_id: i64);

    #[signal]
    fn phase_changed(player_id: i64, new_phase: GString);

    #[signal]
    fn cards_exchanged(player_id: i64, armies_gained: i64);

    #[signal]
    fn crisis_game_over(winner_id: i64, objective: GString);

    #[signal]
    fn tournament_match_started(player1: i64, player2: i64, round: i64);

    #[signal]
    fn tournament_match_ended(winner: i64, round: i64);

    #[signal]
    fn tournament_over(standings: Dictionary);

    // ------------------------------------------------------------------
    // LOCAL (hotseat)
    // ------------------------------------------------------------------
    #[func]
    pub fn start_local_match(&mut self, player_top_id: i64, player_bottom_id: i64) {
        self.recent_events.clear();
        self.undone_commands.clear();
        self.current_game_type = "checkers".to_string();
        let session = new_checkers_session(
            SessionId(1),
            1,
            PlayerId(player_top_id as u32),
            PlayerId(player_bottom_id as u32),
        );
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_checkers(&mut self, player_top_id: i64, player_bottom_id: i64) {
        self.start_local_match(player_top_id, player_bottom_id);
    }

    #[func]
    fn start_local_match_checkers_vs_ai(
        &mut self,
        seed: i64,
        human_player: i64,
        ai_player: i64,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "checkers".to_string();
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);

        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_checkers_session(SessionId(1), seed as u64, p1, p2);
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };

        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        self.process_ai_turn_if_needed();

        true
    }

    #[func]
    fn start_local_match_shogi(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "shogi".to_string();
        let session = new_shogi_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_shogi_vs_ai(
        &mut self,
        human_player: i64,
        ai_player: i64,
        #[opt] _depth: Option<i64>,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "shogi".to_string();
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);

        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_shogi_session(SessionId(1), 1, p1, p2);
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };

        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        self.process_ai_turn_if_needed();

        true
    }

    #[func]
    fn start_local_match_xiangqi(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "xiangqi".to_string();
        let session =
            new_xiangqi_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_xiangqi_vs_ai(
        &mut self,
        human_player: i64,
        ai_player: i64,
        #[opt] _depth: Option<i64>,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "xiangqi".to_string();
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);

        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_xiangqi_session(SessionId(1), 1, p1, p2);
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };

        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        self.process_ai_turn_if_needed();

        true
    }

    #[func]
    fn start_local_match_go(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "go".to_string();
        let session = new_go_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_go_vs_ai(
        &mut self,
        human_player: i64,
        ai_player: i64,
        #[opt] board_size: Option<i64>,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "go".to_string();
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);

        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let size = board_size.unwrap_or(9);
        let size = if size > 0 { size as usize } else { 9 };
        let mut session = new_go_session(SessionId(1), 1, p1, p2);
        if size != 9 {
            let board = go_game::BoardResource::new(size, p1, p2);
            let mut history = go_game::BoardHistoryResource::new();
            history.history.insert(board.compute_hash());
            session.world_mut().insert_resource(board);
            session.world_mut().insert_resource(history);
        }
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };

        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        self.process_ai_turn_if_needed();

        true
    }

    #[func]
    fn start_local_match_uno(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "uno".to_string();
        let session = new_uno_session(
            SessionId(1),
            1,
            vec![PlayerId(p1 as u32), PlayerId(p2 as u32)],
        );
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    fn parse_player_ids(players: &Variant) -> Vec<PlayerId> {
        if let Ok(arr) = players.try_to::<Array<i64>>() {
            arr.iter_shared().map(|p| PlayerId(p as u32)).collect()
        } else if let Ok(arr) = players.try_to::<VariantArray>() {
            arr.iter_shared()
                .filter_map(|p| p.try_to::<i64>().ok())
                .map(|p| PlayerId(p as u32))
                .collect()
        } else if let Ok(arr) = players.try_to::<PackedInt64Array>() {
            arr.as_slice().iter().map(|&p| PlayerId(p as u32)).collect()
        } else {
            Vec::new()
        }
    }

    #[func]
    fn start_local_match_crisis(&mut self, seed: i64, players: Variant) -> bool {
        let player_ids = Self::parse_player_ids(&players);
        if !(2..=6).contains(&player_ids.len()) {
            return false;
        }
        self.current_game_type = "crisis".to_string();
        let session = match new_crisis_session(SessionId(1), seed as u64, &player_ids) {
            Ok(s) => s,
            Err(_) => return false,
        };
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
        true
    }

    #[func]
    fn start_local_match_chess(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "chess".to_string();
        let session = new_chess_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    pub fn set_chess_ai_depth(&mut self, depth: i64) {
        self.chess_ai_depth = depth.clamp(1, 10) as u8;
    }

    #[func]
    fn start_local_match_chess_vs_ai(
        &mut self,
        human_player: i64,
        ai_player: i64,
        depth: i64,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "chess".to_string();
        self.chess_ai_depth = depth.clamp(1, 10) as u8;
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);

        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_chess_session(SessionId(1), 1, p1, p2);
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };

        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        self.process_ai_turn_if_needed();

        true
    }

    #[func]
    fn start_local_match_chinese_checkers(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "chinese_checkers".to_string();
        let session = new_chinese_checkers_session(
            SessionId(1),
            1,
            vec![PlayerId(p1 as u32), PlayerId(p2 as u32)],
        );
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_mille_bornes(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "mille_bornes".to_string();
        let session =
            new_mille_bornes_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_backgammon(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "backgammon".to_string();
        let session =
            new_backgammon_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_backgammon_vs_ai(
        &mut self,
        human_player: i64,
        ai_player: i64,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "backgammon".to_string();
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);

        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_backgammon_session(SessionId(1), 1, p1, p2);
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };

        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        self.process_ai_turn_if_needed();

        true
    }

    #[func]
    fn start_local_match_monopoly(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "monopoly".to_string();
        let session =
            new_monopoly_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_ludo(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "ludo".to_string();
        let session = new_ludo_session(
            SessionId(1),
            1,
            vec![PlayerId(p1 as u32), PlayerId(p2 as u32)],
        );
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_ludo_vs_ai(&mut self, human: i64, ai: i64) -> bool {
        if human == ai || human <= 0 || ai <= 0 {
            return false;
        }

        self.current_game_type = "ludo".to_string();
        let p_human = PlayerId(human as u32);
        let p_ai = PlayerId(ai as u32);

        let (p1, p2) = if human < ai {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_ludo_session(SessionId(1), 1, vec![p1, p2]);
        let current_p = session.current_player().0 as i64;
        self.mode = BridgeMode::Local {
            session,
            ai_player: Some(p_ai),
        };

        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        self.process_ai_turn_if_needed();

        true
    }

    #[func]
    fn start_local_match_battleship(&mut self, p1: i64, p2: i64) {
        self.current_game_type = "battleship".to_string();
        let session =
            new_battleship_session(SessionId(1), 1, PlayerId(p1 as u32), PlayerId(p2 as u32));
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_tournament(&mut self, game_type: GString, players: Variant, rounds: i64) -> bool {
        let p_vec = Self::parse_player_ids(&players);
        if p_vec.len() < 2 || rounds < 1 {
            return false;
        }

        let gt = game_type.to_string();

        let mut matches = Vec::new();
        for r in 1..=(rounds as usize) {
            for i in 0..p_vec.len() {
                for j in (i + 1)..p_vec.len() {
                    matches.push(TournamentMatch {
                        player1: p_vec[i],
                        player2: p_vec[j],
                        round: r,
                    });
                }
            }
        }

        if matches.is_empty() {
            return false;
        }

        let first_match = &matches[0];
        let session =
            match create_session_for_players(&gt, first_match.player1, first_match.player2) {
                Some(s) => s,
                None => return false,
            };

        let mut scores = std::collections::HashMap::new();
        for &p in &p_vec {
            scores.insert(p, 0);
        }

        let first_p1 = first_match.player1.0 as i64;
        let first_p2 = first_match.player2.0 as i64;
        let first_round = first_match.round as i64;
        let first_turn = session.current_player().0 as i64;

        self.mode = BridgeMode::Tournament {
            game_type: gt,
            players: p_vec,
            rounds: rounds as usize,
            matches,
            current_match_idx: 0,
            session,
            scores,
        };

        self.base_mut().emit_signal(
            "tournament_match_started",
            &[
                Variant::from(first_p1),
                Variant::from(first_p2),
                Variant::from(first_round),
            ],
        );
        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(first_turn)]);

        true
    }

    #[func]
    fn start_multi_session(&mut self) {
        self.mode = BridgeMode::MultiSession {
            sessions: Vec::new(),
            active: 0,
        };
    }

    #[func]
    fn add_multi_session(
        &mut self,
        game_id: GString,
        game_type: GString,
        p1: i64,
        p2: i64,
    ) -> bool {
        let gid = game_id.to_string();
        let gtype = game_type.to_string();
        let p1_id = PlayerId(p1 as u32);
        let p2_id = PlayerId(p2 as u32);
        let session = match create_session_for_players(&gtype, p1_id, p2_id) {
            Some(s) => s,
            None => return false,
        };

        match &mut self.mode {
            BridgeMode::MultiSession { sessions, .. } => {
                if let Some(pos) = sessions.iter().position(|(id, _)| id == &gid) {
                    sessions[pos].1 = session;
                } else {
                    sessions.push((gid, session));
                }
                true
            }
            _ => {
                self.mode = BridgeMode::MultiSession {
                    sessions: vec![(gid, session)],
                    active: 0,
                };
                true
            }
        }
    }

    #[func]
    fn switch_session(&mut self, game_id: GString) -> bool {
        let gid = game_id.to_string();
        if let BridgeMode::MultiSession { sessions, active } = &mut self.mode {
            if let Some(pos) = sessions.iter().position(|(id, _)| id == &gid) {
                *active = pos;
                return true;
            }
        }
        false
    }

    #[func]
    fn get_active_game_id(&self) -> GString {
        if let BridgeMode::MultiSession { sessions, active } = &self.mode {
            if let Some((gid, _)) = sessions.get(*active) {
                return GString::from(gid);
            }
        }
        GString::from("")
    }

    #[func]
    fn load_chess_fen(&mut self, fen: GString) -> bool {
        match &mut self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                chess_game::load_chess_position_from_fen(session, &fen.to_string()).is_ok()
            }
            BridgeMode::MultiSession { sessions, active } => {
                if let Some((_, session)) = sessions.get_mut(*active) {
                    chess_game::load_chess_position_from_fen(session, &fen.to_string()).is_ok()
                } else {
                    false
                }
            }
            _ => false,
        }
    }

    #[func]
    fn export_chess_pgn(&self) -> GString {
        let pgn_opt = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::Tournament { session, .. } => session.export_chess_pgn(),
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .and_then(|(_, s)| s.export_chess_pgn()),
            _ => None,
        };
        GString::from(pgn_opt.unwrap_or_default())
    }

    // ------------------------------------------------------------------
    // HOST TCP
    // ------------------------------------------------------------------
    #[func]
    pub fn start_hosting(&mut self, port: i64, player_top_id: i64, player_bottom_id: i64) {
        let session = new_checkers_session(
            SessionId(1),
            1,
            PlayerId(player_top_id as u32),
            PlayerId(player_bottom_id as u32),
        );
        let socket_addr: std::net::SocketAddr = format!("0.0.0.0:{}", port)
            .parse()
            .expect("puerto inválido");
        let transport =
            TcpHostTransport::bind_with_timeout(socket_addr, std::time::Duration::from_secs(60))
                .expect("no pude crear host");
        self.mode = BridgeMode::Host { session, transport };
        godot_print!("✅ Host escuchando en puerto {}", port);
    }

    #[func]
    fn get_join_qr_svg(
        &self,
        join_code: GString,
        host_name: GString,
        game_type: GString,
    ) -> GString {
        let payload = open_table_qr::JoinPayload {
            session_id: open_table_core::ids::SessionId(1),
            join_code: join_code.to_string(),
            host_name: host_name.to_string(),
            game_type: game_type.to_string(),
        };
        match open_table_qr::generate_join_qr_svg(&payload) {
            Ok(svg) => GString::from(svg),
            Err(_) => GString::from(""),
        }
    }

    #[func]
    fn generate_join_qr_svg(
        &self,
        join_code: GString,
        host_name: GString,
        game_type: GString,
    ) -> GString {
        self.get_join_qr_svg(join_code, host_name, game_type)
    }

    // ------------------------------------------------------------------
    // CLIENT TCP
    // ------------------------------------------------------------------
    #[func]
    fn connect_as_client(&mut self, host: GString, port: i64) -> bool {
        self.connect_to_host(host, port, GString::from("Jugador"))
    }

    #[func]
    pub fn connect_to_host(&mut self, host: GString, port: i64, player_name: GString) -> bool {
        let addr = format!("{}:{}", host.to_string(), port);
        match TcpClientTransport::connect_as_new_player(&addr, &player_name.to_string()) {
            Ok((transport, player_id, reconnect_token)) => {
                self.mode = BridgeMode::Client {
                    transport,
                    player_id,
                    client_current_player: 1,
                };
                self.base_mut()
                    .emit_signal("connected", &[Variant::from(player_id.0 as i64)]);
                self.base_mut().emit_signal(
                    "native_handshake_established",
                    &[
                        Variant::from(player_id.0 as i64),
                        Variant::from(reconnect_token),
                    ],
                );
                true
            }
            Err(_) => false,
        }
    }

    #[func]
    pub fn reconnect_to_host(
        &mut self,
        host: GString,
        port: i64,
        arg3: Variant,
        arg4: Variant,
    ) -> bool {
        let addr = format!("{}:{}", host.to_string(), port);
        let mut player_id = PlayerId(2);
        let mut token = String::new();

        if let Ok(pid) = arg3.try_to::<i64>() {
            player_id = PlayerId(pid as u32);
            token = arg4.to_string();
        } else if let Ok(tok) = arg3.try_to::<GString>() {
            token = tok.to_string();
            if let Ok(pid) = arg4.try_to::<i64>() {
                player_id = PlayerId(pid as u32);
            }
        }

        match TcpClientTransport::reconnect(&addr, player_id, token) {
            Ok(transport) => {
                self.mode = BridgeMode::Client {
                    transport,
                    player_id,
                    client_current_player: 2,
                };
                self.base_mut()
                    .emit_signal("connected", &[Variant::from(player_id.0 as i64)]);
                true
            }
            Err(_) => false,
        }
    }

    #[func]
    pub fn is_connected_to_host(&self) -> bool {
        matches!(self.mode, BridgeMode::Client { .. })
    }

    #[func]
    pub fn disconnect_from_host(&mut self) {
        if matches!(
            self.mode,
            BridgeMode::Client { .. } | BridgeMode::Spectator { .. }
        ) {
            self.mode = BridgeMode::None;
            self.base_mut().emit_signal("disconnected", &[]);
        }
    }

    #[func]
    fn start_spectating(&mut self, host_addr: GString) -> bool {
        let addr = host_addr.to_string();
        match TcpClientTransport::connect_as_new_player(&addr, "Spectator") {
            Ok((transport, _player_id, _reconnect_token)) => {
                self.mode = BridgeMode::Spectator { transport };
                true
            }
            Err(_) => false,
        }
    }

    #[func]
    fn my_player_id(&self) -> i64 {
        match &self.mode {
            BridgeMode::Client { player_id, .. } => player_id.0 as i64,
            BridgeMode::NativeClient { player_id, .. } => player_id.0 as i64,
            _ => -1,
        }
    }

    #[func]
    fn is_native_connected(&self) -> bool {
        match &self.mode {
            BridgeMode::NativeClient {
                handshake_complete, ..
            } => *handshake_complete,
            BridgeMode::NativeHost { .. } => true,
            _ => false,
        }
    }

    #[func]
    fn send_move_client(&mut self, from_row: i64, from_col: i64, to_row: i64, to_col: i64) {
        let command_parts = match &self.mode {
            BridgeMode::Client { player_id, .. } => Some(*player_id),
            BridgeMode::NativeClient {
                player_id,
                handshake_complete,
                ..
            } if *handshake_complete => Some(*player_id),
            _ => None,
        };
        let Some(player_id) = command_parts else {
            return;
        };

        let command: Box<dyn Command> = Box::new(MovePieceCommand {
            player: player_id,
            from: Position::new(from_row as u8, from_col as u8),
            to: Position::new(to_row as u8, to_col as u8),
        });

        if let Ok(serialized) = serde_json::to_vec(&command) {
            match &mut self.mode {
                BridgeMode::Client { transport, .. } => {
                    let _ = transport.send(open_table_transport_tcp::HOST_PLAYER_ID, &serialized);
                }
                BridgeMode::NativeClient { transport, .. } => {
                    let _ = transport.send(
                        open_table_transport_native_bridge::HOST_PLAYER_ID,
                        &serialized,
                    );
                }
                _ => {}
            }
        }
    }

    // ------------------------------------------------------------------
    // NATIVE BRIDGE (Android Nearby Connections / iOS Multipeer)
    // ------------------------------------------------------------------
    #[func]
    fn start_native_hosting(&mut self, player_top_id: i64, player_bottom_id: i64) {
        let session = new_checkers_session(
            SessionId(1),
            1,
            PlayerId(player_top_id as u32),
            PlayerId(player_bottom_id as u32),
        );
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotNearbyLink {
            queue: queue.clone(),
        };
        let transport = NativeHostTransport::new(link);
        self.mode = BridgeMode::NativeHost {
            session,
            transport,
            queue,
        };
        godot_print!("✅ Native Host iniciado");
    }

    #[func]
    fn start_native_client(&mut self, player_name: GString) {
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotNearbyLink {
            queue: queue.clone(),
        };
        let transport = NativeClientTransport::begin_join(link, &player_name.to_string())
            .expect("no pude iniciar handshake nativo");
        self.mode = BridgeMode::NativeClient {
            transport,
            player_id: PlayerId(0),
            queue,
            handshake_complete: false,
        };
        godot_print!("✅ Handshake nativo iniciado");
    }

    #[func]
    fn reconnect_native(&mut self, player_id: i64, token: GString) {
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotNearbyLink {
            queue: queue.clone(),
        };
        let pid = PlayerId(player_id as u32);
        let transport = NativeClientTransport::begin_reconnect(link, pid, token.to_string())
            .expect("no pude iniciar reconexión nativa");
        self.mode = BridgeMode::NativeClient {
            transport,
            player_id: pid,
            queue,
            handshake_complete: false,
        };
        godot_print!("✅ Reconexión nativa iniciada para PlayerId={}", player_id);
    }

    #[func]
    fn feed_native_data_received(&mut self, peer_tag: GString, bytes: PackedByteArray) {
        let incoming_bytes = bytes.to_vec();
        match &self.mode {
            BridgeMode::NativeHost { queue, .. } | BridgeMode::NativeClient { queue, .. } => {
                let mut q = queue.lock().unwrap();
                q.incoming.push((peer_tag.to_string(), incoming_bytes));
            }
            _ => {}
        }
    }

    #[func]
    fn feed_native_peer_disconnected(&mut self, peer_tag: GString) {
        match &self.mode {
            BridgeMode::NativeHost { queue, .. } | BridgeMode::NativeClient { queue, .. } => {
                let mut q = queue.lock().unwrap();
                q.events
                    .push(RawLinkEvent::Disconnected(peer_tag.to_string()));
            }
            _ => {}
        }
    }

    fn emit_bridge_signal(&mut self, signal_name: &str, args: &[Variant]) {
        if let BridgeMode::MultiSession { sessions, active } = &self.mode {
            if let Some((gid, _)) = sessions.get(*active) {
                let mut multi_args = vec![Variant::from(GString::from(gid))];
                multi_args.extend_from_slice(args);
                self.base_mut().emit_signal(signal_name, &multi_args);
                return;
            }
        }
        self.base_mut().emit_signal(signal_name, args);
    }

    fn process_and_emit(
        &mut self,
        sender: PlayerId,
        command: Box<dyn Command>,
    ) -> EngineResult<Vec<Box<dyn Event>>> {
        let (prev_player, result) = match &mut self.mode {
            BridgeMode::Local { session, .. } => {
                let prev = session.current_player();
                let res = session.process_command(sender, command);
                (prev, res)
            }
            BridgeMode::Host { session, .. } => {
                let prev = session.current_player();
                let res = session.process_command(sender, command);
                (prev, res)
            }
            BridgeMode::NativeHost { session, .. } => {
                let prev = session.current_player();
                let res = session.process_command(sender, command);
                (prev, res)
            }
            BridgeMode::Replay { session, .. } => {
                let prev = session.current_player();
                let res = session.process_command(sender, command);
                (prev, res)
            }
            BridgeMode::Tournament { session, .. } => {
                let prev = session.current_player();
                let res = session.process_command(sender, command);
                (prev, res)
            }
            BridgeMode::MultiSession { sessions, active } => {
                if let Some((_, session)) = sessions.get_mut(*active) {
                    let prev = session.current_player();
                    let res = session.process_command(sender, command);
                    (prev, res)
                } else {
                    return Err(EngineError::InvalidCommand {
                        reason: "No active session in MultiSession".into(),
                    });
                }
            }
            _ => {
                return Err(EngineError::InvalidCommand {
                    reason: "El modo no soporta comandos".into(),
                })
            }
        };

        match &result {
            Ok(events) => {
                self.emit_game_events(events);
                let new_player = match &self.mode {
                    BridgeMode::Local { session, .. } => session.current_player(),
                    BridgeMode::Host { session, .. } => session.current_player(),
                    BridgeMode::NativeHost { session, .. } => session.current_player(),
                    BridgeMode::Replay { session, .. } => session.current_player(),
                    BridgeMode::Tournament { session, .. } => session.current_player(),
                    BridgeMode::MultiSession { sessions, active } => sessions
                        .get(*active)
                        .map(|(_, s)| s.current_player())
                        .unwrap_or(prev_player),
                    _ => prev_player,
                };
                if new_player != prev_player {
                    self.emit_bridge_signal("turn_changed", &[Variant::from(new_player.0 as i64)]);
                }
            }
            Err(err) => {
                godot_error!("[EngineError] {}", err);
                self.emit_bridge_signal("move_rejected", &[Variant::from(err.to_string())]);
            }
        }

        result
    }

    // ------------------------------------------------------------------
    // UNIVERSAL COMMANDS & STATE
    // ------------------------------------------------------------------
    #[func]
    pub fn send_command_json(
        &mut self,
        player_or_json: Variant,
        #[opt] maybe_json: Option<GString>,
    ) {
        let (player_id, json_str) = if let Some(j) = maybe_json {
            let pid = player_or_json
                .try_to::<i64>()
                .unwrap_or_else(|_| self.current_player());
            (PlayerId(pid as u32), j.to_string())
        } else if let Ok(j) = player_or_json.try_to::<GString>() {
            let s = j.to_string();
            let pid = if let Ok(v) = serde_json::from_str::<serde_json::Value>(&s) {
                v.get("player")
                    .and_then(|p| p.as_i64())
                    .unwrap_or_else(|| self.current_player())
            } else {
                self.current_player()
            };
            (PlayerId(pid as u32), s)
        } else {
            return;
        };

        let command: Box<dyn Command> =
            match parse_command_json(&json_str, &self.current_game_type) {
                Ok(cmd) => cmd,
                Err(e) => {
                    let msg = format!("Error parsing command JSON: {e}");
                    godot_error!("[EngineError] {}", msg);
                    self.emit_bridge_signal("move_rejected", &[Variant::from(msg)]);
                    return;
                }
            };

        if let Ok(events) = self.process_and_emit(player_id, command) {
            match &mut self.mode {
                BridgeMode::Host { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                BridgeMode::NativeHost { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                _ => {}
            }
        }
        self.process_ai_turn_if_needed();
    }

    #[func]
    pub fn get_legal_moves(&self, player_id: i64) -> Array<Dictionary> {
        let player = PlayerId(player_id as u32);
        let moves_json = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => session.get_legal_moves(player),
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .map(|(_, s)| s.get_legal_moves(player))
                .unwrap_or_default(),
            _ => vec![],
        };

        let mut godot_array = Array::new();
        for val in moves_json {
            if let Ok(json_str) = serde_json::to_string(&val) {
                let parsed_var = godot::classes::Json::parse_string(&GString::from(&json_str));
                if let Ok(dict) = parsed_var.try_to::<Dictionary>() {
                    godot_array.push(&dict);
                }
            }
        }
        godot_array
    }

    #[func]
    pub fn compute_elo_delta(
        &self,
        _winner_id: i64,
        _loser_id: i64,
        winner_current: f64,
        loser_current: f64,
        k: f64,
    ) -> Array<f64> {
        let (new_winner, new_loser) = open_table_engine::elo::update_elo(
            open_table_engine::elo::EloRating(winner_current),
            open_table_engine::elo::EloRating(loser_current),
            k,
        );
        let mut result = Array::new();
        result.push(new_winner.0);
        result.push(new_loser.0);
        result
    }

    #[func]
    fn send_move(&mut self, player: i64, from_row: i64, from_col: i64, to_row: i64, to_col: i64) {
        let player_id = PlayerId(player as u32);
        let command: Box<dyn Command> = Box::new(MovePieceCommand {
            player: player_id,
            from: Position::new(from_row as u8, from_col as u8),
            to: Position::new(to_row as u8, to_col as u8),
        });

        if let Ok(events) = self.process_and_emit(player_id, command) {
            match &mut self.mode {
                BridgeMode::Host { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                BridgeMode::NativeHost { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                _ => {}
            }
        }
        self.process_ai_turn_if_needed();
    }

    #[func]
    pub fn save_game(&self, filename: GString) -> bool {
        let mut path = filename.to_string();
        if path.starts_with("user://") {
            let user_dir = godot::classes::Os::singleton()
                .get_user_data_dir()
                .to_string();
            let fname = path.trim_start_matches("user://");
            path = format!("{}/{}", user_dir, fname);
        }
        match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::Tournament { session, .. } => session.save_to_file(&path).is_ok(),
            BridgeMode::MultiSession { sessions, active } => {
                if let Some((_, s)) = sessions.get(*active) {
                    s.save_to_file(&path).is_ok()
                } else {
                    false
                }
            }
            _ => false,
        }
    }

    #[func]
    pub fn load_game(&mut self, filename: GString) -> bool {
        let mut path = filename.to_string();
        if path.starts_with("user://") {
            let user_dir = godot::classes::Os::singleton()
                .get_user_data_dir()
                .to_string();
            let fname = path.trim_start_matches("user://");
            path = format!("{}/{}", user_dir, fname);
        }

        let game_type = if self.current_game_type.is_empty() {
            "checkers"
        } else {
            &self.current_game_type
        };

        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let (id, seed, players, rules) = match game_type.to_lowercase().as_str() {
            "checkers" => (
                SessionId(1),
                1,
                vec![p1, p2],
                checkers_game::build_checkers_rules(),
            ),
            "chess" => (
                SessionId(1),
                1,
                vec![p1, p2],
                chess_game::build_chess_rules(),
            ),
            "shogi" => (
                SessionId(1),
                1,
                vec![p1, p2],
                shogi_game::build_shogi_rules(),
            ),
            "xiangqi" => (
                SessionId(1),
                1,
                vec![p1, p2],
                xiangqi_game::build_xiangqi_rules(),
            ),
            "go" => (SessionId(1), 1, vec![p1, p2], go_game::build_go_rules()),
            "uno" => (SessionId(1), 1, vec![p1, p2], uno_game::build_uno_rules()),
            "crisis" => (
                SessionId(1),
                1,
                vec![p1, p2],
                crisis_game::build_crisis_rules(),
            ),
            "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => (
                SessionId(1),
                1,
                vec![p1, p2],
                chinese_checkers_game::build_chinese_checkers_rules(),
            ),
            "mille_bornes" | "mille-bornes" | "millebornes" => (
                SessionId(1),
                1,
                vec![p1, p2],
                mille_bornes_game::build_mille_bornes_rules(),
            ),
            "backgammon" => (
                SessionId(1),
                1,
                vec![p1, p2],
                backgammon_game::build_backgammon_rules(),
            ),
            "monopoly" => (
                SessionId(1),
                1,
                vec![p1, p2],
                monopoly_game::build_monopoly_rules(),
            ),
            "ludo" => (SessionId(1), 1, vec![p1, p2], ludo_game::build_ludo_rules()),
            "battleship" => (
                SessionId(1),
                1,
                vec![p1, p2],
                battleship_game::build_battleship_rules(),
            ),
            _ => (
                SessionId(1),
                1,
                vec![p1, p2],
                checkers_game::build_checkers_rules(),
            ),
        };

        let log_bytes = match std::fs::read(&path) {
            Ok(b) => b,
            Err(_) => return false,
        };

        match Session::replay_collecting_events(id, seed, players, rules, &log_bytes) {
            Ok((loaded_session, events)) => {
                let current_p = loaded_session.current_player().0 as i64;
                self.mode = BridgeMode::Local {
                    session: loaded_session,
                    ai_player: None,
                };
                self.emit_game_events(&events);
                self.base_mut()
                    .emit_signal("turn_changed", &[Variant::from(current_p)]);
                true
            }
            Err(_) => false,
        }
    }

    #[func]
    pub fn export_log(&self) -> PackedByteArray {
        let log_bytes = match &self.mode {
            BridgeMode::Local { session, .. } => session.export_log().unwrap_or_default(),
            BridgeMode::Host { session, .. } => session.export_log().unwrap_or_default(),
            BridgeMode::NativeHost { session, .. } => session.export_log().unwrap_or_default(),
            BridgeMode::Replay { session, .. } => session.export_log().unwrap_or_default(),
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .and_then(|(_, s)| s.export_log().ok())
                .unwrap_or_default(),
            _ => vec![],
        };
        let mut packed = PackedByteArray::new();
        for b in log_bytes {
            packed.push(b);
        }
        packed
    }

    #[func]
    pub fn load_replay(&mut self, log_bytes: PackedByteArray, game_type: GString) -> bool {
        let bytes = log_bytes.to_vec();
        let log: Vec<open_table_engine::session::LoggedCommand> =
            match serde_json::from_slice(&bytes) {
                Ok(l) => l,
                Err(_) => return false,
            };

        let initial_session = match create_initial_session(&game_type.to_string()) {
            Some(s) => s,
            None => return false,
        };

        let test_session = match create_initial_session(&game_type.to_string()) {
            Some(s) => s,
            None => return false,
        };

        if Session::replay_on_session(test_session, &bytes).is_err() {
            return false;
        }

        self.mode = BridgeMode::Replay {
            session: initial_session,
            pending_commands: log,
        };

        true
    }

    #[func]
    pub fn step_replay(&mut self) -> bool {
        let (sender, command) = {
            let BridgeMode::Replay {
                session,
                pending_commands,
            } = &mut self.mode
            else {
                return false;
            };

            if pending_commands.is_empty() {
                return false;
            }

            let (_tick, _elapsed, command) = pending_commands.remove(0);
            let sender = command.issuer().unwrap_or_else(|| session.current_player());
            (sender, command)
        };

        self.process_and_emit(sender, command).is_ok()
    }

    #[func]
    pub fn is_multiplayer(&self) -> bool {
        matches!(
            self.mode,
            BridgeMode::Host { .. }
                | BridgeMode::Client { .. }
                | BridgeMode::NativeHost { .. }
                | BridgeMode::NativeClient { .. }
                | BridgeMode::Spectator { .. }
        )
    }

    #[func]
    pub fn can_undo(&self) -> bool {
        if self.is_multiplayer() {
            return false;
        }
        if let BridgeMode::Local { session, .. } = &self.mode {
            return session.export_log().map(|b| !b.is_empty()).unwrap_or(false);
        }
        false
    }

    #[func]
    pub fn can_redo(&self) -> bool {
        if self.is_multiplayer() {
            return false;
        }
        !self.undone_commands.is_empty()
    }

    #[func]
    pub fn undo_last_command(&mut self) -> bool {
        self.undo()
    }

    #[func]
    pub fn undo(&mut self) -> bool {
        if self.is_multiplayer() {
            return false;
        }

        let BridgeMode::Local {
            ref mut session, ..
        } = self.mode
        else {
            return false;
        };

        let log_bytes = match session.export_log() {
            Ok(b) if !b.is_empty() => b,
            _ => return false,
        };

        let logged: Vec<open_table_engine::session::LoggedCommand> = match serde_json::from_slice::<
            Vec<open_table_engine::session::LoggedCommand>,
        >(&log_bytes)
        {
            Ok(l) if !l.is_empty() => l,
            _ => return false,
        };

        let last_logged = logged.last().cloned();

        if session.undo_last_command().is_err() {
            return false;
        }

        if let Some((_, _, cmd)) = last_logged {
            let sender = cmd.issuer().unwrap_or_else(|| PlayerId(1));
            if let Ok(json_str) = serde_json::to_string(&cmd) {
                self.undone_commands.push((sender, json_str));
            }
        }

        let game_type = self.current_game_type.clone();
        let new_log_bytes = session.export_log().unwrap_or_default();
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let (id, seed, players, rules) = match game_type.to_lowercase().as_str() {
            "checkers" => (
                SessionId(1),
                1,
                vec![p1, p2],
                checkers_game::build_checkers_rules(),
            ),
            "chess" => (
                SessionId(1),
                1,
                vec![p1, p2],
                chess_game::build_chess_rules(),
            ),
            "shogi" => (
                SessionId(1),
                1,
                vec![p1, p2],
                shogi_game::build_shogi_rules(),
            ),
            "xiangqi" => (
                SessionId(1),
                1,
                vec![p1, p2],
                xiangqi_game::build_xiangqi_rules(),
            ),
            "go" => (SessionId(1), 1, vec![p1, p2], go_game::build_go_rules()),
            "uno" => (SessionId(1), 1, vec![p1, p2], uno_game::build_uno_rules()),
            "crisis" => (
                SessionId(1),
                1,
                vec![p1, p2],
                crisis_game::build_crisis_rules(),
            ),
            "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => (
                SessionId(1),
                1,
                vec![p1, p2],
                chinese_checkers_game::build_chinese_checkers_rules(),
            ),
            "mille_bornes" | "mille-bornes" | "millebornes" => (
                SessionId(1),
                1,
                vec![p1, p2],
                mille_bornes_game::build_mille_bornes_rules(),
            ),
            "backgammon" => (
                SessionId(1),
                1,
                vec![p1, p2],
                backgammon_game::build_backgammon_rules(),
            ),
            "monopoly" => (
                SessionId(1),
                1,
                vec![p1, p2],
                monopoly_game::build_monopoly_rules(),
            ),
            "ludo" => (SessionId(1), 1, vec![p1, p2], ludo_game::build_ludo_rules()),
            "battleship" => (
                SessionId(1),
                1,
                vec![p1, p2],
                battleship_game::build_battleship_rules(),
            ),
            _ => (
                SessionId(1),
                1,
                vec![p1, p2],
                checkers_game::build_checkers_rules(),
            ),
        };

        if let Ok((_, events)) =
            Session::replay_collecting_events(id, seed, players, rules, &new_log_bytes)
        {
            self.emit_game_events(&events);
        }

        let current_p = match &self.mode {
            BridgeMode::Local { session, .. } => session.current_player().0 as i64,
            _ => 1,
        };
        self.base_mut()
            .emit_signal("turn_changed", &[Variant::from(current_p)]);

        true
    }

    #[func]
    pub fn redo(&mut self) -> bool {
        if self.is_multiplayer() {
            return false;
        }

        if let Some((sender, json_str)) = self.undone_commands.pop() {
            if let Ok(cmd) = parse_command_json(&json_str, &self.current_game_type) {
                return self.process_and_emit(sender, cmd).is_ok();
            }
        }
        false
    }

    #[func]
    pub fn get_recent_events(&self) -> Array<Dictionary> {
        let mut arr = Array::new();
        for dict in &self.recent_events {
            arr.push(dict);
        }
        arr
    }

    #[func]
    pub fn current_player(&self) -> i64 {
        match &self.mode {
            BridgeMode::Local { session, .. } => session.current_player().0 as i64,
            BridgeMode::Host { session, .. } => session.current_player().0 as i64,
            BridgeMode::NativeHost { session, .. } => session.current_player().0 as i64,
            BridgeMode::Replay { session, .. } => session.current_player().0 as i64,
            BridgeMode::Tournament { session, .. } => session.current_player().0 as i64,
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .map(|(_, s)| s.current_player().0 as i64)
                .unwrap_or(-1),
            BridgeMode::Client {
                client_current_player,
                ..
            } => *client_current_player,
            _ => -1,
        }
    }

    #[func]
    pub fn current_tick(&self) -> i64 {
        match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => session.current_tick().0 as i64,
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .map(|(_, s)| s.current_tick().0 as i64)
                .unwrap_or(0),
            _ => 0,
        }
    }

    #[func]
    pub fn get_session_ticks(&self) -> i64 {
        self.current_tick()
    }

    #[func]
    pub fn session_tick_count(&self) -> i64 {
        self.current_tick()
    }

    #[func]
    pub fn get_distance(&self, player_id: i64) -> i64 {
        let p_id = PlayerId(player_id as u32);
        match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                if let Some(deck) = session.world().get_resource::<mille_bornes_game::DeckResource>() {
                    deck.distance.get(&p_id).copied().unwrap_or(0) as i64
                } else {
                    0
                }
            }
            BridgeMode::MultiSession { sessions, active } => {
                if let Some((_, session)) = sessions.get(*active) {
                    if let Some(deck) = session.world().get_resource::<mille_bornes_game::DeckResource>() {
                        deck.distance.get(&p_id).copied().unwrap_or(0) as i64
                    } else {
                        0
                    }
                } else {
                    0
                }
            }
            _ => 0,
        }
    }

    #[func]
    pub fn _process(&mut self, _delta: f64) {
        self.poll_events();
    }

    #[func]
    pub fn checkers_ai_pick_move(&mut self, player_id: i64) -> bool {
        let p_id = PlayerId(player_id as u32);
        if let BridgeMode::Local { session, .. } = &mut self.mode {
            if let Some(cmd) = checkers_game::checkers_ai_pick_move(session, p_id) {
                return self.process_and_emit(p_id, Box::new(cmd)).is_ok();
            }
        }
        false
    }

    #[func]
    pub fn chess_ai_pick_move(&mut self, player_id: i64) -> bool {
        let p_id = PlayerId(player_id as u32);
        if let BridgeMode::Local { session, .. } = &mut self.mode {
            if let Some(cmd) = chess_game::chess_ai_pick_move(session, p_id, self.chess_ai_depth) {
                return self.process_and_emit(p_id, Box::new(cmd)).is_ok();
            }
        }
        false
    }

    #[func]
    fn poll_events(&mut self) {
        match &mut self.mode {
            BridgeMode::Host { .. } => self.poll_host_events(),
            BridgeMode::Client { .. } => self.poll_client_events(),
            BridgeMode::Spectator { .. } => self.poll_spectator_events(),
            BridgeMode::NativeHost { .. } => self.poll_native_host_events(),
            BridgeMode::NativeClient { .. } => self.poll_native_client_events(),
            BridgeMode::Local { .. } => self.process_ai_turn_if_needed(),
            BridgeMode::None
            | BridgeMode::Replay { .. }
            | BridgeMode::Tournament { .. }
            | BridgeMode::MultiSession { .. } => {}
        }
        self.flush_native_outgoing();
    }

    fn poll_host_events(&mut self) {
        let BridgeMode::Host { transport, .. } = &mut self.mode else {
            return;
        };

        let connection_events = transport.poll_connection_events();
        for event in connection_events {
            match event {
                ConnectionEvent::Joined { player } => {
                    self.base_mut()
                        .emit_signal("peer_joined", &[Variant::from(player.0 as i64)]);
                    self.base_mut()
                        .emit_signal("player_joined", &[Variant::from(player.0 as i64)]);
                }
                ConnectionEvent::Disconnected { player } => {
                    self.base_mut()
                        .emit_signal("peer_disconnected", &[Variant::from(player.0 as i64)]);
                }
                _ => {}
            }
        }

        let BridgeMode::Host { transport, .. } = &mut self.mode else {
            return;
        };

        let received = transport.poll_received();
        for (player_id, command_bytes) in received {
            let cmd_str = String::from_utf8_lossy(&command_bytes);
            if let Ok(command) = parse_command_json(&cmd_str, &self.current_game_type) {
                if let Ok(events) = self.process_and_emit(player_id, command) {
                    if let BridgeMode::Host { transport, .. } = &mut self.mode {
                        let serialized = serde_json::to_vec(&events).unwrap_or_default();
                        let _ = transport.broadcast(&serialized);
                    }
                }
            }
        }
    }

    fn poll_client_events(&mut self) {
        let BridgeMode::Client { transport, .. } = &mut self.mode else {
            return;
        };
        let received = transport.poll_received();
        for (_host_id, event_bytes) in received {
            if let Ok(events) = serde_json::from_slice::<Vec<Box<dyn Event>>>(&event_bytes) {
                self.emit_game_events(&events);
            }
        }
    }

    fn poll_spectator_events(&mut self) {
        let BridgeMode::Spectator { transport } = &mut self.mode else {
            return;
        };
        let received = transport.poll_received();
        for (_host_id, event_bytes) in received {
            if let Ok(events) = serde_json::from_slice::<Vec<Box<dyn Event>>>(&event_bytes) {
                for event in &events {
                    if let Ok(json) = serde_json::to_string(event) {
                        self.base_mut()
                            .emit_signal("spectator_event_received", &[Variant::from(json)]);
                    }
                }
                self.emit_game_events(&events);
            }
        }
    }

    fn poll_native_host_events(&mut self) {
        let BridgeMode::NativeHost { transport, .. } = &mut self.mode else {
            return;
        };

        let connection_events = transport.poll_connection_events();
        for event in connection_events {
            match event {
                open_table_transport_native_bridge::ConnectionEvent::Joined { player } => {
                    self.base_mut()
                        .emit_signal("peer_joined", &[Variant::from(player.0 as i64)]);
                    self.base_mut()
                        .emit_signal("player_joined", &[Variant::from(player.0 as i64)]);
                }
                open_table_transport_native_bridge::ConnectionEvent::Disconnected { player } => {
                    self.base_mut()
                        .emit_signal("peer_disconnected", &[Variant::from(player.0 as i64)]);
                }
                _ => {}
            }
        }

        let BridgeMode::NativeHost { transport, .. } = &mut self.mode else {
            return;
        };

        let received = transport.poll_received();
        for (player_id, command_bytes) in received {
            let cmd_str = String::from_utf8_lossy(&command_bytes);
            if let Ok(command) = parse_command_json(&cmd_str, &self.current_game_type) {
                if let Ok(events) = self.process_and_emit(player_id, command) {
                    if let BridgeMode::NativeHost { transport, .. } = &mut self.mode {
                        let serialized = serde_json::to_vec(&events).unwrap_or_default();
                        let _ = transport.broadcast(&serialized);
                    }
                }
            }
        }
    }

    fn poll_native_client_events(&mut self) {
        let BridgeMode::NativeClient {
            transport,
            player_id,
            handshake_complete,
            ..
        } = &mut self.mode
        else {
            return;
        };

        if !*handshake_complete {
            match transport.poll_handshake() {
                HandshakeStatus::Pending => {}
                HandshakeStatus::Established {
                    player_id: pid,
                    reconnect_token,
                } => {
                    *player_id = pid;
                    *handshake_complete = true;
                    self.base_mut()
                        .emit_signal("connected", &[Variant::from(pid.0 as i64)]);
                    self.base_mut().emit_signal(
                        "native_handshake_established",
                        &[Variant::from(pid.0 as i64), Variant::from(reconnect_token)],
                    );
                }
                HandshakeStatus::Rejected { .. } => {
                    self.base_mut().emit_signal("disconnected", &[]);
                }
            }
        }

        let BridgeMode::NativeClient { transport, .. } = &mut self.mode else {
            return;
        };

        let received = transport.poll_received();
        for (_host_id, event_bytes) in received {
            if let Ok(events) = serde_json::from_slice::<Vec<Box<dyn Event>>>(&event_bytes) {
                self.emit_game_events(&events);
            }
        }
    }

    fn flush_native_outgoing(&mut self) {
        let (sends, broadcasts) = match &self.mode {
            BridgeMode::NativeHost { queue, .. } | BridgeMode::NativeClient { queue, .. } => {
                let mut q = queue.lock().unwrap();
                let sends = std::mem::take(&mut q.outgoing_sends);
                let broadcasts = std::mem::take(&mut q.outgoing_broadcasts);
                (sends, broadcasts)
            }
            _ => return,
        };

        for (peer_tag, bytes) in sends {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            self.base_mut().emit_signal(
                "native_send_requested",
                &[Variant::from(peer_tag), Variant::from(packed)],
            );
        }

        for bytes in broadcasts {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            self.base_mut()
                .emit_signal("native_broadcast_requested", &[Variant::from(packed)]);
        }
    }

    fn emit_game_events(&mut self, events: &[Box<dyn Event>]) {
        for event in events {
            if let Ok(json) = serde_json::to_string(event) {
                self.emit_bridge_signal("event_json", &[Variant::from(json.clone())]);
                let parsed_var = godot::classes::Json::parse_string(&GString::from(&json));
                if let Ok(dict) = parsed_var.try_to::<Dictionary>() {
                    self.recent_events.push(dict);
                    if self.recent_events.len() > 100 {
                        self.recent_events.remove(0);
                    }
                }
            }

            if let Some(moved) = event.as_any().downcast_ref::<PieceMovedEvent>() {
                if let BridgeMode::Client {
                    client_current_player,
                    ..
                } = &mut self.mode
                {
                    *client_current_player = if moved.player.0 == 1 { 2 } else { 1 };
                }
                let (captured_row, captured_col) = moved
                    .captured
                    .map(|p| (p.row as i64, p.col as i64))
                    .unwrap_or((-1, -1));
                self.emit_bridge_signal(
                    "piece_moved",
                    &[
                        Variant::from(moved.player.0 as i64),
                        Variant::from(moved.from.row as i64),
                        Variant::from(moved.from.col as i64),
                        Variant::from(moved.to.row as i64),
                        Variant::from(moved.to.col as i64),
                        Variant::from(captured_row),
                        Variant::from(captured_col),
                        Variant::from(moved.promoted),
                    ],
                );
            }

            if let Some(game_over) = event.as_any().downcast_ref::<GameOverEvent>() {
                let winner_id = game_over.winner.0 as i64;
                self.emit_bridge_signal("game_over", &[Variant::from(winner_id)]);
                self.check_advance_tournament(winner_id);
            }

            if let Some(game_over) = event.as_any().downcast_ref::<go_game::GameOverEvent>() {
                let winner_id = game_over.winner.map(|p| p.0 as i64).unwrap_or(0);
                self.emit_bridge_signal("game_over", &[Variant::from(winner_id)]);
                self.check_advance_tournament(winner_id);
            }

            if let Some(shot) = event.as_any().downcast_ref::<ShotResultEvent>() {
                let is_hit = shot.result == ShotResult::Hit || shot.result == ShotResult::Sunk;
                self.emit_bridge_signal(
                    "shot_result",
                    &[
                        Variant::from(shot.shooter.0 as i64),
                        Variant::from(shot.target.row as i64),
                        Variant::from(shot.target.col as i64),
                        Variant::from(is_hit),
                    ],
                );
            }

            if let Some(t_moved) = event.as_any().downcast_ref::<ludo_game::TokenMovedEvent>() {
                self.emit_bridge_signal(
                    "token_moved",
                    &[
                        Variant::from(t_moved.player.0 as i64),
                        Variant::from(t_moved.token_index as i64),
                        Variant::from(t_moved.from_steps as i64),
                        Variant::from(t_moved.to_steps as i64),
                        Variant::from(t_moved.finished),
                    ],
                );
            }

            if let Some(c_moved) = event
                .as_any()
                .downcast_ref::<backgammon_game::CheckerMovedEvent>()
            {
                let from_val = c_moved.from.map(|v| v as i64).unwrap_or(-1);
                let to_val = c_moved.to.map(|v| v as i64).unwrap_or(-1);
                self.emit_bridge_signal(
                    "checker_moved",
                    &[
                        Variant::from(c_moved.player.0 as i64),
                        Variant::from(from_val),
                        Variant::from(to_val),
                        Variant::from(c_moved.captured_opponent),
                        Variant::from(c_moved.borne_off),
                    ],
                );
            }

            if let Some(c_conquered) = event.as_any().downcast_ref::<TerritoryConqueredEvent>() {
                self.emit_bridge_signal(
                    "territory_conquered",
                    &[
                        Variant::from(c_conquered.player.0 as i64),
                        Variant::from(c_conquered.territory.0 as i64),
                        Variant::from(c_conquered.from_armies as i64),
                        Variant::from(c_conquered.to_armies as i64),
                    ],
                );
            }

            if let Some(c_attack) = event.as_any().downcast_ref::<AttackResolvedEvent>() {
                let mut att_rolls = VariantArray::new();
                for &r in &c_attack.attacker_rolls {
                    att_rolls.push(&Variant::from(r as i64));
                }
                let mut def_rolls = VariantArray::new();
                for &r in &c_attack.defender_rolls {
                    def_rolls.push(&Variant::from(r as i64));
                }
                self.emit_bridge_signal(
                    "attack_resolved",
                    &[
                        Variant::from(c_attack.from.0 as i64),
                        Variant::from(c_attack.to.0 as i64),
                        Variant::from(att_rolls),
                        Variant::from(def_rolls),
                        Variant::from(c_attack.attacker_losses as i64),
                        Variant::from(c_attack.defender_losses as i64),
                    ],
                );
            }

            if let Some(c_placed) = event.as_any().downcast_ref::<ArmiesPlacedEvent>() {
                self.emit_bridge_signal(
                    "armies_placed",
                    &[
                        Variant::from(c_placed.player.0 as i64),
                        Variant::from(c_placed.territory.0 as i64),
                        Variant::from(c_placed.count as i64),
                        Variant::from(c_placed.armies_remaining as i64),
                    ],
                );
            }

            if let Some(c_elim) = event.as_any().downcast_ref::<PlayerEliminatedEvent>() {
                self.emit_bridge_signal(
                    "player_eliminated",
                    &[
                        Variant::from(c_elim.player.0 as i64),
                        Variant::from(c_elim.by.0 as i64),
                    ],
                );
            }

            if let Some(c_phase) = event.as_any().downcast_ref::<PhaseChangedEvent>() {
                self.emit_bridge_signal(
                    "phase_changed",
                    &[
                        Variant::from(c_phase.player.0 as i64),
                        Variant::from(GString::from(&c_phase.new_phase)),
                    ],
                );
            }

            if let Some(c_cards) = event.as_any().downcast_ref::<CardsExchangedEvent>() {
                self.emit_bridge_signal(
                    "cards_exchanged",
                    &[
                        Variant::from(c_cards.player.0 as i64),
                        Variant::from(c_cards.armies_gained as i64),
                    ],
                );
            }

            if let Some(c_over) = event.as_any().downcast_ref::<TegGameOverEvent>() {
                let winner_id = c_over.winner.0 as i64;
                self.emit_bridge_signal(
                    "crisis_game_over",
                    &[
                        Variant::from(winner_id),
                        Variant::from(GString::from(&c_over.objective)),
                    ],
                );
                self.check_advance_tournament(winner_id);
            }
        }
    }

    fn check_advance_tournament(&mut self, winner_id: i64) {
        let (ended_round, next_match_info, is_over, standings) = match &mut self.mode {
            BridgeMode::Tournament {
                game_type,
                matches,
                current_match_idx,
                session,
                scores,
                ..
            } => {
                let current_match = &matches[*current_match_idx];
                let round = current_match.round as i64;

                if winner_id > 0 {
                    let w_pid = PlayerId(winner_id as u32);
                    *scores.entry(w_pid).or_insert(0) += 1;
                }

                *current_match_idx += 1;

                if *current_match_idx < matches.len() {
                    let next_m = &matches[*current_match_idx];
                    if let Some(new_sess) =
                        create_session_for_players(game_type, next_m.player1, next_m.player2)
                    {
                        *session = new_sess;
                    }
                    let p1 = next_m.player1.0 as i64;
                    let p2 = next_m.player2.0 as i64;
                    let r = next_m.round as i64;
                    let turn = session.current_player().0 as i64;
                    (round, Some((p1, p2, r, turn)), false, Dictionary::new())
                } else {
                    let mut dict = Dictionary::new();
                    for (pid, score) in scores.iter() {
                        let _ = dict.insert(pid.0 as i64, *score as i64);
                    }
                    (round, None, true, dict)
                }
            }
            _ => return,
        };

        self.base_mut().emit_signal(
            "tournament_match_ended",
            &[Variant::from(winner_id), Variant::from(ended_round)],
        );

        if let Some((p1, p2, r, turn)) = next_match_info {
            self.base_mut().emit_signal(
                "tournament_match_started",
                &[Variant::from(p1), Variant::from(p2), Variant::from(r)],
            );
            self.base_mut()
                .emit_signal("turn_changed", &[Variant::from(turn)]);
        } else if is_over {
            self.base_mut()
                .emit_signal("tournament_over", &[Variant::from(standings)]);
        }
    }

    fn process_ai_turn_if_needed(&mut self) {
        let mut steps = 0;
        loop {
            if steps >= 2 {
                break;
            }
            let (acting_p, cmd_opt): (PlayerId, Option<Box<dyn Command>>) = match &self.mode {
                BridgeMode::Local {
                    session,
                    ai_player: Some(ai_p),
                } => {
                    let curr_p = session.current_player();
                    let is_ai_turn = curr_p == *ai_p;
                    if is_ai_turn || self.current_game_type == "shogi" || self.current_game_type == "xiangqi" {
                        let cmd: Option<Box<dyn Command>> = match self.current_game_type.as_str() {
                            "chess" if is_ai_turn => chess_game::chess_ai_pick_move(session, *ai_p, self.chess_ai_depth)
                                .map(|c| Box::new(c) as Box<dyn Command>),
                            "shogi" => shogi_game::shogi_ai_pick_move(session, curr_p),
                            "xiangqi" => xiangqi_game::xiangqi_ai_pick_move(session, curr_p)
                                .map(|c| Box::new(c) as Box<dyn Command>),
                            "go" if is_ai_turn => go_game::go_ai_pick_move(session, *ai_p)
                                .map(|c| Box::new(c) as Box<dyn Command>)
                                .or_else(|| {
                                    Some(Box::new(go_game::PassCommand { player: *ai_p })
                                        as Box<dyn Command>)
                                }),
                            "backgammon" if is_ai_turn => {
                                let has_pending = session
                                    .world()
                                    .get_resource::<backgammon_game::PendingDiceResource>()
                                    .and_then(|p| p.pending.get(ai_p))
                                    .map(|d| !d.is_empty())
                                    .unwrap_or(false);
                                if !has_pending {
                                    Some(Box::new(backgammon_game::RollDiceCommand { player: *ai_p }) as Box<dyn Command>)
                                } else {
                                    backgammon_game::backgammon_ai_pick_move(session, *ai_p)
                                        .map(|c| Box::new(c) as Box<dyn Command>)
                                }
                            }
                            "ludo" if is_ai_turn => {
                                let has_pending = session
                                    .world()
                                    .get_resource::<ludo_game::PendingRollResource>()
                                    .and_then(|p| p.pending.get(ai_p))
                                    .is_some();
                                if !has_pending {
                                    Some(Box::new(ludo_game::RollDiceCommand { player: *ai_p })
                                        as Box<dyn Command>)
                                } else {
                                    ludo_game::ludo_ai_pick_move(session, *ai_p)
                                        .map(|c| Box::new(c) as Box<dyn Command>)
                                }
                            }
                            _ if is_ai_turn => checkers_game::checkers_ai_pick_move(session, *ai_p)
                                .map(|c| Box::new(c) as Box<dyn Command>),
                            _ => None,
                        };
                        (curr_p, cmd)
                    } else {
                        break;
                    }
                }
                _ => break,
            };

            if let Some(cmd) = cmd_opt {
                steps += 1;
                let _ = self.process_and_emit(acting_p, cmd);
            } else {
                break;
            }
        }
    }
}
