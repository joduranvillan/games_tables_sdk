// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use crate::board::{BoardResource, Sides, POINTS};
use crate::commands::{
    AcceptDoubleCommand, MoveCheckerCommand, OfferDoubleCommand, RejectDoubleCommand,
    RollDiceCommand,
};
use crate::dice::PendingDiceResource;
use crate::resources::{DoublingCubeResource, MatchStateResource};
use open_table_engine::prelude::*;
use serde::{Deserialize, Serialize};
pub fn clone_backgammon_session(session: &Session) -> Session {
    let (inc, dec) = session
        .world()
        .get_resource::<Sides>()
        .map(|s| (s.increasing, s.decreasing))
        .unwrap_or((PlayerId(1), PlayerId(2)));
    let mut new_session = crate::new_backgammon_session(session.id, 0, inc, dec);
    if let Some(board) = session.world().get_resource::<BoardResource>() {
        new_session.world_mut().insert_resource(board.clone());
    }
    if let Some(sides) = session.world().get_resource::<Sides>() {
        new_session.world_mut().insert_resource(*sides);
    }
    if let Some(pending) = session.world().get_resource::<PendingDiceResource>() {
        new_session.world_mut().insert_resource(pending.clone());
    }
    if let Some(cube) = session.world().get_resource::<DoublingCubeResource>() {
        new_session.world_mut().insert_resource(cube.clone());
    }
    if let Some(match_state) = session.world().get_resource::<MatchStateResource>() {
        new_session.world_mut().insert_resource(match_state.clone());
    }
    if let Some(turn) = session.world().get_resource::<TurnResource>() {
        new_session.world_mut().insert_resource(turn.clone());
    }
    if let Some(game_over) = session.world().get_resource::<GameOverResource>() {
        new_session.world_mut().insert_resource(*game_over);
    }
    if let Some(winner) = session.world().get_resource::<WinnerResource>() {
        new_session.world_mut().insert_resource(*winner);
    }
    new_session
}

fn is_in_opponent_field(sides: &Sides, player: PlayerId, point: usize) -> bool {
    if player == sides.increasing {
        point < 12
    } else {
        point >= 12
    }
}

/// Evalúa heurísticamente una jugada legal de Backgammon según los criterios:
/// - +10 si saca una ficha de la barra.
/// - +8 si lleva una ficha a la zona "home" (puntos 1-6 del jugador).
/// - +5 si crea un bloque (2 o más fichas en el punto destino).
/// - -15 si deja una "blot" (ficha sola) en el campo del oponente.
/// - +3 por cada punto de avance del dado utilizado.
fn evaluate_backgammon_move(
    after_session: &Session,
    cmd: &MoveCheckerCommand,
    player: PlayerId,
    sides: &Sides,
) -> f32 {
    let mut score = 0.0f32;
    let owner_sign = sides.owner_sign(player);

    // 1. +10 si el movimiento saca una ficha de la barra
    if cmd.from.is_none() {
        score += 10.0;
    }

    // Calcular destino
    let destination: Option<usize> = match cmd.from {
        None => Some(sides.entry_point(player, cmd.die)),
        Some(from) => {
            let raw = from as i32 + sides.forward_direction(player) * cmd.die as i32;
            if raw >= 0 && raw < POINTS as i32 {
                Some(raw as usize)
            } else {
                None // Borne off
            }
        }
    };

    // 2. +8 si lleva una ficha a la zona "home" (o saca la ficha)
    match destination {
        Some(dest) => {
            if sides.is_home_point(player, dest) {
                score += 8.0;
            }
        }
        None => {
            // Bear-off (sacar del tablero)
            score += 8.0;
        }
    }

    if let Some(after_board) = after_session.world().get_resource::<BoardResource>() {
        // 3. +5 si crea un bloque (2 o más fichas en el punto destino)
        if let Some(dest) = destination {
            let count_at_dest = after_board.points[dest] * owner_sign;
            if count_at_dest >= 2 {
                score += 5.0;
            }

            // 4. -15 si deja una "blot" (ficha sola) en el campo del oponente en el destino
            if count_at_dest == 1 && is_in_opponent_field(sides, player, dest) {
                score -= 15.0;
            }
        }

        // -15 si el origen 'from' quedó como blot en el campo del oponente
        if let Some(from_idx) = cmd.from {
            let count_at_from = after_board.points[from_idx] * owner_sign;
            if count_at_from == 1 && is_in_opponent_field(sides, player, from_idx) {
                score -= 15.0;
            }
        }
    }

    // 5. +3 por cada punto de avance del dado utilizado
    score += 3.0 * (cmd.die as f32);

    score
}

