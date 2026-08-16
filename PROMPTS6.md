# Prompts de Calidad, Publicación y Completitud — Games Tables SDK (Parte 6)

Continúa desde `PROMPTS5.md` (prompts 1–350). Numerados del 351 al 395.

**Objetivo de esta parte:**
1. Preparar el workspace para publicación en crates.io (versiones, docs, deny).
2. Completar las reglas faltantes en juegos marcados con ⚠️ (Battleship, Ludo, Mille Bornes, Monopoly).
3. Añadir IA para los juegos que aún carecen de ella (Go, Ludo, Mille Bornes).
4. Mejorar los tests de integración de la IA en Godot headless.
5. Cerrar deuda técnica: PartialEq en structs de contratos, docs, MSRV.

**Convención para prompts visuales de Godot/Redot:**
- Toda función que dibuja usa `_draw()` + `queue_redraw()` (no `CanvasItem.draw_*` fuera de `_draw`).
- Cada nodo nuevo creado por código se elimina en `_exit_tree()` o con `queue_free()`.
- Nodos de UI creados por código: `var n = NodeType.new(); add_child(n)` — no `@onready` a nodos del editor.
- Guard headless en animaciones y partículas: `if OS.has_feature("headless"): return`.
- Para tests headless: no llamar a `get_tree().create_timer()` — usar contadores de frame (`_ticks`).
- Los smoke tests deben verificar estado del bridge con aserciones explícitas y salir con `quit(0/1)`.

---

## 0. Registro de estado al inicio de PROMPTS6 (2026-08-14)

### Ya implementado

| Elemento | Estado |
|----------|--------|
| CI Rust: fmt, clippy, tests | ✅ 0 errores, 80 suites passing |
| IA: Chess (Minimax depth 3) | ✅ `chess_game/src/ai.rs` |
| IA: Checkers (heurística) | ✅ `checkers_game/src/ai.rs` |
| IA: Backgammon (heurística) | ✅ `backgammon_game/src/ai.rs` |
| IA: Shogi (Minimax depth 2) | ✅ `shogi_game/src/ai.rs` |
| IA: Xiangqi (Minimax depth 2) | ✅ `xiangqi_game/src/ai.rs` |
| ELO en Godot UI | ✅ `score_tracker.gd` |
| 5 temas visuales | ✅ `theme_manager.gd` |
| Animaciones selección/captura | ✅ `checkers_board.gd`, `chess_board.gd` |
| Tests headless Godot | ✅ 16 scripts en `godot_project/tests/` |
| `godot_api_surface` test | ✅ movido a `open_table_godot/tests/` |
| Shim Redot → 4.4 | ✅ `tools/redot_gdext_shim.sh` |

### Pendiente real

| Elemento | Dónde | Nota |
|----------|-------|------|
| PartialEq en structs de contratos | múltiples games | Necesario para tests más robustos |
| MSRV explícito en Cargo.toml | todos los crates | Antes de publicar |
| `cargo doc` sin warnings | todo el workspace | 0 warnings requeridos |
| Battleship 10×10 completo | `battleship_game/src/` | Solo 8×8 ahora |
| Ludo tablero estándar 52 casillas | `ludo_game/src/` | Solo 24 casillas ahora |
| Monopoly 40 casillas completo | `monopoly_game/src/` | Solo 16 casillas ahora |
| Mille Bornes meta 1000 km | `mille_bornes_game/src/` | Solo 200 km ahora |
| IA para Go | `go_game/src/` | Sin IA local actualmente |
| IA para Ludo | `ludo_game/src/` | Sin IA local actualmente |
| Plugin Android compilado | `platform_plugins/` | Código escrito, no compilado |

---

## 1. Deuda Técnica — PartialEq y Calidad de Contratos

---

**351.** Añadir `PartialEq` a todos los tipos de comando y evento exportados públicamente.
En cada game crate, encontrar todas las structs que derivan `GameCommand` o `GameEvent`
y añadir `PartialEq` al bloque `#[derive(...)]`. Lista de crates afectados:
`checkers_game`, `chess_game`, `chinese_checkers_game`, `backgammon_game`, `go_game`,
`ludo_game`, `mille_bornes_game`, `monopoly_game`, `shogi_game`, `uno_game`, `xiangqi_game`,
`crisis_game`.

