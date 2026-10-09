# Prompts de Viabilidad Comercial y Lanzamiento Global — Games Tables SDK (Parte 12)

Continúa desde `PROMPTS11.md` (prompts 448–468, con el Bloque 4 social omitido por decisión de alcance). Numerados del **469 al 495**.

**Prerequisito:** PROMPTS11 completado (Bloques 1, 2, 3 y 5) → Relay endurecido con TLS/WSS, JWT, rate limiting, anti-cheat inicial y métricas Prometheus/Grafana; plugins nativos móviles (`.aar` Android y `.xcframework` iOS) compilando en CI; motores de IA con 4 niveles de dificultad en los **13 juegos**; exportación/importación de replays `.otr` y modo espectador online.

**Objetivo:** Cerrar todas las brechas técnicas, de producto, empaquetado, UX y cumplimiento legal necesarias para lanzar **OpenTable** en producción como un producto comercialmente viable, auto-sostenible y listo para publicación inmediata en **Steam, Itch.io, Google Play, Apple App Store, Web (WASM) y crates.io**, sin depender de funciones de red social (chat/amigos).

---

## 0. Estado al inicio de PROMPTS12

### Verificado como implementado (PROMPTS11 auditado)

| Elemento | Archivo | Estado |
|----------|---------|--------|
| Relay TLS/WSS + Autenticación JWT (`HS256`) | `open_table_relay/src/tls.rs`, `auth.rs` | ✅ |
| Rate limiting por IP (30 msg/s) y sala (60 msg/s) + IP ban | `open_table_relay/src/rate_limit.rs` | ✅ |
| Anti-cheat autoritativo en Relay (Chess y Checkers) | `open_table_relay/src/anticheat.rs` | ✅ |
| Contenedor Docker + nginx WSS + Prometheus/Grafana | `open_table_relay/Dockerfile`, `metrics.rs` | ✅ |
| Plugins nativos Android (`.aar`) e iOS (`.xcframework`) en CI | `platform_plugins/`, `.github/workflows/ci.yml` | ✅ |
| `GodotRawByteLink` real en bridge + smoke test P2P | `open_table_godot/src/native_link.rs` | ✅ |
| Motores de IA para los 13 juegos del catálogo | `*/src/ai.rs`, `open_table_godot/src/lib.rs` | ✅ |
| Exportar/Importar Replays (`.otr` gzip JSON) | `godot_project/scripts/save_manager.gd` | ✅ |
| Modo Espectador en partidas online Relay (límite 10) | `open_table_relay/src/room.rs`, `spectator_view.gd` | ✅ |
| Gate de verificación CI `verify_p11.sh` | `tools/verify_p11.sh` | ✅ |
| Bloque 4 de PROMPTS11 (Amigos / Chat / Perfiles) | — | ⏭️ Omitido por alcance |

### Arquitectura de Viabilidad Comercial (v3.0.0)

```
┌────────────────────────────────────────────────────────────────────────────┐
│                LOS 6 PILARES DE VIABILIDAD COMERCIAL (v3.0.0)              │
├────────────────────────────┬───────────────────────────────────────────────┤
│ 1. Relay Autoritativo v2   │ Anti-cheat en los 13 juegos, ELO automático   │
│                            │ sin spoofing, reconexión (rejoin), reloj/AFK  │
│ 2. Red Cero-Fricción       │ Guest JWT automático, LAN UDP discovery,      │
│                            │ selector de Relay en vivo y auto-reconnect    │
│ 3. Empaquetado Real        │ export_presets.cfg canónico, .gdextension     │
│                            │ multiplataforma, branding suite, AAB y VDF    │
│ 4. UX Completa 13 Juegos   │ Reglas in-game 13/13, tutoriales clave,       │
│                            │ reloj visual, rendición/tablas y deshacer     │
│ 5. Steam Deck & Móvil      │ Soporte Gamepad completo, daltonismo/escala,  │
│                            │ safe-area móvil y vibración háptica           │
│ 6. Legal, QA & Lanzamiento │ Privacidad/GDPR in-app, licencias OSS,        │
│                            │ diagnóstico de errores y test de carga Relay  │
└────────────────────────────┴───────────────────────────────────────────────┘
```

---

## Bloque 1: Autoridad del Servidor, Reconexión Online y Onboarding Sin Fricción (Prompts 469–474)

*Problema actual:*
1. El Relay exige JWT si `JWT_SECRET` está activo, pero el cliente Godot no tiene un endpoint para obtener un token de invitado automáticamente al abrir el juego.
2. Solo Ajedrez y Damas validan jugadas en el servidor; en los otros 11 juegos o en el reporte de resultados (`report_result`), un cliente modificado podría enviar comandos inválidos o falsificar victorias para inflar su ELO.
3. Si un jugador sufre un micro-corte de Wi-Fi o su rival se queda inactivo (AFK), la partida online queda bloqueada indefinidamente.

---

### 469. Emisión de JWT de Invitado (`POST /auth/guest`) y Cliente de Identidad en Godot

**Objetivo:** Permitir que cualquier instancia del juego obtenga automáticamente un JWT firmado de invitado (con identidad persistente en el dispositivo) sin requerir registro con correo ni contraseñas.

- **Archivos:**
  - `open_table_relay/src/auth.rs` (añadir generador de tokens firmados con expiración de 7 días)
  - `open_table_relay/src/api.rs` (añadir ruta `POST /auth/guest`)
  - `godot_project/scripts/auth_client.gd` (nuevo — autoload o servicio de identidad)
  - `godot_project/project.godot` (registrar `AuthClient` en `[autoload]`)
