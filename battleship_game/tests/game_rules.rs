use battleship_game::{
    new_battleship_session, FleetResource, FireShotCommand, GameOverEvent, PlaceFleetCommand, Position, RematchCommand, Ship,
    ShotResult, ShotResultEvent, SunkenShipEvent,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

/// Flota estándar del MVP: barcos de 4, 3 y 2 casillas, separados para no ser adyacentes.
fn standard_fleet(row_offset: u8) -> Vec<Ship> {
    vec![
        vec![pos(row_offset, 0), pos(row_offset, 1), pos(row_offset, 2), pos(row_offset, 3)],
        vec![pos(row_offset + 2, 0), pos(row_offset + 2, 1), pos(row_offset + 2, 2)],
        vec![pos(row_offset + 4, 0), pos(row_offset + 4, 1)],
    ]
}

fn place_fleet(session: &mut Session, player: PlayerId, ships: Vec<Ship>) {
    let cmd: Box<dyn Command> = Box::new(PlaceFleetCommand { player, ships });
    session.process_command(player, cmd).expect("la flota debería ser válida");
}

#[test]
fn colocar_una_flota_valida_funciona_y_no_revela_las_coordenadas() {
    let mut session = new_battleship_session(SessionId(1), 1, P1, P2);
    let events = session
        .process_command(
            P1,
            Box::new(PlaceFleetCommand {
                player: P1,
                ships: standard_fleet(0),
            }),
        )
        .expect("flota válida");

    assert_eq!(events.len(), 1);
    let debug = format!("{:?}", events[0]);
    assert!(debug.contains("FleetPlacedEvent"));
}

#[test]
fn una_flota_con_tamanos_incorrectos_es_rechazada() {
    let mut session = new_battleship_session(SessionId(2), 1, P1, P2);
    let result = session.process_command(
        P1,
        Box::new(PlaceFleetCommand {
            player: P1,
            ships: vec![vec![pos(0, 0), pos(0, 1)]], // solo un barco de 2, falta el resto
        }),
    );
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn no_se_puede_disparar_antes_de_que_ambos_coloquen_su_flota() {
    let mut session = new_battleship_session(SessionId(3), 1, P1, P2);
    place_fleet(&mut session, P1, standard_fleet(0));
    // P2 todavía no colocó su flota.
    let result = session.process_command(
        P1,
        Box::new(FireShotCommand {
            player: P1,
            target: pos(5, 5),
        }),
    );
    assert!(matches!(result, Err(EngineError::InvalidCommand { .. })));
}

#[test]
fn un_disparo_certero_se_reporta_como_hit_y_uno_al_agua_como_miss() {
    let mut session = new_battleship_session(SessionId(4), 1, P1, P2);
    place_fleet(&mut session, P1, standard_fleet(0));
    place_fleet(&mut session, P2, standard_fleet(0));

    // P1 dispara y le pega al barco de 3 casillas de P2 en (2,0).
    let events = session
        .process_command(
            P1,
            Box::new(FireShotCommand {
                player: P1,
                target: pos(2, 0),
            }),
        )
        .expect("el disparo debería ser válido");
    let shot = events[0].as_any().downcast_ref::<ShotResultEvent>().unwrap();
    assert_eq!(shot.result, ShotResult::Hit);

    // P2 dispara a una casilla vacía.
    let events = session
        .process_command(
            P2,
            Box::new(FireShotCommand {
                player: P2,
                target: pos(7, 7),
            }),
        )
        .expect("el disparo debería ser válido");
    let shot = events[0].as_any().downcast_ref::<ShotResultEvent>().unwrap();
    assert_eq!(shot.result, ShotResult::Miss);
}

#[test]
fn hundir_todos_los_barcos_rivales_termina_la_partida() {
    let mut session = new_battleship_session(SessionId(5), 1, P1, P2);
    place_fleet(&mut session, P1, standard_fleet(0));
    place_fleet(&mut session, P2, standard_fleet(0));

    let shots_p1 = [pos(0, 0), pos(0, 1), pos(0, 2), pos(0, 3), pos(2, 0), pos(2, 1), pos(2, 2), pos(4, 0)];
    let filler_targets = [pos(7, 0), pos(7, 1), pos(7, 2), pos(7, 3), pos(7, 4), pos(7, 5), pos(7, 6), pos(7, 7)];
    let mut last_events;
    for (i, target) in shots_p1.into_iter().enumerate() {
        last_events = session
            .process_command(P1, Box::new(FireShotCommand { player: P1, target }))
            .expect("disparo válido");
        if !last_events.iter().any(|e| e.as_any().downcast_ref::<GameOverEvent>().is_some()) {
            session
                .process_command(P2, Box::new(FireShotCommand { player: P2, target: filler_targets[i] }))
                .expect("disparo válido de relleno");
        }
    }

    let final_shot = session
        .process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(4, 1) }))
        .expect("el último disparo debería hundir el último barco");

    assert!(final_shot
        .iter()
        .any(|e| e.as_any().downcast_ref::<GameOverEvent>().map(|go| go.winner) == Some(Some(P1))));
}

