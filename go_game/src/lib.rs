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
    ResignCommand, SetBoardSizeCommand, SetKomiCommand,
};
pub use events::{GameOverEvent, PassedEvent, StonePlacedEvent, StonesCapturedEvent};
pub use rules::{build_go_rules, GoLegalMoveGenerator};
pub use sgf::{export_session_sgf, export_to_sgf, GoSgfExport};

pub fn new_go_session(
    session_id: SessionId,
    seed: u64,
    black: PlayerId,
    white: PlayerId,
) -> Session {
    new_go_session_with_komi(session_id, seed, black, white, 13)
}

pub fn new_go_session_with_size(
    session_id: SessionId,
    seed: u64,
    size: usize,
    black: PlayerId,
    white: PlayerId,
) -> Session {
    let valid_size = if matches!(size, 9 | 13 | 19) { size } else { 9 };
    let mut session =
        Session::new_with_metadata(session_id, "Go", seed, vec![black, white], build_go_rules());
    let board = BoardResource::new(valid_size, black, white).with_komi(13);
    let mut history = BoardHistoryResource::new();
    history.history.insert(board.compute_hash());
    session.world_mut().insert_resource(board);
    session.world_mut().insert_resource(history);
    session
        .world_mut()
        .insert_resource(DeadMarkingResource::default());
    session
}

pub fn new_go_session_with_komi(
    session_id: SessionId,
    seed: u64,
    black: PlayerId,
    white: PlayerId,
    komi_half_points: u32,
) -> Session {
    let mut session =
        Session::new_with_metadata(session_id, "Go", seed, vec![black, white], build_go_rules());
    let board = BoardResource::new(9, black, white).with_komi(komi_half_points);
    let mut history = BoardHistoryResource::new();
    history.history.insert(board.compute_hash());
    session.world_mut().insert_resource(board);
    session.world_mut().insert_resource(history);
    session
        .world_mut()
        .insert_resource(DeadMarkingResource::default());
    session
}
