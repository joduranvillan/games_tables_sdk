extends Node2D

const BOARD_ROWS = 10
const BOARD_COLS = 9
const CELL_SIZE = 65.0
const OFFSET_X = 80.0
const OFFSET_Y = 50.0

const P_RED = 1
const P_BLACK = 2

# Kanji mapping for Xiangqi
const KANJI_RED = {
	"General": "帥", "Advisor": "仕", "Elephant": "相",
	"Knight": "馬", "Rook": "車", "Cannon": "砲", "Pawn": "兵"
}
const KANJI_BLACK = {
	"General": "將", "Advisor": "士", "Elephant": "象",
	"Knight": "馬", "Rook": "車", "Cannon": "砲", "Pawn": "卒"
}

# Colors
const COL_BOARD_BG = Color(0.92, 0.82, 0.62)
const COL_LINE = Color(0.2, 0.15, 0.1)
const COL_RED_PIECE = Color(0.85, 0.15, 0.15)
const COL_BLACK_PIECE = Color(0.15, 0.15, 0.20)
const COL_PIECE_BG = Color(0.98, 0.94, 0.85)
const COL_SELECT = Color(1.0, 0.9, 0.2, 0.5)

var bridge
var board: Array = [] # 10x9 array of piece dicts {"player": int, "kind": String} or null
var piece_nodes: Array = [] # 10x9 array of Control nodes
var current: int = P_RED
var winner: int = -1
var selected_pos = null # Vector2i(row, col)
var mode_option_button: OptionButton

@onready var status: Label = $Status

func _ready() -> void:
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(OFFSET_X, OFFSET_Y + (BOARD_ROWS - 1) * CELL_SIZE + 35)
	mode_option_button.custom_minimum_size = Vector2(180, 32)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Negro)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	_init_board_state()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	bridge.start_local_match_xiangqi(P_RED, P_BLACK)
	current = bridge.current_player()
	
	_update_status()
	queue_redraw()

func _on_mode_selected(index: int) -> void:
	winner = -1
	selected_pos = null
	for r in range(BOARD_ROWS):
		for c in range(BOARD_COLS):
			if piece_nodes[r][c] != null and is_instance_valid(piece_nodes[r][c]):
				piece_nodes[r][c].queue_free()
				piece_nodes[r][c] = null

	if bridge != null:
		if index == 1:
			bridge.start_local_match_xiangqi_vs_ai(P_RED, P_BLACK)
		else:
			bridge.start_local_match_xiangqi(P_RED, P_BLACK)

	_init_board_state()
	current = bridge.current_player() if bridge else P_RED
	_update_status()
	queue_redraw()

func _init_board_state() -> void:
	board.clear()
	piece_nodes.clear()
	
	for r in range(BOARD_ROWS):
		var row_arr = []
		var node_arr = []
		for c in range(BOARD_COLS):
			row_arr.append(null)
			node_arr.append(null)
		board.append(row_arr)
		piece_nodes.append(node_arr)
		
	# Black (P2) at rows 0..3
	var black_back = ["Rook", "Knight", "Elephant", "Advisor", "General", "Advisor", "Elephant", "Knight", "Rook"]
	for c in range(9):
		_create_piece(0, c, P_BLACK, black_back[c])
	_create_piece(2, 1, P_BLACK, "Cannon")
	_create_piece(2, 7, P_BLACK, "Cannon")
	for c in [0, 2, 4, 6, 8]:
		_create_piece(3, c, P_BLACK, "Pawn")
		
	# Red (P1) at rows 6..9
	var red_back = ["Rook", "Knight", "Elephant", "Advisor", "General", "Advisor", "Elephant", "Knight", "Rook"]
	for c in range(9):
		_create_piece(9, c, P_RED, red_back[c])
	_create_piece(7, 1, P_RED, "Cannon")
	_create_piece(7, 7, P_RED, "Cannon")
	for c in [0, 2, 4, 6, 8]:
		_create_piece(6, c, P_RED, "Pawn")

func _get_intersection_center(row: int, col: int) -> Vector2:
	return Vector2(OFFSET_X + col * CELL_SIZE, OFFSET_Y + row * CELL_SIZE)

