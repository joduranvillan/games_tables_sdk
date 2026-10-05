pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod rules;
pub mod sgf;

use open_table_engine::prelude::*;

pub use ai::go_ai_pick_move;
pub use board::{BoardHistoryResource, BoardResource, DeadMarkingResource, Stone};
pub use commands::{
    ConfirmDeadCommand, MarkDeadCommand, PassCommand, PlaceHandicapCommand, PlaceStoneCommand,
    ResignCommand,
};
pub use events::{GameOverEvent, PassedEvent, StonePlacedEvent, StonesCapturedEvent};
pub use rules::build_go_rules;
pub use sgf::{export_session_sgf, export_to_sgf, GoSgfExport};

pub fn new_go_session(
    session_id: SessionId,
    seed: u64,
    black: PlayerId,
    white: PlayerId,
) -> Session {
    let mut session =
        Session::new_with_metadata(session_id, "Go", seed, vec![black, white], build_go_rules());
    let board = BoardResource::new(9, black, white);
    let mut history = BoardHistoryResource::new();
    history.history.insert(board.compute_hash());
    session.world_mut().insert_resource(board);
    session.world_mut().insert_resource(history);
    session
        .world_mut()
        .insert_resource(DeadMarkingResource::default());
    session
}
