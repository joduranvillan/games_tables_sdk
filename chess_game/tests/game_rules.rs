// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use chess_game::{
    chess_ai_pick_move, load_chess_position_from_fen, new_chess_session, AcceptDrawCommand,
    BoardResource, DrawOfferedResource, GameOverEvent, HalfMoveClockResource, MovePieceCommand,
    OfferDrawCommand, Piece, PieceKind, Position, ResignCommand,
};
use open_table_engine::prelude::*;

const WHITE: PlayerId = PlayerId(1);
const BLACK: PlayerId = PlayerId(2);

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

fn mv(
    session: &mut Session,
    player: PlayerId,
    from: Position,
    to: Position,
) -> Result<Vec<Box<dyn Event>>, EngineError> {
    session.process_command(
        player,
        Box::new(MovePieceCommand {
            player,
            from,
            to,
            promote_to: None,
        }),
    )
}

#[test]
fn test_legal_moves_posicion_inicial_tiene_20_jugadas() {
    let session = new_chess_session(SessionId(1), 1, WHITE, BLACK);
    let legal_moves = session.get_legal_moves(WHITE);
    assert_eq!(
        legal_moves.len(),
        20,
        "En la posición inicial, las blancas deben tener exactamente 20 movimientos legales"
    );
}

#[test]
fn el_setup_inicial_tiene_16_piezas_por_jugador() {
    let session = new_chess_session(SessionId(1), 1, WHITE, BLACK);
    let board = session.world().resource::<BoardResource>();
    let white_count = board.pieces.values().filter(|p| p.owner == WHITE).count();
    let black_count = board.pieces.values().filter(|p| p.owner == BLACK).count();
    assert_eq!(white_count, 16);
    assert_eq!(black_count, 16);
}

#[test]
fn un_peon_puede_avanzar_dos_casillas_en_su_primer_movimiento() {
    let mut session = new_chess_session(SessionId(2), 1, WHITE, BLACK);
    let events =
        mv(&mut session, WHITE, pos(1, 4), pos(3, 4)).expect("avance de 2 debería ser válido");
    assert_eq!(events.len(), 1);
    assert_eq!(session.current_player(), BLACK);
}

#[test]
fn un_movimiento_no_diagonal_ni_recto_de_alfil_es_rechazado() {
    let mut session = new_chess_session(SessionId(3), 1, WHITE, BLACK);
    // El alfil de (0,2) está bloqueado por su propio peón al inicio, y
    // aunque no lo estuviera, moverlo "en L" es inválido.
    let result = mv(&mut session, WHITE, pos(0, 2), pos(2, 3));
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn un_caballo_puede_saltar_piezas_en_su_primer_movimiento() {
    let mut session = new_chess_session(SessionId(4), 1, WHITE, BLACK);
    let events =
        mv(&mut session, WHITE, pos(0, 1), pos(2, 2)).expect("el caballo debería poder saltar");
    assert_eq!(events.len(), 1);
}

#[test]
fn capturar_una_pieza_rival_la_quita_del_tablero() {
    let mut session = new_chess_session(SessionId(5), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 4),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(3, 3),
            Piece {
                owner: WHITE,
                kind: PieceKind::Queen,
            },
        );
        board.pieces.insert(
            pos(4, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::Pawn,
            },
        );
    }

    let events = mv(&mut session, WHITE, pos(3, 3), pos(4, 4))
        .expect("la dama debería poder capturar en diagonal");
    let moved = events[0]
        .as_any()
        .downcast_ref::<chess_game::PieceMovedEvent>()
        .unwrap();
    assert_eq!(moved.captured, Some(PieceKind::Pawn));

    let board = session.world().resource::<BoardResource>();
    assert_eq!(board.pieces.len(), 3);
}

#[test]
fn una_jugada_que_deja_al_propio_rey_en_jaque_es_rechazada() {
    let mut session = new_chess_session(SessionId(6), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(4, 4),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 7),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
        // Torre negra controlando toda la fila 4 (nada en el medio).
        board.pieces.insert(
            pos(4, 0),
            Piece {
                owner: BLACK,
                kind: PieceKind::Rook,
            },
        );
    }

    // Mover el rey a otra casilla de la MISMA fila sigue dejándolo en la
    // línea de ataque de la torre — inválido.
    let result = mv(&mut session, WHITE, pos(4, 4), pos(4, 5));
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "el rey no puede quedarse en la misma fila que sigue atacada por la torre"
    );

    // En cambio, salir de la fila Y la columna atacadas sí es válido.
    mv(&mut session, WHITE, pos(4, 4), pos(5, 5))
        .expect("salir de la línea de ataque debería ser válido");
}

