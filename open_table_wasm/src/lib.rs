//! Puente WebAssembly (`wasm-bindgen`) para los 14 motores de juego de OpenTable SDK.
//! Expone `WasmGameBridge` a TypeScript/React reutilizando el 100% de las reglas canónicas,
//! generadores de jugadas legales (`LegalMoveGenerator`) e IA determinista en Rust.

use wasm_bindgen::prelude::*;

use backgammon_game::new_backgammon_session;
use battleship_game::new_battleship_session;
use checkers_game::new_checkers_session;
use chess_game::new_chess_session;
use chinese_checkers_game::new_chinese_checkers_session;
use crisis_game::new_crisis_session;
use go_game::new_go_session;
use goose_game::new_goose_session;
use ludo_game::new_ludo_session;
use mille_bornes_game::new_mille_bornes_session;
use monopoly_game::new_monopoly_session;
use open_table_core::command::Command;
use open_table_core::event::Event;
use open_table_core::ids::{PlayerId, SessionId};
use open_table_core::AiDifficulty;
use open_table_engine::session::Session;
use shogi_game::new_shogi_session;
use uno_game::new_uno_session;
use xiangqi_game::new_xiangqi_session;

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
        "crisis" | "teg" => new_crisis_session(id, seed, &[p1, p2]).ok(),
        "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => {
            Some(new_chinese_checkers_session(id, seed, vec![p1, p2]))
        }
        "mille_bornes" | "mille-bornes" | "millebornes" => {
            Some(new_mille_bornes_session(id, seed, p1, p2))
        }
        "backgammon" => Some(new_backgammon_session(id, seed, p1, p2)),
        "monopoly" => Some(new_monopoly_session(id, seed, p1, p2)),
        "ludo" => Some(new_ludo_session(id, seed, vec![p1, p2])),
        "goose" | "oca" => Some(new_goose_session(id, seed, vec![p1, p2])),
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
                        "uno_game::",
                        "goose_game::",
                        "backgammon_game::",
                        "shogi_game::",
                        "xiangqi_game::",
                        "go_game::",
                        "crisis_game::",
                        "ludo_game::",
                        "chinese_checkers_game::",
                        "mille_bornes_game::",
                        "monopoly_game::",
                        "battleship_game::",
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
                }
            }
        }
    }

    serde_json::from_str::<Box<dyn Command>>(json_str)
}

#[wasm_bindgen]
pub struct WasmGameBridge {
    session: Option<Session>,
    current_game_type: String,
    ai_player: Option<PlayerId>,
    ai_difficulty: AiDifficulty,
    replay_log: Vec<(u32, String)>,
    replay_cursor: usize,
    forced_winner: Option<u32>,
}

