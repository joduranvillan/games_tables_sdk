extends Node

signal theme_changed(theme: BoardTheme)
signal font_size_changed(tier: int)
signal font_scale_changed(scale: float)
@warning_ignore("unused_signal")
signal sfx_toggled(enabled: bool)
@warning_ignore("unused_signal")
signal animations_toggled(enabled: bool)
signal colorblind_mode_toggled(enabled: bool)
signal colorblind_mode_changed(mode: String)

const VALID_COLORBLIND_MODES: Array[String] = [
	"none",
	"deuteranopia",
	"protanopia",
	"tritanopia",
	"high_contrast"
]

const VALID_FONT_SCALES: Array[float] = [1.0, 1.15, 1.3]

# Símbolos geométricos superpuestos sobre fichas y cartas de colores (Prompt 490):
# ▲ Rojo, ● Azul, ■ Verde, ◆ Amarillo, ★ Naranja, ⬟ Violeta
const COLORBLIND_SYMBOLS := {
	"Red": "▲",
	"red": "▲",
	"Rojo": "▲",
	"rojo": "▲",
	"HAZARD": "▲",
	"Blue": "●",
	"blue": "●",
	"Azul": "●",
	"azul": "●",
	"Azul Oscuro": "●",
	"Celeste": "●",
	"DISTANCE": "●",
	"Green": "■",
	"green": "■",
	"Verde": "■",
	"verde": "■",
	"REMEDY": "■",
	"Yellow": "◆",
	"yellow": "◆",
	"Amarillo": "◆",
	"amarillo": "◆",
	"SAFETY": "◆",
	"Orange": "★",
	"orange": "★",
	"Naranja": "★",
	"naranja": "★",
	"Suministros": "★",
	"Marrón": "★",
	"Violet": "⬟",
	"violet": "⬟",
	"Purple": "⬟",
	"purple": "⬟",
	"Violeta": "⬟",
	"violeta": "⬟",
	"Púrpura": "⬟",
	"Rosa": "⬟",
	"Wild": "✦",
	"WildColor": "✦",
}

const UNO_COLORBLIND_SYMBOLS := {
	"Red": "▲",
	"Blue": "●",
	"Green": "■",
	"Yellow": "◆",
	"Orange": "★",
	"Violet": "⬟",
	"Wild": "✦",
	"WildColor": "✦",
}

const PLAYER_COLORBLIND_SYMBOLS := {
	1: "▲", # Rojo
	2: "●", # Azul
	3: "■", # Verde
	4: "◆", # Amarillo
	5: "⬟", # Violeta / Púrpura
	6: "★", # Naranja
}

# Paletas Okabe-Ito y Alto Contraste por modo daltónico
const OKABE_ITO_PALETTES := {
	"none": {
		"red": Color("#D32F2F"),
		"blue": Color("#1976D2"),
		"green": Color("#388E3C"),
		"yellow": Color("#FBC02D"),
		"orange": Color("#FB8C00"),
		"violet": Color("#8E24AA"),
		"sky_blue": Color("#5DADE2"),
		"brown": Color("#8B4513"),
	},
	"deuteranopia": {
		"red": Color("#D55E00"),      # Okabe-Ito Vermilion
		"blue": Color("#0072B2"),     # Okabe-Ito Blue
		"green": Color("#009E73"),    # Okabe-Ito Bluish Green
		"yellow": Color("#F0E442"),   # Okabe-Ito Yellow
		"orange": Color("#E69F00"),   # Okabe-Ito Orange
		"violet": Color("#CC79A7"),   # Okabe-Ito Reddish Purple
		"sky_blue": Color("#56B4E9"), # Okabe-Ito Sky Blue
		"brown": Color("#7F4F24"),
	},
	"protanopia": {
		"red": Color("#D55E00"),      # Okabe-Ito Vermilion
		"blue": Color("#0072B2"),     # Okabe-Ito Blue
		"green": Color("#009E73"),    # Okabe-Ito Bluish Green
		"yellow": Color("#F0E442"),   # Okabe-Ito Yellow
		"orange": Color("#E69F00"),   # Okabe-Ito Orange
		"violet": Color("#CC79A7"),   # Okabe-Ito Reddish Purple
		"sky_blue": Color("#56B4E9"), # Okabe-Ito Sky Blue
		"brown": Color("#6B4C35"),
	},
	"tritanopia": {
		"red": Color("#D55E00"),      # Okabe-Ito Vermilion
		"blue": Color("#0072B2"),     # Okabe-Ito Blue
		"green": Color("#009E73"),    # Okabe-Ito Bluish Green
		"yellow": Color("#F0E442"),   # Okabe-Ito Yellow
		"orange": Color("#E69F00"),   # Okabe-Ito Orange
		"violet": Color("#CC79A7"),   # Okabe-Ito Reddish Purple
		"sky_blue": Color("#56B4E9"), # Okabe-Ito Sky Blue
		"brown": Color("#5C3A21"),
	},
	"high_contrast": {
		"red": Color("#FF2E00"),
		"blue": Color("#0088FF"),
		"green": Color("#00E676"),
		"yellow": Color("#FFEA00"),
		"orange": Color("#FF9100"),
		"violet": Color("#E040FB"),
		"sky_blue": Color("#00E5FF"),
		"brown": Color("#A1887F"),
	}
}