#[test]
fn jaque_mate_por_columna_trasera_termina_la_partida() {
    let mut session = new_chess_session(SessionId(7), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        // Rey blanco encerrado por sus propios peones, típico "mate del
        // pasillo": el rey no tiene a dónde ir y la torre negra da jaque
        // por toda la fila 0.
        board.pieces.insert(
            pos(0, 6),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(1, 5),
            Piece {
                owner: WHITE,
                kind: PieceKind::Pawn,
            },
        );
        board.pieces.insert(
            pos(1, 6),
            Piece {
                owner: WHITE,
                kind: PieceKind::Pawn,
            },
        );
        board.pieces.insert(
            pos(1, 7),
            Piece {
                owner: WHITE,
                kind: PieceKind::Pawn,
            },
        );
        board.pieces.insert(
            pos(7, 0),
            Piece {
                owner: BLACK,
                kind: PieceKind::Rook,
            },
        );
        board.pieces.insert(
            pos(7, 7),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
    }
    // Le toca a blancas primero por defecto; para que la torre negra dé
    // el jaque mate, forzamos que le toque a negras.
    force_turn!(session, BLACK);

    let events = mv(&mut session, BLACK, pos(7, 0), pos(0, 0))
        .expect("la torre debería poder moverse a la fila 0");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería haber jaque mate");
    assert_eq!(game_over.winner, Some(BLACK));
}

#[test]
fn captura_al_paso_de_peon_funciona() {
    let mut session = new_chess_session(SessionId(10), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 4),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
        // Peón blanco en (1, 3) y peón negro en (3, 4)
        board.pieces.insert(
            pos(1, 3),
            Piece {
                owner: WHITE,
                kind: PieceKind::Pawn,
            },
        );
        board.pieces.insert(
            pos(3, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::Pawn,
            },
        );
    }

    // Blanco avanza 2 casillas con el peón: (1, 3) -> (3, 3)
    mv(&mut session, WHITE, pos(1, 3), pos(3, 3)).unwrap();

    // Ahora le toca a Negro y puede capturar al paso a (2, 3)
    let events = mv(&mut session, BLACK, pos(3, 4), pos(2, 3)).expect("captura al paso válida");
    let moved = events[0]
        .as_any()
        .downcast_ref::<chess_game::PieceMovedEvent>()
        .unwrap();
    assert_eq!(moved.captured, Some(PieceKind::Pawn));

    // El peón blanco en (3, 3) fue removido del tablero
    let board = session.world().resource::<BoardResource>();
    assert_eq!(board.pieces.get(&pos(3, 3)), None);
    assert_eq!(
        board.pieces.get(&pos(2, 3)),
        Some(&Piece {
            owner: BLACK,
            kind: PieceKind::Pawn
        })
    );
}

#[test]
fn enroque_corto_blanco_funciona() {
    let mut session = new_chess_session(SessionId(11), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 4),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(0, 7),
            Piece {
                owner: WHITE,
                kind: PieceKind::Rook,
            },
        );
        board.pieces.insert(
            pos(7, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
    }

    let events =
        mv(&mut session, WHITE, pos(0, 4), pos(0, 6)).expect("enroque corto blanco válido");
    let moved = events[0]
        .as_any()
        .downcast_ref::<chess_game::PieceMovedEvent>()
        .unwrap();
    assert!(moved.castled);

    let board = session.world().resource::<BoardResource>();
    assert_eq!(
        board.pieces.get(&pos(0, 6)),
        Some(&Piece {
            owner: WHITE,
            kind: PieceKind::King
        })
    );
    assert_eq!(
        board.pieces.get(&pos(0, 5)),
        Some(&Piece {
            owner: WHITE,
            kind: PieceKind::Rook
        })
    );
}

#[test]
fn coronacion_con_eleccion_de_pieza() {
    let mut session = new_chess_session(SessionId(12), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 0),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 7),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(6, 1),
            Piece {
                owner: WHITE,
                kind: PieceKind::Pawn,
            },
        );
    }

    // Blanco corona a Caballo en vez de Dama
    let cmd = Box::new(MovePieceCommand {
        player: WHITE,
        from: pos(6, 1),
        to: pos(7, 1),
        promote_to: Some(PieceKind::Knight),
    });
    let events = session
        .process_command(WHITE, cmd)
        .expect("coronación a caballo válida");
    let moved = events[0]
        .as_any()
        .downcast_ref::<chess_game::PieceMovedEvent>()
        .unwrap();
    assert!(moved.promoted);
    assert_eq!(moved.promoted_to, Some(PieceKind::Knight));

    let board = session.world().resource::<BoardResource>();
    assert_eq!(
        board.pieces.get(&pos(7, 1)),
        Some(&Piece {
            owner: WHITE,
            kind: PieceKind::Knight
        })
    );
}

