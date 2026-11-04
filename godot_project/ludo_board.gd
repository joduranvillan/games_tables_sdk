# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Node2D

const MAX_PLAYERS = 4
const TOKENS_PER_PLAYER = 4
const BOARD_SIZE = 600.0

var bridge
var current_p = 1
var winner = -1
var last_dice_val = 0

# Player tokens: player_id -> Array of 4 step counts (0 = Base, 1..52 = Track, 53..57 = Home column, 58 = Goal)
var token_steps = {
	1: [0, 0, 0, 0],
	2: [0, 0, 0, 0],
	3: [0, 0, 0, 0],
	4: [0, 0, 0, 0]
}

# 52 track coordinates and home columns on 15x15 standard grid
const TRACK_GRID = [
	Vector2(1, 6), Vector2(2, 6), Vector2(3, 6), Vector2(4, 6), Vector2(5, 6),
	Vector2(6, 5), Vector2(6, 4), Vector2(6, 3), Vector2(6, 2), Vector2(6, 1), Vector2(6, 0),
	Vector2(7, 0),
	Vector2(8, 0), Vector2(8, 1), Vector2(8, 2), Vector2(8, 3), Vector2(8, 4), Vector2(8, 5),
	Vector2(9, 6), Vector2(10, 6), Vector2(11, 6), Vector2(12, 6), Vector2(13, 6), Vector2(14, 6),
	Vector2(14, 7),
	Vector2(14, 8), Vector2(13, 8), Vector2(12, 8), Vector2(11, 8), Vector2(10, 8), Vector2(9, 8),
	Vector2(8, 9), Vector2(8, 10), Vector2(8, 11), Vector2(8, 12), Vector2(8, 13), Vector2(8, 14),
	Vector2(7, 14),
	Vector2(6, 14), Vector2(6, 13), Vector2(6, 12), Vector2(6, 11), Vector2(6, 10), Vector2(6, 9),
	Vector2(5, 8), Vector2(4, 8), Vector2(3, 8), Vector2(2, 8), Vector2(1, 8), Vector2(0, 8),
	Vector2(0, 7),
	Vector2(0, 6)
]

const HOME_GRIDS = {
	1: [Vector2(1, 7), Vector2(2, 7), Vector2(3, 7), Vector2(4, 7), Vector2(5, 7)],
	2: [Vector2(7, 1), Vector2(7, 2), Vector2(7, 3), Vector2(7, 4), Vector2(7, 5)],
	3: [Vector2(13, 7), Vector2(12, 7), Vector2(11, 7), Vector2(10, 7), Vector2(9, 7)],
	4: [Vector2(7, 13), Vector2(7, 12), Vector2(7, 11), Vector2(7, 10), Vector2(7, 9)]
}

# UI elements
var token_buttons = {1: [], 2: [], 3: [], 4: []}
var dice_button: Button
var dice_label: Label
var dice_widget: DiceWidget
var mode_option_button: OptionButton
var rules_popup: RulesPopup

var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var _pause_menu: CanvasLayer

@onready var status: Label = get_node_or_null("Status")

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	var gm = (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)
	if is_inside_tree() and get_viewport() != null:
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)

	_setup_ui()
	
	var has_net_bridge: bool = (gm != null and gm.has_method("has_active_network_bridge") and bool(gm.call("has_active_network_bridge")))
	if has_net_bridge:
		bridge = gm.call("claim_network_bridge", self)
	else:
		bridge = OpenTableBridge.new()
		bridge.name = "Bridge"
		add_child(bridge)
	
	# HUD de red — solo en modo Host/Client, nunca en headless
	if not OS.has_feature("headless"):
		if bridge.has_method("is_network_mode") and bridge.call("is_network_mode"):
			var hud_script = load("res://network_status_hud.gd")
			if hud_script:
				var hud: Node = hud_script.new()
				if hud.has_method("setup"):
					hud.setup(bridge)
				elif hud.has_method("bind_bridge"):
					hud.bind_bridge(bridge)
				add_child(hud)

	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)

	if has_net_bridge:
		if mode_option_button != null:
			mode_option_button.selected = 0
	elif gm != null and gm.get_game_mode() == "vs_ai":
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else 1
		var ai_p: int = 2 if human_p == 1 else 1
		var diff: int = gm.get_ai_difficulty() if gm.has_method("get_ai_difficulty") else 1
		if bridge.has_method("set_ai_difficulty"):
			bridge.set_ai_difficulty(diff)
		bridge.start_local_match_ludo_vs_ai(human_p, ai_p)
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_p == 1 else 2
	else:
		bridge.start_local_match_ludo(1, 2)
		if mode_option_button != null:
			mode_option_button.selected = 0
	current_p = bridge.current_player()
	
	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_token_positions()
	_update_status()
	queue_redraw()

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_viewport_size_changed() -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	_on_layout_changed(gm.get_layout() if gm != null else 0)