- **Especificaciones:**
  - `POST /auth/guest` recibe `{"device_id": "<uuid_persistente>"}` y devuelve `{"token": "<jwt>", "player_id": "guest_<hash8>", "expires_at": 1735689600}`.
  - Si `JWT_SECRET` no está configurado en el servidor, devuelve un token de desarrollo válido en modo local.
  - `auth_client.gd` genera un UUID v4 en el primer arranque, lo guarda en `user://identity.cfg`, solicita el JWT al Relay y lo renueva automáticamente si faltan menos de 24 horas para expirar.
  - Al conectar por WebSocket al Relay, el cliente envía automáticamente `{"op": "auth", "token": "<jwt>"}` como primer mensaje.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- guest_auth
  tools/run_godot_tests.sh
  ```

---

### 470. Validación Anti-Cheat Autoritativa para los 13 Juegos en el Relay

**Objetivo:** Extender `AntiCheatSession` en `open_table_relay` para que valide las jugadas de los **13 juegos** del catálogo utilizando sus motores deterministas de Rust.

- **Archivos:**
  - `open_table_relay/Cargo.toml` (añadir `go_game`, `shogi_game`, `xiangqi_game`, `backgammon_game`, `battleship_game`, `ludo_game`, `mille_bornes_game`, `monopoly_game`, `uno_game`, `crisis_game`, `chinese_checkers_game`)
  - `open_table_relay/src/anticheat.rs` (extender `AntiCheatSession::for_game` y `validate_and_apply`)
- **Especificaciones:**
  - Soportar los 13 identificadores canónicos: `"chess"`, `"checkers"`, `"go"`, `"shogi"`, `"xiangqi"`, `"backgammon"`, `"battleship"`, `"ludo"`, `"mille_bornes"`, `"monopoly"`, `"uno"`, `"crisis"`, `"chinese_checkers"`.
  - Al crear la sala (`create_room` o matchmaking), el servidor inicializa la `Session` con una semilla (`seed`) generada por el servidor y enviada a ambos clientes en `room_created` / `joined_room` para garantizar sincronización determinista de dados y mazos.
  - Cualquier comando que viole las reglas o el turno activo es rechazado con `{"op": "move_rejected", "reason": "illegal_move"}`.
  - Exponer método `AntiCheatSession::winner(&self) -> Option<PlayerId>` para consultar si la sesión autoritativa ha terminado.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- anticheat
  ```

---

### 471. Actualización Automática de ELO desde el Motor del Servidor (Anti-Spoofing)

**Objetivo:** Calcular y persistir los cambios de ELO automáticamente cuando el `AntiCheatSession` del servidor detecta `GameOver` o rendición verificada, impidiendo que un cliente falsifique `report_result`.

- **Archivos:**
  - `open_table_relay/src/room.rs` (registrar `authenticated_player_id` por participante y estado `elo_reported: bool`)
  - `open_table_relay/src/main.rs` (disparar actualización de ELO al terminar partida autoritativa o por `op: "resign"`)
- **Especificaciones:**
  - Cuando un movimiento válido produce un ganador en `AntiCheatSession`, el servidor actualiza automáticamente los ratings ELO de ambos jugadores en SQLite y emite `{"op": "elo_updated", "winner": "...", "loser": "...", "winner_elo": 1216, "loser_elo": 1184}` a toda la sala.
  - Añadir soporte para `{"op": "resign"}`: el emisor pierde inmediatamente la partida y el servidor adjudica la victoria al oponente.
  - Si un cliente envía `{"op": "report_result"}` en una sala con `AntiCheatSession` activa que aún no ha finalizado, el servidor rechaza el mensaje con `{"op": "error", "reason": "match_not_finished"}`.
  - Garantizar idempotencia (`elo_reported = true`) para que una misma sala nunca actualice el ELO más de una vez.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- elo_autoverify
  ```

---

### 472. Reconexión de Sesión en Sala Relay (`rejoin_room`) con Historial de Eventos

**Objetivo:** Permitir que un jugador desconectado accidentalmente vuelva a unirse a su sala activa dentro de una ventana de gracia de 90 segundos y recupere el estado exacto de la partida.

- **Archivos:**
  - `open_table_relay/src/room.rs` (añadir buffer de comandos aplicados `command_log: Vec<Value>`, estado `Disconnected { since: Instant }` y método `rejoin_room`)
  - `open_table_relay/src/main.rs` (manejar `{"op": "rejoin_room", "room_code": "ABCD", "player_id": "..."}`)
- **Especificaciones:**
  - Al cerrarse el socket de un jugador en una partida en curso, la sala no se destruye inmediatamente: marca el asiento como desconectado durante 90 segundos y notifica al rival `{"op": "opponent_disconnected", "grace_seconds": 90}`.
  - Si el jugador se reconecta y envía `{"op": "rejoin_room", "room_code": "ABCD"}` con su `player_id` autenticado antes de 90 segundos:
    1. Recupera su asiento original (`player_id` 1 o 2).
    2. Recibe `{"op": "rejoined", "room_code": "ABCD", "seed": 12345, "commands": [...]}` con la lista ordenada de comandos validados hasta el momento.
    3. El rival recibe `{"op": "opponent_reconnected"}`.
  - Si expiran los 90 segundos sin reconexión, el jugador conectado gana por abandono.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- rejoin
  ```

---

### 473. Reloj de Turno Autoritativo en el Servidor y Victoria por Timeout (Anti-AFK)