#[wasm_bindgen]
impl WasmGameBridge {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        let mut bridge = Self {
            session: None,
            current_game_type: "chess".to_string(),
            ai_player: None,
            ai_difficulty: AiDifficulty::Medium,
            replay_log: Vec::new(),
            replay_cursor: 0,
            forced_winner: None,
        };
        bridge.start_local_match("chess", 1, 2);
        bridge
    }

    pub fn start_local_match(&mut self, game_type: &str, p1: u32, p2: u32) -> bool {
        let gtype = game_type.trim().to_lowercase();
        if let Some(sess) =
            create_session_for_players(&gtype, PlayerId(p1.max(1)), PlayerId(p2.max(2)))
        {
            self.current_game_type = gtype;
            self.session = Some(sess);
            self.ai_player = None;
            self.replay_log.clear();
            self.replay_cursor = 0;
            self.forced_winner = None;
            true
        } else {
            false
        }
    }

    pub fn start_ai_match(
        &mut self,
        game_type: &str,
        human_id: u32,
        ai_id: u32,
        difficulty: i64,
    ) -> bool {
        let gtype = game_type.trim().to_lowercase();
        let p_human = PlayerId(human_id.max(1));
        let p_ai = PlayerId(ai_id.max(2));
        let (p1, p2) = if p_human.0 < p_ai.0 {
            (p_human, p_ai)
        } else {
            (p_ai, p_human)
        };
        if let Some(mut sess) = create_session_for_players(&gtype, p1, p2) {
            if gtype == "battleship" {
                let _ = sess.process_command(
                    p_ai,
                    Box::new(battleship_game::default_ai_place_fleet_command(p_ai)),
                );
            }
            self.current_game_type = gtype;
            self.session = Some(sess);
            self.ai_player = Some(p_ai);
            self.ai_difficulty = AiDifficulty::from_i64(difficulty);
            self.replay_log.clear();
            self.replay_cursor = 0;
            self.forced_winner = None;
            true
        } else {
            false
        }
    }

    pub fn current_player(&self) -> u32 {
        self.session
            .as_ref()
            .map(|s| s.current_player().0)
            .unwrap_or(1)
    }

    pub fn current_tick(&self) -> u64 {
        self.session
            .as_ref()
            .map(|s| s.current_tick().0)
            .unwrap_or(0)
    }

    pub fn get_current_game_type(&self) -> String {
        self.current_game_type.clone()
    }

    pub fn get_legal_moves_json(&self, player_id: u32) -> String {
        let Some(sess) = &self.session else {
            return "[]".to_string();
        };
        let moves = sess.get_legal_moves(PlayerId(player_id.max(1)));
        serde_json::to_string(&moves).unwrap_or_else(|_| "[]".to_string())
    }

    pub fn get_state_json(&self) -> String {
        let Some(sess) = &self.session else {
            return r#"{"error":"no_active_session"}"#.to_string();
        };
        let turn = sess.current_player().0;
        let tick = sess.current_tick().0;
        let winner: Option<u32> = self.forced_winner.or_else(|| {
            sess.world()
                .get_resource::<open_table_engine::resources::WinnerResource>()
                .and_then(|w| w.0.map(|pid| pid.0))
        });

        let payload = serde_json::json!({
            "game_type": self.current_game_type,
            "turn": turn,
            "tick": tick,
            "winner": winner,
            "legal_moves": sess.get_legal_moves(sess.current_player()),
        });
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    }

    pub fn send_command_json(&mut self, player_id: u32, json_str: &str) -> String {
        let gtype = self.current_game_type.clone();
        let Ok(cmd) = parse_command_json(json_str, &gtype) else {
            return r#"{"ok":false,"error":"invalid_command_json"}"#.to_string();
        };
        let Some(sess) = &mut self.session else {
            return r#"{"ok":false,"error":"no_active_session"}"#.to_string();
        };
        match sess.process_command(PlayerId(player_id.max(1)), cmd) {
            Ok(events) => {
                if self.replay_cursor < self.replay_log.len() {
                    self.replay_log.truncate(self.replay_cursor);
                }
                self.replay_log.push((player_id.max(1), json_str.to_string()));
                self.replay_cursor = self.replay_log.len();
                serde_json::to_string(&events).unwrap_or_else(|_| "[]".to_string())
            }
            Err(e) => format!(r#"{{"ok":false,"error":{:?}}}"#, e.to_string()),
        }
    }

    pub fn export_log_json(&self) -> String {
        let Some(sess) = &self.session else {
            return "[]".to_string();
        };
        let bytes = sess.export_log().unwrap_or_default();
        String::from_utf8(bytes).unwrap_or_else(|_| "[]".to_string())
    }

    pub fn apply_sync_log_json(&mut self, game_type: &str, log_json: &str) -> bool {
        let gtype = if game_type.trim().is_empty() {
            self.current_game_type.clone()
        } else {
            game_type.trim().to_lowercase()
        };
        let Some(mut sess) = create_session_for_players(&gtype, PlayerId(1), PlayerId(2)) else {
            return false;
        };
        if !log_json.trim().is_empty() {
            let Ok(logged) =
                serde_json::from_slice::<Vec<open_table_engine::session::LoggedCommand>>(
                    log_json.as_bytes(),
                )
            else {
                return false;
            };
            for (_tick, _elapsed, command) in logged {
                let sender = command.issuer().unwrap_or_else(|| sess.current_player());
                if sess.process_command(sender, command).is_err() {
                    return false;
                }
            }
        }
        self.current_game_type = gtype;
        self.session = Some(sess);
        true
    }

    pub fn get_replay_step_count(&self) -> usize {
        self.replay_log.len()
    }

    pub fn get_current_replay_step(&self) -> usize {
        self.replay_cursor
    }

    pub fn is_replay_at_live_head(&self) -> bool {
        self.replay_cursor >= self.replay_log.len()
    }

    pub fn seek_replay_step(&mut self, step_index: usize) -> bool {
        let target = step_index.min(self.replay_log.len());
        let saved_log = self.replay_log.clone();
        let gtype = self.current_game_type.clone();
        let Some(mut sess) = create_session_for_players(&gtype, PlayerId(1), PlayerId(2)) else {
            return false;
        };
        for (pid, cmd_str) in saved_log.iter().take(target) {
            if let Ok(cmd) = parse_command_json(cmd_str, &gtype) {
                let _ = sess.process_command(PlayerId(*pid), cmd);
            }
        }
        self.session = Some(sess);
        self.replay_log = saved_log;
        self.replay_cursor = target;
        true
    }

    pub fn force_timeout_win(&mut self, winner_id: u32) {
        self.forced_winner = Some(winner_id.max(1));
    }

    pub fn export_chess_fen(&self) -> String {
        self.session
            .as_ref()
            .map(chess_game::export_session_fen)
            .unwrap_or_default()
    }

    pub fn generate_join_qr_svg(&self, join_code: &str, host_name: &str, game_type: &str) -> String {
        let payload = open_table_qr::JoinPayload {
            session_id: SessionId(1),
            join_code: join_code.to_string(),
            host_name: host_name.to_string(),
            game_type: game_type.to_string(),
        };
        open_table_qr::generate_join_qr_svg(&payload).unwrap_or_default()
    }

    pub fn step_ai_if_needed(&mut self) -> String {
        let Some(ai_p) = self.ai_player else {
            return "[]".to_string();
        };
        let Some(sess) = &mut self.session else {
            return "[]".to_string();
        };
        if sess.current_player() != ai_p {
            return "[]".to_string();
        }
        let gtype = self.current_game_type.as_str();
        let cmd_opt: Option<Box<dyn Command>> = match gtype {
            "chess" => chess_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                .map(|c| Box::new(c) as Box<dyn Command>),
            "checkers" => checkers_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                .map(|c| Box::new(c) as Box<dyn Command>),
            "shogi" => shogi_game::ai::best_move(sess, ai_p, self.ai_difficulty),
            "xiangqi" => xiangqi_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                .map(|c| Box::new(c) as Box<dyn Command>),
            "go" => go_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                .map(|c| Box::new(c) as Box<dyn Command>)
                .or_else(|| Some(Box::new(go_game::PassCommand { player: ai_p }) as Box<dyn Command>)),
            "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => {
                chinese_checkers_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                    .map(|c| Box::new(c) as Box<dyn Command>)
            }
            "backgammon" => {
                let has_pending = sess
                    .world()
                    .get_resource::<backgammon_game::PendingDiceResource>()
                    .and_then(|p| p.pending.get(&ai_p))
                    .map(|d| !d.is_empty())
                    .unwrap_or(false);
                if !has_pending {
                    Some(Box::new(backgammon_game::RollDiceCommand { player: ai_p })
                        as Box<dyn Command>)
                } else {
                    backgammon_game::backgammon_ai_pick_move(sess, ai_p)
                        .map(|c| Box::new(c) as Box<dyn Command>)
                }
            }
            "ludo" => {
                let has_pending = sess
                    .world()
                    .get_resource::<ludo_game::PendingRollResource>()
                    .and_then(|p| p.pending.get(&ai_p))
                    .is_some();
                if !has_pending {
                    Some(Box::new(ludo_game::RollDiceCommand { player: ai_p }) as Box<dyn Command>)
                } else {
                    ludo_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                        .map(|c| Box::new(c) as Box<dyn Command>)
                }
            }
            "battleship" => battleship_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                .map(|c| Box::new(c) as Box<dyn Command>),
            "mille_bornes" | "mille-bornes" | "millebornes" => {
                let needs_draw = sess
                    .world()
                    .get_resource::<mille_bornes_game::DeckResource>()
                    .is_some_and(|deck| {
                        let hand_len = deck.hands.get(&ai_p).map(Vec::len).unwrap_or(0);
                        hand_len < mille_bornes_game::MAX_HAND_SIZE
                            && (!deck.draw_pile.is_empty() || !deck.discard_pile.is_empty())
                    });
                if needs_draw {
                    Some(Box::new(mille_bornes_game::DrawCardCommand { player: ai_p })
                        as Box<dyn Command>)
                } else {
                    mille_bornes_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                        .map(|c| c.into_command())
                }
            }
            "monopoly" => monopoly_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                .map(|c| c.into_command()),
            "uno" => {
                let has_penalty = sess
                    .world()
                    .get_resource::<uno_game::UnoState>()
                    .is_some_and(|s| s.draw_penalty > 0);
                if has_penalty {
                    Some(Box::new(uno_game::DrawCardCommand { player: ai_p }) as Box<dyn Command>)
                } else {
                    uno_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                        .map(|c| c.into_command())
                }
            }
            "crisis" | "teg" => crisis_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                .map(|c| c.into_command()),
            "goose" | "oca" => {
                let has_pending = sess
                    .world()
                    .get_resource::<goose_game::PendingRollResource>()
                    .and_then(|p| p.pending.get(&ai_p))
                    .is_some();
                if !has_pending {
                    Some(Box::new(goose_game::RollDiceCommand { player: ai_p }) as Box<dyn Command>)
                } else {
                    goose_game::ai::best_move(sess, ai_p, self.ai_difficulty)
                        .map(|c| Box::new(c) as Box<dyn Command>)
                }
            }
            _ => None,
        };
        if let Some(cmd) = cmd_opt {
            if let Ok(events) = sess.process_command(ai_p, cmd) {
                let ev_vec: Vec<&Box<dyn Event>> = events.iter().collect();
                return serde_json::to_string(&ev_vec).unwrap_or_else(|_| "[]".to_string());
            }
        }
        "[]".to_string()
    }
}
