//! Servidor HTTP ligero en el puerto 8081 para consultar rankings ELO y métricas Prometheus.
//!
//! Endpoints soportados:
//! - `GET /rankings/:game_id` -> JSON con el top-50 de jugadores por ELO para ese juego.
//! - `GET /player/:player_id` -> JSON con todos los ratings del jugador por juego.
//! - `GET /metrics` -> Métricas operacionales en formato Prometheus (`text/plain; version=0.0.4`).

use crate::elo::EloStore;
use crate::metrics::global_metrics;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;

/// Ejecuta el servidor HTTP de consulta de rankings ELO sobre el `TcpListener` indicado.
pub async fn run_http_api_server(
    listener: TcpListener,
    elo_store: Arc<Mutex<EloStore>>,
) -> std::io::Result<()> {
    loop {
        let (stream, _) = listener.accept().await?;
        let store_clone = Arc::clone(&elo_store);
        tokio::spawn(async move {
            let _ = handle_http_connection(stream, store_clone).await;
        });
    }
}

async fn handle_http_connection(
    mut stream: TcpStream,
    elo_store: Arc<Mutex<EloStore>>,
) -> std::io::Result<()> {
    let mut buf = [0u8; 4096];
    let n = stream.read(&mut buf).await?;
    if n == 0 {
        return Ok(());
    }

    let request_str = String::from_utf8_lossy(&buf[..n]);
    let first_line = request_str.lines().next().unwrap_or("");
    let mut parts = first_line.split_whitespace();
    let method = parts.next().unwrap_or("");
    let raw_path = parts.next().unwrap_or("");
    let path = raw_path.split('?').next().unwrap_or("");

    let mut content_type = "application/json";
    let (status_line, body_payload) = if method == "GET" {
        if path == "/metrics" {
            content_type = "text/plain; version=0.0.4; charset=utf-8";
            ("HTTP/1.1 200 OK", global_metrics().render_prometheus_text())
        } else if let Some(game_id) = path.strip_prefix("/rankings/") {
            let clean_game = game_id.trim_matches('/');
            let store = elo_store.lock().await;
            let rankings = store.get_rankings(clean_game, 50);
            let body = serde_json::to_string(&rankings).unwrap_or_else(|_| "[]".to_string());
            ("HTTP/1.1 200 OK", body)
        } else if let Some(player_id) = path.strip_prefix("/player/") {
            let clean_player = player_id.trim_matches('/');
            let store = elo_store.lock().await;
            let ratings = store.get_player_ratings(clean_player);
            let body = serde_json::to_string(&ratings).unwrap_or_else(|_| "[]".to_string());
            ("HTTP/1.1 200 OK", body)
        } else {
            (
                "HTTP/1.1 404 Not Found",
                r#"{"error":"not found"}"#.to_string(),
            )
        }
    } else {
        (
            "HTTP/1.1 405 Method Not Allowed",
            r#"{"error":"method not allowed"}"#.to_string(),
        )
    };

    let response = format!(
        "{status_line}\r\nContent-Type: {content_type}\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body_payload}",
        body_payload.len()
    );
    stream.write_all(response.as_bytes()).await?;
    stream.flush().await
}
