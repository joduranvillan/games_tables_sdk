use go_game::{
    new_go_session, BoardResource, ConfirmDeadCommand, GameOverEvent, MarkDeadCommand, PassCommand,
    PlaceStoneCommand, SetKomiCommand, Stone,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn canonical_puntuacion_con_komi_6_5_y_prisioneros() {
    let mut session = new_go_session(SessionId(518_3), 0, P1, P2);

    // Captura en vivo: Negro captura una piedra blanca en (0, 0)
    session
        .process_command(
            P1,
            Box::new(PlaceStoneCommand {
                player: P1,
                x: 1,
                y: 0,
            }),
        )
        .unwrap();
    session
        .process_command(
            P2,
            Box::new(PlaceStoneCommand {
                player: P2,
                x: 0,
                y: 0,
            }),
        )
        .unwrap();
    session
        .process_command(
            P1,
            Box::new(PlaceStoneCommand {
                player: P1,
                x: 0,
                y: 1,
            }),
        )
        .unwrap();

    // Configurar murallas simétricas y una piedra blanca muerta dentro del territorio negro en (1, 2)
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        assert_eq!(board.black_prisoners, 1);
        for y in 0..9 {
            board.set_stone(3, y, Some(Stone::Black));
            board.set_stone(5, y, Some(Stone::White));
        }
        board.set_stone(1, 2, Some(Stone::White));
    }

    // Ambos pasan para entrar a fase de puntuación
    session
        .process_command(P2, Box::new(PassCommand { player: P2 }))
        .unwrap();
    session
        .process_command(P1, Box::new(PassCommand { player: P1 }))
        .unwrap();

    // Marcar (1, 2) como piedra muerta y confirmar por ambos jugadores
    session
        .process_command(
            P1,
            Box::new(MarkDeadCommand {
                player: P1,
                positions: vec![(1, 2)],
            }),
        )
        .unwrap();
    session
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(ConfirmDeadCommand { player: P2 }))
        .unwrap();

    let board = session.world().resource::<BoardResource>();
    assert_eq!(board.black_prisoners, 2);

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debe emitirse GameOverEvent con puntuaciones finales");

    // Territorio Negro: 25 intersecciones vacías + 2 prisioneros = 27.0
    // Territorio Blanco: 27 intersecciones vacías + 0 prisioneros + 6.5 komi = 33.5
    assert!((game_over.black_score - 27.0).abs() < 1e-4);
    assert!((game_over.white_score - 33.5).abs() < 1e-4);
    assert_eq!(game_over.winner, Some(P2));
}

#[test]
fn canonical_set_komi_modifica_komi_antes_de_jugar() {
    let mut session = new_go_session(SessionId(518_4), 0, P1, P2);

    session
        .process_command(
            P1,
            Box::new(SetKomiCommand {
                player: P1,
                komi_half_points: 15, // 7.5 puntos
            }),
        )
        .expect("SetKomiCommand antes de colocar piedras debe ser válido");

    assert_eq!(
        session.world().resource::<BoardResource>().komi_half_points,
        15
    );
}

#[test]
fn canonical_rechazo_set_komi_tardio_y_marcado_antes_de_doble_pase() {
    let mut session = new_go_session(SessionId(518_201), 0, P1, P2);

    // Antes del doble pase, MarkDeadCommand y ConfirmDeadCommand deben rechazarse
    assert!(session
        .process_command(
            P1,
            Box::new(MarkDeadCommand {
                player: P1,
                positions: vec![(0, 0)],
            }),
        )
        .is_err());
    assert!(session
        .process_command(P1, Box::new(ConfirmDeadCommand { player: P1 }))
        .is_err());

    // Tras colocar una piedra en el tablero, SetKomiCommand debe rechazarse
    session
        .process_command(
            P1,
            Box::new(PlaceStoneCommand {
                player: P1,
                x: 4,
                y: 4,
            }),
        )
        .expect("primera piedra válida");

    assert!(session
        .process_command(
            P2,
            Box::new(SetKomiCommand {
                player: P2,
                komi_half_points: 11,
            }),
        )
        .is_err());
}
