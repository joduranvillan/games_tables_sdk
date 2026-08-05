extends Node2D

const P1 = 1 # Increasing (Red / White)
const P2 = 2 # Decreasing (Dark Blue / Black)
const TOTAL_POINTS = 24

# Colors
const COL_BOARD = Color(0.32, 0.20, 0.12)
const COL_BOARD_INNER = Color(0.82, 0.72, 0.58)
const COL_POINT_A = Color(0.80, 0.25, 0.20) # Red triangular point
const COL_POINT_B = Color(0.95, 0.92, 0.85) # White/cream triangular point
const COL_BAR = Color(0.18, 0.12, 0.08)
const COL_BEARING = Color(0.22, 0.14, 0.07)

const PLAYER_COLORS = {
	1: Color(0.90, 0.25, 0.20), # Red
	2: Color(0.20, 0.25, 0.35)  # Dark Blue
}

var bridge
var current = P1
var winner = -1
var rolled_dice: Array = []
var selected_from = -2 # -2: none, -1: bar, 0..23: point index

# Board state: points array [24] with count (+ for P1, - for P2)
var points = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
var bar_checkers = {1: 0, 2: 0}
var borne_off_checkers = {1: 0, 2: 0}

# Checker node elements: point_idx / bar / bearing -> Array of Control/TextureButton
var checker_nodes = []

# UI Controls
var roll_btn: Button
var dice_label: Label

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

	_init_board_state()
	_setup_ui()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	if network_hud != null:
		network_hud.bind_bridge(bridge)

	bridge.start_local_match_backgammon(P1, P2)
	current = bridge.current_player()
	
	_update_checker_positions()
	_update_status()
	queue_redraw()

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	queue_redraw()

func _init_board_state() -> void:
	points = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	# Standard Backgammon setup
	points[0] = 2
	points[11] = 5
	points[16] = 3
	points[18] = 5
	
	points[23] = -2
	points[12] = -5
	points[7] = -3
	points[5] = -5
	
	bar_checkers = {1: 0, 2: 0}
	borne_off_checkers = {1: 0, 2: 0}

func _setup_ui() -> void:
	roll_btn = Button.new()
	roll_btn.position = Vector2(620, 260)
	roll_btn.custom_minimum_size = Vector2(130, 45)
	roll_btn.text = "🎲 Tirar Dados"
	roll_btn.add_theme_font_size_override("font_size", 15)
	roll_btn.pressed.connect(_on_roll_pressed)
	add_child(roll_btn)
	
	dice_label = Label.new()
	dice_label.position = Vector2(620, 315)
	dice_label.size = Vector2(130, 40)
	dice_label.text = "Dados: -"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.add_theme_font_size_override("font_size", 16)
	add_child(dice_label)

	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(40, 535)
	add_child(turn_indicator)

	# Network Status HUD
	network_hud = NetworkStatusHUD.new()
	network_hud.name = "NetworkStatusHUD"
	add_child(network_hud)

func _get_point_base_pos(pt_idx: int) -> Vector2:
	var col_width = 38.0
	var left_start = 65.0
	var right_start = 350.0
	
	if pt_idx < 6: # Bottom left (0..5)
		return Vector2(left_start + pt_idx * col_width + col_width / 2.0, 500)
	elif pt_idx < 12: # Bottom right (6..11)
		return Vector2(right_start + (pt_idx - 6) * col_width + col_width / 2.0, 500)
	elif pt_idx < 18: # Top right (12..17)
		return Vector2(right_start + (17 - pt_idx) * col_width + col_width / 2.0, 60)
	else: # Top left (18..23)
		return Vector2(left_start + (23 - pt_idx) * col_width + col_width / 2.0, 60)

func _on_roll_pressed() -> void:
	if winner != -1:
		return
	var cmd = {"command_type": "RollDiceCommand", "player": current}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _input(event: InputEvent) -> void:
	if winner != -1:
		return
		
	var click_pos = Vector2.ZERO
	var handled = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_pos = event.position
		handled = true
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = event.position
		handled = true
		
	if handled:
		# Check click on bar (x: 290..350)
		if click_pos.x >= 290 and click_pos.x <= 350 and click_pos.y >= 40 and click_pos.y <= 520:
			if bar_checkers[current] > 0:
				selected_from = -1
				queue_redraw()
				return
				
		# Check click on points 0..23
		for pt in range(TOTAL_POINTS):
			var base_px = _get_point_base_pos(pt)
			var is_top = (pt >= 12)
			var pt_rect: Rect2
			if is_top:
				pt_rect = Rect2(base_px.x - 18, 40, 36, 220)
			else:
				pt_rect = Rect2(base_px.x - 18, 300, 36, 220)
				
			if pt_rect.has_point(click_pos):
				_handle_point_click(pt)
				return

