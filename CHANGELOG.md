# Registro de Cambios (Changelog) - Games Tables SDK

Todos los cambios notables en este proyecto serán documentados en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

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