#[test]
fn disparar_dos_veces_a_la_misma_casilla_es_rechazado() {
    let mut session = new_battleship_session(SessionId(6), 1, P1, P2);
    place_fleet(&mut session, P1, standard_fleet(0));
    place_fleet(&mut session, P2, standard_fleet(0));

    session
        .process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(5, 5) }))
        .unwrap();

    session
        .process_command(P2, Box::new(FireShotCommand { player: P2, target: pos(5, 5) }))
        .unwrap();

    let res = session.process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(5, 5) }));
    assert!(res.is_err(), "no se puede repetir un disparo a la misma casilla");
}

#[test]
fn barcos_superpuestos_o_diagonales_son_rechazados() {
    let mut session = new_battleship_session(SessionId(7), 1, P1, P2);

    let overlapping = vec![
        vec![pos(0, 0), pos(0, 1), pos(0, 2), pos(0, 3)],
        vec![pos(0, 0), pos(1, 0), pos(2, 0)],
        vec![pos(2, 2), pos(2, 3)],
    ];
    let res = session.process_command(P1, Box::new(PlaceFleetCommand { player: P1, ships: overlapping }));
    assert!(res.is_err(), "barcos superpuestos deben rechazarse");

    let diagonal = vec![
        vec![pos(0, 0), pos(1, 1), pos(2, 2), pos(3, 3)],
        vec![pos(5, 0), pos(5, 1), pos(5, 2)],
        vec![pos(6, 0), pos(6, 1)],
    ];
    let res = session.process_command(P1, Box::new(PlaceFleetCommand { player: P1, ships: diagonal }));
    assert!(res.is_err(), "barcos diagonales deben rechazarse");
}

#[test]
fn test_barco_adyacente_a_otro_es_rechazado() {
    let mut session = new_battleship_session(SessionId(8), 1, P1, P2);

    // Barco 1 en fila 0, Barco 2 en fila 1 (adyacente verticalmente)
    let adjacent_fleet = vec![
        vec![pos(0, 0), pos(0, 1), pos(0, 2), pos(0, 3)],
        vec![pos(1, 0), pos(1, 1), pos(1, 2)],
        vec![pos(3, 0), pos(3, 1)],
    ];
    let res = session.process_command(
        P1,
        Box::new(PlaceFleetCommand {
            player: P1,
            ships: adjacent_fleet,
        }),
    );
    assert!(res.is_err(), "barcos adyacentes deben ser rechazados");

    // Barcos tocándose diagonalmente: pos(0,3) y pos(1,4)
    let diagonal_touching = vec![
        vec![pos(0, 0), pos(0, 1), pos(0, 2), pos(0, 3)],
        vec![pos(1, 4), pos(1, 5), pos(1, 6)],
        vec![pos(3, 0), pos(3, 1)],
    ];
    let res = session.process_command(
        P1,
        Box::new(PlaceFleetCommand {
            player: P1,
            ships: diagonal_touching,
        }),
    );
    assert!(res.is_err(), "barcos tocándose en diagonal deben ser rechazados");
}

#[test]
fn test_disparo_a_celda_ya_disparada_es_rechazado() {
    let mut session = new_battleship_session(SessionId(9), 1, P1, P2);
    place_fleet(&mut session, P1, standard_fleet(0));
    place_fleet(&mut session, P2, standard_fleet(0));

    // P1 dispara a agua (7, 7)
    session
        .process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(7, 7) }))
        .unwrap();

    // P2 dispara a agua (7, 7)
    session
        .process_command(P2, Box::new(FireShotCommand { player: P2, target: pos(7, 7) }))
        .unwrap();

    // P1 intenta disparar otra vez a (7, 7)
    let res = session.process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(7, 7) }));
    assert!(res.is_err(), "disparar dos veces a una celda de agua debe ser rechazado");
}

