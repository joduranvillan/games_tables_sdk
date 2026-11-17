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
| **Batalla Naval** (`battleship_game`) | ✅ | ✅ (tablero 10×10) | ✅ (100%) | ✅ (`battleship_smoke.gd`) | ✅ |
| **Ludo** (`ludo_game`) | ✅ | ✅ (52 casillas, regla de 6) | ✅ (100%) | ✅ (`ludo_smoke.gd`) | ✅ |
| **Mille Bornes** (`mille_bornes_game`) | ✅ | ✅ (meta 1000 km, extensión de viaje) | ✅ (100%) | ✅ (`mille_bornes_smoke.gd`) | ✅ |
| **Monopoly** (`monopoly_game`) | ✅ | ✅ (40 casillas estándar) | ✅ (100%) | ✅ (`monopoly_smoke.gd`) | ✅ |
| **Uno** (`uno_game`) | ✅ | ✅ (jump-in, robo acumulativo, colores) | ✅ (100%) | ✅ (`uno_smoke.gd`) | ✅ |
| **Crisis / TEG** (`crisis_game`) | ✅ | ✅ (30 terr, 6 cont, obj. sec) | ✅ (100%) | ✅ (`crisis_smoke.gd`) | ✅ |
| **Damas Chinas** (`chinese_checkers_game`) | ✅ | ✅ (tablero hexagonal) | ✅ (100%) | ✅ (`chinese_checkers_smoke.gd`) | ✅ |
| **El Juego de la Oca** (`goose_game`) | ✅ | ✅ (63 casillas espiral, todas las especiales, rebote) | ✅ (100%) | ✅ (`goose_smoke.gd`, `dice_3d_smoke.gd`) | ✅ |

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
- `ai_local_smoke.gd`: ✅ IA local para damas, ajedrez, **Go y Ludo** vía GDExtension.
- `pause_menu_smoke.gd`: ✅ Verificación de señales del menú de pausa.
- `multi_session_smoke.gd`: ✅ Métodos de hosting y conexión de red en bridge.
- `credits_spectator_smoke.gd`: ✅ **404.** Smoke test de créditos y vista de espectador (recursos y método `setup`).
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

## 5. Cierre Gráfico y Usabilidad (PROMPTS7)

- [x] **375.** Conexión de IA de Go (9x9) en el Menú Principal (`main_menu.gd`)
- [x] **376.** Conexión de IA de Ludo en el Menú Principal (`main_menu.gd`)
- [x] **377.** Popup y botón de Reglas en Ajedrez (`chess_board.gd`)
- [x] **378.** Popup y botón de Reglas en Go (`go_board.gd`)
- [x] **379.** Popup y botón de Reglas en Shogi (`shogi_board.gd`)
- [x] **380.** Popup y botón de Reglas en Batalla Naval (`battleship_board.gd`)
- [x] **381.** Integración del Menú de Pausa (`pause_menu.tscn`) en los 13 tableros de juego
- [x] **382.** Fila de Multijugador (Crear partida en red y Unirse con QR) en el Menú Principal (`main_menu.gd`)
- [x] **384.** Notificación de fin de partida a `AchievementManager` (`game_over_overlay.gd`)
- [x] **385.** Smoke test ampliado para IA de Go y Ludo (`tests/ai_local_smoke.gd`)
- [x] **386.** Smoke test de menú de pausa (`tests/pause_menu_smoke.gd`)
- [x] **387.** Verificación de métodos de hosting y conexión de red en bridge (`tests/multi_session_smoke.gd`)
- [x] **388.** Escena de menú de pausa (`pause_menu.tscn`)
- [x] **389.** Escena de lobby de red (`host_lobby.tscn`)
- [x] **393.** Integración de `network_status_hud.gd` en los 13 tableros de juego
- [x] **395.** Conexión de señal `game_ended` en `score_tracker.gd` (N/A justificado: bridge emite `game_over(winner: i64)`)

## 6. Para versión 1.0.0 / 2.1.0 — Estado de Plataforma y Producción
- [x] **396.** Pantalla de créditos / "Acerca de" (`credits_screen.gd`, `credits_screen.tscn`)
- [x] **397.** Temas visuales aplicables per-game (`theme_manager.gd`, `main_menu.gd`)
- [x] **398.** Modo espectador con UI dedicada (`spectator_view.gd`, `spectator_view.tscn`, `host_lobby.gd`)
- [x] **399.** Soporte full-screen y escalado adaptativo en resoluciones 4K (`project.godot`, `settings_menu.gd`)
- [x] **453.** Plugin Android `OpenTableNearby` compilado a `.aar` en CI (`platform_plugins/android/build.gradle.kts`, `.github/workflows/ci.yml`)
- [x] **454.** Plugin iOS `OpenTableMultipeer` compilado a `.xcframework` en CI macOS (`platform_plugins/ios/Package.swift`, `.github/workflows/ci.yml`)
- [x] **455–456.** `GodotRawByteLink` real en `open_table_godot` + smoke test P2P nativo (`native_p2p_smoke.gd`)

