use mille_bornes_game::{
    new_mille_bornes_session, Card, CardDiscardedEvent, CoupFourreCommand, DiscardCardCommand,
    DrawCardCommand, GameOverEvent, Hazard, HazardPlayedEvent, PlayCardCommand, PlayHazardCommand,
    Safety, SafetyPlayedEvent, MAX_HAND_SIZE, TARGET_DISTANCE, WIN_DISTANCE,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn el_setup_reparte_manos_privadas_de_tamano_correcto() {
    let session = new_mille_bornes_session(SessionId(1), 1, P1, P2);
    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.hands[&P1].len(), MAX_HAND_SIZE);
    assert_eq!(deck.hands[&P2].len(), MAX_HAND_SIZE);
    assert_eq!(deck.distance[&P1], 0);
    assert_eq!(deck.distance[&P2], 0);
}

#[test]
fn robar_agrega_una_carta_a_la_mano_y_es_evento_privado() {
    let mut session = new_mille_bornes_session(SessionId(2), 1, P1, P2);

    // El setup ya reparte la mano al tamaño máximo; sacamos una carta
    // primero (simulando que ya jugó algo) para poder robar de nuevo.
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P1).unwrap().pop();
    }

    let events = session
        .process_command(P1, Box::new(DrawCardCommand { player: P1 }))
        .expect("robar debería funcionar");

    assert_eq!(events.len(), 1);
    assert!(events[0].visibility().includes(P1));
    assert!(
        !events[0].visibility().includes(P2),
        "el rival no debería ver qué carta robaste"
    );

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(
        deck.hands[&P1].len(),
        MAX_HAND_SIZE,
        "sacamos una y robamos una, vuelve al tamaño máximo"
    );
}

#[test]
fn jugar_una_carta_de_distancia_avanza_y_pasa_el_turno() {
    let mut session = new_mille_bornes_session(SessionId(3), 1, P1, P2);

    // Forzamos una carta de distancia conocida en la mano de P1 para que
    // el test no dependa de qué le tocó al azar.
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Distance(50);
    }

    let events = session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("jugar la carta de distancia debería funcionar");

    let played = events[0]
        .as_any()
        .downcast_ref::<mille_bornes_game::DistancePlayedEvent>()
        .unwrap();
    assert_eq!(played.value, 50);
    assert_eq!(played.new_distance, 50);
    assert_eq!(session.current_player(), P2);
}

#[test]
fn un_peligro_impide_que_el_rival_juegue_distancia_hasta_curarse() {
    let mut session = new_mille_bornes_session(SessionId(4), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Hazard(Hazard::FlatTire);
    }

    let events = session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("jugar el peligro debería funcionar");
    let hazard_event = events[0]
        .as_any()
        .downcast_ref::<HazardPlayedEvent>()
        .unwrap();
    assert_eq!(hazard_event.target, P2);

    // P2 intenta avanzar estando con una goma pinchada: rechazado.
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P2).unwrap()[0] = Card::Distance(25);
    }
    let result = session.process_command(
        P2,
        Box::new(PlayCardCommand {
            player: P2,
            card_index: 0,
        }),
    );
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));

    // P2 se cura con la rueda de auxilio, y ahora sí puede avanzar.
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        // La rueda de auxilio quedó en el índice 0 tal como estaba antes
        // (la jugada anterior fue rechazada, no se consumió la carta);
        // insertamos el remedio en el índice 0 para reemplazar la carta
        // de distancia que probamos recién.
        deck.hands.get_mut(&P2).unwrap()[0] = Card::Remedy(Hazard::FlatTire);
    }
    session
        .process_command(
            P2,
            Box::new(PlayCardCommand {
                player: P2,
                card_index: 0,
            }),
        )
        .expect("el remedio debería curar la goma pinchada");

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.hazard[&P2], None);
}

#[test]
fn llegar_exacto_a_la_meta_termina_la_partida() {
    let mut session = new_mille_bornes_session(SessionId(5), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.distance.insert(P1, TARGET_DISTANCE - 25);
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Distance(25);
    }

    let events = session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("la jugada final debería ser válida");

    assert!(events.iter().any(|e| e
        .as_any()
        .downcast_ref::<GameOverEvent>()
        .map(|go| go.winner)
        == Some(P1)));
}

