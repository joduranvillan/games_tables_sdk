# Prompts de Cierre e Integración — Games Tables SDK (Parte 4)

Continúa desde `PROMPTS3.md` (prompts 1–300). Numerados del 301 al 340.

**Objetivo de esta parte:** cerrar el proyecto para publicación — corregir bugs
de compilación/calidad, añadir la API de consulta que falta en la UI, completar
las dos reglas de juego que aún no existen, y cubrir los tests de red y la
responsividad mobile que quedaron como NEXT_STEPS.

---

## 0. Registro de implementación — qué está HECHO (no duplicar)

Los siguientes ítems de PROMPTS1–3 **ya están implementados** y verificados en
el código fuente. No volver a pedirlos:

### Reglas de juego (PROMPTS1 y PROMPTS2)

| Prompt | Regla | Estado |
|--------|-------|--------|
| 7 | Xiangqi — General Volador (`check_flying_general`) | ✅ `xiangqi_game/src/movement.rs:124` |
| 9 | Shogi — Nifu (dos peones en la misma columna) | ✅ `shogi_game/src/movement.rs:89` |
| 10 | Go — Regla de Ko y Superko | ✅ `go_game/src/rules.rs:33,72` |
| 41 | Shogi — Uchifuzume (drop de peón causando mate) | ✅ `shogi_game/src/rules.rs:119` |
| Varios | Chess — Enroque corto/largo y al paso (`en_passant_target`) | ✅ `chess_game/src/rules.rs:95-147` |
| 6 | Checkers — Captura obligatoria | ✅ `checkers_game/src/rules.rs:84` |

### Motor, bridge y Godot (PROMPTS2 y PROMPTS3)

- `ResignCommand` en 6 juegos de 2 jugadores ✅
- Exportación/importación PGN y FEN para ajedrez ✅
- `Session::move_history()`, historial de movimientos ✅
- `Session::export_log_compressed()` + firma HMAC ✅
- `Session::swap_rule_engine()` (hot-reload) ✅
- `CommandMiddleware` y `ResourceWatcher` ✅
- `open_table_transport_websocket/` ✅
- `start_local_match_checkers_vs_ai()` (IA básica) ✅
- `start_tournament()` con señales round-robin ✅
- Persistencia local (`save_to_file`/`load_from_file`) ✅
- Replay viewer (`load_replay`/`step_replay`) ✅
- Modo multi-sesión simultánea (`switch_session`) ✅
- Lobby LAN con QR ✅
- `AchievementManager` Autoload + logros ✅
- Tutorial interactivo TEG (`crisis_tutorial.gd`) ✅
- Attract mode en menú principal ✅
- Sistema de temas visuales (`ThemeManager`) ✅
- Sonido (`audio_manager.gd`) ✅
- `dice_widget.gd` ✅
- Localización en 9 idiomas ✅
- 22 smoke tests headless en `godot_project/tests/` ✅
- `tools/run_godot_tests.sh` con timeout y resumen ✅
- `tools/metrics.sh`, `tools/release.sh`, Dependabot ✅
- ADRs, CHANGELOG, `docs/games/teg.md` ✅

### Lo que se eliminó intencionalmente (no re-añadir)

| Elemento | Motivo |
|----------|--------|
| Discord bot (`tools/discord_bot/`) | Componente externo opcional; no parte del SDK |
| Push notifications nativas (Android/iOS) | Depende de plugins de terceros; wrapper listo, compilación nativa fuera del scope |
| Conexión directa a servicios cloud (auth, leaderboard remoto) | Decidido mantener el SDK offline-first/LAN |

### Estado real de NEXT_STEPS.md (está DESACTUALIZADO)

`NEXT_STEPS.md` marca varias reglas como ⚠️ que en realidad ya están
implementadas. El prompt 305 lo corrige.

---

## 1. Correcciones de Bugs Clippy

