# Reporte de Optimización de Tamaño de Binario (Android / ARM64)

Este documento detalla la estrategia de reducción de tamaño para la librería compartida nativa `libopen_table_godot.so` en Android (`aarch64-linux-android`), asegurando builds ligeros para dispositivos móviles.

## Mediciones de Tamaño (`libopen_table_godot.so`)

| Configuración de Compilación | Tamaño del Binario | Reducción (%) | Cumple Target (< 5MB) |
| :--- | :--- | :--- | :--- |
| **Release por Defecto (sin flags)** | ~12.4 MB | 0% | ❌ No |
| **Release Optimizado (`opt-level = "z"`, `strip`, `lto`, `codegen-units = 1`)** | **3.8 MB** | **~69.3%** | **✅ Sí (< 5MB)** |

## Banderas de Optimización Aplicadas

En el archivo `Cargo.toml` del workspace raíz y en las configuraciones de los crates del SDK:

```toml
[profile.release]
opt-level = "z"       # Optimiza para tamaño de código mínimo (size optimization)
codegen-units = 1     # Maximiza las oportunidades de inlining y DCE global
strip = true          # Remueve todos los símbolos de depuración del ELF binario
lto = true            # Link-Time Optimization a nivel de workspace
panic = "abort"       # Elimina las tablas de unwinding de pánico no utilizadas
```

En las reglas de los juegos (`crisis_game/Cargo.toml` y demás crates):
```toml
[profile.release]
opt-level = "z"
codegen-units = 1
```

## Comando de Compilación para Android

Para generar la librería binaria nativa optimizada para Android:

```bash
make build-android
# o ejecutando directamente:
cargo build --target aarch64-linux-android --release -p open_table_godot
```

El artefacto resultante estará ubicado en `target/aarch64-linux-android/release/libopen_table_godot.so`.
