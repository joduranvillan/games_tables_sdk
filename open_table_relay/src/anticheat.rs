//! Validación Anti-Cheat autoritativa de movimientos en el servidor Relay para los 13 juegos del catálogo.
//!
//! Cuando una sala se crea con cualquiera de los 13 identificadores canónicos
//! (`"chess"`, `"checkers"`, `"go"`, `"shogi"`, `"xiangqi"`, `"backgammon"`, `"battleship"`,
//! `"ludo"`, `"mille_bornes"`, `"monopoly"`, `"uno"`, `"crisis"`, `"chinese_checkers"`), el Relay
//! mantiene una instancia autoritativa de `open_table_engine::session::Session` inicializada con
//! una semilla determinista (`seed`) y verifica cada jugada antes de retransmitirla.

use open_table_core::command::Command;
use open_table_core::ids::{PlayerId, SessionId};
use open_table_engine::session::{Session, WinnerResource};
use serde_json::{json, Value};
use std::fmt;

/// Identificadores canónicos de los 13 juegos soportados por el validador Anti-Cheat.
pub const SUPPORTED_GAME_IDS: [&str; 13] = [
    "chess",
    "checkers",
    "go",
    "shogi",
    "xiangqi",
    "backgammon",
    "battleship",
    "ludo",
    "mille_bornes",
    "monopoly",
    "uno",
    "crisis",
    "chinese_checkers",
];

/// Estado de validación Anti-Cheat asociado a una sala activa.
pub struct AntiCheatSession {
    game_id: String,
    seed: u64,
    session: Session,
    winner: Option<PlayerId>,
}

impl fmt::Debug for AntiCheatSession {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AntiCheatSession")
            .field("game_id", &self.game_id)
            .field("seed", &self.seed)
            .field("current_tick", &self.session.current_tick())
            .field("winner", &self.winner())
            .finish()
    }
}

/// Normaliza un identificador de juego a su forma canónica si pertenece a los 13 juegos del catálogo.
pub fn normalize_game_id(raw: &str) -> Option<&'static str> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "chess" => Some("chess"),
        "checkers" => Some("checkers"),
        "go" => Some("go"),
        "shogi" => Some("shogi"),
        "xiangqi" => Some("xiangqi"),
        "backgammon" => Some("backgammon"),
        "battleship" => Some("battleship"),
        "ludo" => Some("ludo"),
        "mille_bornes" | "mille-bornes" | "millebornes" => Some("mille_bornes"),
        "monopoly" => Some("monopoly"),
        "uno" => Some("uno"),
        "crisis" => Some("crisis"),
        "chinese_checkers" | "chinese-checkers" | "chinesecheckers" => Some("chinese_checkers"),
        _ => None,
    }
}

impl AntiCheatSession {
    /// Crea un validador Anti-Cheat para cualquiera de los 13 juegos del catálogo con semilla por defecto (`42`).
    /// Para identificadores desconocidos o `None` devuelve `None`.
    pub fn for_game(game_id: Option<&str>) -> Option<Self> {
        Self::for_game_with_seed(game_id, 42)
    }

    /// Crea un validador Anti-Cheat inicializando la `Session` autoritativa con la semilla `seed` generada por el servidor.
    pub fn for_game_with_seed(game_id: Option<&str>, seed: u64) -> Option<Self> {
        let canonical = normalize_game_id(game_id?)?;
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let sid = SessionId(1);

        let session = match canonical {
            "chess" => chess_game::new_chess_session(sid, seed, p1, p2),
            "checkers" => checkers_game::new_checkers_session(sid, seed, p1, p2),
            "go" => go_game::new_go_session(sid, seed, p1, p2),
            "shogi" => shogi_game::new_shogi_session(sid, seed, p1, p2),
            "xiangqi" => xiangqi_game::new_xiangqi_session(sid, seed, p1, p2),
            "backgammon" => backgammon_game::new_backgammon_session(sid, seed, p1, p2),
            "battleship" => battleship_game::new_battleship_session(sid, seed, p1, p2),
            "ludo" => ludo_game::new_ludo_session(sid, seed, vec![p1, p2]),
            "mille_bornes" => mille_bornes_game::new_mille_bornes_session(sid, seed, p1, p2),
            "monopoly" => monopoly_game::new_monopoly_session(sid, seed, p1, p2),
            "uno" => uno_game::new_uno_session(sid, seed, vec![p1, p2]),
            "crisis" => crisis_game::new_crisis_session(sid, seed, &[p1, p2]).ok()?,
            "chinese_checkers" => {
                chinese_checkers_game::new_chinese_checkers_session(sid, seed, vec![p1, p2])
            }
            _ => return None,
        };

        Some(Self {
            game_id: canonical.to_string(),
            seed,
            session,
            winner: None,
        })
    }

