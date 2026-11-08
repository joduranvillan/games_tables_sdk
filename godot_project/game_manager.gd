# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

signal layout_changed(layout: int)
signal safe_area_changed(margins: Dictionary)

enum ScreenLayout { DESKTOP, TABLET, PHONE }

const PLAYER_COLORS: Array[Color] = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.PURPLE,
	Color.ORANGE
]

var active_game_type: String = ""
var active_game: String = ""
var game_mode: String = "hotseat" # "hotseat", "vs_ai", or "network"
var human_player_id: int = 1 # 1 (Inicia Humano) or 2 (Inicia IA)
var active_network_bridge: Node = null
var network_mode: String = "" # "", "host", or "client"
var local_network_player_id: int = 1
var open_qr_scanner_on_lobby_ready: bool = false
var relay_url: String = "ws://127.0.0.1:8080"
var last_host_ip: String = ""
var last_host_port: int = 0
var last_reconnect_token: String = ""
var last_relay_room_code: String = ""
var last_transport_kind: String = ""
var reconnect_in_progress: bool = false
var reconnect_attempts: int = 0
var reconnect_timer_accum: float = 0.0
const MAX_RECONNECT_ATTEMPTS: int = 5
var ai_difficulty: int = 1 # 0=Easy, 1=Normal, 2=Hard, 3=Expert
var chess_ai_depth: int = 2
var sfx_enabled: bool = true
var animations_enabled: bool = true
var haptics_enabled: bool = true
var privacy_accepted: bool = false
var online_features_enabled: bool = true
var offline_only_mode: bool = false
var font_size_tier: int = 1
var replay_log_bytes: PackedByteArray = PackedByteArray()
var replay_game_type: String = "checkers"
var last_layout: int = -1
var last_safe_margins: Dictionary = {"top": 0, "bottom": 0, "left": 0, "right": 0}

func set_relay_url(url: String, persist: bool = true) -> void:
	var clean: String = url.strip_edges()
	if clean.is_empty():
		clean = "ws://127.0.0.1:8080"
	if not clean.begins_with("ws://") and not clean.begins_with("wss://"):
		clean = "ws://" + clean
	relay_url = clean
	if persist:
		var cfg := ConfigFile.new()
		cfg.load("user://settings.cfg")
		cfg.set_value("network", "relay_url", relay_url)
		cfg.save("user://settings.cfg")

func get_relay_url() -> String:
	if relay_url.strip_edges().is_empty():
		var env_url: String = OS.get_environment("OPEN_TABLE_RELAY_URL").strip_edges()
		if not env_url.is_empty():
			return env_url
		return "ws://127.0.0.1:8080"
	return relay_url

func set_tcp_connection_info(ip: String, port: int, token: String = "") -> void:
	last_host_ip = ip.strip_edges()
	last_host_port = port
	if not token.is_empty():
		last_reconnect_token = token
	last_transport_kind = "tcp_client"

func set_relay_connection_info(url: String, room_code: String, is_host: bool = false) -> void:
	if not url.strip_edges().is_empty():
		set_relay_url(url, false)
	last_relay_room_code = room_code.strip_edges().to_upper()
	last_transport_kind = "relay_host" if is_host else "relay_client"

func set_online_features_enabled(enabled: bool) -> void:
	online_features_enabled = enabled
	offline_only_mode = not enabled
	var auth = (get_node_or_null("/root/AuthClient") if is_inside_tree() else null)
	if auth != null and auth.has_method("set_online_enabled"):
		auth.call("set_online_enabled", enabled)

func is_online_features_enabled() -> bool:
	return online_features_enabled and not offline_only_mode

func set_game_mode(mode: String) -> void:
	game_mode = mode
	if mode != "network" and mode != "host" and mode != "client":
		network_mode = ""
		reconnect_in_progress = false
		reconnect_attempts = 0

func get_game_mode() -> String:
	return game_mode