Criterio de aceptación: `cargo test --workspace --exclude open_table_godot` pasa y
el test de `serialization_contract.rs` puede reescribirse para comparar valores (`assert_eq!(value, deserialized)`)
además de JSON. Actualizar `open_table_engine/tests/serialization_contract.rs` para que
`assert_roundtrip<T: Serialize + DeserializeOwned + PartialEq + Debug>` también afirme
`assert_eq!(value, deserialized, "El valor deserializado debe coincidir con el original")`.

---

**352.** Establecer MSRV explícito en todos los `Cargo.toml` del workspace.
Añadir `rust-version = "1.82"` (o la versión mínima real determinada con `cargo msrv find`)
en el campo `[package]` de cada crate del workspace. Actualizar el CI `test` job para
incluir el paso existente `cargo check --workspace --exclude open_table_godot --ignore-rust-version`
como verificación de que el código compila en la versión mínima.
Verificar que `deny.toml` no tenga restricciones que conflictúen con 1.82.

---

**353.** Reducir a 0 los warnings de `cargo doc`.
Ejecutar `cargo doc --workspace --no-deps 2>&1 | grep "warning:" | wc -l` y resolver
cada warning. Los más comunes:
- Links rotos: `[foo]` sin `[foo]: url` → reemplazar con texto plano o URL real.
- Tipos privados expuestos en doc pública: añadir `#[doc(hidden)]` o hacer público el tipo.
- `/// Safety:` en funciones `unsafe` faltante → añadir sección Safety.
Añadir en el CI `test` job el paso:
```yaml
- name: Check doc warnings
  run: cargo doc --workspace --no-deps --exclude open_table_godot 2>&1 | grep "warning:" | { grep . && exit 1 || exit 0; }
```

---

## 2. Completar Reglas Faltantes en Juegos

---

**354.** Completar **Battleship a 10×10** en `battleship_game/src/`.

El tablero actual es 8×8. Cambiar la constante `BOARD_SIZE` de `8` a `10` en
`battleship_game/src/board.rs`. Actualizar los barcos estándar de la Batalla Naval:
- Portaaviones: 5 casillas
- Acorazado: 4 casillas
- Crucero: 3 casillas
- Submarino: 3 casillas
- Destructor: 2 casillas

Actualizar `place_ship` para validar dentro del rango 10×10. Actualizar las letras de
columna en `battleship_board.gd` de A–H a A–J. Los tests existentes en
`battleship_game/tests/game_rules.rs` que usen coordenadas fijas deben seguir pasando
(usar posiciones dentro de 10×10). Añadir test `test_tablero_es_10x10` que verifica que
un disparo en `(9, 9)` es legal y en `(10, 0)` es error. Criterio: `cargo test -p battleship_game`.

---

**355.** Completar **Ludo a tablero estándar** (52 casillas en la ruta + 5 por brazo de llegada).

El ludo actual usa 24 casillas de ruta. Cambiar `BOARD_STEPS: usize = 52` en
`ludo_game/src/board.rs`. La ruta de cada jugador: sale de su zona de inicio, recorre
52 casillas en sentido horario y entra a su zona de meta (5 casillas adicionales,
pasos 52–56 en términos lógicos). Actualizar `next_step_for(player, from, die)` para
aplicar modulo correcto en la zona compartida y detectar entrada a zona de meta.
Actualizar `ludo_board.gd` para que `get_cell_position(step, player)` mapee
correctamente los 52+5 pasos al tablero visual 11×11.
Test: `test_ficha_recorre_tablero_completo_en_52_pasos`. Criterio: `cargo test -p ludo_game`.

---

**356.** Completar **Mille Bornes a 1000 km** (meta estándar del juego).

La implementación actual usa 200 km como objetivo. Cambiar `WIN_DISTANCE: u32 = 1000`
en `mille_bornes_game/src/rules.rs`. Actualizar la distribución de cartas de distancia:
añadir las cartas `Distance(100)` (12 copias) y `Distance(200)` (4 copias) al mazo
en `mille_bornes_game/src/deck.rs`. El mazo estándar completo es:
- 25 km × 10, 50 km × 10, 75 km × 10, 100 km × 12, 200 km × 4 (total 46 cartas de distancia)
- Hazard/Remedy/Safety: según distribución estándar (ya implementada).
Actualizar el smoke test `mille_bornes_smoke.gd` para que juegue 5 rondas y verifique
que `bridge.get_distance(1)` incrementa correctamente.
Test: `test_gana_con_1000km`. Criterio: `cargo test -p mille_bornes_game`.

