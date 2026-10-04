# Prompts de Madurez Comercial y Ecosistema — Games Tables SDK (Parte 10)

Continúa desde `PROMPTS9.md` (prompts 406–425). Numerados del **426 al 450**.

**Prerequisito:** PROMPTS9 completado → v1.1.0 etiquetada con relay server funcional, guardado/replay, audio procedural, addon empaquetado y release.yml activo.

**Objetivo:** Llevar OpenTable de un producto *funcional* a un producto *comercialmente maduro y competitivo* en tiendas (Steam, Itch.io, Google Play), con ranking ELO online, torneos, IA mejorada por dificultad, sistema de tutoriales y publicación en crates.io del SDK.

---

## 0. Estado al inicio de PROMPTS10

### Verificado como implementado (PROMPTS9 auditado)

| Elemento | Archivo | Estado |
|----------|---------|--------|
| Relay server WebSocket con room codes | `open_table_relay/` | ✅ (PROMPTS9 completo) |
| SaveManager + ReplayViewer | `save_manager.gd`, `replay_viewer.tscn` | ✅ |
| Audio procedural SFX | `audio_manager.gd` | ✅ |
| Traducciones CSV 4+ idiomas | `godot_project/translations/` | ✅ (8 idiomas) |
| Addon Godot empaquetado | `godot_project/addons/open_table/` | ✅ |
| GitHub Actions release.yml | `.github/workflows/release.yml` | ✅ |
| SDK_QUICKSTART.md | `docs/SDK_QUICKSTART.md` | ✅ |

### Nuevas metas de PROMPTS10

```
┌──────────────────────────────────────────────────────────────────────┐
│                  LOS 5 PILARES DE MADUREZ COMERCIAL                   │
├────────────────────────────┬─────────────────────────────────────────┤
│ 1. Distribución en tiendas │ Steam (Steamworks), Itch.io, Google Play │
│ 2. Competitivo Online      │ ELO server, matchmaking, torneos         │
│ 3. IA por Dificultad       │ Easy/Medium/Hard/Expert en 6 juegos      │
│ 4. Tutoriales y Onboarding │ Guía interactiva primer turno por juego  │
│ 5. SDK en crates.io        │ Publicación pública + web de docs        │
└────────────────────────────┴─────────────────────────────────────────┘
```

---

## Bloque 1: Integración con Steam y Tiendas (Prompts 426–429)

*Problema actual:* Los binarios se generan en GitHub Releases pero no están listos para las tiendas: faltan metadatos de Steam, firma APK para Google Play y assets de marketing.

---

### 426. Integración Steamworks: Achievements y Cloud Saves

**Objetivo:** Conectar el SDK de Steam con el sistema de logros existente (`achievement_manager.gd`) y el `SaveManager` para sincronizar partidas guardadas en Steam Cloud.

- **Archivos:**
  - `Cargo.toml` (workspace — añadir `steamworks = "0.11"` como dep opcional)
  - `open_table_godot/src/steam_bridge.rs` (nuevo)
  - `open_table_godot/src/lib.rs` (registrar funciones de Steam)
  - `godot_project/scripts/steam_manager.gd` (nuevo)
- **Especificaciones:**
  - Feature flag `steam` en `open_table_godot/Cargo.toml` — sin la feature, el crate compila sin dependencia de Steamworks (builds de Itch.io y Android no necesitan Steam).
  - Funciones expuestas al bridge:
    - `steam_init() -> bool` — inicializa la API; devuelve false si no hay Steam en ejecución.
    - `steam_unlock_achievement(id: &str)` — desbloquea un logro por su ID de Steam.
    - `steam_sync_save(slot: &str, data: &[u8])` — sube datos binarios a Steam Cloud bajo la clave `slot`.
    - `steam_load_save(slot: &str) -> Vec<u8>` — descarga datos de Steam Cloud.
  - `steam_manager.gd` llama a `steam_init()` en `_ready()` y conecta `achievement_unlocked` de `achievement_manager.gd` a `steam_unlock_achievement`.
  - El sistema de guardado en `save_manager.gd` detecta si Steam está disponible y sincroniza automáticamente.
