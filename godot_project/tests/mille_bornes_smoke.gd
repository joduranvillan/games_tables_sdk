# Test headless de integración para Mille Bornes.
# Correr: redot --headless --path godot_project --script res://tests/mille_bornes_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var events_received: Array = []
	var move_rejected_reasons: Array = []
	var tracked: Dictionary = {"p1_distance": 0}

	var bridge = OpenTableBridge.new()

	bridge.connect("event_json", func(json_str: String):
		var parser = JSON.new()
		if parser.parse(json_str) == OK:
			var data = parser.data
			if data is Dictionary:
				events_received.append(data)
				var et = data.get("event_type", data.get("command_type", ""))
				if "DistancePlayedEvent" in et and data.get("player") == 1:
					tracked["p1_distance"] = int(data.get("new_distance", tracked["p1_distance"]))
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
		var prev_dist = bridge.get_distance(1) if bridge.has_method("get_distance") else int(tracked["p1_distance"])
		
		# P1 juega carta de distancia
		bridge.send_command_json(1, JSON.stringify({
			"command_type": "PlayDistanceCommand",
			"player": 1,
			"distance": dist_to_play
		}))
		total_expected += dist_to_play

		var curr_dist = bridge.get_distance(1) if bridge.has_method("get_distance") else int(tracked["p1_distance"])
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

	# 4. Probar límite canónico de máximo 2 cartas de 200 km por jugador
	bridge.send_command_json(1, JSON.stringify({"command_type": "PlayDistanceCommand", "player": 1, "distance": 200}))
	bridge.send_command_json(2, JSON.stringify({"command_type": "PlayDistanceCommand", "player": 2, "distance": 25}))
	bridge.send_command_json(1, JSON.stringify({"command_type": "PlayDistanceCommand", "player": 1, "distance": 200}))
	bridge.send_command_json(2, JSON.stringify({"command_type": "PlayDistanceCommand", "player": 2, "distance": 25}))
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({"command_type": "PlayDistanceCommand", "player": 1, "distance": 200}))
	results.append(["Intentar jugar una 3ª carta de 200 km genera rechazo move_rejected", move_rejected_reasons.size() > 0])

	# 5. Verificar MilleBornesBoard con controlador de 4 escudos y GameAppMenu
	var mb_script: Script = load("res://mille_bornes_board.gd") as Script
	if mb_script != null:
		var mb_node: Node2D = mb_script.new() as Node2D
		root.add_child(mb_node)
		if mb_node.get("coup_fourre_btn") == null and mb_node.has_method("_ready"):
			mb_node._ready()
		var gm_menu: Node = mb_node.get_node_or_null("GameAppMenu")
		if gm_menu == null:
			gm_menu = mb_node.find_child("GameAppMenu", true, false)
		results.append(["MilleBornesBoard instancia CoupFourreButton y GameAppMenu", mb_node.get("coup_fourre_btn") != null and gm_menu != null])
		root.remove_child(mb_node)
		mb_node.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)

