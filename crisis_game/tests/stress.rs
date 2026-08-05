use crisis_game::{
    new_crisis_session, DeclareAttackCommand, EndPhaseCommand, FortifyCommand,
    PlaceArmiesCommand, RollAttackCommand, TerritoryId,
};
use open_table_core::ids::{PlayerId, SessionId};
use open_table_engine::prelude::Command;

struct SimpleRng {
    state: u64,
}

impl SimpleRng {
    fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 0xdeadbeef } else { seed },
        }
    }

    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }

    fn next_bounded(&mut self, bound: u64) -> u64 {
        if bound == 0 {
            return 0;
        }
        self.next_u64() % bound
    }
}

#[test]
#[ignore]
fn test_estres_motor_teg() {
    let start = std::time::Instant::now();
    let num_sessions = 1000;
    let cmds_per_session = 50;

    for i in 0..num_sessions {
        let seed = (i + 1) as u64;
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let p3 = PlayerId(3);
        let players = vec![p1, p2, p3];

        let mut session = new_crisis_session(SessionId((i + 1) as u64), seed, &players)
            .expect("error al crear sesión de crisis/teg");

        let mut rng = SimpleRng::new(seed * 99991);

        for _ in 0..cmds_per_session {
            let current_player = session.current_player();
            let choice = rng.next_bounded(5);
            let cmd: Box<dyn Command> = match choice {
                0 => Box::new(PlaceArmiesCommand {
                    player: current_player,
                    territory: TerritoryId(rng.next_bounded(50) as u8),
                    count: (rng.next_bounded(5) as u32) + 1,
                }),
                1 => Box::new(DeclareAttackCommand {
                    player: current_player,
                    from: TerritoryId(rng.next_bounded(50) as u8),
                    to: TerritoryId(rng.next_bounded(50) as u8),
                    dice: (rng.next_bounded(3) as u8) + 1,
                }),
                2 => Box::new(RollAttackCommand {
                    player: current_player,
                }),
                3 => Box::new(FortifyCommand {
                    player: current_player,
                    from: TerritoryId(rng.next_bounded(50) as u8),
                    to: TerritoryId(rng.next_bounded(50) as u8),
                    armies: (rng.next_bounded(5) as u32) + 1,
                }),
                _ => Box::new(EndPhaseCommand {
                    player: current_player,
                }),
            };

            let _ = session.process_command(current_player, cmd);
        }
    }

    let elapsed = start.elapsed();
    println!(
        "Test de estrés TEG completado: {} sesiones, {} comandos procesados en {:?}",
        num_sessions,
        num_sessions * cmds_per_session,
        elapsed
    );
}
