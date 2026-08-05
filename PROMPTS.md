# 40 Development Prompts — Games Tables SDK

## 1. Core Infrastructure

**1.** Add a `SpectatorId` newtype to `open_table_core/src/ids.rs` alongside `PlayerId`. Extend the `Visibility` enum in `open_table_core/src/visibility.rs` with a `Spectators` variant so that a new `SpectatorVisibility::AllSpectators` variant can be added. Update `filter_events_for_player` in `open_table_engine/src/session.rs` to accept an additional function signature `filter_events_for_spectator`. Write two unit tests in `open_table_engine/tests/dice_game.rs` verifying that public events reach spectators and private events (like `SecretNoteEvent`) do not.

**2.** Implement `Session::snapshot` in `open_table_engine/src/session.rs` that serializes the full `BevyWorld` resource state (not just the command log) to bytes using `serde_json`. Add a companion `Session::from_snapshot` constructor. This is distinct from `replay`/`export_log` which currently replay all commands; `snapshot` skips replay and restores state directly. Write a test in `open_table_engine/tests/dice_game.rs` that snapshots mid-game and confirms `current_tick()` and `current_player()` are identical to the original after restoration.

**3.** Add a `GameClock::elapsed_millis` field to `open_table_core/src/time.rs` that records real wall-clock time at each tick using `std::time::Instant`. The `Session::process_command` in `open_table_engine/src/session.rs` should stamp the command in the log with this elapsed value. Add a `Session::tick_timestamps` method that returns `Vec<(Tick, u64)>`. Write a test verifying timestamps are monotonically increasing across successive commands.

**4.** Add a `Transport::health_check` method to the `Transport` trait in `open_table_core/src/transport.rs` returning `Result<Duration, EngineError>` (round-trip ping). Implement it as a no-op `Ok(Duration::ZERO)` in `TcpHostTransport` and `TcpClientTransport` in `open_table_transport_tcp`, and likewise for `NativeHostTransport`/`NativeClientTransport` in `open_table_transport_native_bridge`. Add a test in `open_table_transport_tcp/tests/end_to_end.rs` that calls `health_check` after connecting and asserts the response is `Ok`.

**5.** Add `EngineError::GameAlreadyOver` as a new variant in `open_table_core/src/error.rs`. Update `Session::process_command` in `open_table_engine/src/session.rs` to check for a `GameOverResource` (a simple bool `bevy_ecs::Resource` tracking whether a game-over event was emitted) and return this error if any command arrives after the game has ended. Write a test in `open_table_engine/tests/dice_game.rs` verifying that an extra command after a terminal event is rejected with `GameAlreadyOver`.

---

## 2. Game Rules & Logic

**6.** Implement multi-jump chain enforcement in `checkers_game/src/rules.rs`. Currently `captura_multiple_mantiene_el_turno_y_obliga_a_usar_la_misma_ficha` in `checkers_game/tests/game_rules.rs` verifies the first two jumps. Extend the rule handler to detect chains of three or more jumps: after each capture, scan if the landing square has any further capture opportunity, and if so, keep the same player's turn and record the `must_use_piece` position. Add a test with three consecutive jumps using a board setup similar to the existing `SessionId(9)` test.

**7.** Implement the Flying General rule in `xiangqi_game/src/rules.rs`: if after a move the two Generals (Kings) face each other on the same file with no piece between them, the move is illegal. The current `test_move_and_capture` in `xiangqi_game/tests/game_rules.rs` only tests basic movement. Add a dedicated test `flying_general_rechaza_movimiento_que_los_enfrenta` that sets up two Generals on the same column with an empty file between them, attempts a move that would reveal the face-off, and asserts `EngineError::InvalidCommand`.

**8.** Add piece promotion (成/不成) choice to the Shogi move handler in `shogi_game/src/rules.rs`. The existing `MovePieceCommand` already has a `promote: bool` field. Enforce that promotion is mandatory when a piece reaches the opponent's promotion zone (rows 0–2 for Sente). Add a test `test_forced_promotion_en_zona_rival` that moves a Silver General into row 1 with `promote: false` and asserts rejection, then with `promote: true` and asserts the promoted piece type is `PromotedSilver` in `BoardResource.squares`.