# Overrides de color primario por juego (se mezclan sobre el tema global)
const GAME_COLOR_OVERRIDES := {
	"chess":            Color(0.20, 0.20, 0.35),
	"go":               Color(0.20, 0.45, 0.30),
	"shogi":            Color(0.55, 0.40, 0.15),
	"xiangqi":          Color(0.65, 0.20, 0.10),
	"checkers":         Color(0.65, 0.15, 0.15),
	"backgammon":       Color(0.55, 0.30, 0.10),
	"battleship":       Color(0.10, 0.25, 0.55),
	"ludo":             Color(0.60, 0.60, 0.10),
	"mille_bornes":     Color(0.30, 0.55, 0.15),
	"monopoly":         Color(0.10, 0.45, 0.65),
	"uno":              Color(0.75, 0.10, 0.25),
	"crisis":           Color(0.45, 0.10, 0.55),
	"chinese_checkers": Color(0.10, 0.55, 0.55),
}

var themes: Dictionary = {}
var current_theme_key: String = "wood"
var current_theme: BoardTheme
var current_font_tier: int = 0 # 0: 1.0x, 1: 1.15x, 2: 1.3x
var ui_font_scale: float = 1.0
var sfx_enabled: bool = true
var animations_enabled: bool = true
var colorblind_mode: String = "none"

func set_colorblind_mode(mode_or_enabled: Variant) -> void:
	if typeof(mode_or_enabled) == TYPE_BOOL:
		colorblind_mode = "deuteranopia" if bool(mode_or_enabled) else "none"
	else:
		var m := String(mode_or_enabled).strip_edges().to_lower()
		if m in VALID_COLORBLIND_MODES:
			colorblind_mode = m
		elif m == "true" or m == "1":
			colorblind_mode = "deuteranopia"
		else:
			colorblind_mode = "none"

	colorblind_mode_toggled.emit(is_colorblind_mode())
	colorblind_mode_changed.emit(colorblind_mode)
	if current_theme != null:
		theme_changed.emit(current_theme)

func get_colorblind_mode() -> String:
	return colorblind_mode

func is_colorblind_mode() -> bool:
	return colorblind_mode != "none"

func get_palette(mode: String = "") -> Dictionary:
	var target_mode := mode if not mode.is_empty() else colorblind_mode
	if OKABE_ITO_PALETTES.has(target_mode):
		return OKABE_ITO_PALETTES[target_mode]
	return OKABE_ITO_PALETTES["none"]

func _normalize_color_key(color_name: String) -> String:
	var key := color_name.strip_edges().to_lower()
	match key:
		"red", "rojo", "hazard":
			return "red"
		"blue", "azul", "azul oscuro", "distance":
			return "blue"
		"green", "verde", "remedy":
			return "green"
		"yellow", "amarillo", "safety":
			return "yellow"
		"orange", "naranja", "suministros":
			return "orange"
		"violet", "violeta", "purple", "púrpura", "purpura", "rosa":
			return "violet"
		"celeste", "sky_blue":
			return "sky_blue"
		"marrón", "marron", "brown":
			return "brown"
		_:
			return key

func get_accessible_color(color_name: String, fallback: Color = Color.WHITE) -> Color:
	var norm_key := _normalize_color_key(color_name)
	var pal := get_palette()
	if pal.has(norm_key):
		return pal[norm_key]
	return fallback

