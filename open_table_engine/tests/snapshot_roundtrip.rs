// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;
use open_table_engine::rule_engine::RuleEngine;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const SEED: u64 = 42;

fn test_snapshot_roundtrip<F, R>(
    constructor: F,
    rules_fn: R,
    run_3_commands: impl FnOnce(&mut Session),
) where
    F: Fn(SessionId, u64) -> Session,
    R: Fn() -> RuleEngine,
{
    let mut orig_session = constructor(SessionId(1), SEED);
    run_3_commands(&mut orig_session);

    let orig_tick = orig_session.current_tick();
    let orig_player = orig_session.current_player();
    let orig_hash = orig_session.world_hash();

    let snapshot_bytes = orig_session.snapshot().expect("snapshot falló");
    let restored_session =
        Session::from_snapshot(&snapshot_bytes, rules_fn()).expect("from_snapshot falló");

    assert_eq!(
        restored_session.current_tick(),
        orig_tick,
        "current_tick debe coincidir después de from_snapshot"
    );
    assert_eq!(
        restored_session.current_player(),
        orig_player,
        "current_player debe coincidir después de from_snapshot"
    );
    assert_eq!(
        restored_session.world_hash(),
        orig_hash,
        "world_hash debe coincidir después de from_snapshot"
    );
}

#[test]
fn test_checkers_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| checkers_game::new_checkers_session(id, seed, P1, P2),
        checkers_game::build_checkers_rules,
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
        },
    );
}

#[test]
fn test_chess_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| chess_game::new_chess_session(id, seed, P1, P2),
        chess_game::build_chess_rules,
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
        },
    );
}

#[test]
fn test_shogi_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| shogi_game::new_shogi_session(id, seed, P1, P2),
        shogi_game::build_shogi_rules,
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
        },
    );
}

#[test]
fn test_xiangqi_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| xiangqi_game::new_xiangqi_session(id, seed, P1, P2),
        xiangqi_game::build_xiangqi_rules,
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
        },
    );
}

#[test]
fn test_go_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| go_game::new_go_session(id, seed, P1, P2),
        go_game::build_go_rules,
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
        },
    );
}

#[test]
fn test_uno_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| uno_game::new_uno_session(id, seed, vec![P1, P2]),
        uno_game::build_uno_rules,
        |s| {
            for _ in 0..3 {
                let p = s.current_player();
                s.process_command(p, Box::new(uno_game::DrawCardCommand { player: p }))
                    .unwrap();
            }
        },
    );
}

#[test]
fn test_crisis_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| crisis_game::new_crisis_session(id, seed, &[P1, P2]).unwrap(),
        crisis_game::build_crisis_rules,
        |s| {
            for _ in 0..3 {
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
fn test_chinese_checkers_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| chinese_checkers_game::new_chinese_checkers_session(id, seed, vec![P1, P2]),
        chinese_checkers_game::build_chinese_checkers_rules,
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
        },
    );
}

#[test]
fn test_mille_bornes_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| mille_bornes_game::new_mille_bornes_session(id, seed, P1, P2),
        mille_bornes_game::build_mille_bornes_rules,
        |s| {
            for _ in 0..3 {
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
fn test_backgammon_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| backgammon_game::new_backgammon_session(id, seed, P1, P2),
        backgammon_game::build_backgammon_rules,
        |s| {
            for _ in 0..3 {
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
fn test_monopoly_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| monopoly_game::new_monopoly_session(id, seed, P1, P2),
        monopoly_game::build_monopoly_rules,
        |s| {
            for _ in 0..3 {
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
fn test_ludo_snapshot_roundtrip() {
    test_snapshot_roundtrip(
        |id, seed| ludo_game::new_ludo_session(id, seed, vec![P1, P2]),
        ludo_game::build_ludo_rules,
        |s| {
            for _ in 0..3 {
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
