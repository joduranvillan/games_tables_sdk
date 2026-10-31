use checkers_game::{
    new_checkers_session, BoardResource, DrawClockResource, GameOverEvent, MovePieceCommand, Piece,
    Position,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

fn move_cmd(player: PlayerId, from: Position, to: Position) -> Box<dyn Command> {
    Box::new(MovePieceCommand { player, from, to })
}

#[test]
fn canonical_victoria_por_bloqueo_sin_movimientos_legales() {
    let mut session = new_checkers_session(SessionId(518_1), 1, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 5),
            Some(Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(0, 7),
            Some(Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(2, 7),
            Some(Piece {
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
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect(
            "debe emitirse GameOverEvent cuando el rival queda bloqueado sin movimientos legales",
        );

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
fn canonical_tablas_por_40_turnos_sin_captura_ni_coronacion() {
    let mut session = new_checkers_session(SessionId(518_2), 1, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 1),
            Some(Piece {
                owner: P1,
                is_king: true,
            }),
        );
        board.set(
            pos(7, 6),
            Some(Piece {
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
        assert!(ev1
            .iter()
            .all(|e| e.as_any().downcast_ref::<GameOverEvent>().is_none()));

        let (p2_from, p2_to) = if i % 2 == 0 {
            (pos(7, 6), pos(6, 7))
        } else {
            (pos(6, 7), pos(7, 6))
        };
        let ev2 = session
            .process_command(P2, move_cmd(P2, p2_from, p2_to))
            .expect("movimiento de dama P2 válido");

        if i < 39 {
            assert!(ev2
                .iter()
                .all(|e| e.as_any().downcast_ref::<GameOverEvent>().is_none()));
        } else {
            let go = ev2
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
                .expect(
                    "al llegar a 80 medios turnos (40 turnos completos) debe declararse tablas",
                );
            assert!(go.is_draw);
        }
    }

    assert_eq!(
        session
            .world()
            .resource::<DrawClockResource>()
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
fn canonical_reinicio_reloj_tablas_y_captura_obligatoria() {
    let mut session = new_checkers_session(SessionId(518_200), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(2, 1),
            Some(Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 2),
            Some(Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(7, 0),
            Some(Piece {
                owner: P2,
                is_king: true,
            }),
        );
    }
    session
        .world_mut()
        .resource_mut::<DrawClockResource>()
        .half_moves_without_capture_or_promotion = 35;

    // Si existe captura obligatoria ((2,1) -> (4,3)), intentar movimiento simple ((2,1) -> (3,0)) se rechaza
    assert!(session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(3, 0)))
        .is_err());

    // Al ejecutar la captura obligatoria, el reloj de 40 turnos se reinicia a 0
    session
        .process_command(P1, move_cmd(P1, pos(2, 1), pos(4, 3)))
        .expect("captura obligatoria válida");
    assert_eq!(
        session
            .world()
            .resource::<DrawClockResource>()
            .half_moves_without_capture_or_promotion,
        0
    );
}

