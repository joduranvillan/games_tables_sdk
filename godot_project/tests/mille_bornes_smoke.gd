# Test headless de integración para Mille Bornes.
# Correr: redot --headless --path godot_project --script res://tests/mille_bornes_smoke.gd
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

	# 1. Iniciar partida local de Mille Bornes
	bridge.start_local_match_mille_bornes(1, 2)
	results.append(["start_local_match_mille_bornes arranca con jugador 1", bridge.current_player() == 1])

	# 2. Configurar mazo y manos iniciales
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "SetupDeckCommand"
	}))
	results.append(["SetupDeckCommand procesado sin errores", move_rejected_reasons.size() == 0])

	# 3. Jugar carta de distancia válida (P1)
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "PlayDistanceCommand",
		"player": 1,
		"distance": 25
	}))
	var distance_played_event = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "DistancePlayedEvent" in et:
			distance_played_event = true
			break
	results.append(["PlayDistanceCommand con 25 km emite DistancePlayedEvent", distance_played_event])

	# 4. P2 juega carta de distancia para que el turno vuelva a P1
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "PlayDistanceCommand",
		"player": 2,
		"distance": 25
	}))

	# 5. Robo de carta (P1 tiene 5 cartas en mano tras jugar, ahora sí puede robar)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "DrawCardCommand",
		"player": 1
	}))
	var drawn_event = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "CardDrawnEvent" in et:
			drawn_event = true
			break
	results.append(["DrawCardCommand emite CardDrawnEvent", drawn_event])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
