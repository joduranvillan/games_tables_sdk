// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Libro de aperturas ECO compacto (A00-E99) indexado por hash Zobrist de 64 bits.
//!
//! En los niveles `AiDifficulty::Hard` y `AiDifficulty::Expert`, la IA consulta
//! `OpeningBook::lookup(zobrist_hash)` para responder instantáneamente con aperturas
//! teóricas ponderadas por frecuencia de uso.

use std::collections::HashMap;
use std::sync::OnceLock;

use open_table_engine::prelude::*;

use crate::board::{BoardResource, Sides};
use crate::commands::MovePieceCommand;
use crate::position::{PieceKind, Position};

/// Capacidad máxima de posiciones en el libro compacto para mantener el binario < 100 KB.
pub const MAX_BOOK_POSITIONS: usize = 5000;

/// Bytes binarios compactos del libro ECO embebidos en tiempo de compilación.
pub const COMPACT_BOOK_BYTES: &[u8] = include_bytes!("../data/openings_eco_compact.bin");

/// Movimiento de libro ponderado por frecuencia de uso en partidas teóricas ECO.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChessMove {
    /// Casilla de origen.
    pub from: Position,
    /// Casilla de destino.
    pub to: Position,
    /// Peso / frecuencia relativa en el repertorio ECO.
    pub weight: u16,
}

impl ChessMove {
    /// Convierte el movimiento de libro en un `MovePieceCommand` ejecutable para `player`.
    pub fn to_command(self, player: PlayerId) -> MovePieceCommand {
        MovePieceCommand {
            player,
            from: self.from,
            to: self.to,
            promote_to: None,
        }
    }
}

