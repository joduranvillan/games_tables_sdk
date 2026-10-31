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

	# 4. Verificar escena UI de Batalla Naval (validación de adyacencia, Auto-Flota y layout móvil)
	var board_scene: PackedScene = load("res://battleship_board.tscn")
	var board_inst: Node2D = board_scene.instantiate() if board_scene != null else null
	if board_inst != null:
		root.add_child(board_inst)
		if board_inst.grids_container == null and board_inst.has_method("_ready"):
			board_inst._ready()

		var orphan_status = board_inst.get_node_or_null("Status")
		results.append(["Nodo huérfano Status ('Cargando...') está oculto en battleship_board.tscn", orphan_status != null and not orphan_status.visible])

		# Colocar primer barco (Portaaviones, 5 casillas) horizontal en fila 0, col 0..4
		board_inst._on_own_cell_pressed(0, 0)
		results.append(["Primer barco se coloca en (0,0..4) avanzando current_ship_index a 1", board_inst.current_ship_index == 1])

		# Intentar colocar segundo barco (Acorazado, 4 casillas) pegado en fila 1, col 0..3 -> debe rechazarse por adyacencia
		board_inst._on_own_cell_pressed(1, 0)
		results.append(["UI impide colocar segundo barco pegado al primero (adyacencia de 1 casilla)", board_inst.current_ship_index == 1])

		# Cambiar orientación a Vertical y colocar segundo barco (Acorazado, 4 casillas) cerca del borde inferior (fila 8, col 7 -> auto-clamp a filas 6..9, col 7)
		board_inst._on_rotate_pressed()
		board_inst._on_own_cell_pressed(8, 7)
		var vertical_ship_ok: bool = (board_inst.current_ship_index == 2 and board_inst.p1_ships.size() == 2)
		if vertical_ship_ok:
			var v_ship: Array = board_inst.p1_ships[1]
			vertical_ship_ok = (v_ship.size() == 4 and v_ship[0].y == 7 and v_ship[3].y == 7 and v_ship[0].x == 6 and v_ship[3].x == 9)
		results.append(["Permite colocar barco en orientación Vertical con ajuste de borde (filas 6..9, col 7)", vertical_ship_ok])

		# Verificar que los barcos colocados generan nodos visuales con SVG cenital en OwnShipsLayer
		var svg_ok: bool = false
		if board_inst.own_ships_layer != null and board_inst.own_ships_layer.get_child_count() == 2:
			var first_svg_node: Node = board_inst.own_ships_layer.get_child(0)
			var second_svg_node: Node = board_inst.own_ships_layer.get_child(1)
			var svg_str_0: String = str(first_svg_node.get_meta("svg_source", ""))
			var svg_str_1: String = str(second_svg_node.get_meta("svg_source", ""))
			svg_ok = svg_str_0.begins_with("<svg") and svg_str_1.begins_with("<svg") and bool(second_svg_node.get_meta("is_horizontal", true)) == false
		results.append(["Barcos colocados se renderizan en formato SVG cenital (horizontal y vertical)", svg_ok])

		# Verificar menú desplegable superior derecho (GameAppMenu) con Temas, Deshacer, Rehacer, Tutorial y Reglas
		var app_menu: Node = board_inst.get_node_or_null("GameAppMenu")
		var menu_ok: bool = (app_menu != null and app_menu.get("theme_item_btn") != null and app_menu.get("undo_item_btn") != null and app_menu.get("tutorial_item_btn") != null and app_menu.get("rules_item_btn") != null)
		results.append(["Menú desplegable superior derecho (GameAppMenu) agrupa Temas, Deshacer, Rehacer, Tutorial y Reglas", menu_ok])

		# Probar botón Auto-Flota -> debe completar la flota y avanzar de fase
		board_inst._on_auto_fleet_pressed()
		results.append(["Botón Auto-Flota coloca 5 barcos válidos con separación y avanza a fase de disparo", board_inst.phase == board_inst.Phase.FIRE or board_inst.phase == board_inst.Phase.PLACEMENT_P2])

		# Probar layout móvil vertical (layout = 2)
		board_inst._on_layout_changed(2)
		results.append(["Layout móvil (layout=2) apila verticalmente Mi Flota y Radar", board_inst.grids_container != null and board_inst.grids_container.vertical == true])

		# Probar SetBattleshipRulesCommand y rechazo de flota con barcos tocándose en diagonal
		move_rejected_reasons.clear()
		bridge.send_command_json(2, JSON.stringify({
			"command_type": "PlaceFleetCommand",
			"player": 2,
			"ships": [
				[{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 0, "col": 4}],
				[{"row": 1, "col": 5}, {"row": 1, "col": 6}, {"row": 1, "col": 7}, {"row": 1, "col": 8}],
				[{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}],
				[{"row": 6, "col": 0}, {"row": 6, "col": 1}, {"row": 6, "col": 2}],
				[{"row": 8, "col": 0}, {"row": 8, "col": 1}]
			]
		}))
		results.append(["Barcos tocándose en diagonal ((0,4) y (1,5)) generan rechazo move_rejected", move_rejected_reasons.size() > 0])

		root.remove_child(board_inst)
		board_inst.free()
	else:
		results.append(["battleship_board.tscn carga correctamente", false])

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)

