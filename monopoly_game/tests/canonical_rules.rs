use monopoly_game::{
    apply_land_effect, new_monopoly_session, AcceptTradeCommand, BoardResource, BuildHouseCommand,
    BuildingsResource, HouseBuiltEvent, HouseSoldEvent, JailCardUsedEvent, JailResource,
    JailedEvent, MortgagePropertyCommand, PlayersResource, PropertyMortgagedEvent,
    PropertyUnmortgagedEvent, ProposeTradeCommand, RollAndMoveCommand, SellHouseCommand,
    TradeAcceptedEvent, UnmortgagePropertyCommand, UseJailCardCommand, JAIL_SPACE,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn canonical_casas_hoteles_e_hipotecas() {
    let mut session = new_monopoly_session(SessionId(518_30), 1, P1, P2);

    {
        let mut players = session.world_mut().resource_mut::<PlayersResource>();
        players.properties.insert(1, P1);
        players.properties.insert(3, P1);
    }

    // Construcción uniforme hasta Hotel (nivel 5)
    for _ in 1..=5 {
        let ev1 = session
            .process_command(
                P1,
                Box::new(BuildHouseCommand {
                    player: P1,
                    space: 1,
                }),
            )
            .unwrap();
        assert!(ev1[0].as_any().is::<HouseBuiltEvent>());

        let ev3 = session
            .process_command(
                P1,
                Box::new(BuildHouseCommand {
                    player: P1,
                    space: 3,
                }),
            )
            .unwrap();
        assert!(ev3[0].as_any().is::<HouseBuiltEvent>());
    }

    assert_eq!(
        session
            .world()
            .resource::<BuildingsResource>()
            .buildings
            .get(&1),
        Some(&5)
    );

    // No se puede hipotecar con edificios en el grupo
    assert!(session
        .process_command(
            P1,
            Box::new(MortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .is_err());

    // Desmonte uniforme hasta 0 edificios
    for _ in 1..=5 {
        let s1 = session
            .process_command(
                P1,
                Box::new(SellHouseCommand {
                    player: P1,
                    space: 1,
                }),
            )
            .unwrap();
        assert!(s1[0].as_any().is::<HouseSoldEvent>());

        let s3 = session
            .process_command(
                P1,
                Box::new(SellHouseCommand {
                    player: P1,
                    space: 3,
                }),
            )
            .unwrap();
        assert!(s3[0].as_any().is::<HouseSoldEvent>());
    }

    // Hipoteca (50%) y deshipoteca (55%)
    let mort = session
        .process_command(
            P1,
            Box::new(MortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("hipotecar tras vender casas debe ser válido");
    assert_eq!(
        mort[0]
            .as_any()
            .downcast_ref::<PropertyMortgagedEvent>()
            .unwrap()
            .amount,
        30
    );

    let unmort = session
        .process_command(
            P1,
            Box::new(UnmortgagePropertyCommand {
                player: P1,
                space: 1,
            }),
        )
        .expect("deshipotecar debe ser válido");
    assert_eq!(
        unmort[0]
            .as_any()
            .downcast_ref::<PropertyUnmortgagedEvent>()
            .unwrap()
            .cost,
        33
    );
}

#[test]
fn canonical_tres_dobles_a_carcel_e_intercambios() {
    let seed = (1..1000u64)
        .find(|&s| {
            let mut rng = RandomService::from_seed(s);
            rng.roll_die(6) == rng.roll_die(6)
        })
        .expect("debe existir seed con dobles");

    let mut session = new_monopoly_session(SessionId(518_31), seed, P1, P2);
    session
        .world_mut()
        .resource_mut::<JailResource>()
        .consecutive_doubles
        .insert(P1, 2);

    let events = session
        .process_command(P1, Box::new(RollAndMoveCommand { player: P1 }))
        .unwrap();
    assert!(events.iter().any(|e| e.as_any().is::<JailedEvent>()));
    assert_eq!(
        session.world().resource::<PlayersResource>().position[&P1],
        JAIL_SPACE
    );
    assert_eq!(session.current_player(), P2);

    // Intercambio de propiedades y efectivo entre P1 y P2
    {
        let mut players = session.world_mut().resource_mut::<PlayersResource>();
        players.properties.insert(6, P1);
        players.properties.insert(8, P2);
    }

    session
        .process_command(
            P1,
            Box::new(ProposeTradeCommand {
                player: P1,
                target: P2,
                offered_spaces: vec![6],
                requested_spaces: vec![8],
                offered_cash: 100,
                requested_cash: 0,
            }),
        )
        .expect("propuesta de intercambio válida");

    let trade_ev = session
        .process_command(P2, Box::new(AcceptTradeCommand { player: P2 }))
        .expect("aceptación de intercambio válida");
    assert!(trade_ev[0].as_any().is::<TradeAcceptedEvent>());

    let players = session.world().resource::<PlayersResource>();
    assert_eq!(players.properties.get(&6), Some(&P2));
    assert_eq!(players.properties.get(&8), Some(&P1));
}

#[test]
fn canonical_construccion_desigual_rechazada_hipoteca_sin_renta_y_tarjeta_carcel() {
    let mut session = new_monopoly_session(SessionId(518_209), 1, P1, P2);
    {
        let mut players = session.world_mut().resource_mut::<PlayersResource>();
        players.properties.insert(1, P1);
        players.properties.insert(3, P1);
    }

    // Construir 1ª casa en casilla 1 es válido, pero intentar construir 2ª casa en 1 sin construir en 3 se rechaza
    session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .unwrap();
    assert!(session
        .process_command(
            P1,
            Box::new(BuildHouseCommand {
                player: P1,
                space: 1,
            }),
        )
        .is_err());

    // Construir en 3 y otra en 1 (niveles: 1->2, 3->1). Intentar vender en 3 (nivel menor) se rechaza
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
    assert!(session
        .process_command(
            P1,
            Box::new(SellHouseCommand {
                player: P1,
                space: 3,
            }),
        )
        .is_err());

    // Propiedad hipotecada no cobra alquiler al caer el rival
    {
        let mut b = session.world_mut().resource_mut::<BuildingsResource>();
        b.buildings.clear();
        let mut p = session.world_mut().resource_mut::<PlayersResource>();
        p.mortgaged.insert(1);
    }
    let money_before = session.world().resource::<PlayersResource>().money[&P2];
    let space_kind = session.world().resource::<BoardResource>().spaces[1].clone();
    let mut land_evts = Vec::new();
    apply_land_effect(
        &space_kind,
        1,
        P2,
        4,
        false,
        session.world_mut(),
        &mut land_evts,
    );
    assert!(land_evts.is_empty());
    assert_eq!(
        session.world().resource::<PlayersResource>().money[&P2],
        money_before
    );

    // Usar tarjeta Salir de la Cárcel Gratis libera a P1
    {
        let mut jail = session.world_mut().resource_mut::<JailResource>();
        jail.jailed.insert(P1, 3);
        let mut p = session.world_mut().resource_mut::<PlayersResource>();
        p.jail_free_cards.insert(P1, 1);
    }
    let jail_ev = session
        .process_command(P1, Box::new(UseJailCardCommand { player: P1 }))
        .expect("UseJailCardCommand debe liberar al jugador");
    assert!(jail_ev[0].as_any().is::<JailCardUsedEvent>());
    assert!(!session
        .world()
        .resource::<JailResource>()
        .jailed
        .contains_key(&P1));
}

