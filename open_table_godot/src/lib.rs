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
pub mod native_link;
pub mod steam_bridge;

pub use native_link::{
    GodotMultipeerLink, GodotNearbyLink, GodotRawByteLink, NativeBridgeTransport, SharedLinkQueue,
};
pub use open_table_transport_native_bridge::RawByteLink;

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
    HandshakeStatus, NativeClientTransport, NativeHostTransport, RawLinkEvent,
};
use open_table_transport_tcp::{ConnectionEvent, TcpClientTransport, TcpHostTransport};
use open_table_transport_websocket::{RelayClientEvent, WsRelayClient};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

/// Mensajes de sincronización y resync en red (espectadores tardíos y reconexión).
#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum SyncProtocolMessage {
    RequestSync,
    SyncLog {
        game_type: String,
        log_bytes: Vec<u8>,
    },
}

struct OpenTableExtension;

#[gdextension]
unsafe impl ExtensionLibrary for OpenTableExtension {}

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
        transport: NativeHostTransport<GodotRawByteLink>,
        queue: Arc<Mutex<SharedLinkQueue>>,
    },
    NativeClient {
        transport: NativeClientTransport<GodotRawByteLink>,
        player_id: PlayerId,
        queue: Arc<Mutex<SharedLinkQueue>>,
        handshake_complete: bool,
    },
    MultipeerHost {
        session: Session,
        transport: NativeHostTransport<GodotMultipeerLink>,
        queue: Arc<Mutex<SharedLinkQueue>>,
    },
    MultipeerClient {
        transport: NativeClientTransport<GodotMultipeerLink>,
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
    RelayHost {
        session: Session,
    },
    RelayClient {
        player_id: PlayerId,
        client_current_player: i64,
    },
}

fn get_session_init_params(
    game_type: &str,
    p1: PlayerId,
    p2: PlayerId,
) -> (SessionId, u64, Vec<PlayerId>, RuleEngine) {
    let id = SessionId(1);
    let seed = 1;
    match game_type.to_lowercase().as_str() {
        "checkers" => (
            id,
            seed,
            vec![p1, p2],
            checkers_game::build_checkers_rules(),
        ),
        "chess" => (id, seed, vec![p1, p2], chess_game::build_chess_rules()),
        "shogi" => (id, seed, vec![p1, p2], shogi_game::build_shogi_rules()),
        "xiangqi" => (id, seed, vec![p1, p2], xiangqi_game::build_xiangqi_rules()),
        "go" => (id, seed, vec![p1, p2], go_game::build_go_rules()),
        "uno" => (id, seed, vec![p1, p2], uno_game::build_uno_rules()),
        "crisis" => (id, seed, vec![p1, p2], crisis_game::build_crisis_rules()),
        "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => (
            id,
            seed,
            vec![p1, p2],
            chinese_checkers_game::build_chinese_checkers_rules(),
        ),
        "mille_bornes" | "mille-bornes" | "millebornes" => (
            id,
            seed,
            vec![p1, p2],
            mille_bornes_game::build_mille_bornes_rules(),
        ),
        "backgammon" => (
            id,
            seed,
            vec![p1, p2],
            backgammon_game::build_backgammon_rules(),
        ),
        "monopoly" => (
            id,
            seed,
            vec![p1, p2],
            monopoly_game::build_monopoly_rules(),
        ),
        "ludo" => (id, seed, vec![p1, p2], ludo_game::build_ludo_rules()),
        "battleship" => (
            id,
            seed,
            vec![p1, p2],
            battleship_game::build_battleship_rules(),
        ),
        _ => (
            id,
            seed,
            vec![p1, p2],
            checkers_game::build_checkers_rules(),
        ),
    }
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
    relay_client: Option<WsRelayClient>,
    relay_auth_token: Option<String>,
    current_game_type: String,
    undone_commands: Vec<(PlayerId, String)>,
    recent_events: Vec<Dictionary<Variant, Variant>>,
    chess_ai_depth: u8,
    ai_difficulty: AiDifficulty,
}

#[godot_api]
impl INode for OpenTableBridge {
    fn init(base: Base<Node>) -> Self {
        Self {
            base,
            mode: BridgeMode::None,
            relay_client: None,
            relay_auth_token: None,
            current_game_type: String::from("checkers"),
            undone_commands: Vec::new(),
            recent_events: Vec::new(),
            chess_ai_depth: 3,
            ai_difficulty: AiDifficulty::Medium,
        }
    }

    fn process(&mut self, _delta: f64) {
        self.poll_events();
    }
}

#[godot_api]
impl OpenTableBridge {
    // --- SIGNALS ---
    #[allow(clippy::too_many_arguments)]
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
    fn native_send_bytes(bytes: PackedByteArray);

    #[signal]
    fn native_bytes_received(bytes: PackedByteArray);

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
        attacker_rolls: Array<Variant>,
        defender_rolls: Array<Variant>,
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
    fn tournament_over(standings: Dictionary<Variant, Variant>);

    #[signal]
    fn room_created(code: GString);

    #[signal]
    fn room_joined(success: bool, player_id: i64);

    #[signal]
    fn connection_reconnecting(attempt: i64);

    #[signal]
    fn connection_restored();

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
    pub fn set_ai_difficulty(&mut self, difficulty: i64) {
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        self.chess_ai_depth = self.ai_difficulty.max_depth();
    }

