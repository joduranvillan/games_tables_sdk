# Test headless de integración para Mille Bornes.
# Correr: redot --headless --path godot_project --script res://tests/mille_bornes_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var events_received: Array = []
	var move_rejected_reasons: Array = []
	var p1_tracked_distance: int = 0

	var bridge = OpenTableBridge.new()

	bridge.connect("event_json", func(json_str: String):
		var parser = JSON.new()
		if parser.parse(json_str) == OK:
			var data = parser.data
			if data is Dictionary:
				events_received.append(data)
				var et = data.get("event_type", data.get("command_type", ""))
				if "DistancePlayedEvent" in et and data.get("player") == 1:
					p1_tracked_distance = int(data.get("new_distance", p1_tracked_distance))
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

	# 3. Jugar 5 rondas y verificar que bridge.get_distance(1) incrementa correctamente
	var distances = [25, 50, 75, 100, 100]
	var total_expected = 0
	var distance_increments_ok = true

	for round_num in range(1, 6):
		var dist_to_play = distances[round_num - 1]
		var prev_dist = bridge.get_distance(1) if bridge.has_method("get_distance") else p1_tracked_distance
		
		# P1 juega carta de distancia
		bridge.send_command_json(1, JSON.stringify({
			"command_type": "PlayDistanceCommand",
			"player": 1,
			"distance": dist_to_play
		}))
		total_expected += dist_to_play

		var curr_dist = bridge.get_distance(1) if bridge.has_method("get_distance") else p1_tracked_distance
		if curr_dist <= prev_dist or (bridge.has_method("get_distance") and curr_dist != total_expected):
			distance_increments_ok = false

		# P2 juega carta de distancia para que el turno vuelva a P1
		bridge.send_command_json(2, JSON.stringify({
			"command_type": "PlayDistanceCommand",
			"player": 2,
			"distance": 25
		}))

		# P1 roba carta para reponer mano
		bridge.send_command_json(1, JSON.stringify({
			"command_type": "DrawCardCommand",
			"player": 1
		}))

	results.append(["5 rondas jugadas y bridge.get_distance(1) incrementa correctamente a %d km" % total_expected, distance_increments_ok])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
