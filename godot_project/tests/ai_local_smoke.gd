# Test headless de humo para la IA local (Checkers, Chess, Go y Ludo vs IA).
# Correr: redot --headless --path godot_project --script res://tests/ai_local_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []

	# =========================================================================
	# 1. TEST CHECKERS VS IA (Local Match vs AI)
	# =========================================================================
	var bridge = OpenTableBridge.new()
	var checkers_started = bridge.start_local_match_checkers_vs_ai(42, 1, 2)
	results.append(["start_local_match_checkers_vs_ai inició correctamente", checkers_started])
	results.append(["Turno inicial de checkers es Jugador 1 (humano)", bridge.current_player() == 1])

	# Jugador 1 (humano) realiza su primer movimiento: (2, 1) -> (3, 2)
	bridge.send_move(1, 2, 1, 3, 2)

	# Bucle de 50 frames procesando bridge._process(0.016)
	for frame in range(50):
		bridge._process(0.016)
		# Si la IA respondió y volvió el turno a Jugador 1, Jugador 1 realiza un segundo movimiento
		if bridge.current_player() == 1 and bridge.get_session_ticks() < 3:
			bridge.send_move(1, 2, 3, 3, 4)

	var checkers_ticks = bridge.get_session_ticks()
	results.append(["Checkers: ticks de la sesión > 2 (la IA respondió a los movimientos) [ticks=%d]" % checkers_ticks, checkers_ticks > 2])

	bridge.free()

	# =========================================================================
	# 2. TEST CHESS VS IA (Local Match vs AI, depth=1)
	# =========================================================================
	var chess_bridge = OpenTableBridge.new()
	var chess_started = chess_bridge.start_local_match_chess_vs_ai(1, 2, 1)
	results.append(["start_local_match_chess_vs_ai inició correctamente", chess_started])
	results.append(["Turno inicial de ajedrez es Jugador 1 (humano)", chess_bridge.current_player() == 1])

	# Jugador 1 (humano) realiza su primer movimiento: Peón e2-e4
	chess_bridge.send_command_json(1, JSON.stringify({
		"command_type": "chess_game::MovePieceCommand",
		"player": 1,
		"from": {"row": 1, "col": 4},
		"to": {"row": 3, "col": 4},
		"promote_to": null
	}))

	# Bucle de 50 frames procesando chess_bridge._process(0.016)
	for frame in range(50):
		chess_bridge._process(0.016)
		# Si la IA respondió y volvió el turno a Jugador 1, Jugador 1 realiza un segundo movimiento (Caballo g1-f3)
		if chess_bridge.current_player() == 1 and chess_bridge.get_session_ticks() < 3:
			chess_bridge.send_command_json(1, JSON.stringify({
				"command_type": "chess_game::MovePieceCommand",
				"player": 1,
				"from": {"row": 0, "col": 6},
				"to": {"row": 2, "col": 5},
				"promote_to": null
			}))

	var chess_ticks = chess_bridge.get_session_ticks()
	results.append(["Chess: ticks de la sesión > 2 (la IA respondió a los movimientos) [ticks=%d]" % chess_ticks, chess_ticks > 2])

	chess_bridge.free()

	# =========================================================================
	# 3. TEST GO (9x9) VS IA
	# =========================================================================
	var go_bridge = OpenTableBridge.new()
	var go_started = go_bridge.start_local_match_go_vs_ai(1, 2, 9)
	results.append(["start_local_match_go_vs_ai(1, 2, 9) inició correctamente", go_started])

	var go_human_moves = [
		{"x": 4, "y": 4},
		{"x": 2, "y": 2},
		{"x": 6, "y": 6},
		{"x": 2, "y": 6},
		{"x": 6, "y": 2},
		{"x": 4, "y": 2}
	]
	var go_mv_idx = 0

	for i in range(80):          # Go: hasta 80 frames
		if go_bridge.current_player() == 1 and go_mv_idx < go_human_moves.size():
			var mv = go_human_moves[go_mv_idx]
			go_mv_idx += 1
			go_bridge.send_command_json(1, JSON.stringify({
				"type": "PlaceStoneCommand",
				"player": 1,
				"x": mv["x"],
				"y": mv["y"]
			}))
		go_bridge._process(0.016)

	var go_ticks = go_bridge.session_tick_count()
	results.append(["La IA de Go debe hacer al menos 5 movimientos [ticks=%d]" % go_ticks, go_ticks > 5])
	assert(go_ticks > 5, "La IA de Go debe hacer al menos 5 movimientos")

	go_bridge.free()

	# =========================================================================
	# 4. TEST LUDO VS IA
	# =========================================================================
	var ludo_bridge = OpenTableBridge.new()
	var ludo_started = ludo_bridge.start_local_match_ludo_vs_ai(1, 2)
	results.append(["start_local_match_ludo_vs_ai inició correctamente", ludo_started])

	# Ludo requiere tiradas de dado antes de que la IA actúe
	ludo_bridge.send_command_json(1, JSON.stringify({"type": "RollDiceCommand", "player": 1}))
	for i in range(30):
		ludo_bridge._process(0.016)
	var ludo_ticks = ludo_bridge.session_tick_count()
	results.append(["El bridge debe haber procesado al menos 1 tick [ticks=%d]" % ludo_ticks, ludo_ticks >= 1])
	assert(ludo_ticks >= 1, "El bridge debe haber procesado al menos 1 tick")

	ludo_bridge.free()

	# =========================================================================
	# EVALUACIÓN DE RESULTADOS
	# =========================================================================
	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	quit(0 if ok else 1)
