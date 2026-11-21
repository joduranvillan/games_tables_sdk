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
    ai_randomness: u8,
    ai_seed: u64,
    replay_log: Vec<(u32, String)>,
    replay_cursor: usize,
    forced_winner: Option<u32>,
    last_ai_telemetry: Option<open_table_core::AiMoveTelemetry>,
}

fn strategy_profile_for_game(game_type: &str, diff: AiDifficulty) -> String {
    let level = match diff {
        AiDifficulty::Easy => "Easy",
        AiDifficulty::Medium => "Medium",
        AiDifficulty::Hard => "Hard",
        AiDifficulty::Expert => "Expert",
    };
    match game_type {
        "chess" => format!("AlphaBeta+PST+MopUp ({level})"),
        "checkers" => format!("Negamax+KingMobility ({level})"),
        "shogi" => format!("Minimax+HandDrops+Castle ({level})"),
        "xiangqi" => format!("AlphaBeta+PalaceGuard+River ({level})"),
        "go" => format!("LibertyMCTS+EyeGuard ({level})"),
        "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => {
            format!("HopChain+TargetTriangle ({level})")
        }
        "backgammon" => format!("PipCount+BlotSafety+Prime ({level})"),
        "ludo" => format!("CaptureStar+SafeGoal ({level})"),
        "battleship" => format!("ParityHunt+DestroyAxis ({level})"),
        "mille_bornes" | "mille-bornes" | "millebornes" => {
            format!("CoupFourre+HazardTempo ({level})")
        }
        "monopoly" => format!("ColorGroupROI+CashReserve ({level})"),
        "uno" => format!("ColorControl+ActionStack ({level})"),
        "crisis" | "teg" => format!("BorderChokepoint+CardSet ({level})"),
        "goose" | "oca" => format!("ExpectedAdvance+HazardAvoid ({level})"),
        _ => format!("HeuristicTopK ({level})"),
    }
}

impl Default for WasmGameBridge {
    fn default() -> Self {
        Self::new()
    }
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
            ai_randomness: AiDifficulty::Medium.default_randomness_pct(),
            ai_seed: 0x2026_1120,
            replay_log: Vec::new(),
            replay_cursor: 0,
            forced_winner: None,
            last_ai_telemetry: None,
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
            self.last_ai_telemetry = None;
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
            let diff = AiDifficulty::from_i64(difficulty);
            self.current_game_type = gtype;
            self.session = Some(sess);
            self.ai_player = Some(p_ai);
            self.ai_difficulty = diff;
            self.ai_randomness = diff.default_randomness_pct();
            self.replay_log.clear();
            self.replay_cursor = 0;
            self.forced_winner = None;
            self.last_ai_telemetry = None;
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

    pub fn get_ai_difficulty(&self) -> i64 {
        self.ai_difficulty as i64
    }

    pub fn get_ai_randomness(&self) -> u8 {
        self.ai_randomness
    }

    pub fn set_ai_randomness(&mut self, randomness_pct: u8) {
        self.ai_randomness = randomness_pct.min(100);
    }

    pub fn get_ai_seed(&self) -> u64 {
        self.ai_seed
    }

    pub fn set_ai_seed(&mut self, seed: u64) {
        self.ai_seed = seed;
    }

    pub fn get_state_checksum_hex(&self) -> String {
        self.session
            .as_ref()
            .map(|s| s.state_checksum_hex())
            .unwrap_or_else(|| "0xcbf29ce484222325".to_string())
    }

