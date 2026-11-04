// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use checkers_game::{new_checkers_session, MovePieceCommand, Position};
use open_table_engine::prelude::*;
use open_table_transport_tcp::{
    ConnectionEvent, TcpClientTransport, TcpHostTransport, HOST_PLAYER_ID,
};
use std::time::Duration;

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

fn clone_event_for_wire(event: &dyn Event) -> Box<dyn Event> {
    let bytes = serde_json::to_vec(event).expect("serialize event");
    serde_json::from_slice(&bytes).expect("deserialize event")
}

fn wait_for_received(
    transport: &mut TcpHostTransport,
    timeout: Duration,
) -> Vec<(PlayerId, Vec<u8>)> {
    let start = std::time::Instant::now();
    loop {
        let items = transport.poll_received();
        if !items.is_empty() || start.elapsed() > timeout {
            return items;
        }
        std::thread::sleep(Duration::from_millis(5));
    }
}

fn wait_for_connection_events(
    transport: &mut TcpHostTransport,
    timeout: Duration,
) -> Vec<ConnectionEvent> {
    let start = std::time::Instant::now();
    loop {
        let items = transport.poll_connection_events();
        if !items.is_empty() || start.elapsed() > timeout {
            return items;
        }
        std::thread::sleep(Duration::from_millis(5));
    }
}

#[tokio::test]
async fn test_red_caos_desconexiones_aleatorias_y_resync() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind host");
    let addr = host_transport.local_addr();

    let (mut alice_transport, alice, alice_token) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("Alice se conecta");
    let (mut bob_transport, bob, _bob_token) =
        TcpClientTransport::connect_as_new_player(addr, "Bob").expect("Bob se conecta");

    std::thread::sleep(Duration::from_millis(50));
    let _ = host_transport.poll_connection_events();

    let seed = 12345;
    let mut host_session = new_checkers_session(SessionId(1), seed, alice, bob);

    // 5 movimientos planificados de damas
    let moves = vec![
        (alice, pos(2, 1), pos(3, 2)),
        (bob, pos(5, 6), pos(4, 7)),
        (alice, pos(2, 3), pos(3, 4)),
        (bob, pos(5, 0), pos(4, 1)),
        (alice, pos(3, 2), pos(5, 0)),
    ];

    let mut move_count = 0;

    for (player, from, to) in moves {
        // En el movimiento 3, inyectamos una desconexión caótica de Alice con sleep + drop
        if move_count == 2 {
            // Alice se desconecta caóticamente
            alice_transport.disconnect().expect("disconnect Alice");
            drop(alice_transport);

            let conn_events =
                wait_for_connection_events(&mut host_transport, Duration::from_millis(500));
            assert!(
                conn_events.iter().any(
                    |e| matches!(e, ConnectionEvent::Disconnected { player: p } if *p == alice)
                ),
                "El host debe haber detectado la desconexión de Alice"
            );

            // Alice se reconecta con su token
            let reconnected_alice = TcpClientTransport::reconnect(addr, alice, alice_token.clone())
                .expect("Alice se reconecta");

            let reconn_events =
                wait_for_connection_events(&mut host_transport, Duration::from_millis(500));
            assert!(
                reconn_events.iter().any(
                    |e| matches!(e, ConnectionEvent::Reconnected { player: p } if *p == alice)
                ),
                "El host debe haber detectado la reconexión de Alice"
            );

            // Resync: replay log y enviar eventos a Alice
            let log_bytes = host_session.export_log().expect("export log");
            let resync_session = new_checkers_session(SessionId(1), seed, alice, bob);
            let (_temp, all_events) = Session::replay_on_session(resync_session, &log_bytes)
                .expect("replay collecting events");

            let events_for_alice = filter_events_for_player(&all_events, alice);
            for evt in &events_for_alice {
                let bytes = serde_json::to_vec(&EventEnvelope {
                    tick: host_session.current_tick(),
                    payload: clone_event_for_wire(*evt),
                })
                .expect("serialize event envelope");
                host_transport.send(alice, &bytes).expect("send resync");
            }

            alice_transport = reconnected_alice;
        }

        let cmd: Box<dyn Command> = Box::new(MovePieceCommand { player, from, to });
        let env = CommandEnvelope {
            tick: host_session.current_tick(),
            payload: cmd,
        };
        let bytes = serde_json::to_vec(&env).expect("serialize command");

        if player == alice {
            alice_transport
                .send(HOST_PLAYER_ID, &bytes)
                .expect("send cmd Alice");
        } else {
            bob_transport
                .send(HOST_PLAYER_ID, &bytes)
                .expect("send cmd Bob");
        }

        let received = wait_for_received(&mut host_transport, Duration::from_millis(500));
        assert!(
            !received.is_empty(),
            "El host debe haber recibido el comando de movimiento"
        );
        for (sender, raw) in received {
            let decoded: CommandEnvelope = serde_json::from_slice(&raw).expect("decode envelope");
            let events = host_session
                .process_command(sender, decoded.payload)
                .expect("process command debe ser exitoso sin panic ni estado corrupto");
            assert!(!events.is_empty());
        }

        move_count += 1;
    }

    assert_eq!(
        move_count, 5,
        "Se deben haber jugado los 5 movimientos exitosamente"
    );
    assert_eq!(
        host_session.tick_timestamps().len(),
        5,
        "La sesión debe registrar 5 ticks en el log"
    );
}