func _on_quit_to_menu() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	var vp_size := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz := get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if _layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)
	var min_x := 20.0
	var min_y := -42.0
	var design_w := 560.0
	var design_h := 696.0
	var s := clampf(minf((vp_size.x - 40.0) / design_w, (vp_size.y - 24.0) / design_h), 0.30, 1.0)
	scale = Vector2(s, s)
	position = Vector2(
		(vp_size.x - design_w * s) * 0.5 - min_x * s,
		(vp_size.y - design_h * s) * 0.5 - min_y * s
	)

func _setup_ui() -> void:
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	status.position = Vector2(290, -32)

	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(120, -36)
	mode_option_button.custom_minimum_size = Vector2(360, 36)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano Rojo - J1)")
	mode_option_button.add_item("vs IA (Humano Azul - J2, IA inicia)")
	mode_option_button.visible = false
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	# --- ZONA SUPERIOR CENTRADA: Turno, reloj y estado ---
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(20, -36)
	add_child(turn_indicator)

	# --- ZONA INFERIOR CENTRADA: Acciones de turno (Tirar Dado y resultado) ---
	dice_widget = DiceWidget.new()
	dice_widget.position = Vector2(95, 592)
	add_child(dice_widget)

	dice_label = Label.new()
	dice_label.name = "DiceLabel"
	dice_label.position = Vector2(215, 584)
	dice_label.size = Vector2(120, 64)
	dice_label.pivot_offset = Vector2(60, 32)
	dice_label.text = "🎲 -"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.add_theme_font_size_override("font_size", 42)
	add_child(dice_label)

	dice_button = Button.new()
	dice_button.position = Vector2(345, 590)
	dice_button.custom_minimum_size = Vector2(170, 52)
	dice_button.text = "🎲 Tirar Dado"
	dice_button.add_theme_font_size_override("font_size", 18)
	dice_button.pressed.connect(_on_roll_dice_pressed)
	add_child(dice_button)

	var tutorial_btn := Button.new()
	tutorial_btn.name = "LudoTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(235, 590)
	tutorial_btn.custom_minimum_size = Vector2(130, 36)
	tutorial_btn.visible = false
	tutorial_btn.pressed.connect(start_ludo_tutorial)
	add_child(tutorial_btn)

	# Rules Button (Oculto: accesible desde el menú Opciones)
	var rules_btn = Button.new()
	rules_btn.name = "RulesButton"
	rules_btn.text = "📖 Reglas"
	rules_btn.position = Vector2(235, 590)
	rules_btn.custom_minimum_size = Vector2(115, 36)
	rules_btn.visible = false
	rules_btn.pressed.connect(func(): rules_popup.show_for_game("ludo"))
	add_child(rules_btn)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 80)
	add_child(rules_popup)
	
	# Create token circular buttons for players 1..4
	for p in range(1, 5):
		token_buttons[p] = []
		for t in range(TOKENS_PER_PLAYER):
			var btn = TextureButton.new()
			btn.custom_minimum_size = Vector2(30, 30)
			btn.size = Vector2(30, 30)
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_SCALE
			btn.pivot_offset = Vector2(15, 15)
			
			var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
			var p_col = _get_token_color(p)
			for x in range(32):
				for y in range(32):
					var dist = Vector2(x - 16, y - 16).length()
					if dist <= 12:
						var pattern_hit := _is_colorblind_pattern_pixel(p, x, y)
						img.set_pixel(x, y, p_col.lightened(0.38) if pattern_hit else p_col)
					elif dist <= 14:
						img.set_pixel(x, y, Color.BLACK)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
						
			btn.texture_normal = ImageTexture.create_from_image(img)
			
			var pid = p
			var tid = t
			btn.draw.connect(func():
				var font: Font = null
				if current_theme != null and current_theme.piece_font != null:
					font = current_theme.piece_font
				if font == null:
					font = ThemeDB.fallback_font
				var label_txt := _get_token_symbol(pid)
				btn.draw_string(font, Vector2(0, 20), label_txt, HORIZONTAL_ALIGNMENT_CENTER, 30, 13, Color.WHITE)
			)
			
			btn.pressed.connect(func(): _on_token_pressed(pid, tid))
			add_child(btn)
			token_buttons[p].append(btn)