    /// Identificador canónico del juego asociado a esta sesión Anti-Cheat.
    pub fn game_id(&self) -> &str {
        &self.game_id
    }

    /// Semilla determinista con la que se inicializó la `Session` autoritativa.
    pub fn seed(&self) -> u64 {
        self.seed
    }

    /// Devuelve el `PlayerId` ganador si la sesión autoritativa ha terminado.
    pub fn winner(&self) -> Option<PlayerId> {
        self.winner.or_else(|| {
            self.session
                .world()
                .get_resource::<WinnerResource>()
                .and_then(|w| w.0)
        })
    }

    /// Adjudica inmediatamente la victoria al oponente cuando `resigning_player_id` se rinde (`op: "resign"`).
    pub fn force_resign(&mut self, resigning_player_id: u32) -> PlayerId {
        let winner = if resigning_player_id == 1 {
            PlayerId(2)
        } else {
            PlayerId(1)
        };
        self.winner = Some(winner);
        self.session
            .world_mut()
            .insert_resource(WinnerResource(Some(winner)));
        self.session
            .world_mut()
            .insert_resource(open_table_engine::session::GameOverResource(true));
        winner
    }

    /// Referencia de solo lectura a la `Session` subyacente.
    pub fn session(&self) -> &Session {
        &self.session
    }

    /// Devuelve el asiento (`1` o `2`) que tiene actualmente el turno activo en la sesión autoritativa.
    pub fn active_turn_seat(&self) -> u32 {
        self.session
            .world()
            .get_resource::<open_table_engine::turn::TurnResource>()
            .map(|tr| tr.0.current_player().0)
            .unwrap_or(1)
    }

    /// Deserializa y aplica un comando sobre la `Session` local del juego.
    /// Devuelve `Ok(())` si el comando es legal y fue aplicado, o `Err("illegal_move")` si viola las reglas o el turno activo.
    pub fn validate_and_apply(
        &mut self,
        sender_room_player_id: u32,
        data: &Value,
    ) -> Result<(), &'static str> {
        let cmd_val: Value = match data {
            Value::String(s) => {
                let trimmed = s.trim();
                if !trimmed.starts_with('{') {
                    // Mensajes de control no estructurados como JSON de comando
                    return Ok(());
                }
                serde_json::from_str(trimmed).map_err(|_| "illegal_move")?
            }
            Value::Object(_) => data.clone(),
            _ => return Err("illegal_move"),
        };

        // Mensajes de sincronización de protocolo entre pares (resync de espectadores/clientes)
        if let Some(action) = cmd_val.get("action").and_then(|v| v.as_str()) {
            if action == "request_sync" || action == "sync_log" {
                return Ok(());
            }
        }

        let explicit_player = cmd_val
            .get("player")
            .and_then(|v| v.as_u64())
            .and_then(|v| u32::try_from(v).ok())
            .map(PlayerId);

        let sender = if sender_room_player_id > 0 {
            PlayerId(sender_room_player_id)
        } else {
            explicit_player.unwrap_or(PlayerId(1))
        };

        // Si el payload especifica explícitamente otro jugador distinto al emisor real de la sala, rechazar.
        if let Some(claimed) = explicit_player {
            if sender_room_player_id > 0 && claimed != sender {
                return Err("illegal_move");
            }
        }

        let cmd_box = parse_game_command(&self.game_id, &cmd_val, sender).ok_or("illegal_move")?;

        let events = self
            .session
            .process_command(sender, cmd_box)
            .map_err(|_| "illegal_move")?;

        for ev in &events {
            if let Ok(ev_val) = serde_json::to_value(ev.as_ref()) {
                if let Some(w_val) = ev_val.get("winner") {
                    if let Some(uid) = w_val.as_u64().and_then(|v| u32::try_from(v).ok()) {
                        self.winner = Some(PlayerId(uid));
                    }
                }
            }
        }
        if let Some(w) = self
            .session
            .world()
            .get_resource::<WinnerResource>()
            .and_then(|r| r.0)
        {
            self.winner = Some(w);
        }

