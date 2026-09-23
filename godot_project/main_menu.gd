extends Control

signal layout_changed

var bridge: Node

var idle_time: float = 0.0
const ATTRACT_IDLE_LIMIT: float = 30.0
var is_attract_mode: bool = false

var demo_node: Node2D
var demo_bridge: Node
var demo_timer: Timer
var demo_overlay: CanvasLayer
var current_popup_overlay: Control = null

const GAMES = [
	{ "id": "checkers", "name": "Damas (Checkers)", "method": "start_local_match_checkers", "ai_method": "start_local_match_checkers_vs_ai", "scene": "res://checkers_board.tscn", "color": Color(0.85, 0.25, 0.25) },
	{ "id": "chess", "name": "Ajedrez (Chess)", "method": "start_local_match_chess", "ai_method": "start_local_match_chess_vs_ai", "scene": "res://chess_board.tscn", "color": Color(0.35, 0.35, 0.75) },
	{ "id": "shogi", "name": "Shogi", "method": "start_local_match_shogi", "ai_method": "start_local_match_shogi_vs_ai", "scene": "res://shogi_board.tscn", "color": Color(0.85, 0.65, 0.25) },
	{ "id": "xiangqi", "name": "Xiangqi", "method": "start_local_match_xiangqi", "ai_method": "start_local_match_xiangqi_vs_ai", "scene": "res://xiangqi_board.tscn", "color": Color(0.85, 0.35, 0.15) },
	{ "id": "go", "name": "Go", "method": "start_local_match_go", "ai_method": "start_local_match_go_vs_ai", "scene": "res://go_board.tscn", "color": Color(0.25, 0.65, 0.45) },
	{ "id": "uno", "name": "Uno", "method": "start_local_match_uno", "ai_method": "", "scene": "res://uno_board.tscn", "color": Color(0.95, 0.25, 0.45) },
	{ "id": "crisis", "name": "Crisis", "method": "start_local_match_crisis", "ai_method": "", "scene": "res://crisis_board.tscn", "color": Color(0.65, 0.25, 0.75) },
	{ "id": "chinese_checkers", "name": "Damas Chinas", "method": "start_local_match_chinese_checkers", "ai_method": "", "scene": "res://chinese_checkers_board.tscn", "color": Color(0.25, 0.75, 0.75) },
	{ "id": "mille_bornes", "name": "Mille Bornes", "method": "start_local_match_mille_bornes", "ai_method": "", "scene": "res://mille_bornes_board.tscn", "color": Color(0.45, 0.75, 0.25) },
	{ "id": "backgammon", "name": "Backgammon", "method": "start_local_match_backgammon", "ai_method": "start_local_match_backgammon_vs_ai", "scene": "res://backgammon_board.tscn", "color": Color(0.75, 0.45, 0.25) },
	{ "id": "monopoly", "name": "Monopoly", "method": "start_local_match_monopoly", "ai_method": "", "scene": "res://monopoly_board.tscn", "color": Color(0.25, 0.65, 0.85) },
	{ "id": "ludo", "name": "Ludo", "method": "start_local_match_ludo", "ai_method": "start_local_match_ludo_vs_ai", "scene": "res://ludo_board.tscn", "color": Color(0.85, 0.85, 0.25) },
	{ "id": "battleship", "name": "Batalla Naval", "method": "start_local_match_battleship", "ai_method": "", "scene": "res://battleship_board.tscn", "color": Color(0.25, 0.45, 0.85) }
]

@onready var grid_container: GridContainer = $GridContainer

func _ready() -> void:
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	_setup_buttons()
	_play_entry_animation()
	_setup_multiplayer_row()

func _process(delta: float) -> void:
	if not is_attract_mode:
		idle_time += delta
		if idle_time >= ATTRACT_IDLE_LIMIT:
			_start_attract_mode()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch:
		idle_time = 0.0
		if is_attract_mode:
			_stop_attract_mode()
			get_viewport().set_input_as_handled()

