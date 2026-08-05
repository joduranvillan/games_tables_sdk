# Test headless de humo del puente Rust<->Redot. Verifica en RUNTIME (no
# solo que la extensión cargue) que OpenTableBridge arranca una partida,
# valida movimientos contra el motor real y emite las señales correctas.
#
# Correr:  redot --headless --path godot_project --script res://tests/bridge_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var moved: Array = []
	var rejected: Array = []
	var turns_changed: Array = []

	var bridge = OpenTableBridge.new()
	bridge.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, promoted):
		moved.append({"player": p, "to_row": tr, "to_col": tc, "captured_row": cr}))
	bridge.connect("move_rejected", func(reason): rejected.append(reason))
	bridge.connect("turn_changed", func(p): turns_changed.append(p))

	bridge.start_local_match(1, 2)
	results.append(["arranca con turno del jugador 1 (top)", bridge.current_player() == 1])

	# Movimiento válido del top (increasing, avanza +fila): (2,1) -> (3,2).
	bridge.send_move(1, 2, 1, 3, 2)
	results.append(["movimiento válido -> piece_moved", moved.size() == 1])
	if moved.size() == 1:
		results.append(["llegó a (3,2)", moved[0].to_row == 3 and moved[0].to_col == 2])
		results.append(["sin captura (captured_row==-1)", moved[0].captured_row == -1])
	results.append(["el turno pasó al jugador 2", bridge.current_player() == 2])
	results.append(["se emitió la señal turn_changed con nuevo jugador 2", turns_changed.size() == 1 and turns_changed[0] == 2])

	# Movimiento inválido: el jugador 2 intenta mover desde una casilla vacía.
	bridge.send_move(2, 4, 1, 5, 2)
	results.append(["movimiento inválido -> move_rejected", rejected.size() >= 1])
	results.append(["el motor NO cambió de turno tras rechazo", bridge.current_player() == 2])

	# Test de Replay Viewer
	var log_bytes: PackedByteArray = bridge.export_log()
	results.append(["export_log exportó bytes de replay", log_bytes.size() > 0])

	var replay_bridge = OpenTableBridge.new()
	var replay_moved: Array = []
	replay_bridge.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, promoted):
		replay_moved.append({"player": p, "to_row": tr, "to_col": tc}))

	var load_ok: bool = replay_bridge.load_replay(log_bytes, "checkers")
	results.append(["load_replay de 1 movimiento retornó true", load_ok])

	var step_ok: bool = replay_bridge.step_replay()
	results.append(["step_replay avanzó 1 paso -> true", step_ok])
	results.append(["cargando y avanzando el replay de 1 movimiento emite exactamente 1 piece_moved", replay_moved.size() == 1])
	if replay_moved.size() == 1:
		results.append(["replay movió pieza a (3,2)", replay_moved[0].to_row == 3 and replay_moved[0].to_col == 2])

	var step_end: bool = replay_bridge.step_replay()
	results.append(["step_replay retorna false al terminar", not step_end])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	replay_bridge.free()
	quit(0 if ok else 1)
