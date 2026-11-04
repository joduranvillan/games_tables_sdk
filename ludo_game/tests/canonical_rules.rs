use ludo_game::{
    new_ludo_session, ConsecutiveSixesResource, DiceRolledEvent, MoveTokenCommand,
    NoValidMovesEvent, PendingRollResource, RollDiceCommand, SetLudoRulesCommand, TokenMovedEvent,
    TokensResource, MAX_STEPS, TRACK_LEN,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn canonical_tres_seises_seguidos_pierde_turno() {
    let mut session = new_ludo_session(SessionId(518_12), 1, vec![P1, P2]);
    session
        .process_command(
            P1,
            Box::new(SetLudoRulesCommand {
                star_safe_squares: true,
                bonus_roll_on_capture_and_goal: true,
                three_sixes_penalty: true,
            }),
        )
        .unwrap();

    session
        .world_mut()
        .resource_mut::<ConsecutiveSixesResource>()
        .count
        .insert(P1, 2);

    let seed = (0..100u64)
        .find(|&s| {
            let mut rng = RandomService::from_seed(s);
            rng.roll_die(6) == 6
        })
        .expect("debe existir seed que saque 6");
    session.world_mut().resource_mut::<RandomResource>().0 = RandomService::from_seed(seed);

    let events = session
        .process_command(P1, Box::new(RollDiceCommand { player: P1 }))
        .unwrap();

    assert_eq!(events.len(), 2);
    assert_eq!(
        events[0]
            .as_any()
            .downcast_ref::<DiceRolledEvent>()
            .unwrap()
            .value,
        6
    );
    assert!(events[1].as_any().is::<NoValidMovesEvent>());
    assert_eq!(
        session.world().resource::<ConsecutiveSixesResource>().count[&P1],
        0
    );
    assert_eq!(session.current_player(), P2);
}

#[test]
fn canonical_turno_extra_por_captura_y_meta_y_casillas_estrella() {
    let mut session = new_ludo_session(SessionId(518_13), 1, vec![P1, P2]);
    session
        .process_command(
            P1,
            Box::new(SetLudoRulesCommand {
                star_safe_squares: true,
                bonus_roll_on_capture_and_goal: true,
                three_sixes_penalty: true,
            }),
        )
        .unwrap();

    // 1. Casilla estrella segura ((offset + 8) % 52 = 8): no permite captura
    {
        let tokens = session.world().resource::<TokensResource>();
        let p1_star = (tokens.start_offset[&P1] + 8) % TRACK_LEN;
        assert!(tokens.is_safe_square_with_config(p1_star, true));
    }
    {
        let mut t = session.world_mut().resource_mut::<TokensResource>();
        t.tokens.get_mut(&P2).unwrap()[0] = 35; // posición absoluta 8 (estrella)
        t.tokens.get_mut(&P1).unwrap()[0] = 8; // posición absoluta 7
    }
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 1);

    let ev_star = session
        .process_command(
            P1,
            Box::new(MoveTokenCommand {
                player: P1,
                token_index: 0,
            }),
        )
        .unwrap();
    let moved_star = ev_star[0]
        .as_any()
        .downcast_ref::<TokenMovedEvent>()
        .unwrap();
    assert_eq!(moved_star.captured, None);
    assert_eq!(session.current_player(), P2);

    // 2. Turno extra por captura en casilla no segura
    session
        .world_mut()
        .resource_mut::<TurnResource>()
        .0
        .set_current_player(P1);
    {
        let mut t = session.world_mut().resource_mut::<TokensResource>();
        t.tokens.get_mut(&P1).unwrap()[0] = 25;
        t.tokens.get_mut(&P2).unwrap()[0] = 52;
    }
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 1);

    let ev_cap = session
        .process_command(
            P1,
            Box::new(MoveTokenCommand {
                player: P1,
                token_index: 0,
            }),
        )
        .unwrap();
    assert_eq!(
        ev_cap[0]
            .as_any()
            .downcast_ref::<TokenMovedEvent>()
            .unwrap()
            .captured,
        Some((P2, 0))
    );
    assert_eq!(session.current_player(), P1);

    // 3. Turno extra por llegar a la meta exacta
    {
        let mut t = session.world_mut().resource_mut::<TokensResource>();
        t.tokens.get_mut(&P1).unwrap()[1] = MAX_STEPS - 2;
    }
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 2);

    let ev_goal = session
        .process_command(
            P1,
            Box::new(MoveTokenCommand {
                player: P1,
                token_index: 1,
            }),
        )
        .unwrap();
    assert!(
        ev_goal[0]
            .as_any()
            .downcast_ref::<TokenMovedEvent>()
            .unwrap()
            .finished
    );
    assert_eq!(session.current_player(), P1);
}

#[test]
fn canonical_reinicio_contador_seises_y_meta_exacta() {
    let mut session = new_ludo_session(SessionId(518_207), 1, vec![P1, P2]);
    session
        .world_mut()
        .resource_mut::<ConsecutiveSixesResource>()
        .count
        .insert(P1, 2);
    {
        let mut t = session.world_mut().resource_mut::<TokensResource>();
        t.tokens.get_mut(&P1).unwrap()[0] = 1;
        t.tokens.get_mut(&P1).unwrap()[1] = MAX_STEPS - 2;
    }

    // Buscar una seed que saque un número distinto de 6
    let seed_non6 = (0..100u64)
        .find(|&s| {
            let mut rng = RandomService::from_seed(s);
            rng.roll_die(6) != 6
        })
        .expect("debe existir seed que no saque 6");
    session.world_mut().resource_mut::<RandomResource>().0 = RandomService::from_seed(seed_non6);

    session
        .process_command(P1, Box::new(RollDiceCommand { player: P1 }))
        .expect("tirada válida");
    assert_eq!(
        session.world().resource::<ConsecutiveSixesResource>().count[&P1],
        0,
        "sacar un número distinto de 6 tras 2 seises reinicia el contador a 0"
    );

    // Si una ficha está a 2 pasos de la meta y el dado pendiente es 4, exceder MAX_STEPS se rechaza
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 4);
    assert!(session
        .process_command(
            P1,
            Box::new(MoveTokenCommand {
                player: P1,
                token_index: 1,
            }),
        )
        .is_err());
}