**Objetivo:** Evitar partidas eternas por jugadores inactivos implementando un temporizador por turno configurable al crear la sala.

- **Archivos:**
  - `open_table_relay/src/room.rs` (añadir `turn_timeout_secs: u64`, `last_move_at: Instant`, `active_turn_seat: u32`)
  - `open_table_relay/src/main.rs` (tarea periódica cada 1s que verifica timeouts de turno y desconexiones expiradas)
- **Especificaciones:**
  - En `create_room`, aceptar parámetro opcional `"turn_timeout_secs"` (por defecto `120` segundos; presets soportados: `30` Blitz, `60` Rápido, `120` Estándar, `0` Sin límite en salas privadas).
  - En partidas de matchmaking (`queue`), fijar `turn_timeout_secs = 60`.
  - Si el jugador en turno supera `turn_timeout_secs` sin enviar un movimiento válido, el Relay declara ganador al oponente, actualiza ELO y emite `{"op": "match_timeout", "winner_seat": 1, "reason": "turn_timeout"}`.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- timeout
  ```

---

### 474. Limpieza Automática de Salas Inactivas y Apagado Ordenado (Graceful Shutdown)

**Objetivo:** Asegurar que el servidor Relay pueda correr durante meses sin fugas de memoria y cierre conexiones limpiamente ante `SIGTERM`/`SIGINT` en Docker.

- **Archivos:**
  - `open_table_relay/src/room.rs` (añadir `RoomManager::prune_stale_rooms(max_idle: Duration)`)
  - `open_table_relay/src/main.rs` (manejar `tokio::signal::ctrl_c` / `SIGTERM` y recolector periódico cada 60s)
- **Especificaciones:**
  - Eliminar automáticamente salas que lleven más de 30 minutos sin actividad (`last_activity_at`).
  - Limpiar entradas expiradas de `RateLimitManager` cada 5 minutos para acotar el uso de RAM.
  - Al recibir señal de parada (`SIGINT`/`SIGTERM`), enviar `{"op": "server_shutting_down"}` a los clientes conectados, hacer flush de SQLite (`WAL checkpoint`) y terminar con código `0`.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- prune_stale
  ```

---

## Bloque 2: Red Local Cero-Fricción (LAN Discovery) y Conectividad Resiliente en Cliente (Prompts 475–478)

*Problema actual:* En modo LAN TCP, el jugador cliente debe conocer y teclear manualmente la IP local del host (o escanear un QR con cámara). Además, la URL del Relay está fija en código y si hay un corte momentáneo el cliente WebSocket no reintenta.

---

### 475. Auto-Descubrimiento de Partidas en Red Local (UDP Broadcast / LAN Beacon)

**Objetivo:** Permitir que los dispositivos en la misma red Wi-Fi descubran automáticamente las partidas LAN abiertas sin escribir direcciones IP.

- **Archivos:**
  - `godot_project/scripts/lan_discovery.gd` (nuevo — emisor y receptor UDP en puerto `42423`)
  - `godot_project/scenes/host_lobby.gd` (integrar lista de "Salas en tu Wi-Fi" con unión en 1 clic)
- **Especificaciones:**
  - Cuando un host inicia una partida TCP local, `lan_discovery.gd` emite cada 1.5 segundos un paquete UDP broadcast (`255.255.255.255:42423`) con JSON: `{"magic": "OPENTABLE_LAN_V1", "host_name": "...", "game_id": "chess", "port": 7000, "players": "1/2"}`.
  - En modo cliente, `lan_discovery.gd` escucha en el puerto `42423`, mantiene una tabla de salas activas (expiran si no se recibe beacon en 5 segundos) y emite la señal `lan_rooms_updated(rooms: Array)`.
  - `host_lobby.gd` muestra las salas LAN detectadas con un botón "Unirse" que conecta directamente a `<ip_origen>:<port>`.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 476. Configuración de Servidor Relay en Vivo y Diagnóstico de Salud (`GET /health`)

**Objetivo:** Permitir configurar la URL del servidor Relay desde el menú de Ajustes con un botón de "Probar Conexión" que mida la latencia (ping HTTP/WS).

- **Archivos:**
  - `open_table_relay/src/api.rs` (añadir ruta `GET /health` que retorna `{"status": "ok", "version": "0.1.0", "active_rooms": N}`)
  - `godot_project/scenes/settings_menu.gd` (añadir campo `Relay Server URL`, botón `Probar Conexión` y persistencia en `user://settings.cfg`)
