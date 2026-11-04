// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Colector y exportador de métricas operacionales en formato Prometheus (`GET /metrics`).
//!
//! Métricas expuestas:
//! - `relay_connections_active` (gauge)
//! - `relay_rooms_active` (gauge)
//! - `relay_messages_total{game_id="..."}` (counter)
//! - `relay_elo_updates_total` (counter)
//! - `rate_limit_drops_total` (counter)
//! - `ip_bans_total` (counter)

use std::collections::BTreeMap;
use std::fmt::Write;
use std::sync::atomic::{AtomicI64, AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

/// Registro global de métricas operacionales del servidor Relay.
#[derive(Debug)]
pub struct RelayMetrics {
    connections_active: AtomicI64,
    rooms_active: AtomicI64,
    messages_by_game: Mutex<BTreeMap<String, u64>>,
    elo_updates_total: AtomicU64,
    rate_limit_drops_total: AtomicU64,
    ip_bans_total: AtomicU64,
}

impl Default for RelayMetrics {
    fn default() -> Self {
        Self::new()
    }
}

static GLOBAL_METRICS: OnceLock<RelayMetrics> = OnceLock::new();

/// Devuelve la instancia singleton global de [`RelayMetrics`].
pub fn global_metrics() -> &'static RelayMetrics {
    GLOBAL_METRICS.get_or_init(RelayMetrics::new)
}

impl RelayMetrics {
    /// Crea un colector de métricas inicializado en cero.
    pub fn new() -> Self {
        Self {
            connections_active: AtomicI64::new(0),
            rooms_active: AtomicI64::new(0),
            messages_by_game: Mutex::new(BTreeMap::new()),
            elo_updates_total: AtomicU64::new(0),
            rate_limit_drops_total: AtomicU64::new(0),
            ip_bans_total: AtomicU64::new(0),
        }
    }

    /// Incrementa el gauge `relay_connections_active` al abrirse una conexión.
    pub fn inc_connections_active(&self) {
        self.connections_active.fetch_add(1, Ordering::Relaxed);
    }

    /// Decrementa el gauge `relay_connections_active` al cerrarse una conexión.
    pub fn dec_connections_active(&self) {
        self.connections_active.fetch_sub(1, Ordering::Relaxed);
    }

    /// Actualiza el gauge `relay_rooms_active` con el número actual de salas activas.
    pub fn set_rooms_active(&self, count: usize) {
        self.rooms_active.store(count as i64, Ordering::Relaxed);
    }

    /// Devuelve el número actual de salas activas registradas en el gauge `relay_rooms_active`.
    pub fn rooms_active(&self) -> usize {
        self.rooms_active.load(Ordering::Relaxed).max(0) as usize
    }

    /// Incrementa el contador `relay_messages_total` etiquetado por `game_id`.
    pub fn inc_messages_total(&self, game_id: Option<&str>) {
        let label = game_id
            .filter(|s| !s.trim().is_empty())
            .unwrap_or("unknown")
            .to_ascii_lowercase();
        if let Ok(mut map) = self.messages_by_game.lock() {
            *map.entry(label).or_insert(0) += 1;
        }
    }

    /// Incrementa el contador `relay_elo_updates_total`.
    pub fn inc_elo_updates_total(&self) {
        self.elo_updates_total.fetch_add(1, Ordering::Relaxed);
    }

    /// Incrementa el contador `rate_limit_drops_total`.
    pub fn inc_rate_limit_drops_total(&self) {
        self.rate_limit_drops_total.fetch_add(1, Ordering::Relaxed);
    }

    /// Incrementa el contador `ip_bans_total`.
    pub fn inc_ip_bans_total(&self) {
        self.ip_bans_total.fetch_add(1, Ordering::Relaxed);
    }

    /// Renderiza todas las métricas en el formato de exposición de texto de Prometheus (`0.0.4`).
    pub fn render_prometheus_text(&self) -> String {
        let mut out = String::with_capacity(1024);

        let conn = self.connections_active.load(Ordering::Relaxed).max(0);
        let rooms = self.rooms_active.load(Ordering::Relaxed).max(0);
        let elo_updates = self.elo_updates_total.load(Ordering::Relaxed);
        let drops = self.rate_limit_drops_total.load(Ordering::Relaxed);
        let bans = self.ip_bans_total.load(Ordering::Relaxed);

        let _ = writeln!(
            out,
            "# HELP relay_connections_active Number of currently active WebSocket connections."
        );
        let _ = writeln!(out, "# TYPE relay_connections_active gauge");
        let _ = writeln!(out, "relay_connections_active {conn}");

        let _ = writeln!(
            out,
            "# HELP relay_rooms_active Number of currently active rooms in the relay."
        );
        let _ = writeln!(out, "# TYPE relay_rooms_active gauge");
        let _ = writeln!(out, "relay_rooms_active {rooms}");

        let _ = writeln!(
            out,
            "# HELP relay_messages_total Total WebSocket messages processed by game_id."
        );
        let _ = writeln!(out, "# TYPE relay_messages_total counter");
        if let Ok(map) = self.messages_by_game.lock() {
            if map.is_empty() {
                let _ = writeln!(out, "relay_messages_total{{game_id=\"none\"}} 0");
            } else {
                for (gid, count) in map.iter() {
                    let safe_gid = gid.replace('"', "");
                    let _ = writeln!(
                        out,
                        "relay_messages_total{{game_id=\"{safe_gid}\"}} {count}"
                    );
                }
            }
        }

        let _ = writeln!(
            out,
            "# HELP relay_elo_updates_total Total ELO rating updates persisted."
        );
        let _ = writeln!(out, "# TYPE relay_elo_updates_total counter");
        let _ = writeln!(out, "relay_elo_updates_total {elo_updates}");

        let _ = writeln!(
            out,
            "# HELP rate_limit_drops_total Total messages dropped due to rate limiting."
        );
        let _ = writeln!(out, "# TYPE rate_limit_drops_total counter");
        let _ = writeln!(out, "rate_limit_drops_total {drops}");

        let _ = writeln!(
            out,
            "# HELP ip_bans_total Total temporary IP bans triggered by repeated rate-limit violations."
        );
        let _ = writeln!(out, "# TYPE ip_bans_total counter");
        let _ = writeln!(out, "ip_bans_total {bans}");

        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prometheus_metrics_exposition_format() {
        let m = RelayMetrics::new();
        m.inc_connections_active();
        m.set_rooms_active(3);
        m.inc_messages_total(Some("chess"));
        m.inc_messages_total(Some("chess"));
        m.inc_elo_updates_total();
        m.inc_rate_limit_drops_total();
        m.inc_ip_bans_total();

        let text = m.render_prometheus_text();
        assert!(text.contains("relay_connections_active 1"));
        assert!(text.contains("relay_rooms_active 3"));
        assert!(text.contains("relay_messages_total{game_id=\"chess\"} 2"));
        assert!(text.contains("relay_elo_updates_total 1"));
        assert!(text.contains("rate_limit_drops_total 1"));
        assert!(text.contains("ip_bans_total 1"));
    }
}
