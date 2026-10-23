use open_table_engine::prelude::*;
use shogi_game::{
    new_shogi_session, new_shogi_session_fesa, BoardResource, GameOverEvent, MovePieceCommand,
    Piece, PieceKind,
};

const SENTE: PlayerId = PlayerId(1);
const GOTE: PlayerId = PlayerId(2);

#[test]
fn canonical_sennichite_cuadruple_repeticion_declara_tablas() {
    let mut session = new_shogi_session(SessionId(518_5), 0, SENTE, GOTE);

    for cycle in 1..=3 {
        session
            .process_command(
                SENTE,
                Box::new(MovePieceCommand {
                    player: SENTE,
                    from: (4, 8),
                    to: (3, 8),
                    promote: false,
                }),
            )
            .unwrap();

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

        session
            .process_command(
                SENTE,
                Box::new(MovePieceCommand {
                    player: SENTE,
                    from: (3, 8),
                    to: (4, 8),
                    promote: false,
                }),
            )
            .unwrap();

        let events = session
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

        let draw_event = events.iter().any(|e| {
            e.as_any()
                .downcast_ref::<GameOverEvent>()
                .is_some_and(|go| go.winner.is_none())
        });

        if cycle < 3 {
            assert!(!draw_event);
        } else {
            assert!(
                draw_event,
                "en la 4ª aparición del mismo estado debe declararse tablas por Sennichite"
            );
        }
    }

    assert!(session.world().resource::<GameOverResource>().0);
    assert_eq!(session.world().resource::<WinnerResource>().0, None);
}

#[test]
fn canonical_fesa_promocion_opcional_y_obligatoria() {
    let mut session = new_shogi_session_fesa(SessionId(518_6), 0, SENTE, GOTE);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.squares.clear();
        board.squares.insert(
            (4, 8),
            Piece {
                kind: PieceKind::King,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (4, 0),
            Piece {
                kind: PieceKind::King,
                owner: GOTE,
            },
        );
        board.squares.insert(
            (2, 3),
            Piece {
                kind: PieceKind::Silver,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (1, 1),
            Piece {
                kind: PieceKind::Pawn,
                owner: SENTE,
            },
        );
        board.squares.insert(
            (8, 3),
            Piece {
                kind: PieceKind::Knight,
                owner: SENTE,
            },
        );
    }

    // 1. Silver entra en zona de promoción (fila 2) con promote: false (opcional en FESA)
    session
        .process_command(
            SENTE,
            Box::new(MovePieceCommand {
                player: SENTE,
                from: (2, 3),
                to: (2, 2),
                promote: false,
            }),
        )
        .expect("Silver debe poder entrar a fila 2 sin promocionar bajo FESA");

    assert_eq!(
        session
            .world()
            .resource::<BoardResource>()
            .squares
            .get(&(2, 2))
            .map(|p| p.kind),
        Some(PieceKind::Silver)
    );

    // 2. Peón en última fila (0) está obligado a promocionar
    force_turn!(session, SENTE);
    let err_pawn = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (1, 1),
            to: (1, 0),
            promote: false,
        }),
    );
    assert!(matches!(err_pawn, Err(EngineError::InvalidCommand { .. })));

    session
        .process_command(
            SENTE,
            Box::new(MovePieceCommand {
                player: SENTE,
                from: (1, 1),
                to: (1, 0),
                promote: true,
            }),
        )
        .expect("Peón en fila 0 con promote: true es válido");

    // 3. Caballo en penúltima fila (1) está obligado a promocionar
    force_turn!(session, SENTE);
    let err_knight = session.process_command(
        SENTE,
        Box::new(MovePieceCommand {
            player: SENTE,
            from: (8, 3),
            to: (7, 1),
            promote: false,
        }),
    );
    assert!(matches!(
        err_knight,
        Err(EngineError::InvalidCommand { .. })
    ));

    session
        .process_command(
            SENTE,
            Box::new(MovePieceCommand {
                player: SENTE,
                from: (8, 3),
                to: (7, 1),
                promote: true,
            }),
        )
        .expect("Caballo en fila 1 con promote: true es válido");
}