func _get_token_color(player_id: int) -> Color:
	var fallback: Color = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(player_id) - 1, 6)] as Color)
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = get_node("/root/ThemeManager")
		if tm.has_method("is_colorblind_mode") and bool(tm.call("is_colorblind_mode")):
			if tm.has_method("get_player_color"):
				return tm.call("get_player_color", player_id, fallback)
	return fallback

func _get_token_symbol(player_id: int) -> String:
	match player_id:
		1: return "▲"
		2: return "●"
		3: return "■"
		4: return "◆"
		5: return "⬟"
		6: return "★"
		_: return str(player_id)

func start_ludo_tutorial() -> void:
	var LudoTut = load("res://scripts/tutorials/ludo_tutorial.gd")
	if LudoTut != null:
		LudoTut.start_on_board(self)

func _on_mode_selected(index: int) -> void:
	winner = -1
	last_dice_val = 0
	token_steps = {
		1: [0, 0, 0, 0],
		2: [0, 0, 0, 0],
		3: [0, 0, 0, 0],
		4: [0, 0, 0, 0]
	}
	_update_token_positions()
	if bridge != null:
		var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		var diff: int = gm.get_ai_difficulty() if (gm != null and gm.has_method("get_ai_difficulty")) else 1
		if bridge.has_method("set_ai_difficulty"):
			bridge.set_ai_difficulty(diff)
		match index:
			1:
				bridge.start_local_match_ludo_vs_ai(1, 2)
			2:
				bridge.start_local_match_ludo_vs_ai(2, 1)
			_:
				bridge.start_local_match_ludo(1, 2)
	current_p = bridge.current_player() if bridge else 1
	_update_status()
	queue_redraw()

func _is_colorblind_pattern_pixel(player_id: int, x: int, y: int) -> bool:
	match player_id:
		1:
			# Trama de líneas horizontales
			return (y % 4) == 0
		2:
			# Trama de líneas verticales
			return (x % 4) == 0
		3:
			# Trama de puntos
			return (x % 4 == 0) and (y % 4 == 0)
		4:
			# Trama diagonal / cruzada
			return ((x + y) % 5) == 0
		_:
			return false

func _on_roll_dice_pressed() -> void:
	_sfx_dice_roll()
	if winner != -1 or (dice_widget != null and dice_widget.is_rolling):
		return
	var cmd = {"command_type": "RollDiceCommand", "player": current_p}
	bridge.send_command_json(current_p, JSON.stringify(cmd))

func _on_token_pressed(p: int, token_idx: int) -> void:
	if winner != -1:
		return
	if p == current_p:
		if dice_widget != null and dice_widget.is_rolling:
			await dice_widget.wait_if_rolling()
		var cmd = {
			"command_type": "MoveTokenCommand",
			"player": current_p,
			"token_index": token_idx
		}
		bridge.send_command_json(current_p, JSON.stringify(cmd))

