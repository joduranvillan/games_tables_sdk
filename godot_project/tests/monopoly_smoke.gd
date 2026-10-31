# Test headless de integración para Monopoly.
# Correr: redot --headless --path godot_project --script res://tests/monopoly_smoke.gd
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

	# 1. Iniciar partida local de Monopoly
	bridge.start_local_match_monopoly(1, 2)
	results.append(["start_local_match_monopoly arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Enviar RollAndMoveCommand para P1
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "RollAndMoveCommand",
		"player": 1
	}))

	var player_moved_event: Dictionary = {}
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "PlayerMovedEvent" in et:
			player_moved_event = ev
			break

	var valid_roll = false
	if player_moved_event.size() > 0:
		var roll_val = int(player_moved_event.get("roll", 0))
		valid_roll = roll_val >= 2 and roll_val <= 12

	results.append(["RollAndMoveCommand emite PlayerMovedEvent con tiro entre 2 y 12", valid_roll])

	# 3. Comprobar que no hubo rechazo inesperado al tirar los dados
	results.append(["Tirada inicial procesada sin rechazo de movimiento", move_rejected_reasons.size() == 0])

	# 4. Probar ProposeTradeCommand y AcceptTradeCommand
	events_received.clear()
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "ProposeTradeCommand",
		"player": 1,
		"target": 2,
		"offered_spaces": [],
		"requested_spaces": [],
		"offered_cash": 100,
		"requested_cash": 50
	}))

	var has_trade_proposed = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "TradeProposedEvent" in et:
			has_trade_proposed = true
			break
	results.append(["ProposeTradeCommand emite TradeProposedEvent", has_trade_proposed])

	# 5. Aceptar intercambio
	events_received.clear()
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "AcceptTradeCommand",
		"player": 2
	}))

	var has_trade_accepted = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "TradeAcceptedEvent" in et:
			has_trade_accepted = true
			break
	results.append(["AcceptTradeCommand emite TradeAcceptedEvent", has_trade_accepted])

	# 6. Proponer y rechazar intercambio
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "ProposeTradeCommand",
		"player": 1,
		"target": 2,
		"offered_spaces": [],
		"requested_spaces": [],
		"offered_cash": 50,
		"requested_cash": 0
	}))

	events_received.clear()
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "RejectTradeCommand",
		"player": 2
	}))

	var has_trade_rejected = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "TradeRejectedEvent" in et:
			has_trade_rejected = true
			break
	results.append(["RejectTradeCommand emite TradeRejectedEvent", has_trade_rejected])

	# 7. Verificar que monopoly_board contiene los botones de gestión de propiedades
	var board_script = load("res://monopoly_board.gd")
	if board_script != null:
		var board_inst = board_script.new()
		root.add_child(board_inst)
		if board_inst.find_child("BuildHouseButton", true, false) == null and board_inst.has_method("_ready"):
			board_inst._ready()

		var has_build_btn = board_inst.find_child("BuildHouseButton", true, false) != null
		var has_mortgage_btn = board_inst.find_child("MortgageButton", true, false) != null
		var has_trade_btn = board_inst.find_child("TradeButton", true, false) != null
		results.append(["monopoly_board contiene botón 🏠 Construir Casa/Hotel", has_build_btn])
		results.append(["monopoly_board contiene botón 🏦 Hipotecar/Deshipotecar", has_mortgage_btn])
		results.append(["monopoly_board contiene botón 🤝 Proponer Intercambio", has_trade_btn])

		# 8. Verificar distribución visual limpia y compacta sin desborde en escritorio (layout 0) y móvil (layout 2)
		board_inst._on_layout_changed(0)
		var desktop_no_overlap = not board_inst.board_rect.intersects(Rect2(board_inst.control_dashboard.position, board_inst.control_dashboard.size))
		var desktop_compact_width = (board_inst.control_dashboard.position.x + board_inst.control_dashboard.size.x) <= 760.0
		var has_simple_turn = board_inst.find_child("SimpleTurnBanner", true, false) != null
		board_inst._on_layout_changed(2)
		var mobile_no_overlap = not board_inst.board_rect.intersects(Rect2(board_inst.control_dashboard.position, board_inst.control_dashboard.size))
		results.append(["monopoly_board separa el panel de controles del tablero y cabe sin desbordar la escena", desktop_no_overlap and desktop_compact_width and mobile_no_overlap and has_simple_turn])

		# 9. Verificar que tocar/seleccionar una casilla actualiza la tarjeta de detalle (SpaceInspectorPanel)
		board_inst.select_space(39)
		var inspector_updated = board_inst.inspector_title_lbl != null and "Paseo Tablado" in board_inst.inspector_title_lbl.text
		results.append(["monopoly_board muestra detalles de propiedad al seleccionar casilla", inspector_updated])

		# 10. Verificar rechazo de BuildHouseCommand sin poseer monopolio del grupo y presencia de GameAppMenu
		move_rejected_reasons.clear()
		bridge.send_command_json(1, JSON.stringify({
			"command_type": "BuildHouseCommand",
			"player": 1,
			"space": 1
		}))
		results.append(["BuildHouseCommand sin poseer el grupo de color completo genera rechazo move_rejected", move_rejected_reasons.size() > 0])
		var mono_menu: Node = board_inst.get_node_or_null("GameAppMenu")
		if mono_menu == null:
			mono_menu = board_inst.find_child("GameAppMenu", true, false)
		results.append(["monopoly_board integra GameAppMenu en esquina superior derecha", mono_menu != null])

		root.remove_child(board_inst)
		board_inst.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)