---

**357.** Completar **Monopoly a 40 casillas** (tablero estándar).

El tablero actual tiene 16 casillas. Implementar las 40 casillas estándar en
`monopoly_game/src/board.rs`:
- 28 propiedades (22 calles + 4 estaciones + 2 suministros)
- GO, Cárcel (visita), Parking Gratuito, Ve a la Cárcel
- 6 casillas de Suerte/Arca Comunitaria (3 cada una)
- Impuesto sobre la Renta (200$), Impuesto de Lujo (100$)

Añadir `SpaceKind` con variantes: `Property`, `Railroad`, `Utility`, `Tax`, `Jail`,
`GoToJail`, `FreeParking`, `Go`, `Chance`, `CommunityChest`.
En `rules.rs`, implementar `apply_land_effect(space: SpaceKind, player, session)`.
Implementar 10 cartas de Suerte y 10 de Arca Comunitaria como variantes de enum.
Test: `test_jugador_cae_en_ve_a_la_carcel`. Criterio: `cargo test -p monopoly_game`.

---

## 3. IA para Juegos sin IA Local

---

**358.** Implementar **IA de territorio para Go** en `go_game/src/ai.rs`.

Go tiene un espacio de estados enorme; usar Minimax no es práctico. Implementar
una IA basada en **Monte Carlo Tree Search simplificado** con presupuesto fijo de
200 rollouts:

```rust
pub fn go_ai_pick_move(session: &Session, player: PlayerId) -> Option<PlaceStoneCommand>
```

Algoritmo:
1. Generar candidatos: todas las intersecciones vacías donde colocar una piedra sea legal
   (no repite estado Ko, no suicidio) usando `GoLegalMoveGenerator` (ya existe en
   `go_game/src/legal_moves.rs`).
2. Si no hay candidatos, devolver `None` (pase).
3. Para cada candidato, hacer 200/N rollouts de juego aleatorio (N = número de candidatos,
   mínimo 5 rollouts por candidato). En cada rollout: clonar sesión, hacer el movimiento,
   luego jugar movimientos aleatorios alternativos hasta fin de juego o 50 movimientos.
4. Puntuar según territorios al final del rollout usando el estimador de `score_estimator`
   ya implementado en `go_game/src/scoring.rs` (si no existe, crear función `count_territory`
   simple con flood-fill).
5. Elegir el candidato con mayor win-rate entre sus rollouts.

Exponer en `go_game/src/lib.rs`:
```rust
pub use ai::go_ai_pick_move;
```

Test: `test_go_ai_devuelve_movimiento_o_none_en_posicion_inicial`. Criterio: pasa en < 2 s
con tablero 9×9.

---

**359.** Implementar **IA para Ludo** en `ludo_game/src/ai.rs`.

Ludo tiene componente aleatoria (dado); usar heurística, no Minimax.

```rust
pub fn ludo_ai_pick_move(session: &Session, player: PlayerId) -> Option<MoveTokenCommand>
```

Estrategia:
1. Obtener el valor del dado actual desde `PendingDiceResource` (ya existe).
2. Generar los tokens que pueden moverse (`token_index` 0–3 del jugador).
3. Puntuar cada movimiento:
   - **+20** si saca una ficha de la base (steps 0 → 1).
   - **+15** si llega exactamente a la meta (steps == WIN_STEPS).
   - **+10** si captura una ficha rival (llega a casilla ocupada por rival que no es segura).
   - **-10** si se mueve a una casilla ocupada por 2 fichas rivales (inaccesible, movimiento ilegal).
   - **+5** si avanza la ficha más atrasada.
   - **+3 * pasos_avanzados**.
4. Si hay dados con valor 6, priorizar sacar fichas de base.
5. Elegir el token con mayor puntuación. En empate, el de menor `token_index`.

Exponer en `ludo_game/src/lib.rs`:
```rust
pub use ai::ludo_ai_pick_move;
```

