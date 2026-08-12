//! Prueba que un jugador desconectado que NO vuelve a tiempo:
//! 1. Genera un `ConnectionEvent::TimedOut` (no se queda esperando para
//!    siempre).
//! 2. Ya no puede reconectarse con su `reconnect_token` viejo — el host
//!    lo rechaza como si la sesión no hubiera existido nunca.
//!
//! Usa un `reconnect_timeout` corto (unos cientos de milisegundos) para
//! que el test no tenga que esperar el default de producción (60s).

use std::thread;
use std::time::{Duration, Instant};

use open_table_transport_tcp::{ConnectionEvent, TcpClientTransport, TcpHostTransport};

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
fn un_jugador_que_no_vuelve_a_tiempo_pierde_su_sesion() {
    let short_timeout = Duration::from_millis(150);
    let mut host_transport =
        TcpHostTransport::bind_with_timeout("127.0.0.1:0", short_timeout).expect("bind del host");
    let addr = host_transport.local_addr();

    let (alice_transport, alice, alice_token) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("Alice se conecta");

    // Consumir el evento de Joined para no confundirlo con el de abajo.
    let _ = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Joined { player } if *player == alice))
        },
        Duration::from_secs(1),
    );

    alice_transport
        .disconnect()
        .expect("cierra la conexión de Alice");
    drop(alice_transport);

    let disconnected = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Disconnected { player } if *player == alice))
        },
        Duration::from_secs(1),
    );
    assert_eq!(
        disconnected,
        Some(ConnectionEvent::Disconnected { player: alice })
    );

    // Esperamos más que el timeout configurado, SIN que Alice se
    // reconecte, para forzar que expire.
    thread::sleep(short_timeout + Duration::from_millis(100));

    let timed_out = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::TimedOut { player } if *player == alice))
        },
        Duration::from_secs(1),
    );
    assert_eq!(timed_out, Some(ConnectionEvent::TimedOut { player: alice }));

    // El token ya no sirve: el host tiene que rechazar la reconexión.
    let result = TcpClientTransport::reconnect(addr, alice, alice_token);
    assert!(
        result.is_err(),
        "una reconexión después del timeout debería ser rechazada"
    );
}

#[test]
fn reconectar_a_tiempo_cancela_el_timeout() {
    let short_timeout = Duration::from_millis(300);
    let mut host_transport =
        TcpHostTransport::bind_with_timeout("127.0.0.1:0", short_timeout).expect("bind del host");
    let addr = host_transport.local_addr();

    let (alice_transport, alice, alice_token) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("Alice se conecta");
    let _ = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Joined { player } if *player == alice))
        },
        Duration::from_secs(1),
    );

    alice_transport.disconnect().unwrap();
    drop(alice_transport);
    let _ = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Disconnected { player } if *player == alice))
        },
        Duration::from_secs(1),
    );

    // Reconecta ANTES de que expire el timeout.
    let _reconnected_transport = TcpClientTransport::reconnect(addr, alice, alice_token.clone())
        .expect("reconecta a tiempo");

    let reconnected = wait_until(
        || {
            host_transport
                .poll_connection_events()
                .into_iter()
                .find(|e| matches!(e, ConnectionEvent::Reconnected { player } if *player == alice))
        },
        Duration::from_secs(1),
    );
    assert_eq!(
        reconnected,
        Some(ConnectionEvent::Reconnected { player: alice })
    );

    // Esperamos más que el timeout original: como ya se reconectó, NO
    // debería aparecer ningún TimedOut para Alice.
    thread::sleep(short_timeout + Duration::from_millis(150));
    let spurious_timeout = host_transport
        .poll_connection_events()
        .into_iter()
        .find(|e| matches!(e, ConnectionEvent::TimedOut { player } if *player == alice));
    assert_eq!(
        spurious_timeout, None,
        "no debería expirar una sesión que ya se reconectó"
    );
}
