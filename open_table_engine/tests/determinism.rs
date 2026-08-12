use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const SEED: u64 = 42;

fn assert_event_sequences_match(events1: &[Box<dyn Event>], events2: &[Box<dyn Event>]) {
    assert_eq!(
        events1.len(),
        events2.len(),
        "Event counts differ between replayed sessions"
    );
    for (i, (e1, e2)) in events1.iter().zip(events2.iter()).enumerate() {
        let json1 = serde_json::to_string(e1).expect("Failed to serialize event 1");
        let json2 = serde_json::to_string(e2).expect("Failed to serialize event 2");
        assert_eq!(
            json1, json2,
            "Event mismatch at index {i}: {json1} != {json2}"
        );
    }
}

fn test_game_determinism<F>(constructor: F, run_commands: impl FnOnce(&mut Session))
where
    F: Fn(SessionId, u64) -> Session,
{
    // 1. Create source session and run 5 commands
    let mut source_session = constructor(SessionId(1), SEED);
    let initial_count = source_session.tick_timestamps().len();
    run_commands(&mut source_session);
    assert_eq!(
        source_session.tick_timestamps().len() - initial_count,
        5,
        "Source session must contain exactly 5 commands in log"
    );

    let log_bytes = source_session
        .export_log()
        .expect("Failed to export log from source session");

    // 2. Create two fresh sessions with the same seed
    let session1 = constructor(SessionId(101), SEED);
    let session2 = constructor(SessionId(102), SEED);

    // 3. Replay log on both sessions
    let (s1_after, events1) =
        Session::replay_on_session(session1, &log_bytes).expect("Replay failed on session 1");
    let (s2_after, events2) =
        Session::replay_on_session(session2, &log_bytes).expect("Replay failed on session 2");

    // 4. Verify identical event sequences and states
    assert_event_sequences_match(&events1, &events2);
    assert_eq!(s1_after.current_tick(), s2_after.current_tick());
    assert_eq!(s1_after.current_player(), s2_after.current_player());
}

