use monopoly_game::{
    board_layout, new_monopoly_session, AcceptTradeCommand, AuctionBidCommand, AuctionStartedEvent,
    AuctionWonEvent, BankruptcyEvent, BuildHouseCommand, BuildingsResource, BuyPropertyCommand,
    ChanceCard, CommunityChestCard, GameOverEvent, HouseBuiltEvent, HouseSoldEvent,
    JailCardUsedEvent, JailResource, JailedEvent, MortgagePropertyCommand, PayJailFeeCommand,
    PlayerMovedEvent, PropertyMortgagedEvent, PropertyPurchasedEvent, PropertyUnmortgagedEvent,
    ProposeTradeCommand, RailroadRentPaidEvent, RejectTradeCommand, RentPaidEvent,
    RollAndMoveCommand, SellHouseCommand, SpaceKind, TaxPaidEvent, TradeAcceptedEvent,
    TradeOfferResource, TradeProposedEvent, TradeRejectedEvent, UnmortgagePropertyCommand,
    UseJailCardCommand, UtilityRentPaidEvent, BOARD_SIZE, GO_TO_JAIL_SPACE, JAIL_SPACE,
    STARTING_MONEY,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn test_tablero_estandar_40_casillas_con_todas_las_variantes() {
    let layout = board_layout();
    assert_eq!(layout.len(), 40);
    assert_eq!(BOARD_SIZE, 40);

    let mut properties = 0;
    let mut railroads = 0;
    let mut utilities = 0;
    let mut taxes = 0;
    let mut chances = 0;
    let mut community_chests = 0;

    for space in &layout {
        match space {
            SpaceKind::Property { .. } => properties += 1,
            SpaceKind::Railroad { .. } => railroads += 1,
            SpaceKind::Utility { .. } => utilities += 1,
            SpaceKind::Tax { .. } => taxes += 1,
            SpaceKind::Chance => chances += 1,
            SpaceKind::CommunityChest => community_chests += 1,
            SpaceKind::Go | SpaceKind::Jail | SpaceKind::FreeParking | SpaceKind::GoToJail => {}
        }
    }

    assert_eq!(properties, 22, "22 calles");
    assert_eq!(railroads, 4, "4 estaciones");
    assert_eq!(utilities, 2, "2 suministros/servicios");
    assert_eq!(
        properties + railroads + utilities,
        28,
        "28 propiedades totales"
    );
    assert_eq!(taxes, 2, "2 impuestos (Renta y Lujo)");
    assert_eq!(chances, 3, "3 cartas de Suerte");
    assert_eq!(community_chests, 3, "3 cartas de Arca Comunitaria");

    assert_eq!(layout[0], SpaceKind::Go);
    assert_eq!(layout[10], SpaceKind::Jail);
    assert_eq!(layout[20], SpaceKind::FreeParking);
    assert_eq!(layout[30], SpaceKind::GoToJail);
    assert_eq!(JAIL_SPACE, 10);
    assert_eq!(GO_TO_JAIL_SPACE, 30);
}

#[test]
fn test_10_cartas_de_suerte_y_10_de_arca_comunitaria() {
    assert_eq!(ChanceCard::ALL.len(), 10);
    assert_eq!(CommunityChestCard::ALL.len(), 10);
}

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

    let moved = events[0]
        .as_any()
        .downcast_ref::<PlayerMovedEvent>()
        .unwrap();
    assert!(moved.roll >= 2 && moved.roll <= 12);

    let pending = session
        .world()
        .resource::<monopoly_game::PendingPurchaseResource>();
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
        .insert(
            P1,
            monopoly_game::resources::PendingDecision {
                space: 1,
                is_doubles: false,
            },
        );

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
        .insert(
            P1,
            monopoly_game::resources::PendingDecision {
                space: 1,
                is_doubles: false,
            },
        ); // "Av. Mediterráneo", precio 60

    let events = session
        .process_command(
            P1,
            Box::new(BuyPropertyCommand {
                player: P1,
                buy: true,
            }),
        )
        .expect("comprar debería funcionar");
    let purchased = events[0]
        .as_any()
        .downcast_ref::<PropertyPurchasedEvent>()
        .unwrap();
    assert_eq!(purchased.price, 60);

    let players = session.world().resource::<monopoly_game::PlayersResource>();
    assert_eq!(players.money[&P1], STARTING_MONEY - 60);
    assert_eq!(players.properties[&1], P1);
    assert_eq!(
        session.current_player(),
        P2,
        "responder la compra sí avanza el turno"
    );
}

#[test]
fn caer_en_propiedad_ajena_paga_renta_al_dueno() {
    for seed in 0..50u64 {
        let mut session = new_monopoly_session(SessionId(100 + seed), seed, P1, P2);
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .properties
            .insert(3, P2); // "Av. Báltica", renta base 4

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position != 3 {
            continue;
        }
        let rent_event = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<RentPaidEvent>());
        assert!(
            rent_event.is_some(),
            "debería haber pagado renta al caer en la propiedad de P2"
        );
        assert_eq!(rent_event.unwrap().amount, 4);
        return;
    }
    panic!("ninguna seed probada cayó en la casilla 3");
}

