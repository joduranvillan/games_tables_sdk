# Test headless de integración para el tablero de Xiangqi.
# Correr: redot --headless --path godot_project --script res://tests/xiangqi_smoke.gd
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

	# 1. Iniciar partida local de Xiangqi
	bridge.start_local_match_xiangqi(1, 2)
	results.append(["start_local_match_xiangqi arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Movimiento P1: Soldado Rojo en (4,6) avanza a (4,5)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "xiangqi_game::MovePieceCommand",
		"player": 1,
		"from": [4, 6],
		"to": [4, 5]
	}))
	results.append(["P1 mueve soldado -> turno pasa a P2", bridge.current_player() == 2])
	results.append(["Se recibió evento PieceMovedEvent para P1", events_received.size() == 1])
	results.append(["Se emitió la señal turn_changed con P2", turns_changed.size() == 1 and turns_changed[0] == 2])

	# 3. Movimiento P2: Soldado Negro en (4,3) avanza a (4,4)
	bridge.send_command_json(2, JSON.stringify({
		"command_type": "xiangqi_game::MovePieceCommand",
		"player": 2,
		"from": [4, 3],
		"to": [4, 4]
	}))
	results.append(["P2 mueve soldado -> turno pasa a P1", bridge.current_player() == 1])
	results.append(["Se recibieron 2 eventos PieceMovedEvent", events_received.size() == 2])

	# 4. Verificar rechazo de Caballo con pata bloqueada (pata en [1,8] ocupada o fuera de movimiento legal)
	move_rejected_reasons.clear()
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "xiangqi_game::MovePieceCommand",
		"player": 1,
		"from": [1, 9],
		"to": [3, 8]
	}))
	results.append(["Caballo con pata bloqueada horizontalmente en [2,9] genera rechazo move_rejected", move_rejected_reasons.size() > 0])

	# 5. Verificar XiangqiBoard centrado y GameAppMenu activo
	var xq_script: Script = load("res://xiangqi_board.gd") as Script
	if xq_script != null:
		var xq_node: Node2D = xq_script.new() as Node2D
		root.add_child(xq_node)
		if xq_node.get("turn_indicator") == null and xq_node.has_method("_ready"):
			xq_node._ready()
		results.append(["XiangqiBoard inicia centrado horizontalmente con GameAppMenu", xq_node.position.x > 100.0 and xq_node.get_node_or_null("GameAppMenu") != null])
		root.remove_child(xq_node)
		xq_node.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)

