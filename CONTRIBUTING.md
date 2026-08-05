# Guía de Contribución a OpenTable SDK

¡Bienvenido al desarrollo de OpenTable SDK! Esta guía documenta los estándares de código, flujos de trabajo y pasos para extender la plataforma con nuevos juegos o funcionalidades.

---

## 1. Requisitos de Entorno

Para compilar y probar el proyecto completo necesitas:

- **Rust**: Toolchain estable con edición 2021 (se recomienda `rustup`).
- **Herramientas Cargo**: `cargo-fmt` y `clippy`.
- **Make**: Para ejecutar los comandos abreviados definidos en el `Makefile`.
- **Redot / Godot 4.x** (Opcional): Para ejecutar los tests de integración con el motor gráfico en modo headless.
- **Android Studio / Xcode** (Opcional): Para la compilación de plugins nativos en `platform_plugins/`.

### Instalación de Pre-commit Hooks

Para garantizar que todo commit cumpla con el formato y estilo sin advertencias:

```bash
make install-hooks
```

Este comando copiará el script de pre-commit a `.git/hooks/pre-commit`, el cual ejecutará automáticamente:
- `cargo fmt --check --all`
- `cargo clippy --workspace -- -D warnings`

---

## 2. Cómo Añadir un Nuevo Juego Paso a Paso

Para agregar un nuevo juego de mesa al SDK (por ejemplo, `domino_game`), sigue esta secuencia estructurada:

### Paso 1: Crear el crate del juego
Crea una carpeta en la raíz del workspace (ejemplo `domino_game`) con un archivo `Cargo.toml` básico:

```toml
[package]
name = "domino_game"
version = "0.1.0"
edition = "2021"

[dependencies]
open_table_core = { path = "../open_table_core" }
open_table_engine = { path = "../open_table_engine" }
open_table_macros = { path = "../open_table_macros" }
serde = { version = "1", features = ["derive"] }

[dev-dependencies]
serde_json = "1"
```

### Paso 2: Registrar en el Workspace raíz
Añade `"domino_game"` a la lista `members` en el `Cargo.toml` raíz del proyecto.

### Paso 3: Definir Comandos, Eventos, Componentes y Recursos
Usa las macros de `open_table_macros` para derivar automáticamente las implementaciones del trait:

```rust
use open_table_core::prelude::*;
use open_table_macros::{GameCommand, GameEvent, GameResource};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, GameCommand)]
pub struct PlaceTileCommand {
    pub tile_id: u32,
    pub end: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize, GameEvent)]
pub struct TilePlacedEvent {
    pub player: PlayerId,
    pub tile_id: u32,
}
```

### Paso 4: Implementar las reglas de juego y registrarlas en `RuleEngine`
Define el estado del juego mediante un `Resource` (ej. `BoardResource`) y registra las funciones de sistema en el `RuleEngine`:

```rust
use open_table_engine::prelude::*;

pub fn register_rules(engine: &mut RuleEngine) {
    engine.add_handler::<PlaceTileCommand>(handle_place_tile);
}
```

### Paso 5: Añadir Tests de Reglas
Crea un test en `tests/game_rules.rs` para verificar que las transiciones de estado, eventos y validaciones del juego funcionan de forma determinista.

### Paso 6: Exponer en el Bridge de Godot (`open_table_godot`)
En `open_table_godot/src/lib.rs`, añade la fábrica o constructor correspondiente dentro de `OpenTableBridge` para permitir instanciar el nuevo juego desde scripts GDScript/C# en Godot.

---

## 3. Convenciones de Nombres

- **Traducción Conceptual**: Si la lógica de dominio se concibe originalmente en español (ejemplo: *Mover Ficha*, *Tablero*, *Ficha Colocada*), deben traducirse al **inglés en `snake_case` para campos/funciones y `PascalCase` para estructuras/enums**.
  - Comandos: `MovePieceCommand`, `DrawCardCommand`, `RollDiceCommand`
  - Eventos: `PieceMovedEvent`, `CardDrawnEvent`, `DiceRolledEvent`
  - Recursos: `BoardResource`, `DeckResource`, `TurnStateResource`
- **Serialización**: Todos los DTOs de red (`Command` y `Event`) deben derivar `Serialize` y `Deserialize` de `serde`.

---

## 4. Estándar de Cobertura Mínima

- Se exige un estándar de cobertura mínima del **65% de branches**.
- Puedes evaluar la cobertura localmente ejecutando el script especializado:

```bash
./tools/coverage.sh
```

---

## 5. Cómo Ejecutar los Tests de Godot Headless

Los tests del puente Godot/Redot se ejecutan sin interfaz gráfica (headless) utilizando el comando `make`:

```bash
make test-godot
```

O directamente mediante la invocación del binario Redot/Godot:

```bash
redot --headless --path godot_project --script res://tests/bridge_smoke.gd
```

---

## 6. Proceso de Release y Publicación en Crates.io (`cargo publish`)

Para publicar una nueva versión de los crates fundamentales (por ejemplo `open_table_core`):

1. **Incrementar Versión**: Ejecuta el script de sincronización de versión para actualizar todos los `Cargo.toml`:
   ```bash
   ./tools/bump_version.sh [--patch | --minor | --major]
   ```
2. **Validar la Verificación de Empaquetado**:
   ```bash
   cargo publish --dry-run -p open_table_core
   ```
3. **Publicar en Crates.io**:
   ```bash
   cargo publish -p open_table_core
   ```