func _create_piece(row: int, col: int, player: int, kind: String) -> void:
	board[row][col] = {"player": player, "kind": kind}
	
	var piece_ctrl = Control.new()
	piece_ctrl.size = Vector2(CELL_SIZE * 0.85, CELL_SIZE * 0.85)
	var center = _get_intersection_center(row, col)
	piece_ctrl.position = center - piece_ctrl.size / 2.0
	
	# Circular background
	var bg = TextureRect.new()
	bg.size = piece_ctrl.size
	var img = Image.create(60, 60, false, Image.FORMAT_RGBA8)
	var ring_color = COL_RED_PIECE if player == P_RED else COL_BLACK_PIECE
	for x in range(60):
		for y in range(60):
			var dist = Vector2(x - 30, y - 30).length()
			if dist <= 27:
				img.set_pixel(x, y, COL_PIECE_BG)
			elif dist <= 29:
				img.set_pixel(x, y, ring_color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	bg.texture = ImageTexture.create_from_image(img)
	piece_ctrl.add_child(bg)
	
	# Kanji Label
	var label = Label.new()
	var kanji_dict = KANJI_RED if player == P_RED else KANJI_BLACK
	label.text = kanji_dict.get(kind, "?")
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", ring_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = piece_ctrl.size
	piece_ctrl.add_child(label)
	
	add_child(piece_ctrl)
	piece_nodes[row][col] = piece_ctrl

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
		var col = int(round((click_pos.x - OFFSET_X) / CELL_SIZE))
		var row = int(round((click_pos.y - OFFSET_Y) / CELL_SIZE))
		if row >= 0 and row < BOARD_ROWS and col >= 0 and col < BOARD_COLS:
			_handle_cell_click(row, col)

func _handle_cell_click(row: int, col: int) -> void:
	if selected_pos == null:
		var piece = board[row][col]
		if piece != null and piece.get("player") == current:
			selected_pos = Vector2i(row, col)
			queue_redraw()
	else:
		if selected_pos.x == row and selected_pos.y == col:
			selected_pos = null
			queue_redraw()
			return
			
		var piece_at_target = board[row][col]
		if piece_at_target != null and piece_at_target.get("player") == current:
			selected_pos = Vector2i(row, col)
			queue_redraw()
			return
			
		var from_pos = selected_pos
		selected_pos = null
		queue_redraw()
		
		var cmd = {
			"command_type": "MovePieceCommand",
			"player": current,
			"from": [from_pos.x, from_pos.y],
			"to": [row, col]
		}
		bridge.send_command_json(current, JSON.stringify(cmd))

func _move_piece_node(from_r: int, from_c: int, to_r: int, to_c: int) -> void:
	var piece_data = board[from_r][from_c]
	if piece_data == null:
		return
		
	var target_node = piece_nodes[to_r][to_c]
	if target_node != null and is_instance_valid(target_node):
		target_node.queue_free()
		piece_nodes[to_r][to_c] = null
		
	board[to_r][to_c] = piece_data
	board[from_r][from_c] = null
	
	var node = piece_nodes[from_r][from_c]
	piece_nodes[from_r][from_c] = null
	piece_nodes[to_r][to_c] = node
	
	if node != null:
		var target_center = _get_intersection_center(to_r, to_c)
		var target_pos = target_center - node.size / 2.0
		var tween = create_tween()
		tween.tween_property(node, "position", target_pos, 0.2)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "PieceMovedEvent":
				var from = event.get("from", [0, 0])
				var to = event.get("to", [0, 0])
				_move_piece_node(int(from[0]), int(from[1]), int(to[0]), int(to[1]))
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
	queue_redraw()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason

func _draw() -> void:
	# Board background panel
	var rect = Rect2(OFFSET_X - 30, OFFSET_Y - 30, (BOARD_COLS - 1) * CELL_SIZE + 60, (BOARD_ROWS - 1) * CELL_SIZE + 60)
	draw_rect(rect, COL_BOARD_BG)
	
	# Horizontal grid lines
	for r in range(BOARD_ROWS):
		var p1 = _get_intersection_center(r, 0)
		var p2 = _get_intersection_center(r, BOARD_COLS - 1)
		draw_line(p1, p2, COL_LINE, 2.0)
		
	# Vertical grid lines (interrupted at the river between rows 4 and 5)
	for c in range(BOARD_COLS):
		if c == 0 or c == BOARD_COLS - 1:
			var p1 = _get_intersection_center(0, c)
			var p2 = _get_intersection_center(BOARD_ROWS - 1, c)
			draw_line(p1, p2, COL_LINE, 2.0)
		else:
			var p1 = _get_intersection_center(0, c)
			var p2 = _get_intersection_center(4, c)
			draw_line(p1, p2, COL_LINE, 2.0)
			
			var p3 = _get_intersection_center(5, c)
			var p4 = _get_intersection_center(BOARD_ROWS - 1, c)
			draw_line(p3, p4, COL_LINE, 2.0)
			
	# Palaces (X-lines)
	# Top palace (rows 0..2, cols 3..5)
	draw_line(_get_intersection_center(0, 3), _get_intersection_center(2, 5), COL_LINE, 1.5)
	draw_line(_get_intersection_center(0, 5), _get_intersection_center(2, 3), COL_LINE, 1.5)
	# Bottom palace (rows 7..9, cols 3..5)
	draw_line(_get_intersection_center(7, 3), _get_intersection_center(9, 5), COL_LINE, 1.5)
	draw_line(_get_intersection_center(7, 5), _get_intersection_center(9, 3), COL_LINE, 1.5)
	
	# River text
	var river_y = (OFFSET_Y + 4 * CELL_SIZE + OFFSET_Y + 5 * CELL_SIZE) / 2.0 - 10
	draw_string(ThemeDB.fallback_font, Vector2(OFFSET_X + 1.5 * CELL_SIZE, river_y), "楚 河          漢 界", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COL_LINE)
	
	# Selection highlight
	if selected_pos != null:
		var center = _get_intersection_center(selected_pos.x, selected_pos.y)
		draw_circle(center, CELL_SIZE * 0.45, COL_SELECT)

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Jaque mate! Ganó el jugador %s (Xiangqi)" % winner
	else:
		var who = "Rojo (1)" if current == P_RED else "Negro (2)"
		status.text = "Turno: %s (Xiangqi)" % who
