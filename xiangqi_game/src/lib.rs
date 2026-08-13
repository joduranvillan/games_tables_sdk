pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod movement;
pub mod rules;

use open_table_engine::prelude::*;

pub use ai::{cannon_has_screen, piece_value, xiangqi_ai_pick_move};
pub use board::{BoardResource, Piece, PieceKind};
pub use commands::{MovePieceCommand, ResignCommand};
pub use events::{GameOverEvent, PieceMovedEvent};
pub use movement::{check_flying_general, is_in_check, is_legal_move};
pub use rules::{all_legal_moves_for, build_xiangqi_rules};

pub fn new_xiangqi_session(
    session_id: SessionId,
    seed: u64,
    red: PlayerId,
    black: PlayerId,
) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Xiangqi",
        seed,
        vec![red, black],
        build_xiangqi_rules(),
    );
    session
        .world_mut()
        .insert_resource(BoardResource::standard_setup(red, black));
    session
}
