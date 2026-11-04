# OpenTable SDK — Reporte Maestro de Cobertura y Diagnóstico para IA (`TEST_SUMMARY.md`)

> **Propósito de este documento**: Este archivo es generado automáticamente por `games_tables_sdk/tools/generate_test_summary.sh`. Contiene el mapa completo de cobertura de pruebas de **Rust** y **Godot/Redot 4.4** para los **14 juegos de mesa** del SDK, junto con referencias exactas `archivo:línea`, contratos JSON del puente GDExtension y recetas de auto-reparación diseñadas para que cualquier **Agente de IA** pueda diagnosticar y corregir regresiones sin pérdida de contexto.

---

## 1. Resumen Ejecutivo y Estado Global del Workspace

- **Estado Global del Proyecto**: **PASS (100% VERIFICADO — 0 ERRORES)**
- **Modo de Verificación**: Verificación Híbrida (`run_godot_tests.sh` + Inspector Estático AST Rust/GDScript)
- **Juegos Verificados**: **14 / 14** juegos completos (Motor Rust + Bridge GDExtension + Tablero Godot + Smoke Tests + Docs)
- **Juegos con Dados 3D (`DiceRoller3D` + `DiceWidget`)**: **5 / 5** (`backgammon`, `ludo`, `monopoly`, `crisis`, `goose`)
- **Total de Tests en Rust (`#[test]`)**: **456** tests distribuidos en 20 crates:
  - Tests Unitarios en Juegos (`<game>_game/src/**`): **45**
  - Tests de Reglas de Juego (`<game>_game/tests/game_rules.rs`): **235**
  - Tests de Reglas Canónicas (`<game>_game/tests/canonical_rules.rs`): **39**
  - Tests de Crates Core (`open_table_*`): **137**
- **Total de Suites Smoke Test en Godot (`godot_project/tests/*.gd`)**: **45** scripts (**628** puntos de aserción/verificación)
- **Paridad Espejo de Tableros (`godot_project/*_board.gd` ↔ `godot_project/scenes/*_board.gd`)**: **14 / 14** sincronizados byte a byte
- **Cumplimiento Tipado Estricto Redot 4.4 (`Variant` Inference Check)**: **0** violaciones detectadas

---

## 2. Matriz de Cobertura de los 14 Juegos

| # | Juego | Crate Rust | Unit (`src/`) | Reglas (`game_rules.rs`) | Canónicos (`canonical_rules.rs`) | Total Rust | Funciones Bridge | Tablero Godot + Paridad `scenes/` | Dados 3D (`DiceRoller3D`) | Smoke Test Godot | Docs | Estado |
| :-: | :--- | :--- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :--- | :-: | :-: |
| 1 | **Ajedrez (Chess)** | `chess_game` | 11 | 22 | 2 | **35** | 8 | `1474L` (OK (Sync)) | N/A | `chess_smoke.gd` (16 asserts) | OK | **PASS** |
| 2 | **Damas (Checkers)** | `checkers_game` | 3 | 20 | 3 | **26** | 3 | `911L` (OK (Sync)) | N/A | `bridge_smoke.gd` (14 asserts) | OK | **PASS** |
| 3 | **Go (Weiqi / Baduk)** | `go_game` | 3 | 13 | 3 | **19** | 4 | `1116L` (OK (Sync)) | N/A | `go_smoke.gd` (15 asserts) | OK | **PASS** |
| 4 | **Shogi (Ajedrez Japonés)** | `shogi_game` | 1 | 14 | 3 | **18** | 3 | `1092L` (OK (Sync)) | N/A | `shogi_smoke.gd` (13 asserts) | OK | **PASS** |
| 5 | **Xiangqi (Ajedrez Chino)** | `xiangqi_game` | 1 | 13 | 2 | **16** | 3 | `1077L` (OK (Sync)) | N/A | `xiangqi_smoke.gd` (8 asserts) | OK | **PASS** |
| 6 | **Backgammon** | `backgammon_game` | 4 | 19 | 3 | **26** | 2 | `748L` (OK (Sync)) | Sí (3D OK) | `backgammon_smoke.gd` (9 asserts) | OK | **PASS** |
| 7 | **Batalla Naval (Battleship)** | `battleship_game` | 3 | 18 | 2 | **23** | 2 | `1419L` (OK (Sync)) | N/A | `battleship_smoke.gd` (13 asserts) | OK | **PASS** |
| 8 | **Ludo / Parchís** | `ludo_game` | 2 | 22 | 3 | **27** | 2 | `696L` (OK (Sync)) | Sí (3D OK) | `ludo_smoke.gd` (10 asserts) | OK | **PASS** |
| 9 | **Mille Bornes (1000 Millas)** | `mille_bornes_game` | 2 | 19 | 3 | **24** | 3 | `1201L` (OK (Sync)) | N/A | `mille_bornes_smoke.gd` (5 asserts) | OK | **PASS** |
| 10 | **Monopoly (Magnate Inmobiliario)** | `monopoly_game` | 2 | 31 | 3 | **36** | 2 | `1824L` (OK (Sync)) | Sí (3D OK) | `monopoly_smoke.gd` (14 asserts) | OK | **PASS** |
| 11 | **UNO** | `uno_game` | 2 | 14 | 3 | **19** | 3 | `2324L` (OK (Sync)) | N/A | `uno_smoke.gd` (21 asserts) | OK | **PASS** |
| 12 | **Crisis / TEG (Estrategia Global)** | `crisis_game` | 7 | 15 | 2 | **24** | 7 | `2104L` (OK (Sync)) | Sí (3D OK) | `crisis_smoke.gd` (18 asserts) | OK | **PASS** |
| 13 | **Damas Chinas (Chinese Checkers)** | `chinese_checkers_game` | 3 | 12 | 2 | **17** | 3 | `661L` (OK (Sync)) | N/A | `chinese_checkers_smoke.gd` (7 asserts) | OK | **PASS** |
| 14 | **El Juego de la Oca (Game of the Goose)** | `goose_game` | 1 | 3 | 5 | **9** | 3 | `514L` (OK (Sync)) | Sí (3D OK) | `goose_smoke.gd` (5 asserts) | OK | **PASS** |

---

## 3. Cobertura de Crates Base del Motor (`open_table_*`)

| Crate | Propósito Arquitectónico | Total Tests (`#[test]`) | Ubicaciones Clave (`archivo:línea`) |
| :--- | :--- | :-: | :--- |
| `open_table_core` | ECS determinista, World, Resources, Commands, Events y hashing de estado | **2** | `open_table_core/tests/scalability.rs:84` (`comandos_de_juegos_distintos_viajan_por_el_mismo_canal`), `open_table_core/tests/scalability.rs:111` (`visibilidad_filtra_eventos_de_informacion_oculta`) |
| `open_table_engine` | Motor de sesiones de mesa, turnos, validación de comandos y snapshots | **79** | `open_table_engine/src/elo.rs:43` (`test_victoria_sube_elo_del_ganador`), `open_table_engine/src/elo.rs:54` (`test_empate_iguala_elos_similares`), `open_table_engine/src/elo.rs:72` (`test_victoria_contra_favorito_da_mayor_delta`), `open_table_engine/tests/api_contract.rs:7` (`contrato_cross_crate_de_constructores_de_sesion`), ... (+75 más) |
| `open_table_net` | Protocolo de red determinista, sincronización P2P/Relay y serialización | **0** | Verificado vía integración en crates de juego |
| `open_table_godot` | Puente GDExtension (Rust <-> Godot/Redot 4.4) con sesiones para los 14 juegos | **3** | `open_table_godot/src/lib.rs:4697` (`extended_ai_engines_produce_valid_commands_in_easy_mode`), `open_table_godot/src/lib.rs:4738` (`test_parse_command_json_polymorphic_new_commands`), `open_table_godot/tests/godot_api_surface.rs:5` (`test_godot_bridge_api_surface_compilation`) |
| `open_table_relay` | Servidor relay autoritativo y módulo anticheat para los 14 juegos | **53** | `open_table_relay/src/anticheat.rs:855` (`test_anticheat_supports_all_13_canonical_games_with_seed`), `open_table_relay/src/anticheat.rs:872` (`test_anticheat_chess_legal_and_illegal_moves`), `open_table_relay/src/anticheat.rs:893` (`test_anticheat_checkers_legal_and_illegal_moves`), `open_table_relay/src/anticheat.rs:914` (`test_anticheat_all_13_games_validate_rules_and_active_turn`), ... (+49 más) |
| `open_table_schema` | Esquemas compartidos, identificadores y contratos de serialización JSON | **0** | Verificado vía integración en crates de juego |

---

## 4. Diagnóstico de Errores Detectados (`Actionable Failures & Warnings`)

### Estado Limpio: `0 Errores Detectados`

Todas las suites de Rust (14 juegos + 6 crates core), los 45 smoke tests de Godot/Redot, la validación de tipado estricto Redot 4.4 y la paridad byte a byte de `godot_project/scenes/` se encuentran en estado **PASS**.

> **Nota para Agentes de IA**: Si en el futuro introduces un cambio que rompa un test, desincronice un tablero o introduzca una inferencia `:=` inválida sobre un `Variant`, vuelve a ejecutar `bash games_tables_sdk/tools/generate_test_summary.sh` y esta sección listará automáticamente cada fallo con su ID, `archivo:línea`, traza de error y receta exacta de reparación.

---

## 5. Catálogo Detallado de los 14 Juegos (Mapa `archivo:línea` para IA)

