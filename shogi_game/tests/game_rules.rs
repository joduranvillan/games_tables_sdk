use open_table_engine::prelude::*;
use shogi_game::{new_shogi_session, DropPieceCommand, MovePieceCommand, PieceKind};

const SENTE: PlayerId = PlayerId(1);
const GOTE: PlayerId = PlayerId(2);

#[test]
fn test_move_and_drop() {
    let mut session = new_shogi_session(SessionId(1), 0, SENTE, GOTE);

    // Sente moves pawn
    session
        .process_command(
            SENTE,
            Box::new(MovePieceCommand {
                player: SENTE,
                from: (4, 6),
                to: (4, 5),
                promote: false,
            }),
        )
        .unwrap();
    // Gote moves pawn
    session
        .process_command(
            GOTE,
            Box::new(MovePieceCommand {
                player: GOTE,
                from: (4, 2),
                to: (4, 3),
                promote: false,
            }),
        )
        .unwrap();
    // Sente moves pawn
    session
        .process_command(
            SENTE,
            Box::new(MovePieceCommand {
                player: SENTE,
                from: (4, 5),
                to: (4, 4),
                promote: false,
            }),
        )
        .unwrap();
    // Gote moves King
    session
        .process_command(
            GOTE,
            Box::new(MovePieceCommand {
                player: GOTE,
                from: (4, 0),
                to: (3, 0),
                promote: false,
            }),
        )
        .unwrap();
    // Sente captures pawn
    session
        .process_command(
            SENTE,
            Box::new(MovePieceCommand {
                player: SENTE,
                from: (4, 4),
                to: (4, 3),
                promote: false,
            }),
        )
        .unwrap();

    let board = session.world().resource::<shogi_game::BoardResource>();
    assert_eq!(board.hands[&SENTE].len(), 1);
    assert_eq!(board.hands[&SENTE][0], PieceKind::Pawn);

    // Gote moves King back
    session
        .process_command(
            GOTE,
            Box::new(MovePieceCommand {
                player: GOTE,
                from: (3, 0),
                to: (4, 0),
                promote: false,
            }),
        )
        .unwrap();

    // Sente drops pawn in column 3 (to avoid Nifu)
    session
        .process_command(
            SENTE,
            Box::new(DropPieceCommand {
                player: SENTE,
                piece: PieceKind::Pawn,
                to: (3, 2),
            }),
        )
        .unwrap();

    let board = session.world().resource::<shogi_game::BoardResource>();
    assert_eq!(board.hands[&SENTE].len(), 0);
    assert!(board.squares.contains_key(&(3, 2)));
}

#[test]
fn test_forced_promotion_en_zona_rival() {
    let mut session = new_shogi_session(SessionId(10), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.insert(
            (3, 2),
            shogi_game::Piece {
                kind: PieceKind::Silver,
                owner: SENTE,
            },
        );
    }

    let res_no_promo = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (3, 2),
            to: (3, 1),
            promote: false,
        }),
    );
    assert!(
        matches!(res_no_promo, Err(EngineError::InvalidCommand { .. })),
        "Mover a la zona rival sin promocionar debe ser rechazado"
    );

    let res_promo = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (3, 2),
            to: (3, 1),
            promote: true,
        }),
    );
    assert!(
        res_promo.is_ok(),
        "Mover con promote: true debe tener éxito"
    );

    let board = session.world().resource::<shogi_game::BoardResource>();
    assert_eq!(
        board.squares.get(&(3, 1)).map(|p| p.kind),
        Some(PieceKind::PromotedSilver),
        "La pieza en (3, 1) debe ser PromotedSilver"
    );
}

#[test]
fn test_nifu_rechaza_drop_en_columna_con_peon() {
    let mut session = new_shogi_session(SessionId(11), 0, SENTE, GOTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.hands.get_mut(&SENTE).unwrap().push(PieceKind::Pawn);
        board.squares.insert(
            (4, 6),
            shogi_game::Piece {
                kind: PieceKind::Pawn,
                owner: SENTE,
            },
        );
    }

    let res_drop = session.process_command(
        SENTE,
        Box::new(DropPieceCommand {
            player: SENTE,
            piece: PieceKind::Pawn,
            to: (4, 3),
        }),
    );

    assert!(
        matches!(res_drop, Err(EngineError::InvalidCommand { .. })),
        "El drop de un Peón en una columna que ya contiene un Peón propio debe ser rechazado por Nifu"
    );
}