func register_network_bridge(bridge_node: Node, mode_str: String, local_pid: int, game_id: String = "") -> void:
	if bridge_node == null or not is_instance_valid(bridge_node):
		return
	if active_network_bridge != null and is_instance_valid(active_network_bridge) and active_network_bridge != bridge_node:
		if active_network_bridge.get_parent() == self:
			remove_child(active_network_bridge)
		active_network_bridge.queue_free()
	var prev_parent: Node = bridge_node.get_parent()
	if prev_parent != null and prev_parent != self:
		prev_parent.remove_child(bridge_node)
	if bridge_node.get_parent() == null:
		add_child(bridge_node)
	active_network_bridge = bridge_node
	network_mode = mode_str
	local_network_player_id = 2 if local_pid == 2 else 1
	human_player_id = local_network_player_id
	game_mode = "network"
	reconnect_in_progress = false
	reconnect_attempts = 0
	if bridge_node.has_method("get_network_transport_kind"):
		var tk: String = str(bridge_node.call("get_network_transport_kind"))
		if tk != "none" and not tk.is_empty():
			last_transport_kind = tk
	if bridge_node.has_method("get_relay_room_code"):
		var rc: String = str(bridge_node.call("get_relay_room_code"))
		if not rc.is_empty():
			last_relay_room_code = rc
	if bridge_node.has_method("get_relay_url"):
		var rurl: String = str(bridge_node.call("get_relay_url"))
		if not rurl.is_empty():
			relay_url = rurl
	if bridge_node.has_signal("native_handshake_established"):
		var hs_cb := Callable(self, "_on_bridge_handshake_established")
		if not bridge_node.is_connected("native_handshake_established", hs_cb):
			bridge_node.connect("native_handshake_established", hs_cb)
	if bridge_node.has_signal("disconnected"):
		var disc_cb := Callable(self, "_on_bridge_disconnected")
		if not bridge_node.is_connected("disconnected", disc_cb):
			bridge_node.connect("disconnected", disc_cb)
	if not game_id.is_empty():
		set_active_game(game_id)

func _on_bridge_handshake_established(pid: int, token: String) -> void:
	if pid >= 2:
		local_network_player_id = pid
		human_player_id = pid
	if not token.is_empty():
		last_reconnect_token = token

func _on_bridge_disconnected() -> void:
	if not is_network_match() or active_network_bridge == null or not is_instance_valid(active_network_bridge):
		return
	if last_transport_kind in ["tcp_client", "relay_client", "relay_host"]:
		reconnect_in_progress = true
		reconnect_attempts = 0
		reconnect_timer_accum = 0.0
		if active_network_bridge.has_method("emit_connection_reconnecting"):
			active_network_bridge.call("emit_connection_reconnecting", 1)

func attempt_auto_reconnect() -> bool:
	if active_network_bridge == null or not is_instance_valid(active_network_bridge):
		reconnect_in_progress = false
		return false
	var ok: bool = false
	if last_transport_kind == "tcp_client" and not last_host_ip.is_empty() and last_host_port > 0:
		if not last_reconnect_token.is_empty() and active_network_bridge.has_method("reconnect_to_host"):
			ok = bool(active_network_bridge.call("reconnect_to_host", last_host_ip, last_host_port, local_network_player_id, last_reconnect_token))
		elif active_network_bridge.has_method("connect_to_host"):
			ok = bool(active_network_bridge.call("connect_to_host", last_host_ip, last_host_port, "Player" + str(local_network_player_id)))
	elif last_transport_kind in ["relay_client", "relay_host"] and not last_relay_room_code.is_empty():
		if active_network_bridge.has_method("rejoin_relay_room"):
			ok = bool(active_network_bridge.call("rejoin_relay_room", last_relay_room_code))
	if ok:
		reconnect_in_progress = false
		reconnect_attempts = 0
		reconnect_timer_accum = 0.0
		if active_network_bridge.has_method("emit_connection_restored"):
			active_network_bridge.call("emit_connection_restored")
	return ok

func _process(delta: float) -> void:
	if not reconnect_in_progress:
		return
	reconnect_timer_accum += delta
	if reconnect_timer_accum >= 2.0:
		reconnect_timer_accum = 0.0
		reconnect_attempts += 1
		if active_network_bridge != null and is_instance_valid(active_network_bridge) and active_network_bridge.has_method("emit_connection_reconnecting"):
			active_network_bridge.call("emit_connection_reconnecting", reconnect_attempts)
		if attempt_auto_reconnect():
			return
		if reconnect_attempts >= MAX_RECONNECT_ATTEMPTS:
			reconnect_in_progress = false

func has_active_network_bridge() -> bool:
	return active_network_bridge != null and is_instance_valid(active_network_bridge)

func claim_network_bridge(target_parent: Node = null) -> Node:
	if not has_active_network_bridge():
		return null
	var b: Node = active_network_bridge
	if target_parent != null and is_instance_valid(target_parent):
		var prev_parent: Node = b.get_parent()
		if prev_parent != null and prev_parent != target_parent:
			prev_parent.remove_child(b)
		if b.get_parent() == null:
			target_parent.add_child(b)
	return b

func get_network_local_player_id() -> int:
	return local_network_player_id

