use open_table_engine::prelude::*;
use uno_game::{
    new_uno_session, Card, CardColor, CardValue, DrawCardCommand, DrewAndPlayedEvent,
    InterceptCommand, InterceptedEvent, PlayCardCommand, UnoState,
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