- **Especificaciones:**
  - `GET /health` responde con HTTP 200 y JSON con estado del servidor, versión y número de salas activas.
  - En `settings_menu.gd`, el usuario puede cambiar la URL del Relay (por defecto `ws://127.0.0.1:8080` en dev o el dominio configurado en producción) y pulsar "Probar Conexión", mostrando el RTT en milisegundos (ej. `Conectado — 28 ms`).
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- health
  tools/run_godot_tests.sh
  ```

---

### 477. Reconexión Automática con Backoff Exponencial en el Cliente WebSocket

**Objetivo:** Integrar el flujo de `rejoin_room` en `open_table_transport_websocket` y el bridge de Godot para que un corte breve de red se recupere de forma transparente para el usuario.

- **Archivos:**
  - `open_table_transport_websocket/src/client.rs` (añadir estado de reconexión con backoff `500ms`, `1s`, `2s`, `4s`, hasta 5 intentos)
  - `open_table_godot/src/lib.rs` (exponer señales `connection_reconnecting(attempt: i64)` y `connection_restored()`)
  - `godot_project/network_status_hud.gd` (mostrar banner "Reconectando (intento X/5)..." y ocultar al restaurar)
- **Especificaciones:**
  - Si la conexión WebSocket cae inesperadamente durante una partida activa, el cliente intenta reconectar automáticamente al mismo `room_code` enviando `{"op": "rejoin_room"}`.
  - El HUD de red informa visualmente del estado sin expulsar al jugador al menú principal a menos que fallen los 5 intentos.
- **Verificación:**
  ```bash
  cargo test -p open_table_transport_websocket
  cargo check -p open_table_godot
  ```

---

### 478. Smoke Test de Viabilidad Online (Guest Auth + Rejoin + LAN Discovery)

**Objetivo:** Verificar en modo headless el ciclo completo de identidad de invitado, descubrimiento LAN y reconexión.

- **Archivos:**
  - `godot_project/tests/online_viability_smoke.gd` (nuevo)
- **Especificaciones:**
  - Verifica que `auth_client.gd` genera y persiste un `device_id` válido.
  - Instancia dos nodos `lan_discovery.gd` en loopback, emite un anuncio de sala y comprueba que el receptor detecta la partida.
  - Imprime `PASS: online_viability_smoke.gd OK`.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/online_viability_smoke.gd 2>&1 | grep "PASS"
  ```

---

## Bloque 3: Empaquetado Comercial, Branding Unificado y Exportación Multiplataforma (Prompts 479–483)

*Problema actual:* `project.godot` aún tiene `config/name="OpenTable — Damas"`, falta `export_presets.cfg` en el repositorio para que Godot/Redot exporte binarios reales sin fallbacks, y `.gdextension` solo declara un subconjunto de arquitecturas.

---

### 479. Identidad Visual Unificada de la Suite (`OpenTable`) e Íconos Multi-Resolución

**Objetivo:** Actualizar el nombre, metadatos e ícono principal del proyecto Godot para reflejar la colección completa de 13 juegos de mesa.

- **Archivos:**
  - `godot_project/assets/icons/opentable_suite.svg` (nuevo — emblema vectorial de la suite con tablero, dados y cartas)
  - `godot_project/project.godot` (actualizar `config/name="OpenTable — 13 Classic Board & Card Games"`, `config/icon`, `boot_splash/image`)
- **Especificaciones:**
  - `opentable_suite.svg`: diseño vectorial limpio en tonos dorado y pizarra oscura, legible desde 32×32 hasta 1024×1024.
  - Actualizar `project.godot` para usar `res://assets/icons/opentable_suite.svg` como ícono de aplicación y splash screen.
- **Verificación:**
  ```bash
  test -f godot_project/assets/icons/opentable_suite.svg
  grep "OpenTable" godot_project/project.godot
  ```

---

### 480. Manifiesto `.gdextension` Multiplataforma Completo (Desktop, Android, iOS, Web)

**Objetivo:** Declarar todas las bibliotecas dinámicas por plataforma y arquitectura en `open_table.gdextension`, incluyendo las dependencias de los plugins nativos móviles.

- **Archivos:**
  - `godot_project/open_table.gdextension` (actualizar)
  - `godot_project/addons/open_table/open_table.gdextension` (sincronizar)
- **Especificaciones:**
  - Soportar en `[libraries]`:
    - `linux.debug.x86_64`, `linux.release.x86_64`, `linux.release.arm64`
    - `windows.debug.x86_64`, `windows.release.x86_64`
    - `macos.debug`, `macos.release`
    - `android.debug.arm64`, `android.release.arm64`, `android.release.x86_64`
    - `ios.debug.arm64`, `ios.release.arm64`
    - `web.debug.threads.wasm32`, `web.release.threads.wasm32`
- **Verificación:**
  ```bash
  grep "android.release.arm64" godot_project/open_table.gdextension
  grep "ios.release.arm64" godot_project/addons/open_table/open_table.gdextension
  ```

---

### 481. Configuración Canónica de Exportación `export_presets.cfg`

**Objetivo:** Proveer el archivo `godot_project/export_presets.cfg` versionado en Git con los presets listos para exportar en CI y en máquinas de desarrollo sin abrir el editor gráfico.

- **Archivos:**
  - `godot_project/export_presets.cfg` (nuevo)
- **Especificaciones:**
  - Definir 6 presets con nombres exactos consumidos por CI:
    1. `"Linux/X11"` (`runnable=true`, `binary_format/architecture="x86_64"`)
    2. `"Windows Desktop"` (`binary_format/architecture="x86_64"`)
    3. `"macOS"` (`binary_format/architecture="universal"`, bundle identifier `io.opentable.suite`)
    4. `"Android"` (`package/unique_name="io.opentable.suite"`, `version/code=210`, permisos `INTERNET`, `BLUETOOTH`, `ACCESS_WIFI_STATE`, `NEARBY_WIFI_DEVICES`, plugin `OpenTableNearby` habilitado)
    5. `"iOS"` (`application/bundle_identifier="io.opentable.suite"`, `NSLocalNetworkUsageDescription` y `NSBonjourServices` configurados para MultipeerConnectivity)
    6. `"Web"` (`vram_texture_compression/for_desktop=true`, `html/canvas_resize_policy=2`)
- **Verificación:**
  ```bash
  test -f godot_project/export_presets.cfg
  grep -c '\[preset\.[0-9]\+\]' godot_project/export_presets.cfg
  ```

---

### 482. Pipeline de Release Consolidado con Artefactos Nativos Reales (`.github/workflows/release.yml`)

