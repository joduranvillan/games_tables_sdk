# Test headless de integración para el Manager de Logros (AchievementManager).
# Correr: redot --headless --path godot_project --script res://tests/achievements_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []

	# 1. Instanciar o acceder al script del AchievementManager
	var manager_script = load("res://achievement_manager.gd")
	results.append(["achievement_manager.gd se carga correctamente", manager_script != null])

	var manager = manager_script.new()
	root.add_child(manager)

	# 2. Estado inicial: "primera_victoria" debe estar bloqueado
	results.append(["Logro 'primera_victoria' inicialmente no está desbloqueado", not manager.is_unlocked("primera_victoria")])

	# 3. Desbloquear logro manualmente
	var unlocked_ok = manager.unlock("primera_victoria")
	results.append(["manager.unlock('primera_victoria') retorna true al desbloquear", unlocked_ok])
	results.append(["manager.is_unlocked('primera_victoria') es ahora true", manager.is_unlocked("primera_victoria")])

	# 4. Verificar persisencia en user://achievements.json
	var save_path = "user://achievements.json"
	var file_exists = FileAccess.file_exists(save_path)
	results.append(["Archivo user://achievements.json se generó correctamente", file_exists])

	var json_contains_achievement = false
	if file_exists:
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var parser = JSON.new()
			if parser.parse(content) == OK:
				var data = parser.data
				if data is Dictionary and data.has("primera_victoria"):
					json_contains_achievement = data["primera_victoria"].get("unlocked", false) == true

	results.append(["JSON contiene 'primera_victoria' con unlocked = true", json_contains_achievement])

	var ok := true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false

	print("=== RESULTADO: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))
	manager.queue_free()
	quit(0 if ok else 1)
