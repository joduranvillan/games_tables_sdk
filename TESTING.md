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
| `checkers_game` | 18 | Tablero inicial, avance simple, fuera de turno, restricción hacia atrás, captura simple/múltiple/triple, coronación, fin de partida, captura obligatoria, persistencia y AI |
| `chess_game` | 22 | Setup inicial, doble avance de peón, movimientos legales (alfil, caballo, torre), capturas, jaque propio, jaque mate, en passant, enroque, promoción, tablas (oferta, repetición, 50 movimientos, ahogado, material insuficiente), rendición y AI |
| `go_game` | 10 | Colocación y captura simple/grupo de 3 piedras, doble pase, suicidio rechazado, superko (prevención de repetición), handicap de 4 piedras, marcado de piedras muertas, scoring de territorio y AI |
| `shogi_game` | 11 | Movimiento y drop de mano, promoción forzada en zona rival, nifu (doble peón en columna), uchifuzume (drop mate prohibido), restricciones de lanza y caballo, dragón, caballo promovido, jaque descubierto, jaque mate, captura de promovida y AI |
| `xiangqi_game` | 10 | Movimiento de soldado y captura, general volador prohibido, restricción del río para elefantes, bloqueo de ojo de elefante, bloqueo de pata de caballo, cañón (movimiento y plataforma de captura), palacio para guardias, jaque mate y AI |
| `uno_game` | 9 | Skip card, acumulación de Draw Two (+2), Wild Draw Four (+4 legal/ilegal), reversa en dos jugadores, robo con juego inmediato, remezcla de mazo e intercepción con carta idéntica |
| `backgammon_game` | 18 | Setup inicial de 15 fichas, dados pendientes, consumo de dados, captura a la barra (blot), reentrada obligatoria, salida de fichas (bearing-off), dobles (4 dados), auto-pase sin jugadas válidas, bearing-off con pieza más atrasada, property testing y AI |
| `battleship_game` | 15 | Colocación de flota válida y privada, rechazo de tamaños incorrectos, disparos antes de setup, impactos (hit) y agua (miss), hundimiento total, disparos duplicados, flotas superpuestas/diagonales rechazadas |
| `ludo_game` | 18 | Partidas de 2 a 4 jugadores, tiro obligatorio antes de mover, salida de base con 6, turno extra por 6, capturas a la base, 4 fichas en meta (victoria), auto-pase sin jugadas, casillas seguras, bloqueos, recorrido de 52 casillas y AI |
| `mille_bornes_game` | 14 | Reparto inicial y manos privadas, robo de cartas, cartas de distancia, peligros (hazards) y remedios, meta exacta de 1000 km, rechazo de sobrepaso, descartes, límite de velocidad, coup-fourré y extensión de viaje |
| `monopoly_game` | 19 | Setup inicial y dinero, compra de propiedades y subastas, cobro de rentas, grupo de color completo (renta doble), ferrocarriles y servicios, impuestos de renta/lujo, cárcel e intentos de salida, quiebra y transferencia de bienes |
| `crisis_game` | 16 | Conquista táctica TEG (30 territorios, 6 continentes), resolución de combate con dados, conquista y robo de cartas, canje progresivo de tríos (+4, +6, +8, ...), bonus continental, eliminación de jugadores, objetivos secretos y test de estrés |
| `chinese_checkers_game` | 8 | Setup con 10 fichas por jugador, pasos simples, casillas ocupadas, saltos sin captura, cadenas de 3 saltos consecutivos, soporte de hasta 6 jugadores, victoria por llegada completa y property testing |

---

## 4. Key Test Scenarios — Per Game

### Checkers (`checkers_game/tests/game_rules.rs`, `property.rs`)

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
| `captura_triple_mantiene_el_turno_durante_tres_saltos` | Turn stays active through a 3-jump capture sequence |
| `persistencia_de_partida_save_and_load_from_file` | Session serialize and deserialize roundtrip |
| `test_dama_puede_capturar_hacia_atras` | King piece moves and captures backwards |
| `test_cadena_de_tres_saltos_consecutivos` | Multi-jump execution completes successfully |
| `test_checkers_ai_captura_multiple_cuando_puede` | AI prioritizes multi-jump capture when available |
| `movimiento_aleatorio_nunca_paniquea` (`property.rs`) | Proptest fuzzing of random moves against checkers engine |