Añadir `start_local_match_ludo_vs_ai(human: i64, ai: i64) -> bool` en el bridge Godot.
Tests: `test_ludo_ai_saca_ficha_con_seis` y `test_ludo_ai_captura_cuando_puede`.

---

**360.** Añadir tests de humo de IA en Godot headless para Go y Ludo.

Actualizar `godot_project/tests/ai_local_smoke.gd` para añadir dos secciones:

**Go (9×9):**
```gdscript
bridge.start_local_match_go_vs_ai(1, 2, 9)
for i in range(80):          # Go: hasta 80 frames
    bridge._process(0.016)
var ticks = bridge.session_tick_count()
assert(ticks > 5, "La IA de Go debe hacer al menos 5 movimientos")
```
Esperar hasta 80 frames (el MCTS es más lento que Minimax).

**Ludo:**
```gdscript
bridge.start_local_match_ludo_vs_ai(1, 2)
# Ludo requiere tiradas de dado antes de que la IA actúe
bridge.send_command_json(JSON.stringify({"type": "RollDiceCommand", "player": 1}))
for i in range(30):
    bridge._process(0.016)
var ticks = bridge.session_tick_count()
assert(ticks >= 1, "El bridge debe haber procesado al menos 1 tick")
```

Añadir ambas secciones al runner `tools/run_godot_tests.sh`. Timeout global del test: 30 s.
Criterio: exit code 0 headless.

---

## 4. Mejoras Visuales Específicas en Godot — Parte 2

Los siguientes prompts son específicos de GDScript/Redot. Cada prompt incluye el nodo
exacto que se modifica, el método exacto que se añade y cómo testear headless.

---

**361.** Añadir **animación de victoria con confeti** en `godot_project/game_over_overlay.gd`.

Al llamar `show_result(winner_id: int, is_draw: bool)`:

1. Si no es empate, instanciar 3 nodos `CPUParticles2D` posicionados en
   `Vector2(randi_range(50, get_viewport_rect().size.x - 50), -20)`.
   Configuración por nodo:
   ```gdscript
   var p := CPUParticles2D.new()
   p.amount = 40
   p.lifetime = 3.0
   p.explosiveness = 0.0        # continuo
   p.spread = 20.0
   p.direction = Vector2(0, 1)  # cae hacia abajo
   p.gravity = Vector2(0, 120)
   p.initial_velocity_min = 80.0
   p.initial_velocity_max = 200.0
   p.angular_velocity_min = -180.0
   p.angular_velocity_max = 180.0
   p.color = Color.from_hsv(randf(), 0.8, 1.0)
   p.one_shot = false
   add_child(p)
   ```
2. Guard headless: `if OS.has_feature("headless"): return` antes de crear partículas.
3. Liberar los nodos al ocultar el overlay: en `hide()`, iterar `get_children()` y llamar
   `queue_free()` en cada `CPUParticles2D`.
4. El test `hud_and_settings_smoke.gd` ya existe; añadir una verificación al final:
   `assert(overlay.visible == false, "overlay debe ocultarse al navegar al menú")`.

---

**362.** Añadir **animación de shake de tablero cuando hay jaque** en `chess_board.gd`.

Método `_play_check_shake()`:
```gdscript
func _play_check_shake() -> void:
    if OS.has_feature("headless"):
        return
    var original_pos := position
    var t := create_tween()
    t.tween_property(self, "position", original_pos + Vector2(6, 0), 0.05)
    t.tween_property(self, "position", original_pos - Vector2(6, 0), 0.05)
    t.tween_property(self, "position", original_pos + Vector2(4, 0), 0.04)
    t.tween_property(self, "position", original_pos - Vector2(4, 0), 0.04)
    t.tween_property(self, "position", original_pos, 0.03)
```
Llamar `_play_check_shake()` en el punto donde ya se llama `queue_redraw()` y
`check_king_pos != null` (prompt 335 ya implementó el indicador rojo; este añade el shake).
Guard: si `check_king_pos == null`, no llamar.
Criterio: no crasha en headless; el test `chess_smoke.gd` sigue pasando.

---

**363.** Añadir **indicador de turno animado** en la escena base de todos los tableros.

En `godot_project/turn_indicator.gd` (ya existe), añadir:

