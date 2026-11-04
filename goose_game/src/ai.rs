// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;

use crate::board::{GooseBoardResource, PendingRollResource};
use crate::commands::{MoveTokenCommand, RollDiceCommand};

pub type GooseAiDifficulty = AiDifficulty;

#[derive(Debug, Default, Clone, Copy)]
pub struct GooseMoveGenerator;

impl GooseMoveGenerator {
    pub fn legal_moves(&self, session: &Session, player: PlayerId) -> Vec<Box<dyn Command>> {
        self.generate(session.world(), player)
    }
}

impl LegalMoveGenerator for GooseMoveGenerator {
    fn generate(&self, world: &BevyWorld, player: PlayerId) -> Vec<Box<dyn Command>> {
        if world
            .get_resource::<TurnResource>()
            .is_none_or(|t| !t.0.is_current(player))
        {
            return Vec::new();
        }
        if world
            .get_resource::<GooseBoardResource>()
            .and_then(|b| b.winner)
            .is_some()
        {
            return Vec::new();
        }
        let has_pending = world
            .get_resource::<PendingRollResource>()
            .and_then(|p| p.pending.get(&player))
            .is_some();
        if has_pending {
            vec![Box::new(MoveTokenCommand { player })]
        } else {
            vec![Box::new(RollDiceCommand { player })]
        }
    }
}

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

pub fn select_ai_move(
    session: &Session,
    player: PlayerId,
    _difficulty: GooseAiDifficulty,
) -> Option<Box<dyn Command>> {
    GooseMoveGenerator
        .legal_moves(session, player)
        .into_iter()
        .next()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_goose_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn test_goose_ai_pick_move_with_pending_roll() {
        let mut session = new_goose_session(SessionId(1), 42, vec![P1, P2]);
        assert!(goose_ai_pick_move(&session, P1).is_none());

        session
            .world_mut()
            .resource_mut::<PendingRollResource>()
            .pending
            .insert(P1, 4);

        let mv = goose_ai_pick_move(&session, P1);
        assert_eq!(mv, Some(MoveTokenCommand { player: P1 }));
    }
}
