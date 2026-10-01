# Prompts de Viabilidad de Producto y Distribución Comercial — Games Tables SDK (Parte 9)

Continúa desde `PROMPTS8.md` (prompts 393–405). Numerados del **406 al 425**.

**Objetivo:** Elevar el SDK de un motor técnico validado (v1.0.0) a un **producto viable, distribuible y comercialmente atractivo**, resolviendo los vacíos críticos de experiencia de usuario, juego en línea real sin fricción, feedback audiovisual, accesibilidad, y distribución empaquetada para desarrolladores y jugadores finales.

---

## 0. Diagnóstico y Análisis de Viabilidad

La versión 1.0.0 alcanzó la excelencia técnica: 13 juegos implementados, cero warnings de Clippy, suites de tests de integración y regresión en Rust y Godot headless, y un bridge GDExtension funcional.

Sin embargo, para que **OpenTable sea un proyecto verdaderamente viable** tanto como **juego completo para usuarios finales** (Steam/Itch/Móvil) como **SDK para que otros estudios creen sus propios juegos de mesa**, se identifican 7 pilares indispensables que faltan:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   LOS 7 PILARES DEL PROYECTO VIABLE                    │
├────────────────────────────────┬───────────────────────────────────────┤
│ 1. Conectividad Real Internet  │ Servidor Relay ligero con Room Codes  │
│ 2. Persistencia y Replays      │ Guardado en disco, PGN/SGF y visor    │
│ 3. Feedback Audiovisual        │ SFX procedurables y sintéticos        │
│ 4. Internacionalización (i18n) │ Catálogo multilingüe (ES, EN, PT, FR) │
│ 5. Controles y Accesibilidad   │ Gamepad/Steam Deck, zoom táctil, Dalto│
│ 6. Distribución y CI/CD Matrix │ Binarios Windows/Linux/Web empaquetado│
│ 7. Ecosistema SDK (Addon)      │ Plugin Godot + Quickstart 15 minutos  │
└────────────────────────────────┴───────────────────────────────────────┘
```

---

## Bloque 1: Conectividad y Salas por Internet (Prompts 406–409)

*Problema actual:* Las partidas multijugador funcionan por IP directa o código QR en LAN. En el mundo real, el 90% de los usuarios están tras NAT simétricos o routers residenciales sin apertura de puertos.
*Solución viable:* Un servidor Relay de WebSocket en Rust (`open_table_relay`) ultra liviano (<15MB RAM) que maneja salas efímeras con códigos de 4 letras (ej. `AK47`, `GAME`).

---

### 406. Crate `open_table_relay`: Servidor de salas y retransmisión WebSocket

**Objetivo:** Crear un microservidor standalone en Rust en el workspace que administre salas públicas/privadas y retransmita paquetes entre clientes sin requerir apertura de puertos.

- **Archivos:**
  - `open_table_relay/Cargo.toml`
  - `open_table_relay/src/main.rs`
  - `open_table_relay/src/room.rs`
  - `Cargo.toml` (agregar a `members`)
- **Especificaciones:**
  - Usa `tokio` y `tokio-tungstenite`.
  - Protocolo JSON mínimo:
    - `{"op": "create"}` -> responde `{"op": "created", "room_code": "XKCD"}`.
    - `{"op": "join", "room_code": "XKCD"}` -> responde `{"op": "joined", "player_id": 2}`.
    - `{"op": "relay", "data": "..."}` -> retransmite el payload a los demás participantes de la sala.
    - `{"op": "leave"}` / desconexión -> notifica a los participantes restantes.
  - Generación de códigos alfanuméricos legibles de 4 caracteres (evitando letras confusas como O/0, I/1).
- **Verificación:**
  ```bash
  cargo check -p open_table_relay
  cargo test -p open_table_relay
  ```

---

### 407. Cliente Relay en `open_table_transport_websocket` y GDExtension

**Objetivo:** Extender el cliente de transporte WebSocket para soportar el flujo de conexión mediante el Relay Server, exponiendo métodos limpios al bridge de Godot.

- **Archivos:**
  - `open_table_transport_websocket/src/client.rs`
  - `open_table_godot/src/lib.rs`
- **Especificaciones:**
  - Métodos expuestos en el bridge de Godot:
    - `connect_to_relay(relay_url: &str)`
    - `create_relay_room(game_id: &str) -> String` (emite señal `room_created(code)`)
    - `join_relay_room(code: &str)` (emite señal `room_joined(success, player_id)`)
  - Manejo de ping/pong heartbeat cada 15 segundos para evitar que proxies y routers cierren la conexión.
- **Verificación:**
  ```bash
  cargo clippy -p open_table_transport_websocket -p open_table_godot -- -D warnings
  ```

---

### 408. UI de Salas y Códigos de Invitación en Godot

**Objetivo:** Adaptar `host_lobby.gd` y crear `join_dialog.gd` para que los jugadores puedan crear salas por Internet, ver su código en grande (con botón de copiar al portapapeles) y unirse con solo escribir el código de 4 caracteres.

- **Archivos:**
  - `godot_project/scenes/host_lobby.gd`
  - `godot_project/scenes/host_lobby.tscn`
  - `godot_project/scenes/main_menu.gd`
- **Especificaciones:**
  - Selector de modo de conexión: "Local (LAN / Direct IP)" o "En Línea (Código de Sala)".
  - Etiqueta destacada con fuente grande y espaciada: `SALA: ABCD`.
  - Botón "Copiar Código" con feedback visual ("¡Copiado!").
  - Diálogo de entrada para 4 letras con validación automática en mayúsculas y botón "Conectar".
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 409. Smoke test automatizado de Relay

**Objetivo:** Crear un test de integración headless en Godot que simule la conexión de dos clientes a través del flujo de Relay y valide la emisión de las señales de sala.

- **Archivos:**
  - `godot_project/tests/relay_smoke.gd`
  - `tools/run_godot_tests.sh`
- **Especificaciones:**
  - Valida generación de código de sala válido (alfanumérico de 4 caracteres).
  - Simula eventos de unión y desconexión de pares.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/relay_smoke.gd 2>&1 | grep -E "PASS|FAIL"
  ```

