# Testing Guide — Games Tables SDK

## 1. Prerequisites

### Rust Toolchain

The project uses the `stable` channel, pinned via `rust-toolchain.toml` at the workspace root:

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
```

Rustup installs and activates this automatically when you run any `cargo` command from inside the workspace. Minimum required version is Rust 1.78 (required by `bevy_ecs` and `godot-rust`). Verify with:

```bash
rustc --version   # should be 1.78.0 or newer
cargo --version
```

### Redot / Godot Binary (for GDScript tests only)

GDScript integration tests require a `redot` binary in your `PATH`. Rust unit tests have no such requirement and run anywhere.

```bash
redot --version
```

If `redot` is not available, all Rust tests still run. Only the three GDScript smoke tests (section 5) are skipped.

### No External Services Required

All Rust tests are self-contained. The TCP transport tests bind to `127.0.0.1:0` (OS-assigned port) and do not require any external process. The native bridge tests use `FakeHostLink` / `FakeClientLink` (in-process `mpsc` channels) and do not require Android or iOS.

---

## 2. Running Rust Tests

### All Tests in the Workspace

```bash
cargo test --workspace
```

This runs every test suite across all 20 crates. Approximate runtime: 10–30 seconds on a modern laptop (the TCP reconnection tests have deliberate short sleeps of 100–300 ms).

### Excluding the Godot Crate

The `open_table_godot` crate requires `libclang` installed and the Godot extension headers. On CI or machines without these, exclude it:

```bash
cargo test --workspace --exclude open_table_godot
```

### A Single Crate

```bash
cargo test -p checkers_game
cargo test -p open_table_transport_tcp
```

### A Single Test Function

```bash
cargo test -p chess_game una_ficha_que_deja_al_propio_rey
cargo test -p backgammon_game el_setup_inicial
```

(Cargo matches the argument as a substring of the test name, so partial names work.)

### With Output Printed (for debugging)

```bash
cargo test -p monopoly_game -- --nocapture
```

### List All Tests

```bash
cargo test --workspace -- --list
```

### Parallelism

By default Cargo runs test binaries in parallel but tests within a binary sequentially. All tests in this project are independent (each creates its own `Session` with a unique `SessionId`). No inter-test state exists.

---

## 3. Test Coverage by Game

| Crate | Tests | Scenarios Covered |
|---|---|---|
| `checkers_game` | 9 | Initial board, forward move, out-of-turn, backward (non-king), capture, king promotion, game-over, mandatory capture, multi-jump chain |
| `chess_game` | 10 | Initial board count, pawn double-advance, bishop rejection, knight jump, capture+piece-removal, self-check rejection, checkmate (back-rank), en passant, castling (short), promotion with piece choice |
| `go_game` | 2 | Stone placement + capture, double-pass game-over |
| `shogi_game` | 1 | Pawn move, capture into hand, drop from hand |
| `xiangqi_game` | 1 | Soldier move, capture |
| `uno_game` | 2 | Skip card + turn order, Draw Two stacking (penalty accumulation + force-draw) |
| `backgammon_game` | 9 | Initial 15 checkers, dice roll pending, move uses die, blot capture to bar, bar-entry forced, bearing-off final (game-over), doubles give 4 dice, no-valid-moves auto-pass, bearing-off with backmost-piece rule |
| `battleship_game` | 7 | Valid fleet placement, wrong fleet size rejection, fire before fleet rejection, hit/miss, sink-all (game-over), repeat-shot rejection, overlapping+diagonal fleet rejection |
| `ludo_game` | 8 | 3-player support, move-before-roll rejection, base-piece needs 6, extra-turn on 6, token capture + return to base, 4-tokens-home (game-over), no-valid-moves auto-pass, safe-square prevents capture |
| `mille_bornes_game` | 8 | Initial hand size, draw card visibility, distance card advances + turn-pass, hazard blocks distance, goal-exact wins, overshoot rejection, discard mechanic, speed-limit card limits |
| `monopoly_game` | 7 | Initial money+position, unowned property decision pending, no-roll-with-pending, buy property (price+ownership), rent collection, doubled-rent for color group, bankruptcy game-over |
| `crisis_game` | 5 | Initial money+position, unowned company decision, no-roll-with-pending, buy company, (tax/crisis/opportunity stub — incomplete) |
| `chinese_checkers_game` | 5 | 6 pegs per player, simple step, occupied-destination rejection, jump (no capture), all-6-home game-over |

---

## 4. Key Test Scenarios — Per Game

### Checkers (`checkers_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_tablero_inicial_tiene_12_fichas_por_jugador` | `BoardResource` has exactly 12 pieces per side, none crowned |
| `un_movimiento_simple_hacia_adelante_es_valido` | `PieceMovedEvent` fields (from, to, no capture, not promoted), turn passes |
| `no_se_puede_mover_fuera_de_turno` | `EngineError::InvalidCommand` when wrong player acts |
| `no_se_puede_mover_hacia_atras_sin_ser_dama` | Backward move rejected without king status |
| `una_captura_remueve_la_ficha_saltada` | `PieceMovedEvent.captured == Some(pos)`, board cleared at mid-square |
| `una_ficha_se_corona_al_llegar_a_la_ultima_fila` | `PieceMovedEvent.promoted == true`, `BoardResource.is_king == true` |
| `el_juego_termina_cuando_un_jugador_pierde_todas_sus_fichas` | `GameOverEvent.winner == P1` in same event batch as last capture |
| `captura_obligatoria_rechaza_movimientos_simples_si_hay_captura` | Move rejected if a capture was available |
| `captura_multiple_mantiene_el_turno_y_obliga_a_usar_la_misma_ficha` | Turn stays on P1 between jumps; moving a different piece is rejected |

### Chess (`chess_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_setup_inicial_tiene_16_piezas_por_jugador` | 16 pieces per side in `BoardResource.pieces` |
| `un_peon_puede_avanzar_dos_casillas_en_su_primer_movimiento` | Pawn double-advance valid on first move |
| `un_movimiento_no_diagonal_ni_recto_de_alfil_es_rechazado` | Bishop move validation |
| `un_caballo_puede_saltar_piezas_en_su_primer_movimiento` | Knight jump over occupied squares |
| `capturar_una_pieza_rival_la_quita_del_tablero` | `PieceMovedEvent.captured == Some(PieceKind::Pawn)`, board size drops |
| `una_jugada_que_deja_al_propio_rey_en_jaque_es_rechazada` | Self-check detection prevents move |
| `jaque_mate_por_columna_trasera_termina_la_partida` | `GameOverEvent.winner == Some(BLACK)` |
| `captura_al_paso_de_peon_funciona` | En passant removes pawn from its original square |
| `enroque_corto_blanco_funciona` | `PieceMovedEvent.castled == true`, King at (0,6), Rook at (0,5) |
| `coronacion_con_eleccion_de_pieza` | `promoted_to == Some(PieceKind::Knight)`, board reflects Knight |

### Go (`go_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_place_stone_and_capture` | `StonesCapturedEvent.count == 1` when last liberty removed |
| `test_pass_ends_game` | Consecutive passes from both players emit `GameOverEvent` |

### Shogi (`shogi_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_move_and_drop` | Pawn captured goes into `BoardResource.hands[SENTE]`; drop removes from hand and appears on board |

### Xiangqi (`xiangqi_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_move_and_capture` | Soldier advance and capture: `squares[(4,4)].owner == RED` |

### UNO (`uno_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_play_and_skip` | Skip card skips P2, `TurnResource` advances to P3 |
| `test_stacking_draw_two` | `UnoState.draw_penalty` accumulates to 4; P3 forced to draw 4; penalty resets to 0 |

### Backgammon (`backgammon_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_setup_inicial_tiene_15_fichas_por_jugador` | `board.points` sums to `CHECKERS_PER_PLAYER` (15) per side |
| `tirar_los_dados_deja_dos_valores_pendientes` | `DiceRolledEvent.values.len() == 2`; pending dice set for P1 |
| `mover_una_ficha_propia_usa_un_dado_y_la_desplaza` | Die consumed, board updated, turn remains P1 while dice remain |
| `pisar_un_blot_rival_lo_manda_a_la_barra` | `CheckerMovedEvent.captured_opponent == true`; `board.bar[P2] == 1` |
| `con_fichas_en_la_barra_hay_que_entrar_antes_de_mover_otra_cosa` | Non-bar move rejected; bar entry accepted |
| `sacar_las_15_fichas_termina_la_partida` | `GameOverEvent.winner == P1` after last piece bears off |
| `dobles_en_la_barra_o_tablero_pueden_usar_hasta_4_dados` | Pending dice count == 4 for doubles |
| `sin_movimientos_validos_pasa_el_turno` | `NoValidMovesEvent` emitted; `current_player() == P2` |
| `no_se_puede_sacar_ficha_con_dado_mayor_si_hay_fichas_mas_atras` | Bearing-off legality: rejected when backmost piece exists |

### Battleship (`battleship_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `colocar_una_flota_valida_funciona_y_no_revela_las_coordenadas` | `FleetPlacedEvent` debug string contains no coordinate numbers |
| `una_flota_con_tamanos_incorrectos_es_rechazada` | Wrong ship count rejected |
| `no_se_puede_disparar_antes_de_que_ambos_coloquen_su_flota` | Shot rejected while P2 fleet not placed |
| `un_disparo_certero_se_reporta_como_hit_y_uno_al_agua_como_miss` | `ShotResult::Hit` and `ShotResult::Miss` |
| `hundir_todos_los_barcos_rivales_termina_la_partida` | `GameOverEvent.winner == P1` after all 9 squares sunk |
| `disparar_dos_veces_a_la_misma_casilla_es_rechazado` | Duplicate shot rejected |
| `barcos_superpuestos_o_diagonales_son_rechazados` | Invalid fleet geometry rejected |