#[test]
fn test_uchifuzume_rechaza_drop_de_peon_con_jaque_mate_inmediato() {
    let mut session = new_shogi_session(SessionId(12), 0, SENTE, GOTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.clear();
        board.hands.get_mut(&SENTE).unwrap().clear();
        board.hands.get_mut(&GOTE).unwrap().clear();

        // Sente tiene un Peón en la mano
        board.hands.get_mut(&SENTE).unwrap().push(PieceKind::Pawn);

        // Posición mínima para Uchifuzume: Rey de Gote acorralado en (0, 0)
        board.squares.insert(
            (0, 0),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: GOTE,
            },
        );
        board.squares.insert(
            (4, 8),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: SENTE,
            },
        );

        board.squares.insert(
            (1, 0),
            shogi_game::Piece {
                kind: PieceKind::Silver,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (2, 1),
            shogi_game::Piece {
                kind: PieceKind::Gold,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (1, 2),
            shogi_game::Piece {
                kind: PieceKind::Gold,
                owner: SENTE,
            },
        );
    }

    force_turn!(session, SENTE);

    let res_drop = session.process_command(
        SENTE,
        Box::new(DropPieceCommand {
            player: SENTE,
            piece: PieceKind::Pawn,
            to: (0, 1),
        }),
    );

    assert!(
        matches!(res_drop, Err(EngineError::InvalidCommand { .. })),
        "El drop de un Peón que genera jaque mate inmediato (Uchifuzume) debe ser rechazado"
    );
}

#[test]
fn test_lanza_no_puede_droppear_en_ultima_fila() {
    let mut session = new_shogi_session(SessionId(13), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.hands.get_mut(&SENTE).unwrap().push(PieceKind::Lance);
    }

    let res_drop = session.process_command(
        SENTE,
        Box::new(DropPieceCommand {
            player: SENTE,
            piece: PieceKind::Lance,
            to: (3, 0),
        }),
    );

    assert!(
        matches!(res_drop, Err(EngineError::InvalidCommand { .. })),
        "El drop de una Lanza en la última fila (Sente) debe ser rechazado"
    );
}

#[test]
fn test_caballo_no_puede_droppear_en_penultima_fila() {
    let mut session = new_shogi_session(SessionId(14), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.hands.get_mut(&SENTE).unwrap().push(PieceKind::Knight);
    }

    let res_drop = session.process_command(
        SENTE,
        Box::new(DropPieceCommand {
            player: SENTE,
            piece: PieceKind::Knight,
            to: (3, 1),
        }),
    );

    assert!(
        matches!(res_drop, Err(EngineError::InvalidCommand { .. })),
        "El drop de un Caballo en la penúltima fila (Sente) debe ser rechazado"
    );
}

#[test]
fn test_dragon_puede_moverse_ortogonal_y_diagonalmente() {
    let mut session = new_shogi_session(SessionId(15), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.clear();
        board.squares.insert(
            (4, 4),
            shogi_game::Piece {
                kind: PieceKind::PromotedRook,
                owner: SENTE,
            },
        );
        // Agregar reyes para que is_in_check no falle y permita validación
        board.squares.insert(
            (4, 8),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (4, 0),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: GOTE,
            },
        );
    }

    // Movimiento ortogonal (como Torre)
    let res_orto = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (4, 4),
            to: (4, 5),
            promote: false,
        }),
    );
    assert!(res_orto.is_ok(), "Dragon debe poder moverse ortogonalmente");

    // Revertir turno para Sente y devolver pieza
    force_turn!(session, SENTE);
    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.remove(&(4, 5));
        board.squares.insert(
            (4, 4),
            shogi_game::Piece {
                kind: PieceKind::PromotedRook,
                owner: SENTE,
            },
        );
    }

    // Movimiento diagonal adyacente
    let res_diag = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (4, 4),
            to: (5, 5),
            promote: false,
        }),
    );
    assert!(
        res_diag.is_ok(),
        "Dragon debe poder moverse diagonalmente un paso"
    );
}

#[test]
fn test_horse_puede_moverse_diagonal_y_ortogonalmente() {
    let mut session = new_shogi_session(SessionId(16), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.clear();
        board.squares.insert(
            (4, 4),
            shogi_game::Piece {
                kind: PieceKind::PromotedBishop,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (4, 8),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (4, 0),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: GOTE,
            },
        );
    }

    // Movimiento diagonal (como Alfil)
    let res_diag = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (4, 4),
            to: (5, 5),
            promote: false,
        }),
    );
    assert!(res_diag.is_ok(), "Horse debe poder moverse diagonalmente");

    // Revertir turno para Sente y devolver pieza
    force_turn!(session, SENTE);
    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.remove(&(5, 5));
        board.squares.insert(
            (4, 4),
            shogi_game::Piece {
                kind: PieceKind::PromotedBishop,
                owner: SENTE,
            },
        );
    }

    // Movimiento ortogonal adyacente
    let res_orto = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (4, 4),
            to: (4, 5),
            promote: false,
        }),
    );
    assert!(
        res_orto.is_ok(),
        "Horse debe poder moverse ortogonalmente un paso"
    );
}

