extends Node2D

signal animation_finished

@export var use_texture_pieces: bool = true
@export var fallback_to_unicode: bool = true

const BOARD_SIZE = 8
const CELL_SIZE = 80.0
const P1 = 1
const P2 = 2

# Colors
const COL_LIGHT = Color(0.93, 0.85, 0.70)
const COL_DARK = Color(0.45, 0.30, 0.20)
const COL_SELECT = Color(1.0, 0.95, 0.30, 0.5)
const COL_VALID_MOVE = Color(0.2, 0.8, 0.2, 0.55)

var bridge
var current = P1
var winner = -1
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)
var check_king_pos = null
var selected_pos = null # Vector2i(row, col)
var valid_moves: Array = [] # Array of Vector2i
var rejected_cell = null
var highlight_moves_enabled: bool = true
var animating: bool = false
var active_animations: int = 0

var grid_container: GridContainer
var pieces_container: Node2D
var cell_nodes: Array = [] # 8x8 array of Control/ColorRect nodes
var piece_sprites: Array = [] # 8x8 array of Node2D/Sprite

var drag_layer: DragDropLayer
var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var mode_option_button: OptionButton
var opening_option_button: OptionButton

var in_opening_practice: bool = false
var current_opening_key: String = ""
var opening_step_index: int = 0
var opening_moves: Array = []

@onready var status: Label = $Status

func _ready() -> void:
	highlight_moves_enabled = SettingsMenu.get_saved_settings().get("highlight_moves", true)
	
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)
			
	_setup_ui()
	_init_board_state()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	network_hud.bind_bridge(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	bridge.connect("piece_moved", _on_piece_moved_signal)
	
	bridge.start_local_match_chess(P1, P2)
	current = bridge.current_player()
	
	_on_layout_changed(GameManager.get_layout() if gm != null else 0)
	_update_status()
	queue_redraw()

func _on_layout_changed(layout: int) -> void:
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	if layout == 2: # PHONE
		if mode_option_button != null:
			mode_option_button.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 10)
		if opening_option_button != null:
			opening_option_button.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 50)
		if turn_indicator != null:
			turn_indicator.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 90)
		if status != null:
			status.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 130)
	else: # DESKTOP / TABLET
		if mode_option_button != null:
			mode_option_button.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 10)
		if opening_option_button != null:
			opening_option_button.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 50)
		if turn_indicator != null:
			turn_indicator.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 90)
		if status != null:
			status.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 135)

func _setup_ui() -> void:
	grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = BOARD_SIZE
	grid_container.position = Vector2.ZERO
	add_child(grid_container)
	
	var col_l = current_theme.light_color if current_theme else COL_LIGHT
	var col_d = current_theme.dark_color if current_theme else COL_DARK
	
	cell_nodes.clear()
	for r in range(BOARD_SIZE):
		var row_arr = []
		for c in range(BOARD_SIZE):
			var cell = ColorRect.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			var is_light = (r + c) % 2 == 0
			cell.color = col_l if is_light else col_d
			grid_container.add_child(cell)
			row_arr.append(cell)
		cell_nodes.append(row_arr)
		
	pieces_container = Node2D.new()
	pieces_container.name = "PiecesContainer"
	add_child(pieces_container)
	
	# Drag & Drop Layer
	drag_layer = DragDropLayer.new()
	drag_layer.name = "DragDropLayer"
	drag_layer.cell_size = CELL_SIZE
	drag_layer.board_bounds = Vector2i(BOARD_SIZE, BOARD_SIZE)
	drag_layer.piece_drag_started.connect(_on_drag_started)
	drag_layer.piece_dropped.connect(_on_piece_dropped)
	add_child(drag_layer)
	
	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 90)
	add_child(turn_indicator)

	# Network Status HUD
	network_hud = NetworkStatusHUD.new()
	network_hud.name = "NetworkStatusHUD"
	add_child(network_hud)

	# Game Mode Selector
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 10)
	mode_option_button.custom_minimum_size = Vector2(300, 32)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (fácil)")
	mode_option_button.add_item("vs IA (medio)")
	mode_option_button.add_item("vs IA (difícil)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	# Opening Practice Selector
	opening_option_button = OptionButton.new()
	opening_option_button.name = "OpeningOptionButton"
	opening_option_button.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 50)
	opening_option_button.custom_minimum_size = Vector2(300, 32)
	opening_option_button.add_item("Partida libre (Sin apertura)")
	opening_option_button.add_item("Ruy López (e4 e5 Nf3 Nc6 Bb5)")
	opening_option_button.add_item("Gambito de Dama (d4 d5 c4)")
	opening_option_button.add_item("Defensa Siciliana (e4 c5 Nf3 d6 d4)")
	opening_option_button.add_item("Defensa Francesa (e4 e6 d4 d5)")
	opening_option_button.add_item("Apertura Italiana (e4 e5 Nf3 Nc6 Bc4)")
	opening_option_button.add_item("Defensa Caro-Kann (e4 c6 d4 d5)")
	opening_option_button.item_selected.connect(_on_opening_selected)
	add_child(opening_option_button)

