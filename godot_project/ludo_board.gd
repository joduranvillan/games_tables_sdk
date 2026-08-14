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

# UI elements
var token_buttons = {1: [], 2: [], 3: [], 4: []}
var dice_button: Button
var dice_label: Label
var dice_widget: DiceWidget
var rules_popup: RulesPopup

var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD

@onready var status: Label = $Status

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	_setup_ui()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	if network_hud != null:
		network_hud.bind_bridge(bridge)

	bridge.start_local_match_ludo(1, 2)
	current_p = bridge.current_player()
	
	_update_token_positions()
	_update_status()
	queue_redraw()

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	queue_redraw()

func _setup_ui() -> void:
	# Dice Roll Button
	dice_button = Button.new()
	dice_button.position = Vector2(640, 150)
	dice_button.custom_minimum_size = Vector2(140, 60)
	dice_button.text = "Tirar Dado"
	dice_button.add_theme_font_size_override("font_size", 18)
	dice_button.pressed.connect(_on_roll_dice_pressed)
	add_child(dice_button)
	
	# Dice Result Display
	dice_label = Label.new()
	dice_label.name = "DiceLabel"
	dice_label.position = Vector2(640, 220)
	dice_label.size = Vector2(140, 100)
	dice_label.pivot_offset = Vector2(70, 50)
	dice_label.text = "🎲 -"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.add_theme_font_size_override("font_size", 48)
	add_child(dice_label)

	dice_widget = DiceWidget.new()
	dice_widget.position = Vector2(640, 320)
	add_child(dice_widget)

	# Rules Button
	var rules_btn = Button.new()
	rules_btn.text = " ? "
	rules_btn.position = Vector2(675, 10)
	rules_btn.custom_minimum_size = Vector2(36, 36)
	rules_btn.pressed.connect(func(): rules_popup.show_for_game("ludo"))
	add_child(rules_btn)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 80)
	add_child(rules_popup)

	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(20, 595)
	add_child(turn_indicator)

	# Network Status HUD
	network_hud = NetworkStatusHUD.new()
	network_hud.name = "NetworkStatusHUD"
	add_child(network_hud)
	
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
			var p_col = GameManager.get_player_color(p)
			for x in range(32):
				for y in range(32):
					var dist = Vector2(x - 16, y - 16).length()
					if dist <= 12:
						img.set_pixel(x, y, p_col)
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
				btn.draw_string(font, Vector2(0, 20), str(pid), HORIZONTAL_ALIGNMENT_CENTER, 30, 14, Color.WHITE)
			)
			
			btn.pressed.connect(func(): _on_token_pressed(pid, tid))
			add_child(btn)
			token_buttons[p].append(btn)

func _on_roll_dice_pressed() -> void:
	if winner != -1:
		return
	var cmd = {"command_type": "RollDiceCommand", "player": current_p}
	bridge.send_command_json(current_p, JSON.stringify(cmd))

func _on_token_pressed(p: int, token_idx: int) -> void:
	if winner != -1:
		return
	if p == current_p:
		var cmd = {
			"command_type": "MoveTokenCommand",
			"player": current_p,
			"token_index": token_idx
		}
		bridge.send_command_json(current_p, JSON.stringify(cmd))

func _animate_dice_roll(val: int) -> void:
	last_dice_val = val
	var orig_pos = Vector2(640, 220)
	var tween = create_tween()
	
	# 0.4s vibration shake
	for i in range(8):
		var rand_offset = Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		tween.tween_property(dice_label, "position", orig_pos + rand_offset, 0.05)
		
	tween.tween_property(dice_label, "position", orig_pos, 0.04)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_move()

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

