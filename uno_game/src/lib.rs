pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod rules;

use open_table_engine::prelude::*;

pub use ai::{best_move, most_frequent_color, UnoCommand, UnoStateAccess};
pub use board::{Card, CardColor, CardValue, UnoState};
pub use commands::{
    CallUnoCommand, CatchUnoFailureCommand, ChallengeWildDrawFourCommand, DrawCardCommand,
    InterceptCommand, PlayCardCommand,
};
pub use events::{
    CardPlayedEvent, CardsDrawnEvent, DrewAndPlayedEvent, GameOverEvent, InterceptedEvent,
    PlayerSkippedEvent, TurnReversedEvent, UnoCalledEvent, UnoPenaltyEvent,
    WildDrawFourChallengedEvent,
};
pub use rules::build_uno_rules;

pub fn new_uno_session(session_id: SessionId, seed: u64, players: Vec<PlayerId>) -> Session {
    let mut session =
        Session::new_with_metadata(session_id, "Uno", seed, players.clone(), build_uno_rules());
    let state = {
        let mut rng = session.world_mut().resource_mut::<RandomResource>();
        UnoState::new(&players, &mut rng.0)
    }; // rng borrow dropped before insert_resource
    session.world_mut().insert_resource(state);
    session
}
