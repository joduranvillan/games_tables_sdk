# Test headless de integración para el tablero de Backgammon.
# Correr: redot --headless --path godot_project --script res://tests/backgammon_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var dice_events: Array = []
	var checker_moved_events: Array = []
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

	bridge.connect("checker_moved", func(player: int, from_pt: int, to_pt: int, captured: bool, borne_off: bool):
		checker_moved_events.append({
			"player": player,
			"from": from_pt,
			"to": to_pt,
			"captured": captured,
			"borne_off": borne_off
		})
	)

	bridge.connect("move_rejected", func(reason: String):
		move_rejected_reasons.append(reason)
	)

	# 1. Iniciar partida local de Backgammon
	bridge.start_local_match_backgammon(1, 2)
	results.append(["start_local_match_backgammon arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Movimiento 1 (P1): Tirar dados
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "RollDiceCommand",
		"player": 1
	}))
	results.append(["P1 tira dados -> se recibe DiceRolledEvent", dice_events.size() == 1])

	# Extraer dado tirado
	var rolled_die = 1
	if dice_events.size() > 0:
		var vals = dice_events[0].get("values", [1])
		if vals.size() > 0:
			rolled_die = int(vals[0])

	# 3. Movimiento 2 (P1): Mover ficha desde el punto 0 con el dado obtenido
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "MoveCheckerCommand",
		"player": 1,
		"from": 0,
		"die": rolled_die
	}))
	results.append(["P1 mueve ficha -> se emite la señal checker_moved", checker_moved_events.size() == 1])
	if checker_moved_events.size() > 0:
		var evt = checker_moved_events[0]
		results.append(["checker_moved reporta jugador 1 y punto inicial 0", evt.player == 1 and evt.from == 0])

	# 4. Probar movimiento inválido (P2 intenta mover cuando no es su turno o movimiento ilegal)
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "MoveCheckerCommand",
		"player": 2,
		"from": 23,
		"die": 6
	}))
	results.append(["Movimiento inválido emite señal move_rejected sin producir crash", move_rejected_reasons.size() > 0])

	# 5. Probar inicio de partida vs IA
	var started_ai = bridge.start_local_match_backgammon_vs_ai(1, 2)
	results.append(["start_local_match_backgammon_vs_ai inicia correctamente", started_ai == true])

	# 6. Probar OfferDoubleCommand y AcceptDoubleCommand en partida local y HUD centrado
	bridge.start_local_match_backgammon(1, 2)
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({"command_type": "OfferDoubleCommand", "player": 1}))
	bridge.send_command_json(2, JSON.stringify({"command_type": "AcceptDoubleCommand", "player": 2}))
	results.append(["OfferDoubleCommand y AcceptDoubleCommand se procesan sin rechazo antes de tirar dados", move_rejected_reasons.size() == 0])

	var bg_script: Script = load("res://backgammon_board.gd") as Script
	if bg_script != null:
		var bg_node: Node2D = bg_script.new() as Node2D
		root.add_child(bg_node)
		if bg_node.get("turn_indicator") == null and bg_node.has_method("_ready"):
			bg_node._ready()
		results.append(["BackgammonBoard inicia centrado con GameAppMenu activo", bg_node.position.x > 100.0 and bg_node.get_node_or_null("GameAppMenu") != null])
		root.remove_child(bg_node)
		bg_node.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)

