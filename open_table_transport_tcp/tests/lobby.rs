use std::thread;
use std::time::{Duration, Instant};

use open_table_transport_tcp::{JoinedPlayer, TcpClientTransport, TcpLobby};

#[test]
fn dos_clientes_se_unen_al_lobby_y_start_game_retorna_ambos_player_ids() {
    let lobby = TcpLobby::bind("127.0.0.1:0").expect("bind del lobby");
    let addr = lobby.local_addr();

    // Cliente 1 (Alice) se une al lobby
    let (_c1, p1, _token1) =
        TcpClientTransport::connect_as_new_player(addr, "Alice").expect("Alice se une al lobby");

    // Cliente 2 (Bob) se une al lobby
    let (_c2, p2, _token2) =
        TcpClientTransport::connect_as_new_player(addr, "Bob").expect("Bob se une al lobby");

    // Esperar a que el lobby registre a ambos jugadores
    let start = Instant::now();
    let mut joined = Vec::new();
    while start.elapsed() < Duration::from_secs(2) {
        joined = lobby.joined_players();
        if joined.len() == 2 {
            break;
        }
        thread::sleep(Duration::from_millis(10));
    }

    assert_eq!(joined.len(), 2, "el lobby debería recolectar 2 jugadores");
    assert_eq!(
        joined,
        vec![
            JoinedPlayer {
                player_id: p1,
                display_name: "Alice".to_string(),
            },
            JoinedPlayer {
                player_id: p2,
                display_name: "Bob".to_string(),
            },
        ]
    );

    // Transicionar el lobby a TcpHostTransport e iniciar la partida
    let (_host_transport, player_ids) = lobby.start_game();

    assert_eq!(player_ids.len(), 2);
    assert_eq!(player_ids, vec![p1, p2]);
}
