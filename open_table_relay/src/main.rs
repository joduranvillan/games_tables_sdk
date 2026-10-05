//! Microservidor standalone de salas y retransmisión WebSocket para OpenTable SDK.
//!
//! Protocolo JSON mínimo:
//! - `{"op": "create"}` -> `{"op": "created", "room_code": "XKCD"}`
//! - `{"op": "join", "room_code": "XKCD"}` -> `{"op": "joined", "player_id": 2}`
//! - `{"op": "relay", "data": "..."}` -> retransmite el payload a los demás participantes
//! - `{"op": "leave"}` / desconexión -> notifica a los participantes restantes (`peer_left`)

pub mod room;

use futures_util::{SinkExt, StreamExt};
use room::{ClientSender, ConnectionId, RoomError, RoomManager};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, Mutex};
use tokio_tungstenite::tungstenite::Message;

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
    /// Une al cliente a una sala existente mediante su código de 4 caracteres.
    Join {
        /// Código de 4 caracteres de la sala.
        room_code: String,
    },
    /// Retransmite `data` a todos los demás participantes de la sala actual.
    Relay {
        /// Payload arbitrario a retransmitir.
        data: Value,
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
        /// Código de 4 caracteres asignado a la sala.
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

/// Inicia el servidor Relay sobre un `TcpListener` ya enlazado.
pub async fn run_relay_server(listener: TcpListener) -> std::io::Result<()> {
    let manager = Arc::new(Mutex::new(RoomManager::new()));
    let next_conn_id = Arc::new(AtomicU64::new(1));

    loop {
        let (stream, _peer_addr) = listener.accept().await?;
        let conn_id = next_conn_id.fetch_add(1, Ordering::Relaxed);
        let manager_clone = Arc::clone(&manager);

        tokio::spawn(async move {
            handle_connection(stream, conn_id, manager_clone).await;
        });
    }
}

async fn handle_connection(
    stream: TcpStream,
    conn_id: ConnectionId,
    manager: Arc<Mutex<RoomManager>>,
) {
    let ws_stream = match tokio_tungstenite::accept_async(stream).await {
        Ok(ws) => ws,
        Err(_) => return,
    };

    let (mut ws_sink, mut ws_source) = ws_stream.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<String>();

    // Tarea encargada de volcar mensajes salientes hacia el socket WebSocket
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
                process_text_message(&text, conn_id, &tx, &manager).await;
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

    // Al desconectarse, retiramos al participante y notificamos a los demás en la sala
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
    let bind_addr: SocketAddr = std::env::var("OPEN_TABLE_RELAY_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:8080".to_string())
        .parse()
        .expect("OPEN_TABLE_RELAY_ADDR debe ser un SocketAddr válido (ej. 0.0.0.0:8080)");

    let listener = TcpListener::bind(bind_addr).await?;
    println!("open_table_relay listening on ws://{bind_addr}");
    run_relay_server(listener).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio_tungstenite::connect_async;

    #[tokio::test]
    async fn test_websocket_relay_end_to_end() {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let server_handle = tokio::spawn(async move {
            let _ = run_relay_server(listener).await;
        });

        let url = format!("ws://{addr}");
        let (mut ws_host, _) = connect_async(&url).await.unwrap();
        let (mut ws_guest, _) = connect_async(&url).await.unwrap();

        // 1. Host crea sala: {"op": "create"} -> {"op": "created", "room_code": "XXXX"}
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

        // El host recibe notificación peer_joined
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
    }
}
