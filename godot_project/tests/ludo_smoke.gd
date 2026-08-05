# Test headless de integración para el tablero de Ludo.
# Correr: redot --headless --path godot_project --script res://tests/ludo_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var dice_events: Array = []
	var token_moved_events: Array = []
	var move_rejected_reasons: Array = []
	var turns_changed: Array = []

	var bridge = OpenTableBridge.new()
	bridge.connect("turn_changed", func(p: int): turns_changed.append(p))

	bridge.connect("event_json", func(json_str: String):
		var parser = JSON.new()
		if parser.parse(json_str) == OK:
			var data = parser.data
			if data is Dictionary:
				var evt_type = data.get("event_type", data.get("command_type", ""))
				if evt_type.contains("DiceRolledEvent"):
					dice_events.append(data)
	)

	bridge.connect("token_moved", func(player: int, token_index: int, from_steps: int, to_steps: int, finished: bool):
		token_moved_events.append({
			"player": player,
			"token_index": token_index,
			"from_steps": from_steps,
			"to_steps": to_steps,
			"finished": finished
		})
	)

	bridge.connect("move_rejected", func(reason: String):
		move_rejected_reasons.append(reason)
	)

	# 1. Iniciar partida local de Ludo
	bridge.start_local_match_ludo(1, 2)
	results.append(["start_local_match_ludo arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Bucle de tiradas hasta lograr un movimiento de ficha (sale con 6 o mueve)
	var attempts = 0
	while token_moved_events.size() == 0 and attempts < 100:
		attempts += 1
		var curr_p = bridge.current_player()

		# Tirar dado
		bridge.send_command_json(curr_p, JSON.stringify({
			"command_type": "ludo_game::RollDiceCommand",
			"player": curr_p
		}))

		# Intentar mover ficha 0 (usar el jugador actual por si cambió tras tirar dado)
		var active_p = bridge.current_player()
		bridge.send_command_json(active_p, JSON.stringify({
			"command_type": "ludo_game::MoveTokenCommand",
			"player": active_p,
			"token_index": 0
		}))

	results.append(["Se recibió evento token_moved al mover una ficha de Ludo", token_moved_events.size() > 0])
	if token_moved_events.size() > 0:
		var evt = token_moved_events[0]
		results.append(["token_moved emite coordenadas de pasos correctas (0 -> 1)", evt.from_steps == 0 and evt.to_steps == 1])

	# 3. Verificar rechazo de movimiento fuera de turno
	move_rejected_reasons.clear()
	var invalid_p = 3 - bridge.current_player()
	bridge.send_command_json(invalid_p, JSON.stringify({
		"command_type": "ludo_game::MoveTokenCommand",
		"player": invalid_p,
		"token_index": 0
	}))
	results.append(["Movimiento de jugador fuera de turno genera rechazo", move_rejected_reasons.size() > 0])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
