extends Node

signal game_saved(save_id: String, metadata: Dictionary)
signal game_loaded(save_id: String, metadata: Dictionary)
signal save_deleted(save_id: String)

const SAVES_DIR := "user://saves/"

var active_bridge: Node = null
var active_game_id: String = "chess"
var active_turn_number: int = 1
var active_players: Array = [
	{"id": 1, "name": "Jugador 1", "score": 0},
	{"id": 2, "name": "Jugador 2", "score": 0},
]

func _ready() -> void:
	_ensure_saves_dir()

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)

func set_context(
	p_bridge: Node,
	p_game_id: String = "chess",
	p_turn_number: int = 1,
	p_players: Array = []
) -> void:
	active_bridge = p_bridge
	if not p_game_id.strip_edges().is_empty():
		active_game_id = p_game_id
	if p_turn_number >= 0:
		active_turn_number = p_turn_number
	if not p_players.is_empty():
		active_players = p_players

func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hex := "0123456789abcdef"
	var out := ""
	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			out += "-"
		elif i == 14:
			out += "4"
		elif i == 19:
			out += hex.substr((rng.randi() & 0x3) | 0x8, 1)
		else:
			out += hex.substr(rng.randi() & 0xf, 1)
	return out

func _extract_engine_state_base64(target_bridge: Node) -> String:
	if target_bridge != null and is_instance_valid(target_bridge):
		var raw_bytes := PackedByteArray()
		if target_bridge.has_method("serialize_state"):
			raw_bytes = target_bridge.call("serialize_state")
		elif target_bridge.has_method("export_log"):
			raw_bytes = target_bridge.call("export_log")
		if raw_bytes.size() > 0:
			return Marshalls.raw_to_base64(raw_bytes)
	# Snapshot JSON vacío serializado en Base64 como fallback determinista
	return Marshalls.utf8_to_base64("[]")

func save_game(
	slot_name: String,
	p_bridge: Node = null,
	p_game_id: String = "",
	p_turn_number: int = -1,
	p_players: Array = []
) -> String:
	_ensure_saves_dir()

	var save_id := _generate_uuid()
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var target_bridge := p_bridge if p_bridge != null else active_bridge

	var resolved_game_id := p_game_id.strip_edges()
	if resolved_game_id.is_empty():
		if has_node("/root/GameManager"):
			var gm = get_node("/root/GameManager")
			if "active_game" in gm and not String(gm.active_game).is_empty():
				resolved_game_id = String(gm.active_game)
		if resolved_game_id.is_empty():
			resolved_game_id = active_game_id

	var resolved_turn := p_turn_number if p_turn_number >= 0 else active_turn_number
	var resolved_players := p_players if not p_players.is_empty() else active_players.duplicate(true)
	var engine_state := _extract_engine_state_base64(target_bridge)

	var save_payload := {
		"save_id": save_id,
		"slot_name": slot_name,
		"timestamp": timestamp,
		"game_id": resolved_game_id,
		"turn_number": resolved_turn,
		"players": resolved_players,
		"engine_state": engine_state,
	}

	var file_path := SAVES_DIR + save_id + ".json"
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(save_payload, "\t"))
	f.close()

	game_saved.emit(save_id, save_payload)
	return save_id

func load_game(save_id: String, p_bridge: Node = null) -> Dictionary:
	_ensure_saves_dir()

	var target_id := save_id.strip_edges()
	var file_path := SAVES_DIR + target_id + ".json"

	if not FileAccess.file_exists(file_path):
		# Buscar coincidencia por slot_name si se pasó el nombre de ranura
		for entry in list_saves():
			if str(entry.get("slot_name", "")) == target_id or str(entry.get("save_id", "")) == target_id:
				file_path = SAVES_DIR + str(entry.get("save_id", "")) + ".json"
				break

	if not FileAccess.file_exists(file_path):
		return {}

	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}

	var data: Dictionary = json.data
	var target_bridge := p_bridge if p_bridge != null else active_bridge
	var state_b64 := str(data.get("engine_state", ""))
	var game_id := str(data.get("game_id", active_game_id))

	if target_bridge != null and is_instance_valid(target_bridge) and not state_b64.is_empty():
		var raw_bytes := Marshalls.base64_to_raw(state_b64)
		if target_bridge.has_method("restore_state"):
			target_bridge.call("restore_state", raw_bytes, game_id)
		elif target_bridge.has_method("load_replay"):
			if target_bridge.call("load_replay", raw_bytes, game_id):
				while target_bridge.has_method("step_replay") and target_bridge.call("step_replay"):
					pass

	game_loaded.emit(str(data.get("save_id", target_id)), data)
	return data

func list_saves() -> Array:
	_ensure_saves_dir()
	var saves: Array = []
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return saves

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var f := FileAccess.open(SAVES_DIR + fname, FileAccess.READ)
			if f != null:
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
					saves.append(json.data)
				f.close()
		fname = dir.get_next()
	dir.list_dir_end()

	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("timestamp", "")) > str(b.get("timestamp", ""))
	)
	return saves

func delete_save(save_id: String) -> bool:
	_ensure_saves_dir()
	var target_id := save_id.strip_edges()
	var file_path := SAVES_DIR + target_id + ".json"

	if not FileAccess.file_exists(file_path):
		for entry in list_saves():
			if str(entry.get("slot_name", "")) == target_id:
				target_id = str(entry.get("save_id", ""))
				file_path = SAVES_DIR + target_id + ".json"
				break

	if not FileAccess.file_exists(file_path):
		return false

	var err := DirAccess.remove_absolute(file_path)
	if err == OK:
		save_deleted.emit(target_id)
		return true
	return false