- **Verificación:**
  ```bash
  cargo check -p open_table_godot --features steam
  cargo check -p open_table_godot  # sin feature — debe compilar igual
  ```

---

### 427. Assets de Steam y Itch.io (Capsule Art, Descripción, Trailer)

**Objetivo:** Crear los recursos de tienda mínimos para publicar en Steam e Itch.io: descripción en 3 idiomas, checklist de assets gráficos y script de actualización de página vía CLI.

- **Archivos:**
  - `store/steam/description_en.txt`
  - `store/steam/description_es.txt`
  - `store/steam/description_pt.txt`
  - `store/steam/tags.txt`
  - `store/itch/description_en.md`
  - `store/itch/update_page.sh` (usa `butler` CLI de Itch.io)
  - `store/CHECKLIST_ASSETS.md`
- **Especificaciones:**
  - `description_en.txt`: descripción Steam de 4000 caracteres máximo con BBCode. Incluye lista de juegos, características clave (offline/online, cross-platform, SDK para desarrolladores).
  - `tags.txt`: lista de hasta 20 tags de Steam relevantes (Board Game, Strategy, Multiplayer, SDK, 2 Player, Turn-Based, Local Multiplayer, Online Co-Op, etc.).
  - `update_page.sh`: usa `butler push dist/opentable-linux-x86_64/ joduranvillan/opentable:linux-x86_64` y equivalentes para Windows/Mac.
  - `CHECKLIST_ASSETS.md`: tabla con todos los assets visuales requeridos (capsule 460×215, hero 1920×620, screenshots 1280×720 mínimo 5, icon 32×32, trailer MP4).
- **Verificación:**
  ```bash
  test -f store/steam/description_en.txt && wc -c store/steam/description_en.txt
  bash -n store/itch/update_page.sh
  ```

---

### 428. Configuración de Firma APK para Google Play

**Objetivo:** Preparar la infraestructura de firma y metadatos para publicar en Google Play.

- **Archivos:**
  - `store/android/fastlane/Fastfile`
  - `store/android/fastlane/metadata/android/en-US/title.txt`
  - `store/android/fastlane/metadata/android/en-US/short_description.txt`
  - `store/android/fastlane/metadata/android/en-US/full_description.txt`
  - `store/android/fastlane/metadata/android/es-ES/` (idem)
  - `store/android/BUILD_ANDROID.md`
