use checkers_game::{checkers_ai_pick_move, new_checkers_session, MovePieceCommand, Position};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1); // arriba, avanza filas crecientes
const P2: PlayerId = PlayerId(2); // abajo, avanza filas decrecientes

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

fn move_cmd(player: PlayerId, from: Position, to: Position) -> Box<dyn Command> {
    Box::new(MovePieceCommand { player, from, to })
}

#[test]
fn test_get_legal_moves_devuelve_solo_movimientos_validos() {
    let session = new_checkers_session(SessionId(1), 42, P1, P2);
    let legal_moves = session.get_legal_moves(P1);
    assert_eq!(
        legal_moves.len(),
        7,
        "En la posición inicial, P1 debe tener exactamente 7 movimientos válidos"
    );
}

#[test]
fn test_undo_revierte_el_estado_al_tick_anterior() {
    let mut session = new_checkers_session(SessionId(100), 1, P1, P2);

    // Movimiento 1 (P1)
    session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 2)))
        .expect("movimiento 1 válido");

    // Movimiento 2 (P2)
    session
        .process_command(P2, move_cmd(P2, pos(5, 6), pos(4, 7)))
        .expect("movimiento 2 válido");

    // Movimiento 3 (P1)
    session
        .process_command(P1, move_cmd(P1, pos(2, 3), pos(3, 4)))
        .expect("movimiento 3 válido");

    assert_eq!(session.current_tick(), Tick(3));

    session.undo_last_command().expect("undo exitoso");

    assert_eq!(session.current_tick(), Tick(2));
}
#[test]
fn el_tablero_inicial_tiene_12_fichas_por_jugador() {
    let session = new_checkers_session(SessionId(1), 1, P1, P2);
    let mut count_p1 = 0;
    let mut count_p2 = 0;
    for row in 0..8u8 {
        for col in 0..8u8 {
            if let Some(piece) = session
                .world()
                .resource::<checkers_game::BoardResource>()
                .get(pos(row, col))
            {
                if piece.owner == P1 {
                    count_p1 += 1;
                } else {
                    count_p2 += 1;
                }
                assert!(!piece.is_king, "nadie empieza siendo dama");
            }
        }
    }
    assert_eq!(count_p1, 12);
    assert_eq!(count_p2, 12);
}

#[test]
fn un_movimiento_simple_hacia_adelante_es_valido() {
    let mut session = new_checkers_session(SessionId(2), 1, P1, P2);

    // P1 (arriba) mueve una ficha de la fila 2 a la fila 3 (avanza).
    let events = session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 2)))
        .expect("el movimiento debería ser válido");

    assert_eq!(events.len(), 1);
    let moved = events[0]
        .as_any()
        .downcast_ref::<checkers_game::PieceMovedEvent>()
        .unwrap();
    assert_eq!(moved.from, pos(2, 1));
    assert_eq!(moved.to, pos(3, 2));
    assert!(moved.captured.is_none());
    assert!(!moved.promoted);

    assert_eq!(
        session.current_player(),
        P2,
        "el turno pasa al otro jugador"
    );
}

#[test]
fn no_se_puede_mover_fuera_de_turno() {
    let mut session = new_checkers_session(SessionId(3), 1, P1, P2);

    // Le toca a P1, pero P2 intenta mover.
    let result = session.process_command(P2, move_cmd(P2, pos(5, 0), pos(4, 1)));
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn no_se_puede_mover_hacia_atras_sin_ser_dama() {
    let mut session = new_checkers_session(SessionId(4), 1, P1, P2);

    // P1 intenta mover "hacia atrás" (fila menor), inválido sin ser dama.
    // Primero movemos una ficha a la fila 3 para tener algo con margen.
    session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 2)))
        .unwrap();
    session
        .process_command(P2, move_cmd(P2, pos(5, 0), pos(4, 1)))
        .unwrap();

    let result = session.process_command(P1, move_cmd(P1, pos(3, 2), pos(2, 1)));
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn una_captura_remueve_la_ficha_saltada() {
    let mut session = new_checkers_session(SessionId(5), 1, P1, P2);

    // Set up capture scenario directly: P1 at (3,4), P2 at (4,3), P1 jumps to (5,2)
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for row in 0..8u8 {
            for col in 0..8u8 {
                board.set(pos(row, col), None);
            }
        }
        board.set(
            pos(3, 4),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(4, 3),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }

    let events = session
        .process_command(P1, move_cmd(P1, pos(3, 4), pos(5, 2)))
        .expect("la captura debería ser válida");

    let moved = events[0]
        .as_any()
        .downcast_ref::<checkers_game::PieceMovedEvent>()
        .unwrap();
    assert_eq!(moved.captured, Some(pos(4, 3)));

    let board = session.world().resource::<checkers_game::BoardResource>();
    assert!(
        board.get(pos(4, 3)).is_none(),
        "la ficha capturada debe desaparecer del tablero"
    );
    assert!(
        board.get(pos(5, 2)).is_some(),
        "la ficha que capturó debe estar en el destino"
    );
}