func _get_token_board_pos(player: int, token_idx: int, steps: int) -> Vector2:
	# 0 = Base
	if steps == 0:
		var base_corners = {
			1: Vector2(80, 80),    # Red top-left
			2: Vector2(440, 80),   # Green top-right
			3: Vector2(440, 440),  # Yellow bottom-right
			4: Vector2(80, 440)    # Blue bottom-left
		}
		var offsets = [Vector2(-25, -25), Vector2(25, -25), Vector2(-25, 25), Vector2(25, 25)]
		return base_corners.get(player, Vector2(80, 80)) + offsets[token_idx]
		
	# 58 = Goal
	if steps >= 58:
		return Vector2(300, 300)
		
	# Track calculation (1..52) and Home column (53..57)
	var margin = 40.0
	var track_step = 35.0
	
	if steps <= 52:
		var p = (steps + (player - 1) * 13) % 52
		if p < 6: return Vector2(margin + (6 + p) * track_step, margin + 6 * track_step)
		elif p < 12: return Vector2(margin + 12 * track_step, margin + (5 - (p - 6)) * track_step)
		elif p < 18: return Vector2(margin + (12 - (p - 12)) * track_step, margin)
		elif p < 24: return Vector2(margin + 6 * track_step, margin + (p - 18) * track_step)
		elif p < 30: return Vector2(margin + (5 - (p - 24)) * track_step, margin + 6 * track_step)
		elif p < 36: return Vector2(margin, margin + (6 + (p - 30)) * track_step)
		elif p < 42: return Vector2(margin + (p - 36) * track_step, margin + 12 * track_step)
		else: return Vector2(margin + 6 * track_step, margin + (12 - (p - 42)) * track_step)
	else:
		var home_dist = steps - 52
		match player:
			1: return Vector2(margin + home_dist * track_step, margin + 6 * track_step)
			2: return Vector2(margin + 6 * track_step, margin + home_dist * track_step)
			3: return Vector2(margin + (12 - home_dist) * track_step, margin + 6 * track_step)
			4: return Vector2(margin + 6 * track_step, margin + (12 - home_dist) * track_step)
	return Vector2(300, 300)

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
	for p in range(1, 5):
		for t in range(TOKENS_PER_PLAYER):
			var btn = token_buttons[p][t]
			var steps = token_steps[p][t]
			var target_pos = _get_token_board_pos(p, t, steps) - btn.size / 2.0
			btn.position = target_pos

func _animate_token_move(p: int, t_idx: int, to_steps: int) -> void:
	var from_steps = token_steps[p][t_idx]
	token_steps[p][t_idx] = to_steps
	var btn = token_buttons[p][t_idx]
	var path = get_path_from_to(from_steps, to_steps, p, t_idx)
	
	if path.is_empty():
		var target_pos = _get_token_board_pos(p, t_idx, to_steps) - btn.size / 2.0
		btn.position = target_pos
		return

	var tween = create_tween()
	for pos in path:
		var target_pos = pos - btn.size / 2.0
		tween.tween_property(btn, "position", target_pos, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if to_steps >= 58:
		tween.finished.connect(func():
			_spawn_particle_burst(btn.position + btn.size / 2.0, Color.GOLD)
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_capture()
		)
	else:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_move()

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
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
					if has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_capture()
						
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))
				
	current_p = bridge.current_player()
	_update_status()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_game_over()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_invalid()

func _draw() -> void:
	# Main Board Outer Square
	var board_rect = Rect2(20, 20, 560, 560)
	draw_rect(board_rect, Color(0.95, 0.95, 0.95))
	draw_rect(board_rect, Color.BLACK, false, 3.0)
	
	# Base Corner Zones (4 Home bases)
	var zones = [
		{"rect": Rect2(20, 20, 220, 220), "col": GameManager.get_player_color(1)},
		{"rect": Rect2(360, 20, 220, 220), "col": GameManager.get_player_color(2)},
		{"rect": Rect2(360, 360, 220, 220), "col": GameManager.get_player_color(3)},
		{"rect": Rect2(20, 360, 220, 220), "col": GameManager.get_player_color(4)}
	]
	for z in zones:
		draw_rect(z.rect, z.col)
		draw_rect(z.rect, Color.BLACK, false, 2.0)
		draw_circle(z.rect.position + z.rect.size / 2.0, 70, Color.WHITE)
		
	# Cross track 52 cells
	var margin = 40.0
	var track_step = 35.0
	for i in range(15):
		for j in range(15):
			# Skip 4 base corners
			if (i < 6 and j < 6) or (i > 8 and j < 6) or (i < 6 and j > 8) or (i > 8 and j > 8):
				continue
			var cell_rect = Rect2(margin + i * track_step - 17.5, margin + j * track_step - 17.5, track_step, track_step)
			draw_rect(cell_rect, Color.BLACK, false, 1.0)

	# Safe squares permanent highlight (start and star cells)
	var safe_color = Color(0.9, 0.9, 0.3, 0.3)
	for p in range(1, 5):
		for s in [1, 9]:
			var cpos = _get_token_board_pos(p, 0, s)
			var safe_rect = Rect2(cpos.x - 17.5, cpos.y - 17.5, track_step, track_step)
			draw_rect(safe_rect, safe_color)

	# Center Goal Zone
	var center = Vector2(300, 300)
	draw_circle(center, 40, Color(0.9, 0.9, 0.9))
	draw_circle(center, 40, Color.GOLD, false, 3.0)

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Todas las fichas completas! Ganó el jugador %s (Ludo)" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var name = "Jugador %s" % current_p
		var col = GameManager.get_player_color(current_p)
		status.text = "Turno: Jugador %s (Ludo)" % current_p
		if turn_indicator != null:
			turn_indicator.set_turn(current_p, name, col)
