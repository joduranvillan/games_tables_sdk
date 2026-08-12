use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use open_table_engine::prelude::*;

const P1: PlayerId = PlayerId(1);
const P2: PlayerId = PlayerId(2);

#[test]
fn turn_timer_times_out_after_duration_and_returns_correct_player() {
    let mut session = Session::new(SessionId(1), 42, vec![P1, P2], RuleEngine::new());

    // Configurar temporizador de turno con 50 ms
    session
        .world_mut()
        .insert_resource(TimerResource::new(Duration::from_millis(50)));

    // Recién creado no debe estar expirado
    assert_eq!(session.check_timeout(), None);

    // Esperar 100 ms para que expire
    thread::sleep(Duration::from_millis(100));

    // check_timeout debe devolver al jugador del turno actual (P1)
    assert_eq!(session.check_timeout(), Some(P1));
}

#[test]
fn test_timeout_de_reconexion_emite_forfeit() {
    let mut session = Session::new(SessionId(2), 42, vec![P1, P2], RuleEngine::new());

    let forfeit_received = Arc::new(AtomicU32::new(0));
    let forfeit_clone = Arc::clone(&forfeit_received);

    session.on_event::<ForfeitEvent>(move |event| {
        if event.player == P1 {
            forfeit_clone.fetch_add(1, Ordering::SeqCst);
        }
    });

    session.set_reconnection_timeout(P1, Duration::from_millis(50));

    assert_eq!(session.check_timeout(), None);

    thread::sleep(Duration::from_millis(100));

    let timed_out = session.check_timeout();
    assert_eq!(timed_out, Some(P1));
    assert_eq!(forfeit_received.load(Ordering::SeqCst), 1);
    assert_eq!(session.current_player(), P2);
}

#[derive(Debug, serde::Serialize, serde::Deserialize)]
struct DummyCommand(PlayerId);

#[typetag::serde]
impl Command for DummyCommand {
    fn clone_box(&self) -> Box<dyn Command> {
        Box::new(DummyCommand(self.0))
    }
    fn issuer(&self) -> Option<PlayerId> {
        Some(self.0)
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[test]
fn test_pausa_rechaza_comandos() {
    let mut session = Session::new(SessionId(10), 1, vec![P1, P2], RuleEngine::new());
    session.pause().expect("pausa la sesión");
    assert!(session.is_paused());

    let result = session.process_command(P1, Box::new(DummyCommand(P1)));
    assert!(matches!(result, Err(EngineError::SessionPaused)));
}

#[test]
fn test_reanudar_permite_comandos_nuevamente() {
    let mut session = Session::new(SessionId(11), 1, vec![P1, P2], RuleEngine::new());
    session.pause().expect("pausa la sesión");
    assert!(session.is_paused());

    session.resume().expect("reanuda la sesión");
    assert!(!session.is_paused());

    let result = session.process_command(P1, Box::new(DummyCommand(P1)));
    // El comando dummy no tiene handler registrado, pero NO debe fallar con SessionPaused
    assert!(!matches!(result, Err(EngineError::SessionPaused)));
}
