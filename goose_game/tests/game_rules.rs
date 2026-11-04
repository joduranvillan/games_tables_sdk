// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use goose_game::{
    new_goose_session, select_ai_move, GooseAiDifficulty, GooseBoardResource, GooseMoveGenerator,
    MoveTokenCommand, PendingRollResource, ResignCommand, RollDiceCommand,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn test_initial_session_and_roll_then_move() {
    let mut session = new_goose_session(SessionId(100), 12345, vec![P1, P2]);
    assert_eq!(session.current_player(), P1);
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P1),
        0
    );

    session
        .process_command(P1, Box::new(RollDiceCommand { player: P1 }))
        .expect("P1 must be able to roll dice on their turn");

    let rolled = session
        .world()
        .resource::<PendingRollResource>()
        .pending
        .get(&P1)
        .copied()
        .expect("Pending roll should be stored for P1");
    assert!((1..=6).contains(&rolled));

    session
        .process_command(P1, Box::new(MoveTokenCommand { player: P1 }))
        .expect("P1 must be able to move token after rolling");

    assert!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P1)
            >= 1
    );
}

#[test]
fn test_reject_move_without_rolling_and_out_of_turn() {
    let mut session = new_goose_session(SessionId(101), 54321, vec![P1, P2]);

    let err_no_roll = session.process_command(P1, Box::new(MoveTokenCommand { player: P1 }));
    assert!(err_no_roll.is_err(), "Cannot move before rolling dice");

    let err_wrong_turn = session.process_command(P2, Box::new(RollDiceCommand { player: P2 }));
    assert!(err_wrong_turn.is_err(), "P2 cannot roll on P1's turn");
}

#[test]
fn test_legal_moves_ai_and_resign() {
    let mut session = new_goose_session(SessionId(102), 777, vec![P1, P2]);
    let generator = GooseMoveGenerator;

    let legal_initial = generator.legal_moves(&session, P1);
    assert_eq!(legal_initial.len(), 1);

    let ai_cmd = select_ai_move(&session, P1, GooseAiDifficulty::Hard);
    assert!(ai_cmd.is_some());

    session
        .process_command(P1, Box::new(ResignCommand { player: P1 }))
        .expect("Resign should succeed");
    assert_eq!(
        session.world().resource::<GooseBoardResource>().winner,
        Some(P2)
    );
}
