# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## Test TCP bridge host/cliente en una sola instancia Godot
## Crea dos nodos: uno host escuchando en 127.0.0.1:9090,
## otro cliente conectándose al mismo.
##
## Uso: crear un nodo vacío, atachale este script, ejecutá.
## En la consola verás los eventos de ambos lados.
extends Node

const TEST_HOST = "127.0.0.1"
const TEST_PORT = 9090
const P_TOP = 1
const P_BOTTOM = 2

var host_bridge: OpenTableBridge
var client_bridge: OpenTableBridge
var test_state = "setup"  # setup -> host_waiting -> client_connected -> testing

func _ready() -> void:
	host_bridge = OpenTableBridge.new()
	host_bridge.name = "HostBridge"
	add_child(host_bridge)

	client_bridge = OpenTableBridge.new()
	client_bridge.name = "ClientBridge"
	add_child(client_bridge)

	# Conectar signals del host
	host_bridge.peer_joined.connect(_on_host_peer_joined)
	host_bridge.peer_disconnected.connect(_on_host_peer_disconnected)
	host_bridge.piece_moved.connect(_on_host_piece_moved)
	host_bridge.game_over.connect(_on_host_game_over)
	host_bridge.move_rejected.connect(_on_host_move_rejected)

	# Conectar signals del cliente
	client_bridge.connected.connect(_on_client_connected)
	client_bridge.piece_moved.connect(_on_client_piece_moved)
	client_bridge.game_over.connect(_on_client_game_over)
	client_bridge.move_rejected.connect(_on_client_move_rejected)

	# Iniciar el host
	print("\n🟢 [SETUP] Iniciando host en %s:%d..." % [TEST_HOST, TEST_PORT])
	host_bridge.start_hosting(TEST_PORT, P_TOP, P_BOTTOM)
	test_state = "host_waiting"

	# El cliente se conectará en _process después de un frame
	await get_tree().process_frame

func _process(_delta: float) -> void:
	# Crucial: procesar eventos de ambos bridges cada frame
	host_bridge.poll_events()
	client_bridge.poll_events()

	# Conectar el cliente después de que el host esté listo
	if test_state == "host_waiting":
		test_state = "connecting"
		print("\n🟢 [SETUP] Conectando cliente a %s:%d..." % [TEST_HOST, TEST_PORT])
		var ok = client_bridge.connect_to_host(TEST_HOST, TEST_PORT, "TestClient")
		if not ok:
			print("❌ [ERROR] No pude conectar el cliente")
			test_state = "failed"

# ============================================================================
# Host signals
# ============================================================================

func _on_host_peer_joined(player_id: int) -> void:
	print("\n✅ [HOST] Peer joined: PlayerId=%d" % player_id)
	if test_state == "connecting":
		test_state = "client_connected"
		_send_test_moves()

func _on_host_peer_disconnected(player_id: int) -> void:
	print("\n❌ [HOST] Peer disconnected: PlayerId=%d" % player_id)

func _on_host_piece_moved(player: int, from_row: int, from_col: int, to_row: int, to_col: int,
                          captured_row: int, captured_col: int, promoted: bool) -> void:
	var msg = "Pieza movida: (%d,%d) → (%d,%d)" % [from_row, from_col, to_row, to_col]
	if captured_row >= 0:
		msg += " (captura en %d,%d)" % [captured_row, captured_col]
	if promoted:
		msg += " [PROMOCIÓN]"
	print("✅ [HOST] %s (jugador %d)" % [msg, player])

func _on_host_game_over(winner: int) -> void:
	print("\n🏆 [HOST] Fin de la partida. Ganador: PlayerId=%d" % winner)

func _on_host_move_rejected(reason: String) -> void:
	status_log("❌ [HOST] Movimiento rechazado: %s" % reason)

func status_log(msg: String) -> void:
	print(msg)

# ============================================================================
# Client signals
# ============================================================================

func _on_client_connected(player_id: int) -> void:
	print("\n✅ [CLIENT] Conectado al servidor como PlayerId=%d" % player_id)

func _on_client_piece_moved(player: int, from_row: int, from_col: int, to_row: int, to_col: int,
                            captured_row: int, captured_col: int, promoted: bool) -> void:
	var msg = "Pieza movida: (%d,%d) → (%d,%d)" % [from_row, from_col, to_row, to_col]
	if captured_row >= 0:
		msg += " (captura en %d,%d)" % [captured_row, captured_col]
	if promoted:
		msg += " [PROMOCIÓN]"
	print("✅ [CLIENT] %s (jugador %d)" % [msg, player])

func _on_client_game_over(winner: int) -> void:
	print("\n🏆 [CLIENT] Fin de la partida. Ganador: PlayerId=%d" % winner)

func _on_client_move_rejected(reason: String) -> void:
	print("❌ [CLIENT] Movimiento rechazado: %s" % reason)

# ============================================================================
# Test moves: enviar movimientos de prueba
# ============================================================================

func _send_test_moves() -> void:
	print("\n🟡 [TEST] Enviando movimientos de prueba...")
	print("\n🟡 [TEST] Enviando movimiento 1: (2,1) → (3,2) del host")
	host_bridge.send_move(P_TOP, 2, 1, 3, 2)
	await get_tree().process_frame
	await get_tree().process_frame

	print("\n🟡 [TEST] Enviando movimiento 2: (5,2) → (4,3) del host")
	host_bridge.send_move(P_BOTTOM, 5, 2, 4, 3)
	await get_tree().process_frame
	await get_tree().process_frame

	print("\n🟡 [TEST] Intentando movimiento inválido (no es su turno)...")
	host_bridge.send_move(P_TOP, 3, 2, 4, 3)
	await get_tree().process_frame
	await get_tree().process_frame

	print("\n🟢 [TEST] Pruebas completadas. El puente TCP está funcionando.")
