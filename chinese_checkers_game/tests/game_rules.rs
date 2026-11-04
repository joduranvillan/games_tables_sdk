// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use chinese_checkers_game::{
    home_cells_a, home_cells_b, new_chinese_checkers_session, BoardResource,
    ChineseCheckersLegalMoveGenerator, GameOverEvent, MovePegCommand, PegMovedEvent, Position,
    ResignCommand,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const P3: PlayerId = PlayerId(3);
const P4: PlayerId = PlayerId(4);
const P5: PlayerId = PlayerId(5);
const P6: PlayerId = PlayerId(6);

#[test]
fn el_setup_pone_10_fichas_por_jugador_en_esquinas_opuestas() {
    let session = new_chinese_checkers_session(SessionId(1), 1, vec![P1, P2]);
    let board = session.world().resource::<BoardResource>();
    let count_p1 = board.pegs.values().filter(|&&p| p == P1).count();
    let count_p2 = board.pegs.values().filter(|&&p| p == P2).count();
    assert_eq!(count_p1, 10);
    assert_eq!(count_p2, 10);
}

#[test]
fn un_paso_simple_a_una_casilla_vacia_es_valido() {
    let mut session = new_chinese_checkers_session(SessionId(2), 1, vec![P1, P2]);
    let from = home_cells_a()[0];
    let to = from.add((1, 0));

    let events = session
        .process_command(
            P1,
            Box::new(MovePegCommand {
                player: P1,
                from,
                to,
                path: vec![],
            }),
        )
        .expect("el paso debería ser válido si la casilla está vacía y en el tablero");
    let moved = events[0].as_any().downcast_ref::<PegMovedEvent>().unwrap();
    assert!(!moved.was_jump);
}

#[test]
fn no_se_puede_mover_a_una_casilla_ocupada() {
    let mut session = new_chinese_checkers_session(SessionId(3), 1, vec![P1, P2]);
    let cells = home_cells_a();
    let result = session.process_command(
        P1,
        Box::new(MovePegCommand {
            player: P1,
            from: cells[0],
            to: cells[1], // ya ocupada por otra ficha propia
            path: vec![],
        }),
    );
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn saltar_sobre_cualquier_ficha_no_la_captura_solo_permite_pasar() {
    let mut session = new_chinese_checkers_session(SessionId(4), 1, vec![P1, P2]);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pegs.clear();
        board.pegs.insert(Position::new(0, 0), P1);
        board.pegs.insert(Position::new(1, 0), P2); // ficha rival en el medio
    }

    let events = session
        .process_command(
            P1,
            Box::new(MovePegCommand {
                player: P1,
                from: Position::new(0, 0),
                to: Position::new(2, 0),
                path: vec![],
            }),
        )
        .expect("saltar sobre una ficha rival debería ser válido");
    let moved = events[0].as_any().downcast_ref::<PegMovedEvent>().unwrap();
    assert!(moved.was_jump);

    let board = session.world().resource::<BoardResource>();
    assert_eq!(
        board.pegs.get(&Position::new(1, 0)),
        Some(&P2),
        "la ficha saltada NO se captura"
    );
    assert_eq!(board.pegs.get(&Position::new(2, 0)), Some(&P1));
}

