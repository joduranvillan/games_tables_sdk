// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Ludo: juego de referencia para 2-4 jugadores. Maneja tiradas
//! de dado, detección de movimientos válidos (pasando el turno si no
//! hay jugada posible), casillas seguras en las salidas de cada jugador,
//! captura por posición compartida y tramo final.

pub mod ai;
pub mod board;
pub mod commands;
pub mod events;
pub mod rules;

pub use ai::ludo_ai_pick_move;
pub use board::{
    next_step_for, ConsecutiveSixesResource, LudoRulesConfigResource, PendingRollResource,
    TokensResource, BOARD_STEPS, HOME_STRETCH_LEN, MAX_STEPS, TOKENS_PER_PLAYER, TRACK_LEN,
    WIN_STEPS,
};
pub use commands::{MoveTokenCommand, ResignCommand, RollDiceCommand, SetLudoRulesCommand};
pub use events::{DiceRolledEvent, GameOverEvent, NoValidMovesEvent, TokenMovedEvent};
pub use rules::build_ludo_rules;

use open_table_engine::prelude::*;

pub fn new_ludo_session(session_id: SessionId, seed: u64, players: Vec<PlayerId>) -> Session {
    assert!(
        (2..=4).contains(&players.len()),
        "Ludo simplificado soporta entre 2 y 4 jugadores"
    );
    let mut session = Session::new_with_metadata(
        session_id,
        "Ludo",
        seed,
        players.clone(),
        build_ludo_rules(),
    );
    session
        .world_mut()
        .insert_resource(TokensResource::new(&players));
    session
        .world_mut()
        .insert_resource(PendingRollResource::default());
    session
        .world_mut()
        .insert_resource(ConsecutiveSixesResource::default());
    session
        .world_mut()
        .insert_resource(LudoRulesConfigResource::default());
    session
}
