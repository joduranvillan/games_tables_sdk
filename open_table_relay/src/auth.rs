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
use sha2::Sha256;
use std::time::{SystemTime, UNIX_EPOCH};

type HmacSha256 = Hmac<Sha256>;

/// Tiempo máximo permitido para recibir el primer mensaje `{"op": "auth"}` cuando `JWT_SECRET` está activo.
pub const AUTH_HANDSHAKE_TIMEOUT_SECS: u64 = 5;

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
        let Some(secret) = self.jwt_secret.as_deref() else {
            return Ok(JwtClaims {
                sub: "anonymous".to_string(),
                exp: u64::MAX,
            });
        };
        verify_jwt_hs256(token, secret, current_unix_timestamp())
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
}
