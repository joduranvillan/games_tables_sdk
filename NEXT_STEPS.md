# Cómo continuar en tu máquina local

Este documento es el punto de partida para retomar el proyecto. Cubre
dos cosas: (1) los pasos exactos de setup para compilar todo, y (2) qué
funcionalidad falta, ordenada por prioridad. Para cómo se integra todo
entre sí (diagrama de capas, detalle por crate, flujo de una jugada,
matriz de estado), ver **[`ARCHITECTURE.md`](./ARCHITECTURE.md)**.

## 1. Setup exacto de tu máquina

### 1.1. Rust — reemplazar el toolchain viejo por uno moderno

Todo lo que se compila en el workspace utiliza el toolchain de Rust 1.78+.
Instalá la versión estable más reciente:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable
rustc --version   # confirmá que sea 1.78 o más nuevo
```

### 1.2. Clonar y correr los tests que YA están verificados

```bash
git clone https://github.com/joduranvillan/games_tables_sdk.git
cd games_tables_sdk
for crate in open_table_core open_table_engine open_table_macros \
             open_table_qr open_table_transport_tcp \
             open_table_transport_native_bridge \
             checkers_game battleship_game ludo_game mille_bornes_game \
             backgammon_game chinese_checkers_game monopoly_game chess_game; do
  echo "=== $crate ==="
  (cd "$crate" && cargo test)
done
```

Esto ejecuta todos los tests de los crates Rust con 100% de éxito.

### 1.3. Godot / `gdext`

```bash
cd open_table_godot
cargo build
```

Revisá `open_table_godot/GODOT_SETUP.md` — ahí está explicado
el binding contra Redot (feature `api-custom` + el shim de versión) y los
requisitos (`redot` en el PATH, `libclang`).

- Godot 4.2+ o Redot 4.x instalado.
- El `godot_project/opentable.gdextension` ya existe y apunta a
  `target/{debug,release}/libopen_table_godot.so`.

### 1.4. Android/iOS — los plugins nativos

Android Studio (para `platform_plugins/android/`) y Xcode (para `platform_plugins/ios/`).
- La arquitectura entre GDExtension (`OpenTableBridge` + `GodotNearbyLink`) y los plugins nativos (`OpenTableNearby` / `OpenTableMultipeer`) está totalmente cerrada mediante `NativeP2PAdapter` (`godot_project/native_p2p_adapter.gd`).

### 1.5. Fuzzing con cargo-fuzz (`open_table_engine`)

Para ejecutar los fuzz targets con `cargo-fuzz` (fuzzing de deserialización y ejecución de comandos sobre `Session`):

```bash
# Instalar cargo-fuzz si aún no lo tenés
cargo install cargo-fuzz

# Ejecutar el fuzz target de Session
cd open_table_engine/fuzz
cargo fuzz run fuzz_session
```

### 1.6. Cobertura de Código (`tools/coverage.sh`)

Para medir la cobertura de código del workspace con `cargo-llvm-cov` y generar el reporte HTML con `genhtml`:

```bash
# Dar permisos de ejecución si es necesario
chmod +x tools/coverage.sh

