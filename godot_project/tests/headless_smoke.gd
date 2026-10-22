# Test headless de integración para Damas (CheckersBoard + OpenTableBridge).
# Correr: redot --headless --path godot_project -s tests/headless_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var moved: Array = []
	var rejected: Array = []
	var turns_changed: Array = []

	var bridge = OpenTableBridge.new()
	bridge.connect("piece_moved", func(p, fr, fc, tr, tc, cr, cc, promoted):
		moved.append({"player": p, "to_row": tr, "to_col": tc, "captured_row": cr}))
	bridge.connect("move_rejected", func(reason): rejected.append(reason))
	bridge.connect("turn_changed", func(p): turns_changed.append(p))

	bridge.start_local_match(1, 2)
	results.append(["arranca con turno del jugador 1 (top)", bridge.current_player() == 1])

	# Movimiento válido del top (increasing, avanza +fila): (2,1) -> (3,2).
	bridge.send_move(1, 2, 1, 3, 2)
	results.append(["movimiento válido -> piece_moved", moved.size() == 1])
	if moved.size() == 1:
		results.append(["llegó a (3,2)", moved[0].to_row == 3 and moved[0].to_col == 2])
		results.append(["sin captura (captured_row==-1)", moved[0].captured_row == -1])
	results.append(["el turno pasó al jugador 2", bridge.current_player() == 2])
	results.append(["se emitió la señal turn_changed con nuevo jugador 2", turns_changed.size() == 1 and turns_changed[0] == 2])

	# Verificar resaltado de multicaptura en CheckersBoard
	var board_scene: PackedScene = load("res://checkers_board.tscn")
	var board_node = board_scene.instantiate()
	root.add_child(board_node)
	if board_node.board.is_empty() and board_node.has_method("_ready"):
		board_node._ready()

	# Simular evento de salto en el que el turno continúa perteneciendo al jugador 1 (multicaptura activa)
	board_node.board[3][4] = {"owner": 2, "king": false}
	board_node._on_piece_moved(1, 0, 1, 2, 3, 1, 2, false)
	var mc_selected: bool = (
		board_node.selected != null
		and int(board_node.selected.get("row", -1)) == 2
		and int(board_node.selected.get("col", -1)) == 3
		and board_node.multi_capture_cell != null
		and int(board_node.multi_capture_cell.get("row", -1)) == 2
		and int(board_node.multi_capture_cell.get("col", -1)) == 3
	)
	results.append(["multicaptura selecciona y resalta con borde dorado la casilla de aterrizaje (2,3)", mc_selected])

	# Verificar estado de tablas (winner == 0) en CheckersBoard
	board_node._on_game_over(0)
	results.append(["fin de partida por tablas actualiza winner == 0 y limpia multi_capture_cell", board_node.winner == 0 and board_node.multi_capture_cell == null])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	root.remove_child(board_node)
	board_node.free()
	bridge.free()
	quit(0 if ok else 1)
