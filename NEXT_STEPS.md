# Estado Actual del Proyecto y Próximos Pasos (OpenTable SDK)

## 1. Juegos Implementados (Estado de Reglas y Tests)

| Juego | Reglas Básicas | Reglas Completas | Tests Rust | Test Godot Headless | UI Godot |
|---|:---:|:---:|:---:|:---:|:---:|
| **Ajedrez** (`chess_game`) | ✅ | ✅ (enroque, al paso, coronación) | ✅ (100%) | ✅ (`chess_smoke.gd`) | ✅ |
| **Damas** (`checkers_game`) | ✅ | ✅ (captura obligatoria, multicaptura) | ✅ (100%) | ✅ (`bridge_smoke.gd`) | ✅ |
| **Go** (`go_game`) | ✅ | ✅ (regla de Ko, libertades, pase) | ✅ (100%) | ✅ (`go_smoke.gd`) | ✅ |
| **Shogi** (`shogi_game`) | ✅ | ✅ (promoción, drops, Nifu, Uchifuzume) | ✅ (100%) | ✅ (`shogi_smoke.gd`) | ✅ |
| **Xiangqi** (`xiangqi_game`) | ✅ | ✅ (General Volador, palacio, río, cañón) | ✅ (100%) | ✅ (`xiangqi_smoke.gd`) | ✅ |
| **Backgammon** (`backgammon_game`) | ✅ | ✅ (doubling cube, 15 fichas, barra, bearing off) | ✅ (100%) | ✅ (`backgammon_smoke.gd`) | ✅ |
| **Batalla Naval** (`battleship_game`) | ✅ | ⚠️ (tablero 8x8) | ✅ (100%) | ✅ (`battleship_smoke.gd`) | ✅ |
| **Ludo** (`ludo_game`) | ✅ | ⚠️ (24 casillas) | ✅ (100%) | ✅ (`ludo_smoke.gd`) | ✅ |
| **Mille Bornes** (`mille_bornes_game`) | ✅ | ⚠️ (meta 200) | ✅ (100%) | ✅ (`mille_bornes_smoke.gd`) | ✅ |
| **Monopoly** (`monopoly_game`) | ✅ | ⚠️ (16 casillas) | ✅ (100%) | ✅ (`monopoly_smoke.gd`) | ✅ |
| **Uno** (`uno_game`) | ✅ | ✅ (jump-in, robo acumulativo, colores) | ✅ (100%) | ✅ (`uno_smoke.gd`) | ✅ |
| **Crisis / TEG** (`crisis_game`) | ✅ | ✅ (30 terr, 6 cont, obj. sec) | ✅ (100%) | ✅ (`crisis_smoke.gd`) | ✅ |
| **Damas Chinas** (`chinese_checkers_game`) | ✅ | ✅ (tablero hexagonal) | ✅ (100%) | ✅ (`chinese_checkers_smoke.gd`) | ✅ |

## 2. `crisis_game` Reescrito como TEG — Estado

- **Motor completo TEG**: 30 territorios, 6 continentes, objetivos secretos, tarjetas de ejército y canje.
- **Fases de juego**: Distribución inicial, Colocación de ejércitos, Ataque con dados, Fortificación y Fin de turno.
- **Cobertura y estrés**: Cobertura de ramas ≥ 62% con validaciones estrictas de error (no adyacencia, fuera de fase, turno incorrecto). Soportó tests de estrés con 1,000 sesiones concurrentes y fuzzing con `cargo-fuzz`.

## 3. Tests de Godot Headless — Estado de Scripts

Ejecutables mediante `tools/run_godot_tests.sh` en Redot 4.5.2 (Godot 4.x):
- `bridge_smoke.gd`: ✅ Puente GDScript <-> Rust, emisión de señales y ciclo local.
- `chess_smoke.gd`: ✅ Simulación de movimientos de Ajedrez.
- `shogi_smoke.gd`: ✅ Captura y reingreso de piezas (drops).
- `go_smoke.gd`: ✅ Colocación de piedras, captura de libertades y pase.
- `uno_smoke.gd`: ✅ Robo de cartas, coincidencia de color/número y comodines.
- `ludo_smoke.gd`: ✅ Avance con dado y colisiones en casillas.
- `crisis_smoke.gd`: ✅ Declaración de ataque, tirada de dados y fortificación en TEG.
- `backgammon_smoke.gd`: ✅ Movimiento con dados, ficha a la barra y doubling cube.
- `xiangqi_smoke.gd`: ✅ Movimiento de Cañón con pantalla y piezas del palacio.
- `test_spectator.gd`: ✅ Transmisión de eventos a espectadores sin filtrado.
- `test_native_p2p_adapter.gd`: ✅ Simulación de reconexión y adaptador P2P.
- `tcp_reconnection_smoke.gd`: ✅ Reconexión de cliente a host TCP preservando estado.
- `tcp_packet_loss_smoke.gd`: ✅ Simulación de pérdida de paquetes con proxy y convergencia.
- `hud_and_settings_smoke.gd`: ✅ Temas visuales y actualización de puntuación ELO.
- `ai_local_smoke.gd`: ✅ IA local para damas y ajedrez vía GDExtension.
- `visual_regression.gd`: ✅ Validación de regresión visual y generación de snapshots.

