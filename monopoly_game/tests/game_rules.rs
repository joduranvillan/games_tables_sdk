use monopoly_game::{
    new_monopoly_session, AuctionBidCommand, AuctionStartedEvent, AuctionWonEvent, BankruptcyEvent,
    BuyPropertyCommand, GameOverEvent, JailedEvent, PayJailFeeCommand, PlayerMovedEvent, PropertyPurchasedEvent,
    RailroadRentPaidEvent, RentPaidEvent, RollAndMoveCommand, UtilityRentPaidEvent, STARTING_MONEY,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn el_setup_arranca_con_dinero_estandar_y_posicion_cero() {
    let session = new_monopoly_session(SessionId(1), 1, P1, P2);
    let players = session.world().resource::<monopoly_game::PlayersResource>();
    assert_eq!(players.money[&P1], STARTING_MONEY);
    assert_eq!(players.position[&P1], 0);
}

#[test]
fn moverse_a_una_propiedad_sin_dueno_deja_una_decision_pendiente_y_no_avanza_el_turno() {
    let mut session = new_monopoly_session(SessionId(2), 1, P1, P2);
    let events = session
        .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
        .expect("moverse debería funcionar");

    let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
    assert!(moved.roll >= 2 && moved.roll <= 12);

    let pending = session.world().resource::<monopoly_game::PendingPurchaseResource>();
    if pending.pending.contains_key(&P1) {
        assert_eq!(session.current_player(), P1);
    }
}

#[test]
fn no_se_puede_tirar_de_nuevo_con_una_compra_pendiente() {
    let mut session = new_monopoly_session(SessionId(3), 1, P1, P2);
    session
        .world_mut()
        .resource_mut::<monopoly_game::PendingPurchaseResource>()
        .pending
        .insert(P1, monopoly_game::resources::PendingDecision { space: 1, is_doubles: false });

    let result = session.process_command(P1, Box::new(RollAndMoveCommand { player: P1 }));
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn comprar_una_propiedad_descuenta_el_precio_y_asigna_el_dueno() {
    let mut session = new_monopoly_session(SessionId(4), 1, P1, P2);
    session
        .world_mut()
        .resource_mut::<monopoly_game::PendingPurchaseResource>()
        .pending
        .insert(P1, monopoly_game::resources::PendingDecision { space: 1, is_doubles: false }); // "Av. Roja 1", precio 60

    let events = session
        .process_command(P1, Box::new(BuyPropertyCommand { player: P1, buy: true }))
        .expect("comprar debería funcionar");
    let purchased = events[0].as_any().downcast_ref::<PropertyPurchasedEvent>().unwrap();
    assert_eq!(purchased.price, 60);

    let players = session.world().resource::<monopoly_game::PlayersResource>();
    assert_eq!(players.money[&P1], STARTING_MONEY - 60);
    assert_eq!(players.properties[&1], P1);
    assert_eq!(session.current_player(), P2, "responder la compra sí avanza el turno");
}

#[test]
fn caer_en_propiedad_ajena_paga_renta_al_dueno() {
    for seed in 0..50u64 {
        let mut session = new_monopoly_session(SessionId(100 + seed), seed, P1, P2);
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .properties
            .insert(4, P2); // "Av. Verde 2", renta base 10

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");
        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.new_position != 4 {
            continue;
        }
        let rent_event = events.iter().find_map(|e| e.as_any().downcast_ref::<RentPaidEvent>());
        assert!(rent_event.is_some(), "debería haber pagado renta al caer en la propiedad de P2");
        assert_eq!(rent_event.unwrap().amount, 10);
        return;
    }
    panic!("ninguna seed probada cayó en la casilla 4");
}

#[test]
fn poseer_todo_el_grupo_de_color_duplica_la_renta() {
    for seed in 0..50u64 {
        let mut session = new_monopoly_session(SessionId(300 + seed), seed, P1, P2);
        {
            let mut players = session.world_mut().resource_mut::<monopoly_game::PlayersResource>();
            // P2 posee todo el grupo Verde (casillas 3 y 4)
            players.properties.insert(3, P2); // Av. Verde 1 (renta 8)
            players.properties.insert(4, P2); // Av. Verde 2 (renta 10)
        }

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");
        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.new_position != 4 {
            continue;
        }
        let rent_event = events.iter().find_map(|e| e.as_any().downcast_ref::<RentPaidEvent>());
        assert!(rent_event.is_some());
        // Al poseer el grupo completo, la renta de Av. Verde 2 (10) se duplica a 20!
        assert_eq!(rent_event.unwrap().amount, 20);
        return;
    }
    panic!("ninguna seed probada cayó en la casilla 4");
}

#[test]
fn test_renta_doble_por_grupo_completo_en_monopoly() {
    poseer_todo_el_grupo_de_color_duplica_la_renta();
}

#[test]
fn quedarse_sin_dinero_tras_pagar_renta_termina_la_partida() {
    for seed in 0..50u64 {
        let mut session = new_monopoly_session(SessionId(200 + seed), seed, P1, P2);
        {
            let mut players = session.world_mut().resource_mut::<monopoly_game::PlayersResource>();
            players.money.insert(P1, 5); // menos que la renta de 10
            players.properties.insert(4, P2);
        }

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");
        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.new_position != 4 {
            continue;
        }
        assert!(events
            .iter()
            .any(|e| e.as_any().downcast_ref::<GameOverEvent>().map(|go| go.winner) == Some(P2)));
        return;
    }
    panic!("ninguna seed probada cayó en la casilla 4");
}

#[test]
fn test_caer_en_go_to_jail_envia_a_jail_y_emite_jailed_event() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(400 + seed), seed, P1, P2);
        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");

        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.roll == 8 {
            assert_eq!(moved.new_position, 4, "La nueva posición debe ser 4 (JAIL_SPACE)");
            let jailed_event = events.iter().find_map(|e| e.as_any().downcast_ref::<JailedEvent>());
            assert!(jailed_event.is_some(), "Debe emitirse un JailedEvent");
            assert_eq!(jailed_event.unwrap().player, P1);

            let players = session.world().resource::<monopoly_game::PlayersResource>();
            assert_eq!(players.position[&P1], 4, "La posición guardada en PlayersResource debe ser 4");
            return;
        }
    }
    panic!("ninguna seed probada resultó en un tiro de 8");
}

