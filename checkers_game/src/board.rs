use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

use crate::piece::Piece;
use crate::position::Position;

#[derive(GameResource, Default, Clone, Debug)]
pub struct MultiCaptureResource {
    pub active_piece: Option<Position>,
}

#[derive(GameResource, Default, Clone, Copy, Debug, PartialEq, Eq)]
pub struct DrawClockResource {
    pub half_moves_without_capture_or_promotion: u32,
}

/// El tablero completo. 8x8 aunque solo se usen las 32 casillas oscuras
/// (las claras quedan siempre en `None`) — simplifica el código de
/// indexado a costa de un poco de memoria desperdiciada, precio
/// razonable para un juego de referencia.
#[derive(GameResource, Clone)]
pub struct BoardResource {
    pub cells: [[Option<Piece>; 8]; 8],
}

impl BoardResource {
    pub fn get(&self, pos: Position) -> Option<Piece> {
        self.cells[pos.row as usize][pos.col as usize]
    }

    pub fn set(&mut self, pos: Position, piece: Option<Piece>) {
        self.cells[pos.row as usize][pos.col as usize] = piece;
    }

    pub fn get_available_captures_for_piece(
        &self,
        sides: &Sides,
        player: PlayerId,
        from: Position,
    ) -> Vec<Position> {
        let Some(piece) = self.get(from) else {
            return Vec::new();
        };
        if piece.owner != player {
            return Vec::new();
        }

        let opponent = sides.opponent_of(player);
        let forward = sides.forward_direction(player);
        let mut captures = Vec::new();

        let directions: &[(i8, i8)] = if piece.is_king {
            &[(-1, -1), (-1, 1), (1, -1), (1, 1)]
        } else if forward == 1 {
            &[(1, -1), (1, 1)]
        } else {
            &[(-1, -1), (-1, 1)]
        };

        for &(dr, dc) in directions {
            let mid_row = from.row as i8 + dr;
            let mid_col = from.col as i8 + dc;
            let land_row = from.row as i8 + 2 * dr;
            let land_col = from.col as i8 + 2 * dc;

            if (0..8).contains(&land_row) && (0..8).contains(&land_col) {
                let mid_pos = Position::new(mid_row as u8, mid_col as u8);
                let land_pos = Position::new(land_row as u8, land_col as u8);

                if land_pos.is_dark_square() && self.get(land_pos).is_none() {
                    if let Some(mid_piece) = self.get(mid_pos) {
                        if mid_piece.owner == opponent {
                            captures.push(land_pos);
                        }
                    }
                }
            }
        }

        captures
    }

    pub fn get_all_available_captures(
        &self,
        sides: &Sides,
        player: PlayerId,
    ) -> Vec<(Position, Position)> {
        let mut all_captures = Vec::new();
        for row in 0..8u8 {
            for col in 0..8u8 {
                let from = Position::new(row, col);
                if let Some(piece) = self.get(from) {
                    if piece.owner == player {
                        for to in self.get_available_captures_for_piece(sides, player, from) {
                            all_captures.push((from, to));
                        }
                    }
                }
            }
        }
        all_captures
    }

    /// Devuelve todos los movimientos legales `(from, to)` para `player`
    /// respetando la regla de captura obligatoria.
    pub fn get_all_legal_moves(
        &self,
        sides: &Sides,
        player: PlayerId,
    ) -> Vec<(Position, Position)> {
        let captures = self.get_all_available_captures(sides, player);
        if !captures.is_empty() {
            return captures;
        }

        let forward = sides.forward_direction(player);
        let mut moves = Vec::new();
        for row in 0..8u8 {
            for col in 0..8u8 {
                let from = Position::new(row, col);
                if let Some(piece) = self.get(from) {
                    if piece.owner != player {
                        continue;
                    }
                    let directions: &[(i8, i8)] = if piece.is_king {
                        &[(-1, -1), (-1, 1), (1, -1), (1, 1)]
                    } else if forward == 1 {
                        &[(1, -1), (1, 1)]
                    } else {
                        &[(-1, -1), (-1, 1)]
                    };
                    for &(dr, dc) in directions {
                        let nr = row as i8 + dr;
                        let nc = col as i8 + dc;
                        if (0..8).contains(&nr) && (0..8).contains(&nc) {
                            let to = Position::new(nr as u8, nc as u8);
                            if to.is_dark_square() && self.get(to).is_none() {
                                moves.push((from, to));
                            }
                        }
                    }
                }
            }
        }
        moves
    }

    /// Cuenta cuántas fichas le quedan a cada jugador. Con exactamente
    /// dos jugadores (el único caso que soporta damas), si uno llega a
    /// cero, el otro ganó.
    pub fn count_pieces(&self) -> Vec<(PlayerId, u32)> {
        let mut counts: Vec<(PlayerId, u32)> = Vec::new();
        for piece in self.cells.iter().flatten().flatten() {
            match counts.iter_mut().find(|(id, _)| *id == piece.owner) {
                Some((_, count)) => *count += 1,
                None => counts.push((piece.owner, 1)),
            }
        }
        counts
    }
}

/// Quién avanza en qué dirección. `increasing` empieza arriba (filas
/// 0-2) y se mueve hacia filas más altas; `decreasing` empieza abajo
/// (filas 5-7) y se mueve hacia filas más bajas. Se decide una sola vez
/// al armar el tablero inicial y no cambia en toda la partida.
#[derive(GameResource, Clone, Copy)]
pub struct Sides {
    pub increasing: PlayerId,
    pub decreasing: PlayerId,
}

impl Sides {
    pub fn forward_direction(&self, player: PlayerId) -> i8 {
        if player == self.increasing {
            1
        } else {
            -1
        }
    }

    pub fn promotion_row(&self, player: PlayerId) -> u8 {
        if player == self.increasing {
            7
        } else {
            0
        }
    }

    pub fn opponent_of(&self, player: PlayerId) -> PlayerId {
        if player == self.increasing {
            self.decreasing
        } else {
            self.increasing
        }
    }
}

/// Arma el tablero inicial estándar: 12 fichas por jugador, en las 3
/// filas más cercanas a cada uno, solo en casillas oscuras.
pub fn initial_board(player_top: PlayerId, player_bottom: PlayerId) -> (BoardResource, Sides) {
    let mut cells: [[Option<Piece>; 8]; 8] = [[None; 8]; 8];

    for row in 0..3u8 {
        for col in 0..8u8 {
            let pos = Position::new(row, col);
            if pos.is_dark_square() {
                cells[row as usize][col as usize] = Some(Piece {
                    owner: player_top,
                    is_king: false,
                });
            }
        }
    }

    for row in 5..8u8 {
        for col in 0..8u8 {
            let pos = Position::new(row, col);
            if pos.is_dark_square() {
                cells[row as usize][col as usize] = Some(Piece {
                    owner: player_bottom,
                    is_king: false,
                });
            }
        }
    }

    (
        BoardResource { cells },
        Sides {
            increasing: player_top,
            decreasing: player_bottom,
        },
    )
}
