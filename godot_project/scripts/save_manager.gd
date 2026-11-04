# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

signal game_saved(save_id: String, metadata: Dictionary)
signal game_loaded(save_id: String, metadata: Dictionary)
signal save_deleted(save_id: String)
signal replay_exported(path: String, metadata: Dictionary)
signal replay_imported(path: String, metadata: Dictionary)

const SAVES_DIR := "user://saves/"
const OTR_FORMAT_VERSION := "1"

var active_bridge: Node = null
var active_game_id: String = "chess"
var active_turn_number: int = 1
var active_players: Array = [
	{"id": 1, "name": "Jugador 1", "score": 0},
	{"id": 2, "name": "Jugador 2", "score": 0},
]
var last_imported_replay: Dictionary = {}

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
		if (is_inside_tree() and has_node("/root/GameManager")):
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
	var serialized_json := JSON.stringify(save_payload, "\t")
	f.store_string(serialized_json)
	f.close()

	if (is_inside_tree() and has_node("/root/SteamManager")):
		var sm = get_node("/root/SteamManager")
		if sm.has_method("is_steam_available") and sm.call("is_steam_available"):
			var raw_utf8 := serialized_json.to_utf8_buffer()
			sm.call("sync_save", save_id, raw_utf8)
			if not slot_name.strip_edges().is_empty():
				sm.call("sync_save", slot_name.strip_edges(), raw_utf8)

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
		if (is_inside_tree() and has_node("/root/SteamManager")):
			var sm = get_node("/root/SteamManager")
			if sm.has_method("is_steam_available") and sm.call("is_steam_available"):
				var cloud_bytes: PackedByteArray = sm.call("load_save", target_id)
				if cloud_bytes.size() > 0:
					var cf := FileAccess.open(file_path, FileAccess.WRITE)
					if cf != null:
						cf.store_buffer(cloud_bytes)
						cf.close()
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
	var state_b64: String = str(data.get("engine_state", ""))
	var game_id: String = str(data.get("game_id", active_game_id))

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

func _extract_replay_moves_array(target_bridge: Node = null) -> Array:
	var resolved_bridge := target_bridge if target_bridge != null else active_bridge
	var raw_bytes := PackedByteArray()

	if resolved_bridge != null and is_instance_valid(resolved_bridge):
		if resolved_bridge.has_method("export_log"):
			raw_bytes = resolved_bridge.call("export_log")
		elif resolved_bridge.has_method("serialize_state"):
			raw_bytes = resolved_bridge.call("serialize_state")

	if raw_bytes.is_empty() and (is_inside_tree() and has_node("/root/GameManager")):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_replay_log_bytes"):
			raw_bytes = gm.call("get_replay_log_bytes")

	if raw_bytes.size() > 0:
		var parsed = JSON.parse_string(raw_bytes.get_string_from_utf8())
		if parsed is Array:
			return parsed

	if last_imported_replay.has("moves") and last_imported_replay["moves"] is Array:
		return last_imported_replay["moves"].duplicate(true)

	return []

func _extract_player_names() -> Array[String]:
	var names: Array[String] = []
	for p in active_players:
		if p is Dictionary:
			names.append(str(p.get("name", "Jugador")))
		else:
			names.append(str(p))
	if names.is_empty():
		names = ["Jugador 1", "Jugador 2"]
	return names

func export_replay_file(path: String, share_after_export: bool = false) -> bool:
	_ensure_saves_dir()
	var target_path := path.strip_edges()
	if target_path.is_empty():
		return false
	if not target_path.ends_with(".otr"):
		target_path += ".otr"

	var resolved_game_id := active_game_id
	if resolved_game_id.is_empty() and (is_inside_tree() and has_node("/root/GameManager")):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_replay_game_type"):
			resolved_game_id = str(gm.call("get_replay_game_type"))
	if resolved_game_id.is_empty():
		resolved_game_id = "checkers"

	var otr_payload := {
		"version": OTR_FORMAT_VERSION,
		"game_id": resolved_game_id,
		"player_names": _extract_player_names(),
		"moves": _extract_replay_moves_array(),
	}

	var json_str := JSON.stringify(otr_payload)
	var utf8_bytes := json_str.to_utf8_buffer()
	var compressed_bytes := utf8_bytes.compress(FileAccess.COMPRESSION_GZIP)
	var bytes_to_write := compressed_bytes if compressed_bytes.size() > 0 else utf8_bytes

	var base_dir := target_path.get_base_dir()
	if not base_dir.is_empty() and not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)

	var f := FileAccess.open(target_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes_to_write)
	f.close()

	if share_after_export and DisplayServer.get_name() != "headless":
		OS.shell_open(ProjectSettings.globalize_path(target_path))

	replay_exported.emit(target_path, otr_payload)
	return true

func import_replay_file(path: String) -> bool:
	var target_path := path.strip_edges()
	if target_path.is_empty() or not FileAccess.file_exists(target_path):
		return false

	var f := FileAccess.open(target_path, FileAccess.READ)
	if f == null:
		return false
	var raw_file_bytes := f.get_buffer(f.get_length())
	f.close()

	if raw_file_bytes.is_empty():
		return false

	var json_text := ""
	# GZIP magic bytes: 0x1F 0x8B
	if raw_file_bytes.size() >= 2 and raw_file_bytes[0] == 0x1F and raw_file_bytes[1] == 0x8B:
		var decompressed := raw_file_bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		if decompressed.size() > 0:
			json_text = decompressed.get_string_from_utf8()

	if json_text.is_empty():
		json_text = raw_file_bytes.get_string_from_utf8()

	var json := JSON.new()
	if json.parse(json_text) != OK or not (json.data is Dictionary):
		return false

	var data: Dictionary = json.data
	if str(data.get("version", "")) != OTR_FORMAT_VERSION:
		return false
	if not data.has("game_id") or str(data.get("game_id", "")).strip_edges().is_empty():
		return false
	if not (data.get("moves") is Array) or not (data.get("player_names") is Array):
		return false

	last_imported_replay = data.duplicate(true)
	active_game_id = str(data["game_id"])

	var player_names_arr: Array = data["player_names"]
	var updated_players: Array = []
	for idx in range(player_names_arr.size()):
		updated_players.append({
			"id": idx + 1,
			"name": str(player_names_arr[idx]),
			"score": 0,
		})
	if not updated_players.is_empty():
		active_players = updated_players

	var moves_json := JSON.stringify(data["moves"])
	var moves_bytes := moves_json.to_utf8_buffer()

	if (is_inside_tree() and has_node("/root/GameManager")):
		var gm = get_node("/root/GameManager")
		if gm.has_method("set_replay_data"):
			gm.call("set_replay_data", moves_bytes, active_game_id)

	if active_bridge != null and is_instance_valid(active_bridge) and active_bridge.has_method("load_replay"):
		active_bridge.call("load_replay", moves_bytes, active_game_id)

	replay_imported.emit(target_path, last_imported_replay)
	return true

func get_last_imported_replay_bytes() -> PackedByteArray:
	if last_imported_replay.has("moves") and last_imported_replay["moves"] is Array:
		return JSON.stringify(last_imported_replay["moves"]).to_utf8_buffer()
	return PackedByteArray()

