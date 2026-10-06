//! Microservidor standalone de salas, retransmisión WebSocket y servicio ELO para OpenTable SDK.
//!
//! Protocolo JSON WebSocket (puerto 8080):
//! - `{"op": "create"}` -> `{"op": "created", "room_code": "XKCD"}`
//! - `{"op": "join", "room_code": "XKCD"}` -> `{"op": "joined", "player_id": 2}`
//! - `{"op": "relay", "data": "..."}` -> retransmite el payload a los demás participantes
//! - `{"op": "report_result", "winner": "player1", "loser": "player2", "game_id": "chess"}` -> actualiza ELO (K=32)
//! - `{"op": "leave"}` / desconexión -> notifica a los participantes restantes (`peer_left`)
//!
//! API HTTP (puerto 8081):
//! - `GET /rankings/:game_id` -> JSON con top-50 jugadores por ELO
//! - `GET /player/:player_id` -> JSON con todos los ratings del jugador por juego

pub mod api;
pub mod elo;
pub mod room;
pub mod tournament;

use api::run_http_api_server;
use elo::EloStore;
use futures_util::{SinkExt, StreamExt};
use room::{ClientSender, ConnectionId, RoomError, RoomManager};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::net::SocketAddr;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, Mutex};
use tokio_tungstenite::tungstenite::Message;
use tournament::{Tournament, TournamentManager};

/// Solicitud entrante enviada por un cliente WebSocket al servidor Relay.
#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum RelayRequest {
    /// Crea una nueva sala y registra al cliente como anfitrión (`player_id = 1`).
    Create {
        /// Identificador opcional del juego.
        #[serde(default)]
        game_id: Option<String>,
        /// Indica si la sala es pública (por defecto `true`).
        #[serde(default = "default_true")]
        is_public: bool,
    },
    /// Une al cliente a una sala existente mediante su código.
    Join {
        /// Código de la sala.
        room_code: String,
    },
    /// Retransmite `data` a todos los demás participantes de la sala actual.
    Relay {
        /// Payload arbitrario a retransmitir.
        data: Value,
    },
    /// Reporta el resultado de una partida para actualizar el ELO persistente (K=32).
    ReportResult {
        /// Identificador del jugador ganador.
        winner: String,
        /// Identificador del jugador perdedor.
        loser: String,
        /// Identificador del juego (ej. `"chess"`).
        game_id: String,
    },
    /// Crea un nuevo torneo de eliminación simple (4, 8 o 16 jugadores).
    CreateTournament {
        /// Identificador del juego.
        game_id: String,
        /// Capacidad máxima de participantes (`4`, `8` o `16`).
        max_players: usize,
    },
    /// Une a un participante a un torneo existente.
    JoinTournament {
        /// Identificador del torneo (ej. `"T-AB12"`).
        tournament_id: String,
        /// Identificador opcional del jugador.
        #[serde(default)]
        player_id: Option<String>,
    },
    /// Reporta el ganador de un enfrentamiento de torneo y avanza a la siguiente ronda.
    ReportTournamentMatch {
        /// Identificador del torneo.
        tournament_id: String,
        /// Índice de ronda.
        round: usize,
        /// Índice de enfrentamiento dentro de la ronda.
        match_index: usize,
        /// Identificador del jugador ganador.
        winner: String,
    },
    /// Abandona voluntariamente la sala actual.
    Leave,
    /// Ping de mantenimiento de conexión.
    Ping,
}

fn default_true() -> bool {
    true
}