#[test]
fn test_jugador_en_carcel_no_se_mueve_hasta_que_sale() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(1000 + seed), seed, P1, P2);
        {
            let mut players = session.world_mut().resource_mut::<monopoly_game::PlayersResource>();
            players.position.insert(P1, 4);
            let mut jail = session.world_mut().resource_mut::<monopoly_game::JailResource>();
            jail.jailed.insert(P1, 3);
        }

        let events = session.process_command(P1, Box::new(RollAndMoveCommand { player: P1 })).unwrap();
        let moved = events.iter().find_map(|e| e.as_any().downcast_ref::<PlayerMovedEvent>());
        if let Some(m) = moved {
            if !m.is_doubles {
                let players = session.world().resource::<monopoly_game::PlayersResource>();
                assert_eq!(players.position[&P1], 4, "El jugador en cárcel no debe moverse si no saca dobles");

                session.world_mut().resource_mut::<monopoly_game::JailResource>().jailed.insert(P2, 3);
                session.process_command(P2, Box::new(PayJailFeeCommand { player: P2 })).expect("pagar la fianza debe ser válido");
                let jail = session.world().resource::<monopoly_game::JailResource>();
                assert!(!jail.jailed.contains_key(&P2), "P2 debe haber salido de la cárcel al pagar la fianza");
                return;
            }
        }
    }
}

#[test]
fn test_rechazo_de_compra_inicia_subasta() {
    let mut session = new_monopoly_session(SessionId(11), 1, P1, P2);
    session.world_mut().resource_mut::<monopoly_game::PendingPurchaseResource>().pending.insert(
        P1,
        monopoly_game::resources::PendingDecision { space: 1, is_doubles: false },
    );

    let events = session
        .process_command(P1, Box::new(BuyPropertyCommand { player: P1, buy: false }))
        .expect("rechazar compra debe ser válido");

    let started = events.iter().find_map(|e| e.as_any().downcast_ref::<AuctionStartedEvent>());
    assert!(started.is_some(), "debe emitirse un AuctionStartedEvent");
    assert_eq!(started.unwrap().space, 1);

    let _ = session
        .process_command(P2, Box::new(AuctionBidCommand { player: P2, amount: 50 }))
        .expect("puja de P2 debe ser válida");

    let events = session
        .process_command(P1, Box::new(AuctionBidCommand { player: P1, amount: 0 }))
        .expect("pasar en la subasta debe ser válido");

    let won = events.iter().find_map(|e| e.as_any().downcast_ref::<AuctionWonEvent>());
    assert!(won.is_some(), "P2 debe ganar la subasta al pasar P1");
    let won = won.unwrap();
    assert_eq!(won.player, P2);
    assert_eq!(won.space, 1);
    assert_eq!(won.price, 50);

    let players = session.world().resource::<monopoly_game::PlayersResource>();
    assert_eq!(players.properties[&1], P2);
    assert_eq!(players.money[&P2], STARTING_MONEY - 50);
}

