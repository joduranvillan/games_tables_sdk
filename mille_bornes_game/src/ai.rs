// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Inteligencia Artificial heurística basada en reglas para Mille Bornes.
//!
//! Prioridad de jugada (`Medium` / `Hard` / `Expert`):
//! 1. `Safety` (`Card::Safety` / `Card::RightOfWay`) si está en la mano.
//! 2. `Remedy` (`Card::Remedy`) si el jugador IA está bloqueado por un peligro o límite de velocidad.
//! 3. `Hazard` (`Card::Hazard`) al oponente si tiene buen avance y es legal atacarlo.
//! 4. `Distance` (`Card::Distance`) máxima posible que sea legal jugar.
//!
//! En `AiDifficulty::Easy`, ignora las prioridades 1 y 3.

#![allow(clippy::needless_range_loop, clippy::large_enum_variant)]

use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};

use crate::card::{Card, Hazard, Safety};
use crate::commands::{
    DiscardCardCommand, DrawCardCommand, PlayCardCommand, PlayDistanceCommand, PlayHazardCommand,
    PlaySafetyCommand,
};
use crate::deck::{DeckResource, MAX_HAND_SIZE};
use crate::rules::{RightOfWayResource, SpeedLimitResource};

/// Estado de partida de Mille Bornes.
pub type MilleBornesState = Session;

/// Comando devuelto por la IA de Mille Bornes.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MilleBornesCommand {
    PlayCard(PlayCardCommand),
    PlaySafety(PlaySafetyCommand),
    PlayHazard(PlayHazardCommand),
    PlayDistance(PlayDistanceCommand),
    DrawCard(DrawCardCommand),
    DiscardCard(DiscardCardCommand),
}

impl MilleBornesCommand {
    /// Convierte el comando de IA en un `Box<dyn Command>` ejecutable por `Session`.
    pub fn into_command(self) -> Box<dyn Command> {
        match self {
            Self::PlayCard(cmd) => Box::new(cmd),
            Self::PlaySafety(cmd) => Box::new(cmd),
            Self::PlayHazard(cmd) => Box::new(cmd),
            Self::PlayDistance(cmd) => Box::new(cmd),
            Self::DrawCard(cmd) => Box::new(cmd),
            Self::DiscardCard(cmd) => Box::new(cmd),
        }
    }

    /// Índice de carta en la mano si el comando es `PlayCard` o `DiscardCard`.
    pub fn card_index(&self) -> Option<usize> {
        match self {
            Self::PlayCard(cmd) => Some(cmd.card_index),
            Self::DiscardCard(cmd) => Some(cmd.card_index),
            _ => None,
        }
    }
}

fn resolve_opponent(state: &MilleBornesState, ai: PlayerId) -> PlayerId {
    if let Some(turn) = state.world().get_resource::<TurnResource>() {
        if let Some(&other) = turn.0.players().iter().find(|&&p| p != ai) {
            return other;
        }
    }
    if let Some(deck) = state.world().get_resource::<DeckResource>() {
        if let Some(&other) = deck.hands.keys().find(|&&p| p != ai) {
            return other;
        }
    }
    if ai.0 == 1 {
        PlayerId(2)
    } else {
        PlayerId(1)
    }
}

fn can_play_hazard_on(
    deck: &DeckResource,
    speed_limit: Option<&SpeedLimitResource>,
    right_of_way: Option<&RightOfWayResource>,
    opponent: PlayerId,
    hazard: Hazard,
) -> bool {
    let opp_has_row = right_of_way
        .map(|r| r.active.contains(&opponent))
        .unwrap_or(false);
    if opp_has_row && hazard != Hazard::OutOfGas {
        return false;
    }

    if hazard == Hazard::SpeedLimit {
        let already_limited = speed_limit
            .map(|s| s.limited.contains(&opponent))
            .unwrap_or(false)
            || deck.hazard.get(&opponent).copied().flatten() == Some(Hazard::SpeedLimit);
        !already_limited
    } else {
        deck.hazard.get(&opponent).copied().flatten().is_none()
    }
}

fn can_play_distance_value(
    deck: &DeckResource,
    speed_limit: Option<&SpeedLimitResource>,
    right_of_way: Option<&RightOfWayResource>,
    ai: PlayerId,
    value: u32,
) -> bool {
    let has_row = right_of_way
        .map(|r| r.active.contains(&ai))
        .unwrap_or(false);
    let is_speed_limited = speed_limit
        .map(|s| s.limited.contains(&ai))
        .unwrap_or(false)
        || deck.hazard.get(&ai).copied().flatten() == Some(Hazard::SpeedLimit);

    if is_speed_limited && !has_row && value > 50 {
        return false;
    }

    if let Some(h) = deck.hazard.get(&ai).copied().flatten() {
        if h != Hazard::SpeedLimit && (!has_row || h == Hazard::OutOfGas) {
            return false;
        }
    }

    if value == 200 {
        let count_200 = deck.cards_200_played.get(&ai).copied().unwrap_or(0);
        if count_200 >= 2 {
            return false;
        }
    }

    let current = deck.distance.get(&ai).copied().unwrap_or(0);
    current + value <= deck.target_distance
}

