extends CanvasLayer

signal rematch_requested
signal menu_requested

@onready var color_rect: ColorRect = $ColorRect
@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var winner_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WinnerLabel
@onready var restart_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MenuButton

func _ready() -> void:
	_apply_styles()
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_go_to_menu_pressed)
		
	if color_rect:
		color_rect.color = Color(0, 0, 0, 0.72)
		color_rect.modulate.a = 0.0

func _apply_styles() -> void:
	if panel_container:
		panel_container.custom_minimum_size = Vector2(380, 220)
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.15, 0.12, 0.08, 0.97)
		style_box.border_color = Color(0.8, 0.65, 0.1, 1.0)
		style_box.set_border_width_all(3)
		style_box.set_corner_radius_all(12)
		panel_container.add_theme_stylebox_override("panel", style_box)

	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.25, 0.20, 0.12, 0.95)
	btn_style_normal.border_color = Color(0.8, 0.65, 0.1, 1.0)
	btn_style_normal.set_border_width_all(2)
	btn_style_normal.set_corner_radius_all(8)

	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.35, 0.28, 0.16, 1.0)
	btn_style_hover.border_color = Color(1.0, 0.85, 0.2, 1.0)
	btn_style_hover.set_border_width_all(2)
	btn_style_hover.set_corner_radius_all(8)

	for btn in [restart_button, menu_button]:
		if btn != null:
			btn.custom_minimum_size = Vector2(130, 42)
			btn.add_theme_stylebox_override("normal", btn_style_normal)
			btn.add_theme_stylebox_override("hover", btn_style_hover)
			btn.add_theme_stylebox_override("pressed", btn_style_hover)
			btn.add_theme_font_size_override("font_size", 18)

func show_winner(winner_id: int) -> void:
	if winner_id <= 0:
		if title_label:
			title_label.text = "¡Empate!"
			title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		if winner_label:
			winner_label.text = "Partida finalizada sin ganador"
			winner_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	else:
		var p_color = GameManager.get_player_color(winner_id)
		if title_label:
			title_label.text = "¡Victoria!"
			title_label.add_theme_color_override("font_color", p_color)
		if winner_label:
			winner_label.text = "¡Jugador %d gana la partida!" % winner_id
			winner_label.add_theme_color_override("font_color", p_color)

	show()
	_animate_in()

func _animate_in() -> void:
	if color_rect:
		color_rect.modulate.a = 0.0
		var fade_tween = create_tween()
		fade_tween.tween_property(color_rect, "modulate:a", 1.0, 0.3)

	if title_label:
		await get_tree().process_frame
		var target_y = title_label.position.y
		title_label.position.y = -50.0
		var title_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title_label, "position:y", target_y, 0.4)

func _on_restart_pressed() -> void:
	rematch_requested.emit()
	get_tree().reload_current_scene()

func _on_go_to_menu_pressed() -> void:
	menu_requested.emit()
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")

# Alias handlers for backward compatibility
func _on_play_again_pressed() -> void:
	_on_restart_pressed()

func _on_main_menu_pressed() -> void:
	_on_go_to_menu_pressed()

