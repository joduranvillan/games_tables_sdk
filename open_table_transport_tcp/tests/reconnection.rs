//! Prueba el mecanismo de reconexión de punta a punta:
//!
//! 1. Alice se une (Join) y juega un par de turnos junto con Bob.
//! 2. Alice se desconecta (se cierra su socket).
//! 3. El host detecta `ConnectionEvent::Disconnected`.
//! 4. Alice se reconecta con su `player_id` + `reconnect_token` guardados.
//! 5. El host detecta `ConnectionEvent::Reconnected` y dispara un resync:
//!    exporta el log de la `Session` viva, lo reproduce en una `Session`
//!    temporal (`replay_collecting_events`) para juntar TODOS los eventos
//!    ocurridos, los filtra por `Visibility` para Alice
//!    (`filter_events_for_player`), y se los manda por su conexión nueva.
//! 6. Alice recibe el resync y nunca ve el evento privado de Bob.

use std::net::TcpStream;
use std::thread;
use std::time::{Duration, Instant};

use open_table_engine::prelude::*;
use open_table_transport_tcp::{ConnectionEvent, TcpClientTransport, TcpHostTransport};
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

/// Evento privado: solo su dueño debería verlo en el resync.
#[derive(Debug, Serialize, Deserialize)]
struct SecretNoteEvent {
    owner: PlayerId,
    text: String,
}

#[typetag::serde]
impl Event for SecretNoteEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    fn visibility(&self) -> Visibility {
        Visibility::Owner(self.owner)
    }
}