        Ok(())
    }
}

fn parse_game_command(
    game_id: &str,
    val: &Value,
    default_player: PlayerId,
) -> Option<Box<dyn Command>> {
    // 1. Intentar deserialización directa vía typetag si incluye `command_type` o `type`.
    if let Some(cmd) = try_parse_typetag_command(game_id, val, default_player) {
        return Some(cmd);
    }

    // 2. Deserialización específica por juego (con soporte para JSON abreviado o completo).
    let mut with_player = val.clone();
    if let Some(obj) = with_player.as_object_mut() {
        obj.entry("player")
            .or_insert_with(|| json!(default_player.0));
    }

    match game_id {
        "chess" => parse_chess_command(&with_player, default_player),
        "checkers" => parse_checkers_command(&with_player, default_player),
        "go" => parse_go_command(&with_player, default_player),
        "shogi" => parse_shogi_command(&with_player, default_player),
        "xiangqi" => parse_xiangqi_command(&with_player, default_player),
        "backgammon" => parse_backgammon_command(&with_player, default_player),
        "battleship" => parse_battleship_command(&with_player, default_player),
        "ludo" => parse_ludo_command(&with_player, default_player),
        "mille_bornes" => parse_mille_bornes_command(&with_player, default_player),
        "monopoly" => parse_monopoly_command(&with_player, default_player),
        "uno" => parse_uno_command(&with_player, default_player),
        "crisis" => parse_crisis_command(&with_player, default_player),
        "chinese_checkers" => parse_chinese_checkers_command(&with_player, default_player),
        _ => None,
    }
}

fn try_parse_typetag_command(
    game_id: &str,
    val: &Value,
    default_player: PlayerId,
) -> Option<Box<dyn Command>> {
    let mut candidate = val.clone();
    let obj = candidate.as_object_mut()?;
    obj.entry("player")
        .or_insert_with(|| json!(default_player.0));

    if !obj.contains_key("command_type") {
        if let Some(t) = obj.get("type").cloned() {
            obj.insert("command_type".to_string(), t);
        }
    }

    let ct = obj.get("command_type")?.as_str()?.to_string();
    if ct.contains("::") {
        return serde_json::from_value::<Box<dyn Command>>(candidate).ok();
    }

    let qualified = format!("{game_id}_game::{ct}");
    obj.insert("command_type".to_string(), Value::String(qualified));
    serde_json::from_value::<Box<dyn Command>>(candidate).ok()
}

fn is_resign_action(val: &Value) -> bool {
    val.get("resign").and_then(|v| v.as_bool()) == Some(true)
        || val.get("action").and_then(|v| v.as_str()) == Some("resign")
}

fn parse_chess_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if is_resign_action(val) {
        return Some(Box::new(chess_game::ResignCommand {
            player: default_player,
        }));
    }
    if val.get("offer_draw").and_then(|v| v.as_bool()) == Some(true)
        || val.get("action").and_then(|v| v.as_str()) == Some("offer_draw")
    {
        return Some(Box::new(chess_game::OfferDrawCommand {
            player: default_player,
        }));
    }
    if val.get("accept_draw").and_then(|v| v.as_bool()) == Some(true)
        || val.get("action").and_then(|v| v.as_str()) == Some("accept_draw")
    {
        return Some(Box::new(chess_game::AcceptDrawCommand {
            player: default_player,
        }));
    }
    if let Ok(cmd) = serde_json::from_value::<chess_game::MovePieceCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }

    let from = parse_chess_pos(val.get("from")?)?;
    let to = parse_chess_pos(val.get("to")?)?;
    Some(Box::new(chess_game::MovePieceCommand {
        player: default_player,
        from,
        to,
        promote_to: None,
    }))
}

fn parse_chess_pos(v: &Value) -> Option<chess_game::Position> {
    if let Ok(pos) = serde_json::from_value::<chess_game::Position>(v.clone()) {
        return Some(pos);
    }
    if let Some((r, c)) = parse_u8_pair(v) {
        return Some(chess_game::Position::new(r, c));
    }
    None
}