#[test]
fn test_impactar_todos_los_segmentos_hunde_el_barco_y_emite_evento() {
    let mut session = new_battleship_session(SessionId(10), 1, P1, P2);
    place_fleet(&mut session, P1, standard_fleet(0));
    place_fleet(&mut session, P2, standard_fleet(0));

    // El barco de 3 celdas de P2 está en fila 2: pos(2, 0), pos(2, 1), pos(2, 2)
    // Disparo 1: pos(2, 0)
    let ev1 = session
        .process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(2, 0) }))
        .unwrap();
    assert!(!ev1.iter().any(|e| e.as_any().is::<SunkenShipEvent>()), "el barco no debe estar hundido al primer disparo");

    // P2 responde
    session
        .process_command(P2, Box::new(FireShotCommand { player: P2, target: pos(7, 0) }))
        .unwrap();

    // Disparo 2: pos(2, 1)
    let ev2 = session
        .process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(2, 1) }))
        .unwrap();
    assert!(!ev2.iter().any(|e| e.as_any().is::<SunkenShipEvent>()), "el barco no debe estar hundido al segundo disparo");

    // P2 responde
    session
        .process_command(P2, Box::new(FireShotCommand { player: P2, target: pos(7, 1) }))
        .unwrap();

    // Disparo 3: pos(2, 2) - último segmento
    let ev3 = session
        .process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(2, 2) }))
        .unwrap();
    let sunken = ev3.iter().find_map(|e| e.as_any().downcast_ref::<SunkenShipEvent>());
    assert!(sunken.is_some(), "al tercer disparo debe emitirse SunkenShipEvent");
    let sunken_event = sunken.unwrap();
    assert_eq!(sunken_event.ship_type, 3);
    assert_eq!(sunken_event.positions, vec![pos(2, 0), pos(2, 1), pos(2, 2)]);
}

#[test]
fn test_hundir_toda_la_flota_termina_la_partida() {
    let mut session = new_battleship_session(SessionId(11), 1, P1, P2);
    {
        let mut fleet = session.world_mut().resource_mut::<FleetResource>();
        fleet.ships.insert(P1, vec![vec![pos(0, 0)]]);
        fleet.ships.insert(P2, vec![vec![pos(0, 0)]]);
    }

    let events = session
        .process_command(P1, Box::new(FireShotCommand { player: P1, target: pos(0, 0) }))
        .expect("disparo válido");

    let game_over = events.iter().find_map(|e| e.as_any().downcast_ref::<GameOverEvent>());
    assert!(game_over.is_some(), "al hundir la flota debe emitirse GameOverEvent");
    assert_eq!(game_over.unwrap().winner, Some(P1));
}

#[test]
fn test_revancha_reinicia_la_fase_de_colocacion() {
    let mut session = new_battleship_session(SessionId(12), 1, P1, P2);
    place_fleet(&mut session, P1, standard_fleet(0));
    place_fleet(&mut session, P2, standard_fleet(0));

    {
        let fleet = session.world().resource::<FleetResource>();
        assert!(fleet.has_placed_fleet(P1));
        assert!(fleet.has_placed_fleet(P2));
    }

    // P1 pide revancha
    session
        .process_command(P1, Box::new(RematchCommand { player: P1 }))
        .unwrap();

    // La flota sigue antes de que P2 acepte
    {
        let fleet = session.world().resource::<FleetResource>();
        assert!(fleet.has_placed_fleet(P1));
    }

    // P2 pide revancha
    session
        .process_command(P2, Box::new(RematchCommand { player: P2 }))
        .unwrap();

    // Ahora se reinicia la fase de colocación
    {
        let fleet = session.world().resource::<FleetResource>();
        assert!(!fleet.has_placed_fleet(P1));
        assert!(!fleet.has_placed_fleet(P2));
    }

    // Se pueden volver a colocar las flotas
    place_fleet(&mut session, P1, standard_fleet(0));
    place_fleet(&mut session, P2, standard_fleet(0));

    let fleet = session.world().resource::<FleetResource>();
    assert!(fleet.has_placed_fleet(P1));
    assert!(fleet.has_placed_fleet(P2));
}

#[test]
fn test_barco_fuera_de_los_limites_es_rechazado() {
    let mut session = new_battleship_session(SessionId(10), 1, P1, P2);
    let ships = vec![
        vec![pos(2, 0), pos(2, 1), pos(2, 2), pos(2, 3)],
        vec![pos(0, 6), pos(0, 7), pos(0, 8)],
        vec![pos(4, 0), pos(4, 1)],
    ];
    let result = session.process_command(
        P1,
        Box::new(PlaceFleetCommand {
            player: P1,
            ships,
        }),
    );
    assert!(
        matches!(result, Err(EngineError::InvalidCommand { .. })),
        "colocar un barco fuera de los límites debe ser rechazado"
    );
}