#[test]
fn flujo_completo_de_oferta_y_aceptacion_de_tablas() {
    let mut session = new_chess_session(SessionId(13), 1, WHITE, BLACK);

    // Blanco ofrece tablas
    let offer_cmd = Box::new(OfferDrawCommand { player: WHITE });
    let events = session
        .process_command(WHITE, offer_cmd)
        .expect("oferta de tablas válida");
    assert!(events.is_empty());

    // Verificar que el recurso registra la oferta de Blanco
    let offered = session.world().resource::<DrawOfferedResource>().0;
    assert_eq!(offered, Some(WHITE));

    // Negro acepta la oferta
    let accept_cmd = Box::new(AcceptDrawCommand { player: BLACK });
    let events = session
        .process_command(BLACK, accept_cmd)
        .expect("aceptación de tablas válida");

    assert_eq!(events.len(), 1);
    let game_over = events[0]
        .as_any()
        .downcast_ref::<GameOverEvent>()
        .expect("debería haber un GameOverEvent");
    assert_eq!(game_over.winner, None);

    // La oferta pendiente se limpia
    let offered_after = session.world().resource::<DrawOfferedResource>().0;
    assert_eq!(offered_after, None);
}

#[test]
fn hacer_un_movimiento_rechaza_y_limpia_la_oferta_de_tablas_pendiente() {
    let mut session = new_chess_session(SessionId(14), 1, WHITE, BLACK);

    // Blanco ofrece tablas
    let offer_cmd = Box::new(OfferDrawCommand { player: WHITE });
    session
        .process_command(WHITE, offer_cmd)
        .expect("oferta de tablas válida");

    // Blanco hace un movimiento (e2 -> e4)
    mv(&mut session, WHITE, pos(1, 4), pos(3, 4)).expect("movimiento de peón válido");

    // La oferta de tablas fue limpiada por el movimiento
    let offered = session.world().resource::<DrawOfferedResource>().0;
    assert_eq!(offered, None);

    // Negro intenta aceptar tablas cuando ya no hay oferta pendiente -> falla
    let accept_cmd = Box::new(AcceptDrawCommand { player: BLACK });
    let res = session.process_command(BLACK, accept_cmd);
    assert!(matches!(res, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn no_se_puede_aceptar_una_oferta_de_tablas_inexistente_o_propia() {
    let mut session = new_chess_session(SessionId(15), 1, WHITE, BLACK);

    // Aceptar sin oferta previa -> falla
    let accept_cmd = Box::new(AcceptDrawCommand { player: BLACK });
    let res = session.process_command(BLACK, accept_cmd);
    assert!(matches!(res, Err(EngineError::InvalidCommand { .. })));

    // Blanco ofrece tablas
    let offer_cmd = Box::new(OfferDrawCommand { player: WHITE });
    session
        .process_command(WHITE, offer_cmd)
        .expect("oferta válida");

    // Blanco intenta aceptar su propia oferta -> falla
    let accept_own_cmd = Box::new(AcceptDrawCommand { player: WHITE });
    let res_own = session.process_command(WHITE, accept_own_cmd);
    assert!(matches!(res_own, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn test_triple_repeticion_produce_tablas() {
    let mut session = new_chess_session(SessionId(20), 1, WHITE, BLACK);

    // 1. Nf3 Nf6
    mv(&mut session, WHITE, pos(0, 1), pos(2, 2)).unwrap();
    mv(&mut session, BLACK, pos(7, 1), pos(5, 2)).unwrap();

    // 2. Ng1 Ng8 (2da vez la posición inicial)
    mv(&mut session, WHITE, pos(2, 2), pos(0, 1)).unwrap();
    mv(&mut session, BLACK, pos(5, 2), pos(7, 1)).unwrap();

    // 3. Nf3 Nf6
    mv(&mut session, WHITE, pos(0, 1), pos(2, 2)).unwrap();
    mv(&mut session, BLACK, pos(7, 1), pos(5, 2)).unwrap();

    // 4. Ng1 Ng8 (3ra vez la posición inicial -> tablas por repetición)
    mv(&mut session, WHITE, pos(2, 2), pos(0, 1)).unwrap();
    let events =
        mv(&mut session, BLACK, pos(5, 2), pos(7, 1)).expect("movimiento de caballo válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería haber un GameOverEvent por triple repetición");

    assert_eq!(game_over.winner, None);
}

#[test]
fn test_regla_50_movimientos_produce_tablas() {
    let mut session = new_chess_session(SessionId(21), 1, WHITE, BLACK);

    session
        .world_mut()
        .insert_resource(HalfMoveClockResource(99));

    // Mover un caballo (movimiento neutral, no es peón ni captura) para llegar a 100 medios movimientos
    let events =
        mv(&mut session, WHITE, pos(0, 1), pos(2, 2)).expect("movimiento de caballo válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería haber un GameOverEvent por regla de 50 movimientos");

    assert_eq!(game_over.winner, None);
}

#[test]
fn test_ahogado_produce_tablas() {
    let mut session = new_chess_session(SessionId(22), 1, WHITE, BLACK);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 0),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 7),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(5, 5),
            Piece {
                owner: WHITE,
                kind: PieceKind::Queen,
            },
        );
    }

    let events = mv(&mut session, WHITE, pos(5, 5), pos(6, 5)).expect("movimiento de dama válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería haber un GameOverEvent por ahogado");

    assert_eq!(game_over.winner, None);
}

#[test]
fn test_material_insuficiente_rey_vs_rey_produce_tablas() {
    let mut session = new_chess_session(SessionId(23), 1, WHITE, BLACK);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 0),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 7),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
    }

    let events = mv(&mut session, WHITE, pos(0, 0), pos(1, 0)).expect("movimiento de rey válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería haber un GameOverEvent por material insuficiente");

    assert_eq!(game_over.winner, None);
}

