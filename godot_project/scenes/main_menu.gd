# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
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
var privacy_modal: Node = null
var online_action_buttons: Array[Button] = []

var menu_scroll: ScrollContainer = null
var menu_center: CenterContainer = null
var multiplayer_bar: PanelContainer = null
var multiplayer_hbox: HBoxContainer = null
var game_buttons: Array[Button] = []
var utility_buttons: Array[Button] = []

const GAMES = [
	{ "id": "checkers", "name": "Damas (Checkers)", "method": "start_local_match_checkers", "ai_method": "start_local_match_checkers_vs_ai", "scene": "res://checkers_board.tscn", "color": Color(0.85, 0.25, 0.25) },
	{ "id": "chess", "name": "Ajedrez (Chess)", "method": "start_local_match_chess", "ai_method": "start_local_match_chess_vs_ai", "scene": "res://chess_board.tscn", "color": Color(0.35, 0.35, 0.75) },
	{ "id": "shogi", "name": "Shogi", "method": "start_local_match_shogi", "ai_method": "start_local_match_shogi_vs_ai", "scene": "res://shogi_board.tscn", "color": Color(0.85, 0.65, 0.25) },
	{ "id": "xiangqi", "name": "Xiangqi", "method": "start_local_match_xiangqi", "ai_method": "start_local_match_xiangqi_vs_ai", "scene": "res://xiangqi_board.tscn", "color": Color(0.85, 0.35, 0.15) },
	{ "id": "go", "name": "Go", "method": "start_local_match_go", "ai_method": "start_local_match_go_vs_ai", "scene": "res://go_board.tscn", "color": Color(0.25, 0.65, 0.45) },
	{ "id": "uno", "name": "Uno", "method": "start_local_match_uno", "ai_method": "start_local_match_uno_vs_ai", "scene": "res://uno_board.tscn", "color": Color(0.95, 0.25, 0.45) },
	{ "id": "crisis", "name": "Crisis", "method": "start_local_match_crisis", "ai_method": "start_local_match_crisis_vs_ai", "scene": "res://crisis_board.tscn", "color": Color(0.65, 0.25, 0.75) },
	{ "id": "chinese_checkers", "name": "Damas Chinas", "method": "start_local_match_chinese_checkers", "ai_method": "start_local_match_chinese_checkers_vs_ai", "scene": "res://chinese_checkers_board.tscn", "color": Color(0.25, 0.75, 0.75) },
	{ "id": "mille_bornes", "name": "Mille Bornes", "method": "start_local_match_mille_bornes", "ai_method": "start_local_match_mille_bornes_vs_ai", "scene": "res://mille_bornes_board.tscn", "color": Color(0.45, 0.75, 0.25) },
	{ "id": "backgammon", "name": "Backgammon", "method": "start_local_match_backgammon", "ai_method": "start_local_match_backgammon_vs_ai", "scene": "res://backgammon_board.tscn", "color": Color(0.75, 0.45, 0.25) },
	{ "id": "monopoly", "name": "Monopoly", "method": "start_local_match_monopoly", "ai_method": "start_local_match_monopoly_vs_ai", "scene": "res://monopoly_board.tscn", "color": Color(0.25, 0.65, 0.85) },
	{ "id": "ludo", "name": "Ludo", "method": "start_local_match_ludo", "ai_method": "start_local_match_ludo_vs_ai", "scene": "res://ludo_board.tscn", "color": Color(0.85, 0.85, 0.25) },
	{ "id": "battleship", "name": "Batalla Naval", "method": "start_local_match_battleship", "ai_method": "start_local_match_battleship_vs_ai", "scene": "res://battleship_board.tscn", "color": Color(0.25, 0.45, 0.85) },
	{ "id": "goose", "name": "Juego de la Oca", "method": "start_local_match_goose", "ai_method": "start_local_match_goose_vs_ai", "scene": "res://goose_board.tscn", "color": Color(0.92, 0.68, 0.16) }
]

@onready var grid_container: GridContainer = get_node_or_null("GridContainer")