/// Selecciona la mejor jugada para `ai` en Mille Bornes según `difficulty`:
/// 1) Safety si en mano (ignorada en `Easy`),
/// 2) Remedy si bloqueado,
/// 3) Hazard al oponente si tiene buen avance (ignorada en `Easy`),
/// 4) Distance máxima posible.
pub fn best_move(
    state: &MilleBornesState,
    ai: PlayerId,
    difficulty: AiDifficulty,
) -> Option<MilleBornesCommand> {
    best_move_with_randomness(state, ai, difficulty, 0, 0)
}

/// Selecciona la mejor jugada para `ai` en Mille Bornes con factor de aleatoriedad (`randomness_pct`, `0..=100`).
pub fn best_move_with_randomness(
    state: &MilleBornesState,
    ai: PlayerId,
    difficulty: AiDifficulty,
    randomness_pct: u8,
    seed: u64,
) -> Option<MilleBornesCommand> {
    let deck = state.world().get_resource::<DeckResource>()?;
    let speed_limit = state.world().get_resource::<SpeedLimitResource>();
    let right_of_way = state.world().get_resource::<RightOfWayResource>();
    let hand = deck.hands.get(&ai)?;

    if hand.is_empty() {
        if !deck.draw_pile.is_empty() || !deck.discard_pile.is_empty() {
            return Some(MilleBornesCommand::DrawCard(DrawCardCommand { player: ai }));
        }
        return None;
    }

    let opponent = resolve_opponent(state, ai);

    let current_hazard = deck.hazard.get(&ai).copied().flatten();
    let is_speed_limited = speed_limit
        .map(|s| s.limited.contains(&ai))
        .unwrap_or(false)
        || current_hazard == Some(Hazard::SpeedLimit);

    let threatening_safety_idx = hand.iter().position(|&card| match (current_hazard, card) {
        (Some(Hazard::FlatTire), Card::Safety(Safety::PunctureProof)) => true,
        (Some(Hazard::OutOfGas), Card::Safety(Safety::ExtraTank)) => true,
        (Some(Hazard::Accident), Card::Safety(Safety::DrivingAce)) => true,
        _ if is_speed_limited
            && matches!(card, Card::Safety(Safety::RightOfWay) | Card::RightOfWay) =>
        {
            true
        }
        _ => false,
    });

    if let Some(idx) = threatening_safety_idx {
        return Some(MilleBornesCommand::PlayCard(PlayCardCommand {
            player: ai,
            card_index: idx,
        }));
    }

    if difficulty != AiDifficulty::Easy {
        for (idx, card) in hand.iter().enumerate() {
            if matches!(card, Card::Safety(_) | Card::RightOfWay) {
                return Some(MilleBornesCommand::PlayCard(PlayCardCommand {
                    player: ai,
                    card_index: idx,
                }));
            }
        }
    }

    if let Some(h) = current_hazard {
        if h != Hazard::SpeedLimit {
            if let Some(idx) = hand.iter().position(|&c| c == Card::Remedy(h)) {
                return Some(MilleBornesCommand::PlayCard(PlayCardCommand {
                    player: ai,
                    card_index: idx,
                }));
            }
        }
    }
    if is_speed_limited {
        if let Some(idx) = hand
            .iter()
            .position(|&c| c == Card::Remedy(Hazard::SpeedLimit))
        {
            return Some(MilleBornesCommand::PlayCard(PlayCardCommand {
                player: ai,
                card_index: idx,
            }));
        }
    }

    if difficulty != AiDifficulty::Easy {
        let opp_distance = deck.distance.get(&opponent).copied().unwrap_or(0);
        let ai_distance = deck.distance.get(&ai).copied().unwrap_or(0);
        let opp_has_good_progress = opp_distance >= 50 || opp_distance > ai_distance;

        if opp_has_good_progress {
            for (idx, card) in hand.iter().enumerate() {
                if let Card::Hazard(hazard) = *card {
                    if can_play_hazard_on(deck, speed_limit, right_of_way, opponent, hazard) {
                        return Some(MilleBornesCommand::PlayCard(PlayCardCommand {
                            player: ai,
                            card_index: idx,
                        }));
                    }
                }
            }
        }
    }

    let mut distance_indices = Vec::new();
    let mut distance_scores = Vec::new();

    for (idx, card) in hand.iter().enumerate() {
        if let Card::Distance(val) = *card {
            if can_play_distance_value(deck, speed_limit, right_of_way, ai, val) {
                distance_indices.push(idx);
                distance_scores.push(val as f32);
            }
        }
    }

    if !distance_indices.is_empty() {
        let safety_band = match difficulty {
            AiDifficulty::Easy => 125.0,
            AiDifficulty::Medium => 75.0,
            AiDifficulty::Hard => 35.0,
            AiDifficulty::Expert => 15.0,
        };
        let pick_idx = AiDifficulty::select_top_k_with_noise(
            &distance_scores,
            randomness_pct,
            safety_band,
            seed ^ state.current_tick().0 ^ state.id.0,
        )
        .unwrap_or(0);
        return Some(MilleBornesCommand::PlayCard(PlayCardCommand {
            player: ai,
            card_index: distance_indices[pick_idx],
        }));
    }

    if difficulty != AiDifficulty::Easy {
        for (idx, card) in hand.iter().enumerate() {
            if let Card::Hazard(hazard) = *card {
                if can_play_hazard_on(deck, speed_limit, right_of_way, opponent, hazard) {
                    return Some(MilleBornesCommand::PlayCard(PlayCardCommand {
                        player: ai,
                        card_index: idx,
                    }));
                }
            }
        }
    }

    if hand.len() < MAX_HAND_SIZE && (!deck.draw_pile.is_empty() || !deck.discard_pile.is_empty()) {
        return Some(MilleBornesCommand::DrawCard(DrawCardCommand { player: ai }));
    }

    Some(MilleBornesCommand::DiscardCard(DiscardCardCommand {
        player: ai,
        card_index: 0,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::card::Safety;
    use crate::new_mille_bornes_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn mille_bornes_ai_plays_safety_first() {
        let mut session = new_mille_bornes_session(SessionId(1), 42, P1, P2);

        {
            let mut deck = session.world_mut().resource_mut::<DeckResource>();
            deck.hands.insert(
                P1,
                vec![
                    Card::Distance(100),
                    Card::Hazard(Hazard::FlatTire),
                    Card::Safety(Safety::RightOfWay),
                    Card::Distance(200),
                ],
            );
            deck.distance.insert(P2, 150);
        }

        // En dificultad Hard/Medium, la prioridad 1 es jugar la carta Safety (índice 2)
        let hard_cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            hard_cmd,
            MilleBornesCommand::PlayCard(PlayCardCommand {
                player: P1,
                card_index: 2,
            })
        );

        // En dificultad Easy, ignora las prioridades 1 (Safety) y 3 (Hazard) y juega la mayor Distance (200 en índice 3)
        let easy_cmd = best_move(&session, P1, AiDifficulty::Easy).unwrap();
        assert_eq!(
            easy_cmd,
            MilleBornesCommand::PlayCard(PlayCardCommand {
                player: P1,
                card_index: 3,
            })
        );
    }

    #[test]
    fn mille_bornes_ai_prioritizes_all_four_safeties_when_threatened() {
        let safeties_and_hazards = [
            (Hazard::FlatTire, Card::Safety(Safety::PunctureProof)),
            (Hazard::OutOfGas, Card::Safety(Safety::ExtraTank)),
            (Hazard::Accident, Card::Safety(Safety::DrivingAce)),
            (Hazard::SpeedLimit, Card::Safety(Safety::RightOfWay)),
        ];

        for (hazard, safety_card) in safeties_and_hazards {
            let mut session = new_mille_bornes_session(SessionId(1), 42, P1, P2);
            {
                if hazard == Hazard::SpeedLimit {
                    session
                        .world_mut()
                        .resource_mut::<SpeedLimitResource>()
                        .limited
                        .insert(P1);
                } else {
                    let mut deck = session.world_mut().resource_mut::<DeckResource>();
                    deck.hazard.insert(P1, Some(hazard));
                }
                let mut deck = session.world_mut().resource_mut::<DeckResource>();
                deck.hands.insert(
                    P1,
                    vec![Card::Distance(200), Card::Remedy(hazard), safety_card],
                );
            }

            // Debe priorizar la Safety correspondiente (índice 2) sobre el Remedy o la Distance
            let cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
            assert_eq!(
                cmd,
                MilleBornesCommand::PlayCard(PlayCardCommand {
                    player: P1,
                    card_index: 2,
                }),
                "Debe priorizar Safety ante el peligro {:?}",
                hazard
            );
        }
    }
}