- **Especificaciones:**
  - `Fastfile` con lane `beta` que firma el APK con el keystore (path configurado en `ENV['KEYSTORE_PATH']`) y lo sube a Google Play Internal Testing vía `supply`.
  - `BUILD_ANDROID.md` documenta el proceso completo: generar keystore, configurar `export_presets.cfg` de Godot para Android arm64-v8a, ejecutar `fastlane beta`.
  - Las credenciales (keystore, service account JSON) **no se incluyen en el repo** — se usan GitHub Secrets. `BUILD_ANDROID.md` lista los secrets necesarios: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_PLAY_JSON`.
- **Verificación:**
  ```bash
  test -f store/android/fastlane/Fastfile
  test -f store/android/BUILD_ANDROID.md
  ```

---

### 429. CI/CD Matrix para Android y Web (Godot Export)

**Objetivo:** Extender `.github/workflows/release.yml` para compilar y exportar también la variante Android (APK) y Web (HTML5) de OpenTable al crear un tag `v*`.

- **Archivos:**
  - `.github/workflows/release.yml` (actualizar)
- **Especificaciones:**
  - Añadir job `export-android` que:
    1. Instala Redot 4.5 headless + Android export templates.
    2. Exporta con `redot --headless --export-release "Android" dist/opentable.apk`.
    3. Sube el APK como artefacto del Release.
  - Añadir job `export-web` que:
    1. Exporta con `--export-release "Web"` a `dist/web/`.
    2. Despliega en GitHub Pages (`gh-pages` branch) automáticamente — permite jugar directamente desde el navegador en `joduranvillan.github.io/games_tables_sdk`.
  - Los jobs de Android y Web son independientes entre sí y corren en paralelo con los jobs de Linux/Windows/macOS existentes.
- **Verificación:**
  ```bash
  grep "export-android\|export-web" .github/workflows/release.yml
  ```

---

## Bloque 2: Competitivo Online — ELO, Matchmaking y Torneos (Prompts 430–434)

*Problema actual:* El relay server de PROMPTS9 conecta jugadores pero no recuerda resultados, no hay ranking global ni forma de organizar competencias.

---

### 430. Extensión del Relay con Servicio ELO Persistente

**Objetivo:** Añadir a `open_table_relay` un módulo de ratings ELO que persiste en SQLite y expone una API HTTP mínima para consultar rankings.

- **Archivos:**
  - `open_table_relay/Cargo.toml` (añadir `rusqlite`, `axum`)
  - `open_table_relay/src/elo.rs` (nuevo)
  - `open_table_relay/src/api.rs` (nuevo)
  - `open_table_relay/src/main.rs` (actualizar para arrancar ambos servidores)
- **Especificaciones:**
  - Base de datos SQLite en `./data/ratings.db` (creada automáticamente al arrancar).
  - Tabla `ratings(player_id TEXT PRIMARY KEY, game_id TEXT, elo INTEGER DEFAULT 1200, wins INTEGER, losses INTEGER)`.
  - Protocolo WebSocket extendido:
    - `{"op": "report_result", "winner": "player1", "loser": "player2", "game_id": "chess"}` → actualiza ELO con fórmula estándar K=32.
  - API HTTP en el puerto 8081 (WebSocket sigue en 8080):
    - `GET /rankings/:game_id` → JSON con top-50 jugadores por ELO para ese juego.
    - `GET /player/:player_id` → JSON con todos los ratings del jugador por juego.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay
  cargo check -p open_table_relay
  ```

---

### 431. UI de Ranking Global en Godot

**Objetivo:** Crear una pantalla de tabla de clasificación en Godot que consulte la API HTTP del relay y muestre los top-10 de cada juego.

- **Archivos:**
  - `godot_project/scenes/leaderboard.gd` (nuevo)
  - `godot_project/scenes/leaderboard.tscn` (nuevo)
  - `godot_project/main_menu.gd` (añadir botón "🏆 Clasificación")
- **Especificaciones:**
  - Usa `HTTPRequest` de Godot para llamar `GET /rankings/<game_id>`.
  - `OptionButton` para seleccionar el juego (Chess, Go, Checkers, etc.).
  - Tabla con columnas: Posición, Nombre de jugador, ELO, Victorias, Derrotas.
  - Botón de refresco manual. Indicador de carga visual durante la petición HTTP.
  - Si el relay no está disponible, muestra mensaje "Sin conexión al servidor de ranking".
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 432. Matchmaking por Habilidad en el Relay

**Objetivo:** Añadir una cola de emparejamiento que conecte automáticamente a jugadores con ELO similar (±200 puntos) sin necesidad de códigos de sala manuales.

- **Archivos:**
  - `open_table_relay/src/matchmaking.rs` (nuevo)
  - `open_table_relay/src/main.rs` (integrar)
  - `godot_project/scenes/host_lobby.gd` (añadir opción "Partida Rápida")