#[test]
fn test_torre_no_puede_saltar_sobre_piezas() {
    let mut session = new_chess_session(SessionId(30), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 0),
            Piece {
                owner: WHITE,
                kind: PieceKind::Rook,
            },
        );
        board.pieces.insert(
            pos(0, 1),
            Piece {
                owner: WHITE,
                kind: PieceKind::Pawn,
            },
        ); // pieza propia en el medio
        board.pieces.insert(
            pos(0, 4),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
    }

    let result = mv(&mut session, WHITE, pos(0, 0), pos(0, 3));
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "la torre no debe poder saltar sobre piezas"
    );
}

#[test]
fn test_en_passant_no_disponible_un_turno_despues() {
    let mut session = new_chess_session(SessionId(31), 1, WHITE, BLACK);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pieces.clear();
        board.pieces.insert(
            pos(0, 4),
            Piece {
                owner: WHITE,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(7, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::King,
            },
        );
        board.pieces.insert(
            pos(1, 3),
            Piece {
                owner: WHITE,
                kind: PieceKind::Pawn,
            },
        );
        board.pieces.insert(
            pos(3, 4),
            Piece {
                owner: BLACK,
                kind: PieceKind::Pawn,
            },
        );
    }

    // 1. Blanco avanza peón 2 casillas: (1, 3) -> (3, 3)
    mv(&mut session, WHITE, pos(1, 3), pos(3, 3)).expect("avance de 2 casillas válido");

    // 2. Negro NO captura en passant, hace un movimiento neutral con su Rey: (7, 4) -> (7, 5)
    mv(&mut session, BLACK, pos(7, 4), pos(7, 5)).expect("movimiento neutral de rey negro válido");

    // 3. Blanco hace un movimiento neutral con su Rey: (0, 4) -> (0, 5)
    mv(&mut session, WHITE, pos(0, 4), pos(0, 5)).expect("movimiento neutral de rey blanco válido");

    // 4. Ahora Negro intenta la captura en passant a (2, 3) cuando ya pasó el turno oportuno -> debe fallar
    let result = mv(&mut session, BLACK, pos(3, 4), pos(2, 3));
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "el en passant no debe estar disponible un turno después"
    );
}

#[test]
fn test_rendicion_termina_la_partida() {
    let mut session = new_chess_session(SessionId(1), 1, WHITE, BLACK);
    let events = session
        .process_command(WHITE, Box::new(ResignCommand { player: WHITE }))
        .expect("la rendición de un jugador válido debe procesarse");

    assert_eq!(events.len(), 1);
    let game_over = session.world().resource::<GameOverResource>().0;
    assert!(game_over);
    let winner = session.world().resource::<WinnerResource>().0;
    assert_eq!(winner, Some(BLACK));
}

#[test]
fn test_chess_ai_no_mueve_rey_a_casilla_atacada() {
    // Posición: Rey blanco en e1 (row 0, col 4), Torre negra en d8 (row 7, col 3).
    // La IA a depth=1 no debe mover el rey a d1 (row 0, col 3) porque estaría en jaque.
    let fen = "3r4/8/8/8/8/8/8/4K3 w - - 0 1";
    let mut session = new_chess_session(SessionId(1), 42, WHITE, BLACK);
    load_chess_position_from_fen(&mut session, fen).unwrap();
    let mv = chess_ai_pick_move(&session, WHITE, 1);
    if let Some(m) = mv {
        assert!(
            !(m.from == Position::new(0, 4) && m.to == Position::new(0, 3)),
            "La IA no debe mover el rey a casilla atacada por la torre"
        );
    }
}