/// Respuesta o evento enviado por el servidor Relay a los clientes.
#[derive(Debug, Serialize, Deserialize, PartialEq)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum RelayResponse {
    /// Confirmación de creación de sala.
    Created {
        /// Código asignado a la sala.
        room_code: String,
    },
    /// Confirmación de unión exitosa a una sala.
    Joined {
        /// Identificador de jugador asignado dentro de la sala (2..N).
        player_id: u32,
    },
    /// Notificación a los miembros existentes cuando un nuevo jugador entra a la sala.
    PeerJoined {
        /// Identificador del nuevo jugador.
        player_id: u32,
    },
    /// Mensaje retransmitido desde otro participante de la sala.
    Relay {
        /// Payload retransmitido.
        data: Value,
        /// Identificador del jugador que originó el mensaje.
        #[serde(skip_serializing_if = "Option::is_none")]
        from: Option<u32>,
    },
    /// Confirmación de actualización de ELO tras reportar un resultado.
    ResultReported {
        /// Identificador del juego.
        game_id: String,
        /// Identificador del ganador.
        winner: String,
        /// Nuevo ELO del ganador.
        winner_elo: i32,
        /// Identificador del perdedor.
        loser: String,
        /// Nuevo ELO del perdedor.
        loser_elo: i32,
    },
    /// Confirmación de creación de torneo.
    TournamentCreated {
        /// Identificador único del torneo (ej. `"T-AB12"`).
        tournament_id: String,
    },
    /// Estado actualizado del bracket del torneo.
    TournamentUpdated {
        /// Estado completo del torneo y sus rondas.
        tournament: Tournament,
    },
    /// Confirmación al cliente que solicitó salir de la sala.
    Left {
        /// Código de la sala abandonada.
        room_code: String,
    },
    /// Notificación a los participantes restantes cuando alguien se desconecta o sale.
    PeerLeft {
        /// Código de la sala.
        room_code: String,
        /// Identificador del jugador que salió.
        player_id: u32,
    },
    /// Respuesta a `{"op": "ping"}`.
    Pong,
    /// Error de protocolo o de estado de sala.
    Error {
        /// Descripción legible del error.
        message: String,
    },
}

/// Inicia el servidor Relay sobre un `TcpListener` ya enlazado usando la base de datos por defecto.
pub async fn run_relay_server(listener: TcpListener) -> std::io::Result<()> {
    let db_path =
        std::env::var("OPEN_TABLE_RATINGS_DB").unwrap_or_else(|_| "./data/ratings.db".to_string());
    let elo_store = Arc::new(Mutex::new(EloStore::new(db_path)?));
    run_relay_server_with_store(listener, elo_store).await
}

/// Inicia el servidor Relay compartiendo una instancia de `EloStore` con el servidor HTTP.
pub async fn run_relay_server_with_store(
    listener: TcpListener,
    elo_store: Arc<Mutex<EloStore>>,
) -> std::io::Result<()> {
    let manager = Arc::new(Mutex::new(RoomManager::new()));
    let tournaments = Arc::new(Mutex::new(TournamentManager::new()));
    let next_conn_id = Arc::new(AtomicU64::new(1));

    loop {
        let (stream, _peer_addr) = listener.accept().await?;
        let conn_id = next_conn_id.fetch_add(1, Ordering::Relaxed);
        let manager_clone = Arc::clone(&manager);
        let store_clone = Arc::clone(&elo_store);
        let tournaments_clone = Arc::clone(&tournaments);

        tokio::spawn(async move {
            handle_connection(
                stream,
                conn_id,
                manager_clone,
                store_clone,
                tournaments_clone,
            )
            .await;
        });
    }
}

async fn handle_connection(
    stream: TcpStream,
    conn_id: ConnectionId,
    manager: Arc<Mutex<RoomManager>>,
    elo_store: Arc<Mutex<EloStore>>,
    tournaments: Arc<Mutex<TournamentManager>>,
) {
    let ws_stream = match tokio_tungstenite::accept_async(stream).await {
        Ok(ws) => ws,
        Err(_) => return,
    };

    let (mut ws_sink, mut ws_source) = ws_stream.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<String>();

    let writer_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if ws_sink.send(Message::Text(msg.into())).await.is_err() {
                break;
            }
        }
    });

    while let Some(Ok(msg)) = ws_source.next().await {
        match msg {
            Message::Text(text) => {
                process_text_message(&text, conn_id, &tx, &manager, &elo_store, &tournaments).await;
            }
            Message::Ping(payload) => {
                let _ = tx.send(
                    serde_json::to_string(&RelayResponse::Pong)
                        .unwrap_or_else(|_| r#"{"op":"pong"}"#.to_string()),
                );
                let _ = payload;
            }
            Message::Close(_) => {
                break;
            }
            _ => {}
        }
    }

    {
        let mut mgr = manager.lock().await;
        mgr.leave_room(conn_id);
    }

    writer_task.abort();
}

