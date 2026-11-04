// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Test helpers and macros for testing games built on `open_table_engine`.

/// Directly mutates `TurnResource` in a session to force the current turn to a given player.
#[macro_export]
macro_rules! force_turn {
    ($session:expr, $player:expr) => {
        $session
            .world_mut()
            .resource_mut::<$crate::turn::TurnResource>()
            .0
            .set_current_player($player);
    };
}

/// Advances `TurnResource` in a session to the next turn.
#[macro_export]
macro_rules! advance_turn {
    ($session:expr) => {
        $session
            .world_mut()
            .resource_mut::<$crate::turn::TurnResource>()
            .0
            .advance()
    };
}
