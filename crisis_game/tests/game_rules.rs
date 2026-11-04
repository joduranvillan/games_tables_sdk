// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use crisis_game::{
    check_objective, new_crisis_session, AttackResolvedEvent, BoardResource, CardType,
    CardsExchangedEvent, DeclareAttackCommand, EliminatedPlayersResource, EndPhaseCommand,
    ExchangeCardsCommand, FortifyCommand, ObjectiveCard, PendingAttack, PendingAttackResource,
    PlaceArmiesCommand, PlayerCardsResource, PlayerEliminatedEvent, PlayerObjectivesResource,
    RollAttackCommand, TegGameOverEvent, TerritoryCard, TerritoryConqueredEvent, TerritoryId,
    TerritoryMapResource, TerritoryStateResource, TurnPhase, TurnStateResource,
    CONTINENT_SOUTH_AMERICA,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const P3: PlayerId = PlayerId(3);

#[test]
fn test_setup_distribuye_todos_los_territorios() {
    let session = new_crisis_session(SessionId(1), 42, &[P1, P2]).unwrap();
    let territory_state = session.world().resource::<TerritoryMapResource>();

    assert_eq!(territory_state.owners.len(), 30);
    assert_eq!(territory_state.armies.len(), 30);

    for t_id_u8 in 0..30u8 {
        let t_id = TerritoryId(t_id_u8);
        let owner = territory_state
            .owners
            .get(&t_id)
            .expect("cada territorio debe tener un dueño");
        let armies = territory_state
            .armies
            .get(&t_id)
            .expect("cada territorio debe tener cantidad de ejércitos");

        assert!(
            *owner == P1 || *owner == P2,
            "el dueño debe ser uno de los jugadores"
        );
        assert!(
            *armies >= 1,
            "cada territorio debe tener al menos 1 ejército"
        );
    }
}

#[test]
fn test_ataque_resolucion_dados_reduce_ejercitos() {
    let mut session = new_crisis_session(SessionId(1), 100, &[P1, P2]).unwrap();

    {
        let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
        turn_state.phase = TurnPhase::Attack;

        let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
        territory_state.set_owner_and_armies(TerritoryId(0), P1, 3);
        territory_state.set_owner_and_armies(TerritoryId(1), P2, 3);

        let mut pending_attack = session.world_mut().resource_mut::<PendingAttackResource>();
        pending_attack.attack = Some(PendingAttack {
            attacker: P1,
            from: TerritoryId(0),
            to: TerritoryId(1),
            dice: 2,
        });
    }

    let events = session
        .process_command(P1, Box::new(RollAttackCommand { player: P1 }))
        .expect("RollAttackCommand debe ejecutarse con éxito");

    let resolved_event = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<AttackResolvedEvent>())
        .expect("se debe emitir AttackResolvedEvent");

    assert_eq!(resolved_event.attacker, P1);
    assert_eq!(resolved_event.defender, P2);
    assert!(!resolved_event.attacker_rolls.is_empty());
    assert!(!resolved_event.defender_rolls.is_empty());
    assert_eq!(
        resolved_event.attacker_losses + resolved_event.defender_losses,
        std::cmp::min(
            resolved_event.attacker_rolls.len() as u32,
            resolved_event.defender_rolls.len() as u32
        )
    );
}

#[test]
fn test_conquista_transfiere_territorio_al_atacante() {
    // Probar con varias semillas hasta encontrar una donde la tirada de P1 (con 3 dados vs 1) sea victoriosa
    let mut conquered = false;
    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2]).unwrap();

        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;

            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 4);
            territory_state.set_owner_and_armies(TerritoryId(1), P2, 1);
        }

        let _ = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 3,
            }),
        );

        let events = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = events {
            if evts
                .iter()
                .any(|e| e.as_any().is::<TerritoryConqueredEvent>())
            {
                let territory_state = session.world().resource::<TerritoryStateResource>();
                assert_eq!(
                    territory_state.owners.get(&TerritoryId(1)).copied(),
                    Some(P1),
                    "el territorio 1 debe pertenecer a P1 tras la conquista"
                );
                conquered = true;
                break;
            }
        }
    }

    assert!(conquered, "debe haber ocurrido al menos una conquista");
}