async fn process_text_message(
    raw_text: &str,
    conn_id: ConnectionId,
    tx: &ClientSender,
    manager: &Arc<Mutex<RoomManager>>,
    elo_store: &Arc<Mutex<EloStore>>,
    tournaments: &Arc<Mutex<TournamentManager>>,
) {
    let parsed: Result<RelayRequest, _> = serde_json::from_str(raw_text);
    let request = match parsed {
        Ok(req) => req,
        Err(err) => {
            send_response(
                tx,
                &RelayResponse::Error {
                    message: format!("invalid json request: {err}"),
                },
            );
            return;
        }
    };

    match request {
        RelayRequest::Create { game_id, is_public } => {
            let mut mgr = manager.lock().await;
            let room_code = mgr.create_room(conn_id, tx.clone(), game_id, is_public);
            send_response(tx, &RelayResponse::Created { room_code });
        }
        RelayRequest::Join { room_code } => {
            let mut mgr = manager.lock().await;
            match mgr.join_room(conn_id, tx.clone(), &room_code) {
                Ok((normalized_code, player_id)) => {
                    send_response(tx, &RelayResponse::Joined { player_id });
                    if let Ok(peer_notice) =
                        serde_json::to_string(&RelayResponse::PeerJoined { player_id })
                    {
                        let _ = mgr.relay_to_peers(conn_id, &peer_notice);
                    }
                    let _ = normalized_code;
                }
                Err(RoomError::InvalidRoomCode) => {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: "invalid room code format".to_string(),
                        },
                    );
                }
                Err(RoomError::RoomNotFound) => {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: "room not found".to_string(),
                        },
                    );
                }
                Err(RoomError::NotInRoom) => {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: "not in room".to_string(),
                        },
                    );
                }
            }
        }
        RelayRequest::Relay { data } => {
            let mgr = manager.lock().await;
            let from_player = mgr.participant_info(conn_id).map(|(_, pid)| pid);
            let outbound = RelayResponse::Relay {
                data,
                from: from_player,
            };
            if let Ok(serialized) = serde_json::to_string(&outbound) {
                if mgr.relay_to_peers(conn_id, &serialized).is_err() {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: "client is not in a room".to_string(),
                        },
                    );
                }
            }
        }
        RelayRequest::ReportResult {
            winner,
            loser,
            game_id,
        } => {
            let mut store = elo_store.lock().await;
            match store.report_result(&winner, &loser, &game_id) {
                Ok((w_rating, l_rating)) => {
                    send_response(
                        tx,
                        &RelayResponse::ResultReported {
                            game_id,
                            winner,
                            winner_elo: w_rating.elo,
                            loser,
                            loser_elo: l_rating.elo,
                        },
                    );
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: format!("failed to persist ELO result: {err}"),
                        },
                    );
                }
            }
        }
        RelayRequest::CreateTournament {
            game_id,
            max_players,
        } => {
            let mut tm = tournaments.lock().await;
            match tm.create_tournament(game_id, max_players) {
                Ok(tournament_id) => {
                    send_response(tx, &RelayResponse::TournamentCreated { tournament_id });
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: format!("invalid tournament configuration: {err:?}"),
                        },
                    );
                }
            }
        }
        RelayRequest::JoinTournament {
            tournament_id,
            player_id,
        } => {
            let mut tm = tournaments.lock().await;
            let pid = player_id.unwrap_or_else(|| format!("player_{conn_id}"));
            match tm.join_tournament(&tournament_id, pid) {
                Ok((tournament, _started)) => {
                    send_response(tx, &RelayResponse::TournamentUpdated { tournament });
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: format!("failed to join tournament: {err:?}"),
                        },
                    );
                }
            }
        }
        RelayRequest::ReportTournamentMatch {
            tournament_id,
            round,
            match_index,
            winner,
        } => {
            let mut tm = tournaments.lock().await;
            match tm.report_match(&tournament_id, round, match_index, &winner) {
                Ok(tournament) => {
                    send_response(tx, &RelayResponse::TournamentUpdated { tournament });
                }
                Err(err) => {
                    send_response(
                        tx,
                        &RelayResponse::Error {
                            message: format!("failed to report tournament match: {err:?}"),
                        },
                    );
                }
            }
        }
        RelayRequest::Leave => {
            let mut mgr = manager.lock().await;
            if let Some((room_code, _player_id)) = mgr.leave_room(conn_id) {
                send_response(tx, &RelayResponse::Left { room_code });
            } else {
                send_response(
                    tx,
                    &RelayResponse::Error {
                        message: "client is not in a room".to_string(),
                    },
                );
            }
        }
        RelayRequest::Ping => {
            send_response(tx, &RelayResponse::Pong);
        }
    }
}