Los siguientes warnings de Clippy son **bugs semánticos reales**, no estéticos.
`drop()` sobre un tipo sin `Drop` no libera nada y extiende el lifetime del
borrow de forma inesperada, pudiendo causar deadlocks futuros al añadir `Mutex`.

---

**301.** Eliminar las llamadas `drop()` inútiles en `battleship_game/src/rules.rs`. En las líneas 146, 167, 171 y 176 se llama `drop(fleet)`, `drop(shots)`, `drop(turn)` sobre guards que no implementan `Drop` (son referencias sacadas de recursos de Bevy ECS). Reemplazar cada `drop(x)` eliminando la línea directamente — Rust libera el borrow cuando la variable sale de scope. Verificar con `cargo clippy -p battleship_game -- -D warnings` que el crate queda sin warnings. Añadir el test de regresión `test_drop_cleanup_no_afecta_estado` que ejecuta un `PlaceShipCommand` + `ShootCommand` en secuencia y verifica que el estado es consistente.

---

**302.** Eliminar las llamadas `drop()` inútiles en `chinese_checkers_game/src/rules.rs` (líneas 103 y 123) y en `ludo_game/src/rules.rs`. Mismo patrón que el prompt 301: los borrows de recursos Bevy ECS no implementan `Drop` y las llamadas son no-ops. Verificar con `cargo clippy -p chinese_checkers_game -p ludo_game -- -D warnings`. El total de warnings `drop(non-drop)` en el workspace debe bajar de 20 a 0 tras los prompts 301 y 302.

---

**303.** Corregir los warnings de `&Box<T>` en `open_table_engine`. En `open_table_engine/src/rule_engine.rs` y `open_table_engine/src/session.rs`, las firmas internas que reciben `&Box<dyn Command>` o `&Box<dyn Event>` deben cambiarse a `&dyn Command` y `&dyn Event` respectivamente. Aplicar con `cargo clippy --fix -p open_table_engine`. Verificar que todos los tests del engine siguen pasando después del cambio.

---

**304.** Corregir los warnings estéticos de alto impacto en el workspace con `cargo clippy --fix`. Aplicar en bloque las sugerencias automáticas de:
- `while let` en `open_table_transport_tcp/src/host.rs` (reemplazar `loop { match ... }` por `while let`).
- `if` colapsables en `xiangqi_game/src/rules.rs` (3 avisos).
- `map_or` simplificable en `open_table_engine/src/session.rs` y `xiangqi_game`.
- `contains()` vs `iter().any()` en checkers.

Tras aplicar: `cargo clippy --workspace -- -D warnings` debe pasar sin salida (sólo se permiten los warnings de `open_table_godot` que requieren `gdext`).

---

## 2. Actualización de Documentación de Estado

---

**305.** Reescribir la tabla de juegos en `NEXT_STEPS.md`. La tabla actual marca con ⚠️ reglas que ya están implementadas (Ko en Go, Nifu/Uchifuzume en Shogi, General Volador en Xiangqi, captura obligatoria en Checkers, enroque y al paso en Ajedrez). Actualizar cada celda al estado real verificado en código. Las únicas ⚠️ que deben permanecer son las simplificaciones **voluntarias documentadas** (tablero 16 casillas Monopoly, tablero 8×8 Battleship, 24 casillas Ludo, meta 200 Mille Bornes, sin intercepción UNO, sin doubling cube Backgammon). Actualizar también la sección "Próximas Prioridades" para reflejar el estado actual: los dos items de Shogi ya están resueltos; la prioridad #1 real ahora es el doubling cube de Backgammon.

---

## 3. API de Consulta para UI (get_legal_moves)

El problema más crítico de usabilidad pendiente: la UI en Godot debe intentar
movimientos a ciegas o duplicar lógica de reglas en GDScript. Exponer los
movimientos legales directamente desde el motor elimina ambos problemas.

---