func _start_attract_mode() -> void:
	is_attract_mode = true

	demo_node = Node2D.new()
	demo_node.name = "AttractModeDemo"
	demo_node.z_index = -1
	demo_node.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(demo_node)

	demo_bridge = OpenTableBridge.new()
	demo_bridge.name = "AttractBridge"
	demo_node.add_child(demo_bridge)

	if demo_bridge.has_method("start_local_match_checkers_vs_ai"):
		demo_bridge.call("start_local_match_checkers_vs_ai", 42, 1, 2)
	elif demo_bridge.has_method("start_local_match"):
		demo_bridge.call("start_local_match", 1, 2)

	var checkers_scene = load("res://checkers_board.tscn")
	if checkers_scene:
		var checkers_inst = checkers_scene.instantiate()
		checkers_inst.scale = Vector2(0.85, 0.85)
		checkers_inst.position = Vector2(200, 40)
		demo_node.add_child(checkers_inst)

	# Grid container dimming
	grid_container.modulate.a = 0.15
	if has_node("Title"):
		get_node("Title").modulate.a = 0.25

	# Overlay Banner
	demo_overlay = CanvasLayer.new()
	demo_overlay.layer = 20
	add_child(demo_overlay)

	var banner = Panel.new()
	banner.position = Vector2(100, 680)
	banner.custom_minimum_size = Vector2(600, 50)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	banner.add_theme_stylebox_override("normal", style)
	demo_overlay.add_child(banner)

	var lbl = Label.new()
	lbl.text = "🎮 MODO DEMO — Haz click en cualquier parte para volver al menú"
	lbl.position = Vector2(10, 10)
	lbl.custom_minimum_size = Vector2(580, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	banner.add_child(lbl)

	# Timer for AI vs AI step
	demo_timer = Timer.new()
	demo_timer.wait_time = 0.8
	demo_timer.autostart = true
	demo_timer.timeout.connect(_on_demo_tick)
	demo_node.add_child(demo_timer)

	# Set scene process mode paused for background demo as requested
	get_tree().paused = false

func _on_demo_tick() -> void:
	if not is_instance_valid(demo_bridge):
		return
	var cur_p = demo_bridge.current_player()
	if cur_p > 0 and demo_bridge.has_method("checkers_ai_pick_move"):
		var moved = demo_bridge.call("checkers_ai_pick_move", cur_p)
		if not moved:
			var next_p = 2 if cur_p == 1 else 1
			demo_bridge.call("checkers_ai_pick_move", next_p)

func _stop_attract_mode() -> void:
	is_attract_mode = false
	idle_time = 0.0

	if is_instance_valid(demo_node):
		demo_node.queue_free()
	if is_instance_valid(demo_overlay):
		demo_overlay.queue_free()

	grid_container.modulate.a = 1.0
	if has_node("Title"):
		get_node("Title").modulate.a = 1.0

func _load_game_icon(game_id: String) -> Texture2D:
	var paths = [
		"res://assets/icons/%s.svg" % game_id,
		"res://assets/icons/%s.png" % game_id
	]
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is Texture2D:
				return res
		if FileAccess.file_exists(p):
			var img = Image.new()
			var err = img.load(p)
			if err == OK:
				return ImageTexture.create_from_image(img)
	return null

func _apply_button_theme(btn: Button, color: Color) -> void:
	var base_bg = Color(color.r, color.g, color.b, 0.85)
	var hover_border = color.lightened(0.3)
	var shadow_c = color.darkened(0.5)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_bg
	style_normal.border_color = color.darkened(0.2)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(10)
	style_normal.shadow_color = shadow_c
	style_normal.shadow_size = 4
	style_normal.shadow_offset = Vector2(0, 2)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(color.r, color.g, color.b, 0.95)
	style_hover.border_color = hover_border
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(10)
	style_hover.shadow_color = shadow_c
	style_hover.shadow_size = 4
	style_hover.shadow_offset = Vector2(0, 2)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = color.darkened(0.1)
	style_pressed.border_color = hover_border
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(10)
	style_pressed.shadow_color = shadow_c
	style_pressed.shadow_size = 2

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_hover)