func _animate_dice_roll(val: int) -> void:
	last_dice_val = val
	var orig_pos = Vector2(215, 584)
	var tween = create_tween()
	
	# 0.4s vibration shake
	for i in range(8):
		var rand_offset = Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		tween.tween_property(dice_label, "position", orig_pos + rand_offset, 0.05)
		
	tween.tween_property(dice_label, "position", orig_pos, 0.04)
	
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

	if dice_widget != null:
		if dice_widget.has_method("roll_animation"):
			dice_widget.roll_animation(val, 0.4, 3)
		else:
			dice_widget.show_roll([val])

	tween.finished.connect(func():
		var faces = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
		if val >= 1 and val <= 6:
			dice_label.text = faces[val - 1]
		else:
			dice_label.text = "🎲 %d" % val
	)

func _spawn_particle_burst(global_pos: Vector2, color: Color) -> void:
	var particles = CPUParticles2D.new()
	particles.position = global_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.6
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = color
	add_child(particles)
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)

func get_cell_position(step: int, player: int = 1) -> Vector2:
	# 0 = Base
	if step == 0:
		var base_centers = {
			1: Vector2(125, 125),  # Red top-left
			2: Vector2(475, 125),  # Green top-right
			3: Vector2(475, 475),  # Yellow bottom-right
			4: Vector2(125, 475)   # Blue bottom-left
		}
		return base_centers.get(player, Vector2(125, 125))

	# 57/58 = Goal
	if step >= 58:
		return Vector2(300, 300)

	# Track calculation (1..52) and Home column (53..57)
	var margin = 55.0
	var track_step = 35.0

	if step <= 52:
		var idx = (step - 1 + (player - 1) * 13) % 52
		var g = TRACK_GRID[idx]
		return Vector2(margin + g.x * track_step, margin + g.y * track_step)
	else:
		var h_idx = clampi(step - 53, 0, 4)
		var g = HOME_GRIDS.get(player, HOME_GRIDS[1])[h_idx]
		return Vector2(margin + g.x * track_step, margin + g.y * track_step)

func _get_token_board_pos(player: int, token_idx: int, steps: int) -> Vector2:
	if steps == 0:
		var base_center = get_cell_position(0, player)
		var offsets = [Vector2(-25, -25), Vector2(25, -25), Vector2(-25, 25), Vector2(25, 25)]
		return base_center + offsets[token_idx]

	return get_cell_position(steps, player)

func get_path_from_to(from_cell: int, to_cell: int, player: int = 1, token_idx: int = 0) -> Array[Vector2]:
	var path: Array[Vector2] = []
	if from_cell == to_cell:
		return path
	
	if from_cell < to_cell:
		for s in range(from_cell + 1, to_cell + 1):
			path.append(_get_token_board_pos(player, token_idx, s))
	else:
		if to_cell == 0:
			path.append(_get_token_board_pos(player, token_idx, 0))
		else:
			for s in range(from_cell - 1, to_cell - 1, -1):
				path.append(_get_token_board_pos(player, token_idx, s))
	return path

func _update_token_positions() -> void:
	var occupancy: Dictionary = {}
	for p in range(1, 5):
		if not token_buttons.has(p) or token_buttons[p].size() < TOKENS_PER_PLAYER:
			continue
		for t in range(TOKENS_PER_PLAYER):
			var btn = token_buttons[p][t]
			var steps = token_steps[p][t]
			var base_pos = _get_token_board_pos(p, t, steps)
			var stack_offset := Vector2.ZERO
			if steps > 0:
				var key := "%d_%d" % [int(base_pos.x), int(base_pos.y)]
				var idx: int = occupancy.get(key, 0)
				occupancy[key] = idx + 1
				var stack_offsets := [Vector2.ZERO, Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]
				stack_offset = stack_offsets[idx % stack_offsets.size()]
			btn.position = base_pos + stack_offset - btn.size / 2.0