#[test]
fn test_mover_pieza_que_descubre_jaque_propio_es_rechazado() {
    let mut session = new_shogi_session(SessionId(17), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.clear();
        // Sente's King at (4, 8)
        board.squares.insert(
            (4, 8),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: SENTE,
            },
        );
        // Sente's Gold at (4, 7) blocking the Rook
        board.squares.insert(
            (4, 7),
            shogi_game::Piece {
                kind: PieceKind::Gold,
                owner: SENTE,
            },
        );
        // Gote's Rook at (4, 2) attacking the column
        board.squares.insert(
            (4, 2),
            shogi_game::Piece {
                kind: PieceKind::Rook,
                owner: GOTE,
            },
        );
        // Gote's King (must exist)
        board.squares.insert(
            (0, 0),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: GOTE,
            },
        );
    }

    // Attempt to move the Gold out of the column, which would put the King in check
    let res = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (4, 7),
            to: (3, 7),
            promote: false,
        }),
    );

    assert!(
        matches!(res, Err(EngineError::InvalidCommand { .. })),
        "Mover una pieza descubriendo jaque al propio Rey debe ser rechazado"
    );
}

#[test]
fn test_jaque_mate_termina_la_partida() {
    let mut session = new_shogi_session(SessionId(18), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.clear();
        board.hands.get_mut(&SENTE).unwrap().clear();
        board.hands.get_mut(&GOTE).unwrap().clear();

        // Posición de mate. Gote King in the corner.
        board.squares.insert(
            (0, 0),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: GOTE,
            },
        );
        board.squares.insert(
            (4, 8),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: SENTE,
            },
        );
        // Sente's Gold is at (1, 1), defending the corner.
        board.squares.insert(
            (1, 1),
            shogi_game::Piece {
                kind: PieceKind::Gold,
                owner: SENTE,
            },
        );
        // Sente's Rook is at (0, 3)
        board.squares.insert(
            (0, 3),
            shogi_game::Piece {
                kind: PieceKind::Rook,
                owner: SENTE,
            },
        );
    }

    // Sente moves Rook from (0, 3) to (0, 1)
    let res = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (0, 3),
            to: (0, 1),
            promote: true,
        }),
    );

    assert!(res.is_ok(), "The move itself is valid.");

    // We should check that a GameOverEvent was returned.
    let events = res.unwrap();
    let is_game_over = events.iter().any(|e| {
        if let Some(game_over) = e.as_any().downcast_ref::<shogi_game::GameOverEvent>() {
            game_over.winner == Some(SENTE)
        } else {
            false
        }
    });

    assert!(
        is_game_over,
        "El evento GameOverEvent debe ser emitido con Sente como ganador"
    );
}

#[test]
fn test_capturar_pieza_promovida_la_agrega_despromovida_al_hand() {
    let mut session = new_shogi_session(SessionId(19), 0, SENTE, GOTE);
    force_turn!(session, SENTE);

    {
        let mut board = session
            .world_mut()
            .resource_mut::<shogi_game::BoardResource>();
        board.squares.clear();
        board.hands.get_mut(&SENTE).unwrap().clear();
        board.hands.get_mut(&GOTE).unwrap().clear();

        // Gote's PromotedSilver at (4, 4)
        board.squares.insert(
            (4, 4),
            shogi_game::Piece {
                kind: PieceKind::PromotedSilver,
                owner: GOTE,
            },
        );
        // Sente's Rook at (4, 8)
        board.squares.insert(
            (4, 8),
            shogi_game::Piece {
                kind: PieceKind::Rook,
                owner: SENTE,
            },
        );
        // Kings for valid state
        board.squares.insert(
            (0, 8),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (0, 0),
            shogi_game::Piece {
                kind: PieceKind::King,
                owner: GOTE,
            },
        );
    }

    // Sente captures PromotedSilver with Rook
    let res = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (4, 8),
            to: (4, 4),
            promote: false,
        }),
    );

    assert!(res.is_ok(), "The capture should be valid");

    let board = session.world().resource::<shogi_game::BoardResource>();
    let sente_hand = board.hands.get(&SENTE).unwrap();
    assert_eq!(sente_hand.len(), 1, "Sente debe tener una pieza en mano");
    assert_eq!(
        sente_hand[0],
        PieceKind::Silver,
        "La pieza capturada debe ser un Silver (despromovida), no PromotedSilver"
    );
}
