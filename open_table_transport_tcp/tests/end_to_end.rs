//! Este es el test que faltaba: dos `Session` REALES (con `bevy_ecs`
//! adentro) hablando por sockets TCP de verdad, no simulado en memoria.
//! Prueba el ciclo completo:
//!
//! Cliente arma `Command` -> serializa -> TCP -> Host deserializa ->
//! `Session::process_command` (con el `sender` verificado por la propia
//! conexión, no por el payload) -> `RuleEngine` produce `Event` -> Host
//! serializa -> TCP -> Cliente deserializa -> downcast tipado.

use std::thread;
use std::time::{Duration, Instant};

use open_table_engine::prelude::*;
use open_table_transport_tcp::{TcpClientTransport, TcpHostTransport, HOST_PLAYER_ID};
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

/// Los threads de lectura son asincrónicos respecto al test, así que
/// hacemos polling con timeout en vez de asumir que los datos ya están
/// ahí en la primera llamada.
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
fn ciclo_completo_command_red_ruleengine_events_red_por_tcp_real() {
    // --- Setup de red real ---
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();
    let (mut client_transport, alice, _token) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("conexión del cliente");
    let mut host_session = Session::new(SessionId(1), 42, vec![alice], dice_rules());

    // --- Cliente arma el comando y lo manda por la red real ---
    let command: Box<dyn Command> = Box::new(RollDiceCommand { player: alice });
    let outgoing_envelope = CommandEnvelope {
        tick: Tick(0),
        payload: command,
    };
    let outgoing_bytes = serde_json::to_vec(&outgoing_envelope).expect("serializa el comando");
    client_transport
        .send(HOST_PLAYER_ID, &outgoing_bytes)
        .expect("manda el comando por TCP");

    // --- Host recibe por la red real (sender viene de la conexión, no del payload) ---
    let received = wait_for_data(|| host_transport.poll_received(), Duration::from_secs(2));
    assert_eq!(received.len(), 1, "el host debería haber recibido exactamente un mensaje");
    let (sender, raw_command) = &received[0];
    assert_eq!(*sender, alice, "el sender viene de qué conexión TCP trajo los bytes");

    let decoded_envelope: CommandEnvelope =
        serde_json::from_slice(raw_command).expect("deserializa el comando recibido");

    // --- Host procesa el comando en su Session real (bevy_ecs adentro) ---
    let events = host_session
        .process_command(*sender, decoded_envelope.payload)
        .expect("procesa el comando");
    assert_eq!(events.len(), 1);

    // --- Host manda los eventos resultantes de vuelta por la red real ---
    for event in events {
        let envelope = EventEnvelope {
            tick: host_session.current_tick(),
            payload: event,
        };
        let bytes = serde_json::to_vec(&envelope).expect("serializa el evento");
        host_transport.broadcast(&bytes).expect("manda el evento por TCP");
    }

    // --- Cliente recibe el evento por la red real y lo downcastea tipado ---
    let client_received = wait_for_data(|| client_transport.poll_received(), Duration::from_secs(2));
    assert_eq!(client_received.len(), 1, "el cliente debería haber recibido exactamente un evento");

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
fn el_host_rechaza_un_comando_con_issuer_falsificado_aunque_llegue_por_red_real() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();
    let (mut client_transport, alice, _token) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("conexión del cliente");
    // `alice` es la identidad real que el host asignó al hacer Join.
    let mut host_session = Session::new(SessionId(2), 1, vec![alice], dice_rules());

    // El cliente (que la red identifica como PlayerId(1) = alice) manda
    // un comando que dice ser de OTRO jugador.
    let impostor_claim = PlayerId(77);
    let forged: Box<dyn Command> = Box::new(RollDiceCommand { player: impostor_claim });
    let envelope = CommandEnvelope {
        tick: Tick(0),
        payload: forged,
    };
    let bytes = serde_json::to_vec(&envelope).unwrap();
    client_transport.send(HOST_PLAYER_ID, &bytes).unwrap();

    let received = wait_for_data(|| host_transport.poll_received(), Duration::from_secs(2));
    assert_eq!(received.len(), 1);
    let (sender, raw) = &received[0];
    assert_eq!(*sender, alice); // la red dice que es alice, sin importar qué diga el payload

    let decoded: CommandEnvelope = serde_json::from_slice(raw).unwrap();
    let result = host_session.process_command(*sender, decoded.payload);

    assert!(matches!(result, Err(EngineError::Unauthorized(id)) if id == alice));
}

#[test]
fn health_check_devuelve_ok_despues_de_conectar() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();
    let (mut client_transport, _alice, _token) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("conexión del cliente");

    let host_ping = host_transport.health_check();
    assert!(host_ping.is_ok(), "health_check del host debe devolver Ok");
    assert_eq!(host_ping.unwrap(), Duration::ZERO);

    let client_ping = client_transport.health_check();
    assert!(client_ping.is_ok(), "health_check del cliente debe devolver Ok");
    assert_eq!(client_ping.unwrap(), Duration::ZERO);
}

#[test]
fn negociacion_de_version_de_protocolo_exitosa() {
    let host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();

    let result = TcpClientTransport::connect_as_new_player(addr, "Alice");
    assert!(result.is_ok(), "el cliente negocia correctamente la versión de protocolo 1.0");
}

#[test]
fn multi_session_server_eventos_no_cruzan_sesiones() {
    use open_table_transport_tcp::MultiSessionServer;

    let server = MultiSessionServer::bind("127.0.0.1:0").expect("bind de multi session server");
    let addr = server.local_addr();

    let s1_id = SessionId(10);
    let s2_id = SessionId(20);

    let mut session1_transport = server.create_session(s1_id);
    let mut _session2_transport = server.create_session(s2_id);

    let (mut client1, _p1, _) =
        TcpClientTransport::connect_to_session(addr, s1_id, "Player1").expect("conecta a sesión 1");
    let (mut client2, _p2, _) =
        TcpClientTransport::connect_to_session(addr, s2_id, "Player2").expect("conecta a sesión 2");

    thread::sleep(Duration::from_millis(50));

    let msg1 = b"evento_session_1";
    session1_transport.broadcast(msg1).expect("broadcast en sesion 1");

    let recv1 = wait_for_data(|| client1.poll_received(), Duration::from_secs(1));
    assert_eq!(recv1.len(), 1);
    assert_eq!(recv1[0].1, msg1);

    let recv2 = client2.poll_received();
    assert!(recv2.is_empty(), "los eventos de la sesión 1 no deben llegar a la sesión 2");
}