**Objetivo:** Actualizar `.github/workflows/release.yml` para que compile los plugins nativos Android (`.aar`) e iOS (`.xcframework`), los inyecte en `godot_project/addons/` antes de exportar, y verifique el proyecto con `verify_p12.sh`.

- **Archivos:**
  - `.github/workflows/release.yml` (actualizar)
- **Especificaciones:**
  - En el job `export-android`, compilar `libopen_table_godot.so` para `aarch64-linux-android` y `OpenTableNearby-release.aar` antes de invocar el exportador de Godot/Redot.
  - Añadir generación de **Android App Bundle (`opentable.aab`)** además del `opentable.apk` (Google Play exige `.aab` para nuevas aplicaciones).
- **Verificación:**
  ```bash
  grep "opentable.aab" .github/workflows/release.yml
  ```

---

### 483. Scripts de Subida Automática a SteamPipe (`app_build.vdf`) y Google Play AAB

**Objetivo:** Incluir las configuraciones de Steamworks SDK (`steamcmd` VDFs) para subir builds de Linux, Windows y macOS a Steam con un solo comando.

- **Archivos:**
  - `store/steam/app_build.vdf` (nuevo)
  - `store/steam/depot_build_linux.vdf` (nuevo)
  - `store/steam/depot_build_windows.vdf` (nuevo)
  - `store/steam/depot_build_macos.vdf` (nuevo)
  - `store/steam/upload_steam.sh` (nuevo)
  - `store/android/fastlane/Fastfile` (actualizar para soportar subida de `.aab` con `supply(aab: ...)`)
- **Especificaciones:**
  - `app_build.vdf` parametrizado con `AppID` y depots para Windows, Linux y macOS apuntando a `../../dist/`.
  - `upload_steam.sh` ejecuta `steamcmd +login "$STEAM_USER" +run_app_build "$PWD/store/steam/app_build.vdf" +quit`.
- **Verificación:**
  ```bash
  test -f store/steam/app_build.vdf
  bash -n store/steam/upload_steam.sh
  ```

---

## Bloque 4: Experiencia de Juego Comercial en los 13 Tableros (Prompts 484–488)

*Problema actual:* Solo 4 juegos tienen botón de Reglas dentro del tablero, faltan controles estándar de juegos de mesa competitivos (Rendirse, Ofrecer Tablas, Deshacer en modo local, Reloj visual de turno) y una vista de estadísticas locales por juego.

---

### 484. Catálogo Completo de Reglas In-Game para los 13 Juegos (`rules_catalog.gd`)

**Objetivo:** Proveer un catálogo centralizado con el reglamento claro y estructurado (Objetivo, Turno, Reglas Especiales y Condición de Victoria) para los **13 juegos**, accesible tanto desde el tablero como desde el Menú de Pausa.

- **Archivos:**
  - `godot_project/scripts/rules_catalog.gd` (nuevo — textos completos en ES/EN para los 13 juegos)
  - `godot_project/pause_menu.gd` (añadir botón "📖 Ver Reglas del Juego" que abre `RulesPopup` con las reglas del tablero activo)
  - Integración del botón `📖 Reglas` en los 9 tableros que aún no lo tenían (`checkers_board.gd`, `xiangqi_board.gd`, `backgammon_board.gd`, `ludo_board.gd`, `mille_bornes_board.gd`, `monopoly_board.gd`, `uno_board.gd`, `crisis_board.gd`, `chinese_checkers_board.gd`)
- **Especificaciones:**
  - `RulesCatalog.get_rules(game_id: String, locale: String = "es") -> Dictionary` devuelve `{title, summary, sections}`.
  - Desde cualquier partida en cualquiera de los 13 juegos, el jugador puede consultar las reglas sin perder el estado de la partida.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 485. Tutoriales Interactivos para Damas, Backgammon, UNO y Ludo

**Objetivo:** Ampliar el sistema `TutorialManager` (actualmente en Chess, Go y Shogi) a los juegos más populares de corte familiar y casual: Damas, Backgammon, UNO y Ludo.

- **Archivos:**
  - `godot_project/scripts/tutorials/checkers_tutorial.gd` (nuevo — 5 pasos)
  - `godot_project/scripts/tutorials/backgammon_tutorial.gd` (nuevo — 5 pasos)
  - `godot_project/scripts/tutorials/uno_tutorial.gd` (nuevo — 5 pasos)
  - `godot_project/scripts/tutorials/ludo_tutorial.gd` (nuevo — 5 pasos)
  - `godot_project/tests/tutorial_smoke.gd` (ampliar verificación a los 7 tutoriales interactivos)
