extends Node

signal theme_changed(theme: BoardTheme)
signal font_size_changed(tier: int)
@warning_ignore("unused_signal")
signal sfx_toggled(enabled: bool)
@warning_ignore("unused_signal")
signal animations_toggled(enabled: bool)

var themes: Dictionary = {}
var current_theme_key: String = "wood"
var current_theme: BoardTheme
var current_font_tier: int = 1 # 0: Pequeño, 1: Mediano, 2: Grande
var sfx_enabled: bool = true
var animations_enabled: bool = true

func _init() -> void:
	_create_presets()

func _ready() -> void:
	_apply_theme("wood")
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)

func _on_layout_changed(_layout: int) -> void:
	font_size_changed.emit(current_font_tier)

func get_font_scale() -> float:
	var layout = 0
	if has_node("/root/GameManager"):
		layout = get_node("/root/GameManager").get_layout()
	elif Engine.has_singleton("GameManager"):
		layout = GameManager.get_layout()
	match layout:
		2: return 0.75  # PHONE
		1: return 1.0   # TABLET
		0: return 1.25  # DESKTOP
		_: return 1.0

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

	current_theme = themes["wood"]

func toggle_theme() -> BoardTheme:
	if current_theme_key == "wood":
		set_theme("minimal")
	else:
		set_theme("wood")
	return current_theme

func set_theme(theme_name: String) -> void:
	var key = theme_name.to_lower()
	if key.contains("madera") or key == "wood":
		key = "wood"
	elif key.contains("minimal") or key.contains("moderno"):
		key = "minimal"
		
	if themes.has(key):
		current_theme_key = key
		current_theme = themes[key]
		theme_changed.emit(current_theme)

func _apply_theme(key: String) -> void:
	set_theme(key)

func set_font_tier(tier: int) -> void:
	current_font_tier = clamp(tier, 0, 2)
	font_size_changed.emit(current_font_tier)

func get_font_size(base_size: int = 16) -> int:
	match current_font_tier:
		0: return max(10, base_size - 3)
		1: return base_size
		2: return base_size + 4
		_: return base_size

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
