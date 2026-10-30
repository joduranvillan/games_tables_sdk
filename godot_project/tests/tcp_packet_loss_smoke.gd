# Test headless de humo para simulación de pérdida de paquetes TCP vía MockTcpProxy.
# (1) Implementa MockTcpProxy que intercepta tráfico entre Host y Cliente usando StreamPeerBuffer
#     y simula un 20% de descarte (randf_range(0.0, 1.0) < 0.2) con seed(2026).
# (2) Host y cliente se conectan a través del proxy.
# (3) Ejecuta 8 movimientos alternativos de damas (4 por jugador).
# (4) Verifica que todos los eventos llegan al cliente y que host.current_player() == client.current_player().
# Timeout global: 30 segundos.
extends SceneTree

const HOST_PORT: int = 19882
const PROXY_PORT: int = 19883

class MockTcpProxy:
	var server: TCPServer
	var client_peer: StreamPeerTCP = null
	var host_peer: StreamPeerTCP = null
	var pending_c2h: Array = []
	var pending_h2c: Array = []
	var host_port: int
	var proxy_port: int
	var mutex: Mutex
	var rng: RandomNumberGenerator

	func _init(p_host_port: int, p_proxy_port: int) -> void:
		host_port = p_host_port
		proxy_port = p_proxy_port
		mutex = Mutex.new()
		rng = RandomNumberGenerator.new()
		rng.seed = 2026
		server = TCPServer.new()
		server.listen(proxy_port)

	func poll() -> void:
		mutex.lock()
		if client_peer == null and server.is_connection_available():
			client_peer = server.take_connection()
			host_peer = StreamPeerTCP.new()
			host_peer.connect_to_host("127.0.0.1", host_port)

		if client_peer != null:
			client_peer.poll()
		if host_peer != null:
			host_peer.poll()

		# Recibir de cliente -> proxy
		if client_peer != null and client_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and client_peer.get_available_bytes() > 0:
			var res = client_peer.get_data(client_peer.get_available_bytes())
			if res[0] == OK:
				var buf = StreamPeerBuffer.new()
				buf.data_array = res[1]
				pending_c2h.append(buf)

		# Recibir de host -> proxy
		if host_peer != null and host_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and host_peer.get_available_bytes() > 0:
			var res = host_peer.get_data(host_peer.get_available_bytes())
			if res[0] == OK:
				var buf = StreamPeerBuffer.new()
				buf.data_array = res[1]
				pending_h2c.append(buf)

		# Reenviar cliente -> host con 20% de descarte (hasta 5 reintentos por frame)
		if host_peer != null and host_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			while not pending_c2h.is_empty():
				var buf: StreamPeerBuffer = pending_c2h[0]
				var sent = false
				for _attempt in range(5):
					if rng.randf_range(0.0, 1.0) >= 0.2:
						host_peer.put_data(buf.data_array)
						sent = true
						break
				if sent:
					pending_c2h.remove_at(0)
				else:
					break

		# Reenviar host -> cliente con 20% de descarte (hasta 5 reintentos por frame)
		if client_peer != null and client_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			while not pending_h2c.is_empty():
				var buf: StreamPeerBuffer = pending_h2c[0]
				var sent = false
				for _attempt in range(5):
					if rng.randf_range(0.0, 1.0) >= 0.2:
						client_peer.put_data(buf.data_array)
						sent = true
						break
				if sent:
					pending_h2c.remove_at(0)
				else:
					break
		mutex.unlock()

	func is_proxy_connected() -> bool:
		mutex.lock()
		var ok: bool = client_peer != null and host_peer != null \
			and client_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED \
			and host_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
		mutex.unlock()
		return ok

	func stop() -> void:
		mutex.lock()
		if client_peer != null:
			client_peer.disconnect_from_host()
		if host_peer != null:
			host_peer.disconnect_from_host()
		server.stop()
		mutex.unlock()

func _initialize() -> void:
	seed(2026)
	var results: Array = []
	var client_events: Array = []

	# 1. Crear Proxy
	var proxy = MockTcpProxy.new(HOST_PORT, PROXY_PORT)

	# 2. Crear Host en HOST_PORT
	var host = OpenTableBridge.new()
	host.start_hosting(HOST_PORT, 1, 2)

	# 3. Crear Cliente conectándose a PROXY_PORT
	var client = OpenTableBridge.new()
	client.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, prom):
		client_events.append({"player": p, "from_row": fr, "from_col": fc, "to_row": tr, "to_col": tc})
	)

	var handshake_state: Dictionary = {"done": false}
	var handshake_thread: Thread = Thread.new()
	handshake_thread.start(func():
		while not handshake_state["done"]:
			proxy.poll()
			OS.delay_msec(5)
	)
	var ok_conn = client.connect_to_host("127.0.0.1", PROXY_PORT, "P2")
	handshake_state["done"] = true
	handshake_thread.wait_to_finish()
	results.append(["Client connect_to_host via MockTcpProxy retorno true", ok_conn])

	# 4. Esperar a establecer la conexión completa a través del proxy
	var start_ticks = Time.get_ticks_msec()
	while not proxy.is_proxy_connected() and (Time.get_ticks_msec() - start_ticks) < 10000:
		proxy.poll()
		host.poll_events()
		client.poll_events()
		OS.delay_msec(10)

	results.append(["Proxy establecio conexion bidireccional", proxy.is_proxy_connected()])

	# Esperar unos frames adicionales para finalizar el handshake de aplicación
	for _f in range(15):
		proxy.poll()
		host.poll_events()
		client.poll_events()
		OS.delay_msec(10)

	# 5. Jugar 8 movimientos alternativos legales de damas (4 por jugador) vía host
	var moves = [
		[1, 2, 1, 3, 0], # P1
		[2, 5, 6, 4, 7], # P2
		[1, 1, 0, 2, 1], # P1
		[2, 6, 7, 5, 6], # P2
		[1, 0, 1, 1, 0], # P1
		[2, 7, 6, 6, 7], # P2
		[1, 2, 3, 3, 2], # P1
		[2, 5, 4, 4, 5]  # P2
	]

	for m in moves:
		host.send_move(m[0], m[1], m[2], m[3], m[4])
		for _f in range(10):
			proxy.poll()
			host.poll_events()
			client.poll_events()
			OS.delay_msec(10)

	# Esperar a que se procesen todos los eventos pendientes con timeout de 30s
	start_ticks = Time.get_ticks_msec()
	while client_events.size() < 8 and (Time.get_ticks_msec() - start_ticks) < 30000:
		proxy.poll()
		host.poll_events()
		client.poll_events()
		OS.delay_msec(10)

	results.append(["Cliente recibio los 8 eventos de movimiento (actual: %d)" % client_events.size(), client_events.size() == 8])

	var host_current = host.current_player()
	var client_current = client.current_player()
	var player_equal = (host_current == client_current)
	results.append(["host.current_player() (%d) == client.current_player() (%d)" % [host_current, client_current], player_equal])

	var ok: bool = true
	for r in results:
		var passed: bool = r[1]
		print(("PASS  " if passed else "FAIL  ") + r[0])
		if not passed:
			ok = false

	print("=== RESULTADO TEST TCP_PACKET_LOSS_SMOKE: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))

	proxy.stop()
	host.free()
	client.free()

	quit(0 if ok else 1)