```gdscript
func set_active(is_active: bool) -> void:
    modulate = Color(1, 1, 1, 1.0) if is_active else Color(1, 1, 1, 0.4)
    if is_active and not OS.has_feature("headless"):
        var t := create_tween().set_loops()
        t.tween_property(self, "modulate:a", 0.7, 0.6)
        t.tween_property(self, "modulate:a", 1.0, 0.6)
        _active_tween = t
    elif _active_tween:
        _active_tween.kill()
        _active_tween = null

var _active_tween: Tween = null
```

Actualizar cada tablero que ya llama a `turn_indicator` para usar `set_active(true/false)`
en lugar de `modulate =`. Los tableros afectados son los que tienen `TurnIndicator` como
nodo hijo: `chess_board.gd`, `checkers_board.gd`, `backgammon_board.gd`, `go_board.gd`,
`shogi_board.gd`, `xiangqi_board.gd`.
Criterio: los smoke tests de cada tablero siguen pasando.

---

**364.** Añadir **visualización de piezas capturadas** en `shogi_board.gd`.

El Shogi permite reusar piezas capturadas ("mano"). Añadir dos `VBoxContainer`
(uno por jugador) en el lateral derecho del tablero programáticamente:

```gdscript
func _setup_hand_panels() -> void:
    _hand_p1 = VBoxContainer.new()
    _hand_p1.name = "HandP1"
    add_child(_hand_p1)
    _hand_p2 = VBoxContainer.new()
    _hand_p2.name = "HandP2"
    add_child(_hand_p2)

func _update_hand_display(player: int, pieces: Array) -> void:
    var panel := _hand_p1 if player == 1 else _hand_p2
    for child in panel.get_children():
        child.queue_free()
    for piece_name in pieces:
        var lbl := Label.new()
        lbl.text = piece_name  # nombre de pieza en idioma activo via tr()
        panel.add_child(lbl)
```

Llamar `_update_hand_display` al recibir `PieceDroppedEvent` o `PieceMovedEvent` con
campo `captured != null`. Parsear el JSON del evento para extraer `"hand_p1"` y `"hand_p2"`
del estado serializado (llamar `bridge.get_state_json()` si existe, o añadir
`bridge.get_hand_json(player: int) -> String` que retorna JSON del arreglo de mano).
Guard headless: omitir animaciones (`queue_redraw` sí, Tween no).
Criterio: `shogi_smoke.gd` sigue pasando; los paneles de mano no crashan.

---

**365.** Añadir **preview de movimiento al hacer hover** sobre piezas en `chess_board.gd`.

Al mover el mouse sobre una casilla (conectar `mouse_moved` o usar `_input` con
`InputEventMouseMotion`):
1. Obtener la posición de celda bajo el cursor con `_pixel_to_cell(event.position)`.
2. Si hay una pieza del jugador activo en esa casilla, dibujar puntos de destino
   válidos en `_draw()` con color `Color(0.5, 0.9, 0.5, 0.3)` y radio `CELL_SIZE * 0.15`.
3. Guardar `_hover_cell: Vector2i = Vector2i(-1, -1)` y `_hover_moves: Array[Vector2i] = []`.
4. Al hacer hover, llamar `bridge.get_legal_moves_for_cell(row, col) -> PackedInt32Array`
   (ya existe el método en el bridge, añadido en prompts 306–309) y convertir el resultado
   a posiciones de celda.
5. Guard: `if OS.has_feature("headless"): return` en `_input`.
6. Llamar `queue_redraw()` al cambiar `_hover_cell`.

El método `bridge.get_legal_moves_for_cell` existe en GDScript según el test
`test_get_legal_moves_bridge.gd`. Si la firma exacta es diferente, adaptar.
Criterio: `chess_smoke.gd` sigue pasando; no hay regresión de rendimiento notable.

---

**366.** Mejorar la **pantalla de carga** entre escenas en `scene_transition.gd`.

El scene manager ya tiene transiciones. Añadir una pantalla de carga con:
1. `ColorRect` de tamaño viewport con `Color(0.05, 0.05, 0.08)` (fondo oscuro).
2. `Label` centrado con el texto "Cargando…" (o `tr("LOADING")` si hay traducción).
3. Un `ProgressBar` (sin porcentaje real, solo animado) que cicla de 0 a 100 en 0.8 s
   usando `create_tween().set_loops().tween_property(bar, "value", 100, 0.8)`.
