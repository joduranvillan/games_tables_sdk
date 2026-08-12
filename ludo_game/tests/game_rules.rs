use ludo_game::{
    new_ludo_session, GameOverEvent, MoveTokenCommand, NoValidMovesEvent, RollDiceCommand,
    TokenMovedEvent, MAX_STEPS,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const P3: PlayerId = PlayerId(3);

fn roll(session: &mut Session, player: PlayerId) -> u32 {
    let events = session
        .process_command(player, Box::new(RollDiceCommand { player }))
        .expect("tirar el dado debería funcionar");
    events[0]
        .as_any()
        .downcast_ref::<ludo_game::DiceRolledEvent>()
        .unwrap()
        .value
}

fn move_token(
    session: &mut Session,
    player: PlayerId,
    token_index: usize,
) -> Result<Vec<Box<dyn Event>>, EngineError> {
    session.process_command(
        player,
        Box::new(MoveTokenCommand {
            player,
            token_index,
        }),
    )
}

#[test]
fn soporta_mas_de_dos_jugadores() {
    let session = new_ludo_session(SessionId(1), 1, vec![P1, P2, P3]);
    assert_eq!(session.current_player(), P1);
}

#[test]
fn no_se_puede_mover_sin_tirar_primero() {
    let mut session = new_ludo_session(SessionId(2), 1, vec![P1, P2]);
    let result = move_token(&mut session, P1, 0);
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn una_ficha_en_la_base_solo_entra_con_un_6() {
    // Buscamos una seed donde la primera tirada de P1 NO sea 6, para
    // probar el rechazo, y confirmamos el mensaje de error.
    let mut session = new_ludo_session(SessionId(3), 2, vec![P1, P2]);
    let value = roll(&mut session, P1);
    let result = move_token(&mut session, P1, 0);
    if value == 6 {
        assert!(result.is_ok(), "con un 6 la ficha debería poder entrar");
    } else {
        assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
    }
}

#[test]
fn sacar_un_6_da_turno_extra_y_no_avanza_el_turno() {
    // Probamos con varias seeds hasta encontrar una que dé un 6 en la
    // primera tirada de P1 (el test es determinista una vez fijada la
    // seed, solo probamos varias para no depender de conocer de memoria
    // cuál seed da 6 con esta implementación de ChaCha8).
    for seed in 0..50u64 {
        let mut session = new_ludo_session(SessionId(4), seed, vec![P1, P2]);
        let value = roll(&mut session, P1);
        if value != 6 {
            continue;
        }
        move_token(&mut session, P1, 0).expect("entra con el 6");
        assert_eq!(session.current_player(), P1, "un 6 da turno extra");
        return;
    }
    panic!("ninguna seed de las probadas dio un 6 en la primera tirada, ajustar el rango");
}

#[test]
fn pisar_una_ficha_rival_la_manda_de_vuelta_a_la_base() {
    // Con 2 jugadores, TRACK_LEN=24, start_offset[P1]=0, start_offset[P2]=12.
    // Si P1 avanza a steps=12, su posición absoluta es (0+12-1)%24 = 11.
    // Para que P2 esté en esa misma celda absoluta, necesita
    // (12+steps-1)%24 == 11, que se cumple con steps=24 ((12+24-1)%24=35%24=11).
    let mut session = new_ludo_session(SessionId(5), 1, vec![P1, P2]);
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        tokens.tokens.get_mut(&P1).unwrap()[0] = 11; // a un paso de la colisión
        tokens.tokens.get_mut(&P2).unwrap()[0] = 24; // en la misma celda absoluta que P1 tras +1
    }
    {
        let mut pending = session
            .world_mut()
            .resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P1, 1);
    }

    let events = move_token(&mut session, P1, 0).expect("mueve y captura");
    let moved = events[0]
        .as_any()
        .downcast_ref::<TokenMovedEvent>()
        .unwrap();
    assert_eq!(moved.captured, Some((P2, 0)));

    let tokens = session.world().resource::<ludo_game::TokensResource>();
    assert_eq!(
        tokens.tokens[&P2][0], 0,
        "la ficha capturada vuelve a la base"
    );
}

