# OpenTable SDK — estado actual

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/joduranvillan/games_tables_sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/joduranvillan/games_tables_sdk)
[![Crates.io](https://img.shields.io/crates/v/open_table_core.svg)](https://crates.io/crates/open_table_core)
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](LICENSE-MIT)
[![Juegos Implementados](https://img.shields.io/badge/juegos-13%2F13-brightgreen.svg)](#juegos-de-referencia-y-reglas)

Para el diseño completo (diagrama de capas, detalle por crate, flujo de
una jugada de punta a punta, matriz de estado) ver
**[`ARCHITECTURE.md`](./ARCHITECTURE.md)**. Este documento es más bien
un resumen de estado + cómo correr cada parte.

## Nivel de confianza distinto según la parte

### Juegos de referencia y reglas
Cada uno con su propio `Command`/`Event`/`Resource`, reglas reales registradas en el `RuleEngine`, y referencia de reglas documentada:

| Juego | Reglas Básicas | Reglas Completas | Tests Rust | Test Godot | UI Godot | Documentación |
|---|:---:|:---:|:---:|:---:|:---:|---|
| **Ajedrez** (`chess_game`) | ✅ | ⚠️ (sin enroque/al paso) | ✅ | ✅ | ✅ | [`chess.md`](./docs/games/chess.md) |
| **Damas** (`checkers_game`) | ✅ | ⚠️ (sin captura obligatoria) | ✅ | ✅ | ✅ | [`checkers.md`](./docs/games/checkers.md) |
| **Go** (`go_game`) | ✅ | ⚠️ (sin regla de Ko) | ✅ | ✅ | ✅ | [`go.md`](./docs/games/go.md) |
| **Shogi** (`shogi_game`) | ✅ | ⚠️ (falta Nifu/Uchifuzume) | ✅ | ✅ | ✅ | [`shogi.md`](./docs/games/shogi.md) |
| **Xiangqi** (`xiangqi_game`) | ✅ | ⚠️ (falta General Volador) | ✅ | ✅ | ✅ | [`xiangqi.md`](./docs/games/xiangqi.md) |
| **Damas Chinas** (`chinese_checkers_game`) | ✅ | ⚠️ (tablero estrella) | ✅ | ✅ | ✅ | [`chinese_checkers.md`](./docs/games/chinese_checkers.md) |
| **Backgammon** (`backgammon_game`) | ✅ | ⚠️ (sin doubling cube) | ✅ | ✅ | ✅ | [`backgammon.md`](./docs/games/backgammon.md) |
| **Batalla naval** (`battleship_game`) | ✅ | ⚠️ (tablero 8x8) | ✅ | ✅ | ✅ | [`battleship.md`](./docs/games/battleship.md) |
| **Ludo** (`ludo_game`) | ✅ | ⚠️ (24 casillas) | ✅ | ✅ | ✅ | [`ludo.md`](./docs/games/ludo.md) |
| **Mil Millas** (`mille_bornes_game`) | ✅ | ⚠️ (meta 200) | ✅ | ✅ | ✅ | [`mille_bornes.md`](./docs/games/mille_bornes.md) |
| **Monopoly** (`monopoly_game`) | ✅ | ⚠️ (16 casillas) | ✅ | ✅ | ✅ | [`monopoly.md`](./docs/games/monopoly.md) |
| **Uno** (`uno_game`) | ✅ | ⚠️ (sin intercepción) | ✅ | ✅ | ✅ | [`uno.md`](./docs/games/uno.md) |
| **Crisis / TEG** (`crisis_game`) | ✅ | ✅ (30 terr, 6 cont, obj. sec) | ✅ | ✅ | ✅ | [`teg.md`](./docs/games/teg.md) |

**`open_table_godot/` (bridge de Godot/Redot): compila, carga y está
verificado en runtime.** Corre en Redot 26.2 (= Godot 4.5.2 por dentro).
Un único nodo `CheckersBridge` soporta tres modos (local, host, cliente
por TCP) — ver `open_table_godot/BRIDGE_USAGE.md`. Hay una escena
jugable de damas en `godot_project/` (modo local) y dos tests headless
que confirman la cadena motor→bridge→señales: uno de humo (modo local)
y uno de host/cliente sobre TCP real. Detalles del binding contra Redot
(feature `api-custom` + shim) en `open_table_godot/GODOT_SETUP.md`;
cómo correr el demo, en `godot_project/README.md`.

**Todavía NO verificado** (`platform_plugins/android`, `platform_plugins/ios`):
falta compilarlos con Android Studio / Xcode.

## Quick Start / Guía de Integración

Para integrar OpenTable SDK en un proyecto externo de Rust o en Godot Engine, consulta la **[`Guía de Integración`](./docs/integration_guide.md)** con ejemplos completos de código para Rust y GDScript.

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

- **Modos vs IA soportados**: Ajedrez (`chess`), Damas (`checkers`), Go (`go`), Shogi (`shogi`), Xiangqi (`xiangqi`), Backgammon (`backgammon`) y Ludo (`ludo`).
- **Ciclo Autónomo en `_process()`**: Cuando el turno actual coincide con `ai_player`, el bridge procesa y ejecuta automáticamente la jugada en el ECS emitiendo las señales correspondientes (`move_piece`, `board_updated`, `game_over`), validado en `ai_local_smoke.gd` y `ai_shogi_xiangqi_smoke.gd`.
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

`checkers_game` sigue siendo el único con un ejemplo jugable por
consola (`cargo run --example local_match`) — el patrón es idéntico
para replicarlo en cualquiera de los otros siete.

## Simplificaciones deliberadas, por juego

Cada crate documenta las suyas en su propio `lib.rs`, resumidas acá:

- **Damas**: sin captura obligatoria, sin saltos múltiples encadenados.
- **Batalla naval**: tablero 8x8 (no 10x10), 3 barcos (no 5), sin regla
  de separación entre barcos, sin turno extra al acertar.
- **Ludo**: track compartido de 24 casillas (no 52), sin turno extra
  además del de sacar 6 (los dobles no dan 4 movimientos).
- **Mil Millas**: meta de 200 (no 1000), sin cartas de seguridad, sin
  pila de descarte/rebarajado, sin "coup fourré".
- **Backgammon**: dobles no dan 4 movimientos, sin doubling cube, bear-off
  sin la regla exacta de "solo con overshoot si no hay fichas más atrás".
- **Damas chinas**: tablero hexagonal simple (37 casillas), NO la
  estrella de 6 puntas oficial; sin saltos múltiples encadenados.
- **Monopoly**: tablero de 16 casillas (no 40), sin casas/hoteles, sin
  cartas de Suerte/Caja de Comunidad, sin cárcel, sin subastas ni
  intercambios.
- **Ajedrez**: sin enroque, sin captura al paso, corona siempre a dama
  (sin elección), sin regla de 50 movimientos ni triple repetición.

## 👉 Para continuar el proyecto en tu máquina local

Ver **[`NEXT_STEPS.md`](./NEXT_STEPS.md)**: pasos exactos de setup
(Rust moderno, Godot, Android Studio/Xcode), mapa completo de cómo se
integra todo, y la lista de funcionalidad faltante ordenada por
prioridad. Es el punto de partida recomendado después de clonar.

## Workspace y reproducibilidad

Los 15 crates son un solo **workspace de Cargo** (`Cargo.toml` raíz) con un
`target/` y un `Cargo.lock` compartidos y commiteados: esa es la garantía
de builds reproducibles (reemplaza los viejos pines `=x.y.z` que se ponían
a mano por la limitación del toolchain del sandbox original). Comandos:

```bash
cargo test --workspace          # ~74 tests de todo el SDK
cargo build -p open_table_godot # solo el bridge de Godot/Redot
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

## Lo que falta

Ver `NEXT_STEPS.md` para la versión completa y ordenada. Resumen:

1. ~~Compilar `open_table_godot`~~ ✅ hecho (compila y carga en Redot).
2. ~~Separar el bridge de Godot en modo host/cliente~~ ✅ hecho — una
   sola clase `CheckersBridge` con modos Local/Host/Client (ver
   `ARCHITECTURE.md`), verificado en runtime sobre TCP real.
3. **`open_table_transport_native_bridge`**: protocolo de
   identidad/reconexión para transportes móviles nativos, ya probado
   con 5 tests — falta conectarlo a los plugins reales de
   `platform_plugins/` (implementar `RawByteLink`).
4. **Cablear la escena principal de Godot a red** — hoy `main.tscn`
   solo juega en modo local; el modo host/cliente solo se ejerce desde
   la escena de prueba `test_tcp_bridge.tscn`.
5. **Empaquetado real de los plugins nativos** (ver README de cada
   carpeta en `platform_plugins/`).
