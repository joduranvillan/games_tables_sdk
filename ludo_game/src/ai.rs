// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use crate::board::{PendingRollResource, TokensResource, MAX_STEPS, WIN_STEPS};
use crate::commands::MoveTokenCommand;
use open_table_engine::prelude::*;

/// Selecciona el mejor movimiento para `player` según las heurísticas de Ludo.
pub fn ludo_ai_pick_move(session: &Session, player: PlayerId) -> Option<MoveTokenCommand> {
    if session.current_player() != player {
        return None;
    }

    let pending_roll = session
        .world()
        .get_resource::<PendingRollResource>()
        .and_then(|p| p.pending.get(&player).copied())?;

    let tokens_res = session.world().get_resource::<TokensResource>()?;
    let player_tokens = tokens_res.tokens.get(&player)?;

    let min_unfinished_steps = player_tokens
        .iter()
        .copied()
        .filter(|&s| s < MAX_STEPS)
        .min()
        .unwrap_or(0);

    let mut best_token: Option<usize> = None;
    let mut best_score: i32 = i32::MIN;

    for (token_index, &current_steps) in player_tokens.iter().enumerate() {
        if !tokens_res.is_valid_move_for_token(player, token_index, pending_roll) {
            continue;
        }

        let target_steps = if current_steps == 0 {
            1
        } else {
            current_steps + pending_roll
        };

        let pasos_avanzados = if current_steps == 0 { 1 } else { pending_roll };
        let mut score: i32 = 0;

        // +20 si saca una ficha de la base (steps 0 -> 1)
        if current_steps == 0 && target_steps == 1 {
            score += 20;
        }

        // +15 si llega exactamente a la meta (steps == WIN_STEPS)
        if target_steps == WIN_STEPS {
            score += 15;
        }

        // +10 si captura una ficha rival (en casilla compartida que no sea segura)
        if let Some(landing_pos) = tokens_res.board_position(player, target_steps) {
            if !tokens_res.is_safe_square(landing_pos) {
                let captures_rival = tokens_res.tokens.iter().any(|(&other, other_tokens)| {
                    other != player
                        && other_tokens
                            .iter()
                            .any(|&s| tokens_res.board_position(other, s) == Some(landing_pos))
                });
                if captures_rival {
                    score += 10;
                }
            }
        }

        // -10 si se mueve a una casilla ocupada por 2 fichas rivales (bloqueo rival)
        if let Some(landing_pos) = tokens_res.board_position(player, target_steps) {
            if tokens_res.has_rival_blockade_at(landing_pos, player) {
                score -= 10;
            }
        }

        // +5 si avanza la ficha más atrasada
        if current_steps == min_unfinished_steps {
            score += 5;
        }

        // +3 * pasos_avanzados
        score += 3 * (pasos_avanzados as i32);

        // Si hay dado con valor 6, priorizar sacar fichas de base
        if pending_roll == 6 && current_steps == 0 && target_steps == 1 {
            score += 10;
        }

        // En caso de empate, se queda con el de menor token_index (estricto `>`)
        if score > best_score {
            best_score = score;
            best_token = Some(token_index);
        }
    }

    best_token.map(|token_index| MoveTokenCommand {
        player,
        token_index,
    })
}

/// Selecciona el mejor movimiento para `player` en Ludo parametrizado por `AiDifficulty`.
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<MoveTokenCommand> {
    let _depth = difficulty.max_depth();
    ludo_ai_pick_move(session, player)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{new_ludo_session, PendingRollResource, TokensResource};

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn test_ludo_ai_saca_ficha_con_seis() {
        let mut session = new_ludo_session(SessionId(1), 1, vec![P1, P2]);
        {
            let mut pending = session.world_mut().resource_mut::<PendingRollResource>();
            pending.pending.insert(P1, 6);
        }

        let mv = ludo_ai_pick_move(&session, P1);
        assert!(mv.is_some(), "La IA debe poder mover con un 6");
        let cmd = mv.unwrap();
        assert_eq!(cmd.player, P1);
        assert_eq!(
            cmd.token_index, 0,
            "La IA debe elegir sacar la primera ficha de la base (token 0)"
        );
    }

    #[test]
    fn test_ludo_ai_captura_cuando_puede() {
        let mut session = new_ludo_session(SessionId(2), 1, vec![P1, P2]);
        {
            let mut tokens = session.world_mut().resource_mut::<TokensResource>();
            // P1: token 0 en steps=10, token 1 en steps=5
            tokens.tokens.get_mut(&P1).unwrap()[0] = 10;
            tokens.tokens.get_mut(&P1).unwrap()[1] = 5;

            // P2: token 0 en steps=40 tal que posición absoluta coincide con P1 en steps=14
            // P1 start_offset = 0 => (0 + 14 - 1)%52 = 13
            // P2 start_offset = 26 => (26 + steps - 1)%52 = 13 => 25 + steps = 65 => steps = 40
            tokens.tokens.get_mut(&P2).unwrap()[0] = 40;
        }
        {
            let mut pending = session.world_mut().resource_mut::<PendingRollResource>();
            pending.pending.insert(P1, 4);
        }

        let mv = ludo_ai_pick_move(&session, P1);
        assert!(mv.is_some(), "La IA debe seleccionar un movimiento");
        let cmd = mv.unwrap();
        assert_eq!(cmd.player, P1);
        assert_eq!(
            cmd.token_index, 0,
            "La IA debe priorizar la ficha que realiza una captura sobre la más atrasada"
        );
    }
}
