// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use go_game::{
    go_ai_pick_move, new_go_session, BoardResource, ConfirmDeadCommand, GameOverEvent,
    MarkDeadCommand, PassCommand, PlaceHandicapCommand, PlaceStoneCommand, Stone,
    StonesCapturedEvent,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn test_place_stone_and_capture() {
    let mut session = new_go_session(SessionId(1), 0, P1, P2);

    // P1 places at 1,0
    session
        .process_command(
            P1,
            Box::new(PlaceStoneCommand {
                player: P1,
                x: 1,
                y: 0,
            }),
        )
        .unwrap();
    // P2 places at 0,0
    session
        .process_command(
            P2,
            Box::new(PlaceStoneCommand {
                player: P2,
                x: 0,
                y: 0,
            }),
        )
        .unwrap();
    // P1 places at 0,1, capturing P2 at 0,0
    let events = session
        .process_command(
            P1,
            Box::new(PlaceStoneCommand {
                player: P1,
                x: 0,
                y: 1,
            }),
        )
        .unwrap();

    assert!(events
        .iter()
        .any(|e| e.as_any().is::<StonesCapturedEvent>()));
    let capture_event = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<StonesCapturedEvent>())
        .unwrap();
    assert_eq!(capture_event.count, 1);
}

#[test]
fn test_pass_ends_game() {
    let mut session = new_go_session(SessionId(2), 0, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.set_stone(1, 0, Some(Stone::Black));
        board.set_stone(0, 1, Some(Stone::Black));
    }

    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();
    session
        .process_command(P2, Box::new(PassCommand { player: P2 }))
        .unwrap();

    session
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(ConfirmDeadCommand { player: P2 }))
        .unwrap();

    assert!(events.iter().any(|e| e.as_any().is::<GameOverEvent>()));
    let game_over_event = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .unwrap();
    assert_eq!(game_over_event.winner, Some(P1));
}

#[test]
fn test_suicidio_es_rechazado() {
    let mut session = new_go_session(SessionId(3), 0, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        // Surround (0,0) with P2 (White) stones
        board.set_stone(1, 0, Some(Stone::White));
        board.set_stone(0, 1, Some(Stone::White));
    }

    // P1 (Black) tries to place at (0,0) which would have 0 liberties and capture no stones
    let res = session.process_command(
        P1,
        Box::new(PlaceStoneCommand {
            player: P1,
            x: 0,
            y: 0,
        }),
    );

    assert!(
        res.is_err(),
        "Colocar una piedra sin libertades (suicidio) debe ser rechazado"
    );
}

#[test]
fn test_captura_de_grupo_de_tres_piedras() {
    let mut session = new_go_session(SessionId(4), 0, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        // Place 3 connected Black (P1) stones
        board.set_stone(1, 1, Some(Stone::Black));
        board.set_stone(1, 2, Some(Stone::Black));
        board.set_stone(1, 3, Some(Stone::Black));

        // Surround with White (P2) stones, leaving (1, 4) as the last liberty
        board.set_stone(0, 1, Some(Stone::White));
        board.set_stone(2, 1, Some(Stone::White));
        board.set_stone(1, 0, Some(Stone::White));
        board.set_stone(0, 2, Some(Stone::White));
        board.set_stone(2, 2, Some(Stone::White));
        board.set_stone(0, 3, Some(Stone::White));
        board.set_stone(2, 3, Some(Stone::White));
    }

    // P1 passes turn to P2
    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();

    // P2 places stone at (1, 4), closing the last liberty of the 3 Black stones
    let events = session
        .process_command(
            P2,
            Box::new(PlaceStoneCommand {
                player: P2,
                x: 1,
                y: 4,
            }),
        )
        .unwrap();

    // Verify StonesCapturedEvent count is 3
    let capture_event = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<StonesCapturedEvent>())
        .expect("Debe emitirse un StonesCapturedEvent");
    assert_eq!(
        capture_event.count, 3,
        "El conteo de piedras capturadas debe ser 3"
    );
    assert_eq!(capture_event.player, P2);

    // Verify the board has no stones at (1,1), (1,2), (1,3)
    let board = session.world().resource::<BoardResource>();
    assert_eq!(
        board.get_stone(1, 1),
        None,
        "(1,1) debe estar libre tras la captura"
    );
    assert_eq!(
        board.get_stone(1, 2),
        None,
        "(1,2) debe estar libre tras la captura"
    );
    assert_eq!(
        board.get_stone(1, 3),
        None,
        "(1,3) debe estar libre tras la captura"
    );
}

