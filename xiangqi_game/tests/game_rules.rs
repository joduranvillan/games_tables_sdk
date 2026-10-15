use open_table_engine::prelude::*;
use xiangqi_game::{new_xiangqi_session, MovePieceCommand};

const RED: PlayerId = PlayerId(1);
const BLACK: PlayerId = PlayerId(2);

#[test]
fn test_move_and_capture() {
    let mut session = new_xiangqi_session(SessionId(1), 0, RED, BLACK);

    // RED moves soldier
    session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (4, 6),
                to: (4, 5),
            }),
        )
        .unwrap();
    // BLACK moves soldier
    session
        .process_command(
            BLACK,
            Box::new(MovePieceCommand {
                player: BLACK,
                from: (4, 3),
                to: (4, 4),
            }),
        )
        .unwrap();
    // RED captures
    session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (4, 5),
                to: (4, 4),
            }),
        )
        .unwrap();

    let board = session.world().resource::<xiangqi_game::BoardResource>();
    assert!(board.squares.contains_key(&(4, 4)));
    assert_eq!(board.squares.get(&(4, 4)).unwrap().owner, RED);
}

#[test]
fn flying_general_rechaza_movimiento_que_los_enfrenta() {
    let mut session = new_xiangqi_session(SessionId(2), 0, RED, BLACK);

    // Configurar el tablero con dos Generales en la columna 4 y solo un Soldado entre ellos.
    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
        // Soldado rojo en (4, 4) que ha cruzado el río y bloquea la línea de visión
        board.squares.insert(
            (4, 4),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Soldier,
                owner: RED,
            },
        );
    }

    // Intentar mover el soldado de (4, 4) a (3, 4), lo que dejaría la columna 4 vacía entre los Generales
    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (4, 4),
            to: (3, 4),
        }),
    );

    assert!(
        matches!(res, Err(EngineError::InvalidCommand { .. })),
        "El movimiento debe ser rechazado con EngineError::InvalidCommand debido a la regla de Flying General"
    );
}

#[test]
fn test_elefante_no_puede_cruzar_el_rio() {
    let mut session = new_xiangqi_session(SessionId(3), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Red Elephant at (2, 5) which is at the edge of the river on Red's side
        board.squares.insert(
            (2, 5),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Elephant,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
    }

    // Try moving the Elephant across the river to (4, 3) (valid diagonal move but crosses river)
    // Actually, Elephant moves diagonally by 2, so from (2, 5) it could go to (4, 3) or (0, 3) across the river
    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (2, 5),
            to: (4, 3),
        }),
    );

    assert!(
        matches!(res, Err(EngineError::InvalidCommand { .. })),
        "Un Elefante Red no puede moverse a las filas 0-4 (cruzar el río)"
    );
}

#[test]
fn test_ojo_del_elefante_bloqueado_invalida_movimiento() {
    let mut session = new_xiangqi_session(SessionId(4), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Red Elephant at (2, 9)
        board.squares.insert(
            (2, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Elephant,
                owner: RED,
            },
        );
        // Blocking piece at (3, 8)
        board.squares.insert(
            (3, 8),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Soldier,
                owner: BLACK,
            },
        );
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
    }

    // Attempt to move elephant from (2, 9) to (4, 7). The eye is (3, 8).
    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (2, 9),
            to: (4, 7),
        }),
    );

    assert!(
        matches!(
            res,
            Err(open_table_engine::prelude::EngineError::InvalidCommand { .. })
        ),
        "El movimiento debe ser rechazado por el ojo del Elefante bloqueado"
    );
}

#[test]
fn test_pata_de_caballo_bloqueada_invalida_movimiento() {
    let mut session = new_xiangqi_session(SessionId(5), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Red Horse at (1, 9)
        board.squares.insert(
            (1, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Horse,
                owner: RED,
            },
        );
        // Blocking piece at (1, 8) - this blocks the orthogonal step if the Horse moves to (2, 7) or (0, 7)
        board.squares.insert(
            (1, 8),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Soldier,
                owner: BLACK,
            },
        );
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
    }

    // Attempt to move horse from (1, 9) to (2, 7). The leg is blocked at (1, 8).
    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (1, 9),
            to: (2, 7),
        }),
    );

    assert!(
        matches!(
            res,
            Err(open_table_engine::prelude::EngineError::InvalidCommand { .. })
        ),
        "El movimiento debe ser rechazado por la pata del Caballo bloqueada"
    );
}