## 7. Producción Robusta e IA Completa (PROMPTS11 — v2.1.0)

- [x] **448.** TLS/WSS (`rustls`) y autenticación JWT (`HS256`) en `open_table_relay` (`tls.rs`, `auth.rs`)
- [x] **449.** Rate limiting por IP (30 msg/s) y por sala (60 msg/s) con bloqueo temporal de IPs abusivas (`rate_limit.rs`)
- [x] **450.** Validación anti-cheat autoritativa de movimientos en el Relay para Chess y Checkers (`anticheat.rs`)
- [x] **451.** Containerización Docker multi-stage + proxy reverso `nginx` WSS y guía `DEPLOY.md`
- [x] **452.** Métricas Prometheus (`GET /metrics`) y dashboard Grafana (`grafana/dashboard.json`)
- [x] **457–461.** IA completa con 4 dificultades para los 6 juegos restantes (`battleship_game`, `mille_bornes_game`, `uno_game`, `monopoly_game`, `chinese_checkers_game`, `crisis_game`) — **13/13 juegos con IA**
- [ ] *(Omitido por alcance)* **462–465.** Bloque 4 Social (Amigos, Chat de sala, Perfiles con avatar)
- [x] **466.** Exportación e importación de replays comprimidos `.otr` (`save_manager.gd`, `replay_viewer.gd`)
- [x] **467.** Modo espectador en tiempo real para partidas online del Relay (`join_spectator`, límite 10 por sala)
- [x] **468.** Script de verificación integral `tools/verify_p11.sh`

## 8. Lanzamiento Comercial Viable (PROMPTS12.md — v3.0.0) — Completado ✅

- [x] **469–474.** Relay Autoritativo v2, JWT invitado (`auth_client.gd`), anti-cheat en 13 juegos, reconexión 90s y reloj de turno autoritativo.
- [x] **475–478.** Auto-descubrimiento LAN UDP (`lan_discovery.gd`), test de latencia `/health` y reconexión con backoff exponencial.
- [x] **479–483.** Identidad visual (`opentable_suite.svg`), manifiesto `.gdextension` 6 plataformas, `export_presets.cfg`, `.aab` y SteamPipe (`app_build.vdf`).
- [x] **484–488.** Catálogo de reglas in-game (`rules_catalog.gd`), tutoriales adicionales, reloj visual, menú desplegable superior derecho (`GameAppMenu`), rendición/tablas, deshacer/rehacer y estadísticas locales.
- [x] **489–495.** Cursor virtual Gamepad/Steam Deck, paleta daltónica Okabe-Ito, safe-area móvil, vibración háptica, documentos legales y `tools/verify_p12.sh`.

## 9. Certificación de Reglas Oficiales Canónicas y UI (PROMPTS13.md — v4.0.0) — Completado ✅

- [x] **496–512.** Motores Rust (`*_game`) y tests de certificación `tests/canonical_rules.rs` completados al 100% en los 14 juegos (incluyendo `goose_game` Prompts 521–529).
- [x] **513–518.** Controles UI canónicos en los 14 tableros de Godot (`godot_project/*_board.gd` y `godot_project/scenes/*_board.gd`):
  - **Ajedrez (`chess_board.gd`)**: Modal selector de pieza de coronación (`PromotionSelectorPanel`: Dama, Torre, Alfil, Caballo) y botones de oferta/aceptación de tablas (`OfferDrawButton`, `DrawOfferBanner`, `AcceptDrawButton`).
  - **Go (`go_board.gd`)**: Selector de Handicap inicial (`HandicapOptionButton`: 0, 2, 3, 4 piedras Hoshi), marcado interactivo de piedras muertas con `✕` carmesí (`mark_dead_stone`) y confirmación (`ConfirmDeadButton`).
  - **Shogi (`shogi_board.gd`)**: Diálogo de promoción opcional (`PromotionDialogPanel`) con detección de promoción obligatoria FESA (`_is_promotion_mandatory_fesa`).
  - **Batalla Naval (`battleship_board.gd`)**: Siluetas cenitales SVG, orientación Horizontal/Vertical (`R`/clic derecho/vista previa), `ExtraTurnCheckBox` (`🔥 Racha al impactar`) y `RematchButton` (`🔁 Revancha`).
  - **Mille Bornes (`mille_bornes_board.gd`)**: Botón reactivo `CoupFourreButton` (`⚡ ¡Coup Fourré!`) y visualización de los 4 Escudos (`Prioridad`, `Cisterna`, `Impinchable`, `As Volante`).
  - **El Juego de la Oca (`goose_board.gd`)**: Tablero espiral de 63 casillas, cubilete 3D (`DiceRoller3D` / `DiceWidget`), tutorial interactivo (`goose_tutorial.gd`), integración Anti-Cheat en `open_table_relay` y registro ELO en `score_tracker.gd`.
  - **Xiangqi, Backgammon, Ludo, UNO, Monopoly, Crisis/TEG, Damas Chinas y Damas**: Todos los controles e interacciones canónicas verificados y compatibles con Redot Engine (`safeguards strict`).
