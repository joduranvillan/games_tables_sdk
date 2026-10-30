# Test headless de humo para reconexión TCP en OpenTableBridge.
# (1) Arranca una sesión de damas como host TCP en puerto 19877
# (2) Conecta un cliente con client.connect_to_host("127.0.0.1", 19877, "P2")
# (3) Espera 10 frames de proceso para completar el handshake
# (4) Envía un MovePieceCommand desde el host y verifica que el cliente emite piece_moved
# (5) Cierra el cliente con client.disconnect_from_host()
# (6) Crea un nuevo OpenTableBridge y llama reconnect_to_host("127.0.0.1", 19877, "P2")
# (7) Espera 10 frames
# (8) Verifica que client2.is_connected_to_host() es true y que client2.current_player() es consistente con el estado del host.
# Timeout global: 10 segundos.
extends SceneTree

const PORT: int = 19877

func _initialize() -> void:
	var results: Array = []
	var events_client: Array = []
	var hs: Dictionary = {"player_id": 2, "token": ""}

	# 1. Arrancar host TCP en puerto 19877
	var host = OpenTableBridge.new()
	host.start_hosting(PORT, 1, 2)

	# 2. Conectar cliente
	var client = OpenTableBridge.new()
	client.connect("native_handshake_established", func(p_id: int, tok: String):
		hs["player_id"] = p_id
		hs["token"] = tok
	)
	client.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, prom):
		events_client.append({"player": p, "from_row": fr, "from_col": fc, "to_row": tr, "to_col": tc})
	)

	var ok_conn = client.connect_to_host("127.0.0.1", PORT, "P2")
	results.append(["Client connect_to_host retorno true", ok_conn])

	# 3. Esperar 10 frames de proceso para completar handshake
	for _i in range(10):
		host.poll_events()
		client.poll_events()
		OS.delay_msec(10)

	results.append(["Handshake establecido y token recibido", String(hs["token"]) != ""])

	# 4. Enviar MovePieceCommand desde el host y verificar piece_moved en cliente
	# Checkers move: (2, 1) -> (3, 2)
	host.send_move(1, 2, 1, 3, 2)

	for _i in range(10):
		host.poll_events()
		client.poll_events()
		OS.delay_msec(10)

	results.append(["Cliente emitio piece_moved tras movimiento del host", events_client.size() == 1])
	if events_client.size() == 1:
		results.append(["Coordenadas de piece_moved correctas (3,2)", events_client[0].to_row == 3 and events_client[0].to_col == 2])

	# 5. Cerrar cliente con disconnect_from_host()
	client.disconnect_from_host()

	for _i in range(5):
		host.poll_events()
		client.poll_events()
		OS.delay_msec(10)

	results.append(["Cliente desconectado de host", not client.is_connected_to_host()])

	# 6. Crear un nuevo OpenTableBridge y llamar reconnect_to_host
	var client2 = OpenTableBridge.new()
	var ok_reconn: bool = false
	if String(hs["token"]) != "":
		ok_reconn = client2.reconnect_to_host("127.0.0.1", PORT, int(hs["player_id"]), String(hs["token"]))
	else:
		ok_reconn = client2.reconnect_to_host("127.0.0.1", PORT, 2, "")

	results.append(["Client2 reconnect_to_host retorno true", ok_reconn])

	# 7. Esperar 10 frames
	for _i in range(10):
		host.poll_events()
		client2.poll_events()
		OS.delay_msec(10)

	# 8. Verificar client2.is_connected_to_host() y client2.current_player()
	var connected_ok = client2.is_connected_to_host()
	results.append(["client2.is_connected_to_host() es true", connected_ok])

	var host_current = host.current_player()
	var client2_current = client2.current_player()
	var player_consistent = (client2_current == host_current)
	results.append(["client2.current_player() (%d) es consistente con host (%d)" % [client2_current, host_current], player_consistent])

	var ok: bool = true
	for r in results:
		var passed: bool = r[1]
		print(("PASS  " if passed else "FAIL  ") + r[0])
		if not passed:
			ok = false

	print("=== RESULTADO TEST TCP_RECONNECTION_SMOKE: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))

	host.free()
	client.free()
	client2.free()

	quit(0 if ok else 1)
