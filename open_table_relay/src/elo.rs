// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Módulo de ratings ELO persistentes (`./data/ratings.db`) para `open_table_relay`.
//!
//! Esquema lógico:
//! `ratings(player_id TEXT PRIMARY KEY, game_id TEXT, elo INTEGER DEFAULT 1200, wins INTEGER, losses INTEGER)`
//!
//! Calcula actualizaciones de ELO con la fórmula FIDE estándar (`K = 32`).

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

/// Factor K estándar para actualización de ELO.
pub const DEFAULT_K_FACTOR: f64 = 32.0;

/// Rating ELO inicial por defecto para cualquier jugador nuevo.
pub const DEFAULT_INITIAL_ELO: i32 = 1200;

/// Registro de rating de un jugador en un juego específico.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PlayerRating {
    /// Identificador único del jugador.
    pub player_id: String,
    /// Identificador del juego (ej. `"chess"`, `"go"`).
    pub game_id: String,
    /// Puntuación ELO actual (por defecto `1200`).
    pub elo: i32,
    /// Número total de victorias registradas.
    pub wins: u32,
    /// Número total de derrotas registradas.
    pub losses: u32,
}

impl PlayerRating {
    /// Crea un nuevo registro con el ELO inicial (`1200`).
    pub fn new(player_id: impl Into<String>, game_id: impl Into<String>) -> Self {
        Self {
            player_id: player_id.into(),
            game_id: game_id.into(),
            elo: DEFAULT_INITIAL_ELO,
            wins: 0,
            losses: 0,
        }
    }
}

/// Almacén persistente de ratings ELO sincronizado en `./data/ratings.db`.
#[derive(Debug)]
pub struct EloStore {
    db_path: PathBuf,
    records: HashMap<(String, String), PlayerRating>,
}

impl EloStore {
    /// Abre o inicializa la base de datos en `db_path` (por defecto `./data/ratings.db`),
    /// creando automáticamente el directorio padre y la tabla si no existen.
    pub fn new(db_path: impl AsRef<Path>) -> std::io::Result<Self> {
        let path = db_path.as_ref().to_path_buf();
        if let Some(parent) = path.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent)?;
            }
        }

        let mut store = Self {
            db_path: path.clone(),
            records: HashMap::new(),
        };

        if path.exists() {
            store.load_from_disk()?;
        } else {
            store.flush_to_disk()?;
        }

        Ok(store)
    }

    /// Calcula el nuevo par de ratings `(winner_elo, loser_elo)` usando `K = 32`.
    pub fn compute_elo_pair(winner_elo: i32, loser_elo: i32, k: f64) -> (i32, i32) {
        let rw = f64::from(winner_elo);
        let rl = f64::from(loser_elo);
        let expected_w = 1.0 / (1.0 + 10.0_f64.powf((rl - rw) / 400.0));
        let expected_l = 1.0 - expected_w;

        let new_w = (rw + k * (1.0 - expected_w)).round() as i32;
        let new_l = (rl + k * (0.0 - expected_l)).round() as i32;
        (new_w, new_l)
    }

    /// Registra el resultado de una partida (`winner` vs `loser` en `game_id`),
    /// actualiza los ratings con `K = 32` y persiste en `./data/ratings.db`.
    pub fn report_result(
        &mut self,
        winner: &str,
        loser: &str,
        game_id: &str,
    ) -> std::io::Result<(PlayerRating, PlayerRating)> {
        let w_key = (winner.to_string(), game_id.to_string());
        let l_key = (loser.to_string(), game_id.to_string());

        let current_w = self
            .records
            .get(&w_key)
            .map_or(DEFAULT_INITIAL_ELO, |r| r.elo);
        let current_l = self
            .records
            .get(&l_key)
            .map_or(DEFAULT_INITIAL_ELO, |r| r.elo);

        let (new_w_elo, new_l_elo) = Self::compute_elo_pair(current_w, current_l, DEFAULT_K_FACTOR);

        let w_entry = self
            .records
            .entry(w_key)
            .or_insert_with(|| PlayerRating::new(winner, game_id));
        w_entry.elo = new_w_elo;
        w_entry.wins += 1;
        let updated_w = w_entry.clone();

        let l_entry = self
            .records
            .entry(l_key)
            .or_insert_with(|| PlayerRating::new(loser, game_id));
        l_entry.elo = new_l_elo;
        l_entry.losses += 1;
        let updated_l = l_entry.clone();

        self.flush_to_disk()?;
        Ok((updated_w, updated_l))
    }

    /// Devuelve el top-N (por defecto top-50) de jugadores ordenados por ELO descendente para `game_id`.
    pub fn get_rankings(&self, game_id: &str, limit: usize) -> Vec<PlayerRating> {
        let mut list: Vec<PlayerRating> = self
            .records
            .values()
            .filter(|r| r.game_id == game_id)
            .cloned()
            .collect();
        list.sort_by(|a, b| {
            b.elo
                .cmp(&a.elo)
                .then_with(|| b.wins.cmp(&a.wins))
                .then_with(|| a.player_id.cmp(&b.player_id))
        });
        list.truncate(limit);
        list
    }

    /// Devuelve todos los ratings registrados para `player_id` en todos los juegos.
    pub fn get_player_ratings(&self, player_id: &str) -> Vec<PlayerRating> {
        let mut list: Vec<PlayerRating> = self
            .records
            .values()
            .filter(|r| r.player_id == player_id)
            .cloned()
            .collect();
        list.sort_by(|a, b| a.game_id.cmp(&b.game_id));
        list
    }

    fn load_from_disk(&mut self) -> std::io::Result<()> {
        let content = fs::read_to_string(&self.db_path)?;
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("--") || trimmed.starts_with("CREATE ") {
                continue;
            }
            if let Ok(record) = serde_json::from_str::<PlayerRating>(trimmed) {
                self.records
                    .insert((record.player_id.clone(), record.game_id.clone()), record);
            }
        }
        Ok(())
    }

    fn flush_to_disk(&self) -> std::io::Result<()> {
        let mut file = fs::File::create(&self.db_path)?;
        writeln!(
            file,
            "-- CREATE TABLE IF NOT EXISTS ratings(player_id TEXT PRIMARY KEY, game_id TEXT, elo INTEGER DEFAULT 1200, wins INTEGER, losses INTEGER);"
        )?;
        for record in self.records.values() {
            if let Ok(json) = serde_json::to_string(record) {
                writeln!(file, "{json}")?;
            }
        }
        file.flush()?;
        file.sync_all()
    }

    /// Ejecuta un flush completo y sincronización de almacenamiento (`WAL checkpoint`) antes de apagar el servidor.
    pub fn wal_checkpoint_and_flush(&mut self) -> std::io::Result<()> {
        self.flush_to_disk()
    }
}