#[test]
fn llegar_con_las_4_fichas_a_destino_termina_la_partida() {
    let mut session = new_ludo_session(SessionId(6), 1, vec![P1, P2]);
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        // 3 fichas ya en la meta, la 4ta a un paso.
        tokens.tokens.get_mut(&P1).unwrap()[0] = MAX_STEPS;
        tokens.tokens.get_mut(&P1).unwrap()[1] = MAX_STEPS;
        tokens.tokens.get_mut(&P1).unwrap()[2] = MAX_STEPS;
        tokens.tokens.get_mut(&P1).unwrap()[3] = MAX_STEPS - 1;
    }
    {
        let mut pending = session
            .world_mut()
            .resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P1, 1);
    }

    let events = move_token(&mut session, P1, 3).expect("mueve la última ficha a destino");
    assert!(events.iter().any(|e| e
        .as_any()
        .downcast_ref::<GameOverEvent>()
        .map(|go| go.winner)
        == Some(P1)));
}

#[test]
fn sin_movimientos_validos_limpia_tirada_y_pasa_turno() {
    let mut session = new_ludo_session(SessionId(7), 2, vec![P1, P2]);
    // P1 tiene todas las fichas en la base. Si tira algo distinto de 6, no tiene movimientos.
    let events = session
        .process_command(P1, Box::new(RollDiceCommand { player: P1 }))
        .expect("tirada procesada");

    let roll_val = events[0]
        .as_any()
        .downcast_ref::<ludo_game::DiceRolledEvent>()
        .unwrap()
        .value;

    if roll_val != 6 {
        assert_eq!(events.len(), 2);
        let no_moves = events[1]
            .as_any()
            .downcast_ref::<NoValidMovesEvent>()
            .unwrap();
        assert_eq!(no_moves.value, roll_val);
        // Debe haber pasado el turno automáticamente a P2
        assert_eq!(session.current_player(), P2);
    }
}

#[test]
fn casilla_segura_de_salida_evita_captura() {
    let mut session = new_ludo_session(SessionId(8), 1, vec![P1, P2]);
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        // P2 está en su casilla de salida (steps=1). start_offset[P2]=12. board_position(P2, 1) = 12.
        tokens.tokens.get_mut(&P2).unwrap()[0] = 1;
        // P1 aterriza en la misma casilla 12 (con start_offset[P1]=0, necesita steps=13 para board_position=12).
        tokens.tokens.get_mut(&P1).unwrap()[0] = 12;
    }
    {
        let mut pending = session
            .world_mut()
            .resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P1, 1);
    }

    let events = move_token(&mut session, P1, 0).expect("mueve a casilla de salida de P2");
    let moved = events[0]
        .as_any()
        .downcast_ref::<TokenMovedEvent>()
        .unwrap();
    assert_eq!(
        moved.captured, None,
        "en casilla de salida segura no se captura"
    );

    let tokens = session.world().resource::<ludo_game::TokensResource>();
    assert_eq!(
        tokens.tokens[&P2][0], 1,
        "la ficha de P2 no fue enviada a la base"
    );
}

