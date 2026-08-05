use checkers_game::new_checkers_session;
use open_table_core::ids::{PlayerId, SessionId, Tick};
use open_table_engine::session::Session;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn test_checkers_v1_log_compatibility() {
    let fixture_bytes = include_bytes!("fixtures/checkers_v1.json");
    let session = new_checkers_session(SessionId(1), 42, P1, P2);
    let (replayed_session, _events) =
        Session::replay_on_session(session, fixture_bytes)
            .expect("Error al reproducir el log de checkers_v1.json");

    assert_eq!(replayed_session.current_tick(), Tick(5));
    assert_eq!(replayed_session.current_player(), P2);
}