#[test]
fn test_superko_previene_repeticion_de_posicion() {
    let mut session = new_go_session(SessionId(5), 0, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        // Set up Ko shape:
        // Black (P1) stones
        board.set_stone(1, 1, Some(Stone::Black));
        board.set_stone(0, 2, Some(Stone::Black));
        board.set_stone(2, 2, Some(Stone::Black));
        board.set_stone(1, 3, Some(Stone::Black));

        // White (P2) stones
        board.set_stone(0, 1, Some(Stone::White));
        board.set_stone(2, 1, Some(Stone::White));
        board.set_stone(1, 0, Some(Stone::White));
    }

    // P1 passes turn to P2
    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();

    // P2 plays at (1,2), capturing Black stone at (1,1)
    session
        .process_command(
            P2,
            Box::new(PlaceStoneCommand {
                player: P2,
                x: 1,
                y: 2,
            }),
        )
        .unwrap();

    // P1 tries to play at (1,1), which would capture White stone at (1,2)
    // and recreate the exact previous board position (S0)
    let res = session.process_command(
        P1,
        Box::new(PlaceStoneCommand {
            player: P1,
            x: 1,
            y: 1,
        }),
    );

    assert!(
        res.is_err(),
        "Superko debe prohibir volver a una posición de tablero previa"
    );
}

#[test]
fn test_handicap_de_cuatro_piedras_se_coloca_correctamente() {
    let mut session = new_go_session(SessionId(6), 0, P1, P2);

    let positions = vec![(3, 2), (5, 2), (3, 6), (5, 6)];
    session
        .process_command(
            P1,
            Box::new(PlaceHandicapCommand {
                player: P1,
                positions: positions.clone(),
            }),
        )
        .unwrap();

    let board = session.world().resource::<BoardResource>();
    for &(x, y) in &positions {
        assert_eq!(
            board.get_stone(x as usize, y as usize),
            Some(Stone::Black),
            "Piedra de hándicap en ({}, {}) debe estar presente",
            x,
            y
        );
    }

    assert_eq!(
        session.current_player(),
        P2,
        "Después de colocar hándicap debe ser el turno de White (P2)"
    );
}

#[test]
fn test_marcado_y_confirmacion_de_muertas() {
    let mut session = new_go_session(SessionId(7), 0, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.set_stone(1, 0, Some(Stone::Black));
        board.set_stone(0, 1, Some(Stone::Black));
        // Place a dead White stone surrounded or in Black's area
        board.set_stone(0, 0, Some(Stone::White));
    }

    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();
    session
        .process_command(P2, Box::new(PassCommand { player: P2 }))
        .unwrap();

    // Mark White stone at (0, 0) as dead
    session
        .process_command(
            P1,
            Box::new(MarkDeadCommand {
                player: P1,
                positions: vec![(0, 0)],
            }),
        )
        .unwrap();

    session
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(ConfirmDeadCommand { player: P2 }))
        .unwrap();

    let game_over_event = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("Debe emitirse un GameOverEvent");

    assert_eq!(game_over_event.winner, Some(P1));

    let board = session.world().resource::<BoardResource>();
    assert_eq!(
        board.get_stone(0, 0),
        None,
        "(0,0) debe quedar libre tras ser eliminada la piedra muerta"
    );
}

#[test]
fn go_partida_completa_hasta_scoring_de_territorio() {
    let mut session = new_go_session(SessionId(100), 0, P1, P2);

    // Configurar un tablero 9x9 con clara ventaja de territorio para P1 (Black)
    // P1 (Black) encierra el lado izquierdo (columnas 0 a 4) colocando piedras en la columna 5 (y: 0..9)
    // P2 (White) encierra la columna 8 colocando piedras en la columna 7 (y: 0..9)
    // Además colocar una piedra muerta de White en (1, 1) dentro del territorio de Black.
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        for y in 0..9 {
            board.set_stone(5, y, Some(Stone::Black));
            board.set_stone(7, y, Some(Stone::White));
        }
        // Piedra muerta de P2 dentro del territorio de P1
        board.set_stone(1, 1, Some(Stone::White));
    }

    // Doble pass para iniciar la fase de marcaje de muertas
    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();
    session
        .process_command(P2, Box::new(PassCommand { player: P2 }))
        .unwrap();

    // Marcar la piedra muerta en (1, 1)
    session
        .process_command(
            P1,
            Box::new(MarkDeadCommand {
                player: P1,
                positions: vec![(1, 1)],
            }),
        )
        .unwrap();

    // Confirmación de ambos jugadores
    session
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(ConfirmDeadCommand { player: P2 }))
        .unwrap();

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("Debe emitirse GameOverEvent al confirmar las piedras muertas");

    // P1 (Black) tiene mayor territorio (5x9 = 45 vs 1x9 = 9)
    assert_eq!(
        game_over.winner,
        Some(P1),
        "GameOverEvent.winner debe ser P1 por tener el mayor territorio"
    );
}

