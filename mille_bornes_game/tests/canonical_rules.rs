// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use mille_bornes_game::{
    new_mille_bornes_session, Card, CoupFourreCommand, DeckResource, DiscardCardCommand,
    DistancePlayedEvent, Hazard, PlayCardCommand, PlayDistanceCommand, PlayHazardCommand, Safety,
    SafetyPlayedEvent,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn canonical_las_4_safety_cards_otorgan_turno_extra_e_inmunidad() {
    let pairs = [
        (Safety::RightOfWay, Hazard::SpeedLimit),
        (Safety::ExtraTank, Hazard::OutOfGas),
        (Safety::PunctureProof, Hazard::FlatTire),
        (Safety::DrivingAce, Hazard::Accident),
    ];

    for (idx, (safety, hazard)) in pairs.iter().enumerate() {
        let mut session = new_mille_bornes_session(SessionId(518_20 + idx as u64), 1, P1, P2);
        {
            let mut deck = session.world_mut().resource_mut::<DeckResource>();
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
            .expect("jugar Safety debe ser válido");

        // Conserva el turno
        assert_eq!(session.current_player(), P1);

        // P1 descarta para pasar a P2
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

        // P2 intenta atacar con el Hazard bloqueado -> rechazado
        let res = session.process_command(
            P2,
            Box::new(PlayHazardCommand {
                player: P2,
                target: P1,
                hazard: *hazard,
            }),
        );
        assert!(matches!(res, Err(EngineError::InvalidCommand { .. })));
    }
}

#[test]
fn canonical_coup_fourre_con_safety_anula_peligro_y_suma_100_km() {
    let mut session = new_mille_bornes_session(SessionId(518_25), 1, P1, P2);

    session
        .process_command(
            P1,
            Box::new(DiscardCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .unwrap();

    {
        let mut deck = session.world_mut().resource_mut::<DeckResource>();
        deck.hands.get_mut(&P2).unwrap()[0] = Card::Hazard(Hazard::Accident);
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Safety(Safety::DrivingAce);
        deck.distance.insert(P1, 200);
    }

    session
        .process_command(
            P2,
            Box::new(PlayCardCommand {
                player: P2,
                card_index: 0,
            }),
        )
        .unwrap();

    let events = session
        .process_command(P1, Box::new(CoupFourreCommand { player: P1 }))
        .expect("CoupFourreCommand debe ejecutarse con éxito");

    assert!(events.iter().any(|e| e.as_any().is::<SafetyPlayedEvent>()));
    let dist = events
        .iter()
        .find_map(|e| e.as_any().downcast_ref::<DistancePlayedEvent>())
        .expect("debe emitir bono de 100 km");
    assert_eq!(dist.value, 100);
    assert_eq!(dist.new_distance, 300);

    let deck = session.world().resource::<DeckResource>();
    assert_eq!(deck.hazard[&P1], None);
    assert_eq!(deck.hazard[&P2], Some(Hazard::Accident));
    assert!(deck.safeties_played[&P1].contains(&Safety::DrivingAce));
}

#[test]
fn canonical_safety_cura_hazard_activo_y_limite_dos_cartas_200km() {
    let mut session = new_mille_bornes_session(SessionId(518_208), 1, P1, P2);
    {
        let mut deck = session.world_mut().resource_mut::<DeckResource>();
        deck.hazard.insert(P1, Some(Hazard::OutOfGas));
        deck.hands.get_mut(&P1).unwrap()[0] = Card::Safety(Safety::ExtraTank);
        deck.cards_200_played.insert(P1, 2);
    }

    // Jugar ExtraTank en turno propio cura OutOfGas inmediatamente y conserva el turno
    session
        .process_command(
            P1,
            Box::new(PlayCardCommand {
                player: P1,
                card_index: 0,
            }),
        )
        .expect("Safety debe curar el peligro correspondiente");
    assert_eq!(session.world().resource::<DeckResource>().hazard[&P1], None);
    assert_eq!(session.current_player(), P1);

    // Intentar jugar una 3ª carta de 200 km debe ser rechazado
    assert!(session
        .process_command(
            P1,
            Box::new(PlayDistanceCommand {
                player: P1,
                distance: 200,
            }),
        )
        .is_err());
}
