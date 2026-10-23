# Test de humo headless para TODOS los motores IA (Prompt 515).
# Verifica que los bots de Monopoly, UNO, Mille Bornes, Backgammon, Go, Chess,
# Checkers, Ludo, Battleship, Chinese Checkers, Crisis/TEG, Shogi y Xiangqi
# funcionen sin generar errores ni bloqueos.
# Ejecutar: redot --headless --path godot_project -s tests/ai_all_games_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var bridge := OpenTableBridge.new()

	# 1. Backgammon vs IA
	var bg_started = bridge.start_local_match_backgammon_vs_ai(1, 2)
	results.append(["Backgammon vs IA: inició correctamente", bg_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 2. Monopoly vs IA
	bridge = OpenTableBridge.new()
	var mono_started = bridge.start_local_match_monopoly_vs_ai(1, 2, 1)
	results.append(["Monopoly vs IA: inició correctamente", mono_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 3. UNO vs IA
	bridge = OpenTableBridge.new()
	var uno_started = bridge.start_local_match_uno_vs_ai(1, 2, 1)
	results.append(["UNO vs IA: inició correctamente", uno_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 4. Mille Bornes vs IA
	bridge = OpenTableBridge.new()
	var mb_started = bridge.start_local_match_mille_bornes_vs_ai(1, 2, 1)
	results.append(["Mille Bornes vs IA: inició correctamente", mb_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 5. Go vs IA
	bridge = OpenTableBridge.new()
	var go_started = bridge.start_local_match_go_vs_ai(1, 2, 9)
	results.append(["Go vs IA: inició correctamente", go_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 6. Crisis / TEG vs IA
	bridge = OpenTableBridge.new()
	var crisis_started = bridge.start_local_match_crisis_vs_ai(1, 2, 1)
	results.append(["Crisis / TEG vs IA: inició correctamente", crisis_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 7. Chinese Checkers vs IA
	bridge = OpenTableBridge.new()
	var cc_started = bridge.start_local_match_chinese_checkers_vs_ai(1, 2, 1)
	results.append(["Chinese Checkers vs IA: inició correctamente", cc_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 8. Battleship vs IA
	bridge = OpenTableBridge.new()
	var bs_started = bridge.start_local_match_battleship_vs_ai(1, 2, 1)
	results.append(["Battleship vs IA: inició correctamente", bs_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 9. Chess vs IA
	bridge = OpenTableBridge.new()
	var chess_started = bridge.start_local_match_chess_vs_ai(1, 2, 1)
	results.append(["Chess vs IA: inició correctamente", chess_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 10. Checkers vs IA
	bridge = OpenTableBridge.new()
	var checkers_started = bridge.start_local_match_checkers_vs_ai(42, 1, 2)
	results.append(["Checkers vs IA: inició correctamente", checkers_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 11. Ludo vs IA
	bridge = OpenTableBridge.new()
	var ludo_started = bridge.start_local_match_ludo_vs_ai(1, 2)
	results.append(["Ludo vs IA: inició correctamente", ludo_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 12. Shogi vs IA
	bridge = OpenTableBridge.new()
	var shogi_started = bridge.start_local_match_shogi_vs_ai(1, 2, 1)
	results.append(["Shogi vs IA: inició correctamente", shogi_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	# 13. Xiangqi vs IA
	bridge = OpenTableBridge.new()
	var xiangqi_started = bridge.start_local_match_xiangqi_vs_ai(1, 2)
	results.append(["Xiangqi vs IA: inició correctamente", xiangqi_started])
	for _f in range(15):
		if bridge.has_method("_process"):
			bridge._process(0.016)
	bridge.free()

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false
	print("=== RESULTADO: %s ===" % ("TODOS LOS MOTORES IA FUNCIONAN" if ok else "HAY FALLOS"))
	quit(0 if ok else 1)