#[test]
fn test_checkers_determinism() {
    test_game_determinism(
        |id, seed| checkers_game::new_checkers_session(id, seed, P1, P2),
        |s| {
            s.process_command(
                P1,
                Box::new(checkers_game::MovePieceCommand {
                    player: P1,
                    from: checkers_game::Position::new(2, 1),
                    to: checkers_game::Position::new(3, 0),
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(checkers_game::MovePieceCommand {
                    player: P2,
                    from: checkers_game::Position::new(5, 6),
                    to: checkers_game::Position::new(4, 7),
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(checkers_game::MovePieceCommand {
                    player: P1,
                    from: checkers_game::Position::new(2, 7),
                    to: checkers_game::Position::new(3, 6),
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(checkers_game::MovePieceCommand {
                    player: P2,
                    from: checkers_game::Position::new(5, 0),
                    to: checkers_game::Position::new(4, 1),
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(checkers_game::MovePieceCommand {
                    player: P1,
                    from: checkers_game::Position::new(2, 5),
                    to: checkers_game::Position::new(3, 4),
                }),
            )
            .unwrap();
        },
    );
}

#[test]
fn test_chess_determinism() {
    test_game_determinism(
        |id, seed| chess_game::new_chess_session(id, seed, P1, P2),
        |s| {
            s.process_command(
                P1,
                Box::new(chess_game::MovePieceCommand {
                    player: P1,
                    from: chess_game::Position::new(1, 4),
                    to: chess_game::Position::new(3, 4),
                    promote_to: None,
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(chess_game::MovePieceCommand {
                    player: P2,
                    from: chess_game::Position::new(6, 4),
                    to: chess_game::Position::new(4, 4),
                    promote_to: None,
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(chess_game::MovePieceCommand {
                    player: P1,
                    from: chess_game::Position::new(0, 6),
                    to: chess_game::Position::new(2, 5),
                    promote_to: None,
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(chess_game::MovePieceCommand {
                    player: P2,
                    from: chess_game::Position::new(7, 1),
                    to: chess_game::Position::new(5, 2),
                    promote_to: None,
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(chess_game::MovePieceCommand {
                    player: P1,
                    from: chess_game::Position::new(1, 3),
                    to: chess_game::Position::new(3, 3),
                    promote_to: None,
                }),
            )
            .unwrap();
        },
    );
}

#[test]
fn test_shogi_determinism() {
    test_game_determinism(
        |id, seed| shogi_game::new_shogi_session(id, seed, P1, P2),
        |s| {
            s.process_command(
                P1,
                Box::new(shogi_game::MovePieceCommand {
                    player: P1,
                    from: (4, 6),
                    to: (4, 5),
                    promote: false,
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(shogi_game::MovePieceCommand {
                    player: P2,
                    from: (4, 2),
                    to: (4, 3),
                    promote: false,
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(shogi_game::MovePieceCommand {
                    player: P1,
                    from: (4, 8),
                    to: (3, 8),
                    promote: false,
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(shogi_game::MovePieceCommand {
                    player: P2,
                    from: (4, 0),
                    to: (3, 0),
                    promote: false,
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(shogi_game::MovePieceCommand {
                    player: P1,
                    from: (3, 8),
                    to: (2, 8),
                    promote: false,
                }),
            )
            .unwrap();
        },
    );
}

#[test]
fn test_xiangqi_determinism() {
    test_game_determinism(
        |id, seed| xiangqi_game::new_xiangqi_session(id, seed, P1, P2),
        |s| {
            s.process_command(
                P1,
                Box::new(xiangqi_game::MovePieceCommand {
                    player: P1,
                    from: (4, 6),
                    to: (4, 5),
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(xiangqi_game::MovePieceCommand {
                    player: P2,
                    from: (4, 3),
                    to: (4, 4),
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(xiangqi_game::MovePieceCommand {
                    player: P1,
                    from: (4, 5),
                    to: (4, 4),
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(xiangqi_game::MovePieceCommand {
                    player: P2,
                    from: (4, 0),
                    to: (3, 0),
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(xiangqi_game::MovePieceCommand {
                    player: P1,
                    from: (4, 4),
                    to: (4, 3),
                }),
            )
            .unwrap();
        },
    );
}

#[test]
fn test_go_determinism() {
    test_game_determinism(
        |id, seed| go_game::new_go_session(id, seed, P1, P2),
        |s| {
            s.process_command(
                P1,
                Box::new(go_game::PlaceStoneCommand {
                    player: P1,
                    x: 1,
                    y: 0,
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(go_game::PlaceStoneCommand {
                    player: P2,
                    x: 2,
                    y: 0,
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(go_game::PlaceStoneCommand {
                    player: P1,
                    x: 3,
                    y: 0,
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(go_game::PlaceStoneCommand {
                    player: P2,
                    x: 4,
                    y: 0,
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(go_game::PlaceStoneCommand {
                    player: P1,
                    x: 5,
                    y: 0,
                }),
            )
            .unwrap();
        },
    );
}

#[test]
fn test_uno_determinism() {
    test_game_determinism(
        |id, seed| uno_game::new_uno_session(id, seed, vec![P1, P2]),
        |s| {
            for _ in 0..5 {
                let p = s.current_player();
                s.process_command(p, Box::new(uno_game::DrawCardCommand { player: p }))
                    .unwrap();
            }
        },
    );
}

#[test]
fn test_crisis_determinism() {
    test_game_determinism(
        |id, seed| crisis_game::new_crisis_session(id, seed, &[P1, P2]).unwrap(),
        |s| {
            for _ in 0..5 {
                let p = s.current_player();
                let terr = *s
                    .world()
                    .resource::<crisis_game::TerritoryStateResource>()
                    .owners
                    .iter()
                    .find(|(_, &owner)| owner == p)
                    .map(|(t, _)| t)
                    .expect("player has territory");
                s.process_command(
                    p,
                    Box::new(crisis_game::PlaceArmiesCommand {
                        player: p,
                        territory: terr,
                        count: 1,
                    }),
                )
                .unwrap();
            }
        },
    );
}

#[test]
fn test_chinese_checkers_determinism() {
    test_game_determinism(
        |id, seed| chinese_checkers_game::new_chinese_checkers_session(id, seed, vec![P1, P2]),
        |s| {
            let cells_a = chinese_checkers_game::home_cells_a();
            let cells_b = chinese_checkers_game::home_cells_b();
            s.process_command(
                P1,
                Box::new(chinese_checkers_game::MovePegCommand {
                    player: P1,
                    from: cells_a[0],
                    to: cells_a[0].add((1, 0)),
                    path: vec![cells_a[0], cells_a[0].add((1, 0))],
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(chinese_checkers_game::MovePegCommand {
                    player: P2,
                    from: cells_b[0],
                    to: cells_b[0].add((-1, 0)),
                    path: vec![cells_b[0], cells_b[0].add((-1, 0))],
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(chinese_checkers_game::MovePegCommand {
                    player: P1,
                    from: cells_a[0].add((1, 0)),
                    to: cells_a[0].add((2, 0)),
                    path: vec![cells_a[0].add((1, 0)), cells_a[0].add((2, 0))],
                }),
            )
            .unwrap();
            s.process_command(
                P2,
                Box::new(chinese_checkers_game::MovePegCommand {
                    player: P2,
                    from: cells_b[0].add((-1, 0)),
                    to: cells_b[0].add((-2, 0)),
                    path: vec![cells_b[0].add((-1, 0)), cells_b[0].add((-2, 0))],
                }),
            )
            .unwrap();
            s.process_command(
                P1,
                Box::new(chinese_checkers_game::MovePegCommand {
                    player: P1,
                    from: cells_a[0].add((2, 0)),
                    to: cells_a[0].add((3, 0)),
                    path: vec![cells_a[0].add((2, 0)), cells_a[0].add((3, 0))],
                }),
            )
            .unwrap();
        },
    );
}

#[test]
fn test_mille_bornes_determinism() {
    test_game_determinism(
        |id, seed| mille_bornes_game::new_mille_bornes_session(id, seed, P1, P2),
        |s| {
            for _ in 0..5 {
                let p = s.current_player();
                s.process_command(
                    p,
                    Box::new(mille_bornes_game::DiscardCardCommand {
                        player: p,
                        card_index: 0,
                    }),
                )
                .unwrap();
            }
        },
    );
}

#[test]
fn test_backgammon_determinism() {
    test_game_determinism(
        |id, seed| backgammon_game::new_backgammon_session(id, seed, P1, P2),
        |s| {
            for _ in 0..5 {
                let p = s.current_player();
                let has_dice = s
                    .world()
                    .resource::<backgammon_game::PendingDiceResource>()
                    .pending
                    .get(&p)
                    .map_or(false, |d| !d.is_empty());
                if has_dice {
                    let die = s
                        .world()
                        .resource::<backgammon_game::PendingDiceResource>()
                        .pending[&p][0];
                    let board = s.world().resource::<backgammon_game::BoardResource>();
                    let sides = s.world().resource::<backgammon_game::Sides>();
                    let sign = sides.owner_sign(p);
                    let from_pt = (0..24).find(|&i| board.points[i] * sign > 0);
                    s.process_command(
                        p,
                        Box::new(backgammon_game::MoveCheckerCommand {
                            player: p,
                            from: from_pt,
                            die,
                        }),
                    )
                    .unwrap();
                } else {
                    s.process_command(p, Box::new(backgammon_game::RollDiceCommand { player: p }))
                        .unwrap();
                }
            }
        },
    );
}

#[test]
fn test_monopoly_determinism() {
    test_game_determinism(
        |id, seed| monopoly_game::new_monopoly_session(id, seed, P1, P2),
        |s| {
            for _ in 0..5 {
                let p = s.current_player();
                let is_auction = s
                    .world()
                    .resource::<monopoly_game::AuctionResource>()
                    .state
                    .is_some();
                if is_auction {
                    s.process_command(
                        p,
                        Box::new(monopoly_game::AuctionBidCommand {
                            player: p,
                            amount: 0,
                        }),
                    )
                    .unwrap();
                } else {
                    let is_pending = s
                        .world()
                        .resource::<monopoly_game::PendingPurchaseResource>()
                        .pending
                        .contains_key(&p);
                    if is_pending {
                        s.process_command(
                            p,
                            Box::new(monopoly_game::BuyPropertyCommand {
                                player: p,
                                buy: false,
                            }),
                        )
                        .unwrap();
                    } else {
                        s.process_command(
                            p,
                            Box::new(monopoly_game::RollAndMoveCommand { player: p }),
                        )
                        .unwrap();
                    }
                }
            }
        },
    );
}

#[test]
fn test_ludo_determinism() {
    test_game_determinism(
        |id, seed| ludo_game::new_ludo_session(id, seed, vec![P1, P2]),
        |s| {
            for _ in 0..5 {
                let p = s.current_player();
                let is_pending = s
                    .world()
                    .resource::<ludo_game::PendingRollResource>()
                    .pending
                    .contains_key(&p);
                if is_pending {
                    s.process_command(
                        p,
                        Box::new(ludo_game::MoveTokenCommand {
                            player: p,
                            token_index: 0,
                        }),
                    )
                    .unwrap();
                } else {
                    s.process_command(p, Box::new(ludo_game::RollDiceCommand { player: p }))
                        .unwrap();
                }
            }
        },
    );
}
