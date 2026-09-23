# Test headless de humo para múltiples sesiones en OpenTableBridge.
# Verifica que dos partidas simultáneas no mezclan eventos entre sí.
#
# Correr: redot --headless --path godot_project --script res://tests/multi_session_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var game1_moves: Array = []
	var game2_moves: Array = []
	var game1_turns: Array = []
	var game2_turns: Array = []

	var bridge = OpenTableBridge.new()
	bridge.connect("piece_moved", func(gid, p, fr, fc, tr, tc, cr, cc, promoted):
		if gid == "game_a":
			game1_moves.append({"player": p, "to_row": tr, "to_col": tc})
		elif gid == "game_b":
			game2_moves.append({"player": p, "to_row": tr, "to_col": tc})
	)
	bridge.connect("turn_changed", func(gid, p):
		if gid == "game_a":
			game1_turns.append(p)
		elif gid == "game_b":
			game2_turns.append(p)
	)

	bridge.start_multi_session()
	var add_a = bridge.add_multi_session("game_a", "checkers", 1, 2)
	var add_b = bridge.add_multi_session("game_b", "checkers", 1, 2)

	results.append(["Añadir game_a retornó true", add_a])
	results.append(["Añadir game_b retornó true", add_b])

	# Movimiento en game_a: (2,1) -> (3,2)
	bridge.switch_session("game_a")
	results.append(["Sesión activa es game_a", bridge.get_active_game_id() == "game_a"])
	bridge.send_move(1, 2, 1, 3, 2)

	results.append(["game_a recibió 1 movimiento", game1_moves.size() == 1])
	results.append(["game_b NO recibió movimientos de game_a", game2_moves.size() == 0])
	results.append(["game_a cambió de turno a 2", game1_turns.size() == 1 and game1_turns[0] == 2])
	results.append(["game_b NO cambió de turno", game2_turns.size() == 0])

	# Movimiento en game_b: (2,3) -> (3,4)
	bridge.switch_session("game_b")
	results.append(["Sesión activa es game_b", bridge.get_active_game_id() == "game_b"])
	bridge.send_move(1, 2, 3, 3, 4)

	results.append(["game_a mantiene 1 movimiento", game1_moves.size() == 1])
	results.append(["game_b recibió 1 movimiento en (3,4)", game2_moves.size() == 1 and game2_moves[0].to_col == 4])
	results.append(["game_b cambió de turno a 2", game2_turns.size() == 1 and game2_turns[0] == 2])

	# Volver a game_a y mover jugador 2: (5,0) -> (4,1)
	bridge.switch_session("game_a")
	bridge.send_move(2, 5, 0, 4, 1)

	results.append(["game_a recibió 2do movimiento", game1_moves.size() == 2])
	results.append(["game_b mantiene 1 movimiento", game2_moves.size() == 1])

	var all_ok := true
	for r in results:
		var passed: bool = r[1]
		print(("PASS  " if passed else "FAIL  ") + r[0])
		if not passed:
			all_ok = false

	if all_ok:
		print("✅ TEST MULTI_SESSION COMPLETADO CON ÉXITO")
	else:
		print("❌ TEST MULTI_SESSION FALLÓ")

	# --- Verificar que start_hosting y connect_to_host son métodos disponibles ---
	var bridge_host := OpenTableBridge.new()
	assert(bridge_host.has_method("start_hosting"), "Bridge debe tener start_hosting")
	assert(bridge_host.has_method("connect_to_host"), "Bridge debe tener connect_to_host")
	bridge_host.free()

	quit(0 if all_ok else 1)
