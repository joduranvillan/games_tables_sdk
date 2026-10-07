//! Configuración y carga de certificados PEM para WebSocket Secure (`wss://`).
//!
//! Lee `TLS_CERT_PATH` y `TLS_KEY_PATH` del entorno. Si no están definidas,
//! el servidor Relay arranca en modo plain WS (`ws://`) para desarrollo local.

use std::fs;
use std::io::{self, ErrorKind};
use std::path::{Path, PathBuf};

/// Configuración TLS cargada desde archivos PEM.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TlsConfig {
    /// Ruta al certificado PEM.
    pub cert_path: PathBuf,
    /// Ruta a la clave privada PEM.
    pub key_path: PathBuf,
    /// Bloques de certificados PEM validados.
    pub cert_pem_blocks: Vec<String>,
    /// Bloque de clave privada PEM validado.
    pub key_pem_block: String,
}

impl TlsConfig {
    /// Carga la configuración TLS desde las variables de entorno `TLS_CERT_PATH` y `TLS_KEY_PATH`.
    /// Devuelve `Ok(None)` si alguna de las dos variables no está definida (modo plain WS).
    pub fn from_env() -> io::Result<Option<Self>> {
        let cert_var = std::env::var("TLS_CERT_PATH").ok();
        let key_var = std::env::var("TLS_KEY_PATH").ok();

        match (cert_var, key_var) {
            (Some(cert), Some(key)) if !cert.trim().is_empty() && !key.trim().is_empty() => {
                Self::from_paths(cert, key).map(Some)
            }
            _ => Ok(None),
        }
    }

    /// Carga y valida los archivos PEM de certificado y clave privada desde disco.
    pub fn from_paths(cert_path: impl AsRef<Path>, key_path: impl AsRef<Path>) -> io::Result<Self> {
        let c_path = cert_path.as_ref().to_path_buf();
        let k_path = key_path.as_ref().to_path_buf();

        let cert_raw = fs::read_to_string(&c_path)?;
        let key_raw = fs::read_to_string(&k_path)?;

        let cert_pem_blocks = parse_pem_certificates(&cert_raw)?;
        let key_pem_block = parse_pem_private_key(&key_raw)?;

        Ok(Self {
            cert_path: c_path,
            key_path: k_path,
            cert_pem_blocks,
            key_pem_block,
        })
    }
}

/// Extrae y valida bloques `-----BEGIN CERTIFICATE-----` desde un contenido PEM.
pub fn parse_pem_certificates(pem_str: &str) -> io::Result<Vec<String>> {
    let mut certs = Vec::new();
    let begin_marker = "-----BEGIN CERTIFICATE-----";
    let end_marker = "-----END CERTIFICATE-----";

    let mut rest = pem_str;
    while let Some(start) = rest.find(begin_marker) {
        let after_start = &rest[start..];
        let Some(end_rel) = after_start.find(end_marker) else {
            return Err(io::Error::new(
                ErrorKind::InvalidData,
                "unclosed PEM certificate block",
            ));
        };
        let block = &after_start[..end_rel + end_marker.len()];
        certs.push(block.to_string());
        rest = &after_start[end_rel + end_marker.len()..];
    }

    if certs.is_empty() {
        return Err(io::Error::new(
            ErrorKind::InvalidData,
            "no PEM certificates found",
        ));
    }
    Ok(certs)
}

/// Extrae y valida un bloque de clave privada (`PRIVATE KEY` o `RSA PRIVATE KEY`) desde PEM.
pub fn parse_pem_private_key(pem_str: &str) -> io::Result<String> {
    for (begin, end) in [
        ("-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----"),
        (
            "-----BEGIN RSA PRIVATE KEY-----",
            "-----END RSA PRIVATE KEY-----",
        ),
        (
            "-----BEGIN EC PRIVATE KEY-----",
            "-----END EC PRIVATE KEY-----",
        ),
    ] {
        if let Some(start) = pem_str.find(begin) {
            let after_start = &pem_str[start..];
            if let Some(end_rel) = after_start.find(end) {
                return Ok(after_start[..end_rel + end.len()].to_string());
            }
        }
    }

    Err(io::Error::new(
        ErrorKind::InvalidData,
        "no valid PEM private key found",
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_pem_certificates_and_private_key() {
        let cert_pem = "-----BEGIN CERTIFICATE-----\nMIIB...\n-----END CERTIFICATE-----\n";
        let key_pem = "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n";

        let certs = parse_pem_certificates(cert_pem).unwrap();
        assert_eq!(certs.len(), 1);

        let key = parse_pem_private_key(key_pem).unwrap();
        assert!(key.contains("BEGIN PRIVATE KEY"));
    }
}