#[test]
fn test_seis_jugadores_ciclan_correctamente() {
    let mut session = new_chinese_checkers_session(SessionId(10), 1, vec![P1, P2, P3, P4, P5, P6]);
    let players = vec![P1, P2, P3, P4, P5, P6];

    for i in 0..6 {
        let current_p = players[i];
        let current_turn = session
            .world()
            .resource::<TurnResource>()
            .0
            .current_player();
        assert_eq!(
            current_turn,
            current_p,
            "El turno actual debería ser P{}",
            i + 1
        );

        let board = session.world().resource::<BoardResource>();
        let corner_idx = i;
        let (from, valid_to) = chinese_checkers_game::position::corner_cells(corner_idx)
            .iter()
            .find_map(|&cell| {
                if board.pegs.get(&cell) != Some(&current_p) {
                    return None;
                }
                chinese_checkers_game::position::DIRECTIONS
                    .iter()
                    .map(|&d| cell.add(d))
                    .find(|p| p.is_on_board() && !board.pegs.contains_key(p))
                    .map(|to| (cell, to))
            })
            .expect("debe haber una casilla vacía adyacente");

        let _ = board;

        session
            .process_command(
                current_p,
                Box::new(MovePegCommand {
                    player: current_p,
                    from,
                    to: valid_to,
                    path: vec![],
                }),
            )
            .unwrap();
    }

    let final_turn = session
        .world()
        .resource::<TurnResource>()
        .0
        .current_player();
    assert_eq!(
        final_turn, P1,
        "Después de 6 movimientos, el turno debe volver a P1"
    );
}

#[test]
fn test_victoria_cuando_todas_las_fichas_llegan_al_triangulo_opuesto() {
    let mut session = new_chinese_checkers_session(SessionId(11), 1, vec![P1, P2]);
    let target = home_cells_b();
    let last_target = target[9];

    let from = chinese_checkers_game::position::DIRECTIONS
        .iter()
        .map(|&d| last_target.add(d))
        .find(|p| p.is_on_board() && !target.contains(p))
        .expect("debe haber una posición adyacente fuera de target");

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pegs.clear();
        for pos in &target[0..9] {
            board.pegs.insert(*pos, P1);
        }
        board.pegs.insert(from, P1);
    }

    let events = session
        .process_command(
            P1,
            Box::new(MovePegCommand {
                player: P1,
                from,
                to: last_target,
                path: vec![],
            }),
        )
        .expect("el movimiento hacia el último casillero del triángulo opuesto debe ser válido");

    assert!(
        events.iter().any(|e| {
            if let Some(go) = e.as_any().downcast_ref::<GameOverEvent>() {
                go.winner == Some(P1)
            } else {
                false
            }
        }),
        "debe emitirse GameOverEvent con winner = Some(P1)"
    );
}

#[test]
fn test_cadena_de_tres_saltos_consecutivos() {
    let mut session = new_chinese_checkers_session(SessionId(12), 1, vec![P1, P2]);

    let start = Position::new(0, 0);
    let peg1 = Position::new(1, 0);
    let landing1 = Position::new(2, 0);
    let peg2 = Position::new(3, 0);
    let landing2 = Position::new(4, 0);
    let peg3 = Position::new(4, -1);
    let landing3 = Position::new(4, -2);

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pegs.clear();
        board.pegs.insert(start, P1);
        board.pegs.insert(peg1, P2);
        board.pegs.insert(peg2, P2);
        board.pegs.insert(peg3, P2);
    }

    let events = session
        .process_command(
            P1,
            Box::new(MovePegCommand {
                player: P1,
                from: start,
                to: landing3,
                path: vec![landing1, landing2, landing3],
            }),
        )
        .expect("la cadena de 3 saltos debe ser válida");

    let moved = events[0].as_any().downcast_ref::<PegMovedEvent>().unwrap();
    assert!(moved.was_jump);
    assert_eq!(moved.from, start);
    assert_eq!(moved.to, landing3);

    let board = session.world().resource::<BoardResource>();
    assert_eq!(board.pegs.get(&landing3), Some(&P1));
    assert!(!board.pegs.contains_key(&start));
}

#[test]
fn test_tablero_tiene_exactamente_121_casillas_validas() {
    let mut count = 0;
    for q in -15..=15 {
        for r in -15..=15 {
            if Position::new(q, r).is_on_board() {
                count += 1;
            }
        }
    }
    assert_eq!(
        count, 121,
        "El tablero con las 6 puntas triangulares debe tener exactamente 121 casillas"
    );
}

