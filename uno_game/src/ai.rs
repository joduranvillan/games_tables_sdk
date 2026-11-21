// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Inteligencia Artificial heurística basada en reglas para UNO.
//!
//! Prioridad de jugada (`Medium` / `Hard` / `Expert`):
//! 1. `Wild Draw Four` (`CardValue::WildDrawFour`) si tiene ≤ 2 cartas en la mano y es legal.
//! 2. Carta que cambia el color al color propio más frecuente en la mano (`most_frequent_color`).
//! 3. `+2` (`CardValue::DrawTwo`) cuando algún oponente va ganando (tiene pocas cartas).
//! 4. Carta que coincide con el color activo o el número/valor de la cima del descarte.
//!
//! En `AiDifficulty::Easy`: juega la primera carta válida de su mano sin considerar estrategia.

#![allow(clippy::needless_range_loop, clippy::large_enum_variant)]

use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};

use crate::board::{Card, CardColor, CardValue, UnoState};
use crate::commands::{CallUnoCommand, DrawCardCommand, InterceptCommand, PlayCardCommand};

/// Trait de acceso para permitir llamar `best_move(&uno_state, ...)` o `best_move(&session, ...)`.
pub trait UnoStateAccess {
    fn as_uno_state(&self) -> Option<&UnoState>;
}

impl UnoStateAccess for UnoState {
    fn as_uno_state(&self) -> Option<&UnoState> {
        Some(self)
    }
}

impl UnoStateAccess for Session {
    fn as_uno_state(&self) -> Option<&UnoState> {
        self.world().get_resource::<UnoState>()
    }
}

/// Comando devuelto por la IA de UNO.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum UnoCommand {
    PlayCard(PlayCardCommand),
    DrawCard(DrawCardCommand),
    Intercept(InterceptCommand),
    CallUno(CallUnoCommand),
}

impl UnoCommand {
    /// Convierte el comando de IA en un `Box<dyn Command>` ejecutable por `Session`.
    pub fn into_command(self) -> Box<dyn Command> {
        match self {
            Self::PlayCard(cmd) => Box::new(cmd),
            Self::DrawCard(cmd) => Box::new(cmd),
            Self::Intercept(cmd) => Box::new(cmd),
            Self::CallUno(cmd) => Box::new(cmd),
        }
    }

    pub fn card_index(&self) -> Option<usize> {
        match self {
            Self::PlayCard(cmd) => Some(cmd.card_index),
            Self::Intercept(cmd) => Some(cmd.card_index),
            Self::DrawCard(_) | Self::CallUno(_) => None,
        }
    }

    pub fn chosen_color(&self) -> Option<CardColor> {
        match self {
            Self::PlayCard(cmd) => cmd.chosen_color,
            _ => None,
        }
    }
}

/// Calcula el color estándar (`Red`, `Yellow`, `Green`, `Blue`) más frecuente en la mano.
pub fn most_frequent_color(hand: &[Card]) -> CardColor {
    let candidates = [
        CardColor::Red,
        CardColor::Yellow,
        CardColor::Green,
        CardColor::Blue,
    ];
    let mut best_color = CardColor::Red;
    let mut best_count = 0usize;

    for &color in &candidates {
        let count = hand.iter().filter(|c| c.color == color).count();
        if count > best_count {
            best_count = count;
            best_color = color;
        }
    }
    best_color
}

/// Comprueba si `card` es legalmente jugable por `ai` considerando la restricción de `WildDrawFour`.
fn is_legally_playable(state: &UnoState, hand: &[Card], card: &Card) -> bool {
    if !state.is_playable(card) {
        return false;
    }
    if card.value == CardValue::WildDrawFour {
        let has_active_color = hand.iter().any(|c| c.color == state.active_color);
        if has_active_color {
            return false;
        }
    }
    true
}

fn make_play_command(
    ai: PlayerId,
    card_index: usize,
    card: &Card,
    preferred_color: CardColor,
) -> UnoCommand {
    let chosen_color = if card.color == CardColor::WildColor {
        Some(preferred_color)
    } else {
        None
    };
    UnoCommand::PlayCard(PlayCardCommand {
        player: ai,
        card_index,
        chosen_color,
    })
}

