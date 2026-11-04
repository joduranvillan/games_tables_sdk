// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use crate::board::{BoardResource, HalfMoveClockResource, Sides};
use crate::position::{PieceKind, Position};
use open_table_core::ids::PlayerId;
use open_table_engine::prelude::{GameOverResource, WinnerResource};
use open_table_engine::session::Session;
use open_table_engine::turn::TurnResource;

impl BoardResource {
    /// Exporta la posición actual del tablero en notación estándar FEN (Forsyth-Edwards Notation).
    pub fn export_fen(&self) -> String {
        self.export_fen_with_state(PlayerId(1), PlayerId(2), PlayerId(1), 0, 1)
    }

    /// Exporta la posición actual con metadatos completos de turno y relojes en formato FEN.
    pub fn export_fen_with_state(
        &self,
        white: PlayerId,
        _black: PlayerId,
        active_player: PlayerId,
        halfmove_clock: u32,
        fullmove_number: u32,
    ) -> String {
        let mut ranks = Vec::with_capacity(8);
        for rank_idx in 0..8u8 {
            let row = 7 - rank_idx;
            let mut rank_str = String::new();
            let mut empty_count = 0u8;
            for col in 0..8u8 {
                if let Some(piece) = self.get(Position::new(row, col)) {
                    if empty_count > 0 {
                        rank_str.push(char::from(b'0' + empty_count));
                        empty_count = 0;
                    }
                    let base = match piece.kind {
                        PieceKind::Pawn => 'p',
                        PieceKind::Knight => 'n',
                        PieceKind::Bishop => 'b',
                        PieceKind::Rook => 'r',
                        PieceKind::Queen => 'q',
                        PieceKind::King => 'k',
                    };
                    let ch = if piece.owner == white {
                        base.to_ascii_uppercase()
                    } else {
                        base
                    };
                    rank_str.push(ch);
                } else {
                    empty_count += 1;
                }
            }
            if empty_count > 0 {
                rank_str.push(char::from(b'0' + empty_count));
            }
            ranks.push(rank_str);
        }

        let placement = ranks.join("/");
        let active_color = if active_player == white { "w" } else { "b" };

        let mut castling = String::new();
        if !self.white_king_moved {
            if !self.white_rook_h_moved {
                castling.push('K');
            }
            if !self.white_rook_a_moved {
                castling.push('Q');
            }
        }
        if !self.black_king_moved {
            if !self.black_rook_h_moved {
                castling.push('k');
            }
            if !self.black_rook_a_moved {
                castling.push('q');
            }
        }
        if castling.is_empty() {
            castling.push('-');
        }

        let en_passant = match self.en_passant_target {
            Some(pos) if pos.row < 8 && pos.col < 8 => {
                let file = (b'a' + pos.col) as char;
                let rank = (b'1' + pos.row) as char;
                format!("{file}{rank}")
            }
            _ => "-".to_string(),
        };

        format!(
            "{placement} {active_color} {castling} {en_passant} {halfmove_clock} {}",
            fullmove_number.max(1)
        )
    }

    /// Exporta una cabecera PGN básica junto con el FEN actual cuando se invoca directamente sobre el tablero.
    pub fn export_pgn(&self, white: &str, black: &str) -> String {
        let fen = self.export_fen();
        format!(
            "[Event \"Casual Game\"]\n[Site \"OpenTable\"]\n[Date \"????.??.??\"]\n[Round \"1\"]\n[White \"{white}\"]\n[Black \"{black}\"]\n[Result \"*\"]\n[FEN \"{fen}\"]\n\n*"
        )
    }
}

/// Rasgo de extensión para exportar FEN y PGN directamente desde una `Session` de Ajedrez.
pub trait ChessNotationExport {
    fn export_fen(&self) -> String;
    fn export_pgn(&self, white: &str, black: &str) -> String;
}

impl ChessNotationExport for Session {
    fn export_fen(&self) -> String {
        export_session_fen(self)
    }

    fn export_pgn(&self, white: &str, black: &str) -> String {
        export_session_pgn(self, white, black)
    }
}

pub fn export_session_fen(session: &Session) -> String {
    let Some(board) = session.world().get_resource::<BoardResource>() else {
        return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1".to_string();
    };
    let (white, black) = session
        .world()
        .get_resource::<Sides>()
        .map(|s| (s.white, s.black))
        .unwrap_or((PlayerId(1), PlayerId(2)));
    let active_player = session
        .world()
        .get_resource::<TurnResource>()
        .map(|t| t.0.current_player())
        .unwrap_or(white);
    let halfmove_clock = session
        .world()
        .get_resource::<HalfMoveClockResource>()
        .map(|h| h.0)
        .unwrap_or(0);
    let move_count = session
        .command_log()
        .iter()
        .filter(|(_, _, cmd)| {
            serde_json::to_value(cmd.as_ref())
                .ok()
                .and_then(|v| {
                    v.get("command_type")
                        .and_then(|c| c.as_str())
                        .map(|s| s.contains("MovePieceCommand"))
                })
                .unwrap_or(false)
        })
        .count();
    let fullmove_number = (move_count as u32 / 2) + 1;

    board.export_fen_with_state(white, black, active_player, halfmove_clock, fullmove_number)
}

