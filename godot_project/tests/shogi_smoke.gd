# Test headless de integración para el tablero de Shogi.
# Correr: redot --headless --path godot_project --script res://tests/shogi_smoke.gd
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

	# 1. Iniciar partida local de Shogi
	bridge.start_local_match_shogi(1, 2)
	results.append(["start_local_match_shogi arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Movimiento P1: Peón Sente (4,6) a (4,5)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "shogi_game::MovePieceCommand",
		"player": 1,
		"from": [4, 6],
		"to": [4, 5],
		"promote": false
	}))
	results.append(["P1 mueve peón -> turno pasa a P2", bridge.current_player() == 2])
	results.append(["Se recibió evento PieceMovedEvent para P1", events_received.size() == 1])
	results.append(["Se emitió la señal turn_changed con P2", turns_changed.size() == 1 and turns_changed[0] == 2])

	# 3. Movimiento P2: Peón Gote (4,2) a (4,3)
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "shogi_game::MovePieceCommand",
		"player": 2,
		"from": [4, 2],
		"to": [4, 3],
		"promote": false
	}))
	results.append(["P2 mueve peón -> turno pasa a P1", bridge.current_player() == 1])
	results.append(["Se recibieron 2 eventos PieceMovedEvent", events_received.size() == 2])

	# 4. Prueba E2E de interfaz en ShogiBoard (tipografía nítida + clics multi-turno)
	var board_scene = load("res://shogi_board.tscn")
	var shogi_ui: Node2D = board_scene.instantiate()
	shogi_ui._ready()

	var king_node: Control = shogi_ui.piece_nodes[8][4]
	var west_lbl: Label = king_node.get_node_or_null("WesternLabel") if king_node != null else null
	var kanji_lbl: Label = king_node.get_node_or_null("KanjiLabel") if king_node != null else null
	results.append([
		"Pieza pentagonal muestra letra occidental grande (22px) y Kanji secundario (12px) sin solapamiento",
		west_lbl != null and kanji_lbl != null
			and west_lbl.get_theme_font_size("font_size") == 22
			and kanji_lbl.get_theme_font_size("font_size") == 12
			and west_lbl.position.y + west_lbl.size.y <= kanji_lbl.position.y
	])

	var make_click = func(row: int, col: int) -> void:
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = Vector2(
			shogi_ui.BOARD_ORIGIN_X + col * shogi_ui.CELL_SIZE + shogi_ui.CELL_SIZE * 0.5,
			shogi_ui.BOARD_ORIGIN_Y + row * shogi_ui.CELL_SIZE + shogi_ui.CELL_SIZE * 0.5
		)
		shogi_ui._input(press)
		var release: InputEventMouseButton = InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = press.position
		shogi_ui._input(release)

	# Turno 1 UI: Sente selecciona peón en (fila 6, col 4) y avanza a (fila 5, col 4)
	make_click.call(6, 4)
	results.append(["Clic en peón Sente (6,4) selecciona casilla y calcula jugadas válidas", shogi_ui.selected_board_pos == Vector2i(6, 4) and Vector2i(5, 4) in shogi_ui.valid_moves])
	make_click.call(5, 4)
	results.append(["Clic en destino (5,4) mueve el peón Sente y pasa turno a Gote (P2)", shogi_ui.current == 2 and shogi_ui.board[5][4] != null and shogi_ui.board[6][4] == null])

	# Turno 2 UI: Gote selecciona peón en (fila 2, col 4) y avanza a (fila 3, col 4)
	make_click.call(2, 4)
	make_click.call(3, 4)
	results.append(["Clic en destino (3,4) mueve el peón Gote y pasa turno a Sente (P1)", shogi_ui.current == 1 and shogi_ui.board[3][4] != null and shogi_ui.board[2][4] == null])

	# Turno 3 UI: Sente selecciona General de Plata en (fila 8, col 6) y avanza a (fila 7, col 5)
	make_click.call(8, 6)
	make_click.call(7, 5)
	results.append(["Tercer turno UI: Plata Sente avanza de (8,6) a (7,5) con fluidez", shogi_ui.current == 2 and shogi_ui.board[7][5] != null and shogi_ui.board[8][6] == null])

	shogi_ui.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)