func _setup_buttons() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	for game in GAMES:
		var btn = Button.new()
		var tr_key = "GAME_" + game["id"].to_upper()
		var display_name = tr(tr_key) if tr(tr_key) != tr_key else game["name"]
		var color = game.get("color", Color(0.35, 0.45, 0.65))

		_apply_button_theme(btn, color)
		btn.custom_minimum_size = Vector2(310, 90)
		btn.pivot_offset = Vector2(155, 45)

		var icon_tex = _load_game_icon(game["id"])
		if icon_tex != null:
			btn.text = ""
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_theme_constant_override("separation", 6)

			var icon_rect = TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(icon_rect)

			var lbl = Label.new()
			lbl.text = display_name
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(lbl)

			btn.add_child(vbox)
		else:
			btn.text = display_name
			btn.add_theme_font_size_override("font_size", 18)

		# Hover scaling animation
		btn.mouse_entered.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)
		btn.mouse_exited.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)

		btn.pressed.connect(_on_game_selected.bind(game))
		grid_container.add_child(btn)

	# Tutorial TEG button
	var tutorial_btn = Button.new()
	tutorial_btn.text = "🎓 Tutorial TEG"
	_apply_button_theme(tutorial_btn, Color(0.55, 0.35, 0.75))
	tutorial_btn.custom_minimum_size = Vector2(310, 60)
	tutorial_btn.pivot_offset = Vector2(155, 30)
	tutorial_btn.add_theme_font_size_override("font_size", 18)
	tutorial_btn.mouse_entered.connect(func():
		var tw = tutorial_btn.create_tween()
		tw.tween_property(tutorial_btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	tutorial_btn.mouse_exited.connect(func():
		var tw = tutorial_btn.create_tween()
		tw.tween_property(tutorial_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	tutorial_btn.pressed.connect(func():
		if has_node("/root/SceneManager"):
			get_node("/root/SceneManager").transition_to("res://crisis_tutorial.gd")
		else:
			get_tree().change_scene_to_file("res://crisis_tutorial.gd")
	)
	grid_container.add_child(tutorial_btn)

	# Settings button
	var settings_btn = Button.new()
	settings_btn.text = "⚙️ " + tr("BTN_SETTINGS")
	_apply_button_theme(settings_btn, Color(0.35, 0.40, 0.45))
	settings_btn.custom_minimum_size = Vector2(310, 60)
	settings_btn.pivot_offset = Vector2(155, 30)
	settings_btn.add_theme_font_size_override("font_size", 18)
	settings_btn.mouse_entered.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	_apply_button_theme(replay_btn, Color(0.25, 0.50, 0.55))
	replay_btn.custom_minimum_size = Vector2(310, 60)
	replay_btn.pivot_offset = Vector2(155, 30)
	replay_btn.add_theme_font_size_override("font_size", 18)
	replay_btn.mouse_entered.connect(func():
		var tw = replay_btn.create_tween()
		tw.tween_property(replay_btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	_show_mode_popup(game)

func _load_settings_json() -> Dictionary:
	if FileAccess.file_exists("user://settings.json"):
		var f = FileAccess.open("user://settings.json", FileAccess.READ)
		if f != null:
			var txt = f.get_as_text()
			var json = JSON.new()
			if json.parse(txt) == OK and json.data is Dictionary:
				return json.data
	return {}

func _save_settings_json(data: Dictionary) -> void:
	var existing = _load_settings_json()
	for k in data.keys():
		existing[k] = data[k]
	var f = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(existing, "  "))

func _show_mode_popup(game: Dictionary) -> void:
	if is_instance_valid(current_popup_overlay):
		current_popup_overlay.queue_free()
		current_popup_overlay = null

	# Dim background
	grid_container.modulate.a = 0.5
	if has_node("Title"):
		get_node("Title").modulate.a = 0.5

	layout_changed.emit()

	var tr_key = "GAME_" + game["id"].to_upper()
	var display_name = tr(tr_key) if tr(tr_key) != tr_key else game["name"]
	var game_color: Color = game.get("color", Color(0.35, 0.45, 0.65))
	var saved_settings = _load_settings_json()
	var default_mode = saved_settings.get("default_mode", "hotseat")
	var saved_depth = int(saved_settings.get("chess_ai_depth", 2))

	var overlay = Control.new()
	overlay.name = "ModePopupOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	current_popup_overlay = overlay
	add_child(overlay)

	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.05, 0.08, 0.65)
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_mode_popup()
	)
	overlay.add_child(backdrop)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 290)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	style.border_color = game_color.lightened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header with Title and Close Button
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = display_name
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	header_hbox.add_child(title_lbl)

	var close_x = Button.new()
	close_x.text = "✕"
	close_x.custom_minimum_size = Vector2(32, 32)
	close_x.flat = true
	close_x.pressed.connect(_close_mode_popup)
	header_hbox.add_child(close_x)

	vbox.add_child(HSeparator.new())

	var prompt_lbl = Label.new()
	prompt_lbl.text = "Selecciona el modo de juego:"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 15)
	prompt_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(prompt_lbl)

	# Button 2 Players Hotseat
	var hotseat_btn = Button.new()
	hotseat_btn.text = "👥 2 Jugadores (Hotseat)"
	hotseat_btn.custom_minimum_size = Vector2(0, 48)
	hotseat_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_theme(hotseat_btn, Color(0.25, 0.45, 0.70))
	hotseat_btn.pressed.connect(func():
		_save_settings_json({"default_mode": "hotseat"})
		_launch_game(game, "hotseat")
	)
	vbox.add_child(hotseat_btn)

	# Button vs AI & Difficulty for chess
	var has_ai: bool = (game.get("ai_method", "") != "")
	var chess_diff_option: OptionButton = null

	if game["id"] == "chess" and has_ai:
		var diff_hbox = HBoxContainer.new()
		diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		diff_hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(diff_hbox)

		var diff_lbl = Label.new()
		diff_lbl.text = "Dificultad IA:"
		diff_lbl.add_theme_font_size_override("font_size", 14)
		diff_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		diff_hbox.add_child(diff_lbl)

		chess_diff_option = OptionButton.new()
		chess_diff_option.custom_minimum_size = Vector2(190, 32)
		chess_diff_option.add_item("Fácil (Profundidad 1)", 1)
		chess_diff_option.add_item("Medio (Profundidad 2)", 2)
		chess_diff_option.add_item("Difícil (Profundidad 3)", 3)
		var sel_idx = clampi(saved_depth - 1, 0, 2)
		chess_diff_option.selected = sel_idx
		diff_hbox.add_child(chess_diff_option)

	var ai_btn = Button.new()
	ai_btn.custom_minimum_size = Vector2(0, 48)
	ai_btn.add_theme_font_size_override("font_size", 16)

	if has_ai:
		ai_btn.text = "🤖 vs IA"
		_apply_button_theme(ai_btn, Color(0.70, 0.35, 0.35))
		ai_btn.pressed.connect(func():
			var depth = 2
			if chess_diff_option != null:
				depth = chess_diff_option.selected + 1
				_save_settings_json({"default_mode": "vs_ai", "chess_ai_depth": depth})
			else:
				_save_settings_json({"default_mode": "vs_ai"})
			_launch_game(game, "vs_ai", depth)
		)
	else:
		ai_btn.text = "🤖 vs IA (No disponible)"
		ai_btn.disabled = true
		var style_dis = StyleBoxFlat.new()
		style_dis.bg_color = Color(0.2, 0.2, 0.25, 0.5)
		style_dis.set_corner_radius_all(10)
		ai_btn.add_theme_stylebox_override("disabled", style_dis)
		ai_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))

	vbox.add_child(ai_btn)

	# Cancel Button
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(0, 36)
	_apply_button_theme(cancel_btn, Color(0.3, 0.3, 0.35))
	cancel_btn.pressed.connect(_close_mode_popup)
	vbox.add_child(cancel_btn)

	# Focus preferred mode
	if default_mode == "vs_ai" and has_ai:
		ai_btn.grab_focus()
	else:
		hotseat_btn.grab_focus()