- **Especificaciones:**
  - Protocolo WebSocket:
    - `{"op": "queue", "game_id": "chess", "player_id": "alice", "elo": 1450}` → el jugador entra en cola.
    - `{"op": "dequeue"}` → el jugador cancela la búsqueda.
    - Cuando dos jugadores están en cola con ELO |a - b| ≤ 200 y mismo `game_id`, el relay emite a ambos: `{"op": "matched", "room_code": "XKCD", "opponent_elo": 1480}`.
    - Timeout de cola de 60 segundos → si no hay rival, el relay responde `{"op": "queue_timeout"}`.
  - En `host_lobby.gd`, botón "⚡ Partida Rápida" que activa la cola con el ELO local del jugador.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- matchmaking
  ```

---

### 433. Sistema de Torneos con Llaves Eliminatorias

**Objetivo:** Implementar un módulo de torneos que organice brackets de eliminación simple entre 4, 8 o 16 participantes, manejado completamente por el relay.

- **Archivos:**
  - `open_table_relay/src/tournament.rs` (nuevo)
  - `godot_project/scenes/tournament_lobby.gd` (nuevo)
  - `godot_project/scenes/tournament_lobby.tscn` (nuevo)
  - `godot_project/main_menu.gd` (añadir botón "🏟 Torneo")
- **Especificaciones:**
  - Protocolo: `{"op": "create_tournament", "game_id": "chess", "max_players": 8}` → `{"op": "tournament_created", "tournament_id": "T-AB12"}`.
  - Los jugadores se unen con `{"op": "join_tournament", "tournament_id": "T-AB12"}`.
  - Al llenarse, el relay genera el bracket y notifica las parejas de la primera ronda.
  - Al reportar resultado, avanza automáticamente al ganador a la siguiente ronda.
  - UI de `tournament_lobby.gd` muestra el bracket visual con líneas de eliminación y etiquetas de jugadores.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- tournament
  ```

---

### 434. Smoke test de Competitivo Online

**Objetivo:** Test de integración headless que simule el flujo completo: cola → emparejamiento → reporte de resultado → actualización de ELO.

- **Archivos:**
  - `godot_project/tests/competitive_smoke.gd` (nuevo)
- **Especificaciones:**
  - Simula dos clientes que entran en cola para Chess, reciben `matched`, juegan 1 movimiento, y reportan resultado.
  - Verifica que el ELO del ganador aumentó y el del perdedor disminuyó.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/competitive_smoke.gd 2>&1 | grep -E "PASS|FAIL"
  ```

---

## Bloque 3: IA por Niveles de Dificultad (Prompts 435–438)

*Problema actual:* La IA actual usa un único nivel de profundidad en minimax/MCTS. Los principiantes son aplastados; los jugadores avanzados la vencen trivialmente.

---

### 435. Enum `AiDifficulty` y trait `DifficultySettings` en `open_table_core`

**Objetivo:** Definir los 4 niveles de dificultad de forma centralizada y extensible para todos los motores de juego.

- **Archivos:**
  - `open_table_core/src/difficulty.rs` (nuevo)
  - `open_table_core/src/lib.rs` (re-exportar)
- **Especificaciones:**
  ```rust
  #[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
  pub enum AiDifficulty { Easy, Medium, Hard, Expert }

  pub trait DifficultySettings {
      fn max_depth(&self) -> u32;
      fn time_limit_ms(&self) -> u64;
      fn rollouts(&self) -> u32;  // para MCTS (Go, Ludo)
      fn use_opening_book(&self) -> bool;  // para Ajedrez, Shogi, Xiangqi
  }

  impl DifficultySettings for AiDifficulty {
      fn max_depth(&self) -> u32 { match self { Easy => 1, Medium => 3, Hard => 5, Expert => 8 } }
      fn time_limit_ms(&self) -> u64 { match self { Easy => 100, Medium => 500, Hard => 2000, Expert => 10000 } }
      fn rollouts(&self) -> u32 { match self { Easy => 50, Medium => 200, Hard => 800, Expert => 3000 } }
      fn use_opening_book(&self) -> bool { matches!(self, Hard | Expert) }
  }
  ```
- **Verificación:**
  ```bash
  cargo test -p open_table_core
  ```

---

### 436. Dificultad parametrizable en motores Ajedrez, Damas, Go, Shogi, Xiangqi, Ludo

**Objetivo:** Hacer que las funciones de IA en los 6 motores principales acepten `AiDifficulty` como parámetro y ajusten su profundidad/rollouts.

- **Archivos:**
  - `chess_game/src/ai.rs`
  - `checkers_game/src/ai.rs`
  - `go_game/src/ai.rs`
  - `shogi_game/src/ai.rs`
  - `xiangqi_game/src/ai.rs`
  - `ludo_game/src/ai.rs`
  - `open_table_godot/src/lib.rs` (añadir parámetro `difficulty: i64` a funciones `start_local_match_*_vs_ai`)
- **Especificaciones:**
  - Cada función `best_move(state, difficulty: AiDifficulty)` usa `difficulty.max_depth()` para minimax y `difficulty.rollouts()` para MCTS.
  - En `open_table_godot/src/lib.rs`, las funciones `start_local_match_*_vs_ai` aceptan un tercer parámetro `difficulty: i64` (0=Easy, 1=Medium, 2=Hard, 3=Expert) con default 1 si no se pasa.
  - En Easy, la IA en Ajedrez comete un error aleatorio 1 de cada 4 jugadas (movimiento legal pero subóptimo).
- **Verificación:**
  ```bash
  cargo test -p chess_game -- ai
  cargo test -p go_game -- ai
  ```

---

### 437. Selector de Dificultad en el Menú Principal

**Objetivo:** Añadir un `OptionButton` de dificultad al flujo "vs IA" del menú principal que se comunique al bridge al lanzar la partida.

- **Archivos:**
  - `godot_project/main_menu.gd`
- **Especificaciones:**
  - En la ventana de selección de juego vs IA, mostrar: "Dificultad: [Fácil | Normal | Difícil | Experto]".
  - La selección se pasa como cuarto argumento a `bridge.call(ai_method, 1, 2, board_size, difficulty_level)`.
  - Guardar la última dificultad elegida en `user://settings.cfg` como `ai/difficulty`.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 438. Apertura de Libro (Opening Book) para Ajedrez en nivel Hard/Expert