    #[func]
    fn start_local_match_shogi_vs_ai(
        &mut self,
        human_player: i64,
        ai_player: i64,
        difficulty: i64,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
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
    fn start_local_match_xiangqi_vs_ai(&mut self, human_player: i64, ai_player: i64) -> bool {
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
        difficulty: i64,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "go".to_string();
        if (0..=3).contains(&difficulty) {
            self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        } else {
            self.ai_difficulty = AiDifficulty::Medium;
        }
        let p_human = PlayerId(human_player as u32);
        let p_ai = PlayerId(ai_player as u32);

        let (p1, p2) = if human_player < ai_player {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let size = if difficulty > 3 {
            difficulty as usize
        } else {
            9
        };
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

    #[func]
    fn start_local_match_uno_vs_ai(&mut self, human: i64, ai: i64, difficulty: i64) -> bool {
        if human == ai || human <= 0 || ai <= 0 {
            return false;
        }

        self.current_game_type = "uno".to_string();
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        let p_human = PlayerId(human as u32);
        let p_ai = PlayerId(ai as u32);

        let (p1, p2) = if human < ai {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_uno_session(SessionId(1), 1, vec![p1, p2]);
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

    fn parse_player_ids(players: &Variant) -> Vec<PlayerId> {
        if let Ok(arr) = players.try_to::<Array<i64>>() {
            arr.iter_shared().map(|p| PlayerId(p as u32)).collect()
        } else if let Ok(arr) = players.try_to::<Array<Variant>>() {
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
    fn start_local_match_crisis_vs_ai(&mut self, human: i64, ai: i64, difficulty: i64) -> bool {
        if human == ai || human <= 0 || ai <= 0 {
            return false;
        }

        self.current_game_type = "crisis".to_string();
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        let p_human = PlayerId(human as u32);
        let p_ai = PlayerId(ai as u32);

        let (p1, p2) = if human < ai {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = match new_crisis_session(SessionId(1), 1, &[p1, p2]) {
            Ok(s) => s,
            Err(_) => return false,
        };
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
        difficulty: i64,
    ) -> bool {
        if human_player == ai_player || human_player <= 0 || ai_player <= 0 {
            return false;
        }

        self.current_game_type = "chess".to_string();
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        self.chess_ai_depth = self.ai_difficulty.max_depth();
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
    fn start_local_match_chinese_checkers_n_players(&mut self, num_players: i64) {
        self.current_game_type = "chinese_checkers".to_string();
        let count = num_players.clamp(2, 6) as u32;
        let players: Vec<PlayerId> = (1..=count).map(PlayerId).collect();
        let session = new_chinese_checkers_session(SessionId(1), 1, players);
        self.mode = BridgeMode::Local {
            session,
            ai_player: None,
        };
    }

    #[func]
    fn start_local_match_chinese_checkers_vs_ai(
        &mut self,
        human: i64,
        ai: i64,
        difficulty: i64,
    ) -> bool {
        if human == ai || human <= 0 || ai <= 0 {
            return false;
        }

        self.current_game_type = "chinese_checkers".to_string();
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        let p_human = PlayerId(human as u32);
        let p_ai = PlayerId(ai as u32);

        let (p1, p2) = if human < ai {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_chinese_checkers_session(SessionId(1), 1, vec![p1, p2]);
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
    fn start_local_match_mille_bornes_vs_ai(
        &mut self,
        human: i64,
        ai: i64,
        difficulty: i64,
    ) -> bool {
        if human == ai || human <= 0 || ai <= 0 {
            return false;
        }

        self.current_game_type = "mille_bornes".to_string();
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        let p_human = PlayerId(human as u32);
        let p_ai = PlayerId(ai as u32);

        let (p1, p2) = if human < ai {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_mille_bornes_session(SessionId(1), 1, p1, p2);
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
    fn start_local_match_backgammon_vs_ai(&mut self, human_player: i64, ai_player: i64) -> bool {
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
    fn start_local_match_monopoly_vs_ai(&mut self, human: i64, ai: i64, difficulty: i64) -> bool {
        if human == ai || human <= 0 || ai <= 0 {
            return false;
        }

        self.current_game_type = "monopoly".to_string();
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        let p_human = PlayerId(human as u32);
        let p_ai = PlayerId(ai as u32);

        let (p1, p2) = if human < ai {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let session = new_monopoly_session(SessionId(1), 1, p1, p2);
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
    fn start_local_match_battleship_vs_ai(&mut self, human: i64, ai: i64, difficulty: i64) -> bool {
        if human == ai || human <= 0 || ai <= 0 {
            return false;
        }

        self.current_game_type = "battleship".to_string();
        self.ai_difficulty = AiDifficulty::from_i64(difficulty);
        let p_human = PlayerId(human as u32);
        let p_ai = PlayerId(ai as u32);

        let (p1, p2) = if human < ai {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };

        let mut session = new_battleship_session(SessionId(1), 1, p1, p2);
        let _ = session.process_command(
            p_ai,
            Box::new(battleship_game::default_ai_place_fleet_command(p_ai)),
        );
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
            | BridgeMode::MultipeerHost { session, .. }
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
    fn export_chess_fen(&self) -> GString {
        let fen_str = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::RelayHost { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Tournament { session, .. } => chess_game::export_session_fen(session),
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .map(|(_, s)| chess_game::export_session_fen(s))
                .unwrap_or_default(),
            _ => String::new(),
        };
        GString::from(fen_str.as_str())
    }

    #[func]
    fn export_chess_pgn(&self) -> GString {
        let pgn_opt = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::RelayHost { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Tournament { session, .. } => Some(chess_game::export_to_pgn(session)),
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .map(|(_, s)| chess_game::export_to_pgn(s)),
            _ => None,
        };
        GString::from(pgn_opt.unwrap_or_default().as_str())
    }

    #[func]
    fn export_chess_pgn_named(&self, white: GString, black: GString) -> GString {
        let w = white.to_string();
        let b = black.to_string();
        let pgn_str = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::RelayHost { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                chess_game::export_session_pgn(session, &w, &b)
            }
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .map(|(_, s)| chess_game::export_session_pgn(s, &w, &b))
                .unwrap_or_default(),
            _ => String::new(),
        };
        GString::from(pgn_str.as_str())
    }

    #[func]
    fn export_go_sgf(&self) -> GString {
        let sgf_str = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::RelayHost { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Tournament { session, .. } => go_game::export_to_sgf(session),
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .map(|(_, s)| go_game::export_to_sgf(s))
                .unwrap_or_default(),
            _ => String::new(),
        };
        GString::from(sgf_str.as_str())
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
            Ok(svg) => GString::from(svg.as_str()),
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
        let addr = format!("{}:{}", host, port);
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
        let addr = format!("{}:{}", host, port);
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
            Ok(mut transport) => {
                let sync_req = SyncProtocolMessage::RequestSync;
                if let Ok(serialized) = serde_json::to_vec(&sync_req) {
                    let _ = transport.send(open_table_transport_tcp::HOST_PLAYER_ID, &serialized);
                }
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
        matches!(
            self.mode,
            BridgeMode::Client { .. } | BridgeMode::RelayClient { .. }
        )
    }

    #[func]
    pub fn disconnect_from_host(&mut self) {
        if let Some(relay) = &mut self.relay_client {
            let _ = relay.leave_room();
        }
        self.relay_client = None;
        if matches!(
            self.mode,
            BridgeMode::Client { .. }
                | BridgeMode::Spectator { .. }
                | BridgeMode::RelayHost { .. }
                | BridgeMode::RelayClient { .. }
        ) {
            self.mode = BridgeMode::None;
            self.base_mut().emit_signal("disconnected", &[]);
        }
    }

    // ------------------------------------------------------------------
    // RELAY WEBSOCKET
    // ------------------------------------------------------------------
    #[func]
    pub fn set_relay_auth_token(&mut self, token: GString) {
        let tok = token.to_string();
        let clean = tok.trim().to_string();
        if clean.is_empty() {
            self.relay_auth_token = None;
        } else {
            if let Some(relay) = &mut self.relay_client {
                let _ = relay.authenticate(&clean);
            }
            self.relay_auth_token = Some(clean);
        }
    }

    #[func]
    pub fn connect_to_relay(&mut self, relay_url: GString) {
        let url = relay_url.to_string();
        let target_url = if url.trim().is_empty() {
            "ws://127.0.0.1:8080".to_string()
        } else {
            url
        };
        self.relay_client = Some(WsRelayClient::connect_with_token(
            &target_url,
            self.relay_auth_token.as_deref(),
        ));
    }

    #[func]
    pub fn create_relay_room(&mut self, game_id: GString) -> GString {
        let gid = game_id.to_string();
        let effective_game = if gid.trim().is_empty() {
            "checkers".to_string()
        } else {
            gid
        };
        self.current_game_type = effective_game.clone();

        if self.relay_client.is_none() {
            self.relay_client = Some(WsRelayClient::connect_with_token(
                "ws://127.0.0.1:8080",
                self.relay_auth_token.as_deref(),
            ));
        }

        let code = if let Some(relay) = &mut self.relay_client {
            let c = relay.create_room(&effective_game).unwrap_or_default();
            // Consumir RoomCreated de la cola interna porque emitimos la señal directamente aquí
            let _ = relay.poll_relay_events();
            c
        } else {
            String::new()
        };

        let session = create_initial_session(&effective_game)
            .unwrap_or_else(|| new_checkers_session(SessionId(1), 1, PlayerId(1), PlayerId(2)));
        self.mode = BridgeMode::RelayHost { session };

        let code_gstr = GString::from(&code);
        self.base_mut()
            .emit_signal("room_created", &[Variant::from(code_gstr.clone())]);
        code_gstr
    }

    #[func]
    pub fn join_relay_room(&mut self, code: GString) {
        if self.relay_client.is_none() {
            self.relay_client = Some(WsRelayClient::connect_with_token(
                "ws://127.0.0.1:8080",
                self.relay_auth_token.as_deref(),
            ));
        }

        let join_result = if let Some(relay) = &mut self.relay_client {
            let res = relay.join_room(&code.to_string());
            let _ = relay.poll_relay_events();
            res
        } else {
            Err(EngineError::Network("Relay client not initialized".into()))
        };

        match join_result {
            Ok(player_id) => {
                if let Some(relay) = &mut self.relay_client {
                    let sync_req = SyncProtocolMessage::RequestSync;
                    if let Ok(serialized) = serde_json::to_vec(&sync_req) {
                        let _ = relay.send_relay_data(&serialized);
                    }
                }
                self.mode = BridgeMode::RelayClient {
                    player_id,
                    client_current_player: 1,
                };
                let pid = player_id.0 as i64;
                self.base_mut()
                    .emit_signal("room_joined", &[Variant::from(true), Variant::from(pid)]);
                self.base_mut()
                    .emit_signal("connected", &[Variant::from(pid)]);
            }
            Err(_) => {
                self.base_mut().emit_signal(
                    "room_joined",
                    &[Variant::from(false), Variant::from(-1_i64)],
                );
            }
        }
    }

    #[func]
    pub fn leave_relay_room(&mut self) {
        if let Some(relay) = &mut self.relay_client {
            let _ = relay.leave_room();
        }
        if matches!(
            self.mode,
            BridgeMode::RelayHost { .. } | BridgeMode::RelayClient { .. }
        ) {
            self.mode = BridgeMode::None;
            self.base_mut().emit_signal("disconnected", &[]);
        }
    }

    #[func]
    pub fn get_relay_room_code(&self) -> GString {
        if let Some(relay) = &self.relay_client {
            if let Some(code) = relay.room_code() {
                return GString::from(code);
            }
        }
        GString::from("")
    }

    #[func]
    pub fn rejoin_relay_room(&mut self, code: GString) -> bool {
        let Some(relay) = &mut self.relay_client else {
            return false;
        };
        match relay.rejoin_room(&code.to_string()) {
            Ok(_pid) => {
                self.poll_relay_events();
                true
            }
            Err(_) => false,
        }
    }

    #[func]
    pub fn emit_connection_reconnecting(&mut self, attempt: i64) {
        self.base_mut()
            .emit_signal("connection_reconnecting", &[Variant::from(attempt)]);
    }

    #[func]
    pub fn emit_connection_restored(&mut self) {
        self.base_mut().emit_signal("connection_restored", &[]);
    }

    #[func]
    fn start_spectating(&mut self, host_addr: GString) -> bool {
        let addr = host_addr.to_string();
        match TcpClientTransport::connect_as_new_player(&addr, "Spectator") {
            Ok((mut transport, _player_id, _reconnect_token)) => {
                let sync_req = SyncProtocolMessage::RequestSync;
                if let Ok(serialized) = serde_json::to_vec(&sync_req) {
                    let _ = transport.send(open_table_transport_tcp::HOST_PLAYER_ID, &serialized);
                }
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
            BridgeMode::MultipeerClient { player_id, .. } => player_id.0 as i64,
            BridgeMode::RelayHost { .. } => 1,
            BridgeMode::RelayClient { player_id, .. } => player_id.0 as i64,
            _ => -1,
        }
    }

    #[func]
    fn is_native_connected(&self) -> bool {
        match &self.mode {
            BridgeMode::NativeClient {
                handshake_complete, ..
            }
            | BridgeMode::MultipeerClient {
                handshake_complete, ..
            } => *handshake_complete,
            BridgeMode::NativeHost { .. } | BridgeMode::MultipeerHost { .. } => true,
            _ => false,
        }
    }

    #[func]
    fn send_move_client(&mut self, from_row: i64, from_col: i64, to_row: i64, to_col: i64) {
        let command_parts = match &self.mode {
            BridgeMode::Client { player_id, .. } => Some(*player_id),
            BridgeMode::RelayClient { player_id, .. } => Some(*player_id),
            BridgeMode::NativeClient {
                player_id,
                handshake_complete,
                ..
            }
            | BridgeMode::MultipeerClient {
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
                BridgeMode::RelayClient { .. } => {
                    if let Some(relay) = &mut self.relay_client {
                        let _ = relay.send_relay_data(&serialized);
                    }
                }
                BridgeMode::NativeClient { transport, .. } => {
                    let _ = transport.send(
                        open_table_transport_native_bridge::HOST_PLAYER_ID,
                        &serialized,
                    );
                }
                BridgeMode::MultipeerClient { transport, .. } => {
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
    fn ensure_native_signal_connections(&mut self) {
        let callable = self.base().callable("on_native_bytes_received");
        if !self.base().is_connected("native_bytes_received", &callable) {
            self.base_mut().connect("native_bytes_received", &callable);
        }
    }

    #[func]
    fn start_p2p_host(&mut self, game_id: GString) -> bool {
        let plugin_available = GodotRawByteLink::check_native_plugin_available();
        self.ensure_native_signal_connections();

        let gid = game_id.to_string();
        let effective_game_id = if gid.trim().is_empty() {
            "checkers".to_string()
        } else {
            gid.trim().to_lowercase()
        };
        self.current_game_type = effective_game_id.clone();

        let session = create_initial_session(&effective_game_id)
            .unwrap_or_else(|| new_checkers_session(SessionId(1), 1, PlayerId(1), PlayerId(2)));
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotRawByteLink::new(queue.clone());
        let p2p_transport: NativeBridgeTransport<GodotRawByteLink> =
            NativeBridgeTransport::new_host(link);
        if let Some(transport) = p2p_transport.into_host() {
            self.mode = BridgeMode::NativeHost {
                session,
                transport,
                queue,
            };
        }
        self.flush_native_outgoing();
        godot_print!("✅ P2P Host iniciado para juego '{}'", effective_game_id);
        plugin_available
    }

    #[func]
    fn start_p2p_client(&mut self, game_id: GString) -> bool {
        let plugin_available = GodotRawByteLink::check_native_plugin_available();
        self.ensure_native_signal_connections();

        let gid = game_id.to_string();
        let effective_game_id = if gid.trim().is_empty() {
            "checkers".to_string()
        } else {
            gid.trim().to_lowercase()
        };
        self.current_game_type = effective_game_id.clone();

        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotRawByteLink::new(queue.clone());
        match NativeBridgeTransport::<GodotRawByteLink>::new_client(link, "P2PClient") {
            Ok(p2p_transport) => {
                if let Some(transport) = p2p_transport.into_client() {
                    self.mode = BridgeMode::NativeClient {
                        transport,
                        player_id: PlayerId(0),
                        queue,
                        handshake_complete: false,
                    };
                }
                self.flush_native_outgoing();
                godot_print!("✅ P2P Client iniciado para juego '{}'", effective_game_id);
                plugin_available
            }
            Err(e) => {
                godot_warn!("No se pudo inicializar P2P Client: {}", e);
                false
            }
        }
    }

    #[func]
    fn on_native_bytes_received(&mut self, bytes: PackedByteArray) {
        self.feed_native_data_received(GString::from("p2p_peer"), bytes);
    }

    #[func]
    fn send_native_bytes(&mut self, bytes: PackedByteArray) {
        let raw = bytes.to_vec();
        if let BridgeMode::NativeHost { queue, .. }
        | BridgeMode::NativeClient { queue, .. }
        | BridgeMode::MultipeerHost { queue, .. }
        | BridgeMode::MultipeerClient { queue, .. } = &self.mode
        {
            let mut link = GodotRawByteLink::new(queue.clone());
            let _ = link.send(&raw);
        }
        self.flush_native_outgoing();
    }

    #[func]
    fn receive_native_bytes(&mut self) -> PackedByteArray {
        let mut out = PackedByteArray::new();
        if let BridgeMode::NativeHost { queue, .. }
        | BridgeMode::NativeClient { queue, .. }
        | BridgeMode::MultipeerHost { queue, .. }
        | BridgeMode::MultipeerClient { queue, .. } = &self.mode
        {
            let mut link = GodotRawByteLink::new(queue.clone());
            for chunk in link.receive() {
                for b in chunk {
                    out.push(b);
                }
            }
        }
        out
    }

    #[func]
    fn start_native_hosting(&mut self, player_top_id: i64, player_bottom_id: i64) {
        self.ensure_native_signal_connections();
        let session = new_checkers_session(
            SessionId(1),
            1,
            PlayerId(player_top_id as u32),
            PlayerId(player_bottom_id as u32),
        );
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotRawByteLink::new(queue.clone());
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
        self.ensure_native_signal_connections();
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotRawByteLink::new(queue.clone());
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
        self.ensure_native_signal_connections();
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotRawByteLink::new(queue.clone());
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
    fn start_multipeer_hosting(&mut self, player_top_id: i64, player_bottom_id: i64) {
        let session = new_checkers_session(
            SessionId(1),
            1,
            PlayerId(player_top_id as u32),
            PlayerId(player_bottom_id as u32),
        );
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotMultipeerLink {
            queue: queue.clone(),
        };
        let transport = NativeHostTransport::new(link);
        self.mode = BridgeMode::MultipeerHost {
            session,
            transport,
            queue,
        };
        godot_print!("✅ Multipeer Host (iOS) iniciado");
    }

    #[func]
    fn start_multipeer_client(&mut self, player_name: GString) {
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotMultipeerLink {
            queue: queue.clone(),
        };
        let transport = NativeClientTransport::begin_join(link, &player_name.to_string())
            .expect("no pude iniciar handshake multipeer");
        self.mode = BridgeMode::MultipeerClient {
            transport,
            player_id: PlayerId(0),
            queue,
            handshake_complete: false,
        };
        godot_print!("✅ Handshake multipeer (iOS) iniciado");
    }

    #[func]
    fn reconnect_multipeer(&mut self, player_id: i64, token: GString) {
        let queue = Arc::new(Mutex::new(SharedLinkQueue::default()));
        let link = GodotMultipeerLink {
            queue: queue.clone(),
        };
        let pid = PlayerId(player_id as u32);
        let transport = NativeClientTransport::begin_reconnect(link, pid, token.to_string())
            .expect("no pude iniciar reconexión multipeer");
        self.mode = BridgeMode::MultipeerClient {
            transport,
            player_id: pid,
            queue,
            handshake_complete: false,
        };
        godot_print!(
            "✅ Reconexión multipeer (iOS) iniciada para PlayerId={}",
            player_id
        );
    }

    #[func]
    fn feed_native_data_received(&mut self, peer_tag: GString, bytes: PackedByteArray) {
        let incoming_bytes = bytes.to_vec();
        match &self.mode {
            BridgeMode::NativeHost { queue, .. }
            | BridgeMode::NativeClient { queue, .. }
            | BridgeMode::MultipeerHost { queue, .. }
            | BridgeMode::MultipeerClient { queue, .. } => {
                let mut q = queue.lock().unwrap();
                q.incoming.push((peer_tag.to_string(), incoming_bytes));
            }
            _ => {}
        }
    }

    #[func]
    fn feed_native_peer_disconnected(&mut self, peer_tag: GString) {
        match &self.mode {
            BridgeMode::NativeHost { queue, .. }
            | BridgeMode::NativeClient { queue, .. }
            | BridgeMode::MultipeerHost { queue, .. }
            | BridgeMode::MultipeerClient { queue, .. } => {
                let mut q = queue.lock().unwrap();
                q.events
                    .push(RawLinkEvent::Disconnected(peer_tag.to_string()));
            }
            _ => {}
        }
    }

    #[func]
    fn feed_multipeer_data_received(&mut self, peer_tag: GString, bytes: PackedByteArray) {
        self.feed_native_data_received(peer_tag, bytes);
    }

    #[func]
    fn feed_multipeer_peer_disconnected(&mut self, peer_tag: GString) {
        self.feed_native_peer_disconnected(peer_tag);
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
            BridgeMode::MultipeerHost { session, .. } => {
                let prev = session.current_player();
                let res = session.process_command(sender, command);
                (prev, res)
            }
            BridgeMode::RelayHost { session } => {
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
                    BridgeMode::MultipeerHost { session, .. } => session.current_player(),
                    BridgeMode::RelayHost { session } => session.current_player(),
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
    pub fn send_command_json(&mut self, player_id: i64, json_str: GString) {
        let pid = PlayerId(player_id as u32);
        let s = json_str.to_string();
        let command: Box<dyn Command> = match parse_command_json(&s, &self.current_game_type) {
            Ok(cmd) => cmd,
            Err(e) => {
                let msg = format!("Error parsing command JSON: {e}");
                godot_error!("[EngineError] {}", msg);
                self.emit_bridge_signal("move_rejected", &[Variant::from(msg)]);
                return;
            }
        };

        if let BridgeMode::RelayClient { .. } = &self.mode {
            if let Some(relay) = &mut self.relay_client {
                if let Ok(serialized) = serde_json::to_vec(&command) {
                    let _ = relay.send_relay_data(&serialized);
                }
            }
            return;
        }

        if let Ok(events) = self.process_and_emit(pid, command) {
            match &mut self.mode {
                BridgeMode::Host { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                BridgeMode::NativeHost { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                BridgeMode::MultipeerHost { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                BridgeMode::RelayHost { .. } => {
                    if let Some(relay) = &mut self.relay_client {
                        let serialized = serde_json::to_vec(&events).unwrap_or_default();
                        let _ = relay.send_relay_data(&serialized);
                    }
                }
                _ => {}
            }
        }
        self.process_ai_turn_if_needed();
    }

    #[func]
    pub fn get_legal_moves(&self, player_id: i64) -> Array<Dictionary<Variant, Variant>> {
        let player = PlayerId(player_id as u32);
        let moves_json = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
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
                if let Ok(dict) = parsed_var.try_to::<Dictionary<Variant, Variant>>() {
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

        if let BridgeMode::RelayClient { .. } = &self.mode {
            if let Some(relay) = &mut self.relay_client {
                if let Ok(serialized) = serde_json::to_vec(&command) {
                    let _ = relay.send_relay_data(&serialized);
                }
            }
            return;
        }

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
                BridgeMode::MultipeerHost { transport, .. } => {
                    let serialized = serde_json::to_vec(&events).unwrap_or_default();
                    let _ = transport.broadcast(&serialized);
                }
                BridgeMode::RelayHost { .. } => {
                    if let Some(relay) = &mut self.relay_client {
                        let serialized = serde_json::to_vec(&events).unwrap_or_default();
                        let _ = relay.send_relay_data(&serialized);
                    }
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
            | BridgeMode::MultipeerHost { session, .. }
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
        let (id, seed, players, rules) = get_session_init_params(game_type, p1, p2);

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
            BridgeMode::RelayHost { session, .. } => session.export_log().unwrap_or_default(),
            BridgeMode::NativeHost { session, .. } => session.export_log().unwrap_or_default(),
            BridgeMode::MultipeerHost { session, .. } => session.export_log().unwrap_or_default(),
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
    pub fn serialize_state(&self) -> PackedByteArray {
        let state_bytes = match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::RelayHost { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                session.serialize_state().unwrap_or_default()
            }
            BridgeMode::MultiSession { sessions, active } => sessions
                .get(*active)
                .and_then(|(_, s)| s.serialize_state().ok())
                .unwrap_or_default(),
            _ => vec![],
        };
        let mut packed = PackedByteArray::new();
        for b in state_bytes {
            packed.push(b);
        }
        packed
    }

    #[func]
    pub fn restore_state(&mut self, state_bytes: PackedByteArray, game_type: GString) -> bool {
        if !self.load_replay(state_bytes, game_type) {
            return false;
        }
        while self.step_replay() {}
        true
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
                | BridgeMode::MultipeerHost { .. }
                | BridgeMode::MultipeerClient { .. }
                | BridgeMode::RelayHost { .. }
                | BridgeMode::RelayClient { .. }
                | BridgeMode::Spectator { .. }
        )
    }

    #[func]
    pub fn is_network_mode(&self) -> bool {
        self.is_multiplayer() || self.relay_client.is_some()
    }

    #[func]
    pub fn can_undo(&self) -> bool {
        if self.is_network_mode() {
            return false;
        }
        if let BridgeMode::Local { session, .. } = &self.mode {
            return !session.command_log().is_empty();
        }
        false
    }

    #[func]
    pub fn can_redo(&self) -> bool {
        if self.is_network_mode() {
            return false;
        }
        !self.undone_commands.is_empty()
    }

    #[func]
    pub fn undo_last_command(&mut self) -> bool {
        self.undo()
    }

    /// Deshace la última jugada en modo Hotseat o vs IA.
    /// En modo vs IA, si el último comando corresponde a la respuesta de la IA,
    /// deshace tanto la respuesta de la IA como la jugada humana previa.
    /// En partidas de red (`is_network_mode() == true`), retorna `false`.
    #[func]
    pub fn undo_last_move(&mut self) -> bool {
        if self.is_network_mode() {
            return false;
        }

        let steps_to_undo = match &self.mode {
            BridgeMode::Local { session, ai_player } => {
                if session.command_log().is_empty() {
                    return false;
                }
                if let Some(ai_p) = ai_player {
                    let last_is_ai = session
                        .command_log()
                        .last()
                        .and_then(|(_, _, cmd)| cmd.issuer())
                        .map(|issuer| issuer == *ai_p)
                        .unwrap_or(true);
                    if last_is_ai && session.command_log().len() >= 2 {
                        2
                    } else {
                        1
                    }
                } else {
                    1
                }
            }
            _ => return false,
        };

        let mut any_undone = false;
        for _ in 0..steps_to_undo {
            if self.undo() {
                any_undone = true;
            } else {
                break;
            }
        }
        any_undone
    }

    #[func]
    pub fn undo(&mut self) -> bool {
        if self.is_network_mode() {
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
            let sender = cmd.issuer().unwrap_or(PlayerId(1));
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

    /// Inicializa la API de Steamworks; devuelve `false` si Steam no está activo o si se compiló sin `--features steam`.
    #[func]
    pub fn steam_init(&mut self) -> bool {
        steam_bridge::steam_init()
    }

    /// Desbloquea un logro en Steamworks por su ID.
    #[func]
    pub fn steam_unlock_achievement(&mut self, id: GString) -> bool {
        steam_bridge::steam_unlock_achievement(&id.to_string())
    }

    /// Sincroniza datos binarios de una partida guardada en Steam Cloud bajo la clave `slot`.
    #[func]
    pub fn steam_sync_save(&mut self, slot: GString, data: PackedByteArray) -> bool {
        steam_bridge::steam_sync_save(&slot.to_string(), data.as_slice())
    }

    /// Carga datos binarios de una partida guardada desde Steam Cloud bajo la clave `slot`.
    #[func]
    pub fn steam_load_save(&mut self, slot: GString) -> PackedByteArray {
        let bytes = steam_bridge::steam_load_save(&slot.to_string());
        PackedByteArray::from(bytes.as_slice())
    }

    #[func]
    pub fn get_recent_events(&self) -> Array<Dictionary<Variant, Variant>> {
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
            BridgeMode::MultipeerHost { session, .. } => session.current_player().0 as i64,
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
            | BridgeMode::MultipeerHost { session, .. }
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
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                if let Some(deck) = session
                    .world()
                    .get_resource::<mille_bornes_game::DeckResource>()
                {
                    deck.distance.get(&p_id).copied().unwrap_or(0) as i64
                } else {
                    0
                }
            }
            BridgeMode::MultiSession { sessions, active } => {
                if let Some((_, session)) = sessions.get(*active) {
                    if let Some(deck) = session
                        .world()
                        .get_resource::<mille_bornes_game::DeckResource>()
                    {
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
    pub fn get_crisis_territory_owner(&self, territory_id: i64) -> i64 {
        let t_id = crisis_game::TerritoryId(territory_id.clamp(0, 29) as u8);
        match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                if let Some(res) = session
                    .world()
                    .get_resource::<crisis_game::TerritoryStateResource>()
                {
                    res.owners.get(&t_id).map(|p| p.0 as i64).unwrap_or(0)
                } else {
                    0
                }
            }
            _ => 0,
        }
    }

    #[func]
    pub fn get_crisis_territory_armies(&self, territory_id: i64) -> i64 {
        let t_id = crisis_game::TerritoryId(territory_id.clamp(0, 29) as u8);
        match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                if let Some(res) = session
                    .world()
                    .get_resource::<crisis_game::TerritoryStateResource>()
                {
                    res.armies.get(&t_id).copied().unwrap_or(0) as i64
                } else {
                    0
                }
            }
            _ => 0,
        }
    }

    #[func]
    pub fn get_crisis_turn_phase(&self) -> GString {
        match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                if let Some(res) = session
                    .world()
                    .get_resource::<crisis_game::TurnStateResource>()
                {
                    match &res.phase {
                        crisis_game::TurnPhase::PlaceArmies { armies_remaining } => {
                            GString::from(format!("PlaceArmies:{}", armies_remaining).as_str())
                        }
                        crisis_game::TurnPhase::Attack => GString::from("Attack"),
                        crisis_game::TurnPhase::Fortify => GString::from("Fortify"),
                        crisis_game::TurnPhase::EndTurn => GString::from("EndTurn"),
                    }
                } else {
                    GString::from("")
                }
            }
            _ => GString::from(""),
        }
    }

    #[func]
    pub fn get_crisis_remaining_armies(&self) -> i64 {
        match &self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::Replay { session, .. }
            | BridgeMode::Tournament { session, .. } => {
                if let Some(res) = session
                    .world()
                    .get_resource::<crisis_game::TurnStateResource>()
                {
                    match &res.phase {
                        crisis_game::TurnPhase::PlaceArmies { armies_remaining } => {
                            *armies_remaining as i64
                        }
                        _ => 0,
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

    /// Declara la rendición formal del jugador `player_id`, adjudicando la victoria al rival
    /// y emitiendo la señal `game_over(winner_id)`.
    #[func]
    pub fn resign_match(&mut self, player_id: i64) -> i64 {
        let resigning = PlayerId(player_id.max(1) as u32);
        let mut winner_id: i64 = if player_id == 1 { 2 } else { 1 };

        match &mut self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::RelayHost { session }
            | BridgeMode::Tournament { session, .. } => {
                if let Some(turn_res) = session
                    .world()
                    .get_resource::<open_table_engine::turn::TurnResource>()
                {
                    if let Some(opp) = turn_res.0.players().iter().find(|&&p| p != resigning) {
                        winner_id = opp.0 as i64;
                    }
                }
                session
                    .world_mut()
                    .insert_resource(open_table_engine::session::GameOverResource(true));
                session.world_mut().insert_resource(
                    open_table_engine::session::WinnerResource(Some(PlayerId(winner_id as u32))),
                );
            }
            BridgeMode::MultiSession { sessions, active } => {
                if let Some((_, session)) = sessions.get_mut(*active) {
                    if let Some(turn_res) = session
                        .world()
                        .get_resource::<open_table_engine::turn::TurnResource>()
                    {
                        if let Some(opp) = turn_res.0.players().iter().find(|&&p| p != resigning) {
                            winner_id = opp.0 as i64;
                        }
                    }
                    session
                        .world_mut()
                        .insert_resource(open_table_engine::session::GameOverResource(true));
                    session.world_mut().insert_resource(
                        open_table_engine::session::WinnerResource(Some(PlayerId(
                            winner_id as u32,
                        ))),
                    );
                }
            }
            _ => {}
        }

        let events: Vec<Box<dyn Event>> = vec![Box::new(GameOverEvent {
            winner: PlayerId(winner_id as u32),
        })];
        let serialized = serde_json::to_vec(&events).unwrap_or_default();
        match &mut self.mode {
            BridgeMode::Host { transport, .. } => {
                let _ = transport.broadcast(&serialized);
            }
            BridgeMode::NativeHost { transport, .. } => {
                let _ = transport.broadcast(&serialized);
            }
            BridgeMode::MultipeerHost { transport, .. } => {
                let _ = transport.broadcast(&serialized);
            }
            BridgeMode::RelayHost { .. } => {
                if let Some(relay) = &mut self.relay_client {
                    let _ = relay.send_relay_data(&serialized);
                }
            }
            _ => {}
        }

        self.emit_bridge_signal("game_over", &[Variant::from(winner_id)]);
        self.check_advance_tournament(winner_id);
        winner_id
    }

    /// Declara tablas (empate formal) en la partida activa y emite `game_over(0)`.
    #[func]
    pub fn declare_draw(&mut self) -> bool {
        match &mut self.mode {
            BridgeMode::Local { session, .. }
            | BridgeMode::Host { session, .. }
            | BridgeMode::NativeHost { session, .. }
            | BridgeMode::MultipeerHost { session, .. }
            | BridgeMode::RelayHost { session }
            | BridgeMode::Tournament { session, .. } => {
                session
                    .world_mut()
                    .insert_resource(open_table_engine::session::GameOverResource(true));
                session
                    .world_mut()
                    .insert_resource(open_table_engine::session::WinnerResource(None));
            }
            BridgeMode::MultiSession { sessions, active } => {
                if let Some((_, session)) = sessions.get_mut(*active) {
                    session
                        .world_mut()
                        .insert_resource(open_table_engine::session::GameOverResource(true));
                    session
                        .world_mut()
                        .insert_resource(open_table_engine::session::WinnerResource(None));
                }
            }
            _ => {}
        }

        let events: Vec<Box<dyn Event>> = vec![Box::new(go_game::GameOverEvent {
            winner: None,
            black_score: 0.0,
            white_score: 0.0,
        })];
        let serialized = serde_json::to_vec(&events).unwrap_or_default();
        match &mut self.mode {
            BridgeMode::Host { transport, .. } => {
                let _ = transport.broadcast(&serialized);
            }
            BridgeMode::NativeHost { transport, .. } => {
                let _ = transport.broadcast(&serialized);
            }
            BridgeMode::MultipeerHost { transport, .. } => {
                let _ = transport.broadcast(&serialized);
            }
            BridgeMode::RelayHost { .. } => {
                if let Some(relay) = &mut self.relay_client {
                    let _ = relay.send_relay_data(&serialized);
                }
            }
            _ => {}
        }

        self.emit_bridge_signal("game_over", &[Variant::from(0_i64)]);
        self.check_advance_tournament(0);
        true
    }

    #[func]
    fn poll_events(&mut self) {
        match &mut self.mode {
            BridgeMode::Host { .. } => self.poll_host_events(),
            BridgeMode::Client { .. } => self.poll_client_events(),
            BridgeMode::Spectator { .. } => self.poll_spectator_events(),
            BridgeMode::NativeHost { .. } => self.poll_native_host_events(),
            BridgeMode::NativeClient { .. } => self.poll_native_client_events(),
            BridgeMode::MultipeerHost { .. } => self.poll_multipeer_host_events(),
            BridgeMode::MultipeerClient { .. } => self.poll_multipeer_client_events(),
            BridgeMode::RelayHost { .. } | BridgeMode::RelayClient { .. } => {
                self.poll_relay_events();
            }
            BridgeMode::Local { .. } => self.process_ai_turn_if_needed(),
            BridgeMode::None
            | BridgeMode::Replay { .. }
            | BridgeMode::Tournament { .. }
            | BridgeMode::MultiSession { .. } => {
                if self.relay_client.is_some() {
                    self.poll_relay_events();
                }
            }
        }
        self.flush_native_outgoing();
    }

    fn poll_relay_events(&mut self) {
        let events = match &mut self.relay_client {
            Some(relay) => relay.poll_relay_events(),
            None => return,
        };

        for ev in events {
            match ev {
                RelayClientEvent::RoomCreated { room_code } => {
                    self.base_mut()
                        .emit_signal("room_created", &[Variant::from(GString::from(&room_code))]);
                }
                RelayClientEvent::RoomJoined {
                    success, player_id, ..
                } => {
                    let pid = if success { player_id.0 as i64 } else { -1 };
                    self.base_mut()
                        .emit_signal("room_joined", &[Variant::from(success), Variant::from(pid)]);
                }
                RelayClientEvent::PeerJoined { player_id } => {
                    let pid = player_id.0 as i64;
                    self.base_mut()
                        .emit_signal("peer_joined", &[Variant::from(pid)]);
                    self.base_mut()
                        .emit_signal("player_joined", &[Variant::from(pid)]);
                }
                RelayClientEvent::PeerLeft { player_id } => {
                    let pid = player_id.0 as i64;
                    self.base_mut()
                        .emit_signal("peer_disconnected", &[Variant::from(pid)]);
                }
                RelayClientEvent::PayloadReceived { from, data } => match &mut self.mode {
                    BridgeMode::RelayHost { session } => {
                        if let Ok(SyncProtocolMessage::RequestSync) =
                            serde_json::from_slice::<SyncProtocolMessage>(&data)
                        {
                            let log_bytes = session.export_log().unwrap_or_default();
                            let sync_msg = SyncProtocolMessage::SyncLog {
                                game_type: self.current_game_type.clone(),
                                log_bytes,
                            };
                            if let Ok(serialized) = serde_json::to_vec(&sync_msg) {
                                if let Some(relay) = &mut self.relay_client {
                                    let _ = relay.send_relay_data(&serialized);
                                }
                            }
                            continue;
                        }

                        let cmd_str = String::from_utf8_lossy(&data);
                        if let Ok(command) = parse_command_json(&cmd_str, &self.current_game_type) {
                            let sender = if from.0 == 0 { PlayerId(2) } else { from };
                            if let Ok(game_events) = self.process_and_emit(sender, command) {
                                if let Some(relay) = &mut self.relay_client {
                                    let serialized =
                                        serde_json::to_vec(&game_events).unwrap_or_default();
                                    let _ = relay.send_relay_data(&serialized);
                                }
                            }
                        }
                    }
                    BridgeMode::RelayClient { .. } => {
                        if let Ok(SyncProtocolMessage::SyncLog {
                            game_type,
                            log_bytes,
                        }) = serde_json::from_slice::<SyncProtocolMessage>(&data)
                        {
                            let gtype = if !game_type.is_empty() {
                                game_type
                            } else {
                                self.current_game_type.clone()
                            };
                            let (id, seed, players, rules) =
                                get_session_init_params(&gtype, PlayerId(1), PlayerId(2));
                            if let Ok((loaded_session, game_events)) =
                                Session::replay_collecting_events(
                                    id, seed, players, rules, &log_bytes,
                                )
                            {
                                let current_p = loaded_session.current_player().0 as i64;
                                self.emit_game_events(&game_events);
                                self.base_mut()
                                    .emit_signal("turn_changed", &[Variant::from(current_p)]);
                            }
                            continue;
                        }

                        if let Ok(game_events) =
                            serde_json::from_slice::<Vec<Box<dyn Event>>>(&data)
                        {
                            self.emit_game_events(&game_events);
                        }
                    }
                    _ => {}
                },
                RelayClientEvent::Reconnecting { attempt, .. } => {
                    self.base_mut()
                        .emit_signal("connection_reconnecting", &[Variant::from(attempt as i64)]);
                }
                RelayClientEvent::ConnectionRestored {
                    room_code: _,
                    player_id,
                    seed,
                    commands,
                } => {
                    if !commands.is_empty() {
                        let gtype = if self.current_game_type.is_empty() {
                            "checkers".to_string()
                        } else {
                            self.current_game_type.clone()
                        };
                        let (_, _, players, rules) =
                            get_session_init_params(&gtype, PlayerId(1), PlayerId(2));
                        let mut restored_session = Session::new(SessionId(1), seed, players, rules);
                        let mut collected_events = Vec::new();
                        for cmd_val in &commands {
                            if let Ok(cmd_str) = serde_json::to_string(cmd_val) {
                                if let Ok(cmd) = parse_command_json(&cmd_str, &gtype) {
                                    let issuer = cmd
                                        .issuer()
                                        .unwrap_or_else(|| restored_session.current_player());
                                    if let Ok(evs) = restored_session.process_command(issuer, cmd) {
                                        collected_events.extend(evs);
                                    }
                                }
                            }
                        }
                        let current_p = restored_session.current_player().0 as i64;
                        match &mut self.mode {
                            BridgeMode::RelayHost { session } => {
                                *session = restored_session;
                            }
                            BridgeMode::RelayClient {
                                player_id: pid,
                                client_current_player,
                            } => {
                                *pid = player_id;
                                *client_current_player = current_p;
                            }
                            _ => {}
                        }
                        if !collected_events.is_empty() {
                            self.emit_game_events(&collected_events);
                        }
                        self.base_mut()
                            .emit_signal("turn_changed", &[Variant::from(current_p)]);
                    }
                    self.base_mut().emit_signal("connection_restored", &[]);
                }
                RelayClientEvent::Disconnected => {
                    self.base_mut().emit_signal("disconnected", &[]);
                }
                RelayClientEvent::PongReceived | RelayClientEvent::Error { .. } => {}
            }
        }
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
            if let Ok(SyncProtocolMessage::RequestSync) =
                serde_json::from_slice::<SyncProtocolMessage>(&command_bytes)
            {
                if let BridgeMode::Host { session, transport } = &mut self.mode {
                    let log_bytes = session.export_log().unwrap_or_default();
                    let sync_msg = SyncProtocolMessage::SyncLog {
                        game_type: self.current_game_type.clone(),
                        log_bytes,
                    };
                    if let Ok(serialized) = serde_json::to_vec(&sync_msg) {
                        let _ = transport.send(player_id, &serialized);
                    }
                }
                continue;
            }

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
            if let Ok(SyncProtocolMessage::SyncLog {
                game_type,
                log_bytes,
            }) = serde_json::from_slice::<SyncProtocolMessage>(&event_bytes)
            {
                let gtype = if !game_type.is_empty() {
                    game_type
                } else {
                    self.current_game_type.clone()
                };
                let (id, seed, players, rules) =
                    get_session_init_params(&gtype, PlayerId(1), PlayerId(2));
                if let Ok((loaded_session, events)) =
                    Session::replay_collecting_events(id, seed, players, rules, &log_bytes)
                {
                    let current_p = loaded_session.current_player().0 as i64;
                    self.emit_game_events(&events);
                    self.base_mut()
                        .emit_signal("turn_changed", &[Variant::from(current_p)]);
                }
                continue;
            }

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
            if let Ok(SyncProtocolMessage::SyncLog {
                game_type,
                log_bytes,
            }) = serde_json::from_slice::<SyncProtocolMessage>(&event_bytes)
            {
                let gtype = if !game_type.is_empty() {
                    game_type
                } else {
                    self.current_game_type.clone()
                };
                let (id, seed, players, rules) =
                    get_session_init_params(&gtype, PlayerId(1), PlayerId(2));
                if let Ok((_loaded_session, events)) =
                    Session::replay_collecting_events(id, seed, players, rules, &log_bytes)
                {
                    for event in &events {
                        if let Ok(json) = serde_json::to_string(event) {
                            self.base_mut()
                                .emit_signal("spectator_event_received", &[Variant::from(json)]);
                        }
                    }
                    self.emit_game_events(&events);
                }
                continue;
            }

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
            if let Ok(SyncProtocolMessage::RequestSync) =
                serde_json::from_slice::<SyncProtocolMessage>(&command_bytes)
            {
                if let BridgeMode::NativeHost {
                    session, transport, ..
                } = &mut self.mode
                {
                    let log_bytes = session.export_log().unwrap_or_default();
                    let sync_msg = SyncProtocolMessage::SyncLog {
                        game_type: self.current_game_type.clone(),
                        log_bytes,
                    };
                    if let Ok(serialized) = serde_json::to_vec(&sync_msg) {
                        let _ = transport.send(player_id, &serialized);
                    }
                }
                continue;
            }

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
                    let sync_req = SyncProtocolMessage::RequestSync;
                    if let Ok(serialized) = serde_json::to_vec(&sync_req) {
                        let _ = transport.send(
                            open_table_transport_native_bridge::HOST_PLAYER_ID,
                            &serialized,
                        );
                    }
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
            if let Ok(SyncProtocolMessage::SyncLog {
                game_type,
                log_bytes,
            }) = serde_json::from_slice::<SyncProtocolMessage>(&event_bytes)
            {
                let gtype = if !game_type.is_empty() {
                    game_type
                } else {
                    self.current_game_type.clone()
                };
                let (id, seed, players, rules) =
                    get_session_init_params(&gtype, PlayerId(1), PlayerId(2));
                if let Ok((loaded_session, events)) =
                    Session::replay_collecting_events(id, seed, players, rules, &log_bytes)
                {
                    let current_p = loaded_session.current_player().0 as i64;
                    self.emit_game_events(&events);
                    self.base_mut()
                        .emit_signal("turn_changed", &[Variant::from(current_p)]);
                }
                continue;
            }

            if let Ok(events) = serde_json::from_slice::<Vec<Box<dyn Event>>>(&event_bytes) {
                self.emit_game_events(&events);
            }
        }
    }

    fn poll_multipeer_host_events(&mut self) {
        let BridgeMode::MultipeerHost { transport, .. } = &mut self.mode else {
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

        let BridgeMode::MultipeerHost { transport, .. } = &mut self.mode else {
            return;
        };

        let received = transport.poll_received();
        for (player_id, command_bytes) in received {
            if let Ok(SyncProtocolMessage::RequestSync) =
                serde_json::from_slice::<SyncProtocolMessage>(&command_bytes)
            {
                if let BridgeMode::MultipeerHost {
                    session, transport, ..
                } = &mut self.mode
                {
                    let log_bytes = session.export_log().unwrap_or_default();
                    let sync_msg = SyncProtocolMessage::SyncLog {
                        game_type: self.current_game_type.clone(),
                        log_bytes,
                    };
                    if let Ok(serialized) = serde_json::to_vec(&sync_msg) {
                        let _ = transport.send(player_id, &serialized);
                    }
                }
                continue;
            }

            let cmd_str = String::from_utf8_lossy(&command_bytes);
            if let Ok(command) = parse_command_json(&cmd_str, &self.current_game_type) {
                if let Ok(events) = self.process_and_emit(player_id, command) {
                    if let BridgeMode::MultipeerHost { transport, .. } = &mut self.mode {
                        let serialized = serde_json::to_vec(&events).unwrap_or_default();
                        let _ = transport.broadcast(&serialized);
                    }
                }
            }
        }
    }

    fn poll_multipeer_client_events(&mut self) {
        let BridgeMode::MultipeerClient {
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
                    let sync_req = SyncProtocolMessage::RequestSync;
                    if let Ok(serialized) = serde_json::to_vec(&sync_req) {
                        let _ = transport.send(
                            open_table_transport_native_bridge::HOST_PLAYER_ID,
                            &serialized,
                        );
                    }
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

        let BridgeMode::MultipeerClient { transport, .. } = &mut self.mode else {
            return;
        };

        let received = transport.poll_received();
        for (_host_id, event_bytes) in received {
            if let Ok(SyncProtocolMessage::SyncLog {
                game_type,
                log_bytes,
            }) = serde_json::from_slice::<SyncProtocolMessage>(&event_bytes)
            {
                let gtype = if !game_type.is_empty() {
                    game_type
                } else {
                    self.current_game_type.clone()
                };
                let (id, seed, players, rules) =
                    get_session_init_params(&gtype, PlayerId(1), PlayerId(2));
                if let Ok((loaded_session, events)) =
                    Session::replay_collecting_events(id, seed, players, rules, &log_bytes)
                {
                    let current_p = loaded_session.current_player().0 as i64;
                    self.emit_game_events(&events);
                    self.base_mut()
                        .emit_signal("turn_changed", &[Variant::from(current_p)]);
                }
                continue;
            }

            if let Ok(events) = serde_json::from_slice::<Vec<Box<dyn Event>>>(&event_bytes) {
                self.emit_game_events(&events);
            }
        }
    }

    fn flush_native_outgoing(&mut self) {
        let (sends, broadcasts, raw_bytes) = match &self.mode {
            BridgeMode::NativeHost { queue, .. }
            | BridgeMode::NativeClient { queue, .. }
            | BridgeMode::MultipeerHost { queue, .. }
            | BridgeMode::MultipeerClient { queue, .. } => {
                let mut q = queue.lock().unwrap();
                let sends = std::mem::take(&mut q.outgoing_sends);
                let broadcasts = std::mem::take(&mut q.outgoing_broadcasts);
                let raw_bytes = std::mem::take(&mut q.outgoing_raw_bytes);
                (sends, broadcasts, raw_bytes)
            }
            _ => return,
        };

        for bytes in raw_bytes {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            self.base_mut()
                .emit_signal("native_send_bytes", &[Variant::from(packed)]);
        }

        for (peer_tag, bytes) in sends {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            self.base_mut().emit_signal(
                "native_send_requested",
                &[Variant::from(peer_tag), Variant::from(packed.clone())],
            );
            self.base_mut()
                .emit_signal("native_send_bytes", &[Variant::from(packed)]);
        }

        for bytes in broadcasts {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            self.base_mut().emit_signal(
                "native_broadcast_requested",
                &[Variant::from(packed.clone())],
            );
            self.base_mut()
                .emit_signal("native_send_bytes", &[Variant::from(packed)]);
        }
    }

    fn emit_game_events(&mut self, events: &[Box<dyn Event>]) {
        for event in events {
            if let Ok(json) = serde_json::to_string(event) {
                self.emit_bridge_signal("event_json", &[Variant::from(json.clone())]);
                let parsed_var = godot::classes::Json::parse_string(&GString::from(&json));
                if let Ok(dict) = parsed_var.try_to::<Dictionary<Variant, Variant>>() {
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
                let mut att_rolls = Array::<Variant>::new();
                for &r in &c_attack.attacker_rolls {
                    att_rolls.push(&Variant::from(r as i64));
                }
                let mut def_rolls = Array::<Variant>::new();
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
                    (
                        round,
                        Some((p1, p2, r, turn)),
                        false,
                        Dictionary::<i64, i64>::new(),
                    )
                } else {
                    let mut dict = Dictionary::<i64, i64>::new();
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
        let max_steps = if self.current_game_type == "crisis" {
            16
        } else {
            2
        };
        loop {
            if steps >= max_steps {
                break;
            }
            let (acting_p, cmd_opt): (PlayerId, Option<Box<dyn Command>>) = match &self.mode {
                BridgeMode::Local {
                    session,
                    ai_player: Some(ai_p),
                } => {
                    let curr_p = session.current_player();
                    let is_ai_turn = curr_p == *ai_p;
                    if is_ai_turn
                        || self.current_game_type == "shogi"
                        || self.current_game_type == "xiangqi"
                        || self.current_game_type == "go"
                        || self.current_game_type == "monopoly"
                    {
                        let acting = if self.current_game_type == "monopoly" {
                            *ai_p
                        } else {
                            curr_p
                        };
                        let cmd: Option<Box<dyn Command>> = match self.current_game_type.as_str() {
                            "chess" if is_ai_turn => {
                                chess_game::ai::best_move(session, *ai_p, self.ai_difficulty)
                                    .map(|c| Box::new(c) as Box<dyn Command>)
                            }
                            "shogi" => {
                                shogi_game::ai::best_move(session, curr_p, self.ai_difficulty)
                            }
                            "xiangqi" => {
                                xiangqi_game::ai::best_move(session, curr_p, self.ai_difficulty)
                                    .map(|c| Box::new(c) as Box<dyn Command>)
                            }
                            "go" => go_game::ai::best_move(session, curr_p, self.ai_difficulty)
                                .map(|c| Box::new(c) as Box<dyn Command>)
                                .or_else(|| {
                                    Some(Box::new(go_game::PassCommand { player: curr_p })
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
                                    Some(Box::new(backgammon_game::RollDiceCommand {
                                        player: *ai_p,
                                    }) as Box<dyn Command>)
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
                                    ludo_game::ai::best_move(session, *ai_p, self.ai_difficulty)
                                        .map(|c| Box::new(c) as Box<dyn Command>)
                                }
                            }
                            "battleship" if is_ai_turn => {
                                let ai_has_fleet = session
                                    .world()
                                    .get_resource::<battleship_game::FleetResource>()
                                    .map(|f| f.has_placed_fleet(*ai_p))
                                    .unwrap_or(false);
                                if !ai_has_fleet {
                                    Some(Box::new(battleship_game::default_ai_place_fleet_command(
                                        *ai_p,
                                    )) as Box<dyn Command>)
                                } else {
                                    let both_placed = session
                                        .world()
                                        .get_resource::<battleship_game::FleetResource>()
                                        .map(|f| f.ships.len() >= 2)
                                        .unwrap_or(false);
                                    if both_placed {
                                        battleship_game::ai::best_move(
                                            session,
                                            *ai_p,
                                            self.ai_difficulty,
                                        )
                                        .map(|c| Box::new(c) as Box<dyn Command>)
                                    } else {
                                        None
                                    }
                                }
                            }
                            "mille_bornes" | "mille-bornes" | "millebornes" if is_ai_turn => {
                                mille_bornes_game::ai::best_move(session, *ai_p, self.ai_difficulty)
                                    .map(|c| c.into_command())
                            }
                            "uno" if is_ai_turn => {
                                uno_game::ai::best_move(session, *ai_p, self.ai_difficulty)
                                    .map(|c| c.into_command())
                            }
                            "monopoly" => {
                                monopoly_game::ai::best_move(session, *ai_p, self.ai_difficulty)
                                    .map(|c| c.into_command())
                            }
                            "chinese_checkers" | "chinese-checkers" | "chinesecheckers"
                                if is_ai_turn =>
                            {
                                chinese_checkers_game::ai::best_move(
                                    session,
                                    *ai_p,
                                    self.ai_difficulty,
                                )
                                .map(|c| Box::new(c) as Box<dyn Command>)
                            }
                            "crisis" | "teg" if is_ai_turn => {
                                crisis_game::ai::best_move(session, *ai_p, self.ai_difficulty)
                                    .map(|c| c.into_command())
                            }
                            _ if is_ai_turn => {
                                checkers_game::ai::best_move(session, *ai_p, self.ai_difficulty)
                                    .map(|c| Box::new(c) as Box<dyn Command>)
                            }
                            _ => None,
                        };
                        (acting, cmd)
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extended_ai_engines_produce_valid_commands_in_easy_mode() {
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let easy = AiDifficulty::Easy;

        // 1. Battleship
        let mut bs = new_battleship_session(SessionId(1), 1, p1, p2);
        bs.process_command(
            p1,
            Box::new(battleship_game::default_ai_place_fleet_command(p1)),
        )
        .unwrap();
        bs.process_command(
            p2,
            Box::new(battleship_game::default_ai_place_fleet_command(p2)),
        )
        .unwrap();
        assert!(battleship_game::ai::best_move(&bs, p1, easy).is_some());

        // 2. Mille Bornes
        let mb = new_mille_bornes_session(SessionId(2), 1, p1, p2);
        assert!(mille_bornes_game::ai::best_move(&mb, p1, easy).is_some());

        // 3. UNO
        let uno = new_uno_session(SessionId(3), 1, vec![p1, p2]);
        assert!(uno_game::ai::best_move(&uno, p1, easy).is_some());

        // 4. Monopoly
        let mono = new_monopoly_session(SessionId(4), 1, p1, p2);
        assert!(monopoly_game::ai::best_move(&mono, p1, easy).is_some());

        // 5. Chinese Checkers
        let cc = new_chinese_checkers_session(SessionId(5), 1, vec![p1, p2]);
        assert!(chinese_checkers_game::ai::best_move(&cc, p1, easy).is_some());

        // 6. Crisis / TEG
        let crisis = new_crisis_session(SessionId(6), 1, &[p1, p2]).unwrap();
        assert!(crisis_game::ai::best_move(&crisis, p1, easy).is_some());
    }
}
