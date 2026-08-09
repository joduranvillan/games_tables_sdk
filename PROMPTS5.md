# Prompts de Mejora Visual e IA Local — Games Tables SDK (Parte 5)

Continúa desde `PROMPTS4.md` (prompts 1–325). Numerados del 326 al 370.

**Objetivo de esta parte:** mejorar la apariencia visual de todos los tableros,
añadir IA local para juegos de dos jugadores como alternativa al modo hotseat,
y completar los tests de red que siguen pendientes.

---

## 0. Registro de estado al inicio de PROMPTS5

### Ya implementado (verificado en código fuente al 2026-08-09)

| Elemento | Ubicación |
|----------|-----------|
| Doubling cube Backgammon (prompts 310) | `backgammon_game/src/commands.rs` + tests en `tests/game_rules.rs:307,317,334` |
| Jump-in UNO (prompts 311) | `uno_game/src/commands.rs` + tests en `tests/game_rules.rs:241,280` |
| `get_legal_moves` bridge Godot | `test_get_legal_moves_bridge.gd` en `godot_project/tests/` |
| `LegalMoveGenerator` checkers | `checkers_game/tests/game_rules.rs:16` (`test_get_legal_moves_devuelve_solo_movimientos_validos`) |
| `test_legal_moves_posicion_inicial_tiene_20_jugadas` (chess) | `chess_game/tests/game_rules.rs:20` |
| `multi_session_tcp_smoke.gd` (prompt 316) | `godot_project/tests/multi_session_tcp_smoke.gd` |
| Sistema ELO (prompt 312) | `open_table_engine/src/elo.rs` |
| IA básica para Damas | `checkers_game/src/ai.rs` (aleatoria con prioridad de capturas) |
| Visual regression test | `godot_project/tests/visual_regression.gd` |
| 2 temas visuales (Madera, Minimal) | `godot_project/theme_manager.gd` |
| Gestos táctiles + dead zone 8px | `godot_project/chess_board.gd`, `checkers_board.gd` |
| Responsive layout PHONE/TABLET/DESKTOP | `godot_project/game_manager.gd` |

### Pendiente real (no implementado)

| Elemento | Dónde buscar | Nota |
|----------|-------------|------|
| `tcp_reconnection_smoke.gd` (prompt 314) | `godot_project/tests/` — **no existe** | Test de reconexión TCP |
| `tcp_packet_loss_smoke.gd` (prompt 315) | `godot_project/tests/` — **no existe** | Simulación de pérdida de paquetes |
| Sistema ELO expuesto en Godot (prompt 313) | `score_tracker.gd` — sin `elo` campo | Integración UI pendiente |
| Temas visuales adicionales (solo hay 2) | `theme_manager.gd` | Solo "wood" y "minimal" |
| IA para juegos de 2 jugadores distintos de Damas | `open_table_godot/src/lib.rs` — solo `start_local_match_checkers_vs_ai` | |

---

## 1. Tests de Red Pendientes

---

**326.** Crear `godot_project/tests/tcp_reconnection_smoke.gd` — **test de reconexión TCP**.
El test: (1) arranca una sesión de damas como host TCP en puerto 19877 con
`host.start_hosting(19877, 1, 2)`, (2) conecta un cliente con
`client.connect_to_host("127.0.0.1", 19877, "P2")`, (3) espera 10 frames de
proceso para completar el handshake, (4) envía un `MovePieceCommand` desde el
host y verifica que el cliente emite `piece_moved`, (5) cierra el cliente con
`client.disconnect_from_host()`, (6) crea un nuevo `OpenTableBridge` y llama
`reconnect_to_host("127.0.0.1", 19877, "P2")`, (7) espera 10 frames, (8) verifica
que `client2.is_connected_to_host()` es `true` y que `client2.current_player()` es
consistente con el estado del host. Timeout global: 10 segundos (contar frames).
Añadir al runner `tools/run_godot_tests.sh` con la línea correspondiente y
confirmar exit code 0 headless.

---