**Objetivo:** Incorporar un libro de aperturas ECO compacto en formato binario para que la IA de Ajedrez en Hard/Expert juegue aperturas teóricas en lugar de generar movimientos desde cero.

- **Archivos:**
  - `chess_game/src/opening_book.rs` (nuevo)
  - `chess_game/data/openings_eco_compact.bin` (nuevo — generar desde PGN públicos ECO A00-E99)
  - `chess_game/src/ai.rs` (integrar)
- **Especificaciones:**
  - El libro almacena posiciones como hash Zobrist → lista de movimientos ponderados por frecuencia de uso.
  - `OpeningBook::lookup(zobrist_hash: u64) -> Option<ChessMove>` — devuelve el mejor movimiento del libro si la posición está cubierta.
  - Máximo 5000 posiciones en el libro para mantener el binario < 100KB.
  - Si `difficulty.use_opening_book()` es false, la función retorna `None` directamente.
- **Verificación:**
  ```bash
  cargo test -p chess_game -- opening_book
  ```

---

## Bloque 4: Sistema de Tutoriales Interactivos (Prompts 439–442)

*Problema actual:* Los usuarios nuevos que no conocen las reglas de Go, Shogi o Xiangqi no tienen guía dentro del juego. El popup de reglas es pasivo; los tutoriales deben ser activos.

---

### 439. Framework de Tutorial Paso a Paso (`TutorialManager`)

**Objetivo:** Crear un sistema genérico que superponga instrucciones textuales, flechas y resaltados sobre el tablero para guiar al jugador en los primeros movimientos.

- **Archivos:**
  - `godot_project/scripts/tutorial_manager.gd` (nuevo)
  - `godot_project/scenes/tutorial_overlay.tscn` (nuevo)
  - `godot_project/scenes/tutorial_overlay.gd` (nuevo)
