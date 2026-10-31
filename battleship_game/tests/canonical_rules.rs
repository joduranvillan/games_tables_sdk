use battleship_game::{
    new_battleship_session, BattleshipConfigResource, FireShotCommand, FleetResource,
    GameOverEvent, PlaceFleetCommand, Position, RematchCommand, SetBattleshipRulesCommand, Ship,
    ShotResult, ShotResultEvent, SunkenShipEvent,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

fn standard_fleet(row_offset: u8) -> Vec<Ship> {
    vec![
        vec![
            pos(row_offset, 0),
            pos(row_offset, 1),
            pos(row_offset, 2),
            pos(row_offset, 3),
            pos(row_offset, 4),
        ],
        vec![
            pos(row_offset + 2, 0),
            pos(row_offset + 2, 1),
            pos(row_offset + 2, 2),
            pos(row_offset + 2, 3),
        ],
        vec![
            pos(row_offset + 4, 0),
            pos(row_offset + 4, 1),
            pos(row_offset + 4, 2),
        ],
        vec![
            pos(row_offset + 6, 0),
            pos(row_offset + 6, 1),
            pos(row_offset + 6, 2),
        ],
        vec![pos(row_offset + 8, 0), pos(row_offset + 8, 1)],
    ]
}

#[test]
fn canonical_modo_extra_turn_on_hit_mantiene_turno_al_acertar_y_cede_al_fallar() {
    let mut session = new_battleship_session(SessionId(518_11), 1, P1, P2);

    session
        .process_command(
            P1,
            Box::new(PlaceFleetCommand {
                player: P1,
                ships: standard_fleet(0),
            }),
        )
        .unwrap();
    session
        .process_command(
            P2,
            Box::new(PlaceFleetCommand {
                player: P2,
                ships: standard_fleet(0),
            }),
        )
        .unwrap();

    session
        .process_command(
            P1,
            Box::new(SetBattleshipRulesCommand {
                extra_turn_on_hit: true,
            }),
        )
        .expect("SetBattleshipRulesCommand debe activar extra_turn_on_hit");

    assert!(
        session
            .world()
            .resource::<BattleshipConfigResource>()
            .extra_turn_on_hit
    );

    // P1 acierta en (0, 0) -> conserva el turno
    let ev1 = session
        .process_command(
            P1,
            Box::new(FireShotCommand {
                player: P1,
                target: pos(0, 0),
            }),
        )
        .unwrap();
    assert_eq!(
        ev1[0]
            .as_any()
            .downcast_ref::<ShotResultEvent>()
            .unwrap()
            .result,
        ShotResult::Hit
    );
    assert_eq!(session.current_player(), P1);

    // P1 falla en (1, 0) -> el turno pasa a P2
    let ev2 = session
        .process_command(
            P1,
            Box::new(FireShotCommand {
                player: P1,
                target: pos(1, 0),
            }),
        )
        .unwrap();
    assert_eq!(
        ev2[0]
            .as_any()
            .downcast_ref::<ShotResultEvent>()
            .unwrap()
            .result,
        ShotResult::Miss
    );
    assert_eq!(session.current_player(), P2);
}

#[test]
fn canonical_hundir_flota_con_racha_y_rematch_reinicia_estado() {
    let mut session = new_battleship_session(SessionId(518_206), 1, P1, P2);
    let fleet = standard_fleet(0);

    session
        .process_command(
            P1,
            Box::new(PlaceFleetCommand {
                player: P1,
                ships: fleet.clone(),
            }),
        )
        .unwrap();
    session
        .process_command(
            P2,
            Box::new(PlaceFleetCommand {
                player: P2,
                ships: fleet.clone(),
            }),
        )
        .unwrap();
    session
        .process_command(
            P1,
            Box::new(SetBattleshipRulesCommand {
                extra_turn_on_hit: true,
            }),
        )
        .unwrap();

    // Con extra_turn_on_hit activo, P1 dispara en racha a las 17 casillas de los 5 barcos de P2
    let all_cells: Vec<Position> = fleet.into_iter().flatten().collect();
    for (idx, cell) in all_cells.iter().enumerate() {
        let evs = session
            .process_command(
                P1,
                Box::new(FireShotCommand {
                    player: P1,
                    target: *cell,
                }),
            )
            .expect("disparo consecutivo con racha debe ser válido");

        if idx == all_cells.len() - 1 {
            assert!(evs.iter().any(|e| e.as_any().is::<SunkenShipEvent>()));
            let go = evs
                .iter()
                .find_map(|e| e.as_any().downcast_ref::<GameOverEvent>())
                .expect("hundir el último barco emite GameOverEvent");
            assert_eq!(go.winner, Some(P1));
        }
    }

    assert!(session.world().resource::<GameOverResource>().0);

    // Ambos solicitan revancha -> se reinician flotas, disparos y GameOverResource
    session
        .process_command(P1, Box::new(RematchCommand { player: P1 }))
        .unwrap();
    session
        .process_command(P2, Box::new(RematchCommand { player: P2 }))
        .unwrap();

    assert!(!session.world().resource::<GameOverResource>().0);
    assert!(session
        .world()
        .resource::<FleetResource>()
        .ships
        .is_empty());
}