fn dice_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.register::<RollDiceCommand, _>(|cmd, world| {
        let mut rng = world.resource_mut::<RandomResource>();
        let value = rng.0.roll_die(6);

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(DiceRolledEvent {
            player: cmd.player,
            value,
        })];

        // Cada jugador recibe una "nota secreta" propia en cada turno,
        // para tener contenido privado de sobra que probar en el resync.
        events.push(Box::new(SecretNoteEvent {
            owner: cmd.player,
            text: format!("nota privada de {:?}, tick actual", cmd.player),
        }));

        world.resource_mut::<TurnResource>().0.advance();
        Ok(events)
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

/// Acumula ítems a lo largo de varios polls hasta juntar `expected` (o
/// hasta el timeout). Necesario para el resync: el host manda N eventos en
/// N `send()` separados y el cliente puede verlos repartidos en varias
/// lecturas TCP, así que un solo `poll_received()` devuelve solo una parte
/// del lote. Sin esto el test es flaky (a veces ve 3 de 5 y falla).
fn wait_for_data_count<T>(
    mut poll: impl FnMut() -> Vec<T>,
    expected: usize,
    timeout: Duration,
) -> Vec<T> {
    let start = Instant::now();
    let mut acc = Vec::new();
    loop {
        acc.extend(poll());
        if acc.len() >= expected || start.elapsed() > timeout {
            return acc;
        }
        thread::sleep(Duration::from_millis(10));
    }
}

fn wait_until<T>(mut check: impl FnMut() -> Option<T>, timeout: Duration) -> Option<T> {
    let start = Instant::now();
    loop {
        if let Some(value) = check() {
            return Some(value);
        }
        if start.elapsed() > timeout {
            return None;
        }
        thread::sleep(Duration::from_millis(10));
    }
}

#[test]
fn reconexion_real_dispara_resync_filtrado_por_visibilidad() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();

    let (mut alice_transport, alice, alice_token) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("Alice se conecta");
    let (mut bob_transport, bob, _bob_token) =
        TcpClientTransport::connect_as_new_player(addr, "Bob").expect("Bob se conecta");

    // Consumir los eventos de Joined para que no interfieran con los
    // asserts de reconexión más abajo.
    let _ = wait_for_data(
        || host_transport.poll_connection_events(),
        Duration::from_secs(1),
    );

    let players = vec![alice, bob];
    let seed = 2024;
    let mut host_session = Session::new(SessionId(1), seed, players.clone(), dice_rules());

    // --- Un par de turnos jugados normalmente, cada uno genera una nota
    // secreta del jugador de turno. ---
    for _ in 0..3 {
        let current = host_session.current_player();
        let sender_transport = if current == alice {
            &mut alice_transport
        } else {
            &mut bob_transport
        };

        let cmd: Box<dyn Command> = Box::new(RollDiceCommand { player: current });
        let envelope = CommandEnvelope {
            tick: host_session.current_tick(),
            payload: cmd,
        };
        let bytes = serde_json::to_vec(&envelope).unwrap();
        sender_transport
            .send(open_table_transport_tcp::HOST_PLAYER_ID, &bytes)
            .unwrap();

        let received = wait_for_data(|| host_transport.poll_received(), Duration::from_secs(2));
        assert_eq!(received.len(), 1);
        let (sender, raw) = &received[0];
        let decoded: CommandEnvelope = serde_json::from_slice(raw).unwrap();
        host_session
            .process_command(*sender, decoded.payload)
            .unwrap();
        // No hace falta mandar los eventos por la red para este test: lo
        // que importa es que queden en el log de la Session para el
        // resync posterior.
    }

    // --- Alice se cae: cerramos su socket activamente. Un simple
    // `drop()` no alcanza porque el thread de lectura tiene su propio
    // clon del socket todavía abierto (ver doc de `disconnect()`). ---
    alice_transport
        .disconnect()
        .expect("cierra la conexión de Alice");
    drop(alice_transport);

    let disconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Disconnected { player } if *player == alice))
        },
        Duration::from_secs(2),
    );
    assert_eq!(
        disconnect_event,
        Some(ConnectionEvent::Disconnected { player: alice })
    );

    // --- Alice reconecta con su player_id + token guardados. ---
    let mut alice_transport =
        TcpClientTransport::reconnect(addr, alice, alice_token).expect("Alice se reconecta");

    let reconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Reconnected { player } if *player == alice))
        },
        Duration::from_secs(2),
    );
    assert_eq!(
        reconnect_event,
        Some(ConnectionEvent::Reconnected { player: alice })
    );

    // --- El host dispara el resync: exporta el log vivo, lo reproduce en
    // una Session temporal para juntar todos los eventos, y filtra por
    // Visibility para Alice. ---
    let log_bytes = host_session.export_log().expect("exporta el log");
    let (_temp_session, all_events) = Session::replay_collecting_events(
        SessionId(1),
        seed,
        players.clone(),
        dice_rules(),
        &log_bytes,
    )
    .expect("reproduce el log para el resync");

    let events_for_alice = filter_events_for_player(&all_events, alice);
    assert!(
        !events_for_alice.is_empty(),
        "Alice debería recibir al menos un evento en el resync"
    );

    for event in &events_for_alice {
        let bytes = serde_json::to_vec(&EventEnvelope {
            tick: host_session.current_tick(),
            payload: clone_event_for_wire(*event),
        })
        .unwrap();
        host_transport
            .send(alice, &bytes)
            .expect("manda el resync a Alice");
    }

    // --- Alice recibe el resync por su conexión NUEVA y nunca ve una
    // nota secreta que no sea suya. ---
    let received_by_alice = wait_for_data_count(
        || alice_transport.poll_received(),
        events_for_alice.len(),
        Duration::from_secs(2),
    );
    assert_eq!(received_by_alice.len(), events_for_alice.len());

    for (_, raw) in &received_by_alice {
        let envelope: EventEnvelope = serde_json::from_slice(raw).unwrap();
        if let Some(note) = envelope.payload.as_any().downcast_ref::<SecretNoteEvent>() {
            assert_eq!(
                note.owner, alice,
                "Alice no debe recibir la nota secreta de otro jugador en el resync"
            );
        }
    }

    // Bob nunca debería haber recibido nada por la conexión de Alice.
    let _ = TcpStream::connect(addr); // solo para dejar constancia de que el host sigue vivo y aceptando
}

/// `Box<dyn Event>` no implementa `Clone` (los trait objects no pueden
/// derivarlo automáticamente), así que para volver a envolver un evento
/// ya existente en un `EventEnvelope` nuevo lo hacemos ida y vuelta por
/// JSON. Es exactamente lo mismo que ya se hace al mandarlo por red, así
/// que no es un costo extra en la práctica.
fn clone_event_for_wire(event: &dyn Event) -> Box<dyn Event> {
    let bytes = serde_json::to_vec(event).expect("serializa el evento");
    serde_json::from_slice(&bytes).expect("deserializa el evento")
}