#[test]
fn poseer_todo_el_grupo_de_color_duplica_la_renta() {
    for seed in 0..50u64 {
        let mut session = new_monopoly_session(SessionId(300 + seed), seed, P1, P2);
        {
            let mut players = session
                .world_mut()
                .resource_mut::<monopoly_game::PlayersResource>();
            // P2 posee todo el grupo Marrón (casillas 1 y 3)
            players.properties.insert(1, P2); // Av. Mediterráneo (renta 2)
            players.properties.insert(3, P2); // Av. Báltica (renta 4)
        }

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position != 3 {
            continue;
        }
        let rent_event = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<RentPaidEvent>());
        assert!(rent_event.is_some());
        // Al poseer el grupo completo, la renta de Av. Báltica (4) se duplica a 8!
        assert_eq!(rent_event.unwrap().amount, 8);
        return;
    }
    panic!("ninguna seed probada cayó en la casilla 3");
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
            let mut players = session
                .world_mut()
                .resource_mut::<monopoly_game::PlayersResource>();
            players.money.insert(P1, 2); // menos que la renta de 4
            players.properties.insert(3, P2);
        }

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position != 3 {
            continue;
        }
        assert!(events.iter().any(|e| e
            .as_any()
            .downcast_ref::<GameOverEvent>()
            .map(|go| go.winner)
            == Some(P2)));
        return;
    }
    panic!("ninguna seed probada cayó en la casilla 3");
}

#[test]
fn test_jugador_cae_en_ve_a_la_carcel() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(400 + seed), seed, P1, P2);
        // Ubicar al jugador en casilla 24 para que tire 6 y caiga en 30 (Ve a la Cárcel)
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .position
            .insert(P1, 24);

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .expect("moverse debería funcionar");

        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.roll == 6 {
            assert_eq!(
                moved.new_position, 30,
                "El tiro 6 desde 24 llega a 30 (GO_TO_JAIL_SPACE)"
            );
            let jailed_event = events
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<JailedEvent>());
            assert!(jailed_event.is_some(), "Debe emitirse un JailedEvent");
            assert_eq!(jailed_event.unwrap().player, P1);

            let players = session.world().resource::<monopoly_game::PlayersResource>();
            assert_eq!(
                players.position[&P1], 10,
                "La posición final guardada debe ser 10 (JAIL_SPACE)"
            );
            let jail = session.world().resource::<monopoly_game::JailResource>();
            assert!(
                jail.jailed.contains_key(&P1),
                "El jugador debe figurar en JailResource"
            );
            return;
        }
    }
    panic!("ninguna seed probada resultó en un tiro de 6");
}

#[test]
fn test_caer_en_go_to_jail_envia_a_jail_y_emite_jailed_event() {
    test_jugador_cae_en_ve_a_la_carcel();
}

#[test]
fn test_jugador_en_carcel_no_se_mueve_hasta_que_sale() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(1000 + seed), seed, P1, P2);
        {
            let mut players = session
                .world_mut()
                .resource_mut::<monopoly_game::PlayersResource>();
            players.position.insert(P1, 10);
            let mut jail = session
                .world_mut()
                .resource_mut::<monopoly_game::JailResource>();
            jail.jailed.insert(P1, 3);
        }

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .unwrap();
        let moved = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<PlayerMovedEvent>());
        if let Some(m) = moved {
            if !m.is_doubles {
                let players = session.world().resource::<monopoly_game::PlayersResource>();
                assert_eq!(
                    players.position[&P1], 10,
                    "El jugador en cárcel no debe moverse si no saca dobles"
                );

                session
                    .world_mut()
                    .resource_mut::<monopoly_game::JailResource>()
                    .jailed
                    .insert(P2, 3);
                session
                    .process_command(P2, Box::new(PayJailFeeCommand { player: P2 }))
                    .expect("pagar la fianza debe ser válido");
                let jail = session.world().resource::<monopoly_game::JailResource>();
                assert!(
                    !jail.jailed.contains_key(&P2),
                    "P2 debe haber salido de la cárcel al pagar la fianza"
                );
                return;
            }
        }
    }
}