Cada subsección incluye las rutas exactas, funciones del puente GDExtension, contratos de serialización JSON y la ubicación `archivo:línea` de cada test en Rust y Godot para facilitar ediciones precisas.

### 5.1. Ajedrez (Chess) (`chess_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/chess_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/chess_game/tests/game_rules.rs` (**22** tests)
  - **Tests Canónicos**: `games_tables_sdk/chess_game/tests/canonical_rules.rs` (**2** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (8 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/chess_board.gd` ↔ `games_tables_sdk/godot_project/scenes/chess_board.gd` (1474 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/chess_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/chess.md`
- **Contrato de Estado JSON (`get_state_json`)**: `board (64 casillas), turn (White/Black), castling_rights, en_passant, halfmove_clock, in_check, status`
- **Comandos del Motor (`dispatch_command`)**: `MovePieceCommand { from, to, promotion }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_chess` (línea 871), `set_chess_ai_depth` (línea 881), `start_local_match_chess_vs_ai` (línea 886), `load_chess_fen` (línea 1402), `export_chess_fen` (línea 1423), `export_chess_pgn` (línea 1441), `export_chess_pgn_named` (línea 1458), `chess_ai_pick_move` (línea 3242)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_chess_ai_best_move_con_dificultades` (`chess_game/src/ai.rs:330`), `test_chess_ai_devuelve_movimiento_en_posicion_inicial` (`chess_game/src/ai.rs:339`), `test_chess_ai_captura_reina_expuesta` (`chess_game/src/ai.rs:358`), `test_chess_ai_none_cuando_partida_terminada` (`chess_game/src/ai.rs:385`), `test_chess_ai_none_si_no_es_turno` (`chess_game/src/ai.rs:393`), `test_cargar_posicion_desde_fen_inicializa_tablero_correcto` (`chess_game/src/fen.rs:141`), `test_opening_book_lookup_initial_position` (`chess_game/src/opening_book.rs:255`), `test_opening_book_respects_difficulty_flag` (`chess_game/src/opening_book.rs:273`), `test_opening_book_binary_size_under_100kb` (`chess_game/src/opening_book.rs:282`), `test_exportar_partida_a_pgn_produce_formato_valido` (`chess_game/src/pgn.rs:218`), `test_export_fen_posicion_inicial_y_tras_e4` (`chess_game/src/pgn.rs:286`)
  - *Reglas (`tests/game_rules.rs`)*: `test_legal_moves_posicion_inicial_tiene_20_jugadas` (`chess_game/tests/game_rules.rs:33`), `el_setup_inicial_tiene_16_piezas_por_jugador` (`chess_game/tests/game_rules.rs:44`), `un_peon_puede_avanzar_dos_casillas_en_su_primer_movimiento` (`chess_game/tests/game_rules.rs:54`), `un_movimiento_no_diagonal_ni_recto_de_alfil_es_rechazado` (`chess_game/tests/game_rules.rs:63`), `un_caballo_puede_saltar_piezas_en_su_primer_movimiento` (`chess_game/tests/game_rules.rs:72`), `capturar_una_pieza_rival_la_quita_del_tablero` (`chess_game/tests/game_rules.rs:80`), `una_jugada_que_deja_al_propio_rey_en_jaque_es_rechazada` (`chess_game/tests/game_rules.rs:128`), `jaque_mate_por_columna_trasera_termina_la_partida` (`chess_game/tests/game_rules.rs:171`), `captura_al_paso_de_peon_funciona` (`chess_game/tests/game_rules.rs:237`), `enroque_corto_blanco_funciona` (`chess_game/tests/game_rules.rs:297`), `coronacion_con_eleccion_de_pieza` (`chess_game/tests/game_rules.rs:351`), `flujo_completo_de_oferta_y_aceptacion_de_tablas` (`chess_game/tests/game_rules.rs:407`), `hacer_un_movimiento_rechaza_y_limpia_la_oferta_de_tablas_pendiente` (`chess_game/tests/game_rules.rs:440`), `no_se_puede_aceptar_una_oferta_de_tablas_inexistente_o_propia` (`chess_game/tests/game_rules.rs:463`), `test_triple_repeticion_produce_tablas` (`chess_game/tests/game_rules.rs:484`), `test_regla_50_movimientos_produce_tablas` (`chess_game/tests/game_rules.rs:513`), `test_ahogado_produce_tablas` (`chess_game/tests/game_rules.rs:533`), `test_material_insuficiente_rey_vs_rey_produce_tablas` (`chess_game/tests/game_rules.rs:573`), `test_torre_no_puede_saltar_sobre_piezas` (`chess_game/tests/game_rules.rs:606`), `test_en_passant_no_disponible_un_turno_despues` (`chess_game/tests/game_rules.rs:649`), `test_rendicion_termina_la_partida` (`chess_game/tests/game_rules.rs:702`), `test_chess_ai_no_mueve_rey_a_casilla_atacada` (`chess_game/tests/game_rules.rs:716`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_enroque_en_passant_y_tablas_50_movimientos` (`chess_game/tests/canonical_rules.rs:15`), `canonical_subpromocion_y_rechazo_tablas_sin_oferta` (`chess_game/tests/canonical_rules.rs:83`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/chess_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `chess_smoke.gd`*: **16** verificaciones (ej. líneas 30, 40, 41, 42, 52, 53, 77, 78)

### 5.2. Damas (Checkers) (`checkers_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/checkers_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/checkers_game/tests/game_rules.rs` (**20** tests)
  - **Tests Canónicos**: `games_tables_sdk/checkers_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (3 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/checkers_board.gd` ↔ `games_tables_sdk/godot_project/scenes/checkers_board.gd` (911 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/bridge_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/checkers.md`
- **Contrato de Estado JSON (`get_state_json`)**: `board (8x8), current_turn (Red/Black), mandatory_capture_from, must_continue_jump, winner`
- **Comandos del Motor (`dispatch_command`)**: `MoveCheckerCommand { from_row, from_col, to_row, to_col }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_checkers` (línea 518), `start_local_match_checkers_vs_ai` (línea 523), `checkers_ai_pick_move` (línea 3231)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_ai_always_returns_a_move_when_board_not_over` (`checkers_game/src/ai.rs:153`), `test_ai_returns_none_when_game_over` (`checkers_game/src/ai.rs:181`), `test_ai_returns_none_when_not_player_turn` (`checkers_game/src/ai.rs:193`)
  - *Reglas (`tests/game_rules.rs`)*: `test_get_legal_moves_devuelve_solo_movimientos_validos` (`checkers_game/tests/game_rules.rs:16`), `test_undo_revierte_el_estado_al_tick_anterior` (`checkers_game/tests/game_rules.rs:27`), `el_tablero_inicial_tiene_12_fichas_por_jugador` (`checkers_game/tests/game_rules.rs:52`), `un_movimiento_simple_hacia_adelante_es_valido` (`checkers_game/tests/game_rules.rs:77`), `no_se_puede_mover_fuera_de_turno` (`checkers_game/tests/game_rules.rs:103`), `no_se_puede_mover_hacia_atras_sin_ser_dama` (`checkers_game/tests/game_rules.rs:112`), `una_captura_remueve_la_ficha_saltada` (`checkers_game/tests/game_rules.rs:129`), `una_ficha_se_corona_al_llegar_a_la_ultima_fila` (`checkers_game/tests/game_rules.rs:180`), `el_juego_termina_cuando_un_jugador_pierde_todas_sus_fichas` (`checkers_game/tests/game_rules.rs:217`), `captura_obligatoria_rechaza_movimientos_simples_si_hay_captura` (`checkers_game/tests/game_rules.rs:271`), `captura_multiple_mantiene_el_turno_y_obliga_a_usar_la_misma_ficha` (`checkers_game/tests/game_rules.rs:310`), `captura_triple_mantiene_el_turno_durante_tres_saltos` (`checkers_game/tests/game_rules.rs:376`), `persistencia_de_partida_save_and_load_from_file` (`checkers_game/tests/game_rules.rs:476`), `test_captura_obligatoria_rechaza_movimiento_simple_si_hay_captura_disponible` (`checkers_game/tests/game_rules.rs:522`), `test_dama_puede_capturar_hacia_atras` (`checkers_game/tests/game_rules.rs:561`), `test_cadena_de_tres_saltos_consecutivos` (`checkers_game/tests/game_rules.rs:611`), `test_checkers_ai_captura_multiple_cuando_puede` (`checkers_game/tests/game_rules.rs:689`), `test_victoria_por_bloqueo_total_sin_movimientos_legales` (`checkers_game/tests/game_rules.rs:731`), `test_tablas_por_40_movimientos_sin_captura_ni_coronacion` (`checkers_game/tests/game_rules.rs:791`), `test_draw_clock_se_reinicia_en_captura_o_coronacion` (`checkers_game/tests/game_rules.rs:881`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_victoria_por_bloqueo_sin_movimientos_legales` (`checkers_game/tests/canonical_rules.rs:19`), `canonical_tablas_por_40_turnos_sin_captura_ni_coronacion` (`checkers_game/tests/canonical_rules.rs:76`), `canonical_reinicio_reloj_tablas_y_captura_obligatoria` (`checkers_game/tests/canonical_rules.rs:157`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/bridge_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 8)
  - *Total de aserciones/chequeos en `bridge_smoke.gd`*: **14** verificaciones (ej. líneas 21, 25, 27, 28, 29, 30, 34, 35)

### 5.3. Go (Weiqi / Baduk) (`go_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/go_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/go_game/tests/game_rules.rs` (**13** tests)
  - **Tests Canónicos**: `games_tables_sdk/go_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (4 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/go_board.gd` ↔ `games_tables_sdk/godot_project/scenes/go_board.gd` (1116 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/go_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/go.md`
- **Contrato de Estado JSON (`get_state_json`)**: `size (9/13/19), grid, current_stone (Black/White), captures_black, captures_white, ko_point, consecutive_passes`
- **Comandos del Motor (`dispatch_command`)**: `PlaceStoneCommand { x, y }, PassTurnCommand`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_go` (línea 661), `set_go_board_size` (línea 671), `start_local_match_go_vs_ai` (línea 704), `export_go_sgf` (línea 1480)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_go_ai_devuelve_movimiento_o_none_en_posicion_inicial` (`go_game/src/ai.rs:258`), `test_export_sgf_incluye_metadatos_tamano_y_secuencia_de_piedras` (`go_game/src/sgf.rs:113`), `test_board_resource_export_sgf_directo` (`go_game/src/sgf.rs:155`)
  - *Reglas (`tests/game_rules.rs`)*: `test_place_stone_and_capture` (`go_game/tests/game_rules.rs:12`), `test_pass_ends_game` (`go_game/tests/game_rules.rs:60`), `test_suicidio_es_rechazado` (`go_game/tests/game_rules.rs:92`), `test_captura_de_grupo_de_tres_piedras` (`go_game/tests/game_rules.rs:119`), `test_superko_previene_repeticion_de_posicion` (`go_game/tests/game_rules.rs:187`), `test_handicap_de_cuatro_piedras_se_coloca_correctamente` (`go_game/tests/game_rules.rs:240`), `test_marcado_y_confirmacion_de_muertas` (`go_game/tests/game_rules.rs:273`), `go_partida_completa_hasta_scoring_de_territorio` (`go_game/tests/game_rules.rs:325`), `test_pasar_fuera_de_turno_es_rechazado` (`go_game/tests/game_rules.rs:383`), `test_go_ai_devuelve_movimiento_o_none_en_posicion_inicial` (`go_game/tests/game_rules.rs:393`), `test_prisioneros_se_acumulan_en_captura_y_piedras_muertas` (`go_game/tests/game_rules.rs:417`), `test_komi_6_5_desempata_a_favor_de_blancas_y_configurable_con_set_komi` (`go_game/tests/game_rules.rs:513`), `test_go_legal_move_generator_excluye_suicidio_y_ko_e_incluye_pass` (`go_game/tests/game_rules.rs:593`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_puntuacion_con_komi_6_5_y_prisioneros` (`go_game/tests/canonical_rules.rs:11`), `canonical_set_komi_modifica_komi_antes_de_jugar` (`go_game/tests/canonical_rules.rs:98`), `canonical_rechazo_set_komi_tardio_y_marcado_antes_de_doble_pase` (`go_game/tests/canonical_rules.rs:118`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/go_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `go_smoke.gd`*: **15** verificaciones (ej. líneas 37, 46, 47, 56, 66, 68, 76, 94)

### 5.4. Shogi (Ajedrez Japonés) (`shogi_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/shogi_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/shogi_game/tests/game_rules.rs` (**14** tests)
  - **Tests Canónicos**: `games_tables_sdk/shogi_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (3 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/shogi_board.gd` ↔ `games_tables_sdk/godot_project/scenes/shogi_board.gd` (1092 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/shogi_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/shogi.md`
- **Contrato de Estado JSON (`get_state_json`)**: `board (9x9), hands (Sente/Gote pieces in hand), current_player, promotion_zone, in_check`
- **Comandos del Motor (`dispatch_command`)**: `ShogiMoveCommand { from, to, promote }, ShogiDropCommand { piece_type, to }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_shogi` (línea 559), `start_local_match_shogi_vs_ai` (línea 578), `populate_full_shogi_board` (línea 4320)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_shogi_ai_devuelve_movimiento_en_posicion_inicial` (`shogi_game/src/ai.rs:387`)
  - *Reglas (`tests/game_rules.rs`)*: `test_move_and_drop` (`shogi_game/tests/game_rules.rs:8`), `test_forced_promotion_en_zona_rival` (`shogi_game/tests/game_rules.rs:107`), `test_nifu_rechaza_drop_en_columna_con_peon` (`shogi_game/tests/game_rules.rs:161`), `test_uchifuzume_rechaza_drop_de_peon_con_jaque_mate_inmediato` (`shogi_game/tests/game_rules.rs:194`), `test_lanza_no_puede_droppear_en_ultima_fila` (`shogi_game/tests/game_rules.rs:265`), `test_caballo_no_puede_droppear_en_penultima_fila` (`shogi_game/tests/game_rules.rs:292`), `test_dragon_puede_moverse_ortogonal_y_diagonalmente` (`shogi_game/tests/game_rules.rs:319`), `test_horse_puede_moverse_diagonal_y_ortogonalmente` (`shogi_game/tests/game_rules.rs:397`), `test_mover_pieza_que_descubre_jaque_propio_es_rechazado` (`shogi_game/tests/game_rules.rs:474`), `test_jaque_mate_termina_la_partida` (`shogi_game/tests/game_rules.rs:535`), `test_capturar_pieza_promovida_la_agrega_despromovida_al_hand` (`shogi_game/tests/game_rules.rs:610`), `test_sennichite_cuadruple_repeticion_declara_tablas` (`shogi_game/tests/game_rules.rs:679`), `test_fesa_promocion_opcional_y_obligatoria_por_fila` (`shogi_game/tests/game_rules.rs:766`), `test_shogi_legal_move_generator_registrado` (`shogi_game/tests/game_rules.rs:897`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_sennichite_cuadruple_repeticion_declara_tablas` (`shogi_game/tests/canonical_rules.rs:11`), `canonical_fesa_promocion_opcional_y_obligatoria` (`shogi_game/tests/canonical_rules.rs:84`), `canonical_captura_pieza_promocionada_vuelve_a_mano_sin_promocionar_y_drop` (`shogi_game/tests/canonical_rules.rs:205`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/shogi_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `shogi_smoke.gd`*: **13** verificaciones (ej. líneas 30, 40, 41, 42, 52, 53, 63, 88)

### 5.5. Xiangqi (Ajedrez Chino) (`xiangqi_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/xiangqi_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/xiangqi_game/tests/game_rules.rs` (**13** tests)
  - **Tests Canónicos**: `games_tables_sdk/xiangqi_game/tests/canonical_rules.rs` (**2** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (3 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/xiangqi_board.gd` ↔ `games_tables_sdk/godot_project/scenes/xiangqi_board.gd` (1077 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/xiangqi_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/xiangqi.md`
- **Contrato de Estado JSON (`get_state_json`)**: `board (10x9), current_turn (Red/Black), palace_bounds, river_crossed, flying_general_check`
- **Comandos del Motor (`dispatch_command`)**: `XiangqiMoveCommand { from_r, from_c, to_r, to_c }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_xiangqi` (línea 616), `start_local_match_xiangqi_vs_ai` (línea 629), `populate_full_xiangqi_board` (línea 4392)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_xiangqi_ai_devuelve_movimiento_en_posicion_inicial` (`xiangqi_game/src/ai.rs:278`)
  - *Reglas (`tests/game_rules.rs`)*: `test_move_and_capture` (`xiangqi_game/tests/game_rules.rs:8`), `flying_general_rechaza_movimiento_que_los_enfrenta` (`xiangqi_game/tests/game_rules.rs:51`), `test_elefante_no_puede_cruzar_el_rio` (`xiangqi_game/tests/game_rules.rs:101`), `test_ojo_del_elefante_bloqueado_invalida_movimiento` (`xiangqi_game/tests/game_rules.rs:152`), `test_pata_de_caballo_bloqueada_invalida_movimiento` (`xiangqi_game/tests/game_rules.rs:213`), `test_canon_movimiento_simple_bloqueado_por_pieza_interpuesta` (`xiangqi_game/tests/game_rules.rs:274`), `test_canon_captura_valida_con_una_plataforma` (`xiangqi_game/tests/game_rules.rs:336`), `test_canon_captura_invalida_sin_plataforma` (`xiangqi_game/tests/game_rules.rs:410`), `test_guardia_no_puede_salir_del_palacio` (`xiangqi_game/tests/game_rules.rs:468`), `test_jaque_mate_termina_la_partida_en_xiangqi` (`xiangqi_game/tests/game_rules.rs:519`), `test_kunbi_ahogado_sin_jaque_otorga_victoria_en_xiangqi` (`xiangqi_game/tests/game_rules.rs:597`), `test_triple_repeticion_xiangqi_declara_tablas` (`xiangqi_game/tests/game_rules.rs:681`), `test_xiangqi_legal_move_generator_registrado` (`xiangqi_game/tests/game_rules.rs:790`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_victoria_por_ahogado_kunbi` (`xiangqi_game/tests/canonical_rules.rs:11`), `canonical_triple_repeticion_tablas_y_general_volador` (`xiangqi_game/tests/canonical_rules.rs:77`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/xiangqi_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `xiangqi_smoke.gd`*: **8** verificaciones (ej. líneas 30, 39, 40, 41, 50, 51, 61, 70)

### 5.6. Backgammon (`backgammon_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/backgammon_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/backgammon_game/tests/game_rules.rs` (**19** tests)
  - **Tests Canónicos**: `games_tables_sdk/backgammon_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (2 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/backgammon_board.gd` ↔ `games_tables_sdk/godot_project/scenes/backgammon_board.gd` (748 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/backgammon_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/backgammon.md`
- **Contrato de Estado JSON (`get_state_json`)**: `points (24), bar_white, bar_black, borne_off_white, borne_off_black, dice_remaining, doubling_cube, current_turn`
- **Comandos del Motor (`dispatch_command`)**: `RollDiceCommand { d1, d2 }, MoveCheckerBgCommand { from_point, to_point }`
- **Integración Dados 3D (`DiceWidget` / `DiceRoller3D`)**: Activa en `godot_project/backgammon_board.gd` y verificada en `godot_project/tests/dice_3d_smoke.gd` y `godot_project/tests/backgammon_smoke.gd`.
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_backgammon` (línea 1035), `start_local_match_backgammon_vs_ai` (línea 1046)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_backgammon_ai_saca_ficha_de_barra_cuando_puede` (`backgammon_game/src/ai.rs:426`), `test_backgammon_ai_prefiere_crear_bloque_sobre_dejar_blot` (`backgammon_game/src/ai.rs:476`), `test_backgammon_ai_offers_double_with_advantage` (`backgammon_game/src/ai.rs:523`), `test_backgammon_ai_does_not_double_when_crawford_or_behind` (`backgammon_game/src/ai.rs:551`)
  - *Reglas (`tests/game_rules.rs`)*: `el_setup_inicial_tiene_15_fichas_por_jugador` (`backgammon_game/tests/game_rules.rs:20`), `tirar_los_dados_deja_dos_valores_pendientes` (`backgammon_game/tests/game_rules.rs:30`), `mover_una_ficha_propia_usa_un_dado_y_la_desplaza` (`backgammon_game/tests/game_rules.rs:48`), `pisar_un_blot_rival_lo_manda_a_la_barra` (`backgammon_game/tests/game_rules.rs:78`), `con_fichas_en_la_barra_hay_que_entrar_antes_de_mover_otra_cosa` (`backgammon_game/tests/game_rules.rs:112`), `sacar_las_15_fichas_termina_la_partida` (`backgammon_game/tests/game_rules.rs:153`), `dobles_en_la_barra_o_tablero_pueden_usar_hasta_4_dados` (`backgammon_game/tests/game_rules.rs:184`), `sin_movimientos_validos_pasa_el_turno` (`backgammon_game/tests/game_rules.rs:199`), `no_se_puede_sacar_ficha_con_dado_mayor_si_hay_fichas_mas_atras` (`backgammon_game/tests/game_rules.rs:228`), `test_gammon_cuando_oponente_no_saco_ninguna_ficha` (`backgammon_game/tests/game_rules.rs:254`), `test_backgammon_cuando_oponente_tiene_fichas_en_home_del_ganador` (`backgammon_game/tests/game_rules.rs:292`), `test_doblar_y_rechazar_termina_la_partida_con_valor_actual` (`backgammon_game/tests/game_rules.rs:328`), `test_crawford_rule_bloquea_dado_de_doblaje` (`backgammon_game/tests/game_rules.rs:354`), `test_sacar_ultima_ficha_emite_game_over_inmediatamente` (`backgammon_game/tests/game_rules.rs:375`), `test_ofrecer_doble_antes_de_mover_es_valido` (`backgammon_game/tests/game_rules.rs:406`), `test_rechazar_doble_termina_la_partida` (`backgammon_game/tests/game_rules.rs:416`), `test_aceptar_doble_duplica_el_cubo` (`backgammon_game/tests/game_rules.rs:433`), `test_obligacion_usar_dado_mayor_cuando_solo_uno_es_jugable` (`backgammon_game/tests/game_rules.rs:449`), `test_obligacion_usar_ambos_dados_rechaza_primer_movimiento_que_bloquea_el_segundo` (`backgammon_game/tests/game_rules.rs:508`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_obligacion_de_usar_dado_mayor_cuando_solo_uno_es_jugable` (`backgammon_game/tests/canonical_rules.rs:20`), `canonical_obligacion_de_usar_ambos_dados_si_existe_secuencia_completa` (`backgammon_game/tests/canonical_rules.rs:60`), `canonical_cubo_doblaje_y_regla_crawford` (`backgammon_game/tests/canonical_rules.rs:109`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/backgammon_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `backgammon_smoke.gd`*: **9** verificaciones (ej. líneas 41, 48, 64, 67, 76, 80, 87, 95)

### 5.7. Batalla Naval (Battleship) (`battleship_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/battleship_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/battleship_game/tests/game_rules.rs` (**18** tests)
  - **Tests Canónicos**: `games_tables_sdk/battleship_game/tests/canonical_rules.rs` (**2** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (2 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/battleship_board.gd` ↔ `games_tables_sdk/godot_project/scenes/battleship_board.gd` (1419 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/battleship_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/battleship.md`
- **Contrato de Estado JSON (`get_state_json`)**: `phase (Placement/Combat/Finished), fleets, shots_p1, shots_p2, sunken_ships, active_player`
- **Comandos del Motor (`dispatch_command`)**: `PlaceShipCommand { player, ship_id, x, y, horizontal }, FireShotCommand { player, x, y }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_battleship` (línea 1222), `start_local_match_battleship_vs_ai` (línea 1233)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `easy_ai_fires_untouched_cell` (`battleship_game/src/ai.rs:374`), `medium_ai_hunts_after_hit` (`battleship_game/src/ai.rs:396`), `hard_ai_prefers_high_density` (`battleship_game/src/ai.rs:433`)
  - *Reglas (`tests/game_rules.rs`)*: `colocar_una_flota_valida_funciona_y_no_revela_las_coordenadas` (`battleship_game/tests/game_rules.rs:54`), `una_flota_con_tamanos_incorrectos_es_rechazada` (`battleship_game/tests/game_rules.rs:72`), `no_se_puede_disparar_antes_de_que_ambos_coloquen_su_flota` (`battleship_game/tests/game_rules.rs:85`), `un_disparo_certero_se_reporta_como_hit_y_uno_al_agua_como_miss` (`battleship_game/tests/game_rules.rs:100`), `hundir_todos_los_barcos_rivales_termina_la_partida` (`battleship_game/tests/game_rules.rs:139`), `disparar_dos_veces_a_la_misma_casilla_es_rechazado` (`battleship_game/tests/game_rules.rs:219`), `barcos_superpuestos_o_diagonales_son_rechazados` (`battleship_game/tests/game_rules.rs:258`), `test_barco_adyacente_a_otro_es_rechazado` (`battleship_game/tests/game_rules.rs:295`), `test_disparo_a_celda_ya_disparada_es_rechazado` (`battleship_game/tests/game_rules.rs:337`), `test_impactar_todos_los_segmentos_hunde_el_barco_y_emite_evento` (`battleship_game/tests/game_rules.rs:379`), `test_hundir_toda_la_flota_termina_la_partida` (`battleship_game/tests/game_rules.rs:463`), `test_revancha_reinicia_la_fase_de_colocacion` (`battleship_game/tests/game_rules.rs:492`), `test_barco_fuera_de_los_limites_es_rechazado` (`battleship_game/tests/game_rules.rs:536`), `test_drop_cleanup_no_afecta_estado` (`battleship_game/tests/game_rules.rs:553`), `test_tablero_es_10x10` (`battleship_game/tests/game_rules.rs:582`), `test_regla_por_defecto_alterna_turnos_incluso_al_acertar` (`battleship_game/tests/game_rules.rs:615`), `test_regla_racha_turno_extra_al_acertar` (`battleship_game/tests/game_rules.rs:649`), `test_resign_command_concede_victoria_al_rival` (`battleship_game/tests/game_rules.rs:728`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_modo_extra_turn_on_hit_mantiene_turno_al_acertar_y_cede_al_fallar` (`battleship_game/tests/canonical_rules.rs:45`), `canonical_hundir_flota_con_racha_y_rematch_reinicia_estado` (`battleship_game/tests/canonical_rules.rs:125`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/battleship_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `battleship_smoke.gd`*: **13** verificaciones (ej. líneas 26, 48, 64, 75, 79, 83, 92, 102)

### 5.8. Ludo / Parchís (`ludo_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/ludo_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/ludo_game/tests/game_rules.rs` (**22** tests)
  - **Tests Canónicos**: `games_tables_sdk/ludo_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (2 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/ludo_board.gd` ↔ `games_tables_sdk/godot_project/scenes/ludo_board.gd` (696 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/ludo_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/ludo.md`
- **Contrato de Estado JSON (`get_state_json`)**: `players (2..4), tokens (4 por jugador: Base/Track/HomeStretch/Goal), last_roll, consecutive_sixes, safe_squares`
- **Comandos del Motor (`dispatch_command`)**: `LudoRollCommand { value }, LudoMoveTokenCommand { player, token_idx }`
- **Integración Dados 3D (`DiceWidget` / `DiceRoller3D`)**: Activa en `godot_project/ludo_board.gd` y verificada en `godot_project/tests/dice_3d_smoke.gd` y `godot_project/tests/ludo_smoke.gd`.
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_ludo` (línea 1120), `start_local_match_ludo_vs_ai` (línea 1134)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_ludo_ai_saca_ficha_con_seis` (`ludo_game/src/ai.rs:120`), `test_ludo_ai_captura_cuando_puede` (`ludo_game/src/ai.rs:138`)
  - *Reglas (`tests/game_rules.rs`)*: `soporta_mas_de_dos_jugadores` (`ludo_game/tests/game_rules.rs:38`), `no_se_puede_mover_sin_tirar_primero` (`ludo_game/tests/game_rules.rs:44`), `una_ficha_en_la_base_solo_entra_con_un_6` (`ludo_game/tests/game_rules.rs:51`), `sacar_un_6_da_turno_extra_y_no_avanza_el_turno` (`ludo_game/tests/game_rules.rs:65`), `pisar_una_ficha_rival_la_manda_de_vuelta_a_la_base` (`ludo_game/tests/game_rules.rs:84`), `llegar_con_las_4_fichas_a_destino_termina_la_partida` (`ludo_game/tests/game_rules.rs:119`), `sin_movimientos_validos_limpia_tirada_y_pasa_turno` (`ludo_game/tests/game_rules.rs:147`), `casilla_segura_de_salida_evita_captura` (`ludo_game/tests/game_rules.rs:173`), `test_token_no_puede_entrar_en_columna_de_casa_rival` (`ludo_game/tests/game_rules.rs:209`), `test_dado_mayor_que_casillas_restantes_en_meta_es_invalido` (`ludo_game/tests/game_rules.rs:248`), `test_bloqueo_impide_que_rival_aterrice_en_casilla` (`ludo_game/tests/game_rules.rs:272`), `test_seleccion_de_token_invalido_es_rechazada` (`ludo_game/tests/game_rules.rs:304`), `test_ficha_recorre_tablero_completo_en_52_pasos` (`ludo_game/tests/game_rules.rs:330`), `ludo_de_4_jugadores_hasta_victoria` (`ludo_game/tests/game_rules.rs:415`), `test_ludo_con_tres_jugadores_cicla_correctamente` (`ludo_game/tests/game_rules.rs:499`), `test_esquinas_segun_numero_de_jugadores` (`ludo_game/tests/game_rules.rs:518`), `test_ludo_ai_saca_ficha_con_seis` (`ludo_game/tests/game_rules.rs:540`), `test_ludo_ai_captura_cuando_puede` (`ludo_game/tests/game_rules.rs:558`), `test_tres_seises_consecutivos_pierde_turno` (`ludo_game/tests/game_rules.rs:585`), `test_turno_extra_por_captura_y_meta` (`ludo_game/tests/game_rules.rs:648`), `test_casillas_estrella_son_seguras` (`ludo_game/tests/game_rules.rs:700`), `test_resign_command` (`ludo_game/tests/game_rules.rs:748`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_tres_seises_seguidos_pierde_turno` (`ludo_game/tests/canonical_rules.rs:12`), `canonical_turno_extra_por_captura_y_meta_y_casillas_estrella` (`ludo_game/tests/canonical_rules.rs:61`), `canonical_reinicio_contador_seises_y_meta_exacta` (`ludo_game/tests/canonical_rules.rs:174`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/ludo_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `ludo_smoke.gd`*: **10** verificaciones (ej. líneas 41, 63, 66, 76, 86, 89, 92, 97)

### 5.9. Mille Bornes (1000 Millas) (`mille_bornes_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/mille_bornes_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/mille_bornes_game/tests/game_rules.rs` (**19** tests)
  - **Tests Canónicos**: `games_tables_sdk/mille_bornes_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (3 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/mille_bornes_board.gd` ↔ `games_tables_sdk/godot_project/scenes/mille_bornes_board.gd` (1201 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/mille_bornes_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/mille_bornes.md`
- **Contrato de Estado JSON (`get_state_json`)**: `distances, battle_pile, speed_pile, safety_areas (fourreaux), hands, deck_remaining, target_distance (1000)`
- **Comandos del Motor (`dispatch_command`)**: `PlayCardMbCommand { player, card_idx, target_player }, DiscardCardMbCommand { player, card_idx }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_mille_bornes` (línea 987), `start_local_match_mille_bornes_vs_ai` (línea 998), `get_mille_bornes_hand` (línea 2973)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `mille_bornes_ai_plays_safety_first` (`mille_bornes_game/src/ai.rs:307`), `mille_bornes_ai_prioritizes_all_four_safeties_when_threatened` (`mille_bornes_game/src/ai.rs:346`)
  - *Reglas (`tests/game_rules.rs`)*: `el_setup_reparte_manos_privadas_de_tamano_correcto` (`mille_bornes_game/tests/game_rules.rs:12`), `robar_agrega_una_carta_a_la_mano_y_es_evento_privado` (`mille_bornes_game/tests/game_rules.rs:24`), `jugar_una_carta_de_distancia_avanza_y_pasa_el_turno` (`mille_bornes_game/tests/game_rules.rs:58`), `un_peligro_impide_que_el_rival_juegue_distancia_hasta_curarse` (`mille_bornes_game/tests/game_rules.rs:90`), `llegar_exacto_a_la_meta_termina_la_partida` (`mille_bornes_game/tests/game_rules.rs:158`), `una_jugada_que_pasaria_la_meta_es_rechazada` (`mille_bornes_game/tests/game_rules.rs:186`), `descartar_una_carta_pasa_el_turno_y_va_al_descarte` (`mille_bornes_game/tests/game_rules.rs:207`), `limite_de_velocidad_permite_cartas_de_25_o_50_pero_bloquea_mayores` (`mille_bornes_game/tests/game_rules.rs:241`), `test_coup_fourre_contraataca_y_anula_peligro` (`mille_bornes_game/tests/game_rules.rs:280`), `test_limite_de_velocidad_rechaza_distancia_mayor_a_50` (`mille_bornes_game/tests/game_rules.rs:336`), `test_derecho_de_via_bloquea_todos_los_hazards` (`mille_bornes_game/tests/game_rules.rs:365`), `test_tercera_carta_200_es_rechazada` (`mille_bornes_game/tests/game_rules.rs:399`), `test_extension_de_viaje_a_1000_cuando_se_agotan_las_200` (`mille_bornes_game/tests/game_rules.rs:456`), `test_gana_con_1000km` (`mille_bornes_game/tests/game_rules.rs:520`), `test_las_4_cartas_de_seguridad_bloquean_sus_hazards_especificos` (`mille_bornes_game/tests/game_rules.rs:563`), `test_extra_tank_cura_inmediatamente_out_of_gas` (`mille_bornes_game/tests/game_rules.rs:624`), `test_turno_extra_al_jugar_carta_de_seguridad` (`mille_bornes_game/tests/game_rules.rs:655`), `test_coup_fourre_con_safety_otorga_bono_100_inmunidad_y_anula_peligro` (`mille_bornes_game/tests/game_rules.rs:684`), `test_build_deck_contiene_las_4_safeties` (`mille_bornes_game/tests/game_rules.rs:759`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_las_4_safety_cards_otorgan_turno_extra_e_inmunidad` (`mille_bornes_game/tests/canonical_rules.rs:12`), `canonical_coup_fourre_con_safety_anula_peligro_y_suma_100_km` (`mille_bornes_game/tests/canonical_rules.rs:66`), `canonical_safety_cura_hazard_activo_y_limite_dos_cartas_200km` (`mille_bornes_game/tests/canonical_rules.rs:115`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/mille_bornes_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `mille_bornes_smoke.gd`*: **5** verificaciones (ej. líneas 30, 36, 72, 81, 93)

### 5.10. Monopoly (Magnate Inmobiliario) (`monopoly_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/monopoly_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/monopoly_game/tests/game_rules.rs` (**31** tests)
  - **Tests Canónicos**: `games_tables_sdk/monopoly_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (2 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/monopoly_board.gd` ↔ `games_tables_sdk/godot_project/scenes/monopoly_board.gd` (1824 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/monopoly_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/monopoly.md`
- **Contrato de Estado JSON (`get_state_json`)**: `players (cash, position, in_jail, properties), board_deeds (owner, houses, mortgaged), auction_state, last_dice`
- **Comandos del Motor (`dispatch_command`)**: `RollAndMoveCommand { d1, d2 }, BuyPropertyCommand, BuildHouseCommand { property_id }, EndTurnCommand`
- **Integración Dados 3D (`DiceWidget` / `DiceRoller3D`)**: Activa en `godot_project/monopoly_board.gd` y verificada en `godot_project/tests/dice_3d_smoke.gd` y `godot_project/tests/monopoly_smoke.gd`.
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_monopoly` (línea 1077), `start_local_match_monopoly_vs_ai` (línea 1088)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `monopoly_ai_buys_affordable_property` (`monopoly_game/src/ai.rs:278`), `monopoly_ai_builds_house_when_owning_group_and_has_reserve` (`monopoly_game/src/ai.rs:363`)
  - *Reglas (`tests/game_rules.rs`)*: `test_tablero_estandar_40_casillas_con_todas_las_variantes` (`monopoly_game/tests/game_rules.rs:19`), `test_10_cartas_de_suerte_y_10_de_arca_comunitaria` (`monopoly_game/tests/game_rules.rs:64`), `el_setup_arranca_con_dinero_estandar_y_posicion_cero` (`monopoly_game/tests/game_rules.rs:70`), `moverse_a_una_propiedad_sin_dueno_deja_una_decision_pendiente_y_no_avanza_el_turno` (`monopoly_game/tests/game_rules.rs:78`), `no_se_puede_tirar_de_nuevo_con_una_compra_pendiente` (`monopoly_game/tests/game_rules.rs:99`), `comprar_una_propiedad_descuenta_el_precio_y_asigna_el_dueno` (`monopoly_game/tests/game_rules.rs:118`), `caer_en_propiedad_ajena_paga_renta_al_dueno` (`monopoly_game/tests/game_rules.rs:158`), `poseer_todo_el_grupo_de_color_duplica_la_renta` (`monopoly_game/tests/game_rules.rs:191`), `test_renta_doble_por_grupo_completo_en_monopoly` (`monopoly_game/tests/game_rules.rs:225`), `quedarse_sin_dinero_tras_pagar_renta_termina_la_partida` (`monopoly_game/tests/game_rules.rs:230`), `test_jugador_cae_en_ve_a_la_carcel` (`monopoly_game/tests/game_rules.rs:262`), `test_caer_en_go_to_jail_envia_a_jail_y_emite_jailed_event` (`monopoly_game/tests/game_rules.rs:308`), `test_jugador_en_carcel_no_se_mueve_hasta_que_sale` (`monopoly_game/tests/game_rules.rs:313`), `test_rechazo_de_compra_inicia_subasta` (`monopoly_game/tests/game_rules.rs:361`), `test_renta_de_servicio_es_4x_con_uno_y_10x_con_dos` (`monopoly_game/tests/game_rules.rs:426`), `test_renta_de_ferrocarril_escala_con_cantidad_de_estaciones` (`monopoly_game/tests/game_rules.rs:495`), `test_quiebra_transfiere_propiedades_al_acreedor` (`monopoly_game/tests/game_rules.rs:529`), `test_impuesto_sobre_la_renta_y_lujo` (`monopoly_game/tests/game_rules.rs:576`), `monopoly_primer_jugador_en_quebrar` (`monopoly_game/tests/game_rules.rs:605`), `test_construccion_uniforme_y_coste_por_lado_del_tablero` (`monopoly_game/tests/game_rules.rs:784`), `test_construccion_hasta_hotel_y_limite_nivel_5` (`monopoly_game/tests/game_rules.rs:883`), `test_desmonte_uniforme_y_reembolso_50_porciento` (`monopoly_game/tests/game_rules.rs:937`), `test_renta_escalonada_segun_edificios` (`monopoly_game/tests/game_rules.rs:1027`), `test_hipoteca_y_deshipoteca_propiedad` (`monopoly_game/tests/game_rules.rs:1088`), `test_no_se_puede_hipotecar_con_edificios_en_grupo` (`monopoly_game/tests/game_rules.rs:1213`), `test_tres_dobles_consecutivos_a_la_carcel` (`monopoly_game/tests/game_rules.rs:1285`), `test_tarjeta_salir_libre_de_la_carcel` (`monopoly_game/tests/game_rules.rs:1340`), `test_propose_trade_valida_propiedades_y_efectivo` (`monopoly_game/tests/game_rules.rs:1391`), `test_propose_trade_rechaza_casos_invalidos` (`monopoly_game/tests/game_rules.rs:1441`), `test_accept_trade_transfiere_atomicamente_propiedades_y_dinero` (`monopoly_game/tests/game_rules.rs:1561`), `test_reject_trade_limpia_la_oferta` (`monopoly_game/tests/game_rules.rs:1632`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_casas_hoteles_e_hipotecas` (`monopoly_game/tests/canonical_rules.rs:14`), `canonical_tres_dobles_a_carcel_e_intercambios` (`monopoly_game/tests/canonical_rules.rs:132`), `canonical_construccion_desigual_rechazada_hipoteca_sin_renta_y_tarjeta_carcel` (`monopoly_game/tests/canonical_rules.rs:189`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/monopoly_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `monopoly_smoke.gd`*: **14** verificaciones (ej. líneas 26, 46, 49, 69, 84, 109, 122, 123)

### 5.11. UNO (`uno_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/uno_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/uno_game/tests/game_rules.rs` (**14** tests)
  - **Tests Canónicos**: `games_tables_sdk/uno_game/tests/canonical_rules.rs` (**3** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (3 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/uno_board.gd` ↔ `games_tables_sdk/godot_project/scenes/uno_board.gd` (2324 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/uno_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/uno.md`
- **Contrato de Estado JSON (`get_state_json`)**: `hands, discard_top, active_color, direction (Clockwise/CounterClockwise), pending_draw, uno_called`
- **Comandos del Motor (`dispatch_command`)**: `PlayUnoCardCommand { player, card_idx, chosen_color }, DrawUnoCardCommand { player }, CallUnoCommand { player }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_uno` (línea 757), `start_local_match_uno_vs_ai` (línea 771), `get_uno_state` (línea 3054)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `uno_ai_changes_color_strategically` (`uno_game/src/ai.rs:233`), `uno_ai_calls_uno_when_left_with_one_card` (`uno_game/src/ai.rs:284`)
  - *Reglas (`tests/game_rules.rs`)*: `test_play_and_skip` (`uno_game/tests/game_rules.rs:14`), `test_stacking_draw_two` (`uno_game/tests/game_rules.rs:58`), `test_wild_draw_four_ilegal_si_tienes_carta_del_color` (`uno_game/tests/game_rules.rs:146`), `test_reversa_es_skip_en_dos_jugadores` (`uno_game/tests/game_rules.rs:174`), `test_robar_cuando_no_hay_jugada_avanza_el_turno_o_juega_inmediatamente` (`uno_game/tests/game_rules.rs:205`), `test_mazo_agotado_se_remezcla_desde_descarte` (`uno_game/tests/game_rules.rs:272`), `test_mazo_y_descarte_agotados_no_produce_panic` (`uno_game/tests/game_rules.rs:311`), `test_intercepcion_valida_con_carta_identica` (`uno_game/tests/game_rules.rs:331`), `test_intercepcion_invalida_con_carta_similar_pero_diferente_color` (`uno_game/tests/game_rules.rs:378`), `test_call_uno_con_una_o_dos_cartas_exito` (`uno_game/tests/game_rules.rs:408`), `test_call_uno_con_mas_de_dos_cartas_falla` (`uno_game/tests/game_rules.rs:450`), `test_catch_uno_failure_penaliza_dos_cartas` (`uno_game/tests/game_rules.rs:469`), `test_challenge_wild_draw_four_infractor_bluffeando` (`uno_game/tests/game_rules.rs:525`), `test_challenge_wild_draw_four_legal_retador_penalizado` (`uno_game/tests/game_rules.rs:607`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_call_uno_y_catch_uno_failure` (`uno_game/tests/canonical_rules.rs:12`), `canonical_challenge_wild_draw_four_bluff_y_legal` (`uno_game/tests/canonical_rules.rs:57`), `canonical_jump_in_intercept_carta_identica_y_rechazo_no_identica` (`uno_game/tests/canonical_rules.rs:136`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/uno_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `uno_smoke.gd`*: **21** verificaciones (ej. líneas 28, 35, 36, 44, 54, 65, 75, 86)

### 5.12. Crisis / TEG (Estrategia Global) (`crisis_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/crisis_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/crisis_game/tests/game_rules.rs` (**15** tests)
  - **Tests Canónicos**: `games_tables_sdk/crisis_game/tests/canonical_rules.rs` (**2** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (7 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/crisis_board.gd` ↔ `games_tables_sdk/godot_project/scenes/crisis_board.gd` (2104 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/crisis_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/teg.md`
- **Contrato de Estado JSON (`get_state_json`)**: `territories (owner, armies, adjacencies), phase (Reinforce/Attack/Regroup), continents, secret_objectives, combat_dice`
- **Comandos del Motor (`dispatch_command`)**: `PlaceArmiesCommand { territory, count }, AttackTerritoryCommand { from, to, attacker_dice, defender_dice }, FortifyCommand`
- **Integración Dados 3D (`DiceWidget` / `DiceRoller3D`)**: Activa en `godot_project/crisis_board.gd` y verificada en `godot_project/tests/dice_3d_smoke.gd` y `godot_project/tests/crisis_smoke.gd`.
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `crisis_game_over` (línea 474), `start_local_match_crisis` (línea 818), `start_local_match_crisis_vs_ai` (línea 836), `get_crisis_territory_owner` (línea 3124), `get_crisis_territory_armies` (línea 3147), `get_crisis_turn_phase` (línea 3170), `get_crisis_remaining_armies` (línea 3199)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `crisis_ai_reinforces_threatened_territory` (`crisis_game/src/ai.rs:523`), `crisis_ai_attacks_when_superior` (`crisis_game/src/ai.rs:563`), `crisis_ai_expert_prioritizes_secret_objective_and_fortifies` (`crisis_game/src/ai.rs:618`), `test_board_counts` (`crisis_game/src/board.rs:447`), `test_continent_territories_match` (`crisis_game/src/board.rs:453`), `test_are_adjacent` (`crisis_game/src/board.rs:459`), `test_i18n_names` (`crisis_game/src/i18n.rs:205`)
  - *Reglas (`tests/game_rules.rs`)*: `test_setup_distribuye_todos_los_territorios` (`crisis_game/tests/game_rules.rs:17`), `test_ataque_resolucion_dados_reduce_ejercitos` (`crisis_game/tests/game_rules.rs:47`), `test_conquista_transfiere_territorio_al_atacante` (`crisis_game/tests/game_rules.rs:90`), `test_player_eliminado_sale_del_ciclo_de_turnos` (`crisis_game/tests/game_rules.rs:137`), `test_game_over_por_objetivo_conquistar_continente` (`crisis_game/tests/game_rules.rs:201`), `test_teg_board_initialization` (`crisis_game/tests/game_rules.rs:264`), `test_objetivo_conquistar_continente_detecta_victoria` (`crisis_game/tests/game_rules.rs:272`), `test_bonus_de_continente_se_aplica_al_inicio_del_turno` (`crisis_game/tests/game_rules.rs:294`), `test_serializar_y_deserializar_declare_attack_command_roundtrip` (`crisis_game/tests/game_rules.rs:341`), `test_crisis_session_rechaza_mas_de_seis_jugadores` (`crisis_game/tests/game_rules.rs:355`), `test_crisis_error_paths_cobertura_de_ramas` (`crisis_game/tests/game_rules.rs:373`), `test_primera_conquista_del_turno_roba_tarjeta_automaticamente` (`crisis_game/tests/game_rules.rs:511`), `test_segunda_conquista_en_mismo_turno_no_roba_segunda_tarjeta` (`crisis_game/tests/game_rules.rs:566`), `test_conquista_con_cinco_tarjetas_no_roba_mas` (`crisis_game/tests/game_rules.rs:633`), `test_canje_de_tarjetas_con_territorio_propio_agrega_dos_ejercitos_directamente` (`crisis_game/tests/game_rules.rs:684`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_robo_de_territory_card_al_conquistar_y_bono_mas_dos_por_pais_propio` (`crisis_game/tests/canonical_rules.rs:12`), `canonical_maximo_una_tarjeta_por_turno_y_rechazo_canje_invalido` (`crisis_game/tests/canonical_rules.rs:108`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/crisis_smoke.gd`)**:
  - *Puntos de entrada*: `_initialize()` (línea 5)
  - *Total de aserciones/chequeos en `crisis_smoke.gd`*: **18** verificaciones (ej. líneas 46, 47, 64, 76, 85, 92, 93, 103)

### 5.13. Damas Chinas (Chinese Checkers) (`chinese_checkers_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/chinese_checkers_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/chinese_checkers_game/tests/game_rules.rs` (**12** tests)
  - **Tests Canónicos**: `games_tables_sdk/chinese_checkers_game/tests/canonical_rules.rs` (**2** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (3 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/chinese_checkers_board.gd` ↔ `games_tables_sdk/godot_project/scenes/chinese_checkers_board.gd` (661 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/chinese_checkers_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/chinese_checkers.md`
- **Contrato de Estado JSON (`get_state_json`)**: `star_grid (121 hex posiciones q,r), active_players (2/3/4/6), current_turn, hop_chain_active, winner`
- **Comandos del Motor (`dispatch_command`)**: `MoveMarbleCommand { from_q, from_r, to_q, to_r }`
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_chinese_checkers` (línea 924), `start_local_match_chinese_checkers_n_players` (línea 938), `start_local_match_chinese_checkers_vs_ai` (línea 950)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `chinese_checkers_ai_moves_toward_goal` (`chinese_checkers_game/src/ai.rs:253`), `test_tablero_tiene_exactamente_121_casillas_validas` (`chinese_checkers_game/src/position.rs:74`), `test_las_6_puntas_no_se_superponen_con_el_hexagono_central` (`chinese_checkers_game/src/position.rs:90`)
  - *Reglas (`tests/game_rules.rs`)*: `el_setup_pone_10_fichas_por_jugador_en_esquinas_opuestas` (`chinese_checkers_game/tests/game_rules.rs:16`), `un_paso_simple_a_una_casilla_vacia_es_valido` (`chinese_checkers_game/tests/game_rules.rs:26`), `no_se_puede_mover_a_una_casilla_ocupada` (`chinese_checkers_game/tests/game_rules.rs:47`), `saltar_sobre_cualquier_ficha_no_la_captura_solo_permite_pasar` (`chinese_checkers_game/tests/game_rules.rs:63`), `test_seis_jugadores_ciclan_correctamente` (`chinese_checkers_game/tests/game_rules.rs:96`), `test_victoria_cuando_todas_las_fichas_llegan_al_triangulo_opuesto` (`chinese_checkers_game/tests/game_rules.rs:157`), `test_cadena_de_tres_saltos_consecutivos` (`chinese_checkers_game/tests/game_rules.rs:202`), `test_tablero_tiene_exactamente_121_casillas_validas` (`chinese_checkers_game/tests/game_rules.rs:245`), `test_las_6_puntas_no_se_superponen_con_el_hexagono_central` (`chinese_checkers_game/tests/game_rules.rs:261`), `test_regla_anti_bloqueo_home_camp_spoiling_otorga_victoria` (`chinese_checkers_game/tests/game_rules.rs:278`), `test_resign_command_termina_la_partida_y_asigna_ganador` (`chinese_checkers_game/tests/game_rules.rs:327`), `test_chinese_checkers_legal_move_generator_lista_movimientos_del_turno_actual` (`chinese_checkers_game/tests/game_rules.rs:347`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `canonical_victoria_anti_bloqueo_en_punta_de_meta` (`chinese_checkers_game/tests/canonical_rules.rs:11`), `canonical_cadena_de_saltos_multiples_y_rechazo_salto_invalido` (`chinese_checkers_game/tests/canonical_rules.rs:57`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/chinese_checkers_smoke.gd`)**:
  - *Puntos de entrada*: `_rotate_60()` (línea 5), `_corner_cells()` (línea 11), `_initialize()` (línea 29)
  - *Total de aserciones/chequeos en `chinese_checkers_smoke.gd`*: **7** verificaciones (ej. líneas 53, 78, 89, 94, 96, 107, 115)

### 5.14. El Juego de la Oca (Game of the Goose) (`goose_game`)

- **Archivos del Juego**:
  - **Motor Rust**: `games_tables_sdk/goose_game/src/lib.rs`
  - **Tests de Reglas**: `games_tables_sdk/goose_game/tests/game_rules.rs` (**3** tests)
  - **Tests Canónicos**: `games_tables_sdk/goose_game/tests/canonical_rules.rs` (**5** tests)
  - **Puente GDExtension**: `games_tables_sdk/open_table_godot/src/lib.rs` (3 métodos exportados)
  - **Tablero Godot (Raíz y Escena)**: `games_tables_sdk/godot_project/goose_board.gd` ↔ `games_tables_sdk/godot_project/scenes/goose_board.gd` (514 líneas, Paridad: `OK`)
  - **Smoke Test Godot**: `games_tables_sdk/godot_project/tests/goose_smoke.gd`
  - **Documentación Técnica**: `games_tables_sdk/docs/games/goose.md`
- **Contrato de Estado JSON (`get_state_json`)**: `num_players (2..4), current_player, positions (0..63), wait_turns, in_well, last_roll, last_event, finished, winner`
- **Comandos del Motor (`dispatch_command`)**: `RollDiceCommand { player_id, die } (con efecto en cadena Oca/Puente/Posada/Pozo/Laberinto/Cárcel/Dados/Calavera y rebote en 63)`
- **Integración Dados 3D (`DiceWidget` / `DiceRoller3D`)**: Activa en `godot_project/goose_board.gd` y verificada en `godot_project/tests/dice_3d_smoke.gd` y `godot_project/tests/goose_smoke.gd`.
- **Funciones en `open_table_godot/src/lib.rs`**:
  - `start_local_match_goose` (línea 1165), `start_local_match_goose_n_players` (línea 1179), `start_local_match_goose_vs_ai` (línea 1191)
- **Inventario de Tests en Rust (`archivo:línea`)**:
  - *Unitarios (`src/`) *: `test_goose_ai_pick_move_with_pending_roll` (`goose_game/src/ai.rs:98`)
  - *Reglas (`tests/game_rules.rs`)*: `test_initial_session_and_roll_then_move` (`goose_game/tests/game_rules.rs:14`), `test_reject_move_without_rolling_and_out_of_turn` (`goose_game/tests/game_rules.rs:52`), `test_legal_moves_ai_and_resign` (`goose_game/tests/game_rules.rs:63`)
  - *Canónicos (`tests/canonical_rules.rs`)*: `test_goose_to_goose_grants_bonus_turn` (`goose_game/tests/canonical_rules.rs:16`), `test_bridge_and_dice_jumps_grant_bonus_turn` (`goose_game/tests/canonical_rules.rs:42`), `test_labyrinth_and_skull_setbacks` (`goose_game/tests/canonical_rules.rs:89`), `test_inn_well_and_prison_penalties_and_well_rescue` (`goose_game/tests/canonical_rules.rs:139`), `test_exact_bounce_and_victory_on_63` (`goose_game/tests/canonical_rules.rs:229`)
- **Funciones y Aserciones en Smoke Test Godot (`godot_project/tests/goose_smoke.gd`)**:
  - *Puntos de entrada*: `_init()` (línea 5)
  - *Total de aserciones/chequeos en `goose_smoke.gd`*: **5** verificaciones (ej. líneas 14, 27, 36, 45, 51)

---

## 6. Inventario Completo de los 45 Smoke Tests de Godot (`godot_project/tests/*.gd`)

| # | Archivo de Prueba (`games_tables_sdk/...`) | Líneas | Aserciones / Chequeos | Funciones Definidas (`func:línea`) |
| :-: | :--- | :-: | :-: | :--- |
| 1 | `godot_project/tests/achievements_smoke.gd` | 50 | 6 | `_initialize:5` |
| 2 | `godot_project/tests/ai_all_games_smoke.gd` | 154 | 25 | `_initialize:9` |
| 3 | `godot_project/tests/ai_extended_smoke.gd` | 39 | 2 | `_initialize:6` |
| 4 | `godot_project/tests/ai_local_smoke.gd` | 118 | 10 | `_initialize:5` |
| 5 | `godot_project/tests/ai_shogi_xiangqi_smoke.gd` | 57 | 5 | `_initialize:3`, `_notification:55` |
| 6 | `godot_project/tests/audio_events_smoke.gd` | 127 | 7 | `_initialize:8` |
| 7 | `godot_project/tests/backgammon_smoke.gd` | 112 | 9 | `_initialize:5` |
| 8 | `godot_project/tests/battleship_smoke.gd` | 146 | 13 | `_initialize:5` |
| 9 | `godot_project/tests/bridge_smoke.gd` | 67 | 14 | `_initialize:8` |
| 10 | `godot_project/tests/canonical_rules_ui_smoke.gd` | 387 | 94 | `_check:7`, `_initialize:14` |
| 11 | `godot_project/tests/chess_smoke.gd` | 156 | 16 | `_initialize:5` |
| 12 | `godot_project/tests/chinese_checkers_smoke.gd` | 129 | 7 | `_rotate_60:5`, `_corner_cells:11`, `_initialize:29` |
| 13 | `godot_project/tests/competitive_smoke.gd` | 104 | 1 | `_initialize:13`, `_run_competitive_flow:23` |
| 14 | `godot_project/tests/credits_spectator_smoke.gd` | 82 | 23 | `_initialize:3`, `_notification:80` |
| 15 | `godot_project/tests/crisis_smoke.gd` | 172 | 18 | `_initialize:5` |
| 16 | `godot_project/tests/dice_3d_smoke.gd` | 89 | 9 | `_initialize:7` |
| 17 | `godot_project/tests/go_smoke.gd` | 151 | 15 | `_initialize:5` |
| 18 | `godot_project/tests/goose_smoke.gd` | 55 | 5 | `_init:5` |
| 19 | `godot_project/tests/guest_auth_smoke.gd` | 73 | 8 | `send_text:9`, `_initialize:12` |
| 20 | `godot_project/tests/headless_smoke.gd` | 80 | 13 | `_initialize:5` |
| 21 | `godot_project/tests/hud_and_settings_smoke.gd` | 280 | 69 | `_initialize:4` |
| 22 | `godot_project/tests/lan_discovery_smoke.gd` | 90 | 7 | `connect_to_host:13`, `_initialize:19` |
| 23 | `godot_project/tests/ludo_smoke.gd` | 124 | 10 | `_initialize:5` |
| 24 | `godot_project/tests/mille_bornes_smoke.gd` | 106 | 5 | `_initialize:5` |
| 25 | `godot_project/tests/monopoly_smoke.gd` | 169 | 14 | `_initialize:5` |
| 26 | `godot_project/tests/multi_session_smoke.gd` | 80 | 15 | `_initialize:7` |
| 27 | `godot_project/tests/multi_session_tcp_smoke.gd` | 124 | 16 | `_initialize:11` |
| 28 | `godot_project/tests/native_p2p_smoke.gd` | 46 | 7 | `_initialize:6` |
| 29 | `godot_project/tests/online_viability_smoke.gd` | 128 | 20 | `_initialize:19` |
| 30 | `godot_project/tests/pause_menu_smoke.gd` | 111 | 30 | `_initialize:7`, `_notification:109` |
| 31 | `godot_project/tests/performance_smoke.gd` | 47 | 2 | `_initialize:6` |
| 32 | `godot_project/tests/relay_smoke.gd` | 123 | 7 | `_is_valid_room_code:12`, `_initialize:21` |
| 33 | `godot_project/tests/replay_viewer_smoke.gd` | 84 | 16 | `_initialize:6` |
| 34 | `godot_project/tests/save_replay_smoke.gd` | 167 | 11 | `_initialize:9` |
| 35 | `godot_project/tests/shogi_smoke.gd` | 128 | 13 | `_initialize:5` |
| 36 | `godot_project/tests/tcp_packet_loss_smoke.gd` | 204 | 4 | `_init:24`, `poll:33`, `is_proxy_connected:92`, `stop:100`, `_initialize:109` |
| 37 | `godot_project/tests/tcp_reconnection_smoke.gd` | 106 | 8 | `_initialize:15` |
| 38 | `godot_project/tests/test_get_legal_moves_bridge.gd` | 34 | 5 | `_initialize:6` |
| 39 | `godot_project/tests/test_get_recent_events.gd` | 44 | 4 | `_initialize:6` |
| 40 | `godot_project/tests/test_native_p2p_adapter.gd` | 86 | 8 | `startHosting:15`, `startDiscovery:18`, `sendBytes:21`, `broadcastBytes:24`, `stopAll:27` (+1 más) |
| 41 | `godot_project/tests/test_spectator.gd` | 120 | 14 | `_initialize:6` |
| 42 | `godot_project/tests/tutorial_smoke.gd` | 129 | 14 | `_initialize:22` |
| 43 | `godot_project/tests/uno_smoke.gd` | 182 | 21 | `_initialize:5` |
| 44 | `godot_project/tests/visual_regression.gd` | 129 | 0 | `_initialize:25`, `_compare_images:112` |
| 45 | `godot_project/tests/xiangqi_smoke.gd` | 83 | 8 | `_initialize:5` |

---

## 7. Guía de Auto-Reparación para Agentes de IA (`AI Self-Healing Playbook`)

Si eres un agente de IA encargado de corregir errores o añadir funcionalidades en este proyecto, sigue estrictamente estas **5 reglas de oro** para evitar regresiones:

### Regla 1: Tipado Estricto en Redot 4.4 / GDScript (`0` Inferencias `:=` sobre `Variant`)
- **Síntoma del Error**: `Parse Error: Cannot infer the type of "..." variable because the value doesn't have a set type.`
- **Causa**: Redot 4.4 trata como error fatal usar `:=` cuando la expresión de la derecha retorna `Variant` (`JSON.parse_string()`, `.get()` en diccionarios, indexación `dict["key"]` o `arr[i]` no tipados, `str_to_var()`, etc.).
- **Solución Exacta**:
  ```gdscript
  # INCORRECTO (Falla en Redot 4.4):
  var parsed := JSON.parse_string(raw_json)
  var pos := state_dict.get("positions", [])

  # CORRECTO (Cumple Redot 4.4 Strict):
  var parsed: Variant = JSON.parse_string(raw_json)
  if typeof(parsed) != TYPE_DICTIONARY:
      return
  var state_dict: Dictionary = parsed
  var pos_raw: Variant = state_dict.get("positions", [])
  var pos: Array = pos_raw if typeof(pos_raw) == TYPE_ARRAY else []
  ```

### Regla 2: Paridad Obligatoria entre `godot_project/*_board.gd` y `godot_project/scenes/*_board.gd`
- **Síntoma del Error**: `[ERR-BOARD-PARITY-<JUEGO>]` en `TEST_SUMMARY.md` o fallo en `verify_p12.sh` / `run_godot_tests.sh`.
- **Causa**: El proyecto mantiene los scripts de tablero tanto en `godot_project/<juego>_board.gd` como en `godot_project/scenes/<juego>_board.gd`.
- **Solución Exacta**: Cada vez que modifiques cualquier archivo `godot_project/<juego>_board.gd`, ejecuta inmediatamente:
  ```bash
  cp games_tables_sdk/godot_project/<juego>_board.gd games_tables_sdk/godot_project/scenes/<juego>_board.gd
  ```

### Regla 3: Sincronización de Dados 3D (`DiceRoller3D` y `DiceWidget`)
- **Juegos Afectados**: `goose` (1 dado), `ludo` (1 dado), `backgammon` (2 dados), `monopoly` (2 dados), `crisis` (hasta 3 dados).
- **Arquitectura**:
  - `games_tables_sdk/godot_project/scripts/dice_roller_3d.gd` gestiona el `SubViewport`, `Camera3D`, `DirectionalLight3D` y 3 dados `MeshInstance3D` con texturas procedurales de pips (1..6) y rotaciones exactas `_target_rotation_for_value(val)`.
  - `games_tables_sdk/godot_project/dice_widget.gd` instancia `DiceRoller3D`, expone `set_dice_values(values: Array)` y `roll_to_values(values: Array)`, realiza una pausa breve al aterrizar para mostrar el resultado 3D y finalmente emite `roll_completed(values)`.
- **Solución ante fallos en `dice_3d_smoke.gd`**: Verificar que `DiceRoller3D.roll_3d(values)` valide valores en `1..6`, configure la visibilidad de 1 a 3 dados y emita `roll_finished(values)` tras la animación o de forma síncrona en modo headless.

### Regla 4: Contratos del Puente Rust ↔ Godot (`open_table_godot/src/lib.rs`)
- **Arquitectura**: Ningún juego altera `open_table_core` ni `open_table_engine`. Cada juego encapsula sus reglas en `<juego>_game/src/lib.rs` y se expone en `OpenTableBridge` dentro de `open_table_godot/src/lib.rs`.
- **Verificación de Reglas**: Toda regla nueva o corrección de bug en un juego debe incluir su test correspondiente en `<juego>_game/tests/game_rules.rs` y `<juego>_game/tests/canonical_rules.rs`, además de mantener el anticheat sincronizado en `open_table_relay/src/anticheat.rs`.

### Regla 5: Comandos Estándar de Verificación y Regeneración
Después de aplicar cualquier cambio en Rust o GDScript, ejecuta en orden:
```bash
# 1. Regenerar este reporte TEST_SUMMARY.md y validar 0 errores
bash games_tables_sdk/tools/generate_test_summary.sh

# 2. Ejecutar los gates completos del workspace y PROMPTS13
bash games_tables_sdk/tools/verify_workspace.sh && bash games_tables_sdk/tools/verify_p13.sh
```