fn send_response(tx: &ClientSender, response: &RelayResponse) {
    if let Ok(json) = serde_json::to_string(response) {
        let _ = tx.send(json);
    }
}

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let ws_addr: SocketAddr = std::env::var("OPEN_TABLE_RELAY_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8080".to_string())
        .parse()
        .expect("OPEN_TABLE_RELAY_ADDR debe ser un SocketAddr válido (ej. 0.0.0.0:8080)");

    let http_addr: SocketAddr = std::env::var("OPEN_TABLE_HTTP_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8081".to_string())
        .parse()
        .expect("OPEN_TABLE_HTTP_ADDR debe ser un SocketAddr válido (ej. 0.0.0.0:8081)");

    let db_path =
        std::env::var("OPEN_TABLE_RATINGS_DB").unwrap_or_else(|_| "./data/ratings.db".to_string());
    let elo_store = Arc::new(Mutex::new(EloStore::new(Path::new(&db_path))?));

    let ws_listener = TcpListener::bind(ws_addr).await?;
    let http_listener = TcpListener::bind(http_addr).await?;

    println!("open_table_relay WebSocket listening on ws://{ws_addr}");
    println!("open_table_relay HTTP ELO API listening on http://{http_addr}");

    tokio::try_join!(
        run_relay_server_with_store(ws_listener, Arc::clone(&elo_store)),
        run_http_api_server(http_listener, elo_store),
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio_tungstenite::connect_async;

    #[tokio::test]
    async fn test_websocket_relay_end_to_end() {
        let db_file =
            std::env::temp_dir().join(format!("opentable_ratings_ws_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let server_handle = tokio::spawn(async move {
            let _ = run_relay_server_with_store(listener, elo_store).await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        // 1. Host crea sala: {"op": "create"} -> {"op": "created", "room_code": "XXXXXX"}
        ws_host
            .send(Message::Text(r#"{"op":"create"}"#.into()))
            .await
            .unwrap();
        let created_msg = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let created_val: Value = serde_json::from_str(&created_msg).unwrap();
        assert_eq!(created_val["op"], "created");
        let room_code = created_val["room_code"].as_str().unwrap().to_string();
        assert!(room::is_valid_room_code(&room_code));

        // 2. Guest se une: {"op": "join", "room_code": "..."} -> {"op": "joined", "player_id": 2}
        let join_cmd = serde_json::json!({
            "op": "join",
            "room_code": room_code,
        })
        .to_string();
        ws_guest.send(Message::Text(join_cmd.into())).await.unwrap();

        let joined_msg = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let joined_val: Value = serde_json::from_str(&joined_msg).unwrap();
        assert_eq!(joined_val["op"], "joined");
        assert_eq!(joined_val["player_id"], 2);

        let host_notice = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let host_notice_val: Value = serde_json::from_str(&host_notice).unwrap();
        assert_eq!(host_notice_val["op"], "peer_joined");
        assert_eq!(host_notice_val["player_id"], 2);

        // 3. Host envía {"op": "relay", "data": "move_e2e4"} -> Guest lo recibe
        ws_host
            .send(Message::Text(r#"{"op":"relay","data":"move_e2e4"}"#.into()))
            .await
            .unwrap();
        let relayed_msg = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let relayed_val: Value = serde_json::from_str(&relayed_msg).unwrap();
        assert_eq!(relayed_val["op"], "relay");
        assert_eq!(relayed_val["data"], "move_e2e4");
        assert_eq!(relayed_val["from"], 1);

        // 4. Guest envía {"op": "leave"} -> Host recibe notificación peer_left
        ws_guest
            .send(Message::Text(r#"{"op":"leave"}"#.into()))
            .await
            .unwrap();
        let left_confirm = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
        let left_confirm_val: Value = serde_json::from_str(&left_confirm).unwrap();
        assert_eq!(left_confirm_val["op"], "left");

        let peer_left_msg = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
        let peer_left_val: Value = serde_json::from_str(&peer_left_msg).unwrap();
        assert_eq!(peer_left_val["op"], "peer_left");
        assert_eq!(peer_left_val["player_id"], 2);

        server_handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }

    #[tokio::test]
    async fn test_elo_report_result_and_http_api() {
        let db_file =
            std::env::temp_dir().join(format!("opentable_ratings_elo_{}.db", std::process::id()));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let ws_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let ws_addr = ws_listener.local_addr().unwrap();

        let http_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let http_addr = http_listener.local_addr().unwrap();

        let store_ws = Arc::clone(&elo_store);
        let ws_handle = tokio::spawn(async move {
            let _ = run_relay_server_with_store(ws_listener, store_ws).await;
        });

        let store_http = Arc::clone(&elo_store);
        let http_handle = tokio::spawn(async move {
            let _ = run_http_api_server(http_listener, store_http).await;
        });

        // Reportar resultado por WebSocket: player1 vence a player2 en chess (K=32: 1200 -> 1216 / 1184)
        let (mut ws_client, _) = connect_async(&format!("ws://{ws_addr}")).await.unwrap();
        ws_client
            .send(Message::Text(
                r#"{"op":"report_result","winner":"player1","loser":"player2","game_id":"chess"}"#
                    .into(),
            ))
            .await
            .unwrap();

        let resp_txt = ws_client
            .next()
            .await
            .unwrap()
            .unwrap()
            .into_text()
            .unwrap();
        let resp_val: Value = serde_json::from_str(&resp_txt).unwrap();
        assert_eq!(resp_val["op"], "result_reported");
        assert_eq!(resp_val["winner_elo"], 1216);
        assert_eq!(resp_val["loser_elo"], 1184);

        // Consultar GET /rankings/chess por HTTP
        let mut stream = TcpStream::connect(http_addr).await.unwrap();
        stream
            .write_all(b"GET /rankings/chess HTTP/1.1\r\nHost: localhost\r\n\r\n")
            .await
            .unwrap();
        let mut buf = Vec::new();
        stream.read_to_end(&mut buf).await.unwrap();
        let http_resp = String::from_utf8_lossy(&buf);
        assert!(http_resp.contains("200 OK"));
        assert!(http_resp.contains("\"player1\""));
        assert!(http_resp.contains("1216"));

        // Consultar GET /player/player1 por HTTP
        let mut stream2 = TcpStream::connect(http_addr).await.unwrap();
        stream2
            .write_all(b"GET /player/player1 HTTP/1.1\r\nHost: localhost\r\n\r\n")
            .await
            .unwrap();
        let mut buf2 = Vec::new();
        stream2.read_to_end(&mut buf2).await.unwrap();
        let http_resp2 = String::from_utf8_lossy(&buf2);
        assert!(http_resp2.contains("200 OK"));
        assert!(http_resp2.contains("\"chess\""));

        ws_handle.abort();
        http_handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }
}