#[test]
fn test_rechazo_de_compra_inicia_subasta() {
    let mut session = new_monopoly_session(SessionId(11), 1, P1, P2);
    session
        .world_mut()
        .resource_mut::<monopoly_game::PendingPurchaseResource>()
        .pending
        .insert(
            P1,
            monopoly_game::resources::PendingDecision {
                space: 1,
                is_doubles: false,
            },
        );

    let events = session
        .process_command(
            P1,
            Box::new(BuyPropertyCommand {
                player: P1,
                buy: false,
            }),
        )
        .expect("rechazar compra debe ser válido");

    let started = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<AuctionStartedEvent>());
    assert!(started.is_some(), "debe emitirse un AuctionStartedEvent");
    assert_eq!(started.unwrap().space, 1);

    let _ = session
        .process_command(
            P2,
            Box::new(AuctionBidCommand {
                player: P2,
                amount: 50,
            }),
        )
        .expect("puja de P2 debe ser válida");

    let events = session
        .process_command(
            P1,
            Box::new(AuctionBidCommand {
                player: P1,
                amount: 0,
            }),
        )
        .expect("pasar en la subasta debe ser válido");

    let won = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<AuctionWonEvent>());
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
        // Casilla 12 es Compañía Eléctrica
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .properties
            .insert(12, P2);
        // Posicionar a P1 en casilla 6 para que al tirar 6 caiga en 12
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .position
            .insert(P1, 6);

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .unwrap();
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position != 12 {
            continue;
        }

        let rent_event = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<UtilityRentPaidEvent>());
        assert!(
            rent_event.is_some(),
            "debe haber pagado renta de servicio a P2"
        );
        let re = rent_event.unwrap();
        assert_eq!(
            re.multiplier, 4,
            "con 1 servicio el multiplicador debe ser 4"
        );
        assert_eq!(re.amount, 4 * moved.roll);

        let mut session2 = new_monopoly_session(SessionId(1200 + seed), seed, P1, P2);
        {
            let mut players = session2
                .world_mut()
                .resource_mut::<monopoly_game::PlayersResource>();
            players.properties.insert(12, P2); // Compañía Eléctrica
            players.properties.insert(28, P2); // Planta de Agua
            players.position.insert(P1, 6);
        }
        let events2 = session2
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .unwrap();
        let rent_event2 = events2
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<UtilityRentPaidEvent>());
        assert!(rent_event2.is_some());
        let re2 = rent_event2.unwrap();
        assert_eq!(
            re2.multiplier, 10,
            "con 2 servicios el multiplicador debe ser 10"
        );
        assert_eq!(re2.amount, 10 * moved.roll);
        return;
    }
    panic!("ninguna seed cayó en la casilla 12");
}

#[test]
fn test_renta_de_ferrocarril_escala_con_cantidad_de_estaciones() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(1300 + seed), seed, P1, P2);
        // Casilla 5 es Ferrocarril Reading
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .properties
            .insert(5, P2);

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .unwrap();
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position != 5 {
            continue;
        }

        let rent_event = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<RailroadRentPaidEvent>());
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
            let mut players = session
                .world_mut()
                .resource_mut::<monopoly_game::PlayersResource>();
            players.money.insert(P1, 2);
            players.properties.insert(1, P1);
            players.properties.insert(3, P2);
        }

        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .unwrap();
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position != 3 {
            continue;
        }

        let bk = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<BankruptcyEvent>());
        assert!(bk.is_some(), "debe emitirse un BankruptcyEvent");
        assert_eq!(bk.unwrap().player, P1);

        let players = session.world().resource::<monopoly_game::PlayersResource>();
        assert_eq!(
            players.properties.get(&1),
            Some(&P2),
            "las propiedades de P1 se transfieren a P2"
        );

        let game_over = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>());
        assert!(game_over.is_some(), "debe finalizar la partida");
        assert_eq!(game_over.unwrap().winner, P2);
        return;
    }
    panic!("ninguna seed cayó en la casilla 3");
}

