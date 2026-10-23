//! Backgammon: juego de referencia para 2 jugadores.
//! Soporta tiradas con dobles (4 movimientos iguales), punto de entrada
//! desde la barra, regla de bear-off (sacar fichas) y paso automático
//! de turno cuando no hay movimientos válidos con los dados tirados.

pub mod ai;
pub mod board;
pub mod commands;
pub mod dice;
pub mod events;
pub mod resources;
pub mod rules;

pub use ai::{backgammon_ai_pick_move, best_move, calculate_pip_count, should_accept_double, should_offer_double, BackgammonCommand};
pub use board::{must_use_larger_die_check, BoardResource, Sides, CHECKERS_PER_PLAYER, POINTS};
pub use commands::{
    AcceptDoubleCommand, MoveCheckerCommand, OfferDoubleCommand, RejectDoubleCommand,
    ResignCommand, RollDiceCommand,
};
pub use dice::PendingDiceResource;
pub use events::{
    CheckerMovedEvent, DiceRolledEvent, DoubleAcceptedEvent, DoubleOfferedEvent,
    DoubleRejectedEvent, GameOverEvent, NoValidMovesEvent,
};
pub use resources::{DoublingCubeResource, MatchStateResource};
pub use rules::{build_backgammon_rules, BackgammonLegalMoveGenerator};

use open_table_engine::prelude::*;

pub fn new_backgammon_session(
    session_id: SessionId,
    seed: u64,
    increasing: PlayerId,
    decreasing: PlayerId,
) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Backgammon",
        seed,
        vec![increasing, decreasing],
        build_backgammon_rules(),
    );
    session
        .world_mut()
        .insert_resource(BoardResource::standard_setup(increasing, decreasing));
    session.world_mut().insert_resource(Sides {
        increasing,
        decreasing,
    });
    session
        .world_mut()
        .insert_resource(PendingDiceResource::default());
    session
        .world_mut()
        .insert_resource(DoublingCubeResource::default());
    session
        .world_mut()
        .insert_resource(MatchStateResource::default());

    session.set_initial_setup(move |world| {
        world.insert_resource(BoardResource::standard_setup(increasing, decreasing));
        world.insert_resource(Sides {
            increasing,
            decreasing,
        });
        world.insert_resource(PendingDiceResource::default());
        world.insert_resource(DoublingCubeResource::default());
        world.insert_resource(MatchStateResource::default());
    });

    session
}