**327.** Crear `godot_project/tests/tcp_packet_loss_smoke.gd` — **simulación de
pérdida de paquetes**. Implementar un `MockTcpProxy` en GDScript que recibe
paquetes vía `StreamPeerBuffer` y los reenvía con un 20 % de descarte
(`randf_range(0.0, 1.0) < 0.2`), usando seed fija (`seed(2026)`) para
reproducibilidad. Host y cliente se conectan al proxy en lugar de directamente
entre sí. Jugar 8 movimientos alternativos de damas (4 por jugador) vía host.
Verificar que todos los eventos llegan eventualmente al cliente (con hasta 5
reintentos por frame) y que `host.current_player() == client.current_player()`
al final. Timeout: 30 segundos. Añadir al runner y confirmar exit code 0
headless. Este test no requiere implementar retransmisión real en Rust; solo
verifica que el estado converge cuando la pérdida es simulada a nivel de proxy
GDScript.

---

## 2. ELO en Godot UI (Prompt 313 de PROMPTS4, aún pendiente)

---

**328.** Completar la integración ELO en `godot_project/score_tracker.gd`.
Añadir el campo `"elo"` al objeto JSON almacenado en `user://scores.json` con
estructura `{ "elo": { "chess": { "1": 1200, "2": 1200 }, "checkers": {...} } }`.
Añadir la función `update_elo_after_game(game_type: String, winner_id: int,
loser_id: int)` que llama `bridge.compute_elo_delta(winner_id, loser_id,
get_elo(game_type, winner_id), get_elo(game_type, loser_id), 32.0)` y guarda
los nuevos valores. Conectar al evento `game_over` del bridge en
`game_manager.gd` para llamar automáticamente a `update_elo_after_game`.
En `settings_menu.tscn`, añadir una pestaña "Estadísticas" con un `VBoxContainer`
que muestre por juego: partidas jugadas, victorias, ELO actual. Leer los datos
desde `score_tracker.gd`. Añadir el smoke test `hud_and_settings_smoke.gd`
(ya existe) con una verificación adicional: tras simular un `GameOverEvent` con
`winner=1`, el campo ELO del jugador 1 debe ser > 1200.

---

## 3. Mejoras de Apariencia Visual — Temas Adicionales

El sistema de temas ya existe (`ThemeManager`, `BoardTheme`) con solo 2 presets.
Esta sección añade 3 temas nuevos, efectos de pieza, y mejoras visuales
concretas en los tableros más usados.

---

**329.** Añadir 3 temas nuevos en `godot_project/theme_manager.gd`:

- **"Piedra Oscura"** (`stone`): `light_color = Color("#C8B89A")`,
  `dark_color = Color("#4A3728")`, `board_color = Color("#3D2E21")`,
  `line_color = Color("#1A0E08")`, `select_color = Color(0.95, 0.75, 0.1, 0.55)`,
  `valid_move_color = Color(0.15, 0.75, 0.15, 0.55)`.
- **"Noche Azul"** (`night`): `light_color = Color("#B0C4DE")`,
  `dark_color = Color("#0D1B2A")`, `board_color = Color("#0D1B2A")`,
  `line_color = Color("#4A90D9")`, `select_color = Color(0.4, 0.9, 1.0, 0.55)`,
  `valid_move_color = Color(0.0, 0.85, 0.7, 0.6)`.
- **"Jade Verde"** (`jade`): `light_color = Color("#D4E6C3")`,
  `dark_color = Color("#2D5A27")`, `board_color = Color("#2D5A27")`,
  `line_color = Color("#1A3A15")`, `select_color = Color(0.9, 0.95, 0.3, 0.55)`,
  `valid_move_color = Color(0.9, 0.5, 0.1, 0.6)`.

Actualizar `set_theme()` para reconocer las claves `"stone"`, `"night"` y `"jade"`.
Actualizar `toggle_theme()` para ciclar entre los 5 temas en orden
(`wood → minimal → stone → night → jade → wood`). En `settings_menu.gd`,
reemplazar el botón binario de tema por un `OptionButton` con las 5 opciones
y su nombre localizado. Añadir el smoke test `hud_and_settings_smoke.gd`
verificando que `ThemeManager.set_theme("night")` emite `theme_changed` con el
tema correcto.

