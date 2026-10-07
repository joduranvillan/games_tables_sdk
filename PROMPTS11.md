# Prompts de Producción, IA Completa y Redes Nativas — Games Tables SDK (Parte 11)

Continúa desde `PROMPTS10.md` (prompts 426–447). Numerados del **448 al 468**.

**Prerequisito:** PROMPTS10 completado → relay funcional con ELO/matchmaking/torneos, IA en 7 juegos con 4 niveles de dificultad, tutoriales para Chess/Go/Shogi, SDK publicable en crates.io, mdBook docs en GitHub Pages.

**Objetivo:** Llevar OpenTable del estado "comercialmente maduro" al estado "producción robusta y ecosistema completo": hardening de seguridad del relay, compilación real de plugins nativos móviles, IA en los 6 juegos que aún carecen de ella, sistema social básico (amigos/chat) y más tutoriales.

---

## 0. Estado al inicio de PROMPTS11

### Verificado como implementado (PROMPTS10 auditado)

| Elemento | Archivo | Estado |
|----------|---------|--------|
| Relay WebSocket ELO + matchmaking | `open_table_relay/src/` | ✅ |
| Relay torneos con brackets | `open_table_relay/src/tournament.rs` | ✅ |
| `AiDifficulty` + 7 motores IA | `open_table_core/src/difficulty.rs`, `*/src/ai.rs` | ✅ |
| Opening book Ajedrez Hard/Expert | `chess_game/src/opening_book.rs` | ✅ |
| Tutoriales Chess, Go, Shogi | `godot_project/scripts/tutorials/` | ✅ |
| Metadatos crates.io + mdBook | `open_table_core/Cargo.toml`, `docs/book.toml` | ✅ |
| Assets Steam / Itch.io / Google Play | `store/` | ✅ |
| Steamworks bridge | `open_table_godot/src/steam_bridge.rs` | ✅ |

### Pendiente identificado en NEXT_STEPS.md

```
┌───────────────────────────────────────────────────────────────────────┐
│                  LOS 4 PILARES DE PROMPTS11                           │
├──────────────────────────┬────────────────────────────────────────────┤
│ 1. Relay en Producción   │ TLS/WSS, JWT auth, rate-limit, Docker      │
│ 2. Mobile P2P Real       │ Android (Nearby) + iOS (Multipeer) reales  │
│ 3. IA Completa           │ 6 juegos sin IA: Battleship, Mille Bornes, │
│                          │ UNO, Monopoly, Chinese Checkers, Crisis     │
│ 4. Social y Tutoriales   │ Amigos, chat, + tutoriales Backgammon/UNO  │
└──────────────────────────┴────────────────────────────────────────────┘
```

---

## Bloque 1: Relay en Producción — Seguridad y Deployment (Prompts 448–452)