func _animate_token_move(p: int, t_idx: int, to_steps: int) -> void:
	var from_steps = token_steps[p][t_idx]
	token_steps[p][t_idx] = to_steps
	var btn = token_buttons[p][t_idx]
	var path = get_path_from_to(from_steps, to_steps, p, t_idx)
	
	if path.is_empty():
		var target_pos = _get_token_board_pos(p, t_idx, to_steps) - btn.size / 2.0
		btn.position = target_pos
		return

	if dice_widget != null and dice_widget.is_rolling and is_inside_tree() and not OS.has_feature("headless"):
		await dice_widget.wait_if_rolling()

	var tween = create_tween()
	for pos in path:
		var target_pos = pos - btn.size / 2.0
		tween.tween_property(btn, "position", target_pos, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if to_steps >= 58:
		tween.finished.connect(func():
			_spawn_particle_burst(btn.position + btn.size / 2.0, Color.GOLD)
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_piece_place(2.0)
		)
	else:
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_piece_place()

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type: String = str(event.get("command_type", event.get("event_type", "")))
			var event_type: String = raw_type.split("::")[-1]
			if event_type == "DiceRolledEvent":
				var val = int(event.get("value", 1))
				_animate_dice_roll(val)
			elif event_type == "TokenMovedEvent":
				var p = int(event.get("player", current_p))
				var t_idx = int(event.get("token_index", 0))
				var to_s = int(event.get("to_steps", 0))
				_animate_token_move(p, t_idx, to_s)
				
				if event.has("captured") and event["captured"] != null:
					var cap = event["captured"]
					var cap_p = int(cap[0])
					var cap_t = int(cap[1])
					var cap_pos = token_buttons[cap_p][cap_t].position
					_spawn_particle_burst(cap_pos + Vector2(15, 15), Color.RED)
					_animate_token_move(cap_p, cap_t, 0) # Return to base
					if (is_inside_tree() and has_node("/root/AudioManager")):
						get_node("/root/AudioManager").play_piece_place(2.0)
						
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))
				
	current_p = bridge.current_player()
	_update_status()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _draw() -> void:
	var bg_col = current_theme.board_color if current_theme != null else Color(0.95, 0.95, 0.95)
	var line_col = current_theme.line_color if current_theme != null else Color.BLACK

	# Main Board Outer Square
	var board_rect = Rect2(20, 20, 560, 560)
	draw_rect(board_rect, bg_col)
	draw_rect(board_rect, line_col, false, 3.0)
	
	# Base Corner Zones (4 Home bases)
	var zones = [
		{"rect": Rect2(20, 20, 210, 210), "col": ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(1) - 1, 6)] as Color)},
		{"rect": Rect2(370, 20, 210, 210), "col": ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(2) - 1, 6)] as Color)},
		{"rect": Rect2(370, 370, 210, 210), "col": ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(3) - 1, 6)] as Color)},
		{"rect": Rect2(20, 370, 210, 210), "col": ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(4) - 1, 6)] as Color)}
	]
	for z in zones:
		draw_rect(z.rect, z.col)
		draw_rect(z.rect, line_col, false, 2.5)
		var yard_center: Vector2 = z.rect.position + z.rect.size / 2.0
		draw_rect(Rect2(yard_center - Vector2(68, 68), Vector2(136, 136)), Color(0.98, 0.98, 0.96))
		draw_rect(Rect2(yard_center - Vector2(68, 68), Vector2(136, 136)), line_col, false, 2.0)
		for off in [Vector2(-25, -25), Vector2(25, -25), Vector2(-25, 25), Vector2(25, 25)]:
			draw_circle(yard_center + off, 16.0, z.col.lightened(0.25))
			draw_arc(yard_center + off, 16.0, 0.0, TAU, 24, line_col, 1.8)
		
	# Cross track 52 cells
	var margin = 55.0
	var track_step = 35.0
	for i in range(15):
		for j in range(15):
			# Skip 4 base corners and 3x3 center goal
			if (i < 6 and j < 6) or (i > 8 and j < 6) or (i < 6 and j > 8) or (i > 8 and j > 8):
				continue
			if i >= 6 and i <= 8 and j >= 6 and j <= 8:
				continue
			var cell_rect = Rect2(margin + i * track_step - 17.5, margin + j * track_step - 17.5, track_step, track_step)
			draw_rect(cell_rect, Color(0.99, 0.99, 0.97))
			draw_rect(cell_rect, line_col, false, 1.0)

	# Draw home columns
	for p in range(1, 5):
		var p_col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(p) - 1, 6)] as Color)
		var fill_col = Color(p_col.r, p_col.g, p_col.b, 0.55)
		for g in HOME_GRIDS[p]:
			var h_rect = Rect2(margin + g.x * track_step - 17.5, margin + g.y * track_step - 17.5, track_step, track_step)
			draw_rect(h_rect, fill_col)
			draw_rect(h_rect, line_col, false, 1.2)

	# Safe squares permanent highlight (start and star cells) with ★ icon
	var safe_color = Color(0.98, 0.90, 0.32, 0.55)
	var font: Font = ThemeDB.fallback_font
	for p in range(1, 5):
		var p_col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(p) - 1, 6)] as Color)
		for s in [1, 9]:
			var cpos = get_cell_position(s, p)
			var safe_rect = Rect2(cpos.x - 17.5, cpos.y - 17.5, track_step, track_step)
			draw_rect(safe_rect, Color(p_col.r, p_col.g, p_col.b, 0.45) if s == 1 else safe_color)
			draw_rect(safe_rect, line_col, false, 1.5)
			if font != null:
				draw_string(font, Vector2(cpos.x - 14.0, cpos.y + 6.0), "★", HORIZONTAL_ALIGNMENT_CENTER, 28.0, 16, Color(0.25, 0.18, 0.02))

	# Center Goal Zone (4 converging triangles)
	var center = Vector2(300, 300)
	var tl = Vector2(247.5, 247.5)
	var tr_pt = Vector2(352.5, 247.5)
	var br = Vector2(352.5, 352.5)
	var bl = Vector2(247.5, 352.5)
	draw_colored_polygon(PackedVector2Array([tl, bl, center]), Color.RED)
	draw_colored_polygon(PackedVector2Array([tl, tr_pt, center]), Color.BLUE)
	draw_colored_polygon(PackedVector2Array([tr_pt, br, center]), Color.GREEN)
	draw_colored_polygon(PackedVector2Array([bl, br, center]), Color.YELLOW)
	draw_rect(Rect2(tl, Vector2(105, 105)), line_col, false, 2.5)
	draw_line(tl, br, line_col, 2.0)
	draw_line(tr_pt, bl, line_col, 2.0)
	draw_circle(center, 16, Color(1.0, 0.96, 0.80))
	draw_arc(center, 16, 0.0, TAU, 24, Color.GOLD.darkened(0.25), 2.5)

func _update_status() -> void:
	if winner != -1:
		if status != null:
			status.text = "¡Todas las fichas completas! Ganó el jugador %s (Ludo)" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var p_name = "Jugador %s" % current_p
		var col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(current_p) - 1, 6)] as Color)
		if status != null:
			status.text = ""
		if turn_indicator != null:
			turn_indicator.set_turn(current_p, p_name, col)

# --- Conexión de eventos sonoros procedurales (AudioManager) ---
func _sfx_piece_slide() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_slide()

func _sfx_piece_place() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

func _sfx_capture(world_pos: Vector2 = Vector2(240, 240)) -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place(2.0)
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.45
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 110.0
	particles.color = Color(1.0, 0.85, 0.3, 0.9)
	add_child(particles)
	if is_inside_tree():
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)

func _sfx_dice_roll() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_dice_roll()

func _sfx_card_flip() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_card_flip()

func _sfx_check_alert() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_check_alert()

func _sfx_victory_fanfare() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()

func _sfx_error_buzz() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()
