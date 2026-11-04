// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use backgammon_game::{
    new_backgammon_session, BoardResource as BgBoardResource, MoveCheckerCommand,
    CHECKERS_PER_PLAYER,
};
use checkers_game::{
    new_checkers_session, BoardResource as CheckersBoardResource, MovePieceCommand, Piece, Position,
};
use open_table_engine::prelude::*;
use uno_game::{new_uno_session, Card, CardColor, CardValue, PlayCardCommand, UnoState};

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

#[test]
fn test_regresion_checkers_captura_multiple_mantiene_turno() {
    let mut session = new_checkers_session(SessionId(1), 1, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<CheckersBoardResource>();
        for r in 0..8u8 {
            for c in 0..8u8 {
                board.set(pos(r, c), None);
            }
        }
        board.set(
            pos(0, 1),
            Some(Piece {
                owner: P1,
                is_king: false,
            }),
        );
        board.set(
            pos(1, 2),
            Some(Piece {
                owner: P2,
                is_king: false,
            }),
        );
        board.set(
            pos(3, 4),
            Some(Piece {
                owner: P2,
                is_king: false,
            }),
        );
    }

    // Primer salto de captura
    session
        .process_command(
            P1,
            Box::new(MovePieceCommand {
                player: P1,
                from: pos(0, 1),
                to: pos(2, 3),
            }),
        )
        .expect("primer salto debe ser válido");

    // Debe mantener el turno de P1 porque hay una captura posterior disponible
    assert_eq!(
        session.current_player(),
        P1,
        "en captura múltiple, el turno debe permanecer en el mismo jugador"
    );

    // Segundo salto de captura
    session
        .process_command(
            P1,
            Box::new(MovePieceCommand {
                player: P1,
                from: pos(2, 3),
                to: pos(4, 5),
            }),
        )
        .expect("segundo salto debe ser válido");

    // Al finalizar la cadena, el turno pasa a P2
    assert_eq!(
        session.current_player(),
        P2,
        "al finalizar las capturas múltiples el turno pasa al oponente"
    );
}

#[test]
fn test_regresion_backgammon_bearing_off_dado_mayor() {
    let mut session = new_backgammon_session(SessionId(2), 1, P1, P2);

    {
        let mut board = session.world_mut().resource_mut::<BgBoardResource>();
        board.points = [0; backgammon_game::POINTS];
        board.points[20] = 1; // Ficha de P1 en el punto 20
        board.borne_off.insert(P1, CHECKERS_PER_PLAYER - 1);
    }

    // Forzar dado 6
    session
        .world_mut()
        .resource_mut::<backgammon_game::PendingDiceResource>()
        .pending
        .insert(P1, vec![6]);

    let res = session.process_command(
        P1,
        Box::new(MoveCheckerCommand {
            player: P1,
            from: Some(20),
            die: 6,
        }),
    );

    assert!(
        res.is_ok(),
        "sacar ficha con dado mayor que la distancia (distancia=4, dado=6) cuando no hay fichas más atrás debe ser válido"
    );
}

#[test]
fn test_regresion_uno_wild_draw_four_invalido_con_carta_del_color() {
    let mut session = new_uno_session(SessionId(3), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Number(3)));
        hand.push(Card::new(CardColor::WildColor, CardValue::WildDrawFour));
    }

    let res = session.process_command(
        P1,
        Box::new(PlayCardCommand {
            player: P1,
            card_index: 1,
            chosen_color: Some(CardColor::Blue),
        }),
    );

    assert!(
        matches!(res, Err(EngineError::InvalidCommand { .. })),
        "jugar Wild Draw Four teniendo una carta del color activo en la mano debe ser rechazado"
    );
}