#[test]
fn test_pasar_fuera_de_turno_es_rechazado() {
    let mut session = new_go_session(SessionId(101), 0, P1, P2);
    let result = session.process_command(P2, Box::new(PassCommand { player: P2 }));
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "pasar fuera de turno debe ser rechazado"
    );
}

#[test]
fn test_go_ai_devuelve_movimiento_o_none_en_posicion_inicial() {
    let start = std::time::Instant::now();
    let session = new_go_session(SessionId(200), 42, P1, P2);

    let mv = go_ai_pick_move(&session, P1);
    let elapsed = start.elapsed();

    assert!(
        mv.is_some(),
        "La IA de Go debe devolver un movimiento en posición inicial"
    );
    let chosen = mv.unwrap();
    assert!(chosen.x < 9 && chosen.y < 9);
    assert_eq!(chosen.player, P1);
    // En debug mode con bevy_ecs 0.19 (recursos como entidades) el overhead es mayor.
    // 10s detecta loops infinitos sin fallos espurios.
    assert!(
        elapsed.as_secs_f32() < 10.0,
        "La ejecución de la IA debe tardar menos de 10s en 9x9, tardó {:?}",
        elapsed
    );
}

#[test]
fn test_prisioneros_se_acumulan_en_captura_y_piedras_muertas() {
    let mut session = new_go_session(SessionId(301), 0, P1, P2);

    // P1 (Black) juega en (1, 0), P2 (White) en (0, 0), P1 en (0, 1) capturando la piedra blanca en (0, 0)
    session
        .process_command(
            P1,
            Box::new(PlaceStoneCommand {
                player: P1,
                x: 1,
                y: 0,
            }),
        )
        .unwrap();
    session
        .process_command(
            P2,
            Box::new(PlaceStoneCommand {
                player: P2,
                x: 0,
                y: 0,
            }),
        )
        .unwrap();
    session
        .process_command(
            P1,
            Box::new(PlaceStoneCommand {
                player: P1,
                x: 0,
                y: 1,
            }),
        )
        .unwrap();

    assert_eq!(
        session.world().resource::<BoardResource>().black_prisoners,
        1,
        "Negro debe acumular 1 prisionero tras capturar en (0, 0)"
    );

    // Colocar muros simétricos: columna 3 de Negro, columna 5 de Blanco, y una piedra blanca muerta en (1, 2)
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        for y in 0..9 {
            board.set_stone(3, y, Some(Stone::Black));
            board.set_stone(5, y, Some(Stone::White));
        }
        board.set_stone(1, 2, Some(Stone::White));
    }

    // Doble pase (turno actual es P2)
    session
        .process_command(P2, Box::new(PassCommand { player: P2 }))
        .unwrap();
    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();

    // Marcar la piedra blanca en (1, 2) como muerta
    session
        .process_command(
            P1,
            Box::new(MarkDeadCommand {
                player: P1,
                positions: vec![(1, 2)],
            }),
        )
        .unwrap();

    session
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(ConfirmDeadCommand { player: P2 }))
        .unwrap();

    let board = session.world().resource::<BoardResource>();
    assert_eq!(
        board.black_prisoners, 2,
        "Negro debe tener 2 prisioneros (1 capturado en juego + 1 piedra muerta removida)"
    );

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("Debe emitirse GameOverEvent");

    // Territorio Negro: 3x9 = 27 menos 2 piedras propias en (1,0) y (0,1) = 25 + 2 prisioneros = 27.0
    // Territorio Blanco: 3x9 = 27 + 0 prisioneros + 6.5 komi = 33.5
    assert!((game_over.black_score - 27.0).abs() < 1e-4);
    assert!((game_over.white_score - 33.5).abs() < 1e-4);
    assert_eq!(game_over.winner, Some(P2));
}

