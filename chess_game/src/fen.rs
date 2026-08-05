use std::collections::HashMap;
use open_table_core::ids::PlayerId;
use open_table_core::error::EngineError;
use open_table_engine::session::Session;
use crate::board::BoardResource;
use crate::position::{Piece, PieceKind, Position};

pub fn load_chess_position_from_fen(session: &mut Session, fen: &str) -> Result<(), EngineError> {
    let (board, active_player) = parse_fen_with_player(fen)?;
    session.world_mut().insert_resource(board);
    if let Some(mut turn) = session.world_mut().get_resource_mut::<open_table_engine::turn::TurnResource>() {
        turn.0.set_current_player(active_player);
    }
    Ok(())
}

pub fn from_fen(fen: &str) -> Result<BoardResource, EngineError> {
    let (board, _) = parse_fen_with_player(fen)?;
    Ok(board)
}

pub fn parse_fen_with_player(fen: &str) -> Result<(BoardResource, PlayerId), EngineError> {
    let parts: Vec<&str> = fen.split_whitespace().collect();
    if parts.is_empty() {
        return Err(EngineError::InvalidCommand {
            reason: "FEN vacío".into(),
        });
    }

    let p1 = PlayerId(1);
    let p2 = PlayerId(2);

    let mut pieces = HashMap::new();
    let ranks: Vec<&str> = parts[0].split('/').collect();
    if ranks.len() != 8 {
        return Err(EngineError::InvalidCommand {
            reason: format!("FEN inválido: se esperaban 8 filas, hay {}", ranks.len()),
        });
    }

    for (rank_idx, rank_str) in ranks.iter().enumerate() {
        let row = (7 - rank_idx) as u8;
        let mut col: u8 = 0;
        for c in rank_str.chars() {
            if let Some(digit) = c.to_digit(10) {
                col += digit as u8;
            } else {
                if col >= 8 {
                    return Err(EngineError::InvalidCommand {
                        reason: "FEN inválido: columna fuera de límites".into(),
                    });
                }
                let owner = if c.is_uppercase() { p1 } else { p2 };
                let kind = match c.to_ascii_lowercase() {
                    'p' => PieceKind::Pawn,
                    'n' => PieceKind::Knight,
                    'b' => PieceKind::Bishop,
                    'r' => PieceKind::Rook,
                    'q' => PieceKind::Queen,
                    'k' => PieceKind::King,
                    _ => {
                        return Err(EngineError::InvalidCommand {
                            reason: format!("Pieza FEN desconocida: {c}"),
                        });
                    }
                };
                pieces.insert(Position::new(row, col), Piece { owner, kind });
                col += 1;
            }
        }
    }

    let active_player = if parts.len() > 1 && parts[1] == "b" {
        p2
    } else {
        p1
    };

    let mut white_king_moved = true;
    let mut white_rook_a_moved = true;
    let mut white_rook_h_moved = true;
    let mut black_king_moved = true;
    let mut black_rook_a_moved = true;
    let mut black_rook_h_moved = true;

    if parts.len() > 2 {
        let castling = parts[2];
        if castling.contains('K') {
            white_king_moved = false;
            white_rook_h_moved = false;
        }
        if castling.contains('Q') {
            white_king_moved = false;
            white_rook_a_moved = false;
        }
        if castling.contains('k') {
            black_king_moved = false;
            black_rook_h_moved = false;
        }
        if castling.contains('q') {
            black_king_moved = false;
            black_rook_a_moved = false;
        }
    }

    let mut en_passant_target = None;
    if parts.len() > 3 && parts[3] != "-" {
        let ep_str = parts[3];
        if ep_str.len() == 2 {
            let ep_bytes = ep_str.as_bytes();
            let c = ep_bytes[0] as i32 - b'a' as i32;
            let r = ep_bytes[1] as i32 - b'1' as i32;
            if (0..8).contains(&c) && (0..8).contains(&r) {
                en_passant_target = Some(Position::new(r as u8, c as u8));
            }
        }
    }

    let board = BoardResource {
        pieces,
        en_passant_target,
        white_king_moved,
        white_rook_a_moved,
        white_rook_h_moved,
        black_king_moved,
        black_rook_a_moved,
        black_rook_h_moved,
    };

    Ok((board, active_player))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cargar_posicion_desde_fen_inicializa_tablero_correcto() {
        let initial_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
        let (board_init, active_init) = parse_fen_with_player(initial_fen).unwrap();
        assert_eq!(board_init.pieces.len(), 32);
        assert_eq!(active_init, PlayerId(1));
        assert_eq!(board_init.get(Position::new(1, 4)), Some(Piece { owner: PlayerId(1), kind: PieceKind::Pawn }));
        assert_eq!(board_init.get(Position::new(7, 4)), Some(Piece { owner: PlayerId(2), kind: PieceKind::King }));

        let middlegame_fen = "r1bqk2r/pp1pppbp/2n2np1/8/3NP3/2N1B3/PPP2PPP/R2QKB1R w KQkq - 3 7";
        let (board_mid, active_mid) = parse_fen_with_player(middlegame_fen).unwrap();
        assert_eq!(active_mid, PlayerId(1));
        assert_eq!(board_mid.get(Position::new(3, 3)), Some(Piece { owner: PlayerId(1), kind: PieceKind::Knight }));
        assert_eq!(board_mid.get(Position::new(5, 2)), Some(Piece { owner: PlayerId(2), kind: PieceKind::Knight }));
        assert_eq!(board_mid.get(Position::new(2, 4)), Some(Piece { owner: PlayerId(1), kind: PieceKind::Bishop }));
    }
}
