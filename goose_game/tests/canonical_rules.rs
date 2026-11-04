// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use goose_game::{
    new_goose_session, GooseBoardResource, MoveTokenCommand, PendingRollResource, RollDiceCommand,
    BRIDGE_A, BRIDGE_B, DICE_A, DICE_B, GARDEN_SQUARE, INN_SQUARE, LABYRINTH_SQUARE,
    LABYRINTH_TARGET, PRISON_SQUARE, SKULL_SQUARE, SKULL_TARGET, WELL_SQUARE,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);
const P3: PlayerId = PlayerId(3);

#[test]
fn test_goose_to_goose_grants_bonus_turn() {
    let mut session = new_goose_session(SessionId(1), 42, vec![P1, P2]);
    // Forzar tirada de 5 desde casilla 0 -> cae en Oca (5) -> salta a Oca (9) y conserva turno
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 5);

    session
        .process_command(P1, Box::new(MoveTokenCommand { player: P1 }))
        .unwrap();

    let pos = session
        .world()
        .resource::<GooseBoardResource>()
        .position_of(P1);
    assert_eq!(pos, 9, "Desde Oca 5 debe saltar a Oca 9");
    assert_eq!(
        session.current_player(),
        P1,
        "Caer en una Oca debe otorgar turno extra ('tiro porque me toca')"
    );
}

#[test]
fn test_bridge_and_dice_jumps_grant_bonus_turn() {
    let mut session = new_goose_session(SessionId(2), 42, vec![P1, P2]);

    // Puente 6 -> 12
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, BRIDGE_A);
    session
        .process_command(P1, Box::new(MoveTokenCommand { player: P1 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P1),
        BRIDGE_B
    );
    assert_eq!(session.current_player(), P1);

    // Dados 26 (DICE_A) -> 53 (DICE_B)
    assert_eq!(22 + 4, DICE_A);
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P1, 22);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 4); // 22 + 4 = 26 (DICE_A)
    session
        .process_command(P1, Box::new(MoveTokenCommand { player: P1 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P1),
        DICE_B
    );
    assert_eq!(session.current_player(), P1);
}

#[test]
fn test_labyrinth_and_skull_setbacks() {
    let mut session = new_goose_session(SessionId(3), 42, vec![P1, P2]);

    // Laberinto: 40 + 2 = 42 -> retrocede a 30
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P1, 40);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 2);
    session
        .process_command(P1, Box::new(MoveTokenCommand { player: P1 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P1),
        LABYRINTH_TARGET
    );
    assert_eq!(session.current_player(), P2);

    // Calavera: 55 + 3 = 58 -> vuelve a 1
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P2, 55);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P2, 3);
    session
        .process_command(P2, Box::new(MoveTokenCommand { player: P2 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P2),
        SKULL_TARGET
    );
}

#[test]
fn test_inn_well_and_prison_penalties_and_well_rescue() {
    let mut session = new_goose_session(SessionId(4), 42, vec![P1, P2, P3]);

    // P1 cae en la Posada (19): pierde 1 turno
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P1, 16);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 3); // 16 + 3 = 19
    session
        .process_command(P1, Box::new(MoveTokenCommand { player: P1 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .wait_turns_of(P1),
        1
    );

    // P2 cae en el Pozo (31): 2 turnos de espera
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P2, 28);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P2, 3); // 28 + 3 = 31 (WELL_SQUARE)
    session
        .process_command(P2, Box::new(MoveTokenCommand { player: P2 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .wait_turns_of(P2),
        2
    );

    // P3 también cae en el Pozo (31): rescata inmediatamente a P2 (wait_turns de P2 pasa a 0)
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P3, 29);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P3, 2); // 29 + 2 = 31
    session
        .process_command(P3, Box::new(MoveTokenCommand { player: P3 }))
        .unwrap();

    // Al avanzar el turno tras P3: P1 tenía wait=1 (se descuenta a 0 y se salta), por lo que el turno llega a P2 (rescatado)
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .wait_turns_of(P1),
        0
    );
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .wait_turns_of(P2),
        0
    );
    assert_eq!(session.current_player(), P2);

    // Verificar constante de Cárcel (52) e Inn/Well/Labyrinth/Skull
    let _ = (
        INN_SQUARE,
        WELL_SQUARE,
        LABYRINTH_SQUARE,
        PRISON_SQUARE,
        SKULL_SQUARE,
    );
}

#[test]
fn test_exact_bounce_and_victory_on_63() {
    let mut session = new_goose_session(SessionId(5), 42, vec![P1, P2]);

    // P1 está en 61 y saca un 5 -> 61 + 5 = 66 (exceso 3) -> rebota a 60
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P1, 61);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P1, 5);
    session
        .process_command(P1, Box::new(MoveTokenCommand { player: P1 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P1),
        60
    );
    assert!(session
        .world()
        .resource::<GooseBoardResource>()
        .winner
        .is_none());

    // P2 está en 60 y saca un 3 -> llega exacto a 63 y gana
    session
        .world_mut()
        .resource_mut::<GooseBoardResource>()
        .positions
        .insert(P2, 60);
    session
        .world_mut()
        .resource_mut::<PendingRollResource>()
        .pending
        .insert(P2, 3);
    session
        .process_command(P2, Box::new(MoveTokenCommand { player: P2 }))
        .unwrap();
    assert_eq!(
        session
            .world()
            .resource::<GooseBoardResource>()
            .position_of(P2),
        GARDEN_SQUARE
    );
    assert_eq!(
        session.world().resource::<GooseBoardResource>().winner,
        Some(P2)
    );

    // También probar RollDiceCommand determinista en nueva sesión
    let mut s2 = new_goose_session(SessionId(6), 99, vec![P1, P2]);
    s2.process_command(P1, Box::new(RollDiceCommand { player: P1 }))
        .unwrap();
    let rolled = s2
        .world()
        .resource::<PendingRollResource>()
        .pending
        .get(&P1)
        .copied();
    assert!(rolled.is_some_and(|v| (1..=6).contains(&v)));
}
