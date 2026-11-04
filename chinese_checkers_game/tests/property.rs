// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use chinese_checkers_game::{new_chinese_checkers_session, MovePegCommand, Position};
use open_table_engine::prelude::*;
use proptest::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn all_board_positions() -> Vec<Position> {
    let mut positions = Vec::new();
    for q in -4..=4 {
        for r in -4..=4 {
            let p = Position::new(q, r);
            if p.is_on_board() {
                positions.push(p);
            }
        }
    }
    positions
}

proptest! {
    #[test]
    fn movimiento_aleatorio_nunca_paniquea(
        from_index in 0usize..61usize,
        to_index in 0usize..61usize,
    ) {
        let positions = all_board_positions();
        let from = positions[from_index];
        let to = positions[to_index];

        let mut session = new_chinese_checkers_session(SessionId(1), 42, vec![P1, P2]);

        let cmd = MovePegCommand {
            player: P1,
            from,
            to,
            path: vec![],
        };

        let res = session.process_command(P1, Box::new(cmd));
        match res {
            Ok(_) | Err(_) => {
                // Debe retornar Ok o Err de engine/validación, nunca hacer panic.
            }
        }
    }
}
