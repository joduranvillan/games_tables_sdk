use open_table_engine::session::Session;

pub fn export_to_pgn(session: &Session) -> String {
    session.export_chess_pgn().unwrap_or_else(|| {
        "[Event \"Casual Game\"]\n[Site \"OpenTable\"]\n[Date \"????.??.??\"]\n[Round \"1\"]\n[White \"White\"]\n[Black \"Black\"]\n[Result \"*\"]\n\n*".to_string()
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use open_table_core::ids::{PlayerId, SessionId};
    use crate::{new_chess_session, MovePieceCommand, Position};

    #[test]
    fn test_exportar_partida_a_pgn_produce_formato_valido() {
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let mut session = new_chess_session(SessionId(1), 1, p1, p2);

        // 1. e2-e4 (White)
        session.process_command(p1, Box::new(MovePieceCommand {
            player: p1,
            from: Position::new(1, 4),
            to: Position::new(3, 4),
            promote_to: None,
        })).unwrap();

        // 1... e7-e5 (Black)
        session.process_command(p2, Box::new(MovePieceCommand {
            player: p2,
            from: Position::new(6, 4),
            to: Position::new(4, 4),
            promote_to: None,
        })).unwrap();

        // 2. g1-f3 (White)
        session.process_command(p1, Box::new(MovePieceCommand {
            player: p1,
            from: Position::new(0, 6),
            to: Position::new(2, 5),
            promote_to: None,
        })).unwrap();

        // 2... b8-c6 (Black)
        session.process_command(p2, Box::new(MovePieceCommand {
            player: p2,
            from: Position::new(7, 1),
            to: Position::new(5, 2),
            promote_to: None,
        })).unwrap();

        let pgn = export_to_pgn(&session);
        assert!(pgn.contains("1. e4 e5 2. Nf3 Nc6"), "El PGN debe contener '1. e4 e5 2. Nf3 Nc6'. Obtenido:\n{}", pgn);
    }
}
