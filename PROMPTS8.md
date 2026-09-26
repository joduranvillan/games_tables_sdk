# Prompts de Cierre v1.0.0 — Games Tables SDK (Parte 8)

Continúa desde `PROMPTS7.md` (prompts 1–392). Numerados del 393 al 412.

**Objetivo:** Cerrar los huecos reales detectados en la auditoría de PROMPTS7 y completar los
requisitos para publicación en crates.io y versión 1.0.0.

---

## 0. Estado al inicio de PROMPTS8 (2026-09-25)

### Verificado como implementado (PROMPTS7 auditado)

| Elemento | Archivo | Estado |
|----------|---------|--------|
| IA Go/Ludo en menú | `main_menu.gd:22,29` | ✅ |
| Rules popup Chess/Go/Shogi/Battleship | `*_board.gd` | ✅ |
| Pause menu (13 tableros) | todos los `*_board.gd` | ✅ |
| Fila multijugador en menú | `main_menu.gd:587` | ✅ |
| Logros en game_over_overlay | `game_over_overlay.gd:62-67` | ✅ |
| Smoke tests IA Go/Ludo, pause, multi | `tests/` | ✅ |
| `pause_menu.tscn`, `host_lobby.tscn` | godot_project/ | ✅ |
| Tamaños de tablero en Rust | battleship(10), ludo(52), mille(1000km), monopoly(40) | ✅ |

### Pendiente real (huecos confirmados en auditoría)

| Elemento | Archivo | Nota |
|----------|---------|------|
| `network_status_hud` sin integrar | todos los `*_board.gd` | Prompt 383 declarado ✅ pero no ejecutado |
| `score_tracker._connect_bridge` | `score_tracker.gd` | Usa `game_over`, no `game_ended`; `_connect_bridge` ausente |
| Tabla de juegos en NEXT_STEPS.md | `NEXT_STEPS.md` | Battleship/Ludo/Mille/Monopoly siguen como ⚠️ en la tabla |
| Pantalla de créditos/"Acerca de" | nueva escena | Para v1.0.0 |
| Temas visuales per-game | `theme_manager.gd` | Global solamente ahora |
| UI de espectador dedicada | nueva escena | Datos existen, UI no |
| Fullscreen + escalado 4K | `project.godot` / `settings_menu.gd` | No configurado |
| 0 warnings Clippy | workspace Rust | Para crates.io |
| Versión semántica 0.1.0 | todos los `Cargo.toml` | Para crates.io |
| `cargo doc` sin errores | workspace Rust | Para docs.rs |

---

## 1. Huecos reales de PROMPTS7 (Retrabajo)

---

**393.** Implementar **`network_status_hud`** en todos los tableros (prompt 383 pendiente real).

El prompt 383 fue declarado ✅ pero la auditoría confirma 0 ocurrencias de `is_network_mode`
en cualquier `*_board.gd`. Ejecutar ahora.

En **cada uno de los 13 tableros** (`backgammon_board.gd`, `battleship_board.gd`,
`checkers_board.gd`, `chess_board.gd`, `chinese_checkers_board.gd`, `crisis_board.gd`,
`go_board.gd`, `ludo_board.gd`, `mille_bornes_board.gd`, `monopoly_board.gd`,
`shogi_board.gd`, `uno_board.gd`, `xiangqi_board.gd`), dentro de `_ready()`, tras
la inicialización del bridge:

```gdscript
# HUD de red — solo en modo Host/Client, nunca en headless
if not OS.has_feature("headless"):
    if bridge.has_method("is_network_mode") and bridge.call("is_network_mode"):
        var hud_script := load("res://network_status_hud.gd")
        if hud_script:
            var hud: Node = hud_script.new()
            if hud.has_method("setup"):
                hud.setup(bridge)
            add_child(hud)
```

Nota: usar `load("res://network_status_hud.gd").new()` en lugar de `.tscn` porque
`network_status_hud.tscn` no existe (solo el `.gd`); el script construye su UI por código.

Criterio de aceptación:
- Todos los smoke tests headless siguen pasando (el guard `OS.has_feature("headless")`
  previene la instanciación en tests).
- `grep -c "is_network_mode" godot_project/*_board.gd` devuelve 13 líneas con 1+.

---

**394.** Corregir la **tabla de juegos en `NEXT_STEPS.md`** para reflejar el estado real.

