# Registro de Cambios (Changelog) - Games Tables SDK

Todos los cambios notables en este proyecto serán documentados en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [1.0.0] — 2026-04-23

### Added
- **Catálogo Completo de 14 Juegos Canónicos**: Incorporación de **El Juego de la Oca** (`goose_game`) con espiral de 63 casillas, las 13 Ocas ("De oca a oca y tiro porque me toca"), Puentes, Posada, Dados (26 y 53), Pozo, Laberinto, Cárcel, Calavera (58 → 1), rebote exacto en el Jardín de la Oca (63) y animaciones de casillas especiales.
- **Cubilete y Dados 3D (`DiceRoller3D`)**: Simulación tridimensional de dados integrada en `DiceWidget` para los 5 juegos basados en dados (`backgammon`, `ludo`, `monopoly`, `crisis`, `goose`) con fallback determinista en modo headless.
- **Multijugador Offline QR + LAN (`UDP 19451` / `TCP 19450`)**: Creación y unión de partidas locales sin servidor central desde `MainMenu` mediante descubrimiento automático LAN y código QR (`opentable://join?...`), con transferencia automática del bridge a cualquiera de los 14 tableros (`GameManager.claim_network_bridge()`).
- **Multijugador Online Relay WebSocket (`OpenTableRelayServer` + `RelayClient`)**:
  - Creación de salas con código de 6 caracteres (`create_online_relay_room`) y unión remota (`join_online_relay_room`) para los 14 juegos.
  - Sincronización autoritativa de estado (`SyncState` / `sync_state_received`) al conectarse o reconectarse un par remoto (`apply_state_json` en Rust y `apply_sync_state_json` en los 14 tableros).
  - URL del servidor Relay WebSocket configurable y persistente en `SettingsMenu` (`user://settings.cfg`) y editable en tiempo real desde el diálogo de conexión del Menú Principal.
- **Bloqueo de Turno por Jugador Local en Red (`is_local_turn_allowed()`)**: Validación activa en los 14 tableros (`chess`, `checkers`, `go`, `shogi`, `xiangqi`, `chinese_checkers`, `backgammon`, `battleship`, `ludo`, `mille_bornes`, `monopoly`, `uno`, `crisis`, `goose`) que impide mover piezas o jugar cartas fuera del turno asignado (`local_network_player_id`).
- **Reconexión Automática TCP y Relay**: Bucle de supervisión en `GameManager` que reintenta automáticamente la reconexión TCP y WebSocket Relay ante microcortes de red, notificando el estado en `NetworkStatusHud`.
- **Suite de 47 Smoke Tests Headless en Godot/Redot**: Nuevas pruebas integrales `goose_smoke.gd`, `dice_3d_smoke.gd`, `qr_lan_multiplayer_smoke.gd` y `network_full_integration_smoke.gd`, integradas en CI (`ci.yml`) y en el validador de release (`verify_p13.sh` en `release.yml`).

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

## [Unreleased]

### Added
- **Suite de Tests Headless Godot**: Se agregaron smoke tests para Mille Bornes (`mille_bornes_smoke.gd`), Damas Chinas (`chinese_checkers_smoke.gd`), Monopoly (`monopoly_smoke.gd`) y Batalla Naval (`battleship_smoke.gd`).
- **Pruebas de Regresión Visual**: Script `visual_regression.gd` para verificar el renderizado en los 13 tableros de Godot.
- **Herramientas de Métricas y Calidad**: Script `tools/metrics.sh` que evalúa warnings de Clippy, formato con `cargo fmt`, warnings de `cargo doc` y conteo de `TODOs`.
- **Validador de Consistencia del Workspace**: Script `tools/verify_workspace.sh` para verificar coincidencia entre los miembros del workspace, funciones exported en `lib.rs`, tests unitarios y documentación.
- **Generador de Changelog**: Script `tools/generate_changelog.sh` que extrae commits categorizados por tipo (`feat:`, `fix:`, `docs:`, etc.).
- **Mejoras de Interfaz de Usuario**: Componentes Godot `rules_popup.gd`, `error_logger.gd` y `dice_widget.gd` para retroalimentación visual y visualización de dados/reglas.

### Changed
- **Reescritura de `crisis_game` (Evolución a TEG)**: Rediseño completo del motor pasando de clon simplificado a reglas de TEG (30 territorios, 6 continentes, objetivos secretos, tarjetas de ejército y canjes).
- **Runner de Pruebas Unificado**: `tools/run_godot_tests.sh` actualizado para ejecutar la suite completa de 18+ scripts headless de Godot/Redot.
- **Permisos de Ejecución**: Permisos `chmod +x` restaurados e indeksados en Git para todos los scripts en `tools/` y `run_test.sh`.

### Fixed
- **Permisos de Ejecución en CI/Entorno Local**: Corregido el error de `Permission denied (os error 13)` al invocar `redot_gdext_shim.sh` durante los builds de `godot-ffi` y `godot-core`.
- **Inicialización de Métodos de Bridge**: Corregida la firma de `start_local_match_battleship` en `open_table_godot/src/lib.rs`.

### Removed
- **Código Obsoleto de Prototipos**: Eliminadas configuraciones y structs obsoletas en los motores de prueba.

---

## [0.1.0] - 2026-08-01

### Backgammon
- **Tiradas Dobles**: Cuando un jugador saca el mismo valor en ambos dados (ej. 4 y 4), recibe 4 movimientos de ese valor.
- **Paso de Turno Automático**: Detección de bloqueos con emisión de `NoValidMovesEvent`.
- **Regla estricta de Bear-off**: Ajuste para permitir sacar fichas mayores solo si no hay fichas lejanas.

### Batalla Naval (Battleship)
- **Validación de Flota**: Rechazo de colocación diagonal o superpuesta de barcos.
- **Validación de Disparos**: Rechazo de ataques duplicados a la misma coordenada.

### Monopoly
- **Grupos de Color y Renta Duplicada**: Tablero con propiedades por grupos de color y cobro x2 si posee el grupo completo.
- **Mecánica de Dobles**: Mantener turno al sacar dobles y decisiones pendientes.

### Shogi, Xiangqi y Go
- **Shogi**: Tablero 9x9 con drops, promoción y reglas de Nifu.
- **Xiangqi**: Tablero 9x10 con palacio, río, cañones y regla de General Volador.
- **Go**: Regla de Ko y validación anti-suicidio.

### UNO
- **Estructura y Mazo**: 108 cartas, orden de turno bidireccional y acumulador de penalidades (+2/+4 stacking).
