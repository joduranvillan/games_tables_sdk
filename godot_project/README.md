# Proyecto Redot — demo de damas

Escena mínima jugable de damas con la vista en Redot/Godot y todas las
reglas corriendo en el motor Rust (`checkers_game` + `open_table_engine`)
a través del nodo nativo `OpenTableBridge` (crate `open_table_godot`).

Es el "vertical slice" que valida la cadena completa **lógica Rust →
bridge GDExtension → señales → UI**. La escena principal (`main.tscn`)
juega en modo **local** (dos jugadores en el mismo dispositivo, sin
red) vía `checkers_board.gd`. El modo **host/cliente por red real**
(TCP) también existe en el mismo bridge, pero solo se ejerce hoy desde
la escena de prueba `test_tcp_bridge.tscn` — ver
`../open_table_godot/BRIDGE_USAGE.md` para la API completa de los tres
modos (Local/Host/Client) y `../ARCHITECTURE.md` para el diseño general.

## Correr

```bash
# 1. Compilar el bridge (desde la raíz del repo). Genera
#    target/debug/libopen_table_godot.so, que .gdextension referencia.
cargo build -p open_table_godot

# 2. Abrir el proyecto en el editor…
redot --path godot_project -e
#    …o correrlo directo:
redot --path godot_project
```

## Test headless (sin abrir ventana)

Verifica en runtime que el bridge arranca la partida, valida movimientos
contra el motor real y emite las señales correctas (modo local):

```bash
redot --headless --path godot_project --script res://tests/bridge_smoke.gd
```

Para el modo host/cliente por red (dos instancias de `OpenTableBridge`
hablando por TCP en el mismo proceso), ver `test_tcp_bridge.tscn` /
`test_tcp_bridge.gd`, corrible con `../run_test.sh`. A diferencia del
smoke test, esa escena es interactiva y **no se cierra sola** — hace
falta un `timeout` (por eso `run_test.sh` lo corre con
`timeout -k 5 30`, en foreground; no lo corras en background con
`sleep`+`pkill`, ver nota en el script).

## Cómo jugar

- Tocá/clic una ficha tuya (rojo = jugador 1, arriba; negro = jugador 2,
  abajo) y después la casilla destino. El turno lo dicta el motor.
- Movimiento simple: 1 diagonal hacia adelante. Captura: saltar 2 sobre una
  ficha rival. Coronación al llegar a la última fila (marca dorada).
- La barra inferior muestra de quién es el turno, los rechazos del motor y
  el ganador.

## Archivos y Configuración de GDExtension

- `opentable.gdextension` — apunta a la `.so` compilada del bridge usando ruta relativa (`res://../target/debug/libopen_table_godot.so`). Sostiene desarrollo local y entornos CI.
- `main.tscn` / `checkers_board.gd` — tablero, input y dibujo.
- `tests/bridge_smoke.gd` — test de humo headless.

Detalles del binding contra Redot: ver
`../open_table_godot/GODOT_SETUP.md`.
