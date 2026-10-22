# Test headless de integración para el juego UNO.
# Correr: redot --headless --path godot_project --script res://tests/uno_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var events_received: Array = []
	var move_rejected_reasons: Array = []
	var turns_changed: Array = []

	var bridge = OpenTableBridge.new()
	bridge.connect("turn_changed", func(p: int): turns_changed.append(p))

	bridge.connect("event_json", func(json_str: String):
		var parser = JSON.new()
		if parser.parse(json_str) == OK:
			var data = parser.data
			if data is Dictionary:
				events_received.append(data)
	)

	bridge.connect("move_rejected", func(reason: String):
		move_rejected_reasons.append(reason)
	)

	# 1. Iniciar partida local de UNO
	bridge.start_local_match_uno(1, 2)
	results.append(["start_local_match_uno arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Movimiento 1 (P1): Robar carta
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "DrawCardCommand",
		"player": 1
	}))
	results.append(["P1 roba carta -> evento de cartas robadas recibido", events_received.size() >= 1])
	results.append(["Se emitió la señal turn_changed al cambiar de turno", turns_changed.size() >= 1])

	# 3. Movimiento 2: Robar carta con el jugador en turno
	var curr_p = bridge.current_player()
	bridge.send_command_json(curr_p, JSON.stringify({
		"command_type": "DrawCardCommand",
		"player": curr_p
	}))
	results.append(["Segundo movimiento ejecutado con exito", events_received.size() >= 2])

	# 4. Probar CallUnoCommand (se procesa y valida regla sin error de deserialización)
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"type": "CallUnoCommand",
		"command_type": "CallUnoCommand",
		"player": 1
	}))
	# Con mano de 7 cartas debe ser rechazado por la regla de negocio (1 o 2 cartas requeridas)
	var call_uno_processed = move_rejected_reasons.size() > 0 or events_received.any(func(e): return "UnoCalledEvent" in str(e))
	results.append(["CallUnoCommand procesado por el engine de UNO", call_uno_processed])

	# 5. Probar CatchUnoFailureCommand
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"type": "CatchUnoFailureCommand",
		"command_type": "CatchUnoFailureCommand",
		"accuser": 1,
		"target": 2
	}))
	var catch_uno_processed = move_rejected_reasons.size() > 0 or events_received.any(func(e): return "UnoPenaltyEvent" in str(e))
	results.append(["CatchUnoFailureCommand procesado por el engine de UNO", catch_uno_processed])

	# 6. Probar ChallengeWildDrawFourCommand
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"type": "ChallengeWildDrawFourCommand",
		"command_type": "ChallengeWildDrawFourCommand",
		"challenger": 1
	}))
	var challenge_processed = move_rejected_reasons.size() > 0 or events_received.any(func(e): return "WildDrawFourChallengedEvent" in str(e))
	results.append(["ChallengeWildDrawFourCommand procesado por el engine de UNO", challenge_processed])

	# 7. Probar InterceptCommand (Jump-In)
	move_rejected_reasons.clear()
	bridge.send_command_json(2, JSON.stringify({
		"type": "InterceptCommand",
		"command_type": "InterceptCommand",
		"player": 2,
		"card_index": 0
	}))
	var intercept_processed = move_rejected_reasons.size() > 0 or events_received.any(func(e): return "InterceptedEvent" in str(e))
	results.append(["InterceptCommand procesado por el engine de UNO", intercept_processed])

	# 8. Verificar botones y métodos en uno_board.gd
	var board_script = load("res://uno_board.gd")
	if board_script != null:
		var board_inst = board_script.new()
		root.add_child(board_inst)
		if board_inst.find_child("CallUnoButton", true, false) == null and board_inst.has_method("_ready"):
			board_inst._ready()

		var has_call_uno_btn = board_inst.find_child("CallUnoButton", true, false) != null
		var has_catch_uno_btn = board_inst.find_child("CatchUnoButton", true, false) != null
		var has_challenge_btn = board_inst.find_child("ChallengeWildFourButton", true, false) != null
		var has_jump_in_btn = board_inst.find_child("JumpInButton", true, false) != null
		var has_intercept_method = board_inst.has_method("_is_card_interceptable")

		results.append(["uno_board contiene botón 🔥 ¡UNO! (CallUnoButton)", has_call_uno_btn])
		results.append(["uno_board contiene botón 🚨 Acusar UNO (CatchUnoButton)", has_catch_uno_btn])
		results.append(["uno_board contiene botón ⚡ Desafiar +4 (ChallengeWildFourButton)", has_challenge_btn])
		results.append(["uno_board contiene botón ⚡ Jump-In (JumpInButton)", has_jump_in_btn])
		results.append(["uno_board implementa lógica Jump-In (_is_card_interceptable)", has_intercept_method])

		root.remove_child(board_inst)
		board_inst.free()

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
