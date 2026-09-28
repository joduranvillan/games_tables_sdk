class_name BoardTheme
extends Resource

@export var theme_name: String = "Madera Clásica"
@export var light_color: Color = Color("#DEB887")
@export var dark_color: Color = Color("#8B4513")
@export var board_color: Color = Color("#DEB887")
@export var line_color: Color = Color("#3E200B")
@export var select_color: Color = Color(1.0, 0.95, 0.30, 0.55)
@export var valid_move_color: Color = Color(0.2, 0.8, 0.2, 0.55)
@export var piece_font: Font = null
@export var background_texture: Texture2D = null

var custom_colors: Dictionary = {}

func set_color(property: String, theme_type: String, color: Color) -> void:
	if not custom_colors.has(theme_type):
		custom_colors[theme_type] = {}
	custom_colors[theme_type][property] = color

func get_color(property: String, theme_type: String) -> Color:
	if custom_colors.has(theme_type) and custom_colors[theme_type].has(property):
		return custom_colors[theme_type][property]
	return Color.WHITE
