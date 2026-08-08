use open_table_engine::prelude::*;

use crate::board::{has_any_legal_move, is_in_check, is_legal_move, BoardResource, DrawOfferedResource, HalfMoveClockResource, PositionHistoryResource, Sides};
use crate::commands::{AcceptDrawCommand, MovePieceCommand, OfferDrawCommand, ResignCommand};
use crate::events::{GameOverEvent, PieceMovedEvent};
use crate::position::{PieceKind, Position};

fn invalid(reason: impl Into<String>) -> EngineError {
    EngineError::InvalidCommand {
        reason: reason.into(),
    }
}

fn is_insufficient_material(board: &BoardResource) -> bool {
    let pieces = &board.pieces;
    let total = pieces.len();
    if total < 2 {
        return false;
    }

    let mut kings = 0;
    let mut bishops = Vec::new();
    let mut knights = 0;
    let mut others = 0;

    for (pos, piece) in pieces {
        match piece.kind {
            PieceKind::King => kings += 1,
            PieceKind::Bishop => bishops.push(pos),
            PieceKind::Knight => knights += 1,
            _ => others += 1,
        }
    }

    if kings != 2 || others > 0 {
        return false;
    }

    if total == 2 {
        return true;
    }

    if total == 3 {
        if bishops.len() == 1 || knights == 1 {
            return true;
        }
    }

    if total == 4 {
        if bishops.len() == 2 {
            let color1 = (bishops[0].row + bishops[0].col) % 2;
            let color2 = (bishops[1].row + bishops[1].col) % 2;
            if color1 == color2 {
                return true;
            }
        }
    }

    false
}

