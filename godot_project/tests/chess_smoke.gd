# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
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
	var e2_pos: Vector2 = Vector2(4 * 76.0 + 38.0, 6 * 76.0 + 38.0)
	var ev_press1: InputEventMouseButton = InputEventMouseButton.new()
	ev_press1.button_index = MOUSE_BUTTON_LEFT
	ev_press1.pressed = true
	ev_press1.position = e2_pos
	chess_node._handle_unified_input(ev_press1)

	var ev_rel1: InputEventMouseButton = InputEventMouseButton.new()
	ev_rel1.button_index = MOUSE_BUTTON_LEFT
	ev_rel1.pressed = false
	ev_rel1.position = e2_pos
	chess_node._handle_unified_input(ev_rel1)

	results.append(["ChessBoard click en e2 mantiene pieza seleccionada tras soltar ratón", chess_node.selected_pos == Vector2i(6, 4)])
	results.append(["ChessBoard calcula jugadas válidas para e2 (e3 y e4)", chess_node.valid_moves.size() == 2])

	# Click 2 en e4 (fila visual 4, col 4): press + release
	var e4_pos: Vector2 = Vector2(4 * 76.0 + 38.0, 4 * 76.0 + 38.0)
	var ev_press2: InputEventMouseButton = InputEventMouseButton.new()
	ev_press2.button_index = MOUSE_BUTTON_LEFT
	ev_press2.pressed = true
	ev_press2.position = e4_pos
	chess_node._handle_unified_input(ev_press2)

	var ev_rel2: InputEventMouseButton = InputEventMouseButton.new()
	ev_rel2.button_index = MOUSE_BUTTON_LEFT
	ev_rel2.pressed = false
	ev_rel2.position = e4_pos
	chess_node._handle_unified_input(ev_rel2)

	results.append(["ChessBoard avanza peón blanco e2->e4 en primer turno y pasa turno a J2", chess_node.current == 2 and chess_node.piece_sprites[4][4] != null])

	# 5. Prueba multi-turno vs IA (Medio, index 2): 1. e2->e4, 2. d2->d3, 3. Caballo g1->f3
	chess_node._on_mode_selected(2) # vs IA (Blancas J1 - Medio)
	var click_square = func(r: int, c: int):
		var pos: Vector2 = Vector2(c * 76.0 + 38.0, r * 76.0 + 38.0)
		var p: InputEventMouseButton = InputEventMouseButton.new()
		p.button_index = MOUSE_BUTTON_LEFT
		p.pressed = true
		p.position = pos
		chess_node._handle_unified_input(p)
		var rel: InputEventMouseButton = InputEventMouseButton.new()
		rel.button_index = MOUSE_BUTTON_LEFT
		rel.pressed = false
		rel.position = pos
		chess_node._handle_unified_input(rel)

	# Turno 1: e2 (6,4) -> e4 (4,4)
	click_square.call(6, 4)
	click_square.call(4, 4)
	results.append(["ChessBoard vs IA Turno 1 (e2->e4): IA responde y devuelve turno a J1", chess_node.current == 1])

	# Turno 2: d2 (6,3) -> d3 (5,3)
	click_square.call(6, 3)
	click_square.call(5, 3)
	results.append(["ChessBoard vs IA Turno 2 (d2->d3): IA responde y devuelve turno a J1", chess_node.current == 1])

	# Turno 3: Caballo g1 (7,6) -> f3 (5,5)
	click_square.call(7, 6)
	results.append(["ChessBoard vs IA Turno 3: click en caballo g1 selecciona (7,6) y muestra f3 (5,5) como válida", chess_node.selected_pos == Vector2i(7, 6) and Vector2i(5, 5) in chess_node.valid_moves])
	click_square.call(5, 5)
	results.append(["ChessBoard vs IA Turno 3 (Ng1->f3): caballo avanza a f3 y la IA responde devolviendo turno a J1", chess_node.current == 1 and chess_node.piece_sprites[7][6] == null])

	# 6. Verificar atajos de subpromoción 1-4 y rechazo de AcceptDrawCommand sin oferta previa
	chess_node.call("handle_promotion_shortcut", 2)
	var promo_rook: bool = str(chess_node.get("selected_promotion_kind")) == "Rook"
	chess_node.call("handle_promotion_shortcut", 3)
	var promo_bishop: bool = str(chess_node.get("selected_promotion_kind")) == "Bishop"
	chess_node.call("handle_promotion_shortcut", 1)
	var promo_queen: bool = str(chess_node.get("selected_promotion_kind")) == "Queen"
	results.append(["Atajos de coronación 1, 2 y 3 seleccionan Dama, Torre y Alfil respectivamente", promo_queen and promo_rook and promo_bishop])

	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "chess_game::AcceptDrawCommand",
		"player": 1
	}))
	results.append(["AcceptDrawCommand sin oferta previa genera rechazo move_rejected", move_rejected_reasons.size() > 0])
	results.append(["ChessBoard centrado horizontalmente con GameAppMenu activo", chess_node.position.x > 100.0 and chess_node.get_node_or_null("GameAppMenu") != null])

	root.remove_child(chess_node)
	chess_node.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)