- [x] **519–520.** Smoke test headless de controles UI canónicos (`godot_project/tests/canonical_rules_ui_smoke.gd`) y script de certificación `tools/verify_p13.sh` (14/14 juegos).

## 10. Para publicación en crates.io y Estado de Deuda Técnica

- [x] Doubling cube Backgammon (prompt 310) — ✅ Implementado
- [x] Jump-in UNO (prompt 311) — ✅ Implementado
- [x] `get_legal_moves` con `LegalMoveGenerator` para los 14 juegos — ✅ Implementado
- [x] 0 warnings de Clippy (`cargo clippy --workspace --exclude open_table_godot -- -D warnings`) — ✅ 0 warnings (exit 0)
- [x] **401.** Versión semántica 0.1.0 en todos los `Cargo.toml` y dependencias internas (`version = "0.1.0"`) — ✅ Verificado
- [x] **402.** Documentación pública en `docs.rs` (`cargo doc --workspace --exclude open_table_godot --no-deps`) — ✅ 0 errores, 0 warnings (exit 0)
- **0 TODOs activos** en el código fuente de los crates de Rust y GDScript, y 0 inferencias inseguras `:=` sobre `Variant` en Redot strict.

## 11. Integración Completa de Red y Lanzamiento `v1.0.0` — Completado ✅

- [x] **Multijugador Offline QR + LAN (`qr_lan_multiplayer_smoke.gd`)**: Creación/unión de partidas para los 14 juegos vía `UDP 19451` y `TCP 19450`, con transferencia de bridge activo (`GameManager.claim_network_bridge()`).
- [x] **Flujo Online Relay WebSocket + `SyncState` (`network_full_integration_smoke.gd`)**: Salas de 6 caracteres (`create_online_relay_room` / `join_online_relay_room`), URL de Relay configurable en `SettingsMenu` (`user://settings.cfg`) y en el diálogo de conexión, y sincronización autoritativa de estado (`apply_state_json` / `apply_sync_state_json`).
- [x] **Bloqueo de Turno por Jugador Local (`is_local_turn_allowed()`)**: Aplicado en los **14 tableros** (`godot_project/*_board.gd` y `godot_project/scenes/*_board.gd`).
- [x] **Reconexión Automática TCP y Relay**: Reintento periódico automático ante microcortes en `GameManager` con feedback en `NetworkStatusHud`.
- [x] **47 Suites Smoke Headless en Godot/Redot**: Verificadas en `tools/run_godot_tests.sh`, `tools/verify_p13.sh`, `.github/workflows/ci.yml` y `.github/workflows/release.yml`.

## 12. Ecosistema Web Paralelo React + WebAssembly (`open_table_wasm` + `web_client`) — Fases 1 a 4 Completadas ✅

- [x] **Fase 1 y 2 — Los 14 Tableros Canónicos en React + WASM**: Crate aislado `open_table_wasm/` y cliente `web_client/` con los 14 juegos completos, dados 3D interactivos (`DiceRoller3D.tsx`), generador QR y cliente WebSocket `RelayWebSocketClient` compatible con `SyncState`.
- [x] **Fase 3 — Repeticiones, Tutoriales, Reloj FIDE/Byo-yomi, Espectador y PWA Offline-First**: `ReplayViewerBar.tsx`, `InteractiveTutorialPanel.tsx` (14 juegos), `TournamentClock.tsx`, modo Espectador de solo lectura y Service Worker PWA instalable.
- [x] **Fase 4 — Clasificación ELO (`K = 32`), Logros, Torneos, Temas Visuales + Okabe-Ito, Audio Procedural y Chat Relay**:
  - `EloAndAchievementsPanel.tsx`: Ecuación logística FIDE (`K = 32`), desglose ELO en los 14 juegos, exportación/importación JSON y catálogo de 12 logros desbloqueables.
  - `TournamentManagerPanel.tsx`: Organizador de torneos *Round-Robin* (algoritmo de tablas de Berger) y *Eliminatoria Directa* (*Knockout*) con tabla de posiciones en vivo.
  - `ThemeAndAudioManager.tsx`: 3 temas visuales oficiales (*Piedra Oscura*, *Noche Azul*, *Jade Verde*), modo daltónico *Okabe-Ito* y sintetizador acústico procedural basado en Web Audio API.
  - `RelayChatPanel.tsx`: Chat de sala en tiempo real y reacciones tácticas rápidas sobre `RelayWebSocketClient`.
  - Validado por 4 suites automatizadas (`wasm_and_network.test.ts`, `regression_14_games.test.ts`, `phase3_ecosystem.test.ts` y `phase4_competitive.test.ts`) integradas en `.github/workflows/ci.yml` y `.github/workflows/release.yml`.