### Ludo (`ludo_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `soporta_mas_de_dos_jugadores` | `new_ludo_session` with 3 players starts on P1 |
| `no_se_puede_mover_sin_tirar_primero` | Move without `RollDiceCommand` rejected |
| `una_ficha_en_la_base_solo_entra_con_un_6` | Base token requires die == 6 |
| `sacar_un_6_da_turno_extra_y_no_avanza_el_turno` | Extra turn granted on 6 |
| `pisar_una_ficha_rival_la_manda_de_vuelta_a_la_base` | `TokenMovedEvent.captured == Some((P2, 0))`; P2 token resets to 0 |
| `llegar_con_las_4_fichas_a_destino_termina_la_partida` | `GameOverEvent.winner == P1` when all 4 tokens reach `MAX_STEPS` |
| `sin_movimientos_validos_limpia_tirada_y_pasa_turno` | `NoValidMovesEvent` + auto-advance to P2 |
| `casilla_segura_de_salida_evita_captura` | `TokenMovedEvent.captured == None` on safe start square |

### Mille Bornes (`mille_bornes_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_setup_reparte_manos_privadas_de_tamano_correcto` | Both players start with `MAX_HAND_SIZE` cards; `distance == 0` |
| `robar_agrega_una_carta_a_la_mano_y_es_evento_privado` | Draw event visible to P1, invisible to P2 |
| `jugar_una_carta_de_distancia_avanza_y_pasa_el_turno` | `DistancePlayedEvent.new_distance == 50`; turn passes |
| `un_peligro_impide_que_el_rival_juegue_distancia_hasta_curarse` | Distance blocked under hazard; Remedy clears `deck.hazard[P2]` |
| `llegar_exacto_a_la_meta_termina_la_partida` | `GameOverEvent.winner == P1` at `TARGET_DISTANCE` |
| `una_jugada_que_pasaria_la_meta_es_rechazada` | Overshoot rejected |
| `descartar_una_carta_pasa_el_turno_y_va_al_descarte` | `CardDiscardedEvent.card` matches; `discard_pile.len() == 1` |
| `limite_de_velocidad_permite_cartas_de_25_o_50_pero_bloquea_mayores` | 75-km card rejected under speed limit; 50-km card accepted |