La tabla de la sección 1 muestra Battleship, Ludo, Mille Bornes y Monopoly como ⚠️ cuando
el código ya tiene los valores correctos (verificado: `battleship_game/src/board.rs:2`
`BOARD_SIZE=10`, `ludo_game/src/board.rs:6` `BOARD_STEPS=52`, `mille_bornes_game/src/rules.rs:104`
`target_distance=1000`, `monopoly_game/src/board.rs:218` `BOARD_SIZE=40`).

Cambios en `NEXT_STEPS.md`, sección 1, columna "Reglas Completas":

```markdown
# ANTES
| **Batalla Naval** | ✅ | ⚠️ (tablero 8x8) | ...
| **Ludo** | ✅ | ⚠️ (24 casillas) | ...
| **Mille Bornes** | ✅ | ⚠️ (meta 200) | ...
| **Monopoly** | ✅ | ⚠️ (16 casillas) | ...

# DESPUÉS
| **Batalla Naval** | ✅ | ✅ (tablero 10×10) | ...
| **Ludo** | ✅ | ✅ (52 casillas, regla de 6) | ...
| **Mille Bornes** | ✅ | ✅ (meta 1000 km, extensión de viaje) | ...
| **Monopoly** | ✅ | ✅ (40 casillas estándar) | ...
```

También añadir a la sección 3 los tests que faltan en la lista:
```markdown
- `ai_local_smoke.gd`: ✅ IA local para damas, ajedrez, **Go y Ludo** vía GDExtension.
- `pause_menu_smoke.gd`: ✅ Verificación de señales del menú de pausa.
- `multi_session_smoke.gd`: ✅ Métodos de hosting y conexión de red en bridge.
```

Criterio: la tabla en `NEXT_STEPS.md` refleja el estado real del código.

---

**395.** Completar **`score_tracker.gd`** con conexión a señal `game_ended`.

El prompt 384 pedía que `score_tracker.gd` conectara la señal `game_ended` del bridge.
`score_tracker.gd` actualmente conecta `game_over` (línea 38). El bridge emite ambas señales
o solo `game_over`; verificar en `open_table_godot/src/lib.rs` qué señales emite.

**Paso 1**: verificar señales del bridge:
```bash
grep -n "emit_signal\|#\[signal\]" open_table_godot/src/lib.rs | grep -i "game"
```

**Paso 2**: Si el bridge emite `game_ended(winner: int, loser: int)` (distinto de `game_over`),
añadir en `score_tracker.gd`, dentro de `bind_bridge(p_bridge: Node)`:
```gdscript
if p_bridge.has_signal("game_ended"):
    if not p_bridge.is_connected("game_ended", _on_game_ended):
        p_bridge.connect("game_ended", _on_game_ended)

func _on_game_ended(winner: int, loser: int) -> void:
    var game_type: String = GameManager.get_active_game() if has_node("/root/GameManager") else "unknown"
    update_elo(winner, loser, game_type)

func update_elo(winner: int, loser: int, game_type: String) -> void:
    # Usar lógica ELO existente del archivo (ya tiene record_match / get_elo)
    record_match(str(winner), game_type, true)
    record_match(str(loser), game_type, false)
```

Si el bridge NO emite `game_ended`, documentar eso en `NEXT_STEPS.md` sección 8 y marcar
este ítem como N/A con justificación.

Criterio: `hud_and_settings_smoke.gd` sigue pasando; no hay errores de señal en headless.

---

## 2. Funcionalidades para v1.0.0

---

**396.** Crear **pantalla de créditos / "Acerca de"** en Godot.

Crear `godot_project/credits_screen.gd` y `godot_project/credits_screen.tscn`.

`credits_screen.gd`:
```gdscript
extends Control

const CREDITS_TEXT := """
OpenTable SDK — Games Tables SDK
Versión 0.1.0 (2026)

Motor de juego: Rust + GDExtension
UI: Godot 4 / Redot 4.5

Juegos incluidos:
  Ajedrez, Damas, Go, Shogi, Xiangqi, Backgammon,
  Batalla Naval, Ludo, Mille Bornes, Monopoly,
  Uno, Crisis/TEG, Damas Chinas

Licencia: MIT
"""

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 20)
    add_child(vbox)

    var lbl := RichTextLabel.new()
    lbl.bbcode_enabled = true
    lbl.text = CREDITS_TEXT
    lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(lbl)

    var back := Button.new()
    back.text = "← Volver al Menú"
    back.custom_minimum_size = Vector2(200, 44)
    back.pressed.connect(_on_back_pressed)
    vbox.add_child(back)

func _on_back_pressed() -> void:
    if has_node("/root/SceneManager"):
        get_node("/root/SceneManager").transition_to("res://main.tscn")
    else:
        get_tree().change_scene_to_file("res://main.tscn")
```

