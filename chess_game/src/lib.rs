// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Ajedrez: octavo y último juego de referencia, el más completo en
//! términos de validación de reglas. Implementa movimiento real de las
//! 6 piezas, enroque (corto y largo), captura al paso, elección de pieza
//! al coronar, detección de jaque (simulando la jugada antes de aplicarla
//! de verdad), y jaque mate / ahogado por enumeración completa de
//! movimientos legales del rival.

pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod fen;
pub mod legal_moves;
pub mod opening_book;
pub mod pgn;
pub mod position;
pub mod rules;

pub use ai::chess_ai_pick_move;
pub use board::{
    has_any_legal_move, is_in_check, is_legal_move, piece_moves, BoardResource,
    DrawOfferedResource, HalfMoveClockResource, PositionHistoryResource, Sides,
};
pub use commands::{AcceptDrawCommand, MovePieceCommand, OfferDrawCommand, ResignCommand};
pub use events::{GameOverEvent, PieceMovedEvent};
pub use fen::{from_fen, load_chess_position_from_fen, parse_fen_with_player};
pub use legal_moves::ChessLegalMoveGenerator;
pub use opening_book::{compute_zobrist_hash, ChessMove, OpeningBook};
pub use pgn::{export_session_fen, export_session_pgn, export_to_pgn, ChessNotationExport};
pub use position::{Piece, PieceKind, Position};
pub use rules::build_chess_rules;

use open_table_engine::prelude::*;

pub fn new_chess_session(
    session_id: SessionId,
    seed: u64,
    white: PlayerId,
    black: PlayerId,
) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Chess",
        seed,
        vec![white, black],
        build_chess_rules(),
    );
    let board = BoardResource::standard_setup(white, black);
    let initial_hash = board.compute_hash(white);
    session.world_mut().insert_resource(board);
    session.world_mut().insert_resource(Sides { white, black });
    session
        .world_mut()
        .insert_resource(TurnResource(TurnOrder::new(vec![white, black])));
    session
        .world_mut()
        .insert_resource(DrawOfferedResource::default());
    session
        .world_mut()
        .insert_resource(HalfMoveClockResource(0));
    let mut history = PositionHistoryResource::default();
    history.history.insert(initial_hash, 1);
    session.world_mut().insert_resource(history);
    session
        .world_mut()
        .insert_resource(LegalMoveGeneratorResource(std::sync::Arc::new(
            ChessLegalMoveGenerator,
        )));
    session.world_mut().insert_resource(GameOverResource(false));
    session.world_mut().insert_resource(WinnerResource(None));
    session
}
