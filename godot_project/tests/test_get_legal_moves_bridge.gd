# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# Test test_get_legal_moves_bridge.gd en Godot.
#
# Correr: redot --headless --path godot_project --script res://tests/test_get_legal_moves_bridge.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []

	var bridge = OpenTableBridge.new()
	bridge.start_local_match_checkers(1, 2)

	var p1_moves = bridge.get_legal_moves(1)
	results.append(["get_legal_moves(1) en Checkers retorna un Array", p1_moves is Array])
	results.append(["get_legal_moves(1) en Checkers tiene 7 jugadas en posicion inicial", p1_moves.size() == 7])

	bridge.start_local_match_chess(1, 2)
	var chess_p1_moves = bridge.get_legal_moves(1)
	results.append(["get_legal_moves(1) en Chess retorna un Array", chess_p1_moves is Array])
	results.append(["get_legal_moves(1) en Chess tiene 20 jugadas en posicion inicial", chess_p1_moves.size() == 20])
	bridge.free()

	var ok: bool = true
	for r in results:
		var status = "PASS" if r[1] else "FAIL"
		print("%s  %s" % [status, r[0]])
		if not r[1]:
			ok = false

	if ok:
		print("RESULTADO: TODOS LOS TESTS PASARON EXITOSAMENTE")
		quit(0)
	else:
		print("HAY FALLOS EN TEST GET LEGAL MOVES BRIDGE")
		quit(1)
