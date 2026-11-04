# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# Test headless de integración para el componente DiceRoller3D, DiceWidget y los 5 juegos de dados.
# Correr: redot --headless --path godot_project --script res://tests/dice_3d_smoke.gd
extends SceneTree

func _initialize() -> void:
	print("=== INICIANDO DICE 3D & DICE WIDGET SMOKE TEST ===")
	var results: Array = []

	# 1. Verificar DiceRoller3D standalone (escena 3D, texturas procedurales y rotaciones 1..6)
	var roller: DiceRoller3D = DiceRoller3D.new(Vector2i(240, 140))
	root.add_child(roller)
	results.append(["DiceRoller3D crea SubViewport con mundo 3D propio y fondo transparente", roller.sub_viewport != null and roller.sub_viewport.own_world_3d and roller.sub_viewport.transparent_bg])
	results.append(["DiceRoller3D genera 6 texturas de caras (1..6) y 3 dados 3D", roller.face_textures.size() == 6 and roller.dice_nodes.size() == 3])

	var all_faces_ok: bool = true
	for val in range(1, 7):
		roller.set_values_immediate([val])
		var expected_rot: Vector3 = DiceRoller3D.get_target_rotation_for_value(val)
		var actual_rot: Vector3 = roller.get_die_rotation_degrees(0)
		if not actual_rot.is_equal_approx(expected_rot):
			all_faces_ok = false
	results.append(["DiceRoller3D orienta con precisión las 6 caras (1..6) hacia la cámara superior", all_faces_ok])

	# Verificar múltiples dados simultáneos (1, 2 y 3 dados)
	roller.set_values_immediate([2, 5])
	var two_dice_ok: bool = roller.dice_nodes[0].visible and roller.dice_nodes[1].visible and (not roller.dice_nodes[2].visible)
	results.append(["DiceRoller3D posiciona y visibiliza 2 dados para Backgammon/Monopoly", two_dice_ok])

	roller.set_values_immediate([1, 4, 6])
	var three_dice_ok: bool = roller.dice_nodes[0].visible and roller.dice_nodes[1].visible and roller.dice_nodes[2].visible
	results.append(["DiceRoller3D posiciona y visibiliza 3 dados para Crisis (TEG)", three_dice_ok])

	# 2. Verificar DiceWidget (dock 3D + overlay central 3D + resumen de tirada)
	var widget: DiceWidget = DiceWidget.new()
	root.add_child(widget)
	widget._ready()
	results.append(["DiceWidget inicializa dock_roller_3d en el HUD", widget.dock_roller_3d != null])

	widget._ensure_center_overlay()
	results.append(["DiceWidget construye overlay central 3D (CanvasLayer + OverlayRoller3D)", widget._overlay_layer != null and widget._overlay_roller_3d != null])

	widget.show_roll([4, 6])
	var summary_text: String = widget._format_outcome_summary(widget.last_values)
	results.append(["DiceWidget registra tirada doble [4, 6] y formatea el total (10)", widget.last_values.size() == 2 and summary_text.contains("10")])

	# 3. Verificar integración de DiceWidget + DiceRoller3D en los 5 tableros de dados
	var board_paths: Array[String] = [
		"res://goose_board.gd",
		"res://ludo_board.gd",
		"res://backgammon_board.gd",
		"res://monopoly_board.gd",
		"res://crisis_board.gd"
	]

	for b_path in board_paths:
		var b_script: Script = load(b_path) as Script
		var board_ok: bool = false
		if b_script != null:
			var b_inst: Node = b_script.new()
			root.add_child(b_inst)
			var dw: Variant = b_inst.get("dice_widget")
			if dw == null and b_inst.has_method("_ready"):
				b_inst._ready()
				dw = b_inst.get("dice_widget")
			if dw != null and dw is DiceWidget:
				var dw_typed: DiceWidget = dw as DiceWidget
				if dw_typed.dock_roller_3d == null:
					dw_typed._ready()
				dw_typed.show_roll([5])
				board_ok = (dw_typed.dock_roller_3d != null and dw_typed.last_values.size() == 1 and dw_typed.last_values[0] == 5)
			root.remove_child(b_inst)
			b_inst.free()
		results.append(["Tablero %s integra DiceWidget con DiceRoller3D activo" % b_path.get_file(), board_ok])

	root.remove_child(widget)
	widget.free()
	root.remove_child(roller)
	roller.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + String(r[0]))
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	quit(0 if ok else 1)
