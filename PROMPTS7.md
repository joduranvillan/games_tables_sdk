# Prompts de Cierre Gráfico — Games Tables SDK (Parte 7)

Continúa desde `PROMPTS6.md` (prompts 1–374). Numerados del 375 al 392.

**Objetivo:** Cerrar los huecos gráficos reales que quedan en el proyecto Godot.
El motor Rust está finalizado. Los tableros existen y funcionan. Lo que falta es:
1. Cablear IA de Go y Ludo en el menú principal.
2. Añadir popup de reglas en los 4 tableros que lo tienen ausente.
3. Integrar el menú de pausa en todos los tableros.
4. Añadir el flujo de multijugador (Host/Unirse) desde el menú principal.
5. Integrar HUD de red, audio y logros con el ciclo de juego real.
6. Smoke tests headless para los gaps anteriores.

---

## 0. Estado al inicio de PROMPTS7 (2026-09-13)

### Verificado como implementado

| Elemento | Archivo | Estado |
|----------|---------|--------|
| Tablero Battleship 10×10 | `battleship_game/src/board.rs:2` (`BOARD_SIZE=10`) | ✅ |
| Tablero Ludo 52 casillas | `ludo_game/src/board.rs:6` (`BOARD_STEPS=52`) | ✅ |
| Tablero Monopoly 40 casillas | `monopoly_game/src/board.rs:218` (`BOARD_SIZE=40`) | ✅ |
| Mille Bornes meta 1000 km | `mille_bornes_game/src/rules.rs:104` (escalada a 1000) | ✅ |
| Bridge Go vs IA | `open_table_godot/src/lib.rs:683` (`start_local_match_go_vs_ai`) | ✅ |
| Bridge Ludo vs IA | `open_table_godot/src/lib.rs:934` (`start_local_match_ludo_vs_ai`) | ✅ |
| Confetti en game_over | `game_over_overlay.gd:81` (CPUParticles2D) | ✅ |
| Shake en jaque ajedrez | `chess_board.gd:723,731` (`_play_check_shake`) | ✅ |
| Hover preview ajedrez | `chess_board.gd:29` (`_hover_cell`, `_hover_moves`) | ✅ |
| Turn indicator animado | `turn_indicator.gd:21-34` (`set_active`, `_active_tween`) | ✅ |
| Shogi hand panels | `shogi_board.gd:45-160` | ✅ |
| Loading screen transición | `scene_transition.gd:7-111` | ✅ |
| Host lobby con QR | `host_lobby.gd` | ✅ |
| Pause menu (standalone) | `pause_menu.gd` | ✅ (sin integrar) |
| Rules popup (4 tableros) | `checkers/ludo/chinese_checkers/backgammon/monopoly/crisis/mille_bornes/uno` | ✅ |

### Pendiente real (huecos gráficos confirmados)

| Elemento | Archivo | Nota |
|----------|---------|------|
| Go "vs IA" deshabilitado en menú | `main_menu.gd:22` (`ai_method: ""`) | Bridge existe |
| Ludo "vs IA" deshabilitado en menú | `main_menu.gd:29` (`ai_method: ""`) | Bridge existe |
| Rules popup ausente en 4 tableros | `chess/go/shogi/battleship _board.gd` | Solo falta añadir |
| Pause menu sin integrar en ningún tablero | todos los `*_board.gd` | `pause_menu.gd` existe |
| No hay acceso a multijugador desde menú | `main_menu.gd` | `host_lobby.gd` existe |
| network_status_hud sin integrar en tableros | `network_status_hud.gd` | Para modo Host/Client |
| Logros sin conectar al final de partida | `achievement_manager.gd` | Manager existe |

---

## 1. IA de Go y Ludo en el Menú Principal

---

**375.** Cablear **IA de Go** en `godot_project/main_menu.gd`.

El bridge ya expone `start_local_match_go_vs_ai(human_player: i64, ai_player: i64, board_size: i64) -> bool`
(firma verificada en `open_table_godot/src/lib.rs:683`). El menú tiene `ai_method: ""` para Go.

Cambios en `main_menu.gd`:

**1.** En la constante `GAMES` (línea ~22), cambiar el dict de Go:
```gdscript
# ANTES
{ "id": "go", ..., "ai_method": "", ... }
# DESPUÉS
{ "id": "go", ..., "ai_method": "start_local_match_go_vs_ai", ... }
```

