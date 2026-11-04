// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_core::ids::PlayerId;
use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: &str = "1.0";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HandshakeRequest {
    Join {
        player_name: String,
        protocol_version: String,
        route: Option<String>,
    },
    Reconnect {
        player_id: PlayerId,
        reconnect_token: String,
        protocol_version: String,
        route: Option<String>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HandshakeResponse {
    Welcome {
        player_id: PlayerId,
        reconnect_token: String,
        protocol_version: String,
    },
    UnsupportedProtocolVersion {
        expected: String,
        got: String,
    },
    Rejected {
        reason: String,
    },
}
