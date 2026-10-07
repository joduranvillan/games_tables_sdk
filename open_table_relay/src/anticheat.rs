//! Validación Anti-Cheat autoritativa de movimientos en el servidor Relay para `chess` y `checkers`.
//!
//! Cuando una sala se crea con `"game_id": "chess"` o `"game_id": "checkers"`, el Relay
//! mantiene una instancia local de `open_table_engine::session::Session` y verifica cada movimiento
//! antes de retransmitirlo a los demás participantes.

use open_table_core::command::Command;
use open_table_core::ids::{PlayerId, SessionId};
use open_table_engine::session::Session;
use serde_json::Value;
use std::fmt;

/// Estado de validación Anti-Cheat asociado a una sala activa.
pub struct AntiCheatSession {
    game_id: String,
    session: Session,
}

impl fmt::Debug for AntiCheatSession {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AntiCheatSession")
            .field("game_id", &self.game_id)
            .field("current_tick", &self.session.current_tick())
            .finish()
    }
}

impl AntiCheatSession {
    /// Crea un validador Anti-Cheat si `game_id` es `"chess"` o `"checkers"`.
    /// Para cualquier otro juego devuelve `None` (retransmisión directa sin validación).
    pub fn for_game(game_id: Option<&str>) -> Option<Self> {
        let gid = game_id?.trim().to_ascii_lowercase();
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        match gid.as_str() {
            "chess" => Some(Self {
                game_id: "chess".to_string(),
                session: chess_game::new_chess_session(SessionId(1), 42, p1, p2),
            }),
            "checkers" => Some(Self {
                game_id: "checkers".to_string(),
                session: checkers_game::new_checkers_session(SessionId(1), 42, p1, p2),
            }),
            _ => None,
        }
    }

    /// Deserializa y aplica un comando sobre la `Session` local del juego.
    /// Devuelve `Ok(())` si el comando es legal y fue aplicado, o `Err("illegal_move")` si es inválido.
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

        let sender = cmd_val
            .get("player")
            .and_then(|v| v.as_u64())
            .and_then(|v| u32::try_from(v).ok())
            .map(PlayerId)
            .unwrap_or(PlayerId(sender_room_player_id));

        let cmd_box: Box<dyn Command> = match self.game_id.as_str() {
            "chess" => parse_chess_command(&cmd_val, sender).ok_or("illegal_move")?,
            "checkers" => parse_checkers_command(&cmd_val, sender).ok_or("illegal_move")?,
            _ => return Ok(()),
        };

        self.session
            .process_command(sender, cmd_box)
            .map(|_| ())
            .map_err(|_| "illegal_move")
    }
}

fn parse_chess_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if let Ok(cmd) = serde_json::from_value::<chess_game::MovePieceCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }

    let from = parse_chess_pos(val.get("from")?)?;
    let to = parse_chess_pos(val.get("to")?)?;
    let player = val
        .get("player")
        .and_then(|v| v.as_u64())
        .and_then(|v| u32::try_from(v).ok())
        .map(PlayerId)
        .unwrap_or(default_player);

    Some(Box::new(chess_game::MovePieceCommand {
        player,
        from,
        to,
        promote_to: None,
    }))
}

fn parse_chess_pos(v: &Value) -> Option<chess_game::Position> {
    if let Ok(pos) = serde_json::from_value::<chess_game::Position>(v.clone()) {
        return Some(pos);
    }
    if let Some(arr) = v.as_array() {
        if arr.len() == 2 {
            let r = u8::try_from(arr[0].as_u64()?).ok()?;
            let c = u8::try_from(arr[1].as_u64()?).ok()?;
            return Some(chess_game::Position::new(r, c));
        }
    }
    None
}

fn parse_checkers_command(val: &Value, default_player: PlayerId) -> Option<Box<dyn Command>> {
    if let Ok(cmd) = serde_json::from_value::<checkers_game::MovePieceCommand>(val.clone()) {
        return Some(Box::new(cmd));
    }

    let from = parse_checkers_pos(val.get("from")?)?;
    let to = parse_checkers_pos(val.get("to")?)?;
    let player = val
        .get("player")
        .and_then(|v| v.as_u64())
        .and_then(|v| u32::try_from(v).ok())
        .map(PlayerId)
        .unwrap_or(default_player);

    Some(Box::new(checkers_game::MovePieceCommand { player, from, to }))
}

fn parse_checkers_pos(v: &Value) -> Option<checkers_game::Position> {
    if let Ok(pos) = serde_json::from_value::<checkers_game::Position>(v.clone()) {
        return Some(pos);
    }
    if let Some(arr) = v.as_array() {
        if arr.len() == 2 {
            let r = u8::try_from(arr[0].as_u64()?).ok()?;
            let c = u8::try_from(arr[1].as_u64()?).ok()?;
            return Some(checkers_game::Position::new(r, c));
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

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
    fn test_anticheat_other_games_opt_out() {
        assert!(AntiCheatSession::for_game(Some("go")).is_none());
        assert!(AntiCheatSession::for_game(None).is_none());
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
