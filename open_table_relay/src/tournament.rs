// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Sistema de torneos con llaves eliminatorias simples (4, 8 o 16 participantes) para `open_table_relay`.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Enfrentamiento individual dentro de una ronda del bracket.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BracketMatch {
    /// Índice de la ronda (0 = primera ronda, 1 = siguiente, etc.).
    pub round: usize,
    /// Índice del enfrentamiento dentro de la ronda.
    pub match_index: usize,
    /// Primer participante del enfrentamiento.
    pub player1: Option<String>,
    /// Segundo participante del enfrentamiento.
    pub player2: Option<String>,
    /// Ganador del enfrentamiento una vez reportado el resultado.
    pub winner: Option<String>,
}

/// Estado completo de un torneo de eliminación simple.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Tournament {
    /// Identificador único del torneo (formato `"T-XXXX"`).
    pub tournament_id: String,
    /// Identificador del juego (ej. `"chess"`, `"checkers"`).
    pub game_id: String,
    /// Capacidad máxima de participantes (`4`, `8` o `16`).
    pub max_players: usize,
    /// Lista ordenada de participantes inscritos.
    pub participants: Vec<String>,
    /// Rondas del bracket (`rounds[r][m]`).
    pub rounds: Vec<Vec<BracketMatch>>,
    /// Indica si el torneo ya comenzó (al llenarse el cupo).
    pub started: bool,
    /// Campeón del torneo cuando finaliza la última ronda.
    pub champion: Option<String>,
}

/// Errores de gestión de torneos.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TournamentError {
    /// El número de jugadores no es 4, 8 ni 16.
    InvalidMaxPlayers,
    /// El torneo solicitado no existe.
    TournamentNotFound,
    /// El torneo ya está lleno o en curso.
    TournamentFull,
    /// El jugador ya estaba inscrito.
    AlreadyJoined,
    /// El enfrentamiento o ganador indicado no es válido.
    InvalidMatchReport,
}

impl Tournament {
    /// Crea un nuevo torneo si `max_players` es 4, 8 o 16.
    pub fn new(
        tournament_id: impl Into<String>,
        game_id: impl Into<String>,
        max_players: usize,
    ) -> Result<Self, TournamentError> {
        if !matches!(max_players, 4 | 8 | 16) {
            return Err(TournamentError::InvalidMaxPlayers);
        }
        Ok(Self {
            tournament_id: tournament_id.into(),
            game_id: game_id.into(),
            max_players,
            participants: Vec::with_capacity(max_players),
            rounds: Vec::new(),
            started: false,
            champion: None,
        })
    }

    /// Inscribe a un jugador y genera automáticamente el bracket cuando se alcanza `max_players`.
    pub fn add_participant(
        &mut self,
        player_id: impl Into<String>,
    ) -> Result<bool, TournamentError> {
        if self.started || self.participants.len() >= self.max_players {
            return Err(TournamentError::TournamentFull);
        }
        let pid = player_id.into();
        if self.participants.contains(&pid) {
            return Err(TournamentError::AlreadyJoined);
        }
        self.participants.push(pid);
        if self.participants.len() == self.max_players {
            self.generate_bracket();
            return Ok(true);
        }
        Ok(false)
    }

    /// Genera todas las rondas del bracket de eliminación simple al completarse el cupo.
    pub fn generate_bracket(&mut self) {
        self.rounds.clear();
        let mut match_count = self.max_players / 2;
        let mut round_idx = 0;

        while match_count >= 1 {
            let mut round_matches = Vec::with_capacity(match_count);
            for m in 0..match_count {
                let (p1, p2) = if round_idx == 0 {
                    (
                        self.participants.get(m * 2).cloned(),
                        self.participants.get(m * 2 + 1).cloned(),
                    )
                } else {
                    (None, None)
                };
                round_matches.push(BracketMatch {
                    round: round_idx,
                    match_index: m,
                    player1: p1,
                    player2: p2,
                    winner: None,
                });
            }
            self.rounds.push(round_matches);
            match_count /= 2;
            round_idx += 1;
        }
        self.started = true;
    }

    /// Registra el ganador de un enfrentamiento y lo avanza automáticamente a la siguiente ronda.
    pub fn report_match_winner(
        &mut self,
        round: usize,
        match_index: usize,
        winner: &str,
    ) -> Result<Option<String>, TournamentError> {
        if !self.started || round >= self.rounds.len() || match_index >= self.rounds[round].len() {
            return Err(TournamentError::InvalidMatchReport);
        }

        {
            let m = &mut self.rounds[round][match_index];
            let valid_p1 = m.player1.as_deref() == Some(winner);
            let valid_p2 = m.player2.as_deref() == Some(winner);
            if !valid_p1 && !valid_p2 {
                return Err(TournamentError::InvalidMatchReport);
            }
            m.winner = Some(winner.to_string());
        }

        if round + 1 < self.rounds.len() {
            let next_match_idx = match_index / 2;
            let next_match = &mut self.rounds[round + 1][next_match_idx];
            if (match_index & 1) == 0 {
                next_match.player1 = Some(winner.to_string());
            } else {
                next_match.player2 = Some(winner.to_string());
            }
        } else {
            self.champion = Some(winner.to_string());
        }

        Ok(self.champion.clone())
    }
}

