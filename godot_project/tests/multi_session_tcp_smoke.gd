# Test headless de humo para múltiples sesiones TCP simultáneas en OpenTableBridge.
# Inicia dos servidores y clientes TCP en puertos distintos (19878 y 19879) y
# verifica que los eventos de la sesión A no llegan a la B y viceversa.
#
# Correr: redot --headless --path godot_project --script res://tests/multi_session_tcp_smoke.gd
extends SceneTree

const PORT_A: int = 19878
const PORT_B: int = 19879

func _initialize() -> void:
	var results: Array = []
	var events_a_host: Array = []
	var events_a_client: Array = []
	var events_b_host: Array = []
	var events_b_client: Array = []

	# 1. Configurar Host A y Cliente A en PORT_A (19878)
	var host_a = OpenTableBridge.new()
	host_a.start_hosting(PORT_A, 1, 2)

	var client_a = OpenTableBridge.new()
	var ok_conn_a = client_a.connect_to_host("127.0.0.1", PORT_A, "ClientA")
	results.append(["Client A connect_to_host en puerto %d retorno true" % PORT_A, ok_conn_a])

	# 2. Configurar Host B y Cliente B en PORT_B (19879)
	var host_b = OpenTableBridge.new()
	host_b.start_hosting(PORT_B, 1, 2)

	var client_b = OpenTableBridge.new()
	var ok_conn_b = client_b.connect_to_host("127.0.0.1", PORT_B, "ClientB")
	results.append(["Client B connect_to_host en puerto %d retorno true" % PORT_B, ok_conn_b])

	# Conectar listeners de señales
	host_a.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, prom):
		events_a_host.append({"player": p, "from_row": fr, "from_col": fc, "to_row": tr, "to_col": tc})
	)
	client_a.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, prom):
		events_a_client.append({"player": p, "from_row": fr, "from_col": fc, "to_row": tr, "to_col": tc})
	)

	host_b.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, prom):
		events_b_host.append({"player": p, "from_row": fr, "from_col": fc, "to_row": tr, "to_col": tc})
	)
	client_b.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, prom):
		events_b_client.append({"player": p, "from_row": fr, "from_col": fc, "to_row": tr, "to_col": tc})
	)

	# Procesar eventos para establecer conexiones TCP completas
	for _i in range(15):
		host_a.poll_events()
		client_a.poll_events()
		host_b.poll_events()
		client_b.poll_events()
		OS.delay_msec(10)

	# 3. Realizar movimiento en Sesion A (Host A)
	# Checkers initial move: (2, 1) -> (3, 2)
	host_a.send_move(1, 2, 1, 3, 2)

	for _i in range(15):
		host_a.poll_events()
		client_a.poll_events()
		host_b.poll_events()
		client_b.poll_events()
		OS.delay_msec(10)

	results.append(["Host A recibio su propio movimiento", events_a_host.size() == 1])
	results.append(["Client A recibio el movimiento de Sesion A", events_a_client.size() == 1])
	results.append(["Host B NO recibio eventos de Sesion A", events_b_host.size() == 0])
	results.append(["Client B NO recibio eventos de Sesion A", events_b_client.size() == 0])

	if events_a_client.size() == 1:
		results.append(["Client A recibio movimiento correcto (3,2)", events_a_client[0].to_row == 3 and events_a_client[0].to_col == 2])

	# 4. Realizar movimiento en Sesion B (Host B)
	# Checkers initial move in session B: (2, 3) -> (3, 4)
	host_b.send_move(1, 2, 3, 3, 4)

	for _i in range(15):
		host_a.poll_events()
		client_a.poll_events()
		host_b.poll_events()
		client_b.poll_events()
		OS.delay_msec(10)

	results.append(["Host B recibio su propio movimiento", events_b_host.size() == 1])
	results.append(["Client B recibio el movimiento de Sesion B", events_b_client.size() == 1])
	results.append(["Host A no recibio eventos de Sesion B (mantiene 1)", events_a_host.size() == 1])
	results.append(["Client A no recibio eventos de Sesion B (mantiene 1)", events_a_client.size() == 1])

	if events_b_client.size() == 1:
		results.append(["Client B recibio movimiento correcto (3,4)", events_b_client[0].to_row == 3 and events_b_client[0].to_col == 4])

	# 5. Realizar segundo movimiento en Sesion A (Host A) para Jugador 2: (5,0) -> (4,1)
	host_a.send_move(2, 5, 0, 4, 1)

	for _i in range(15):
		host_a.poll_events()
		client_a.poll_events()
		host_b.poll_events()
		client_b.poll_events()
		OS.delay_msec(10)

	results.append(["Sesion A avanzo a 2 movimientos en Host A", events_a_host.size() == 2])
	results.append(["Sesion A avanzo a 2 movimientos en Client A", events_a_client.size() == 2])
	results.append(["Sesion B se mantuvo en 1 movimiento en Host B", events_b_host.size() == 1])
	results.append(["Sesion B se mantuvo en 1 movimiento en Client B", events_b_client.size() == 1])

	var ok := true
	for r in results:
		var passed: bool = r[1]
		print(("PASS  " if passed else "FAIL  ") + r[0])
		if not passed:
			ok = false

	print("=== RESULTADO TEST MULTI_SESSION_TCP: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))

	host_a.free()
	client_a.free()
	host_b.free()
	client_b.free()

	quit(0 if ok else 1)
