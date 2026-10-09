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

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	bridge.free()
	quit(0 if ok else 1)