#[test]
fn una_ficha_se_corona_al_llegar_a_la_ultima_fila() {
    // Seed y set up ad-hoc: en vez de jugar toda la partida para llegar
    // hasta el fondo, insertamos directamente una ficha cerca del borde
    // para probar la coronación de forma aislada.
    let mut session = new_checkers_session(SessionId(6), 1, P1, P2);
    force_turn!(session, P1);
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        board.set(pos(0, 1), None); // limpiar el tablero inicial en el camino
        board.set(
            pos(6, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(pos(7, 0), None);
        board.set(pos(7, 2), None);
    }

    let events = session
        .process_command(P1, move_cmd(P1, pos(6, 1), pos(7, 0)))
        .expect("mover a la última fila debería coronar");

    let moved = events[0]
        .as_any()
        .downcast_ref::<checkers_game::PieceMovedEvent>()
        .unwrap();
    assert!(moved.promoted, "debería coronarse al llegar a la fila 7");

    let board = session.world().resource::<checkers_game::BoardResource>();
    assert!(board.get(pos(7, 0)).unwrap().is_king);
}

#[test]
fn el_juego_termina_cuando_un_jugador_pierde_todas_sus_fichas() {
    let mut session = new_checkers_session(SessionId(7), 1, P1, P2);

    // Vaciamos el tablero y armamos una posición mínima: una ficha de P1
    // lista para capturar la única ficha que le dejamos a P2. Así el
    // juego termina en un solo movimiento, sin depender de una secuencia
    // larga de jugadas intermedias.
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for row in 0..8u8 {
            for col in 0..8u8 {
                board.set(pos(row, col), None);
            }
        }
        board.set(
            pos(2, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 2),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        // (4,3) queda vacía: ahí aterriza P1 tras la captura.
    }

    let events = session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(4, 3)))
        .expect("la captura final debería ser válida");

    let moved = events[0]
        .as_any()
        .downcast_ref::<checkers_game::PieceMovedEvent>()
        .unwrap();
    assert_eq!(moved.captured, Some(pos(3, 2)));

    assert!(
        events.iter().any(|e| e
            .as_any()
            .downcast_ref::<checkers_game::GameOverEvent>()
            .map(|go| go.winner)
            == Some(P1)),
        "debería haber un GameOverEvent con P1 como ganador"
    );
}

#[test]
fn captura_obligatoria_rechaza_movimientos_simples_si_hay_captura() {
    let mut session = new_checkers_session(SessionId(8), 1, P1, P2);

    // P1 en (2, 1) y P2 en (3, 2). P1 puede capturar a P2 en (4, 3).
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        board.set(
            pos(2, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 2),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(pos(4, 3), None);
    }

    // P1 intenta un movimiento simple (2, 3) -> (3, 4).
    let result = session.process_command(P1, move_cmd(P1, pos(2, 3), pos(3, 4)));
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "debería rechazar movimiento simple cuando hay captura disponible"
    );

    // En cambio, capturar (2, 1) -> (4, 3) sí es aceptado.
    session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(4, 3)))
        .expect("la captura obligatoria debe ser válida");
}

