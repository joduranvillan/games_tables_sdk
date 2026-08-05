# Test headless de integración para el tablero de Go.
# Correr: redot --headless --path godot_project --script res://tests/go_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var captured_counts: Array = []
	var game_over_winners: Array = []
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
				if evt_type.contains("StonesCapturedEvent"):
					captured_counts.append(int(data.get("count", 0)))
				elif evt_type.contains("GameOverEvent"):
					game_over_winners.append(int(data.get("winner", 0)))
	)

	bridge.connect("game_over", func(winner: int):
		game_over_winners.append(winner)
	)

	bridge.connect("move_rejected", func(reason: String):
		move_rejected_reasons.append(reason)
	)

	# 1. Iniciar partida local de Go entre Jugador 1 (Negro) y Jugador 2 (Blanco)
	bridge.start_local_match_go(1, 2)
	results.append(["start_local_match_go arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Colocar piedra P1 en (1, 0)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "go_game::PlaceStoneCommand",
		"player": 1,
		"x": 1,
		"y": 0
	}))
	results.append(["P1 coloca piedra en (1,0) -> turno pasa a P2", bridge.current_player() == 2])
	results.append(["Se emitió la señal turn_changed con P2", turns_changed.size() == 1 and turns_changed[0] == 2])

	# 3. Colocar piedra P2 en (0, 0)
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "go_game::PlaceStoneCommand",
		"player": 2,
		"x": 0,
		"y": 0
	}))
	results.append(["P2 coloca piedra en (0,0) -> turno pasa a P1", bridge.current_player() == 1])

	# 4. Colocar piedra P1 en (0, 1) capturando la piedra de P2 en (0,0)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "go_game::PlaceStoneCommand",
		"player": 1,
		"x": 0,
		"y": 1
	}))

	results.append(["Se emitió señal/evento de captura de piedras", captured_counts.size() >= 1])
	if captured_counts.size() >= 1:
		results.append(["Cantidad de piedras capturadas es count == 1", captured_counts[0] == 1])

	# 5. P2 pasa su turno
	var p2 := bridge.current_player()
	bridge.send_command_json(p2, JSON.stringify({
		"command_type": "go_game::PassCommand",
		"player": p2
	}))
	results.append(["Primer pass exitoso, no hay game_over aún", game_over_winners.size() == 0])

	# 6. P1 pasa su turno. Dos pases entran en fase dead marking
	var p1 := bridge.current_player()
	bridge.send_command_json(p1, JSON.stringify({
		"command_type": "go_game::PassCommand",
		"player": p1
	}))

	# 7. Ambos confirman piedras muertas -> gatilla game_over
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "go_game::ConfirmDeadCommand",
		"player": 1
	}))
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "go_game::ConfirmDeadCommand",
		"player": 2
	}))
	results.append(["Dos pases consecutivos y confirmación gatillan la señal game_over", game_over_winners.size() >= 1])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
