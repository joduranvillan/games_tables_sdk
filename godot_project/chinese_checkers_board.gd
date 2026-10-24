extends Node2D

const BOARD_RADIUS = 4

const CENTER = Vector2(400, 370)
const HEX_SPACING = 38.0

const DIRECTIONS = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

const PLAYER_COLORS: Dictionary = {
	1: Color(0.92, 0.22, 0.22), # Rojo
	2: Color(0.22, 0.48, 0.92), # Azul
	3: Color(0.18, 0.82, 0.35), # Verde
	4: Color(0.96, 0.80, 0.15), # Amarillo
	5: Color(0.72, 0.28, 0.92), # Púrpura
	6: Color(0.96, 0.52, 0.18)  # Naranja
}

const PLAYER_NAMES: Dictionary = {
	1: "Rojo (1)",
	2: "Azul (2)",
	3: "Verde (3)",
	4: "Amarillo (4)",
	5: "Púrpura (5)",
	6: "Naranja (6)"
}

var bridge
var num_players: int = 2
var current: int = 1
var winner: int = -1
var selected_pos = null # Vector2i(q, r)
var valid_dests: Array = [] # Array of Vector2i(q, r)

# Grid of positions: Vector2i(q, r) -> player_id (0 = empty, 1..6 = player)
var board_pegs: Dictionary = {}
# Grid of buttons: Vector2i(q, r) -> TextureButton
var peg_buttons: Dictionary = {}

var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var rules_popup: RulesPopup
var player_select_box: HBoxContainer
var player_count_option: OptionButton
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

	_setup_ui_layers()
	start_match(num_players)
	_on_layout_changed(gm.get_layout() if gm != null else 0)

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_quit_to_menu() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	_update_peg_visuals()
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

func _rotate_60(p: Vector2i, times: int) -> Vector2i:
	var curr = p
	var count = posmod(times, 6)
	for i in range(count):
		curr = Vector2i(-curr.y, curr.x + curr.y)
	return curr

func _get_corner_cells(corner: int) -> Array[Vector2i]:
	var base: Array[Vector2i] = [
		Vector2i(-5, 1),
		Vector2i(-5, 2),
		Vector2i(-5, 3),
		Vector2i(-6, 2),
		Vector2i(-6, 3),
		Vector2i(-6, 4),
		Vector2i(-7, 3),
		Vector2i(-7, 4),
		Vector2i(-8, 4),
		Vector2i(-5, 4)
	]
	var res: Array[Vector2i] = []
	for p in base:
		res.append(_rotate_60(p, corner))
	return res

func _is_on_board(q: int, r: int) -> bool:
	if max(abs(q), max(abs(r), abs(q + r))) <= BOARD_RADIUS:
		return true
	var p = Vector2i(q, r)
	for c in range(6):
		if p in _get_corner_cells(c):
			return true
	return false

func _init_board_positions(player_count: int) -> void:
	board_pegs.clear()
	# 1. Central hexagon
	for q in range(-BOARD_RADIUS, BOARD_RADIUS + 1):
		for r in range(-BOARD_RADIUS, BOARD_RADIUS + 1):
			if max(abs(q), max(abs(r), abs(q + r))) <= BOARD_RADIUS:
				board_pegs[Vector2i(q, r)] = 0
	# 2. All 6 corner triangles (star points)
	for c in range(6):
		for p in _get_corner_cells(c):
			board_pegs[p] = 0

	# 3. Setup players initial pieces in corners according to count
	var corner_map: Array[int] = []
	match player_count:
		2: corner_map = [0, 3]
		3: corner_map = [0, 2, 4]
		4: corner_map = [0, 1, 3, 4]
		6: corner_map = [0, 1, 2, 3, 4, 5]
		_:
			# Fallback for 5 or any other value
			corner_map = []
			for i in range(player_count):
				corner_map.append(i % 6)

	for i in range(player_count):
		var p_id = i + 1
		var c_idx = corner_map[i]
		for pos in _get_corner_cells(c_idx):
			board_pegs[pos] = p_id

func _axial_to_pixel(q: int, r: int) -> Vector2:
	var x = CENTER.x + HEX_SPACING * (q + r / 2.0)
	var y = CENTER.y + HEX_SPACING * (r * sqrt(3.0) / 2.0)
	return Vector2(x, y)