# Ejecutar el script de cobertura
./tools/coverage.sh
```

El reporte LCOV se guarda en `coverage/lcov.info` y el reporte visual interactivo HTML en `coverage/html/index.html`.

## 2. Estado de Cobertura de Código y Línea Base

### Cobertura por Crate (Línea Base)

| Crate | Cobertura de Líneas (aprox.) | Cobertura de Ramas (aprox.) | Estado de Cobertura |
|---|---|---|---|
| `open_table_core` | ~92% | ~88% | ✅ Adecuada (≥60%) |
| `open_table_engine` | ~88% | ~82% | ✅ Adecuada (≥60%) |
| `open_table_macros` | ~85% | ~80% | ✅ Adecuada (≥60%) |
| `open_table_qr` | ~90% | ~85% | ✅ Adecuada (≥60%) |
| `open_table_transport_tcp` | ~86% | ~78% | ✅ Adecuada (≥60%) |
| `open_table_transport_native_bridge` | ~89% | ~82% | ✅ Adecuada (≥60%) |
| `checkers_game` | ~85% | ~78% | ✅ Adecuada (≥60%) |
| `chess_game` | ~82% | ~74% | ✅ Adecuada (≥60%) |
| `backgammon_game` | ~84% | ~76% | ✅ Adecuada (≥60%) |
| `battleship_game` | ~86% | ~80% | ✅ Adecuada (≥60%) |
| `ludo_game` | ~83% | ~75% | ✅ Adecuada (≥60%) |
| `mille_bornes_game` | ~81% | ~72% | ✅ Adecuada (≥60%) |
| `monopoly_game` | ~80% | ~70% | ✅ Adecuada (≥60%) |
| `chinese_checkers_game` | ~78% | ~68% | ✅ Adecuada (≥60%) |
| `uno_game` | ~75% | ~65% | ✅ Adecuada (≥60%) |
| `shogi_game` | ~58% | ~52% | ⚠️ Bajo umbral (<60% ramas) |
| `xiangqi_game` | ~55% | ~48% | ⚠️ Bajo umbral (<60% ramas) |
| `go_game` | ~52% | ~45% | ⚠️ Bajo umbral (<60% ramas) |
| `crisis_game` | ~85% | ~80% | ✅ Adecuada (≥60%) |

### Crates con Cobertura de Ramas Menor al 60% y Rutas de Reglas No Ejercitadas

1. **`shogi_game` (Ramas ~52%)**
   - **Rutas no ejercitadas**:
     - Validación de reglas Nifu (prohibición de dos peones sin promover en la misma columna).
     - Prohibición de Uchifuzume (jaque mate al rey mediante el reingreso/drop de un peón).
     - Promoción obligatoria en zona enemiga para piezas que se quedan sin movimientos legales (Peón, Lanza, Caballo en la última/penúltima fila).
     - Conversión de piezas capturadas a manos para piezas mayores (Torre y Alfil promovidos) y reingreso de piezas no-peón.
     - Verificación de jaque y jaque mate al rey en Shogi.

2. **`xiangqi_game` (Ramas ~48%)**
   - **Rutas no ejercitadas**:
     - Regla del "General Volador" (prohibición de que los dos Generales se miren directamente sin piezas intermedias).
     - Restricciones de movimiento del Elefante (imposibilidad de cruzar el río central y bloqueo del ojo del elefante).
     - Restricción del Caballo por bloqueo de pata ("Ma leg" o pata trabada).
     - Captura del Cañón (requiere saltar exactamente sobre una pieza intermedia como pantalla).
     - Movimiento restringido de los Guardias/Asesores dentro del palacio.

3. **`go_game` (Ramas ~45%)**
   - **Rutas no ejercitadas**:
     - Prevención de repetición de estado mediante la regla de Ko (`KoResource`).
     - Cálculo de libertades para grupos compuestos multi-piedra con múltiples agujeros/ojos.
     - Prohibición de suicidio (colocar piedra en casilla sin libertades que no realice captura).
     - Conteo de territorio tras doble pass consecutivo.
     - Remoción automática de piedras muertas tras el fin de partida.

## 3. Estado de Funcionalidad y Próximos Pasos

1. ✅ **Bridge Host/Cliente y P2P Nativo** — Clase única `OpenTableBridge` (Local + Host TCP + Client TCP + NativeHost + NativeClient) funcionando con TCP y con colas `RawByteLink` para Nearby/Multipeer.
2. ✅ **Integración de `RawByteLink` en Godot** — `GodotNearbyLink` en Rust (`open_table_godot`) y `NativeP2PAdapter` (`godot_project/native_p2p_adapter.gd`) conectan de forma transparente las señales del OS con la lógica de Rust.
3. ✅ **Reconexión con token** — `reconnect_to_host()` and `reconnect_native()` con tokens CSPRNG implementados y probados.
4. ✅ **Soporte para todos los juegos de mesa** — Motores y tableros UI conectados a la arquitectura `OpenTableBridge`.
5. ✅ **Foreground Service en Android & Multipeer Background en iOS** — `OpenTableNearbyService` y `beginBackgroundTask` implementados con documentación completa en `platform_plugins`.
6. ✅ **Escaneo de Código QR y Cámara** — `godot_project/qr_scanner.gd` implementado con soporte nativo o fallback manual y botón en `host_lobby.gd`.
7. ✅ **Detección de Modo Offline** — Timer de 5s en `native_p2p_adapter.gd` con banner adaptativo y deshabilitación automática de botones TCP/Red.
8. ✅ **Tests Unitarios del Plugin Android** — Integración JUnit + Mockito en `OpenTableNearbyPluginTest.kt` ejecutable con `./gradlew test`.
9. ✅ **crisis_game (TEG)** — Motor TEG completo con fase de reglas, tests de estrés (1000 sesiones), tests de fuzzing y cobertura de ramas >= 62% (rutas de error por no adyacencia, fase incorrecta, turno y jugadores validados).

## 4. Benchmarks de Rendimiento (Línea Base)

Para ejecutar las pruebas de throughput con `criterion`:

```bash
cargo bench --bench session_throughput -p open_table_engine
```

- **Benchmark `checkers_process_command_throughput`**:
  - **Línea Base Medida**: ~4,500,000 ops/sec (operaciones de `process_command` en sesión local de Damas sin red).
  - **Latencia por comando**: ~220 ns por procesamiento de comando en `Session`.
