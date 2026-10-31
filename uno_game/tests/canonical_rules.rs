use open_table_engine::prelude::*;
use uno_game::{
    new_uno_session, CallUnoCommand, Card, CardColor, CardValue, CatchUnoFailureCommand,
    ChallengeWildDrawFourCommand, InterceptCommand, InterceptedEvent, PlayCardCommand,
    UnoCalledEvent, UnoPenaltyEvent, UnoState, WildDrawFourChallengedEvent,
};

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn canonical_call_uno_y_catch_uno_failure() {
    let mut session = new_uno_session(SessionId(518_40), 0, vec![P1, P2]);

    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Number(1)));
        hand.push(Card::new(CardColor::Red, CardValue::Number(2)));
    }

    // P1 canta UNO con 2 cartas
    let ev_call = session
        .process_command(P1, Box::new(CallUnoCommand { player: P1 }))
        .expect("CallUnoCommand válido con 2 cartas");
    assert!(ev_call[0].as_any().is::<UnoCalledEvent>());

    // Si P1 tiene 1 carta pero NO cantó UNO, P2 lo penaliza con +2 cartas
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.uno_called.clear();
        let hand = state.hands.get_mut(&P1).unwrap();
        hand.clear();
        hand.push(Card::new(CardColor::Red, CardValue::Number(1)));
    }

    let ev_catch = session
        .process_command(
            P2,
            Box::new(CatchUnoFailureCommand {
                accuser: P2,
                target: P1,
            }),
        )
        .expect("CatchUnoFailureCommand debe penalizar a P1");
    let penalty = ev_catch[0]
        .as_any()
        .downcast_ref::<UnoPenaltyEvent>()
        .unwrap();
    assert_eq!(penalty.target, P1);
    assert_eq!(penalty.drawn, 2);
    assert_eq!(session.world().resource::<UnoState>().hands[&P1].len(), 3);
}

#[test]
fn canonical_challenge_wild_draw_four_bluff_y_legal() {
    // 1. Bluff ilegal: el infractor roba 4 y el retador mantiene turno
    let mut session = new_uno_session(SessionId(518_41), 0, vec![P1, P2]);
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.allow_bluff_wild_draw_four = true;
        state.active_color = CardColor::Red;
        let hand_p1 = state.hands.get_mut(&P1).unwrap();
        hand_p1.clear();
        hand_p1.push(Card::new(CardColor::Red, CardValue::Number(3)));
        hand_p1.push(Card::new(CardColor::WildColor, CardValue::WildDrawFour));
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
        .unwrap();

    let ev_bluff = session
        .process_command(
            P2,
            Box::new(ChallengeWildDrawFourCommand { challenger: P2 }),
        )
        .unwrap();
    let ch1 = ev_bluff[0]
        .as_any()
        .downcast_ref::<WildDrawFourChallengedEvent>()
        .unwrap();
    assert!(ch1.was_illegal);
    assert_eq!(ch1.penalty_player, P1);
    assert_eq!(ch1.cards_drawn, 4);
    assert_eq!(session.current_player(), P2);

    // 2. Jugada legal: el retador fallido roba 6 y pierde el turno
    let mut session2 = new_uno_session(SessionId(518_42), 0, vec![P1, P2]);
    {
        let mut state = session2.world_mut().resource_mut::<UnoState>();
        state.allow_bluff_wild_draw_four = true;
        state.active_color = CardColor::Red;
        let hand_p1 = state.hands.get_mut(&P1).unwrap();
        hand_p1.clear();
        hand_p1.push(Card::new(CardColor::Yellow, CardValue::Number(3)));
        hand_p1.push(Card::new(CardColor::WildColor, CardValue::WildDrawFour));
    }

    session2
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 1,
                chosen_color: Some(CardColor::Blue),
            }),
        )
        .unwrap();

    let ev_legal = session2
        .process_command(
            P2,
            Box::new(ChallengeWildDrawFourCommand { challenger: P2 }),
        )
        .unwrap();
    let ch2 = ev_legal[0]
        .as_any()
        .downcast_ref::<WildDrawFourChallengedEvent>()
        .unwrap();
    assert!(!ch2.was_illegal);
    assert_eq!(ch2.penalty_player, P2);
    assert_eq!(ch2.cards_drawn, 6);
    assert_eq!(session2.current_player(), P1);
}

#[test]
fn canonical_jump_in_intercept_carta_identica_y_rechazo_no_identica() {
    let mut session = new_uno_session(SessionId(518_210), 0, vec![P1, P2]);
    {
        let mut state = session.world_mut().resource_mut::<UnoState>();
        state.discard_pile = vec![Card::new(CardColor::Green, CardValue::Number(7))];
        state.active_color = CardColor::Green;
        let hand_p2 = state.hands.get_mut(&P2).unwrap();
        hand_p2.clear();
        hand_p2.push(Card::new(CardColor::Green, CardValue::Number(5)));
        hand_p2.push(Card::new(CardColor::Green, CardValue::Number(7)));
        hand_p2.push(Card::new(CardColor::Blue, CardValue::Number(1)));
    }

    // CallUnoCommand con 3 cartas debe rechazarse
    assert!(session
        .process_command(P2, Box::new(CallUnoCommand { player: P2 }))
        .is_err());

    // InterceptCommand con carta de distinto valor (Green 5 vs Green 7) se rechaza
    assert!(session
        .process_command(
            P2,
            Box::new(InterceptCommand {
                player: P2,
                card_index: 0,
            }),
        )
        .is_err());

    // InterceptCommand fuera de turno con carta idéntica (Green 7) tiene éxito y emite InterceptedEvent
    let ev_int = session
        .process_command(
            P2,
            Box::new(InterceptCommand {
                player: P2,
                card_index: 1,
            }),
        )
        .expect("Jump-In con carta exactamente idéntica debe aceptarse");
    assert!(ev_int[0].as_any().is::<InterceptedEvent>());
}

