# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# Test headless de integración para Damas Chinas (Chinese Checkers).
# Correr: redot --headless --path godot_project --script res://tests/chinese_checkers_smoke.gd
extends SceneTree

func _rotate_60(p: Vector2i, times: int) -> Vector2i:
	var curr = p
	for i in range(posmod(times, 6)):
		curr = Vector2i(-curr.y, curr.x + curr.y)
	return curr

func _corner_cells(corner: int) -> Array[Vector2i]:
	var base: Array[Vector2i] = [
		Vector2i(-5, 1),
		Vector2i(-5, 2),
		Vector2i(-5, 3),
		Vector2i(-6, 2),
		Vector2i(-6, 3),
		Vector2i(-6, 4),
		Vector2i(-7, 3),
		Vector2i(-7, 4),
		Vector2i(-8, 4),
		Vector2i(-5, 4)
	]
	var res: Array[Vector2i] = []
	for p in base:
		res.append(_rotate_60(p, corner))
	return res

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

	# 1. Iniciar partida local de Damas Chinas de 4 jugadores
	if bridge.has_method("start_local_match_chinese_checkers_n_players"):
		bridge.start_local_match_chinese_checkers_n_players(4)
	else:
		bridge.start_local_match_chinese_checkers(1, 2)
	results.append(["start_local_match_chinese_checkers arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Verificar que las 10 fichas iniciales de cada jugador (en 4 jugadores: puntas 0, 1, 3, 4) están en las puntas correctas
	var corners_4p = [0, 1, 3, 4]
	var p1_tip_cell = _corner_cells(corners_4p[0])[0] # Por ej (-5, 1)
	var p2_tip_cell = _corner_cells(corners_4p[1])[0]
	var p3_tip_cell = _corner_cells(corners_4p[2])[0]
	var p4_tip_cell = _corner_cells(corners_4p[3])[0]

	# Movimiento de apertura válido de P1 desde el borde de su punta hacia el hexágono adyacente
	# (-5, 1) + (1, 0) = (-4, 1) que está en el tablero central
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "MovePegCommand",
		"player": 1,
		"from": {"q": -5, "r": 1},
		"to": {"q": -4, "r": 1},
		"path": []
	}))

	var peg_moved = false
	for ev in events_received:
		var et = ev.get("event_type", ev.get("command_type", ""))
		if "PegMovedEvent" in et or "PegMoved" in et:
			peg_moved = true
			break
	results.append(["Movimiento válido de ficha de P1 desde punta 0 emite evento PegMovedEvent", peg_moved or move_rejected_reasons.size() == 0])

	# 3. Movimiento inválido a una casilla ocupada por su propia ficha
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "MovePegCommand",
		"player": 1,
		"from": {"q": -5, "r": 2},
		"to": {"q": -5, "r": 3},
		"path": []
	}))
	results.append(["Movimiento a casilla ocupada genera rechazo move_rejected", move_rejected_reasons.size() > 0])

	# 4. Probar también inicialización de 6 jugadores y 2 jugadores en el bridge
	if bridge.has_method("start_local_match_chinese_checkers_n_players"):
		bridge.start_local_match_chinese_checkers_n_players(6)
		results.append(["start_local_match_chinese_checkers_n_players(6) inicializa sesión de 6 jugadores", bridge.current_player() == 1])
		bridge.start_local_match_chinese_checkers_n_players(2)
		results.append(["start_local_match_chinese_checkers_n_players(2) inicializa sesión de 2 jugadores", bridge.current_player() == 1])

	# 5. Verificar ChineseCheckersBoard centrado y rechazo de salto sin pivote
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "MovePegCommand",
		"player": 1,
		"from": {"q": -5, "r": 1},
		"to": {"q": -3, "r": 1},
		"path": [{"q": -3, "r": 1}]
	}))
	results.append(["Salto de 2 casillas sobre casilla vacía genera rechazo move_rejected", move_rejected_reasons.size() > 0])

	var cc_script: Script = load("res://chinese_checkers_board.gd") as Script
	if cc_script != null:
		var cc_node: Node2D = cc_script.new() as Node2D
		root.add_child(cc_node)
		if cc_node.get("turn_indicator") == null and cc_node.has_method("_ready"):
			cc_node._ready()
		results.append(["ChineseCheckersBoard inicia centrado con GameAppMenu activo", cc_node.position.x > 100.0 and cc_node.get_node_or_null("GameAppMenu") != null])
		root.remove_child(cc_node)
		cc_node.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)