### Monopoly (`monopoly_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_setup_arranca_con_dinero_estandar_y_posicion_cero` | `STARTING_MONEY` and position 0 for all players |
| `moverse_a_una_propiedad_sin_dueno_deja_una_decision_pendiente_y_no_avanza_el_turno` | `PendingPurchaseResource` populated; turn not advanced |
| `no_se_puede_tirar_de_nuevo_con_una_compra_pendiente` | Roll rejected while pending decision exists |
| `comprar_una_propiedad_descuenta_el_precio_y_asigna_el_dueno` | Money decremented by 60; property assigned to P1; turn advances |
| `caer_en_propiedad_ajena_paga_renta_al_dueno` | `RentPaidEvent.amount == 10` |
| `poseer_todo_el_grupo_de_color_duplica_la_renta` | Rent doubles to 20 when P2 owns full color group |
| `quedarse_sin_dinero_tras_pagar_renta_termina_la_partida` | `GameOverEvent.winner == P2` on bankruptcy |

### Crisis (`crisis_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_setup_arranca_con_dinero_estandar_y_posicion_cero` | `STARTING_MONEY` and position 0 |
| `moverse_a_una_propiedad_sin_dueno_deja_una_decision_pendiente_y_no_avanza_el_turno` | Pending purchase blocks turn advance |
| `no_se_puede_tirar_de_nuevo_con_una_compra_pendiente` | Roll rejected while pending |
| `comprar_una_propiedad_descuenta_el_precio_y_asigna_el_dueno` | Price 1000; `CompanyPurchasedEvent` fired; turn advances |
| `caer_en_impuestos_o_crisis_o_oportunidad_aplica_el_efecto_correspondiente` | **Stub — body not yet implemented** |