#[test]
fn test_canon_movimiento_simple_bloqueado_por_pieza_interpuesta() {
    let mut session = new_xiangqi_session(SessionId(6), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Red Cannon at (1, 7)
        board.squares.insert(
            (1, 7),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Cannon,
                owner: RED,
            },
        );
        // Blocking piece at (4, 7)
        board.squares.insert(
            (4, 7),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Soldier,
                owner: BLACK,
            },
        );
        // Kings
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
    }

    // Attempt to move cannon from (1, 7) to (7, 7). There is no capture, but (4, 7) is blocking.
    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (1, 7),
            to: (7, 7),
        }),
    );

    assert!(
        matches!(
            res,
            Err(open_table_engine::prelude::EngineError::InvalidCommand { .. })
        ),
        "El movimiento debe ser rechazado porque el Cañón sin captura no puede saltar"
    );
}

#[test]
fn test_canon_captura_valida_con_una_plataforma() {
    let mut session = new_xiangqi_session(SessionId(7), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Red Cannon at (1, 7)
        board.squares.insert(
            (1, 7),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Cannon,
                owner: RED,
            },
        );
        // Platform piece at (4, 7)
        board.squares.insert(
            (4, 7),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Soldier,
                owner: RED,
            },
        );
        // Target enemy piece at (7, 7)
        board.squares.insert(
            (7, 7),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Soldier,
                owner: BLACK,
            },
        );
        // Kings
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
    }

    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (1, 7),
            to: (7, 7),
        }),
    );

    assert!(
        res.is_ok(),
        "La captura del Cañón con una plataforma intermedia debe ser válida"
    );

    let board = session.world().resource::<xiangqi_game::BoardResource>();
    assert!(board.squares.contains_key(&(7, 7)));
    assert_eq!(board.squares.get(&(7, 7)).unwrap().owner, RED);
    assert_eq!(
        board.squares.get(&(7, 7)).unwrap().kind,
        xiangqi_game::PieceKind::Cannon
    );
}

#[test]
fn test_canon_captura_invalida_sin_plataforma() {
    let mut session = new_xiangqi_session(SessionId(8), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Red Cannon at (1, 7)
        board.squares.insert(
            (1, 7),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Cannon,
                owner: RED,
            },
        );
        // Target enemy piece at (7, 7), with NO intermediate piece between (1, 7) and (7, 7)
        board.squares.insert(
            (7, 7),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Soldier,
                owner: BLACK,
            },
        );
        // Kings
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
    }

    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (1, 7),
            to: (7, 7),
        }),
    );

    assert!(
        matches!(res, Err(EngineError::InvalidCommand { .. })),
        "La captura del Cañón sin plataforma debe ser rechazada"
    );
}

#[test]
fn test_guardia_no_puede_salir_del_palacio() {
    let mut session = new_xiangqi_session(SessionId(9), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Red Advisor/Guard at (4, 8) inside palace
        board.squares.insert(
            (4, 8),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Advisor,
                owner: RED,
            },
        );
        // Kings
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
    }

    // Try moving Red Advisor orthogonally from (4, 8) to (5, 8)
    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (4, 8),
            to: (5, 8),
        }),
    );

    assert!(
        matches!(res, Err(EngineError::InvalidCommand { .. })),
        "El movimiento ortogonal o fuera del palacio del Guardia debe ser rechazado"
    );
}

#[test]
fn test_jaque_mate_termina_la_partida_en_xiangqi() {
    let mut session = new_xiangqi_session(SessionId(10), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Black General at (3, 0) in palace corner
        board.squares.insert(
            (3, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
        // Red General at (4, 9)
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );

        // Red Chariots setup
        board.squares.insert(
            (0, 1),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Chariot,
                owner: RED,
            },
        );
        board.squares.insert(
            (3, 5),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Chariot,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 5),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Chariot,
                owner: RED,
            },
        );
    }

    // Red moves Chariot from (0, 1) to (3, 1), checking Black General at (3, 0)
    let res = session.process_command(
        RED,
        Box::new(MovePieceCommand {
            player: RED,
            from: (0, 1),
            to: (3, 1),
        }),
    );

    assert!(res.is_ok(), "El movimiento de mate debe ser válido");

    let events = res.unwrap();
    let is_game_over = events.iter().any(|e| {
        if let Some(game_over) = e.as_any().downcast_ref::<xiangqi_game::GameOverEvent>() {
            game_over.winner == Some(RED)
        } else {
            false
        }
    });

    assert!(
        is_game_over,
        "El evento GameOverEvent debe ser emitido con Red como ganador"
    );
}