#[test]
fn test_renta_de_servicio_es_4x_con_uno_y_10x_con_dos() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(1200 + seed), seed, P1, P2);
        session.world_mut().resource_mut::<monopoly_game::PlayersResource>().properties.insert(11, P2);

        let events = session.process_command(P1, Box::new(RollAndMoveCommand { player: P1 })).unwrap();
        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.new_position != 11 {
            continue;
        }

        let rent_event = events.iter().find_map(|e| e.as_any().downcast_ref::<UtilityRentPaidEvent>());
        assert!(rent_event.is_some(), "debe haber pagado renta de servicio a P2");
        let re = rent_event.unwrap();
        assert_eq!(re.multiplier, 4, "con 1 servicio el multiplicador debe ser 4");
        assert_eq!(re.amount, 4 * moved.roll);

        let mut session2 = new_monopoly_session(SessionId(1200 + seed), seed, P1, P2);
        {
            let mut players = session2.world_mut().resource_mut::<monopoly_game::PlayersResource>();
            players.properties.insert(11, P2);
            players.properties.insert(14, P2);
        }
        let events2 = session2.process_command(P1, Box::new(RollAndMoveCommand { player: P1 })).unwrap();
        let rent_event2 = events2.iter().find_map(|e| e.as_any().downcast_ref::<UtilityRentPaidEvent>());
        assert!(rent_event2.is_some());
        let re2 = rent_event2.unwrap();
        assert_eq!(re2.multiplier, 10, "con 2 servicios el multiplicador debe ser 10");
        assert_eq!(re2.amount, 10 * moved.roll);
        return;
    }
    panic!("ninguna seed cayó en la casilla 11");
}

#[test]
fn test_renta_de_ferrocarril_escala_con_cantidad_de_estaciones() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(1300 + seed), seed, P1, P2);
        session.world_mut().resource_mut::<monopoly_game::PlayersResource>().properties.insert(5, P2);

        let events = session.process_command(P1, Box::new(RollAndMoveCommand { player: P1 })).unwrap();
        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.new_position != 5 {
            continue;
        }

        let rent_event = events.iter().find_map(|e| e.as_any().downcast_ref::<RailroadRentPaidEvent>());
        assert!(rent_event.is_some());
        let re = rent_event.unwrap();
        assert_eq!(re.railroads_owned, 1);
        assert_eq!(re.amount, 25, "con 1 estación la renta es 25");
        return;
    }
    panic!("ninguna seed cayó en la casilla 5");
}

#[test]
fn test_quiebra_transfiere_propiedades_al_acreedor() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(1400 + seed), seed, P1, P2);
        {
            let mut players = session.world_mut().resource_mut::<monopoly_game::PlayersResource>();
            players.money.insert(P1, 5);
            players.properties.insert(1, P1);
            players.properties.insert(4, P2);
        }

        let events = session.process_command(P1, Box::new(RollAndMoveCommand { player: P1 })).unwrap();
        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.new_position != 4 {
            continue;
        }

        let bk = events.iter().find_map(|e| e.as_any().downcast_ref::<BankruptcyEvent>());
        assert!(bk.is_some(), "debe emitirse un BankruptcyEvent");
        assert_eq!(bk.unwrap().player, P1);

        let players = session.world().resource::<monopoly_game::PlayersResource>();
        assert_eq!(players.properties.get(&1), Some(&P2), "las propiedades de P1 se transfieren a P2");

        let game_over = events.iter().find_map(|e| e.as_any().downcast_ref::<GameOverEvent>());
        assert!(game_over.is_some(), "debe finalizar la partida");
        assert_eq!(game_over.unwrap().winner, P2);
        return;
    }
    panic!("ninguna seed cayó en la casilla 4");
}