---

**330.** Añadir **sombra proyectada bajo las piezas** en `checkers_board.gd`.
En la función `PieceSprite._draw()`, antes de dibujar el círculo de la pieza,
dibujar un círculo de sombra desplazado `(3, 4)` píxeles con color
`Color(0, 0, 0, 0.35)` y radio `cell_size * 0.36`. El efecto crea profundidad
visual sin coste de rendimiento. Aplicar el mismo patrón en `chess_board.gd`
para los fallback-unicode: añadir una `Label` duplicada detrás del texto
(desplazada 2px) con color `Color(0, 0, 0, 0.4)`. Verificar que el test
`visual_regression.gd` no detecta regresión si se actualizan los snapshots
(`UPDATE_SNAPSHOTS=1`).

---

**331.** Añadir **animación de "bounce" al seleccionar una pieza** en
`checkers_board.gd` y `chess_board.gd`. Cuando el jugador selecciona una pieza
(click/tap), el sprite correspondiente hace un Tween de escala:
`scale → Vector2(1.15, 1.15)` en 0.08 s, luego regresa a `Vector2(1.0, 1.0)`
en 0.08 s. Al deseleccionar o mover, el scale vuelve inmediatamente a 1.0 sin
animación. Usar `create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)`.
La animación no debe bloquear el input (solo setea `scale`, no usa `animating`).
Verificar que el bounce no se dispara durante la animación de movimiento
(guardia `if animating: return`).

---

**332.** Añadir **animación de captura con partículas simples** en
`checkers_board.gd`. Al recibir la señal `piece_moved` con una captura
(la pieza capturada desaparece), instanciar un `CPUParticles2D` en la posición
de la celda capturada con: `amount = 12`, `lifetime = 0.5`, `explosiveness = 0.8`,
`direction = Vector2(0, -1)`, `spread = 180.0`, `gravity = Vector2(0, 200)`,
`initial_velocity_min = 80`, `initial_velocity_max = 160`,
`color = Color del jugador que capturó` (via `GameManager.get_player_color`).
El nodo de partículas se añade con `add_child()` y se libera automáticamente
al terminar (`one_shot = true`, conectar `finished` a `queue_free`).
No añadir esta animación en modo headless (guardia `if OS.has_feature("headless"): return`).

---

**333.** Mejorar el **tablero de Ajedrez visualmente** en `chess_board.gd`:

1. **Coordenadas del tablero**: dibujar en `_draw()` las letras a–h en la fila
   inferior y los números 1–8 en la columna izquierda usando `draw_string()`.
   Fuente: `ThemeManager.get_current_theme().piece_font` si no es null, o
   la fuente por defecto del sistema. Color: 60 % del color de la casilla
   contraria (para que haya contraste pero sin dominar). Tamaño: `CELL_SIZE * 0.22`.
2. **Borde del tablero**: dibujar un `Rect2` del tamaño total del tablero con
   grosor 3 px y color `Color(0.2, 0.12, 0.05, 1.0)` (marrón oscuro) en `_draw()`.
3. **Highlight del último movimiento**: guardar `last_move_from` y `last_move_to`
   al recibir `piece_moved`. En `_draw()`, colorear esas dos casillas con
   `Color(0.9, 0.85, 0.3, 0.35)` antes de dibujar la selección.

---

**334.** Mejorar el **Menú Principal** en `godot_project/main_menu.gd`:

1. **Fondo animado**: añadir un `ColorRect` con `ShaderMaterial` de gradiente
   suave que cicla entre 3 colores del tema activo (`board_color → dark_color → board_color`)
   con un periodo de 8 segundos usando `TIME` uniforme. El shader es
   `void fragment() { COLOR = mix(colorA, colorB, (sin(TIME * 0.785) + 1.0) * 0.5); }`.
   Si el dispositivo no soporta shaders (detect con `RenderingServer.get_rendering_device() == null`),
   usar un `ColorRect` estático con el `board_color` del tema.