**306.** Implementar `Session::get_legal_moves` en `open_table_engine/src/session.rs`. La función prueba cada comando registrado para el jugador activo con `process_command` en un **clon del mundo** (no en la sesión real) y devuelve los que no retornan error:

```rust
pub fn get_legal_moves(&self, player: PlayerId) -> Vec<serde_json::Value>
```

El clon del mundo se obtiene con `self.world.clone()`. Cada juego registra sus comandos con tipos concretos vía `RuleEngine`; la función itera sobre los candidatos generados por un `LegalMoveGenerator` — una nueva trait que cada juego puede implementar opcionalmente. Si el juego no implementa la trait, `get_legal_moves` devuelve `vec![]` (comportamiento seguro por defecto). Añadir el test `test_get_legal_moves_devuelve_solo_movimientos_validos` en checkers: posición inicial, P1 tiene exactamente 7 movimientos posibles.

---

**307.** Implementar `LegalMoveGenerator` para `checkers_game`. Crear `checkers_game/src/legal_moves.rs` con `pub struct CheckersLegalMoveGenerator`. La función `generate(world: &World, player: PlayerId) -> Vec<Box<dyn Command>>` enumera todos los `MovePieceCommand` posibles para las piezas del jugador (iterar sobre el tablero, calcular destinos válidos para cada pieza). Registrar en `build_checkers_rules()` con `rule_engine.set_legal_move_generator(Box::new(CheckersLegalMoveGenerator))`. Verificar que `session.get_legal_moves(P1)` en posición inicial devuelve exactamente los 7 movimientos esperados.

---

**308.** Implementar `LegalMoveGenerator` para `chess_game`. Crear `chess_game/src/legal_moves.rs` con `pub struct ChessLegalMoveGenerator` que enumera todos los `MovePieceCommand` posibles para cada pieza del jugador (torre: ortogonal; alfil: diagonal; dama: ambas; caballo: L; peón: avance + captura diagonal + al paso; rey: adyacente + enroque). Excluir movimientos que dejan al rey en jaque usando el mismo clon-del-mundo del prompt 306. Registrar en `build_chess_rules()`. Añadir el test `test_legal_moves_posicion_inicial_tiene_20_jugadas` que verifica que las blancas en la posición inicial tienen exactamente 20 movimientos legales.

---

**309.** Exponer `get_legal_moves` en el bridge Godot. Añadir en `open_table_godot/src/lib.rs`:

```rust
#[func]
fn get_legal_moves(&self, player_id: i64) -> Array<Dictionary>
```

Cada elemento del array es un `Dictionary` con las claves del comando (ej. `{ "from_row": 2, "from_col": 1, "to_row": 3, "to_col": 2 }` para checkers). Actualizar `checkers_board.gd` para reemplazar el cálculo client-side de movimientos válidos (añadido en el prompt 202 de PROMPTS3) por una llamada real a `bridge.get_legal_moves(current_player())`. Hacer lo mismo en `chess_board.gd`. Añadir el smoke test `test_get_legal_moves_bridge.gd` que verifica que la llamada devuelve un `Array` no vacío en la posición inicial.

---

## 4. Reglas Avanzadas Restantes

Las dos únicas reglas marcadas en NEXT_STEPS como pendientes reales (no simplificaciones voluntarias).

---

**310.** Implementar el **doubling cube** en `backgammon_game`. Añadir en `backgammon_game/src/commands.rs`:

```rust
pub struct OfferDoubleCommand { pub player: PlayerId }
pub struct AcceptDoubleCommand { pub player: PlayerId }
pub struct RejectDoubleCommand { pub player: PlayerId }
```

