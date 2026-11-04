// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod movement;
pub mod rules;

use open_table_engine::prelude::*;

pub use ai::{generate_shogi_candidates, piece_value, shogi_ai_pick_move, ShogiAction};
pub use board::{BoardResource, Piece, PieceKind, ShogiHistoryResource, ShogiRulesConfigResource};
pub use commands::{DropPieceCommand, MovePieceCommand, ResignCommand, SetShogiRulesCommand};
pub use events::{GameOverEvent, PieceDroppedEvent, PieceMovedEvent};
pub use movement::{
    can_promote, find_king, has_any_legal_move, is_checkmate, is_in_check, is_legal_drop,
    is_legal_move, must_promote, must_promote_fesa,
};
pub use rules::{build_shogi_rules, ShogiLegalMoveGenerator};

pub fn new_shogi_session(
    session_id: SessionId,
    seed: u64,
    sente: PlayerId,
    gote: PlayerId,
) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Shogi",
        seed,
        vec![sente, gote],
        build_shogi_rules(),
    );
    let board = BoardResource::standard_setup(sente, gote);
    let mut history = ShogiHistoryResource::new();
    history.record(&board, sente);
    session.world_mut().insert_resource(board);
    session.world_mut().insert_resource(history);
    session
        .world_mut()
        .insert_resource(ShogiRulesConfigResource::default());
    session
        .world_mut()
        .insert_resource(LegalMoveGeneratorResource(std::sync::Arc::new(
            ShogiLegalMoveGenerator,
        )));
    session
}

pub fn new_shogi_session_fesa(
    session_id: SessionId,
    seed: u64,
    sente: PlayerId,
    gote: PlayerId,
) -> Session {
    let mut session = new_shogi_session(session_id, seed, sente, gote);
    session
        .world_mut()
        .insert_resource(ShogiRulesConfigResource::fesa());
    session
}