#[test]
fn test_player_eliminado_sale_del_ciclo_de_turnos() {
    let mut conquered = false;

    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2, P3]).unwrap();

        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;

            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            // Asignar todos los territorios de P2 a P1 salvo el 1
            for t in 0..30u8 {
                let t_id = TerritoryId(t);
                if territory_state.owners.get(&t_id) == Some(&P2) && t != 1 {
                    territory_state.set_owner_and_armies(t_id, P1, 2);
                }
            }
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 4);
            territory_state.set_owner_and_armies(TerritoryId(1), P2, 1);
        }

        let _ = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 3,
            }),
        );

        let events = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = events {
            let has_eliminated = evts
                .iter()
                .any(|e| e.as_any().is::<PlayerEliminatedEvent>());

            if has_eliminated {
                // P2 fue eliminado por P1
                let eliminated_res = session.world().resource::<EliminatedPlayersResource>();
                assert!(eliminated_res.is_eliminated(P2));

                // Pasar fase de ataque -> fortify -> siguiente turno
                let _ = session.process_command(P1, Box::new(EndPhaseCommand { player: P1 }));
                let _ = session.process_command(P1, Box::new(EndPhaseCommand { player: P1 }));

                let turn_res = session.world().resource::<TurnResource>();
                assert_eq!(
                    turn_res.0.current_player(),
                    P3,
                    "el turno debe pasar a P3 salteando a P2 que está eliminado"
                );

                conquered = true;
                break;
            }
        }
    }

    assert!(conquered, "P2 debe ser eliminado y salteado en los turnos");
}

#[test]
fn test_game_over_por_objetivo_conquistar_continente() {
    let mut game_over_triggered = false;

    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2]).unwrap();

        {
            let mut player_objs = session
                .world_mut()
                .resource_mut::<PlayerObjectivesResource>();
            player_objs
                .objectives
                .insert(P1, ObjectiveCard::ConquerContinent(CONTINENT_SOUTH_AMERICA));

            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;

            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            // América del sur: 0, 1, 2, 3, 4
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 4);
            territory_state.set_owner_and_armies(TerritoryId(1), P1, 2);
            territory_state.set_owner_and_armies(TerritoryId(2), P1, 2);
            territory_state.set_owner_and_armies(TerritoryId(3), P1, 2);
            territory_state.set_owner_and_armies(TerritoryId(4), P2, 1);
        }

        let _ = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(4),
                dice: 3,
            }),
        );

        let events = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = events {
            if let Some(game_over_evt) = evts
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TegGameOverEvent>())
            {
                assert_eq!(game_over_evt.winner, P1);

                let game_over_res = session.world().resource::<GameOverResource>();
                assert!(game_over_res.0);

                let winner_res = session.world().resource::<WinnerResource>();
                assert_eq!(winner_res.0, Some(P1));

                game_over_triggered = true;
                break;
            }
        }
    }

    assert!(
        game_over_triggered,
        "debe dispararse TegGameOverEvent al cumplir el objetivo"
    );
}

#[test]
fn test_teg_board_initialization() {
    let session = new_crisis_session(SessionId(1), 1, &[P1, P2]).unwrap();
    let board = session.world().resource::<BoardResource>();
    assert_eq!(board.territories.len(), 30);
    assert_eq!(board.continents.len(), 6);
}

#[test]
fn test_objetivo_conquistar_continente_detecta_victoria() {
    let mut map = TerritoryStateResource::new();
    let players = vec![P1, P2];
    let eliminated = EliminatedPlayersResource::default();

    let sa_obj = ObjectiveCard::ConquerContinent(CONTINENT_SOUTH_AMERICA);

    map.set_owner_and_armies(TerritoryId(0), P1, 2);
    map.set_owner_and_armies(TerritoryId(1), P1, 2);
    map.set_owner_and_armies(TerritoryId(2), P1, 2);
    map.set_owner_and_armies(TerritoryId(3), P2, 1);
    map.set_owner_and_armies(TerritoryId(4), P2, 1);

    assert!(!check_objective(&sa_obj, &map, &players, &eliminated, P1));

    map.set_owner_and_armies(TerritoryId(3), P1, 2);
    map.set_owner_and_armies(TerritoryId(4), P1, 2);

    assert!(check_objective(&sa_obj, &map, &players, &eliminated, P1));
}