func _on_mode_selected(index: int) -> void:
	in_opening_practice = false
	current_opening_key = ""
	opening_step_index = 0
	opening_moves.clear()
	if opening_option_button != null:
		opening_option_button.selected = 0

	if bridge != null:
		match index:
			0:
				bridge.start_local_match_chess(P1, P2)
			1:
				bridge.start_local_match_chess_vs_ai(P1, P2, 1)
			2:
				bridge.start_local_match_chess_vs_ai(P1, P2, 2)
			3:
				bridge.start_local_match_chess_vs_ai(P1, P2, 3)

	_init_board_state()
	current = bridge.current_player() if bridge else P1
	selected_pos = null
	valid_moves.clear()
	winner = -1
	_update_status()
	queue_redraw()

func _on_opening_selected(index: int) -> void:
	if index == 0:
		in_opening_practice = false
		current_opening_key = ""
		opening_step_index = 0
		opening_moves.clear()
		_update_status()
		queue_redraw()
		return

	var keys = ["ruy_lopez", "queen_gambit", "sicilian", "french", "italian", "caro_kann"]
	var key = keys[index - 1]
	start_opening_practice(key)

func start_opening_practice(key: String) -> void:
	if mode_option_button != null:
		mode_option_button.selected = 0
	if bridge != null:
		bridge.start_local_match_chess(P1, P2)
	_init_board_state()
	current = bridge.current_player() if bridge else P1
	in_opening_practice = true
	current_opening_key = key
	opening_step_index = 0
	var op_data = ChessOpenings.get_opening(key)
	opening_moves = op_data.get("moves", [])
	selected_pos = null
	valid_moves.clear()
	winner = -1
	_update_status()
	queue_redraw()

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var is_light = (r + c) % 2 == 0
			cell_nodes[r][c].color = theme.light_color if is_light else theme.dark_color
	queue_redraw()

func _reset_all_piece_scales() -> void:
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var sprite = piece_sprites[r][c]
			if sprite != null and is_instance_valid(sprite):
				sprite.scale = Vector2(1.0, 1.0)

func _bounce_piece(r: int, c: int) -> void:
	if animating:
		return
	if r < 0 or r >= BOARD_SIZE or c < 0 or c >= BOARD_SIZE:
		return
	var sprite = piece_sprites[r][c]
	if sprite != null and is_instance_valid(sprite):
		sprite.scale = Vector2(1.0, 1.0)
		var tw = sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.08)
		tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

func _on_drag_started(from_cell: Vector2i) -> void:
	if winner != -1 or animating: return
	var r = from_cell.x
	var c = from_cell.y
	var piece = piece_sprites[r][c]
	if piece != null and piece.get_meta("player") == current:
		_reset_all_piece_scales()
		selected_pos = from_cell
		valid_moves = _calculate_valid_moves(r, c)
		_bounce_piece(r, c)
		queue_redraw()
	else:
		_reset_all_piece_scales()
		drag_layer.clear_selection()
		selected_pos = null
		valid_moves.clear()
		queue_redraw()

func _on_piece_dropped(to_cell: Vector2i) -> void:
	if winner != -1 or selected_pos == null or animating: return
	
	var from_r = selected_pos.x
	var from_c = selected_pos.y
	var to_r = to_cell.x
	var to_c = to_cell.y
	
	_reset_all_piece_scales()
	selected_pos = null
	valid_moves.clear()
	queue_redraw()
	
	var cmd = {
		"command_type": "MovePieceCommand",
		"player": current,
		"from": {"row": from_r, "col": from_c},
		"to": {"row": to_r, "col": to_c},
		"promotion": null
	}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _process(_delta: float) -> void:
	if check_king_pos != null:
		queue_redraw()