#[test]
fn una_jugada_que_pasaria_la_meta_es_rechazada() {
    let mut session = new_mille_bornes_session(SessionId(6), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.distance.insert(P1, TARGET_DISTANCE - 25);
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Distance(50);
    }

    let result = session.process_command(
        P1,
        Box::new(PlayCardCommand {
            player: P1,
            card_index: 0,
        }),
    );
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn descartar_una_carta_pasa_el_turno_y_va_al_descarte() {
    let mut session = new_mille_bornes_session(SessionId(7), 1, P1, P2);
    let card_to_discard = {
        let deck = session
            .world()
            .resource::<mille_bornes_game::DeckResource>();
        deck.hands[&P1][0]
    };

    let events = session
        .process_command(
            P1,
            Box::new(DiscardCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("descartar carta válida");

    let discarded = events[0]
        .as_any()
        .downcast_ref::<CardDiscardedEvent>()
        .unwrap();
    assert_eq!(discarded.card, card_to_discard);
    assert_eq!(session.current_player(), P2);

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.discard_pile.len(), 1);
    assert_eq!(deck.discard_pile[0], card_to_discard);
}

#[test]
fn limite_de_velocidad_permite_cartas_de_25_o_50_pero_bloquea_mayores() {
    let mut session = new_mille_bornes_session(SessionId(8), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hazard.insert(P1, Some(Hazard::SpeedLimit));
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Distance(75);
        deck.hands.get_mut(&P1).unwrap()[1] = Card::Distance(50);
    }

    // Intentar jugar 75 bajo límite de velocidad falla
    let result = session.process_command(
        P1,
        Box::new(PlayCardCommand {
            player: P1,
            card_index: 0,
        }),
    );
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));

    // Jugar 50 sí funciona
    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 1,
            }),
        )
        .expect("50 km/h está dentro del límite de velocidad");

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.distance[&P1], 50);
}

#[test]
fn test_coup_fourre_contraataca_y_anula_peligro() {
    let mut session = new_mille_bornes_session(SessionId(9), 1, P1, P2);

    session
        .process_command(
            P1,
            Box::new(DiscardCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("P1 descarta para pasar turno");

    assert_eq!(session.current_player(), P2);

    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P2).unwrap()[0] = Card::Hazard(Hazard::FlatTire);
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Remedy(Hazard::FlatTire);
    }

    session
        .process_command(
            P2,
            Box::new(PlayCardCommand {
                player: P2,
                card_index: 0,
            }),
        )
        .expect("P2 juega peligro FlatTire");

    {
        let deck = session
            .world()
            .resource::<mille_bornes_game::DeckResource>();
        assert_eq!(deck.hazard[&P1], Some(Hazard::FlatTire));
    }

    session
        .process_command(P1, Box::new(CoupFourreCommand { player: P1 }))
        .expect("P1 debe poder hacer Coup Fourré");

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.hazard[&P1], None, "el peligro de P1 debe ser anulado");
    assert_eq!(
        deck.hazard[&P2],
        Some(Hazard::FlatTire),
        "P2 debe quedar marcado con FlatTire"
    );
}

#[test]
fn test_limite_de_velocidad_rechaza_distancia_mayor_a_50() {
    let mut session = new_mille_bornes_session(SessionId(10), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Distance(75);
    }
    {
        let mut speed_res = session
            .world_mut()
            .resource_mut::<mille_bornes_game::SpeedLimitResource>();
        speed_res.limited.insert(P1);
    }

    let result = session.process_command(
        P1,
        Box::new(mille_bornes_game::PlayDistanceCommand {
            player: P1,
            distance: 75,
        }),
    );
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "con limite de velocidad no se puede jugar distancia mayor a 50"
    );
}