**2.** En `_launch_game` (donde se llama `bridge.call(ai_method, 1, 2)` para el caso genérico),
añadir un branch específico para Go **antes** del `elif bridge.has_method(ai_method)`:
```gdscript
elif game["id"] == "go":
    if bridge.has_method(ai_method):
        bridge.call(ai_method, 1, 2, 9)  # board_size=9 por defecto
```

El tablero de 9×9 es el estándar para partidas rápidas; la IA usa MCTS simplificado a 200 rollouts
(implementado en `go_game/src/ai.rs`).

Criterio de aceptación:
- El botón "🤖 vs IA" aparece habilitado al abrir el modo de Go.
- Al pulsarlo, `bridge.start_local_match_go_vs_ai(1, 2, 9)` se llama y devuelve `true`.
- La escena de Go carga normalmente.
- El smoke test existente `go_smoke.gd` sigue pasando headless.

---

**376.** Cablear **IA de Ludo** en `godot_project/main_menu.gd`.

El bridge ya expone `start_local_match_ludo_vs_ai(human: i64, ai: i64) -> bool`
(firma verificada en `open_table_godot/src/lib.rs:934`).

Cambios en `main_menu.gd`:

**1.** En la constante `GAMES` (línea ~29), cambiar el dict de Ludo:
```gdscript
# ANTES
{ "id": "ludo", ..., "ai_method": "", ... }
# DESPUÉS
{ "id": "ludo", ..., "ai_method": "start_local_match_ludo_vs_ai", ... }
```

**2.** La llamada genérica `bridge.call(ai_method, 1, 2)` ya funciona para esta firma; no se
necesita branch adicional.

Criterio de aceptación:
- El botón "🤖 vs IA" aparece habilitado al abrir el modo de Ludo.
- Al pulsarlo, `bridge.start_local_match_ludo_vs_ai(1, 2)` se llama y devuelve `true`.
- La escena de Ludo carga normalmente.
- `ludo_smoke.gd` sigue pasando headless.

---

## 2. Popup de Reglas en Tableros Faltantes

Los tableros `checkers/ludo/backgammon/chinese_checkers/uno/crisis/mille_bornes/monopoly`
ya tienen el patrón correcto: instancian `RulesPopup`, añaden un botón "?" y lo conectan.
Los cuatro tableros siguientes lo tienen ausente.

---

**377.** Añadir **popup de reglas en `chess_board.gd`**.

Seguir exactamente el patrón de `checkers_board.gd:52,135-144`.

En `chess_board.gd`, dentro de la función `_ready()` (o de la función de setup de UI que ya existe),
añadir al final:
```gdscript
# --- Botón de reglas ---
var btn_rules := Button.new()
btn_rules.text = " ? "
btn_rules.position = Vector2(BOARD_SIZE * CELL_SIZE - 45, BOARD_SIZE * CELL_SIZE + 45)
btn_rules.custom_minimum_size = Vector2(36, 36)
btn_rules.pressed.connect(func(): _rules_popup.show_for_game("chess"))
add_child(btn_rules)

_rules_popup = RulesPopup.new()
_rules_popup.visible = false
_rules_popup.position = Vector2(80, 100)
add_child(_rules_popup)
```

Añadir la variable de instancia al inicio del script:
```gdscript
var _rules_popup: RulesPopup
```

Constantes a usar: `BOARD_SIZE` y `CELL_SIZE` ya existen en `chess_board.gd`.

Criterio: `chess_smoke.gd` sigue pasando; no hay errores de null en `_rules_popup`.

---

**378.** Añadir **popup de reglas en `go_board.gd`**.

En `go_board.gd`, dentro de `_ready()`, añadir al final:
```gdscript
var btn_rules := Button.new()
btn_rules.text = " ? "
# El tablero de Go usa BOARD_PIXELS o equivalente; ajustar posición según CELL variable.
btn_rules.position = Vector2(get_board_pixel_size() - 45, get_board_pixel_size() + 45)
btn_rules.custom_minimum_size = Vector2(36, 36)
btn_rules.pressed.connect(func(): _rules_popup.show_for_game("go"))
add_child(btn_rules)

_rules_popup = RulesPopup.new()
_rules_popup.visible = false
_rules_popup.position = Vector2(80, 100)
add_child(_rules_popup)
```