func is_local_player_turn(bridge_node: Node = null) -> bool:
	if not is_network_match():
		return true
	var b: Node = bridge_node if (bridge_node != null and is_instance_valid(bridge_node)) else active_network_bridge
	if b != null and is_instance_valid(b):
		if b.has_method("is_local_player_turn") and b.has_method("is_network_mode") and bool(b.call("is_network_mode")):
			return bool(b.call("is_local_player_turn"))
		if b.has_method("current_player"):
			var cp: int = int(b.call("current_player"))
			if cp > 0:
				return cp == local_network_player_id
	return true

func is_network_match() -> bool:
	return game_mode == "network" or not network_mode.is_empty()

func clear_network_bridge() -> void:
	if active_network_bridge != null and is_instance_valid(active_network_bridge):
		if active_network_bridge.get_parent() == self:
			remove_child(active_network_bridge)
		active_network_bridge.queue_free()
	active_network_bridge = null
	network_mode = ""
	reconnect_in_progress = false
	reconnect_attempts = 0

func set_human_player_id(pid: int) -> void:
	human_player_id = 2 if pid == 2 else 1

func get_human_player_id() -> int:
	return human_player_id

func set_ai_difficulty(diff: int) -> void:
	ai_difficulty = clampi(diff, 0, 3)

func get_ai_difficulty() -> int:
	return ai_difficulty

func set_chess_ai_depth(depth: int) -> void:
	chess_ai_depth = depth

func get_chess_ai_depth() -> int:
	return chess_ai_depth

static func get_layout() -> ScreenLayout:
	var w = DisplayServer.screen_get_size().x
	if Engine.get_main_loop() != null and Engine.get_main_loop().root != null:
		w = min(w, Engine.get_main_loop().root.size.x)
	if w >= 1024: return ScreenLayout.DESKTOP
	if w >= 600:  return ScreenLayout.TABLET
	return ScreenLayout.PHONE

func set_replay_data(bytes: PackedByteArray, game_type: String = "checkers") -> void:
	replay_log_bytes = bytes
	replay_game_type = game_type

func get_replay_log_bytes() -> PackedByteArray:
	return replay_log_bytes

func get_replay_game_type() -> String:
	return replay_game_type

func _ready() -> void:
	load_saved_settings()
	if get_tree() != null and get_tree().root != null:
		get_tree().root.size_changed.connect(_on_root_size_changed)
	_on_root_size_changed()

func _on_root_size_changed() -> void:
	var current_layout = get_layout()
	if current_layout != last_layout:
		last_layout = current_layout
		layout_changed.emit(current_layout)
	var margins := get_safe_area_margins()
	last_safe_margins = margins
	if get_tree() != null and get_tree().root != null:
		apply_safe_area_to_hud(get_tree().root, margins)
	safe_area_changed.emit(margins)

static func get_safe_area_margins(
	custom_safe_rect: Rect2i = Rect2i(),
	custom_window_size: Vector2i = Vector2i.ZERO
) -> Dictionary:
	var safe_rect := custom_safe_rect
	var win_size := custom_window_size
	if safe_rect == Rect2i() and DisplayServer.has_method("get_display_safe_area"):
		safe_rect = DisplayServer.get_display_safe_area()
	if win_size == Vector2i.ZERO:
		if DisplayServer.has_method("window_get_size"):
			win_size = DisplayServer.window_get_size()
		else:
			win_size = DisplayServer.screen_get_size()

	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0 or win_size.x <= 0 or win_size.y <= 0:
		return {"top": 0, "bottom": 0, "left": 0, "right": 0}

	var top_m := maxi(0, safe_rect.position.y)
	var left_m := maxi(0, safe_rect.position.x)
	var bottom_m := maxi(0, win_size.y - (safe_rect.position.y + safe_rect.size.y))
	var right_m := maxi(0, win_size.x - (safe_rect.position.x + safe_rect.size.x))

	# Limitar a márgenes razonables de notch / barra de gestos (0..120 px)
	top_m = clampi(top_m, 0, 120)
	bottom_m = clampi(bottom_m, 0, 120)
	left_m = clampi(left_m, 0, 120)
	right_m = clampi(right_m, 0, 120)

	return {
		"top": top_m,
		"bottom": bottom_m,
		"left": left_m,
		"right": right_m
	}

func apply_safe_area_to_hud(target_root: Node = null, custom_margins: Dictionary = {}) -> Dictionary:
	var margins: Dictionary = custom_margins if not custom_margins.is_empty() else get_safe_area_margins()
	var root_node: Node = target_root
	if root_node == null and get_tree() != null:
		root_node = get_tree().root
	if root_node != null:
		_apply_safe_area_recursive(root_node, margins)
	return margins

