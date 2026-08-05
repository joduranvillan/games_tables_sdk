use criterion::{black_box, criterion_group, criterion_main, Criterion};
use checkers_game::{new_checkers_session, MovePieceCommand, Position};
use open_table_engine::prelude::*;

fn pos(row: u8, col: u8) -> Position {
    Position::new(row, col)
}

fn bench_checkers_process_command_throughput(c: &mut Criterion) {
    let p1 = PlayerId(1);
    let p2 = PlayerId(2);

    c.bench_function("checkers_process_command_throughput", |b| {
        b.iter(|| {
            let mut session = new_checkers_session(SessionId(1), 42, p1, p2);

            // Secuencia de 4 movimientos válidos de damas
            let res1 = session.process_command(
                p1,
                Box::new(MovePieceCommand {
                    player: p1,
                    from: pos(2, 1),
                    to: pos(3, 0),
                }),
            );
            let res2 = session.process_command(
                p2,
                Box::new(MovePieceCommand {
                    player: p2,
                    from: pos(5, 6),
                    to: pos(4, 7),
                }),
            );
            let res3 = session.process_command(
                p1,
                Box::new(MovePieceCommand {
                    player: p1,
                    from: pos(2, 7),
                    to: pos(3, 6),
                }),
            );
            let res4 = session.process_command(
                p2,
                Box::new(MovePieceCommand {
                    player: p2,
                    from: pos(5, 0),
                    to: pos(4, 1),
                }),
            );

            black_box((res1, res2, res3, res4, session.current_tick()));
        });
    });
}

criterion_group!(benches, bench_checkers_process_command_throughput);
criterion_main!(benches);
