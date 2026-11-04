// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

#![no_main]

use libfuzzer_sys::fuzz_target;
use crisis_game::{new_crisis_session, DeclareAttackCommand};
use open_table_core::ids::{PlayerId, SessionId};

fuzz_target!(|data: &[u8]| {
    if let Ok(cmd) = serde_json::from_slice::<DeclareAttackCommand>(data) {
        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        if let Ok(mut session) = new_crisis_session(SessionId(1), 12345, &[p1, p2]) {
            let issuer = cmd.player;
            let _ = session.process_command(issuer, Box::new(cmd));
        }
    }
});
