# OpenTable SDK — Godot / Redot Addon (`addons/open_table/`)

Este addon empaqueta el puente GDExtension (`OpenTableBridge`) y las utilidades del **OpenTable SDK v1.0.0** para que cualquier proyecto de Godot 4.1+ o Redot pueda integrarlo copiando la carpeta `addons/open_table/`.

## Instalación rápida

1. Copia el directorio `addons/open_table/` dentro de la carpeta `res://addons/open_table/` de tu proyecto Godot/Redot.
2. Compila la librería nativa para tu plataforma desde la raíz del workspace Rust:
   ```bash
   cargo build --release -p open_table_godot
   ```
3. En el editor de Godot/Redot, abre **Proyecto -> Ajustes del Proyecto -> Plugins** y activa **OpenTable SDK**.

## Plataformas soportadas en `open_table.gdextension`

- **Linux**: `x86_64`, `arm64` (`.so`)
- **Windows**: `x86_64`, `arm64` (`.dll`)
- **macOS**: Universal / `x86_64` / `arm64` (`.dylib`)
- **Android**: `arm64` (`aarch64`), `x86_64` (`.so`)
- **iOS**: `arm64` (`.dylib`)

## Uso básico en GDScript

```gdscript
var bridge := OpenTableBridge.new()
add_child(bridge)
bridge.init_local("chess")

# Consultar movimientos legales
var moves: Array = bridge.get_legal_moves(1)

# Exportar partida en formato estándar PGN / FEN
var fen: String = bridge.export_chess_fen()
var pgn: String = bridge.export_chess_pgn("Jugador 1", "Jugador 2")
```