func start_match(p_count: int = 2) -> void:
	num_players = clampi(p_count, 2, 6)
	winner = -1
	selected_pos = null
	valid_dests.clear()

	_init_board_positions(num_players)
	_setup_peg_buttons()

	if bridge != null and is_instance_valid(bridge):
		bridge.queue_free()

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)

	if bridge.has_method("start_local_match_chinese_checkers_n_players"):
		bridge.start_local_match_chinese_checkers_n_players(num_players)
	elif num_players == 2:
		bridge.start_local_match_chinese_checkers(1, 2)
	else:
		bridge.start_local_match_chinese_checkers(1, 2)

	current = bridge.current_player()

	# HUD de red — solo en modo Host/Client, nunca en headless
	if not OS.has_feature("headless"):
		if bridge.has_method("is_network_mode") and bridge.call("is_network_mode"):
			var hud_script := load("res://network_status_hud.gd")
			if hud_script:
				var hud: Node = hud_script.new()
				if hud.has_method("setup"):
					hud.setup(bridge)
				elif hud.has_method("bind_bridge"):
					hud.bind_bridge(bridge)
				add_child(hud)

	_update_peg_visuals()
	_update_status()
	queue_redraw()

func _setup_ui_layers() -> void:
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(20, 20)
	add_child(turn_indicator)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(690, 20)
	btn_rules.custom_minimum_size = Vector2(90, 40)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("chinese_checkers"))
	add_child(btn_rules)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 100)
	add_child(rules_popup)

	# Selector de número de jugadores (2 a 6)
	player_select_box = HBoxContainer.new()
	player_select_box.position = Vector2(450, 24)
	player_select_box.add_theme_constant_override("separation", 8)
	add_child(player_select_box)

	var lbl = Label.new()
	lbl.text = "Jugadores:"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_select_box.add_child(lbl)

	player_count_option = OptionButton.new()
	player_count_option.add_item("2 Jugadores", 2)
	player_count_option.add_item("3 Jugadores", 3)
	player_count_option.add_item("4 Jugadores", 4)
	player_count_option.add_item("6 Jugadores", 6)
	player_count_option.selected = 0
	player_count_option.item_selected.connect(func(index):
		var count = player_count_option.get_item_id(index)
		start_match(count)
	)
	player_select_box.add_child(player_count_option)

func _setup_peg_buttons() -> void:
	for btn in peg_buttons.values():
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	peg_buttons.clear()

	for pos in board_pegs.keys():
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(30, 30)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.pivot_offset = Vector2(15, 15)

		var px_pos = _axial_to_pixel(pos.x, pos.y)
		btn.position = px_pos - Vector2(15, 15)

		var grid_pos = pos
		btn.pressed.connect(func(): _on_peg_clicked(grid_pos))
		btn.draw.connect(func():
			var pid: int = int(board_pegs.get(grid_pos, 0))
			if pid > 0:
				var sym := _get_peg_symbol(pid)
				btn.draw_string(ThemeDB.fallback_font, Vector2(0, 20), sym, HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color.WHITE)
		)
		add_child(btn)
		peg_buttons[pos] = btn

func _get_peg_color(p_id: int) -> Color:
	var fallback: Color = PLAYER_COLORS.get(p_id, ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(p_id) - 1, 6)] as Color))
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = get_node("/root/ThemeManager")
		if tm.has_method("is_colorblind_mode") and bool(tm.call("is_colorblind_mode")):
			if tm.has_method("get_player_color"):
				return tm.call("get_player_color", p_id, fallback)
	return fallback

func _get_peg_symbol(p_id: int) -> String:
	match p_id:
		1: return "▲" # Rojo
		2: return "●" # Azul
		3: return "■" # Verde
		4: return "◆" # Amarillo
		5: return "⬟" # Violeta / Púrpura
		6: return "★" # Naranja
		_: return "●"