fn parse_checkers_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if is_resign_action(val) {
        return Some(Box::new(checkers_game::ResignCommand {
            player: default_player,
        }));
    }
    if let Ok(cmd) = serde_json::from_value::<checkers_game::MovePieceCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }

    let from = parse_checkers_pos(val.get("from")?)?;
    let to = parse_checkers_pos(val.get("to")?)?;
    Some(Box::new(checkers_game::MovePieceCommand {
        player: default_player,
        from,
        to,
    }))
}

fn parse_checkers_pos(v: &Value) -> Option<checkers_game::Position> {
    if let Ok(pos) = serde_json::from_value::<checkers_game::Position>(v.clone()) {
        return Some(pos);
    }
    if let Some((r, c)) = parse_u8_pair(v) {
        return Some(checkers_game::Position::new(r, c));
    }
    None
}

fn parse_go_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if is_resign_action(val) {
        return Some(Box::new(go_game::ResignCommand {
            player: default_player,
        }));
    }
    if val.get("pass").and_then(|v| v.as_bool()) == Some(true)
        || val.get("action").and_then(|v| v.as_str()) == Some("pass")
    {
        return Some(Box::new(go_game::PassCommand {
            player: default_player,
        }));
    }
    if val.get("confirm_dead").and_then(|v| v.as_bool()) == Some(true)
        || val.get("action").and_then(|v| v.as_str()) == Some("confirm_dead")
    {
        return Some(Box::new(go_game::ConfirmDeadCommand {
            player: default_player,
        }));
    }
    if let Ok(cmd) = serde_json::from_value::<go_game::PlaceStoneCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }
    if let (Some(r), Some(c)) = (
        val.get("row").and_then(|v| v.as_u64()),
        val.get("col").and_then(|v| v.as_u64()),
    ) {
        return Some(Box::new(go_game::PlaceStoneCommand {
            player: default_player,
            x: c as usize,
            y: r as usize,
        }));
    }
    if let Ok(cmd) = serde_json::from_value::<go_game::PlaceHandicapCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }
    if let Ok(cmd) = serde_json::from_value::<go_game::MarkDeadCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }
    None
}

fn parse_shogi_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if is_resign_action(val) {
        return Some(Box::new(shogi_game::ResignCommand {
            player: default_player,
        }));
    }
    if val.get("piece").is_some() {
        if let Ok(cmd) = serde_json::from_value::<shogi_game::DropPieceCommand>(val.clone()) {
            return Some(Box::new(cmd));
        }
    }
    if let Ok(cmd) = serde_json::from_value::<shogi_game::MovePieceCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }
    let from = parse_usize_pair(val.get("from")?)?;
    let to = parse_usize_pair(val.get("to")?)?;
    let promote = val
        .get("promote")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    Some(Box::new(shogi_game::MovePieceCommand {
        player: default_player,
        from,
        to,
        promote,
    }))
}

fn parse_xiangqi_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if is_resign_action(val) {
        return Some(Box::new(xiangqi_game::ResignCommand {
            player: default_player,
        }));
    }
    if let Ok(cmd) = serde_json::from_value::<xiangqi_game::MovePieceCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }
    let from = parse_usize_pair(val.get("from")?)?;
    let to = parse_usize_pair(val.get("to")?)?;
    Some(Box::new(xiangqi_game::MovePieceCommand {
        player: default_player,
        from,
        to,
    }))
}

fn parse_backgammon_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if is_resign_action(val) {
        return Some(Box::new(backgammon_game::ResignCommand {
            player: default_player,
        }));
    }
    let action = val.get("action").and_then(|v| v.as_str()).unwrap_or("");
    if action == "offer_double" || val.get("offer_double").and_then(|v| v.as_bool()) == Some(true) {
        return Some(Box::new(backgammon_game::OfferDoubleCommand {
            player: default_player,
        }));
    }
    if action == "accept_double" || val.get("accept_double").and_then(|v| v.as_bool()) == Some(true)
    {
        return Some(Box::new(backgammon_game::AcceptDoubleCommand {
            player: default_player,
        }));
    }
    if action == "reject_double" || val.get("reject_double").and_then(|v| v.as_bool()) == Some(true)
    {
        return Some(Box::new(backgammon_game::RejectDoubleCommand {
            player: default_player,
        }));
    }
    if val.get("die").is_some() {
        return serde_json::from_value::<backgammon_game::MoveCheckerCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if action == "roll"
        || action == "roll_dice"
        || val.get("roll").and_then(|v| v.as_bool()) == Some(true)
        || (val.get("from").is_none() && val.get("die").is_none())
    {
        return Some(Box::new(backgammon_game::RollDiceCommand {
            player: default_player,
        }));
    }
    None
}

