//! Validación y emisión de tokens JWT (`HS256`) para el servidor Relay.
//!
//! Lee `JWT_SECRET` desde las variables de entorno:
//! - Si no está presente, la autenticación queda desactivada (modo desarrollo local).
//! - Si está presente, el cliente debe enviar `{"op": "auth", "token": "<jwt>"}` en los primeros
//!   5 segundos tras conectar.
//! - Valida estrictamente la firma `HMAC-SHA256` y el campo `exp`. Tokens expirados son
//!   rechazados con `{"op": "auth_error", "reason": "expired"}`.

use hmac::{Hmac, KeyInit, Mac};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::time::{SystemTime, UNIX_EPOCH};

type HmacSha256 = Hmac<Sha256>;

/// Tiempo máximo permitido para recibir el primer mensaje `{"op": "auth"}` cuando `JWT_SECRET` está activo.
pub const AUTH_HANDSHAKE_TIMEOUT_SECS: u64 = 5;

/// Tiempo de vida de los tokens JWT de invitado emitidos por `POST /auth/guest` (7 días en segundos).
pub const GUEST_TOKEN_TTL_SECS: u64 = 7 * 24 * 60 * 60;

/// Secreto de desarrollo utilizado para firmar tokens locales cuando `JWT_SECRET` no está configurado.
pub const DEV_DEFAULT_JWT_SECRET: &str = "open_table_dev_local_secret";

/// Solicitud JSON recibida en `POST /auth/guest`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct GuestAuthRequest {
    /// Identificador único persistente (UUID v4) del dispositivo cliente.
    pub device_id: String,
}

/// Respuesta JSON emitida por `POST /auth/guest`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct GuestAuthResponse {
    /// Token JWT firmado con `HS256`.
    pub token: String,
    /// Identificador canónico de invitado (`guest_<hash8>`).
    pub player_id: String,
    /// Timestamp UNIX (en segundos) de expiración del token (`now + 7 días`).
    pub expires_at: u64,
}

/// Claims mínimos requeridos en el token JWT del cliente.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct JwtClaims {
    /// Identificador canónico del jugador (`sub`).
    pub sub: String,
    /// Timestamp UNIX (en segundos) de expiración del token (`exp`).
    pub exp: u64,
}

/// Errores posibles durante la validación de un JWT.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthError {
    /// El token ha expirado (`exp <= now`).
    Expired,
    /// La firma HMAC-SHA256 no coincide con `JWT_SECRET`.
    InvalidSignature,
    /// El formato del JWT o su cabecera/payload no es válido.
    MalformedToken,
}

impl AuthError {
    /// Código corto de razón para el mensaje `{"op": "auth_error", "reason": "..."}`.
    pub fn reason(&self) -> &'static str {
        match self {
            Self::Expired => "expired",
            Self::InvalidSignature => "invalid_signature",
            Self::MalformedToken => "malformed_token",
        }
    }
}

/// Configuración de autenticación del servidor Relay.
#[derive(Debug, Clone, Default)]
pub struct AuthConfig {
    /// Secreto compartido `HS256` si la autenticación está habilitada.
    pub jwt_secret: Option<String>,
}

impl AuthConfig {
    /// Construye `AuthConfig` leyendo la variable de entorno `JWT_SECRET`.
    pub fn from_env() -> Self {
        let secret = std::env::var("JWT_SECRET")
            .ok()
            .filter(|s| !s.trim().is_empty());
        Self { jwt_secret: secret }
    }

    /// Crea una configuración con secreto explícito.
    pub fn with_secret(secret: impl Into<String>) -> Self {
        Self {
            jwt_secret: Some(secret.into()),
        }
    }

    /// Indica si el servidor requiere autenticación JWT.
    pub fn is_enabled(&self) -> bool {
        self.jwt_secret.is_some()
    }

    /// Verifica un token JWT contra el secreto configurado usando el reloj actual del sistema.
    pub fn verify_token(&self, token: &str) -> Result<JwtClaims, AuthError> {
        let now = current_unix_timestamp();
        let Some(secret) = self.jwt_secret.as_deref() else {
            return match verify_jwt_hs256(token, DEV_DEFAULT_JWT_SECRET, now) {
                Ok(claims) => Ok(claims),
                Err(AuthError::Expired) => Err(AuthError::Expired),
                Err(_) => Ok(JwtClaims {
                    sub: "anonymous".to_string(),
                    exp: u64::MAX,
                }),
            };
        };
        verify_jwt_hs256(token, secret, now)
    }

    /// Emite un token JWT de invitado válido por 7 días (`GUEST_TOKEN_TTL_SECS`) a partir de `device_id`.
    ///
    /// Si `JWT_SECRET` no está configurado en el servidor, firma un token de desarrollo válido en modo local.
    pub fn issue_guest_token(&self, device_id: &str) -> GuestAuthResponse {
        self.issue_guest_token_at(device_id, current_unix_timestamp())
    }