#[test]
fn test_las_6_puntas_no_se_superponen_con_el_hexagono_central() {
    for corner in 0..6 {
        let cells = chinese_checkers_game::position::corner_cells(corner);
        assert_eq!(cells.len(), 10);
        for pos in cells {
            let in_central_hex = pos.q.abs().max(pos.r.abs()).max((pos.q + pos.r).abs())
                <= chinese_checkers_game::position::BOARD_RADIUS;
            assert!(
                !in_central_hex,
                "La casilla {:?} de la punta {} no debe pertenecer al hexágono central",
                pos, corner
            );
        }
    }
}

#[test]
fn test_regla_anti_bloqueo_home_camp_spoiling_otorga_victoria() {
    let mut session = new_chinese_checkers_session(SessionId(13), 1, vec![P1, P2]);
    let target = home_cells_b();
    let last_target = target[9];

    let from = chinese_checkers_game::position::DIRECTIONS
        .iter()
        .map(|&d| last_target.add(d))
        .find(|p| p.is_on_board() && !target.contains(p))
        .expect("debe haber una posición adyacente fuera de target");

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pegs.clear();
        // P2 deja una ficha rezagada bloqueando la punta de su propia casa (target[0] de P1)
        board.pegs.insert(target[0], P2);
        // P1 ya tiene 8 fichas dentro del triángulo objetivo
        for pos in &target[1..9] {
            board.pegs.insert(*pos, P1);
        }
        // Y la novena ficha de P1 está lista para entrar en la última casilla vacía (target[9])
        board.pegs.insert(from, P1);
    }

    let events = session
        .process_command(
            P1,
            Box::new(MovePegCommand {
                player: P1,
                from,
                to: last_target,
                path: vec![],
            }),
        )
        .expect("P1 debe poder ocupar la última casilla libre de su triángulo objetivo");

    assert!(
        events.iter().any(|e| {
            e.as_any()
                .downcast_ref::<GameOverEvent>()
                .is_some_and(|go| go.winner == Some(P1))
        }),
        "La regla anti-bloqueo (Home-Camp Spoiling) debe otorgar la victoria a P1 aunque P2 bloquee una casilla de la meta"
    );
    assert!(session.world().resource::<GameOverResource>().0);
    assert_eq!(session.world().resource::<WinnerResource>().0, Some(P1));
}

#[test]
fn test_resign_command_termina_la_partida_y_asigna_ganador() {
    let mut session = new_chinese_checkers_session(SessionId(14), 1, vec![P1, P2]);

    let events = session
        .process_command(P1, Box::new(ResignCommand { player: P1 }))
        .expect("ResignCommand debe ser válido para un jugador de la partida");

    assert!(
        events.iter().any(|e| {
            e.as_any()
                .downcast_ref::<GameOverEvent>()
                .is_some_and(|go| go.winner == Some(P2))
        }),
        "Al rendirse P1 debe ganar P2"
    );
    assert!(session.world().resource::<GameOverResource>().0);
    assert_eq!(session.world().resource::<WinnerResource>().0, Some(P2));
}

#[test]
fn test_chinese_checkers_legal_move_generator_lista_movimientos_del_turno_actual() {
    let session = new_chinese_checkers_session(SessionId(15), 1, vec![P1, P2]);
    let generator = ChineseCheckersLegalMoveGenerator;

    let moves_p1 = generator.legal_moves(session.world(), P1);
    assert!(
        !moves_p1.is_empty(),
        "El jugador en turno (P1) debe tener movimientos legales iniciales"
    );

    let moves_p2 = generator.legal_moves(session.world(), P2);
    assert!(
        moves_p2.is_empty(),
        "El jugador fuera de turno (P2) no debe tener movimientos legales"
    );

    let via_engine = session.rules().legal_moves(session.world(), P1);
    assert_eq!(via_engine.len(), moves_p1.len());
}