#[test]
fn test_derecho_de_via_bloquea_todos_los_hazards() {
    let mut session = new_mille_bornes_session(SessionId(11), 1, P1, P2);
    {
        let mut row = session
            .world_mut()
            .resource_mut::<mille_bornes_game::RightOfWayResource>();
        row.active.insert(P1);
    }

    session
        .process_command(
            P1,
            Box::new(DiscardCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .unwrap();

    let result = session.process_command(
        P2,
        Box::new(mille_bornes_game::PlayHazardCommand {
            player: P2,
            target: P1,
            hazard: Hazard::FlatTire,
        }),
    );
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "derecho de via debe bloquear los hazards"
    );
}

#[test]
fn test_tercera_carta_200_es_rechazada() {
    let mut session = new_mille_bornes_session(SessionId(12), 1, P1, P2);

    session
        .process_command(
            P1,
            Box::new(mille_bornes_game::PlayDistanceCommand {
                player: P1,
                distance: 200,
            }),
        )
        .expect("primera carta de 200 es valida");

    session
        .process_command(
            P2,
            Box::new(DiscardCardCommand {
                player: P2,
                card_index: 0,
            }),
        )
        .unwrap();

    session
        .process_command(
            P1,
            Box::new(mille_bornes_game::PlayDistanceCommand {
                player: P1,
                distance: 200,
            }),
        )
        .expect("segunda carta de 200 es valida");

    session
        .process_command(
            P2,
            Box::new(DiscardCardCommand {
                player: P2,
                card_index: 0,
            }),
        )
        .unwrap();

    let result = session.process_command(
        P1,
        Box::new(mille_bornes_game::PlayDistanceCommand {
            player: P1,
            distance: 200,
        }),
    );
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "la tercera carta de 200 km debe ser rechazada"
    );
}

#[test]
fn test_extension_de_viaje_a_1000_cuando_se_agotan_las_200() {
    let mut session = new_mille_bornes_session(SessionId(13), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.target_distance = 700;
    }

    session
        .process_command(
            P1,
            Box::new(mille_bornes_game::PlayDistanceCommand {
                player: P1,
                distance: 200,
            }),
        )
        .unwrap();

    session
        .process_command(
            P2,
            Box::new(mille_bornes_game::PlayDistanceCommand {
                player: P2,
                distance: 200,
            }),
        )
        .unwrap();

    session
        .process_command(
            P1,
            Box::new(mille_bornes_game::PlayDistanceCommand {
                player: P1,
                distance: 200,
            }),
        )
        .unwrap();

    let events = session
        .process_command(
            P2,
            Box::new(mille_bornes_game::PlayDistanceCommand {
                player: P2,
                distance: 200,
            }),
        )
        .expect("se completa la segunda carta de 200 de P2");

    assert!(
        events.iter().any(|e| e
            .as_any()
            .downcast_ref::<mille_bornes_game::TripExtendedEvent>()
            .is_some()),
        "debe emitirse el TripExtendedEvent al agotarse las cartas de 200"
    );

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.target_distance, 1000);
}

#[test]
fn test_gana_con_1000km() {
    let mut session = new_mille_bornes_session(SessionId(100), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.distance.insert(P1, 800);
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Distance(200);
    }

    let events = session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("jugar carta de 200 para llegar a 1000 km");

    let played = events
        .iter()
        .find_map(|e| {
            e.as_any()
                .downcast_ref::<mille_bornes_game::DistancePlayedEvent>()
        })
        .expect("DistancePlayedEvent");
    assert_eq!(played.new_distance, 1000);

    let game_over = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
        .expect("GameOverEvent al alcanzar 1000 km");
    assert_eq!(game_over.winner, P1);

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.distance[&P1], 1000);
    assert_eq!(WIN_DISTANCE, 1000);
}

#[test]
fn test_las_4_cartas_de_seguridad_bloquean_sus_hazards_especificos() {
    let safeties_and_hazards = [
        (Safety::RightOfWay, Hazard::SpeedLimit),
        (Safety::ExtraTank, Hazard::OutOfGas),
        (Safety::PunctureProof, Hazard::FlatTire),
        (Safety::DrivingAce, Hazard::Accident),
    ];

    for (i, (safety, hazard)) in safeties_and_hazards.iter().enumerate() {
        let mut session = new_mille_bornes_session(SessionId(200 + i as u64), 1, P1, P2);
        // P1 juega su carta de seguridad
        {
            let mut deck = session
                .world_mut()
                .resource_mut::<mille_bornes_game::DeckResource>();
            deck.hands.get_mut(&P1).unwrap()[0] = Card::Safety(*safety);
        }
        session
            .process_command(
                P1,
                Box::new(PlayCardCommand {
                    player: P1,
                    card_index: 0,
                }),
            )
            .expect("jugar carta de seguridad debe ser válido");

        // Turno extra: P1 sigue teniendo el turno
        assert_eq!(session.current_player(), P1);

        // P1 descarta para ceder turno a P2
        session
            .process_command(
                P1,
                Box::new(DiscardCardCommand {
                    player: P1,
                    card_index: 0,
                }),
            )
            .expect("P1 descarta");
        assert_eq!(session.current_player(), P2);

        // P2 intenta jugar el peligro bloqueado por esa seguridad
        let result = session.process_command(
            P2,
            Box::new(PlayHazardCommand {
                player: P2,
                target: P1,
                hazard: *hazard,
            }),
        );
        assert!(
            matches!(result, Err(EngineError::InvalidCommand { .. })),
            "Safety {:?} debe bloquear Hazard {:?}",
            safety,
            hazard
        );
    }
}

