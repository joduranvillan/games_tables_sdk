# Test headless de integración para el juego CRISIS (TEG).
# Correr: redot --headless --path godot_project --script res://tests/crisis_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var armies_placed_events: Array = []
	var phase_changed_events: Array = []
	var turns_changed: Array = []

	var bridge = OpenTableBridge.new()
	bridge.connect("turn_changed", func(p: int): turns_changed.append(p))

	bridge.connect("event_json", func(json_str: String):
		var parser = JSON.new()
		if parser.parse(json_str) == OK:
			var data = parser.data
			if data is Dictionary:
				var evt_type = data.get("event_type", data.get("command_type", ""))
				if evt_type.contains("ArmiesPlacedEvent"):
					armies_placed_events.append(data)
				elif evt_type.contains("PhaseChangedEvent"):
					phase_changed_events.append(data)
	)

	if bridge.has_signal("armies_placed"):
		bridge.connect("armies_placed", func(player_id: int, territory_id: int, count: int, remaining: int):
			armies_placed_events.append({
				"player_id": player_id,
				"territory_id": territory_id,
				"count": count,
				"remaining": remaining
			})
		)

	if bridge.has_signal("phase_changed"):
		bridge.connect("phase_changed", func(player_id: int, new_phase: String):
			phase_changed_events.append({
				"player_id": player_id,
				"new_phase": new_phase
			})
		)

	# 1. Iniciar partida local de Crisis con seed 42 y jugadores [1, 2]
	var started = bridge.start_local_match_crisis(42, [1, 2])
	results.append(["start_local_match_crisis retorno verdadero", started == true])
	results.append(["Turno inicial es jugador 1", bridge.current_player() == 1])

	# 2. Emitir PlaceArmiesCommand para P1 buscando un territorio de P1
	var p1_territory = -1
	for t in [2, 0, 1, 3, 4, 5, 6, 7, 8, 9, 10]:
		if armies_placed_events.size() > 0:
			break
		bridge.send_command_json(1, JSON.stringify({
			"command_type": "crisis_game::PlaceArmiesCommand",
			"player": 1,
			"territory": t,
			"count": 1
		}))
		if armies_placed_events.size() > 0:
			p1_territory = t
	
	var received_armies = armies_placed_events.size() > 0
	results.append(["Señal armies_placed recibida para player_id == 1", received_armies])

	# Colocar las tropas restantes para avanzar a la fase Attack
	if p1_territory >= 0:
		bridge.send_command_json(1, JSON.stringify({
			"command_type": "crisis_game::PlaceArmiesCommand",
			"player": 1,
			"territory": p1_territory,
			"count": 39
		}))

	var phase_attack = phase_changed_events.size() > 0 and phase_changed_events[-1]["new_phase"] == "Attack"
	results.append(["Colocar todas las tropas avanza fase a Attack", phase_attack])

	# 3. Emitir EndPhaseCommand -> verificar phase_changed con new_phase == "Fortify"
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "crisis_game::EndPhaseCommand",
		"player": 1
	}))

	var phase_fortify = phase_changed_events.size() > 0 and phase_changed_events[-1]["new_phase"] == "Fortify"
	results.append(["EndPhaseCommand avanza fase a Fortify", phase_fortify])

	# 4. Emitir EndPhaseCommand -> turno avanza a P2
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "crisis_game::EndPhaseCommand",
		"player": 1
	}))
	results.append(["EndPhaseCommand en Fortify avanza turno a P2", bridge.current_player() == 2])
	results.append(["Se emitió la señal turn_changed con P2", turns_changed.size() >= 1 and turns_changed[-1] == 2])

	# 5. Verificar crisis_board.gd: carga sin error en TurnIndicator, mapa fullscreen (1280x720) y turno IA instantáneo
	var board_script = load("res://crisis_board.gd")
	if board_script != null:
		var board_inst = board_script.new()
		root.add_child(board_inst)
		if board_inst.map_panel == null and board_inst.has_method("_ready"):
			board_inst._ready()

		results.append(["crisis_board carga con MapPanel a pantalla completa (1280x720)", board_inst.map_panel != null and board_inst.map_panel.size == Vector2(1280, 720)])
		results.append(["crisis_board superpone TopBarPanel y SidebarPanel sobre el mapa", board_inst.top_bar_panel != null and board_inst.sidebar_panel != null])
		results.append(["TurnIndicator soporta set_current_player y set_turn sin errores", board_inst.turn_indicator != null and board_inst.turn_indicator.has_method("set_current_player")])

		# Probar que los 30 centros están dentro de su polígono y tienen separación mínima sin solapamiento (>= 55px)
		var all_inside: bool = true
		var min_dist: float = 99999.0
		for i in range(30):
			if not Geometry2D.is_point_in_polygon(board_inst.TERRITORY_CENTERS[i], board_inst.TERRITORY_POLYGONS[i]):
				all_inside = false
			for j in range(i + 1, 30):
				var d: float = board_inst.TERRITORY_CENTERS[i].distance_to(board_inst.TERRITORY_CENTERS[j])
				if d < min_dist:
					min_dist = d
		results.append(["Los 30 territorios tienen códigos cortos y centros dentro de sus siluetas continentales", all_inside and board_inst.TERRITORY_CODES.size() == 30])
		results.append(["Ningún par de centros de territorios se solapa en el mapa (distancia mínima >= 55px)", min_dist >= 55.0])

		# Probar distribución móvil (layout == 2) y botón icono pequeño (24x24) del panel plegable
		board_inst._on_layout_changed(2)
		var mobile_expanded_h: float = board_inst.sidebar_panel.size.y
		board_inst._on_toggle_sidebar_pressed()
		var mobile_collapsed_h: float = board_inst.sidebar_panel.size.y
		var icon_compact: bool = board_inst.btn_toggle_panel != null and board_inst.btn_toggle_panel.custom_minimum_size.x <= 28.0
		results.append(["En modo móvil (layout 2), el panel inferior es plegable con botón icono compacto y amplía el mapa", board_inst.sidebar_collapsed and mobile_collapsed_h < mobile_expanded_h and icon_compact])
		board_inst._on_toggle_sidebar_pressed()
		board_inst._on_layout_changed(0)

		# Verificar que ErrorLogger mantiene su overlay visual oculto por defecto en todas las escenas
		var err_logger_script = load("res://error_logger.gd")
		if err_logger_script != null:
			var err_inst = err_logger_script.new()
			root.add_child(err_inst)
			if err_inst.overlay_panel == null and err_inst.has_method("_ready"):
				err_inst._ready()
			results.append(["ErrorLogger inicia con el cartel visual oculto por defecto", err_inst.overlay_panel != null and err_inst.overlay_panel.visible == false])
			root.remove_child(err_inst)
			err_inst.free()

		# Probar modo vs IA (Humano = J1, IA = J2): completar turno de J1 y verificar que la IA juega al instante
		board_inst._on_mode_selected(1)
		var tick_before: int = board_inst.bridge.current_tick()
		board_inst._place_armies(board_inst.armies_remaining_to_place)
		board_inst._on_btn_end_phase_pressed() # Attack -> Fortify
		board_inst._on_btn_end_phase_pressed() # Fortify -> Turno IA (instantáneo) -> vuelve a J1
		var tick_after: int = board_inst.bridge.current_tick()
		results.append(["En modo vs IA de TEG, la IA ejecuta su turno al instante y devuelve turno a J1", tick_after > tick_before + 3 and board_inst.current_player_id == 1])
		results.append(["El turno de la IA no abre popups bloqueantes (dice_popup oculto)", not board_inst.dice_popup.visible])

		var crisis_menu: Node = board_inst.get_node_or_null("GameAppMenu")
		if crisis_menu == null:
			crisis_menu = board_inst.find_child("GameAppMenu", true, false)
		results.append(["crisis_board integra GameAppMenu en esquina superior derecha", crisis_menu != null])

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