### Chess (`chess_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_legal_moves_posicion_inicial_tiene_20_jugadas` | Legal move generator returns exactly 20 initial moves |
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
| `flujo_completo_de_oferta_y_aceptacion_de_tablas` | Offer and acceptance of draw agreement |
| `test_triple_repeticion_produce_tablas` | Threefold repetition triggers draw |
| `test_regla_50_movimientos_produce_tablas` | 50-move rule without pawn move or capture triggers draw |
| `test_ahogado_produce_tablas` | Stalemate triggers draw |
| `test_material_insuficiente_rey_vs_rey_produce_tablas` | Insufficient material (K vs K) triggers draw |
| `test_torre_no_puede_saltar_sobre_piezas` | Rook movement blocked by intervening pieces |
| `test_en_passant_no_disponible_un_turno_despues` | En passant opportunity expires after one turn |
| `test_rendicion_termina_la_partida` | Resignation ends game with opponent victory |
| `test_chess_ai_no_mueve_rey_a_casilla_atacada` | AI avoids moving King into check |

### Go (`go_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_place_stone_and_capture` | `StonesCapturedEvent.count == 1` when last liberty removed |
| `test_pass_ends_game` | Consecutive passes from both players emit `GameOverEvent` |
| `test_suicidio_es_rechazado` | Placement with no liberties and no capture rejected |
| `test_captura_de_grupo_de_tres_piedras` | Group capture removing 3 adjacent stones |
| `test_superko_previene_repeticion_de_posicion` | Superko rule prevents board state repetition |
| `test_handicap_de_cuatro_piedras_se_coloca_correctamente` | 4-stone handicap setup on star points |
| `test_marcado_y_confirmacion_de_muertas` | Dead stone marking and agreement in counting phase |
| `go_partida_completa_hasta_scoring_de_territorio` | Full game played through territorial score resolution |
| `test_pasar_fuera_de_turno_es_rechazado` | Out-of-turn pass rejected |
| `test_go_ai_devuelve_movimiento_o_none_en_posicion_inicial` | Go AI returns valid move in initial position |

### Shogi (`shogi_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_move_and_drop` | Pawn captured goes into `BoardResource.hands[SENTE]`; drop removes from hand and appears on board |
| `test_forced_promotion_en_zona_rival` | Mandatory promotion when pawn/lance reaches back rank |
| `test_nifu_rechaza_drop_en_columna_con_peon` | Nifu (two unpromoted pawns in same column) drop rejected |
| `test_uchifuzume_rechaza_drop_de_peon_con_jaque_mate_inmediato` | Uchifuzume (pawn drop checkmate) rejected |
| `test_lanza_no_puede_droppear_en_ultima_fila` | Lance drop on back rank rejected |
| `test_caballo_no_puede_droppear_en_penultima_fila` | Knight drop on rank 8/9 rejected |
| `test_dragon_puede_moverse_ortogonal_y_diagonalmente` | Promoted Rook (Dragon) orthogonal + 1-step diagonal moves |
| `test_horse_puede_moverse_diagonal_y_ortogonalmente` | Promoted Bishop (Horse) diagonal + 1-step orthogonal moves |
| `test_mover_pieza_que_descubre_jaque_propio_es_rechazado` | Discovery check on own king rejected |
| `test_jaque_mate_termina_la_partida` | Checkmate triggers game over |
| `test_capturar_pieza_promovida_la_agrega_despromovida_al_hand` | Captured promoted piece returns to unpromoted state in hand |

### Xiangqi (`xiangqi_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_move_and_capture` | Soldier advance and capture across river |
| `flying_general_rechaza_movimiento_que_los_enfrenta` | Flying General (opposing generals facing directly) move rejected |
| `test_elefante_no_puede_cruzar_el_rio` | Elephant restricted to own side of the river |
| `test_ojo_del_elefante_bloqueado_invalida_movimiento` | Elephant eye blocking restricts movement |
| `test_pata_de_caballo_bloqueada_invalida_movimiento` | Horse leg (hobbling) blocks knight jump |
| `test_canon_movimiento_simple_bloqueado_por_pieza_interpuesta` | Cannon non-capture blocked by intervening piece |
| `test_canon_captura_valida_con_una_plataforma` | Cannon capture valid with exactly one platform |
| `test_canon_captura_invalida_sin_plataforma` | Cannon capture rejected without screen/platform |
| `test_guardia_no_puede_salir_del_palacio` | Advisor/Guard restricted to the 3x3 palace |
| `test_jaque_mate_termina_la_partida_en_xiangqi` | Checkmate terminates match with winner |