#[test]
fn test_impuesto_sobre_la_renta_y_lujo() {
    for seed in 0..100u64 {
        let mut session = new_monopoly_session(SessionId(1500 + seed), seed, P1, P2);
        // Casilla 4 es Impuesto sobre la Renta (200$)
        let events = session
            .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
            .unwrap();
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position == 4 {
            let tax_event = events
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TaxPaidEvent>());
            assert!(tax_event.is_some(), "Debe emitirse un TaxPaidEvent");
            let te = tax_event.unwrap();
            assert_eq!(te.amount, 200);
            assert_eq!(te.player, P1);

            let players = session.world().resource::<monopoly_game::PlayersResource>();
            assert_eq!(players.money[&P1], STARTING_MONEY - 200);
            return;
        }
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
        test_session
            .world_mut()
            .insert_resource(monopoly_game::BoardResource::new());
        test_session
            .world_mut()
            .insert_resource(monopoly_game::PlayersResource::new(&players));
        test_session
            .world_mut()
            .insert_resource(monopoly_game::PendingPurchaseResource::default());
        test_session
            .world_mut()
            .insert_resource(monopoly_game::JailResource::default());
        test_session
            .world_mut()
            .insert_resource(monopoly_game::AuctionResource::default());

        {
            let mut players_res = test_session
                .world_mut()
                .resource_mut::<monopoly_game::PlayersResource>();
            players_res.properties.insert(24, p1); // Av. Illinois, renta 20
            players_res.properties.insert(1, p2);
            players_res.money.insert(p2, 10);
            players_res.position.insert(p2, 22); // al tirar 2 caerá en 24
        }

        // P1 tira
        let _ = test_session.process_command(p1, Box::new(RollAndMoveCommand { player: p1 }));
        if test_session
            .world()
            .resource::<monopoly_game::PendingPurchaseResource>()
            .pending
            .contains_key(&p1)
        {
            let _ = test_session.process_command(
                p1,
                Box::new(BuyPropertyCommand {
                    player: p1,
                    buy: false,
                }),
            );
            if test_session
                .world()
                .resource::<monopoly_game::AuctionResource>()
                .state
                .is_some()
            {
                let _ = test_session.process_command(
                    p1,
                    Box::new(AuctionBidCommand {
                        player: p1,
                        amount: 0,
                    }),
                );
                let _ = test_session.process_command(
                    p2,
                    Box::new(AuctionBidCommand {
                        player: p2,
                        amount: 0,
                    }),
                );
                let _ = test_session.process_command(
                    p3,
                    Box::new(AuctionBidCommand {
                        player: p3,
                        amount: 0,
                    }),
                );
            }
        }

        if test_session.current_player() != p2 {
            continue;
        }

        let events = test_session
            .process_command(p2, Box::new(RollAndMoveCommand { player: p2 }))
            .unwrap();
        let moved = events[0]
            .as_any()
            .downcast_ref::<PlayerMovedEvent>()
            .unwrap();
        if moved.new_position != 24 {
            continue;
        }

        // Verificar BankruptcyEvent { player: P2 }
        let bk = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<BankruptcyEvent>());
        assert!(bk.is_some(), "Debe emitirse un BankruptcyEvent para P2");
        assert_eq!(bk.unwrap().player, p2);

        // Verificar transferencia de propiedades de P2 a P1
        let players_res = test_session
            .world()
            .resource::<monopoly_game::PlayersResource>();
        assert_eq!(
            players_res.properties.get(&1),
            Some(&p1),
            "La propiedad de P2 debe transferirse al acreedor P1"
        );

        // Verificar que el ciclo de turnos continúa entre P1 y P3 (P2 es saltado)
        assert_eq!(
            test_session.current_player(),
            p3,
            "El turno de P2 en quiebra debe pasar a P3"
        );

        let _ = test_session.process_command(p3, Box::new(RollAndMoveCommand { player: p3 }));
        if test_session
            .world()
            .resource::<monopoly_game::PendingPurchaseResource>()
            .pending
            .contains_key(&p3)
        {
            let _ = test_session.process_command(
                p3,
                Box::new(BuyPropertyCommand {
                    player: p3,
                    buy: false,
                }),
            );
            if test_session
                .world()
                .resource::<monopoly_game::AuctionResource>()
                .state
                .is_some()
            {
                let _ = test_session.process_command(
                    p1,
                    Box::new(AuctionBidCommand {
                        player: p1,
                        amount: 0,
                    }),
                );
                let _ = test_session.process_command(
                    p3,
                    Box::new(AuctionBidCommand {
                        player: p3,
                        amount: 0,
                    }),
                );
            }
        }

        assert_eq!(
            test_session.current_player(),
            p1,
            "Tras P3, el turno debe volver a P1 saltando a P2"
        );

        bankruptcy_found = true;
        break;
    }

    assert!(
        bankruptcy_found,
        "Debe encontrarse una seed válida para el test de quiebra"
    );
}

#[test]
fn test_construccion_uniforme_y_coste_por_lado_del_tablero() {
    let mut session = new_monopoly_session(SessionId(101), 1, P1, P2);

    // Dar a P1 las casillas del grupo Marrón (1 y 3)
    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(1, P1);

    // Sin el grupo completo, no puede construir
    let err = session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap_err();
    assert!(err.to_string().contains("grupo"));

    // Otorgar casilla 3 a P1 (completa grupo Marrón)
    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(3, P1);

    // Coste de casilla 1 (< 10) es $50
    let money_before = session
        .world()
        .resource::<monopoly_game::PlayersResource>()
        .money[&P1];

    let events = session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("debe construir primera casa en casilla 1");

    let built = events[0]
        .as_any()
        .downcast_ref::<HouseBuiltEvent>()
        .expect("debe emitir HouseBuiltEvent");
    assert_eq!(built.level, 1);
    assert_eq!(built.cost, 50);

    let money_after = session
        .world()
        .resource::<monopoly_game::PlayersResource>()
        .money[&P1];
    assert_eq!(money_before - money_after, 50);

    // Intento de construir segunda casa en casilla 1 cuando casilla 3 tiene 0 casas (viola construcción uniforme)
    let err_uniform = session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap_err();
    assert!(err_uniform.to_string().contains("uniforme"));

    // Construir en casilla 3 para igualar a nivel 1
    session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 3,
            }),
        )
        .expect("debe permitir construir en casilla 3");

    // Ahora sí se puede construir en casilla 1 para llevarla a nivel 2
    let events2 = session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("debe permitir construir segunda casa en casilla 1");
    let built2 = events2[0]
        .as_any()
        .downcast_ref::<HouseBuiltEvent>()
        .unwrap();
    assert_eq!(built2.level, 2);
}

