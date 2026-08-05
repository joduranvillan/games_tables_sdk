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

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO TEST ESPECTADOR: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	host_bridge.free()
	spectator_bridge.free()
	quit(0 if ok else 1)