### Chinese Checkers (`chinese_checkers_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_setup_pone_6_fichas_por_jugador_en_esquinas_opuestas` | 6 pegs per player in `BoardResource.pegs` |
| `un_paso_simple_a_una_casilla_vacia_es_valido` | `PegMovedEvent.was_jump == false` |
| `no_se_puede_mover_a_una_casilla_ocupada` | Move to occupied square rejected |
| `saltar_sobre_cualquier_ficha_no_la_captura_solo_permite_pasar` | `was_jump == true`; jumped piece survives on board |
| `llevar_las_6_fichas_a_la_casa_rival_termina_la_partida` | `GameOverEvent.winner == P1` after placing 6th peg in target zone |

---

## 5. Godot Integration Testing

### GDScript Bridge Smoke Test (Checkers)

Tests that the `OpenTableBridge` GDExtension loads, starts a checkers match, validates moves against the real Rust rule engine, and emits the correct signals.

**Requires:** `redot` in PATH, the Godot extension compiled (`cargo build -p open_table_godot`).

```bash
# Build the extension first
cargo build -p open_table_godot

# Run the smoke test
redot --headless --path /path/to/games_tables_sdk/godot_project \
      --script res://tests/bridge_smoke.gd
```

Expected output: lines beginning with `PASS` for all checks, ending with `=== RESULTADO: TODO OK ===`. Exit code 0 on success, 1 on any failure.

### NativeP2PAdapter Test

```bash
redot --headless --path /path/to/games_tables_sdk/godot_project \
      --script res://tests/test_native_p2p_adapter.gd
```

