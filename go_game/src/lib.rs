pub mod board;
pub mod commands;
pub mod events;
pub mod rules;

use open_table_engine::prelude::*;

pub use board::{BoardResource, BoardHistoryResource, DeadMarkingResource, Stone};
pub use commands::{PlaceStoneCommand, PassCommand, PlaceHandicapCommand, MarkDeadCommand, ConfirmDeadCommand, ResignCommand};
pub use events::{StonePlacedEvent, StonesCapturedEvent, PassedEvent, GameOverEvent};
pub use rules::build_go_rules;

pub fn new_go_session(session_id: SessionId, seed: u64, black: PlayerId, white: PlayerId) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Go",
        seed,
        vec![black, white],
        build_go_rules(),
    );
    let board = BoardResource::new(9, black, white);
    let mut history = BoardHistoryResource::new();
    history.history.insert(board.compute_hash());
    session.world_mut().insert_resource(board);
    session.world_mut().insert_resource(history);
    session.world_mut().insert_resource(DeadMarkingResource::default());
    session
}