    /// Emite un token JWT de invitado válido por 7 días a partir del timestamp `now_unix_secs`.
    pub fn issue_guest_token_at(&self, device_id: &str, now_unix_secs: u64) -> GuestAuthResponse {
        issue_guest_token_with_secret(device_id, self.jwt_secret.as_deref(), now_unix_secs)
    }
}

/// Deriva un identificador canónico `guest_<hash8>` determinista a partir del `device_id`.
pub fn derive_guest_player_id(device_id: &str) -> String {
    let clean = device_id.trim();
    let input = if clean.is_empty() { "anonymous" } else { clean };
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    let digest = hasher.finalize();
    format!(
        "guest_{:02x}{:02x}{:02x}{:02x}",
        digest[0], digest[1], digest[2], digest[3]
    )
}

/// Emite una respuesta `GuestAuthResponse` con un JWT firmado con `HS256` y expiración de 7 días.
///
/// Si `secret` es `None` o vacío, utiliza `DEV_DEFAULT_JWT_SECRET` para producir un token de desarrollo válido.
pub fn issue_guest_token_with_secret(
    device_id: &str,
    secret: Option<&str>,
    now_unix_secs: u64,
) -> GuestAuthResponse {
    let player_id = derive_guest_player_id(device_id);
    let expires_at = now_unix_secs.saturating_add(GUEST_TOKEN_TTL_SECS);
    let signing_secret = secret
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(DEV_DEFAULT_JWT_SECRET);
    let claims = JwtClaims {
        sub: player_id.clone(),
        exp: expires_at,
    };
    let token = encode_jwt_hs256(&claims, signing_secret);
    GuestAuthResponse {
        token,
        player_id,
        expires_at,
    }
}

/// Devuelve el timestamp UNIX actual en segundos.
pub fn current_unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Genera un token JWT firmado con `HS256` (`HMAC-SHA256`).
pub fn encode_jwt_hs256(claims: &JwtClaims, secret: &str) -> String {
    let header_json = r#"{"alg":"HS256","typ":"JWT"}"#;
    let payload_json = serde_json::to_string(claims).unwrap_or_else(|_| "{}".to_string());

    let header_b64 = base64url_encode(header_json.as_bytes());
    let payload_b64 = base64url_encode(payload_json.as_bytes());
    let signing_input = format!("{header_b64}.{payload_b64}");

    let sig = compute_hmac_sha256(signing_input.as_bytes(), secret.as_bytes());
    let sig_b64 = base64url_encode(&sig);
    format!("{signing_input}.{sig_b64}")
}

/// Valida un token JWT `HS256` comprobando su firma y su expiración (`exp > now_unix_secs`).
pub fn verify_jwt_hs256(
    token: &str,
    secret: &str,
    now_unix_secs: u64,
) -> Result<JwtClaims, AuthError> {
    let parts: Vec<&str> = token.trim().split('.').collect();
    if parts.len() != 3 {
        return Err(AuthError::MalformedToken);
    }

    let header_bytes = base64url_decode(parts[0]).ok_or(AuthError::MalformedToken)?;
    let header_val: serde_json::Value =
        serde_json::from_slice(&header_bytes).map_err(|_| AuthError::MalformedToken)?;
    if header_val.get("alg").and_then(|v| v.as_str()) != Some("HS256") {
        return Err(AuthError::MalformedToken);
    }

    let signing_input = format!("{}.{}", parts[0], parts[1]);
    let expected_sig = compute_hmac_sha256(signing_input.as_bytes(), secret.as_bytes());
    let provided_sig = base64url_decode(parts[2]).ok_or(AuthError::MalformedToken)?;

    if !constant_time_eq(&expected_sig, &provided_sig) {
        return Err(AuthError::InvalidSignature);
    }

    let payload_bytes = base64url_decode(parts[1]).ok_or(AuthError::MalformedToken)?;
    let claims: JwtClaims =
        serde_json::from_slice(&payload_bytes).map_err(|_| AuthError::MalformedToken)?;

    if claims.sub.trim().is_empty() {
        return Err(AuthError::MalformedToken);
    }

    if claims.exp <= now_unix_secs {
        return Err(AuthError::Expired);
    }

    Ok(claims)
}