### Visual Regression Tests (`visual_regression.gd`)

Compares rendered frames of all 13 board scenes against reference PNG snapshots stored in `godot_project/tests/snapshots/` with a 1% pixel diff tolerance.

```bash
# Run visual regression tests
redot --headless --path godot_project --script res://tests/visual_regression.gd

# Regenerate reference snapshots after intentional visual changes
UPDATE_SNAPSHOTS=1 make test-godot
```

> **Importante sobre la actualización de snapshots:**
> Solo debe ejecutarse con `UPDATE_SNAPSHOTS=1` tras introducir **cambios visuales intencionales** en los tableros o temas (por ejemplo, nuevas sombras, coordenadas, temas o partículas). **NUNCA** debe utilizarse como un atajo para "arreglar" un pipeline de CI fallido sin antes investigar y verificar si el cambio visual es deliberado y correcto.

### TCP Bridge Smoke (Timed)

The `test_tcp_bridge.tscn` scene is interactive (does not call `quit()`). Run it with the provided shell script that enforces a 30-second timeout:

```bash
bash /path/to/games_tables_sdk/run_test.sh
```

The script uses `timeout -k 5 30 redot ...` so the process is killed after 30 seconds. Exit code 124 (timeout) is expected and normal. Look for `✅` or `❌` lines in the filtered output.

---

## 6. Adding New Tests

All game test files follow the same pattern. Here is a complete template for adding a new test to `ludo_game`:

```rust
// In: ludo_game/tests/game_rules.rs

#[test]
fn mi_nuevo_test_de_regla() {
    // 1. Create a session with a unique SessionId (never reuse IDs across tests)
    //    and a deterministic seed.
    let mut session = new_ludo_session(SessionId(99), 1, vec![P1, P2]);

    // 2. Set up board state directly via world_mut() + resource_mut()
    //    instead of playing through many valid moves.
    {
        let mut tokens = session.world_mut().resource_mut::<ludo_game::TokensResource>();
        tokens.tokens.get_mut(&P1).unwrap()[0] = 10;
    }

    // 3. For dice-dependent games, inject the desired roll directly.
    {
        let mut pending = session.world_mut().resource_mut::<ludo_game::PendingRollResource>();
        pending.pending.insert(P1, 3); // force die=3
    }

    // 4. Issue the command under test.
    let result = session.process_command(
        P1,
        Box::new(MoveTokenCommand { player: P1, token_index: 0 }),
    );

    // 5. Assert the happy path or the rejection.
    let events = result.expect("expected this move to be valid");
    let moved = events[0]
        .as_any()
        .downcast_ref::<TokenMovedEvent>()
        .expect("first event should be TokenMovedEvent");
    assert_eq!(moved.to, 13); // 10 + 3 = 13

    // 6. Optionally inspect board state after the command.
    let tokens = session.world().resource::<ludo_game::TokensResource>();
    assert_eq!(tokens.tokens[&P1][0], 13);
}
```

### Key Patterns

**Unique `SessionId`:** Every test creates its own `Session`. Use any integer; existing tests use sequential values per file (e.g., `SessionId(1)` through `SessionId(12)`).

**Direct resource mutation:** Access ECS resources via `session.world_mut().resource_mut::<SomeResource>()` to set up board state without playing filler moves. Wrap in `{ }` blocks to drop the borrow before other resource accesses.

**Force dice/randomness:** Games with randomness expose a pending-state resource (e.g., `PendingDiceResource`, `PendingRollResource`, `PendingPurchaseResource`). Insert the desired value before issuing the command instead of looping over seeds.

**Seed-looping for probabilistic tests:** The monopoly tests demonstrate looping `for seed in 0..50u64` when the scenario depends on landing on a specific space. Always add a final `panic!("ninguna seed probada...")` to catch exhaustion without hitting the condition.

