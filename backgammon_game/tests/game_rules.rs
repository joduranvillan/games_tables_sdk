use backgammon_game::{
    new_backgammon_session, AcceptDoubleCommand, CheckerMovedEvent, DoublingCubeResource, GameOverEvent,
    MatchStateResource, MoveCheckerCommand, OfferDoubleCommand, RejectDoubleCommand, RollDiceCommand,
    CHECKERS_PER_PLAYER,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1); // increasing
const P2: PlayerId = PlayerId(2); // decreasing

fn force_roll(session: &mut Session, player: PlayerId, values: Vec<u32>) {
    session
        .world_mut()
        .resource_mut::<backgammon_game::PendingDiceResource>()
        .pending
        .insert(player, values);
}

#[test]
fn el_setup_inicial_tiene_15_fichas_por_jugador() {
    let session = new_backgammon_session(SessionId(1), 1, P1, P2);
    let board = session.world().resource::<backgammon_game::BoardResource>();
    let p1_count: i32 = board.points.iter().filter(|&&c| c > 0).sum();
    let p2_count: i32 = board.points.iter().filter(|&&c| c < 0).map(|c| -c).sum();
    assert_eq!(p1_count as u32, CHECKERS_PER_PLAYER);
    assert_eq!(p2_count as u32, CHECKERS_PER_PLAYER);
}

#[test]
fn tirar_los_dados_deja_dos_valores_pendientes() {
    let mut session = new_backgammon_session(SessionId(2), 1, P1, P2);
    let events = session
        .process_command(P1, Box::new(RollDiceCommand { player: P1 }))
        .expect("tirar debería funcionar");
    let rolled = events[0].as_any().downcast_ref::<backgammon_game::DiceRolledEvent>().unwrap();
    assert_eq!(rolled.values.len(), 2);

    let pending = session.world().resource::<backgammon_game::PendingDiceResource>();
    assert_eq!(pending.pending[&P1].len(), 2);
}

#[test]
fn mover_una_ficha_propia_usa_un_dado_y_la_desplaza() {
    let mut session = new_backgammon_session(SessionId(3), 1, P1, P2);
    force_roll(&mut session, P1, vec![3, 5]);

    // P1 tiene 2 fichas en el punto 0; movemos una con el dado 3 -> punto 3.
    let events = session
        .process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: Some(0), die: 3 }))
        .expect("el movimiento debería ser válido");
    let moved = events[0].as_any().downcast_ref::<CheckerMovedEvent>().unwrap();
    assert_eq!(moved.to, Some(3));

    let board = session.world().resource::<backgammon_game::BoardResource>();
    assert_eq!(board.points[0], 1);
    assert_eq!(board.points[3], 1);

    // Todavía queda el dado 5 pendiente, no debería haber pasado el turno.
    assert_eq!(session.current_player(), P1);
}

#[test]
fn pisar_un_blot_rival_lo_manda_a_la_barra() {
    let mut session = new_backgammon_session(SessionId(4), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<backgammon_game::BoardResource>();
        board.points = [0; backgammon_game::POINTS];
        board.points[0] = 1; // una ficha de P1
        board.points[3] = -1; // un blot solitario de P2
    }
    force_roll(&mut session, P1, vec![3, 6]);

    let events = session
        .process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: Some(0), die: 3 }))
        .expect("capturar el blot debería ser válido");
    let moved = events[0].as_any().downcast_ref::<CheckerMovedEvent>().unwrap();
    assert!(moved.captured_opponent);

    let board = session.world().resource::<backgammon_game::BoardResource>();
    assert_eq!(board.points[3], 1, "el punto ahora es de P1");
    assert_eq!(board.bar[&P2], 1, "la ficha de P2 va a la barra");
}

#[test]
fn con_fichas_en_la_barra_hay_que_entrar_antes_de_mover_otra_cosa() {
    let mut session = new_backgammon_session(SessionId(5), 1, P1, P2);
    session.world_mut().resource_mut::<backgammon_game::BoardResource>().bar.insert(P1, 1);
    force_roll(&mut session, P1, vec![2, 4]);

    let result = session.process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: Some(0), die: 2 }));
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));

    // Entrar desde la barra sí funciona: con el dado 2, entra al punto 1.
    let events = session
        .process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: None, die: 2 }))
        .expect("entrar desde la barra debería ser válido");
    let moved = events[0].as_any().downcast_ref::<CheckerMovedEvent>().unwrap();
    assert_eq!(moved.to, Some(1));

    let board = session.world().resource::<backgammon_game::BoardResource>();
    assert_eq!(board.bar[&P1], 0);
}