func _find_king_pos(player_id: int):
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var sprite = piece_sprites[r][c]
			if sprite != null and is_instance_valid(sprite):
				if sprite.has_meta("kind") and sprite.get_meta("kind") == "King":
					if sprite.has_meta("player") and sprite.get_meta("player") == player_id:
						return Vector2i(r, c)
	return null

func _init_board_state() -> void:
	last_move_from = Vector2i(-1, -1)
	last_move_to = Vector2i(-1, -1)
	check_king_pos = null
	piece_sprites.clear()
	for r in range(BOARD_SIZE):
		var row_arr = []
		for c in range(BOARD_SIZE):
			row_arr.append(null)
		piece_sprites.append(row_arr)
		
	# Initial chess setup
	# Row 0: Black backline, Row 1: Black pawns
	# Row 6: White pawns, Row 7: White backline
	var backline = ["Rook", "Knight", "Bishop", "Queen", "King", "Bishop", "Knight", "Rook"]
	for c in range(8):
		_create_piece_sprite(0, c, P2, backline[c])
		_create_piece_sprite(1, c, P2, "Pawn")
		_create_piece_sprite(6, c, P1, "Pawn")
		_create_piece_sprite(7, c, P1, backline[c])

func _get_piece_texture_path(kind: String, player: int) -> String:
	var color_prefix = "white" if player == P1 else "black"
	var type_name = kind.to_lower()
	return "res://assets/chess/" + color_prefix + "_" + type_name + ".png"

