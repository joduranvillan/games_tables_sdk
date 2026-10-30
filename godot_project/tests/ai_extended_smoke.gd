# Test de humo headless para los 6 nuevos motores IA en el bridge (Prompt 461):
# Battleship, Mille Bornes, UNO, Monopoly, Chinese Checkers y Crisis/TEG.
# Ejecutar: redot --headless --path godot_project -s tests/ai_extended_smoke.gd
extends SceneTree

func _initialize() -> void:
	var methods: Array[String] = [
		"start_local_match_battleship_vs_ai",
		"start_local_match_mille_bornes_vs_ai",
		"start_local_match_uno_vs_ai",
		"start_local_match_monopoly_vs_ai",
		"start_local_match_chinese_checkers_vs_ai",
		"start_local_match_crisis_vs_ai",
	]

	for method_name in methods:
		var bridge = OpenTableBridge.new()
		if not bridge.has_method(method_name):
			printerr("FAIL: OpenTableBridge no expone el método %s" % method_name)
			bridge.free()
			quit(1)
			return

		# Modo Easy = 0 (human: 1, ai: 2, difficulty: 0)
		var ok: bool = bool(bridge.call(method_name, 1, 2, 0))
		if not ok:
			printerr("FAIL: %s(1, 2, 0) retornó false" % method_name)
			bridge.free()
			quit(1)
			return

		for _frame in range(10):
			if bridge.has_method("_process"):
				bridge._process(0.016)

		bridge.free()

	print("PASS: AI extended OK")
	quit(0)