func get_player_color(player_id: int, fallback: Color = Color.WHITE) -> Color:
	var idx := posmod(player_id - 1, 6) + 1
	match idx:
		1: return get_accessible_color("red", fallback)
		2: return get_accessible_color("blue", fallback)
		3: return get_accessible_color("green", fallback)
		4: return get_accessible_color("yellow", fallback)
		5: return get_accessible_color("violet", fallback)
		6: return get_accessible_color("orange", fallback)
		_: return fallback

func get_color_symbol(color_name: String) -> String:
	if COLORBLIND_SYMBOLS.has(color_name):
		return COLORBLIND_SYMBOLS[color_name]
	var norm := _normalize_color_key(color_name)
	match norm:
		"red": return "▲"
		"blue", "sky_blue": return "●"
		"green": return "■"
		"yellow": return "◆"
		"orange", "brown": return "★"
		"violet": return "⬟"
		_: return "◆"

func get_uno_color_symbol(color_name: String) -> String:
	return UNO_COLORBLIND_SYMBOLS.get(color_name, get_color_symbol(color_name))

func get_player_symbol(player_id: int) -> String:
	var idx := posmod(player_id - 1, 6) + 1
	return PLAYER_COLORBLIND_SYMBOLS.get(idx, "●")

func get_player_pattern_type(player_id: int) -> String:
	match player_id:
		1: return "stripes_h"
		2: return "stripes_v"
		3: return "dots"
		4: return "cross"
		_: return "ring"

func get_theme_for_game(game_id: String) -> Theme:
	var th := Theme.new()
	if GAME_COLOR_OVERRIDES.has(game_id):
		var col: Color = GAME_COLOR_OVERRIDES[game_id]
		th.set_color("font_color", "Panel", col.lightened(0.6))
		th.set_color("bg_color", "PanelContainer", col.darkened(0.5))
	return th

func apply_game_theme(game_id: String) -> void:
	var base := get_theme_for_game(game_id)
	if get_tree() != null:
		if get_tree().has_method("set_theme"):
			get_tree().call("set_theme", base)
		if get_tree().root != null:
			get_tree().root.theme = base

func _init() -> void:
	_create_presets()

func _ready() -> void:
	_apply_theme("wood")
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)

func _on_layout_changed(_layout: int) -> void:
	font_size_changed.emit(current_font_tier)

func set_ui_font_scale(scale_val: float) -> void:
	if scale_val < 1.075:
		ui_font_scale = 1.0
		current_font_tier = 0
	elif scale_val < 1.225:
		ui_font_scale = 1.15
		current_font_tier = 1
	else:
		ui_font_scale = 1.3
		current_font_tier = 2
	font_scale_changed.emit(ui_font_scale)
	font_size_changed.emit(current_font_tier)

func get_ui_font_scale() -> float:
	return ui_font_scale

func get_font_scale() -> float:
	var layout = 0
	if has_node("/root/GameManager"):
		layout = get_node("/root/GameManager").get_layout()
	elif Engine.has_singleton("GameManager"):
		layout = GameManager.get_layout()
	var base_layout_scale := 1.0
	match layout:
		2: base_layout_scale = 0.75  # PHONE
		1: base_layout_scale = 1.0   # TABLET
		0: base_layout_scale = 1.0   # DESKTOP
		_: base_layout_scale = 1.0
	return base_layout_scale * ui_font_scale

func apply_font_scale_to_board(board_node: Node, base_size: int = 16) -> void:
	var scale_factor = get_font_scale()
	var target_size = int(round(base_size * scale_factor))
	_apply_font_scale_recursive(board_node, target_size)

func _apply_font_scale_recursive(node: Node, target_size: int) -> void:
	if node is Label:
		node.add_theme_font_size_override("font_size", target_size)
	elif node is Button or node is LineEdit or node is OptionButton:
		node.add_theme_font_size_override("font_size", target_size)
	elif node is Control and node.theme != null:
		node.theme.set_font_size("font_size", "Label", target_size)
	for child in node.get_children():
		_apply_font_scale_recursive(child, target_size)

