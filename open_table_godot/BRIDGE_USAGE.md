# Bridge `OpenTableBridge` — Uso en GDScript

`open_table_godot` expone un único nodo Godot, `OpenTableBridge`, con varios modos internos (Local, Host TCP, Client TCP, NativeHost, NativeClient). El modo se fija llamando a uno de los métodos de inicio (`start_local_match_*()`, `start_hosting()`, `connect_to_host()`, `start_native_hosting()`, `start_native_client()`, `reconnect_native()`); a partir de ahí el resto de los métodos dispatch-ean según ese modo.

## Local — hotseat sin red

Un único proceso, dos jugadores en el mismo dispositivo.

```gdscript
extends Node

@onready var bridge = OpenTableBridge.new()

func _ready():
    bridge.start_local_match(1, 2)  # player_top_id, player_bottom_id
    bridge.piece_moved.connect(_on_piece_moved)
    bridge.game_over.connect(_on_game_over)
    bridge.move_rejected.connect(_on_move_rejected)

func send_move(player: int, from_row: int, from_col: int, to_row: int, to_col: int):
    bridge.send_move(player, from_row, from_col, to_row, to_col)

func current_player() -> int:
    return bridge.current_player()

func _on_piece_moved(player, from_row, from_col, to_row, to_col, captured_row, captured_col, promoted):
    print("Pieza movida: (%d,%d) → (%d,%d)" % [from_row, from_col, to_row, to_col])

func _on_game_over(winner: int):
    print("🏆 Fin de la partida. Ganador: Jugador %d" % winner)

func _on_move_rejected(reason: String):
    print("❌ Movimiento rechazado: %s" % reason)
```

No hace falta llamar `poll_events()` en modo Local — no hay transporte de red que drenar, `send_move()` procesa y emite señales al toque.

## Host — servidor TCP que valida reglas y acepta clientes

Crea una `Session` real + `TcpHostTransport` en un puerto. Usa el mismo `send_move(player, ...)` que el modo Local, pero además hace broadcast por red.

```gdscript
extends Node

@onready var bridge = OpenTableBridge.new()

func _ready():
    bridge.start_hosting(9090, 1, 2)  # port, player_top_id, player_bottom_id
    bridge.peer_joined.connect(_on_peer_joined)
    bridge.peer_disconnected.connect(_on_peer_disconnected)
    bridge.piece_moved.connect(_on_piece_moved)
    bridge.game_over.connect(_on_game_over)
    bridge.move_rejected.connect(_on_move_rejected)

func _process(_delta):
    # Crucial: procesar eventos del transporte cada frame
    bridge.poll_events()

func send_move(player: int, from_row: int, from_col: int, to_row: int, to_col: int):
    bridge.send_move(player, from_row, from_col, to_row, to_col)

func _on_peer_joined(player_id: int):
    print("✅ Jugador %d se conectó" % player_id)

func _on_peer_disconnected(player_id: int):
    print("❌ Jugador %d se desconectó" % player_id)

func _on_piece_moved(player, from_row, from_col, to_row, to_col, captured_row, captured_col, promoted):
    print("Pieza movida: (%d,%d) → (%d,%d)" % [from_row, from_col, to_row, to_col])

func _on_game_over(winner: int):
    print("🏆 Fin de la partida. Ganador: Jugador %d" % winner)

func _on_move_rejected(reason: String):
    print("❌ Movimiento rechazado: %s" % reason)
```

## Client — se conecta a un host TCP

Se conecta con `TcpClientTransport`. No tiene `Session` local: manda comandos y consume eventos de la red. El `player_id` que asigna el servidor se guarda internamente (`my_player_id()`) — `send_move_client()` lo usa automáticamente. También soporta reconexión transparente con token vía `reconnect_to_host()`.