/// Gestor de múltiples torneos en memoria para el servidor Relay.
#[derive(Debug, Default)]
pub struct TournamentManager {
    tournaments: HashMap<String, Tournament>,
    seq: u32,
}

impl TournamentManager {
    /// Crea una instancia vacía de `TournamentManager`.
    pub fn new() -> Self {
        Self::default()
    }

    /// Crea un torneo nuevo y devuelve su `tournament_id` (ej. `"T-AB12"`).
    pub fn create_tournament(
        &mut self,
        game_id: impl Into<String>,
        max_players: usize,
    ) -> Result<String, TournamentError> {
        self.seq = self.seq.wrapping_add(1);
        let code = format!("T-{:04X}", (self.seq.wrapping_mul(0xAB12)) & 0xFFFF);
        let tournament = Tournament::new(code.clone(), game_id, max_players)?;
        self.tournaments.insert(code.clone(), tournament);
        Ok(code)
    }

    /// Une un jugador al torneo `tournament_id`. Devuelve una copia del torneo actualizado y si acaba de iniciar.
    pub fn join_tournament(
        &mut self,
        tournament_id: &str,
        player_id: impl Into<String>,
    ) -> Result<(Tournament, bool), TournamentError> {
        let key = tournament_id.trim().to_uppercase();
        let t = self
            .tournaments
            .get_mut(&key)
            .ok_or(TournamentError::TournamentNotFound)?;
        let just_started = t.add_participant(player_id)?;
        Ok((t.clone(), just_started))
    }

    /// Reporta el ganador de un enfrentamiento en un torneo activo.
    pub fn report_match(
        &mut self,
        tournament_id: &str,
        round: usize,
        match_index: usize,
        winner: &str,
    ) -> Result<Tournament, TournamentError> {
        let key = tournament_id.trim().to_uppercase();
        let t = self
            .tournaments
            .get_mut(&key)
            .ok_or(TournamentError::TournamentNotFound)?;
        t.report_match_winner(round, match_index, winner)?;
        Ok(t.clone())
    }

    /// Consulta el estado de un torneo por su identificador.
    pub fn get_tournament(&self, tournament_id: &str) -> Option<&Tournament> {
        let key = tournament_id.trim().to_uppercase();
        self.tournaments.get(&key)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tournament_4_players_single_elimination() {
        let mut mgr = TournamentManager::new();
        let tid = mgr.create_tournament("chess", 4).unwrap();
        assert!(tid.starts_with("T-"));

        for p in ["p1", "p2", "p3"] {
            let (_, started) = mgr.join_tournament(&tid, p).unwrap();
            assert!(!started);
        }
        let (t, started) = mgr.join_tournament(&tid, "p4").unwrap();
        assert!(started);
        assert_eq!(t.rounds.len(), 2);
        assert_eq!(t.rounds[0].len(), 2);
        assert_eq!(t.rounds[1].len(), 1);

        // Semifinales (ronda 0)
        let t = mgr.report_match(&tid, 0, 0, "p1").unwrap();
        assert_eq!(t.rounds[1][0].player1.as_deref(), Some("p1"));
        let t = mgr.report_match(&tid, 0, 1, "p4").unwrap();
        assert_eq!(t.rounds[1][0].player2.as_deref(), Some("p4"));

        // Final (ronda 1)
        let t = mgr.report_match(&tid, 1, 0, "p1").unwrap();
        assert_eq!(t.champion.as_deref(), Some("p1"));
    }

    #[test]
    fn test_tournament_8_and_16_players_bracket_generation() {
        let mut mgr = TournamentManager::new();
        assert_eq!(
            mgr.create_tournament("chess", 6),
            Err(TournamentError::InvalidMaxPlayers)
        );

        let tid8 = mgr.create_tournament("go", 8).unwrap();
        for i in 1..=8 {
            mgr.join_tournament(&tid8, format!("player_{i}")).unwrap();
        }
        let t8 = mgr.get_tournament(&tid8).unwrap();
        assert!(t8.started);
        assert_eq!(t8.rounds.len(), 3); // 4 cuartos, 2 semis, 1 final

        let tid16 = mgr.create_tournament("checkers", 16).unwrap();
        for i in 1..=16 {
            mgr.join_tournament(&tid16, format!("player_{i}")).unwrap();
        }
        let t16 = mgr.get_tournament(&tid16).unwrap();
        assert!(t16.started);
        assert_eq!(t16.rounds.len(), 4); // 8 octavos, 4 cuartos, 2 semis, 1 final
    }
}
