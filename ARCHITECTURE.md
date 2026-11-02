# Arquitectura del Motor — OpenTable SDK & Suite (v4.0.0)

Documento técnico de referencia de la arquitectura del motor determinista **OpenTable SDK** y de la colección de **13 juegos clásicos de mesa y cartas**.
- Para crear un juego nuevo paso a paso o extender el motor con código ejecutable, consulta **[`DEVELOPER_GUIDE.md`](./DEVELOPER_GUIDE.md)**.
- Para el ejemplo mínimo en 15 minutos, consulta **[`docs/SDK_QUICKSTART.md`](./docs/SDK_QUICKSTART.md)**.

---

## 1. Principio de Diseño: Anillos Desacoplados y Autoridad Determinista

**Cada capa solo conoce a la capa inmediatamente inferior.**
- `Session` (`open_table_engine`) procesa comandos sobre un `bevy_ecs::World` sin saber si el transporte es memoria local, TCP LAN, WebSocket TLS (`open_table_relay`) o P2P móvil (`Nearby Connections` / `MultipeerConnectivity`).
- Los **13 crates de juegos** (`*_game`) contienen el 100% de las reglas oficiales de torneo, generadores de movimientos legales (`LegalMoveGenerator`) y motores de IA (`src/ai.rs`), sin depender de Godot ni de sockets de red.
- El puente nativo `OpenTableBridge` (`open_table_godot`) traduce intenciones de la vista a `Command` y convierte cada `Event` emitido por el motor en señales de Godot/Redot.

```
┌────────────────────────────────────────────────────────────────────────────┐
│ 1. NÚCLEO DETERMINISTA (open_table_core + open_table_macros + qr)          │
│    • Traits puros: Command, Event (typetag JSON), Visibility, Transport    │
│    • Servicios deterministas: RandomService (ChaCha8), GameClock           │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      │
┌─────────────────────────────────────▼──────────────────────────────────────┐
│ 2. MOTOR AUTORITATIVO ECS (open_table_engine)                              │
│    • bevy_ecs::World + RuleEngine (validadores + LegalMoveGenerator)       │
│    • Session: control de turnos, ActionHistory (.otr), snapshots, ELO      │
└─────────────────┬───────────────────┴───────────────────┬──────────────────┘
                  │                                       │
┌─────────────────▼───────────────────┐ ┌─────────────────▼──────────────────┐
│ 3A. 13 MOTORES DE JUEGO (*_game)    │ │ 3B. CAPA DE RED Y RELAY            │
│  • Reglas canónicas 100% en Rust    │ │  • transport_tcp (LAN + Reconnect) │
│  • IA local con 4 niveles           │ │  • transport_websocket (TLS/WSS)   │
│  • Cero dependencia de UI o red     │ │  • transport_native_bridge (P2P)   │
│  • Tests unitarios + canónicos      │ │  • open_table_relay (Auth + AntiCh)│
└─────────────────┬───────────────────┘ └─────────────────┬──────────────────┘
                  └───────────────────┬───────────────────┘
                                      ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ 4. PUENTE NATIVO Y CLIENTE VISUAL (open_table_godot + godot_project)       │
│    • Clase única GDExtension: OpenTableBridge (Local / Host / Client)      │
│    • 13 Tableros GDScript + TurnIndicator compacto + GameAppMenu + Audio   │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mapa de los 22 Crates del Workspace

### Motor Base y Utilidades (4 Crates)
| Crate | Responsabilidad Principal |
| :--- | :--- |
| **`open_table_core`** | Primitivas base: `PlayerId`, `SessionId`, traits `Command` y `Event` serializables vía `typetag`, `EventVisibility` (`Public`, `OnlyPlayer`, `Hidden`), `RandomService` determinista (`ChaCha8Rng`), `GameClock` y trait `Transport`. |
| **`open_table_engine`** | Motor de sesión autoritativo sobre `bevy_ecs::World`: `RuleEngine`, `Session`, `TurnManager`, `ActionHistory` (replays `.otr`), `SnapshotManager`, deshacer/rehacer (`undo`/`redo`) y cálculo de rating ELO FIDE (`elo.rs`). |
| **`open_table_macros`** | Macros procedimentales `#[game_command]`, `#[game_event]`, `#[derive(GameResource, GameComponent)]` que automatizan el registro de `typetag` y traits ECS. |
| **`open_table_qr`** | Codificación compacta de invitaciones de sala (`JoinTicket` en Base64/JSON) y renderizado de códigos QR en matriz SVG/PNG para unión rápida desde móvil o escritorio. |