2. **Título con animación de entrada**: en `_play_entry_animation()`, añadir
   después de la animación actual un parpadeo suave del subtítulo usando
   `create_tween().set_loops().tween_property(subtitle_label, "modulate:a", 0.5, 1.2).chain().tween_property(..., 1.0, 1.2)`.
3. **Hover con escala en botones de juego**: al hacer hover sobre cada botón de
   juego, animar `scale` a `Vector2(1.05, 1.05)` y al salir volver a `Vector2(1, 1)`,
   con Tween de 0.1 s. Conectar `mouse_entered` y `mouse_exited`.

---

**335.** Añadir **indicador visual de jaque** en `chess_board.gd`. Tras cada
movimiento, obtener la posición del rey del jugador activo iterando
`piece_sprites` buscando la pieza con `get_meta("kind") == "King"` y
`get_meta("player") == current`. Si el último evento JSON contiene
`"event_type": "CheckEvent"` o `"in_check": true`, guardar la posición en
`check_king_pos`. En `_draw()`, dibujar un halo rojo pulsante sobre la casilla
del rey en jaque: `draw_rect(Rect2(...), Color(1, 0, 0, 0.3 + 0.2 * sin(Time.get_ticks_msec() * 0.005)))`.
Llamar `queue_redraw()` en `_process()` mientras `check_king_pos != null` para
mantener la animación. Limpiar `check_king_pos` cuando ya no hay jaque
(próximo evento sin `in_check` o turno terminado sin jaque).

---

**336.** Mejorar el **overlay de fin de juego** en `godot_project/game_over_overlay.gd`.
El overlay actual muestra texto plano. Reemplazar por:

1. **Fondo**: `ColorRect` semi-transparente que cubre toda la pantalla
   (`Color(0, 0, 0, 0.72)`), fade-in de 0.3 s con Tween.
2. **Panel central**: `PanelContainer` de 380×220 px centrado, con
   `StyleBoxFlat` de `bg_color = Color(0.15, 0.12, 0.08, 0.97)`,
   `border_color = Color(0.8, 0.65, 0.1)`, `border_width = 3`,
   `corner_radius = 12`.
3. **Título animado**: `Label` con texto "¡Victoria!" / "¡Empate!" en tamaño 36,
   que entra desde arriba con Tween `position.y` (desde -50 px fuera del panel
   hasta su posición final) en 0.4 s con `TRANS_BOUNCE`.
4. **Color del ganador**: el texto del jugador ganador usa el color de
   `GameManager.get_player_color(winner_id)`.
5. **Botones**: "Revancha" (`restart`) y "Menú" (`go_to_menu`) con mismo estilo.
   Emitir señales `rematch_requested` y `menu_requested` respectivamente.

Verificar que el overlay es funcional sin el GDExtension cargado (el overlay
no llama a `bridge`).

---

**337.** Añadir **temas visuales a la pantalla de selección de juego** en
`main_menu.gd`. Cada botón de juego del `GridContainer` ya tiene un campo
`"color"` en el diccionario `GAMES`. Usar ese color como:

1. `StyleBoxFlat.bg_color` del botón con alpha `0.85`.
2. `StyleBoxFlat.border_color` en estado hover: `color.lightened(0.3)`.
3. `StyleBoxFlat.shadow_color = color.darkened(0.5)` con `shadow_size = 4`.

Añadir un ícono SVG/PNG por juego en `godot_project/assets/icons/`
(ajedrez = ♟, damas = ●, go = ●●, shogi = 将, etc.) cargado como `Texture2D`
en el botón. Si el archivo no existe, usar el texto actual (degradado a solo
texto). La cuadrícula pasa de un solo texto a `VBoxContainer` con ícono 48×48
encima del nombre.

---

## 4. IA Local para Juegos de Dos Jugadores

