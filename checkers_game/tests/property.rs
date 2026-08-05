use checkers_game::{new_checkers_session, MovePieceCommand, Position};
use open_table_engine::prelude::*;
use proptest::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

proptest! {
    #[test]
    fn any_valid_simple_move_never_panics(
        from_row in 0..8u8,
        from_col in 0..8u8,
        to_row in 0..8u8,
        to_col in 0..8u8,
    ) {
        let mut session = new_checkers_session(SessionId(1), 42, P1, P2);
        let current_player = session.current_player();

        let cmd = Box::new(MovePieceCommand {
            player: current_player,
            from: Position::new(from_row, from_col),
            to: Position::new(to_row, to_col),
        });

        let result = session.process_command(current_player, cmd);

        match result {
            Ok(_) => {},
            Err(EngineError::InvalidCommand { .. }) => {},
            Err(other) => panic!("Esperado Ok u Err(InvalidCommand), pero se obtuvo: {:?}", other),
        }
    }
}