### Capa de Transporte y Servidor Autoritativo (4 Crates)
| Crate | Responsabilidad Principal |
| :--- | :--- |
| **`open_table_transport_tcp`** | Transporte Host/Client sobre sockets TCP con framing length-prefixed, tokens de sesión CSPRNG y reconexión automática preservando la partida. |
| **`open_table_transport_websocket`** | Transporte asíncrono sobre WebSockets (`tokio-tungstenite`) compatible con proxies HTTP/WSS y el servidor Relay. |
| **`open_table_transport_native_bridge`** | Protocolo completo de apretón de manos, identidad y reconexión abstraído sobre el trait mínimo `RawByteLink` para Bluetooth / Nearby Connections (Android) y MultipeerConnectivity (iOS). |
| **`open_table_relay`** | Servidor dedicado de producción con salas de 6 caracteres, TLS/WSS (`rustls`), autenticación JWT (`HS256`), rate-limiting por IP/sala, validación anti-cheat autoritativa para los 13 juegos, modo espectador (hasta 10 por sala) y métricas Prometheus (`/metrics`). |

### Puente Nativo con Godot / Redot (1 Crate)
| Crate | Responsabilidad Principal |
| :--- | :--- |
| **`open_table_godot`** | Biblioteca dinámica `GDExtension` (`cdylib`) que expone la clase unificada `OpenTableBridge` a GDScript. Gestiona sesiones locales, partidas contra IA, hosting/cliente TCP, conexión al Relay y `GodotRawByteLink`. |

### Los 13 Motores de Juego (`*_game`) (13 Crates)
Todos los juegos implementan sus reglas canónicas oficiales, validación determinista de jugadas ilegales (`MoveRejected`), generador de movimientos legales (`LegalMoveGenerator`) y oponente de IA local con 4 niveles de dificultad:

| # | Juego | Crate | Arquitectura de Estado y Reglas Canónicas Destacadas |
| :-: | :--- | :--- | :--- |
| 1 | **Damas** | `checkers_game` | Tablero 8×8, captura obligatoria, saltos múltiples encadenados (`multi_capture`), coronación a Dama de 4 diagonales, victoria por bloqueo total y tablas por 40 medios turnos sin captura. |
| 2 | **Ajedrez** | `chess_game` | Tablero 8×8, enroque corto/largo, captura al paso (*en passant*), subpromoción (`Queen`, `Rook`, `Bishop`, `Knight`), oferta/aceptación de tablas, triple repetición, regla de 50 movimientos e insuficiencia de material. |
| 3 | **Go (Weiqi / Baduk)** | `go_game` | Tableros 9×9, 13×13 y 19×19, cálculo de libertades por grupo, prohibición de suicidio, Superko Posicional (historial de hashes Zobrist/estado), Handicap inicial Hoshi, fase de marcado/acuerdo de piedras muertas y Komi configurable (`6.5`). |
| 4 | **Shogi** | `shogi_game` | Tablero 9×9 con reserva de capturas (*Komadai*), reingreso (*Drop*), prohibición de *Nifu* (dos peones en la misma columna) y *Uchifuzume* (mate por drop de peón), promoción opcional vs obligatoria FESA y *Sennichite* (repetición ×4). |
| 5 | **Xiangqi** | `xiangqi_game` | Intersecciones 9×10 con Río Central y Palacios 3×3, bloqueo de Caballo y Elefante, captura con pantalla del Cañón, regla del General Volador, victoria por ahogado (*Kunbi*) y prohibición de jaque perpetuo. |
| 6 | **Damas Chinas** | `chinese_checkers_game` | Estrella hexagonal de 121 casillas en coordenadas axiales `(q, r)` para 2, 3, 4 o 6 jugadores, saltos encadenados sin captura y regla oficial anti-bloqueo (*Home-Camp Spoiling*). |
| 7 | **Backgammon** | `backgammon_game` | 24 picos con conteo con signo, barra central, *bearing off* exacto o superior desde el pico más lejano, obligación de usar ambos dados (o el mayor), Cubo de Doblaje (`2..64`), regla Crawford y puntuación Simple/Gammon/Backgammon. |
| 8 | **Batalla Naval** | `battleship_game` | Información oculta real (`EventVisibility::OnlyPlayer`), fase de despliegue de 5 buques (`[5,4,3,3,2]`) en grilla 10×10, variante configurable de ráfaga (`extra_turn_on_hit`) y revancha inmediata (`RematchCommand`). |
| 9 | **Ludo** | `ludo_game` | Circuito de 52 casillas + pasillo de meta de 5 pasos para 2–4 jugadores, salida con 6, penalización por tres 6 consecutivos, 8 casillas seguras (4 salidas + 4 estrellas) y tirada extra por captura o llegada exacta a meta. |
| 10 | **Mille Bornes** | `mille_bornes_game` | Carrera de cartas a 1000 km (con extensión opcional a 1200 km), límite de 2 cartas de 200 km, Peligros/Remedios, las 4 Cartas de Seguridad (*Safeties*) con turno extra e intercepción reactiva *Coup Fourré* (+300 pts). |
| 11 | **Monopoly** | `monopoly_game` | Circuito oficial de 40 casillas, mazos de Suerte y Arca Comunal, subastas cuando no se compra un solar, construcción uniforme de casas/hoteles por grupo de color, hipotecas (+10% al levantar), cárcel por 3 dobles e intercambios comerciales. |
| 12 | **UNO** | `uno_game` | Mazo oficial de 108 cartas, cartas de acción (`Skip`, `Reverse` = `Skip` en 2J, `+2`, `Wild`, `Wild +4`), grito y penalización de `"¡UNO!"` (+2 cartas), desafío formal de `Wild +4` (+4 o +6 cartas) e intercepción fuera de turno (*Jump-In*). |
| 13 | **Crisis (T.E.G.)** | `crisis_game` | Mapa geopolítico de 30 territorios y 6 continentes, objetivos secretos + conquista global, fases de Incorporación, Ataque con dados (hasta 3v3, empate favorece al defensor) y Reagrupamiento, robo de tarjeta por conquista y bono `+2` en país propio. |

