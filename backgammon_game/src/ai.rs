use open_table_engine::prelude::*;

use crate::board::{BoardResource, Sides, POINTS};
use crate::commands::MoveCheckerCommand;
use crate::dice::PendingDiceResource;
use crate::resources::{DoublingCubeResource, MatchStateResource};

/// Clona el estado actual de la sesión de Backgammon para evaluar jugadas candidatas.
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
    if let Some(dice) = session.world().get_resource::<PendingDiceResource>() {
        new_session.world_mut().insert_resource(dice.clone());
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

/// Indica si una posición está en el campo/cuadrante del oponente.
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
/// Genera todos los movimientos legales mediante prueba-y-error sobre copias temporales
/// de la sesión, evalúa cada uno con la función heurística y elige el de mayor puntuación.
/// En caso de empate, elige al azar entre los mejores movimientos.
pub fn backgammon_ai_pick_move(session: &Session, player: PlayerId) -> Option<MoveCheckerCommand> {
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
        for from_idx in 0..POINTS {
            if board.points[from_idx] * owner_sign > 0 {
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

    let mut legal_moves_with_score: Vec<(MoveCheckerCommand, f32)> = Vec::new();

    for cmd in potential_moves {
        let mut trial = clone_backgammon_session(session);
        if trial.process_command(player, Box::new(cmd.clone())).is_ok() {
            let score = evaluate_backgammon_move(&trial, &cmd, player, sides);
            legal_moves_with_score.push((cmd, score));
        }
    }

    if legal_moves_with_score.is_empty() {
        return None;
    }

    let mut max_score = f32::NEG_INFINITY;
    for (_, score) in &legal_moves_with_score {
        if *score > max_score {
            max_score = *score;
        }
    }

    let best_moves: Vec<MoveCheckerCommand> = legal_moves_with_score
        .into_iter()
        .filter(|(_, s)| (*s - max_score).abs() < 1e-4)
        .map(|(cmd, _)| cmd)
        .collect();

    if best_moves.len() == 1 {
        Some(best_moves[0].clone())
    } else {
        use std::time::{SystemTime, UNIX_EPOCH};
        let seed = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.subsec_nanos() as usize)
            .unwrap_or(0);
        let idx = seed % best_moves.len();
        Some(best_moves[idx].clone())
    }
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
        session.world_mut().insert_resource(TurnResource(TurnOrder::new(vec![P1, P2])));
        session.world_mut().resource_mut::<TurnResource>().0.set_current_player(P1);

        // Aplicamos el setup manualmente
        {
            let world = session.world_mut();
            world.insert_resource(BoardResource::standard_setup(P1, P2));
            world.insert_resource(Sides { increasing: P1, decreasing: P2 });
            world.insert_resource(PendingDiceResource::default());
            
            // Colocar ficha en la barra para P1
            world.resource_mut::<BoardResource>().bar.insert(P1, 1);
            
            // Dados pendientes para P1: [3, 5]
            world.resource_mut::<PendingDiceResource>()
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
        session.world_mut().insert_resource(TurnResource(TurnOrder::new(vec![P1, P2])));
        session.world_mut().resource_mut::<TurnResource>().0.set_current_player(P1);

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
        session.world_mut()
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
}