func _update_peg_visuals() -> void:
	var slot_color = current_theme.dark_color if current_theme else Color(0.24, 0.18, 0.14, 0.78)
	var slot_rim = current_theme.line_color if current_theme else Color(0.55, 0.45, 0.35, 0.85)

	for pos in board_pegs.keys():
		var btn = peg_buttons.get(pos)
		if btn == null or not is_instance_valid(btn):
			continue
		var p_id = board_pegs[pos]

		var img = Image.create(30, 30, false, Image.FORMAT_RGBA8)
		var p_color = _get_peg_color(p_id)

		for x in range(30):
			for y in range(30):
				var v = Vector2(x - 15.0, y - 15.0)
				var dist = v.length()
				if p_id > 0:
					if dist <= 11.5:
						var light_dist = Vector2(x - 11.0, y - 10.5).length() / 13.0
						var shade = clampf(1.22 - light_dist * 0.55, 0.62, 1.25)
						var c = Color(
							clampf(p_color.r * shade, 0.0, 1.0),
							clampf(p_color.g * shade, 0.0, 1.0),
							clampf(p_color.b * shade, 0.0, 1.0),
							1.0
						)
						if Vector2(x - 11.0, y - 10.0).length() <= 3.2:
							c = c.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.55)
						img.set_pixel(x, y, c)
					elif dist <= 13.2:
						img.set_pixel(x, y, Color(0.08, 0.08, 0.10, 0.92))
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					if dist <= 6.8:
						img.set_pixel(x, y, slot_color)
					elif dist <= 8.6:
						img.set_pixel(x, y, slot_rim)
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))

		btn.texture_normal = ImageTexture.create_from_image(img)

func _on_peg_clicked(pos: Vector2i) -> void:
	if winner != -1:
		return

	if selected_pos == null:
		if board_pegs.get(pos, 0) == current:
			selected_pos = pos
			valid_dests = _calculate_valid_destinations(pos)
			queue_redraw()
	else:
		if selected_pos == pos:
			selected_pos = null
			valid_dests.clear()
			queue_redraw()
			return

		if board_pegs.get(pos, 0) == current:
			selected_pos = pos
			valid_dests.clear()
			valid_dests = _calculate_valid_destinations(pos)
			queue_redraw()
			return

		var from_pos = selected_pos
		selected_pos = null
		valid_dests.clear()
		queue_redraw()

		var cmd = {
			"command_type": "MovePegCommand",
			"player": current,
			"from": {"q": from_pos.x, "r": from_pos.y},
			"to": {"q": pos.x, "r": pos.y},
			"path": []
		}
		bridge.send_command_json(current, JSON.stringify(cmd))

func _calculate_valid_destinations(start: Vector2i) -> Array:
	var dests: Array = []
	# 1. Single steps
	for dir in DIRECTIONS:
		var target = start + dir
		if board_pegs.has(target) and board_pegs[target] == 0:
			dests.append(target)

	# 2. Jumps & jump chains
	var visited = {}
	var queue = [start]
	visited[start] = true

	while not queue.is_empty():
		var curr = queue.pop_front()
		for dir in DIRECTIONS:
			var mid = curr + dir
			var landing = curr + dir * 2
			if board_pegs.has(mid) and board_pegs[mid] > 0: # Jump over peg
				if board_pegs.has(landing) and board_pegs[landing] == 0:
					if not visited.has(landing):
						visited[landing] = true
						if landing != start and not dests.has(landing):
							dests.append(landing)
						queue.append(landing)
	return dests

func _animate_peg_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var p_id = board_pegs.get(from_pos, current)
	board_pegs[from_pos] = 0
	board_pegs[to_pos] = p_id

	_update_peg_visuals()
	var btn = peg_buttons.get(to_pos)
	if btn != null and is_instance_valid(btn):
		var from_px = _axial_to_pixel(from_pos.x, from_pos.y) - Vector2(15, 15)
		var to_px = _axial_to_pixel(to_pos.x, to_pos.y) - Vector2(15, 15)
		btn.position = from_px

		var tween = create_tween()
		tween.tween_property(btn, "position", to_px, 0.25)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "PegMovedEvent" or event_type == "TokenMovedEvent":
				var from_dict = event.get("from", {})
				var to_dict = event.get("to", {})
				var from_p = Vector2i(int(from_dict.get("q", 0)), int(from_dict.get("r", 0)))
				var to_p = Vector2i(int(to_dict.get("q", 0)), int(to_dict.get("r", 0)))
				_animate_peg_move(from_p, to_p)
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))

	current = bridge.current_player()
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	_sfx_victory_fanfare()
	winner = w
	_update_status()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	_sfx_error_buzz()
	status.text = "Movimiento inválido: %s" % reason