La única IA existente (`checkers_ai_pick_move`) usa búsqueda aleatoria con
prioridad de capturas. Esta sección añade IA basada en Minimax con poda
alfa-beta para ajedrez y backgammon, y una IA heurística simple para los
juegos restantes de 2 jugadores (Shogi, Xiangqi, Go). La IA es **completamente
local y offline**: sin llamadas a red, sin modelos de ML, sin dependencias
externas.

---

**338.** Implementar **Minimax con poda alfa-beta para Ajedrez** en
`chess_game/src/ai.rs`. Crear `pub fn chess_ai_pick_move(session: &Session, player: PlayerId, depth: u8) -> Option<MovePieceCommand>`.

Arquitectura:
- Función `minimax(session: &Session, depth: u8, alpha: f32, beta: f32, maximizing: bool, player: PlayerId) -> f32`.
- `generate_candidates(session: &Session, player: PlayerId) -> Vec<MovePieceCommand>`: usa `ChessLegalMoveGenerator` (ya implementado en `chess_game/src/legal_moves.rs`) para obtener todos los movimientos legales.
- `evaluate_position(session: &Session, player: PlayerId) -> f32`: función de evaluación estática con:
  - Material: Peón=1, Caballo/Alfil=3, Torre=5, Dama=9, Rey=1000. Suma para `player`, resta para el oponente.
  - Bonus de movilidad: `+0.1 * num_movimientos_legales_del_jugador`.
  - Control del centro: +0.15 por pieza en las 4 casillas centrales (d4, e4, d5, e5).
- Profundidad por defecto: `depth = 3` (ajustable). A depth=3 el árbol explora ~9,000 nodos en posición inicial, tiempo < 200 ms en hardware moderno.
- Si no hay movimientos legales (jaque mate / ahogado), devolver `f32::NEG_INFINITY` o `0.0` según corresponda.

Exponer en `chess_game/src/lib.rs`:
```rust
pub use ai::chess_ai_pick_move;
```

Tests en `chess_game/src/ai.rs`:
- `test_chess_ai_devuelve_movimiento_en_posicion_inicial`: verifica `chess_ai_pick_move(&session, P1, 2).is_some()`.
- `test_chess_ai_captura_reina_expuesta`: posición con la reina negra sin defender; la IA blanca a depth=2 debe elegir el movimiento que captura la reina.

---

**339.** Exponer la IA de Ajedrez en el bridge Godot. Añadir en
`open_table_godot/src/lib.rs`:

```rust
#[func]
fn start_local_match_chess_vs_ai(&mut self, human_player: i64, ai_player: i64, depth: i64) -> bool
```

Misma lógica que `start_local_match_checkers_vs_ai`: valida parámetros, crea
la sesión con `new_chess_session`, guarda `ai_player: Some(p_ai)`. En
`process_ai_turn_if_needed()`, añadir la rama para `"chess"`:

```rust
"chess" => chess_game::chess_ai_pick_move(session, *ai_p, self.chess_ai_depth),
```

Añadir `chess_ai_depth: u8 = 3` como campo en la struct. Añadir en GDScript la
función `set_chess_ai_depth(depth: int)` que modifica ese campo vía `#[func]`.

En `chess_board.gd`, añadir un `OptionButton` "Modo de juego" con opciones
"Hotseat (2 jugadores)", "vs IA (fácil)", "vs IA (medio)", "vs IA (difícil)"
que mapean a `depth` 1, 2, 3 y que llaman `start_local_match_chess_vs_ai` o
`start_local_match_chess` según la selección. El selector aparece en la misma
posición que el selector de apertura (desplazando ese 40 px hacia abajo si
ambos están activos).

---

**340.** Implementar **IA heurística para Backgammon** en
`backgammon_game/src/ai.rs`. Crear
`pub fn backgammon_ai_pick_move(session: &Session, player: PlayerId) -> Option<MoveCheckerCommand>`.

Estrategia (no minimax por el rol del dado aleatorio):
1. Generar todos los `MoveCheckerCommand` legales para el jugador usando el mismo
   patrón que la IA de damas (prueba-y-error con clon de sesión).
