// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use std::net::TcpStream;
use std::thread;
use std::time::{Duration, Instant};

use chess_game::{new_chess_session, MovePieceCommand, PieceMovedEvent, Position};
use open_table_engine::prelude::*;
use open_table_transport_tcp::{
    ConnectionEvent, TcpClientTransport, TcpHostTransport, HOST_PLAYER_ID,
};

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

fn clone_event_for_wire(event: &dyn Event) -> Box<dyn Event> {
    let bytes = serde_json::to_vec(event).expect("serialize event");
    serde_json::from_slice(&bytes).expect("deserialize event")
}

#[test]
fn chess_reconnection_resync_delivers_piece_moved_event() {
    let mut host_transport = TcpHostTransport::bind("127.0.0.1:0").expect("bind host");
    let addr = host_transport.local_addr();

    let (mut white_transport, white, white_token) =
        TcpClientTransport::connect_as_new_player(addr, "White").expect("White connects");
    let (_black_transport, black, _black_token) =
        TcpClientTransport::connect_as_new_player(addr, "Black").expect("Black connects");

    // Clear connection events
    let _ = wait_for_data(
        || host_transport.poll_connection_events(),
        Duration::from_secs(1),
    );

    let seed = 42;
    let mut host_session = new_chess_session(SessionId(1), seed, white, black);

    // White plays pawn advance e2 -> e4 (1, 4 -> 3, 4)
    let move_cmd: Box<dyn Command> = Box::new(MovePieceCommand {
        player: white,
        from: Position::new(1, 4),
        to: Position::new(3, 4),
        promote_to: None,
    });

    let envelope = CommandEnvelope {
        tick: host_session.current_tick(),
        payload: move_cmd,
    };
    let bytes = serde_json::to_vec(&envelope).expect("serialize command envelope");
    white_transport
        .send(HOST_PLAYER_ID, &bytes)
        .expect("White sends move");

    let received = wait_for_data(|| host_transport.poll_received(), Duration::from_secs(2));
    assert_eq!(received.len(), 1);
    let (sender, raw) = &received[0];
    let decoded: CommandEnvelope = serde_json::from_slice(raw).expect("decode command");
    host_session
        .process_command(*sender, decoded.payload)
        .expect("process pawn move command");

    // White disconnects
    white_transport.disconnect().expect("disconnect White");
    drop(white_transport);

    let disconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Disconnected { player } if *player == white))
        },
        Duration::from_secs(2),
    );
    assert_eq!(
        disconnect_event,
        Some(ConnectionEvent::Disconnected { player: white })
    );

    // White reconnects
    let mut white_transport =
        TcpClientTransport::reconnect(addr, white, white_token).expect("White reconnects");

    let reconnect_event = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Reconnected { player } if *player == white))
        },
        Duration::from_secs(2),
    );
    assert_eq!(
        reconnect_event,
        Some(ConnectionEvent::Reconnected { player: white })
    );

    // Resync pipeline
    let log_bytes = host_session.export_log().expect("export log");
    let resync_session = new_chess_session(SessionId(1), seed, white, black);
    let (_temp_session, all_events) = Session::replay_on_session(resync_session, &log_bytes)
        .expect("replay collecting events for chess resync");

    let events_for_white = filter_events_for_player(&all_events, white);
    assert_eq!(
        events_for_white.len(),
        1,
        "Should deliver exactly 1 event for White"
    );

    for event in &events_for_white {
        let bytes = serde_json::to_vec(&EventEnvelope {
            tick: host_session.current_tick(),
            payload: clone_event_for_wire(*event),
        })
        .expect("serialize event envelope");
        host_transport
            .send(white, &bytes)
            .expect("send resync to White");
    }

    let received_by_white = wait_for_data_count(
        || white_transport.poll_received(),
        events_for_white.len(),
        Duration::from_secs(2),
    );

    assert_eq!(received_by_white.len(), 1, "Delivered exactly 1 event");

    let (_, raw) = &received_by_white[0];
    let envelope: EventEnvelope =
        serde_json::from_slice(raw).expect("decode event envelope from wire");

    let piece_moved = envelope
        .payload
        .as_any()
        .downcast_ref::<PieceMovedEvent>()
        .expect("Resynced event must be a PieceMovedEvent");

    assert_eq!(piece_moved.player, white);
    assert_eq!(piece_moved.from, Position::new(1, 4));
    assert_eq!(piece_moved.to, Position::new(3, 4));

    // Confirm host is alive
    let _ = TcpStream::connect(addr);
}