#[test]
fn captura_multiple_mantiene_el_turno_y_obliga_a_usar_la_misma_ficha() {
    let mut session = new_checkers_session(SessionId(9), 1, P1, P2);

    // P1 en (0, 1), P2 en (1, 2) y (3, 4).
    // P1 salta (0, 1) -> (2, 3) capturando (1, 2), y luego desde (2, 3) debe saltar a (4, 5) capturando (3, 4).
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(2, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(1, 2),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 4),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }

    // Primer salto
    session
        .process_command(P1, move_cmd(P1, pos(0, 1), pos(2, 3)))
        .expect("primer salto de captura múltiple válido");

    // Sigue siendo el turno de P1
    assert_eq!(session.current_player(), P1);

    // Intentar mover otra ficha de P1 debe ser rechazado
    let result = session.process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 2)));
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));

    // Completar el segundo salto con la misma ficha
    session
        .process_command(P1, move_cmd(P1, pos(2, 3), pos(4, 5)))
        .expect("segundo salto válido");

    // Ahora la captura múltiple terminó y le toca a P2
    assert_eq!(session.current_player(), P2);
}

#[test]
fn captura_triple_mantiene_el_turno_durante_tres_saltos() {
    let mut session = new_checkers_session(SessionId(10), 1, P1, P2);

    // P1 en (0, 1), P2 en (1, 2), (3, 4) y (5, 6).
    // P1 salta (0, 1) -> (2, 3) -> (4, 5) -> (6, 7), realizando 3 capturas consecutivas.
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(2, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(1, 2),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 4),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(5, 6),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }

    // Primer salto
    session
        .process_command(P1, move_cmd(P1, pos(0, 1), pos(2, 3)))
        .expect("primer salto válido");
    assert_eq!(
        session.current_player(),
        P1,
        "mantiene el turno de P1 tras el primer salto"
    );

    // Intentar mover otra ficha debe ser rechazado
    let err1 = session.process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 2)));
    assert!(matches!(err1, Err(EngineError::InvalidCommand { .. })));

    // Segundo salto
    session
        .process_command(P1, move_cmd(P1, pos(2, 3), pos(4, 5)))
        .expect("segundo salto válido");
    assert_eq!(
        session.current_player(),
        P1,
        "mantiene el turno de P1 tras el segundo salto"
    );

    // Intentar mover otra ficha debe seguir siendo rechazado
    let err2 = session.process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 2)));
    assert!(matches!(err2, Err(EngineError::InvalidCommand { .. })));

    // Tercer salto
    session
        .process_command(P1, move_cmd(P1, pos(4, 5), pos(6, 7)))
        .expect("tercer salto válido");

    // Cadena terminada, turno pasa a P2
    assert_eq!(
        session.current_player(),
        P2,
        "turno pasa a P2 tras completar la triple captura"
    );

    // Las tres fichas capturadas deben haber desaparecido
    let board = session.world().resource::<checkers_game::BoardResource>();
    assert!(board.get(pos(1, 2)).is_none());
    assert!(board.get(pos(3, 4)).is_none());
    assert!(board.get(pos(5, 6)).is_none());
    assert!(board.get(pos(6, 7)).is_some());
}

#[test]
fn persistencia_de_partida_save_and_load_from_file() {
    let mut session = new_checkers_session(SessionId(100), 42, P1, P2);

    // Movimiento 1 (P1): (2, 1) -> (3, 2)
    session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 2)))
        .expect("movimiento 1 válido");

    // Movimiento 2 (P2): (5, 6) -> (4, 7)
    session
        .process_command(P2, move_cmd(P2, pos(5, 6), pos(4, 7)))
        .expect("movimiento 2 válido");

    // Movimiento 3 (P1): (2, 3) -> (3, 4)
    session
        .process_command(P1, move_cmd(P1, pos(2, 3), pos(3, 4)))
        .expect("movimiento 3 válido");

    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("checkers_persisted_session.json");
    let path_str = file_path.to_str().expect("ruta temporal válida");

    // Guardar a archivo
    session
        .save_to_file(path_str)
        .expect("guardar en archivo debe ser exitoso");

    // Cargar desde archivo
    let reloaded = Session::load_from_file(
        SessionId(100),
        42,
        vec![P1, P2],
        checkers_game::build_checkers_rules(),
        path_str,
    )
    .expect("cargar desde archivo debe ser exitoso");

    // Verificar current_tick() y current_player()
    assert_eq!(reloaded.current_tick(), session.current_tick());
    assert_eq!(reloaded.current_player(), session.current_player());

    // Limpiar archivo de prueba
    let _ = std::fs::remove_file(file_path);
}