Escena mínima `credits_screen.tscn`:
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://credits_screen.gd" id="1_credits"]
[node name="CreditsScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_credits")
```

En `main_menu.gd`, añadir botón "Acerca de" en `_setup_multiplayer_row()` o en un
tercer `HBoxContainer` bajo los botones de multijugador:
```gdscript
var about_btn := Button.new()
about_btn.text = "ℹ️ Acerca de"
about_btn.custom_minimum_size = Vector2(160, 44)
about_btn.pressed.connect(func():
    get_node("/root/SceneManager").transition_to("res://credits_screen.tscn")
)
hbox.add_child(about_btn)
```

Criterio: el botón navega a la pantalla de créditos; "Volver" regresa al menú. `bridge_smoke.gd` sigue pasando.

---

**397.** Añadir **temas visuales per-game** en `theme_manager.gd`.

`theme_manager.gd` actualmente aplica un tema global. Añadir un `Dictionary` de overrides por game_id
y una función `get_theme_for_game(game_id: String) -> Theme`.

En `theme_manager.gd`:
```gdscript
# Overrides de color primario por juego (se mezclan sobre el tema global)
const GAME_COLOR_OVERRIDES := {
    "chess":            Color(0.20, 0.20, 0.35),
    "go":               Color(0.20, 0.45, 0.30),
    "shogi":            Color(0.55, 0.40, 0.15),
    "xiangqi":          Color(0.65, 0.20, 0.10),
    "checkers":         Color(0.65, 0.15, 0.15),
    "backgammon":       Color(0.55, 0.30, 0.10),
    "battleship":       Color(0.10, 0.25, 0.55),
    "ludo":             Color(0.60, 0.60, 0.10),
    "mille_bornes":     Color(0.30, 0.55, 0.15),
    "monopoly":         Color(0.10, 0.45, 0.65),
    "uno":              Color(0.75, 0.10, 0.25),
    "crisis":           Color(0.45, 0.10, 0.55),
    "chinese_checkers": Color(0.10, 0.55, 0.55),
}

func apply_game_theme(game_id: String) -> void:
    var base := get_current_theme()
    if GAME_COLOR_OVERRIDES.has(game_id):
        var col: Color = GAME_COLOR_OVERRIDES[game_id]
        base.set_color("font_color", "Panel", col.lightened(0.6))
        base.set_color("bg_color", "PanelContainer", col.darkened(0.5))
    get_tree().set_theme(base)
```

Llamar a `ThemeManager.apply_game_theme(game_id)` en `main_menu.gd`, dentro de `_launch_game`,
antes de `get_node("/root/SceneManager").transition_to(scene)`.

Criterio: al entrar a una partida de Chess el fondo del panel es azul oscuro; en Uno, rojo.
`hud_and_settings_smoke.gd` sigue pasando.

---

**398.** Crear **UI de modo espectador** (`spectator_view.gd` / `spectator_view.tscn`).

Los datos de espectador ya llegan vía `test_spectator.gd`. Lo que falta es una escena
que los muestre.

`spectator_view.gd`:
```gdscript
extends Control

var bridge: Node
var _log: RichTextLabel

func setup(p_bridge: Node) -> void:
    bridge = p_bridge
    if bridge.has_signal("spectator_event"):
        bridge.connect("spectator_event", _on_spectator_event)

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(vbox)

    var title := Label.new()
    title.text = "Modo Espectador"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    _log = RichTextLabel.new()
    _log.bbcode_enabled = true
    _log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(_log)

    var back := Button.new()
    back.text = "← Salir"
    back.pressed.connect(func():
        get_tree().change_scene_to_file("res://main.tscn")
    )
    vbox.add_child(back)

func _on_spectator_event(event_json: String) -> void:
    _log.append_text("[color=cyan]%s[/color]\n" % event_json)
```

Escena mínima `spectator_view.tscn`:
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://spectator_view.gd" id="1_sv"]
[node name="SpectatorView" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_sv")
```

En `host_lobby.gd`, añadir botón "👁 Espectador" que:
1. Llame `bridge.call("join_as_spectator")` si el método existe.
2. Transite a `spectator_view.tscn`.

Criterio: `test_spectator.gd` sigue pasando; la escena carga sin null-refs.

---

**399.** Configurar **fullscreen y escalado adaptativo** en `project.godot` y `settings_menu.gd`.

