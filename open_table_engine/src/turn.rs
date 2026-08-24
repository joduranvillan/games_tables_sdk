//! Manejo de turnos. Genérico a propósito: `TurnOrder` solo sabe "en qué
//! orden juegan" y "a quién le toca ahora" — no sabe nada de fases de
//! partida (setup/juego/fin), porque eso es específico de cada juego.
//!
//! Para las fases, la recomendación es que cada juego defina su propio
//! enum y lo registre con `#[derive(GameResource)]` de `open_table_macros`
//! (ya tenés ese mecanismo, no hace falta nada nuevo en el core para eso).

use bevy_ecs::prelude::Resource;
use open_table_core::ids::PlayerId;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurnOrder {
    players: Vec<PlayerId>,
    current: usize,
    turn_number: u32,
    direction: i32,
}

impl TurnOrder {
    pub fn new(players: Vec<PlayerId>) -> Self {
        assert!(
            !players.is_empty(),
            "TurnOrder necesita al menos un jugador"
        );
        Self {
            players,
            current: 0,
            turn_number: 0,
            direction: 1,
        }
    }

    pub fn current_player(&self) -> PlayerId {
        self.players[self.current]
    }

    /// Todos los jugadores de la partida, en el orden de turno. Útil
    /// para setup inicial (repartir cartas, fichas, etc.) sin necesitar
    /// que el comando de turno mande la lista de jugadores de nuevo.
    pub fn players(&self) -> &[PlayerId] {
        &self.players
    }

    pub fn is_current(&self, player: PlayerId) -> bool {
        self.current_player() == player
    }

    /// A quién le tocaría DESPUÉS de este, sin avanzar el turno. Útil
    /// para juegos de 2 jugadores donde una regla necesita saber "quién
    /// es el rival" sin mutar el estado real del turno (ej. batalla
    /// naval calculando a quién le está disparando el jugador actual).
    pub fn peek_next(&self) -> PlayerId {
        let n = self.players.len() as i32;
        let next = (self.current as i32 + self.direction).rem_euclid(n);
        self.players[next as usize]
    }

    pub fn peek_next_n(&self, steps: i32) -> PlayerId {
        let n = self.players.len() as i32;
        let next = (self.current as i32 + self.direction * steps).rem_euclid(n);
        self.players[next as usize]
    }

    pub fn reverse_direction(&mut self) {
        self.direction = -self.direction;
    }

    pub fn turn_number(&self) -> u32 {
        self.turn_number
    }

    /// Pasa el turno al siguiente jugador en el orden. Devuelve a quién le
    /// toca ahora.
    pub fn advance(&mut self) -> PlayerId {
        self.advance_n(1)
    }

    pub fn advance_n(&mut self, steps: i32) -> PlayerId {
        let n = self.players.len() as i32;
        self.current = (self.current as i32 + self.direction * steps).rem_euclid(n) as usize;
        self.turn_number += 1;
        self.current_player()
    }

    pub fn set_current_player(&mut self, player: PlayerId) {
        if let Some(pos) = self.players.iter().position(|&p| p == player) {
            self.current = pos;
        }
    }
}

/// Recurso de bevy_ecs que envuelve `TurnOrder`. Mismo patrón que
/// `RandomResource`: la lógica vive en el tipo puro (`TurnOrder`), acá
/// solo se agrega el `#[derive(Resource)]` que bevy_ecs exige.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Resource)]
pub struct TurnResource(pub TurnOrder);