#[test]
fn test_bonus_de_continente_se_aplica_al_inicio_del_turno() {
    let mut session = new_crisis_session(SessionId(100), 1, &[P1, P2]).unwrap();

    // Asignar los 5 territorios de América del Sur (0, 1, 2, 3, 4) a P1
    {
        let mut map = session.world_mut().resource_mut::<TerritoryStateResource>();
        for &t_id in &[
            TerritoryId(0),
            TerritoryId(1),
            TerritoryId(2),
            TerritoryId(3),
            TerritoryId(4),
        ] {
            map.owners.insert(t_id, P1);
        }
        for t_id in 5u8..30 {
            map.owners.insert(TerritoryId(t_id), P2);
        }
    }

    {
        let mut turn = session.world_mut().resource_mut::<TurnResource>();
        turn.0.set_current_player(P2);
    }
    {
        let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
        turn_state.phase = TurnPhase::Fortify;
    }

    session
        .process_command(P2, Box::new(EndPhaseCommand { player: P2 }))
        .expect("P2 termina turno");

    assert_eq!(session.current_player(), P1);

    let turn_state = session.world().resource::<TurnStateResource>();
    if let TurnPhase::PlaceArmies { armies_remaining } = turn_state.phase {
        assert_eq!(
            armies_remaining, 5,
            "P1 debe recibir 3 ejércitos base + 2 de bonus por América del Sur = 5 ejércitos"
        );
    } else {
        panic!("P1 debería estar en la fase PlaceArmies");
    }
}

#[test]
fn test_serializar_y_deserializar_declare_attack_command_roundtrip() {
    let cmd = DeclareAttackCommand {
        player: P1,
        from: TerritoryId(0),
        to: TerritoryId(1),
        dice: 3,
    };
    let json = serde_json::to_string(&cmd).expect("serialización a JSON falló");
    let deserialized: DeclareAttackCommand =
        serde_json::from_str(&json).expect("deserialización de JSON falló");
    assert_eq!(cmd, deserialized);
}

#[test]
fn test_crisis_session_rechaza_mas_de_seis_jugadores() {
    let players = vec![
        PlayerId(1),
        PlayerId(2),
        PlayerId(3),
        PlayerId(4),
        PlayerId(5),
        PlayerId(6),
        PlayerId(7),
    ];
    let result = new_crisis_session(SessionId(1), 42, &players);
    assert!(matches!(
        result,
        Err(EngineError::InvalidCommand { reason }) if reason.contains("2 y 6 jugadores")
    ));
}

