# Investigación: gdext 0.2.4 no registra múltiples clases

## Problema

Cuando un `.gdextension` (Rust) tiene múltiples structs con `#[derive(GodotClass)]`, gdext **genera el código para ambas**, pero **Godot solo ve la primera**.

## Síntoma

```
SCRIPT ERROR: Parse Error: Identifier "CheckersBridgeClient" not declared in the current scope.
```

## Investigación realizada

### 1. Las clases SÍ se compilany están en el binario
```bash
nm target/release/libopen_table_godot.so | grep -i "CheckersBridgeHost\|CheckersBridgeClient"
# Ambas aparecen: ✓ Existe el problema en registro, no en compilación
```

### 2. Mecanismo de registro en gdext

**Flujo de registro:**
- `#[derive(GodotClass)]` — genera `impl GodotClass for MyType`
- `#[godot_api]` — genera `impl ImplementsGodotApi for MyType` + `__register_methods()`
- `plugin_execute_pre_main!` — macro que registra funciones antes de main
  - Pushea funcion de registro a un `static Mutex<Vec<fn()>>`
  - Esta ejecución sucede per-struct en sus propios contextos

**El punto de fallo:**
- Cada `#[godot_api] impl` genera su propio `plugin_execute_pre_main!`
- Pero **all classes deben ser registradas EN EL MISMO PUNTO GLOBAL** durante `gdext_rust_init`
- gdext parece asumir que **solo hay UNA clase** y no itera sobre todas

### 3. Archivos investigados

- `/godot-macros-0.2.4/src/gdextension.rs` — genera `#[gdextension]` y entry point
- `/godot-macros-0.2.4/src/class/derive_godot_class.rs` — genera `#[derive(GodotClass)]`
- `/godot-core-0.2.4/src/registry/plugin.rs` — struct `ClassPlugin` para registro

### 4. Conclusión

**gdext 0.2.4 no fue diseñado para múltiples clases en una sola extensión**, o hay un bug en cómo se itera sobre todas ellas durante inicialización.

## Soluciones viables

### Opción A: Actualizar gdext (probablemente la solveré)
Versiones más nuevas (0.2.4+) pueden tener el fix. Requiere:
- Actualizar `godot = "0.2.4"` a versión más nueva en `Cargo.toml`
- Puede quebrar API, necesitaría porting

### Opción B: Refactor a single struct con dispatch interno
Fusionar `CheckersBridgeHost` + `CheckersBridgeClient` en un único `CheckersBridge` que internamente dispatch por modo.
- El código Rust de lógica es el mismo (ya verificado)
- Problema: Rust borrowing complejo (intentado, parcial fail)
- Workaround: Usar `unsafe` block o `RefCell`/`Mutex` para shared state

### Opción C: Dos extensiones separadas
Crear `libopen_table_host.so` + `libopen_table_client.so`, cada una con su clase.
- Simple pero más mantenimiento
- Dos `.gdextension` en Godot

## Recomendación

**Probar Opción A primero** (actualizar godot-rust). Si fallaba, **Opción B con RefCell wrapper** es clean.

## Archivos de test generados

- `test_multiple_classes.rs` — minimal reproducible example (no compilado)

## Resolución

Se implementó la **Opción B**: `CheckersBridgeHost` + `CheckersBridgeClient`
se fusionaron en una única clase `CheckersBridge` (`src/lib.rs`) con un enum
interno `BridgeMode { None, Local, Host, Client }` que dispatch-ea según el
modo activo. De paso se sumó el modo `Local` (hotseat sin red), que ya
existía como API previa a la separación host/cliente y se había roto en el
camino — así la clase soporta los tres modos con los que se usa hoy en
Godot (`checkers_board.gd` en local, `test_tcp_bridge.gd` en red).

Verificado en runtime (no solo `cargo build`) con Redot 26.2 headless:
- `tests/bridge_smoke.gd` (modo local): 7/7 asserts OK.
- `test_tcp_bridge.tscn` (modo host+cliente sobre TCP real): movimientos
  del host llegan al cliente por red y viceversa, movimiento inválido
  rechazado correctamente.

El problema de borrow-checker mencionado en la Opción B ("intentado,
parcial fail") se resolvió computando el `Result` de `process_command`
como valor *owned* antes de llamar a `self.emit_game_events(...)`, así el
borrow de `self.mode` termina (vía NLL) antes de necesitar un segundo
borrow de `self` completo.

No hizo falta la Opción A (actualizar gdext) ni la C (dos `.so`).
