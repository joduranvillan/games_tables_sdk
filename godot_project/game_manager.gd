extends Node

const PLAYER_COLORS: Array[Color] = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.PURPLE,
	Color.ORANGE
]

var active_game_type: String = ""
var sfx_enabled: bool = true
var animations_enabled: bool = true
var font_size_tier: int = 1
var replay_log_bytes: PackedByteArray = PackedByteArray()
var replay_game_type: String = "checkers"

func set_replay_data(bytes: PackedByteArray, game_type: String = "checkers") -> void:
	replay_log_bytes = bytes
	replay_game_type = game_type

func get_replay_log_bytes() -> PackedByteArray:
	return replay_log_bytes

func get_replay_game_type() -> String:
	return replay_game_type

func _ready() -> void:
	load_saved_settings()

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
