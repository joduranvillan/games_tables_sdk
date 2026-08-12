//! Partida de damas jugable por consola, dos jugadores humanos en el
//! mismo proceso (turnándose frente a la misma terminal). Sirve para
//! probar el juego de punta a punta sin esperar a `open_table_godot`.
//!
//! Correr con: `cargo run --example local_match`
//!
//! En cada turno, escribí el movimiento como `fila,col fila,col`, por
//! ejemplo `2,1 3,2`. Las filas/columnas van de 0 a 7. Fila 0 es la de
//! arriba (fichas de X), fila 7 es la de abajo (fichas de O).

use std::io::{self, Write};

use checkers_game::{new_checkers_session, MovePieceCommand, Position};
use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

fn print_board(session: &Session) {
    let board = session.world().resource::<checkers_game::BoardResource>();
    println!();
    print!("   ");
    for col in 0..8 {
        print!(" {col} ");
    }
    println!();
    for row in 0..8u8 {
        print!(" {row} ");
        for col in 0..8u8 {
            let symbol = match board.get(Position::new(row, col)) {
                None => " . ".to_string(),
                Some(piece) if piece.owner == P1 && piece.is_king => " X ".to_string(),
                Some(piece) if piece.owner == P1 => " x ".to_string(),
                Some(piece) if piece.is_king => " O ".to_string(),
                Some(_) => " o ".to_string(),
            };
            print!("{symbol}");
        }
        println!();
    }
    println!();
}

fn parse_move(line: &str) -> Option<(Position, Position)> {
    let parts: Vec<&str> = line.trim().split(' ').collect();
    if parts.len() != 2 {
        return None;
    }
    let parse_pos = |s: &str| -> Option<Position> {
        let coords: Vec<&str> = s.split(',').collect();
        if coords.len() != 2 {
            return None;
        }
        let row = coords[0].trim().parse().ok()?;
        let col = coords[1].trim().parse().ok()?;
        Some(Position::new(row, col))
    };
    Some((parse_pos(parts[0])?, parse_pos(parts[1])?))
}

fn main() {
    println!("=== Damas — OpenTable SDK, juego de referencia ===");
    println!("x/X = jugador 1 (arriba, avanza hacia abajo)");
    println!("o/O = jugador 2 (abajo, avanza hacia arriba)");
    println!("Mayúscula = dama. Formato de movimiento: fila,col fila,col (ej: 2,1 3,2)");

    let mut session = new_checkers_session(SessionId(1), 1, P1, P2);

    loop {
        print_board(&session);

        let current = session.current_player();
        let label = if current == P1 {
            "Jugador 1 (x)"
        } else {
            "Jugador 2 (o)"
        };
        print!("{label}, tu movimiento: ");
        io::stdout().flush().ok();

        let mut line = String::new();
        if io::stdin().read_line(&mut line).is_err() {
            println!("no se pudo leer la entrada, saliendo.");
            break;
        }
        if line.trim().eq_ignore_ascii_case("salir") {
            break;
        }

        let Some((from, to)) = parse_move(&line) else {
            println!("formato inválido. Usá: fila,col fila,col (ej: 2,1 3,2)");
            continue;
        };

        let command: Box<dyn Command> = Box::new(MovePieceCommand {
            player: current,
            from,
            to,
        });

        match session.process_command(current, command) {
            Ok(events) => {
                for event in &events {
                    if let Some(moved) = event
                        .as_any()
                        .downcast_ref::<checkers_game::PieceMovedEvent>()
                    {
                        if let Some(captured) = moved.captured {
                            println!("¡Captura en {captured:?}!");
                        }
                        if moved.promoted {
                            println!("¡La ficha se coronó!");
                        }
                    }
                    if let Some(game_over) = event
                        .as_any()
                        .downcast_ref::<checkers_game::GameOverEvent>()
                    {
                        print_board(&session);
                        println!(
                            "Ganó el jugador {:?}. ¡Fin de la partida!",
                            game_over.winner
                        );
                        return;
                    }
                }
            }
            Err(e) => println!("Movimiento inválido: {e}"),
        }
    }

    println!("Partida terminada.");
}