**9.** Add the Nifu (二歩) drop rule to `shogi_game/src/rules.rs`: a Pawn (`PieceKind::Pawn`) may not be dropped on a file that already contains a friendly Pawn. The `DropPieceCommand` handler must scan the target column before accepting. Add a test `test_nifu_rechaza_drop_en_columna_con_peon` that leaves a Sente Pawn in the hand (`boards.hands`), places another Sente Pawn on column 4 of the board, and verifies that a drop to any square in column 4 returns `EngineError::InvalidCommand`.

**10.** Extend the Go engine in `go_game/src/rules.rs` to enforce the ko rule: the board position after a capture may not be identical to the position before the previous move. Store the previous board state hash in a `KoResource` (a `u64` `bevy_ecs::Resource`). Add a test `test_ko_rule_prevents_immediate_recapture` that sets up a classic one-stone ko situation, has P1 capture, P2 attempt immediate recapture, and verifies the attempt is rejected with `EngineError::InvalidCommand`.

**11.** Add territory scoring to `go_game/src/rules.rs` for the `PassCommand` double-pass game-over path. When both players pass (the condition already detected in `test_pass_ends_game`), compute territory using a flood-fill on empty intersections on the 9×9 board and emit a `GameOverEvent` with the correct winner based on territory count rather than always the first player. Update `test_pass_ends_game` to verify the `winner` field is `Some(player_with_more_territory)` for a pre-set board position.

**12.** Implement the UNO Wild Draw Four validity rule in `uno_game/src/rules.rs`: a player may only legally play a `WildDrawFour` if they have no card matching the current active color. Add state to `UnoState` tracking whether a `WildDrawFour` was played illegally (for challenge mechanics, a stretch goal). Add a test `test_wild_draw_four_ilegal_si_tienes_carta_del_color` that gives P1 a Red card and a `WildDrawFour` when the active color is Red, attempts to play the `WildDrawFour` at card index 1, and asserts rejection.

**13.** Add the "Go to Jail" space (space index 8 in the 16-square Monopoly board) to `monopoly_game/src/rules.rs`. When a player lands on space 8, emit a `JailedEvent` and set their position to a `JAIL_SPACE` constant (e.g., space 4). Add a test that loops over seeds until a player rolls into space 8, then checks `PlayerMovedEvent.new_position == 4` and that a `JailedEvent` is present in the returned events.

**14.** Implement the Backgammon bearing-off legality rule already tested in `test_no_se_puede_sacar_ficha_con_dado_mayor_si_hay_fichas_mas_atras` but currently failing (the assertion is present but the rule may not be fully enforced). Review `backgammon_game/src/rules.rs`, find the bearing-off handler, and add the guard: if there is any piece at a lower absolute point index than the die-requested exit point, the move is invalid. Verify the existing `SessionId(9)` test passes cleanly.

**15.** Add a Mille Bornes "Coup Fourré" mechanic to `mille_bornes_game/src/rules.rs`: if a player holds the Remedy card matching the Hazard just played against them, they may immediately play the Remedy out of turn, counterattacking. This requires a new `CoupFourreCommand` struct in `mille_bornes_game/src/commands.rs`. Register it in `build_mille_bornes_rules()` with the validation that the player must have the matching Remedy in hand. Add a test that has P2 play a `FlatTire` hazard against P1, then P1 immediately issues `CoupFourreCommand` and verify the hazard is nullified and P2 is marked with a `FlatTire`.

---

## 3. New Features

**16.** Add a `SpectatorMode` to `OpenTableBridge` in `open_table_godot/src/lib.rs`. When `start_spectating(host_addr: String)` is called, the bridge connects to the TCP host (reusing `TcpClientTransport`) but never calls `process_command`; it only receives and emits events. Add a new GDScript signal `spectator_event_received(event_json: String)`. Write a GDScript smoke test in `godot_project/tests/` that starts a local checkers match and a spectator bridge, plays one move, and asserts the spectator received the `piece_moved` signal.

**17.** Implement a replay viewer in `open_table_godot/src/lib.rs`. Add a `load_replay(log_bytes: PackedByteArray, game_type: String) -> bool` method that calls `Session::replay` (already exists in `open_table_engine`) and re-emits all events to the existing Godot signals (e.g., `piece_moved`, `game_over`) in sequence. Add a `step_replay() -> bool` method to advance one tick at a time for a step-by-step viewer. Update `bridge_smoke.gd` in `godot_project/tests/` to verify that loading and stepping through a one-move replay emits exactly one `piece_moved` signal.

