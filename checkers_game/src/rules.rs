use open_table_engine::prelude::*;

use crate::board::{BoardResource, MultiCaptureResource, Sides};
use crate::commands::{MovePieceCommand, ResignCommand};
use crate::events::{GameOverEvent, PieceMovedEvent};
use crate::legal_moves::CheckersLegalMoveGenerator;
use crate::position::Position;

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

fn has_any_capture(world: &BevyWorld, player: PlayerId) -> bool {
    let board = world.resource::<BoardResource>();
    let sides = world.resource::<Sides>();
    !board.get_all_available_captures(sides, player).is_empty()
}

pub fn build_checkers_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.set_legal_move_generator(Box::new(CheckersLegalMoveGenerator));

    rules.register::<MovePieceCommand, _>(|cmd, world| {
        if !world.contains_resource::<BoardResource>() || !world.contains_resource::<Sides>() {
            let players = world.resource::<TurnResource>().0.players();
            let p1 = players[0];
            let p2 = players.get(1).copied().unwrap_or(p1);
            let (board, sides) = crate::board::initial_board(p1, p2);
            world.insert_resource(board);
            world.insert_resource(sides);
        }
        if !world.contains_resource::<MultiCaptureResource>() {
            world.insert_resource(MultiCaptureResource::default());
        }
        if !world.contains_resource::<LegalMoveGeneratorResource>() {
            world.insert_resource(LegalMoveGeneratorResource(std::sync::Arc::new(CheckersLegalMoveGenerator)));
        }

        // 1. Le tiene que tocar a este jugador.
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        if !cmd.from.is_on_board() || !cmd.to.is_on_board() {
            return Err(invalid("la casilla está fuera del tablero"));
        }
        if !cmd.from.is_dark_square() || !cmd.to.is_dark_square() {
            return Err(invalid("damas solo se juega en casillas oscuras"));
        }

        // Si hay una captura múltiple activa, debe moverse con la misma ficha.
        let active_jumper = world
            .get_resource::<MultiCaptureResource>()
            .and_then(|m| m.active_piece);
        if let Some(required_from) = active_jumper {
            if cmd.from != required_from {
                return Err(invalid(
                    "debés continuar la captura múltiple con la misma ficha",
                ));
            }
        }

        let opponent = world.resource::<Sides>().opponent_of(cmd.player);
        let forward = world.resource::<Sides>().forward_direction(cmd.player);
        let promotion_row = world.resource::<Sides>().promotion_row(cmd.player);
        let sides_snapshot = *world.resource::<Sides>();
        let captures_available = has_any_capture(world, cmd.player);

        let mut board = world.resource_mut::<BoardResource>();

        let piece = board
            .get(cmd.from)
            .ok_or_else(|| invalid("no hay ninguna ficha en la casilla de origen"))?;
        if piece.owner != cmd.player {
            return Err(invalid("esa ficha no es tuya"));
        }
        if board.get(cmd.to).is_some() {
            return Err(invalid("la casilla de destino ya está ocupada"));
        }

        let (row_diff, col_diff) = cmd.from.diff(cmd.to);
        if col_diff.abs() != row_diff.abs() {
            return Err(invalid("el movimiento tiene que ser diagonal"));
        }

        if captures_available && row_diff.abs() != 2 {
            return Err(invalid("hay capturas disponibles: la captura es obligatoria"));
        }

        let mut captured_pos: Option<Position> = None;

        match row_diff.abs() {
            1 => {
                if !piece.is_king && row_diff.signum() != forward {
                    return Err(invalid(
                        "esa ficha todavía no es dama: solo puede avanzar hacia adelante",
                    ));
                }
            }
            2 => {
                if !piece.is_king && row_diff.signum() != forward {
                    return Err(invalid(
                        "esa ficha todavía no es dama: solo puede capturar hacia adelante",
                    ));
                }
                let mid = cmd.from.midpoint(cmd.to);
                let mid_piece = board
                    .get(mid)
                    .ok_or_else(|| invalid("no hay ninguna ficha para saltar en el medio"))?;
                if mid_piece.owner == cmd.player {
                    return Err(invalid("no podés saltar tu propia ficha"));
                }
                captured_pos = Some(mid);
            }
            _ => return Err(invalid("las damas se mueven 1 casilla, o 2 al capturar")),
        }

        // --- Aplicar el movimiento ---
        board.set(cmd.from, None);
        if let Some(captured) = captured_pos {
            board.set(captured, None);
        }
        let promoted = !piece.is_king && cmd.to.row == promotion_row;
        board.set(
            cmd.to,
            Some(crate::piece::Piece {
                owner: piece.owner,
                is_king: piece.is_king || promoted,
            }),
        );

        // Escanear si desde la casilla de llegada (cmd.to) la misma ficha tiene capturas adicionales disponibles.
        // Si es así, se mantiene el turno del jugador y se registra la posición requerida (must_use_piece).
        let has_further_capture = captured_pos.is_some()
            && !promoted
            && !board.get_available_captures_for_piece(&sides_snapshot, cmd.player, cmd.to).is_empty();

        let counts = board.count_pieces();
        drop(board); // soltar el borrow antes de tocar otros resources

        if let Some(mut multi) = world.get_resource_mut::<MultiCaptureResource>() {
            if has_further_capture {
                multi.active_piece = Some(cmd.to);
            } else {
                multi.active_piece = None;
            }
        } else if has_further_capture {
            world.insert_resource(MultiCaptureResource {
                active_piece: Some(cmd.to),
            });
        }

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            captured: captured_pos,
            promoted,
        })];

        // Condición de victoria: si el rival se quedó sin fichas.
        let opponent_pieces_left = counts
            .iter()
            .find(|(id, _)| *id == opponent)
            .map(|(_, count)| *count)
            .unwrap_or(0);
        if opponent_pieces_left == 0 {
            events.push(Box::new(GameOverEvent { winner: cmd.player }));
        }

        if !has_further_capture {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(invalid("no eres un jugador de esta partida"));
        }
        let opponent = players.into_iter().find(|&p| p != cmd.player).unwrap_or(cmd.player);
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent { winner: opponent })])
    });

    rules
}
