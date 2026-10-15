use std::collections::HashMap;

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

pub const BOARD_STEPS: usize = 52;
pub const TRACK_LEN: u32 = 52;
pub const HOME_STRETCH_LEN: u32 = 5;
pub const MAX_STEPS: u32 = TRACK_LEN + HOME_STRETCH_LEN;
pub const WIN_STEPS: u32 = MAX_STEPS;
pub const TOKENS_PER_PLAYER: usize = 4;

/// Progreso de una ficha, medido como "pasos recorridos desde la base",
/// no como coordenada absoluta del tablero — mucho más simple que
/// modelar el track compartido con wraparound distinto por jugador.
///
/// - `0`: todavía en la base, no entró al tablero.
/// - `1..=TRACK_LEN`: en el tramo compartido (52 casillas).
/// - `TRACK_LEN+1..=MAX_STEPS`: en el tramo final privado de ese jugador (5 casillas).
/// - `MAX_STEPS`: llegó, ficha terminada (meta).
pub type Steps = u32;

/// Calcula el siguiente paso para una ficha dado su progreso actual y el dado.
/// Retorna `None` si el movimiento es ilegal (requiere 6 para salir de base,
/// o el dado excede las casillas exactas para llegar a la meta).
pub fn next_step_for(_player: PlayerId, from: Steps, die: u32) -> Option<Steps> {
    if from == 0 {
        if die == 6 {
            Some(1)
        } else {
            None
        }
    } else if from + die <= MAX_STEPS {
        Some(from + die)
    } else {
        None
    }
}

#[derive(GameResource)]
pub struct TokensResource {
    pub tokens: HashMap<PlayerId, [Steps; TOKENS_PER_PLAYER]>,
    /// En qué celda del tramo compartido empieza a entrar cada jugador.
    /// Determina también, junto con `steps`, la posición absoluta en el
    /// tablero (para saber si dos fichas de distintos dueños coinciden).
    pub start_offset: HashMap<PlayerId, u32>,
}

impl TokensResource {
    pub fn new(players: &[PlayerId]) -> Self {
        let mut tokens = HashMap::new();
        let mut start_offset = HashMap::new();
        let spacing = TRACK_LEN / players.len() as u32;
        for (i, player) in players.iter().enumerate() {
            tokens.insert(*player, [0; TOKENS_PER_PLAYER]);
            start_offset.insert(*player, i as u32 * spacing);
        }
        Self {
            tokens,
            start_offset,
        }
    }

    /// Posición absoluta en el tramo compartido, o `None` si la ficha
    /// está en la base o ya entró a su tramo final (esos casos son
    /// siempre "a salvo", nunca capturables).
    pub fn board_position(&self, player: PlayerId, steps: Steps) -> Option<u32> {
        if steps == 0 || steps > TRACK_LEN {
            return None;
        }
        let offset = self.start_offset[&player];
        Some((offset + steps - 1) % TRACK_LEN)
    }

    pub fn all_finished(&self, player: PlayerId) -> bool {
        self.tokens[&player].iter().all(|&s| s == MAX_STEPS)
    }

    /// Las casillas de salida de cada jugador actúan como casillas seguras donde no se puede capturar.
    /// Si `star_safe_squares` está activo, también son seguras las casillas estrella en (offset + 8) % TRACK_LEN.
    pub fn is_safe_square_with_config(&self, board_pos: u32, star_safe_squares: bool) -> bool {
        self.start_offset.values().any(|&offset| {
            if offset == board_pos {
                true
            } else if star_safe_squares {
                (offset + 8) % TRACK_LEN == board_pos
            } else {
                false
            }
        })
    }

    /// Mantiene compatibilidad directa con el comportamiento por defecto de casillas de salida.
    pub fn is_safe_square(&self, board_pos: u32) -> bool {
        self.is_safe_square_with_config(board_pos, false)
    }

    /// Comprueba si algún rival del jugador tiene 2 o más fichas en `board_pos` (formando un bloqueo).
    pub fn has_rival_blockade_at(&self, board_pos: u32, player: PlayerId) -> bool {
        for &other in self.tokens.keys() {
            if other == player {
                continue;
            }
            let count = self.tokens[&other]
                .iter()
                .filter(|&&steps| self.board_position(other, steps) == Some(board_pos))
                .count();
            if count >= 2 {
                return true;
            }
        }
        false
    }

    pub fn next_step_for(&self, player: PlayerId, from: Steps, die: u32) -> Option<Steps> {
        next_step_for(player, from, die)
    }

    /// Verifica si mover la ficha `token_index` de `player` con `roll` es un movimiento legal.
    pub fn is_valid_move_for_token(&self, player: PlayerId, token_index: usize, roll: u32) -> bool {
        let Some(tokens) = self.tokens.get(&player) else {
            return false;
        };
        if token_index >= TOKENS_PER_PLAYER {
            return false;
        }
        let current_steps = tokens[token_index];
        if current_steps == MAX_STEPS {
            return false;
        }

        let Some(target_steps) = self.next_step_for(player, current_steps, roll) else {
            return false;
        };

        if current_steps == 0 {
            if let Some(start_pos) = self.board_position(player, 1) {
                if self.has_rival_blockade_at(start_pos, player) {
                    return false;
                }
            }
            return true;
        }

        // Verificar bloqueo rival en todo el trayecto (paso a paso y aterrizaje)
        for step in (current_steps + 1)..=target_steps {
            if let Some(board_pos) = self.board_position(player, step) {
                if self.has_rival_blockade_at(board_pos, player) {
                    return false;
                }
            }
        }

        true
    }

    /// Verifica si el jugador tiene al menos un movimiento válido con la tirada actual.
    pub fn has_any_valid_move(&self, player: PlayerId, roll: u32) -> bool {
        for idx in 0..TOKENS_PER_PLAYER {
            if self.is_valid_move_for_token(player, idx, roll) {
                return true;
            }
        }
        false
    }
}

/// Tirada de dado pendiente de usar. Mientras un jugador tenga una acá,
/// no puede tirar de nuevo — primero tiene que mover una ficha con ese
/// valor (o quedarse sin jugadas válidas, ver limitaciones en el README).
#[derive(GameResource, Default)]
pub struct PendingRollResource {
    pub pending: HashMap<PlayerId, u32>,
}

#[derive(GameResource, Default, Debug, Clone, PartialEq, Eq)]
pub struct ConsecutiveSixesResource {
    pub count: HashMap<PlayerId, u8>,
}

impl ConsecutiveSixesResource {
    pub fn new() -> Self {
        Self {
            count: HashMap::new(),
        }
    }
}

#[derive(GameResource, Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct LudoRulesConfigResource {
    pub star_safe_squares: bool,
    pub bonus_roll_on_capture_and_goal: bool,
    pub three_sixes_penalty: bool,
}