#[test]
fn test_captura_obligatoria_rechaza_movimiento_simple_si_hay_captura_disponible() {
    let mut session = new_checkers_session(SessionId(11), 1, P1, P2);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        board.set(
            pos(2, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 2),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(pos(4, 3), None);
        board.set(
            pos(2, 3),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
    }

    let result = session.process_command(P1, move_cmd(P1, pos(2, 3), pos(3, 4)));
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "debería rechazar el movimiento simple cuando hay captura disponible"
    );
}

#[test]
fn test_dama_puede_capturar_hacia_atras() {
    let mut session = new_checkers_session(SessionId(12), 1, P1, P2);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(5, 4),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: true,
            }),
        );
        board.set(
            pos(4, 3),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }

    let events = session
        .process_command(P1, move_cmd(P1, pos(5, 4), pos(3, 2)))
        .expect("la captura hacia atrás con dama debe ser válida");

    let moved = events[0]
        .as_any()
        .downcast_ref::<checkers_game::PieceMovedEvent>()
        .unwrap();
    assert_eq!(moved.from, pos(5, 4));
    assert_eq!(moved.to, pos(3, 2));
    assert_eq!(moved.captured, Some(pos(4, 3)));

    let board = session.world().resource::<checkers_game::BoardResource>();
    assert!(
        board.get(pos(4, 3)).is_none(),
        "la pieza capturada debe ser removida"
    );
    assert_eq!(board.get(pos(3, 2)).unwrap().owner, P1);
    assert!(board.get(pos(3, 2)).unwrap().is_king, "sigue siendo dama");
}

#[test]
fn test_cadena_de_tres_saltos_consecutivos() {
    let mut session = new_checkers_session(SessionId(99), 1, P1, P2);

    // P1 en (0, 1), tres fichas rivales P2 alineadas en diagonal para saltar: (1, 2), (3, 4) y (5, 6).
    // Salto 1: (0, 1) -> (2, 3) capturando (1, 2)
    // Salto 2: (2, 3) -> (4, 5) capturando (3, 4)
    // Salto 3: (4, 5) -> (6, 7) capturando (5, 6)
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(1, 2),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 4),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(5, 6),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }

    // Primer salto
    session
        .process_command(P1, move_cmd(P1, pos(0, 1), pos(2, 3)))
        .expect("primer salto válido");
    assert_eq!(
        session.current_player(),
        P1,
        "mantiene el turno de P1 tras el primer salto"
    );

    // Segundo salto (captura en cadena)
    session
        .process_command(P1, move_cmd(P1, pos(2, 3), pos(4, 5)))
        .expect("segundo salto válido");
    assert_eq!(
        session.current_player(),
        P1,
        "después del segundo salto el current_player() sigue siendo el mismo jugador"
    );

    // Tercer salto
    session
        .process_command(P1, move_cmd(P1, pos(4, 5), pos(6, 7)))
        .expect("tercer salto válido");
    assert_eq!(
        session.current_player(),
        P2,
        "solo cambia de turno a P2 tras agotar los saltos"
    );
}

#[test]
fn test_checkers_ai_captura_multiple_cuando_puede() {
    // Posición con captura doble disponible; la IA debe elegir una captura cuando hay captura disponible.
    let mut session = new_checkers_session(SessionId(1), 42, P1, P2);
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(1, 2),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 4),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }
    let mv = checkers_ai_pick_move(&session, P1);
    assert!(mv.is_some());
    let chosen = mv.unwrap();
    assert_eq!(chosen.from, pos(0, 1));
    assert_eq!(chosen.to, pos(2, 3));
}

