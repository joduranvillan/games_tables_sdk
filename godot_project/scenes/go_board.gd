extends Node2D

const BOARD_SIZE = 9
const CELL_SIZE = 70.0
const P_BLACK = 1
const P_WHITE = 2

# Colors
const COL_BOARD = Color(0.85, 0.70, 0.35)
const COL_LINE = Color(0.15, 0.10, 0.05)
const COL_BLACK_STONE = Color(0.10, 0.10, 0.10)
const COL_WHITE_STONE = Color(0.95, 0.95, 0.95)

var bridge
var board: Array = [] # 9x9 array: null | P_BLACK | P_WHITE
var stone_nodes: Array = [] # 9x9 array: TextureRect/Control nodes
var territory_map: Array = [] # 9x9 array: null | P_BLACK | P_WHITE
var current: int = P_BLACK
var winner: int = -1
var black_score: float = 0.0
var white_score: float = 0.0
var black_captured: int = 0
var white_captured: int = 0

var grid_container: GridContainer
var stones_container: Node2D

var captured_score_label: Label
var captures_label_b: Label
var captures_label_n: Label
var drag_layer: DragDropLayer
var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var export_game_button: Button
var export_toast_label: Label
var _rules_popup: RulesPopup
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

	_setup_ui()
	_init_board()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

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
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	bridge.start_local_match_go(P_BLACK, P_WHITE)
	current = bridge.current_player()
	
	_on_layout_changed(GameManager.get_layout() if gm != null else 0)
	_update_status()
	_update_captured_score()
	queue_redraw()

	# --- Botón de reglas ---
	var btn_rules := Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(BOARD_SIZE * CELL_SIZE - 95, BOARD_SIZE * CELL_SIZE + 45)
	btn_rules.custom_minimum_size = Vector2(90, 36)
	btn_rules.pressed.connect(func(): _rules_popup.show_for_game("go"))
	add_child(btn_rules)

	_rules_popup = RulesPopup.new()
	_rules_popup.visible = false
	_rules_popup.position = Vector2(80, 100)
	add_child(_rules_popup)

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

func _setup_ui() -> void:
	stones_container = Node2D.new()
	stones_container.name = "StonesContainer"
	add_child(stones_container)

	# Captured Stones Top-Right Panel
	captured_score_label = Label.new()
	captured_score_label.name = "CapturedScoreLabel"
	captured_score_label.position = Vector2(380, 15)
	captured_score_label.size = Vector2(300, 45)
	captured_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	captured_score_label.add_theme_font_size_override("font_size", 16)
	captured_score_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	add_child(captured_score_label)

	# Captured Stones Counters below the board
	var captures_container = HBoxContainer.new()
	captures_container.name = "CapturesContainer"
	captures_container.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 10)
	captures_container.size = Vector2(BOARD_SIZE * CELL_SIZE, 30)
	captures_container.add_theme_constant_override("separation", 24)
	add_child(captures_container)

	captures_label_b = Label.new()
	captures_label_b.name = "CapturesLabelB"
	captures_label_b.text = "Capturas B: 0"
	captures_label_b.add_theme_font_size_override("font_size", 16)
	captures_label_b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	captures_container.add_child(captures_label_b)

	captures_label_n = Label.new()
	captures_label_n.name = "CapturesLabelN"
	captures_label_n.text = "Capturas N: 0"
	captures_label_n.add_theme_font_size_override("font_size", 16)
	captures_label_n.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	captures_container.add_child(captures_label_n)

	# Drag & Drop / Input Layer
	drag_layer = DragDropLayer.new()
	drag_layer.name = "DragDropLayer"
	drag_layer.cell_size = CELL_SIZE
	drag_layer.board_bounds = Vector2i(BOARD_SIZE, BOARD_SIZE)
	drag_layer.cell_clicked.connect(_on_cell_clicked)
	add_child(drag_layer)

	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 48)
	add_child(turn_indicator)

	# Botón Exportar Partida (SGF)
	export_game_button = Button.new()
	export_game_button.name = "ExportGameButton"
	export_game_button.text = "Exportar Partida"
	export_game_button.position = Vector2(360, BOARD_SIZE * CELL_SIZE + 10)
	export_game_button.custom_minimum_size = Vector2(160, 32)
	export_game_button.pressed.connect(_on_export_game_pressed)
	add_child(export_game_button)

	# Botón Tutorial Interactivo de Go (5 pasos)
	var tutorial_btn := Button.new()
	tutorial_btn.name = "GoTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(360, BOARD_SIZE * CELL_SIZE + 48)
	tutorial_btn.custom_minimum_size = Vector2(160, 32)
	tutorial_btn.pressed.connect(start_go_tutorial)
	add_child(tutorial_btn)

	export_toast_label = Label.new()
	export_toast_label.name = "ExportToastLabel"
	export_toast_label.text = ""
	export_toast_label.visible = false
	export_toast_label.position = Vector2(360, BOARD_SIZE * CELL_SIZE + 48)
	export_toast_label.add_theme_font_size_override("font_size", 14)
	export_toast_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	add_child(export_toast_label)

