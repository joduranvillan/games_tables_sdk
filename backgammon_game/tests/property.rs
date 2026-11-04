// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use backgammon_game::{new_backgammon_session, MoveCheckerCommand, PendingDiceResource};
use open_table_engine::prelude::*;
use proptest::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

proptest! {
    #[test]
    fn cualquier_movimiento_valido_no_paniquea(
        die1 in 1u32..=6u32,
        die2 in 1u32..=6u32,
        checker_index in 0usize..25usize,
    ) {
        let mut session = new_backgammon_session(SessionId(1), 42, P1, P2);

        // Forzar los dados pendientes para P1
        session
            .world_mut()
            .resource_mut::<PendingDiceResource>()
            .pending
            .insert(P1, vec![die1, die2]);

        let from = if checker_index == 24 {
            None
        } else {
            Some(checker_index)
        };

        let cmd = MoveCheckerCommand {
            player: P1,
            from,
            die: die1,
        };

        let res = session.process_command(P1, Box::new(cmd));
        match res {
            Ok(_) | Err(EngineError::InvalidCommand { .. }) => {
                // Comportamiento esperado: Ok o error de comando inválido sin causar panic.
            }
            Err(e) => {
                panic!("Error de motor inesperado: {:?}", e);
            }
        }
    }
}