## 4. Mejoras visuales e IA local (PROMPTS5)

- [x] **326.** Test de reconexión TCP (`tcp_reconnection_smoke.gd`)
- [x] **327.** Simulación de pérdida de paquetes (`tcp_packet_loss_smoke.gd`)
- [x] **328.** Integración de ELO en UI (`score_tracker.gd`, `settings_menu.tscn`, `hud_and_settings_smoke.gd`)
- [x] **329.** 3 nuevos temas visuales: Piedra Oscura, Noche Azul y Jade Verde (`theme_manager.gd`)
- [x] **330.** Sombra proyectada bajo las piezas para profundidad visual (`checkers_board.gd`, `chess_board.gd`)
- [x] **331.** Animación de "bounce" suave al seleccionar piezas (`checkers_board.gd`, `chess_board.gd`)
- [x] **332.** Animación de captura con emisión de partículas (`CPUParticles2D`)
- [x] **333.** Tablero de Ajedrez mejorado: coordenadas (a–h, 1–8), borde y highlight del último movimiento
- [x] **334.** Menú Principal mejorado: fondo animado con shader, entrada de título y hover en botones
- [x] **335.** Indicador visual pulsante de jaque sobre el rey amenazado (`chess_board.gd`)
- [x] **336.** Overlay de fin de juego rediseñado con paneles y animaciones (`game_over_overlay.gd`)
- [x] **337.** Temas visuales e íconos en el selector de juegos del menú (`main_menu.gd`)
- [x] **338.** Minimax con poda alfa-beta para IA de Ajedrez (`chess_game/src/ai.rs`)
- [x] **339.** Exposición de IA de Ajedrez en bridge Godot (`start_local_match_chess_vs_ai`) y selector de dificultad
- [x] **340.** IA heurística para Backgammon (`backgammon_game/src/ai.rs`, `start_local_match_backgammon_vs_ai`)
- [x] **341.** IA para Shogi y Xiangqi (`shogi_game/src/ai.rs`, `xiangqi_game/src/ai.rs`)
- [x] **342.** Selector de modo de juego (Hotseat / vs IA) en Menú Principal con persistencia
- [x] **343.** Test de humo para IA local en Godot (`ai_local_smoke.gd`)
- [x] **344.** UI de Uno mejorada: cartas redondeadas, animación de robo e indicador de color activo (`uno_board.gd`)
- [x] **345.** UI de Battleship mejorada: coordenadas, animación de disparo y barcos hundidos en gris (`battleship_board.gd`)
- [x] **346.** UI de Ludo mejorada: fichas numeradas, camino casilla a casilla, casillas seguras y animación de dado (`ludo_board.gd`)
- [x] **347.** UI de Go mejorada: puntos hoshi, animación de escala, contador de capturas y territorio final (`go_board.gd`)

## 5. Para publicación en crates.io

- [x] Doubling cube Backgammon (prompt 310) — ✅ Implementado
- [x] Jump-in UNO (prompt 311) — ✅ Implementado
- [x] `get_legal_moves` con `LegalMoveGenerator` para checkers y chess (prompts 306-309) — ✅ Implementado
- [ ] 0 warnings de Clippy (`cargo clippy --workspace -- -D warnings`)
- [ ] Versión semántica 0.1.0 en todos los `Cargo.toml`
- [ ] Documentación pública en `docs.rs` (verificar `cargo doc --workspace --no-deps`)

## 6. Deuda Técnica Conocida

- **0 TODOs activos** en el código fuente de los crates de Rust y GDScript.
- **Plugins nativos móviles (`platform_plugins/`)**: `OpenTableNearby` (Android) y `OpenTableMultipeer` (iOS) probados en arquitectura mock/unit-test; requieren compilación nativa en Android Studio / Xcode.
- **Simplificaciones voluntarias de reglas**: Documentadas en la tabla anterior y en cada `README.md` individual para mantener la agilidad del engine.