pub fn export_session_pgn(session: &Session, white: &str, black: &str) -> String {
    let base_pgn = session.export_chess_pgn().unwrap_or_else(|| {
        "[Event \"Casual Game\"]\n[Site \"OpenTable\"]\n[Date \"????.??.??\"]\n[Round \"1\"]\n[White \"White\"]\n[Black \"Black\"]\n[Result \"*\"]\n\n*".to_string()
    });

    let result_str = determine_pgn_result(session);
    let mut customized = base_pgn
        .replacen("[White \"White\"]", &format!("[White \"{white}\"]"), 1)
        .replacen("[Black \"Black\"]", &format!("[Black \"{black}\"]"), 1)
        .replacen("[Result \"*\"]", &format!("[Result \"{result_str}\"]"), 1);

    if !customized.ends_with(&result_str) {
        if customized.ends_with("\n\n") {
            customized.push_str(&result_str);
        } else {
            customized.push(' ');
            customized.push_str(&result_str);
        }
    }
    customized
}

fn determine_pgn_result(session: &Session) -> String {
    let is_over = session
        .world()
        .get_resource::<GameOverResource>()
        .map(|g| g.0)
        .unwrap_or(false);
    if !is_over {
        return "*".to_string();
    }
    let (white, black) = session
        .world()
        .get_resource::<Sides>()
        .map(|s| (s.white, s.black))
        .unwrap_or((PlayerId(1), PlayerId(2)));
    let winner = session
        .world()
        .get_resource::<WinnerResource>()
        .and_then(|w| w.0);
    match winner {
        Some(w) if w == white => "1-0".to_string(),
        Some(w) if w == black => "0-1".to_string(),
        _ => "1/2-1/2".to_string(),
    }
}

pub fn export_to_pgn(session: &Session) -> String {
    export_session_pgn(session, "White", "Black")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{new_chess_session, MovePieceCommand, Position};
    use open_table_core::ids::{PlayerId, SessionId};

    #[test]
    fn test_exportar_partida_a_pgn_produce_formato_valido() {
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let mut session = new_chess_session(SessionId(1), 1, p1, p2);

        // 1. e2-e4 (White)
        session
            .process_command(
                p1,
                Box::new(MovePieceCommand {
                    player: p1,
                    from: Position::new(1, 4),
                    to: Position::new(3, 4),
                    promote_to: None,
                }),
            )
            .unwrap();

        // 1... e7-e5 (Black)
        session
            .process_command(
                p2,
                Box::new(MovePieceCommand {
                    player: p2,
                    from: Position::new(6, 4),
                    to: Position::new(4, 4),
                    promote_to: None,
                }),
            )
            .unwrap();

        // 2. g1-f3 (White)
        session
            .process_command(
                p1,
                Box::new(MovePieceCommand {
                    player: p1,
                    from: Position::new(0, 6),
                    to: Position::new(2, 5),
                    promote_to: None,
                }),
            )
            .unwrap();

        // 2... b8-c6 (Black)
        session
            .process_command(
                p2,
                Box::new(MovePieceCommand {
                    player: p2,
                    from: Position::new(7, 1),
                    to: Position::new(5, 2),
                    promote_to: None,
                }),
            )
            .unwrap();

        let pgn = session.export_pgn("Magnus", "Hikaru");
        assert!(pgn.contains("[White \"Magnus\"]"));
        assert!(pgn.contains("[Black \"Hikaru\"]"));
        assert!(
            pgn.contains("1. e4 e5 2. Nf3 Nc6"),
            "El PGN debe contener '1. e4 e5 2. Nf3 Nc6'. Obtenido:\n{}",
            pgn
        );
    }

    #[test]
    fn test_export_fen_posicion_inicial_y_tras_e4() {
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let mut session = new_chess_session(SessionId(1), 1, p1, p2);

        assert_eq!(
            session.export_fen(),
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        );

        // 1. e2-e4
        session
            .process_command(
                p1,
                Box::new(MovePieceCommand {
                    player: p1,
                    from: Position::new(1, 4),
                    to: Position::new(3, 4),
                    promote_to: None,
                }),
            )
            .unwrap();

        assert_eq!(
            session.export_fen(),
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        );
    }
}
