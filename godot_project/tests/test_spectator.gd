# Test de humo para SpectatorMode en OpenTableBridge.
# Inicia una partida host de damas (checkers) y un puente espectador que se conecta por TCP.
# Realiza un movimiento y verifica que el espectador reciba la señal piece_moved y spectator_event_received.
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var moved_events: Array = []
	var spectator_jsons: Array = []

	var host_bridge = OpenTableBridge.new()
	var port: int = 18099
	host_bridge.start_hosting(port, 1, 2)

	var spectator_bridge = OpenTableBridge.new()
	spectator_bridge.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, promoted):
		moved_events.append({"player": p, "to_row": tr, "to_col": tc}))
	spectator_bridge.connect("spectator_event_received", func(event_json):
		spectator_jsons.append(event_json))

	var host_addr: String = "127.0.0.1:%d" % port
	var spectating_ok: bool = spectator_bridge.start_spectating(host_addr)
	results.append(["start_spectating se conecta exitosamente al host", spectating_ok])

	# Procesar eventos en el host y espectador para completar la conexión TCP
	for _i in range(15):
		host_bridge.poll_events()
		spectator_bridge.poll_events()
		OS.delay_msec(10)

	# Realizar un movimiento en la partida del host: (2, 1) -> (3, 2)
	host_bridge.send_move(1, 2, 1, 3, 2)

	# El espectador procesa eventos para recibir el evento transmitido por el host
	for _i in range(15):
		host_bridge.poll_events()
		spectator_bridge.poll_events()
		OS.delay_msec(10)

	results.append(["el espectador recibió el evento piece_moved", moved_events.size() == 1])
	if moved_events.size() == 1:
		results.append(["movimiento a (3,2)", moved_events[0].to_row == 3 and moved_events[0].to_col == 2])

	results.append(["el espectador recibió la señal spectator_event_received", spectator_jsons.size() >= 1])

	# --- TEST DE ESPECTADOR TARDÍO (RESYNC HISTÓRICO DE COMANDOS / EVENTOS) ---
	var late_moved_events: Array = []
	var late_spectator_jsons: Array = []
	var host_late = OpenTableBridge.new()
	var port_late: int = 18100
	host_late.start_hosting(port_late, 1, 2)

	# Jugar 2 movimientos antes de que el espectador se conecte
	# Movimiento 1 (Jugador 1): (2, 1) -> (3, 2)
	host_late.send_move(1, 2, 1, 3, 2)
	for _i in range(5):
		host_late.poll_events()
		OS.delay_msec(10)

	# Movimiento 2 (Jugador 2): (5, 0) -> (4, 1)
	host_late.send_move(2, 5, 0, 4, 1)
	for _i in range(5):
		host_late.poll_events()
		OS.delay_msec(10)

	# Ahora se une el espectador tardío
	var late_spectator_bridge = OpenTableBridge.new()
	late_spectator_bridge.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, promoted):
		late_moved_events.append({"player": p, "from_row": fr, "from_col": fc, "to_row": tr, "to_col": tc}))
	late_spectator_bridge.connect("spectator_event_received", func(event_json):
		late_spectator_jsons.append(event_json))

	var late_addr: String = "127.0.0.1:%d" % port_late
	var late_ok: bool = late_spectator_bridge.start_spectating(late_addr)
	results.append(["espectador tardío se conecta al host", late_ok])

	# Procesar eventos para que se complete la conexión y el resync histórico
	for _i in range(25):
		host_late.poll_events()
		late_spectator_bridge.poll_events()
		OS.delay_msec(10)

	results.append(["espectador tardío recibió los 2 movimientos históricos por resync", late_moved_events.size() == 2])
	if late_moved_events.size() >= 2:
		var m1_ok: bool = late_moved_events[0].player == 1 and late_moved_events[0].to_row == 3 and late_moved_events[0].to_col == 2
		var m2_ok: bool = late_moved_events[1].player == 2 and late_moved_events[1].to_row == 4 and late_moved_events[1].to_col == 1
		results.append(["movimiento histórico 1 recibido en orden correcto (3,2)", m1_ok])
		results.append(["movimiento histórico 2 recibido en orden correcto (4,1)", m2_ok])
	else:
		results.append(["movimiento histórico 1 recibido en orden correcto (3,2)", false])
		results.append(["movimiento histórico 2 recibido en orden correcto (4,1)", false])

	results.append(["espectador tardío recibió señales spectator_event_received históricas", late_spectator_jsons.size() >= 2])

	# Realizar un 3er movimiento en vivo: captura obligatoria (3, 2) -> (5, 0)
	host_late.send_move(1, 3, 2, 5, 0)
	for _i in range(15):
		host_late.poll_events()
		late_spectator_bridge.poll_events()
		OS.delay_msec(10)

	results.append(["espectador tardío recibió el tercer movimiento en vivo tras el resync", late_moved_events.size() == 3])
	if late_moved_events.size() == 3:
		var m3_ok: bool = late_moved_events[2].player == 1 and late_moved_events[2].to_row == 5 and late_moved_events[2].to_col == 0
		results.append(["tercer movimiento en vivo correcto (5,0)", m3_ok])
	else:
		results.append(["tercer movimiento en vivo correcto (5,0)", false])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO TEST ESPECTADOR: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	host_bridge.free()
	spectator_bridge.free()
	host_late.free()
	late_spectator_bridge.free()
	quit(0 if ok else 1)