#[test]
fn test_extra_tank_cura_inmediatamente_out_of_gas() {
    let mut session = new_mille_bornes_session(SessionId(300), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hazard.insert(P1, Some(Hazard::OutOfGas));
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Safety(Safety::ExtraTank);
    }

    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("jugar ExtraTank debe ser válido");

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.hazard[&P1], None, "ExtraTank debe curar inmediatamente OutOfGas");
    assert!(deck.safeties_played[&P1].contains(&Safety::ExtraTank));
}

#[test]
fn test_turno_extra_al_jugar_carta_de_seguridad() {
    let mut session = new_mille_bornes_session(SessionId(301), 1, P1, P2);
    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Safety(Safety::DrivingAce);
    }

    assert_eq!(session.current_player(), P1);
    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("P1 juega DrivingAce");

    // Debe conservar el turno
    assert_eq!(
        session.current_player(),
        P1,
        "jugar carta de seguridad debe otorgar turno extra (no avanzar turno)"
    );
}

#[test]
fn test_coup_fourre_con_safety_otorga_bono_100_inmunidad_y_anula_peligro() {
    let mut session = new_mille_bornes_session(SessionId(302), 1, P1, P2);
    // P1 descarta para pasar turno a P2
    session
        .process_command(
            P1,
            Box::new(DiscardCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .unwrap();
    assert_eq!(session.current_player(), P2);

    {
        let mut deck = session
            .world_mut()
            .resource_mut::<mille_bornes_game::DeckResource>();
        deck.hands.get_mut(&P2).unwrap()[0] = Card::Hazard(Hazard::Accident);
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Safety(Safety::DrivingAce);
        deck.distance.insert(P1, 100);
    }

    // P2 ataca a P1 con Accident
    session
        .process_command(
            P2,
            Box::new(PlayCardCommand {
                player: P2,
                card_index: 0,
            }),
        )
        .expect("P2 juega peligro Accident");

    {
        let deck = session
            .world()
            .resource::<mille_bornes_game::DeckResource>();
        assert_eq!(deck.hazard[&P1], Some(Hazard::Accident));
    }

    // P1 responde con Coup Fourré
    let events = session
        .process_command(P1, Box::new(CoupFourreCommand { player: P1 }))
        .expect("P1 realiza Coup Fourré");

    // Verificar eventos: SafetyPlayedEvent, DistancePlayedEvent (+100), HazardPlayedEvent
    assert!(events.iter().any(|e| e.as_any().is::<SafetyPlayedEvent>()));
    let dist_ev = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<mille_bornes_game::DistancePlayedEvent>())
        .expect("debe emitir DistancePlayedEvent por bono de 100 km");
    assert_eq!(dist_ev.value, 100);
    assert_eq!(dist_ev.new_distance, 200);

    let deck = session
        .world()
        .resource::<mille_bornes_game::DeckResource>();
    assert_eq!(deck.hazard[&P1], None, "el peligro de P1 debe ser anulado");
    assert_eq!(deck.hazard[&P2], Some(Hazard::Accident), "P2 sufre el peligro reflejado");
    assert_eq!(deck.distance[&P1], 200, "P1 recibe bono de 100 km");
    assert!(
        deck.safeties_played[&P1].contains(&Safety::DrivingAce),
        "P1 obtiene inmunidad permanente de DrivingAce"
    );
}

#[test]
fn test_build_deck_contiene_las_4_safeties() {
    let deck = mille_bornes_game::deck::build_deck();
    assert!(deck.contains(&Card::Safety(Safety::RightOfWay)));
    assert!(deck.contains(&Card::Safety(Safety::ExtraTank)));
    assert!(deck.contains(&Card::Safety(Safety::PunctureProof)));
    assert!(deck.contains(&Card::Safety(Safety::DrivingAce)));
}

