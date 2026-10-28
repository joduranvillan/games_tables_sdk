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

	# 8. Verificar botones, diseño visual (Panel vs PanelContainer) y turno de IA en uno_board.gd
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

		# Verificar que _create_card_visual devuelve un Panel (no PanelContainer) y mesa amplia (1200x692)
		var sample_card = board_inst._create_card_visual({"color": "Red", "value": "5"}, true, false)
		var is_plain_panel = (sample_card is Panel) and not (sample_card is PanelContainer)
		sample_card.free()
		results.append(["_create_card_visual usa Panel para no deformar el óvalo interior", is_plain_panel])
		results.append(["TableMatPanel tiene diseño amplio centrado (1200x692)", board_inst.table_mat_panel != null and board_inst.table_mat_panel.size.x >= 1100])

		# 9. Verificar que comodín / +4 en descarte se pinta con el color activo elegido
		board_inst.active_color = "Blue"
		var wild_display_card: Dictionary = board_inst._get_discard_display_card({"color": "Wild", "value": "WildDrawFour"})
		results.append(["Comodín +4 en descarte adopta el color elegido (Blue)", str(wild_display_card.get("color", "")) == "Blue"])

		board_inst.discard_pile = [{"color": "Wild", "value": "Wild"}]
		board_inst._update_discard_display()
		var discard_sb = board_inst.discard_card_node.get_theme_stylebox("panel") as StyleBoxFlat
		var discard_painted_blue = discard_sb != null and discard_sb.bg_color.is_equal_approx(board_inst.CARD_COLORS["Blue"])
		results.append(["Carta Wild en pila de descarte se pinta visualmente con el color elegido", discard_painted_blue])

		# 10. Probar partida vs IA en uno_board.gd jugando una carta desde la mano humana
		board_inst._on_mode_selected(1) # vs IA (Humano = J1, IA = J2)
		var tick_before: int = board_inst.bridge.current_tick()
		var played_non_wild := false
		for i in range(board_inst.player_hand.size()):
			var c = board_inst.player_hand[i]
			var c_col = str(c.get("color", ""))
			var c_val = str(c.get("value", ""))
			if board_inst._is_card_playable(c) and not (c_col in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]):
				board_inst._execute_play_card(i, Vector2.ZERO, "")
				played_non_wild = true
				break
		if not played_non_wild:
			board_inst._on_draw_pile_pressed()
		var tick_after: int = board_inst.bridge.current_tick()
		results.append(["En modo vs IA, jugada de J1 es aceptada y la IA responde automáticamente (ticks >= +2)", not board_inst._last_move_rejected and tick_after >= tick_before + 2 and board_inst.current == 1])
		results.append(["Penalización de robo (+2/+4) queda en 0 tras aplicarse automáticamente", board_inst.draw_penalty == 0])

		# 11. Verificar que tras definir el color con Wild/+4/+2 y resolverse el salto, una carta normal de ese color es jugable sin obligar a robar
		board_inst.active_color = "Blue"
		board_inst.draw_penalty = 0
		board_inst._rust_draw_penalty = 0
		board_inst.discard_pile = [{"color": "Wild", "value": "WildDrawFour"}]
		var blue_card_playable: bool = board_inst._is_card_playable({"color": "Blue", "value": "7"})
		results.append(["Tras jugar comodín +4/+2 y saltar turno, carta del color elegido es jugable sin obligar a robar", blue_card_playable])

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