/// Selecciona una jugada legal heurística para Backgammon.
pub fn backgammon_ai_pick_move(session: &Session, player: PlayerId) -> Option<MoveCheckerCommand> {
    backgammon_ai_pick_move_with_randomness(session, player, AiDifficulty::Medium, 0, 0)
}

/// Selecciona una jugada legal heurística para Backgammon con factor de aleatoriedad (`randomness_pct`, `0..=100`).
pub fn backgammon_ai_pick_move_with_randomness(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
    randomness_pct: u8,
    seed: u64,
) -> Option<MoveCheckerCommand> {
    if session
        .world()
        .get_resource::<GameOverResource>()
        .is_some_and(|r| r.0)
    {
        return None;
    }

    if session.current_player() != player {
        return None;
    }

    let board = session.world().get_resource::<BoardResource>()?;
    let sides = session.world().get_resource::<Sides>()?;
    let pending_dice = session.world().get_resource::<PendingDiceResource>()?;
    let available_dice = pending_dice.pending.get(&player)?;
    if available_dice.is_empty() {
        return None;
    }

    let mut unique_dice = available_dice.clone();
    unique_dice.sort_unstable();
    unique_dice.dedup();

    let owner_sign = sides.owner_sign(player);
    let on_bar = *board.bar.get(&player).unwrap_or(&0);

    let mut potential_moves = Vec::new();
    if on_bar > 0 {
        for &die in &unique_dice {
            potential_moves.push(MoveCheckerCommand {
                player,
                from: None,
                die,
            });
        }
    } else {
        for (from_idx, &point_count) in board.points.iter().enumerate().take(POINTS) {
            if point_count * owner_sign > 0 {
                for &die in &unique_dice {
                    potential_moves.push(MoveCheckerCommand {
                        player,
                        from: Some(from_idx),
                        die,
                    });
                }
            }
        }
    }

    let mut legal_moves = Vec::new();
    let mut scores = Vec::new();

    for cmd in potential_moves {
        let mut trial = clone_backgammon_session(session);
        if trial.process_command(player, Box::new(cmd.clone())).is_ok() {
            let score = evaluate_backgammon_move(&trial, &cmd, player, sides);
            legal_moves.push(cmd);
            scores.push(score);
        }
    }

    if legal_moves.is_empty() {
        return None;
    }

    if randomness_pct > 0 {
        let safety_band = match difficulty {
            AiDifficulty::Easy => 20.0,
            AiDifficulty::Medium => 10.0,
            AiDifficulty::Hard => 5.0,
            AiDifficulty::Expert => 2.5,
        };
        if let Some(idx) = AiDifficulty::select_top_k_with_noise(
            &scores,
            randomness_pct,
            safety_band,
            seed ^ session.current_tick().0 ^ session.id.0,
        ) {
            return legal_moves.into_iter().nth(idx);
        }
    }

    let mut max_score = f32::NEG_INFINITY;
    for &score in &scores {
        if score > max_score {
            max_score = score;
        }
    }

    let best_moves: Vec<MoveCheckerCommand> = legal_moves
        .into_iter()
        .zip(scores)
        .filter(|(_, s)| (*s - max_score).abs() < 1e-4)
        .map(|(cmd, _)| cmd)
        .collect();

    if best_moves.len() == 1 {
        Some(best_moves[0].clone())
    } else {
        let idx = ((seed ^ session.current_tick().0) as usize) % best_moves.len();
        Some(best_moves[idx].clone())
    }
}

/// Calcula el pip count (distancia total restante para sacar todas las fichas) de un jugador.
pub fn calculate_pip_count(board: &BoardResource, sides: &Sides, player: PlayerId) -> u32 {
    let owner_sign = sides.owner_sign(player);
    let mut pips = 0u32;

    let on_bar = board.bar.get(&player).copied().unwrap_or(0);
    pips += on_bar * 25;

    for (idx, &point_count) in board.points.iter().enumerate().take(POINTS) {
        let count = point_count * owner_sign;
        if count > 0 {
            let distance = if player == sides.increasing {
                24 - idx as u32
            } else {
                idx as u32 + 1
            };
            pips += (count as u32) * distance;
        }
    }
    pips
}

