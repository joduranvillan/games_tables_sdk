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
	# --- Go vs IA ---
	var bridge_go := OpenTableBridge.new()
	var ok_go := bridge_go.start_local_match_go_vs_ai(1, 2, 9)
	assert(ok_go, "Go vs IA: start debe retornar true")
	if bridge_go.current_player() == 1:
		bridge_go.send_command_json(1, JSON.stringify({"type": "PlaceStoneCommand", "player": 1, "x": 4, "y": 4}))
	for _i in range(100):          # MCTS es más lento; 100 frames
		bridge_go._process(0.016)
	var ticks_go: int = bridge_go.session_tick_count()
	assert(ticks_go > 2, "Go vs IA: la IA debe haber hecho al menos 1 movimiento (ticks=%d)" % ticks_go)
	results.append(["Go vs IA: la IA respondió correctamente con movimientos [ticks=%d]" % ticks_go, ok_go and ticks_go > 2])
	bridge_go.free()

	# =========================================================================
	# 4. TEST LUDO VS IA
	# =========================================================================
	# --- Ludo vs IA ---
	var bridge_ludo := OpenTableBridge.new()
	var ok_ludo := bridge_ludo.start_local_match_ludo_vs_ai(1, 2)
	assert(ok_ludo, "Ludo vs IA: start debe retornar true")
	# Ludo necesita un RollDice antes de que la IA actúe
	var dice_cmd_json := JSON.stringify({"type": "RollDiceCommand", "player": 1})
	bridge_ludo.call("send_command_json", dice_cmd_json)
	bridge_ludo.send_command_json(1, dice_cmd_json)
	for _i in range(50):
		bridge_ludo._process(0.016)
	var ticks_ludo: int = bridge_ludo.session_tick_count()
	assert(ticks_ludo >= 1, "Ludo vs IA: debe haber procesado al menos 1 tick")
	results.append(["Ludo vs IA: el bridge procesó al menos 1 tick con la IA [ticks=%d]" % ticks_ludo, ok_ludo and ticks_ludo >= 1])
	bridge_ludo.free()

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
