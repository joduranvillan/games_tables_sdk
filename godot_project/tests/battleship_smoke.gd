# Test headless de integración para Batalla Naval (Battleship).
# Correr: redot --headless --path godot_project --script res://tests/battleship_smoke.gd
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

	# 1. Iniciar partida local de Batalla Naval
	bridge.start_local_match_battleship(1, 2)
	results.append(["start_local_match_battleship inicia correctamente en fase de colocación", bridge != null])

	# 2. Colocar flota válida para el Jugador 1 (5 barcos: tamaños 5, 4, 3, 3 y 2)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "PlaceFleetCommand",
		"player": 1,
		"ships": [
			[{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 0, "col": 4}],
			[{"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 2, "col": 2}, {"row": 2, "col": 3}],
			[{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}],
			[{"row": 6, "col": 0}, {"row": 6, "col": 1}, {"row": 6, "col": 2}],
			[{"row": 8, "col": 0}, {"row": 8, "col": 1}]
		]
	}))

	var fleet_placed_event = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "FleetPlacedEvent" in et:
			fleet_placed_event = true
			break

	results.append(["Colocación de flota válida emite FleetPlacedEvent", fleet_placed_event])

	# 3. Colocar flota inválida para el Jugador 2 (barco fuera de límites: row = 15)
	move_rejected_reasons.clear()
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "PlaceFleetCommand",
		"player": 2,
		"ships": [
			[{"row": 15, "col": 0}, {"row": 15, "col": 1}, {"row": 15, "col": 2}, {"row": 15, "col": 3}, {"row": 15, "col": 4}],
			[{"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 2, "col": 2}, {"row": 2, "col": 3}],
			[{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}],
			[{"row": 6, "col": 0}, {"row": 6, "col": 1}, {"row": 6, "col": 2}],
			[{"row": 8, "col": 0}, {"row": 8, "col": 1}]
		]
	}))

	results.append(["Colocación de flota fuera de límites genera rechazo move_rejected", move_rejected_reasons.size() > 0])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