### UNO (`uno_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_play_and_skip` | Skip card skips P2, `TurnResource` advances to P3 |
| `test_stacking_draw_two` | `UnoState.draw_penalty` accumulates to 4; forced draw resolves |
| `test_wild_draw_four_ilegal_si_tienes_carta_del_color` | Illegal Wild Draw Four challenge handling |
| `test_reversa_es_skip_en_dos_jugadores` | Reverse acts as skip in 2-player game |
| `test_robar_cuando_no_hay_jugada_avanza_el_turno_o_juega_inmediatamente` | Draw card on empty turn and optional play |
| `test_mazo_agotado_se_remezcla_desde_descarte` | Reshuffling discard pile into draw deck when empty |
| `test_mazo_y_descarte_agotados_no_produce_panic` | Graceful handling when both deck and discard are exhausted |
| `test_intercepcion_valida_con_carta_identica` | Jump-in interception with identical card out of turn |
| `test_intercepcion_invalida_con_carta_similar_pero_diferente_color` | Invalid jump-in rejected |

### Backgammon (`backgammon_game/tests/game_rules.rs`, `property.rs`)

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
| `movimiento_aleatorio_nunca_paniquea` (`property.rs`) | Proptest fuzzing of random moves on backgammon engine |

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
| `test_token_no_puede_entrar_en_columna_de_casa_rival` | Token restricted from entering opposing home columns |
| `test_bloqueo_impide_que_rival_aterrice_en_casilla` | Blockade with two tokens prevents landing |
| `test_ficha_recorre_tablero_completo_en_52_pasos` | Full board traversal to home column |
| `ludo_de_4_jugadores_hasta_victoria` | Complete 4-player game played through victory |

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
| `test_coup_fourre_contraataca_y_anula_peligro` | Coup-fourré counter-attack cancels hazard instantly |
| `test_derecho_de_via_bloquea_todos_los_hazards` | Right of Way safety blocks all vehicle hazards |
| `test_extension_de_viaje_a_1000_cuando_se_agotan_las_200` | Voyage extension to 1000 km |

### Monopoly (`monopoly_game/tests/game_rules.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_tablero_estandar_40_casillas_con_todas_las_variantes` | Full 40-square board layout with color groups, railroads and utilities |
| `test_10_cartas_de_suerte_y_10_de_arca_comunitaria` | Chance and Community Chest card decks initialized |
| `el_setup_arranca_con_dinero_estandar_y_posicion_cero` | `STARTING_MONEY` and position 0 for all players |
| `moverse_a_una_propiedad_sin_dueno_deja_una_decision_pendiente_y_no_avanza_el_turno` | `PendingPurchaseResource` populated; turn not advanced |
| `no_se_puede_tirar_de_nuevo_con_una_compra_pendiente` | Roll rejected while pending decision exists |
| `comprar_una_propiedad_descuenta_el_precio_y_asigna_el_dueno` | Money decremented; property assigned to P1; turn advances |
| `caer_en_propiedad_ajena_paga_renta_al_dueno` | `RentPaidEvent.amount == 10` |
| `poseer_todo_el_grupo_de_color_duplica_la_renta` | Rent doubles when owner holds full color group |
| `quedarse_sin_dinero_tras_pagar_renta_termina_la_partida` | `GameOverEvent.winner == P2` on bankruptcy |
| `test_caer_en_go_to_jail_envia_a_jail_y_emite_jailed_event` | Landing on Go To Jail sends player to Jail |
| `test_rechazo_de_compra_inicia_subasta` | Declining purchase triggers auction mechanism |
| `test_renta_de_servicio_es_4x_con_uno_y_10x_con_dos` | Utility multiplier scales with owned utility count |
| `test_renta_de_ferrocarril_escala_con_cantidad_de_estaciones` | Railroad rent scales with station count |
| `test_quiebra_transfiere_propiedades_al_acreedor` | Bankruptcy transfers mortgaged assets to creditor |

