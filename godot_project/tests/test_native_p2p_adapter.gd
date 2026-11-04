# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# Test del adaptador P2P nativo NativeP2PAdapter
# Verifica en runtime que la vinculación entre OpenTableBridge y NativeP2PAdapter funciona.
extends SceneTree

# Mock del plugin nativo para simular las llamadas del OS
class MockNativePlugin extends RefCounted:
	signal data_received(peer_tag: String, bytes: PackedByteArray)
	signal peer_disconnected(peer_tag: String)

	var sent_bytes: Array = []
	var broadcast_bytes: Array = []
	var hosting_started: bool = false
	var discovery_started: bool = false

	func startHosting(join_code: String, display_name: String) -> void:
		hosting_started = true

	func startDiscovery(join_code: String, display_name: String, auto_connect: bool) -> void:
		discovery_started = true

	func sendBytes(peer_tag: String, bytes: PackedByteArray) -> void:
		sent_bytes.append({"peer": peer_tag, "bytes": bytes})

	func broadcastBytes(bytes: PackedByteArray) -> void:
		broadcast_bytes.append(bytes)

	func stopAll() -> void:
		hosting_started = false
		discovery_started = false

func _initialize() -> void:
	var results: Array = []
	var mock_plugin = MockNativePlugin.new()
	var bridge = OpenTableBridge.new()
	var adapter = load("res://native_p2p_adapter.gd").new()
	adapter.plugin = mock_plugin
	adapter.setup(bridge)

	# 1. Probar Host Nivel Nativo
	adapter.start_hosting("TEST1234", 1, 2, "TestHost")
	results.append(["start_hosting inicia el plugin nativo", mock_plugin.hosting_started])

	# 2. Simular recepción de datos desde el plugin nativo hacia Rust
	var test_data = "hello_opentable".to_utf8_buffer()
	mock_plugin.data_received.emit("peer_100", test_data)

	bridge.poll_events()
	results.append(["feed_native_data_received alimentó a Rust sin crash", true])

	# 3. Simular desconexión de peer desde el plugin nativo hacia Rust
	mock_plugin.peer_disconnected.emit("peer_100")
	bridge.poll_events()
	results.append(["feed_native_peer_disconnected alimentó a Rust sin crash", true])

	# 4. Test de reconexión automática tras backoff (3 segundos)
	adapter.start_client("SALA123", "Cliente1")
	bridge.native_handshake_established.emit(2, "token_abc")

	results.append(["is_native_connected es false antes de completar handshake", not bridge.is_native_connected()])
	results.append(["player_id y token guardados correctamente", adapter.saved_player_id == 2 and adapter.saved_token == "token_abc"])

	# Simular desconexión o espera pasando tiempo menor a RECONNECT_BACKOFF (1.0s)
	mock_plugin.discovery_started = false
	adapter._process(1.0)
	results.append(["reconexión NO se dispara antes de los 3s (timer=1.0)", not mock_plugin.discovery_started])

	# Pasar otro segundo (total 2.0s)
	adapter._process(1.0)
	results.append(["reconexión NO se dispara antes de los 3s (timer=2.0)", not mock_plugin.discovery_started])

	# Pasar 1.5s más (total 3.5s >= 3.0s backoff)
	adapter._process(1.5)
	results.append(["reconexión SE dispara automáticamente tras el backoff de 3s", mock_plugin.discovery_started])

	adapter.stop()
	adapter.free()
	bridge.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO TEST ADAPTER: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	quit(0 if ok else 1)