En `project.godot`, bajo `[display]`:
```ini
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

Esto habilita escalado automático a cualquier resolución incluyendo 4K.

En `settings_menu.gd`, dentro del menú de ajustes existente, añadir opción de pantalla completa:
```gdscript
var fullscreen_check := CheckButton.new()
fullscreen_check.text = "Pantalla completa"
fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
fullscreen_check.toggled.connect(func(on: bool):
    if on:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
)
# Insertar en el VBoxContainer de ajustes existente
```

Guardar la preferencia en `ConfigFile` usando la clave `"display/fullscreen"`.

Criterio: la ventana escala correctamente en 1280×720, 1920×1080 y 3840×2160 sin barras
negras (expand mode). `hud_and_settings_smoke.gd` sigue pasando.

---

## 3. Requisitos para crates.io

---

**400.** Eliminar todos los **warnings de Clippy** en el workspace.

Ejecutar:
```bash
cargo clippy --workspace --exclude open_table_godot -- -D warnings 2>&1 | grep "^error" | head -40
```

Para cada warning (usualmente `dead_code`, `unused_variables`, `clippy::too_many_arguments`,
`clippy::single_match`):
- `dead_code`: añadir `#[allow(dead_code)]` en items que deben existir para la API pública,
  o eliminar si realmente no se usan.
- `unused_variables`: prefijar con `_` o eliminar.
- `clippy::too_many_arguments`: refactorizar con un struct de parámetros si hay >7 argumentos.
- `clippy::single_match`: convertir a `if let`.

Meta: `cargo clippy --workspace --exclude open_table_godot -- -D warnings` devuelve exit 0.

Nota: excluir `open_table_godot` porque el proc-macro de `godot-rust` genera código que
puede tener warnings en el output del compilador pero no son controlables.

---

**401.** Establecer **versión semántica 0.1.0** en todos los `Cargo.toml`.

Cada crate del workspace tiene actualmente `version = "0.1.0"` o una versión diferente.
Verificar con:
```bash
grep -r "^version" */Cargo.toml open_table_*/Cargo.toml | grep -v "0.1.0"
```

Para cada crate que no sea `0.1.0`, actualizar `version = "0.1.0"`.

También verificar que las dependencias internas usen `{ path = "..", version = "0.1.0" }`:
```bash
grep -r 'path = "\.\.' */Cargo.toml | grep -v 'version'
```

Añadir `version = "0.1.0"` a las que falten.

Criterio: `cargo publish --dry-run -p open_table_core` (y los demás crates sin dep de godot)
devuelve 0 errores de versión.

---

**402.** Generar **documentación pública** sin errores (`cargo doc`).

Ejecutar:
```bash
cargo doc --workspace --exclude open_table_godot --no-deps 2>&1 | grep -E "^error|warning\[" | head -30
```

Para cada error de documentación:
- Links rotos (`[Foo]` sin referencia): cambiar a `` [`Foo`] `` o añadir `[Foo]: path::to::Foo`.
- Items públicos sin doc: añadir docstring mínima de una línea donde haga falta en la API pública.
- `missing_docs` en módulos públicos: si el crate tiene `#![deny(missing_docs)]`, añadir las
  docstrings que faltan; si no, no añadir la regla.

Meta: `cargo doc --workspace --exclude open_table_godot --no-deps` devuelve exit 0 sin errores.

Verificar que `docs.rs` puede generar la documentación simulando el entorno con:
```bash
RUSTDOCFLAGS="--cfg docsrs" cargo doc --workspace --exclude open_table_godot --no-deps
```

---

## 4. Plugin Android y móvil

---

**403.** Documentar el proceso de **compilación del plugin Android** (`OpenTableNearbyPlugin`).

El archivo `platform_plugins/android/OpenTableNearbyPlugin.kt` está escrito pero no compilado.
No se puede compilar en este entorno (requiere Android Studio), pero se puede documentar el
proceso exacto para que sea reproducible.

Crear `platform_plugins/android/BUILD.md` con:

```markdown
# Compilación del Plugin Android OpenTableNearby

## Prerrequisitos
- Android Studio Ladybug (2024.2+)
- NDK r27 o superior
- Gradle 8.x

## Pasos

1. Abrir `platform_plugins/android/` como proyecto en Android Studio.
2. En `build.gradle`, verificar `compileSdk = 34` y `minSdk = 24`.
3. Build → Build Bundle(s)/APK(s) → Build AAR.
4. Copiar el `.aar` resultante a `godot_project/android/plugins/`.
5. En `godot_project/project.godot`, añadir bajo `[android]`:
   ```ini
   plugins="OpenTableNearbyPlugin"
   ```
6. Exportar el proyecto con Redot 4.5.2 para Android (arm64-v8a).

## Test en dispositivo físico
- Instalar en dos dispositivos Android con BLE/WiFi Direct habilitado.
- Verificar que `OpenTableNearbyPlugin.discover_peers()` devuelve al menos 1 peer.

## CI automatizado (pendiente)
- Añadir job `android-plugin` en `.github/workflows/` usando `actions/setup-java@v6`
  y `gradle build` en el directorio del plugin.
```