/// Calcula el hash Zobrist determinista de 64 bits para una posición de ajedrez.
pub fn compute_zobrist_hash(board: &BoardResource, sides: &Sides, turn: PlayerId) -> u64 {
    fn splitmix64(mut x: u64) -> u64 {
        x = x.wrapping_add(0x9e3779b97f4a7c15);
        x = (x ^ (x >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        x = (x ^ (x >> 27)).wrapping_mul(0x94d049bb133111eb);
        x ^ (x >> 31)
    }

    let mut hash = 0u64;
    for (&pos, piece) in &board.pieces {
        let color_idx: u64 = if piece.owner == sides.white { 0 } else { 1 };
        let kind_idx: u64 = match piece.kind {
            PieceKind::Pawn => 1,
            PieceKind::Knight => 2,
            PieceKind::Bishop => 3,
            PieceKind::Rook => 4,
            PieceKind::Queen => 5,
            PieceKind::King => 6,
        };
        let square_idx = u64::from(pos.row) * 8 + u64::from(pos.col);
        let key_seed = (square_idx << 8) | (color_idx << 4) | kind_idx;
        hash ^= splitmix64(key_seed);
    }

    if turn == sides.black {
        hash ^= splitmix64(0xFFFF_0001);
    }
    hash
}

/// Libro de aperturas ECO (A00-E99) indexado por hash Zobrist.
pub struct OpeningBook {
    entries: HashMap<u64, Vec<ChessMove>>,
}

static GLOBAL_BOOK: OnceLock<OpeningBook> = OnceLock::new();

impl OpeningBook {
    /// Devuelve la instancia global del libro de aperturas cargada en memoria.
    pub fn global() -> &'static Self {
        GLOBAL_BOOK.get_or_init(Self::load_default)
    }

    /// Busca el mejor movimiento teórico (mayor peso) para `zobrist_hash`.
    pub fn lookup(zobrist_hash: u64) -> Option<ChessMove> {
        let list = Self::global().entries.get(&zobrist_hash)?;
        list.iter().copied().max_by_key(|m| m.weight)
    }

    /// Consulta el libro sólo si `difficulty.use_opening_book()` es `true`; de lo contrario retorna `None`.
    /// En `AiDifficulty::Hard` elige la línea principal (mayor peso) y en `AiDifficulty::Expert`
    /// selecciona la variante magistral alternativa de alto peso cuando existen múltiples líneas teóricas.
    pub fn lookup_with_difficulty(
        zobrist_hash: u64,
        difficulty: AiDifficulty,
    ) -> Option<ChessMove> {
        if !difficulty.use_opening_book() {
            return None;
        }
        let list = Self::global().entries.get(&zobrist_hash)?;
        if list.is_empty() {
            return None;
        }
        let mut sorted = list.clone();
        sorted.sort_by(|a, b| b.weight.cmp(&a.weight));
        if difficulty == AiDifficulty::Expert && sorted.len() > 1 {
            Some(sorted[1])
        } else {
            Some(sorted[0])
        }
    }

    /// Consulta el libro para la sesión actual si `difficulty.use_opening_book()` está activo.
    pub fn lookup_session(
        session: &Session,
        player: PlayerId,
        difficulty: AiDifficulty,
    ) -> Option<MovePieceCommand> {
        if !difficulty.use_opening_book() {
            return None;
        }
        let board = session.world().get_resource::<BoardResource>()?;
        let sides = session.world().get_resource::<Sides>()?;
        let zh = compute_zobrist_hash(board, sides, player);
        let book_mv = Self::lookup_with_difficulty(zh, difficulty)?;
        Some(book_mv.to_command(player))
    }

    fn load_default() -> Self {
        let mut entries: HashMap<u64, Vec<ChessMove>> = HashMap::new();

        // 1. Decodificar entradas del archivo binario compacto (registros de 14 bytes)
        for chunk in COMPACT_BOOK_BYTES.chunks_exact(14) {
            if entries.len() >= MAX_BOOK_POSITIONS {
                break;
            }
            let zh = u64::from_le_bytes([
                chunk[0], chunk[1], chunk[2], chunk[3], chunk[4], chunk[5], chunk[6], chunk[7],
            ]);
            let from = Position::new(chunk[8], chunk[9]);
            let to = Position::new(chunk[10], chunk[11]);
            let weight = u16::from_le_bytes([chunk[12], chunk[13]]);
            if from.row < 8 && from.col < 8 && to.row < 8 && to.col < 8 {
                entries
                    .entry(zh)
                    .or_default()
                    .push(ChessMove { from, to, weight });
            }
        }

        // 2. Poblar líneas ECO principales (A00-E99) sobre el hash Zobrist canónico del motor
        type EcoCoord = [u8; 2];
        type EcoMovePair = (EcoCoord, EcoCoord);
        type EcoLine<'a> = (&'a [EcoMovePair], u16);

        let p1 = PlayerId(1);
        let p2 = PlayerId(2);
        let eco_lines: &[EcoLine<'_>] = &[
            // C50 Giuoco Piano / Italiana: 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5
            (
                &[
                    ([1, 4], [3, 4]),
                    ([6, 4], [4, 4]),
                    ([0, 6], [2, 5]),
                    ([7, 1], [5, 2]),
                    ([0, 5], [3, 2]),
                    ([7, 5], [4, 2]),
                ],
                100,
            ),
            // C60 Ruy López / Española: 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6
            (
                &[
                    ([1, 4], [3, 4]),
                    ([6, 4], [4, 4]),
                    ([0, 6], [2, 5]),
                    ([7, 1], [5, 2]),
                    ([0, 5], [4, 1]),
                    ([6, 0], [5, 0]),
                ],
                95,
            ),
            // B20 Defensa Siciliana: 1.e4 c5 2.Nf3 d6 3.d4 cxd4
            (
                &[
                    ([1, 4], [3, 4]),
                    ([6, 2], [4, 2]),
                    ([0, 6], [2, 5]),
                    ([6, 3], [5, 3]),
                    ([1, 3], [3, 3]),
                    ([4, 2], [3, 3]),
                ],
                90,
            ),
            // D06 Gambito de Dama: 1.d4 d5 2.c4 e6 3.Nc3 Nf6
            (
                &[
                    ([1, 3], [3, 3]),
                    ([6, 3], [4, 3]),
                    ([1, 2], [3, 2]),
                    ([6, 4], [5, 4]),
                    ([0, 1], [2, 2]),
                    ([7, 6], [5, 5]),
                ],
                88,
            ),
            // E60 Defensa India de Rey: 1.d4 Nf6 2.c4 g6 3.Nc3 Bg7
            (
                &[
                    ([1, 3], [3, 3]),
                    ([7, 6], [5, 5]),
                    ([1, 2], [3, 2]),
                    ([6, 6], [5, 6]),
                    ([0, 1], [2, 2]),
                    ([7, 5], [6, 6]),
                ],
                85,
            ),
        ];

        for &(moves, base_weight) in eco_lines {
            let mut sim = crate::new_chess_session(SessionId(999), 1, p1, p2);
            for (ply, &([fr, fc], [tr, tc])) in moves.iter().enumerate() {
                if entries.len() >= MAX_BOOK_POSITIONS {
                    break;
                }
                let turn = sim.current_player();
                let zh = {
                    let b = sim.world().get_resource::<BoardResource>().unwrap();
                    let s = sim.world().get_resource::<Sides>().unwrap();
                    compute_zobrist_hash(b, s, turn)
                };
                let candidate = ChessMove {
                    from: Position::new(fr, fc),
                    to: Position::new(tr, tc),
                    weight: base_weight.saturating_sub(ply as u16),
                };
                let list = entries.entry(zh).or_default();
                if !list
                    .iter()
                    .any(|m| m.from == candidate.from && m.to == candidate.to)
                {
                    list.push(candidate);
                }
                let _ = sim.process_command(turn, Box::new(candidate.to_command(turn)));
            }
        }

        Self { entries }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::new_chess_session;

    const P1: PlayerId = PlayerId(1);
    const P2: PlayerId = PlayerId(2);

    #[test]
    fn test_opening_book_lookup_initial_position() {
        let session = new_chess_session(SessionId(1), 1, P1, P2);
        let board = session.world().get_resource::<BoardResource>().unwrap();
        let sides = session.world().get_resource::<Sides>().unwrap();
        let zh = compute_zobrist_hash(board, sides, P1);

        let mv = OpeningBook::lookup(zh);
        assert!(
            mv.is_some(),
            "La posición inicial debe estar cubierta en el OpeningBook"
        );
        let chosen = mv.unwrap();
        // 1.e4 (row 1, col 4 -> row 3, col 4) tiene el mayor peso (100)
        assert_eq!(chosen.from, Position::new(1, 4));
        assert_eq!(chosen.to, Position::new(3, 4));
    }

    #[test]
    fn test_opening_book_respects_difficulty_flag() {
        let session = new_chess_session(SessionId(1), 1, P1, P2);
        assert!(OpeningBook::lookup_session(&session, P1, AiDifficulty::Easy).is_none());
        assert!(OpeningBook::lookup_session(&session, P1, AiDifficulty::Medium).is_none());
        assert!(OpeningBook::lookup_session(&session, P1, AiDifficulty::Hard).is_some());
        assert!(OpeningBook::lookup_session(&session, P1, AiDifficulty::Expert).is_some());
    }

    #[test]
    fn test_opening_book_binary_size_under_100kb() {
        assert!(
            !COMPACT_BOOK_BYTES.is_empty(),
            "El archivo binario de aperturas no debe estar vacío"
        );
        assert!(
            COMPACT_BOOK_BYTES.len() < 100 * 1024,
            "El binario compacto debe pesar menos de 100 KB"
        );
    }
}