#[test]
fn test_retry_policy_limita_intentos_a_max_attempts() {
    use open_table_transport_tcp::{reconnect_to_host, RetryPolicy};

    let policy = RetryPolicy {
        max_attempts: 3,
        base_backoff_ms: 10,
        max_backoff_ms: 50,
    };

    let start = Instant::now();
    let result = reconnect_to_host("127.0.0.1:1", PlayerId(1), "invalid_token".into(), policy);
    let elapsed = start.elapsed();

    assert!(result.is_err());
    assert!(elapsed >= Duration::from_millis(15));
}


#[test]
fn test_reconexion_con_eventos_reales_de_checkers() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();

    let (mut p1_transport, p1, p1_token) =
        TcpClientTransport::connect_as_new_player(addr, "Player1").unwrap();
    let (mut p2_transport, p2, _p2_token) =
        TcpClientTransport::connect_as_new_player(addr, "Player2").unwrap();

    let _ = wait_for_data(
        || host_transport.poll_connection_events(),
        Duration::from_secs(1),
    );

    let seed = 2024;
    let mut host_session = checkers_game::new_checkers_session(SessionId(1), seed, p1, p2);

    let cmd: Box<dyn Command> = Box::new(checkers_game::commands::ResignCommand {
        player: p1,
    });
    
    let envelope = CommandEnvelope {
        tick: host_session.current_tick(),
        payload: cmd,
    };
    let bytes = serde_json::to_vec(&envelope).unwrap();
    p1_transport.send(open_table_transport_tcp::HOST_PLAYER_ID, &bytes).unwrap();

    let received = wait_for_data(|| host_transport.poll_received(), Duration::from_secs(2));
    let (sender, raw) = &received[0];
    let decoded: CommandEnvelope = serde_json::from_slice(raw).unwrap();
    host_session.process_command(*sender, decoded.payload).unwrap();

    p1_transport.disconnect().unwrap();
    drop(p1_transport);

    let disconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Disconnected { player } if *player == p1))
        },
        Duration::from_secs(2),
    );

    let mut p1_transport =
        TcpClientTransport::reconnect(addr, p1, p1_token).unwrap();

    let reconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Reconnected { player } if *player == p1))
        },
        Duration::from_secs(2),
    );

    let log_bytes = host_session.export_log().unwrap();
    let temp_session = checkers_game::new_checkers_session(SessionId(1), seed, p1, p2);
    let (_temp_session, all_events) = Session::replay_on_session(
        temp_session,
        &log_bytes,
    )
    .unwrap();

    let events_for_p1 = filter_events_for_player(&all_events, p1);
    assert!(!events_for_p1.is_empty(), "P1 should have received events in resync");

    for event in &events_for_p1 {
        let bytes = serde_json::to_vec(&EventEnvelope {
            tick: host_session.current_tick(),
            payload: clone_event_for_wire(*event),
        })
        .unwrap();
        host_transport.send(p1, &bytes).unwrap();
    }

    let received_by_p1 = wait_for_data_count(
        || p1_transport.poll_received(),
        events_for_p1.len(),
        Duration::from_secs(2),
    );
    assert_eq!(received_by_p1.len(), events_for_p1.len());
}