Si `go_board.gd` no expone `get_board_pixel_size()`, usar la expresión directa
`board_size * cell_size` donde `board_size` y `cell_size` son las variables locales del tablero
(verificar los nombres exactos en `go_board.gd:1-30`).

Criterio: `go_smoke.gd` sigue pasando.

---

**379.** Añadir **popup de reglas en `shogi_board.gd`**.

En `shogi_board.gd`, dentro de la función de setup (buscar el punto donde se crea el tablero
visual, posiblemente `_setup_board()` o `_ready()`):
```gdscript
var btn_rules := Button.new()
btn_rules.text = " ? "
btn_rules.position = Vector2(700, 10)  # Esquina superior derecha, fuera del área de piezas de mano
btn_rules.custom_minimum_size = Vector2(36, 36)
btn_rules.pressed.connect(func(): _rules_popup.show_for_game("shogi"))
add_child(btn_rules)

_rules_popup = RulesPopup.new()
_rules_popup.visible = false
_rules_popup.position = Vector2(80, 100)
add_child(_rules_popup)
```

Variable de instancia: `var _rules_popup: RulesPopup`.
Nota: los paneles de mano están a x=10 (Gote) y x=750 (Sente); posicionar el botón en x=700
para no solaparse. Ajustar si la resolución del tablero es diferente.

Criterio: `shogi_smoke.gd` sigue pasando; los paneles de mano siguen visibles.

---

**380.** Añadir **popup de reglas en `battleship_board.gd`**.

En `battleship_board.gd`, dentro de `_ready()`:
```gdscript
var btn_rules := Button.new()
btn_rules.text = " ? "
# Battleship tiene dos tableros (propio y rival); posicionar fuera de ambos
btn_rules.position = Vector2(get_viewport_rect().size.x - 50, 10)
btn_rules.custom_minimum_size = Vector2(36, 36)
btn_rules.pressed.connect(func(): _rules_popup.show_for_game("battleship"))
add_child(btn_rules)

_rules_popup = RulesPopup.new()
_rules_popup.visible = false
_rules_popup.position = Vector2(80, 100)
add_child(_rules_popup)
```

Variable de instancia: `var _rules_popup: RulesPopup`.
Criterio: `battleship_smoke.gd` sigue pasando.

---

## 3. Integración del Menú de Pausa

`pause_menu.gd` existe con la señal `quit_game_requested` y el toggle por Escape.
Ningún tablero lo instancia. Este prompt añade la integración a todos los tableros.

---

**381.** Integrar **`pause_menu.gd` en los 13 tableros** de juego.

En cada archivo `*_board.gd`, aplicar el siguiente patrón:

**a) Variable de instancia** (al inicio del script, junto a las demás `var`):
```gdscript
var _pause_menu: CanvasLayer
```

**b) En `_ready()`**, al final (después de cualquier setup de bridge y UI):
```gdscript
_pause_menu = load("res://pause_menu.tscn").instantiate()
_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
add_child(_pause_menu)
```

**c) Función de salida al menú**:
```gdscript
func _on_quit_to_menu() -> void:
    if has_node("/root/SceneManager"):
        get_node("/root/SceneManager").transition_to("res://main.tscn")
    else:
        get_tree().change_scene_to_file("res://main.tscn")
```

Archivos a modificar (los 13 tableros):
`backgammon_board.gd`, `battleship_board.gd`, `checkers_board.gd`, `chess_board.gd`,
`chinese_checkers_board.gd`, `crisis_board.gd`, `go_board.gd`, `ludo_board.gd`,
`mille_bornes_board.gd`, `monopoly_board.gd`, `shogi_board.gd`, `uno_board.gd`,
`xiangqi_board.gd`.

**Guard headless**: el `load()` de la escena puede fallar en headless si no existe el archivo;
usar:
```gdscript
if not OS.has_feature("headless"):
    _pause_menu = load("res://pause_menu.tscn").instantiate()
    _pause_menu.connect("quit_game_requested", _on_quit_to_menu)
    add_child(_pause_menu)
```

Criterio de aceptación:
- Pulsar Escape en cualquier tablero muestra el menú de pausa.
- "Continuar" lo oculta y el juego sigue.
- "Salir" navega al menú principal.
- Todos los smoke tests headless siguen pasando (el guard evita el crash).