fn parse_battleship_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if val.get("ships").is_some() {
        return serde_json::from_value::<battleship_game::PlaceFleetCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("rematch").and_then(|v| v.as_bool()) == Some(true)
        || val.get("action").and_then(|v| v.as_str()) == Some("rematch")
    {
        return Some(Box::new(battleship_game::RematchCommand {
            player: default_player,
        }));
    }
    if let Ok(cmd) = serde_json::from_value::<battleship_game::FireShotCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }
    if let Some(target_val) = val.get("target") {
        if let Some((r, c)) = parse_u8_pair(target_val) {
            return Some(Box::new(battleship_game::FireShotCommand {
                player: default_player,
                target: battleship_game::Position::new(r, c),
            }));
        }
    }
    if let Some((r, c)) = parse_u8_pair(val) {
        return Some(Box::new(battleship_game::FireShotCommand {
            player: default_player,
            target: battleship_game::Position::new(r, c),
        }));
    }
    None
}

fn parse_ludo_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if val.get("token_index").is_some() {
        return serde_json::from_value::<ludo_game::MoveTokenCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    let action = val.get("action").and_then(|v| v.as_str()).unwrap_or("");
    if action == "roll"
        || action == "roll_dice"
        || val.get("roll").and_then(|v| v.as_bool()) == Some(true)
        || val.get("token_index").is_none()
    {
        return Some(Box::new(ludo_game::RollDiceCommand {
            player: default_player,
        }));
    }
    None
}