func _create_presets() -> void:
	# 1. Madera Clásica
	var wood = BoardTheme.new()
	wood.theme_name = "Madera Clásica"
	wood.light_color = Color("#DEB887")
	wood.dark_color = Color("#8B4513")
	wood.board_color = Color("#DEB887")
	wood.line_color = Color("#3E200B")
	wood.select_color = Color(1.0, 0.95, 0.30, 0.55)
	wood.valid_move_color = Color(0.2, 0.8, 0.2, 0.55)
	themes["wood"] = wood

	# 2. Moderno Minimal
	var minimal = BoardTheme.new()
	minimal.theme_name = "Moderno Minimal"
	minimal.light_color = Color("#EEEEEE")
	minimal.dark_color = Color("#222222")
	minimal.board_color = Color("#222222")
	minimal.line_color = Color("#EEEEEE")
	minimal.select_color = Color(0.3, 0.8, 1.0, 0.55)
	minimal.valid_move_color = Color(0.0, 0.8, 0.6, 0.6)
	themes["minimal"] = minimal

	# 3. Piedra Oscura (Stone)
	var stone = BoardTheme.new()
	stone.theme_name = "Piedra Oscura"
	stone.light_color = Color("#8B8B8B")
	stone.dark_color = Color("#3A3A3A")
	stone.board_color = Color("#2A2A2A")
	stone.line_color = Color("#AAAAAA")
	stone.select_color = Color(0.9, 0.6, 0.2, 0.55)
	stone.valid_move_color = Color(0.3, 0.7, 0.9, 0.6)
	themes["stone"] = stone

	# 4. Noche Azul (Night)
	var night = BoardTheme.new()
	night.theme_name = "Noche Azul"
	night.light_color = Color("#5B7A9C")
	night.dark_color = Color("#1A2634")
	night.board_color = Color("#121A24")
	night.line_color = Color("#7C9BB8")
	night.select_color = Color(0.4, 0.8, 1.0, 0.55)
	night.valid_move_color = Color(0.2, 0.9, 0.7, 0.6)
	themes["night"] = night

	# 5. Jade Verde (Jade)
	var jade = BoardTheme.new()
	jade.theme_name = "Jade Verde"
	jade.light_color = Color("#A3C9A8")
	jade.dark_color = Color("#2D5A3D")
	jade.board_color = Color("#1E3F2B")
	jade.line_color = Color("#C5E1D4")
	jade.select_color = Color(1.0, 0.85, 0.3, 0.55)
	jade.valid_move_color = Color(0.1, 0.9, 0.4, 0.6)
	themes["jade"] = jade

	current_theme = themes["wood"]

func toggle_theme() -> BoardTheme:
	var keys = ["wood", "minimal", "stone", "night", "jade"]
	var idx = keys.find(current_theme_key)
	if idx != -1:
		var next_key = keys[(idx + 1) % keys.size()]
		set_theme(next_key)
	else:
		set_theme("wood")
	return current_theme

func set_theme(theme_name: String) -> void:
	var key = theme_name.to_lower()
	if key.contains("madera") or key == "wood":
		key = "wood"
	elif key.contains("minimal") or key.contains("moderno"):
		key = "minimal"
	elif key.contains("stone") or key.contains("piedra"):
		key = "stone"
	elif key.contains("night") or key.contains("noche"):
		key = "night"
	elif key.contains("jade"):
		key = "jade"
		
	if themes.has(key):
		current_theme_key = key
		current_theme = themes[key]
		theme_changed.emit(current_theme)

func _apply_theme(key: String) -> void:
	set_theme(key)

func set_font_tier(tier: int) -> void:
	current_font_tier = clamp(tier, 0, 2)
	ui_font_scale = VALID_FONT_SCALES[current_font_tier]
	font_scale_changed.emit(ui_font_scale)
	font_size_changed.emit(current_font_tier)

func get_font_size(base_size: int = 16) -> int:
	return maxi(10, int(round(float(base_size) * ui_font_scale)))

func apply_font_size_to_node(node: Node, base_size: int = 16) -> void:
	if node is Label or node is Button or node is LineEdit:
		node.add_theme_font_size_override("font_size", get_font_size(base_size))

func get_current_theme() -> BoardTheme:
	return get_theme()

func get_theme() -> BoardTheme:
	if current_theme == null:
		if themes.has("wood"):
			current_theme = themes["wood"]
		else:
			_create_presets()
	return current_theme

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	sfx_toggled.emit(sfx_enabled)

func set_animations_enabled(enabled: bool) -> void:
	animations_enabled = enabled
	animations_toggled.emit(animations_enabled)