#[test]
fn test_komi_6_5_desempata_a_favor_de_blancas_y_configurable_con_set_komi() {
    let mut session = new_go_session(SessionId(302), 0, P1, P2);

    // Posición simétrica: Negro encierra columnas 0..2 (piedras en col 3), Blanco encierra columnas 6..8 (piedras en col 5)
    // Ambos tienen exactamente 27 puntos de territorio y 0 prisioneros.
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        for y in 0..9 {
            board.set_stone(3, y, Some(Stone::Black));
            board.set_stone(5, y, Some(Stone::White));
        }
    }

    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();
    session
        .process_command(P2, Box::new(PassCommand { player: P2 }))
        .unwrap();
    session
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(ConfirmDeadCommand { player: P2 }))
        .unwrap();

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("Debe emitirse GameOverEvent");

    assert_eq!(
        game_over.winner,
        Some(P2),
        "Con territorio igual (27 vs 27), Blancas debe ganar gracias al Komi de 6.5"
    );
    assert!((game_over.black_score - 27.0).abs() < 1e-4);
    assert!((game_over.white_score - 33.5).abs() < 1e-4);

    // Ahora probar SetKomiCommand con komi = 0 y 1 prisionero para Negro
    let mut session_no_komi = go_game::new_go_session_with_komi(SessionId(303), 0, P1, P2, 13);
    session_no_komi
        .process_command(
            P1,
            Box::new(go_game::SetKomiCommand {
                player: P1,
                komi_half_points: 0,
            }),
        )
        .unwrap();
    {
        let mut board = session_no_komi.world_mut().resource_mut::<BoardResource>();
        for y in 0..9 {
            board.set_stone(3, y, Some(Stone::Black));
            board.set_stone(5, y, Some(Stone::White));
        }
        board.black_prisoners = 1;
    }
    session_no_komi
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();
    session_no_komi
        .process_command(P2, Box::new(PassCommand { player: P2 }))
        .unwrap();
    session_no_komi
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .unwrap();
    let events2 = session_no_komi
        .process_command(P2, Box::new(ConfirmDeadCommand { player: P2 }))
        .unwrap();
    let game_over2 = events2
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .unwrap();
    assert_eq!(game_over2.winner, Some(P1));
    assert!((game_over2.black_score - 28.0).abs() < 1e-4);
    assert!((game_over2.white_score - 27.0).abs() < 1e-4);
}

#[test]
fn test_go_legal_move_generator_excluye_suicidio_y_ko_e_incluye_pass() {
    let mut session = new_go_session(SessionId(304), 0, P1, P2);

    // En tablero 9x9 vacío deben existir 81 jugadas PlaceStoneCommand + 1 PassCommand = 82
    let initial_moves = session.get_legal_moves(P1);
    assert_eq!(
        initial_moves.len(),
        82,
        "En tablero 9x9 vacío deben existir 81 intersecciones + PassCommand"
    );

    // Rodear (0, 0) con piedras blancas para que (0, 0) sea suicidio para Negro
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.set_stone(1, 0, Some(Stone::White));
        board.set_stone(0, 1, Some(Stone::White));
        board.ko_point = Some((4, 4));
    }

    let moves = session.get_legal_moves(P1);
    // 81 total - 2 ocupadas ((1,0) y (0,1)) - 1 suicidio ((0,0)) - 1 ko ((4,4)) + 1 PassCommand = 78
    assert_eq!(moves.len(), 78);
    let has_suicide_0_0 = moves.iter().any(|m| {
        m.get("x").and_then(|v| v.as_u64()) == Some(0)
            && m.get("y").and_then(|v| v.as_u64()) == Some(0)
    });
    assert!(
        !has_suicide_0_0,
        "GoLegalMoveGenerator no debe incluir la intersección suicida (0, 0)"
    );
    let has_ko_4_4 = moves.iter().any(|m| {
        m.get("x").and_then(|v| v.as_u64()) == Some(4)
            && m.get("y").and_then(|v| v.as_u64()) == Some(4)
    });
    assert!(
        !has_ko_4_4,
        "GoLegalMoveGenerator no debe incluir el punto de Ko (4, 4)"
    );
}