func _ready() -> void:
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	_setup_responsive_containers()
	_setup_buttons()
	_setup_multiplayer_row()
	_update_responsive_layout()

	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_update_responsive_layout)

	_play_entry_animation()
	_check_and_show_privacy_modal()

func _setup_responsive_containers() -> void:
	if has_node("Title"):
		var title_node := get_node("Title") as Label
		if title_node != null:
			title_node.set_anchors_preset(Control.PRESET_TOP_WIDE)
			title_node.offset_left = 20.0
			title_node.offset_top = 14.0
			title_node.offset_right = -20.0
			title_node.offset_bottom = 58.0
			title_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if grid_container == null:
		grid_container = find_child("GridContainer", true, false) as GridContainer
	if grid_container == null:
		grid_container = GridContainer.new()
		grid_container.name = "GridContainer"
		add_child(grid_container)

	if menu_scroll == null:
		menu_scroll = ScrollContainer.new()
		menu_scroll.name = "MenuScrollContainer"
		menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		add_child(menu_scroll)

		menu_center = CenterContainer.new()
		menu_center.name = "MenuCenterContainer"
		menu_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		menu_scroll.add_child(menu_center)

		if grid_container.get_parent() != menu_center:
			if grid_container.get_parent() != null:
				grid_container.get_parent().remove_child(grid_container)
			menu_center.add_child(grid_container)

	grid_container.add_theme_constant_override("h_separation", 16)
	grid_container.add_theme_constant_override("v_separation", 12)

