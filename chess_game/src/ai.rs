// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use open_table_engine::prelude::*;

use crate::board::{
    is_in_check, piece_moves, BoardResource, DrawOfferedResource, HalfMoveClockResource,
    PositionHistoryResource, Sides,
};
use crate::commands::MovePieceCommand;
use crate::legal_moves::ChessLegalMoveGenerator;
use crate::position::{PieceKind, Position};

/// Genera la lista completa de comandos de movimiento legales para `player` en la sesión dada.
pub fn generate_candidates(session: &Session, player: PlayerId) -> Vec<MovePieceCommand> {
    ChessLegalMoveGenerator::generate_moves(session.world(), player)
}

/// Función de evaluación estática posicional para el jugador `player`.
///
/// Componentes:
/// - Material: Peón=1, Caballo/Alfil=3, Torre=5, Dama=9, Rey=1000 (+ para `player`, - para oponente).
/// - Movilidad: +0.1 * num_movimientos_del_jugador.
/// - Control del centro: +0.15 por pieza en las 4 casillas centrales (d4, e4, d5, e5).
pub fn evaluate_position(session: &Session, player: PlayerId) -> f32 {
    if let Some(game_over) = session.world().get_resource::<GameOverResource>() {
        if game_over.0 {
            if let Some(winner) = session
                .world()
                .get_resource::<WinnerResource>()
                .and_then(|w| w.0)
            {
                return if winner == player {
                    100_000.0
                } else {
                    -100_000.0
                };
            } else {
                return 0.0;
            }
        }
    }

    let Some(board) = session.world().get_resource::<BoardResource>() else {
        return 0.0;
    };
    let Some(sides) = session.world().get_resource::<Sides>() else {
        return 0.0;
    };

    let opponent = sides.opponent_of(player);
    let mut score = 0.0f32;
    let mut player_moves = 0usize;

    // 1. Material + 2. Movilidad del jugador evaluado
    for (&pos, piece) in &board.pieces {
        let val = match piece.kind {
            PieceKind::Pawn => 1.0,
            PieceKind::Knight => 3.0,
            PieceKind::Bishop => 3.0,
            PieceKind::Rook => 5.0,
            PieceKind::Queen => 9.0,
            PieceKind::King => 1000.0,
        };

        if piece.owner == player {
            score += val;
            player_moves += piece_moves(board, sides, pos, *piece).len();
        } else if piece.owner == opponent {
            score -= val;
        }
    }

    score += 0.1 * (player_moves as f32);

    // 3. Control del centro: +0.15 por pieza en las 4 casillas centrales (d4, e4, d5, e5)
    // d4: (row 3, col 3), e4: (row 3, col 4), d5: (row 4, col 3), e5: (row 4, col 4)
    let center_squares = [
        Position::new(3, 3),
        Position::new(3, 4),
        Position::new(4, 3),
        Position::new(4, 4),
    ];
    for pos in center_squares {
        if let Some(piece) = board.get(pos) {
            if piece.owner == player {
                score += 0.15;
            } else if piece.owner == opponent {
                score -= 0.15;
            }
        }
    }

    score
}