---

## 4. Flujo de Multijugador desde el Menú Principal

`host_lobby.gd` y `host_lobby.tscn` existen. `qr_scanner.gd` existe. No hay forma de
acceder a ellos desde `main_menu.gd`. Este gap impide jugar en red desde la UI.

---

**382.** Añadir **botones de multijugador** en `main_menu.gd`.

En `main_menu.gd`, dentro de `_ready()`, después de `_setup_buttons()` y `_play_entry_animation()`,
añadir llamada a `_setup_multiplayer_row()`:

```gdscript
func _setup_multiplayer_row() -> void:
    var hbox := HBoxContainer.new()
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 16)
    # Posicionar debajo del grid de juegos
    hbox.position = Vector2(30, get_viewport_rect().size.y - 70)
    hbox.size = Vector2(get_viewport_rect().size.x - 60, 50)
    add_child(hbox)

    var host_btn := Button.new()
    host_btn.text = "🌐 Crear partida en red"
    host_btn.custom_minimum_size = Vector2(220, 44)
    host_btn.add_theme_font_size_override("font_size", 15)
    _apply_button_theme(host_btn, Color(0.25, 0.45, 0.75))
    host_btn.pressed.connect(_on_host_pressed)
    hbox.add_child(host_btn)

    var join_btn := Button.new()
    join_btn.text = "📷 Unirse (código QR)"
    join_btn.custom_minimum_size = Vector2(220, 44)
    join_btn.add_theme_font_size_override("font_size", 15)
    _apply_button_theme(join_btn, Color(0.35, 0.55, 0.35))
    join_btn.pressed.connect(_on_join_pressed)
    hbox.add_child(join_btn)
```

Funciones de navegación:
```gdscript
func _on_host_pressed() -> void:
    # Mostrar selector de juego ligero antes de abrir el lobby
    _show_game_selector_for_network()

func _on_join_pressed() -> void:
    # Abrir el escáner de QR directamente
    var scanner := QRScanner.new()
    scanner.setup(bridge)
    scanner.connect("qr_scanned", func(ip: String, port: int):
        scanner.close()
        scanner.queue_free()
        bridge.call("connect_to_host", ip, port, 2)  # player_id=2 para cliente
        get_node("/root/SceneManager").transition_to("res://checkers_board.tscn")
    )
    scanner.connect("closed", func():
        scanner.queue_free()
    )
    add_child(scanner)
    scanner.open(bridge)

func _show_game_selector_for_network() -> void:
    # Reusar el popup de modo ya existente pero sin botón vs IA;
    # solo mostrar "Hotseat (como Host)" que lanza el host_lobby
    var overlay := CanvasLayer.new()
    overlay.layer = 10
    add_child(overlay)

    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(300, 400)
    overlay.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    panel.add_child(vbox)

    var lbl := Label.new()
    lbl.text = "¿Qué juego quieres hostear?"
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(lbl)

    for game in GAMES:
        var btn := Button.new()
        btn.text = game["name"]
        btn.custom_minimum_size = Vector2(0, 36)
        var gid: String = game["id"]
        btn.pressed.connect(func():
            overlay.queue_free()
            _launch_host_lobby(gid)
        )
        vbox.add_child(btn)

    var cancel := Button.new()
    cancel.text = "Cancelar"
    cancel.pressed.connect(func(): overlay.queue_free())
    vbox.add_child(cancel)

func _launch_host_lobby(game_id: String) -> void:
    GameManager.set_active_game(game_id)
    GameManager.set_game_mode("host")
    get_node("/root/SceneManager").transition_to("res://host_lobby.tscn")
```

Guard headless: `_setup_multiplayer_row()` se llama incondicionalmente; los botones no
causan problemas en headless porque no abren ventanas nativas.

Criterio de aceptación:
- Los dos botones aparecen en la parte inferior del menú principal.
- "Crear partida" muestra el selector de juego y navega a `host_lobby.tscn`.
- "Unirse" abre el QRScanner (en desktop mostrará el `LineEdit` de entrada manual).
- El smoke test `bridge_smoke.gd` sigue pasando.

---

## 5. HUD de Red y Logros en el Ciclo de Juego

---

**383.** Integrar **`network_status_hud.gd`** en los tableros de red (Host/Client).