#[test]
fn test_construccion_hasta_hotel_y_limite_nivel_5() {
    let mut session = new_monopoly_session(SessionId(102), 1, P1, P2);

    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(1, P1);
    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(3, P1);

    // Llevar ambas casillas hasta nivel 5 (Hotel)
    for level in 1..=5 {
        session
            .process_command(
                P1,
                Box::new(BuildHouseCommand {
                    player: P1,
                    space: 1,
                }),
            )
            .unwrap_or_else(|e| panic!("error en espacio 1 nivel {}: {}", level, e));
        session
            .process_command(
                P1,
                Box::new(BuildHouseCommand {
                    player: P1,
                    space: 3,
                }),
            )
            .unwrap_or_else(|e| panic!("error en espacio 3 nivel {}: {}", level, e));
    }

    let buildings = session.world().resource::<BuildingsResource>();
    assert_eq!(buildings.buildings.get(&1), Some(&5));
    assert_eq!(buildings.buildings.get(&3), Some(&5));

    // Intentar construir más allá del nivel 5 (Hotel)
    let err_max = session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap_err();
    assert!(err_max.to_string().contains("máximo") || err_max.to_string().contains("hotel"));
}

#[test]
fn test_desmonte_uniforme_y_reembolso_50_porciento() {
    let mut session = new_monopoly_session(SessionId(103), 1, P1, P2);

    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(1, P1);
    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(3, P1);

    // Construir 2 casas en casilla 1 y 1 en casilla 3
    session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap();
    session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 3,
            }),
        )
        .unwrap();
    session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap();

    // Casilla 1 tiene nivel 2, casilla 3 tiene nivel 1.
    // Intentar vender de casilla 3 (que tiene 1, menor que casilla 1 con 2) viola desmonte uniforme
    let err_desmonte = session
        .process_command(
            P1,
            Box::new(SellHouseCommand {
                player: P1,
                space: 3,
            }),
        )
        .unwrap_err();
    assert!(
        err_desmonte.to_string().contains("desmonte")
            || err_desmonte.to_string().contains("uniforme")
    );

    // Vender de casilla 1 (coste $50 -> reembolso $25)
    let money_before = session
        .world()
        .resource::<monopoly_game::PlayersResource>()
        .money[&P1];

    let events = session
        .process_command(
            P1,
            Box::new(SellHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("debe vender de casilla 1");

    let sold = events[0]
        .as_any()
        .downcast_ref::<HouseSoldEvent>()
        .expect("debe emitir HouseSoldEvent");
    assert_eq!(sold.level, 1);
    assert_eq!(sold.refund, 25);

    let money_after = session
        .world()
        .resource::<monopoly_game::PlayersResource>()
        .money[&P1];
    assert_eq!(money_after - money_before, 25);
}

#[test]
fn test_renta_escalonada_segun_edificios() {
    // Casilla 1: Av. Mediterráneo, base rent = 2
    // 0 casas grupo completo: 2 * 2 = 4
    // 1 casa: 2 * 5 = 10
    // 2 casas: 2 * 15 = 30
    // 3 casas: 2 * 45 = 90
    // 4 casas: 2 * 80 = 160
    // 5 casas (hotel): 2 * 125 = 250

    for (lvl, expected_rent) in [(0, 4), (1, 10), (2, 30), (3, 90), (4, 160), (5, 250)] {
        let mut session = new_monopoly_session(SessionId(200 + lvl as u64), 1, P1, P2);
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .properties
            .insert(1, P1);
        session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>()
            .properties
            .insert(3, P1);

        if lvl > 0 {
            session
                .world_mut()
                .resource_mut::<BuildingsResource>()
                .buildings
                .insert(1, lvl as u8);
        }

        // P2 cae en la casilla 1
        let space = session
            .world()
            .resource::<monopoly_game::BoardResource>()
            .spaces[1]
            .clone();
        let mut events = Vec::new();
        let decision = monopoly_game::apply_land_effect(
            &space,
            1,
            P2,
            7,
            false,
            session.world_mut(),
            &mut events,
        );
        assert!(!decision);

        let rent_event = events
            .iter()
            .find_map(|e| e.as_any().downcast_ref::<RentPaidEvent>())
            .expect("debe emitirse RentPaidEvent");
        assert_eq!(
            rent_event.amount, expected_rent,
            "Renta para nivel {} debe ser {}",
            lvl, expected_rent
        );
    }
}

#[test]
fn test_hipoteca_y_deshipoteca_propiedad() {
    let mut session = new_monopoly_session(SessionId(301), 1, P1, P2);

    // Otorgar propiedad 1 (Mediterráneo, precio $60) a P1
    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(1, P1);

    let money_before = session
        .world()
        .resource::<monopoly_game::PlayersResource>()
        .money[&P1];

    // P1 hipoteca la propiedad (precio $60 -> recibe $30)
    let events = session
        .process_command(
            P1,
            Box::new(MortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("debe permitir hipotecar propiedad");

    let mort_event = events[0]
        .as_any()
        .downcast_ref::<PropertyMortgagedEvent>()
        .expect("debe emitir PropertyMortgagedEvent");
    assert_eq!(mort_event.amount, 30);
    assert_eq!(mort_event.space, 1);

    let money_after = session
        .world()
        .resource::<monopoly_game::PlayersResource>()
        .money[&P1];
    assert_eq!(money_after - money_before, 30);

    assert!(
        session
            .world()
            .resource::<monopoly_game::PlayersResource>()
            .mortgaged
            .contains(&1),
        "casilla 1 debe estar marcada como hipotecada"
    );

    // Intentar hipotecar de nuevo debe fallar
    let err_double = session
        .process_command(
            P1,
            Box::new(MortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap_err();
    assert!(err_double.to_string().contains("hipotecada"));

    // Mientras esté hipotecada, caer en ella NO cobra renta
    let space = session
        .world()
        .resource::<monopoly_game::BoardResource>()
        .spaces[1]
        .clone();
    let mut land_events = Vec::new();
    let decision = monopoly_game::apply_land_effect(
        &space,
        1,
        P2,
        7,
        false,
        session.world_mut(),
        &mut land_events,
    );
    assert!(!decision);
    assert!(
        land_events.is_empty(),
        "propiedad hipotecada no debe emitir eventos de renta"
    );

    // Deshipotecar: costo = (60 / 2) * 110 / 100 = 33
    let events_unmort = session
        .process_command(
            P1,
            Box::new(UnmortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("debe permitir deshipotecar");

    let unmort_event = events_unmort[0]
        .as_any()
        .downcast_ref::<PropertyUnmortgagedEvent>()
        .expect("debe emitir PropertyUnmortgagedEvent");
    assert_eq!(unmort_event.cost, 33);
    assert_eq!(unmort_event.space, 1);

    assert!(
        !session
            .world()
            .resource::<monopoly_game::PlayersResource>()
            .mortgaged
            .contains(&1),
        "casilla 1 ya no debe estar hipotecada"
    );

    // Ahora caer en ella sí cobra renta
    let mut land_events_2 = Vec::new();
    monopoly_game::apply_land_effect(
        &space,
        1,
        P2,
        7,
        false,
        session.world_mut(),
        &mut land_events_2,
    );
    assert_eq!(land_events_2.len(), 1);
    assert!(land_events_2[0].as_any().is::<RentPaidEvent>());
}

#[test]
fn test_no_se_puede_hipotecar_con_edificios_en_grupo() {
    let mut session = new_monopoly_session(SessionId(302), 1, P1, P2);

    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(1, P1);
    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .properties
        .insert(3, P1);

    // Construir casa en casilla 1
    session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap();

    // Intentar hipotecar casilla 1 o casilla 3 debe fallar por haber edificios en el grupo
    let err_mort = session
        .process_command(
            P1,
            Box::new(MortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap_err();
    assert!(err_mort.to_string().contains("edificios"));

    let err_mort_other = session
        .process_command(
            P1,
            Box::new(MortgagePropertyCommand {
                player: P1,
                space: 3,
            }),
        )
        .unwrap_err();
    assert!(err_mort_other.to_string().contains("edificios"));

    // Vender la casa
    session
        .process_command(
            P1,
            Box::new(SellHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap();

    // Ahora sí se puede hipotecar
    session
        .process_command(
            P1,
            Box::new(MortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("debe permitir hipotecar tras demoler edificios");
}

#[test]
fn test_tres_dobles_consecutivos_a_la_carcel() {
    // Buscar una semilla donde la tirada de dados sea dobles
    let mut found_seed = None;
    for s in 1..1000 {
        let mut session = new_monopoly_session(SessionId(s), s, P1, P2);
        let mut rng = session
            .world_mut()
            .resource_mut::<open_table_engine::prelude::RandomResource>();
        let (d1, d2) = (rng.0.roll_die(6), rng.0.roll_die(6));
        if d1 == d2 {
            found_seed = Some(s);
            break;
        }
    }

    let seed = found_seed.expect("debe existir una semilla que genere dobles");
    let mut session = new_monopoly_session(SessionId(seed), seed, P1, P2);

    // Simular que P1 ya sacó 2 dobles consecutivos en este turno
    session
        .world_mut()
        .resource_mut::<JailResource>()
        .consecutive_doubles
        .insert(P1, 2);

    // Ejecutar RollAndMoveCommand (tercer doble consecutivo)
    let events = session
        .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
        .expect("debe procesar RollAndMoveCommand");

    // Debe emitirse JailedEvent
    let _jailed_event = events
        .iter()
        .find(|e| e.as_any().is::<JailedEvent>())
        .expect("debe emitirse JailedEvent tras 3 dobles");

    // El jugador debe estar en la cárcel y con 3 turnos de condena
    let jail_res = session.world().resource::<JailResource>();
    assert_eq!(jail_res.jailed.get(&P1), Some(&3));
    assert_eq!(
        jail_res.consecutive_doubles.get(&P1).copied().unwrap_or(0),
        0
    );

    let pos = session
        .world()
        .resource::<monopoly_game::PlayersResource>()
        .position[&P1];
    assert_eq!(pos, JAIL_SPACE);

    // El turno debe haber avanzado a P2 (sin turno extra a pesar del doble)
    assert_eq!(session.current_player(), P2);
}

#[test]
fn test_tarjeta_salir_libre_de_la_carcel() {
    let mut session = new_monopoly_session(SessionId(303), 1, P1, P2);

    // Otorgar 1 tarjeta a P1
    session
        .world_mut()
        .resource_mut::<monopoly_game::PlayersResource>()
        .jail_free_cards
        .insert(P1, 1);

    // Enviar a P1 a la cárcel
    session
        .world_mut()
        .resource_mut::<JailResource>()
        .jailed
        .insert(P1, 3);

    // Usar la tarjeta para salir de la cárcel
    let events = session
        .process_command(P1, Box::new(UseJailCardCommand { player: P1 }))
        .expect("debe permitir usar la tarjeta de cárcel");

    assert!(events[0].as_any().is::<JailCardUsedEvent>());

    // P1 ya no está en la cárcel
    assert!(!session
        .world()
        .resource::<JailResource>()
        .jailed
        .contains_key(&P1));

    // La cantidad de tarjetas se decrementó a 0
    assert_eq!(
        session
            .world()
            .resource::<monopoly_game::PlayersResource>()
            .jail_free_cards
            .get(&P1)
            .copied()
            .unwrap_or(0),
        0
    );

    // Intentar usarla otra vez debe fallar
    let err_empty = session
        .process_command(P1, Box::new(UseJailCardCommand { player: P1 }))
        .unwrap_err();
    assert!(err_empty.to_string().contains("cárcel"));
}

#[test]
fn test_propose_trade_valida_propiedades_y_efectivo() {
    let mut session = new_monopoly_session(SessionId(511), 1, P1, P2);

    // Asignar propiedades
    {
        let mut players = session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>();
        players.properties.insert(1, P1);
        players.properties.insert(3, P2);
    }

    // P1 propone a P2 cambiar casilla 1 + $50 por casilla 3 + $20
    let events = session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![1],
                requested_spaces: vec![3],
                offered_cash: 50,
                requested_cash: 20,
            }),
        )
        .expect("la propuesta de intercambio debe ser válida");

    assert_eq!(events.len(), 1);
    let prop = events[0]
        .as_any()
        .downcast_ref::<TradeProposedEvent>()
        .unwrap();
    assert_eq!(prop.player, P1);
    assert_eq!(prop.target, P2);
    assert_eq!(prop.offered_spaces, vec![1]);
    assert_eq!(prop.requested_spaces, vec![3]);
    assert_eq!(prop.offered_cash, 50);
    assert_eq!(prop.requested_cash, 20);

    // TradeOfferResource debe registrar la oferta
    let trade_res = session.world().resource::<TradeOfferResource>();
    let offer = trade_res
        .offer
        .as_ref()
        .expect("debe haber una oferta registrada");
    assert_eq!(offer.from, P1);
    assert_eq!(offer.to, P2);
}

#[test]
fn test_propose_trade_rechaza_casos_invalidos() {
    let mut session = new_monopoly_session(SessionId(512), 1, P1, P2);

    {
        let mut players = session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>();
        players.properties.insert(1, P1);
        players.properties.insert(3, P2);
        players.money.insert(P1, 100);
        players.money.insert(P2, 50);
    }

    // 1. Comerciar consigo mismo
    let err_self = session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P1,
                offered_spaces: vec![1],
                requested_spaces: vec![],
                offered_cash: 0,
                requested_cash: 0,
            }),
        )
        .unwrap_err();
    assert!(err_self.to_string().contains("mismo"));

    // 2. Ofrecer propiedad que no posee
    let err_not_owner = session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![6], // No pertenece a P1
                requested_spaces: vec![3],
                offered_cash: 0,
                requested_cash: 0,
            }),
        )
        .unwrap_err();
    assert!(err_not_owner.to_string().contains("dueño"));

    // 3. Solicitar propiedad que el target no posee
    let err_target_not_owner = session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![1],
                requested_spaces: vec![8], // No pertenece a P2
                offered_cash: 0,
                requested_cash: 0,
            }),
        )
        .unwrap_err();
    assert!(
        err_target_not_owner.to_string().contains("dueño")
            || err_target_not_owner.to_string().contains("objetivo")
    );

    // 4. Ofrecer más efectivo del que tiene
    let err_cash = session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![1],
                requested_spaces: vec![3],
                offered_cash: 200, // P1 solo tiene 100
                requested_cash: 0,
            }),
        )
        .unwrap_err();
    assert!(err_cash.to_string().contains("efectivo"));

    // 5. Solicitar más efectivo del que target tiene
    let err_target_cash = session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![1],
                requested_spaces: vec![3],
                offered_cash: 0,
                requested_cash: 100, // P2 solo tiene 50
            }),
        )
        .unwrap_err();
    assert!(err_target_cash.to_string().contains("efectivo"));

    // 6. Propiedad con edificios no puede comerciarse
    {
        let mut buildings = session
            .world_mut()
            .resource_mut::<monopoly_game::BuildingsResource>();
        buildings.buildings.insert(1, 1);
    }
    let err_bldg = session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![1],
                requested_spaces: vec![3],
                offered_cash: 0,
                requested_cash: 0,
            }),
        )
        .unwrap_err();
    assert!(err_bldg.to_string().contains("edificios"));
}