#[test]
fn test_crisis_error_paths_cobertura_de_ramas() {
    let mut session = new_crisis_session(SessionId(1), 42, &[P1, P2]).unwrap();

    // 1. Comando por un jugador que no es el turno actual
    let err = session
        .process_command(
            P2,
            Box::new(PlaceArmiesCommand {
                player: P2,
                territory: TerritoryId(0),
                count: 1,
            }),
        )
        .unwrap_err();
    assert!(format!("{err:?}").contains("no es tu turno"));

    // 2. Colocar ejércitos en territorio ajeno
    let p2_territory = session
        .world()
        .resource::<TerritoryStateResource>()
        .owners
        .iter()
        .find_map(|(t, &o)| if o == P2 { Some(*t) } else { None })
        .unwrap();

    let err = session
        .process_command(
            P1,
            Box::new(PlaceArmiesCommand {
                player: P1,
                territory: p2_territory,
                count: 1,
            }),
        )
        .unwrap_err();
    assert!(format!("{err:?}").contains("no te pertenece"));

    // 3. Colocar ejércitos con cantidad inválida (0 ó mayor a restantes)
    let p1_territory = session
        .world()
        .resource::<TerritoryStateResource>()
        .owners
        .iter()
        .find_map(|(t, &o)| if o == P1 { Some(*t) } else { None })
        .unwrap();

    let err = session
        .process_command(
            P1,
            Box::new(PlaceArmiesCommand {
                player: P1,
                territory: p1_territory,
                count: 0,
            }),
        )
        .unwrap_err();
    assert!(format!("{err:?}").contains("inválida"));

    // 4. Intentar pasar de fase sin colocar todos los ejércitos
    let err = session
        .process_command(P1, Box::new(EndPhaseCommand { player: P1 }))
        .unwrap_err();
    assert!(format!("{err:?}").contains("debe colocar todos los ejércitos"));

    // Forzar pasar a fase de ataque
    let armies_to_place = match session.world().resource::<TurnStateResource>().phase {
        TurnPhase::PlaceArmies { armies_remaining } => armies_remaining,
        _ => 0,
    };
    session
        .process_command(
            P1,
            Box::new(PlaceArmiesCommand {
                player: P1,
                territory: p1_territory,
                count: armies_to_place,
            }),
        )
        .unwrap();

    // 5. Atacar territorios no adyacentes
    // Forzar ejércitos
    session
        .world_mut()
        .resource_mut::<TerritoryStateResource>()
        .set_owner_and_armies(TerritoryId(0), P1, 5);
    session
        .world_mut()
        .resource_mut::<TerritoryStateResource>()
        .set_owner_and_armies(TerritoryId(29), P2, 1);

    let err = session
        .process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(29), // No adyacentes en el mapa
                dice: 1,
            }),
        )
        .unwrap_err();
    assert!(format!("{err:?}").contains("no es adyacente"));

    // 6. Atacar con dados inválidos (e.g. 0 o mas de max)
    session
        .world_mut()
        .resource_mut::<TerritoryStateResource>()
        .set_owner_and_armies(TerritoryId(1), P2, 1);
    let err = session
        .process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 5,
            }),
        )
        .unwrap_err();
    assert!(format!("{err:?}").contains("inválida"));

    // 7. Reagrupar en fase equivocada
    let err = session
        .process_command(
            P1,
            Box::new(FortifyCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                armies: 1,
            }),
        )
        .unwrap_err();
    assert!(format!("{err:?}").contains("no estás en la fase de fortificación"));
}

#[test]
fn test_primera_conquista_del_turno_roba_tarjeta_automaticamente() {
    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2]).unwrap();
        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;
            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 10);
            territory_state.set_owner_and_armies(TerritoryId(1), P2, 1);
        }

        let _ = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 3,
            }),
        );

        let events = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = events {
            if let Some(conq_evt) = evts
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TerritoryConqueredEvent>())
            {
                assert!(
                    conq_evt.card_drawn.is_some(),
                    "La primera conquista debe otorgar una tarjeta"
                );
                let drawn_card = conq_evt.card_drawn.as_ref().unwrap();

                let player_cards = session.world().resource::<PlayerCardsResource>();
                assert!(
                    player_cards.conquered_this_turn,
                    "conquered_this_turn debe ser true"
                );
                let p1_cards = player_cards
                    .cards
                    .get(&P1)
                    .expect("P1 debe tener lista de tarjetas");
                assert_eq!(p1_cards.len(), 1, "P1 debe tener exactamente 1 tarjeta");
                assert_eq!(
                    &p1_cards[0], drawn_card,
                    "La tarjeta en la mano debe ser la robada"
                );
                return;
            }
        }
    }
    panic!("No se pudo lograr una tirada victoriosa para el test");
}

#[test]
fn test_segunda_conquista_en_mismo_turno_no_roba_segunda_tarjeta() {
    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2]).unwrap();
        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;
            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 10);
            territory_state.set_owner_and_armies(TerritoryId(1), P2, 1);
            territory_state.set_owner_and_armies(TerritoryId(2), P2, 1);
        }

        // Primera conquista
        let _ = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 3,
            }),
        );
        let evts1 = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        let first_conq = evts1.is_ok()
            && evts1
                .unwrap()
                .iter()
                .any(|e| e.as_any().is::<TerritoryConqueredEvent>());
        if !first_conq {
            continue;
        }

        // Segunda conquista en el mismo turno
        let _ = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(2),
                dice: 3,
            }),
        );
        let evts2 = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = evts2 {
            if let Some(conq_evt2) = evts
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TerritoryConqueredEvent>())
            {
                assert!(
                    conq_evt2.card_drawn.is_none(),
                    "La segunda conquista en el mismo turno no debe robar tarjeta"
                );
                let player_cards = session.world().resource::<PlayerCardsResource>();
                let p1_cards = player_cards.cards.get(&P1).unwrap();
                assert_eq!(
                    p1_cards.len(),
                    1,
                    "P1 debe conservar solo 1 tarjeta robada en el turno"
                );
                return;
            }
        }
    }
    panic!("No se pudo lograr doble conquista para el test");
}

