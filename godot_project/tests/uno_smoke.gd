# Test headless de integración para el juego UNO.
# Correr: redot --headless --path godot_project --script res://tests/uno_smoke.gd
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
				if evt_type.contains("CardsDrawnEvent") or evt_type.contains("CardPlayedEvent") or evt_type.contains("DrewAndPlayedEvent"):
					events_received.append(data)
	)

	bridge.connect("move_rejected", func(reason: String):
		move_rejected_reasons.append(reason)
	)

	# 1. Iniciar partida local de UNO
	bridge.start_local_match_uno(1, 2)
	results.append(["start_local_match_uno arranca con turno del jugador 1", bridge.current_player() == 1])

	# 2. Movimiento 1 (P1): Robar carta
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "DrawCardCommand",
		"player": 1
	}))
	results.append(["P1 roba carta -> evento de cartas robadas recibido", events_received.size() >= 1])
	results.append(["Se emitió la señal turn_changed al cambiar de turno", turns_changed.size() >= 1])

	# 3. Movimiento 2: Robar carta con el jugador en turno
	var curr_p = bridge.current_player()
	bridge.send_command_json(curr_p, JSON.stringify({
		"command_type": "DrawCardCommand",
		"player": curr_p
	}))
	results.append(["Segundo movimiento ejecutado con exito", events_received.size() >= 2])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
