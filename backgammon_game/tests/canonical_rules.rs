use backgammon_game::{
    new_backgammon_session, BoardResource, MoveCheckerCommand, PendingDiceResource, Sides, POINTS,
};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn force_roll(session: &mut Session, player: PlayerId, values: Vec<u32>) {
    session
        .world_mut()
        .resource_mut::<PendingDiceResource>()
        .pending
        .insert(player, values);
}

#[test]
fn canonical_obligacion_de_usar_dado_mayor_cuando_solo_uno_es_jugable() {
    let mut session = new_backgammon_session(SessionId(518_9), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.points = [0; POINTS];
        board.points[0] = 1;
        board.points[5] = -2; // bloquea 0 + 2 + 3 = 5
    }
    force_roll(&mut session, P1, vec![2, 3]);

    let sides = *session.world().resource::<Sides>();
    let board = session.world().resource::<BoardResource>();
    assert!(!sides.can_play_both_dice(board, P1, 2, 3));

    // Intentar usar el dado menor (2) debe ser rechazado
    let err = session.process_command(
        P1,
        Box::new(MoveCheckerCommand {
            player: P1,
            from: Some(0),
            die: 2,
        }),
    );
    assert!(err.is_err());

    // Usar el dado mayor (3) es obligatorio y válido
    session
        .process_command(
            P1,
            Box::new(MoveCheckerCommand {
                player: P1,
                from: Some(0),
                die: 3,
            }),
        )
        .expect("jugar el dado mayor (3) debe ser válido");
    assert_eq!(session.current_player(), P2);
}

#[test]
fn canonical_obligacion_de_usar_ambos_dados_si_existe_secuencia_completa() {
    let mut session = new_backgammon_session(SessionId(518_10), 1, P1, P2);
    {
        let mut board = session.world_mut().resource_mut::<BoardResource>();
        board.points = [0; POINTS];
        board.points[0] = 1;
        board.points[10] = 1;
        board.points[3] = -2;
        board.points[13] = -2;
        board.points[15] = -2;
    }
    force_roll(&mut session, P1, vec![2, 3]);

    // Mover desde 10 con dado 2 bloquearía el dado 3 -> rechazado
    let err = session.process_command(
        P1,
        Box::new(MoveCheckerCommand {
            player: P1,
            from: Some(10),
            die: 2,
        }),
    );
    assert!(err.is_err());

    // Mover desde 0 con dado 2 (0 -> 2) permite jugar luego el 3 (2 -> 5)
    session
        .process_command(
            P1,
            Box::new(MoveCheckerCommand {
                player: P1,
                from: Some(0),
                die: 2,
            }),
        )
        .expect("0 -> 2 permite usar ambos dados");
    session
        .process_command(
            P1,
            Box::new(MoveCheckerCommand {
                player: P1,
                from: Some(2),
                die: 3,
            }),
        )
        .expect("2 -> 5 completa la tirada");
    assert_eq!(session.current_player(), P2);
}