#[test]
fn test_kunbi_ahogado_sin_jaque_otorga_victoria_en_xiangqi() {
    let mut session = new_xiangqi_session(SessionId(11), 0, RED, BLACK);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<xiangqi_game::BoardResource>();
        board.squares.clear();

        // Black General en (3, 0); no tiene más piezas
        board.squares.insert(
            (3, 0),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: BLACK,
            },
        );
        // Red General en (4, 9) controla la columna 4 por regla de General Volador
        board.squares.insert(
            (4, 9),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::General,
                owner: RED,
            },
        );
        // Red Chariot en (0, 5), listo para bajar a (0, 1) y cortar la fila 1 sin dar jaque
        board.squares.insert(
            (0, 5),
            xiangqi_game::Piece {
                kind: xiangqi_game::PieceKind::Chariot,
                owner: RED,
            },
        );
    }

    // Red mueve Chariot de (0, 5) a (0, 1): Black General en (3, 0) NO está en jaque,
    // pero no puede ir a (4, 0) (Flying General) ni a (3, 1) (controlado por Chariot en (0, 1)).
    let events = session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (0, 5),
                to: (0, 1),
            }),
        )
        .expect("El movimiento de bloqueo Kunbi debe ser válido");

    {
        let board = session.world().resource::<xiangqi_game::BoardResource>();
        assert!(
            !xiangqi_game::is_in_check(board, BLACK),
            "El General negro no está en jaque (es ahogado / Kunbi)"
        );
    }
    assert!(
        xiangqi_game::all_legal_moves_for(session.world(), BLACK).is_empty(),
        "Black no debe tener movimientos legales disponibles"
    );

    let is_red_winner = events.iter().any(|e| {
        if let Some(game_over) = e.as_any().downcast_ref::<xiangqi_game::GameOverEvent>() {
            game_over.winner == Some(RED)
        } else {
            false
        }
    });
    assert!(
        is_red_winner,
        "En Xiangqi el ahogado (Kunbi) debe otorgar la victoria inmediata a RED"
    );
    assert_eq!(
        session.world().resource::<GameOverResource>().0,
        true,
        "GameOverResource debe ser true tras Kunbi"
    );
    assert_eq!(
        session.world().resource::<WinnerResource>().0,
        Some(RED),
        "WinnerResource debe ser Some(RED) tras Kunbi"
    );
}

#[test]
fn test_triple_repeticion_xiangqi_declara_tablas() {
    let mut session = new_xiangqi_session(SessionId(12), 0, RED, BLACK);

    // Ciclo 1 -> 2da aparición de la posición inicial
    session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (4, 9),
                to: (3, 9),
            }),
        )
        .unwrap();
    session
        .process_command(
            BLACK,
            Box::new(MovePieceCommand {
                player: BLACK,
                from: (4, 0),
                to: (3, 0),
            }),
        )
        .unwrap();
    session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (3, 9),
                to: (4, 9),
            }),
        )
        .unwrap();
    let events_second = session
        .process_command(
            BLACK,
            Box::new(MovePieceCommand {
                player: BLACK,
                from: (3, 0),
                to: (4, 0),
            }),
        )
        .unwrap();
    assert!(
        !events_second
            .iter()
            .any(|e| e.as_any().is::<xiangqi_game::GameOverEvent>()),
        "Con 2 repeticiones aún no debe declararse tablas"
    );

    // Ciclo 2 -> 3ra aparición de la posición inicial
    session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (4, 9),
                to: (3, 9),
            }),
        )
        .unwrap();
    session
        .process_command(
            BLACK,
            Box::new(MovePieceCommand {
                player: BLACK,
                from: (4, 0),
                to: (3, 0),
            }),
        )
        .unwrap();
    session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (3, 9),
                to: (4, 9),
            }),
        )
        .unwrap();
    let events_third = session
        .process_command(
            BLACK,
            Box::new(MovePieceCommand {
                player: BLACK,
                from: (3, 0),
                to: (4, 0),
            }),
        )
        .unwrap();

    let is_draw = events_third.iter().any(|e| {
        if let Some(go) = e.as_any().downcast_ref::<xiangqi_game::GameOverEvent>() {
            go.winner.is_none()
        } else {
            false
        }
    });
    assert!(
        is_draw,
        "Al repetirse 3 veces la misma posición debe emitirse GameOverEvent con winner: None"
    );
    assert!(session.world().resource::<GameOverResource>().0);
    assert_eq!(session.world().resource::<WinnerResource>().0, None);
}

#[test]
fn test_xiangqi_legal_move_generator_registrado() {
    let session = new_xiangqi_session(SessionId(13), 0, RED, BLACK);
    let rules = xiangqi_game::build_xiangqi_rules();

    let red_moves = rules.legal_moves(session.world(), RED);
    assert!(
        !red_moves.is_empty(),
        "XiangqiLegalMoveGenerator debe generar movimientos legales para RED en su turno"
    );

    let black_moves = rules.legal_moves(session.world(), BLACK);
    assert!(
        black_moves.is_empty(),
        "XiangqiLegalMoveGenerator no debe generar movimientos para BLACK fuera de su turno"
    );
}

