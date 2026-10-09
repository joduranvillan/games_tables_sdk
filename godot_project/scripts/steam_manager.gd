extends Node

signal steam_initialized(available: bool)
signal cloud_save_synced(slot: String, success: bool)

var steam_available: bool = false
var bridge: Object = null

func _ready() -> void:
	if ClassDB.class_exists("OpenTableBridge"):
		bridge = ClassDB.instantiate("OpenTableBridge")
		if bridge != null and bridge is Node:
			add_child(bridge)
		if bridge != null and bridge.has_method("steam_init"):
			steam_available = bool(bridge.call("steam_init"))
	steam_initialized.emit(steam_available)

	if (is_inside_tree() and has_node("/root/AchievementManager")):
		var am = get_node("/root/AchievementManager")
		if am.has_signal("achievement_unlocked") and not am.achievement_unlocked.is_connected(_on_achievement_unlocked):
			am.achievement_unlocked.connect(_on_achievement_unlocked)

func is_steam_available() -> bool:
	return steam_available

func _on_achievement_unlocked(achievement_id: String, _info: Dictionary = {}) -> void:
	unlock_achievement(achievement_id)

func unlock_achievement(achievement_id: String) -> bool:
	if not steam_available or bridge == null:
		return false
	if bridge.has_method("steam_unlock_achievement"):
		return bool(bridge.call("steam_unlock_achievement", achievement_id))
	return false

func sync_save(slot: String, data: PackedByteArray) -> bool:
	if not steam_available or bridge == null:
		return false
	if bridge.has_method("steam_sync_save"):
		var ok := bool(bridge.call("steam_sync_save", slot, data))
		cloud_save_synced.emit(slot, ok)
		return ok
	return false

func load_save(slot: String) -> PackedByteArray:
	if not steam_available or bridge == null:
		return PackedByteArray()
	if bridge.has_method("steam_load_save"):
		var res = bridge.call("steam_load_save", slot)
		if res is PackedByteArray:
			return res
	return PackedByteArray()
