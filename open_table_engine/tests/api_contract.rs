use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn contrato_cross_crate_de_constructores_de_sesion() {
    let players = vec![P1, P2];
    let sessions: Vec<(&str, Session)> = vec![
        ("checkers", checkers_game::new_checkers_session(SessionId(1), 42, P1, P2)),
        ("chess", chess_game::new_chess_session(SessionId(2), 42, P1, P2)),
        ("shogi", shogi_game::new_shogi_session(SessionId(3), 42, P1, P2)),
        ("xiangqi", xiangqi_game::new_xiangqi_session(SessionId(4), 42, P1, P2)),
        ("go", go_game::new_go_session(SessionId(5), 42, P1, P2)),
        ("uno", uno_game::new_uno_session(SessionId(6), 42, vec![P1, P2])),
        ("crisis", crisis_game::new_crisis_session(SessionId(7), 42, &[P1, P2]).unwrap()),
        ("chinese_checkers", chinese_checkers_game::new_chinese_checkers_session(SessionId(8), 42, vec![P1, P2])),
        ("mille_bornes", mille_bornes_game::new_mille_bornes_session(SessionId(9), 42, P1, P2)),
        ("backgammon", backgammon_game::new_backgammon_session(SessionId(10), 42, P1, P2)),
        ("monopoly", monopoly_game::new_monopoly_session(SessionId(11), 42, P1, P2)),
        ("ludo", ludo_game::new_ludo_session(SessionId(12), 42, vec![P1, P2])),
    ];

    for (name, session) in sessions {
        // 1. Retorna una Session (asertado por tipo)

        // 2. Tiene al menos 2 jugadores válidos en TurnResource
        let turn_res = session.world().resource::<TurnResource>();
        assert!(
            turn_res.0.players().len() >= 2,
            "{} debe tener al menos 2 jugadores en TurnResource",
            name
        );

        // 3. current_player() es uno de los jugadores pasados
        let curr = session.current_player();
        assert!(
            players.contains(&curr),
            "{} current_player() ({:?}) debe ser uno de los jugadores pasados {:?}",
            name,
            curr,
            players
        );
    }
}

#[test]
fn test_move_history_refleja_los_comandos_jugados() {
    let mut session = checkers_game::new_checkers_session(SessionId(1), 42, P1, P2);
    let cmd = Box::new(checkers_game::MovePieceCommand {
        player: P1,
        from: checkers_game::Position::new(2, 1),
        to: checkers_game::Position::new(3, 2),
    });

    session.process_command(P1, cmd).unwrap();

    let history = session.move_history();
    assert_eq!(history.len(), 1);
    assert!(history[0].contains("Tick 1"));
    assert!(history[0].contains("Player 1"));
    assert!(history[0].contains("MovePieceCommand"));
}

#[test]
fn test_watch_dispara_cuando_turn_resource_cambia() {
    let mut session = checkers_game::new_checkers_session(SessionId(1), 42, P1, P2);
    let count = std::sync::Arc::new(std::sync::atomic::AtomicU32::new(0));
    let count_clone = count.clone();

    session.watch::<TurnResource>(move |_res| {
        count_clone.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    });

    let cmd = Box::new(checkers_game::MovePieceCommand {
        player: P1,
        from: checkers_game::Position::new(2, 1),
        to: checkers_game::Position::new(3, 2),
    });

    session.process_command(P1, cmd).unwrap();

    assert_eq!(count.load(std::sync::atomic::Ordering::SeqCst), 1);
}