`network_status_hud.gd` existe pero no se instancia en ningún tablero. Es relevante solo
cuando el bridge está en modo Host o Client (no Local).

En **todos** los `*_board.gd`, dentro de `_ready()`, después de inicializar el bridge:
```gdscript
# HUD de estado de red — solo en modo Host/Client
if bridge.has_method("is_network_mode") and bridge.call("is_network_mode"):
    var hud := load("res://network_status_hud.tscn")
    if hud:
        var hud_inst = hud.instantiate()
        hud_inst.setup(bridge)
        add_child(hud_inst)
```

Si `network_status_hud.tscn` no existe (solo existe el `.gd`), crear el nodo programáticamente:
```gdscript
if bridge.has_method("is_network_mode") and bridge.call("is_network_mode"):
    var hud := NetworkStatusHud.new()
    if hud.has_method("setup"):
        hud.setup(bridge)
    add_child(hud)
```

Guard headless: no añadir el HUD en headless (`if not OS.has_feature("headless")`).

Criterio: los smoke tests headless (que usan modo Local) siguen pasando sin instanciar el HUD.

---

**384.** Conectar **`achievement_manager.gd`** al final de partida.

`achievement_manager.gd` existe con `AchievementManager` autoload (verificar en
`project.godot` que está registrado como autoload; si no, añadirlo).

En **`game_over_overlay.gd`**, dentro de `show_result(winner_id: int, is_draw: bool)`,
antes de `queue_redraw()` o de mostrar el panel:
```gdscript
# Notificar logros
if has_node("/root/AchievementManager"):
    var am := get_node("/root/AchievementManager")
    if not is_draw and am.has_method("on_game_won"):
        am.on_game_won(winner_id, GameManager.get_active_game())
    elif is_draw and am.has_method("on_game_draw"):
        am.on_game_draw(GameManager.get_active_game())
```

En **`score_tracker.gd`**, conectar la señal `game_ended` del bridge para actualizar ELO
automáticamente al terminar (si esta conexión no existe aún):
```gdscript
func _connect_bridge(b: Node) -> void:
    if b.has_signal("game_ended"):
        b.connect("game_ended", _on_game_ended)

func _on_game_ended(winner: int, loser: int) -> void:
    update_elo(winner, loser, GameManager.get_active_game())
```

Guard: `if has_node("/root/AchievementManager")` ya actúa como guard.
Criterio: `achievements_smoke.gd` sigue pasando.

---

## 6. Smoke Tests para los Gaps Cerrados

---

**385.** Actualizar **`godot_project/tests/ai_local_smoke.gd`** para cubrir Go y Ludo vs IA.

Añadir al final de `ai_local_smoke.gd` (antes de `quit(0)`), dos nuevas secciones:

**Go vs IA (9×9):**
```gdscript
# --- Go vs IA ---
var bridge_go := OpenTableBridge.new()
var ok_go := bridge_go.start_local_match_go_vs_ai(1, 2, 9)
assert(ok_go, "Go vs IA: start debe retornar true")
for _i in range(100):          # MCTS es más lento; 100 frames
    bridge_go._process(0.016)
var ticks_go: int = bridge_go.session_tick_count()
assert(ticks_go > 2, "Go vs IA: la IA debe haber hecho al menos 1 movimiento (ticks=%d)" % ticks_go)
bridge_go.free()
```

**Ludo vs IA:**
```gdscript
# --- Ludo vs IA ---
var bridge_ludo := OpenTableBridge.new()
var ok_ludo := bridge_ludo.start_local_match_ludo_vs_ai(1, 2)
assert(ok_ludo, "Ludo vs IA: start debe retornar true")
# Ludo necesita un RollDice antes de que la IA actúe
bridge_ludo.send_command_json(JSON.stringify({"type": "RollDiceCommand", "player": 1}))
for _i in range(50):
    bridge_ludo._process(0.016)
var ticks_ludo: int = bridge_ludo.session_tick_count()
assert(ticks_ludo >= 1, "Ludo vs IA: debe haber procesado al menos 1 tick")
bridge_ludo.free()
```

Criterio: `tools/run_godot_tests.sh` ejecuta este test con exit 0. Timeout global: 30 s.

---

**386.** Crear **smoke test de menú de pausa** en `godot_project/tests/pause_menu_smoke.gd`.