/// Determina si el jugador tiene suficiente ventaja para proponer doblar la apuesta.
pub fn should_offer_double(session: &Session, player: PlayerId) -> bool {
    if session
        .world()
        .get_resource::<GameOverResource>()
        .is_some_and(|r| r.0)
    {
        return false;
    }
    if session.current_player() != player {
        return false;
    }
    if session
        .world()
        .get_resource::<MatchStateResource>()
        .map(|m| m.crawford_game)
        .unwrap_or(false)
    {
        return false;
    }
    let pending = session.world().get_resource::<PendingDiceResource>();
    if pending
        .map(|p| {
            p.pending
                .get(&player)
                .map(|d| !d.is_empty())
                .unwrap_or(false)
        })
        .unwrap_or(false)
    {
        return false;
    }
    let cube = match session.world().get_resource::<DoublingCubeResource>() {
        Some(c) => c,
        None => return false,
    };
    if let Some(owner) = cube.owner {
        if owner != player {
            return false;
        }
    }
    if cube.offered || cube.offered_by.is_some() {
        return false;
    }

    let board = match session.world().get_resource::<BoardResource>() {
        Some(b) => b,
        None => return false,
    };
    let sides = match session.world().get_resource::<Sides>() {
        Some(s) => s,
        None => return false,
    };

    let opp = sides.opponent_of(player);
    let my_pips = calculate_pip_count(board, sides, player);
    let opp_pips = calculate_pip_count(board, sides, opp);

    let my_bar = board.bar.get(&player).copied().unwrap_or(0);
    let opp_bar = board.bar.get(&opp).copied().unwrap_or(0);

    // Ventaja clara de doblaje:
    // 1) Si el rival tiene fichas en la barra y nosotros ninguna, y no estamos muy atrasados
    if opp_bar > 0 && my_bar == 0 && my_pips <= opp_pips + 10 {
        return true;
    }
    // 2) Ventaja en pip count (carrera): al menos 15 pips por delante
    my_bar == 0 && my_pips + 15 <= opp_pips
}

/// Determina si el jugador debe aceptar una oferta de doblaje del oponente.
pub fn should_accept_double(session: &Session, player: PlayerId) -> bool {
    let board = match session.world().get_resource::<BoardResource>() {
        Some(b) => b,
        None => return false,
    };
    let sides = match session.world().get_resource::<Sides>() {
        Some(s) => s,
        None => return false,
    };

    let opp = sides.opponent_of(player);
    let my_pips = calculate_pip_count(board, sides, player);
    let opp_pips = calculate_pip_count(board, sides, opp);

    my_pips <= opp_pips + 40
}

/// Comando devuelto por la IA de Backgammon.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum BackgammonCommand {
    Move(MoveCheckerCommand),
    OfferDouble(OfferDoubleCommand),
    AcceptDouble(AcceptDoubleCommand),
    RejectDouble(RejectDoubleCommand),
    RollDice(RollDiceCommand),
}

impl BackgammonCommand {
    pub fn into_command(self) -> Box<dyn Command> {
        match self {
            Self::Move(c) => Box::new(c),
            Self::OfferDouble(c) => Box::new(c),
            Self::AcceptDouble(c) => Box::new(c),
            Self::RejectDouble(c) => Box::new(c),
            Self::RollDice(c) => Box::new(c),
        }
    }
}

/// Selecciona la mejor acción para `player` según su nivel de dificultad.
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<BackgammonCommand> {
    best_move_with_randomness(session, player, difficulty, 0, 0)
}