Añadir `DoublingCubeResource { value: u32, owner: Option<PlayerId>, offered: bool }` en `backgammon_game/src/resources.rs`. Reglas: solo puede ofrecer el jugador activo antes de mover. Si el oponente rechaza, pierde la partida al valor actual del cubo. Si acepta, el cubo se duplica y pasa a ser propiedad del aceptante (solo él puede re-doblar). El `GameOverEvent` debe incluir `score: u32` (= cubo × puntos de tablero). Registrar los tres handlers en `build_backgammon_rules()`. Añadir tests: `test_ofrecer_doble_antes_de_mover_es_valido`, `test_rechazar_doble_termina_la_partida`, `test_aceptar_doble_duplica_el_cubo`.

---

**311.** Implementar la **intercepción (jump-in)** en `uno_game`. Un jugador que tiene exactamente la carta jugada por el jugador activo puede interrumpir el turno y jugarla fuera de orden. Añadir `InterceptCommand { player: PlayerId, card_index: usize }` en `uno_game/src/commands.rs`. El handler valida que `hand[player][card_index]` es idéntica (mismo color Y mismo valor, no wildcards) a la carta en la pila de descarte. Tras la intercepción, el turno continúa desde el jugador interceptor en la dirección normal (como si él hubiera jugado regularmente). Añadir `InterceptedEvent { player: PlayerId, card: Card }`. Tests: `test_intercepcion_valida_con_carta_identica`, `test_intercepcion_invalida_con_carta_similar_pero_diferente_color`.

---

## 5. Sistema de Puntuación ELO

---

**312.** Implementar **ELO rating** en `open_table_engine`. Crear `open_table_engine/src/elo.rs` con:

```rust
pub struct EloRating(pub f64);
pub fn update_elo(winner: EloRating, loser: EloRating, k: f64) -> (EloRating, EloRating)
pub fn update_elo_draw(a: EloRating, b: EloRating, k: f64) -> (EloRating, EloRating)
```

Implementar la fórmula estándar: `E_a = 1 / (1 + 10^((R_b - R_a)/400))`, delta = `K * (S - E)`. Empezar en 1200, K=32 para partidas normales, K=16 para jugadores con +30 partidas. Añadir `Session::compute_elo_delta(winner: PlayerId, loser: PlayerId, k: f64) -> (f64, f64)` que devuelve los deltas a aplicar externamente (el motor no almacena ELO; es responsabilidad de la app). Añadir los tests: `test_victoria_sube_elo_del_ganador`, `test_empate_iguala_elos_similares`, `test_victoria_contra_favorito_da_mayor_delta`.

---

**313.** Exponer ELO en Godot y conectar con `score_tracker.gd`. Añadir en `open_table_godot/src/lib.rs` la función `compute_elo_delta(winner_id: i64, loser_id: i64, winner_current: f64, loser_current: f64, k: f64) -> Array[float]` que devuelve `[nuevo_winner, nuevo_loser]`. Actualizar `score_tracker.gd` para almacenar en `user://scores.json` el campo `elo` por jugador y por tipo de juego. Al recibir la señal `game_over`, si `winner_id != -1` (no empate), llamar `compute_elo_delta` y guardar los nuevos valores. Mostrar el ELO actual en la pestaña "Estadísticas" del `settings_menu.tscn`.

---

## 6. Tests de Red TCP en Godot

El test `test_spectator.gd` existe pero los escenarios de reconexión y pérdida de paquetes no están cubiertos en Godot headless.

---

**314.** Crear `godot_project/tests/tcp_reconnection_smoke.gd` — **test de reconexión TCP**. El test: (1) arranca una sesión de damas local como host TCP en puerto 19877, (2) conecta un cliente, (3) juega un movimiento y verifica que el cliente lo recibe, (4) cierra el socket del cliente abruptamente con `client.close()`, (5) reconecta el cliente al mismo puerto, (6) verifica que el host re-emite los eventos perdidos (replay desde el tick del cliente). Añadir un timeout de 10 segundos. Confirmar exit code 0 headless. Añadir al runner `tools/run_godot_tests.sh`.

---