4. La pantalla se muestra en `_play_transition_out()` y se oculta en `_play_transition_in()`.
5. Si la carga real de la escena tarda < 0.3 s (la mayoría), la pantalla se muestra igual
   mínimo 0.3 s para evitar flash: `await get_tree().create_timer(0.3).timeout`.

Guard headless en el tween: el `ProgressBar` no anima en headless.
Criterio: navegar entre escenas no crasha en headless.

---

**367.** Añadir **soporte de localización para los nuevos temas visuales** en `theme_manager.gd`.

Los 5 temas (`wood`, `minimal`, `stone`, `night`, `jade`) tienen nombre en código.
Añadir las entradas en los archivos CSV de traducción en `godot_project/translations/`:

Para cada idioma (es, en, de, fr, it, ja, ko, pt, zh), añadir al CSV:
```
THEME_WOOD,"Madera","Wood","Holz","Bois","Legno","木材","나무","Madeira","木材"
THEME_MINIMAL,"Minimal","Minimal","Minimal","Minimal","Minimale","ミニマル","미니멀","Minimal","极简"
THEME_STONE,"Piedra Oscura","Dark Stone","Dunkler Stein","Pierre Sombre","Pietra Scura","ダークストーン","다크 스톤","Pedra Escura","暗石"
THEME_NIGHT,"Noche Azul","Blue Night","Blaue Nacht","Nuit Bleue","Notte Blu","青い夜","블루 나이트","Noite Azul","蓝夜"
THEME_JADE,"Jade Verde","Green Jade","Grüner Jade","Jade Vert","Giada Verde","緑の翡翠","그린 옥","Jade Verde","绿玉"
```

En `settings_menu.gd`, el `OptionButton` de temas usa `tr("THEME_WOOD")` etc. para mostrar
nombres localizados. Regenerar los archivos `.translation` ejecutando:
```
Redot --headless --path godot_project --export-pack dummy /tmp/dummy.pck
```
(o dejar que el CI de Godot los regenere). Criterio: `hud_and_settings_smoke.gd` pasa.

---

## 5. Tests de Integración de IA más Robustos

---

**368.** Añadir **tests de regresión de movimiento de IA** en Rust para Chess y Checkers.

En `chess_game/tests/game_rules.rs`, añadir:
```rust
#[test]
fn test_chess_ai_no_mueve_rey_a_casilla_atacada() {
    // Posición: Rey blanco en e1 (row 0, col 4), Torre negra en d8 (row 7, col 3).
    // La IA a depth=1 no debe mover el rey a d1 (row 0, col 3) porque estaría en jaque.
    let fen = "3r4/8/8/8/8/8/8/4K3 w - - 0 1";
    let mut session = new_chess_session(SessionId(1), 42, P1, P2);
    load_chess_position_from_fen(&mut session, fen).unwrap();
    let mv = chess_ai_pick_move(&session, P1, 1);
    if let Some(m) = mv {
        assert!(!(m.from == Position::new(0, 4) && m.to == Position::new(0, 3)),
            "La IA no debe mover el rey a casilla atacada por la torre");
    }
}
```

En `checkers_game/tests/game_rules.rs`, añadir:
```rust
#[test]
fn test_checkers_ai_captura_multiple_cuando_puede() {
    // Posición con captura doble disponible; la IA debe elegir la cadena más larga.
    // ...setup con piezas en posición de multicaptura...
    let mv = checkers_ai_pick_move(&session, P1);
    assert!(mv.is_some());
}
```

Criterio: `cargo test -p chess_game -p checkers_game`.

---

**369.** Añadir **smoke test de IA para Shogi y Xiangqi** en Godot headless.

