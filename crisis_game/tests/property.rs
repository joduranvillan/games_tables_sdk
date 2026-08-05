use crisis_game::{
    new_crisis_session, DeclareAttackCommand, RollAttackCommand, TerritoryId, TurnPhase,
    TurnStateResource,
};
use open_table_engine::prelude::*;
use proptest::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

proptest! {
    #[test]
    fn ataque_con_dados_aleatorios_no_paniquea(
        from_territory in 0..30u8,
        to_territory in 0..30u8,
        dice in 0..10u8,
    ) {
        let mut session = new_crisis_session(SessionId(1), 42, &[P1, P2]).unwrap();

        {
            let mut turn_state = session.world_mut().resource_mut::<TurnStateResource>();
            turn_state.phase = TurnPhase::Attack;
        }

        let current_player = session.current_player();

        let declare_cmd = Box::new(DeclareAttackCommand {
            player: current_player,
            from: TerritoryId(from_territory),
            to: TerritoryId(to_territory),
            dice,
        });

        let declare_res = session.process_command(current_player, declare_cmd);

        match declare_res {
            Ok(_) => {
                let roll_cmd = Box::new(RollAttackCommand {
                    player: current_player,
                });
                let roll_res = session.process_command(current_player, roll_cmd);
                match roll_res {
                    Ok(_) => {},
                    Err(EngineError::InvalidCommand { .. }) => {},
                    Err(other) => panic!("Esperado Ok o Err(InvalidCommand) en RollAttack, pero se obtuvo: {:?}", other),
                }
            },
            Err(EngineError::InvalidCommand { .. }) => {},
            Err(other) => panic!("Esperado Ok o Err(InvalidCommand) en DeclareAttack, pero se obtuvo: {:?}", other),
        }
    }
}
