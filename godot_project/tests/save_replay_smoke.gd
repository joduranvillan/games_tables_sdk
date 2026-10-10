# Test headless de humo para Guardado (SaveManager) y Replay (ReplayViewer).
# Inicia una partida de damas, ejecuta 3 jugadas, guarda a disco en user://saves/,
# limpia el estado, carga el archivo guardado y verifica que el turno y las
# posiciones del tablero coinciden exactamente.
#
# Correr: redot --headless --path godot_project -s tests/save_replay_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []

	# 1. Iniciar partida de damas y ejecutar 3 jugadas válidas
	var bridge = OpenTableBridge.new()
	bridge.start_local_match(1, 2)

	# Jugada 1 (Jugador 1): (2,1) -> (3,2)
	bridge.send_move(1, 2, 1, 3, 2)
	# Jugada 2 (Jugador 2): (5,0) -> (4,1)
	bridge.send_move(2, 5, 0, 4, 1)
	# Jugada 3 (Jugador 1): captura obligatoria (3,2) -> (5,0)
	bridge.send_move(1, 3, 2, 5, 0)

	var expected_turn: int = bridge.current_player()
	var expected_legal_moves: String = bridge.get_legal_moves_json(expected_turn) if bridge.has_method("get_legal_moves_json") else JSON.stringify(bridge.get_legal_moves(expected_turn))
	results.append([
		"tras 3 jugadas en damas el turno activo es del jugador 2",
		expected_turn == 2
	])

	# 2. Guardar partida a disco mediante SaveManager
	var save_mgr = load("res://scripts/save_manager.gd").new()
	save_mgr._ready()

	var players_meta := [
		{"id": 1, "name": "Jugador 1", "score": 0},
		{"id": 2, "name": "Jugador 2", "score": 0},
	]
	save_mgr.set_context(bridge, "checkers", 3, players_meta)

	var save_id: String = save_mgr.save_game("Damas 3 Jugadas")
	var save_file_path: String = "user://saves/" + save_id + ".json"

	results.append([
		"save_game genera UUID válido (%s) y guarda en disco" % save_id,
		save_id.length() == 36 and FileAccess.file_exists(save_file_path)
	])

	# 3. Verificar que list_saves() lista la partida guardada correctamente
	var saves: Array = save_mgr.list_saves()
	var listed_entry: Dictionary = {}
	for entry in saves:
		if str(entry.get("save_id", "")) == save_id:
			listed_entry = entry
			break

	results.append([
		"list_saves incluye la partida con game_id='checkers' y turn_number=3",
		not listed_entry.is_empty()
		and str(listed_entry.get("game_id", "")) == "checkers"
		and int(listed_entry.get("turn_number", 0)) == 3
	])

	# 4. Limpiar el estado original
	bridge.free()
	bridge = null

	# 5. Cargar el archivo guardado en una instancia limpia y verificar turno y posiciones
	var restored_bridge = OpenTableBridge.new()
	var restored_moves: Array = []
	restored_bridge.connect("piece_moved", func(p, fr, fc, tr, tc, _cr, _cc, _prom):
		restored_moves.append({
			"player": p,
			"from": Vector2i(fr, fc),
			"to": Vector2i(tr, tc),
		})
	)

	var loaded_data: Dictionary = save_mgr.load_game(save_id, restored_bridge)
	results.append([
		"load_game recupera metadatos y engine_state desde disco",
		not loaded_data.is_empty() and not str(loaded_data.get("engine_state", "")).is_empty()
	])

	var restored_turn: int = restored_bridge.current_player()
	var restored_legal_moves: String = restored_bridge.get_legal_moves_json(restored_turn) if restored_bridge.has_method("get_legal_moves_json") else JSON.stringify(restored_bridge.get_legal_moves(restored_turn))

	results.append([
		"el turno restaurado coincide exactamente con el turno previo al guardado (%d)" % restored_turn,
		restored_turn == expected_turn
	])

	var positions_match: bool = (
		restored_moves.size() == 3
		and restored_moves[0]["from"] == Vector2i(2, 1) and restored_moves[0]["to"] == Vector2i(3, 2)
		and restored_moves[1]["from"] == Vector2i(5, 0) and restored_moves[1]["to"] == Vector2i(4, 1)
		and restored_moves[2]["from"] == Vector2i(3, 2) and restored_moves[2]["to"] == Vector2i(5, 0)
		and restored_legal_moves == expected_legal_moves
	)
	results.append([
		"las posiciones del tablero y movimientos legales tras cargar coinciden exactamente",
		positions_match
	])

	# 6. Verificar compatibilidad del snapshot con ReplayViewer
	var raw_log: PackedByteArray = Marshalls.base64_to_raw(str(loaded_data.get("engine_state", "")))
	var viewer = load("res://replay_viewer.gd").new()
	root.add_child(viewer)
	viewer.load_replay_data(raw_log, "checkers")
	viewer.seek_to_step(3)
	results.append([
		"ReplayViewer carga los 3 pasos y navega al paso 3 correctamente",
		viewer.total_steps == 3 and viewer.current_step == 3
	])
	viewer.free()

	# 7. Exportar e importar Replay (.otr comprimido con gzip, version "1")
	save_mgr.set_context(restored_bridge, "checkers", 3, players_meta)
	var otr_path := "user://saves/test_share.otr"
	var exported_otr: bool = save_mgr.export_replay_file(otr_path)
	results.append([
		"export_replay_file guarda archivo .otr comprimido con gzip en disco",
		exported_otr and FileAccess.file_exists(otr_path)
	])

	var imported_otr: bool = save_mgr.import_replay_file(otr_path)
	var otr_meta: Dictionary = save_mgr.last_imported_replay
	results.append([
		"import_replay_file descomprime y valida version=='1', game_id=='checkers' y moves",
		imported_otr
		and str(otr_meta.get("version", "")) == "1"
		and str(otr_meta.get("game_id", "")) == "checkers"
		and (otr_meta.get("player_names", []) as Array).size() == 2
		and (otr_meta.get("moves", []) as Array).size() == 3
	])

	var otr_viewer = load("res://replay_viewer.gd").new()
	root.add_child(otr_viewer)
	var viewer_imported: bool = otr_viewer.import_otr_replay(otr_path)
	results.append([
		"ReplayViewer importa .otr y muestra botón 'Importar Replay' con filtro *.otr",
		viewer_imported
		and otr_viewer.total_steps == 3
		and otr_viewer.btn_import_replay != null
		and otr_viewer.import_otr_dialog != null
	])
	otr_viewer.free()
	DirAccess.remove_absolute(otr_path)

	# 8. Limpiar archivo de prueba
	var deleted_ok: bool = save_mgr.delete_save(save_id)
	results.append([
		"delete_save elimina la partida guardada de disco",
		deleted_ok and not FileAccess.file_exists(save_file_path)
	])

	var ok := true
	for r in results:
		var passed: bool = r[1]
		print(("PASS  " if passed else "FAIL  ") + r[0])
		if not passed:
			ok = false

	print("=== RESULTADO SAVE & REPLAY SMOKE: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))

	save_mgr.free()
	restored_bridge.free()
	quit(0 if ok else 1)