#[test]
fn test_victoria_por_bloqueo_total_sin_movimientos_legales() {
    let mut session = new_checkers_session(SessionId(200), 1, P1, P2);

    // P2 tiene una ficha en (2, 7) (borde derecho, avanza hacia filas menores: solo podría ir a (1, 6)).
    // Si (0, 5) también está ocupada por P1, P2 tampoco puede saltar sobre (1, 6).
    // P1 mueve de (0, 7) a (1, 6), dejando a P2 con 1 ficha en el tablero pero 0 movimientos legales.
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 5),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(0, 7),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(2, 7),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }

    let events = session
        .process_command(P1, move_cmd(P1, pos(0, 7), pos(1, 6)))
        .expect("el movimiento de bloqueo debe ser válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<checkers_game::GameOverEvent>())
        .expect("debe emitirse GameOverEvent cuando el rival queda sin movimientos legales");

    assert_eq!(game_over.winner, P1);
    assert!(!game_over.is_draw);
    assert_eq!(
        session.world().resource::<GameOverResource>(),
        &GameOverResource(true)
    );
    assert_eq!(
        session.world().resource::<WinnerResource>(),
        &WinnerResource(Some(P1))
    );
}

#[test]
fn test_tablas_por_40_movimientos_sin_captura_ni_coronacion() {
    let mut session = new_checkers_session(SessionId(201), 1, P1, P2);

    // Dos damas lejos entre sí moviéndose sin capturas durante 80 medios turnos (40 movimientos por lado).
    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 1),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: true,
            }),
        );
        board.set(
            pos(7, 6),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: true,
            }),
        );
    }

    for i in 0..40 {
        let (p1_from, p1_to) = if i % 2 == 0 {
            (pos(0, 1), pos(1, 0))
        } else {
            (pos(1, 0), pos(0, 1))
        };
        let ev1 = session
            .process_command(P1, move_cmd(P1, p1_from, p1_to))
            .expect("movimiento de dama P1 válido");
        assert!(
            ev1.iter().all(|e| e
                .as_any()
                .downcast_ref::<checkers_game::GameOverEvent>()
                .is_none()),
            "no debe terminar antes del medio turno 80"
        );

        let (p2_from, p2_to) = if i % 2 == 0 {
            (pos(7, 6), pos(6, 7))
        } else {
            (pos(6, 7), pos(7, 6))
        };
        let ev2 = session
            .process_command(P2, move_cmd(P2, p2_from, p2_to))
            .expect("movimiento de dama P2 válido");

        if i < 39 {
            assert!(
                ev2.iter().all(|e| e
                    .as_any()
                    .downcast_ref::<checkers_game::GameOverEvent>()
                    .is_none()),
                "no debe terminar antes del medio turno 80"
            );
        } else {
            let go = ev2
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<checkers_game::GameOverEvent>())
                .expect("al llegar a 80 medios turnos debe emitirse GameOverEvent de tablas");
            assert!(go.is_draw);
        }
    }

    assert_eq!(
        session
            .world()
            .resource::<checkers_game::DrawClockResource>()
            .half_moves_without_capture_or_promotion,
        80
    );
    assert_eq!(
        session.world().resource::<GameOverResource>(),
        &GameOverResource(true)
    );
    assert_eq!(
        session.world().resource::<WinnerResource>(),
        &WinnerResource(None)
    );
}

#[test]
fn test_draw_clock_se_reinicia_en_captura_o_coronacion() {
    let mut session = new_checkers_session(SessionId(202), 1, P1, P2);

    // Pre-cargar DrawClockResource en 50 medios turnos y ejecutar una captura
    session
        .world_mut()
        .insert_resource(checkers_game::DrawClockResource {
            half_moves_without_capture_or_promotion: 50,
        });

    {
        let mut board = session
            .world_mut()
            .resource_mut::<checkers_game::BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(3, 4),
            Some(checkers_game::Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(4, 3),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(7, 6),
            Some(checkers_game::Piece {
                owner: P2,
                is_king: true,
            }),
        );
    }

    session
        .process_command(P1, move_cmd(P1, pos(3, 4), pos(5, 2)))
        .expect("captura válida");

    assert_eq!(
        session
            .world()
            .resource::<checkers_game::DrawClockResource>()
            .half_moves_without_capture_or_promotion,
        0,
        "el reloj de tablas debe reiniciarse a 0 tras una captura"
    );
}
