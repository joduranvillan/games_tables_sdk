use crisis_game::{
    new_crisis_session, CardType, CardsExchangedEvent, DeclareAttackCommand, EndPhaseCommand,
    ExchangeCardsCommand, ObjectiveCard, PlaceArmiesCommand, PlayerCardsResource, PlayerEliminatedEvent,
    PlayerObjectivesResource, RollAttackCommand, TegGameOverEvent, TerritoryCard, TerritoryId,
    TerritoryStateResource, TurnPhase, TurnStateResource, CONTINENT_SOUTH_AMERICA,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const P3: PlayerId = PlayerId(3);

#[test]
fn test_partida_teg_de_dos_jugadores_hasta_victoria_por_objetivo() {
    let mut game_over_triggered = false;

    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2]).unwrap();

        {
            let mut player_objs = session.world_mut().resource_mut::<PlayerObjectivesResource>();
            player_objs.objectives.insert(
                P1,
                ObjectiveCard::ConquerContinent(CONTINENT_SOUTH_AMERICA),
            );

            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;

            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            // América del Sur: territorios 0, 1, 2, 3, 4
            // P1 controla 0, 1, 2, 3
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 10);
            territory_state.set_owner_and_armies(TerritoryId(1), P1, 2);
            territory_state.set_owner_and_armies(TerritoryId(2), P1, 2);
            territory_state.set_owner_and_armies(TerritoryId(3), P1, 2);
            // P2 controla 4 con 1 solo ejército
            territory_state.set_owner_and_armies(TerritoryId(4), P2, 1);
        }

        let declare_res = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(4),
                dice: 3,
            }),
        );
        if declare_res.is_err() {
            continue;
        }

        let events = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = events {
            if let Some(game_over_evt) = evts
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TegGameOverEvent>())
            {
                assert_eq!(game_over_evt.winner, P1);
                assert!(session.world().resource::<GameOverResource>().0);
                assert_eq!(session.world().resource::<WinnerResource>().0, Some(P1));
                game_over_triggered = true;
                break;
            }
        }
    }

    assert!(
        game_over_triggered,
        "Debe alcanzarse la victoria por objetivo y emitir TegGameOverEvent"
    );
}

#[test]
fn test_canje_de_tarjetas_da_ejercitos_extra() {
    let mut session = new_crisis_session(SessionId(1), 42, &[P1, P2]).unwrap();

    {
        let mut player_cards = session.world_mut().resource_mut::<PlayerCardsResource>();
        player_cards.cards.insert(
            P1,
            vec![
                TerritoryCard {
                    territory: TerritoryId(0),
                    card_type: CardType::Infantry,
                },
                TerritoryCard {
                    territory: TerritoryId(1),
                    card_type: CardType::Infantry,
                },
                TerritoryCard {
                    territory: TerritoryId(2),
                    card_type: CardType::Infantry,
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
        .expect("ExchangeCardsCommand debe ejecutarse con éxito");

    let exchanged_evt = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<CardsExchangedEvent>())
        .expect("Debe emitirse CardsExchangedEvent");

    assert_eq!(exchanged_evt.player, P1);
    assert_eq!(exchanged_evt.armies_gained, 4);

    let turn_state = session.world().resource::<TurnStateResource>();
    if let TurnPhase::PlaceArmies { armies_remaining } = turn_state.phase {
        assert_eq!(
            armies_remaining, 7,
            "Debe tener 3 ejércitos iniciales + 4 por el primer canje = 7 ejércitos"
        );
    } else {
        panic!("La fase debe seguir siendo PlaceArmies");
    }
}

#[test]
fn test_eliminacion_de_jugador_con_tres_jugadores() {
    let mut eliminated = false;

    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(1), seed, &[P1, P2, P3]).unwrap();

        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;

            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            // Asignar todos los territorios de P3 a P1 excepto el territorio 1
            for t in 0..30u8 {
                let t_id = TerritoryId(t);
                if territory_state.owners.get(&t_id) == Some(&P3) && t != 1 {
                    territory_state.set_owner_and_armies(t_id, P1, 2);
                }
            }
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 10);
            territory_state.set_owner_and_armies(TerritoryId(1), P3, 1);
        }

        let declare_res = session.process_command(
            P1,
            Box::new(DeclareAttackCommand {
                player: P1,
                from: TerritoryId(0),
                to: TerritoryId(1),
                dice: 3,
            }),
        );
        if declare_res.is_err() {
            continue;
        }

        let events = session.process_command(P1, Box::new(RollAttackCommand { player: P1 }));
        if let Ok(evts) = events {
            if evts
                .iter()
                .any(|e| e.as_any().is::<PlayerEliminatedEvent>())
            {
                // P3 fue eliminado. Avanzamos de fase P1 (Ataque -> Fortify -> Siguiente turno)
                session
                    .process_command(P1, Box::new(EndPhaseCommand { player: P1 }))
                    .unwrap();
                session
                    .process_command(P1, Box::new(EndPhaseCommand { player: P1 }))
                    .unwrap();

                // El turno pasa a P2
                assert_eq!(session.current_player(), P2);

                // P2 coloca sus ejércitos antes de avanzar de fase
                let armies = match session.world().resource::<TurnStateResource>().phase {
                    TurnPhase::PlaceArmies { armies_remaining } => armies_remaining,
                    _ => 0,
                };
                if armies > 0 {
                    let p2_territory = session
                        .world()
                        .resource::<TerritoryStateResource>()
                        .owners
                        .iter()
                        .find_map(|(t, &owner)| if owner == P2 { Some(*t) } else { None })
                        .unwrap();
                    session
                        .process_command(
                            P2,
                            Box::new(PlaceArmiesCommand {
                                player: P2,
                                territory: p2_territory,
                                count: armies,
                            }),
                        )
                        .unwrap();
                }

                // Avanzamos turno de P2
                session
                    .process_command(P2, Box::new(EndPhaseCommand { player: P2 }))
                    .unwrap();
                session
                    .process_command(P2, Box::new(EndPhaseCommand { player: P2 }))
                    .unwrap();

                // El turno vuelve a P1 (salteando a P3)
                assert_eq!(session.current_player(), P1);

                eliminated = true;
                break;
            }
        }
    }

    assert!(
        eliminated,
        "P3 debe ser eliminado y los turnos deben ciclar únicamente entre P1 y P2"
    );
}