func _handle_point_click(pt: int) -> void:
	if selected_from == -2:
		var count = points[pt]
		var belongs_to_current = (count > 0 and current == P1) or (count < 0 and current == P2)
		if belongs_to_current and bar_checkers[current] == 0:
			selected_from = pt
			queue_redraw()
	elif selected_from == pt:
		selected_from = -2
		queue_redraw()
	else:
		var from_val = null if selected_from == -1 else selected_from
		var die_val = rolled_dice.front() if rolled_dice.size() > 0 else 1
		
		if from_val != null and rolled_dice.size() > 0:
			var diff = abs(pt - from_val)
			if diff in rolled_dice:
				die_val = diff
				
		var cmd = {
			"command_type": "MoveCheckerCommand",
			"player": current,
			"from": from_val,
			"die": die_val
		}
		selected_from = -2
		queue_redraw()
		bridge.send_command_json(current, JSON.stringify(cmd))

func _update_checker_positions() -> void:
	for node in checker_nodes:
		if is_instance_valid(node):
			node.queue_free()
	checker_nodes.clear()
	
	# Draw checkers on 24 points with stack limit of 5
	for pt in range(TOTAL_POINTS):
		var count = points[pt]
		if count == 0:
			continue
		var owner = P1 if count > 0 else P2
		var total_num = abs(count)
		var visible_num = min(total_num, 5)
		var base_pos = _get_point_base_pos(pt)
		var is_top = (pt >= 12)
		
		for k in range(visible_num):
			var is_top_stack = (k == visible_num - 1) and (total_num > 5)
			var badge_text = str(total_num) if is_top_stack else ""
			var btn = _create_checker_button(owner, badge_text)
			var y_off = k * 28.0 if is_top else -k * 28.0
			var pos = base_pos + Vector2(-15, y_off - (0 if is_top else 30))
			btn.position = pos
			add_child(btn)
			checker_nodes.append(btn)
			
	# Draw bar checkers
	for p in [P1, P2]:
		var b_cnt = bar_checkers[p]
		for k in range(min(b_cnt, 5)):
			var is_top_stack = (k == 4) and (b_cnt > 5)
			var badge_text = str(b_cnt) if is_top_stack else ""
			var btn = _create_checker_button(p, badge_text)
			var y_pos = 280 + k * 28 if p == P1 else 240 - k * 28
			btn.position = Vector2(320 - 15, y_pos)
			add_child(btn)
			checker_nodes.append(btn)

func _create_checker_button(owner: int, badge_text: String = "") -> Control:
	var ctrl = Control.new()
	ctrl.size = Vector2(30, 30)
	
	var img = Image.create(30, 30, false, Image.FORMAT_RGBA8)
	var col = PLAYER_COLORS[owner]
	for x in range(30):
		for y in range(30):
			var dist = Vector2(x - 15, y - 15).length()
			if dist <= 12:
				img.set_pixel(x, y, col)
			elif dist <= 14:
				img.set_pixel(x, y, Color.BLACK)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	var tex = TextureRect.new()
	tex.texture = ImageTexture.create_from_image(img)
	tex.size = Vector2(30, 30)
	ctrl.add_child(tex)

	if badge_text != "":
		var lbl = Label.new()
		lbl.text = badge_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(30, 30)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color.YELLOW)
		ctrl.add_child(lbl)

	return ctrl

