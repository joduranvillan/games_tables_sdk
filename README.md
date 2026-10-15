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
Cada uno con su propio `Command`/`Event`/`Resource`, reglas reales registradas en el `RuleEngine`, y referencia de reglas documentada (ver **[`PROMPTS13.md`](./PROMPTS13.md)** para el cierre del 100% de reglas canónicas de torneo y su cableado en UI):

| Juego | Reglas Básicas | Reglas en Motor Rust | Pendiente Canónico / UI (`PROMPTS13.md`) | Tests Rust | Test Godot | UI Godot | Documentación |
|---|:---:|:---:|---|:---:|:---:|:---:|---|
| **Ajedrez** (`chess_game`) | ✅ | ✅ (enroque, al paso, promoción, 50 mov, triple rep, mat. insuf., tablas) | ⚠️ UI: selector visual de pieza al coronar y botones de oferta/aceptación de tablas en tablero | ✅ | ✅ | ✅ | [`chess.md`](./docs/games/chess.md) |
| **Damas** (`checkers_game`) | ✅ | ✅ (captura obligatoria, saltos múltiples encadenados, dama 4 diag.) | ⚠️ Motor: victoria por bloqueo total sin jugadas legales del rival y tablas por 40 turnos sin captura | ✅ | ✅ | ✅ | [`checkers.md`](./docs/games/checkers.md) |
| **Go** (`go_game`) | ✅ | ✅ (Ko, Superko posicional, suicidio prohibido, Handicap, marcado de muertas) | ⚠️ Motor/UI: Komi (6.5) + prisioneros en score final; botones `Pass`, `MarkDead` y `ConfirmDead` en `go_board.gd` | ✅ | ✅ | ✅ | [`go.md`](./docs/games/go.md) |
| **Shogi** (`shogi_game`) | ✅ | ✅ (drops con despromoción, Nifu, Uchifuzume, Fuzumi/Todome) | ⚠️ Motor/UI: promoción opcional vs obligatoria por fila exacta, Sennichite (repetición ×4) y modal de promoción en UI | ✅ | ✅ | ✅ | [`shogi.md`](./docs/games/shogi.md) |
| **Xiangqi** (`xiangqi_game`) | ✅ | ✅ (General Volador, ojo de elefante, pata de caballo, río, palacio, cañón) | ⚠️ Motor: derrota por ahogado (*Kunbi*), `LegalMoveGenerator` en `RuleEngine` y regla de repetición | ✅ | ✅ | ✅ | [`xiangqi.md`](./docs/games/xiangqi.md) |
| **Damas Chinas** (`chinese_checkers_game`) | ✅ | ✅ (estrella oficial de 121 casillas, 2/3/4/6 jugadores, saltos encadenados `path`) | ⚠️ Motor: regla oficial anti-bloqueo en punta de meta (*home-camp spoiling*), `ResignCommand` y `LegalMoveGenerator` | ✅ | ✅ | ✅ | [`chinese_checkers.md`](./docs/games/chinese_checkers.md) |
| **Backgammon** (`backgammon_game`) | ✅ | ✅ (dobles = 4 movs, Doubling Cube, regla Crawford, bear-off exacto, Gammon/Backgammon) | ⚠️ Motor/UI: obligación de usar ambos dados (o el mayor) y botones de `Offer/Accept/RejectDouble` en `backgammon_board.gd` | ✅ | ✅ | ✅ | [`backgammon.md`](./docs/games/backgammon.md) |
| **Batalla naval** (`battleship_game`) | ✅ | ✅ (tablero 10×10, 5 barcos `[5,4,3,3,2]`, separación 8 dir., `RematchCommand`) | ⚠️ Motor/UI: variante configurable de turno extra al acertar (`extra_turn_on_hit`), `ResignCommand` y botón Revancha en UI | ✅ | ✅ | ✅ | [`battleship.md`](./docs/games/battleship.md) |
| **Ludo** (`ludo_game`) | ✅ | ✅ (track de 52 casillas + 5 meta, salida/turno extra con 6, casillas seguras, barreras) | ⚠️ Motor: anulación de turno por 3 seises seguidos, tiro extra por captura/meta y 4 casillas seguras de estrella (`+8`) | ✅ | ✅ | ✅ | [`ludo.md`](./docs/games/ludo.md) |
| **Mil Millas** (`mille_bornes_game`) | ✅ | ✅ (meta 1000 km con extensión, límite 2×200 km, rebarajado, `RightOfWay`, `CoupFourre`) | ⚠️ Motor/UI: las 3 cartas de seguridad restantes (`ExtraTank`, `PunctureProof`, `DrivingAce`), turno extra por Safety y botón Coup Fourré en UI | ✅ | ✅ | ✅ | [`mille_bornes.md`](./docs/games/mille_bornes.md) |
| **Monopoly** (`monopoly_game`) | ✅ | ✅ (tablero 40 casillas, 10 Suerte + 10 Arca, Cárcel, Subastas, renta doble grupo, quiebra) | ⚠️ Motor/UI: construcción de Casas/Hoteles, Hipotecas, 3 dobles seguidos a la cárcel, retención de carta salir de cárcel e Intercambios | ✅ | ✅ | ✅ | [`monopoly.md`](./docs/games/monopoly.md) |
| **Uno** (`uno_game`) | ✅ | ✅ (mazo 108 cartas, stacking `+2`/`+4`, validación `+4` legal, robo/juego inmediato, `InterceptCommand`) | ⚠️ Motor/UI: grito/penalización de `"¡UNO!"` (+2 cartas), desafío formal de `+4` (`ChallengeWildDrawFour`) y botón Jump-In en `uno_board.gd` | ✅ | ✅ | ✅ | [`uno.md`](./docs/games/uno.md) |
| **Crisis / TEG** (`crisis_game`) | ✅ | ✅ (30 territorios, 6 continentes, objetivos secretos, combate 3v3, canje de tarjetas y fortificación) | ⚠️ Motor: robo automático de 1 `TerritoryCard` al conquistar al menos un país en el turno y bono de +2 ejércitos por tarjeta de país propio | ✅ | ✅ | ✅ | [`teg.md`](./docs/games/teg.md) |

**`open_table_godot/` (bridge de Godot/Redot): compila, carga y está
verificado en runtime.** Corre en Redot 26.2 (= Godot 4.5.2 por dentro).
Un único nodo `OpenTableBridge` soporta modos local, vs IA, host/cliente TCP,
Relay WebSocket y P2P móvil — ver `open_table_godot/BRIDGE_USAGE.md`.

## Quick Start / Guía de Integración

> 🚀 **[Guía Rápida de 15 Minutos (`docs/SDK_QUICKSTART.md`)](./docs/SDK_QUICKSTART.md)**: Aprende a crear tu propio juego de mesa desde cero (ejemplo completo de *Tres en Línea / Tic-Tac-Toe* en menos de 100 líneas de Rust con `GameEngine`, `State`, `Action`, `PlayerId`, registro en `open_table_engine::Session` y señales en Godot).

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

- **Modos vs IA soportados**: Los **13 juegos** del catálogo (`chess`, `checkers`, `go`, `shogi`, `xiangqi`, `backgammon`, `ludo`, `mille_bornes`, `uno`, `crisis`, `chinese_checkers`, `monopoly`, `battleship`).
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