func _on_export_game_pressed() -> void:
	var sgf_text := ""
	if bridge != null and bridge.has_method("export_go_sgf"):
		sgf_text = str(bridge.call("export_go_sgf"))
	if sgf_text.is_empty():
		sgf_text = "(;GM[1]FF[4]CA[UTF-8]AP[OpenTable]SZ[%d]KM[6.5]PB[Black]PW[White])" % BOARD_SIZE
	DisplayServer.clipboard_set(sgf_text)
	_show_clipboard_notification("Copiado al portapapeles")

func _show_clipboard_notification(msg: String = "Copiado al portapapeles") -> void:
	if export_toast_label != null:
		export_toast_label.text = msg
		export_toast_label.visible = true
	if (is_inside_tree() and has_node("/root/NotificationManager")):
		var nm = get_node("/root/NotificationManager")
		if nm.has_method("show_toast"):
			nm.call("show_toast", msg)
	if is_inside_tree():
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(export_toast_label):
				export_toast_label.visible = false
		)

func _update_captured_score() -> void:
	if captures_label_b != null:
		captures_label_b.text = "Capturas B: %d" % white_captured
	if captures_label_n != null:
		captures_label_n.text = "Capturas N: %d" % black_captured
	if captured_score_label != null:
		captured_score_label.text = "Capturas N: %d | Capturas B: %d" % [black_captured, white_captured]

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)

func start_go_tutorial() -> void:
	var GoTut = load("res://scripts/tutorials/go_tutorial.gd")
	if GoTut != null:
		GoTut.start_on_board(self)

func _on_cell_clicked(cell: Vector2i) -> void:
	if (is_inside_tree() and has_node("/root/TutorialManager")):
		var tm = get_node("/root/TutorialManager")
		if tm.get("is_running") == true:
			if not tm.call("notify_cell_action", Vector2i(cell.y, cell.x)):
				return
	_sfx_piece_slide()
	if winner != -1: return
	var row = cell.x
	var col = cell.y
	if row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE:
		if board[row][col] == null:
			var cmd = {
				"command_type": "PlaceStoneCommand",
				"player": current,
				"x": col,
				"y": row
			}
			bridge.send_command_json(current, JSON.stringify(cmd))
			if drag_layer != null:
				drag_layer.clear_selection()

func _init_board() -> void:
	board.clear()
	stone_nodes.clear()
	territory_map.clear()
	for r in range(BOARD_SIZE):
		var row_arr = []
		var node_arr = []
		var terr_arr = []
		for c in range(BOARD_SIZE):
			row_arr.append(null)
			node_arr.append(null)
			terr_arr.append(null)
		board.append(row_arr)
		stone_nodes.append(node_arr)
		territory_map.append(terr_arr)

func _find_nearest_intersection(click_pos: Vector2) -> Vector2i:
	var best_cell = Vector2i(-1, -1)
	var min_manhattan = 999999.0
	
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var center = Vector2(c * CELL_SIZE + CELL_SIZE / 2.0, r * CELL_SIZE + CELL_SIZE / 2.0)
			var dist = abs(center.x - click_pos.x) + abs(center.y - click_pos.y)
			if dist < min_manhattan:
				min_manhattan = dist
				best_cell = Vector2i(r, c)
				
	if min_manhattan <= CELL_SIZE * 0.85:
		return best_cell
	return Vector2i(-1, -1)

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
		var cell = _find_nearest_intersection(click_pos)
		var row = cell.x
		var col = cell.y
		
		if row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE:
			if board[row][col] == null:
				var cmd = {
					"command_type": "PlaceStoneCommand",
					"player": current,
					"x": col,
					"y": row
				}
				bridge.send_command_json(current, JSON.stringify(cmd))