- **Especificaciones:**
  - Cada tutorial guía paso a paso las mecánicas clave (ej. captura obligatoria y coronación en Damas; barra y doubling cube en Backgammon; colores, +2 y Jump-In en UNO; salida con 6 y casillas seguras en Ludo).
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/tutorial_smoke.gd 2>&1 | grep "PASS"
  ```

---

### 486. Reloj Visual de Turno (`turn_timer_hud.gd`), Rendición (`Resign`) y Oferta de Tablas (`Offer Draw`)

**Objetivo:** Mostrar en pantalla el tiempo restante del turno actual y permitir rendirse u ofrecer tablas de manera formal en partidas locales y online.

- **Archivos:**
  - `godot_project/scenes/turn_timer_hud.gd` (nuevo — barra y contador regresivo `MM:SS` con alerta visual en los últimos 10 segundos)
  - `godot_project/pause_menu.gd` (añadir botones "🏳️ Rendirse" y "🤝 Ofrecer Tablas" con diálogo de confirmación)
  - `open_table_godot/src/lib.rs` (añadir métodos `resign_match(player_id: i64)` y `declare_draw()`)
- **Especificaciones:**
  - En modo local/vs IA, si el temporizador opcional está activo y llega a `00:00`, adjudica la victoria al rival.
  - En los últimos 10 segundos, el reloj parpadea en ámbar/rojo y reproduce un pulso sonoro suave mediante `AudioManager`.
  - "Rendirse" solicita confirmación para evitar clics accidentales y dispara el overlay de fin de partida (`game_over_overlay.gd`).
- **Verificación:**
  ```bash
  cargo check -p open_table_godot
  tools/run_godot_tests.sh
  ```

---

### 487. Deshacer Movimiento (`Undo` / `Takeback`) en Modo Local y vs IA

**Objetivo:** Permitir a los jugadores en modo Hotseat o vs IA deshacer el último turno para aprender de errores sin tener que reiniciar toda la partida.

- **Archivos:**
  - `open_table_engine/src/session.rs` (añadir `Session::undo_last_command() -> Result<(), EngineError>` reconstruyendo el estado desde el estado inicial + `history[..len-1]`)
  - `open_table_godot/src/lib.rs` (exponer `undo_last_move() -> bool`; en modo vs IA deshace tanto la respuesta de la IA como la jugada humana previa)
  - `godot_project/pause_menu.gd` (añadir botón "↩️ Deshacer Jugada", deshabilitado automáticamente en partidas online/Relay)
- **Especificaciones:**
  - Gracias al diseño determinista por comandos de `open_table_engine::Session`, `undo_last_command` guarda un clon del `initial_state` al crear la sesión y reaplica los comandos previos en microsegundos, garantizando exactitud total en los 13 juegos.
  - En partidas de red (`is_network_mode() == true`), `undo_last_move()` retorna `false` y el botón no se muestra.
- **Verificación:**
  ```bash
  cargo test -p open_table_engine -- undo
  cargo check -p open_table_godot
  ```

---

### 488. Pantalla de Estadísticas Locales y Progreso por Juego (`stats_screen.gd`)

**Objetivo:** Mostrar al jugador su historial local de desempeño en cada uno de los 13 juegos (partidas jugadas, porcentaje de victorias, racha máxima, ELO local y victorias contra IA por dificultad) sin requerir cuentas sociales.

- **Archivos:**
  - `godot_project/score_tracker.gd` (ampliar registro local con `games_played`, `win_streak`, `best_streak`, `ai_wins_by_difficulty`)
  - `godot_project/scenes/stats_screen.gd` (nuevo)
  - `godot_project/scenes/stats_screen.tscn` (nuevo)
  - `godot_project/main_menu.gd` (añadir botón "📊 Mis Estadísticas")
- **Especificaciones:**
  - Persistencia 100% local en `user://stats.cfg` (sincronizada con Steam Cloud si `SteamManager` está activo).
  - Tabla resumen de los 13 juegos + tarjetas de hitos personales (Total de partidas, Juego favorito, Mayor ELO alcanzado).
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

## Bloque 5: Accesibilidad, Steam Deck y Adaptación Móvil (Prompts 489–491)

*Problema actual:* Para obtener el sello **Steam Deck Playable/Verified** y destacar en Google Play / App Store, los tableros necesitan navegación completa con mando (sin depender de ratón), opciones para daltonismo (clave en UNO, Ludo, Damas Chinas y Mille Bornes) y feedback háptico móvil.

---

### 489. Cursor Virtual de Tablero para Gamepad y Steam Deck (`gamepad_board_cursor.gd`)

**Objetivo:** Permitir jugar cualquiera de los 13 juegos usando únicamente un mando (Xbox, DualSense, Steam Deck) mediante un cursor de grilla/selector controlado con el D-Pad o stick izquierdo.

- **Archivos:**
  - `godot_project/scripts/gamepad_board_cursor.gd` (nuevo — componente reutilizable que traduce `ui_gamepad_*` a selección de casilla o carta)
  - `godot_project/project.godot` (registrar `GamepadBoardCursor` o integrarlo en los tableros)
- **Especificaciones:**
  - Se activa automáticamente al detectar cualquier evento `InputEventJoypadButton` o `InputEventJoypadMotion`, y se oculta al mover el ratón o tocar la pantalla.
  - Botón `A` (`ui_gamepad_select`) simula clic en la celda/carta actual; botón `B` (`ui_gamepad_cancel`) cancela la selección; botón `Start` (`ui_gamepad_start`) abre el menú de pausa.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 490. Accesibilidad Visual: Modo Daltónico, Alto Contraste y Escalado de Texto

**Objetivo:** Asegurar que los juegos dependientes del color (UNO, Ludo, Chinese Checkers, Mille Bornes, Monopoly) sean 100% distinguibles para jugadores con deuteranopia, protanopia o tritanopia.

- **Archivos:**
  - `godot_project/theme_manager.gd` (añadir paleta `colorblind_mode: String` ∈ `{"none", "deuteranopia", "protanopia", "tritanopia", "high_contrast"}` y `ui_font_scale: float` ∈ `{1.0, 1.15, 1.3}`)
  - `godot_project/scenes/settings_menu.gd` (añadir selectores de Modo Daltónico y Tamaño de Texto)
- **Especificaciones:**
  - Además de ajustar la paleta de colores con alto contraste perceptual (paleta Okabe-Ito), activar símbolos geométricos superpuestos sobre fichas de colores (▲ Rojo, ● Azul, ■ Verde, ◆ Amarillo, ★ Naranja, ⬟ Violeta).
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 491. Pulido Móvil: Safe-Area Adaptativa y Vibración Háptica (`haptics_manager.gd`)