func _close_mode_popup() -> void:
	if is_instance_valid(current_popup_overlay):
		current_popup_overlay.queue_free()
		current_popup_overlay = null

	grid_container.modulate.a = 1.0
	if has_node("Title"):
		get_node("Title").modulate.a = 1.0

func _launch_game(game: Dictionary, mode: String, depth: int = 2) -> void:
	_close_mode_popup()
	GameManager.set_active_game(game["id"])
	GameManager.set_game_mode(mode)

	if mode == "vs_ai":
		if game["id"] == "chess":
			GameManager.set_chess_ai_depth(depth)
			if bridge.has_method("start_local_match_chess_vs_ai"):
				bridge.call("start_local_match_chess_vs_ai", 1, 2, depth)
		elif game.get("ai_method", "") != "":
			var ai_method: String = game["ai_method"]
			if game["id"] == "checkers":
				if bridge.has_method(ai_method):
					bridge.call(ai_method, 42, 1, 2)
			elif game["id"] == "go":
				if bridge.has_method(ai_method):
					bridge.call(ai_method, 1, 2, 9)
			elif bridge.has_method(ai_method):
				bridge.call(ai_method, 1, 2)
	else:
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

func _setup_multiplayer_row() -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	hbox.position = Vector2(30, get_viewport_rect().size.y - 70)
	hbox.size = Vector2(get_viewport_rect().size.x - 60, 50)
	add_child(hbox)

	var host_btn := Button.new()
	host_btn.text = "🌐 Crear partida en red"
	host_btn.custom_minimum_size = Vector2(220, 44)
	host_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_theme(host_btn, Color(0.25, 0.45, 0.75))
	host_btn.pressed.connect(_on_host_pressed)
	hbox.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "📷 Unirse (código QR)"
	join_btn.custom_minimum_size = Vector2(220, 44)
	join_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_theme(join_btn, Color(0.35, 0.55, 0.35))
	join_btn.pressed.connect(_on_join_pressed)
	hbox.add_child(join_btn)

func _on_host_pressed() -> void:
	_show_game_selector_for_network()

func _on_join_pressed() -> void:
	var scanner := QRScanner.new()
	scanner.setup(bridge)
	scanner.connect("qr_scanned", func(ip: String, port: int):
		scanner.close()
		scanner.queue_free()
		bridge.call("connect_to_host", ip, port, 2)
		if has_node("/root/SceneManager"):
			get_node("/root/SceneManager").transition_to("res://checkers_board.tscn")
		else:
			get_tree().change_scene_to_file("res://checkers_board.tscn")
	)
	scanner.connect("closed", func():
		scanner.queue_free()
	)
	add_child(scanner)
	scanner.open(bridge)

func _show_game_selector_for_network() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 400)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "¿Qué juego quieres hostear?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	for game in GAMES:
		var btn := Button.new()
		btn.text = game["name"]
		btn.custom_minimum_size = Vector2(0, 36)
		var gid: String = game["id"]
		btn.pressed.connect(func():
			overlay.queue_free()
			_launch_host_lobby(gid)
		)
		vbox.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel)

func _launch_host_lobby(game_id: String) -> void:
	GameManager.set_active_game(game_id)
	GameManager.set_game_mode("host")
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://host_lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://host_lobby.tscn")