- **Especificaciones:**
  - `TutorialManager` recibe una lista de pasos tipo `Array[TutorialStep]`:
    ```gdscript
    class TutorialStep:
        var text: String        # Instrucción al jugador
        var highlight_cell: Vector2i  # Casilla a resaltar (-1,-1 = ninguna)
        var arrow_from: Vector2i      # Origen de la flecha indicadora
        var arrow_to: Vector2i        # Destino de la flecha
        var wait_for_action: bool     # Si true, espera clic del usuario antes de avanzar
    ```
  - `tutorial_overlay.tscn`: panel semitransparente con `RichTextLabel` de instrucción, botón "Siguiente ▶", flecha animada (`Line2D`) y resaltado de casilla (`Polygon2D` parpadeante).
  - `TutorialManager.start(steps: Array, board_node: Node)` conecta el overlay al tablero y bloquea las acciones del jugador fuera de las casillas permitidas.
  - Botón "Saltar Tutorial" siempre visible.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 440. Tutorial Interactivo de Ajedrez (8 pasos)

**Objetivo:** Implementar el tutorial de Ajedrez para partidas vs IA o primer arranque, cubriendo movimientos de peón, captura, jaque y enroque.

- **Archivos:**
  - `godot_project/scenes/chess_board.gd` (integrar `TutorialManager`)
  - `godot_project/scripts/tutorials/chess_tutorial.gd` (nuevo)
- **Pasos del tutorial:**
  1. Resaltar e1-e2: "Mueve tu peón del rey dos casillas adelante".
  2. Mostrar las casillas de movimiento válidas del peón.
  3. Guiar al caballo: "El caballo salta en forma de L — intenta moverlo a f3".
  4. Explicar captura con el peón de dama.
  5. Mostrar la pieza del oponente en jaque.
  6. Guiar el enroque corto.
  7. Jaque mate de pastor simplificado.
  8. "¡Felicitaciones! Ahora practica contra la IA en modo Fácil."
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/tutorial_smoke.gd
  ```

---

### 441. Tutoriales de Go y Shogi (versión compacta 5 pasos)

**Objetivo:** Crear tutoriales mínimos para los dos juegos más desconocidos para el público hispanohablante.

- **Archivos:**
  - `godot_project/scripts/tutorials/go_tutorial.gd` (nuevo)
  - `godot_project/scripts/tutorials/shogi_tutorial.gd` (nuevo)
  - `godot_project/scenes/go_board.gd` (integrar)
  - `godot_project/scenes/shogi_board.gd` (integrar)
- **Go (5 pasos):** Colocar piedra → capturar grupo → Ko → Pass → puntuar territorio.
- **Shogi (5 pasos):** Promoción → pieza capturada como propia → movimiento del caballo → jaque → drop piece.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 442. Smoke test de Tutoriales

**Objetivo:** Verificar en headless que los tutoriales cargan sin errores y que `TutorialManager.start()` no provoca null refs.

- **Archivos:**
  - `godot_project/tests/tutorial_smoke.gd` (nuevo)
- **Especificaciones:**
  - Carga `chess_tutorial.gd`, `go_tutorial.gd`, `shogi_tutorial.gd`.
  - Verifica que cada uno tiene al menos 3 pasos definidos.
  - Instancia `TutorialOverlay` y llama `start([])` — debe terminar sin error.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/tutorial_smoke.gd 2>&1 | grep -E "PASS|FAIL"
  ```

---

## Bloque 5: Publicación del SDK en crates.io y Web de Documentación (Prompts 443–447)

*Problema actual:* `open_table_core` y `open_table_engine` son la propuesta de valor del SDK pero no están publicados en crates.io ni tienen documentación web navegable. Los estudios interesados no pueden descubrirlos.

---

### 443. Preparación de `open_table_core` para publicación en crates.io

**Objetivo:** Verificar y completar todos los metadatos y restricciones de publicación en el crate central.

- **Archivos:**
  - `open_table_core/Cargo.toml`
  - `open_table_core/src/lib.rs` (doc de nivel de crate)
- **Especificaciones:**
  - Campos obligatorios en `Cargo.toml`:
    ```toml
    [package]
    name = "open_table_core"
    version = "1.0.0"
    authors = ["joduranvillan"]
    license = "MIT"
    description = "Core traits and types for turn-based board game engines"
    repository = "https://github.com/joduranvillan/games_tables_sdk"
    keywords = ["board-game", "game-engine", "sdk", "chess", "go"]
    categories = ["game-engines", "game-development"]
    edition = "2021"
    rust-version = "1.82"
    ```
  - Doc de nivel de módulo en `lib.rs` con ejemplo de código ejecutable (`/// # Examples` con `cargo test --doc`).
  - `cargo publish --dry-run -p open_table_core` devuelve exit 0.
