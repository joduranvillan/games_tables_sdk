# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

func _init() -> void:
	print("=== INICIANDO GOOSE GAME (JUEGO DE LA OCA) SMOKE TEST ===")
	var bridge: Node = OpenTableBridge.new()
	root.add_child(bridge)

	bridge.start_local_match_goose(1, 2)
	var curr: int = bridge.current_player()
	if curr != 1:
		print("HAY FALLOS: jugador inicial esperado 1, obtenido ", curr)
		quit(1)
		return

	var roll_cmd: Dictionary = {"command_type": "RollDiceCommand", "player": 1}
	bridge.send_command_json(1, JSON.stringify(roll_cmd))

	var move_cmd: Dictionary = {"command_type": "MoveTokenCommand", "player": 1}
	bridge.send_command_json(1, JSON.stringify(move_cmd))

	var rules_data: Dictionary = RulesCatalog.get_game_rules("goose", "es")
	var secs: Array = rules_data.get("sections", [])
	if secs.size() < 5:
		print("HAY FALLOS: RulesCatalog para goose debe tener 5 secciones")
		quit(1)
		return

	print("PASS: goose_smoke.gd completado correctamente")
	quit(0)