#[test]
fn test_token_no_puede_entrar_en_columna_de_casa_rival() {
    let mut session = new_ludo_session(SessionId(9), 1, vec![P1, P2]);
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        // P1 tiene una ficha en su columna de casa (steps = 25).
        tokens.tokens.get_mut(&P1).unwrap()[0] = 25;
        // P2 está en la casilla compartida 23 (steps = 12 para P2 ya que start_offset[P2]=12).
        tokens.tokens.get_mut(&P2).unwrap()[0] = 12;
    }
    // Avanzar el turno a P2 para que sea su turno
    {
        let mut turn = session.world_mut().resource_mut::<TurnResource>();
        turn.0.advance();
    }
    {
        let mut pending = session
            .world_mut()
            .resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P2, 1);
    }

    let events = move_token(&mut session, P2, 0).expect("mueve en el tramo compartido");
    let moved = events[0]
        .as_any()
        .downcast_ref::<TokenMovedEvent>()
        .unwrap();
    // La ficha de P2 pasa a steps = 13 (posición absoluta 0 del tramo compartido), NO a la columna de casa de P1
    assert_eq!(moved.to_steps, 13);
    let tokens = session.world().resource::<ludo_game::TokensResource>();
    assert_eq!(tokens.board_position(P2, 13), Some(0));
    assert_eq!(
        tokens.tokens[&P1][0], 25,
        "la ficha de P1 en su columna de casa permanece intacta"
    );
}

#[test]
fn test_dado_mayor_que_casillas_restantes_en_meta_es_invalido() {
    let mut session = new_ludo_session(SessionId(10), 1, vec![P1, P2]);
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        // Colocar ficha a 2 casillas de la meta: MAX_STEPS = 29, así que steps = 27 (faltan 2)
        tokens.tokens.get_mut(&P1).unwrap()[0] = MAX_STEPS - 2;
    }
    {
        let mut pending = session
            .world_mut()
            .resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P1, 3);
    }

    let result = move_token(&mut session, P1, 0);
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "un movimiento con dado mayor que las casillas restantes a la meta debe fallar"
    );
}

#[test]
fn test_bloqueo_impide_que_rival_aterrice_en_casilla() {
    let mut session = new_ludo_session(SessionId(11), 1, vec![P1, P2]);
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        // P1 tiene dos fichas en la casilla de posición absoluta 10 (steps = 11 para P1).
        tokens.tokens.get_mut(&P1).unwrap()[0] = 11;
        tokens.tokens.get_mut(&P1).unwrap()[1] = 11;
        // P2 tiene una ficha en posición absoluta 8 (steps = 21 para P2, ya que (12 + 21 - 1)%24 = 32%24 = 8).
        tokens.tokens.get_mut(&P2).unwrap()[0] = 21;
    }
    // Dar turno a P2
    {
        let mut turn = session.world_mut().resource_mut::<TurnResource>();
        turn.0.advance();
    }
    {
        let mut pending = session
            .world_mut()
            .resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P2, 2); // intenta aterrizar en la casilla 10 con un bloqueo
    }

    let result = move_token(&mut session, P2, 0);
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "no se puede aterrizar en una casilla con un bloqueo rival"
    );
}

#[test]
fn test_seleccion_de_token_invalido_es_rechazada() {
    let mut session = new_ludo_session(SessionId(12), 1, vec![P1, P2]);
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        // P1 tiene la ficha 0 en el tablero (steps = 1) y la ficha 1 en la base (steps = 0).
        tokens.tokens.get_mut(&P1).unwrap()[0] = 1;
        tokens.tokens.get_mut(&P1).unwrap()[1] = 0;
    }
    {
        let mut pending = session
            .world_mut()
            .resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P1, 2); // Dado 2: válido para ficha 0, pero inválido para ficha 1 en base
    }

    // Seleccionar ficha 1 (que está en base y requiere un 6)
    let result = move_token(&mut session, P1, 1);
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "seleccionar un token que no tiene movimiento válido debe ser rechazado"
    );
}

