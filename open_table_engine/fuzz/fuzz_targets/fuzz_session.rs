#![no_main]

use libfuzzer_sys::fuzz_target;
use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct RollDiceCommand {
    player: PlayerId,
}

#[typetag::serde]
impl Command for RollDiceCommand {
    fn clone_box(&self) -> Box<dyn Command> {
        Box::new(self.clone())
    }

    fn issuer(&self) -> Option<PlayerId> {
        Some(self.player)
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct DiceRolledEvent {
    player: PlayerId,
    value: u32,
}

#[typetag::serde]
impl Event for DiceRolledEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

fn build_dice_game_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.register::<RollDiceCommand, _>(|cmd, world| {
        let mut rng = world.resource_mut::<RandomResource>();
        let value = rng.0.roll_die(6);
        let events: Vec<Box<dyn Event>> = vec![Box::new(DiceRolledEvent {
            player: cmd.player,
            value,
        })];
        world.resource_mut::<TurnResource>().0.advance();
        Ok(events)
    });
    rules
}

fuzz_target!(|data: &[u8]| {
    if let Ok(envelope) = serde_json::from_slice::<CommandEnvelope>(data) {
        let alice = PlayerId(1);
        let bob = PlayerId(2);
        let mut session = Session::new(
            SessionId(1),
            42,
            vec![alice, bob],
            build_dice_game_rules(),
        );

        let sender = envelope.payload.issuer().unwrap_or(alice);
        let _ = session.process_command(sender, envelope.payload);
    }
});