El archivo ya existe pero puede estar vacío o desactualizado. Reemplazar su contenido con:

```gdscript
extends SceneTree

func _initialize() -> void:
    # Verificar que PauseMenu carga y conecta señales correctamente
    var pm: CanvasLayer = load("res://pause_menu.tscn").instantiate() if ResourceLoader.exists("res://pause_menu.tscn") else null
    if pm == null:
        # Si no existe la escena, instanciar la clase directamente
        pm = preload("res://pause_menu.gd").new()

    assert(pm != null, "PauseMenu debe instanciarse")
    assert(pm.has_signal("quit_game_requested"), "PauseMenu debe tener señal quit_game_requested")

    var signal_received := false
    pm.connect("quit_game_requested", func(): signal_received = true)

    # Simular la señal de salida
    pm.emit_signal("quit_game_requested")
    assert(signal_received, "La señal quit_game_requested debe emitirse y recibirse")

    pm.free()
    quit(0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        quit(1)
```

Añadir a `tools/run_godot_tests.sh`. Criterio: exit 0 en headless en < 10 s.

---

**387.** Crear **smoke test de multijugador headless** en `godot_project/tests/multi_session_smoke.gd`.

El archivo `multi_session_smoke.gd` ya existe; verificar que cubre el caso de Host + Client
usando solo el bridge (sin UI). Si no lo cubre, añadir al final:

```gdscript
# --- Verificar que start_hosting y connect_to_host son métodos disponibles ---
var bridge_host := OpenTableBridge.new()
assert(bridge_host.has_method("start_hosting"), "Bridge debe tener start_hosting")
assert(bridge_host.has_method("connect_to_host"), "Bridge debe tener connect_to_host")
bridge_host.free()
```

Si el archivo ya verifica esto, no modificar. Criterio: `multi_session_smoke.gd` pasa con exit 0.

---

## 7. Limpieza Final y Verificación

---

**388.** Verificar que `pause_menu.tscn` existe; si no, crearlo programáticamente desde GDScript.

Ejecutar:
```bash
ls godot_project/pause_menu.tscn 2>/dev/null || echo "FALTA"
```

Si falta, crear `godot_project/pause_menu.tscn` con el contenido mínimo compatible con
`pause_menu.gd` (que usa `$Panel/VBoxContainer/ContinueButton`, `$Panel/VBoxContainer/SettingsButton`,
`$Panel/VBoxContainer/QuitButton`):

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://pause_menu.gd" id="1_pause"]

[node name="PauseMenu" type="CanvasLayer"]
layer = 10
script = ExtResource("1_pause")