- **Verificación:**
  ```bash
  cargo publish --dry-run -p open_table_core 2>&1 | tail -5
  cargo test --doc -p open_table_core
  ```

---

### 444. Publicación de `open_table_engine` y sus dependencias

**Objetivo:** Publicar en orden correcto en crates.io: `open_table_core` → `open_table_macros` → `open_table_engine`.

- **Archivos:**
  - `open_table_engine/Cargo.toml`
  - `open_table_macros/Cargo.toml`
  - `tools/publish_sdk.sh` (nuevo)
- **Especificaciones:**
  - `publish_sdk.sh`:
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    cargo publish -p open_table_core
    sleep 30  # esperar propagación a crates.io
    cargo publish -p open_table_macros
    sleep 30
    cargo publish -p open_table_engine
    echo "SDK published successfully"
    ```
  - Las dependencias internas deben referenciar la versión publicada, no `path`:
    ```toml
    # open_table_engine/Cargo.toml
    [dependencies]
    open_table_core = { version = "1.0.0", path = "../open_table_core" }
    # La sintaxis path+version es válida para publicar con path local + versión remota
    ```
- **Verificación:**
  ```bash
  bash -n tools/publish_sdk.sh
  cargo publish --dry-run -p open_table_engine
  ```

---

### 445. Web de Documentación con mdBook

**Objetivo:** Generar una web de documentación estática en `https://joduranvillan.github.io/games_tables_sdk/` que combine la guía de usuario, el quickstart del SDK, y la referencia API generada por `rustdoc`.

- **Archivos:**
  - `docs/book.toml`
  - `docs/src/SUMMARY.md`
  - `docs/src/introduction.md`
  - `docs/src/quickstart.md` (symlink a `../SDK_QUICKSTART.md`)
  - `docs/src/architecture.md`
  - `docs/src/games/` (páginas por juego)
  - `.github/workflows/docs.yml` (nuevo)
- **Especificaciones:**
  - `book.toml`:
    ```toml
    [book]
    title = "OpenTable SDK"
    authors = ["joduranvillan"]
    language = "en"
    [output.html]
    git-repository-url = "https://github.com/joduranvillan/games_tables_sdk"
    ```
  - `docs.yml` de GitHub Actions: dispara en push a `main`, ejecuta `mdbook build docs/`, publica el output `docs/book/` a `gh-pages`.
  - `architecture.md`: diagrama ASCII de la arquitectura de capas del SDK (core → engine → games → bridge → Godot).
- **Verificación:**
  ```bash
  mdbook build docs/ && echo "BUILD OK"
  test -f .github/workflows/docs.yml
  ```

---

### 446. Integración de `cargo doc` en la Web de Documentación

**Objetivo:** Incluir la referencia de API de Rust generada por `cargo doc` dentro de la misma web de mdBook para que los desarrolladores tengan un solo punto de entrada.

- **Archivos:**
  - `docs/src/api_reference.md`
  - `.github/workflows/docs.yml` (actualizar)
- **Especificaciones:**
  - En el job de `docs.yml`, tras `mdbook build`:
    ```bash
    cargo doc --workspace --exclude open_table_godot --no-deps
    cp -r target/doc docs/book/api/
    ```
  - `api_reference.md` contiene un iframe o enlace directo a `api/open_table_core/index.html`.
- **Verificación:**
  ```bash
  cargo doc --workspace --exclude open_table_godot --no-deps 2>&1 | grep "^error" | wc -l
  ```

---

### 447. Smoke test de CI completo PROMPTS10

**Objetivo:** Verificar el estado de todos los nuevos sistemas de PROMPTS10 en un solo script de CI.

- **Archivos:**
  - `tools/verify_p10.sh` (nuevo)