**315.** Crear `godot_project/tests/tcp_packet_loss_smoke.gd` — **simulación de pérdida de paquetes**. Implementar un `MockTcpProxy` en GDScript que reenvía paquetes entre host y cliente con un 20% de probabilidad de descarte (usando `randf()` con seed fija). Conectar host y cliente a través del proxy. Jugar 10 movimientos. Verificar que todos los movimientos llegan eventualmente (con reintentos) y que el estado final es consistente entre host y cliente. Timeout de 30 segundos. Este test verifica la robustez del protocolo TCP del SDK bajo condiciones adversas.

---

**316.** Crear `godot_project/tests/multi_session_tcp_smoke.gd` — **dos sesiones TCP simultáneas en puertos diferentes** (19878 y 19879). Verificar que los eventos de la sesión A no llegan a la sesión B y viceversa. Este test complementa `multi_session_smoke.gd` (que cubre sesiones locales) con aislamiento de red real. Confirmar exit code 0 headless.

---

## 7. Mobile UI Responsive

---

**317.** Implementar **breakpoints de layout** en `godot_project/game_manager.gd`. Añadir:

```gdscript
enum ScreenLayout { DESKTOP, TABLET, PHONE }
static func get_layout() -> ScreenLayout:
    var w = DisplayServer.screen_get_size().x
    if w >= 1024: return ScreenLayout.DESKTOP
    if w >= 600:  return ScreenLayout.TABLET
    return ScreenLayout.PHONE
```

Emitir la señal `layout_changed(layout: int)` al detectar un cambio de tamaño de ventana (`get_tree().root.size_changed`). Conectar `checkers_board.gd`, `chess_board.gd` y `crisis_board.gd` a esta señal para reposicionar el panel lateral: en PHONE, el panel de estado de jugador colapsa debajo del tablero en lugar de a la derecha. Verificar que el tablero sigue siendo cuadrado en todos los layouts.

---

**318.** Implementar **gestos táctiles** en `checkers_board.gd` y `chess_board.gd`. Reemplazar el `_gui_input` de click por un handler unificado que acepta tanto `InputEventMouseButton` como `InputEventScreenTouch` (un tap = un click). Para arrastrar piezas, manejar `InputEventScreenDrag` con el mismo inicio/fin que el drag con ratón. Añadir un área de "zona muerta" de 8px para evitar drops accidentales en pantallas táctiles. Verificar que las animaciones Tween siguen funcionando correctamente tras el gesto.

---

**319.** Implementar **tamaño de fuente adaptativo** en `ThemeManager`. Añadir `get_font_scale() -> float` que devuelve 0.75 en PHONE, 1.0 en TABLET, 1.25 en DESKTOP (basado en `GameManager.get_layout()`). Aplicar el factor a todos los `Label` de los tableros usando `theme.set_font_size("font_size", "Label", base_size * scale)`. Conectar al evento `layout_changed` para re-aplicar al cambiar orientación. Verificar que los nombres de territorios en `crisis_board.gd` siguen siendo legibles en un viewport de 375×667 (iPhone SE).

---

## 8. Cierre y Publicación

---

**320.** Actualizar `NEXT_STEPS.md` al estado final real. Eliminar la sección "Próximas Prioridades" con los tres ítems ya resueltos (Shogi, tests TCP, mobile UI). Reemplazar por una sección **"Para publicación en crates.io"** con checklist:
- `[ ]` Doubling cube Backgammon (prompt 310)
- `[ ]` Jump-in UNO (prompt 311)
- `[ ]` `get_legal_moves` con `LegalMoveGenerator` para checkers y chess (prompts 306-309)
- `[ ]` 0 warnings de Clippy (`cargo clippy --workspace -- -D warnings`)
- `[ ]` Versión semántica 0.1.0 en todos los `Cargo.toml`
- `[ ]` Documentación pública en `docs.rs` (verificar `cargo doc --workspace --no-deps`)

---