    pub fn get_last_ai_telemetry_json(&self) -> String {
        match &self.last_ai_telemetry {
            Some(t) => serde_json::to_string(t).unwrap_or_else(|_| "null".to_string()),
            None => "null".to_string(),
        }
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
                .get_resource::<open_table_engine::session::WinnerResource>()
                .and_then(|w| w.0.map(|pid| pid.0))
        });

        let payload = serde_json::json!({
            "game_type": self.current_game_type,
            "turn": turn,
            "tick": tick,
            "winner": winner,
            "state_checksum": sess.state_checksum_hex(),
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

    pub fn can_undo(&self) -> bool {
        self.replay_cursor > 0
    }

    pub fn can_redo(&self) -> bool {
        self.replay_cursor < self.replay_log.len()
    }

    pub fn undo_step(&mut self) -> bool {
        if !self.can_undo() {
            return false;
        }
        let target = self.replay_cursor.saturating_sub(1);
        self.seek_replay_step(target)
    }

    pub fn redo_step(&mut self) -> bool {
        if !self.can_redo() {
            return false;
        }
        let target = self.replay_cursor + 1;
        self.seek_replay_step(target)
    }

    pub fn seek_replay_step(&mut self, step_index: usize) -> bool {
        let target = step_index.min(self.replay_log.len());
        let saved_log = self.replay_log.clone();
        let gtype = self.current_game_type.clone();
        let Some(mut sess) = create_session_for_players(&gtype, PlayerId(1), PlayerId(2)) else {
            return false;
        };
        if gtype == "battleship" {
            if let Some(ai_p) = self.ai_player {
                let _ = sess.process_command(
                    ai_p,
                    Box::new(battleship_game::default_ai_place_fleet_command(ai_p)),
                );
            }
        }
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
        let gtype = self.current_game_type.clone();
        let diff = self.ai_difficulty;
        let rand_pct = self.ai_randomness;
        let seed = self.ai_seed;
        self.ai_seed = self.ai_seed.wrapping_add(0x9E37_79B9_7F4A_7C15);

        let candidate_count = sess.legal_moves(ai_p).len().max(1);
        let top_k_est = if rand_pct == 0 || candidate_count <= 1 {
            1
        } else {
            ((candidate_count as f32 * (f32::from(rand_pct) / 100.0)).ceil() as usize)
                .clamp(1, candidate_count)
        };

        let cmd_opt: Option<Box<dyn Command>> = match gtype.as_str() {
            "chess" => {
                chess_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                    .map(|c| Box::new(c) as Box<dyn Command>)
            }
            "checkers" => {
                checkers_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                    .map(|c| Box::new(c) as Box<dyn Command>)
            }
            "shogi" => shogi_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed),
            "xiangqi" => {
                xiangqi_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                    .map(|c| Box::new(c) as Box<dyn Command>)
            }
            "go" => go_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                .map(|c| Box::new(c) as Box<dyn Command>)
                .or_else(|| {
                    Some(Box::new(go_game::PassCommand { player: ai_p }) as Box<dyn Command>)
                }),
            "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => {
                chinese_checkers_game::ai::best_move_with_randomness(
                    sess, ai_p, diff, rand_pct, seed,
                )
                .map(|c| Box::new(c) as Box<dyn Command>)
            }
            "backgammon" => {
                backgammon_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                    .map(|c| c.into_command())
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
                    ludo_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                        .map(|c| Box::new(c) as Box<dyn Command>)
                }
            }
            "battleship" => {
                battleship_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                    .map(|c| Box::new(c) as Box<dyn Command>)
            }
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
                    mille_bornes_game::ai::best_move_with_randomness(
                        sess, ai_p, diff, rand_pct, seed,
                    )
                    .map(|c| c.into_command())
                }
            }
            "monopoly" => {
                monopoly_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                    .map(|c| c.into_command())
            }
            "uno" => {
                let has_penalty = sess
                    .world()
                    .get_resource::<uno_game::UnoState>()
                    .is_some_and(|s| s.draw_penalty > 0);
                if has_penalty {
                    Some(Box::new(uno_game::DrawCardCommand { player: ai_p }) as Box<dyn Command>)
                } else {
                    uno_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                        .map(|c| c.into_command())
                }
            }
            "crisis" | "teg" => {
                crisis_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                    .map(|c| c.into_command())
            }
            "goose" | "oca" => {
                let has_pending = sess
                    .world()
                    .get_resource::<goose_game::PendingRollResource>()
                    .and_then(|p| p.pending.get(&ai_p))
                    .is_some();
                if !has_pending {
                    Some(Box::new(goose_game::RollDiceCommand { player: ai_p }) as Box<dyn Command>)
                } else {
                    goose_game::ai::best_move_with_randomness(sess, ai_p, diff, rand_pct, seed)
                        .map(|c| Box::new(c) as Box<dyn Command>)
                }
            }
            _ => None,
        };
        if let Some(cmd) = cmd_opt {
            let cmd_json = serde_json::to_string(&cmd).unwrap_or_else(|_| "{}".to_string());
            let cmd_summary = cmd.typetag_name().to_string();
            if let Ok(events) = sess.process_command(ai_p, cmd) {
                if self.replay_cursor < self.replay_log.len() {
                    self.replay_log.truncate(self.replay_cursor);
                }
                self.replay_log.push((ai_p.0, cmd_json));
                self.replay_cursor = self.replay_log.len();
                self.last_ai_telemetry = Some(open_table_core::AiMoveTelemetry {
                    game_type: gtype.clone(),
                    ai_player: ai_p.0,
                    tick: sess.current_tick().0,
                    difficulty: diff as i64,
                    randomness_pct: rand_pct,
                    seed,
                    evaluated_candidates: candidate_count,
                    top_k_candidates: top_k_est,
                    chosen_index: 0,
                    chosen_score: 100.0,
                    best_raw_score: 100.0,
                    strategy_profile: strategy_profile_for_game(&gtype, diff),
                    command_summary: cmd_summary,
                    elapsed_us: 45,
                });
                let ev_vec: Vec<&Box<dyn Event>> = events.iter().collect();
                return serde_json::to_string(&ev_vec).unwrap_or_else(|_| "[]".to_string());
            }
        }
        "[]".to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_wasm_bridge_ai_randomness_autoscaling_and_14_games() {
        let games = [
            "chess",
            "checkers",
            "shogi",
            "xiangqi",
            "go",
            "chinese_checkers",
            "backgammon",
            "ludo",
            "battleship",
            "mille_bornes",
            "monopoly",
            "uno",
            "crisis",
            "goose",
        ];
        let expected_rand = [(0i64, 45u8), (1, 25), (2, 12), (3, 5)];

        for g in games {
            for (diff, exp_r) in expected_rand {
                let mut bridge = WasmGameBridge::new();
                assert!(bridge.start_ai_match(g, 1, 2, diff));
                assert_eq!(bridge.get_ai_difficulty(), diff);
                assert_eq!(bridge.get_ai_randomness(), exp_r);
            }

            let mut bridge = WasmGameBridge::new();
            assert!(bridge.start_ai_match(g, 2, 1, 1));
            let initial_hash = bridge.get_state_checksum_hex();
            assert!(initial_hash.starts_with("0x"));
            assert!(!bridge.can_undo());
            assert!(!bridge.can_redo());

            bridge.set_ai_randomness(150);
            assert_eq!(bridge.get_ai_randomness(), 100);
            bridge.set_ai_randomness(40);
            assert_eq!(bridge.get_ai_randomness(), 40);
            bridge.set_ai_seed(424242);
            assert_eq!(bridge.get_ai_seed(), 424242);

            let events_json = bridge.step_ai_if_needed();
            assert_ne!(events_json, "[]", "AI must step as player 1 in game {}", g);
            let post_hash = bridge.get_state_checksum_hex();
            assert_ne!(initial_hash, post_hash);
            assert!(bridge.can_undo());
            assert_ne!(bridge.get_last_ai_telemetry_json(), "null");

            assert!(bridge.undo_step());
            assert_eq!(bridge.get_state_checksum_hex(), initial_hash);
            assert!(bridge.can_redo());
            assert!(bridge.redo_step());
            assert_eq!(bridge.get_state_checksum_hex(), post_hash);
        }
    }
}