func _create_piece_sprite(row: int, col: int, player: int, kind: String) -> Node2D:
	var piece_node = Node2D.new()
	piece_node.position = Vector2(col * CELL_SIZE + CELL_SIZE / 2.0, row * CELL_SIZE + CELL_SIZE / 2.0)
	
	var created_texture = false
	if use_texture_pieces:
		var tex_path = _get_piece_texture_path(kind, player)
		if ResourceLoader.exists(tex_path):
			var tex = load(tex_path) as Texture2D
			if tex != null:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				var tex_size = tex.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					var scale_factor = (CELL_SIZE * 0.75) / max(tex_size.x, tex_size.y)
					sprite.scale = Vector2(scale_factor, scale_factor)
				piece_node.add_child(sprite)
				created_texture = true

	if not created_texture and fallback_to_unicode:
		var shadow_label = Label.new()
		shadow_label.text = _get_piece_symbol(kind, player)
		shadow_label.add_theme_font_size_override("font_size", 42)
		shadow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shadow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shadow_label.size = Vector2(CELL_SIZE, CELL_SIZE)
		shadow_label.position = -Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0) + Vector2(2, 2)
		shadow_label.add_theme_color_override("font_color", Color(0, 0, 0, 0.4))
		piece_node.add_child(shadow_label)

		var label = Label.new()
		label.text = _get_piece_symbol(kind, player)
		label.add_theme_font_size_override("font_size", 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(CELL_SIZE, CELL_SIZE)
		label.position = -Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var text_color = GameManager.get_player_color(player)
		label.add_theme_color_override("font_color", text_color)
		piece_node.add_child(label)

	piece_node.set_meta("player", player)
	piece_node.set_meta("kind", kind)
	
	pieces_container.add_child(piece_node)
	piece_sprites[row][col] = piece_node
	return piece_node

func _get_piece_symbol(kind: String, player: int) -> String:
	match kind:
		"Pawn": return "♙" if player == P1 else "♟"
		"Rook": return "♖" if player == P1 else "♜"
		"Knight": return "♘" if player == P1 else "♞"
		"Bishop": return "♗" if player == P1 else "♝"
		"Queen": return "♕" if player == P1 else "♛"
		"King": return "♔" if player == P1 else "♚"
		_: return "?"

var touch_down_pos: Vector2 = Vector2.ZERO
var touch_start_cell: Vector2i = Vector2i(-1, -1)
var is_touch_dragging: bool = false
const DEAD_ZONE: float = 8.0

func _gui_input(event: InputEvent) -> void:
	_handle_unified_input(event)

func _input(event: InputEvent) -> void:
	_handle_unified_input(event)

func _handle_unified_input(event: InputEvent) -> void:
	if winner != -1 or animating:
		return

	var event_pos := Vector2.ZERO
	var is_press := false
	var is_release := false
	var is_drag := false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			event_pos = event.position
			is_press = event.pressed
			is_release = not event.pressed
	elif event is InputEventScreenTouch:
		event_pos = event.position
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			event_pos = event.position
			is_drag = true
	elif event is InputEventScreenDrag:
		event_pos = event.position
		is_drag = true

	if is_press:
		touch_down_pos = event_pos
		touch_start_cell = Vector2i(int(event_pos.y / CELL_SIZE), int(event_pos.x / CELL_SIZE))
		is_touch_dragging = false
	elif is_drag:
		if touch_down_pos.distance_to(event_pos) > DEAD_ZONE:
			is_touch_dragging = true
	elif is_release:
		var dist = touch_down_pos.distance_to(event_pos)
		var col = int(event_pos.x / CELL_SIZE)
		var row = int(event_pos.y / CELL_SIZE)
		if dist <= DEAD_ZONE:
			if row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE:
				_handle_cell_click(row, col)
		else:
			var release_cell = Vector2i(row, col)
			if touch_start_cell != release_cell and touch_start_cell.x >= 0 and touch_start_cell.x < BOARD_SIZE and touch_start_cell.y >= 0 and touch_start_cell.y < BOARD_SIZE:
				var piece = piece_sprites[touch_start_cell.x][touch_start_cell.y]
				if piece != null and piece.get_meta("player") == current:
					_reset_all_piece_scales()
					selected_pos = touch_start_cell
					valid_moves = _calculate_valid_moves(touch_start_cell.x, touch_start_cell.y)
					_bounce_piece(touch_start_cell.x, touch_start_cell.y)
					_handle_cell_click(row, col)
		touch_start_cell = Vector2i(-1, -1)
		is_touch_dragging = false

func _handle_cell_click(row: int, col: int) -> void:
	if animating:
		return

	if selected_pos == null:
		var piece = piece_sprites[row][col]
		if piece != null and piece.get_meta("player") == current:
			_reset_all_piece_scales()
			selected_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_moves(row, col)
			_bounce_piece(row, col)
			queue_redraw()
	else:
		if selected_pos.x == row and selected_pos.y == col:
			_reset_all_piece_scales()
			selected_pos = null
			valid_moves.clear()
			queue_redraw()
			return
			
		var piece_at_target = piece_sprites[row][col]
		if piece_at_target != null and piece_at_target.get_meta("player") == current:
			_reset_all_piece_scales()
			selected_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_moves(row, col)
			_bounce_piece(row, col)
			queue_redraw()
			return
			
		var from_pos = selected_pos
		_reset_all_piece_scales()
		selected_pos = null
		valid_moves.clear()
		queue_redraw()
		
		var cmd = {
			"command_type": "MovePieceCommand",
			"player": current,
			"from": {"row": from_pos.x, "col": from_pos.y},
			"to": {"row": row, "col": col},
			"promotion": null
		}
		bridge.send_command_json(current, JSON.stringify(cmd))

func _calculate_valid_moves(r: int, c: int) -> Array:
	var moves: Array = []
	if bridge == null or not bridge.has_method("get_legal_moves"):
		return moves
	var legal_moves = bridge.get_legal_moves(current)
	for m in legal_moves:
		var f_row := -1
		var f_col := -1
		var t_row := -1
		var t_col := -1

		if m.has("from") and m.from is Dictionary:
			f_row = m.from.get("row", -1)
			f_col = m.from.get("col", -1)
		elif m.has("from_row"):
			f_row = m.get("from_row", -1)
			f_col = m.get("from_col", -1)

		if m.has("to") and m.to is Dictionary:
			t_row = m.to.get("row", -1)
			t_col = m.to.get("col", -1)
		elif m.has("to_row"):
			t_row = m.get("to_row", -1)
			t_col = m.get("to_col", -1)

		if f_row == r and f_col == c:
			var dest = Vector2i(t_row, t_col)
			if not dest in moves:
				moves.append(dest)
	return moves

func _is_in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE

func _move_piece_sprite(from_r: int, from_c: int, to_r: int, to_c: int, is_promotion: bool = false) -> void:
	last_move_from = Vector2i(from_r, from_c)
	last_move_to = Vector2i(to_r, to_c)
	var piece = piece_sprites[from_r][from_c]
	if piece == null:
		return
		
	animating = true
	_reset_all_piece_scales()
	active_animations += 1

	var target_piece = piece_sprites[to_r][to_c]
	if target_piece != null:
		target_piece.queue_free()
		piece_sprites[to_r][to_c] = null
		
	piece_sprites[from_r][from_c] = null
	piece_sprites[to_r][to_c] = piece
	
	var target_pos = Vector2(to_c * CELL_SIZE + CELL_SIZE / 2.0, to_r * CELL_SIZE + CELL_SIZE / 2.0)
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(piece, "position", target_pos, 0.25)

	if is_promotion:
		tween.chain().tween_property(piece, "modulate:a", 0.0, 0.1)
		tween.tween_property(piece, "modulate:a", 1.0, 0.15)
		tween.tween_property(piece, "modulate:a", 0.5, 0.1)
		tween.tween_property(piece, "modulate:a", 1.0, 0.1)

	tween.finished.connect(func():
		active_animations -= 1
		if active_animations <= 0:
			active_animations = 0
			animating = false
			animation_finished.emit()
	)

func _on_piece_moved_signal(player: int, from_r: int, from_c: int, to_r: int, to_c: int, cap_r: int, cap_c: int, prom: bool) -> void:
	if in_opening_practice and opening_step_index < opening_moves.size():
		var expected = opening_moves[opening_step_index]
		if from_r == expected.from.x and from_c == expected.from.y and to_r == expected.to.x and to_c == expected.to.y:
			opening_step_index += 1
			if opening_step_index >= opening_moves.size():
				in_opening_practice = false
		else:
			in_opening_practice = false

	var is_capture = (cap_r >= 0 and cap_c >= 0) or (piece_sprites[to_r][to_c] != null)
	if is_capture:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_capture()
	else:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_move()

	_move_piece_sprite(from_r, from_c, to_r, to_c, prom)
	current = bridge.current_player()
	selected_pos = null
	valid_moves.clear()
	_update_status()
	queue_redraw()

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "PieceMovedEvent":
				var from_dict = event.get("from", {})
				var to_dict = event.get("to", {})
				var from_r = int(from_dict.get("row", 0))
				var from_c = int(from_dict.get("col", 0))
				var to_r = int(to_dict.get("row", 0))
				var to_c = int(to_dict.get("col", 0))
				var is_prom = event.get("promotion") != null or event.get("promoted", false)
				_move_piece_sprite(from_r, from_c, to_r, to_c, is_prom)
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null:
					w = 0
				_on_game_over(int(w))

			current = bridge.current_player()
			var is_check = (event.get("event_type") == "CheckEvent") or (event.get("in_check") == true)
			if is_check:
				check_king_pos = _find_king_pos(current)
			else:
				check_king_pos = null

	current = bridge.current_player()
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	winner = w
	check_king_pos = null
	selected_pos = null
	valid_moves.clear()
	_update_status()
	queue_redraw()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_game_over()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_invalid()
		
	if selected_pos != null:
		rejected_cell = selected_pos
	
	queue_redraw()
	var timer = get_tree().create_timer(0.3)
	timer.timeout.connect(func():
		rejected_cell = null
		queue_redraw()
	)

func _draw() -> void:
	# Halo rojo pulsante sobre la casilla del rey en jaque
	if check_king_pos != null and _is_in_bounds(check_king_pos.x, check_king_pos.y):
		var king_rect = Rect2(check_king_pos.y * CELL_SIZE, check_king_pos.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		var alpha = 0.3 + 0.2 * sin(Time.get_ticks_msec() * 0.005)
		draw_rect(king_rect, Color(1.0, 0.0, 0.0, alpha))

	# Highlight del último movimiento
	if last_move_from != Vector2i(-1, -1) and _is_in_bounds(last_move_from.x, last_move_from.y):
		var lm_from_rect = Rect2(last_move_from.y * CELL_SIZE, last_move_from.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(lm_from_rect, Color(0.9, 0.85, 0.3, 0.35))
	if last_move_to != Vector2i(-1, -1) and _is_in_bounds(last_move_to.x, last_move_to.y):
		var lm_to_rect = Rect2(last_move_to.y * CELL_SIZE, last_move_to.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(lm_to_rect, Color(0.9, 0.85, 0.3, 0.35))

	if in_opening_practice and opening_step_index < opening_moves.size():
		var exp_move = opening_moves[opening_step_index]
		var from_pos = exp_move.from
		var to_pos = exp_move.to
		var from_rect = Rect2(from_pos.y * CELL_SIZE, from_pos.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		var to_rect = Rect2(to_pos.y * CELL_SIZE, to_pos.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(from_rect, Color(0.0, 0.7, 1.0, 0.45))
		draw_rect(from_rect, Color(0.0, 0.5, 1.0, 0.9), false, 3.0)
		draw_rect(to_rect, Color(0.2, 0.9, 0.3, 0.45))
		draw_rect(to_rect, Color(0.1, 0.8, 0.2, 0.9), false, 3.0)

	if selected_pos != null:
		var sel_rect = Rect2(selected_pos.y * CELL_SIZE, selected_pos.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(sel_rect, COL_SELECT)
		draw_rect(sel_rect, Color(1.0, 0.84, 0.0, 0.9), false, 3.0) # Golden border
		
	if rejected_cell != null:
		var rej_rect = Rect2(rejected_cell.y * CELL_SIZE, rejected_cell.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(rej_rect, Color(1.0, 0.2, 0.2, 0.6))

	if highlight_moves_enabled and selected_pos != null:
		for move_pos in valid_moves:
			var center = Vector2(move_pos.y * CELL_SIZE + CELL_SIZE / 2.0, move_pos.x * CELL_SIZE + CELL_SIZE / 2.0)
			draw_circle(center, CELL_SIZE * 0.25, COL_VALID_MOVE)

	# Coordenadas del tablero (a-h en la fila inferior, 1-8 en la columna izquierda)
	var font: Font = null
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			var th = tm.get_current_theme() if tm.has_method("get_current_theme") else tm.get_theme()
			if th != null:
				font = th.piece_font
	if font == null:
		font = ThemeDB.fallback_font

	var font_sz := int(CELL_SIZE * 0.22)
	var col_l = current_theme.light_color if current_theme else COL_LIGHT
	var col_d = current_theme.dark_color if current_theme else COL_DARK

	# Letras a-h en la fila inferior (row 7)
	for c in range(BOARD_SIZE):
		var is_light = (7 + c) % 2 == 0
		var opp_color = col_d if is_light else col_l
		var coord_color = Color(opp_color.r, opp_color.g, opp_color.b, 0.6)
		var letter = String.chr("a".unicode_at(0) + c)
		var pos = Vector2(c * CELL_SIZE, (7 + 1) * CELL_SIZE - 4.0)
		draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_RIGHT, CELL_SIZE - 4.0, font_sz, coord_color)

	# Números 1-8 en la columna izquierda (col 0)
	for r in range(BOARD_SIZE):
		var is_light = (r + 0) % 2 == 0
		var opp_color = col_d if is_light else col_l
		var coord_color = Color(opp_color.r, opp_color.g, opp_color.b, 0.6)
		var number = str(8 - r)
		var pos = Vector2(4.0, r * CELL_SIZE + font_sz + 2.0)
		draw_string(font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_sz, coord_color)

	# Borde del tablero
	var board_rect = Rect2(0, 0, BOARD_SIZE * CELL_SIZE, BOARD_SIZE * CELL_SIZE)
	draw_rect(board_rect, Color(0.2, 0.12, 0.05, 1.0), false, 3.0)

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Jaque mate! Ganó el jugador %s" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var p_name = "Jugador %s" % current
		var p_col = GameManager.get_player_color(current)
		if in_opening_practice and opening_step_index < opening_moves.size():
			var expected = opening_moves[opening_step_index]
			var op_data = ChessOpenings.get_opening(current_opening_key)
			status.text = "Práctica: %s | Esperado: %s" % [op_data.get("name", "Apertura"), expected.get("notation", "")]
		else:
			if opening_moves.size() > 0 and opening_step_index >= opening_moves.size():
				status.text = "¡Apertura completada! Continúa en partida libre (Turno: P%s)" % current
			elif opening_moves.size() > 0:
				status.text = "Desviado de apertura. Partida libre (Turno: P%s)" % current
			else:
				status.text = "Turno: Jugador %s (Ajedrez)" % current

		if turn_indicator != null:
			turn_indicator.set_turn(current, p_name, p_col)