---

## Bloque 2: Sistema de Guardado, Notación y Replays (Prompts 410–413)

*Problema actual:* Las partidas no pueden pausarse para continuar después, ni pueden guardarse para repasar jugadas clave o compartirse con la comunidad de ajedrez/go.
*Solución viable:* Sistema de guardado y carga serializado en JSON/Bincode en `user://saves/`, exportación a PGN/FEN (Ajedrez) y SGF (Go), y un visor interactivo de repetición.

---

### 410. Exportador estándar PGN/FEN para Ajedrez y SGF para Go

**Objetivo:** Permitir que los tableros de Ajedrez y Go generen las cadenas en notación estándar internacional para permitir análisis en Lichess/Chess.com o KGS/OGS.

- **Archivos:**
  - `chess_game/src/pgn.rs`
  - `go_game/src/sgf.rs`
  - `open_table_godot/src/lib.rs`
  - `godot_project/scenes/chess_board.gd`
  - `godot_project/scenes/go_board.gd`
- **Especificaciones:**
  - Ajedrez: `export_fen(&self) -> String` y `export_pgn(&self, white: &str, black: &str) -> String`.
  - Go: `export_sgf(&self) -> String` con metadatos de tamaño de tablero y secuencia de piedras.
  - En la UI de ambos juegos, agregar botón "Exportar Partida" que copia la notación al portapapeles con una notificación flotante "Copiado al portapapeles".
- **Verificación:**
  ```bash
  cargo test -p chess_game --lib pgn
  cargo test -p go_game --lib sgf
  ```

---

### 411. Gestor centralizado de partidas guardadas (`SaveManager`)

**Objetivo:** Implementar la persistencia de partidas en curso en disco con soporte para múltiples ranuras de guardado y metadatos de reanudación.

- **Archivos:**
  - `godot_project/scripts/save_manager.gd`
  - `godot_project/scenes/save_load_dialog.tscn`
  - `godot_project/scenes/save_load_dialog.gd`