func _update_responsive_layout() -> void:
	var vp_size := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var r_sz := get_viewport_rect().size
		if r_sz.x > 0 and r_sz.y > 0:
			vp_size = r_sz

	if has_node("Title"):
		var title_node := get_node("Title") as Label
		if title_node != null:
			title_node.set_anchors_preset(Control.PRESET_TOP_LEFT)
			title_node.position = Vector2(20.0, 12.0)
			title_node.size = Vector2(vp_size.x - 40.0, 44.0)
			title_node.add_theme_font_size_override("font_size", 22 if vp_size.x < 700.0 else 28)

	var cols := 4
	var btn_w := 276.0
	var game_btn_h := 84.0
	var util_btn_h := 54.0

	if vp_size.x < 560.0:
		cols = 1
		btn_w = clampf(vp_size.x - 48.0, 240.0, 360.0)
		game_btn_h = 76.0
		util_btn_h = 50.0
	elif vp_size.x < 860.0:
		cols = 2
		btn_w = clampf((vp_size.x - 64.0) * 0.5, 220.0, 310.0)
		game_btn_h = 80.0
		util_btn_h = 52.0
	elif vp_size.x < 1140.0:
		cols = 3
		btn_w = clampf((vp_size.x - 84.0) / 3.0, 230.0, 290.0)
		game_btn_h = 82.0
		util_btn_h = 54.0
	else:
		cols = 4
		btn_w = clampf((vp_size.x - 120.0) / 4.0, 250.0, 285.0)
		game_btn_h = 84.0
		util_btn_h = 54.0

	if grid_container != null:
		grid_container.columns = cols

	for btn in game_buttons:
		if is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(btn_w, game_btn_h)
			btn.pivot_offset = Vector2(btn_w * 0.5, game_btn_h * 0.5)

	for btn in utility_buttons:
		if is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(btn_w, util_btn_h)
			btn.pivot_offset = Vector2(btn_w * 0.5, util_btn_h * 0.5)

	var bottom_bar_h := 60.0
	var top_offset := 62.0
	var scroll_h := maxf(200.0, vp_size.y - top_offset - bottom_bar_h - 14.0)

	if menu_scroll != null:
		menu_scroll.position = Vector2(16.0, top_offset)
		menu_scroll.size = Vector2(vp_size.x - 32.0, scroll_h)
	if menu_center != null:
		menu_center.custom_minimum_size = Vector2(vp_size.x - 32.0, scroll_h)

	if multiplayer_bar != null:
		var bar_w := minf(vp_size.x - 32.0, 920.0)
		multiplayer_bar.position = Vector2((vp_size.x - bar_w) * 0.5, vp_size.y - bottom_bar_h - 6.0)
		multiplayer_bar.size = Vector2(bar_w, bottom_bar_h - 4.0)

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

	var vp_w := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var banner = Panel.new()
	banner.position = Vector2((vp_w - 600.0) * 0.5, 650)
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
	var base_bg = Color(color.r, color.g, color.b, 0.88)
	var hover_border = color.lightened(0.35)
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
	style_hover.bg_color = Color(color.r, color.g, color.b, 0.98)
	style_hover.border_color = hover_border
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(10)
	style_hover.shadow_color = shadow_c
	style_hover.shadow_size = 5
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
	online_action_buttons.clear()
	game_buttons.clear()
	utility_buttons.clear()
	for child in grid_container.get_children():
		child.queue_free()

	for game in GAMES:
		var btn = Button.new()
		var tr_key = "GAME_" + game["id"].to_upper()
		var display_name = tr(tr_key) if tr(tr_key) != tr_key else game["name"]
		var color = game.get("color", Color(0.35, 0.45, 0.65))

		_apply_button_theme(btn, color)
		btn.custom_minimum_size = Vector2(276, 84)
		btn.pivot_offset = Vector2(138, 42)

		var icon_tex = _load_game_icon(game["id"])
		if icon_tex != null:
			btn.text = ""
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_theme_constant_override("separation", 4)

			var icon_rect = TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(42, 42)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(icon_rect)

			var lbl = Label.new()
			lbl.text = display_name
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(lbl)

			btn.add_child(vbox)
		else:
			btn.text = display_name
			btn.add_theme_font_size_override("font_size", 17)

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
		game_buttons.append(btn)

	# Tutorial TEG button
	var tutorial_btn = Button.new()
	tutorial_btn.text = "🎓 Tutorial TEG"
	_apply_button_theme(tutorial_btn, Color(0.55, 0.35, 0.75))
	tutorial_btn.custom_minimum_size = Vector2(276, 54)
	tutorial_btn.pivot_offset = Vector2(138, 27)
	tutorial_btn.add_theme_font_size_override("font_size", 16)
	tutorial_btn.mouse_entered.connect(func():
		var tw = tutorial_btn.create_tween()
		tw.tween_property(tutorial_btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	tutorial_btn.mouse_exited.connect(func():
		var tw = tutorial_btn.create_tween()
		tw.tween_property(tutorial_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	tutorial_btn.pressed.connect(func():
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://crisis_tutorial.gd")
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file("res://crisis_tutorial.gd")
	)
	grid_container.add_child(tutorial_btn)
	utility_buttons.append(tutorial_btn)

	# Settings button
	var settings_btn = Button.new()
	settings_btn.text = "⚙️ " + tr("BTN_SETTINGS")
	_apply_button_theme(settings_btn, Color(0.35, 0.40, 0.45))
	settings_btn.custom_minimum_size = Vector2(276, 54)
	settings_btn.pivot_offset = Vector2(138, 27)
	settings_btn.add_theme_font_size_override("font_size", 16)
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
	utility_buttons.append(settings_btn)

	# Repeticiones button
	var replay_btn = Button.new()
	replay_btn.text = "🎬 Repeticiones"
	_apply_button_theme(replay_btn, Color(0.25, 0.50, 0.55))
	replay_btn.custom_minimum_size = Vector2(276, 54)
	replay_btn.pivot_offset = Vector2(138, 27)
	replay_btn.add_theme_font_size_override("font_size", 16)
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
	utility_buttons.append(replay_btn)

	# Clasificación Global ELO button
	var leaderboard_btn = Button.new()
	leaderboard_btn.text = "🏆 Clasificación"
	_apply_button_theme(leaderboard_btn, Color(0.70, 0.52, 0.15))
	leaderboard_btn.custom_minimum_size = Vector2(276, 54)
	leaderboard_btn.pivot_offset = Vector2(138, 27)
	leaderboard_btn.add_theme_font_size_override("font_size", 16)
	leaderboard_btn.mouse_entered.connect(func():
		var tw = leaderboard_btn.create_tween()
		tw.tween_property(leaderboard_btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	leaderboard_btn.mouse_exited.connect(func():
		var tw = leaderboard_btn.create_tween()
		tw.tween_property(leaderboard_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	leaderboard_btn.pressed.connect(func():
		if not is_online_mode_allowed():
			return
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://scenes/leaderboard.tscn")
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
	)
	grid_container.add_child(leaderboard_btn)
	utility_buttons.append(leaderboard_btn)
	online_action_buttons.append(leaderboard_btn)

	# Mis Estadísticas Locales button
	var stats_btn = Button.new()
	stats_btn.name = "StatsButton"
	stats_btn.text = "📊 Mis Estadísticas"
	_apply_button_theme(stats_btn, Color(0.22, 0.54, 0.72))
	stats_btn.custom_minimum_size = Vector2(276, 54)
	stats_btn.pivot_offset = Vector2(138, 27)
	stats_btn.add_theme_font_size_override("font_size", 16)
	stats_btn.mouse_entered.connect(func():
		var tw = stats_btn.create_tween()
		tw.tween_property(stats_btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	stats_btn.mouse_exited.connect(func():
		var tw = stats_btn.create_tween()
		tw.tween_property(stats_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	stats_btn.pressed.connect(func():
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://scenes/stats_screen.tscn")
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scenes/stats_screen.tscn")
	)
	grid_container.add_child(stats_btn)
	utility_buttons.append(stats_btn)

	# Torneo button
	var tournament_btn = Button.new()
	tournament_btn.text = "🏟 Torneo"
	_apply_button_theme(tournament_btn, Color(0.65, 0.25, 0.35))
	tournament_btn.custom_minimum_size = Vector2(276, 54)
	tournament_btn.pivot_offset = Vector2(138, 27)
	tournament_btn.add_theme_font_size_override("font_size", 16)
	tournament_btn.mouse_entered.connect(func():
		var tw = tournament_btn.create_tween()
		tw.tween_property(tournament_btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	tournament_btn.mouse_exited.connect(func():
		var tw = tournament_btn.create_tween()
		tw.tween_property(tournament_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	tournament_btn.pressed.connect(func():
		if not is_online_mode_allowed():
			return
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://scenes/tournament_lobby.tscn")
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scenes/tournament_lobby.tscn")
	)
	grid_container.add_child(tournament_btn)
	utility_buttons.append(tournament_btn)
	online_action_buttons.append(tournament_btn)

func _play_entry_animation() -> void:
	var buttons = grid_container.get_children()
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.modulate.a = 0.0
		var delay = i * 0.03
		var tw = create_tween()
		tw.tween_interval(delay)
		tw.tween_property(btn, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_settings_pressed() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://settings_menu.tscn")
	else:
		if is_inside_tree():
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
		if is_inside_tree() and has_node("/root/GameManager"):
			get_node("/root/GameManager").set_replay_data(bytes, "checkers")
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://replay_viewer.tscn")
	else:
		if is_inside_tree():
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

func _load_ai_difficulty_cfg() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		return clampi(int(cfg.get_value("ai", "difficulty", 1)), 0, 3)
	return 1

func _save_ai_difficulty_cfg(difficulty_level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("ai", "difficulty", clampi(difficulty_level, 0, 3))
	cfg.save("user://settings.cfg")

func _show_mode_popup(game: Dictionary) -> void:
	if is_instance_valid(current_popup_overlay):
		current_popup_overlay.queue_free()
		current_popup_overlay = null

	# Dim background
	if grid_container != null:
		grid_container.modulate.a = 0.5
	if has_node("Title"):
		get_node("Title").modulate.a = 0.5

	layout_changed.emit()

	var tr_key = "GAME_" + game["id"].to_upper()
	var display_name = tr(tr_key) if tr(tr_key) != tr_key else game["name"]
	var game_color: Color = game.get("color", Color(0.35, 0.45, 0.65))
	var saved_settings: Dictionary = _load_settings_json()
	var default_mode: String = str(saved_settings.get("default_mode", "hotseat"))
	var saved_depth: int = int(saved_settings.get("chess_ai_depth", 2))
	var saved_human_side: int = int(saved_settings.get("human_player_id", 1))

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
	panel.custom_minimum_size = Vector2(440, 340)
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
	vbox.add_theme_constant_override("separation", 12)
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
	hotseat_btn.custom_minimum_size = Vector2(0, 46)
	hotseat_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_theme(hotseat_btn, Color(0.25, 0.45, 0.70))
	hotseat_btn.pressed.connect(func():
		_save_settings_json({"default_mode": "hotseat"})
		_launch_game(game, "hotseat", 1, 1)
	)
	vbox.add_child(hotseat_btn)

	# Button vs AI & Selector de Dificultad y Bando
	var has_ai: bool = (game.get("ai_method", "") != "")
	var diff_option: OptionButton = null
	var side_option: OptionButton = null
	var saved_diff_level: int = clampi(int(saved_settings.get("ai_difficulty", saved_depth - 1)), 0, 3)
	if saved_settings.is_empty():
		saved_diff_level = _load_ai_difficulty_cfg()

	if has_ai:
		var game_hbox = HBoxContainer.new()
		game_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		game_hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(game_hbox)

		var game_lbl = Label.new()
		game_lbl.text = "Juego (vs IA):"
		game_lbl.add_theme_font_size_override("font_size", 14)
		game_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		game_hbox.add_child(game_lbl)

		var game_option = OptionButton.new()
		game_option.name = "AiGameOptionButton"
		game_option.custom_minimum_size = Vector2(210, 32)
		var selected_game_idx := 0
		var ai_idx := 0
		for g in GAMES:
			if g.get("ai_method", "") != "":
				game_option.add_item("%s (vs IA)" % g["name"], ai_idx)
				if g["id"] == game["id"]:
					selected_game_idx = ai_idx
				ai_idx += 1
		game_option.selected = selected_game_idx
		game_hbox.add_child(game_option)

		var side_hbox = HBoxContainer.new()
		side_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		side_hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(side_hbox)

		var side_lbl = Label.new()
		side_lbl.text = "Tu bando:"
		side_lbl.add_theme_font_size_override("font_size", 14)
		side_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		side_hbox.add_child(side_lbl)

		side_option = OptionButton.new()
		side_option.name = "AiSideOptionButton"
		side_option.custom_minimum_size = Vector2(210, 32)
		side_option.add_item("Jugador 1 (Tú inicias)", 0)
		side_option.add_item("Jugador 2 (IA inicia)", 1)
		side_option.selected = 1 if saved_human_side == 2 else 0
		side_hbox.add_child(side_option)

		var diff_hbox = HBoxContainer.new()
		diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		diff_hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(diff_hbox)

		var diff_lbl = Label.new()
		diff_lbl.text = "Dificultad:"
		diff_lbl.add_theme_font_size_override("font_size", 14)
		diff_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		diff_hbox.add_child(diff_lbl)

		diff_option = OptionButton.new()
		diff_option.custom_minimum_size = Vector2(210, 32)
		diff_option.add_item("Fácil", 0)
		diff_option.add_item("Normal", 1)
		diff_option.add_item("Difícil", 2)
		diff_option.add_item("Experto", 3)
		diff_option.selected = clampi(saved_diff_level, 0, 3)
		diff_hbox.add_child(diff_option)

	var ai_btn = Button.new()
	ai_btn.custom_minimum_size = Vector2(0, 46)
	ai_btn.add_theme_font_size_override("font_size", 16)

	if has_ai:
		ai_btn.text = "🤖 Jugar vs IA"
		_apply_button_theme(ai_btn, Color(0.70, 0.35, 0.35))
		ai_btn.pressed.connect(func():
			var difficulty_level := 1
			if diff_option != null:
				difficulty_level = clampi(diff_option.selected, 0, 3)
			var human_side := 1
			if side_option != null and side_option.selected == 1:
				human_side = 2
			_save_ai_difficulty_cfg(difficulty_level)
			_save_settings_json({
				"default_mode": "vs_ai",
				"chess_ai_depth": difficulty_level + 1,
				"ai_difficulty": difficulty_level,
				"human_player_id": human_side
			})
			_launch_game(game, "vs_ai", difficulty_level, human_side)
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

	# Botones de Red Local / Código QR (Offline sin servidor) dentro del popup de cada juego
	var qr_net_hbox = HBoxContainer.new()
	qr_net_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_net_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(qr_net_hbox)

	var host_qr_btn = Button.new()
	host_qr_btn.name = "HostQrPopupButton"
	host_qr_btn.text = "📡 Crear Partida QR / LAN"
	host_qr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_qr_btn.custom_minimum_size = Vector2(185, 42)
	host_qr_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(host_qr_btn, Color(0.22, 0.52, 0.68))
	var popup_game_id: String = str(game["id"])
	host_qr_btn.pressed.connect(func():
		_close_mode_popup()
		_launch_host_lobby(popup_game_id, false)
	)
	qr_net_hbox.add_child(host_qr_btn)

	var scan_qr_btn = Button.new()
	scan_qr_btn.name = "ScanQrPopupButton"
	scan_qr_btn.text = "📷 Escanear QR / Unirse"
	scan_qr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_qr_btn.custom_minimum_size = Vector2(185, 42)
	scan_qr_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(scan_qr_btn, Color(0.28, 0.58, 0.36))
	scan_qr_btn.pressed.connect(func():
		_close_mode_popup()
		_on_join_pressed(popup_game_id)
	)
	qr_net_hbox.add_child(scan_qr_btn)

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

	if grid_container != null:
		grid_container.modulate.a = 1.0
	if has_node("Title"):
		get_node("Title").modulate.a = 1.0

func _launch_game(game: Dictionary, mode: String, difficulty_level: int = 1, human_player: int = 1) -> void:
	_close_mode_popup()
	var human_p: int = 2 if human_player == 2 else 1
	var ai_p: int = 1 if human_p == 2 else 2

	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("clear_network_bridge"):
			gm.call("clear_network_bridge")
		gm.set_active_game(game["id"])
		gm.set_game_mode(mode)
		if gm.has_method("set_human_player_id"):
			gm.set_human_player_id(human_p)
		if gm.has_method("set_ai_difficulty"):
			gm.set_ai_difficulty(difficulty_level)
		gm.set_chess_ai_depth(difficulty_level + 1)

	if mode == "vs_ai":
		var board_size: int = 9
		if bridge.has_method("set_ai_difficulty"):
			bridge.call("set_ai_difficulty", difficulty_level)
		if game["id"] == "chess":
			if bridge.has_method("start_local_match_chess_vs_ai"):
				bridge.call("start_local_match_chess_vs_ai", human_p, ai_p, difficulty_level)
		elif game.get("ai_method", "") != "":
			var ai_method: String = game["ai_method"]
			if game["id"] == "checkers":
				if bridge.has_method(ai_method):
					bridge.call(ai_method, 42, human_p, ai_p)
			elif game["id"] == "go":
				if bridge.has_method("start_local_match_go_vs_ai_ext"):
					bridge.call("start_local_match_go_vs_ai_ext", human_p, ai_p, board_size, difficulty_level)
				elif bridge.has_method(ai_method):
					bridge.call(ai_method, human_p, ai_p, board_size)
			elif game["id"] in ["shogi", "uno", "crisis", "chinese_checkers", "mille_bornes", "monopoly", "battleship"]:
				if bridge.has_method(ai_method):
					bridge.call(ai_method, human_p, ai_p, difficulty_level)
			elif bridge.has_method(ai_method):
				bridge.call(ai_method, human_p, ai_p)
	else:
		var method_name: String = game["method"]
		if game["id"] == "crisis":
			if bridge.has_method(method_name):
				bridge.call(method_name, 42, [1, 2])
		elif bridge.has_method(method_name):
			bridge.call(method_name, 1, 2)
		elif bridge.has_method("start_local_match"):
			bridge.call("start_local_match", 1, 2)

	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_game_theme(game["id"])
	elif Engine.has_singleton("ThemeManager"):
		if is_inside_tree() and has_node("/root/ThemeManager"):
			get_node("/root/ThemeManager").apply_game_theme(game["id"])

	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to(game["scene"])
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file(game["scene"])

func _setup_multiplayer_row() -> void:
	multiplayer_bar = PanelContainer.new()
	multiplayer_bar.name = "MultiplayerBarPanel"
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.09, 0.11, 0.15, 0.92)
	bar_style.border_color = Color(0.25, 0.32, 0.45, 0.7)
	bar_style.set_border_width_all(1)
	bar_style.set_corner_radius_all(10)
	bar_style.content_margin_left = 12
	bar_style.content_margin_right = 12
	bar_style.content_margin_top = 5
	bar_style.content_margin_bottom = 5
	multiplayer_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(multiplayer_bar)

	multiplayer_hbox = HBoxContainer.new()
	multiplayer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	multiplayer_hbox.add_theme_constant_override("separation", 14)
	multiplayer_bar.add_child(multiplayer_hbox)

	var host_btn := Button.new()
	host_btn.name = "HostNetworkButton"
	host_btn.text = "🌐 Crear partida (QR / Red)"
	host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_btn.custom_minimum_size = Vector2(180, 42)
	host_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(host_btn, Color(0.25, 0.45, 0.75))
	host_btn.pressed.connect(_on_host_pressed)
	multiplayer_hbox.add_child(host_btn)

	var join_code_btn := Button.new()
	join_code_btn.name = "JoinCodeButton"
	join_code_btn.text = "🔑 Unirse con Código"
	join_code_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_code_btn.custom_minimum_size = Vector2(170, 42)
	join_code_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(join_code_btn, Color(0.25, 0.60, 0.55))
	join_code_btn.pressed.connect(_on_join_code_pressed)
	multiplayer_hbox.add_child(join_code_btn)
	online_action_buttons.append(join_code_btn)

	var join_btn := Button.new()
	join_btn.name = "JoinQrButton"
	join_btn.text = "📷 Unirse (código QR)"
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn.custom_minimum_size = Vector2(170, 42)
	join_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(join_btn, Color(0.35, 0.55, 0.35))
	join_btn.pressed.connect(func(): _on_join_pressed("checkers"))
	multiplayer_hbox.add_child(join_btn)

	var about_btn := Button.new()
	about_btn.text = "ℹ️ Acerca de"
	about_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about_btn.custom_minimum_size = Vector2(140, 42)
	about_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(about_btn, Color(0.45, 0.35, 0.65))
	about_btn.pressed.connect(func():
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://credits_screen.tscn")
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file("res://credits_screen.tscn")
	)
	multiplayer_hbox.add_child(about_btn)

func _on_host_pressed() -> void:
	_show_game_selector_for_network()

func _on_join_code_pressed() -> void:
	if not is_online_mode_allowed():
		return
	var dialog_script = load("res://join_dialog.gd")
	if dialog_script == null:
		return
	var dialog: Control = dialog_script.new()
	add_child(dialog)
	dialog.setup(bridge)
	dialog.connect("join_completed", func(success: bool, _player_id: int):
		if success:
			dialog.close()
			dialog.queue_free()
			var gm_ref = get_node_or_null("/root/GameManager") if is_inside_tree() else null
			var active_id: String = String(gm_ref.active_game) if gm_ref != null and "active_game" in gm_ref and not String(gm_ref.active_game).is_empty() else "checkers"
			var scene_path := "res://%s_board.tscn" % active_id
			if not ResourceLoader.exists(scene_path):
				scene_path = "res://checkers_board.tscn"
			if (is_inside_tree() and has_node("/root/SceneManager")):
				get_node("/root/SceneManager").transition_to(scene_path)
			else:
				if is_inside_tree():
					get_tree().change_scene_to_file(scene_path)
	)
	dialog.connect("closed", func():
		dialog.queue_free()
	)
	dialog.open(bridge)

func _on_join_pressed(default_game_id: String = "checkers") -> void:
	var scanner := QRScanner.new()
	scanner.auto_connect_on_scan = false
	scanner.setup(bridge)
	scanner.qr_payload_decoded.connect(func(payload: Dictionary):
		var ip: String = str(payload.get("ip", "127.0.0.1"))
		var port: int = int(payload.get("port", 9090))
		var target_game: String = str(payload.get("game_type", ""))
		if target_game.is_empty():
			target_game = default_game_id if not default_game_id.is_empty() else "checkers"
		scanner.close()
		scanner.queue_free()
		if bridge != null and bridge.has_method("connect_to_host"):
			bridge.call("connect_to_host", ip, port, "Jugador2")
		elif bridge != null and bridge.has_method("connect_as_client"):
			bridge.call("connect_as_client", ip, port)
		if is_inside_tree() and has_node("/root/GameManager"):
			var gm = get_node("/root/GameManager")
			if gm.has_method("register_network_bridge"):
				gm.call("register_network_bridge", bridge, "client", 2, target_game)
		var scene_path: String = "res://%s_board.tscn" % target_game
		if not ResourceLoader.exists(scene_path):
			scene_path = "res://checkers_board.tscn"
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to(scene_path)
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file(scene_path)
	)
	scanner.connect("closed", func():
		if is_instance_valid(scanner):
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
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(460, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.18, 0.98)
	style.border_color = Color(0.35, 0.55, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "¿Qué juego quieres hostear?"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var net_grid := GridContainer.new()
	net_grid.columns = 2
	net_grid.add_theme_constant_override("h_separation", 10)
	net_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(net_grid)

	for game in GAMES:
		var btn := Button.new()
		btn.text = game["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(200, 38)
		_apply_button_theme(btn, game.get("color", Color(0.3, 0.45, 0.7)))
		var gid: String = game["id"]
		btn.pressed.connect(func():
			overlay.queue_free()
			_launch_host_lobby(gid)
		)
		net_grid.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.custom_minimum_size = Vector2(0, 38)
	_apply_button_theme(cancel, Color(0.35, 0.35, 0.4))
	cancel.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel)

func _launch_host_lobby(game_id: String, require_online: bool = false) -> void:
	if require_online and not is_online_mode_allowed():
		return
	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.set_active_game(game_id)
		gm.set_game_mode("host")
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://host_lobby.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://host_lobby.tscn")

func _check_and_show_privacy_modal(settings_path: String = "user://settings.cfg") -> bool:
	var modal_script = load("res://scenes/privacy_consent_modal.gd")
	if modal_script == null:
		return false
	if not modal_script.should_show_on_startup(settings_path):
		var allow_online: bool = modal_script.is_online_enabled(settings_path)
		_apply_online_mode_state(allow_online)
		return false

	if is_instance_valid(privacy_modal):
		privacy_modal.queue_free()

	privacy_modal = modal_script.new(settings_path)
	privacy_modal.name = "PrivacyConsentModal"
	add_child(privacy_modal)
	privacy_modal.consent_completed.connect(func(allow_online: bool):
		_apply_online_mode_state(allow_online)
	)
	return true

func is_online_mode_allowed(settings_path: String = "user://settings.cfg") -> bool:
	var modal_script = load("res://scenes/privacy_consent_modal.gd")
	if modal_script != null:
		return modal_script.is_online_enabled(settings_path)
	return true

func _apply_online_mode_state(allow_online: bool) -> void:
	if (is_inside_tree() and has_node("/root/GameManager")):
		var gm = get_node("/root/GameManager")
		if gm.has_method("set_online_features_enabled"):
			gm.call("set_online_features_enabled", allow_online)
	if (is_inside_tree() and has_node("/root/AuthClient")):
		var auth = get_node("/root/AuthClient")
		if auth.has_method("set_online_enabled"):
			auth.call("set_online_enabled", allow_online)
	for btn in online_action_buttons:
		if is_instance_valid(btn):
			btn.disabled = not allow_online
			btn.tooltip_text = "" if allow_online else "Deshabilitado en Modo Solo Local / Offline"