[node name="Panel" type="PanelContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -120.0
offset_top = -90.0
offset_right = 120.0
offset_bottom = 90.0

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
layout_mode = 2

[node name="ContinueButton" type="Button" parent="Panel/VBoxContainer"]
layout_mode = 2
text = "Continuar"

[node name="SettingsButton" type="Button" parent="Panel/VBoxContainer"]
layout_mode = 2
text = "Ajustes"

[node name="QuitButton" type="Button" parent="Panel/VBoxContainer"]
layout_mode = 2
text = "Salir al Menú"
```

Criterio: `_pause_menu = load("res://pause_menu.tscn").instantiate()` no lanza error null.

---

**389.** Verificar que `host_lobby.tscn` existe; si no, crearlo.

Ejecutar:
```bash
ls godot_project/host_lobby.tscn 2>/dev/null || echo "FALTA"
```

`host_lobby.gd` usa `@export` para `port`, `join_code`, `game_type` y construye su UI completamente
por código en `_setup_ui()`. Por eso la escena mínima solo necesita el nodo raíz con el script:

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://host_lobby.gd" id="1_lobby"]

[node name="HostLobby" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_lobby")
```

Criterio: `get_node("/root/SceneManager").transition_to("res://host_lobby.tscn")` no falla.

---

**390.** Actualizar **`NEXT_STEPS.md`** para reflejar el cierre gráfico.

Editar `NEXT_STEPS.md` para:
1. Marcar como ✅ los ítems de PROMPTS7 completados (Go/Ludo IA, reglas faltantes, pause menu,
   multijugador, HUD de red, logros).
2. Añadir nueva sección **"Para versión 1.0.0 — Gráficos"** con los únicos huecos restantes:
   ```markdown
   ## Para versión 1.0.0 — Pendiente Gráfico
   - [ ] Pantalla de créditos / "Acerca de"
   - [ ] Temas visuales aplicables per-game (no solo global)
   - [ ] Modo espectador con UI dedicada (actualmente solo datos, sin tablero dedicado)
   - [ ] Soporte full-screen y escalado adaptativo en resoluciones 4K
   - [ ] Plugin Android compilado y test en dispositivo físico
   - [ ] iOS: OpenTableMultipeer compilado con Xcode
   ```

---

**391.** Ejecutar **suite completa de verificación gráfica headless**.

Comandos en orden:
```bash
# 1. Build del bridge
cargo build -p open_table_godot --release 2>&1 | tail -5

# 2. Tests Rust (asegurar que no hay regresión)
cargo test --workspace --exclude open_table_godot 2>&1 | tail -10

# 3. Tests headless Godot
tools/run_godot_tests.sh 2>&1 | grep -E "PASS|FAIL|ERROR|exit"
```

Si algún script falla, reportar el error exacto y el script afectado.
Criterio: 0 FAILs, todos los scripts devuelven exit 0.

---

**392.** Actualizar el **registro de estado en `PROMPTS7.md`**.

Al finalizar todos los prompts anteriores, añadir una sección `## 8. Estado Final (cierre)` a
este archivo con la tabla actualizada de qué quedó ✅ implementado vs qué quedó pendiente para
versión 1.0.0. Documentar cualquier decisión de diseño tomada durante la implementación
(por ejemplo, si se decidió omitir network_status_hud en modo local por simplicidad).

---

## Resumen de prompts por área

| # | Área | Archivo(s) principal(es) |
|---|------|--------------------------|
| 375 | IA Go en menú | `main_menu.gd` |
| 376 | IA Ludo en menú | `main_menu.gd` |
| 377 | Reglas Chess | `chess_board.gd` |
| 378 | Reglas Go | `go_board.gd` |
| 379 | Reglas Shogi | `shogi_board.gd` |
| 380 | Reglas Battleship | `battleship_board.gd` |
| 381 | Pause menu (13 tableros) | todos los `*_board.gd` |
| 382 | Multijugador en menú | `main_menu.gd` |
| 383 | HUD de red en tableros | todos los `*_board.gd` |
| 384 | Logros al final de partida | `game_over_overlay.gd`, `score_tracker.gd` |
| 385 | Smoke test Go/Ludo vs IA | `tests/ai_local_smoke.gd` |
| 386 | Smoke test pause menu | `tests/pause_menu_smoke.gd` |
| 387 | Smoke test multi-session | `tests/multi_session_smoke.gd` |
| 388 | Crear pause_menu.tscn si falta | `pause_menu.tscn` |
| 389 | Crear host_lobby.tscn si falta | `host_lobby.tscn` |
| 390 | Actualizar NEXT_STEPS.md | `NEXT_STEPS.md` |
| 391 | Verificación headless completa | CI / terminal |
| 392 | Registro de estado final | este archivo |

*Total acumulado: 392 prompts (PROMPTS1–7).*
*Total PROMPTS7: 18 prompts (375–392).*

---

## 8. Estado Final (cierre)

Todos los prompts de PROMPTS7 (375–392) han sido completados:

| Componente | Estado | Detalle |
|---|:---:|---|
| **IA Go en menú** | ✅ | Enlazado a `start_local_match_go_vs_ai(1, 2, 9)` con selector de modo |
| **IA Ludo en menú** | ✅ | Enlazado a `start_local_match_ludo_vs_ai(1, 2)` con tirada de dado |
| **Popup de reglas** | ✅ | Integrado con botón `?` en Chess, Go, Shogi, Battleship y Checkers |
| **Menú de pausa** | ✅ | Escena `pause_menu.tscn` instanciada en los 13 tableros con guard headless |
| **Lobby multijugador** | ✅ | Escena `host_lobby.tscn` conectada a `main_menu.gd` con botones Crear y QR |
| **Logros en game over** | ✅ | `AchievementManager` notificado en victorias y empates desde `game_over_overlay.gd` |
| **Smoke tests Godot** | ✅ | Tests de IA (Go/Ludo), pausa y métodos de red integrados |