func _animate_arc_movement(owner: int, start_pos: Vector2, end_pos: Vector2) -> void:
	var anim_checker = _create_checker_button(owner)
	anim_checker.position = start_pos
	add_child(anim_checker)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_move()

	var tween = create_tween()
	# Curved arc control point
	var duration = 0.35
	tween.tween_method(func(t: float):
		if is_instance_valid(anim_checker):
			var linear_pos = start_pos.lerp(end_pos, t)
			var height_arc = sin(t * PI) * 90.0 # Curving upwards
			anim_checker.position = Vector2(linear_pos.x, linear_pos.y - height_arc)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if is_instance_valid(anim_checker):
			anim_checker.queue_free()
		_update_checker_positions()
	)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "DiceRolledEvent":
				rolled_dice = event.get("values", [])
				dice_label.text = "Dados: %s" % str(rolled_dice)
			elif event_type == "CheckerMovedEvent":
				var p = int(event.get("player", current))
				var from_p = event.get("from", null)
				var to_p = event.get("to", null)
				
				var start_pos = Vector2(320 - 15, 280) if from_p == null else _get_point_base_pos(int(from_p)) - Vector2(15, 15)
				var end_pos = Vector2(620, 100) if to_p == null else _get_point_base_pos(int(to_p)) - Vector2(15, 15)

				# Update board state
				if from_p == null:
					bar_checkers[p] = max(0, bar_checkers[p] - 1)
				else:
					var f_idx = int(from_p)
					if p == P1: points[f_idx] -= 1
					else: points[f_idx] += 1
					
				if to_p == null:
					borne_off_checkers[p] += 1
				else:
					var t_idx = int(to_p)
					if event.get("captured_opponent", false):
						var opp = P2 if p == P1 else P1
						bar_checkers[opp] += 1
						points[t_idx] = 0
						if has_node("/root/AudioManager"):
							get_node("/root/AudioManager").play_capture()
					if p == P1: points[t_idx] += 1
					else: points[t_idx] -= 1
					
				if rolled_dice.size() > 0:
					rolled_dice.pop_front()
				dice_label.text = "Dados: %s" % str(rolled_dice)
				
				_animate_arc_movement(p, start_pos, end_pos)
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))
				
	current = bridge.current_player()
	_update_status()
	queue_redraw()

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
	# Main Outer Board Frame
	var board_rect = Rect2(40, 40, 560, 480)
	draw_rect(board_rect, COL_BOARD)
	draw_rect(Rect2(55, 55, 530, 450), COL_BOARD_INNER)
	
	# Central Bar for Hit Checkers
	var bar_rect = Rect2(290, 40, 60, 480)
	draw_rect(bar_rect, COL_BAR)
	draw_rect(bar_rect, Color(0.4, 0.25, 0.15), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(300, 265), "BARRA", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.8, 0.7, 0.5))

	# Bearing-Off Area
	draw_rect(Rect2(610, 40, 150, 200), COL_BEARING)
	draw_string(ThemeDB.fallback_font, Vector2(620, 70), "Bearing Off 🏁", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(620, 110), "P1 (Rojo): %d/15" % borne_off_checkers[P1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PLAYER_COLORS[P1])
	draw_string(ThemeDB.fallback_font, Vector2(620, 140), "P2 (Azul): %d/15" % borne_off_checkers[P2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PLAYER_COLORS[P2])
	
	# 24 Triangular Points with Red / White alternate colors
	for pt in range(TOTAL_POINTS):
		var base_pos = _get_point_base_pos(pt)
		var is_top = (pt >= 12)
		var tri_col = COL_POINT_A if (pt % 2 == 0) else COL_POINT_B
		
		var p1: Vector2 = base_pos + Vector2(-18, 0)
		var p2: Vector2 = base_pos + Vector2(18, 0)
		var p3: Vector2
		if is_top:
			p3 = base_pos + Vector2(0, 200)
		else:
			p3 = base_pos + Vector2(0, -200)
			
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), tri_col)
		
	# Selected highlight
	if selected_from >= 0:
		var sel_base = _get_point_base_pos(selected_from)
		draw_circle(sel_base, 20.0, Color(1.0, 0.9, 0.2, 0.7))
	elif selected_from == -1:
		draw_circle(Vector2(320, 280), 25.0, Color(1.0, 0.9, 0.2, 0.7))

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Retiró todas sus fichas! Ganó el jugador %s (Backgammon)" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var name = "Rojo (P1)" if current == P1 else "Azul (P2)"
		var col = PLAYER_COLORS[current]
		status.text = "Turno: Jugador %s (Backgammon)" % name
		if turn_indicator != null:
			turn_indicator.set_turn(current, name, col)
