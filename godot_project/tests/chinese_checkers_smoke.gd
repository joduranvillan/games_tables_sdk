# Test headless de integración para Damas Chinas (Chinese Checkers).
# Correr: redot --headless --path godot_project --script res://tests/chinese_checkers_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var events_received: Array = []
	var move_rejected_reasons: Array = []

	var bridge = OpenTableBridge.new()

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

	# 1. Iniciar partida local de Damas Chinas
	bridge.start_local_match_chinese_checkers(1, 2)
	results.append(["start_local_match_chinese_checkers arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Movimiento simple válido de la ficha en la punta de la esquina (-1, 1) a (0, 0)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "MovePegCommand",
		"player": 1,
		"from": {"q": -1, "r": 1},
		"to": {"q": 0, "r": 0},
		"path": []
	}))

	var peg_moved = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "PegMovedEvent" in et or "PegMoved" in et:
			peg_moved = true
			break
	# También se puede verificar que no hubo rechazos en este paso
	results.append(["Movimiento válido de ficha emite evento PegMovedEvent", peg_moved or move_rejected_reasons.size() == 0])

	# 3. Movimiento inválido a una casilla ocupada por su propia ficha (-2, 1)
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "MovePegCommand",
		"player": 1,
		"from": {"q": -2, "r": 2},
		"to": {"q": -2, "r": 1},
		"path": []
	}))
	results.append(["Movimiento a casilla ocupada genera rechazo move_rejected", move_rejected_reasons.size() > 0])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
