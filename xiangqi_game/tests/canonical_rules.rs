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