2. Aplicar heurística de puntuación a cada movimiento legal:
   - **+10** si el movimiento saca una ficha de la barra.
   - **+8** si el movimiento lleva una ficha a la zona "home" (puntos 1-6 del jugador).
   - **+5** si el movimiento crea un bloque (2 o más fichas en el punto destino).
   - **-15** si el movimiento deja una "blot" (ficha sola) en el campo del oponente.
   - **+3** por cada punto de avance del dado utilizado.
3. Elegir el movimiento con mayor puntuación; en empate, elegir al azar entre ellos.

Exponer con `pub use ai::backgammon_ai_pick_move` en `backgammon_game/src/lib.rs`.
Tests: `test_backgammon_ai_saca_ficha_de_barra_cuando_puede` y
`test_backgammon_ai_prefiere_crear_bloque_sobre_dejar_blot`.

Añadir `start_local_match_backgammon_vs_ai(human: i64, ai: i64) -> bool` en el
bridge Godot usando la misma infraestructura que ajedrez/damas. En
`backgammon_board.gd`, añadir el `OptionButton` "Modo: Hotseat / vs IA".

---

**341.** Implementar **IA para Shogi y Xiangqi** usando el mismo patrón de
puntuación material que el Minimax de Ajedrez pero con depth=2 y evaluaciones
específicas.

**Shogi** (`shogi_game/src/ai.rs`):
- `shogi_ai_pick_move(session: &Session, player: PlayerId) -> Option<Box<dyn Command>>`.
- Generar candidatos: movimientos de piezas en tablero + drops de mano (todas las piezas de la mano del jugador en todas las casillas vacías legales).
- Evaluación material: Peón=1, Caballo=3, Alfil/Torre=5, General=3, Lanza=2, Oro/Plata=4, Rey=1000. Bonus +1 por pieza promovida.
- depth=2 para mantener tiempo < 150 ms.

**Xiangqi** (`xiangqi_game/src/ai.rs`):
- `xiangqi_ai_pick_move(session: &Session, player: PlayerId) -> Option<MovePieceCommand>`.
- Evaluación: Peón=1, Caballo=4, Alfil/Consejero=2, Torre=9, Cañón=4.5, General=1000.
- Bonus de posición: +0.5 si el Cañón tiene al menos 1 pantalla disponible.
- depth=2.

Exponer ambas en sus `lib.rs` respectivos y añadir `start_local_match_shogi_vs_ai`
y `start_local_match_xiangqi_vs_ai` en el bridge Godot. Actualizar los `.gd`
de tablero con el `OptionButton` de modo de juego. Tests mínimos: 1 test por
función que verifica que devuelve un movimiento en posición inicial.

---

**342.** Añadir **selector de modo de juego (Hotseat / vs IA)** en el Menú Principal.
En el diccionario `GAMES` de `main_menu.gd`, añadir el campo `"ai_method"` con el
nombre del método `start_local_match_*_vs_ai` correspondiente, o `""` si no hay
IA implementada para ese juego.

Al pulsar un juego, en lugar de navegar directamente a la escena, mostrar un
`Popup` (o `ConfirmationDialog`) con:
- Título: nombre del juego
- Opciones: botón "2 Jugadores (Hotseat)" y botón "vs IA" (grisado/oculto si `ai_method == ""`).
- Para "vs IA" en ajedrez: `OptionButton` de dificultad (Fácil=depth 1, Medio=depth 2, Difícil=depth 3).

Guardar la última selección en `user://settings.json` como `"default_mode"` para
recordarla entre sesiones. Emitir `layout_changed` al abrir el popup para que
el fondo se oscurezca ligeramente (`modulate.a = 0.5` sobre el `GridContainer`).

---

