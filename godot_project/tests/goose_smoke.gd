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

	# Verificar componente 3D de dados (DiceRoller3D + DiceWidget)
	var widget: DiceWidget = DiceWidget.new()
	root.add_child(widget)
	widget._ready()
	if widget.dock_roller_3d == null:
		print("HAY FALLOS: DiceWidget debe inicializar dock_roller_3d (DiceRoller3D)")
		quit(1)
		return

	for face_val in range(1, 7):
		widget.show_roll([face_val])
		var expected_rot: Vector3 = DiceRoller3D.get_target_rotation_for_value(face_val)
		var actual_rot: Vector3 = widget.dock_roller_3d.get_die_rotation_degrees(0)
		if not actual_rot.is_equal_approx(expected_rot):
			print("HAY FALLOS: rotación 3D incorrecta para cara ", face_val, " esperado=", expected_rot, " obtenido=", actual_rot)
			quit(1)
			return

	widget.show_roll([3, 6])
	if widget.last_values.size() != 2 or widget.last_values[0] != 3 or widget.last_values[1] != 6:
		print("HAY FALLOS: DiceWidget.show_roll([3, 6]) no registró los valores esperados")
		quit(1)
		return

	print("PASS: goose_smoke.gd + DiceRoller3D completado correctamente")
	quit(0)