### Crisis (`crisis_game/tests/full_game.rs`, `game_rules.rs`, `stress.rs`, `property.rs`)

| Test Function | What It Verifies |
|---|---|
| `test_partida_teg_de_dos_jugadores_hasta_victoria_por_objetivo` (`full_game.rs`) | Full 2-player TEG match played until secret objective completion |
| `test_canje_de_tarjetas_da_ejercitos_extra` (`full_game.rs`) | Card set exchange grants progressive extra armies (+4, +6, +8...) |
| `test_eliminacion_de_jugador_con_tres_jugadores` (`full_game.rs`) | Player elimination, card inheritance and turn skipping in 3-player match |
| `test_setup_distribuye_todos_los_territorios` (`game_rules.rs`) | Initial setup distributes all 30 territories evenly among players |
| `test_ataque_resolucion_dados_reduce_ejercitos` (`game_rules.rs`) | Dice combat resolution with ordered comparisons reducing defender/attacker armies |
| `test_conquista_transfiere_territorio_al_atacante` (`game_rules.rs`) | Territory conquest transfers ownership and draws territory card |
| `test_player_eliminado_sale_del_ciclo_de_turnos` (`game_rules.rs`) | Eliminated players are permanently omitted from turn rotation |
| `test_game_over_por_objetivo_conquistar_continente` (`game_rules.rs`) | Continent conquest objective triggers game over |
| `test_bonus_de_continente_se_aplica_al_inicio_del_turno` (`game_rules.rs`) | Controlling entire continent awards bonus armies in placement phase |
| `test_serializar_y_deserializar_declare_attack_command_roundtrip` (`game_rules.rs`) | Command serialization and deserialization roundtrip |
| `test_crisis_session_rechaza_mas_de_seis_jugadores` (`game_rules.rs`) | Sessions exceeding 6 players rejected |
| `test_crisis_error_paths_cobertura_de_ramas` (`game_rules.rs`) | Branch error coverage for invalid moves, out-of-phase actions and invalid targets |
| `test_estres_motor_teg` (`stress.rs`) | 1000-turn stress test of random valid actions without engine panics |
| `ataque_con_dados_aleatorios_no_paniquea` (`property.rs`) | Proptest fuzzing of random attack and defense dice combinations |

### Chinese Checkers (`chinese_checkers_game/tests/game_rules.rs`, `property.rs`)

| Test Function | What It Verifies |
|---|---|
| `el_setup_pone_10_fichas_por_jugador_en_esquinas_opuestas` | 10 pegs per player in `BoardResource.pegs` |
| `un_paso_simple_a_una_casilla_vacia_es_valido` | `PegMovedEvent.was_jump == false` |
| `no_se_puede_mover_a_una_casilla_ocupada` | Move to occupied square rejected |
| `saltar_sobre_cualquier_ficha_no_la_captura_solo_permite_pasar` | `was_jump == true`; jumped piece survives on board |
| `test_seis_jugadores_ciclan_correctamente` | Turn cycle validation for 6-player match |
| `test_victoria_cuando_todas_las_fichas_llegan_al_triangulo_opuesto` | `GameOverEvent.winner == P1` after placing 10th peg in target zone |
| `test_cadena_de_tres_saltos_consecutivos` | 3-jump chain traversal in single turn |
| `movimiento_aleatorio_nunca_paniquea` (`property.rs`) | Proptest fuzzing of random jumps and steps on star board |

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

**Godot headless execution:** The headless `bridge_smoke.gd` and visual regression tests verify bridge signal dispatch and rendered frames against reference snapshots, but interactive audio/haptic responses require running with full display server.

**Replay with game-specific types:** `Session::replay` is tested in `open_table_engine/tests/dice_game.rs`. Replay with `chess_game::MovePieceCommand` or other specific game commands is exercised via normal command processing rather than separate standalone replay test suites.

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

## Test de Estabilidad de Memoria

El motor incluye un test de estrés de memoria para asegurar que no existan fugas al procesar comandos repetitivamente (`memory_stability`). Este test está ignorado por defecto (`#[ignore]`) porque toma más tiempo de lo usual y depende de lecturas del sistema (RSS).

Para correr el test manualmente, usar:

```bash
cargo test --test memory_stability -- --ignored
```
