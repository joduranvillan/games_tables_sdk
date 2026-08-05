extends Control

var bridge: Node

const GAMES = [
	{ "id": "checkers", "name": "Damas (Checkers)", "method": "start_local_match_checkers", "scene": "res://checkers_board.tscn", "color": Color(0.85, 0.25, 0.25) },
	{ "id": "chess", "name": "Ajedrez (Chess)", "method": "start_local_match_chess", "scene": "res://chess_board.tscn", "color": Color(0.35, 0.35, 0.75) },
	{ "id": "shogi", "name": "Shogi", "method": "start_local_match_shogi", "scene": "res://shogi_board.tscn", "color": Color(0.85, 0.65, 0.25) },
	{ "id": "xiangqi", "name": "Xiangqi", "method": "start_local_match_xiangqi", "scene": "res://xiangqi_board.tscn", "color": Color(0.85, 0.35, 0.15) },
	{ "id": "go", "name": "Go", "method": "start_local_match_go", "scene": "res://go_board.tscn", "color": Color(0.25, 0.65, 0.45) },
	{ "id": "uno", "name": "Uno", "method": "start_local_match_uno", "scene": "res://uno_board.tscn", "color": Color(0.95, 0.25, 0.45) },
	{ "id": "crisis", "name": "Crisis", "method": "start_local_match_crisis", "scene": "res://crisis_board.tscn", "color": Color(0.65, 0.25, 0.75) },
	{ "id": "chinese_checkers", "name": "Damas Chinas", "method": "start_local_match_chinese_checkers", "scene": "res://chinese_checkers_board.tscn", "color": Color(0.25, 0.75, 0.75) },
	{ "id": "mille_bornes", "name": "Mille Bornes", "method": "start_local_match_mille_bornes", "scene": "res://mille_bornes_board.tscn", "color": Color(0.45, 0.75, 0.25) },
	{ "id": "backgammon", "name": "Backgammon", "method": "start_local_match_backgammon", "scene": "res://backgammon_board.tscn", "color": Color(0.75, 0.45, 0.25) },
	{ "id": "monopoly", "name": "Monopoly", "method": "start_local_match_monopoly", "scene": "res://monopoly_board.tscn", "color": Color(0.25, 0.65, 0.85) },
	{ "id": "ludo", "name": "Ludo", "method": "start_local_match_ludo", "scene": "res://ludo_board.tscn", "color": Color(0.85, 0.85, 0.25) },
	{ "id": "battleship", "name": "Batalla Naval", "method": "start_local_match_battleship", "scene": "res://battleship_board.tscn", "color": Color(0.25, 0.45, 0.85) }
]

@onready var grid_container: GridContainer = $GridContainer

func _ready() -> void:
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	_setup_buttons()
	_play_entry_animation()

func _generate_placeholder_icon(main_color: Color) -> Texture2D:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x - 16, y - 16).length()
			if dist <= 12:
				img.set_pixel(x, y, main_color)
			elif dist <= 14:
				img.set_pixel(x, y, main_color.darkened(0.3))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _setup_buttons() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	for game in GAMES:
		var btn = Button.new()
		var tr_key = "GAME_" + game["id"].to_upper()
		btn.text = " " + (tr(tr_key) if tr(tr_key) != tr_key else game["name"])
		btn.custom_minimum_size = Vector2(310, 52)
		btn.pivot_offset = Vector2(155, 26)
		btn.add_theme_font_size_override("font_size", 18)
		
		# 32x32 icon
		var icon_tex = _generate_placeholder_icon(game.get("color", Color.CORNFLOWER_BLUE))
		btn.icon = icon_tex
		btn.expand_icon = true
		
		# Hover scaling animation
		btn.mouse_entered.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)
		btn.mouse_exited.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)
		
		btn.pressed.connect(_on_game_selected.bind(game))
		grid_container.add_child(btn)
		
	# Settings button
	var settings_btn = Button.new()
	settings_btn.text = "⚙️ " + tr("BTN_SETTINGS")
	settings_btn.custom_minimum_size = Vector2(310, 52)
	settings_btn.pivot_offset = Vector2(155, 26)
	settings_btn.add_theme_font_size_override("font_size", 18)
	settings_btn.mouse_entered.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	settings_btn.mouse_exited.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	settings_btn.pressed.connect(_on_settings_pressed)
	grid_container.add_child(settings_btn)

	# Replay button
	var replay_btn = Button.new()
	replay_btn.text = "🎬 Ver Replay"
	replay_btn.custom_minimum_size = Vector2(310, 52)
	replay_btn.pivot_offset = Vector2(155, 26)
	replay_btn.add_theme_font_size_override("font_size", 18)
	replay_btn.mouse_entered.connect(func():
		var tw = replay_btn.create_tween()
		tw.tween_property(replay_btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	replay_btn.mouse_exited.connect(func():
		var tw = replay_btn.create_tween()
		tw.tween_property(replay_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	replay_btn.pressed.connect(_on_ver_replay_pressed)
	grid_container.add_child(replay_btn)

func _play_entry_animation() -> void:
	var buttons = grid_container.get_children()
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.modulate.a = 0.0
		var delay = i * 0.05
		var tw = create_tween()
		tw.tween_interval(delay)
		tw.tween_property(btn, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_settings_pressed() -> void:
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://settings_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://settings_menu.tscn")

func _on_ver_replay_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.otlog ; Replay Logs", "* ; All Files"])
	dialog.file_selected.connect(_on_replay_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_replay_file_selected(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	if f != null:
		var bytes = f.get_buffer(f.get_length())
		GameManager.set_replay_data(bytes, "checkers")
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://replay_viewer.tscn")
	else:
		get_tree().change_scene_to_file("res://replay_viewer.tscn")

func _on_game_selected(game: Dictionary) -> void:
	GameManager.set_active_game(game["id"])

	var method_name: String = game["method"]
	if game["id"] == "crisis":
		if bridge.has_method(method_name):
			bridge.call(method_name, 42, [1, 2])
	elif bridge.has_method(method_name):
		bridge.call(method_name, 1, 2)
	elif bridge.has_method("start_local_match"):
		bridge.call("start_local_match", 1, 2)

	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to(game["scene"])
	else:
		get_tree().change_scene_to_file(game["scene"])
