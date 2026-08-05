extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var winner_label: Label = $CenterContainer/VBoxContainer/WinnerLabel
@onready var play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton

func _ready() -> void:
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Start hidden for smooth fade-in
	if color_rect:
		color_rect.modulate.a = 0.0

func show_winner(winner_id: int) -> void:
	if winner_label:
		if winner_id <= 0:
			winner_label.text = "¡Empate!"
		else:
			winner_label.text = "¡Jugador %d gana!" % winner_id
		winner_label.pivot_offset = winner_label.size / 2.0
		winner_label.scale = Vector2(0.5, 0.5)

	show()
	_animate_in()

func _animate_in() -> void:
	# Fade-in overlay background from alpha 0 to 1 in 0.5s
	if color_rect:
		var fade_tween = create_tween()
		fade_tween.tween_property(color_rect, "modulate:a", 1.0, 0.5)

	# Winner label bounce scale: 0.5 -> 1.1 -> 1.0
	if winner_label:
		winner_label.pivot_offset = winner_label.size / 2.0
		var bounce_tween = create_tween()
		bounce_tween.tween_property(winner_label, "scale", Vector2(1.1, 1.1), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bounce_tween.tween_property(winner_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")
