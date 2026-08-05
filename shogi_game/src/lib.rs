pub mod board;
pub mod commands;
pub mod events;
pub mod rules;
pub mod movement;

use open_table_engine::prelude::*;

pub use board::{BoardResource, Piece, PieceKind};
pub use commands::{MovePieceCommand, DropPieceCommand, ResignCommand};
pub use events::{PieceMovedEvent, PieceDroppedEvent, GameOverEvent};
pub use rules::build_shogi_rules;
pub use movement::{is_legal_move, is_legal_drop, can_promote, must_promote, is_in_check, is_checkmate, find_king, has_any_legal_move};

pub fn new_shogi_session(session_id: SessionId, seed: u64, sente: PlayerId, gote: PlayerId) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Shogi",
        seed,
        vec![sente, gote],
        build_shogi_rules(),
    );
    session.world_mut().insert_resource(BoardResource::standard_setup(sente, gote));
    session
}