fn compute_hmac_sha256(data: &[u8], key: &[u8]) -> Vec<u8> {
    let mut mac = HmacSha256::new_from_slice(key).expect("HMAC accepts keys of any size");
    mac.update(data);
    mac.finalize().into_bytes().to_vec()
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff = 0u8;
    for (&x, &y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

const B64_URL_TABLE: &[u8; 64] =
    b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

fn base64url_encode(input: &[u8]) -> String {
    let mut out = String::with_capacity(input.len().div_ceil(3) * 4);
    let mut i = 0;
    while i + 3 <= input.len() {
        let n = ((input[i] as u32) << 16) | ((input[i + 1] as u32) << 8) | (input[i + 2] as u32);
        out.push(B64_URL_TABLE[((n >> 18) & 0x3F) as usize] as char);
        out.push(B64_URL_TABLE[((n >> 12) & 0x3F) as usize] as char);
        out.push(B64_URL_TABLE[((n >> 6) & 0x3F) as usize] as char);
        out.push(B64_URL_TABLE[(n & 0x3F) as usize] as char);
        i += 3;
    }
    let rem = input.len() - i;
    if rem == 1 {
        let n = (input[i] as u32) << 16;
        out.push(B64_URL_TABLE[((n >> 18) & 0x3F) as usize] as char);
        out.push(B64_URL_TABLE[((n >> 12) & 0x3F) as usize] as char);
    } else if rem == 2 {
        let n = ((input[i] as u32) << 16) | ((input[i + 1] as u32) << 8);
        out.push(B64_URL_TABLE[((n >> 18) & 0x3F) as usize] as char);
        out.push(B64_URL_TABLE[((n >> 12) & 0x3F) as usize] as char);
        out.push(B64_URL_TABLE[((n >> 6) & 0x3F) as usize] as char);
    }
    out
}

fn base64url_decode(input: &str) -> Option<Vec<u8>> {
    let clean = input.trim_end_matches('=');
    let mut buf = Vec::with_capacity(clean.len() * 3 / 4);
    let mut accum = 0u32;
    let mut bits = 0u32;

    for b in clean.bytes() {
        let val = match b {
            b'A'..=b'Z' => b - b'A',
            b'a'..=b'z' => b - b'a' + 26,
            b'0'..=b'9' => b - b'0' + 52,
            b'-' | b'+' => 62,
            b'_' | b'/' => 63,
            _ => return None,
        } as u32;
        accum = (accum << 6) | val;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            buf.push(((accum >> bits) & 0xFF) as u8);
        }
    }
    Some(buf)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_auth_jwt_valid_and_canonical_sub() {
        let secret = "super_secret_test_key";
        let now = 1_700_000_000;
        let claims = JwtClaims {
            sub: "grandmaster_42".to_string(),
            exp: now + 3600,
        };
        let token = encode_jwt_hs256(&claims, secret);
        let decoded = verify_jwt_hs256(&token, secret, now).unwrap();
        assert_eq!(decoded.sub, "grandmaster_42");
        assert_eq!(decoded.exp, now + 3600);
    }

    #[test]
    fn test_auth_jwt_expired_rejected() {
        let secret = "super_secret_test_key";
        let now = 1_700_000_000;
        let claims = JwtClaims {
            sub: "player_expired".to_string(),
            exp: now - 10,
        };
        let token = encode_jwt_hs256(&claims, secret);
        let err = verify_jwt_hs256(&token, secret, now).unwrap_err();
        assert_eq!(err, AuthError::Expired);
        assert_eq!(err.reason(), "expired");
    }

    #[test]
    fn test_auth_jwt_invalid_signature_rejected() {
        let now = 1_700_000_000;
        let claims = JwtClaims {
            sub: "player_1".to_string(),
            exp: now + 600,
        };
        let token = encode_jwt_hs256(&claims, "secret_a");
        let err = verify_jwt_hs256(&token, "secret_b", now).unwrap_err();
        assert_eq!(err, AuthError::InvalidSignature);
    }

    #[test]
    fn test_guest_auth_token_generation_7_days_and_hash8() {
        let now = 1_735_084_800;
        let cfg = AuthConfig::with_secret("prod_guest_secret");
        let resp = cfg.issue_guest_token_at("550e8400-e29b-41d4-a716-446655440000", now);

        assert!(resp.player_id.starts_with("guest_"));
        assert_eq!(resp.player_id.len(), "guest_".len() + 8);
        assert_eq!(resp.expires_at, now + GUEST_TOKEN_TTL_SECS);
        assert_eq!(resp.expires_at, 1_735_689_600);

        let decoded = verify_jwt_hs256(&resp.token, "prod_guest_secret", now).unwrap();
        assert_eq!(decoded.sub, resp.player_id);
        assert_eq!(decoded.exp, resp.expires_at);
    }

    #[test]
    fn test_guest_auth_dev_fallback_when_jwt_secret_not_set() {
        let cfg = AuthConfig::default();
        assert!(!cfg.is_enabled());

        let resp = cfg.issue_guest_token("123e4567-e89b-12d3-a456-426614174000");
        assert!(resp.player_id.starts_with("guest_"));
        assert_eq!(resp.player_id.len(), 14);

        let verified = cfg.verify_token(&resp.token).unwrap();
        assert_eq!(verified.sub, resp.player_id);
        assert_eq!(verified.exp, resp.expires_at);
    }
}