#[test]
fn sacar_las_15_fichas_termina_la_partida() {
    let mut session = new_backgammon_session(SessionId(6), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<backgammon_game::BoardResource>();
        board.points = [0; backgammon_game::POINTS];
        board.points[20] = 1; // última ficha de P1, ya en su cuadrante final
        board.borne_off.insert(P1, CHECKERS_PER_PLAYER - 1);
    }
    force_roll(&mut session, P1, vec![5, 1]);

    let events = session
        .process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: Some(20), die: 5 }))
        .expect("sacar la última ficha debería ser válido");

    assert!(events
        .iter()
        .any(|e| e.as_any().downcast_ref::<GameOverEvent>().map(|go| go.winner) == Some(P1)));
}

#[test]
fn dobles_en_la_barra_o_tablero_pueden_usar_hasta_4_dados() {
    let mut session = new_backgammon_session(SessionId(7), 1, P1, P2);
    force_roll(&mut session, P1, vec![4, 4, 4, 4]);

    let pending = session.world().resource::<backgammon_game::PendingDiceResource>();
    assert_eq!(pending.pending[&P1].len(), 4, "los dobles deben dar 4 dados");
}

#[test]
fn sin_movimientos_validos_pasa_el_turno() {
    let mut session = new_backgammon_session(SessionId(8), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<backgammon_game::BoardResource>();
        board.points = [0; backgammon_game::POINTS];
        // P1 tiene una ficha en la barra
        board.bar.insert(P1, 1);
        // P2 bloquea la entrada en los puntos 0, 1, 2, 3, 4, 5 (las casillas de entrada de P1)
        for i in 0..6 {
            board.points[i] = -2;
        }
    }

    // P1 intenta tirar los dados
    let events = session
        .process_command(P1, Box::new(RollDiceCommand { player: P1 }))
        .expect("tirada procesada");

    // Como no se puede mover, emite NoValidMovesEvent y pasa el turno a P2
    assert!(events
        .iter()
        .any(|e| e.as_any().downcast_ref::<backgammon_game::NoValidMovesEvent>().is_some()));
    assert_eq!(session.current_player(), P2);
}

#[test]
fn no_se_puede_sacar_ficha_con_dado_mayor_si_hay_fichas_mas_atras() {
    let mut session = new_backgammon_session(SessionId(9), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<backgammon_game::BoardResource>();
        board.points = [0; backgammon_game::POINTS];
        // P1 tiene ficha en el punto 18 y en el punto 22 (para P1, la meta es >23)
        board.points[18] = 1;
        board.points[22] = 1;
    }
    force_roll(&mut session, P1, vec![5, 2]);

    // Intentar sacar la ficha del punto 22 con un dado de 5 (distancia=2) cuando hay una ficha en el punto 18 (más atrás) debe fallar
    let res = session.process_command(
        P1,
        Box::new(MoveCheckerCommand {
            player: P1,
            from: Some(22),
            die: 5,
        }),
    );
    assert!(res.is_err());
}

#[test]
fn test_gammon_cuando_oponente_no_saco_ninguna_ficha() {
    let mut session = new_backgammon_session(SessionId(10), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<backgammon_game::BoardResource>();
        board.points = [0; backgammon_game::POINTS];
        board.points[20] = 1; // última ficha de P1
        board.borne_off.insert(P1, CHECKERS_PER_PLAYER - 1);
        board.borne_off.insert(P2, 0); // P2 no ha sacado ninguna ficha
    }
    force_roll(&mut session, P1, vec![5, 1]);

    let events = session
        .process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: Some(20), die: 5 }))
        .expect("sacar la última ficha debería ser válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería haber un GameOverEvent");

    assert_eq!(game_over.winner, P1);
    assert!(game_over.gammon, "debería ser victoria por Gammon");
    assert!(!game_over.backgammon, "no debería ser Backgammon si no hay fichas en home de P1 ni en la barra");
}

