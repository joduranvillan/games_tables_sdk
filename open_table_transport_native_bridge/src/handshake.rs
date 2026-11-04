// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use serde::{Deserialize, Serialize};

use open_table_core::ids::PlayerId;

/// Mismo protocolo que `open_table_transport_tcp::handshake` — a
/// propósito no se comparte el tipo entre los dos crates (por ahora es
/// más simple duplicar ~20 líneas estables que armar un tercer crate
/// solo para esto). Si el protocolo llegara a crecer, ahí sí conviene
/// extraerlo a un `open_table_handshake` común.
#[derive(Debug, Serialize, Deserialize)]
pub enum HandshakeRequest {
    Join {
        player_name: String,
    },
    Reconnect {
        player_id: PlayerId,
        reconnect_token: String,
    },
}

#[derive(Debug, Serialize, Deserialize)]
pub enum HandshakeResponse {
    Welcome {
        player_id: PlayerId,
        reconnect_token: String,
    },
    Rejected {
        reason: String,
    },
}

/// Token de reconexión con el CSPRNG del sistema — igual que en
/// `open_table_transport_tcp::host::generate_token`.
pub fn generate_token() -> String {
    let mut bytes = [0u8; 16];
    getrandom::fill(&mut bytes).expect(
        "el sistema operativo debería poder darnos bytes aleatorios; \
         si esto falla, algo está muy mal a nivel de SO",
    );
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