*Problema actual:* El relay escucha en WS plano (ws://) sin autenticación, sin límite de peticiones y sin contenedor. Una instancia en Internet quedaría expuesta a spam, replay de mensajes y conexiones abusivas.

---

### 448. TLS/WSS y Autenticación JWT en el Relay

**Objetivo:** Añadir soporte para WebSocket Secure (wss://) mediante `rustls` y validar un JWT mínimo (sub, exp) antes de aceptar cualquier conexión.

- **Archivos:**
  - `open_table_relay/Cargo.toml` (añadir `rustls = "0.23"`, `tokio-rustls = "0.26"`, `jsonwebtoken = "9"`)
  - `open_table_relay/src/tls.rs` (nuevo — carga certificados PEM desde path de env)
  - `open_table_relay/src/auth.rs` (nuevo — validación JWT con `HS256`, secret desde `JWT_SECRET` env var)
  - `open_table_relay/src/main.rs` (integrar TLS acceptor y middleware de auth)
- **Especificaciones:**
  - Variable de entorno `TLS_CERT_PATH` / `TLS_KEY_PATH` — si no están presentes, el relay arranca en modo plain WS (retro-compatible para dev local).
  - Variable de entorno `JWT_SECRET` — si no está presente, auth desactivada (dev local).
  - El cliente incluye el JWT en el primer mensaje `{"op": "auth", "token": "<jwt>"}` dentro de los 5 segundos o el servidor cierra la conexión.
  - Si el token es válido, `sub` se usa como `player_id` canónico (anula el ID asignado por conexión).
  - El campo `exp` se valida estrictamente; tokens expirados son rechazados con `{"op": "auth_error", "reason": "expired"}`.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- auth
  cargo check -p open_table_relay
  ```

---

### 449. Rate Limiting y Protección Anti-Spam

**Objetivo:** Limitar la velocidad de mensajes por IP y por `player_id` para prevenir flooding del relay.

- **Archivos:**
  - `open_table_relay/Cargo.toml` (añadir `governor = "0.6"`)
  - `open_table_relay/src/rate_limit.rs` (nuevo)
  - `open_table_relay/src/main.rs` (integrar)
- **Especificaciones:**
  - Límite por IP: 30 mensajes/segundo usando `governor::RateLimiter` (GCRA).
  - Límite global por sala: 60 mensajes/segundo (suma de todos los participantes).
  - Al superar el límite, el relay descarta el mensaje y responde `{"op": "rate_limited", "retry_after_ms": 1000}` — **no** cierra la conexión en el primer incidente.
  - Tras 5 violaciones en 10 segundos desde la misma IP, cierra la conexión y bloquea la IP durante 60 segundos (lista en memoria; no persiste entre reinicios).
  - Exposición en métricas: contador `rate_limit_drops_total` y `ip_bans_total`.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- rate_limit
  ```

---

### 450. Validación Anti-Cheat de Movimientos en el Relay

**Objetivo:** Para partidas relay de Chess y Checkers, el servidor valida que los movimientos recibidos son legales según el motor Rust antes de retransmitirlos.

- **Archivos:**
  - `open_table_relay/Cargo.toml` (añadir `chess_game`, `checkers_game` como deps)
  - `open_table_relay/src/anticheat.rs` (nuevo)
  - `open_table_relay/src/room.rs` (integrar validación al retransmitir)
- **Especificaciones:**
  - Cuando una sala tiene `"game_id": "chess"` o `"checkers"`, el relay mantiene un `Session` del motor correspondiente.
  - Al recibir `{"op": "relay", "data": "<json_de_comando>"}`, el relay deserializa el comando e intenta aplicarlo a la sesión local.
  - Si el comando es ilegal, responde al emisor `{"op": "move_rejected", "reason": "illegal_move"}` y no retransmite.
  - Si es legal, aplica el comando a la sesión local y retransmite normalmente.
  - Para otros juegos, el relay retransmite sin validar (opt-in futuro).
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- anticheat
  ```

---

### 451. Containerización Docker y Configuración nginx

**Objetivo:** Proveer un `Dockerfile` y `docker-compose.yml` listos para desplegar el relay en producción con nginx como proxy reverso para WSS.

- **Archivos:**
  - `open_table_relay/Dockerfile` (nuevo)
  - `open_table_relay/docker-compose.yml` (nuevo)
  - `open_table_relay/nginx/nginx.conf` (nuevo)
  - `open_table_relay/DEPLOY.md` (nuevo)
- **Especificaciones:**
  - `Dockerfile`: imagen base `rust:1.82-slim`, compila en release, imagen final `debian:bookworm-slim` con solo el binario.
  - `docker-compose.yml`: servicio `relay` (imagen local), servicio `nginx` (imagen oficial), volúmenes para certificados TLS y base de datos SQLite.
  - `nginx.conf`:
    - Puerto 443 → proxy a relay WS en 8080, con `proxy_set_header Upgrade $http_upgrade`.
    - Puerto 80 → redirect a 443.
    - Puerto 8081 (API HTTP) expuesto solo en red interna (no público).
  - `DEPLOY.md`: instrucciones paso a paso (certbot/Let's Encrypt, `docker compose up -d`, health check).
- **Verificación:**
  ```bash
  docker build -t open_table_relay open_table_relay/
  bash -n open_table_relay/nginx/nginx.conf || true
  test -f open_table_relay/DEPLOY.md
  ```

---

### 452. Métricas Prometheus y Dashboard Grafana

**Objetivo:** Exponer métricas operacionales del relay en formato Prometheus y proveer un dashboard Grafana como JSON exportable.

- **Archivos:**
  - `open_table_relay/Cargo.toml` (añadir `metrics = "0.23"`, `metrics-exporter-prometheus = "0.15"`)
  - `open_table_relay/src/metrics.rs` (nuevo)
  - `open_table_relay/grafana/dashboard.json` (nuevo)
  - `open_table_relay/docker-compose.yml` (añadir servicios `prometheus`, `grafana`)
- **Especificaciones:**
  - Métricas expuestas en `GET /metrics` (puerto 8081, nueva ruta):
    - `relay_connections_active` (gauge)
    - `relay_rooms_active` (gauge)
    - `relay_messages_total` (counter, label `game_id`)
    - `relay_elo_updates_total` (counter)
    - `rate_limit_drops_total` (counter)
    - `ip_bans_total` (counter)
  - `grafana/dashboard.json`: panel con serie temporal de conexiones activas, mensajes/min y top-5 juegos por actividad.
  - `docker-compose.yml` actualizado: servicios `prometheus` (scrape interval 15s), `grafana` (provisioned con el dashboard).
- **Verificación:**
  ```bash
  cargo check -p open_table_relay
  test -f open_table_relay/grafana/dashboard.json
  ```

---

## Bloque 2: Mobile P2P Real — Android e iOS Nativos (Prompts 453–456)

*Problema actual:* Los plugins `OpenTableNearby` (Android/Kotlin) y `OpenTableMultipeer` (iOS/Swift) están escritos como código fuente pero nunca han sido compilados como `.aar` / `.xcframework`. El `RawByteLink` en el bridge de Godot usa solo `FakeRawByteLink` en tests.

---

### 453. Build Script Android para el Plugin Nearby Connections

**Objetivo:** Crear un `build.gradle.kts` funcional que compile `OpenTableNearby` como `.aar` listo para incluir en el proyecto Godot, y documentar el proceso en CI.

- **Archivos:**
  - `platform_plugins/android/build.gradle.kts` (actualizar/completar)
  - `platform_plugins/android/settings.gradle.kts` (nuevo si falta)
  - `platform_plugins/android/BUILD.md` (actualizar)
  - `.github/workflows/ci.yml` (añadir job `build-android-plugin`)
- **Especificaciones:**
  - El `.aar` compila con `minSdkVersion 21`, `targetSdkVersion 34`.
  - Dependencias: `com.google.android.gms:play-services-nearby:19.3.0`.
  - El plugin implementa `OpenTableNearbyPlugin` (ya escrito en Kotlin) y exporta `OpenTableNearbyPlugin.gdap` con la ruta al `.aar`.
  - Job CI `build-android-plugin` en `ubuntu-latest`, JDK 17, NDK r27, ejecuta `./gradlew assembleRelease` y sube `OpenTableNearby-release.aar` como artefacto.
  - `BUILD.md` actualizado: pasos para desarrolladores locales (Android Studio o CLI), cómo copiar el `.aar` al proyecto Godot.
- **Verificación:**
  ```bash
  grep "build-android-plugin" .github/workflows/ci.yml
  test -f platform_plugins/android/build.gradle.kts
  ```

---

### 454. Build Script iOS para el Plugin MultipeerConnectivity

**Objetivo:** Crear un `Package.swift` que compile `OpenTableMultipeer` como XCFramework y documentar el proceso de integración con Godot/Redot en iOS.

- **Archivos:**
  - `platform_plugins/ios/Package.swift` (nuevo)
  - `platform_plugins/ios/BUILD.md` (actualizar)
  - `.github/workflows/ci.yml` (añadir job `build-ios-plugin` en `macos-latest`)
- **Especificaciones:**
  - `Package.swift`: Swift Package con target `OpenTableMultipeer` que incluye `OpenTableMultipeerPlugin.swift`, `OpenTableMultipeerNetwork.swift` y `OpenTableMultipeer.swift`.
  - Framework target: iOS 15+, `MultipeerConnectivity` como framework del sistema (no dependencia externa).
  - Job CI `build-ios-plugin` en `macos-latest`, Xcode 16: `swift build -c release --sdk iphoneos` y `xcodebuild -create-xcframework ...`, sube `OpenTableMultipeer.xcframework` como artefacto.
  - `BUILD.md` actualizado: cómo generar el XCFramework localmente, cómo copiarlo a `godot_project/ios/plugins/`.
- **Verificación:**
  ```bash
  grep "build-ios-plugin" .github/workflows/ci.yml
  test -f platform_plugins/ios/Package.swift
  ```

---

### 455. RawByteLink Real en el Bridge de Godot (P2P Nativo)

**Objetivo:** Implementar `GodotRawByteLink` en el bridge, que usa señales GDExtension para comunicarse con el plugin nativo (Android o iOS), sustituyendo a `FakeRawByteLink`.

- **Archivos:**
  - `open_table_godot/src/native_link.rs` (nuevo)
  - `open_table_godot/src/lib.rs` (integrar `GodotRawByteLink`)
- **Especificaciones:**
  - `GodotRawByteLink` implementa el trait `RawByteLink` de `open_table_transport_native_bridge`.
  - `send(data: &[u8])` → llama a la señal Godot `native_send_bytes(bytes: PackedByteArray)` hacia el plugin.
  - `receive()` → retorna bytes recibidos desde la señal Godot `native_bytes_received(bytes: PackedByteArray)`.
  - El bridge expone `start_p2p_host(game_id: String)` y `start_p2p_client(game_id: String)` que inicializan `NativeBridgeTransport<GodotRawByteLink>`.
  - Si el plugin nativo no está disponible (desktop), registra un warning en Godot y no falla.
- **Verificación:**
  ```bash
  cargo check -p open_table_godot
  cargo test -p open_table_transport_native_bridge
  ```

---

### 456. Test de Humo P2P Nativo en Headless

**Objetivo:** Test headless que verifique que las funciones `start_p2p_host` y `start_p2p_client` del bridge existen y no dan error null al llamarlas (sin plugin real disponible en desktop/headless).

- **Archivos:**
  - `godot_project/tests/native_p2p_smoke.gd` (nuevo — reemplaza o extiende `test_native_p2p_adapter.gd`)
- **Especificaciones:**
  - Instancia el bridge y llama `start_p2p_host("chess")` — verifica que el método existe y retorna sin crash (puede retornar false en desktop).
  - Verifica que la señal `native_send_bytes` está registrada en el bridge.
  - Imprime `PASS: P2P API surface OK` al completar.
- **Verificación:**
  ```bash
  redot --headless --path godot_project -s tests/native_p2p_smoke.gd 2>&1 | grep "PASS"
  ```

---

## Bloque 3: IA Completa — Los 6 Juegos Restantes (Prompts 457–461)

*Problema actual:* Battleship, Mille Bornes, UNO, Monopoly, Chinese Checkers y Crisis/TEG no tienen módulo `ai.rs`. Los usuarios no pueden jugar esos juegos en modo "vs IA".

---

### 457. IA para Batalla Naval (Battleship) con Probabilistic Targeting

**Objetivo:** Implementar una IA para Battleship que use probabilistic targeting: calcula la probabilidad de que cada celda contenga un barco y dispara a la de mayor probabilidad.

- **Archivos:**
  - `battleship_game/src/ai.rs` (nuevo)
  - `battleship_game/src/lib.rs` (re-exportar `ai`)
  - `open_table_godot/src/lib.rs` (añadir `start_local_match_battleship_vs_ai`)
- **Especificaciones:**
  - `best_move(state: &BattleshipState, ai_player: PlayerId, difficulty: AiDifficulty) -> Option<BattleshipCommand>`
  - En `Easy`: disparo aleatorio en celdas no disparadas.
  - En `Medium`: disparo aleatorio pero prioriza adyacentes si hay un impacto sin hundir.
  - En `Hard`/`Expert`: probability density map — cuenta cuántas orientaciones de barcos no hundidos pueden cubrir cada celda; dispara a la de mayor densidad.
  - Tests unitarios: `easy_ai_fires_untouched_cell`, `medium_ai_hunts_after_hit`, `hard_ai_prefers_high_density`.
- **Verificación:**
  ```bash
  cargo test -p battleship_game -- ai
  ```

---

### 458. IA para Mille Bornes y UNO (Heurísticas Basadas en Reglas)

**Objetivo:** Implementar IA heurística para los dos juegos de cartas que evalúa la mano actual y escoge la jugada con mejor valor esperado.

- **Archivos:**
  - `mille_bornes_game/src/ai.rs` (nuevo)
  - `mille_bornes_game/src/lib.rs` (re-exportar)
  - `uno_game/src/ai.rs` (nuevo)
  - `uno_game/src/lib.rs` (re-exportar)
  - `open_table_godot/src/lib.rs` (añadir `start_local_match_mille_bornes_vs_ai`, `start_local_match_uno_vs_ai`)
- **Especificaciones:**

  **Mille Bornes:**
  - `best_move(state, ai, difficulty) -> Option<MilleBornesCommand>`
  - Prioridad de jugada: 1) Safety si en mano, 2) Remedy si bloqueado, 3) Hazard al oponente si tiene buen avance, 4) Distance máxima posible.
  - En `Easy` ignora las prioridades 1 y 3.

  **UNO:**
  - `best_move(state, ai, difficulty) -> Option<UnoCommand>`
  - Prioridad: 1) Wild Draw Four si ≤2 cartas en mano, 2) carta que cambia color al color propio más frecuente, 3) +2 al jugador que va ganando, 4) carta que coincide con color/número.
  - En `Easy`: juega la primera carta válida sin considerar estrategia.
  - Tests: `mille_bornes_ai_plays_safety_first`, `uno_ai_changes_color_strategically`.
- **Verificación:**
  ```bash
  cargo test -p mille_bornes_game -- ai
  cargo test -p uno_game -- ai
  ```

---

### 459. IA para Monopoly y Damas Chinas (Chinese Checkers)

**Objetivo:** Implementar IA heurística para Monopoly (decisiones de compra/subasta) y MCTS ligero para Chinese Checkers.

- **Archivos:**
  - `monopoly_game/src/ai.rs` (nuevo)
  - `monopoly_game/src/lib.rs` (re-exportar)
  - `chinese_checkers_game/src/ai.rs` (nuevo)
  - `chinese_checkers_game/src/lib.rs` (re-exportar)
  - `open_table_godot/src/lib.rs` (añadir `start_local_match_monopoly_vs_ai`, `start_local_match_chinese_checkers_vs_ai`)
- **Especificaciones:**

  **Monopoly:**
  - `best_move(state, ai, difficulty) -> Option<MonopolyCommand>`
  - Comprar propiedad si `cash > price * 2` o si completa un grupo de color.
  - En subasta: ofertar hasta `80%` del valor de mercado.
  - Pagar fianza si hay propiedades no hipotecadas que se puedan desarrollar.

  **Chinese Checkers:**
  - MCTS con `difficulty.rollouts()` simulaciones aleatorias.
  - Función de evaluación: distancia total de peones al objetivo (minimizar suma).
  - Tests: `monopoly_ai_buys_affordable_property`, `chinese_checkers_ai_moves_toward_goal`.
- **Verificación:**
  ```bash
  cargo test -p monopoly_game -- ai
  cargo test -p chinese_checkers_game -- ai
  ```

---

### 460. IA para Crisis/TEG (Monte Carlo Tree Search)

**Objetivo:** Implementar MCTS para Crisis/TEG que evalúe ataques y colocación de ejércitos, el juego con el estado más complejo del SDK.

- **Archivos:**
  - `crisis_game/src/ai.rs` (nuevo)
  - `crisis_game/src/lib.rs` (re-exportar)
  - `open_table_godot/src/lib.rs` (añadir `start_local_match_crisis_vs_ai`)
- **Especificaciones:**
  - `best_move(state, ai, difficulty) -> Option<CrisisCommand>` para fases: colocación de ejércitos, ataque y fortificación.
  - **Colocación:** reforzar el territorio propio más amenazado (menor ratio `ejércitos_propios / ejércitos_vecinos_enemigos`).
  - **Ataque:** atacar si `ejércitos_atacantes > ejércitos_defensores * 1.5` (Easy: 2.0, Expert: 1.2).
  - **Fortificación:** mover ejércitos excedentes al territorio fronterizo más débil.
  - En `Expert`, evalúa si atacar acerca al objetivo secreto y prioriza esos territorios.
  - Tests: `crisis_ai_reinforces_threatened_territory`, `crisis_ai_attacks_when_superior`.
- **Verificación:**
  ```bash
  cargo test -p crisis_game -- ai
  ```

---

### 461. Exposición de las Nuevas IAs en el Bridge + Smoke Test

**Objetivo:** Exponer los 6 nuevos motores IA en `open_table_godot/src/lib.rs` y verificar que el bridge los llama correctamente desde Godot headless.

- **Archivos:**
  - `open_table_godot/src/lib.rs` (consolidar las 6 nuevas funciones)
  - `godot_project/main_menu.gd` (añadir opciones "vs IA" para los 6 juegos nuevos)
  - `godot_project/tests/ai_extended_smoke.gd` (nuevo)
- **Especificaciones:**
  - Las 6 funciones siguen la firma: `start_local_match_<game>_vs_ai(human: i64, ai: i64, difficulty: i64) -> bool`.
  - `ai_extended_smoke.gd` instancia el bridge, llama cada función en modo Easy y verifica retorno `true`.
  - Imprime `PASS: AI extended OK` al final.
  - `main_menu.gd`: en el `OptionButton` de juego, todos los 13 juegos aparecen en la lista "vs IA".
- **Verificación:**
  ```bash
  cargo test -p open_table_godot
  redot --headless --path godot_project -s tests/ai_extended_smoke.gd 2>&1 | grep "PASS"
  ```

---

## Bloque 4: Sistema Social — Amigos, Chat y Perfiles (Prompts 462–465)

*Problema actual:* El relay conecta a extraños por código de sala o matchmaking, pero no hay forma de invitar a un amigo directamente ni de chatear antes de la partida.

---

### 462. Sistema de Amigos en el Relay

**Objetivo:** Añadir a `open_table_relay` un módulo de amigos que permita enviar solicitudes, aceptar y listar amigos en la API HTTP.

- **Archivos:**
  - `open_table_relay/Cargo.toml` (rusqlite ya presente)
  - `open_table_relay/src/friends.rs` (nuevo)
  - `open_table_relay/src/api.rs` (añadir rutas HTTP de amigos)
  - `open_table_relay/src/main.rs` (inicializar tabla de amigos)
- **Especificaciones:**
  - Tabla SQL: `friends(requester TEXT, target TEXT, status TEXT, ts INTEGER)`. `status` ∈ `{pending, accepted}`.
  - API HTTP (puerto 8081):
    - `POST /friends/request` `{"from": "alice", "to": "bob"}` → inserta fila pending.
    - `POST /friends/accept` `{"from": "alice", "to": "bob"}` → cambia status a accepted.
    - `GET /friends/:player_id` → JSON con lista de amigos aceptados.
  - Protocolo WebSocket: `{"op": "invite_friend", "friend_id": "bob", "game_id": "chess"}` → el relay busca si `bob` está conectado y le envía `{"op": "friend_invite", "from": "alice", "game_id": "chess", "room_code": "XY12"}`.
  - Tests: `test_friend_request_flow`, `test_invite_connected_friend`.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- friends
  ```

---

### 463. Chat de Sala Pre-Partida

**Objetivo:** Añadir mensajes de texto en sala (lobby chat) al protocolo WebSocket del relay, con historial de los últimos 20 mensajes.

- **Archivos:**
  - `open_table_relay/src/room.rs` (añadir buffer de chat)
  - `open_table_relay/src/main.rs` (manejar `op: "chat"`)
  - `godot_project/scenes/host_lobby.gd` (añadir UI de chat)
  - `godot_project/scenes/host_lobby.tscn` (añadir `VBoxContainer` con `RichTextLabel` y `LineEdit`)
- **Especificaciones:**
  - Protocolo: `{"op": "chat", "text": "Hola!"}` → el relay retransmite a todos los de la sala: `{"op": "chat_msg", "from": "alice", "text": "Hola!", "ts": 1234567890}`.
  - El relay mantiene un buffer circular de 20 mensajes por sala; al unirse, envía el historial al nuevo participante.
  - En Godot: `RichTextLabel` (scrollable) con mensajes en formato `[alice] Hola!`, `LineEdit` con placeholder "Escribe un mensaje...", botón Enviar (o Enter).
  - Límite de 200 caracteres por mensaje; mensajes más largos se truncan en el servidor.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- chat
  tools/run_godot_tests.sh
  ```

---

### 464. Perfiles de Jugador con Avatar y Estadísticas

**Objetivo:** Añadir una pantalla de perfil en Godot que muestre el ELO por juego, victorias/derrotas y un avatar seleccionable de entre 8 opciones predefinidas.

- **Archivos:**
  - `godot_project/scenes/player_profile.gd` (nuevo)
  - `godot_project/scenes/player_profile.tscn` (nuevo)
  - `godot_project/main_menu.gd` (añadir botón "👤 Mi Perfil")
  - `open_table_relay/src/api.rs` (ruta `GET /player/:player_id` ya existe — ampliar con `avatar_id`)
- **Especificaciones:**
  - 8 avatares SVG incluidos en `godot_project/assets/avatars/` (figuras geométricas o animales abstractos, no personajes con copyright).
  - El jugador selecciona su avatar con un `GridContainer` de 8 opciones; se guarda en `user://settings.cfg` como `profile/avatar_id`.
  - La pantalla consulta `GET /player/<player_id>` para mostrar ELO y record en cada juego.
  - Botón "Copiar ID" para compartir el `player_id` con amigos.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  test -d godot_project/assets/avatars
  ```

---

### 465. Tutoriales de Backgammon y UNO

**Objetivo:** Añadir tutoriales interactivos de 5 pasos para Backgammon y UNO usando el `TutorialManager` existente.

- **Archivos:**
  - `godot_project/scripts/tutorials/backgammon_tutorial.gd` (nuevo)
  - `godot_project/scripts/tutorials/uno_tutorial.gd` (nuevo)
  - `godot_project/scenes/backgammon_board.gd` (integrar `TutorialManager`)
  - `godot_project/scenes/uno_board.gd` (integrar `TutorialManager`)
- **Backgammon (5 pasos):**
  1. "Tira los dados: mueve tus fichas el número de casillas mostrado."
  2. "Mueve una ficha 4 casillas — selecciona la ficha y la casilla destino."
  3. "Cuando el oponente ocupa una casilla con una sola ficha, puedes capturarla (hit)."
  4. "Las fichas capturadas van a la barra — debes reingresarlas primero."
  5. "Doubling cube: ofrece doblar las apuestas para aumentar el valor de la partida."
- **UNO (5 pasos):**
  1. "Juega una carta que coincida en color o número con la del centro."
  2. "Usa +2 para forzar al siguiente jugador a robar 2 cartas."
  3. "El comodín cambia el color activo — elige el color que más tengas."
  4. "Jump-In: si tienes la carta idéntica, puedes jugarla fuera de turno."
  5. "Di '¡UNO!' cuando te quede solo una carta. ¡Gana el primero en quedarse sin cartas!"
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

## Bloque 5: Smoke Test Global PROMPTS11 (Prompts 466–468)

---

### 466. Replay Sharing — Exportar e Importar Replays

**Objetivo:** Permitir exportar un replay de partida como archivo `.otr` (OpenTable Replay) y cargarlo en `ReplayViewer` desde cualquier dispositivo.

- **Archivos:**
  - `godot_project/scripts/save_manager.gd` (añadir `export_replay_file`, `import_replay_file`)
  - `godot_project/scenes/replay_viewer.gd` (añadir botón "Importar Replay")
- **Especificaciones:**
  - Formato `.otr`: JSON comprimido con gzip, campos `game_id`, `player_names`, `moves: [...]`, `version: "1"`.
  - `export_replay_file(path: String)` guarda el replay activo en el path dado (puede ser una ruta de descarga o compartir vía `OS.shell_open`).
  - `import_replay_file(path: String) -> bool` carga el `.otr`, valida la versión y retorna `true` si es compatible.
  - El `ReplayViewer` muestra un `FileDialog` al pulsar "Importar Replay" filtrado por `*.otr`.
- **Verificación:**
  ```bash
  tools/run_godot_tests.sh
  ```

---

### 467. Espectador en Partidas Online (Relay Spectator)

**Objetivo:** Extender el relay para que un tercer participante se una como espectador (sin permisos de escritura) y reciba todos los eventos de la partida en tiempo real.

- **Archivos:**
  - `open_table_relay/src/room.rs` (añadir rol `Spectator`)
  - `open_table_relay/src/main.rs` (manejar `op: "join_spectator"`)
  - `godot_project/scenes/spectator_view.gd` (adaptar para partidas relay)
- **Especificaciones:**
  - Protocolo: `{"op": "join_spectator", "room_code": "XKCD"}` → el relay confirma con `{"op": "spectating", "player_count": 2}` y empieza a reenviar todos los mensajes `relay` a este cliente.
  - Los espectadores no pueden enviar `op: "relay"` — si lo intentan, el relay responde `{"op": "error", "reason": "spectator_cannot_relay"}`.
  - `spectator_view.gd` ya existe; añadir soporte para recibir y aplicar eventos relay en lugar de eventos locales.
  - Límite: 10 espectadores por sala; si se supera, responde `{"op": "error", "reason": "spectator_limit"}`.
- **Verificación:**
  ```bash
  cargo test -p open_table_relay -- spectator
  ```

---

### 468. Script de Verificación CI Completo PROMPTS11 (`verify_p11.sh`)

**Objetivo:** Script único que verifica todos los nuevos sistemas de PROMPTS11 y sirve como gate de CI antes de etiquetar v2.1.0.

- **Archivos:**
  - `tools/verify_p11.sh` (nuevo)
- **Especificaciones:**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  echo "=== 1. Rust workspace (clippy + tests) ==="
  cargo clippy --workspace --exclude open_table_godot -- -D warnings
  cargo test --workspace --exclude open_table_godot
  cargo test --test serialization_contract -p open_table_engine

  echo "=== 2. Relay: auth + rate-limit + anticheat + friends + chat + spectator ==="
  cargo test -p open_table_relay

  echo "=== 3. IA extendida (6 nuevos juegos) ==="
  cargo test -p battleship_game -- ai
  cargo test -p mille_bornes_game -- ai
  cargo test -p uno_game -- ai
  cargo test -p monopoly_game -- ai
  cargo test -p chinese_checkers_game -- ai
  cargo test -p crisis_game -- ai

  echo "=== 4. Bridge P2P nativo ==="
  cargo check -p open_table_godot
  cargo test -p open_table_transport_native_bridge

  echo "=== 5. Godot headless tests ==="
  tools/run_godot_tests.sh

  echo "=== 6. Docker build relay ==="
  docker build -t open_table_relay_ci open_table_relay/ --quiet

  echo "=== 7. Store assets ==="
  test -f store/steam/description_en.txt
  test -f store/android/fastlane/Fastfile
  test -f open_table_relay/DEPLOY.md

  echo "=== 8. Platform plugins ==="
  test -f platform_plugins/android/build.gradle.kts
  test -f platform_plugins/ios/Package.swift

  echo "ALL PROMPTS11 CHECKS PASSED — ready for v2.1.0"
  ```
- **Verificación:**
  ```bash
  bash tools/verify_p11.sh
  ```

---

## Resumen de Prompts PROMPTS11

| # | Área | Elemento Principal |
|---|------|--------------------|
| **448** | Relay Prod | TLS/WSS + JWT auth en relay |
| **449** | Relay Prod | Rate limiting + anti-spam (governor) |
| **450** | Relay Prod | Anti-cheat: validación de movimientos Chess/Checkers |
| **451** | Relay Prod | Docker + nginx para despliegue en producción |
| **452** | Relay Prod | Métricas Prometheus + dashboard Grafana |
| **453** | Mobile P2P | Build script Android para plugin Nearby (.aar) |
| **454** | Mobile P2P | Build script iOS para plugin Multipeer (.xcframework) |
| **455** | Mobile P2P | `GodotRawByteLink` real en bridge (no más FakeRawByteLink) |
| **456** | Mobile P2P | Smoke test P2P API surface headless |
| **457** | IA | Battleship IA (probabilistic targeting) |
| **458** | IA | Mille Bornes + UNO IA (heurísticas de cartas) |
| **459** | IA | Monopoly + Chinese Checkers IA (compra/MCTS) |
| **460** | IA | Crisis/TEG IA (MCTS + evaluación de objetivo secreto) |
| **461** | IA | Bridge + smoke test 6 nuevas IAs |
| **462** | Social | Sistema de amigos en relay (HTTP + WebSocket invite) |
| **463** | Social | Chat de sala pre-partida en relay + UI Godot |
| **464** | Social | Perfiles de jugador con avatar + estadísticas |
| **465** | Social | Tutoriales interactivos Backgammon + UNO |
| **466** | Extra | Replay sharing (exportar/importar `.otr`) |
| **467** | Extra | Espectador en partidas online relay |
| **468** | CI | `verify_p11.sh` — gate completo para v2.1.0 |

*Total acumulado al finalizar PROMPTS11: 468 prompts.*

---

## Criterios de "Producción Robusta (v2.1.0)"

Al completar los prompts de `PROMPTS11.md` (Bloques 1, 2, 3 y 5; Bloque 4 omitido por decisión de alcance):

- [x] Relay deployable en Internet con TLS, JWT, rate limiting y anti-cheat.
- [x] Plugin Android compilable a `.aar` en CI sin intervención manual.
- [x] Plugin iOS compilable a `.xcframework` en CI macOS.
- [x] IA disponible para los 13 juegos (sin excepción).
- [ ] *(Omitido — Bloque 4)* Sistema de amigos e invitación directa vía WebSocket.
- [ ] *(Omitido — Bloque 4)* Chat de sala funcional antes de iniciar partida.
- [ ] *(Omitido — Bloque 4)* Perfiles de jugador con avatar y ELO por juego.
- [ ] *(Omitido — Bloque 4)* Tutoriales para Backgammon y UNO.
- [x] Replays exportables e importables como `.otr`.
- [x] Espectadores en partidas relay (hasta 10 por sala).
- [x] `verify_p11.sh` pasa limpio en CI.
