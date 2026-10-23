use battleship_game::{
    new_battleship_session, BattleshipConfigResource, FireShotCommand, PlaceFleetCommand, Position,
    SetBattleshipRulesCommand, Ship, ShotResult, ShotResultEvent,
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
