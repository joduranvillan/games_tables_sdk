# Cómo se integra este bridge con Godot/Redot

Estado (verificado en esta máquina): el crate **compila y carga** en
**Redot 26.2.alpha** (que internamente es **Godot 4.5.2**), y la cadena
motor Rust → `CheckersBridge` → señales → GDScript está probada en runtime
(`godot_project/tests/bridge_smoke.gd`, 7 chequeos en verde).

## El problema con Redot y cómo se resuelve

`gdext` (la crate `godot`) trae por defecto bindings precompilados contra
un Godot oficial. Redot es un **fork**, y aunque por dentro es Godot 4.5.2,
los hashes de sus funciones no coinciden con los de un Godot oficial de la
misma numeración. Al cargar la extensión, Redot rechaza el `.so` con un
error tipo `Failed to load utility function lerp ... hash mismatch`.

La solución (ya aplicada en `Cargo.toml`) es el feature **`api-custom`**:
gdext genera los bindings contra la API **exacta** del engine apuntado por
la variable `GODOT4_BIN`, ejecutándolo en tiempo de build para volcar su
`extension_api.json`.

Queda un obstáculo: el build script de gdext parsea `redot --version`
(`26.2.alpha…`) y aborta porque exige un Godot de major **4**. Redot sí
mantiene un `header` con `version_major: 4` dentro de su
`extension_api.json`, pero gdext frena antes de leerlo. Por eso usamos un
shim (`tools/redot_gdext_shim.sh`) que intercepta **solo** `--version` y
responde `4.5.2.stable…`, delegando todo lo demás (incluido
`--dump-extension-api`) al `redot` real.

`GODOT4_BIN` queda fijado al shim en `.cargo/config.toml` (ruta relativa),
así que **no hay que exportar nada a mano**: un `cargo build` en un clon
limpio funciona con solo tener `redot` en el PATH.

## Requisitos

- Rust estable reciente (probado con 1.96).
- Redot 4.x / 26.x en el PATH como `redot` (o exportá `REDOT_BIN`).
- `libclang` (bindgen lo necesita con `api-custom`). En Arch: `pacman -S clang`.

## Recompilar el bridge

```bash
# Desde la raíz del repo. El .cargo/config.toml ya provee GODOT4_BIN.
cargo build -p open_table_godot
# el .so queda en target/debug/libopen_table_godot.so
```

Si cambiás de versión de Redot, forzá el rerun del generador de bindings:

```bash
cargo clean -p godot-bindings && cargo build -p open_table_godot
```

## Si algún día migrás a un Godot OFICIAL (no Redot)

Ahí ya no hace falta ni el shim ni `api-custom`: alcanza con
`godot = { version = "0.2", features = ["api-4-2"] }` (o el `api-4-x` que
corresponda a tu editor) y borrar el `[env]` de `.cargo/config.toml`.
