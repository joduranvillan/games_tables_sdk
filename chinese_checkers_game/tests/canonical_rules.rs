use chinese_checkers_game::{
    home_cells_b, new_chinese_checkers_session, BoardResource, GameOverEvent, MovePegCommand,
    Position,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn canonical_victoria_anti_bloqueo_en_punta_de_meta() {
    let mut session = new_chinese_checkers_session(SessionId(518_8), 1, vec![P1, P2]);
    let target = home_cells_b();
    let last_target = target[9];

    let from = chinese_checkers_game::position::DIRECTIONS
        .iter()
        .map(|&d| last_target.add(d))
        .find(|p| p.is_on_board() && !target.contains(p))
        .expect("debe existir una casilla adyacente fuera del triángulo de meta");

    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pegs.clear();
        // P2 deja una ficha rezagada bloqueando una casilla de la punta objetivo de P1
        board.pegs.insert(target[0], P2);
        // P1 ocupa 8 de las 9 casillas restantes
        for pos in &target[1..9] {
            board.pegs.insert(*pos, P1);
        }
        // Y la última ficha necesaria de P1 está a un paso de llenar la única casilla libre del triángulo
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
        .expect("P1 debe poder entrar en la última casilla libre de su triángulo objetivo");

    let go = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debe emitirse GameOverEvent por regla anti-bloqueo (Home-Camp Spoiling)");
    assert_eq!(go.winner, Some(P1));
    assert!(session.world().resource::<GameOverResource>().0);
    assert_eq!(session.world().resource::<WinnerResource>().0, Some(P1));
}

#[test]
fn canonical_cadena_de_saltos_multiples_y_rechazo_salto_invalido() {
    let mut session = new_chinese_checkers_session(SessionId(518_204), 1, vec![P1, P2]);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.pegs.clear();
        board.pegs.insert(Position::new(0, 0), P1);
        board.pegs.insert(Position::new(1, 0), P2);
        board.pegs.insert(Position::new(3, 0), P2);
        board.pegs.insert(Position::new(0, 4), P2);
    }

    // Salto doble falso sin pivote intermedio en (0, 1) -> rechazado
    assert!(session
        .process_command(
            P1,
            Box::new(MovePegCommand {
                player: P1,
                from: Position::new(0, 0),
                to: Position::new(0, 2),
                path: vec![Position::new(0, 2)],
            }),
        )
        .is_err());

    // Cadena de 2 saltos válidos: (0,0) -> (2,0) sobre (1,0), y (2,0) -> (4,0) sobre (3,0)
    session
        .process_command(
            P1,
            Box::new(MovePegCommand {
                player: P1,
                from: Position::new(0, 0),
                to: Position::new(4, 0),
                path: vec![Position::new(2, 0), Position::new(4, 0)],
            }),
        )
        .expect("cadena de saltos múltiples con pivotes válidos debe aceptarse");
    assert_eq!(
        session
            .world()
            .resource::<BoardResource>()
            .pegs
            .get(&Position::new(4, 0)),
        Some(&P1)
    );
}