**18.** Add a simple AI player to `checkers_game` as a new optional crate `checkers_ai/` or a sub-module `checkers_game/src/ai.rs`. The AI should enumerate all legal moves (reusing the existing rule engine's validation via `session.process_command` trial-and-error) and pick randomly from captures first, then simple moves. Expose `pub fn checkers_ai_pick_move(session: &Session, player: PlayerId) -> Option<MovePieceCommand>`. Add a test that verifies the AI always returns a move when the board is not over.

**19.** Add a draw-offer mechanism to `chess_game`. Add two commands to `chess_game/src/commands.rs`: `OfferDrawCommand { player }` and `AcceptDrawCommand { player }`. Register handlers in `chess_game/src/rules.rs` that track a `DrawOfferedResource` (which player offered), and upon `AcceptDrawCommand`, emit `GameOverEvent { winner: None }`. Add tests for the full offer-accept flow and for the case where a player rejects by simply making a move (clear the pending offer on any non-draw command).

**20.** Implement game persistence: add `Session::save_to_file(path: &str)` and `Session::load_from_file(path: &str)` to `open_table_engine/src/session.rs` using `std::fs`. These should call the existing `export_log`/`replay` under the hood. Write a test that creates a checkers session, plays three moves, saves to a temp file, reloads, and verifies `current_tick()` and `current_player()` match the original. Handle the `EngineError::IoError` variant that would need to be added to `open_table_core/src/error.rs`.

**21.** Add a lobby/room concept to `open_table_transport_tcp`. Add a `TcpLobby` struct in a new file `open_table_transport_tcp/src/lobby.rs` that listens for connections, collects `JoinedPlayer { player_id, display_name }` entries, and provides a `start_game() -> Vec<PlayerId>` that transitions the lobby into a full `TcpHostTransport`. This avoids the current pattern where `TcpClientTransport::connect_as_new_player` is called immediately before the game start. Write a test that two clients join the lobby and `start_game()` returns both player IDs.

**22.** Add a turn timer to `open_table_engine`. Create `TimerResource` (a `bevy_ecs::Resource` wrapping `Instant` + a `Duration`). In `Session::process_command`, after each accepted command, reset the timer. Add `Session::check_timeout() -> Option<PlayerId>` that returns the timed-out player if elapsed > the configured duration. Write a test using a 50 ms timer that calls `check_timeout` after sleeping 100 ms and verifies it returns the correct player.

**23.** Implement a chat message system that travels through the existing transports. Add `ChatMessageCommand { sender: PlayerId, text: String }` to `open_table_core` (or a shared sub-crate), register a no-op rule handler that emits `ChatMessageEvent { sender, text }` with `Visibility::Public`. This piggybacks on the existing command/event serialization. Write a test in `open_table_transport_tcp/tests/` that sends a chat message from the client, the host processes it, and the broadcast event reaches the client side decoded.

---

## 4. Testing & Quality

**24.** Add property-based tests to `checkers_game` using `proptest`. Create `checkers_game/tests/property.rs` and add a property test `any_valid_simple_move_never_panics` that generates random `(from_row, from_col, to_row, to_col)` tuples (each 0–7), calls `session.process_command` with a `MovePieceCommand`, and asserts the result is either `Ok` or `Err(EngineError::InvalidCommand)` — never a panic or `EngineError::Unauthorized`. Add `proptest` to `checkers_game/Cargo.toml` under `[dev-dependencies]`.

**25.** Add fuzz targets to `open_table_engine` using `cargo-fuzz`. Create `fuzz/fuzz_targets/fuzz_session.rs` that deserializes arbitrary bytes as a `CommandEnvelope` (via `serde_json::from_slice`) and calls `session.process_command` on a fresh dice-game session. The fuzz target should never panic, only return `Ok` or `Err`. Add `fuzz/Cargo.toml` with the necessary `libfuzzer-sys` dependency and document how to run `cargo fuzz run fuzz_session` in `NEXT_STEPS.md`.

**26.** Add a determinism test that runs each of the 12 game constructors (`new_checkers_session`, `new_chess_session`, etc.) with the same seed twice and verifies that the first 5 commands produce identical event sequences. Create `open_table_engine/tests/determinism.rs`. The test does not need to know valid commands for each game: use the existing test board setups by calling `Session::replay` on a log exported from a separate session. This exercises the `export_log`/`replay` pipeline for all 12 games at once.

**27.** Add integration tests for the full TCP reconnection resync pipeline for a chess game. Currently `open_table_transport_tcp/tests/reconnection.rs` uses a simplified dice game. Create `open_table_transport_tcp/tests/chess_reconnection.rs` that starts a chess host, has White play a pawn advance, disconnects White, reconnects, and verifies the resync delivers exactly the `PieceMovedEvent` (from `chess_game`) and no extra events. This validates that game-specific events survive the JSON roundtrip through the wire.

**28.** Add test helpers to reduce boilerplate across the 12 game test files. Create a new file `open_table_engine/src/test_helpers.rs` (behind `#[cfg(test)]`) with macros like `force_turn!(session, player)` that directly mutates `TurnResource` so tests don't need to play valid filler moves to reach a desired turn. Export from `open_table_engine::prelude`. Update three or more existing tests (e.g., the chess `jaque_mate` test that currently calls `session.world_mut().resource_mut::<TurnResource>().0.advance()` manually) to use the macro.

**29.** Add code coverage measurement to the project. Create `tools/coverage.sh` that runs `cargo llvm-cov --workspace --lcov --output-path coverage/lcov.info` and then `genhtml coverage/lcov.info -o coverage/html`. Document the coverage baseline (approximate percentages per crate) in `NEXT_STEPS.md`. Identify any game crate whose branch coverage is below 60% and add a note about which rule paths are not yet exercised.

**30.** Add missing tests for `crisis_game` (TEG): implement tests in `tests/game_rules.rs` covering TEG mechanics: `test_setup_distribuye_todos_los_territorios` (initial territory setup with 30 territories), `test_ataque_resolucion_dados_reduce_ejercitos` (attack dice resolution and army reduction), `test_conquista_transfiere_territorio_al_atacante` (territory conquest upon victory), `test_player_eliminado_sale_del_ciclo_de_turnos` (player elimination and turn cycle advancement), and `test_game_over_por_objetivo_conquistar_continente` (victory detection on continent conquest objective).

---

## 5. Godot Integration

**31.** Add a visual board for Battleship in Godot. Create `godot_project/battleship_board.gd` (the `.tscn` scene already exists but the script is incomplete) with an 8×8 `GridContainer`, ship placement phase (click-to-place), and a fire phase (click-to-shoot). Connect `OpenTableBridge`'s `shot_result(player, row, col, is_hit)` signal using the existing bridge signal pattern from `checkers_board.gd`. Handle the `FleetPlacedEvent` and `ShotResultEvent` types by inspecting the bridge's JSON event output.

**32.** Implement a game selection main menu in `godot_project/main.tscn`. Add 12 buttons (one per game) that call the corresponding `start_local_match_*` method on `OpenTableBridge` and then switch to the relevant board scene (e.g., `checkers_board.tscn`, `chess_board.tscn`, etc.). Store the active game type in an `Autoload` singleton so other scenes can read it. This replaces the current empty `main.tscn` that has no navigation.

**33.** Add animated piece movement to `checkers_board.gd`. Currently `piece_moved` teleports sprites. On receiving the signal, instead start a `Tween` that moves the piece sprite from `(from_row, from_col)` to `(to_row, to_col)` over 0.2 seconds, and if `captured_row != -1` destroy the captured sprite after the tween completes. Add an `animation_finished` signal to the board scene that tests can await to avoid race conditions in headless testing.

**34.** Add a game-over overlay scene. Create `godot_project/game_over_overlay.tscn` with a `CanvasLayer` containing a centered `Label` ("Player 1 wins!") and a "Play Again" button. Connect the `OpenTableBridge.game_over(winner_id)` signal in every board `.gd` file (checkers, chess, go, uno, etc.) to show this overlay. The "Play Again" button should call `get_tree().reload_current_scene()`.

**35.** Add a QR code display scene to Godot for LAN multiplayer join flow. Create `godot_project/host_lobby.gd` that, on `_ready`, calls `OpenTableBridge.start_hosting(port)` and then renders the QR SVG (returned by `open_table_qr::generate_join_qr_svg`) inside an `ImageTexture` on a `TextureRect`. Use Godot's XML parser to render the SVG, or embed the SVG string in a `Label` as a fallback. Add a `player_joined` signal handler that updates a player count label.

**36.** Add an in-game chat UI to the Godot project. Create `godot_project/chat_panel.gd` with a `VBoxContainer` (message log) and a `LineEdit` + send button. When the user presses send, call `OpenTableBridge.send_chat(text)`. Connect the bridge's `chat_received(sender_id, text)` signal (which you will also need to add to `open_table_godot/src/lib.rs` as part of the chat feature from prompt 23) to append messages to the log. Style the panel to float over any game board without obscuring the center.

**37.** Write a GDScript headless integration test for the Go board. Create `godot_project/tests/go_smoke.gd` following the pattern of `bridge_smoke.gd`. It should: instantiate `OpenTableBridge`, call `bridge.start_local_match_go(1, 2)`, place a stone at (1,0), place a stone at (0,0), place a stone at (0,1) capturing (0,0), and assert a capture signal fires with `count == 1`. Also test that two consecutive passes trigger a `game_over` signal. Run with `redot --headless --path godot_project --script res://tests/go_smoke.gd`.

---

## 6. Mobile / Platform

**38.** Complete the Android Gradle build for the Nearby Connections plugin. In `platform_plugins/android/build.gradle.kts`, verify that `com.google.android.gms:play-services-nearby` is listed in `dependencies` with the correct version. Add the `OpenTableNearby.gdap` manifest file (using the template in `platform_plugins/android/OpenTableNearby.gdap.template`) substituting the correct AAR path. Document in `platform_plugins/android/README.md` the exact `./gradlew assembleRelease` command and where to copy the resulting `.aar` into the Godot project.

**39.** Implement the `sendBytes` / `broadcastBytes` Kotlin methods in `platform_plugins/android/src/OpenTableNearbyPlugin.kt` (if they exist as stubs). These must call the Nearby Connections `Nearby.getConnectionsClient(context).sendPayload(endpointId, Payload.fromBytes(bytes))`. Verify the GDScript-to-Kotlin bridge by adding a manual test procedure in the Android README: start the plugin from GDScript, call `sendBytes("test-tag", PackedByteArray([1,2,3]))`, and verify the Kotlin-side log shows the payload.

**40.** Add background reconnection logic to `NativeP2PAdapter.gd` in `godot_project/native_p2p_adapter.gd`. Currently the adapter calls `bridge.reconnect_native` only when the GDScript layer explicitly invokes it. Add a `_process(delta)` loop that monitors the bridge's connection status (`bridge.is_native_connected()` — add this query method to `open_table_godot/src/lib.rs`) and, if disconnected but a saved `(player_id, reconnect_token)` pair exists, automatically calls `reconnect_native` after a 3-second backoff. Write a unit test in `godot_project/tests/test_native_p2p_adapter.gd` using the existing `MockNativePlugin` class to verify the retry fires after the backoff.

---

## 7. DevOps / Build

**38b.** Create a GitHub Actions CI workflow at `.github/workflows/ci.yml` that runs on every push and pull request. It should: check out the repo, install the `stable` Rust toolchain (matching `rust-toolchain.toml`), run `cargo test --workspace --exclude open_table_godot` (excluding the Godot crate that needs `libclang`), and run `cargo clippy --workspace -- -D warnings`. Add a badge to `README.md` pointing to the workflow status.

**39b.** Add a `Makefile` at the workspace root with targets: `test` (runs `cargo test --workspace`), `build-godot` (runs `cargo build -p open_table_godot`), `test-godot` (runs `redot --headless --path godot_project --script res://tests/bridge_smoke.gd`), and `android-aar` (runs `cd platform_plugins && ./gradlew assembleRelease`). This consolidates the several manual commands documented in `NEXT_STEPS.md` into a single entry point for new contributors.

**40b.** Set up `cargo-deny` for dependency auditing. Create `deny.toml` at the workspace root, configure it to deny any dependency with a known security advisory (using the `advisories` section), ban duplicate versions of `serde` and `bevy_ecs`, and allow the current set of licenses (MIT, Apache-2.0, BSD-3-Clause). Add a `cargo deny check` step to the GitHub Actions CI workflow from the previous prompt. Document how to update advisories with `cargo deny fetch` in the contributing guide section of `README.md`.
