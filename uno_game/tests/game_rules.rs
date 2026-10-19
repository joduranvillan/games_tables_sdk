use open_table_engine::prelude::*;
use uno_game::{
    new_uno_session, CallUnoCommand, Card, CardColor, CardValue, CatchUnoFailureCommand,
    ChallengeWildDrawFourCommand, DrawCardCommand, DrewAndPlayedEvent, InterceptCommand,
    InterceptedEvent, PlayCardCommand, UnoCalledEvent, UnoPenaltyEvent, UnoState,
    WildDrawFourChallengedEvent,
};

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const P3: PlayerId = PlayerId(3);

#[test]
fn test_play_and_skip() {
    let mut session = new_uno_session(SessionId(1), 0, vec![P1, P2, P3]);

    // Manipulate state to force a playable card
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(5)));

        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Skip)); // Playable skip
        hand.push(Card::new(CardColor::Blue, CardValue::Number(1)));
    }

    let events = session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
                chosen_color: None,
            }),
        )
        .unwrap();

    let skipped = events
        .iter()
        .any(|e| e.as_any().is::<uno_game::PlayerSkippedEvent>());
    assert!(skipped, "P2 should be skipped");

    assert_eq!(
        session
            .world()
            .resource::<TurnResource>()
            .0
            .current_player(),
        P3
    );
}

#[test]
fn test_stacking_draw_two() {
    let mut session = new_uno_session(SessionId(2), 0, vec![P1, P2, P3]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(5)));

        state
            .hands
            .get_mut(&P1)
            .unwrap()
            .insert(0, Card::new(CardColor::Red, CardValue::DrawTwo));
        state
            .hands
            .get_mut(&P2)
            .unwrap()
            .insert(0, Card::new(CardColor::Blue, CardValue::DrawTwo));
    }

    // P1 plays DrawTwo
    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
                chosen_color: None,
            }),
        )
        .unwrap();

    assert_eq!(
        session
            .world()
            .resource::<TurnResource>()
            .0
            .current_player(),
        P2
    );
    assert_eq!(session.world().resource::<UnoState>().draw_penalty, 2);

    // P2 stacks DrawTwo
    session
        .process_command(
            P2,
            Box::new(PlayCardCommand {
                player: P2,
                card_index: 0,
                chosen_color: None,
            }),
        )
        .unwrap();

    assert_eq!(
        session
            .world()
            .resource::<TurnResource>()
            .0
            .current_player(),
        P3
    );
    assert_eq!(session.world().resource::<UnoState>().draw_penalty, 4);

    let initial_deck_len = session.world().resource::<UnoState>().deck.len();

    // P3 has no DrawTwo, draws 4 cards
    let _events = session
        .process_command(P3, Box::new(DrawCardCommand { player: P3 }))
        .unwrap();

    let state = session.world().resource::<UnoState>();
    assert_eq!(state.draw_penalty, 0);
    assert_eq!(state.deck.len(), initial_deck_len - 4);

    assert_eq!(
        session
            .world()
            .resource::<TurnResource>()
            .0
            .current_player(),
        P1
    );
}

#[test]
fn test_wild_draw_four_ilegal_si_tienes_carta_del_color() {
    let mut session = new_uno_session(SessionId(10), 0, vec![P1, P2]);

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
        "Jugar WildDrawFour teniendo una carta del color activo debe ser rechazado"
    );
}

#[test]
fn test_reversa_es_skip_en_dos_jugadores() {
    let mut session = new_uno_session(SessionId(11), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(5)));

        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Reverse));
        hand.push(Card::new(CardColor::Blue, CardValue::Number(1)));
    }

    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
                chosen_color: None,
            }),
        )
        .unwrap();

    assert_eq!(session.current_player(), P1);
}