- **Especificaciones:**
  - Guarda en `user://saves/` con formato JSON enriquecido:
    - `save_id`: UUID único.
    - `timestamp`: Fecha/hora de guardado.
    - `game_id`: Identificador del juego (ej. `chess`, `catan_crisis`).
    - `turn_number`: Número de turno alcanzado.
    - `players`: Nombres y puntuaciones.
    - `engine_state`: Snapshot binario/Base64 generado por `Session::serialize_state()`.
  - Métodos: `save_game(slot_name)`, `load_game(save_id)`, `list_saves()`, `delete_save(save_id)`.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/save_replay_smoke.gd 2>&1 | grep -E "PASS|FAIL"
  ```

---

### 412. Visor interactivo de Repeticiones (`ReplayViewer`)

**Objetivo:** Diseñar una escena universal que reciba un log de eventos de partida y permita navegar la partida temporalmente (adelante, atrás, inicio, fin, velocidad automática).

- **Archivos:**
  - `godot_project/scenes/replay_viewer.tscn`
  - `godot_project/scenes/replay_viewer.gd`
  - `godot_project/scenes/main_menu.gd` (botón "Repeticiones" en menú principal)
- **Especificaciones:**
  - Barra de tiempo horizontal interactiva (`HSlider`) que muestra la posición del turno actual.
  - Controles de reproducción: `⏮ Inicio`, `◀ Paso Anterior`, `▶/⏸ Play/Pausa`, `▶ Paso Siguiente`, `⏭ Fin`.
  - Selector de velocidad: 1x, 2x, 4x.
  - Panel lateral con lista de movimientos con scroll automático al turno activo.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 413. Smoke test de Guardado y Replay

**Objetivo:** Validar en headless que una partida jugada en cualquiera de los motores se guarde en disco, se liste correctamente y pueda cargarse restaurando el estado exacto del tablero.

- **Archivos:**
  - `godot_project/tests/save_replay_smoke.gd`
- **Especificaciones:**
  - Inicia partida de damas, ejecuta 3 jugadas, guarda a disco.
  - Limpia el estado, carga el archivo guardado y verifica que el turno y las posiciones coinciden exactamente.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/save_replay_smoke.gd
  ```

---

## Bloque 3: Motor de Audio y Efectos Sonoros (Prompts 414–416)

*Problema actual:* Las partidas son mudas. La sensación táctil y la satisfacción de mover una pieza pesada, tirar dados o cantar jaque requiere retroalimentación acústica inmediata.
*Solución viable:* Sintetizador de audio procedural en GDScript mediante `AudioStreamGenerator` (para no depender de archivos binarios externos pesados) que genera ondas senoidales, ruido blanco modelado para dados y clics percusivos de madera.

---

### 414. Sintetizador de SFX Procedural en `AudioManager`

**Objetivo:** Añadir a `audio_manager.gd` un generador de efectos sonoros procedurales para tableros sin necesidad de assets WAV/OGG externos.

- **Archivos:**
  - `godot_project/scripts/audio_manager.gd`
