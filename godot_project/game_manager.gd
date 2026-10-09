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
var game_mode: String = "hotseat" # "hotseat" or "vs_ai"
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

func set_online_features_enabled(enabled: bool) -> void:
	online_features_enabled = enabled
	offline_only_mode = not enabled
	var auth := get_node_or_null("/root/AuthClient")
	if auth != null and auth.has_method("set_online_enabled"):
		auth.call("set_online_enabled", enabled)

func is_online_features_enabled() -> bool:
	return online_features_enabled and not offline_only_mode

func set_game_mode(mode: String) -> void:
	game_mode = mode

func get_game_mode() -> String:
	return game_mode

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
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			tm.set_theme(board_theme)
			tm.set_font_tier(font_size_tier)
			if tm.has_method("set_ui_font_scale"):
				tm.call("set_ui_font_scale", ui_scale)
			if tm.has_method("set_colorblind_mode"):
				tm.call("set_colorblind_mode", cb_mode)
		var hm = get_node_or_null("/root/HapticsManager")
		if hm != null and hm.has_method("set_haptics_enabled"):
			hm.call("set_haptics_enabled", haptics_enabled)

		privacy_accepted = bool(cfg.get_value("privacy", "privacy_accepted", false))
		offline_only_mode = bool(cfg.get_value("privacy", "offline_only_mode", false))
		online_features_enabled = bool(cfg.get_value("privacy", "online_enabled", not offline_only_mode)) and not offline_only_mode
		set_online_features_enabled(online_features_enabled)

func set_active_game(game_type: String) -> void:
	active_game_type = game_type

func get_active_game() -> String:
	return active_game_type

static func get_player_color(player_id: int) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color.WHITE
	var idx = posmod(player_id - 1, PLAYER_COLORS.size())
	return PLAYER_COLORS[idx]
