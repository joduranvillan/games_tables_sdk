pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod movement;
pub mod rules;

use open_table_engine::prelude::*;

pub use ai::{generate_shogi_candidates, piece_value, shogi_ai_pick_move, ShogiAction};
pub use board::{BoardResource, Piece, PieceKind};
pub use commands::{DropPieceCommand, MovePieceCommand, ResignCommand};
pub use events::{GameOverEvent, PieceDroppedEvent, PieceMovedEvent};
pub use movement::{
    can_promote, find_king, has_any_legal_move, is_checkmate, is_in_check, is_legal_drop,
    is_legal_move, must_promote,
};
pub use rules::build_shogi_rules;

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
    session
        .world_mut()
        .insert_resource(BoardResource::standard_setup(sente, gote));
    session
}