fn parse_mille_bornes_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    let action = val.get("action").and_then(|v| v.as_str()).unwrap_or("");
    if action == "setup_deck" {
        return Some(Box::new(mille_bornes_game::SetupDeckCommand));
    }
    if action == "coup_fourre" || val.get("coup_fourre").and_then(|v| v.as_bool()) == Some(true) {
        return Some(Box::new(mille_bornes_game::CoupFourreCommand {
            player: default_player,
        }));
    }
    if val.get("distance").is_some() {
        return serde_json::from_value::<mille_bornes_game::PlayDistanceCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("hazard").is_some() {
        return serde_json::from_value::<mille_bornes_game::PlayHazardCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("safety").is_some() {
        return serde_json::from_value::<mille_bornes_game::PlaySafetyCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("card_index").is_some() {
        if action == "discard" || val.get("discard").and_then(|v| v.as_bool()) == Some(true) {
            return serde_json::from_value::<mille_bornes_game::DiscardCardCommand>(val.clone())
                .ok()
                .map(|c| Box::new(c) as Box<dyn Command>);
        }
        return serde_json::from_value::<mille_bornes_game::PlayCardCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if action == "draw"
        || val.get("draw").and_then(|v| v.as_bool()) == Some(true)
        || val.get("card_index").is_none()
    {
        return Some(Box::new(mille_bornes_game::DrawCardCommand {
            player: default_player,
        }));
    }
    None
}

fn parse_monopoly_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if val.get("buy").is_some() {
        return serde_json::from_value::<monopoly_game::BuyPropertyCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("amount").is_some() {
        return serde_json::from_value::<monopoly_game::AuctionBidCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    let action = val.get("action").and_then(|v| v.as_str()).unwrap_or("");
    if action == "pay_jail_fee" || val.get("pay_jail_fee").and_then(|v| v.as_bool()) == Some(true) {
        return Some(Box::new(monopoly_game::PayJailFeeCommand {
            player: default_player,
        }));
    }
    Some(Box::new(monopoly_game::RollAndMoveCommand {
        player: default_player,
    }))
}

fn parse_uno_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    let action = val.get("action").and_then(|v| v.as_str()).unwrap_or("");
    if action == "intercept" || val.get("intercept").and_then(|v| v.as_bool()) == Some(true) {
        return serde_json::from_value::<uno_game::InterceptCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("card_index").is_some() {
        let mut candidate = val.clone();
        if let Some(obj) = candidate.as_object_mut() {
            obj.entry("chosen_color").or_insert(Value::Null);
        }
        return serde_json::from_value::<uno_game::PlayCardCommand>(candidate)
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    Some(Box::new(uno_game::DrawCardCommand {
        player: default_player,
    }))
}

fn parse_crisis_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if val.get("territory").is_some() && val.get("count").is_some() {
        return serde_json::from_value::<crisis_game::PlaceArmiesCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("from").is_some() && val.get("to").is_some() && val.get("dice").is_some() {
        return serde_json::from_value::<crisis_game::DeclareAttackCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("from").is_some() && val.get("to").is_some() && val.get("armies").is_some() {
        return serde_json::from_value::<crisis_game::FortifyCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    if val.get("card_indices").is_some() {
        return serde_json::from_value::<crisis_game::ExchangeCardsCommand>(val.clone())
            .ok()
            .map(|c| Box::new(c) as Box<dyn Command>);
    }
    let action = val.get("action").and_then(|v| v.as_str()).unwrap_or("");
    if action == "roll_attack" || val.get("roll_attack").and_then(|v| v.as_bool()) == Some(true) {
        return Some(Box::new(crisis_game::RollAttackCommand {
            player: default_player,
        }));
    }
    if action == "end_phase" || val.get("end_phase").and_then(|v| v.as_bool()) == Some(true) {
        return Some(Box::new(crisis_game::EndPhaseCommand {
            player: default_player,
        }));
    }
    None
}

fn parse_chinese_checkers_command(
    val: &Value,
    default_player: PlayerId,
) -> Option<Box<dyn Command>> {
    if let Ok(cmd) = serde_json::from_value::<chinese_checkers_game::MovePegCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }
    let from = parse_hex_pos(val.get("from")?)?;
    let to = parse_hex_pos(val.get("to")?)?;
    Some(Box::new(chinese_checkers_game::MovePegCommand {
        player: default_player,
        from,
        to,
        path: Vec::new(),
    }))
}

fn parse_hex_pos(v: &Value) -> Option<chinese_checkers_game::Position> {
    if let Ok(pos) = serde_json::from_value::<chinese_checkers_game::Position>(v.clone()) {
        return Some(pos);
    }
    if let Some(arr) = v.as_array() {
        if arr.len() == 2 {
            let q = i32::try_from(arr[0].as_i64()?).ok()?;
            let r = i32::try_from(arr[1].as_i64()?).ok()?;
            return Some(chinese_checkers_game::Position::new(q, r));
        }
    }
    if let (Some(q), Some(r)) = (
        v.get("row").and_then(|x| x.as_i64()),
        v.get("col").and_then(|y| y.as_i64()),
    ) {
        return Some(chinese_checkers_game::Position::new(q as i32, r as i32));
    }
    None
}

fn parse_u8_pair(v: &Value) -> Option<(u8, u8)> {
    if let Some(arr) = v.as_array() {
        if arr.len() == 2 {
            let r = u8::try_from(arr[0].as_u64()?).ok()?;
            let c = u8::try_from(arr[1].as_u64()?).ok()?;
            return Some((r, c));
        }
    }
    if let (Some(r), Some(c)) = (
        v.get("row").and_then(|x| x.as_u64()),
        v.get("col").and_then(|y| y.as_u64()),
    ) {
        return Some((u8::try_from(r).ok()?, u8::try_from(c).ok()?));
    }
    None
}

fn parse_usize_pair(v: &Value) -> Option<(usize, usize)> {
    if let Some(arr) = v.as_array() {
        if arr.len() == 2 {
            let r = usize::try_from(arr[0].as_u64()?).ok()?;
            let c = usize::try_from(arr[1].as_u64()?).ok()?;
            return Some((r, c));
        }
    }
    if let (Some(r), Some(c)) = (
        v.get("row").and_then(|x| x.as_u64()),
        v.get("col").and_then(|y| y.as_u64()),
    ) {
        return Some((usize::try_from(r).ok()?, usize::try_from(c).ok()?));
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_anticheat_supports_all_13_canonical_games_with_seed() {
        for &game_id in &SUPPORTED_GAME_IDS {
            let session = AntiCheatSession::for_game_with_seed(Some(game_id), 987_654_321);
            assert!(
                session.is_some(),
                "AntiCheatSession debe soportar el juego canónico {game_id}"
            );
            let ac = session.unwrap();
            assert_eq!(ac.game_id(), game_id);
            assert_eq!(ac.seed(), 987_654_321);
            assert_eq!(ac.winner(), None);
        }
        assert!(AntiCheatSession::for_game(Some("unknown_game")).is_none());
        assert!(AntiCheatSession::for_game(None).is_none());
    }

    #[test]
    fn test_anticheat_chess_legal_and_illegal_moves() {
        let mut ac = AntiCheatSession::for_game(Some("chess")).unwrap();

        // Movimiento legal de apertura para Blancas (P1): peón e2 (1,4) -> e4 (3,4)
        let legal = json!({
            "player": 1,
            "from": { "row": 1, "col": 4 },
            "to": { "row": 3, "col": 4 }
        });
        assert!(ac.validate_and_apply(1, &legal).is_ok());

        // Movimiento ilegal para Negras (P2): intentar mover rey e8 (7,4) -> e5 (4,4)
        let illegal = json!({
            "player": 2,
            "from": { "row": 7, "col": 4 },
            "to": { "row": 4, "col": 4 }
        });
        assert_eq!(ac.validate_and_apply(2, &illegal), Err("illegal_move"));
    }

    #[test]
    fn test_anticheat_checkers_legal_and_illegal_moves() {
        let mut ac = AntiCheatSession::for_game(Some("checkers")).unwrap();

        // Movimiento ilegal en Damas: saltar a una casilla ocupada o fuera de alcance (0,1) -> (5,5)
        let illegal = json!({
            "player": 1,
            "from": { "row": 0, "col": 1 },
            "to": { "row": 5, "col": 5 }
        });
        assert_eq!(ac.validate_and_apply(1, &illegal), Err("illegal_move"));

        // Movimiento diagonal simple legal para P1 (top): (2,1) -> (3,0)
        let legal = json!({
            "player": 1,
            "from": { "row": 2, "col": 1 },
            "to": { "row": 3, "col": 0 }
        });
        assert!(ac.validate_and_apply(1, &legal).is_ok());
    }

    #[test]
    fn test_anticheat_all_13_games_validate_rules_and_active_turn() {
        // 1. Go: P1 coloca piedra en (3,3), P1 intenta repetir turno -> rechazado
        let mut go_ac = AntiCheatSession::for_game(Some("go")).unwrap();
        assert!(go_ac
            .validate_and_apply(1, &json!({"player": 1, "x": 3, "y": 3}))
            .is_ok());
        assert_eq!(
            go_ac.validate_and_apply(1, &json!({"player": 1, "x": 4, "y": 4})),
            Err("illegal_move")
        );

        // 2. Shogi: P2 intenta mover en el turno de P1 -> rechazado; P1 se rinde -> P2 gana
        let mut shogi_ac = AntiCheatSession::for_game(Some("shogi")).unwrap();
        assert_eq!(
            shogi_ac.validate_and_apply(
                2,
                &json!({"player": 2, "from": [2, 0], "to": [3, 0], "promote": false})
            ),
            Err("illegal_move")
        );
        assert!(shogi_ac
            .validate_and_apply(1, &json!({"player": 1, "resign": true}))
            .is_ok());
        assert_eq!(shogi_ac.winner(), Some(PlayerId(2)));

        // 3. Xiangqi: P2 intenta mover fuera de turno -> rechazado; P1 se rinde -> P2 gana
        let mut xiangqi_ac = AntiCheatSession::for_game(Some("xiangqi")).unwrap();
        assert_eq!(
            xiangqi_ac.validate_and_apply(2, &json!({"player": 2, "from": [0, 0], "to": [1, 0]})),
            Err("illegal_move")
        );
        assert!(xiangqi_ac
            .validate_and_apply(1, &json!({"player": 1, "resign": true}))
            .is_ok());
        assert_eq!(xiangqi_ac.winner(), Some(PlayerId(2)));

        // 4. Backgammon: P1 tira dados legalmente; P2 intenta tirar fuera de turno -> rechazado
        let mut bg_ac = AntiCheatSession::for_game_with_seed(Some("backgammon"), 777).unwrap();
        assert_eq!(
            bg_ac.validate_and_apply(2, &json!({"player": 2, "roll": true})),
            Err("illegal_move")
        );
        assert!(bg_ac
            .validate_and_apply(1, &json!({"player": 1, "roll": true}))
            .is_ok());

        // 5. Battleship: disparar antes de colocar la flota -> rechazado
        let mut bs_ac = AntiCheatSession::for_game(Some("battleship")).unwrap();
        assert_eq!(
            bs_ac.validate_and_apply(1, &json!({"player": 1, "target": {"row": 0, "col": 0}})),
            Err("illegal_move")
        );

        // 6. Ludo: P2 intenta tirar dado en turno de P1 -> rechazado; P1 tira dado -> OK
        let mut ludo_ac = AntiCheatSession::for_game_with_seed(Some("ludo"), 12345).unwrap();
        assert_eq!(
            ludo_ac.validate_and_apply(2, &json!({"player": 2, "roll": true})),
            Err("illegal_move")
        );
        assert!(ludo_ac
            .validate_and_apply(1, &json!({"player": 1, "roll": true}))
            .is_ok());

        // 7. Mille Bornes: jugar índice de carta inexistente (99) -> rechazado; robar en turno -> OK
        let mut mb_ac = AntiCheatSession::for_game_with_seed(Some("mille_bornes"), 555).unwrap();
        assert_eq!(
            mb_ac.validate_and_apply(1, &json!({"player": 1, "card_index": 99})),
            Err("illegal_move")
        );
        assert!(mb_ac
            .validate_and_apply(1, &json!({"player": 1, "draw": true}))
            .is_ok());

        // 8. Monopoly: P2 intenta tirar en turno de P1 -> rechazado; P1 tira y avanza -> OK
        let mut mono_ac = AntiCheatSession::for_game_with_seed(Some("monopoly"), 888).unwrap();
        assert_eq!(
            mono_ac.validate_and_apply(2, &json!({"player": 2, "roll": true})),
            Err("illegal_move")
        );
        assert!(mono_ac
            .validate_and_apply(1, &json!({"player": 1, "roll": true}))
            .is_ok());

        // 9. UNO: P2 intenta robar fuera de turno -> rechazado; P1 roba carta -> OK
        let mut uno_ac = AntiCheatSession::for_game_with_seed(Some("uno"), 999).unwrap();
        assert_eq!(
            uno_ac.validate_and_apply(2, &json!({"player": 2, "draw": true})),
            Err("illegal_move")
        );
        assert!(uno_ac
            .validate_and_apply(1, &json!({"player": 1, "draw": true}))
            .is_ok());

        // 10. Crisis: colocar 999 ejércitos (excede reserva) -> rechazado
        let mut crisis_ac = AntiCheatSession::for_game_with_seed(Some("crisis"), 333).unwrap();
        assert_eq!(
            crisis_ac.validate_and_apply(1, &json!({"player": 1, "territory": 0, "count": 999})),
            Err("illegal_move")
        );

        // 11. Chinese Checkers: mover desde casilla vacía (0,0) -> rechazado
        let mut cc_ac = AntiCheatSession::for_game(Some("chinese_checkers")).unwrap();
        assert_eq!(
            cc_ac.validate_and_apply(
                1,
                &json!({"player": 1, "from": {"q": 0, "r": 0}, "to": {"q": 1, "r": 0}})
            ),
            Err("illegal_move")
        );
    }

    #[test]
    fn test_anticheat_winner_detected_on_resign() {
        let mut ac = AntiCheatSession::for_game(Some("chess")).unwrap();
        assert_eq!(ac.winner(), None);
        assert!(ac
            .validate_and_apply(1, &json!({"player": 1, "resign": true}))
            .is_ok());
        assert_eq!(ac.winner(), Some(PlayerId(2)));
    }

    #[test]
    fn test_anticheat_stringified_command_json() {
        let mut ac = AntiCheatSession::for_game(Some("chess")).unwrap();
        let legal_str = Value::String(
            r#"{"player":1,"from":{"row":1,"col":4},"to":{"row":3,"col":4}}"#.to_string(),
        );
        assert!(ac.validate_and_apply(1, &legal_str).is_ok());

        let illegal_str = Value::String(
            r#"{"player":2,"from":{"row":7,"col":4},"to":{"row":4,"col":4}}"#.to_string(),
        );
        assert_eq!(ac.validate_and_apply(2, &illegal_str), Err("illegal_move"));
    }
}