#[test]
fn test_backgammon_cuando_oponente_tiene_fichas_en_home_del_ganador() {
    let mut session = new_backgammon_session(SessionId(11), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<backgammon_game::BoardResource>();
        board.points = [0; backgammon_game::POINTS];
        board.points[20] = 1; // última ficha de P1 (home board de P1)
        board.points[19] = -1; // ficha de P2 atrapada en el home board de P1
        board.borne_off.insert(P1, CHECKERS_PER_PLAYER - 1);
        board.borne_off.insert(P2, 0); // P2 no ha sacado ninguna ficha
    }
    force_roll(&mut session, P1, vec![5, 1]);

    let events = session
        .process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: Some(20), die: 5 }))
        .expect("sacar la última ficha debería ser válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería haber un GameOverEvent");

    assert_eq!(game_over.winner, P1);
    assert!(game_over.gammon, "debería ser victoria por Gammon");
    assert!(game_over.backgammon, "debería ser victoria por Backgammon");
}

#[test]
fn test_doblar_y_rechazar_termina_la_partida_con_valor_actual() {
    let mut session = new_backgammon_session(SessionId(12), 1, P1, P2);

    // P1 ofrece doblar antes de tirar dados
    let events = session
        .process_command(P1, Box::new(OfferDoubleCommand { player: P1 }))
        .expect("ofrecer doblaje debería ser válido");
    assert_eq!(events.len(), 1);

    // P2 rechaza el doblaje
    let events = session
        .process_command(P2, Box::new(RejectDoubleCommand { player: P2 }))
        .expect("rechazar doblaje debería ser válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("al rechazar el doblaje debe terminar la partida");

    assert_eq!(game_over.winner, P1, "el oferente gana cuando el rival rechaza");
}

#[test]
fn test_crawford_rule_bloquea_dado_de_doblaje() {
    let mut session = new_backgammon_session(SessionId(13), 1, P1, P2);

    // Simular llegar a match_points - 1 (juego Crawford)
    {
        let mut match_state = session
            .world_mut()
            .resource_mut::<MatchStateResource>();
        match_state.match_points = 5;
        match_state.scores.insert(P1, 4);
        match_state.crawford_game = true;
    }

    // P1 intenta ofrecer doblaje durante un juego Crawford
    let result = session.process_command(P1, Box::new(OfferDoubleCommand { player: P1 }));

    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "OfferDoubleCommand debe fallar durante un juego Crawford"
    );
}

#[test]
fn test_sacar_ultima_ficha_emite_game_over_inmediatamente() {
    let mut session = new_backgammon_session(SessionId(50), 1, P1, P2);
    {
        let mut board = session
            .world_mut()
            .resource_mut::<backgammon_game::BoardResource>();
        board.points = [0; backgammon_game::POINTS];
        board.points[20] = 1; // última ficha de P1
        board.borne_off.insert(P1, CHECKERS_PER_PLAYER - 1);
    }
    force_roll(&mut session, P1, vec![5, 1]);

    let events = session
        .process_command(P1, Box::new(MoveCheckerCommand { player: P1, from: Some(20), die: 5 }))
        .expect("sacar la última ficha debería ser válido");

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("debería emitirse GameOverEvent inmediatamente en el mismo process_command");
    assert_eq!(game_over.winner, P1);
}

#[test]
fn test_ofrecer_doble_antes_de_mover_es_valido() {
    let mut session = new_backgammon_session(SessionId(101), 1, P1, P2);
    let events = session
        .process_command(P1, Box::new(OfferDoubleCommand { player: P1 }))
        .expect("ofrecer doble antes de mover debe ser válido");
    assert_eq!(events.len(), 1);
    assert!(session.world().resource::<DoublingCubeResource>().offered);
}

#[test]
fn test_rechazar_doble_termina_la_partida() {
    let mut session = new_backgammon_session(SessionId(102), 1, P1, P2);
    session
        .process_command(P1, Box::new(OfferDoubleCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(RejectDoubleCommand { player: P2 }))
        .expect("rechazar doble debe ser válido");
    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("al rechazar el doble debe terminar la partida");
    assert_eq!(game_over.winner, P1);
    assert_eq!(game_over.score, 1);
}

#[test]
fn test_aceptar_doble_duplica_el_cubo() {
    let mut session = new_backgammon_session(SessionId(103), 1, P1, P2);
    session
        .process_command(P1, Box::new(OfferDoubleCommand { player: P1 }))
        .unwrap();
    let events = session
        .process_command(P2, Box::new(AcceptDoubleCommand { player: P2 }))
        .expect("aceptar doble debe ser válido");
    assert_eq!(events.len(), 1);
    let cube = session.world().resource::<DoublingCubeResource>();
    assert_eq!(cube.value, 2);
    assert_eq!(cube.owner, Some(P2));
    assert!(!cube.offered);
}


