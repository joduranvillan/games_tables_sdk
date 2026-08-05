use std::thread;
use std::time::{Duration, Instant};

use open_table_engine::prelude::*;
use open_table_transport_websocket::{WsClientTransport, WsHostTransport, HOST_PLAYER_ID};
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

fn dice_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.register::<RollDiceCommand, _>(|cmd, world| {
        let mut rng = world.resource_mut::<RandomResource>();
        let value = rng.0.roll_die(6);
        Ok(vec![Box::new(DiceRolledEvent {
            player: cmd.player,
            value,
        })])
    });
    rules
}

fn wait_for_data<T>(mut poll: impl FnMut() -> Vec<T>, timeout: Duration) -> Vec<T> {
    let start = Instant::now();
    loop {
        let items = poll();
        if !items.is_empty() || start.elapsed() > timeout {
            return items;
        }
        thread::sleep(Duration::from_millis(10));
    }
}

#[test]
fn ciclo_completo_command_red_ruleengine_events_red_por_websocket() {
    let mut host_transport = WsHostTransport::bind("127.0.0.1:0").expect("bind del host websocket");
    let addr = host_transport.local_addr();

    let (mut client_transport, alice, _token) =
        WsClientTransport::connect_as_new_player(addr, "Alice").expect("conexión cliente websocket");

    let mut host_session = Session::new(SessionId(1), 42, vec![alice], dice_rules());

    // Client sends command using send_command
    let command: Box<dyn Command> = Box::new(RollDiceCommand { player: alice });
    let outgoing_envelope = CommandEnvelope {
        tick: Tick(0),
        payload: command,
    };
    let outgoing_bytes = serde_json::to_vec(&outgoing_envelope).expect("serializa el comando");

    client_transport
        .send_command(HOST_PLAYER_ID, &outgoing_bytes)
        .expect("manda el comando por websocket");

    // Host receives command using poll_events
    let received = wait_for_data(|| host_transport.poll_events(), Duration::from_secs(2));
    assert_eq!(received.len(), 1, "el host debería haber recibido exactamente un mensaje");

    let (sender, raw_command) = &received[0];
    assert_eq!(*sender, alice, "el sender proviene de la conexión websocket");

    let decoded_envelope: CommandEnvelope =
        serde_json::from_slice(raw_command).expect("deserializa el comando recibido");

    let events = host_session
        .process_command(*sender, decoded_envelope.payload)
        .expect("procesa el comando");
    assert_eq!(events.len(), 1);

    for event in events {
        let envelope = EventEnvelope {
            tick: host_session.current_tick(),
            payload: event,
        };
        let bytes = serde_json::to_vec(&envelope).expect("serializa el evento");
        host_transport.broadcast(&bytes).expect("manda el evento por websocket");
    }

    // Client receives events using poll_events
    let client_received = wait_for_data(|| client_transport.poll_events(), Duration::from_secs(2));
    assert_eq!(client_received.len(), 1, "el cliente debería recibir exactamente un evento");

    let (_, raw_event) = &client_received[0];
    let decoded_event_envelope: EventEnvelope =
        serde_json::from_slice(raw_event).expect("deserializa el evento recibido");

    let dice_event = decoded_event_envelope
        .payload
        .as_any()
        .downcast_ref::<DiceRolledEvent>()
        .expect("el evento debe ser un DiceRolledEvent");

    assert_eq!(dice_event.player, alice);
    assert!((1..=6).contains(&dice_event.value));
}

#[test]
fn health_check_websocket() {
    let mut host_transport = WsHostTransport::bind("127.0.0.1:0").expect("bind host");
    let addr = host_transport.local_addr();

    let (mut client_transport, _alice, _token) =
        WsClientTransport::connect_as_new_player(addr, "Alice").expect("connect client");

    assert!(host_transport.health_check().is_ok());
    assert!(client_transport.health_check().is_ok());
}