```gdscript
extends Node

@onready var bridge = OpenTableBridge.new()

func _ready():
    bridge.connected.connect(_on_connected)
    bridge.piece_moved.connect(_on_piece_moved)
    bridge.game_over.connect(_on_game_over)
    bridge.move_rejected.connect(_on_move_rejected)

func connect_to_game(host: String, port: int, player_name: String) -> bool:
    return bridge.connect_to_host(host, port, player_name)

func reconnect_game(host: String, port: int, player_id: int, token: String) -> bool:
    return bridge.reconnect_to_host(host, port, player_id, token)

func _process(_delta):
    bridge.poll_events()

func send_move(from_row: int, from_col: int, to_row: int, to_col: int):
    bridge.send_move_client(from_row, from_col, to_row, to_col)

func _on_connected(player_id: int):
    print("✅ Conectado al servidor como jugador %d" % player_id)
```

## P2P Nativo Mobile (Android Nearby Connections / iOS Multipeer)

Para plataformas móviles sin IP ni puerto, se utiliza `NativeP2PAdapter` (`res://native_p2p_adapter.gd`), que conecta `GodotNearbyLink` / `RawByteLink` de Rust con los plugins nativos de plataforma (`OpenTableNearby` en Android y `OpenTableMultipeer` en iOS):

```gdscript
extends Node

@onready var bridge = OpenTableBridge.new()
@onready var p2p_adapter = NativeP2PAdapter.new()

func _ready():
    add_child(bridge)
    add_child(p2p_adapter)
    p2p_adapter.setup(bridge)

    bridge.connected.connect(_on_connected)
    bridge.native_handshake_established.connect(_on_handshake)

# Crear mesa P2P como Host
func create_p2p_room(join_code: String):
    p2p_adapter.start_hosting(join_code, 1, 2, "Mesa de Mi Nombre")

# Unirse a mesa P2P como Cliente (auto-conexión transparente)
func join_p2p_room(join_code: String):
    p2p_adapter.start_client(join_code, "Jugador 2")

# Reconectarse a mesa P2P
func reconnect_p2p_room(join_code: String, player_id: int, token: String):
    p2p_adapter.reconnect_client(join_code, player_id, token, "Jugador 2")

func _process(_delta):
    bridge.poll_events()

func _on_handshake(player_id: int, reconnect_token: String):
    print("✅ Handshake P2P completado: PlayerId=%d, Token=%s" % [player_id, reconnect_token])
```

## Referencia rápida de la API

| Método | Modo | Qué hace |
|---|---|---|
| `start_local_match(top_id, bottom_id)` | Local | Arranca `Session` de Damas sin red |
| `start_local_match_chess(...)`, etc. | Local | Arranca `Session` para otros 11 juegos |
| `start_hosting(port, top_id, bottom_id)` | Host TCP | Arranca `Session` + servidor TCP |
| `connect_to_host(host, port, name) -> bool` | Client TCP | Conecta a host TCP, asigna `player_id` y emite token |
| `reconnect_to_host(host, port, pid, token) -> bool` | Client TCP | Reconecta con token de sesión anterior |
| `start_native_hosting(top_id, bottom_id)` | NativeHost | Arranca Host P2P con `GodotNearbyLink` |
| `start_native_client(player_name)` | NativeClient | Arranca Cliente P2P e inicia handshake `Join` |
| `reconnect_native(player_id, token)` | NativeClient | Arranca Cliente P2P e inicia handshake `Reconnect` |
| `send_move(player, from_row, from_col, to_row, to_col)` | Local, Host, NativeHost | Procesa movimiento localmente y hace broadcast |
| `send_command_json(player, json_str)` | Local, Host, NativeHost | Envía un comando en formato JSON genérico |
| `send_move_client(from_row, from_col, to_row, to_col)` | Client, NativeClient | Envía el movimiento al Host usando el `player_id` propio |
| `my_player_id() -> int` | Client, NativeClient | `player_id` asignado por el Host (-1 si no aplica) |
| `current_player() -> int` | Local, Host, NativeHost | De quién es el turno (-1 en Client/sin partida) |
| `poll_events()` | Host, Client, NativeHost, NativeClient | Drena red/colas nativas y emite señales; llamar cada `_process()` |
