extends Node

signal layout_changed(layout: int)

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
var font_size_tier: int = 1
var replay_log_bytes: PackedByteArray = PackedByteArray()
var replay_game_type: String = "checkers"
var last_layout: int = -1

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
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			tm.set_theme(board_theme)
			tm.set_font_tier(font_size_tier)

func set_active_game(game_type: String) -> void:
	active_game_type = game_type

func get_active_game() -> String:
	return active_game_type

static func get_player_color(player_id: int) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color.WHITE
	var idx = posmod(player_id - 1, PLAYER_COLORS.size())
	return PLAYER_COLORS[idx]