func _apply_safe_area_recursive(node: Node, margins: Dictionary) -> void:
	var top_m: int = int(margins.get("top", 0))
	var bottom_m: int = int(margins.get("bottom", 0))
	var left_m: int = int(margins.get("left", 0))
	var right_m: int = int(margins.get("right", 0))

	var n_lower := node.name.to_lower()
	if node is MarginContainer:
		if "hud" in n_lower or "safe" in n_lower or "top" in n_lower or "bottom" in n_lower:
			var mc := node as MarginContainer
			mc.add_theme_constant_override("margin_top", top_m)
			mc.add_theme_constant_override("margin_bottom", bottom_m)
			mc.add_theme_constant_override("margin_left", left_m)
			mc.add_theme_constant_override("margin_right", right_m)
	elif node is Control:
		var ctrl := node as Control
		if n_lower in ["topbar", "top_bar", "hudtop", "hud_top", "headerbar", "turn_timer_hud", "turntimerhud"]:
			if not ctrl.has_meta("_base_offset_top"):
				ctrl.set_meta("_base_offset_top", ctrl.offset_top)
			var base_top: float = float(ctrl.get_meta("_base_offset_top"))
			ctrl.offset_top = base_top + float(top_m)
		elif n_lower in ["bottombar", "bottom_bar", "hudbottom", "hud_bottom", "footerbar", "hand_panel", "handcontainer"]:
			if not ctrl.has_meta("_base_offset_bottom"):
				ctrl.set_meta("_base_offset_bottom", ctrl.offset_bottom)
			var base_bottom: float = float(ctrl.get_meta("_base_offset_bottom"))
			ctrl.offset_bottom = base_bottom - float(bottom_m)

	for child in node.get_children():
		_apply_safe_area_recursive(child, margins)

func load_saved_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	
	var sys_lang = OS.get_locale_language()
	var valid_langs = ["es", "en", "de", "fr", "it", "pt", "zh", "ja", "ko"]
	var default_lang = sys_lang if sys_lang in valid_langs else "es"

	if err == OK:
		var lang = cfg.get_value("locale", "language", default_lang)
		if lang in valid_langs:
			TranslationServer.set_locale(lang)
			
		var sfx_vol = cfg.get_value("audio", "sfx_volume", 0.8)
		sfx_enabled = cfg.get_value("audio", "sfx_enabled", true)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(sfx_vol if sfx_enabled else 0.0))
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sfx_enabled)
		
		animations_enabled = cfg.get_value("display", "animations_enabled", true)
		font_size_tier = cfg.get_value("display", "font_size_tier", 1)
		
		var board_theme = cfg.get_value("theme", "board_theme", "wood")
		var cb_mode = cfg.get_value("accessibility", "colorblind_mode", "none")
		var ui_scale = float(cfg.get_value("accessibility", "ui_font_scale", 1.0))
		haptics_enabled = bool(cfg.get_value("accessibility", "haptics_enabled", true))
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			tm.set_theme(board_theme)
			tm.set_font_tier(font_size_tier)
			if tm.has_method("set_ui_font_scale"):
				tm.call("set_ui_font_scale", ui_scale)
			if tm.has_method("set_colorblind_mode"):
				tm.call("set_colorblind_mode", cb_mode)
		var hm = (get_node_or_null("/root/HapticsManager") if is_inside_tree() else null)
		if hm != null and hm.has_method("set_haptics_enabled"):
			hm.call("set_haptics_enabled", haptics_enabled)

		privacy_accepted = bool(cfg.get_value("privacy", "privacy_accepted", false))
		offline_only_mode = bool(cfg.get_value("privacy", "offline_only_mode", false))
		online_features_enabled = bool(cfg.get_value("privacy", "online_enabled", not offline_only_mode)) and not offline_only_mode
		set_online_features_enabled(online_features_enabled)
		var env_relay: String = OS.get_environment("OPEN_TABLE_RELAY_URL").strip_edges()
		var default_relay: String = env_relay if not env_relay.is_empty() else "ws://127.0.0.1:8080"
		var saved_relay: String = str(cfg.get_value("network", "relay_url", default_relay))
		set_relay_url(saved_relay, false)
	else:
		var env_relay_fallback: String = OS.get_environment("OPEN_TABLE_RELAY_URL").strip_edges()
		if not env_relay_fallback.is_empty():
			set_relay_url(env_relay_fallback, false)

func set_active_game(game_type: String) -> void:
	active_game_type = game_type
	active_game = game_type

func get_active_game() -> String:
	return active_game_type if not active_game_type.is_empty() else active_game

static func get_player_color(player_id: int) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color.WHITE
	var idx = posmod(player_id - 1, PLAYER_COLORS.size())
	return PLAYER_COLORS[idx]