#[test]
fn test_conquista_con_cinco_tarjetas_no_roba_mas() {
    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2]).unwrap();
        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;
            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 10);
            territory_state.set_owner_and_armies(TerritoryId(1), P2, 1);

            let mut player_cards = session.world_mut().resource_mut::<PlayerCardsResource>();
            player_cards.cards.insert(
                P1,
                (0..5)
                    .map(|i| TerritoryCard {
                        territory: TerritoryId(i),
                        card_type: CardType::Infantry,
                    })
                    .collect(),
            );
        }

        let _ = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 3,
            }),
        );
        let events = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = events {
            if let Some(conq_evt) = evts
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TerritoryConqueredEvent>())
            {
                assert!(
                    conq_evt.card_drawn.is_none(),
                    "Con 5 tarjetas no se debe robar tarjeta adicional"
                );
                let player_cards = session.world().resource::<PlayerCardsResource>();
                assert_eq!(player_cards.cards.get(&P1).unwrap().len(), 5);
                return;
            }
        }
    }
    panic!("No se pudo lograr conquista para el test de límite de tarjetas");
}

#[test]
fn test_canje_de_tarjetas_con_territorio_propio_agrega_dos_ejercitos_directamente() {
    let mut session = new_crisis_session(SessionId(1), 42, &[P1, P2]).unwrap();
    {
        let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
        // P1 es dueño de los territorios 0 y 1 con 3 ejércitos cada uno
        territory_state.set_owner_and_armies(TerritoryId(0), P1, 3);
        territory_state.set_owner_and_armies(TerritoryId(1), P1, 3);
        // Territorio 2 pertenece a P2
        territory_state.set_owner_and_armies(TerritoryId(2), P2, 5);

        let mut player_cards = session.world_mut().resource_mut::<PlayerCardsResource>();
        player_cards.cards.insert(
            P1,
            vec![
                TerritoryCard {
                    territory: TerritoryId(0), // Propio
                    card_type: CardType::Infantry,
                },
                TerritoryCard {
                    territory: TerritoryId(1), // Propio
                    card_type: CardType::Cavalry,
                },
                TerritoryCard {
                    territory: TerritoryId(2), // Ajeno
                    card_type: CardType::Cannon,
                },
            ],
        );

        let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
        turn_state.phase = TurnPhase::PlaceArmies {
            armies_remaining: 3,
        };
    }

    let events = session
        .process_command(
            P1,
            Box::new(ExchangeCardsCommand {
                player: P1,
                card_indices: [0, 1, 2],
            }),
        )
        .expect("El canje debe ser exitoso");

    let exchanged_evt = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<CardsExchangedEvent>())
        .expect("Debe emitirse CardsExchangedEvent");
    assert_eq!(exchanged_evt.armies_gained, 4);

    let territory_state = session.world().resource::<TerritoryStateResource>();
    // Territorio 0 debe tener 3 iniciales + 2 de bono por tarjeta propia = 5
    assert_eq!(
        territory_state.armies.get(&TerritoryId(0)).copied(),
        Some(5),
        "Territorio 0 debe haber recibido +2 ejércitos directamente"
    );
    // Territorio 1 debe tener 3 iniciales + 2 de bono por tarjeta propia = 5
    assert_eq!(
        territory_state.armies.get(&TerritoryId(1)).copied(),
        Some(5),
        "Territorio 1 debe haber recibido +2 ejércitos directamente"
    );
    // Territorio 2 pertenece a P2, debe mantenerse en 5
    assert_eq!(
        territory_state.armies.get(&TerritoryId(2)).copied(),
        Some(5),
        "Territorio 2 ajeno no debe haber recibido bono"
    );

    // Además, el armies_remaining general debe ser 3 + 4 = 7
    let turn_state = session.world().resource::<TurnStateResource>();
    if let TurnPhase::PlaceArmies { armies_remaining } = turn_state.phase {
        assert_eq!(armies_remaining, 7);
    } else {
        panic!("La fase debe seguir siendo PlaceArmies");
    }
}