func _place_stone(row: int, col: int, player: int) -> void:
	board[row][col] = player
	
	var stone = TextureRect.new()
	stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stone.custom_minimum_size = Vector2(CELL_SIZE * 0.85, CELL_SIZE * 0.85)
	stone.size = Vector2(CELL_SIZE * 0.85, CELL_SIZE * 0.85)
	stone.pivot_offset = stone.size / 2.0
	stone.scale = Vector2.ZERO
	
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var col_color = COL_BLACK_STONE if player == P_BLACK else COL_WHITE_STONE
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x - 32, y - 32).length()
			if dist <= 28:
				img.set_pixel(x, y, col_color)
			elif dist <= 30:
				img.set_pixel(x, y, Color(0, 0, 0, 0.4))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	stone.texture = ImageTexture.create_from_image(img)
	var pos = Vector2(
		col * CELL_SIZE + CELL_SIZE / 2.0 - stone.size.x / 2.0,
		row * CELL_SIZE + CELL_SIZE / 2.0 - stone.size.y / 2.0
	)
	stone.position = pos
	
	stones_container.add_child(stone)
	stone_nodes[row][col] = stone

	var tween = create_tween()
	tween.tween_property(stone, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

func _animate_captures(captured_coords: Array) -> void:
	if captured_coords.size() > 0 and (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place(2.0)
		
	for coord in captured_coords:
		var r = coord.x
		var c = coord.y
		var stone = stone_nodes[r][c]
		if stone != null and is_instance_valid(stone):
			board[r][c] = null
			stone_nodes[r][c] = null
			var tween = create_tween()
			tween.tween_property(stone, "modulate:a", 0.0, 0.3)
			tween.parallel().tween_property(stone, "scale", Vector2(0.1, 0.1), 0.3)
			tween.finished.connect(func(): if is_instance_valid(stone): stone.queue_free())

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type.ends_with("StonePlacedEvent") or event_type == "StonePlacedEvent" or event_type == "stone_placed":
				var r = int(event.get("y", 0))
				var c = int(event.get("x", 0))
				var p = int(event.get("player", current))
				_place_stone(r, c, p)
			elif event_type.ends_with("StonesCapturedEvent") or event_type.ends_with("StonesRemovedEvent") or event_type == "StonesCapturedEvent" or event_type == "StonesRemovedEvent":
				var cap_coords = []
				if event.has("coords"):
					for pair in event["coords"]:
						cap_coords.append(Vector2i(pair[0], pair[1]))
				elif event.has("stones"):
					for pair in event["stones"]:
						cap_coords.append(Vector2i(pair[0], pair[1]))
				var count = int(event.get("count", cap_coords.size()))
				var cap_player = int(event.get("player", current))
				var num_captured = max(count, cap_coords.size())
				if cap_player == P_BLACK:
					black_captured += num_captured
				else:
					white_captured += num_captured
				_animate_captures(cap_coords)
				_update_captured_score()
			elif event_type.ends_with("GameOverEvent") or event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				if event.has("black_score"): black_score = float(event["black_score"])
				if event.has("white_score"): white_score = float(event["white_score"])
				if event.has("territory") and event["territory"] is Array:
					territory_map.clear()
					for row in event["territory"]:
						territory_map.append(row.duplicate())
				_on_game_over(int(w))
				
	current = bridge.current_player()
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	winner = w
	_calculate_territory()
	_update_status()
	_update_captured_score()
	queue_redraw()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _calculate_territory() -> void:
	# Client-side flood fill territory scoring algorithm
	territory_map.clear()
	var visited = []
	for r in range(BOARD_SIZE):
		var row_arr = []
		var row_v = []
		for c in range(BOARD_SIZE):
			row_arr.append(null)
			row_v.append(false)
		territory_map.append(row_arr)
		visited.append(row_v)

	var black_territory = 0
	var white_territory = 0

	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if board[r][c] == null and not visited[r][c]:
				var empty_region = []
				var border_players = {}
				var queue = [Vector2i(r, c)]
				visited[r][c] = true

				while queue.size() > 0:
					var curr = queue.pop_front()
					empty_region.append(curr)

					for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						var nr = curr.x + dir.x
						var nc = curr.y + dir.y
						if nr >= 0 and nr < BOARD_SIZE and nc >= 0 and nc < BOARD_SIZE:
							if board[nr][nc] == null:
								if not visited[nr][nc]:
									visited[nr][nc] = true
									queue.append(Vector2i(nr, nc))
							else:
								border_players[board[nr][nc]] = true

				var region_owner = null
				if border_players.has(P_BLACK) and not border_players.has(P_WHITE):
					region_owner = P_BLACK
					black_territory += empty_region.size()
				elif border_players.has(P_WHITE) and not border_players.has(P_BLACK):
					region_owner = P_WHITE
					white_territory += empty_region.size()

				if region_owner != null:
					for pos in empty_region:
						territory_map[pos.x][pos.y] = region_owner

	var black_stones = 0
	var white_stones = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if board[r][c] == P_BLACK:
				black_stones += 1
			elif board[r][c] == P_WHITE:
				white_stones += 1

	black_score = black_stones + black_territory + black_captured
	white_score = white_stones + white_territory + white_captured

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _draw() -> void:
	var bg_col = current_theme.board_color if current_theme else COL_BOARD
	var line_col = current_theme.line_color if current_theme else COL_LINE

	# Draw wooden board background
	var board_rect = Rect2(0, 0, BOARD_SIZE * CELL_SIZE, BOARD_SIZE * CELL_SIZE)
	draw_rect(board_rect, bg_col)
	
	# Draw grid lines intersecting at CELL_SIZE * (i + 0.5)
	for i in range(BOARD_SIZE):
		var start_h = Vector2(CELL_SIZE / 2.0, i * CELL_SIZE + CELL_SIZE / 2.0)
		var end_h = Vector2((BOARD_SIZE - 0.5) * CELL_SIZE, i * CELL_SIZE + CELL_SIZE / 2.0)
		draw_line(start_h, end_h, line_col, 2.0)
		
		var start_v = Vector2(i * CELL_SIZE + CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var end_v = Vector2(i * CELL_SIZE + CELL_SIZE / 2.0, (BOARD_SIZE - 0.5) * CELL_SIZE)
		draw_line(start_v, end_v, line_col, 2.0)
		
	# Star points (Hoshi) for Go board:
	# 9 points on canonical intersections: 3-3, 3-7, 5-5 (indices 2, 4, 6) on 9x9; 3-3, 3-9, 3-15 (indices 3, 9, 15) on 19x19
	var hoshi_points: Array[Vector2i] = []
	if BOARD_SIZE == 9:
		for r in [2, 4, 6]:
			for c in [2, 4, 6]:
				hoshi_points.append(Vector2i(r, c))
	elif BOARD_SIZE == 19:
		for r in [3, 9, 15]:
			for c in [3, 9, 15]:
				hoshi_points.append(Vector2i(r, c))
	elif BOARD_SIZE == 13:
		for r in [3, 6, 9]:
			for c in [3, 6, 9]:
				hoshi_points.append(Vector2i(r, c))
	else:
		hoshi_points = [Vector2i(2, 2), Vector2i(2, 6), Vector2i(6, 2), Vector2i(6, 6), Vector2i(4, 4)]
		
	var hoshi_radius = CELL_SIZE * 0.12
	for hp in hoshi_points:
		var pos = Vector2(hp.y * CELL_SIZE + CELL_SIZE / 2.0, hp.x * CELL_SIZE + CELL_SIZE / 2.0)
		draw_circle(pos, hoshi_radius, Color.BLACK)

	# Territory scoring color grid overlay on game over (alpha 0.35 on empty intersections)
	if winner != -1 and territory_map.size() > 0:
		for r in range(BOARD_SIZE):
			for c in range(BOARD_SIZE):
				if board[r][c] == null:
					var owner = territory_map[r][c]
					if owner != null:
						var cell_pos = Vector2(c * CELL_SIZE + 4, r * CELL_SIZE + 4)
						var cell_rect = Rect2(cell_pos, Vector2(CELL_SIZE - 8, CELL_SIZE - 8))
						var t_col = Color(0.1, 0.1, 0.1, 0.35) if owner == P_BLACK else Color(0.95, 0.95, 0.95, 0.35)
						draw_rect(cell_rect, t_col)

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Fin del juego! Ganó el jugador %s (Negro: %.1f, Blanco: %.1f)" % [winner, black_score, white_score]
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var who = "Negro (1)" if current == P_BLACK else "Blanco (2)"
		var p_col = COL_BLACK_STONE if current == P_BLACK else COL_WHITE_STONE
		status.text = "Turno: %s (Go 9x9)" % who
		if turn_indicator != null:
			turn_indicator.set_turn(current, who, p_col)
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