**Downcast events:** All events are `Box<dyn Event>`. Downcast with `event.as_any().downcast_ref::<ConcreteEventType>()`. If the downcast returns `None`, the event was a different type.

**Check game-over:**

```rust
assert!(
    events.iter().any(|e|
        e.as_any().downcast_ref::<GameOverEvent>()
            .map(|go| go.winner) == Some(expected_winner)
    ),
    "should have a GameOverEvent with the expected winner"
);
```

---

## 7. Known Limitations in Tests

**Android Nearby Connections plugin:** `platform_plugins/android/` contains `OpenTableNearbyPlugin.kt` (written, not yet compiled). No Rust or GDScript test exercises the real Nearby Connections API. The `open_table_transport_native_bridge` tests use `FakeHostLink` (in-memory channels) which is structurally identical to the real plugin interface but does not call any Android API.

**iOS MultipeerConnectivity plugin:** Same status as Android. `platform_plugins/ios/` contains `OpenTableMultipeerPlugin.swift` and `OpenTableMultipeerNetwork.swift` (written, not compiled, not linked). No test exercises the real `MCSession`.

**Real Wi-Fi / Bluetooth P2P:** No test uses an actual radio. All multi-device scenarios are simulated with `FakeHostLink` or `127.0.0.1` TCP loopback.

**Godot rendering:** The headless `bridge_smoke.gd` test does not test visual correctness (sprite positions, colors, animations). It only verifies that signals fire with the correct argument values.

**Go territory scoring:** `test_pass_ends_game` verifies that a `GameOverEvent` is emitted after two consecutive passes but does not check the `winner` field. Territory scoring is not fully implemented.

**Crisis game — incomplete test:** `caer_en_impuestos_o_crisis_o_oportunidad_aplica_el_efecto_correspondiente` in `crisis_game/tests/game_rules.rs` has no assertions in its body. The `TaxPaidEvent`, `CrisisOccurredEvent`, and `OpportunityGainedEvent` types exist but their rule handlers are not verified by any passing test.

**Shogi / Xiangqi depth:** Each has only 1 integration test covering a narrow path. Flying General, Nifu, forced promotion zone, and elephant movement restrictions are not yet tested.

**Go ko rule:** `KoResource` is not yet implemented; no test covers ko.

**Replay with game-specific types:** `Session::replay` is tested in `open_table_engine/tests/dice_game.rs` only. Replay with `chess_game::MovePieceCommand` or other game commands is not covered.

---

## 8. Test Commands Reference

| What | Command |
|---|---|
| All Rust tests | `cargo test --workspace` |
| All except Godot crate | `cargo test --workspace --exclude open_table_godot` |
| One crate | `cargo test -p <crate_name>` |
| One test by name | `cargo test -p <crate_name> <partial_test_name>` |
| With printed output | `cargo test -p <crate_name> -- --nocapture` |
| List all tests | `cargo test --workspace -- --list` |
| Checkers tests | `cargo test -p checkers_game` |
| Chess tests | `cargo test -p chess_game` |
| Backgammon tests | `cargo test -p backgammon_game` |
| TCP transport tests | `cargo test -p open_table_transport_tcp` |
| Native bridge tests | `cargo test -p open_table_transport_native_bridge` |
| Engine pipeline tests | `cargo test -p open_table_engine` |
| Macro derive tests | `cargo test -p open_table_macros` |
| QR join flow tests | `cargo test -p open_table_qr` |
| Build Godot extension | `cargo build -p open_table_godot` |
| Godot bridge smoke test | `redot --headless --path godot_project --script res://tests/bridge_smoke.gd` |
| NativeP2PAdapter test | `redot --headless --path godot_project --script res://tests/test_native_p2p_adapter.gd` |
| TCP bridge scene (timed) | `bash run_test.sh` |
| Clippy all crates | `cargo clippy --workspace -- -D warnings` |
| Format check | `cargo fmt --all -- --check` |
