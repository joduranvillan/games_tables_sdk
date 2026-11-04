use crisis_game::{
    new_crisis_session, CardType, CardsExchangedEvent, DeclareAttackCommand, ExchangeCardsCommand,
    PlayerCardsResource, RollAttackCommand, TerritoryCard, TerritoryConqueredEvent, TerritoryId,
    TerritoryStateResource, TurnPhase, TurnStateResource,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn canonical_robo_de_territory_card_al_conquistar_y_bono_mas_dos_por_pais_propio() {
    let mut conquered_once = false;
    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(518_50), seed, &[P1, P2]).unwrap();
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

        if let Ok(evts) = session.process_command(P1, Box::new(RollAttackCommand { player: P1 })) {
            if let Some(conq) = evts
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TerritoryConqueredEvent>())
            {
                assert!(
                    conq.card_drawn.is_some(),
                    "la primera conquista del turno debe otorgar una TerritoryCard"
                );
                let player_cards = session.world().resource::<PlayerCardsResource>();
                assert_eq!(player_cards.cards[&P1].len(), 1);
                conquered_once = true;
                break;
            }
        }
    }
    assert!(conquered_once);

    // Verificar bono +2 ejércitos directo sobre países propios al canjear tarjetas
    let mut session = new_crisis_session(SessionId(518_51), 42, &[P1, P2]).unwrap();
    {
        let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
        territory_state.set_owner_and_armies(TerritoryId(0), P1, 3);
        territory_state.set_owner_and_armies(TerritoryId(1), P1, 3);
        territory_state.set_owner_and_armies(TerritoryId(2), P2, 5);

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
                    card_type: CardType::Cavalry,
                },
                TerritoryCard {
                    territory: TerritoryId(2),
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
        .expect("canje de 3 tarjetas distintas debe ser válido");

    let exchanged = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<CardsExchangedEvent>())
        .unwrap();
    assert_eq!(exchanged.armies_gained, 4);

    let territory_state = session.world().resource::<TerritoryStateResource>();
    assert_eq!(territory_state.armies[&TerritoryId(0)], 5);
    assert_eq!(territory_state.armies[&TerritoryId(1)], 5);
    assert_eq!(territory_state.armies[&TerritoryId(2)], 5);
}

#[test]
fn canonical_maximo_una_tarjeta_por_turno_y_rechazo_canje_invalido() {
    // 1. Segunda conquista en el mismo turno (conquered_this_turn == true) no otorga 2ª tarjeta
    let mut second_conquest_checked = false;
    for seed in 1..200 {
        let mut session = new_crisis_session(SessionId(518_211), seed, &[P1, P2]).unwrap();
        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;
            let mut territory_state = session.world_mut().resource_mut::<TerritoryStateResource>();
            territory_state.set_owner_and_armies(TerritoryId(0), P1, 10);
            territory_state.set_owner_and_armies(TerritoryId(1), P2, 1);
            let mut player_cards = session.world_mut().resource_mut::<PlayerCardsResource>();
            player_cards.conquered_this_turn = true;
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
        if let Ok(evts) = session.process_command(P1, Box::new(RollAttackCommand { player: P1 })) {
            if let Some(conq) = evts
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<TerritoryConqueredEvent>())
            {
                assert!(
                    conq.card_drawn.is_none(),
                    "una segunda conquista en el mismo turno no debe otorgar otra tarjeta"
                );
                second_conquest_checked = true;
                break;
            }
        }
    }
    assert!(second_conquest_checked);

    // 2. Canje inválido (2 iguales + 1 distinta sin comodín) debe ser rechazado
    let mut session = new_crisis_session(SessionId(518_212), 42, &[P1, P2]).unwrap();
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
                    card_type: CardType::Cavalry,
                },
            ],
        );
        let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
        turn_state.phase = TurnPhase::PlaceArmies {
            armies_remaining: 3,
        };
    }

    assert!(session
        .process_command(
            P1,
            Box::new(ExchangeCardsCommand {
                player: P1,
                card_indices: [0, 1, 2],
            }),
        )
        .is_err());
}
