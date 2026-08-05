//! Protocolo de handshake, intercambiado ANTES de que una conexión empiece
//! a mandar `CommandEnvelope`s normales.
//!
//! El problema que resuelve: cuando un cliente se cae y vuelve a
//! conectarse, ¿cómo sabe el host que es el mismo jugador de antes y no
//! alguien pretendiendo serlo? Un jugador que simplemente "dice" su
//! `PlayerId` al reconectar tiene el mismo problema que ya resolvimos
//! para los comandos (`issuer` vs `sender`): es trivial de falsificar.
//!
//! La solución acá es la misma idea aplicada a la conexión en vez de al
//! comando: el host entrega un `reconnect_token` al aceptar un `Join`, y
//! exige ese token de vuelta en un `Reconnect`. El cliente lo guarda
//! localmente (fuera del alcance de este crate — en Godot sería
//! `user://`, por ejemplo).

use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;

pub const PROTOCOL_VERSION: &str = "1.0";

fn default_protocol_version() -> String {
    PROTOCOL_VERSION.to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HandshakeRequest {
    /// Un jugador nuevo entrando a la sala por primera vez.
    Join {
        player_name: String,
        #[serde(default = "default_protocol_version")]
        protocol_version: String,
        #[serde(default)]
        route: Option<String>,
    },
    /// Un jugador que ya estaba, probando que es quien dice ser.
    Reconnect {
        player_id: PlayerId,
        reconnect_token: String,
        #[serde(default = "default_protocol_version")]
        protocol_version: String,
        #[serde(default)]
        route: Option<String>,
    },
}

impl HandshakeRequest {
    pub fn protocol_version(&self) -> &str {
        match self {
            HandshakeRequest::Join { protocol_version, .. } => protocol_version,
            HandshakeRequest::Reconnect { protocol_version, .. } => protocol_version,
        }
    }

    pub fn route(&self) -> Option<&str> {
        match self {
            HandshakeRequest::Join { route, .. } => route.as_deref(),
            HandshakeRequest::Reconnect { route, .. } => route.as_deref(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HandshakeResponse {
    Welcome {
        player_id: PlayerId,
        reconnect_token: String,
        #[serde(default = "default_protocol_version")]
        protocol_version: String,
    },
    Rejected {
        reason: String,
    },
    UnsupportedProtocolVersion {
        expected: String,
        got: String,
    },
}