/// Clona una sesión de ajedrez replicando su estado de recursos actual para simulación sin efectos secundarios.
fn clone_chess_session(session: &Session) -> Session {
    let (white, black) = session
        .world()
        .get_resource::<Sides>()
        .map(|s| (s.white, s.black))
        .unwrap_or((PlayerId(1), PlayerId(2)));

    let mut new_session = crate::new_chess_session(session.id, 0, white, black);

    if let Some(board) = session.world().get_resource::<BoardResource>() {
        new_session.world_mut().insert_resource(board.clone());
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
    if let Some(history) = session.world().get_resource::<PositionHistoryResource>() {
        new_session.world_mut().insert_resource(history.clone());
    }
    if let Some(clock) = session.world().get_resource::<HalfMoveClockResource>() {
        new_session.world_mut().insert_resource(clock.clone());
    }
    if let Some(draw) = session.world().get_resource::<DrawOfferedResource>() {
        new_session.world_mut().insert_resource(draw.clone());
    }

    new_session
}

/// Algoritmo Minimax con poda alfa-beta para búsqueda en árbol de jugadas de ajedrez.
pub fn minimax(
    session: &Session,
    depth: u8,
    mut alpha: f32,
    mut beta: f32,
    maximizing: bool,
    player: PlayerId,
) -> f32 {
    if let Some(game_over) = session.world().get_resource::<GameOverResource>() {
        if game_over.0 {
            if let Some(winner) = session
                .world()
                .get_resource::<WinnerResource>()
                .and_then(|w| w.0)
            {
                return if winner == player {
                    100_000.0
                } else {
                    -100_000.0
                };
            } else {
                return 0.0;
            }
        }
    }

    if depth == 0 {
        return evaluate_position(session, player);
    }

    let current = session.current_player();
    let mut candidates = generate_candidates(session, current);

    if candidates.is_empty() {
        let board = session.world().get_resource::<BoardResource>();
        let sides = session.world().get_resource::<Sides>();
        let in_check = match (board, sides) {
            (Some(b), Some(s)) => is_in_check(b, s, current),
            _ => false,
        };
        return if in_check {
            if current == player {
                f32::NEG_INFINITY
            } else {
                f32::INFINITY
            }
        } else {
            0.0
        };
    }

    if let Some(board) = session.world().get_resource::<BoardResource>() {
        candidates.sort_by_key(|cmd| if board.get(cmd.to).is_some() { 0 } else { 1 });
    }

    if maximizing {
        let mut max_eval = f32::NEG_INFINITY;
        for candidate in candidates {
            let mut next_session = clone_chess_session(session);
            let _ = next_session.process_command(current, Box::new(candidate));
            let eval = minimax(&next_session, depth - 1, alpha, beta, false, player);
            if eval > max_eval {
                max_eval = eval;
            }
            if eval > alpha {
                alpha = eval;
            }
            if beta <= alpha {
                break;
            }
        }
        max_eval
    } else {
        let mut min_eval = f32::INFINITY;
        for candidate in candidates {
            let mut next_session = clone_chess_session(session);
            let _ = next_session.process_command(current, Box::new(candidate));
            let eval = minimax(&next_session, depth - 1, alpha, beta, true, player);
            if eval < min_eval {
                min_eval = eval;
            }
            if eval < beta {
                beta = eval;
            }
            if beta <= alpha {
                break;
            }
        }
        min_eval
    }
}

/// Selecciona la mejor jugada legal para `player` en `session` usando Minimax con poda alfa-beta.
///
/// Parámetros:
/// - `session`: Sesión actual de la partida.
/// - `player`: Jugador que ejecuta la IA.
/// - `depth`: Profundidad máxima del árbol de búsqueda (recomendado 3).
///
/// Devuelve `None` si la partida terminó, si no es el turno de `player` o si no hay jugadas legales.
pub fn chess_ai_pick_move(
    session: &Session,
    player: PlayerId,
    depth: u8,
) -> Option<MovePieceCommand> {
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

    let mut candidates = generate_candidates(session, player);
    if candidates.is_empty() {
        return None;
    }

    // Ordenamiento heurístico básico: capturas primero para maximizar cortes alfa-beta
    if let Some(board) = session.world().get_resource::<BoardResource>() {
        candidates.sort_by_key(|cmd| {
            let is_capture = board.get(cmd.to).is_some();
            if is_capture {
                0
            } else {
                1
            }
        });
    }

    let depth = depth.max(1);
    let mut best_move = None;
    let mut best_score = f32::NEG_INFINITY;
    let mut alpha = f32::NEG_INFINITY;
    let beta = f32::INFINITY;

    for candidate in candidates {
        let mut next_session = clone_chess_session(session);
        if next_session
            .process_command(player, Box::new(candidate.clone()))
            .is_ok()
        {
            let score = if depth <= 1 {
                evaluate_position(&next_session, player)
            } else {
                minimax(&next_session, depth - 1, alpha, beta, false, player)
            };

            if score > best_score || best_move.is_none() {
                best_score = score;
                best_move = Some(candidate);
            }
            if score > alpha {
                alpha = score;
            }
        }
    }

    best_move
}

/// Selecciona la jugada de IA en Ajedrez parametrizada por `AiDifficulty`.
///
/// - En `Hard` y `Expert` (`difficulty.use_opening_book() == true`), consulta primero `OpeningBook`.
/// - Usa `difficulty.max_depth()` para Minimax.
/// - En `AiDifficulty::Easy`, comete un error subóptimo pero legal 1 de cada 4 jugadas (`tick % 4 == 0`).
pub fn best_move(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
) -> Option<MovePieceCommand> {
    best_move_with_randomness(session, player, difficulty, 0, 0)
}

/// Selecciona la jugada de IA en Ajedrez con factor de aleatoriedad (`randomness_pct`, `0..=100`)
/// aplicado sobre una banda de seguridad Top-K acotada por dificultad.
pub fn best_move_with_randomness(
    session: &Session,
    player: PlayerId,
    difficulty: AiDifficulty,
    randomness_pct: u8,
    seed: u64,
) -> Option<MovePieceCommand> {
    if difficulty.use_opening_book() {
        if let Some(book_cmd) = crate::opening_book::OpeningBook::lookup_session_with_randomness(
            session,
            player,
            difficulty,
            randomness_pct,
            seed,
        ) {
            return Some(book_cmd);
        }
    }
    if difficulty == AiDifficulty::Easy && randomness_pct == 0 {
        let candidates = generate_candidates(session, player);
        if candidates.len() > 1 && (session.current_tick().0 & 3) == 0 {
            return candidates.last().cloned();
        }
    }
    if randomness_pct == 0 {
        return chess_ai_pick_move(session, player, difficulty.max_depth());
    }

    if session
        .world()
        .get_resource::<GameOverResource>()
        .is_some_and(|r| r.0)
        || session.current_player() != player
    {
        return None;
    }

    let mut candidates = generate_candidates(session, player);
    if candidates.is_empty() {
        return None;
    }

    if let Some(board) = session.world().get_resource::<BoardResource>() {
        candidates.sort_by_key(|cmd| if board.get(cmd.to).is_some() { 0 } else { 1 });
    }

    let depth = difficulty.max_depth().max(1);
    let mut scored_moves = Vec::with_capacity(candidates.len());
    let mut scores = Vec::with_capacity(candidates.len());
    let alpha = f32::NEG_INFINITY;
    let beta = f32::INFINITY;

    for candidate in candidates {
        let mut next_session = clone_chess_session(session);
        if next_session
            .process_command(player, Box::new(candidate.clone()))
            .is_ok()
        {
            let score = if depth <= 1 {
                evaluate_position(&next_session, player)
            } else {
                minimax(&next_session, depth - 1, alpha, beta, false, player)
            };
            scored_moves.push(candidate);
            scores.push(score);
        }
    }

    let safety_band = match difficulty {
        AiDifficulty::Easy => 2.5,
        AiDifficulty::Medium => 1.1,
        AiDifficulty::Hard => 0.45,
        AiDifficulty::Expert => 0.25,
    };
    let idx = AiDifficulty::select_top_k_with_noise(
        &scores,
        randomness_pct,
        safety_band,
        seed ^ session.current_tick().0 ^ session.id.0,
    )?;
    scored_moves.into_iter().nth(idx)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fen::load_chess_position_from_fen;
    use crate::new_chess_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn test_chess_ai_best_move_con_dificultades() {
        let session = new_chess_session(SessionId(1), 42, P1, P2);
        for diff in [AiDifficulty::Easy, AiDifficulty::Medium, AiDifficulty::Hard] {
            let mv = best_move(&session, P1, diff);
            assert!(mv.is_some());
        }
    }

    #[test]
    fn test_chess_ai_devuelve_movimiento_en_posicion_inicial() {
        let session = new_chess_session(SessionId(1), 42, P1, P2);
        let mv = chess_ai_pick_move(&session, P1, 2);
        assert!(
            mv.is_some(),
            "La IA debe devolver un movimiento en la posición inicial"
        );

        let chosen = mv.unwrap();
        assert_eq!(chosen.player, P1);

        let mut test_session = clone_chess_session(&session);
        assert!(
            test_session.process_command(P1, Box::new(chosen)).is_ok(),
            "El movimiento de la IA debe ser válido en el motor de reglas"
        );
    }

    #[test]
    fn test_chess_ai_captura_reina_expuesta() {
        let mut session = new_chess_session(SessionId(1), 42, P1, P2);

        // Posición FEN: Torre blanca en d1 (row 0, col 3), Rey blanco en e1 (row 0, col 4).
        // Dama negra indefensa en d5 (row 4, col 3), Rey negro en e8 (row 7, col 4).
        // Juegan blancas ("w").
        let fen = "4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1";
        load_chess_position_from_fen(&mut session, fen).expect("FEN válido");

        let mv = chess_ai_pick_move(&session, P1, 2);
        assert!(mv.is_some(), "La IA debe encontrar jugada");

        let chosen = mv.unwrap();
        assert_eq!(chosen.player, P1);
        assert_eq!(
            chosen.from,
            Position::new(0, 3),
            "La torre blanca debe moverse desde d1"
        );
        assert_eq!(
            chosen.to,
            Position::new(4, 3),
            "La torre blanca debe capturar la dama en d5"
        );
    }

    #[test]
    fn test_chess_ai_none_cuando_partida_terminada() {
        let mut session = new_chess_session(SessionId(1), 42, P1, P2);
        session.world_mut().insert_resource(GameOverResource(true));

        assert!(chess_ai_pick_move(&session, P1, 2).is_none());
    }

    #[test]
    fn test_chess_ai_none_si_no_es_turno() {
        let session = new_chess_session(SessionId(1), 42, P1, P2);
        assert_eq!(session.current_player(), P1);
        assert!(chess_ai_pick_move(&session, P2, 2).is_none());
    }
}
