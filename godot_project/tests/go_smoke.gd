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
	var p2 = bridge.current_player()
	bridge.send_command_json(p2, JSON.stringify({
		"command_type": "go_game::PassCommand",
		"player": p2
	}))
	results.append(["Primer pass exitoso, no hay game_over aún", game_over_winners.size() == 0])

	# 6. P1 pasa su turno. Dos pases entran en fase dead marking
	var p1 = bridge.current_player()
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

	# 8. Verificar inicialización, captura visual, selector 9x9/13x13/19x19 y doble pase en GoBoard
	var go_scene = load("res://go_board.tscn")
	if go_scene != null:
		var go_ui: Node2D = go_scene.instantiate()
		go_ui._ready()
		results.append(["GoBoard inicia con selector de tamaño en 9x9", go_ui.BOARD_SIZE == 9 and go_ui.size_option_button != null])

		# Escenario de captura por rodeado:
		# Negro en (fila 0, col 0), Blanco en (fila 0, col 1), Negro en (fila 0, col 2), Blanco en (fila 5, col 5), Negro en (fila 1, col 1)
		go_ui._on_cell_clicked(Vector2i(0, 0)) # Negro A9
		go_ui._on_cell_clicked(Vector2i(0, 1)) # Blanco B9
		results.append(["Piedra blanca colocada en B9 (0,1)", go_ui.board[0][1] == 2 and go_ui.stone_nodes[0][1] != null])
		go_ui._on_cell_clicked(Vector2i(0, 2)) # Negro C9
		go_ui._on_cell_clicked(Vector2i(5, 5)) # Blanco F4
		go_ui._on_cell_clicked(Vector2i(1, 1)) # Negro B8 -> rodea y captura B9 (0,1)
		results.append([
			"Piedra blanca rodeada en B9 (0,1) es capturada y retirada del tablero visual y lógico",
			go_ui.board[0][1] == null and go_ui.stone_nodes[0][1] == null and go_ui.black_captured == 1
		])

		# Verificar cambio a 13x13 y 19x19
		go_ui.set_board_size(13)
		results.append(["Selector cambia el tablero a 13x13 correctamente", go_ui.BOARD_SIZE == 13 and go_ui.board.size() == 13])
		go_ui.set_board_size(19)
		results.append(["Selector cambia el tablero a 19x19 correctamente", go_ui.BOARD_SIZE == 19 and go_ui.board.size() == 19])

		# Verificar doble pase con cierre automático
		go_ui.set_board_size(9)
		go_ui._on_cell_clicked(Vector2i(2, 2)) # Negro juega
		go_ui._on_pass_pressed() # Blanco pasa
		go_ui._on_pass_pressed() # Negro pasa -> doble pase cierra partida automáticamente
		results.append(["Doble pase consecutivo en GoBoard calcula territorio y cierra la partida", go_ui.winner != -1])

		# Verificar rechazo de SetKomiCommand tras colocar piedras
		go_ui.set_board_size(9)
		go_ui._on_cell_clicked(Vector2i(4, 4))
		move_rejected_reasons.clear()
		bridge.start_local_match_go(1, 2)
		bridge.send_command_json(1, JSON.stringify({"command_type": "go_game::PlaceStoneCommand", "player": 1, "x": 4, "y": 4}))
		bridge.send_command_json(2, JSON.stringify({"command_type": "go_game::SetKomiCommand", "player": 2, "komi_half_points": 15}))
		results.append(["SetKomiCommand tras iniciar jugadas en el tablero genera rechazo move_rejected", move_rejected_reasons.size() > 0])

		go_ui.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)


