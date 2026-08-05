pub mod board;
pub mod commands;
pub mod events;
pub mod rules;
pub mod movement;

use open_table_engine::prelude::*;

pub use board::{BoardResource, Piece, PieceKind};
pub use commands::{MovePieceCommand, ResignCommand};
pub use events::{PieceMovedEvent, GameOverEvent};
pub use rules::{build_xiangqi_rules, all_legal_moves_for};
pub use movement::{is_legal_move, check_flying_general, is_in_check};

pub fn new_xiangqi_session(session_id: SessionId, seed: u64, red: PlayerId, black: PlayerId) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Xiangqi",
        seed,
        vec![red, black],
        build_xiangqi_rules(),
    );
    session.world_mut().insert_resource(BoardResource::standard_setup(red, black));
    session
}