- **Especificaciones:**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  echo "=== 1. Rust checks ==="
  cargo clippy --workspace --exclude open_table_godot -- -D warnings
  cargo test --workspace --exclude open_table_godot
  cargo doc --workspace --exclude open_table_godot --no-deps 2>&1 | grep "^error" | (! grep .)

  echo "=== 2. Relay server ==="
  cargo test -p open_table_relay

  echo "=== 3. Publish dry-run ==="
  cargo publish --dry-run -p open_table_core

  echo "=== 4. Godot tests ==="
  tools/run_godot_tests.sh

  echo "=== 5. Store assets ==="
  test -f store/steam/description_en.txt
  test -f store/android/fastlane/Fastfile

  echo "=== 6. Docs ==="
  mdbook build docs/

  echo "ALL CHECKS PASSED"
  ```
- **Verificación:**
  ```bash
  bash tools/verify_p10.sh
  ```

---

## Resumen de Prompts PROMPTS10

| # | Área | Elemento Principal |
|---|------|--------------------|
| **426** | Tiendas | Steamworks: achievements + cloud saves en `open_table_godot` |
| **427** | Tiendas | Assets Steam/Itch.io: descripciones, tags, `butler` script |
| **428** | Tiendas | Google Play: Fastfile de firma APK + BUILD_ANDROID.md |
| **429** | CI/CD | Release.yml extendido: export Android APK + Web/HTML5 |
| **430** | Competitivo | ELO persistente en SQLite dentro del relay + API HTTP |
| **431** | Competitivo | UI Leaderboard en Godot (`leaderboard.tscn`) |
| **432** | Competitivo | Matchmaking por habilidad (±200 ELO) en el relay |
| **433** | Competitivo | Sistema de torneos con brackets eliminatorios |
| **434** | Competitivo | Smoke test de flujo competitivo completo |
| **435** | IA | Enum `AiDifficulty` + trait `DifficultySettings` en `open_table_core` |
| **436** | IA | Dificultad parametrizable en 6 motores (Chess, Checkers, Go, Shogi, Xiangqi, Ludo) |
| **437** | IA | Selector de dificultad en menú principal de Godot |
| **438** | IA | Opening book ECO compacto para Ajedrez (Hard/Expert) |
| **439** | Tutorial | Framework `TutorialManager` + `TutorialOverlay` genérico |
| **440** | Tutorial | Tutorial interactivo de Ajedrez (8 pasos) |
| **441** | Tutorial | Tutoriales compactos de Go y Shogi (5 pasos c/u) |
| **442** | Tutorial | Smoke test de tutoriales en headless |
| **443** | SDK | `open_table_core` listo para crates.io (metadatos + doctests) |
| **444** | SDK | Publicación de `open_table_engine` + script `publish_sdk.sh` |
| **445** | SDK | Web de documentación mdBook en GitHub Pages |
| **446** | SDK | `cargo doc` integrado en la web de mdBook como `/api/` |
| **447** | SDK | Script de verificación CI completo `tools/verify_p10.sh` |

*Total acumulado al finalizar PROMPTS10: 447 prompts.*

---

## Criterios de "Producto Comercialmente Maduro (v2.0.0)"

Al completar los 22 prompts de `PROMPTS10.md`:

- [ ] Página de Steam con descripción, tags, screenshots y trailer (aunque sea en Early Access).
- [ ] APK firmado disponible en Google Play Internal Testing.
- [ ] Web desplegada en `joduranvillan.github.io/games_tables_sdk` con guía y referencia API.
- [ ] `open_table_core` y `open_table_engine` publicados en crates.io.
- [ ] Ranking global ELO consultable desde el juego para al menos 3 juegos.
- [ ] Matchmaking automático sin necesidad de códigos de sala.
- [ ] Sistema de torneos para 4-16 jugadores funcional.
- [ ] IA con 4 niveles de dificultad en los 6 juegos principales.
- [ ] Tutoriales interactivos para Ajedrez, Go y Shogi.
- [ ] Release.yml genera binarios para Linux, Windows, macOS, Android y Web en cada tag.