**Objetivo:** Respetar los recortes de pantalla (notch / barra de gestos inferior) en iOS y Android y proporcionar respuesta táctil sutil al mover piezas, tirar dados o capturar.

- **Archivos:**
  - `godot_project/scripts/haptics_manager.gd` (nuevo — wrapper sobre `Input.vibrate_handheld` con intensidades `light_tap()`, `medium_impact()`, `victory_pulse()` y toggle en Ajustes)
  - `godot_project/game_manager.gd` (aplicar márgenes de `DisplayServer.get_display_safe_area()` a los contenedores HUD superiores e inferiores)
- **Especificaciones:**
  - En dispositivos de escritorio o cuando la vibración está desactivada en `settings.cfg`, `haptics_manager.gd` es un no-op seguro.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

## Bloque 6: Cumplimiento Legal, Diagnóstico y Gate Final de Lanzamiento v3.0.0 (Prompts 492–495)

*Problema actual:* Google Play y Apple App Store rechazan aplicaciones que se conectan a Internet si no incluyen una Política de Privacidad accesible dentro de la app y en el repositorio, además de la atribución de licencias de terceros.

---

### 492. Cumplimiento Legal para Tiendas: Política de Privacidad, Términos y Modal en Primer Arranque

**Objetivo:** Incluir la documentación legal de privacidad (cumplimiento GDPR/CCPA sin rastreadores de terceros) y un aviso informativo en el primer arranque del juego.

- **Archivos:**
  - `PRIVACY_POLICY.md` (nuevo — detalla que solo se almacena un UUID anónimo de dispositivo para ELO/matchmaking y no se comparten datos con terceros)
  - `TERMS_OF_SERVICE.md` (nuevo)
  - `godot_project/scenes/privacy_consent_modal.gd` (nuevo — se muestra una sola vez si `privacy_accepted != true` en `user://settings.cfg`, con opción de jugar 100% Offline si el usuario rechaza funciones online)
  - `godot_project/main_menu.gd` (mostrar modal en el primer inicio si no ha sido aceptado)
- **Especificaciones:**
  - Si el jugador acepta, se habilitan las funciones online (Relay/Matchmaking). Si elige "Solo Modo Local / Offline", el juego funciona al 100% en local/vs IA sin realizar ninguna conexión HTTP/WS externa.
- **Verificación:**
  ```bash
  test -f PRIVACY_POLICY.md
  test -f TERMS_OF_SERVICE.md
  tools/run_godot_tests.sh
  ```

---

### 493. Visor de Licencias Open Source y Exportación de Diagnóstico (`error_logger.gd`)

**Objetivo:** Incluir las licencias de dependencias de Rust y Godot en la pantalla de Créditos y permitir exportar un archivo de diagnóstico técnico (`opentable_diag.json`) en caso de soporte al usuario.

- **Archivos:**
  - `THIRD_PARTY_LICENSES.md` (nuevo — resumen de licencias MIT/Apache-2.0 del ecosistema Rust y Godot/Redot)
  - `godot_project/error_logger.gd` (añadir `export_diagnostics(path: String) -> bool` con versión de OS, renderer, últimos 50 logs y estado del bridge, sin datos personales)
  - `godot_project/scenes/credits_screen.gd` (añadir pestaña "Licencias Open Source" y botón "Exportar Diagnóstico")
- **Especificaciones:**
  - Cumple con la obligación de atribución de las licencias MIT y Apache-2.0 en distribuciones binarias comerciales.
- **Verificación:**
  ```bash
  test -f THIRD_PARTY_LICENSES.md
  tools/run_godot_tests.sh
  ```

---

### 494. Test de Carga e Integración Concurrencia del Servidor Relay (`load_test.rs`)

**Objetivo:** Verificar mediante un test de integración automatizado que `open_table_relay` soporta múltiples salas concurrentes, emparejamientos simultáneos y validación anti-cheat sin interbloqueos (deadlocks) ni degradación de latencia.

- **Archivos:**
  - `open_table_relay/tests/load_test.rs` (nuevo)
- **Especificaciones:**
  - Levanta una instancia efímera del Relay en un puerto libre local.
  - Simula 50 salas concurrentes (100 clientes WebSocket en paralelo) intercambiando comandos validados de Ajedrez y Damas, más 20 clientes en cola de matchmaking.
  - Verifica que el 100% de los mensajes válidos se entregan en menos de 200 ms y que las salas se limpian correctamente al desconectar.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay --test load_test
  ```

---

### 495. Script Maestro de Verificación Comercial (`tools/verify_p12.sh`)

**Objetivo:** Gate definitivo de CI/CD que certifica que el proyecto completo está listo para etiquetar `v3.0.0` y publicar en todas las tiendas.

- **Archivos:**
  - `tools/verify_p12.sh` (nuevo)
- **Especificaciones:**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  echo "=== 1. Ejecutando gate previo PROMPTS11 (verify_p11.sh) ==="
  bash tools/verify_p11.sh

  echo "=== 2. Relay v2: guest auth + 13-game anticheat + rejoin + timeout + load test ==="
  cargo test -p open_table_relay
  cargo test -p open_table_relay --test load_test

  echo "=== 3. Engine: undo / takeback determinista ==="
  cargo test -p open_table_engine -- undo

  echo "=== 4. Empaquetado multiplataforma y presets de exportación ==="
  test -f godot_project/assets/icons/opentable_suite.svg
  test -f godot_project/export_presets.cfg
  test -f store/steam/app_build.vdf
  grep -q "android.release.arm64" godot_project/open_table.gdextension
  grep -q "ios.release.arm64" godot_project/open_table.gdextension

  echo "=== 5. Cumplimiento legal y licencias para tiendas ==="
  test -f PRIVACY_POLICY.md
  test -f TERMS_OF_SERVICE.md
  test -f THIRD_PARTY_LICENSES.md

  echo "=== 6. Godot headless tests completos (incluyendo online_viability_smoke y tutoriales) ==="
  bash tools/run_godot_tests.sh

  echo "ALL PROMPTS12 CHECKS PASSED — OpenTable v3.0.0 commercially viable & ready for store launch!"
  ```