func _draw() -> void:
	var bg_board = current_theme.board_color if current_theme else Color(0.91, 0.83, 0.72)
	var bg_triangle = current_theme.light_color if current_theme else Color(0.85, 0.76, 0.64)
	var border_col = current_theme.line_color if current_theme else Color(0.32, 0.20, 0.10)
	var select_col = current_theme.select_color if current_theme else Color(1.0, 0.95, 0.30, 0.65)
	var valid_col = current_theme.valid_move_color if current_theme else Color(0.2, 0.85, 0.35, 0.7)

	# 1. Dibujar estrella real de 6 puntas (compuesta por los 2 triángulos grandes superpuestos de la estrella de David)
	# Cada punta sobresale visiblemente como un triángulo reconocible
	var tip_radius = 295.0
	var star_poly_1 = PackedVector2Array() # Triángulo 1 (puntas 0, 2, 4)
	for i in [0, 2, 4]:
		var angle = deg_to_rad(60 * i + 30)
		star_poly_1.append(CENTER + Vector2(cos(angle), sin(angle)) * tip_radius)

	var star_poly_2 = PackedVector2Array() # Triángulo 2 (puntas 1, 3, 5)
	for i in [1, 3, 5]:
		var angle = deg_to_rad(60 * i + 30)
		star_poly_2.append(CENTER + Vector2(cos(angle), sin(angle)) * tip_radius)

	# Dibujar base de madera/tema en forma de estrella de 12 vértices (perímetro exterior exacto)
	var star_outer_polygon = PackedVector2Array()
	var inner_indent_radius = tip_radius / sqrt(3.0) # Vértices interiores en las intersecciones
	for i in range(6):
		var tip_angle = deg_to_rad(60 * i + 30)
		var indent_angle = deg_to_rad(60 * i + 60)
		star_outer_polygon.append(CENTER + Vector2(cos(tip_angle), sin(tip_angle)) * tip_radius)
		star_outer_polygon.append(CENTER + Vector2(cos(indent_angle), sin(indent_angle)) * inner_indent_radius)

	# Sombra suave del tablero
	var shadow_poly = PackedVector2Array()
	for p in star_outer_polygon:
		shadow_poly.append(p + Vector2(4, 6))
	draw_colored_polygon(shadow_poly, Color(0, 0, 0, 0.25))

	# Fondo exterior de la estrella con el color del tema
	draw_colored_polygon(star_outer_polygon, bg_board)

	# Dibujar los 2 triángulos con sutileza para resaltar la geometría de estrella
	draw_colored_polygon(star_poly_1, Color(bg_triangle.r, bg_triangle.g, bg_triangle.b, 0.45))
	draw_colored_polygon(star_poly_2, Color(bg_triangle.r, bg_triangle.g, bg_triangle.b, 0.45))

	# Dibujar contorno exterior de la estrella
	star_outer_polygon.append(star_outer_polygon[0])
	draw_polyline(star_outer_polygon, border_col, 3.5)

	# Dibujar líneas guía entre casillas adyacentes para conectar los agujeros de la grilla
	var drawn_lines = {}
	for pos in board_pegs.keys():
		var p1_px = _axial_to_pixel(pos.x, pos.y)
		for dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, -1)]:
			var neighbor = pos + dir
			if board_pegs.has(neighbor):
				var key = "%s,%s-%s,%s" % [pos.x, pos.y, neighbor.x, neighbor.y]
				if not drawn_lines.has(key):
					drawn_lines[key] = true
					var p2_px = _axial_to_pixel(neighbor.x, neighbor.y)
					draw_line(p1_px, p2_px, Color(border_col.r, border_col.g, border_col.b, 0.25), 1.5)

	# Resaltar selección
	if selected_pos != null:
		var px = _axial_to_pixel(selected_pos.x, selected_pos.y)
		draw_circle(px, 18.0, select_col)
		draw_arc(px, 18.0, 0.0, TAU, 24, Color(select_col.r, select_col.g, select_col.b, 1.0), 2.0)

	# Resaltar destinos válidos
	for dest in valid_dests:
		var px = _axial_to_pixel(dest.x, dest.y)
		draw_circle(px, 12.0, valid_col)
		draw_arc(px, 12.0, 0.0, TAU, 18, Color(1, 1, 1, 0.8), 1.5)

func _update_status() -> void:
	if winner != -1:
		var win_name = PLAYER_NAMES.get(winner, "Jugador %s" % winner)
		status.text = "¡Ganó %s (Damas Chinas)!" % win_name
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var curr_name = PLAYER_NAMES.get(current, "Jugador %s" % current)
		var p_col = _get_peg_color(current)
		status.text = "Turno: %s (Damas Chinas — %d jugadores)" % [curr_name, num_players]
		if turn_indicator != null:
			turn_indicator.set_turn(current, curr_name, p_col)
			turn_indicator.set_active(true)

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
