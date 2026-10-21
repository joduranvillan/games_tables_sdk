use crate::board::{BoardResource, Stone};
use crate::commands::{PassCommand, PlaceHandicapCommand, PlaceStoneCommand};
use open_table_core::ids::PlayerId;
use open_table_engine::session::Session;

fn sgf_coord(x: usize, y: usize) -> String {
    let col = (b'a' + (x.min(25) as u8)) as char;
    let row = (b'a' + (y.min(25) as u8)) as char;
    format!("{col}{row}")
}

impl BoardResource {
    /// Exporta el estado actual del tablero de Go en formato estándar SGF (Smart Game Format `FF[4]`).
    pub fn export_sgf(&self) -> String {
        let mut sgf = format!(
            "(;GM[1]FF[4]CA[UTF-8]AP[OpenTable]SZ[{}]KM[6.5]PB[Black]PW[White]",
            self.size
        );

        for y in 0..self.size {
            for x in 0..self.size {
                if let Some(stone) = self.get_stone(x, y) {
                    let tag = match stone {
                        Stone::Black => "B",
                        Stone::White => "W",
                    };
                    let coord = sgf_coord(x, y);
                    sgf.push_str(&format!(";{tag}[{coord}]"));
                }
            }
        }

        sgf.push(')');
        sgf
    }
}

/// Rasgo de extensión para exportar una partida de Go a formato SGF desde `Session`.
pub trait GoSgfExport {
    fn export_sgf(&self) -> String;
}

impl GoSgfExport for Session {
    fn export_sgf(&self) -> String {
        export_session_sgf(self)
    }
}

pub fn export_session_sgf(session: &Session) -> String {
    let (size, black_player) = session
        .world()
        .get_resource::<BoardResource>()
        .map(|b| (b.size, b.black_player))
        .unwrap_or((9, PlayerId(1)));

    let mut sgf = format!("(;GM[1]FF[4]CA[UTF-8]AP[OpenTable]SZ[{size}]KM[6.5]PB[Black]PW[White]");

    let mut nodes_written = 0usize;

    for (_tick, _elapsed, cmd) in session.command_log() {
        let any_cmd = cmd.as_any();
        if let Some(place) = any_cmd.downcast_ref::<PlaceStoneCommand>() {
            let color = if place.player == black_player {
                "B"
            } else {
                "W"
            };
            let coord = sgf_coord(place.x, place.y);
            sgf.push_str(&format!(";{color}[{coord}]"));
            nodes_written += 1;
        } else if let Some(pass) = any_cmd.downcast_ref::<PassCommand>() {
            let color = if pass.player == black_player {
                "B"
            } else {
                "W"
            };
            sgf.push_str(&format!(";{color}[]"));
            nodes_written += 1;
        } else if let Some(handicap) = any_cmd.downcast_ref::<PlaceHandicapCommand>() {
            if !handicap.positions.is_empty() {
                sgf.push_str(&format!("HA[{}]", handicap.positions.len()));
                sgf.push_str("AB");
                for &(hx, hy) in &handicap.positions {
                    let coord = sgf_coord(hx as usize, hy as usize);
                    sgf.push_str(&format!("[{coord}]"));
                }
                nodes_written += 1;
            }
        }
    }

    if nodes_written == 0 {
        if let Some(board) = session.world().get_resource::<BoardResource>() {
            return board.export_sgf();
        }
    }

    sgf.push(')');
    sgf
}

pub fn export_to_sgf(session: &Session) -> String {
    export_session_sgf(session)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{new_go_session, PassCommand, PlaceStoneCommand};
    use open_table_core::ids::{PlayerId, SessionId};

    #[test]
    fn test_export_sgf_incluye_metadatos_tamano_y_secuencia_de_piedras() {
        let black = PlayerId(1);
        let white = PlayerId(2);
        let mut session = new_go_session(SessionId(1), 42, black, white);

        // Negro juega en (4, 4) -> 'ee'
        session
            .process_command(
                black,
                Box::new(PlaceStoneCommand {
                    player: black,
                    x: 4,
                    y: 4,
                }),
            )
            .unwrap();

        // Blanco juega en (2, 2) -> 'cc'
        session
            .process_command(
                white,
                Box::new(PlaceStoneCommand {
                    player: white,
                    x: 2,
                    y: 2,
                }),
            )
            .unwrap();

        // Negro pasa -> ';B[]'
        session
            .process_command(black, Box::new(PassCommand { player: black }))
            .unwrap();

        let sgf = session.export_sgf();
        assert!(sgf.starts_with("(;GM[1]FF[4]"));
        assert!(sgf.contains("SZ[9]"));
        assert!(sgf.contains(";B[ee];W[cc];B[]"));
        assert!(sgf.ends_with(')'));
    }

    #[test]
    fn test_board_resource_export_sgf_directo() {
        let mut board = BoardResource::new(9, PlayerId(1), PlayerId(2));
        board.set_stone(0, 0, Some(Stone::Black));
        board.set_stone(8, 8, Some(Stone::White));

        let sgf = board.export_sgf();
        assert!(sgf.contains("SZ[9]"));
        assert!(sgf.contains(";B[aa]"));
        assert!(sgf.contains(";W[ii]"));
    }
}