/// Selecciona la mejor acción para `player` en Backgammon con factor de aleatoriedad (`randomness_pct`, `0..=100`).
pub fn best_move_with_randomness(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
    randomness_pct: u8,
    seed: u64,
) -> Option<BackgammonCommand> {
    if session
        .world()
        .get_resource::<GameOverResource>()
        .is_some_and(|r| r.0)
    {
        return None;
    }

    // 1. Si el rival propuso doblar al jugador, responder
    if let Some(cube) = session.world().get_resource::<DoublingCubeResource>() {
        if cube.offered {
            let opp = session
                .world()
                .get_resource::<Sides>()
                .map(|s| s.opponent_of(player));
            if cube.offered_by == opp {
                if should_accept_double(session, player) {
                    return Some(BackgammonCommand::AcceptDouble(AcceptDoubleCommand {
                        player,
                    }));
                } else {
                    return Some(BackgammonCommand::RejectDouble(RejectDoubleCommand {
                        player,
                    }));
                }
            }
        }
    }

    if session.current_player() != player {
        return None;
    }

    // 2. Si no ha tirado los dados:
    let pending_dice = session.world().get_resource::<PendingDiceResource>();
    let has_pending = pending_dice
        .and_then(|p| p.pending.get(&player))
        .map(|d| !d.is_empty())
        .unwrap_or(false);

    if !has_pending {
        if difficulty != AiDifficulty::Easy && should_offer_double(session, player) {
            return Some(BackgammonCommand::OfferDouble(OfferDoubleCommand {
                player,
            }));
        }
        return Some(BackgammonCommand::RollDice(RollDiceCommand { player }));
    }

    // 3. Mover fichas con los dados pendientes
    backgammon_ai_pick_move_with_randomness(session, player, difficulty, randomness_pct, seed)
        .map(BackgammonCommand::Move)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::build_backgammon_rules;
    use crate::new_backgammon_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);
    #[test]
    fn test_backgammon_ai_saca_ficha_de_barra_cuando_puede() {
        let mut session = Session::new_with_metadata(
            SessionId(1),
            "Backgammon",
            1,
            vec![P1, P2],
            build_backgammon_rules(),
        );

        // Inicializar TurnResource
        session
            .world_mut()
            .insert_resource(TurnResource(TurnOrder::new(vec![P1, P2])));
        session
            .world_mut()
            .resource_mut::<TurnResource>()
            .0
            .set_current_player(P1);

        // Aplicamos el setup manualmente
        {
            let world = session.world_mut();
            world.insert_resource(BoardResource::standard_setup(P1, P2));
            world.insert_resource(Sides {
                increasing: P1,
                decreasing: P2,
            });
            world.insert_resource(PendingDiceResource::default());

            // Colocar ficha en la barra para P1
            world.resource_mut::<BoardResource>().bar.insert(P1, 1);

            // Dados pendientes para P1: [3, 5]
            world
                .resource_mut::<PendingDiceResource>()
                .pending
                .insert(P1, vec![3, 5]);
        }

        let chosen = backgammon_ai_pick_move(&session, P1);
        assert!(chosen.is_some(), "La IA debe encontrar una jugada legal");
        let mv = chosen.unwrap();
        assert_eq!(mv.player, P1);
        assert!(
            mv.from.is_none(),
            "La IA debe sacar la ficha de la barra (from = None)"
        );
    }

    #[test]
    fn test_backgammon_ai_prefiere_crear_bloque_sobre_dejar_blot() {
        let mut session = new_backgammon_session(SessionId(1), 1, P1, P2);

        // Inicializar TurnResource
        session
            .world_mut()
            .insert_resource(TurnResource(TurnOrder::new(vec![P1, P2])));
        session
            .world_mut()
            .resource_mut::<TurnResource>()
            .0
            .set_current_player(P1);

        // Limpiamos el tablero para configurar una posición controlada
        {
            let mut board = session.world_mut().resource_mut::<BoardResource>();
            board.points = [0; POINTS];
            // P1 (increasing) tiene 1 ficha en punto 8 y 1 ficha en punto 10 (ambos en campo rival < 12)
            // Mover de 8 a 10 con dado 2 crea un bloque en 10 (2 fichas) y deja 8 vacío (sin blot) -> +5 bloque + 6 dado = +11
            board.points[8] = 1;
            board.points[10] = 1;

            // Ficha en punto 15 (propio campo) que con dado 2 iría a 17 (dejando blot en 17 o moviéndose)
            // Mover de 15 a 17 da +6 dado (sin bloque) = +6
            board.points[15] = 1;
        }

        // Dados pendientes: [2]
        session
            .world_mut()
            .resource_mut::<PendingDiceResource>()
            .pending
            .insert(P1, vec![2]);

        let chosen = backgammon_ai_pick_move(&session, P1);
        assert!(chosen.is_some(), "La IA debe encontrar una jugada");
        let mv = chosen.unwrap();
        assert_eq!(mv.player, P1);
        assert_eq!(
            mv.from,
            Some(8),
            "La IA debe preferir mover desde el punto 8 hacia el 10 para crear un bloque (+5) en lugar de otra jugada"
        );
        assert_eq!(mv.die, 2);
    }

    #[test]
    fn test_backgammon_ai_offers_double_with_advantage() {
        let mut session = new_backgammon_session(SessionId(1), 42, P1, P2);
        // Colocar ficha en barra de P2 para dar clara ventaja posicional a P1
        {
            let mut board = session.world_mut().resource_mut::<BoardResource>();
            board.bar.insert(P2, 1);
        }

        assert!(
            should_offer_double(&session, P1),
            "P1 debe detectar ventaja y proponer doblar"
        );

        let cmd = best_move(&session, P1, AiDifficulty::Hard).unwrap();
        assert_eq!(
            cmd,
            BackgammonCommand::OfferDouble(OfferDoubleCommand { player: P1 })
        );

        // En Easy, no dobla y opta por tirar dados
        let easy_cmd = best_move(&session, P1, AiDifficulty::Easy).unwrap();
        assert_eq!(
            easy_cmd,
            BackgammonCommand::RollDice(RollDiceCommand { player: P1 })
        );
    }

    #[test]
    fn test_backgammon_ai_does_not_double_when_crawford_or_behind() {
        let mut session = new_backgammon_session(SessionId(1), 42, P1, P2);
        {
            let mut match_state = session.world_mut().resource_mut::<MatchStateResource>();
            match_state.crawford_game = true;
        }

        assert!(
            !should_offer_double(&session, P1),
            "No debe doblar durante juego Crawford"
        );
    }
}