#[test]
fn ludo_de_4_jugadores_hasta_victoria() {
    let p1 = PlayerId(1);
    let p2 = PlayerId(2);
    let p3 = PlayerId(3);
    let p4 = PlayerId(4);
    let players = vec![p1, p2, p3, p4];
    let mut session = new_ludo_session(SessionId(100), 42, players.clone());

    // Posicionar las fichas de P1 a pocos pasos de la meta (MAX_STEPS = 29)
    {
        let mut tokens = session
            .world_mut()
            .resource_mut::<ludo_game::TokensResource>();
        tokens.tokens.get_mut(&p1).unwrap()[0] = MAX_STEPS - 2;
        tokens.tokens.get_mut(&p1).unwrap()[1] = MAX_STEPS - 2;
        tokens.tokens.get_mut(&p1).unwrap()[2] = MAX_STEPS - 2;
        tokens.tokens.get_mut(&p1).unwrap()[3] = MAX_STEPS - 2;
    }

    let mut game_over_emitted = false;
    let mut turn_sequence = Vec::new();
    let mut max_turns = 2000;

    while !game_over_emitted && max_turns > 0 {
        max_turns -= 1;
        let current = session.current_player();

        if turn_sequence.last() != Some(&current) {
            turn_sequence.push(current);
        }

        let roll_events = session
            .process_command(current, Box::new(RollDiceCommand { player: current }))
            .expect("tirada de dado");

        if roll_events
            .iter()
            .any(|e| e.as_any().is::<NoValidMovesEvent>())
        {
            continue;
        }

        for token_idx in 0..4 {
            let res = session.process_command(
                current,
                Box::new(MoveTokenCommand {
                    player: current,
                    token_index: token_idx,
                }),
            );

            if let Ok(evts) = res {
                if evts.iter().any(|e| {
                    e.as_any()
                        .downcast_ref::<GameOverEvent>()
                        .map(|go| go.winner)
                        == Some(p1)
                }) {
                    game_over_emitted = true;
                }
                break;
            }
        }
    }

    assert!(
        game_over_emitted,
        "La partida debe terminar con la victoria de P1"
    );

    // Verificar que el ciclo de turnos respetó la secuencia (P1 -> P2 -> P3 -> P4 -> P1...)
    for window in turn_sequence.windows(2) {
        let prev = window[0];
        let curr = window[1];
        let prev_idx = players.iter().position(|&p| p == prev).unwrap();
        let expected_next = players[(prev_idx + 1) % players.len()];
        assert_eq!(
            curr, expected_next,
            "El orden de turnos debe ser secuencial P1 -> P2 -> P3 -> P4 -> P1"
        );
    }
}

#[test]
fn test_ludo_con_tres_jugadores_cicla_correctamente() {
    let players = vec![P1, P2, P3];
    let mut session = new_ludo_session(SessionId(20), 1, players.clone());
    assert_eq!(session.current_player(), P1);

    // Turn sequence advances P1 -> P2 -> P3 -> P1
    {
        let mut turn = session.world_mut().resource_mut::<TurnResource>();
        assert_eq!(turn.0.current_player(), P1);
        turn.0.advance();
        assert_eq!(turn.0.current_player(), P2);
        turn.0.advance();
        assert_eq!(turn.0.current_player(), P3);
        turn.0.advance();
        assert_eq!(turn.0.current_player(), P1);
    }
}

#[test]
fn test_esquinas_segun_numero_de_jugadores() {
    let s2 = new_ludo_session(SessionId(21), 1, vec![P1, P2]);
    let t2 = s2.world().resource::<ludo_game::TokensResource>();
    assert_eq!(t2.start_offset[&P1], 0);
    assert_eq!(t2.start_offset[&P2], 12);

    let s3 = new_ludo_session(SessionId(22), 1, vec![P1, P2, P3]);
    let t3 = s3.world().resource::<ludo_game::TokensResource>();
    assert_eq!(t3.start_offset[&P1], 0);
    assert_eq!(t3.start_offset[&P2], 8);
    assert_eq!(t3.start_offset[&P3], 16);

    let p4 = PlayerId(4);
    let s4 = new_ludo_session(SessionId(23), 1, vec![P1, P2, P3, p4]);
    let t4 = s4.world().resource::<ludo_game::TokensResource>();
    assert_eq!(t4.start_offset[&P1], 0);
    assert_eq!(t4.start_offset[&P2], 6);
    assert_eq!(t4.start_offset[&P3], 12);
    assert_eq!(t4.start_offset[&p4], 18);
}