Crear `godot_project/tests/ai_shogi_xiangqi_smoke.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
    var bridge := OpenTableBridge.new()

    # Shogi vs IA (depth 1 para velocidad)
    var ok_shogi := bridge.start_local_match_shogi_vs_ai(1, 2, 1)
    assert(ok_shogi, "Shogi vs IA debe inicializarse")
    for i in range(60):
        bridge._process(0.016)
    assert(bridge.session_tick_count() > 2,
        "La IA de Shogi debe haber realizado al menos un movimiento")

    # Xiangqi vs IA (depth 1)
    bridge = OpenTableBridge.new()
    var ok_xq := bridge.start_local_match_xiangqi_vs_ai(1, 2)
    assert(ok_xq, "Xiangqi vs IA debe inicializarse")
    for i in range(60):
        bridge._process(0.016)
    assert(bridge.session_tick_count() > 2,
        "La IA de Xiangqi debe haber realizado al menos un movimiento")

    quit(0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        quit(1)
```

Añadir al runner `tools/run_godot_tests.sh`. Timeout: 20 s. Criterio: exit code 0.

---

## 6. Preparación para Publicación en crates.io

---

**370.** Completar los metadatos de publicación en todos los `Cargo.toml`.

Para cada crate publicable (todos excepto `open_table_godot` y `open_table_macros` que
son internos), añadir o completar:

```toml
[package]
name = "checkers_game"          # ya existe
version = "0.1.0"               # ya existe
edition = "2021"                # ya existe
rust-version = "1.82"           # NUEVO
description = "..."             # ya existe en algunos; completar en los que falten
license = "MIT OR Apache-2.0"   # ya existe
repository = "https://github.com/joduranvillan/games_tables_sdk"   # NUEVO
keywords = ["game", "board-game", "checkers", "draughts", "rules"] # NUEVO (máx 5)
categories = ["game-engines", "games"]  # NUEVO
```

Crates a publicar: `open_table_core`, `open_table_engine`, `open_table_transport_tcp`,
`open_table_transport_websocket`, `open_table_transport_native_bridge`, `open_table_qr`,
`checkers_game`, `chess_game`, `chinese_checkers_game`, `backgammon_game`, `go_game`,
`ludo_game`, `mille_bornes_game`, `monopoly_game`, `shogi_game`, `uno_game`,
`xiangqi_game`, `crisis_game`.

Verificar con `cargo publish --dry-run -p <crate>` que no hay errores de publicación.

---

**371.** Actualizar `CHANGELOG.md` para la versión `0.2.0`.

Añadir la sección:
```markdown
## [0.2.0] — 2026-08-14

### Added
- IA local offline: Chess (Minimax depth 3), Checkers (heurística), Backgammon (heurística),
  Shogi (Minimax depth 2), Xiangqi (Minimax depth 2).
- 3 nuevos temas visuales: Piedra Oscura, Noche Azul, Jade Verde.
- Animaciones de selección (bounce), captura (partículas CPUParticles2D) y jaque (halo rojo pulsante).
- Overlay de fin de juego rediseñado con fade-in y animación de título.
- Selector de modo de juego (Hotseat/vs IA) en el Menú Principal con persistencia.
- ELO integrado en la UI: pestaña Estadísticas en Ajustes con ranking por juego.
- Tests TCP de reconexión y simulación de pérdida de paquetes.
- `godot_api_surface` test movido a `open_table_godot/tests/` (arquitectura más limpia).

### Fixed
- Shim Redot → Godot 4.4: `redot_gdext_shim.sh` ahora reporta 4.4.0 para Redot 26.x.
- `open_table_godot` removido de dev-deps de `open_table_engine` para limpiar el build sin Godot.
- Clippy: `clone_on_copy` y `for_kv_map` en módulos de IA de chess, backgammon, shogi, xiangqi.
- CI: eliminado fallback a Godot 4.3 (incompatible con el código que usa API 4.4+).

### Changed
- Tablero de Ajedrez: coordenadas a–h/1–8, borde, highlight último movimiento.
- Tablero de Go: puntos hoshi, animación de escala, contador de capturas.
- Menú Principal: fondo animado con shader, hover con escala en botones.
```

---

**372.** Añadir `deny.toml` correctamente configurado para publicación.

El `deny.toml` actual tiene configuración de licencias. Revisar y actualizar:
- `[licenses]` → `allow = ["MIT", "Apache-2.0", "ISC", "Unicode-DFS-2016"]`
- `[bans]` → añadir baneos de crates problemáticos comunes: `openssl` (preferir `rustls`),
  `chrono` con feature `clock` (prefijo determinista).
