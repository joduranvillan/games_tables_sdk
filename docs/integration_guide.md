# Guía de Integración — OpenTable SDK

Esta guía describe cómo integrar el **OpenTable SDK** en aplicaciones Rust externas y proyectos de Godot / Redot Engine.

---

## 1. Integración en Rust

Para utilizar OpenTable SDK en un proyecto externo de Rust, sigue estos pasos:

### Paso 1: Añadir dependencias en `Cargo.toml`

Agrega `open_table_core`, `open_table_engine` y el crate correspondiente al juego que deseas utilizar (por ejemplo, `chess_game`):

```toml
[dependencies]
open_table_core = "0.1.0"
open_table_engine = "0.1.0"
chess_game = "0.1.0"
```

### Paso 2: Código completo de ejemplo (Creación de sesión, comandos y eventos)

A continuación se presenta un ejemplo completo y ejecutable que muestra cómo instanciar una partida de Ajedrez, enviar un comando de movimiento y procesar los eventos resultantes:

```rust,no_run
use open_table_core::ids::{PlayerId, SessionId};
use chess_game::{new_chess_session, MovePieceCommand, Position, PieceMovedEvent};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Definir los identificadores de jugador y sesión
    let white = PlayerId(1);
    let black = PlayerId(2);
    let session_id = SessionId(100);
    let seed = 42;

    // 2. Crear una nueva sesión de Ajedrez
    let mut session = new_chess_session(session_id, seed, white, black);

    // Verificar el jugador que tiene el turno activo (Blancas inicia)
    assert_eq!(session.current_player(), white);

    // 3. Crear y procesar un comando (Mover peón de e2 a e4 => fila 1, col 4 a fila 3, col 4)
    let move_command = MovePieceCommand {
        player: white,
        from: Position::new(1, 4),
        to: Position::new(3, 4),
        promote_to: None,
    };

    let events = session.process_command(white, move_command)?;

    // 4. Procesar los eventos emitidos por el motor
    for event in events {
        if let Some(piece_moved) = event.downcast_ref::<PieceMovedEvent>() {
            println!(
                "Pieza movida por jugador {:?}: desde ({}, {}) hasta ({}, {})",
                piece_moved.player,
                piece_moved.from.row, piece_moved.from.col,
                piece_moved.to.row, piece_moved.to.col
            );
        }
    }

    Ok(())
}
```

---

## 2. Integración en Godot / Redot Engine

Para integrar el motor en un proyecto de **Godot Engine 4.x** o **Redot Engine**:

### Paso 1: Descargar/Compilar la extensión GDExtension (`.so` / `.dll` / `.dylib`)

Compila o descarga la extensión nativa `open_table_godot`:

```bash
cargo build --release -p open_table_godot
```

El artefacto resultante (`libopen_table_godot.so` en Linux, `.dll` en Windows o `.dylib` in macOS) se genera en `target/release/`.

### Paso 2: Copiar al proyecto de Godot

1. Copia la librería compilada a la carpeta de binarios de tu proyecto de Godot (por ejemplo `res://bin/`).
2. Configura o copia el manifiesto `.gdextension` (`res://bin/open_table_godot.gdextension`).

### Paso 3: Uso desde GDScript

Instancia el nodo `OpenTableBridge`, conecta las señales de evento y cambio de estado, y arranca la partida local o de red:

```gdscript
extends Node

var bridge: OpenTableBridge

func _ready() -> void:
	# Instanciar el bridge nativo
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	# Conectar señales principales
	bridge.event_emitted.connect(_on_event_emitted)
	bridge.state_changed.connect(_on_state_changed)

	# Iniciar partida local de Ajedrez (Blancas ID=1, Negras ID=2)
	bridge.start_local_match_chess(1, 2)
	print("Jugador actual: ", bridge.current_player())

func _on_event_emitted(event_type: String, event_data: Dictionary) -> void:
	print("Evento recibido del motor: ", event_type, " -> ", event_data)

func _on_state_changed() -> void:
	queue_redraw()
```

---

## 3. Documentación Adicional

- [Arquitectura general del SDK](../ARCHITECTURE.md)
- [Uso detallado del Bridge de Godot](../open_table_godot/BRIDGE_USAGE.md)
- [Hoja de ruta y próximos pasos](../NEXT_STEPS.md)