**343.** Añadir **test de humo para la IA local** en `godot_project/tests/`.
Crear `ai_local_smoke.gd` que: (1) crea un `OpenTableBridge`, (2) llama
`start_local_match_checkers_vs_ai(42, 1, 2)`, (3) espera 50 frames procesando
`bridge._process(0.016)` en un loop, (4) verifica que el número de ticks de la
sesión es > 2 (la IA hizo al menos un movimiento), (5) repite el mismo test
para `start_local_match_chess_vs_ai(1, 2, 1)` (depth 1 para velocidad).
Añadir al runner `tools/run_godot_tests.sh`. Confirmar exit code 0 headless.

---

## 5. Mejoras Visuales Adicionales en Tableros Específicos

---

**344.** Mejorar la **UI de Uno** (`uno_board.gd`):

1. **Cartas con borde redondeado**: cada carta del `hand_container` se dibuja
   como un `PanelContainer` con `StyleBoxFlat.corner_radius_*_px = 8` y
   `border_width = 2`. El color del panel es el color de la carta
   (`Color("#FF0000")` para rojo, `Color("#0000FF")` azul, etc.) más texto blanco
   centrado con el valor.
2. **Animación de robo**: al robar carta, el nuevo `PanelContainer` entra desde
   la posición del mazo (`deck_button.global_position`) hasta su posición final
   en el `hand_container` con un Tween de posición de 0.3 s.
3. **Indicador de color activo**: añadir un `ColorRect` de 24×24 px en la
   esquina superior derecha de la zona de descarte que muestra el color activo
   (importante para las wildcards). Actualizar al procesar `event_json` con
   `"event_type": "ColorChangedEvent"`.
4. No introducir lógica de reglas: toda la información viene de los eventos del bridge.

---

**345.** Mejorar la **UI de Battleship** (`battleship_board.gd`):

1. **Cuadrícula con coordenadas**: dibujar las letras A–H en la columna izquierda
   y los números 1–8 en la fila superior de ambas cuadrículas (la propia y la
   del oponente) usando `draw_string()` en `_draw()`.
2. **Animación de disparo**: al recibir `shot_result`, mostrar un `Sprite2D` de
   explosión en la celda correspondiente. Si no existe sprite, dibujar un
   círculo rojo pulsante con `CPUParticles2D` (igual que el prompt 332).
3. **Barcos hundidos en gris**: cuando se hunde un barco (`SunkShipEvent`),
   colorear todas sus celdas con `Color(0.3, 0.3, 0.3, 0.8)` para diferenciarlo
   de las celdas de impacto (rojo).
4. **Indicador de turno prominente**: hacer que el `TurnIndicator` del tablero
   del jugador activo tenga `modulate = Color(1, 1, 1, 1)` y el inactivo
   `Color(1, 1, 1, 0.4)`.

---

**346.** Mejorar la **UI de Ludo** (`ludo_board.gd`):

1. **Fichas con número de jugador**: en el centro de cada ficha (círculo),
   dibujar el número del jugador en blanco con `draw_string()`.
2. **Animación de avance casilla a casilla**: en lugar de mover la ficha
   directamente a su destino, usar un Tween en cadena que pase por cada
   casilla intermedia (tiempo 0.12 s por casilla). Calcular el camino con la
   función `get_path_from_to(from_cell, to_cell) -> Array[Vector2]` que devuelve
   las posiciones de pantalla de cada paso.
3. **Highlight de casillas seguras**: colorear las casillas "seguras" (inicio y
   estrella) con `Color(0.9, 0.9, 0.3, 0.3)` permanentemente en `_draw()`.
4. **Animación de dado**: el `dice_widget.gd` ya existe. Conectar en `ludo_board.gd`
   para que al recibir el evento de tirada de dado, el widget haga una animación
   de 3 caras aleatorias en 0.4 s antes de mostrar el resultado real.

---

**347.** Mejorar la **UI de Go** (`go_board.gd`):

1. **Puntos hoshi**: dibujar los 9 puntos hoshi del tablero de Go 9×9 (o 19×19)
   como círculos negros rellenos de radio `CELL * 0.12` en las intersecciones
   canónicas (3-3, 3-9, 3-15 en 19×19, o 3-3, 3-7, 5-5 en 9×9). En `_draw()`,
   antes de dibujar las piedras.