- **Especificaciones:**
  - Métodos de síntesis de sonido procedural:
    - `play_piece_slide()`: Frecuencia baja con decaimiento rápido (sensación de madera deslizándose).
    - `play_piece_place()`: Golpe percusivo con resonancia corta (pieza de ajedrez/dama colocada).
    - `play_dice_roll()`: Ráfaga de pulsos de ruido con frecuencias aleatorias (dados rodando).
    - `play_card_flip()`: Ruido blanco suave con envolvente aguda (carta de Uno robada/jugada).
    - `play_check_alert()`: Tono dual de campana de atención (jaque).
    - `play_victory_fanfare()`: Arpegio mayor ascendente de tres notas.
    - `play_error_buzz()`: Tono disonante grave corto (movimiento ilegal).
  - Controles de volumen independientes en decibelios para Música y SFX vinculados a `settings_menu.gd`.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/audio_events_smoke.gd
  ```

---

### 415. Conexión de eventos sonoros en los 13 tableros

**Objetivo:** Disparar los efectos sonoros sintetizados en cada interacción clave de los 13 tableros existentes.

- **Archivos:**
  - Todos los `godot_project/scenes/*_board.gd`
- **Especificaciones:**
  - Selección de pieza -> `play_piece_slide()`.
  - Movimiento completado -> `play_piece_place()`.
  - Captura -> `play_piece_place()` con volumen +2dB y partículas.
  - Tirada de dados (Ludo, Backgammon, Monopoly, TEG) -> `play_dice_roll()`.
  - Cartas (Uno, Mille Bornes) -> `play_card_flip()`.
  - Fin de partida -> `play_victory_fanfare()`.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 416. Smoke test de eventos de audio

**Objetivo:** Comprobar que todas las funciones de sonido son invocables de manera segura en modo headless sin provocar fallos de bus de audio ni cuelgues.

- **Archivos:**
  - `godot_project/tests/audio_events_smoke.gd`
- **Especificaciones:**
  - Itera sobre todos los tipos de SFX y valida que las llamadas a `AudioManager` no generan errores ni nulos.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/audio_events_smoke.gd
  ```

---

## Bloque 4: Localización e Internacionalización (Prompts 417–418)

*Problema actual:* Múltiples textos están en español y otros en inglés sin catálogo unificado.
*Solución viable:* Soporte nativo de `tr()` en Godot con archivo `translations.csv` para 4 idiomas clave (Español, Inglés, Portugués, Francés) y selector de idioma en Ajustes.

---

### 417. Catálogo de traducciones multilingüe (`translations.csv`)

**Objetivo:** Crear el archivo de traducciones con todas las claves de interfaz de menús, configuraciones, nombres de juegos, reglas y mensajes de victoria.

- **Archivos:**
  - `godot_project/assets/translations/translations.csv`
  - `godot_project/project.godot` (registrar en sección `[locale]`)
- **Especificaciones:**
  - Columnas: `key,en,es,pt,fr`.
  - Claves para:
    - Menú: `MENU_PLAY`, `MENU_LOCAL`, `MENU_VS_AI`, `MENU_ONLINE`, `MENU_SETTINGS`, `MENU_CREDITS`, `MENU_EXIT`.
    - Reglas y Estado: `STATUS_CHECK`, `STATUS_CHECKMATE`, `STATUS_YOUR_TURN`, `STATUS_WAITING_OPPONENT`.
    - Nombres de los 13 juegos traducidos correctamente a cada idioma.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/hud_and_settings_smoke.gd
  ```

---

### 418. Selector de idioma en tiempo real en `SettingsMenu`

**Objetivo:** Permitir cambiar el idioma del juego desde la pantalla de configuración actualizando dinámicamente toda la interfaz sin reiniciar la aplicación.

- **Archivos:**
  - `godot_project/scenes/settings_menu.gd`
  - `godot_project/scenes/settings_menu.tscn`
- **Especificaciones:**
  - `OptionButton` para seleccionar: English, Español, Português, Français.
  - Guarda la preferencia en `user://settings.cfg`.
  - Llama a `TranslationServer.set_locale(selected_locale)`.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

## Bloque 5: Accesibilidad, Controles y Gamepad (Prompts 419–421)

*Problema actual:* La interacción actual requiere exclusivamente ratón o toque puntual. No hay soporte para pantallas táctiles con tableros densos (Go 19x19, TEG) ni para Steam Deck / mandos de consola.
*Solución viable:* Mapeo de gamepad con selector en cuadrícula y modo para daltónicos.

---

### 419. Soporte de Gamepad y Steam Deck con cursor virtual en tableros

**Objetivo:** Configurar acciones de entrada en `project.godot` para D-pad y joystick analógico que permitan mover un retículo de selección por las casillas del tablero.

- **Archivos:**
  - `godot_project/project.godot` (acciones `ui_gamepad_up`, `down`, `left`, `right`, `select`, `cancel`)
  - `godot_project/scenes/chess_board.gd`
  - `godot_project/scenes/checkers_board.gd`
- **Especificaciones:**
  - Cursor de selección visual resaltado que se desplaza casilla por casilla con la cruceta o stick.
  - Botón A / Cruz: Seleccionar pieza / confirmar destino.
  - Botón B / Círculo: Deseleccionar / cancelar jugada.
  - Botón Start: Abrir menú de pausa.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 420. Controles táctiles de Paneo y Pellizco (Pinch-to-Zoom)

**Objetivo:** Permitir a los jugadores móviles o de pantalla táctil hacer zoom y deslizar en tableros con alta densidad de elementos (Go 19×19, TEG/Crisis y Monopoly).

- **Archivos:**
  - `godot_project/scripts/touch_camera_controller.gd`
  - `godot_project/scenes/go_board.tscn`
  - `godot_project/scenes/crisis_board.tscn`
- **Especificaciones:**
  - Detección de gestos multitáctiles con `InputEventScreenDrag` y `InputEventScreenTouch`.
  - Zoom suave limitado entre 0.8x y 2.5x con anclaje al centro del gesto.
  - Límites de desplazamiento para que el tablero nunca se salga completamente de la vista.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 421. Modo de Alto Contraste y Daltonismo en `ThemeManager`

**Objetivo:** Garantizar que los juegos dependientes del color (Uno, Mille Bornes, Damas Chinas, Ludo) incluyan símbolos o patrones geométricos complementarios para jugadores con protanopía, deuteranopía o tritanopía.

- **Archivos:**
  - `godot_project/scripts/theme_manager.gd`
  - `godot_project/scenes/uno_board.gd`
  - `godot_project/scenes/ludo_board.gd`
- **Especificaciones:**
  - Opción "Modo Accesibilidad Daltónicos" en `SettingsMenu`.
  - Cartas de Uno: añade un icono distintivo según el color (Rojo = Círculo, Azul = Cuadrado, Verde = Triángulo, Amarillo = Estrella).
  - Damas Chinas / Ludo: las fichas incorporan tramas con líneas o puntos para diferenciación no cromática.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

## Bloque 6: Empaquetado, Addon y Distribución SDK (Prompts 422–425)

*Problema actual:* No existe un paquete reutilizable para otros proyectos de Godot ni un pipeline automatizado para exportar binarios finales para Steam/Itch.
*Solución viable:* Estructuración del addon de Godot `addons/open_table/` y workflows de GitHub Actions para compilación cruzada.

---

### 422. Empaquetado como Godot Addon (`addons/open_table/`)

**Objetivo:** Estructurar la biblioteca para que cualquier desarrollador pueda copiar la carpeta `addons/open_table/` a su proyecto y tener acceso inmediato al GDExtension y los nodos de juego.

- **Archivos:**
  - `godot_project/addons/open_table/plugin.cfg`
  - `godot_project/addons/open_table/open_table.gdextension`
  - `godot_project/addons/open_table/README.md`
- **Especificaciones:**
  - Archivo `plugin.cfg` con metadatos: nombre, descripción, versión "1.0.0", autor, script principal.
  - Enlace al `.gdextension` configurado para cargar la librería compilada según la plataforma (`x86_64`, `arm64`, `windows`, `linux`, `macos`, `android`).
- **Verificación:**
  ```bash
  ls -la godot_project/addons/open_table/plugin.cfg
  ```

---

### 423. Documento de Integración Rápida `SDK_QUICKSTART.md`

**Objetivo:** Crear una guía técnica concisa de 15 minutos que explique a desarrolladores externos cómo implementar su propio juego de mesa usando los traits de `open_table_core` y visualizándolo en Godot.

- **Archivos:**
  - `docs/SDK_QUICKSTART.md`
  - `README.md` (añadir enlace destacado al Quickstart)
- **Especificaciones:**
  - Ejemplo completo de juego "Tres en Línea / Tic-Tac-Toe" implementado en menos de 100 líneas de Rust.
  - Implementación del trait `GameEngine`, `State`, `Action`, y `PlayerId`.
  - Registro en `open_table_engine::Session` y conexión con la señal de Godot.
- **Verificación:**
  ```bash
  test -f docs/SDK_QUICKSTART.md
  ```

---

### 424. Script de empaquetado de distribuciones (`tools/package_release.sh`)

**Objetivo:** Crear un script Bash robusto que compile los binarios release de Rust, exporte el proyecto Godot y empaquete los archivos en archivos `.zip` / `.tar.gz` listos para distribución.

- **Archivos:**
  - `tools/package_release.sh`
- **Especificaciones:**
  - Compila `cargo build --release -p open_table_godot`.
  - Crea carpetas `dist/opentable-linux-x86_64/` y `dist/opentable-windows-x86_64/`.
  - Copia los binarios `.so` / `.dll`, assets y ejecutables.
  - Genera sumas de verificación `SHA256SUMS.txt`.
- **Verificación:**
  ```bash
  bash -n tools/package_release.sh
  ```

---

### 425. GitHub Actions Workflow para Releases Automáticos (`.github/workflows/release.yml`)

**Objetivo:** Automatizar la compilación multiplataforma en la nube cada vez que se cree un tag `v*` en el repositorio.

- **Archivos:**
  - `.github/workflows/release.yml`
- **Especificaciones:**
  - Matrix de compilación: `ubuntu-latest` (Linux), `windows-latest` (Windows), `macos-latest` (macOS).
  - Pasos de compilación de Rust (`stable`) y Godot 4 export.
  - Publicación automática de artefactos comprimidos adjuntos al Release de GitHub con changelog generado.
- **Verificación:**
  ```bash
  test -f .github/workflows/release.yml
  ```

---

## Resumen de Prompts por Área (PROMPTS9)

| # | Área | Elemento / Archivo Principal |
|---|------|------------------------------|
| **406** | Conectividad | Crate `open_table_relay` (servidor WebSocket de salas) |
| **407** | Conectividad | Cliente Relay en `open_table_transport_websocket` y bridge |
| **408** | Conectividad | UI de Códigos de Sala en `host_lobby.gd` / `join_dialog.gd` |
| **409** | Conectividad | Smoke test de Relay (`tests/relay_smoke.gd`) |
| **410** | Persistencia | Exportadores PGN/FEN (Ajedrez) y SGF (Go) |
| **411** | Persistencia | `SaveManager` (`save_manager.gd`) y ranuras de guardado |
| **412** | Persistencia | Visor de Repeticiones interactivo (`replay_viewer.tscn`) |
| **413** | Persistencia | Smoke test de guardado y replay (`tests/save_replay_smoke.gd`) |
| **414** | Audio | Sintetizador de audio procedural en `audio_manager.gd` |
| **415** | Audio | Integración de SFX en los 13 tableros de juego |
| **416** | Audio | Smoke test de audio (`tests/audio_events_smoke.gd`) |
| **417** | i18n | Catálogo de traducción `translations.csv` (ES, EN, PT, FR) |
| **418** | i18n | Selector de idioma dinámico en `settings_menu.gd` |
| **419** | Controles | Mapeo y navegación con Gamepad / Steam Deck |
| **420** | Controles | Soporte táctil Paneo y Pellizco (Pinch-to-zoom) |
| **421** | Accesibilidad | Modos de alto contraste y daltonismo en `theme_manager.gd` |
| **422** | Ecosistema | Empaquetado como Godot Addon (`addons/open_table/`) |
| **423** | Ecosistema | Guía de inicio rápido `docs/SDK_QUICKSTART.md` |
| **424** | Distribución | Script de empaquetado `tools/package_release.sh` |
| **425** | Distribución | CI/CD de GitHub Actions (`.github/workflows/release.yml`) |

---

## Criterios de "Proyecto Viable Comercial (v1.1.0)"

Al completar los 20 prompts de `PROMPTS9.md`:
- [ ] Partidas multijugador por Internet sin configurar routers mediante códigos de sala de 4 letras.
- [ ] Guardado y reanudación de partidas en cualquier momento desde el menú.
- [ ] Visor de repetición jugada a jugada para análisis y aprendizaje.
- [ ] Experiencia inmersiva con efectos sonoros táctiles generados en tiempo real.
- [ ] Interfaz completamente traducida a 4 idiomas (Español, Inglés, Portugués, Francés).
- [ ] Navegable con mando (Steam Deck / consola) y gestos táctiles fluidos en dispositivos móviles.
- [ ] Addon listo para importar en cualquier proyecto Godot y documentación Quickstart de 15 minutos.
- [ ] Artefactos ejecutables generados automáticamente en GitHub Releases para Windows, Linux y Mac.
