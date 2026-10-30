# Test headless de integración para el flujo de Relay en OpenTableBridge.
# Simula la conexión de dos clientes (Host y Guest) a través del flujo de Relay,
# valida la generación de código de sala alfanumérico de 4 caracteres y verifica
# la emisión de señales de creación, unión, retransmisión de jugadas y desconexión.
#
# Correr: redot --headless --path godot_project -s tests/relay_smoke.gd
extends SceneTree

const VALID_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const RELAY_URL = "ws://127.0.0.1:8080"

func _is_valid_room_code(code: String) -> bool:
	if code.length() != 4:
		return false
	for i in range(code.length()):
		var ch: String = code.substr(i, 1)
		if not VALID_ALPHABET.contains(ch):
			return false
	return true

func _initialize() -> void:
	var results: Array = []
	var created_codes: Array = []
	var host_peers_joined: Array = []
	var host_peers_disconnected: Array = []
	var guest_join_events: Array = []
	var guest_moves_received: Array = []

	var host_bridge = OpenTableBridge.new()
	var guest_bridge = OpenTableBridge.new()

	host_bridge.connect("room_created", func(code: String):
		created_codes.append(code)
	)
	host_bridge.connect("peer_joined", func(pid: int):
		host_peers_joined.append(pid)
	)
	host_bridge.connect("peer_disconnected", func(pid: int):
		host_peers_disconnected.append(pid)
	)

	guest_bridge.connect("room_joined", func(success: bool, pid: int):
		guest_join_events.append({"success": success, "player_id": pid})
	)
	guest_bridge.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, promoted):
		guest_moves_received.append({"player": p, "to_row": tr, "to_col": tc})
	)

	# 1. Host conecta al Relay y crea una sala
	host_bridge.connect_to_relay(RELAY_URL)
	var room_code: String = host_bridge.create_relay_room("checkers")

	results.append([
		"create_relay_room genera código alfanumérico válido de 4 caracteres (%s)" % room_code,
		_is_valid_room_code(room_code)
	])
	results.append([
		"señal room_created emitida con el código de sala",
		created_codes.size() == 1 and created_codes[0] == room_code
	])

	# 2. Guest conecta al Relay y se une usando el código de 4 caracteres
	guest_bridge.connect_to_relay(RELAY_URL)
	guest_bridge.join_relay_room(room_code)

	for _i in range(10):
		host_bridge.poll_events()
		guest_bridge.poll_events()
		OS.delay_msec(5)

	results.append([
		"guest emite señal room_joined(true, 2)",
		guest_join_events.size() == 1 and guest_join_events[0]["success"] == true and guest_join_events[0]["player_id"] == 2
	])
	results.append([
		"host emite señal peer_joined(2) cuando el par se une a la sala",
		host_peers_joined.has(2)
	])

	# 3. Retransmisión de jugada del Host al Guest a través del Relay
	host_bridge.send_move(1, 2, 1, 3, 2)
	for _i in range(10):
		host_bridge.poll_events()
		guest_bridge.poll_events()
		OS.delay_msec(5)

	results.append([
		"guest recibe piece_moved retransmitido por el Relay",
		guest_moves_received.size() == 1 and guest_moves_received[0]["to_row"] == 3 and guest_moves_received[0]["to_col"] == 2
	])

	# 4. Validación de JoinDialog (normalización en mayúsculas de 4 caracteres)
	var join_dlg = load("res://join_dialog.gd").new()
	var sanitized: String = join_dlg.sanitize_room_code("ab23")
	results.append([
		"JoinDialog normaliza código en mayúsculas de 4 caracteres",
		sanitized == "AB23"
	])
	join_dlg.free()

	# 5. Simulación de desconexión del par
	guest_bridge.leave_relay_room()
	for _i in range(10):
		host_bridge.poll_events()
		OS.delay_msec(5)

	results.append([
		"host emite señal peer_disconnected(2) cuando el par abandona la sala",
		host_peers_disconnected.has(2)
	])

	var ok: bool = true
	for r in results:
		var passed: bool = r[1]
		print(("PASS  " if passed else "FAIL  ") + r[0])
		if not passed:
			ok = false

	print("=== RESULTADO RELAY SMOKE: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))

	host_bridge.free()
	guest_bridge.free()
	quit(0 if ok else 1)