#[test]
fn test_robar_cuando_no_hay_jugada_avanza_el_turno_o_juega_inmediatamente() {
    let mut session = new_uno_session(SessionId(12), 0, vec![P1, P2]);

    // Scenario A: Drawn card is not playable -> turn advances to P2, card stays in hand
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(5)));

        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Blue, CardValue::Number(1)));

        state.deck.clear();
        state
            .deck
            .push(Card::new(CardColor::Green, CardValue::Number(2)));
    }

    let events = session
        .process_command(P1, Box::new(DrawCardCommand { player: P1 }))
        .unwrap();

    assert_eq!(session.current_player(), P2);
    let state = session.world().resource::<UnoState>();
    assert_eq!(state.hands.get(&P1).unwrap().len(), 2);
    assert!(events
        .iter()
        .any(|e| e.as_any().is::<uno_game::CardsDrawnEvent>()));

    // Reset turn back to P1
    session
        .world_mut()
        .resource_mut::<TurnResource>()
        .0
        .advance();
    assert_eq!(session.current_player(), P1);

    // Scenario B: Drawn card is playable -> played immediately emitting DrewAndPlayedEvent
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(5)));

        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Blue, CardValue::Number(1)));

        state.deck.clear();
        state
            .deck
            .push(Card::new(CardColor::Red, CardValue::Number(8)));
    }

    let events = session
        .process_command(P1, Box::new(DrawCardCommand { player: P1 }))
        .unwrap();

    assert!(events.iter().any(|e| e.as_any().is::<DrewAndPlayedEvent>()));
    assert_eq!(session.current_player(), P2);
}

#[test]
fn test_mazo_agotado_se_remezcla_desde_descarte() {
    let mut session = new_uno_session(SessionId(13), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state.deck.clear();

        state.discard_pile = vec![
            Card::new(CardColor::Green, CardValue::Number(1)),
            Card::new(CardColor::Green, CardValue::Number(2)),
            Card::new(CardColor::Green, CardValue::Number(3)),
            Card::new(CardColor::Green, CardValue::Number(4)),
            Card::new(CardColor::Red, CardValue::Number(5)),
        ];

        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Blue, CardValue::Number(1)));
    }

    session
        .process_command(P1, Box::new(DrawCardCommand { player: P1 }))
        .unwrap();

    let state = session.world().resource::<UnoState>();
    assert_eq!(
        state.deck.len(),
        3,
        "El mazo debe tener 3 cartas (5 en descarte - 1 top en descarte - 1 robada = 3)"
    );
    assert_eq!(
        state.discard_pile.len(),
        1,
        "El descarte debe mantener 1 carta (la carta superior)"
    );
}

#[test]
fn test_mazo_y_descarte_agotados_no_produce_panic() {
    let mut session = new_uno_session(SessionId(20), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.deck.clear();
        state.discard_pile.clear();
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(5)));
    }

    let result = session.process_command(P1, Box::new(DrawCardCommand { player: P1 }));
    assert!(
        result.is_ok(),
        "robar cuando el mazo y el descarte están agotados no debe producir panic"
    );
}

#[test]
fn test_intercepcion_valida_con_carta_identica() {
    let mut session = new_uno_session(SessionId(30), 0, vec![P1, P2, P3]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(7)));

        let hand_p3 = state.hands.get_mut(&P3).unwrap();
        hand_p3.clear();
        hand_p3.push(Card::new(CardColor::Red, CardValue::Number(7)));
        hand_p3.push(Card::new(CardColor::Blue, CardValue::Number(1)));
    }

    // It is P1's turn, but P3 intercepts out of order with identical card (Red 7)
    assert_eq!(session.current_player(), P1);

    let events = session
        .process_command(
            P3,
            Box::new(InterceptCommand {
                player: P3,
                card_index: 0,
            }),
        )
        .unwrap();

    let intercepted = events.iter().any(|e| e.as_any().is::<InterceptedEvent>());
    assert!(
        intercepted,
        "InterceptedEvent debe ser emitido tras intercepción válida"
    );

    // After P3 intercepts with regular card (Red 7), turn continues from P3 in normal direction -> P1
    assert_eq!(session.current_player(), P1);

    let state = session.world().resource::<UnoState>();
    assert_eq!(state.hands.get(&P3).unwrap().len(), 1);
    assert_eq!(
        state.discard_pile.last(),
        Some(&Card::new(CardColor::Red, CardValue::Number(7)))
    );
}