---

## 3. Ciclo de Vida de un Comando y Visibilidad de Eventos

```
[Input en Godot] ──► OpenTableBridge::send_command_json(player_id, json)
                            │
                            ▼
             Session::process_command(player_id, Box<dyn Command>)
                            │
        ┌───────────────────┴───────────────────┐
        ▼ (1. Validación de Turno y Reglas)     ▼ (En caso de error)
RuleEngine::validate(&mut World, player, cmd)   Emite MoveRejectedEvent(reason)
        │                                               │
        ▼ (2. Mutación del World ECS)                   ▼
Retorna Vec<Box<dyn Event>> con EventVisibility  Señal `move_rejected` en Godot
        │
        ├─► ActionHistory::record()  (Guarda para Undo/Redo y Replay .otr)
        ├─► Transport::broadcast()   (Filtra eventos privados según PlayerId)
        └─► OpenTableBridge          (Emite señales GDScript: piece_moved, event_json, game_over)
```

### Filtrado de Información Oculta (`EventVisibility`)
Para evitar trampas en red (como inspeccionar las cartas del rival o la posición de sus barcos en memoria):
- `EventVisibility::Public`: Se transmite a todos los jugadores y espectadores.
- `EventVisibility::OnlyPlayer(PlayerId)`: El Host/Relay solo envía el payload real a ese `PlayerId` específico.
- `EventVisibility::Hidden`: Uso interno del servidor/motor.

---

## 4. Arquitectura de la Interfaz en Godot / Redot (`godot_project`)

Todos los tableros siguen un contrato visual y estructural uniforme:
1. **Zona Superior Compacta (`TurnIndicator` + `TurnTimerHud` + `GameAppMenu`)**:
   - `TurnIndicator` (`res://turn_indicator.gd`): Muestra el color del jugador activo, su nombre (`Turno: Jugador X`) y el badge regresivo compacto `TurnTimerHud` (`00:30` en formato `MM:SS`, con alerta visual ámbar/roja y pulso sonoro en los últimos 10 segundos).
   - `GameAppMenu` (`res://scenes/game_app_menu.gd`): Botón desplegable `☰ Opciones ▾` anclado en la esquina superior derecha que centraliza el selector de Modo/IA, tamaño/variante, Reglas del juego (`RulesPopup` alimentado por `RulesCatalog` en ES/EN), Guardar/Cargar partida, Guardar Replay (`.otr`), Ofrecer Tablas y Rendirse.
2. **Zona Central (Lienzo del Tablero)**:
   - Escalado adaptativo (`_on_layout_changed`) que centra el tablero automáticamente en resoluciones Desktop (`1280×720` a `4K`), Steam Deck (`1280×800`) y Móvil vertical (`375×667`).
   - Paridad estricta 1:1 entre `godot_project/<juego>_board.gd` y `godot_project/scenes/<juego>_board.gd`, verificada automáticamente por `tools/run_godot_tests.sh`.
3. **Zona Inferior (Acciones del Turno y Avisos)**:
   - Controles propios de la jugada activa (ej. `🎲 Tirar Dados`, `⏭️ Pasar Turno`, `⚡ ¡Coup Fourré!`, `🔥 ¡UNO!`) y mensajes de estado o rechazo de jugada.

---

## 5. Licenciamiento (`GPL-3.0-or-later`)

Todo el código fuente de **OpenTable SDK & Suite** (los 22 crates de Rust y el proyecto Godot/Redot) se distribuye bajo la licencia **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)** (ver [`LICENSE`](./LICENSE)), incluyendo la excepción explícita de enlace con el runtime de Godot/Redot y SDKs de plataforma (Steamworks, Android Nearby Connections, Apple MultipeerConnectivity).