- **Verificación:**
  ```bash
  bash tools/verify_p12.sh
  ```

---

## Resumen de Prompts PROMPTS12

| # | Área | Elemento Principal |
|---|------|--------------------|
| **469** | Relay v2 / Auth | Endpoint `POST /auth/guest` + `auth_client.gd` con JWT automático |
| **470** | Relay v2 / Anti-Cheat | Validación autoritativa en el servidor para los **13 juegos** |
| **471** | Relay v2 / ELO | Actualización automática de ELO desde el motor (anti-spoofing) + `resign` |
| **472** | Relay v2 / Resiliencia | Reconexión a sala (`rejoin_room`) con ventana de 90s y replay de comandos |
| **473** | Relay v2 / Reloj | Temporizador de turno autoritativo en servidor y victoria por timeout (anti-AFK) |
| **474** | Relay v2 / Ops | Limpieza automática de salas inactivas (TTL) y apagado ordenado (`SIGTERM`) |
| **475** | Red Local | Auto-descubrimiento LAN por UDP broadcast (`lan_discovery.gd`) en 1 clic |
| **476** | Conectividad | Selector de URL del Relay en Ajustes + `GET /health` con test de latencia |
| **477** | Conectividad | Reconexión automática con backoff exponencial en cliente WebSocket |
| **478** | QA Red | Smoke test headless de Guest Auth, LAN Discovery y reconexión |
| **479** | Branding | Identidad visual unificada de la suite `OpenTable` e ícono vectorial |
| **480** | Packaging | Manifiesto `.gdextension` completo (Desktop, Android, iOS, Web WASM) |
| **481** | Packaging | `godot_project/export_presets.cfg` canónico para las 6 plataformas |
| **482** | CI/CD Release | Compilación cruzada real y generación de `.aab` (Google Play) en `release.yml` |
| **483** | Tiendas | Configuración SteamPipe (`app_build.vdf` + depots) y Fastlane `.aab` |
| **484** | UX Tableros | Catálogo completo de Reglas In-Game para los 13 juegos (`rules_catalog.gd`) |
| **485** | Onboarding | Tutoriales interactivos para Damas, Backgammon, UNO y Ludo |
| **486** | UX Competitiva | Reloj visual de turno (`turn_timer_hud.gd`), Rendirse y Ofrecer Tablas |
| **487** | UX Local/IA | Deshacer jugada (`undo_last_move`) determinista en modo Hotseat y vs IA |
| **488** | Progreso Local | Pantalla de Estadísticas Locales detalladas por juego (`stats_screen.gd`) |
| **489** | Steam Deck | Soporte completo de Gamepad con cursor virtual de tablero |
| **490** | Accesibilidad | Modo Daltónico (Okabe-Ito + símbolos), Alto Contraste y Escalado de Texto |
| **491** | Mobile UX | Adaptación a Safe-Area (notch) y vibración háptica (`haptics_manager.gd`) |
| **492** | Legal / Tiendas | `PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md` y modal de consentimiento offline/online |
| **493** | Soporte / OSS | `THIRD_PARTY_LICENSES.md` en Créditos y exportación de diagnóstico técnico |
| **494** | QA Escala | Test de carga y concurrencia del Relay (50 salas / 100 clientes simultáneos) |
| **495** | CI Gate Final | `tools/verify_p12.sh` — certificación integral para lanzamiento v3.0.0 |

*Total acumulado al finalizar PROMPTS12: 495 prompts.*

---

## Criterios de "Lanzamiento Comercial Viable (v3.0.0)"

Al completar los 27 prompts de `PROMPTS12.md`:

- [x] Cualquier jugador puede abrir el juego y jugar online al instante con un JWT de invitado firmado automáticamente (`POST /auth/guest`), o jugar 100% offline.
- [x] El servidor Relay valida las reglas de los **13 juegos**, calcula el ELO sin confiar en el cliente, gestiona relojes de turno (anti-AFK) y permite reconectar tras micro-cortes de red (`rejoin_room`).
- [x] En red local (Wi-Fi), las salas aparecen automáticamente en pantalla mediante descubrimiento UDP sin teclear direcciones IP.
- [x] Los 13 juegos cuentan con reglamento completo consultable en partida, controles de rendición/tablas, deshacer jugada en modo local/IA y estadísticas detalladas.
- [x] El proyecto es jugable con mando (Steam Deck), accesible para personas con daltonismo y respeta las áreas seguras y vibración en móviles.
- [x] El repositorio incluye `export_presets.cfg`, scripts de SteamPipe (`.vdf`), soporte `.aab` para Google Play, Política de Privacidad y licencias Open Source requeridas por las tiendas.
- [x] `tools/verify_p12.sh` pasa limpio de principio a fin.