pub fn build_chess_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();
    rules.set_legal_move_generator(Box::new(crate::legal_moves::ChessLegalMoveGenerator));

    rules.register::<MovePieceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno"));
        }

        let sides = {
            let s = world.resource::<Sides>();
            Sides {
                white: s.white,
                black: s.black,
            }
        };
        let opponent = sides.opponent_of(cmd.player);

        let mut board = world.resource_mut::<BoardResource>();

        let piece = board
            .get(cmd.from)
            .ok_or_else(|| invalid("no hay ninguna pieza en la casilla de origen"))?;
        if piece.owner != cmd.player {
            return Err(invalid("esa pieza no es tuya"));
        }

        if !is_legal_move(&board, &sides, cmd.player, cmd.from, cmd.to) {
            return Err(invalid(
                "ese movimiento no es legal (inválido para esa pieza, o te dejaría en jaque)",
            ));
        }

        // Detectar si es en passant
        let is_en_passant = piece.kind == PieceKind::Pawn
            && board.en_passant_target == Some(cmd.to)
            && cmd.from.col != cmd.to.col
            && board.get(cmd.to).is_none();

        // Detectar si es enroque
        let castled = piece.kind == PieceKind::King && (cmd.from.col as i32 - cmd.to.col as i32).abs() == 2;

        let mut captured = board.get(cmd.to).map(|p| p.kind);

        if is_en_passant {
            captured = Some(PieceKind::Pawn);
            board.pieces.remove(&Position::new(cmd.from.row, cmd.to.col));
        } else if castled {
            if cmd.to.col == 6 {
                if let Some(rook) = board.pieces.remove(&Position::new(cmd.from.row, 7)) {
                    board.pieces.insert(Position::new(cmd.from.row, 5), rook);
                }
            } else if cmd.to.col == 2 {
                if let Some(rook) = board.pieces.remove(&Position::new(cmd.from.row, 0)) {
                    board.pieces.insert(Position::new(cmd.from.row, 3), rook);
                }
            }
        }

        board.pieces.remove(&cmd.from);

        let mut moved_piece = piece;
        let promoted = piece.kind == PieceKind::Pawn && cmd.to.row == sides.promotion_row(cmd.player);
        let mut promoted_to = None;

        if promoted {
            let target_kind = match cmd.promote_to {
                Some(k @ (PieceKind::Queen | PieceKind::Rook | PieceKind::Bishop | PieceKind::Knight)) => k,
                Some(_) => {
                    return Err(invalid(
                        "la coronación debe ser a dama, torre, alfil o caballo",
                    ));
                }
                None => PieceKind::Queen,
            };
            moved_piece.kind = target_kind;
            promoted_to = Some(target_kind);
        }

        board.pieces.insert(cmd.to, moved_piece);

        // Actualizar en_passant_target
        if piece.kind == PieceKind::Pawn && (cmd.from.row as i32 - cmd.to.row as i32).abs() == 2 {
            let passed_row = ((cmd.from.row as u16 + cmd.to.row as u16) / 2) as u8;
            board.en_passant_target = Some(Position::new(passed_row, cmd.from.col));
        } else {
            board.en_passant_target = None;
        }

        // Actualizar banderas de movimiento
        if piece.kind == PieceKind::King {
            if cmd.player == sides.white {
                board.white_king_moved = true;
            } else {
                board.black_king_moved = true;
            }
        } else if piece.kind == PieceKind::Rook {
            if cmd.player == sides.white {
                if cmd.from == Position::new(0, 0) {
                    board.white_rook_a_moved = true;
                } else if cmd.from == Position::new(0, 7) {
                    board.white_rook_h_moved = true;
                }
            } else {
                if cmd.from == Position::new(7, 0) {
                    board.black_rook_a_moved = true;
                } else if cmd.from == Position::new(7, 7) {
                    board.black_rook_h_moved = true;
                }
            }
        }

        if cmd.to == Position::new(0, 0) {
            board.white_rook_a_moved = true;
        } else if cmd.to == Position::new(0, 7) {
            board.white_rook_h_moved = true;
        } else if cmd.to == Position::new(7, 0) {
            board.black_rook_a_moved = true;
        } else if cmd.to == Position::new(7, 7) {
            board.black_rook_h_moved = true;
        }

        let opponent_in_check = is_in_check(&board, &sides, opponent);
        let opponent_has_moves = has_any_legal_move(&board, &sides, opponent);

        let insufficient_material = is_insufficient_material(&board);
        let new_hash = board.compute_hash(opponent);

        drop(board);

        let is_threefold = if let Some(mut history) = world.get_resource_mut::<PositionHistoryResource>() {
            let count = history.history.entry(new_hash).or_insert(0);
            *count += 1;
            *count >= 3
        } else {
            let mut history = PositionHistoryResource::default();
            history.history.insert(new_hash, 1);
            world.insert_resource(history);
            false
        };

        let is_fifty_moves = if let Some(mut clock) = world.get_resource_mut::<HalfMoveClockResource>() {
            if captured.is_some() || piece.kind == PieceKind::Pawn {
                clock.0 = 0;
                false
            } else {
                clock.0 += 1;
                clock.0 >= 100
            }
        } else {
            let new_val = if captured.is_some() || piece.kind == PieceKind::Pawn { 0 } else { 1 };
            world.insert_resource(HalfMoveClockResource(new_val));
            new_val >= 100
        };

        // Cualquier movimiento (comando que no es oferta/aceptación de tablas) limpia la oferta pendiente
        if let Some(mut draw_offered) = world.get_resource_mut::<DrawOfferedResource>() {
            draw_offered.0 = None;
        }

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            captured,
            promoted,
            opponent_in_check,
            castled,
            promoted_to,
        })];

        if !opponent_has_moves {
            let winner = if opponent_in_check { Some(cmd.player) } else { None };
            events.push(Box::new(GameOverEvent { winner }));
            world.insert_resource(GameOverResource(true));
        } else if is_threefold || is_fifty_moves || insufficient_material {
            events.push(Box::new(GameOverEvent { winner: None }));
            world.insert_resource(GameOverResource(true));
        }

        world.resource_mut::<TurnResource>().0.advance();

        Ok(events)
    });

    rules.register::<OfferDrawCommand, _>(|cmd, world| {
        let sides = world.resource::<Sides>();
        if cmd.player != sides.white && cmd.player != sides.black {
            return Err(invalid("no eres un jugador de esta partida"));
        }
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(invalid("no es tu turno para ofrecer tablas"));
        }

        if let Some(mut draw_offered) = world.get_resource_mut::<DrawOfferedResource>() {
            draw_offered.0 = Some(cmd.player);
        } else {
            world.insert_resource(DrawOfferedResource(Some(cmd.player)));
        }

        Ok(vec![])
    });

    rules.register::<AcceptDrawCommand, _>(|cmd, world| {
        let sides = world.resource::<Sides>();
        if cmd.player != sides.white && cmd.player != sides.black {
            return Err(invalid("no eres un jugador de esta partida"));
        }

        let offered_by = world
            .get_resource::<DrawOfferedResource>()
            .and_then(|r| r.0);

        match offered_by {
            Some(offerer) if offerer != cmd.player => {
                if let Some(mut draw_offered) = world.get_resource_mut::<DrawOfferedResource>() {
                    draw_offered.0 = None;
                }
                world.insert_resource(GameOverResource(true));
                Ok(vec![Box::new(GameOverEvent { winner: None })])
            }
            _ => Err(invalid("no hay una oferta de tablas pendiente para ti")),
        }
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(invalid("no eres un jugador de esta partida"));
        }
        let opponent = players.into_iter().find(|&p| p != cmd.player).unwrap_or(cmd.player);
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent { winner: Some(opponent) })])
    });

    rules
}
