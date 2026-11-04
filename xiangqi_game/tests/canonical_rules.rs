// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;
use xiangqi_game::{
    all_legal_moves_for, is_in_check, new_xiangqi_session, BoardResource, GameOverEvent,
    MovePieceCommand, Piece, PieceKind,
};

const RED: PlayerId = PlayerId(1);
const BLACK: PlayerId = PlayerId(2);

#[test]
fn canonical_victoria_por_ahogado_kunbi() {
    let mut session = new_xiangqi_session(SessionId(518_7), 0, RED, BLACK);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.squares.clear();

        // General negro en (3, 0)
        board.squares.insert(
            (3, 0),
            Piece {
                kind: PieceKind::General,
                owner: BLACK,
            },
        );
        // General rojo en (4, 9) controla la columna 4 por regla de General Volador
        board.squares.insert(
            (4, 9),
            Piece {
                kind: PieceKind::General,
                owner: RED,
            },
        );
        // Carro rojo en (0, 5) listo para bajar a (0, 1) y cortar la fila 1 sin dar jaque
        board.squares.insert(
            (0, 5),
            Piece {
                kind: PieceKind::Chariot,
                owner: RED,
            },
        );
    }

    let events = session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (0, 5),
                to: (0, 1),
            }),
        )
        .expect("el movimiento de bloqueo Kunbi debe ser válido");

    {
        let board = session.world().resource::<BoardResource>();
        assert!(
            !is_in_check(board, BLACK),
            "el General negro no está en jaque directo, sino en ahogado (Kunbi)"
        );
    }
    assert!(
        all_legal_moves_for(session.world(), BLACK).is_empty(),
        "BLACK no debe tener movimientos legales"
    );

    let go = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debe emitirse GameOverEvent tras Kunbi");
    assert_eq!(go.winner, Some(RED));
    assert!(session.world().resource::<GameOverResource>().0);
    assert_eq!(session.world().resource::<WinnerResource>().0, Some(RED));
}

#[test]
fn canonical_triple_repeticion_tablas_y_general_volador() {
    let mut session = new_xiangqi_session(SessionId(518_203), 0, RED, BLACK);
    // Verificar generador de jugadas iniciales (4 movimientos legales para Rojo en standard_setup)
    assert_eq!(all_legal_moves_for(session.world(), RED).len(), 4);

    // Configurar posición simple para probar General Volador y Triple Repetición
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.squares.clear();
        board.squares.insert(
            (4, 9),
            Piece {
                kind: PieceKind::General,
                owner: RED,
            },
        );
        board.squares.insert(
            (4, 0),
            Piece {
                kind: PieceKind::General,
                owner: BLACK,
            },
        );
        board.squares.insert(
            (4, 5),
            Piece {
                kind: PieceKind::Soldier,
                owner: RED,
            },
        );
        board.squares.insert(
            (0, 9),
            Piece {
                kind: PieceKind::Chariot,
                owner: RED,
            },
        );
        board.squares.insert(
            (0, 0),
            Piece {
                kind: PieceKind::Chariot,
                owner: BLACK,
            },
        );
    }

    // Quitar el soldado intermedio expondría a ambos Generales en la columna 4 -> ilegal
    assert!(session
        .process_command(
            RED,
            Box::new(MovePieceCommand {
                player: RED,
                from: (4, 5),
                to: (3, 5),
            }),
        )
        .is_err());

    // Repetir posición 3 veces con los Carros -> Tablas por triple repetición
    for cycle in 1..=2 {
        session
            .process_command(
                RED,
                Box::new(MovePieceCommand {
                    player: RED,
                    from: (0, 9),
                    to: (0, 8),
                }),
            )
            .unwrap();
        session
            .process_command(
                BLACK,
                Box::new(MovePieceCommand {
                    player: BLACK,
                    from: (0, 0),
                    to: (0, 1),
                }),
            )
            .unwrap();
        session
            .process_command(
                RED,
                Box::new(MovePieceCommand {
                    player: RED,
                    from: (0, 8),
                    to: (0, 9),
                }),
            )
            .unwrap();
        let evs = session
            .process_command(
                BLACK,
                Box::new(MovePieceCommand {
                    player: BLACK,
                    from: (0, 1),
                    to: (0, 0),
                }),
            )
            .unwrap();
        if cycle == 2 {
            let go = evs
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
                .expect("3ª aparición de la misma posición declara tablas");
            assert_eq!(go.winner, None);
        }
    }
}