2. **Animación de colocación de piedra**: al recibir `stone_placed`, la nueva
   piedra aparece con un Tween de escala desde `0.0` a `1.0` en 0.15 s
   (`TRANS_BACK`, `EASE_OUT`).
3. **Indicador de capturas**: debajo del tablero, mostrar dos contadores
   `"Capturas B: N"` y `"Capturas N: N"` que se actualizan al procesar los
   eventos de captura (`StonesRemovedEvent`).
4. **Territorio en fin de juego**: al recibir `GameOverEvent`, colorear las
   intersecciones vacías con el color del jugador que controla ese territorio
   (alpha 0.35), calculado con un flood-fill simple desde las piedras de cada
   jugador. Si no hay datos de territorio en el evento, omitir este paso.

---

## 6. Calidad y Cierre de PROMPTS5

---

**348.** Actualizar `NEXT_STEPS.md` para reflejar el estado real al terminar
PROMPTS5. Reemplazar la sección "Para publicación en crates.io" con estado
actualizado: marcar como ✅ los ítems completados (doubling cube, jump-in UNO,
`get_legal_moves`), añadir la sección **"Mejoras visuales e IA local (PROMPTS5)"**
con checkboxes para cada prompt 326–347. Actualizar la tabla de reglas para
reflejar que Backgammon tiene doubling cube (cambiar ⚠️ a ✅).

---

**349.** Actualizar los **snapshots de regresión visual** tras aplicar todos los
cambios visuales de esta parte. Ejecutar `UPDATE_SNAPSHOTS=1 make test-godot`
para regenerar los 13 archivos PNG de referencia en `godot_project/tests/snapshots/`.
Verificar que después de la regeneración, `make test-godot` pasa con 0 fallos.
Añadir una nota en `TESTING.md` explicando cuándo actualizar snapshots (solo
tras cambios visuales intencionales, nunca como fix de CI fallido).

---

**350.** Ejecutar el conjunto completo de tests y documentar el estado final en
`CHANGELOG.md`. Comandos a ejecutar en orden:
1. `cargo clippy --workspace -- -D warnings` → debe pasar sin output.
2. `cargo test --workspace --lib --tests 2>&1 | tail -5` → todos los tests deben pasar.
3. `tools/run_godot_tests.sh` → todos los smoke tests deben devolver exit 0.
4. `cargo doc --workspace --no-deps 2>&1 | grep "warning:" | wc -l` → debe ser 0.

En `CHANGELOG.md`, añadir la sección `[0.2.0-dev]` con subsecciones:
- **Added**: IA local para Ajedrez, Backgammon, Shogi, Xiangqi; 3 temas visuales nuevos; animaciones de selección, captura y partículas; overlay de fin de juego mejorado; selector de modo de juego en menú.
- **Fixed**: tests TCP de reconexión y pérdida de paquetes; integración ELO en UI.
- **Changed**: menú principal con fondo animado; tablero de Ajedrez con coordenadas y último movimiento; tablero de Go con hoshi y contador de capturas.

---

*Fin de PROMPTS5.md — 25 prompts (326–350).*

*Resumen por sección:*
- *0. Registro de estado: documentación de lo implementado al iniciar PROMPTS5*
- *1. Tests de red pendientes: prompts 326–327 (2 prompts)*
- *2. ELO en Godot UI: prompt 328 (1 prompt)*
- *3. Temas visuales adicionales: prompts 329–337 (9 prompts)*
- *4. IA local para juegos de 2 jugadores: prompts 338–343 (6 prompts)*
- *5. Mejoras visuales en tableros específicos: prompts 344–347 (4 prompts)*
- *6. Calidad y cierre: prompts 348–350 (3 prompts)*

*Total acumulado: 350 prompts (PROMPTS1: 1–40, PROMPTS2: 41–160, PROMPTS3: 161–300, PROMPTS4: 301–325, PROMPTS5: 326–350).*
