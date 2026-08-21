use checkers_game::commands::MovePieceCommand;
use checkers_game::{new_checkers_session, Position};
use open_table_core::ids::{PlayerId, SessionId};
use open_table_engine::prelude::*;

#[cfg(target_os = "linux")]
fn get_rss_bytes() -> usize {
    use std::fs;
    if let Ok(statm) = fs::read_to_string("/proc/self/statm") {
        if let Some(rss_pages) = statm.split_whitespace().nth(1) {
            if let Ok(pages) = rss_pages.parse::<usize>() {
                // assume 4096 bytes per page
                return pages * 4096;
            }
        }
    }
    0
}

#[cfg(not(target_os = "linux"))]
fn get_rss_bytes() -> usize {
    0
}

#[test]
#[ignore]
fn test_memory_stability_10k_commands() {
    let p1 = PlayerId(1);
    let p2 = PlayerId(2);
    let mut session = new_checkers_session(SessionId(1), 2024, p1, p2);

    let initial_rss = get_rss_bytes();
    if initial_rss == 0 && cfg!(target_os = "linux") {
        println!("Warning: Could not read RSS");
    }

    // Play 10,000 commands
    // We send an invalid command structure so we don't have to simulate a full real game.
    // However, it must be a syntactically valid JSON payload of a registered command type.
    // If we just use `process_command` with a MovePieceCommand, it will get rejected by rules
    // (e.g. invalid move) but it exercises the engine's command processing pipeline.

    let invalid_move = Box::new(MovePieceCommand {
        player: p1,
        from: Position::new(0, 0),
        to: Position::new(0, 0), // obviously invalid in checkers
    });

    for _ in 0..10_000 {
        // Enforce cloning to supply a Box<dyn Command> to the engine.
        // wait, we can just recreate it.
        let cmd = Box::new(MovePieceCommand {
            player: p1,
            from: Position::new(0, 0),
            to: Position::new(0, 0),
        });

        let _ = session.process_command(p1, cmd);
    }

    let final_rss = get_rss_bytes();
    if final_rss > 0 && initial_rss > 0 {
        let diff = final_rss.saturating_sub(initial_rss);
        // limit is 5MB
        let limit = 5 * 1024 * 1024;
        assert!(
            diff <= limit,
            "Memory grew by more than 5MB: {} bytes (initial: {}, final: {})",
            diff,
            initial_rss,
            final_rss
        );
    }
}
