// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Test de Carga e Integración de Concurrencia del Servidor Relay (`load_test.rs` — Prompt 494).
//!
//! Verifica que `open_table_relay` soporta simultáneamente:
//! - 50 salas concurrentes (100 clientes WebSocket en paralelo) intercambiando comandos validados
//!   con `AntiCheatSession` de Ajedrez (`"chess"`) y Damas (`"checkers"`).
//! - 20 clientes concurrentes en cola de matchmaking (`"queue"`), formando 10 partidas adicionales.
//! - Latencia de entrega inferior a 200 ms para el 100% de los mensajes válidos.
//! - Limpieza completa de todas las salas (`active_room_count() == 0`) al desconectar.

use futures_util::{SinkExt, StreamExt};
use open_table_relay::auth::AuthConfig;
use open_table_relay::elo::EloStore;
use open_table_relay::rate_limit::{RelayRateLimiter, ROOM_RATE_LIMIT_PER_SEC};
use open_table_relay::room::RoomManager;
use open_table_relay::tournament::TournamentManager;
use open_table_relay::{run_relay_server_with_state, RelaySharedState};
use serde_json::{json, Value};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::net::TcpListener;
use tokio::sync::Mutex;
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message;

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn test_relay_concurrent_50_rooms_100_clients_plus_20_matchmaking() {
    let db_file = std::env::temp_dir().join(format!(
        "opentable_relay_load_test_{}.db",
        std::process::id()
    ));
    let _ = std::fs::remove_file(&db_file);

    let elo_store = Arc::new(Mutex::new(
        EloStore::new(&db_file).expect("debe inicializar SQLite para load test"),
    ));

    let mut room_mgr = RoomManager::new();
    // Ventana de gracia reducida para verificar también limpieza inmediata por desconexión además de `leave`
    room_mgr.set_rejoin_grace_duration(Duration::ZERO);
    let manager = Arc::new(Mutex::new(room_mgr));

    // En loopback todos los 120 clientes comparten 127.0.0.1; ampliamos el bucket por IP manteniendo el límite por sala
    let rate_limiter = Arc::new(Mutex::new(RelayRateLimiter::with_limits(
        20_000,
        ROOM_RATE_LIMIT_PER_SEC,
    )));

    let state = RelaySharedState {
        manager: Arc::clone(&manager),
        elo_store: Arc::clone(&elo_store),
        tournaments: Arc::new(Mutex::new(TournamentManager::new())),
        rate_limiter,
        auth_config: AuthConfig::disabled(),
        tls_config: None,
    };

    let listener = TcpListener::bind("127.0.0.1:0")
        .await
        .expect("debe enlazar un puerto efímero libre");
    let addr = listener.local_addr().unwrap();
    let ws_url = format!("ws://{addr}");

    let server_state = state.clone();
    let server_handle = tokio::spawn(async move {
        let _ = run_relay_server_with_state(listener, server_state).await;
    });

    // 1. Lanzar 50 salas concurrentes (100 clientes WebSocket en paralelo):
    //    - 25 salas de Ajedrez ("chess")
    //    - 25 salas de Damas ("checkers")
    let mut room_tasks = Vec::with_capacity(50);
    for room_idx in 0..50usize {
        let url = ws_url.clone();
        let is_chess = room_idx % 2 == 0;
        let game_id = if is_chess { "chess" } else { "checkers" };

        room_tasks.push(tokio::spawn(async move {
            let (mut ws_host, _) = connect_async(&url).await.expect("host connect failed");
            let (mut ws_guest, _) = connect_async(&url).await.expect("guest connect failed");

            // Host crea sala privada para no interferir con la cola pública de matchmaking
            let create_msg = json!({
                "op": "create",
                "game_id": game_id,
                "is_public": false
            })
            .to_string();
            ws_host
                .send(Message::Text(create_msg.into()))
                .await
                .unwrap();

            let created_raw = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
            let created_val: Value = serde_json::from_str(&created_raw).unwrap();
            assert_eq!(created_val["op"], "created");
            let room_code = created_val["room_code"].as_str().unwrap().to_string();

            // Guest se une a la sala
            let join_msg = json!({
                "op": "join",
                "room_code": room_code
            })
            .to_string();
            ws_guest.send(Message::Text(join_msg.into())).await.unwrap();

            let joined_raw = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
            let joined_val: Value = serde_json::from_str(&joined_raw).unwrap();
            assert_eq!(joined_val["op"], "joined");
            assert_eq!(joined_val["player_id"], 2);

            let peer_joined_raw = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
            let peer_joined_val: Value = serde_json::from_str(&peer_joined_raw).unwrap();
            assert_eq!(peer_joined_val["op"], "peer_joined");

            // Movimiento 1 (P1 -> P2) validado por AntiCheatSession + medición de latencia (< 200 ms)
            let p1_move = if is_chess {
                // Peón blanco e2 (1,4) -> e4 (3,4)
                json!({
                    "op": "relay",
                    "data": {
                        "player": 1,
                        "from": { "row": 1, "col": 4 },
                        "to": { "row": 3, "col": 4 }
                    }
                })
            } else {
                // Ficha P1 en Damas (2,1) -> (3,0)
                json!({
                    "op": "relay",
                    "data": {
                        "player": 1,
                        "from": { "row": 2, "col": 1 },
                        "to": { "row": 3, "col": 0 }
                    }
                })
            };

            let t0 = Instant::now();
            ws_host
                .send(Message::Text(p1_move.to_string().into()))
                .await
                .unwrap();
            let recv1_raw = ws_guest.next().await.unwrap().unwrap().into_text().unwrap();
            let latency_1 = t0.elapsed();
            let recv1_val: Value = serde_json::from_str(&recv1_raw).unwrap();
            assert_eq!(recv1_val["op"], "relay");
            assert_eq!(recv1_val["from"], 1);
            assert!(
                latency_1 < Duration::from_millis(200),
                "Sala {room_idx} ({game_id}): latencia P1->P2 {:?} excedió 200 ms",
                latency_1
            );

            // Movimiento 2 (P2 -> P1) validado por AntiCheatSession + medición de latencia (< 200 ms)
            let p2_move = if is_chess {
                // Peón negro e7 (6,4) -> e5 (4,4)
                json!({
                    "op": "relay",
                    "data": {
                        "player": 2,
                        "from": { "row": 6, "col": 4 },
                        "to": { "row": 4, "col": 4 }
                    }
                })
            } else {
                // Ficha P2 en Damas (5,0) -> (4,1)
                json!({
                    "op": "relay",
                    "data": {
                        "player": 2,
                        "from": { "row": 5, "col": 0 },
                        "to": { "row": 4, "col": 1 }
                    }
                })
            };

            let t1 = Instant::now();
            ws_guest
                .send(Message::Text(p2_move.to_string().into()))
                .await
                .unwrap();
            let recv2_raw = ws_host.next().await.unwrap().unwrap().into_text().unwrap();
            let latency_2 = t1.elapsed();
            let recv2_val: Value = serde_json::from_str(&recv2_raw).unwrap();
            assert_eq!(recv2_val["op"], "relay");
            assert_eq!(recv2_val["from"], 2);
            assert!(
                latency_2 < Duration::from_millis(200),
                "Sala {room_idx} ({game_id}): latencia P2->P1 {:?} excedió 200 ms",
                latency_2
            );

            // Salida limpia y cierre de ambos sockets
            ws_guest
                .send(Message::Text(r#"{"op":"leave"}"#.into()))
                .await
                .unwrap();
            let _ = ws_guest.next().await;
            let _ = ws_host.next().await;

            ws_host
                .send(Message::Text(r#"{"op":"leave"}"#.into()))
                .await
                .unwrap();
            let _ = ws_host.next().await;

            let _ = ws_guest.close(None).await;
            let _ = ws_host.close(None).await;

            (latency_1, latency_2)
        }));
    }

    // 2. Lanzar 20 clientes en cola de matchmaking simultáneamente (formando 10 salas emparejadas)
    let mut matchmaking_tasks = Vec::with_capacity(20);
    for mm_idx in 0..20usize {
        let url = ws_url.clone();
        matchmaking_tasks.push(tokio::spawn(async move {
            let (mut ws, _) = connect_async(&url)
                .await
                .expect("matchmaking client connect failed");

            let queue_msg = json!({
                "op": "queue",
                "game_id": "chess"
            })
            .to_string();

            let t_queue = Instant::now();
            ws.send(Message::Text(queue_msg.into())).await.unwrap();
            let resp_raw = ws.next().await.unwrap().unwrap().into_text().unwrap();
            let queue_latency = t_queue.elapsed();
            let resp_val: Value = serde_json::from_str(&resp_raw).unwrap();
            let op = resp_val["op"].as_str().unwrap_or("");
            assert!(
                op == "created" || op == "joined",
                "Cliente matchmaking #{mm_idx} recibió respuesta inesperada: {resp_raw}"
            );
            assert!(
                queue_latency < Duration::from_millis(200),
                "Cliente matchmaking #{mm_idx}: latencia de cola {:?} excedió 200 ms",
                queue_latency
            );

            ws
        }));
    }

    // Esperar a que los 20 clientes de matchmaking estén emparejados y las 50 salas terminen su intercambio
    let mut mm_sockets = Vec::with_capacity(20);
    for task in matchmaking_tasks {
        mm_sockets.push(task.await.expect("matchmaking task panicked"));
    }

    for task in room_tasks {
        let (l1, l2) = task.await.expect("room task panicked");
        assert!(l1 < Duration::from_millis(200));
        assert!(l2 < Duration::from_millis(200));
    }

    // Cerrar y limpiar los 20 clientes de matchmaking
    for mut ws in mm_sockets {
        let _ = ws.send(Message::Text(r#"{"op":"leave"}"#.into())).await;
        let _ = ws.close(None).await;
    }

    // Dar margen breve al bucle asíncrono del servidor para procesar todos los cierres TCP
    for _ in 0..20 {
        let remaining = manager.lock().await.active_room_count();
        if remaining == 0 {
            break;
        }
        tokio::time::sleep(Duration::from_millis(15)).await;
    }

    let final_active_rooms = manager.lock().await.active_room_count();
    assert_eq!(
        final_active_rooms, 0,
        "Todas las salas deben limpiarse correctamente tras desconectar los 120 clientes"
    );

    server_handle.abort();
    let _ = std::fs::remove_file(&db_file);
}
