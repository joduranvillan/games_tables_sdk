# OpenTable SDK v1.1.0 — Deterministic Board Game Engine Suite (Rust, Godot 4 & WebAssembly)

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/joduranvillan/games_tables_sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/joduranvillan/games_tables_sdk)
[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![Docs.rs](https://docs.rs/open_table_core/badge.svg)](https://docs.rs/open_table_core)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3_or_later-blue.svg)](./LICENSE)
[![Games Implemented](https://img.shields.io/badge/games-14%2F14-brightgreen.svg)](#14-canonical-board-games-suite)

**Languages / Idiomas:** [English](./docs/i18n/en/README.md) · [Español](./docs/i18n/es/README.md) · [Português (BR)](./docs/i18n/pt-BR/README.md) · [Français](./docs/i18n/fr/README.md) · [Deutsch](./docs/i18n/de/README.md) · [简体中文](./docs/i18n/zh-CN/README.md) · [日本語](./docs/i18n/ja/README.md)

---

OpenTable SDK is a deterministic, modular turn-based board game workspace written in Rust (24 crates) with native runtimes for **Godot 4 / Redot 4** (`open_table_godot`) and **React + TypeScript + WebAssembly** (`open_table_wasm`). Every one of the **14 canonical board games** implements official tournament rules, a legal move generator (`LegalMoveGenerator`), a 4-level local AI opponent with configurable **0–100% Top-K decision randomness**, transactional **Undo/Redo**, **64-bit FNV-1a state checksums**, and a **Post-Match Tactical Analyzer** with an interactive **Decision Intensity Heat-Map**.

## Highlights & What's New in `v1.1.0`

- **AI Randomness / Decision Noise (`0–100%`)**: Auto-scaled by difficulty (`Easy = 45%`, `Medium = 25%`, `Hard = 12%`, `Expert = 5%`) with live UI slider control and Top-K score band perturbation (`AiDifficulty::select_top_k_with_noise`) across all 14 games.
- **Transactional Undo/Redo & 64-Bit FNV-1a Checksums**: Snapshot rollback/re-apply (`undo_step`, `redo_step`) and deterministic 64-bit FNV-1a state signatures (`get_state_checksum_hex`) across Rust, Godot, and WebAssembly.
- **AI Decision Intensity Heat-Map Overlay**: Integrated into the Post-Match Tactical Analyzer (`PostMatchAnalyzerPanel.tsx`) with a live toggle between **Selected Turn (`#ply`)** and **Cumulative Match (`N turns`)**, adapted to the board topology of all 14 games.
- **Multilingual Native Documentation (7 Languages) & Crates.io Ready**: Every one of the 24 crates includes an English `README.md` for `crates.io` / `docs.rs`, paired with full native guides in **English, Español, Português (BR), Français, Deutsch, 简体中文, and 日本語** under [`docs/i18n/`](./docs/i18n/).

## Complete Workspace Directory — 24 Crates (`crates.io` & `docs.rs`)

| Crate | Layer | Version | Description |
|---|---|:---:|---|
| [`open_table_core`](./open_table_core/README.md) | Core & Engine Foundation | `1.1.0` | Foundational deterministic traits, serializable Commands/Events, seeded ChaCha8 RNG, and transport contracts for turn-based board game engines. |
| [`open_table_engine`](./open_table_engine/README.md) | Core & Engine Foundation | `1.1.0` | ECS-backed deterministic turn-based session runtime (`Session`), transactional command pipeline, Undo/Redo stacks, FIDE ELO calculator, and state hashing. |
| [`open_table_macros`](./open_table_macros/README.md) | Core & Engine Foundation | `1.1.0` | Procedural derive macros (`#[derive(Component)]`, `#[derive(Resource)]`, `#[game_command]`, `#[game_event]`) reducing boilerplate for OpenTable game crates. |
| [`open_table_qr`](./open_table_qr/README.md) | Transports, Relay & Discovery | `1.1.0` | Compact session invitation payloads and SVG/terminal QR code generation for LAN, Relay room codes, and mobile P2P pairing. |
| [`open_table_transport_tcp`](./open_table_transport_tcp/README.md) | Transports, Relay & Discovery | `1.1.0` | Length-prefixed TCP host/client transport implementation of `open_table_core::Transport` for low-latency LAN multiplayer. |
| [`open_table_transport_websocket`](./open_table_transport_websocket/README.md) | Transports, Relay & Discovery | `1.1.0` | WebSocket client transport connecting desktop, mobile, and WebAssembly peers through `open_table_relay` rooms. |
| [`open_table_transport_native_bridge`](./open_table_transport_native_bridge/README.md) | Transports, Relay & Discovery | `1.1.0` | Zero-socket `RawByteLink` bridge adapting Android Nearby Connections, iOS MultipeerConnectivity, and WebRTC DataChannels into `Transport`. |
| [`open_table_relay`](./open_table_relay/README.md) | Transports, Relay & Discovery | `1.1.0` | Asynchronous WebSocket Relay server with 6-character room codes, spectator broadcasting, and automated ELO-window matchmaking queues. |
| [`open_table_godot`](./open_table_godot/README.md) | Runtime Bridges (Godot & WebAssembly) | `1.1.0` | GDExtension C-ABI bridge exposing all 14 canonical board games, 4-level AI with 0-100% randomness, ELO rating, and networking to Godot 4 / Redot 4. |
| [`open_table_wasm`](./open_table_wasm/README.md) | Runtime Bridges (Godot & WebAssembly) | `1.1.0` | WebAssembly (`wasm-bindgen`) bridge compiling all 14 canonical Rust board game engines, AI levels, Undo/Redo, FNV-1a checksums, and telemetry for the React Web client. |
| [`chess_game`](./chess_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical FIDE Chess engine with castling, en passant, 4-piece promotion, 50-move/threefold repetition draws, Zobrist hashing, ECO opening book, and alpha-beta AI. |
| [`checkers_game`](./checkers_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 8x8 Draughts / Checkers engine with mandatory capture priority, chained multi-jump continuations, King crowning, 40-move draw clock, and minimax AI. |
| [`go_game`](./go_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical Go (Weiqi / Baduk) engine supporting 9x9, 13x13, and 19x19 boards, BFS liberty & chain capture, positional Superko, Hoshi handicap, and 6.5 Komi scoring. |
| [`shogi_game`](./shogi_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 9x9 Japanese Shogi engine with Komadai capture trays, piece drops, Nifu (double pawn) and Uchifuzume bans, FESA promotion zones, and Sennichite x4 detection. |
| [`xiangqi_game`](./xiangqi_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 9x10 Chinese Chess (Xiangqi) engine with 3x3 Palaces, River boundary, Horse/Elephant leg blocking, Cannon screen jumping, and Flying General prohibition. |
| [`chinese_checkers_game`](./chinese_checkers_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 121-node hexagram Chinese Checkers engine supporting 2, 3, 4, and 6 players, BFS chained multi-hop paths, anti-camping rules, and axial distance heuristics. |
| [`backgammon_game`](./backgammon_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 24-point Backgammon engine with doubles (4 moves), mandatory bar re-entry, exact/highest bear-off, Doubling Cube (2..64), and Crawford rule. |
| [`battleship_game`](./battleship_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 10x10 Naval Combat (Battleship) engine with 5-ship fleet deployment (`[5,4,3,3,2]`), optional `extra_turn_on_hit` salvo rule, rematch command, and Hunt/Target parity AI. |
| [`ludo_game`](./ludo_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 52-track + 5-goal Ludo (Parcheesi) engine with 8 safe star squares, triple-six penalty, capture/goal bonus rolls, and threat-aware tactical AI. |
| [`mille_bornes_game`](./mille_bornes_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 1000-km Mille Bornes card racing engine with Hazards, Remedies, Speed Limits, max two 200-km cards, 4 Safety shields, and Coup Fourré instant counter-play. |
| [`monopoly_game`](./monopoly_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 40-square Monopoly economic engine with property auctions, Chance/Community Chest decks, even house/hotel building, mortgages, jail, P2P trades, and ROI AI. |
| [`uno_game`](./uno_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 108-card UNO engine with Skip, Reverse, Draw Two, Wild, Wild Draw Four challenge verification, mandatory UNO! call/penalty, and Jump-In interception. |
| [`crisis_game`](./crisis_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 30-territory, 6-continent global strategy engine (TEG / Risk) with secret objectives, continent bonuses, 3v3 sorted dice combat, 3-card trades, and multi-phase AI. |
| [`goose_game`](./goose_game/README.md) | 14 Canonical Board Game Engines | `1.1.0` | Canonical 63-square spiral Game of the Goose (Juego de la Oca) engine with 13 Geese ('De oca a oca'), Bridges, Inn, Dice, Well, Labyrinth, Prison, Death Skull (58), and exact bounce. |

## Quick Verification Commands

```bash
# 1. Run all 458+ Rust workspace tests and canonical rule suites
cargo test --workspace

# 2. Verify workspace structure, Godot smoke suites, and generate TEST_SUMMARY.md
bash tools/verify_workspace.sh && bash tools/generate_test_summary.sh

# 3. Verify React + TypeScript + WebAssembly Web Client (Vitest + PWA build)
bash tools/verify_web_client.sh
```

---

<!-- SPANISH_CANONICAL_REFERENCE_START -->
# OpenTable SDK — estado actual

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/joduranvillan/games_tables_sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/joduranvillan/games_tables_sdk)
[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3_or_later-blue.svg)](./LICENSE)
[![Juegos Implementados](https://img.shields.io/badge/juegos-14%2F14-brightgreen.svg)](#juegos-de-referencia-y-reglas)

Para el diseño completo del motor (diagrama de capas, detalle de los 23 crates y flujo de eventos) consulta **[`ARCHITECTURE.md`](./ARCHITECTURE.md)**.
Para expandir el motor, crear un juego nuevo desde cero o añadir un transporte de red con ejemplos completos, consulta **[`DEVELOPER_GUIDE.md`](./DEVELOPER_GUIDE.md)** y **[`docs/SDK_QUICKSTART.md`](./docs/SDK_QUICKSTART.md)**.

## Estado de los 14 Juegos de la Suite (100% Reglas Canónicas + IA + UI Godot)

Cada uno de los **14 juegos** cuenta con su propio crate en Rust (`*_game`), reglas oficiales de torneo validadas en `tests/canonical_rules.rs`, generador de jugadas legales (`LegalMoveGenerator`), oponente de IA local con 4 niveles y tablero completo en Godot/Redot con HUD compacto (`TurnIndicator` + `TurnTimerHud` + `GameAppMenu`):

| Juego | Reglas Básicas | Reglas Canónicas en Motor Rust | Controles Canónicos en UI Godot | Tests Rust | Test Godot | UI Godot | Documentación |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **Ajedrez** (`chess_game`) | ✅ | ✅ (enroque, al paso, subpromoción, 50 mov, triple rep, mat. insuf., tablas) | ✅ (`PromotionSelectorPanel`, `OfferDrawButton`, `AcceptDrawButton`) | ✅ | ✅ | ✅ | [`chess.md`](./docs/games/chess.md) |
| **Damas** (`checkers_game`) | ✅ | ✅ (captura obligatoria, saltos múltiples encadenados, dama 4 diag., bloqueo, 40 turnos) | ✅ (`MandatoryCaptureLabel`, resaltado multicaptura, `GameAppMenu`) | ✅ | ✅ | ✅ | [`checkers.md`](./docs/games/checkers.md) |
| **Go** (`go_game`) | ✅ | ✅ (Ko, Superko posicional, suicidio prohibido, Handicap, Komi 6.5, piedras muertas) | ✅ (`HandicapOptionButton`, `PassTurnButton`, marcado `✕` y `ConfirmDeadButton`) | ✅ | ✅ | ✅ | [`go.md`](./docs/games/go.md) |
| **Shogi** (`shogi_game`) | ✅ | ✅ (drops con despromoción, Nifu, Uchifuzume, promoción FESA, Sennichite ×4) | ✅ (`PromotionDialogPanel`, bandejas Komadai interactivas) | ✅ | ✅ | ✅ | [`shogi.md`](./docs/games/shogi.md) |
| **Xiangqi** (`xiangqi_game`) | ✅ | ✅ (General Volador, bloqueo caballo/elefante, río, palacio, cañón, Kunbi) | ✅ (Bandejas de capturas, alerta de jaque, `EventBanner`) | ✅ | ✅ | ✅ | [`xiangqi.md`](./docs/games/xiangqi.md) |
| **Damas Chinas** (`chinese_checkers_game`) | ✅ | ✅ (estrella de 121 casillas, 2/3/4/6 jugadores, saltos en cadena, anti-bloqueo) | ✅ (Selector 2–6 jugadores en menú Opciones, resaltado de saltos) | ✅ | ✅ | ✅ | [`chinese_checkers.md`](./docs/games/chinese_checkers.md) |
| **Backgammon** (`backgammon_game`) | ✅ | ✅ (dobles = 4 movs, obligación de usar ambos/mayor dado, Doubling Cube, Crawford) | ✅ (`OfferDouble`, `AcceptDouble`, `RejectDouble`, `DiceWidget`) | ✅ | ✅ | ✅ | [`backgammon.md`](./docs/games/backgammon.md) |
| **Batalla Naval** (`battleship_game`) | ✅ | ✅ (tablero 10×10, 5 barcos `[5,4,3,3,2]`, ráfaga `extra_turn_on_hit`, `RematchCommand`) | ✅ (Rotación `R`/clic der., `ExtraTurnCheckBox`, `RematchButton`) | ✅ | ✅ | ✅ | [`battleship.md`](./docs/games/battleship.md) |
| **Ludo** (`ludo_game`) | ✅ | ✅ (circuito 52 + 5 meta, tres 6 seguidos, 8 casillas seguras/estrellas, bono captura/meta) | ✅ (`DiceWidget`, recorrido animado, casillas estrella) | ✅ | ✅ | ✅ | [`ludo.md`](./docs/games/ludo.md) |
| **Mil Millas** (`mille_bornes_game`) | ✅ | ✅ (meta 1000/1200 km, máx 2×200 km, 4 Safeties con turno extra, Coup Fourré) | ✅ (`CoupFourreButton`, tableau de 4 escudos e iconos SVG) | ✅ | ✅ | ✅ | [`mille_bornes.md`](./docs/games/mille_bornes.md) |
| **Monopoly** (`monopoly_game`) | ✅ | ✅ (40 casillas, Suerte/Arca, Subastas, Casas/Hoteles uniformes, Hipotecas, Trueques) | ✅ (Paneles de Subasta, Construcción, Hipoteca y Trade) | ✅ | ✅ | ✅ | [`monopoly.md`](./docs/games/monopoly.md) |
| **Uno** (`uno_game`) | ✅ | ✅ (mazo 108 cartas, grito/castigo `¡UNO!`, desafío `Wild +4`, intercepción Jump-In) | ✅ (`UnoCallButton`, `ChallengeW4Button`, `JumpInButton`, selector de color) | ✅ | ✅ | ✅ | [`uno.md`](./docs/games/uno.md) |
| **Crisis / TEG** (`crisis_game`) | ✅ | ✅ (30 territorios, 6 continentes, objetivos secretos, combate 3v3, tarjeta + bono `+2`) | ✅ (Mapa interactivo 30 países, modal de tarjetas/canje y dados 3v3) | ✅ | ✅ | ✅ | [`teg.md`](./docs/games/teg.md) |
| **El Juego de la Oca** (`goose_game`) | ✅ | ✅ (espiral 63 casillas, 13 Ocas, Puentes, Posada, Dados, Pozo, Laberinto, Cárcel, Calavera, rebote) | ✅ (`DiceWidget` 3D/2D, recorrido en espiral 63 casillas, `GooseTutorial`) | ✅ | ✅ | ✅ | [`goose.md`](./docs/games/goose.md) |

**`open_table_godot/` (bridge de Godot/Redot): compila, carga y está
verificado en runtime.** Corre en Redot 4.x / Godot 4.x.
Un único nodo `OpenTableBridge` soporta modos local, vs IA, host/cliente TCP,
Relay WebSocket y P2P móvil — ver `open_table_godot/BRIDGE_USAGE.md`.

## Quick Start / Guía de Expansión para Desarrolladores

> 🚀 **[Guía del Desarrollador (`DEVELOPER_GUIDE.md`)](./DEVELOPER_GUIDE.md)** y **[Guía Rápida de 15 Minutos (`docs/SDK_QUICKSTART.md`)](./docs/SDK_QUICKSTART.md)**: Aprende a crear tu propio juego de mesa desde cero, añadir variantes configurables o integrar un nuevo transporte `RawByteLink`.

Para integrar OpenTable SDK en un proyecto externo de Rust o en Godot Engine, consulta también la **[`Guía de Integración`](./docs/integration_guide.md)** con ejemplos completos de código para Rust y GDScript.

## Logros, Rating ELO y Oponente de IA Local

El SDK incluye módulos de alto nivel listos para usar directamente desde GDScript en Godot 4 / Redot:

### 1. Sistema de Logros (`AchievementManager`)
Gestiona el desbloqueo, persistencia y feedback visual de logros del jugador (`godot_project/achievement_manager.gd`), validado mediante `godot_project/tests/achievements_smoke.gd`.

- **Persistencia automática**: Guarda el progreso en `user://achievements.json`.
- **Notificaciones HUD**: Despliega alertas animadas flotantes estilo popup en pantalla cuando un logro es obtenido.
- **API y Señales principales**:
  ```gdscript
  # Desbloquear un logro por ID (retorna true si se desbloqueó por primera vez)
  var newly_unlocked = AchievementManager.unlock("primera_victoria_damas")

  # Consultar estado
  if AchievementManager.is_unlocked("gane_jaque_mate"):
      print("Logro obtenido")

  # Suscribirse a la señal de desbloqueo
  AchievementManager.achievement_unlocked.connect(func(id: String, info: Dictionary):
      print("¡Logro desbloqueado: ", info["title"], " - ", info["description"])
  )
  ```

### 2. Rating ELO (`open_table_engine::elo` y GDScript Bridge)
Cálculo oficial de puntuación ELO ($E_a = \frac{1}{1 + 10^{(R_b - R_a)/400}}$, $\Delta = K \cdot (S - E)$) implementado de forma pura en Rust (`open_table_engine/src/elo.rs`) y expuesto a Godot vía GDExtension (`open_table_godot`).

- **Fórmula FIDE**: Soporta factores K configurables (por defecto $K=32$ para partidas estándar, $K=16$ para jugadores veteranos).
- **Cálculo de Deltas desde GDScript**:
  ```gdscript
  var bridge = OpenTableBridge.new()

  # Calcula los nuevos ratings tras una victoria (winner_id, loser_id, elo_winner, elo_loser, k_factor)
  var nuevos_elos: Array = bridge.compute_elo_delta(1, 2, 1200.0, 1200.0, 32.0)
  var nuevo_elo_ganador: float = nuevos_elos[0] # 1216.0
  var nuevo_elo_perdedor: float = nuevos_elos[1] # 1184.0
  ```
- **Seguimiento Integrado**: `ScoreTracker` (`godot_project/score_tracker.gd`) almacena automáticamente el rating ELO por jugador y tipo de juego en `user://scores.json`.

### 3. Oponente de IA Local Offline (`ai_player: Option<PlayerId>`)
El motor cuenta con algoritmos de IA locales y deterministas (heurísticas posicionales, Minimax/evaluación con profundidad configurable y agentes de toma de decisiones) para jugar contra la máquina sin conexión ni dependencias externas.

- **Modos vs IA soportados**: Los **14 juegos** del catálogo (`chess`, `checkers`, `go`, `shogi`, `xiangqi`, `backgammon`, `ludo`, `mille_bornes`, `uno`, `crisis`, `chinese_checkers`, `monopoly`, `battleship`, `goose`).
- **Ciclo Autónomo en `_process()`**: Cuando el turno actual coincide con `ai_player`, el bridge procesa y ejecuta automáticamente la jugada en el ECS emitiendo las señales correspondientes (`piece_moved`, `event_json`, `game_over`), validado en `ai_local_smoke.gd`, `ai_shogi_xiangqi_smoke.gd` y `ai_all_games_smoke.gd`.
- **Inicialización desde GDScript**:
  ```gdscript
  var bridge = OpenTableBridge.new()

  # Ajedrez vs IA (Jugador 1 humano vs Jugador 2 IA con profundidad 2)
  bridge.start_local_match_chess_vs_ai(1, 2, 2)

  # Damas vs IA (seed aleatorio, Jugador 1 humano vs Jugador 2 IA)
  bridge.start_local_match_checkers_vs_ai(42, 1, 2)

  # Go (9x9) vs IA
  bridge.start_local_match_go_vs_ai(1, 2, 9)

  # Shogi y Xiangqi vs IA
  bridge.start_local_match_shogi_vs_ai(1, 2, 1)
  bridge.start_local_match_xiangqi_vs_ai(1, 2)

  # Backgammon y Ludo vs IA
  bridge.start_local_match_backgammon_vs_ai(1, 2)
  bridge.start_local_match_ludo_vs_ai(1, 2)
  ```

## Cómo correr los tests de cualquier juego

```bash
cd checkers_game && cargo test          # o battleship_game, ludo_game, etc.
```

## Auditoría de Reglas Completas y Plan de Cierre (`PROMPTS13.md`)

Las simplificaciones iniciales de los prototipos (enroque/al paso en Ajedrez, captura obligatoria y saltos múltiples en Damas, Ko/Superko en Go, Nifu/Uchifuzume en Shogi, General Volador en Xiangqi, estrella de 121 casillas en Damas Chinas, Doubling Cube en Backgammon, tablero 10×10 con 5 barcos en Batalla Naval, pista de 52 casillas en Ludo, meta de 1000 km y Coup Fourré en Mil Millas, tablero de 40 casillas con Suerte/Arca/Cárcel/Subastas en Monopoly e Intercepción Jump-In en UNO) **ya están implementadas en los crates de Rust**.

Los detalles finos de reglamento oficial de torneo y el cableado de comandos avanzados en la UI de Godot están especificados paso a paso, garantizando **compatibilidad regresiva total sin romper el motor ni los tests existentes**, en **[`PROMPTS13.md`](./PROMPTS13.md)** (Prompts **496 al 520**):

- **Ajedrez**: Selector visual de coronación (`Queen`/`Rook`/`Bishop`/`Knight`) y controles de tablas (`OfferDraw`/`AcceptDraw`) en `chess_board.gd`.
- **Damas**: Victoria automática cuando el rival queda bloqueado sin movimientos legales y tablas por 40 turnos sin captura ni coronación.
- **Go**: Puntuación con Komi (`6.5`) y prisioneros capturados; botones de `PassCommand`, `MarkDeadCommand` y `ConfirmDeadCommand` en `go_board.gd`.
- **Shogi**: Separación entre promoción opcional (`can_promote`) y obligatoria (`must_promote` solo en filas sin jugada futura), regla de **Sennichite** (cuádruple repetición) y diálogo de promoción en `shogi_board.gd`.
- **Xiangqi**: Derrota por ahogado (*Kunbi* — quedarse sin jugadas legales aunque no haya jaque) y registro de `XiangqiLegalMoveGenerator`.
- **Damas Chinas**: Regla oficial anti-bloqueo en triángulo destino (*home-camp spoiling*), `ResignCommand` y `ChineseCheckersLegalMoveGenerator`.
- **Backgammon**: Obligación de usar ambos dados (o el dado mayor si solo uno es jugable) y controles del Doubling Cube en `backgammon_board.gd`.
- **Batalla Naval**: Regla opcional `extra_turn_on_hit` en `BattleshipConfigResource` (desactivada por defecto para preservar tests clásicos), `ResignCommand` y botón de revancha en `battleship_board.gd`.
- **Ludo**: Penalización por tres `6` consecutivos, tirada extra al capturar o coronar ficha en meta y las 4 casillas seguras de estrella intermedias (`+8`).
- **Mil Millas**: Las 4 cartas de seguridad completas (`RightOfWay`, `ExtraTank`, `PunctureProof`, `DrivingAce`), turno extra al bajar Safety, bono de `+100 km` en `CoupFourreCommand` y botón de reacción en `mille_bornes_board.gd`.
- **Monopoly**: Construcción uniforme de Casas y Hoteles (`BuildHouseCommand`/`SellHouseCommand`), Hipotecas (`MortgagePropertyCommand`), 3 dobles seguidos a la cárcel, uso de carta `GetOutOfJailFree` e intercambios entre jugadores (`ProposeTradeCommand`).
- **UNO**: Grito y penalización de `"¡UNO!"` (`CallUnoCommand`/`CatchUnoFailureCommand`), desafío de `+4` (`ChallengeWildDrawFourCommand`) y botón de intercepción (`InterceptCommand`) en `uno_board.gd`.
- **Crisis / TEG**: Robo efectivo de 1 `TerritoryCard` al finalizar el turno tras conquistar al menos un territorio y bono de `+2` ejércitos al canjear tarjeta de territorio propio.

## 👉 Para continuar el proyecto en tu máquina local

Ver **[`NEXT_STEPS.md`](./NEXT_STEPS.md)** y **[`PROMPTS13.md`](./PROMPTS13.md)**.

## Workspace y reproducibilidad

Los **23 crates** son un solo **workspace de Cargo** (`Cargo.toml` raíz) con un
`target/` y un `Cargo.lock` compartidos y commiteados: esa es la garantía
de builds reproducibles. Comandos principales:

```bash
cargo test --workspace --exclude open_table_godot  # Suites unitarias, de reglas y canónicas en Rust
cargo build -p open_table_godot                    # Puente GDExtension para Godot 4 / Redot
./tools/run_godot_tests.sh                         # 47 suites smoke headless en Godot / Redot
./tools/verify_p13.sh                              # Certificación completa de lanzamiento v1.0.0
```

## Guía de Contribución / Audit de Dependencias

Para mantener la seguridad y licencias del proyecto, se utiliza `cargo-deny` para auditar vulnerabilidades, licencias y versiones duplicadas de crates clave (`serde`, `bevy_ecs`).

- Para ejecutar la verificación local de dependencias:
  ```bash
  cargo deny check
  ```
- Para actualizar la base de datos local de avisos de seguridad (RustSec Advisory Database):
  ```bash
  cargo deny fetch
  ```

## Estado de Cierre (`v1.0.0` Ready)

Ver `NEXT_STEPS.md` y `TEST_SUMMARY.md` para el inventario completo de pruebas:

1. ✅ **`open_table_godot`**: Compila, carga en Redot 26.2 / Godot 4.x y expone los 14 juegos en modos Local, vs IA, Host/Cliente TCP, Relay WebSocket y P2P móvil.
2. ✅ **14 Juegos con Reglas Canónicas + IA + Dados 3D**: Todos los motores de Rust y los 14 tableros de Godot implementan las reglas oficiales de torneo, generador de jugadas legales (`LegalMoveGenerator`) y dados 3D (`DiceRoller3D`).
3. ✅ **Multijugador QR/LAN y Online Relay WebSocket**: Integrado en el Menú Principal (`main_menu.gd`) y `GameManager` con descubrimiento UDP (`19451`), transporte TCP (`19450`), salas Relay WebSocket con `SyncState`, bloqueo de turno local (`is_local_turn_allowed()`) en los 14 tableros y reconexión automática.
4. ✅ **Plugins Nativos Móviles (`Android` / `iOS`)**: `OpenTableNearby` (`.aar`) y `OpenTableMultipeer` (`.xcframework`) conectados a `GodotRawByteLink` y compilados en CI/Release.
5. ✅ **47/47 Suites Smoke Headless en Godot + `verify_p13.sh`**: Ejecutadas automáticamente en CI y en el pipeline de Release.
