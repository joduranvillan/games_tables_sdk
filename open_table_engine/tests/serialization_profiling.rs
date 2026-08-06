use checkers_game::{new_checkers_session, MovePieceCommand, Position};
use open_table_engine::prelude::*;
use std::time::Instant;

#[test]
fn test_profile_1000_commands_serialization() {
    let p1 = PlayerId(1);
    let p2 = PlayerId(2);

    let mut total_process_ns = 0u128;
    let mut total_serde_json_ns = 0u128;
    let mut total_bincode_ns = 0u128;

    for _ in 0..250 {
        let mut session = new_checkers_session(SessionId(1), 42, p1, p2);

        let moves = [
            (p1, 2, 1, 3, 0),
            (p2, 5, 6, 4, 7),
            (p1, 2, 7, 3, 6),
            (p2, 5, 0, 4, 1),
        ];

        for (player, fr, fc, tr, tc) in moves {
            let cmd: Box<dyn Command> = Box::new(MovePieceCommand {
                player,
                from: Position::new(fr, fc),
                to: Position::new(tr, tc),
            });

            let t0 = Instant::now();
            let res = session.process_command(player, cmd);
            let process_dur = t0.elapsed();
            total_process_ns += process_dur.as_nanos();

            if let Ok(events) = res {
                let t1 = Instant::now();
                let json_bytes = serde_json::to_vec(&events).unwrap_or_default();
                let json_dur = t1.elapsed();
                total_serde_json_ns += json_dur.as_nanos();

                let t2 = Instant::now();
                let _bin_bytes = bincode::serialize(&json_bytes).unwrap_or_default();
                let bin_dur = t2.elapsed();
                total_bincode_ns += bin_dur.as_nanos();
            }
        }
    }

    let total_time_json_ns = total_process_ns + total_serde_json_ns;
    let json_pct = (total_serde_json_ns as f64 / total_time_json_ns as f64) * 100.0;

    println!("=== Benchmark Profiling (1000 Comandos) ===");
    println!("Tiempo de Ejecución Session::process_command: {:.2} ms", total_process_ns as f64 / 1_000_000.0);
    println!("Tiempo de Serialización serde_json:         {:.2} ms", total_serde_json_ns as f64 / 1_000_000.0);
    println!("Tiempo de Serialización bincode:            {:.2} ms", total_bincode_ns as f64 / 1_000_000.0);
    println!("Porcentaje de Serialización JSON:            {:.2}%", json_pct);

    assert!(total_process_ns > 0);
}
