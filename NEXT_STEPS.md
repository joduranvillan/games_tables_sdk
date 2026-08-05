# Estado Actual del Proyecto y Próximos Pasos (OpenTable SDK)

## 1. Juegos Implementados (Estado de Reglas y Tests)

| Juego | Reglas Básicas | Reglas Completas | Tests Rust | Test Godot Headless | UI Godot |
|---|:---:|:---:|:---:|:---:|:---:|
| **Ajedrez** (`chess_game`) | ✅ | ⚠️ (sin enroque/al paso) | ✅ (100%) | ✅ (`chess_smoke.gd`) | ✅ |
| **Damas** (`checkers_game`) | ✅ | ⚠️ (sin captura obligatoria) | ✅ (100%) | ✅ (`bridge_smoke.gd`) | ✅ |
| **Go** (`go_game`) | ✅ | ⚠️ (sin regla de Ko) | ✅ (100%) | ✅ (`go_smoke.gd`) | ✅ |
| **Shogi** (`shogi_game`) | ✅ | ⚠️ (falta Nifu/Uchifuzume) | ✅ (100%) | ✅ (`shogi_smoke.gd`) | ✅ |
| **Xiangqi** (`xiangqi_game`) | ✅ | ⚠️ (falta General Volador) | ✅ (100%) | ✅ (`xiangqi_smoke.gd`) | ✅ |
| **Backgammon** (`backgammon_game`) | ✅ | ⚠️ (sin doubling cube) | ✅ (100%) | ✅ (`backgammon_smoke.gd`) | ✅ |
| **Batalla Naval** (`battleship_game`) | ✅ | ⚠️ (tablero 8x8) | ✅ (100%) | ✅ | ✅ |
| **Ludo** (`ludo_game`) | ✅ | ⚠️ (24 casillas) | ✅ (100%) | ✅ (`ludo_smoke.gd`) | ✅ |
| **Mille Bornes** (`mille_bornes_game`) | ✅ | ⚠️ (meta 200) | ✅ (100%) | ✅ | ✅ |
| **Monopoly** (`monopoly_game`) | ✅ | ⚠️ (16 casillas) | ✅ (100%) | ✅ | ✅ |
| **Uno** (`uno_game`) | ✅ | ⚠️ (sin intercepción) | ✅ (100%) | ✅ (`uno_smoke.gd`) | ✅ |
| **Crisis / TEG** (`crisis_game`) | ✅ | ✅ (30 terr, 6 cont, obj. sec) | ✅ (100%) | ✅ (`crisis_smoke.gd`) | ✅ |

## 2. `crisis_game` Reescrito como TEG — Estado

- **Motor completo TEG**: 30 territorios, 6 continentes, objetivos secretos, tarjetas de ejército y canje.
- **Fases de juego**: Distribución inicial, Colocación de ejércitos, Ataque con dados, Fortificación y Fin de turno.
- **Cobertura y estrés**: Cobertura de ramas ≥ 62% con validaciones estrictas de error (no adyacencia, fuera de fase, turno incorrecto). Soportó tests de estrés con 1,000 sesiones concurrentes y fuzzing con `cargo-fuzz`.

## 3. Tests de Godot Headless — Estado de Scripts

Ejecutables mediante `tools/run_godot_tests.sh` en Redot 4.5.2 (Godot 4.x):
- `bridge_smoke.gd`: ✅ Puente GDScript <-> Rust, emisión de señales y ciclo local.
- `chess_smoke.gd`: ✅ Simulación de movimientos de Ajedrez.
- `shogi_smoke.gd`: ✅ Captura y reingreso de piezas (drops).
- `go_smoke.gd`: ✅ Colocación de piedras, captura de libertades y pase.
- `uno_smoke.gd`: ✅ Robo de cartas, coincidencia de color/número y comodines.
- `ludo_smoke.gd`: ✅ Avance con dado y colisiones en casillas.
- `crisis_smoke.gd`: ✅ Declaración de ataque, tirada de dados y fortificación en TEG.
- `backgammon_smoke.gd`: ✅ Movimiento con dados y ficha a la barra.
- `xiangqi_smoke.gd`: ✅ Movimiento de Cañón con pantalla y piezas del palacio.
- `test_spectator.gd`: ✅ Transmisión de eventos a espectadores sin filtrado.
- `test_native_p2p_adapter.gd`: ✅ Simulación de reconexión y adaptador P2P.

## 4. Próximas Prioridades (por orden de ejecución)

1. **Completar Reglas Avanzadas de Shogi (`shogi_game`)**: Implementar validación de Nifu (dos peones sin promover en la misma columna) y Uchifuzume (jaque mate al rey mediante el reingreso de un peón).
2. **Tests Headless de Red para Godot**: Crear scripts de prueba headless que ejerzan el flujo de reconexión TCP y simulación de desconexión bajo pérdida de paquetes.
3. **UI Móvil Adaptativa**: Ajustes responsivos para pantallas de smartphones y soporte de gestos táctiles en `godot_project/`.

## 5. Deuda Técnica Conocida

- **0 TODOs activos** en el código fuente de los crates de Rust y GDScript.
- **Plugins nativos móviles (`platform_plugins/`)**: `OpenTableNearby` (Android) y `OpenTableMultipeer` (iOS) probados en arquitectura mock/unit-test; requieren compilación nativa en Android Studio / Xcode.
- **Simplificaciones voluntarias de reglas**: Documentadas en la tabla anterior y en cada `README.md` individual para mantener la agilidad del engine.
