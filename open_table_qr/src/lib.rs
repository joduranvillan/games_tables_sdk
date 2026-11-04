// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Código QR de invitación a una sala.
//!
//! Una aclaración de diseño importante: Nearby Connections (Android) y
//! MultipeerConnectivity (iOS) YA hacen descubrimiento de dispositivos
//! cercanos solos - no hace falta ningún código para que un teléfono
//! "encuentre" a otro. El QR acá resuelve un problema distinto: cuando
//! hay más de una partida siendo anunciada cerca (dos mesas jugando en el
//! mismo bar, por ejemplo), ¿a cuál se une el jugador? Y además, que un
//! jugador no técnico no tenga que tipear nada.
//!
//! Por eso el QR NO codifica direcciones de red, MACs de Bluetooth ni
//! IDs de conexión de Nearby Connections/Multipeer - esos son manejados
//! por esas APIs y son efímeros. El QR codifica solo un `JoinPayload`
//! chico: un `join_code` legible (también se muestra como texto, por si
//! alguien no puede escanear) que el cliente usa para filtrar, entre los
//! dispositivos que ya descubrió por Bluetooth/Wi-Fi, cuál es el correcto.

use qrcode::render::svg;
use qrcode::QrCode;
use serde::{Deserialize, Serialize};
use thiserror::Error;

use open_table_core::ids::SessionId;
use open_table_core::random::RandomService;

const CODE_ALPHABET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sin 0/O/1/I: se confunden a simple vista
const CODE_LENGTH: usize = 6;

#[derive(Debug, Error)]
pub enum QrError {
    #[error("no se pudo serializar el payload de invitación: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("no se pudo generar el código QR: {0}")]
    Encoding(#[from] qrcode::types::QrError),
}

/// Lo que efectivamente viaja adentro del QR (y también se puede mostrar
/// como texto plano para quien no pueda escanear).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct JoinPayload {
    pub session_id: SessionId,
    pub join_code: String,
    pub host_name: String,
    pub game_type: String,
}

/// Payload extendido para partidas en red local (LAN / Hotspot offline) que
/// incluye dirección IP y puerto TCP además de los metadatos de la sala.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LanJoinPayload {
    pub session_id: SessionId,
    pub join_code: String,
    pub host_name: String,
    pub game_type: String,
    pub ip: String,
    pub port: u16,
}

/// Genera un código corto, legible, para mostrar junto al QR. Usa
/// `RandomService` (el mismo que ya usa el motor para dados/barajado) en
/// vez de una fuente de aleatoriedad nueva, para no introducir una
/// segunda noción de "azar" en el SDK.
pub fn generate_join_code(rng: &mut RandomService) -> String {
    (0..CODE_LENGTH)
        .map(|_| {
            let idx = rng.range(0, CODE_ALPHABET.len() as u32 - 1) as usize;
            CODE_ALPHABET[idx] as char
        })
        .collect()
}

/// Genera el QR como un string SVG, listo para que el bridge de Godot lo
/// cargue como textura (Godot puede rasterizar SVG directamente, o este
/// string se puede convertir a PNG del lado de Godot si hace falta).
pub fn generate_join_qr_svg(payload: &JoinPayload) -> Result<String, QrError> {
    let json = serde_json::to_string(payload)?;
    let code = QrCode::new(json.as_bytes())?;

    let mut svg = code
        .render::<svg::Color>()
        .min_dimensions(240, 240)
        .quiet_zone(true)
        .build();

    svg.push_str(&format!("<!--OPENTABLE_QR_JSON:{json}-->"));
    Ok(svg)
}

/// Genera un código QR SVG con los datos completos de conexión LAN offline
/// (`ip`, `port`, `game_type`, `join_code`, `host_name`).
pub fn generate_lan_join_qr_svg(payload: &LanJoinPayload) -> Result<String, QrError> {
    let json = serde_json::to_string(payload)?;
    let code = QrCode::new(json.as_bytes())?;

    let mut svg = code
        .render::<svg::Color>()
        .min_dimensions(240, 240)
        .quiet_zone(true)
        .build();

    svg.push_str(&format!("<!--OPENTABLE_QR_JSON:{json}-->"));
    Ok(svg)
}

/// El lado del cliente: decodifica lo que salió de escanear el QR (o de
/// tipear el `join_code` a mano como fallback).
pub fn parse_join_payload(json: &str) -> Result<JoinPayload, QrError> {
    Ok(serde_json::from_str(json)?)
}

/// Decodifica un payload LAN completo desde JSON.
pub fn parse_lan_join_payload(json: &str) -> Result<LanJoinPayload, QrError> {
    Ok(serde_json::from_str(json)?)
}

/// Extrae el JSON de invitación desde un archivo/string SVG generado por
/// `open_table_qr` o desde un texto JSON directo.
pub fn extract_qr_payload_json(input: &str) -> Option<String> {
    let trimmed = input.trim();
    if let Some(start_idx) = trimmed.find("<!--OPENTABLE_QR_JSON:") {
        let rest = &trimmed[start_idx + "<!--OPENTABLE_QR_JSON:".len()..];
        if let Some(end_idx) = rest.find("-->") {
            return Some(rest[..end_idx].trim().to_string());
        }
    }
    if trimmed.starts_with('{') && trimmed.ends_with('}') {
        return Some(trimmed.to_string());
    }
    None
}