**321.** Completar la **documentación pública de API** en los crates principales. Añadir doc-comments `///` en las funciones públicas de `open_table_core/src/lib.rs` y `open_table_engine/src/session.rs` que actualmente no tienen ninguno: `Session::process_command`, `Session::current_player`, `Session::export_log`, `Session::get_legal_moves`, `Session::compute_elo_delta`. El estándar: una línea de descripción + ejemplo de uso en bloque `# Examples`. Verificar con `cargo doc --workspace --no-deps 2>&1 | grep "warning:" | wc -l` que el resultado es 0.

---

**322.** Crear `.cargo/publish.toml` con la **configuración de publicación** para el orden correcto de crates en crates.io (las dependencias antes que los dependientes):

```
open_table_macros → open_table_core → open_table_engine
→ [juegos] → open_table_transport_tcp → open_table_transport_websocket
→ open_table_qr
```

Añadir el target `publish-dry-run` al Makefile que corre `cargo publish --dry-run -p <crate>` en ese orden para verificar que los manifests están correctos. Excluir `open_table_godot` y `open_table_transport_native_bridge` del publish (no son útiles en crates.io sin el entorno nativo). Documentar en `CONTRIBUTING.md`.

---

**323.** Añadir el **target `audit` al Makefile** que corre `cargo deny check` (ya configurado en `deny.toml`) + `cargo audit` (si está instalado). El audit verifica advisories de seguridad en las dependencias. Añadir como step en `ci.yml` antes del paso de tests, de forma que una vulnerabilidad conocida bloquee el CI. Documentar en `CONTRIBUTING.md` cómo responder a un advisory: actualizar la dependencia o añadir una excepción justificada en `deny.toml`.

---

**324.** Crear `docs/integration_guide.md` — **guía de integración para desarrolladores externos**. Documentar cómo usar el SDK desde un proyecto Rust externo: (1) añadir `open_table_engine` como dependencia, (2) crear una sesión de ajedrez con `new_chess_session`, (3) procesar un comando, (4) leer los eventos. Incluir un ejemplo completo compilable (doctest). Para Godot: cómo descargar la extensión `.so` precompilada (cuando exista), copiarla al proyecto, y hacer una llamada mínima desde GDScript. Enlazar desde `README.md` en la sección "Quick Start".

---

**325.** Crear el **tag de primera release** cuando los prompts 301-324 estén completos. Ejecutar `tools/release.sh` que: verifica 0 uncommitted changes, 0 clippy warnings, todos los tests pasando, hace bump de versión a `0.1.0` en todos los `Cargo.toml` del workspace con `tools/bump_version.sh --set 0.1.0`, crea el commit `chore: release v0.1.0`, y crea el tag anotado `v0.1.0`. Nunca hacer push automático — el desarrollador lo hace manualmente tras revisar. Añadir la sección `[0.1.0]` en `CHANGELOG.md` con la fecha real de publicación.

---

*Fin de PROMPTS4.md — 25 prompts (301–325).*

*Resumen por sección:*
- *0. Registro de estado (no son prompts): documentación de lo implementado en 1–300*
- *1. Bugs Clippy críticos: prompts 301–304 (4 prompts)*
- *2. Documentación de estado: prompt 305 (1 prompt)*
- *3. API de consulta get_legal_moves: prompts 306–309 (4 prompts)*
- *4. Reglas avanzadas restantes: prompts 310–311 (2 prompts)*
- *5. Sistema ELO: prompts 312–313 (2 prompts)*
- *6. Tests de red TCP: prompts 314–316 (3 prompts)*
- *7. Mobile UI responsive: prompts 317–319 (3 prompts)*
- *8. Cierre y publicación: prompts 320–325 (6 prompts)*

*Total acumulado: 325 prompts (PROMPTS1: 1–40, PROMPTS2: 41–160, PROMPTS3: 161–300, PROMPTS4: 301–325).*
