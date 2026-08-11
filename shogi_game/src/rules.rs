use open_table_engine::prelude::*;
use crate::board::{BoardResource, Piece, PieceKind};
use crate::commands::{MovePieceCommand, DropPieceCommand, ResignCommand};
use crate::events::{PieceMovedEvent, PieceDroppedEvent, GameOverEvent};
use crate::movement::{is_legal_move, is_legal_drop, can_promote, must_promote, is_checkmate, is_in_check};

pub fn build_shogi_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<MovePieceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand { reason: "Not your turn".into() });
        }

        let board_backup = world.resource::<BoardResource>().clone();

        let (promoted, captured_kind) = {
            let mut board = world.resource_mut::<BoardResource>();

            if !is_legal_move(&board, cmd.from, cmd.to, cmd.player) {
                return Err(EngineError::InvalidCommand { reason: "Illegal move for this piece".into() });
            }

            let piece = board.squares.get(&cmd.from).copied().unwrap();
            let target = board.squares.get(&cmd.to).copied();

            let mut captured_kind = None;
            if let Some(t) = target {
                let hand_piece = match t.kind {
                    PieceKind::PromotedPawn => PieceKind::Pawn,
                    PieceKind::PromotedRook => PieceKind::Rook,
                    PieceKind::PromotedBishop => PieceKind::Bishop,
                    PieceKind::PromotedSilver => PieceKind::Silver,
                    PieceKind::PromotedLance => PieceKind::Lance,
                    PieceKind::PromotedKnight => PieceKind::Knight,
                    k => k,
                };
                board.hands.get_mut(&cmd.player).unwrap().push(hand_piece);
                captured_kind = Some(hand_piece);
            }

            let can_pro = can_promote(&board, piece.kind, cmd.from, cmd.to, cmd.player);
            let must_pro = must_promote(&board, piece.kind, cmd.to, cmd.player);

            if must_pro && !cmd.promote {
                return Err(EngineError::InvalidCommand { reason: "Must promote this piece".into() });
            }

            let mut moving_piece = piece;
            if cmd.promote {
                if !can_pro {
                    return Err(EngineError::InvalidCommand { reason: "Cannot promote here".into() });
                }
                moving_piece.kind = match moving_piece.kind {
                    PieceKind::Pawn => PieceKind::PromotedPawn,
                    PieceKind::Silver => PieceKind::PromotedSilver,
                    PieceKind::Knight => PieceKind::PromotedKnight,
                    PieceKind::Lance => PieceKind::PromotedLance,
                    PieceKind::Bishop => PieceKind::PromotedBishop,
                    PieceKind::Rook => PieceKind::PromotedRook,
                    k => k,
                };
            }

            board.squares.remove(&cmd.from);
            board.squares.insert(cmd.to, moving_piece);
            (cmd.promote, captured_kind)
        }; // board dropped here

        if is_in_check(world.resource::<BoardResource>(), cmd.player) {
            *world.resource_mut::<BoardResource>() = board_backup;
            return Err(EngineError::InvalidCommand { reason: "Move leaves king in check".into() });
        }

        world.resource_mut::<TurnResource>().0.advance();

        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceMovedEvent {
            player: cmd.player,
            from: cmd.from,
            to: cmd.to,
            promoted,
            captured: captured_kind,
        })];

        let opponent = {
            let board = world.resource::<BoardResource>();
            if cmd.player == board.sente { board.gote } else { board.sente }
        };

        if is_checkmate(world.resource::<BoardResource>(), opponent) {
            events.push(Box::new(GameOverEvent { winner: Some(cmd.player) }));
        }

        Ok(events)
    });

    rules.register::<DropPieceCommand, _>(|cmd, world| {
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand { reason: "Not your turn".into() });
        }

        let board_backup = world.resource::<BoardResource>().clone();

        let piece_placed = {
            let mut board = world.resource_mut::<BoardResource>();

            if !is_legal_drop(&board, cmd.piece, cmd.to, cmd.player) {
                return Err(EngineError::InvalidCommand {
                    reason: "Illegal drop (occupied, nifu, or no legal moves)".into(),
                });
            }

            if cmd.piece == PieceKind::Pawn {
                let opponent = if cmd.player == board.sente { board.gote } else { board.sente };
                let mut test_board = board.clone();
                test_board.squares.insert(cmd.to, Piece { kind: PieceKind::Pawn, owner: cmd.player });
                if is_checkmate(&test_board, opponent) {
                    return Err(EngineError::InvalidCommand {
                        reason: "Uchifuzume: Pawn drop causing checkmate is illegal".into(),
                    });
                }
            }

            let hand = board.hands.get_mut(&cmd.player).unwrap();
            if let Some(pos) = hand.iter().position(|&p| p == cmd.piece) {
                hand.remove(pos);
                board.squares.insert(cmd.to, Piece { kind: cmd.piece, owner: cmd.player });
                true
            } else {
                false
            }
        }; // board dropped here

        if !piece_placed {
            return Err(EngineError::InvalidCommand { reason: "Piece not in hand".into() });
        }

        if is_in_check(world.resource::<BoardResource>(), cmd.player) {
            *world.resource_mut::<BoardResource>() = board_backup;
            return Err(EngineError::InvalidCommand { reason: "Drop leaves king in check".into() });
        }

        world.resource_mut::<TurnResource>().0.advance();
        
        let mut events: Vec<Box<dyn Event>> = vec![Box::new(PieceDroppedEvent {
            player: cmd.player,
            piece: cmd.piece,
            to: cmd.to,
        })];

        let opponent = {
            let board = world.resource::<BoardResource>();
            if cmd.player == board.sente { board.gote } else { board.sente }
        };

        if is_checkmate(world.resource::<BoardResource>(), opponent) {
            events.push(Box::new(GameOverEvent { winner: Some(cmd.player) }));
        }

        Ok(events)
    });

    rules.register::<ResignCommand, _>(|cmd, world| {
        let players = world.resource::<TurnResource>().0.players().to_vec();
        if !players.contains(&cmd.player) {
            return Err(EngineError::InvalidCommand { reason: "Not a player in this session".into() });
        }
        let opponent = players.into_iter().find(|&p| p != cmd.player).unwrap_or(cmd.player);
        world.insert_resource(GameOverResource(true));
        world.insert_resource(WinnerResource(Some(opponent)));
        Ok(vec![Box::new(GameOverEvent { winner: Some(opponent) })])
    });

    rules
}