- `[advisories]` → `ignore = []` (vacío; no ignorar ninguna alerta de seguridad).
- Añadir en CI después de `Run cargo deny check` el paso de verificar que no hay
  crates duplicados con versiones conflictivas:
  ```yaml
  - name: Check duplicate dependencies
    run: cargo deny check duplicates
  ```

---

## 7. Plugin Android (Compilación)

---

**373.** Compilar y verificar el plugin Android `OpenTableNearbyPlugin.kt`.

El archivo `platform_plugins/android/OpenTableNearbyPlugin.kt` está escrito pero nunca
compilado. Para compilarlo:

1. Verificar que existe un `build.gradle.kts` en `platform_plugins/android/` con:
   ```kotlin
   plugins { id("com.android.library") }
   android {
       compileSdk = 34
       defaultConfig { minSdk = 21 }
   }
   dependencies {
       compileOnly("org.godotengine:godot:4.2.2.stable")
       implementation("com.google.android.gms:play-services-nearby:19.3.0")
   }
   ```
2. Si no existe el `build.gradle.kts`, crearlo con el contenido anterior.
3. Añadir un `settings.gradle.kts` mínimo:
   ```kotlin
   rootProject.name = "OpenTableNearbyPlugin"
   include(":android")
   ```
4. Verificar compilación con `cd platform_plugins && gradle :android:assembleRelease --no-daemon`.
5. Añadir en el CI un job `build-android-plugin`:
   ```yaml
   build-android-plugin:
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v7
       - uses: actions/setup-java@v4
         with: { java-version: '17', distribution: 'temurin' }
       - name: Build Android Plugin
         run: cd platform_plugins && gradle :android:assembleRelease --no-daemon
         working-directory: .
   ```

---

## 8. Cierre de PROMPTS6

---

**374.** Ejecutar la suite completa de verificación y documentar en `NEXT_STEPS.md`.

Comandos a ejecutar en orden:
1. `cargo fmt --all --check` → debe pasar limpio.
2. `cargo clippy --workspace --exclude open_table_godot -- -D warnings` → 0 errores.
3. `cargo test --workspace --exclude open_table_godot` → todos los tests pasan.
4. `cargo doc --workspace --no-deps --exclude open_table_godot 2>&1 | grep "warning:" | wc -l` → 0.
5. `tools/run_godot_tests.sh` → todos los scripts headless devuelven exit 0.
6. `cargo deny check` → sin vulnerabilidades ni licencias incompatibles.

Actualizar `NEXT_STEPS.md`:
- Marcar como ✅ los ítems de PROMPTS6 completados.
- Añadir la sección **"Para versión 1.0.0"** con checkboxes:
  - [ ] Publicación en crates.io de todos los crates públicos.
  - [ ] Plugin Android compilado y empaquetado como `.aar`.
  - [ ] Documentación en `docs.rs` validada.
  - [ ] Soporte para Godot 4.5 verificado con el shim actualizado.
  - [ ] Go: tablero 19×19 completo con scoring por área.
  - [ ] Monopoly: 40 casillas con casas y hoteles.

---

*Fin de PROMPTS6.md — 24 prompts (351–374).*

*Resumen por sección:*
- *0. Registro de estado: documentación al iniciar PROMPTS6*
- *1. Deuda técnica: prompts 351–353 (PartialEq, MSRV, cargo doc)*
- *2. Completar reglas: prompts 354–357 (Battleship 10×10, Ludo 52 casillas, Mille Bornes 1000 km, Monopoly 40 casillas)*
- *3. IA para Go y Ludo: prompts 358–360 (MCTS Go, heurística Ludo, smoke tests)*
- *4. Mejoras visuales Godot: prompts 361–367 (confeti, shake jaque, turno animado, mano Shogi, preview hover, carga, i18n temas)*
- *5. Tests integración IA: prompts 368–369 (regresión Rust, smoke Shogi/Xiangqi Godot)*
- *6. Publicación crates.io: prompts 370–372 (metadatos, CHANGELOG, deny.toml)*
- *7. Plugin Android: prompt 373*
- *8. Cierre: prompt 374*

*Total acumulado: 374 prompts (PROMPTS1: 1–40, PROMPTS2: 41–160, PROMPTS3: 161–300, PROMPTS4: 301–325, PROMPTS5: 326–350, PROMPTS6: 351–374).*
