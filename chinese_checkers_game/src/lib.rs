pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod position;
pub mod rules;

pub use ai::{
    best_move, generate_legal_moves, hex_distance, total_distance_to_goal, ChineseCheckersCommand,
    ChineseCheckersState,
};
pub use board::BoardResource;
pub use commands::{MovePegCommand, ResignCommand};
pub use events::{GameOverEvent, PegMovedEvent};
pub use position::{corner_cells, home_cells_a, home_cells_b, Position, BOARD_RADIUS};
pub use rules::{build_chinese_checkers_rules, ChineseCheckersLegalMoveGenerator};

use open_table_engine::prelude::*;

pub fn new_chinese_checkers_session(
    session_id: SessionId,
    seed: u64,
    players: Vec<PlayerId>,
) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Chinese Checkers",
        seed,
        players.clone(),
        build_chinese_checkers_rules(),
    );
    session
        .world_mut()
        .insert_resource(BoardResource::new(players));
    session
}
