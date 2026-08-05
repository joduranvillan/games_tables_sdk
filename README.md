# OpenTable SDK — estado actual

[![CI](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/joduranvillan/games_tables_sdk/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/joduranvillan/games_tables_sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/joduranvillan/games_tables_sdk)

Para el diseño completo (diagrama de capas, detalle por crate, flujo de
una jugada de punta a punta, matriz de estado) ver
**[`ARCHITECTURE.md`](./ARCHITECTURE.md)**. Este documento es más bien
un resumen de estado + cómo correr cada parte.

## Nivel de confianza distinto según la parte

**Verificado con tests reales (73 tests, 14 crates, todo corrió de
verdad en este sandbox):**

### Infraestructura (5 crates)
- `open_table_core/`: IDs, `Command`/`Event` como trait objects
  serializables (`typetag`, JSON) con visibilidad por evento,
  `Component`/`Resource`, `RandomService` determinista, `GameClock`,
  trait `Transport`.
- `open_table_engine/`: `bevy_ecs` real + `RuleEngine` + `Session`
  (turnos con `players()`/`peek_next()`, validación de identidad,
  replay/resync, `world_mut()` para setup).
- `open_table_macros/`: `#[derive(GameCommand/GameEvent/GameResource/GameComponent)]`.
- `open_table_qr/`: código + QR de invitación.
- `open_table_transport_tcp/`: `Transport` real sobre TCP, reconexión
  autenticada (token CSPRNG, timeout configurable).
- `open_table_transport_native_bridge/` **(nuevo)**: mismo protocolo de
  identidad/reconexión que `_tcp`, pero generalizado sobre un trait
  `RawByteLink` para que cualquier transporte móvil nativo (Nearby
  Connections, MultipeerConnectivity) lo herede sin reimplementarlo.
  5 tests con un `FakeRawByteLink` en memoria — el protocolo está
  probado aunque el plugin nativo real todavía no.

### Juegos de referencia y reglas
Cada uno con su propio `Command`/`Event`/`Resource`, reglas reales registradas en el `RuleEngine`, y referencia de reglas documentada:

| Juego | Reglas | Crate | Qué ejercita del SDK que los demás no |
|---|---|---|---|
| Damas | [`checkers.md`](./docs/rules/checkers.md) | `checkers_game` | Turnos, captura obligatoria, cadenas de saltos y coronación |
| Batalla naval | [`battleship.md`](./docs/rules/battleship.md) | `battleship_game` | Información oculta real (tableros privados), fase de setup sin turnos |
| Ludo | [`ludo.md`](./docs/rules/ludo.md) | `ludo_game` | 2-4 jugadores, casillas seguras, patrón "tirada pendiente" |
| Mil Millas | [`mille_bornes.md`](./docs/rules/mille_bornes.md) | `mille_bornes_game` | Manos de cartas privadas, rebarajado, peligros y remedios |
| Backgammon | [`backgammon.md`](./docs/rules/backgammon.md) | `backgammon_game` | Conteo con signo, doblaje con Doubling Cube, barra/bear-off |
| Damas chinas | [`chinese_checkers.md`](./docs/rules/chinese_checkers.md) | `chinese_checkers_game` | Coordenadas hexagonales axiales, saltar sin capturar |
| Monopoly | [`monopoly.md`](./docs/rules/monopoly.md) | `monopoly_game` | Decisión que suspende avance de turno, subastas, bancarrota |
| Ajedrez | [`chess.md`](./docs/rules/chess.md) | `chess_game` | Validación completa, enroque, al paso, simulación de jaque/jaque mate |
| Shogi | [`shogi.md`](./docs/rules/shogi.md) | `shogi_game` | Reingreso de piezas capturadas (Drops) y zona de promoción |
| Xiangqi | [`xiangqi.md`](./docs/rules/xiangqi.md) | `xiangqi_game` | Palacio, Río, regla del General Volador, tiros con Cañón |
| Go | [`go.md`](./docs/rules/go.md) | `go_game` | Libertades, regla de Ko, handicap, paso y recuento de territorio |
| Uno | [`uno.md`](./docs/rules/uno.md) | `uno_game` | Cambio de sentido, salto, cartas comodín y acumulaciones |
| Crisis | [`crisis.md`](./docs/rules/crisis.md) | `crisis_game` | Mecánica de crisis macroeconómicas e impuestos sobre capital |

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