#[test]
fn monopoly_primer_jugador_en_quebrar() {
    let p1 = PlayerId(1);
    let p2 = PlayerId(2);
    let p3 = PlayerId(3);
    let players = vec![p1, p2, p3];

    let mut bankruptcy_found = false;
    for seed in 0..100u64 {
        let mut test_session = Session::new_with_metadata(
            SessionId(2000 + seed),
            "Monopoly",
            seed,
            players.clone(),
            monopoly_game::build_monopoly_rules(),
        );
        test_session.world_mut().insert_resource(monopoly_game::BoardResource::new());
        test_session.world_mut().insert_resource(monopoly_game::PlayersResource::new(&players));
        test_session.world_mut().insert_resource(monopoly_game::PendingPurchaseResource::default());
        test_session.world_mut().insert_resource(monopoly_game::JailResource::default());
        test_session.world_mut().insert_resource(monopoly_game::AuctionResource::default());

        {
            let mut board = test_session.world_mut().resource_mut::<monopoly_game::BoardResource>();
            board.spaces[15] = monopoly_game::board::Space::Property {
                name: "Av. Cara".to_string(),
                group: "Cara".to_string(),
                price: 500,
                rent: 100,
            };
        }
        {
            let mut players_res = test_session.world_mut().resource_mut::<monopoly_game::PlayersResource>();
            players_res.properties.insert(15, p1);
            players_res.properties.insert(1, p2);
            players_res.money.insert(p2, 50);
            players_res.position.insert(p2, 13);
        }

        // P1 tira
        let _ = test_session.process_command(p1, Box::new(RollAndMoveCommand { player: p1 }));
        if test_session.world().resource::<monopoly_game::PendingPurchaseResource>().pending.contains_key(&p1) {
            let _ = test_session.process_command(p1, Box::new(BuyPropertyCommand { player: p1, buy: false }));
            if test_session.world().resource::<monopoly_game::AuctionResource>().state.is_some() {
                let _ = test_session.process_command(p1, Box::new(AuctionBidCommand { player: p1, amount: 0 }));
                let _ = test_session.process_command(p2, Box::new(AuctionBidCommand { player: p2, amount: 0 }));
                let _ = test_session.process_command(p3, Box::new(AuctionBidCommand { player: p3, amount: 0 }));
            }
        }

        if test_session.current_player() != p2 {
            continue;
        }

        let events = test_session.process_command(p2, Box::new(RollAndMoveCommand { player: p2 })).unwrap();
        let moved = events[0].as_any().downcast_ref::<PlayerMovedEvent>().unwrap();
        if moved.new_position != 15 {
            continue;
        }

        // Verificar BankruptcyEvent { player: P2 }
        let bk = events.iter().find_map(|e| e.as_any().downcast_ref::<BankruptcyEvent>());
        assert!(bk.is_some(), "Debe emitirse un BankruptcyEvent para P2");
        assert_eq!(bk.unwrap().player, p2);

        // Verificar transferencia de propiedades de P2 a P1
        let players_res = test_session.world().resource::<monopoly_game::PlayersResource>();
        assert_eq!(
            players_res.properties.get(&1),
            Some(&p1),
            "La propiedad de P2 debe transferirse al acreedor P1"
        );

        // Verificar que el ciclo de turnos continúa entre P1 y P3 (P2 es saltado)
        assert_eq!(test_session.current_player(), p3, "El turno de P2 en quiebra debe pasar a P3");

        let _ = test_session.process_command(p3, Box::new(RollAndMoveCommand { player: p3 }));
        if test_session.world().resource::<monopoly_game::PendingPurchaseResource>().pending.contains_key(&p3) {
            let _ = test_session.process_command(p3, Box::new(BuyPropertyCommand { player: p3, buy: false }));
            if test_session.world().resource::<monopoly_game::AuctionResource>().state.is_some() {
                let _ = test_session.process_command(p1, Box::new(AuctionBidCommand { player: p1, amount: 0 }));
                let _ = test_session.process_command(p3, Box::new(AuctionBidCommand { player: p3, amount: 0 }));
            }
        }

        assert_eq!(test_session.current_player(), p1, "Tras P3, el turno debe volver a P1 saltando a P2");

        bankruptcy_found = true;
        break;
    }

    assert!(bankruptcy_found, "Debe encontrarse una seed válida para el test de quiebra");
}


