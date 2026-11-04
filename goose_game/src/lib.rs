// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! El Juego de la Oca (`goose_game`): juego clásico de recorrido en espiral de 63 casillas
//! para 2 a 6 jugadores (por defecto 2 a 4), con casillas especiales tradicionales
//! (Ocas, Puentes, Posada, Dados, Pozo, Laberinto, Cárcel, Calavera y Jardín de la Oca)
//! y rebote exacto al superar la casilla 63.

pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod rules;

pub use ai::{
    best_move, goose_ai_pick_move, select_ai_move, GooseAiDifficulty, GooseMoveGenerator,
};
pub use board::{
    compute_raw_square, is_goose_square, next_goose_square, resolve_landing, GooseBoardResource,
    LandingResolution, PendingRollResource, SpecialSquareKind, BRIDGE_A, BRIDGE_B, DICE_A, DICE_B,
    GARDEN_SQUARE, GOOSE_SQUARES, INN_SQUARE, LABYRINTH_SQUARE, LABYRINTH_TARGET, PRISON_SQUARE,
    SKULL_SQUARE, SKULL_TARGET, WELL_SQUARE,
};
pub use commands::{MoveTokenCommand, ResignCommand, RollDiceCommand};
pub use events::{DiceRolledEvent, GameOverEvent, GooseMovedEvent, TurnSkippedEvent};
pub use rules::build_goose_rules;

use open_table_engine::prelude::*;

pub fn new_goose_session(session_id: SessionId, seed: u64, players: Vec<PlayerId>) -> Session {
    assert!(
        (2..=6).contains(&players.len()),
        "El Juego de la Oca soporta entre 2 y 6 jugadores"
    );
    let mut session = Session::new_with_metadata(
        session_id,
        "Goose",
        seed,
        players.clone(),
        build_goose_rules(),
    );
    let setup = move |world: &mut BevyWorld| {
        world.insert_resource(GooseBoardResource::new(&players));
        world.insert_resource(PendingRollResource::default());
        world.insert_resource(LegalMoveGeneratorResource(std::sync::Arc::new(
            GooseMoveGenerator,
        )));
    };
    setup(session.world_mut());
    session.set_initial_setup(setup);
    session
}
