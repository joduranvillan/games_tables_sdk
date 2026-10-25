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

	# 4. Prueba E2E de input en ChessBoard (click en pieza e2 + click en destino e4, y drag d7->d5)
	var chess_scene: PackedScene = load("res://chess_board.tscn")
	var chess_node = chess_scene.instantiate()
	root.add_child(chess_node)
	if chess_node.bridge == null and chess_node.has_method("_ready"):
		chess_node._ready()
	chess_node._on_mode_selected(0) # Hotseat P1 vs P2

	# Click 1 en e2 (fila visual 6, col 4): press + release
	var e2_pos := Vector2(4 * 76.0 + 38.0, 6 * 76.0 + 38.0)
	var ev_press1 := InputEventMouseButton.new()
	ev_press1.button_index = MOUSE_BUTTON_LEFT
	ev_press1.pressed = true
	ev_press1.position = e2_pos
	chess_node._handle_unified_input(ev_press1)

	var ev_rel1 := InputEventMouseButton.new()
	ev_rel1.button_index = MOUSE_BUTTON_LEFT
	ev_rel1.pressed = false
	ev_rel1.position = e2_pos
	chess_node._handle_unified_input(ev_rel1)

	results.append(["ChessBoard click en e2 mantiene pieza seleccionada tras soltar ratón", chess_node.selected_pos == Vector2i(6, 4)])
	results.append(["ChessBoard calcula jugadas válidas para e2 (e3 y e4)", chess_node.valid_moves.size() == 2])

	# Click 2 en e4 (fila visual 4, col 4): press + release
	var e4_pos := Vector2(4 * 76.0 + 38.0, 4 * 76.0 + 38.0)
	var ev_press2 := InputEventMouseButton.new()
	ev_press2.button_index = MOUSE_BUTTON_LEFT
	ev_press2.pressed = true
	ev_press2.position = e4_pos
	chess_node._handle_unified_input(ev_press2)

	var ev_rel2 := InputEventMouseButton.new()
	ev_rel2.button_index = MOUSE_BUTTON_LEFT
	ev_rel2.pressed = false
	ev_rel2.position = e4_pos
	chess_node._handle_unified_input(ev_rel2)

	results.append(["ChessBoard avanza peón blanco e2->e4 en primer turno y pasa turno a J2", chess_node.current == 2 and chess_node.piece_sprites[4][4] != null])

	root.remove_child(chess_node)
	chess_node.free()

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