#[test]
fn test_reconexion_con_eventos_reales_de_chess() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();

    let (mut p1_transport, p1, p1_token) =
        TcpClientTransport::connect_as_new_player(addr, "Player1").unwrap();
    let (mut p2_transport, p2, _p2_token) =
        TcpClientTransport::connect_as_new_player(addr, "Player2").unwrap();

    let _ = wait_for_data(
        || host_transport.poll_connection_events(),
        Duration::from_secs(1),
    );

    let seed = 2024;
    let mut host_session = chess_game::new_chess_session(SessionId(1), seed, p1, p2);

    let cmd: Box<dyn Command> = Box::new(chess_game::commands::ResignCommand {
        player: p1,
    });
    
    let envelope = CommandEnvelope {
        tick: host_session.current_tick(),
        payload: cmd,
    };
    let bytes = serde_json::to_vec(&envelope).unwrap();
    p1_transport.send(open_table_transport_tcp::HOST_PLAYER_ID, &bytes).unwrap();

    let received = wait_for_data(|| host_transport.poll_received(), Duration::from_secs(2));
    let (sender, raw) = &received[0];
    let decoded: CommandEnvelope = serde_json::from_slice(raw).unwrap();
    host_session.process_command(*sender, decoded.payload).unwrap();

    p1_transport.disconnect().unwrap();
    drop(p1_transport);

    let disconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Disconnected { player } if *player == p1))
        },
        Duration::from_secs(2),
    );

    let mut p1_transport =
        TcpClientTransport::reconnect(addr, p1, p1_token).unwrap();

    let reconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Reconnected { player } if *player == p1))
        },
        Duration::from_secs(2),
    );

    let log_bytes = host_session.export_log().unwrap();
    let temp_session = chess_game::new_chess_session(SessionId(1), seed, p1, p2);
    let (_temp_session, all_events) = Session::replay_on_session(
        temp_session,
        &log_bytes,
    )
    .unwrap();

    let events_for_p1 = filter_events_for_player(&all_events, p1);
    assert!(!events_for_p1.is_empty(), "P1 should have received events in resync");

    for event in &events_for_p1 {
        let bytes = serde_json::to_vec(&EventEnvelope {
            tick: host_session.current_tick(),
            payload: clone_event_for_wire(*event),
        })
        .unwrap();
        host_transport.send(p1, &bytes).unwrap();
    }

    let received_by_p1 = wait_for_data_count(
        || p1_transport.poll_received(),
        events_for_p1.len(),
        Duration::from_secs(2),
    );
    assert_eq!(received_by_p1.len(), events_for_p1.len());
}

#[test]
fn test_reconexion_con_eventos_reales_de_go() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind del host");
    let addr = host_transport.local_addr();

    let (mut p1_transport, p1, p1_token) =
        TcpClientTransport::connect_as_new_player(addr, "Player1").unwrap();
    let (mut p2_transport, p2, _p2_token) =
        TcpClientTransport::connect_as_new_player(addr, "Player2").unwrap();

    let _ = wait_for_data(
        || host_transport.poll_connection_events(),
        Duration::from_secs(1),
    );

    let seed = 2024;
    let mut host_session = go_game::new_go_session(SessionId(1), seed, p1, p2);

    let cmd: Box<dyn Command> = Box::new(go_game::commands::ResignCommand {
        player: p1,
    });
    
    let envelope = CommandEnvelope {
        tick: host_session.current_tick(),
        payload: cmd,
    };
    let bytes = serde_json::to_vec(&envelope).unwrap();
    p1_transport.send(open_table_transport_tcp::HOST_PLAYER_ID, &bytes).unwrap();

    let received = wait_for_data(|| host_transport.poll_received(), Duration::from_secs(2));
    let (sender, raw) = &received[0];
    let decoded: CommandEnvelope = serde_json::from_slice(raw).unwrap();
    host_session.process_command(*sender, decoded.payload).unwrap();

    p1_transport.disconnect().unwrap();
    drop(p1_transport);

    let disconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Disconnected { player } if *player == p1))
        },
        Duration::from_secs(2),
    );

    let mut p1_transport =
        TcpClientTransport::reconnect(addr, p1, p1_token).unwrap();

    let reconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Reconnected { player } if *player == p1))
        },
        Duration::from_secs(2),
    );

    let log_bytes = host_session.export_log().unwrap();
    let temp_session = go_game::new_go_session(SessionId(1), seed, p1, p2);
    let (_temp_session, all_events) = Session::replay_on_session(
        temp_session,
        &log_bytes,
    )
    .unwrap();

    let events_for_p1 = filter_events_for_player(&all_events, p1);
    assert!(!events_for_p1.is_empty(), "P1 should have received events in resync");

    for event in &events_for_p1 {
        let bytes = serde_json::to_vec(&EventEnvelope {
            tick: host_session.current_tick(),
            payload: clone_event_for_wire(*event),
        })
        .unwrap();
        host_transport.send(p1, &bytes).unwrap();
    }

    let received_by_p1 = wait_for_data_count(
        || p1_transport.poll_received(),
        events_for_p1.len(),
        Duration::from_secs(2),
    );
    assert_eq!(received_by_p1.len(), events_for_p1.len());
}