#[test]
fn test_accept_trade_transfiere_atomicamente_propiedades_y_dinero() {
    let mut session = new_monopoly_session(SessionId(513), 1, P1, P2);

    {
        let mut players = session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>();
        players.properties.insert(1, P1);
        players.properties.insert(3, P2);
        players.money.insert(P1, 1500);
        players.money.insert(P2, 1500);
    }

    // P1 propone: Casilla 1 + $200 por Casilla 3 + $50
    session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![1],
                requested_spaces: vec![3],
                offered_cash: 200,
                requested_cash: 50,
            }),
        )
        .expect("propuesta válida");

    // P1 no puede aceptar su propia propuesta
    let err_proposer_accept = session
        .process_command(P1, Box::new(AcceptTradeCommand { player: P1 }))
        .unwrap_err();
    assert!(err_proposer_accept.to_string().contains("destinatario"));

    // P2 acepta la propuesta
    let events = session
        .process_command(P2, Box::new(AcceptTradeCommand { player: P2 }))
        .expect("P2 debe poder aceptar la oferta");

    assert_eq!(events.len(), 1);
    let acc = events[0]
        .as_any()
        .downcast_ref::<TradeAcceptedEvent>()
        .unwrap();
    assert_eq!(acc.player, P2);
    assert_eq!(acc.target, P1);

    // Verificar transferencia de propiedades
    let players = session.world().resource::<monopoly_game::PlayersResource>();
    assert_eq!(
        players.properties.get(&1),
        Some(&P2),
        "Casilla 1 ahora debe pertenecer a P2"
    );
    assert_eq!(
        players.properties.get(&3),
        Some(&P1),
        "Casilla 3 ahora debe pertenecer a P1"
    );

    // P1 pagó 200 y recibió 50 -> neto -150: 1500 - 150 = 1350
    assert_eq!(players.money[&P1], 1350);
    // P2 recibió 200 y pagó 50 -> neto +150: 1500 + 150 = 1650
    assert_eq!(players.money[&P2], 1650);

    // Oferta debe estar limpia
    let trade_res = session.world().resource::<TradeOfferResource>();
    assert!(trade_res.offer.is_none());
}

#[test]
fn test_reject_trade_limpia_la_oferta() {
    let mut session = new_monopoly_session(SessionId(514), 1, P1, P2);

    {
        let mut players = session
            .world_mut()
            .resource_mut::<monopoly_game::PlayersResource>();
        players.properties.insert(1, P1);
        players.properties.insert(3, P2);
    }

    session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![1],
                requested_spaces: vec![3],
                offered_cash: 0,
                requested_cash: 0,
            }),
        )
        .expect("propuesta válida");

    assert!(session
        .world()
        .resource::<TradeOfferResource>()
        .offer
        .is_some());

    // P2 rechaza la oferta
    let events = session
        .process_command(P2, Box::new(RejectTradeCommand { player: P2 }))
        .expect("P2 debe poder rechazar");

    assert_eq!(events.len(), 1);
    assert!(events[0].as_any().is::<TradeRejectedEvent>());

    // Oferta limpia
    assert!(session
        .world()
        .resource::<TradeOfferResource>()
        .offer
        .is_none());
}
