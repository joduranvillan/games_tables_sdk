//! Juego de referencia del OpenTable SDK: damas.
//!
//! Ejercita el SDK completo: `Command`/`Event` via los derives de
//! `open_table_macros`, dos `Resource` (`BoardResource`, `Sides`),
//! turnos (`TurnResource` del engine), y una condición de victoria.
//! Sin información oculta (a propósito: damas es el caso más simple
//! posible antes de meterse con un juego de cartas).
//!
//! Para jugarlo de punta a punta sin esperar a `open_table_godot`, ver
//! `examples/local_match.rs` (dos jugadores por consola, mismo proceso).

pub mod board;
pub mod commands;
pub mod events;
pub mod piece;
pub mod position;
pub mod rules;

pub use board::{initial_board, BoardResource, MultiCaptureResource, Sides};
pub use commands::{MovePieceCommand, ResignCommand};
pub use events::{GameOverEvent, PieceMovedEvent};
pub use piece::Piece;
pub use position::Position;
pub use rules::build_checkers_rules;

use open_table_engine::prelude::*;

/// Arma una `Session` de damas lista para jugar: tablero inicial,
/// jugadores, reglas registradas. Es el punto de entrada que tanto los
/// tests como `examples/local_match.rs` usan para no repetir el setup.
pub fn new_checkers_session(session_id: SessionId, seed: u64, player_top: PlayerId, player_bottom: PlayerId) -> Session {
    let mut session = Session::new_with_metadata(
        session_id,
        "Checkers",
        seed,
        vec![player_top, player_bottom],
        build_checkers_rules(),
    );
    let setup = move |world: &mut BevyWorld| {
        let (board, sides) = initial_board(player_top, player_bottom);
        world.insert_resource(board);
        world.insert_resource(sides);
        world.insert_resource(MultiCaptureResource::default());
    };
    setup(session.world_mut());
    session.set_initial_setup(setup);
    session
}
