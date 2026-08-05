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

@onready var status: Label = $Status

func _ready() -> void:
	highlight_moves_enabled = SettingsMenu.get_saved_settings().get("highlight_moves", true)
	
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)
			
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
	
	_update_status()
	queue_redraw()

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
	turn_indicator.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 45)
	add_child(turn_indicator)

	# Network Status HUD
	network_hud = NetworkStatusHUD.new()
	network_hud.name = "NetworkStatusHUD"
	add_child(network_hud)

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var is_light = (r + c) % 2 == 0
			cell_nodes[r][c].color = theme.light_color if is_light else theme.dark_color
	queue_redraw()

func _on_drag_started(from_cell: Vector2i) -> void:
	if winner != -1 or animating: return
	var r = from_cell.x
	var c = from_cell.y
	var piece = piece_sprites[r][c]
	if piece != null and piece.get_meta("player") == current:
		selected_pos = from_cell
		valid_moves = _calculate_valid_moves(r, c)
		queue_redraw()
	else:
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

func _init_board_state() -> void:
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

func _input(event: InputEvent) -> void:
	if winner != -1 or animating:
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
		var col = int(click_pos.x / CELL_SIZE)
		var row = int(click_pos.y / CELL_SIZE)
		if row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE:
			_handle_cell_click(row, col)

func _handle_cell_click(row: int, col: int) -> void:
	if animating:
		return

	if selected_pos == null:
		var piece = piece_sprites[row][col]
		if piece != null and piece.get_meta("player") == current:
			selected_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_moves(row, col)
			queue_redraw()
	else:
		if selected_pos.x == row and selected_pos.y == col:
			selected_pos = null
			valid_moves.clear()
			queue_redraw()
			return
			
		var piece_at_target = piece_sprites[row][col]
		if piece_at_target != null and piece_at_target.get_meta("player") == current:
			selected_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_moves(row, col)
			queue_redraw()
			return
			
		var from_pos = selected_pos
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
	var piece = piece_sprites[r][c]
	if piece == null:
		return moves
		
	var kind = piece.get_meta("kind")
	var player = piece.get_meta("player")
	var forward = -1 if player == P1 else 1
	
	match kind:
		"Pawn":
			var nr = r + forward
			if _is_in_bounds(nr, c) and piece_sprites[nr][c] == null:
				moves.append(Vector2i(nr, c))
				var start_row = 6 if player == P1 else 1
				var nnr = r + forward * 2
				if r == start_row and _is_in_bounds(nnr, c) and piece_sprites[nnr][c] == null:
					moves.append(Vector2i(nnr, c))
			for dc in [-1, 1]:
				var tc = c + dc
				if _is_in_bounds(nr, tc):
					var target = piece_sprites[nr][tc]
					if target != null and target.get_meta("player") != player:
						moves.append(Vector2i(nr, tc))
		"Knight":
			var offsets = [
				Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, -2), Vector2i(-1, 2),
				Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1)
			]
			for off in offsets:
				var tr = r + off.x
				var tc = c + off.y
				if _is_in_bounds(tr, tc):
					var target = piece_sprites[tr][tc]
					if target == null or target.get_meta("player") != player:
						moves.append(Vector2i(tr, tc))
		"King":
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					if dr == 0 and dc == 0: continue
					var tr = r + dr
					var tc = c + dc
					if _is_in_bounds(tr, tc):
						var target = piece_sprites[tr][tc]
						if target == null or target.get_meta("player") != player:
							moves.append(Vector2i(tr, tc))
		"Rook", "Bishop", "Queen":
			var dirs = []
			if kind == "Rook" or kind == "Queen":
				dirs.append_array([Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)])
			if kind == "Bishop" or kind == "Queen":
				dirs.append_array([Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
			for dir in dirs:
				var tr = r + dir.x
				var tc = c + dir.y
				while _is_in_bounds(tr, tc):
					var target = piece_sprites[tr][tc]
					if target == null:
						moves.append(Vector2i(tr, tc))
					else:
						if target.get_meta("player") != player:
							moves.append(Vector2i(tr, tc))
						break
					tr += dir.x
					tc += dir.y
	return moves

func _is_in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE

func _move_piece_sprite(from_r: int, from_c: int, to_r: int, to_c: int, is_promotion: bool = false) -> void:
	var piece = piece_sprites[from_r][from_c]
	if piece == null:
		return
		
	animating = true
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
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	winner = w
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

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Jaque mate! Ganó el jugador %s" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var p_name = "Jugador %s" % current
		var p_col = GameManager.get_player_color(current)
		status.text = "Turno: Jugador %s (Ajedrez)" % current
		if turn_indicator != null:
			turn_indicator.set_turn(current, p_name, p_col)