/// Selecciona la mejor jugada para `ai` en UNO según `difficulty`:
/// - `Easy`: primera carta válida en la mano sin estrategia.
/// - `Medium` / `Hard` / `Expert`:
///   1) `Wild Draw Four` si ≤ 2 cartas en mano,
///   2) Carta que cambia el color al color propio más frecuente,
///   3) `+2` al jugador que va ganando,
///   4) Carta que coincide con color/número.
pub fn best_move<S: UnoStateAccess>(
    state: &S,
    ai: PlayerId,
    difficulty: AiDifficulty,
) -> Option<UnoCommand> {
    best_move_with_randomness(state, ai, difficulty, 0, 0)
}

/// Selecciona la mejor jugada para `ai` en UNO con factor de aleatoriedad (`randomness_pct`, `0..=100`).
pub fn best_move_with_randomness<S: UnoStateAccess>(
    state: &S,
    ai: PlayerId,
    difficulty: AiDifficulty,
    randomness_pct: u8,
    seed: u64,
) -> Option<UnoCommand> {
    let uno = state.as_uno_state()?;
    let hand = uno.hands.get(&ai)?;

    if uno.draw_penalty > 0 {
        return Some(UnoCommand::DrawCard(DrawCardCommand { player: ai }));
    }

    if hand.len() == 1 && !uno.uno_called.contains(&ai) {
        let forgets = if difficulty == AiDifficulty::Easy {
            (uno.discard_pile.len() * 37 + ai.0 as usize * 17) % 10 < 3
        } else {
            false
        };
        if !forgets {
            return Some(UnoCommand::CallUno(CallUnoCommand { player: ai }));
        }
    }

    let playable: Vec<(usize, Card)> = hand
        .iter()
        .copied()
        .enumerate()
        .filter(|(_, card)| is_legally_playable(uno, hand, card))
        .collect();

    if playable.is_empty() {
        return Some(UnoCommand::DrawCard(DrawCardCommand { player: ai }));
    }

    let dominant_color = most_frequent_color(hand);

    if difficulty == AiDifficulty::Easy && randomness_pct == 0 {
        let (idx, card) = playable[0];
        let fallback_color = if uno.active_color != CardColor::WildColor {
            uno.active_color
        } else {
            CardColor::Red
        };
        return Some(make_play_command(ai, idx, &card, fallback_color));
    }

    let rival_leading = uno
        .hands
        .iter()
        .any(|(&p, h)| p != ai && (h.len() <= hand.len() || h.len() <= 3));

    if randomness_pct == 0 {
        if hand.len() <= 2 {
            if let Some(&(idx, card)) = playable
                .iter()
                .find(|(_, c)| c.value == CardValue::WildDrawFour)
            {
                return Some(make_play_command(ai, idx, &card, dominant_color));
            }
        }

        if dominant_color != uno.active_color {
            if let Some(&(idx, card)) = playable.iter().find(|(_, c)| c.color == dominant_color) {
                return Some(make_play_command(ai, idx, &card, dominant_color));
            }
            if let Some(&(idx, card)) = playable.iter().find(|(_, c)| c.value == CardValue::Wild) {
                return Some(make_play_command(ai, idx, &card, dominant_color));
            }
        }

        if rival_leading {
            if let Some(&(idx, card)) = playable.iter().find(|(_, c)| c.value == CardValue::DrawTwo)
            {
                return Some(make_play_command(ai, idx, &card, dominant_color));
            }
        }

        if let Some(&(idx, card)) = playable
            .iter()
            .find(|(_, c)| c.color != CardColor::WildColor)
        {
            return Some(make_play_command(ai, idx, &card, dominant_color));
        }

        let (idx, card) = playable[0];
        return Some(make_play_command(ai, idx, &card, dominant_color));
    }

    let scores: Vec<f32> = playable
        .iter()
        .map(|(_, c)| {
            if c.value == CardValue::WildDrawFour && hand.len() <= 2 {
                100.0
            } else if dominant_color != uno.active_color && c.color == dominant_color {
                85.0
            } else if dominant_color != uno.active_color && c.value == CardValue::Wild {
                80.0
            } else if rival_leading && c.value == CardValue::DrawTwo {
                75.0
            } else if c.color != CardColor::WildColor {
                50.0
            } else {
                25.0
            }
        })
        .collect();

    let safety_band = match difficulty {
        AiDifficulty::Easy => 60.0,
        AiDifficulty::Medium => 30.0,
        AiDifficulty::Hard => 15.0,
        AiDifficulty::Expert => 8.0,
    };
    let pick = AiDifficulty::select_top_k_with_noise(
        &scores,
        randomness_pct,
        safety_band,
        seed ^ (uno.discard_pile.len() as u64),
    )
    .unwrap_or(0);
    let (idx, card) = playable[pick];
    Some(make_play_command(ai, idx, &card, dominant_color))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_uno_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn uno_ai_changes_color_strategically() {
        let mut session = new_uno_session(SessionId(1), 42, vec![P1, P2]);

        {
            let mut state = session.world_mut().resource_mut::<UnoState>();
            // Color activo actual: Rojo (carta superior: 5 Rojo)
            state.active_color = CardColor::Red;
            state.discard_pile = vec![Card::new(CardColor::Red, CardValue::Number(5))];
            state.draw_penalty = 0;

            // Mano de P1:
            // - Índice 0: 2 Rojo (mantiene Rojo)
            // - Índice 1: 5 Azul (coincide por número 5 y cambia el color a Azul, que es el color más frecuente en la mano)
            // - Índice 2: 7 Azul
            // - Índice 3: 9 Azul
            state.hands.insert(
                P1,
                vec![
                    Card::new(CardColor::Red, CardValue::Number(2)),
                    Card::new(CardColor::Blue, CardValue::Number(5)),
                    Card::new(CardColor::Blue, CardValue::Number(7)),
                    Card::new(CardColor::Blue, CardValue::Number(9)),
                ],
            );
        }

        // En Hard/Medium, la IA detecta que Azul es su color más frecuente (3 cartas vs 1 Roja)
        // y juega la carta en índice 1 (5 Azul) para cambiar estratégicamente el color activo a Azul.
        let hard_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            hard_cmd,
            UnoCommand::PlayCard(PlayCardCommand {
                player: P1,
                card_index: 1,
                chosen_color: None,
            })
        );

        // En Easy, juega la primera carta válida sin considerar estrategia (índice 0: 2 Rojo)
        let easy_cmd = best_move(&session, P1, AiDifficulty::Easy).unwrap();
        assert_eq!(
            easy_cmd,
            UnoCommand::PlayCard(PlayCardCommand {
                player: P1,
                card_index: 0,
                chosen_color: None,
            })
        );
    }

    #[test]
    fn uno_ai_calls_uno_when_left_with_one_card() {
        let mut session = new_uno_session(SessionId(1), 42, vec![P1, P2]);
        {
            let mut state = session.world_mut().resource_mut::<UnoState>();
            state.active_color = CardColor::Red;
            state.discard_pile = vec![Card::new(CardColor::Red, CardValue::Number(5))];
            // P1 tiene exactamente 1 carta y no ha cantado UNO
            state
                .hands
                .insert(P1, vec![Card::new(CardColor::Red, CardValue::Number(2))]);
            state.uno_called.clear();
        }

        // En Hard, debe cantar UNO inmediatamente
        let cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(cmd, UnoCommand::CallUno(CallUnoCommand { player: P1 }));

        // Tras cantar UNO, vuelve a emitir la jugada de la carta
        {
            let mut state = session.world_mut().resource_mut::<UnoState>();
            state.uno_called.insert(P1);
        }
        let play_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            play_cmd,
            UnoCommand::PlayCard(PlayCardCommand {
                player: P1,
                card_index: 0,
                chosen_color: None,
            })
        );
    }
}
