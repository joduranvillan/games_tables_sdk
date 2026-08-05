# Test headless de integración para el tablero de Ajedrez (Chess).
# Correr: redot --headless --path godot_project --script res://tests/chess_smoke.gd
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
				var evt_type = data.get("event_type", data.get("command_type", ""))
				if evt_type.contains("PieceMovedEvent"):
					events_received.append(data)
	)

	bridge.connect("move_rejected", func(reason: String):
		move_rejected_reasons.append(reason)
	)

	# 1. Iniciar partida local de Ajedrez
	bridge.start_local_match_chess(1, 2)
	results.append(["start_local_match_chess arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Movimiento P1: Peón blanco de e2 (row 1, col 4) a e4 (row 3, col 4)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "chess_game::MovePieceCommand",
		"player": 1,
		"from": {"row": 1, "col": 4},
		"to": {"row": 3, "col": 4},
		"promote_to": null
	}))
	results.append(["P1 mueve e2-e4 -> turno pasa a P2", bridge.current_player() == 2])
	results.append(["Se recibió evento PieceMovedEvent para P1", events_received.size() == 1])
	results.append(["Se emitió la señal turn_changed con P2", turns_changed.size() == 1 and turns_changed[0] == 2])

	# 3. Movimiento P2: Peón negro de e7 (row 6, col 4) a e5 (row 4, col 4)
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "chess_game::MovePieceCommand",
		"player": 2,
		"from": {"row": 6, "col": 4},
		"to": {"row": 4, "col": 4},
		"promote_to": null
	}))
	results.append(["P2 mueve e7-e5 -> turno pasa a P1", bridge.current_player() == 1])
	results.append(["Se recibieron 2 eventos PieceMovedEvent", events_received.size() == 2])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
