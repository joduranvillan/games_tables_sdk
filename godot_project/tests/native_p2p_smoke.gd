# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# Test de Humo P2P Nativo en Headless (Prompt 456)
# Verifica que start_p2p_host y start_p2p_client existen en OpenTableBridge,
# retornan sin crash en desktop/headless y que native_send_bytes está registrada.
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var bridge = OpenTableBridge.new()
	assert(bridge != null, "OpenTableBridge debe instanciarse correctamente")

	# 1. Verificar existencia de métodos P2P en el bridge
	var has_host_method: bool = bridge.has_method("start_p2p_host")
	var has_client_method: bool = bridge.has_method("start_p2p_client")
	results.append(["start_p2p_host existe en OpenTableBridge", has_host_method])
	results.append(["start_p2p_client existe en OpenTableBridge", has_client_method])

	# 2. Verificar señal native_send_bytes registrada en el bridge
	var has_send_signal: bool = bridge.has_signal("native_send_bytes")
	results.append(["señal native_send_bytes registrada en OpenTableBridge", has_send_signal])

	# 3. Llamar start_p2p_host("chess") y start_p2p_client("chess") sin crash en desktop/headless
	var emitted_packets: Array = []
	if has_send_signal:
		bridge.connect("native_send_bytes", func(bytes: PackedByteArray) -> void:
			emitted_packets.append(bytes)
		)

	var host_res = bridge.start_p2p_host("chess")
	results.append(["start_p2p_host('chess') retorna sin crash", host_res == true or host_res == false or host_res == null])

	var client_res = bridge.start_p2p_client("chess")
	results.append(["start_p2p_client('chess') retorna sin crash", client_res == true or client_res == false or client_res == null])

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + str(r[0]))
		if not r[1]:
			ok = false

	bridge.free()
	if ok:
		print("PASS: P2P API surface OK")
		quit(0)
	else:
		print("FAIL: P2P API surface check failed")
		quit(1)
