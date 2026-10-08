//! Servidor HTTP ligero en el puerto 8081 para consultar rankings ELO, métricas Prometheus y autenticación de invitados.
//!
//! Endpoints soportados:
//! - `POST /auth/guest` -> Recibe `{"device_id": "<uuid_persistente>"}` y devuelve `{"token": "<jwt>", "player_id": "guest_<hash8>", "expires_at": ...}`.
//! - `GET /rankings/:game_id` -> JSON con el top-50 de jugadores por ELO para ese juego.
//! - `GET /player/:player_id` -> JSON con todos los ratings del jugador por juego.
//! - `GET /metrics` -> Métricas operacionales en formato Prometheus (`text/plain; version=0.0.4`).

use crate::auth::{AuthConfig, GuestAuthRequest};
use crate::elo::EloStore;
use crate::metrics::global_metrics;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;

/// Ejecuta el servidor HTTP de consulta de rankings ELO y emisión de JWT sobre el `TcpListener` indicado.
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
    let mut raw = Vec::with_capacity(4096);
    let mut chunk = [0u8; 4096];
    let n = stream.read(&mut chunk).await?;
    if n == 0 {
        return Ok(());
    }
    raw.extend_from_slice(&chunk[..n]);

    // Si es una petición POST con Content-Length y el cuerpo viene en un segundo paquete TCP, completar lectura.
    if let Some((headers_end, content_len)) = parse_headers_and_content_length(&raw) {
        while raw.len() < headers_end + content_len && raw.len() < 65_536 {
            let m = stream.read(&mut chunk).await?;
            if m == 0 {
                break;
            }
            raw.extend_from_slice(&chunk[..m]);
        }
    }

    let request_str = String::from_utf8_lossy(&raw);
    let first_line = request_str.lines().next().unwrap_or("");
    let mut parts = first_line.split_whitespace();
    let method = parts.next().unwrap_or("");
    let raw_path = parts.next().unwrap_or("");
    let path = raw_path.split('?').next().unwrap_or("");

    let body_str = extract_http_body(&request_str);

    let mut content_type = "application/json";
    let (status_line, body_payload) = if method == "OPTIONS" {
        ("HTTP/1.1 204 No Content", String::new())
    } else if method == "POST" && path == "/auth/guest" {
        match serde_json::from_str::<GuestAuthRequest>(body_str) {
            Ok(req) if !req.device_id.trim().is_empty() => {
                let auth_cfg = AuthConfig::from_env();
                let resp = auth_cfg.issue_guest_token(req.device_id.trim());
                let body = serde_json::to_string(&resp).unwrap_or_else(|_| "{}".to_string());
                ("HTTP/1.1 200 OK", body)
            }
            _ => (
                "HTTP/1.1 400 Bad Request",
                r#"{"error":"device_id is required"}"#.to_string(),
            ),
        }
    } else if method == "GET" {
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
        "{status_line}\r\nContent-Type: {content_type}\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, Authorization\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body_payload}",
        body_payload.len()
    );
    stream.write_all(response.as_bytes()).await?;
    stream.flush().await
}

fn extract_http_body(request: &str) -> &str {
    if let Some(idx) = request.find("\r\n\r\n") {
        &request[idx + 4..]
    } else if let Some(idx) = request.find("\n\n") {
        &request[idx + 2..]
    } else {
        ""
    }
}

fn parse_headers_and_content_length(raw: &[u8]) -> Option<(usize, usize)> {
    let text = std::str::from_utf8(raw).ok()?;
    let (headers_part, headers_end) = if let Some(idx) = text.find("\r\n\r\n") {
        (&text[..idx], idx + 4)
    } else if let Some(idx) = text.find("\n\n") {
        (&text[..idx], idx + 2)
    } else {
        return None;
    };

    for line in headers_part.lines() {
        if let Some((name, val)) = line.split_once(':') {
            if name.trim().eq_ignore_ascii_case("content-length") {
                if let Ok(len) = val.trim().parse::<usize>() {
                    return Some((headers_end, len));
                }
            }
        }
    }
    Some((headers_end, 0))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::{GuestAuthResponse, GUEST_TOKEN_TTL_SECS};

    #[tokio::test]
    async fn test_guest_auth_http_post_endpoint() {
        let db_file = std::env::temp_dir().join(format!(
            "opentable_api_guest_auth_{}.db",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&db_file);
        let elo_store = Arc::new(Mutex::new(EloStore::new(&db_file).unwrap()));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        let handle = tokio::spawn(async move {
            let _ = run_http_api_server(listener, elo_store).await;
        });

        let payload = r#"{"device_id":"550e8400-e29b-41d4-a716-446655440000"}"#;
        let http_req = format!(
            "POST /auth/guest HTTP/1.1\r\nHost: {addr}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{payload}",
            payload.len()
        );

        let mut client = TcpStream::connect(addr).await.unwrap();
        client.write_all(http_req.as_bytes()).await.unwrap();
        let mut resp_bytes = Vec::new();
        client.read_to_end(&mut resp_bytes).await.unwrap();
        let resp_str = String::from_utf8_lossy(&resp_bytes);

        assert!(resp_str.starts_with("HTTP/1.1 200 OK"));
        let body = extract_http_body(&resp_str);
        let parsed: GuestAuthResponse = serde_json::from_str(body).unwrap();

        assert!(parsed.player_id.starts_with("guest_"));
        assert_eq!(parsed.player_id.len(), 14);
        assert!(!parsed.token.is_empty());
        assert!(
            parsed.expires_at >= crate::auth::current_unix_timestamp() + GUEST_TOKEN_TTL_SECS - 10
        );

        let verified = AuthConfig::from_env().verify_token(&parsed.token).unwrap();
        assert_eq!(verified.sub, parsed.player_id);
        assert_eq!(verified.exp, parsed.expires_at);

        handle.abort();
        let _ = std::fs::remove_file(&db_file);
    }
}