#[test]
fn test_intercepcion_invalida_con_carta_similar_pero_diferente_color() {
    let mut session = new_uno_session(SessionId(31), 0, vec![P1, P2, P3]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.active_color = CardColor::Red;
        state
            .discard_pile
            .push(Card::new(CardColor::Red, CardValue::Number(7)));

        let hand_p3 = state.hands.get_mut(&P3).unwrap();
        hand_p3.clear();
        hand_p3.push(Card::new(CardColor::Blue, CardValue::Number(7))); // Similar value, different color
    }

    let result = session.process_command(
        P3,
        Box::new(InterceptCommand {
            player: P3,
            card_index: 0,
        }),
    );

    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "Intercepción con carta de distinto color debe ser rechazada"
    );
}

#[test]
fn test_call_uno_con_una_o_dos_cartas_exito() {
    let mut session = new_uno_session(SessionId(521), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Number(1)));
        hand.push(Card::new(CardColor::Red, CardValue::Number(2)));
    }

    // P1 con 2 cartas canta UNO
    let events = session
        .process_command(P1, Box::new(CallUnoCommand { player: P1 }))
        .expect("debe permitir cantar UNO con 2 cartas");
    assert_eq!(events.len(), 1);
    assert!(events[0].as_any().is::<UnoCalledEvent>());
    assert!(session.world().resource::<UnoState>().uno_called.contains(&P1));

    // Ahora con 1 carta
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.uno_called.clear();
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.pop();
    }
    let events = session
        .process_command(P1, Box::new(CallUnoCommand { player: P1 }))
        .expect("debe permitir cantar UNO con 1 carta");
    assert_eq!(events.len(), 1);
    assert!(session.world().resource::<UnoState>().uno_called.contains(&P1));
}

#[test]
fn test_call_uno_con_mas_de_dos_cartas_falla() {
    let mut session = new_uno_session(SessionId(522), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Number(1)));
        hand.push(Card::new(CardColor::Red, CardValue::Number(2)));
        hand.push(Card::new(CardColor::Red, CardValue::Number(3)));
    }

    let err = session
        .process_command(P1, Box::new(CallUnoCommand { player: P1 }))
        .unwrap_err();
    assert!(err.to_string().contains("1 or 2"));
}

#[test]
fn test_catch_uno_failure_penaliza_dos_cartas() {
    let mut session = new_uno_session(SessionId(523), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Number(1)));
        state.uno_called.clear();
    }

    // P2 acusa a P1 por no cantar UNO
    let events = session
        .process_command(
            P2,
            Box::new(CatchUnoFailureCommand {
                accuser: P2,
                target: P1,
            }),
        )
        .expect("debe permitir acusar si target tiene 1 carta y no cantó UNO");

    assert_eq!(events.len(), 2);
    let penalty = events[0].as_any().downcast_ref::<UnoPenaltyEvent>().unwrap();
    assert_eq!(penalty.target, P1);
    assert_eq!(penalty.accuser, P2);
    assert_eq!(penalty.drawn, 2);

    // P1 ahora tiene 1 + 2 = 3 cartas
    let state = session.world().resource::<UnoState>();
    assert_eq!(state.hands[&P1].len(), 3);

    // Si P1 ya cantó UNO, acusar debe fallar
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Number(1)));
        state.uno_called.insert(P1);
    }
    let err = session
        .process_command(
            P2,
            Box::new(CatchUnoFailureCommand {
                accuser: P2,
                target: P1,
            }),
        )
        .unwrap_err();
    assert!(err.to_string().contains("already called UNO"));
}

