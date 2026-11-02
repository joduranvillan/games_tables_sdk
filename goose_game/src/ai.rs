// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;

use crate::board::{GooseBoardResource, PendingRollResource};
use crate::commands::MoveTokenCommand;

/// Selecciona el movimiento de avance para `player` cuando tiene una tirada pendiente.
pub fn goose_ai_pick_move(session: &Session, player: PlayerId) -> Option<MoveTokenCommand> {
    if session.current_player() != player {
        return None;
    }

    if session
        .world()
        .get_resource::<GooseBoardResource>()
        .and_then(|b| b.winner)
        .is_some()
    {
        return None;
    }

    let _roll = session
        .world()
        .get_resource::<PendingRollResource>()
        .and_then(|p| p.pending.get(&player).copied())?;

    Some(MoveTokenCommand { player })
}

pub fn best_move(
    session: &Session,
    player: PlayerId,
    _difficulty: AiDifficulty,
) -> Option<MoveTokenCommand> {
    goose_ai_pick_move(session, player)
}