Criterio: el archivo existe y describe el proceso paso a paso.

---

**404.** Crear **smoke test de créditos y espectador** en `godot_project/tests/`.

Crear `godot_project/tests/credits_spectator_smoke.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
    # Verificar que credits_screen carga
    var credits_res := ResourceLoader.exists("res://credits_screen.tscn")
    assert(credits_res, "credits_screen.tscn debe existir")

    # Verificar que spectator_view carga
    var spectator_res := ResourceLoader.exists("res://spectator_view.tscn")
    assert(spectator_res, "spectator_view.tscn debe existir")

    # Verificar que spectator_view tiene método setup
    var sv_script = load("res://spectator_view.gd")
    var sv_inst: Node = sv_script.new()
    assert(sv_inst.has_method("setup"), "SpectatorView debe tener método setup")
    sv_inst.free()

    print("credits_spectator_smoke: OK")
    quit(0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        quit(1)
```

Añadir a `tools/run_godot_tests.sh`. Criterio: exit 0 en headless en < 10 s.

---

**405.** Verificación **CI completa de cierre v1.0.0**.

Ejecutar en orden y reportar resultado de cada paso:

```bash
# 1. Clippy sin warnings
cargo clippy --workspace --exclude open_table_godot -- -D warnings 2>&1 | tail -3

# 2. Tests Rust completos
cargo test --workspace --exclude open_table_godot 2>&1 | tail -5

# 3. Documentación sin errores
cargo doc --workspace --exclude open_table_godot --no-deps 2>&1 | grep "^error" | wc -l

# 4. Build del bridge
cargo build -p open_table_godot --release 2>&1 | tail -3

# 5. Tests Godot headless
tools/run_godot_tests.sh 2>&1 | grep -E "PASS|FAIL|ERROR|exit code"
```

Meta: todos los pasos devuelven exit 0; el paso 3 devuelve "0" (cero errores de doc).

Si algún paso falla, reportar el error exacto y corregir antes de marcar el prompt como ✅.

---

## Resumen de prompts por área

| # | Área | Archivo(s) principal(es) |
|---|------|--------------------------|
| 393 | NetworkStatusHud en tableros | todos los `*_board.gd` |
| 394 | Tabla de juegos en NEXT_STEPS.md | `NEXT_STEPS.md` |
| 395 | score_tracker game_ended | `score_tracker.gd` |
| 396 | Pantalla de créditos | `credits_screen.gd/tscn`, `main_menu.gd` |
| 397 | Temas per-game | `theme_manager.gd`, `main_menu.gd` |
| 398 | UI de espectador | `spectator_view.gd/tscn`, `host_lobby.gd` |
| 399 | Fullscreen + escalado 4K | `project.godot`, `settings_menu.gd` |
| 400 | 0 warnings Clippy | workspace Rust |
| 401 | Versión 0.1.0 en Cargo.toml | todos los `Cargo.toml` |
| 402 | cargo doc sin errores | workspace Rust |
| 403 | BUILD.md plugin Android | `platform_plugins/android/BUILD.md` |
| 404 | Smoke test créditos+espectador | `tests/credits_spectator_smoke.gd` |
| 405 | CI completa v1.0.0 | CI / terminal |

*Total acumulado: 405 prompts (PROMPTS1–8).*
*Total PROMPTS8: 13 prompts (393–405).*

---

## Criterios de "Versión 1.0.0 lista"

Antes de etiquetar `v1.0.0` en git, deben estar todos en ✅:

- [ ] `cargo clippy --workspace -- -D warnings` → exit 0
- [ ] `cargo test --workspace` → exit 0
- [ ] `cargo doc --workspace --no-deps` → 0 errores
- [ ] Versión `0.1.0` en todos los `Cargo.toml`
- [ ] `tools/run_godot_tests.sh` → 0 FAILs
- [ ] `network_status_hud` integrado en los 13 tableros (prompt 393)
- [ ] Pantalla de créditos accesible desde el menú (prompt 396)
- [ ] Fullscreen configurable (prompt 399)
- [ ] `BUILD.md` del plugin Android existe (prompt 403)