#[test]
fn test_challenge_wild_draw_four_infractor_bluffeando() {
    let mut session = new_uno_session(SessionId(524), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.allow_bluff_wild_draw_four = true;
        state.active_color = CardColor::Red;
        let hand_p1 = state.hands.get_mut(&P1).unwrap();
        hand_p1.clear();
        // P1 tiene una carta roja (del color activo) y juega WildDrawFour ilegalmente (bluff)
        hand_p1.push(Card::new(CardColor::Red, CardValue::Number(3)));
        hand_p1.push(Card::new(CardColor::WildColor, CardValue::WildDrawFour));

        let hand_p2 = state.hands.get_mut(&P2).unwrap();
        hand_p2.clear();
        hand_p2.push(Card::new(CardColor::Blue, CardValue::Number(5)));
    }

    // P1 juega WildDrawFour eligiendo Azul
    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 1,
                chosen_color: Some(CardColor::Blue),
            }),
        )
        .expect("debe permitir jugar con allow_bluff_wild_draw_four");

    assert_eq!(session.world().resource::<TurnResource>().0.current_player(), P2);
    assert_eq!(session.world().resource::<UnoState>().draw_penalty, 4);
    assert!(session.world().resource::<UnoState>().wild_draw_four_illegal);

    // P2 desafía el WildDrawFour
    let events = session
        .process_command(
            P2,
            Box::new(ChallengeWildDrawFourCommand { challenger: P2 }),
        )
        .expect("desafío debe procesarse");

    let challenge_ev = events[0]
        .as_any()
        .downcast_ref::<WildDrawFourChallengedEvent>()
        .unwrap();
    assert_eq!(challenge_ev.challenger, P2);
    assert_eq!(challenge_ev.target, P1);
    assert!(challenge_ev.was_illegal);
    assert_eq!(challenge_ev.penalty_player, P1);
    assert_eq!(challenge_ev.cards_drawn, 4);

    let state = session.world().resource::<UnoState>();
    assert_eq!(state.draw_penalty, 0);
    // P1 tenía 1 carta y robó 4 -> 5 cartas
    assert_eq!(state.hands[&P1].len(), 5);
    // P2 mantiene su única carta
    assert_eq!(state.hands[&P2].len(), 1);
    // P2 mantiene su turno para jugar
    assert_eq!(session.world().resource::<TurnResource>().0.current_player(), P2);
}

#[test]
fn test_challenge_wild_draw_four_legal_retador_penalizado() {
    let mut session = new_uno_session(SessionId(525), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.allow_bluff_wild_draw_four = true;
        state.active_color = CardColor::Red;
        let hand_p1 = state.hands.get_mut(&P1).unwrap();
        hand_p1.clear();
        // P1 NO tiene cartas rojas: juega legalmente
        hand_p1.push(Card::new(CardColor::Yellow, CardValue::Number(3)));
        hand_p1.push(Card::new(CardColor::WildColor, CardValue::WildDrawFour));

        let hand_p2 = state.hands.get_mut(&P2).unwrap();
        hand_p2.clear();
        hand_p2.push(Card::new(CardColor::Blue, CardValue::Number(5)));
    }

    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 1,
                chosen_color: Some(CardColor::Blue),
            }),
        )
        .expect("jugada legal");

    assert!(!session.world().resource::<UnoState>().wild_draw_four_illegal);

    // P2 desafía erróneamente
    let events = session
        .process_command(
            P2,
            Box::new(ChallengeWildDrawFourCommand { challenger: P2 }),
        )
        .expect("desafío procesado");

    let challenge_ev = events[0]
        .as_any()
        .downcast_ref::<WildDrawFourChallengedEvent>()
        .unwrap();
    assert_eq!(challenge_ev.challenger, P2);
    assert_eq!(challenge_ev.target, P1);
    assert!(!challenge_ev.was_illegal);
    assert_eq!(challenge_ev.penalty_player, P2);
    assert_eq!(challenge_ev.cards_drawn, 6);

    let state = session.world().resource::<UnoState>();
    assert_eq!(state.draw_penalty, 0);
    // P2 tenía 1 carta y robó 6 -> 7 cartas
    assert_eq!(state.hands[&P2].len(), 7);
    // Turno avanza de vuelta a P1
    assert_eq!(session.world().resource::<TurnResource>().0.current_player(), P1);
}
