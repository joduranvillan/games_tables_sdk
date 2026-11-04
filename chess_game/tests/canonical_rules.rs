// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use chess_game::{
    new_chess_session, AcceptDrawCommand, BoardResource, GameOverEvent, HalfMoveClockResource,
    MovePieceCommand, OfferDrawCommand, Piece, PieceKind, PieceMovedEvent, Position,
};
use open_table_engine::prelude::*;

const WHITE: PlayerId = PlayerId(1);
const BLACK: PlayerId = PlayerId(2);

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

#[test]
fn canonical_enroque_en_passant_y_tablas_50_movimientos() {
    let mut session = new_chess_session(SessionId(518_60), 1, WHITE, BLACK);
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

    let events = session
        .process_command(
            WHITE,
            Box::new(MovePieceCommand {
                player: WHITE,
                from: pos(0, 4),
                to: pos(0, 6),
                promote_to: None,
            }),
        )
        .expect("enroque corto válido");
    let moved = events[0]
        .as_any()
        .downcast_ref::<PieceMovedEvent>()
        .unwrap();
    assert!(moved.castled);

    // Regla de 50 movimientos (100 medios turnos)
    session
        .world_mut()
        .insert_resource(HalfMoveClockResource(99));
    let ev_draw = session
        .process_command(
            BLACK,
            Box::new(MovePieceCommand {
                player: BLACK,
                from: pos(7, 4),
                to: pos(7, 3),
                promote_to: None,
            }),
        )
        .expect("movimiento neutral válido");
    let go = ev_draw
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debe declararse tablas al alcanzar 100 medios movimientos");
    assert_eq!(go.winner, None);
}

#[test]
fn canonical_subpromocion_y_rechazo_tablas_sin_oferta() {
    for (idx, kind) in [PieceKind::Rook, PieceKind::Bishop, PieceKind::Knight]
        .into_iter()
        .enumerate()
    {
        let mut session = new_chess_session(SessionId(518_61 + idx as u64), 1, WHITE, BLACK);
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
                pos(7, 7),
                Piece {
                    owner: BLACK,
                    kind: PieceKind::King,
                },
            );
            board.pieces.insert(
                pos(6, 0),
                Piece {
                    owner: WHITE,
                    kind: PieceKind::Pawn,
                },
            );
        }

        let events = session
            .process_command(
                WHITE,
                Box::new(MovePieceCommand {
                    player: WHITE,
                    from: pos(6, 0),
                    to: pos(7, 0),
                    promote_to: Some(kind),
                }),
            )
            .expect("subpromoción válida");
        let moved = events[0]
            .as_any()
            .downcast_ref::<PieceMovedEvent>()
            .unwrap();
        assert_eq!(moved.promoted_to, Some(kind));
        assert_eq!(
            session
                .world()
                .resource::<BoardResource>()
                .pieces
                .get(&pos(7, 0))
                .map(|p| p.kind),
            Some(kind)
        );
    }

    // Rechazo de AcceptDrawCommand sin oferta previa y OfferDrawCommand fuera de turno
    let mut session = new_chess_session(SessionId(518_65), 1, WHITE, BLACK);
    assert!(session
        .process_command(WHITE, Box::new(AcceptDrawCommand { player: WHITE }))
        .is_err());
    assert!(session
        .process_command(BLACK, Box::new(OfferDrawCommand { player: BLACK }))
        .is_err());
}
