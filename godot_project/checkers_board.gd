## Vista de damas: dibuja el tablero, toma el input táctil/mouse y habla
## con el motor Rust a través del nodo nativo `OpenTableBridge` (del
## GDExtension open_table_godot). Este script NUNCA valida reglas: manda
## el movimiento al bridge y solo actualiza lo que dibuja cuando el motor
## confirma con la señal `piece_moved`. Así la vista no puede
## "desincronizarse" de la verdad que vive en Rust.
extends Node2D

signal animation_finished

const BOARD := 8
const CELL := 90.0
const P_TOP := 1     # "increasing": arranca en filas 0-2, avanza hacia abajo
const P_BOTTOM := 2  # "decreasing": arranca en filas 5-7, avanza hacia arriba

# Colores
const COL_LIGHT := Color(0.93, 0.85, 0.70)
const COL_DARK := Color(0.45, 0.30, 0.20)
const COL_SELECT := Color(1.0, 0.95, 0.30, 0.55)
const COL_KING := Color(1.0, 0.85, 0.0)

class PieceSprite extends Node2D:
	var owner_id: int = 1
	var king: bool = false
	var cell_size: float = 90.0

	const COL_KING := Color(1.0, 0.85, 0.0)

	func _draw() -> void:
		var pcolor := GameManager.get_player_color(owner_id)
		draw_circle(Vector2.ZERO, cell_size * 0.38, pcolor)
		draw_arc(Vector2.ZERO, cell_size * 0.38, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)
		if king:
			draw_circle(Vector2.ZERO, cell_size * 0.16, COL_KING)

var bridge                # OpenTableBridge (nodo nativo del GDExtension)
var board: Array = []     # board[row][col] = null | {"owner": int, "king": bool}
var piece_sprites: Array = [] # piece_sprites[row][col] = PieceSprite | null
var pieces_container: Node2D
var selected = null       # {"row": int, "col": int} o null
var valid_moves: Array[Vector2i] = [] # Posiciones de destino válidas para resaltar
var animating: bool = false # Bloquea el input durante las animaciones
var current: int = P_TOP  # de quién es el turno (según el motor)
var winner: int = -1

var drag_layer: DragDropLayer
var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var mandatory_label: Label
var rules_popup: RulesPopup

@onready var status: Label = $Status

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	_init_board()
	_setup_ui_layers()

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	network_hud.bind_bridge(bridge)

	# Señales del motor -> actualizaciones de la vista.
	bridge.connect("piece_moved", _on_piece_moved)
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)

	bridge.start_local_match(P_TOP, P_BOTTOM)
	current = bridge.current_player()

	_update_status()
	queue_redraw()

func _setup_ui_layers() -> void:
	# Mandatory capture banner at top
	mandatory_label = Label.new()
	mandatory_label.name = "MandatoryCaptureLabel"
	mandatory_label.text = "¡Captura obligatoria!"
	mandatory_label.position = Vector2(10, 10)
	mandatory_label.size = Vector2(BOARD * CELL - 20, 40)
	mandatory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mandatory_label.add_theme_font_size_override("font_size", 22)
	mandatory_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	mandatory_label.hide()
	add_child(mandatory_label)

	drag_layer = DragDropLayer.new()
	drag_layer.name = "DragDropLayer"
	drag_layer.cell_size = CELL
	drag_layer.board_bounds = Vector2i(BOARD, BOARD)
	drag_layer.piece_drag_started.connect(_on_drag_started)
	drag_layer.piece_dropped.connect(_on_piece_dropped)
	add_child(drag_layer)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(10, BOARD * CELL + 45)
	add_child(turn_indicator)

	network_hud = NetworkStatusHUD.new()
	network_hud.name = "NetworkStatusHUD"
	add_child(network_hud)

	var btn_rules = Button.new()
	btn_rules.text = " ? "
	btn_rules.position = Vector2(BOARD * CELL - 45, BOARD * CELL + 45)
	btn_rules.custom_minimum_size = Vector2(36, 36)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("checkers"))
	add_child(btn_rules)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 100)
	add_child(rules_popup)

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	queue_redraw()

func _get_pieces_with_captures(player_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r in range(BOARD):
		for c in range(BOARD):
			var cell = board[r][c]
			if cell != null and cell.owner == player_id:
				if _piece_has_capture(r, c):
					result.append(Vector2i(r, c))
	return result

func _piece_has_capture(r: int, c: int) -> bool:
	var cell = board[r][c]
	if cell == null: return false
	var directions: Array[Vector2i] = []
	if cell.king:
		directions = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
	elif cell.owner == P_TOP:
		directions = [Vector2i(1, -1), Vector2i(1, 1)]
	else:
		directions = [Vector2i(-1, -1), Vector2i(-1, 1)]

	for d in directions:
		var mid_r = r + d.x
		var mid_c = c + d.y
		var land_r = r + d.x * 2
		var land_c = c + d.y * 2
		if land_r >= 0 and land_r < BOARD and land_c >= 0 and land_c < BOARD:
			if board[mid_r][mid_c] != null and board[mid_r][mid_c].owner != cell.owner:
				if board[land_r][land_c] == null:
					return true
	return false

func _show_mandatory_capture_warning() -> void:
	if mandatory_label != null:
		mandatory_label.text = "¡Captura obligatoria!"
		mandatory_label.modulate.a = 1.0
		mandatory_label.show()
		var tw = create_tween()
		tw.tween_interval(1.5)
		tw.tween_property(mandatory_label, "modulate:a", 0.0, 0.5)
		tw.finished.connect(func(): mandatory_label.hide())

	var capturing_pieces = _get_pieces_with_captures(current)
	for pos in capturing_pieces:
		var sprite = piece_sprites[pos.x][pos.y]
		if sprite != null and is_instance_valid(sprite):
			_flash_sprite_red(sprite)

func _flash_sprite_red(sprite: Node2D) -> void:
	var anim_player = sprite.get_node_or_null("FlashAnim")
	if anim_player == null:
		anim_player = AnimationPlayer.new()
		anim_player.name = "FlashAnim"
		sprite.add_child(anim_player)
		var lib = AnimationLibrary.new()
		var anim = Animation.new()
		var track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, ":modulate")
		anim.track_insert_key(track_idx, 0.0, Color.WHITE)
		anim.track_insert_key(track_idx, 0.2, Color(1.0, 0.1, 0.1))
		anim.track_insert_key(track_idx, 0.4, Color.WHITE)
		anim.track_insert_key(track_idx, 0.6, Color(1.0, 0.1, 0.1))
		anim.track_insert_key(track_idx, 0.8, Color.WHITE)
		lib.add_animation("flash", anim)
		anim_player.add_animation_library("", lib)
	anim_player.play("flash")

func _on_drag_started(from_cell: Vector2i) -> void:
	if winner != -1 or animating: return
	var r = from_cell.x
	var c = from_cell.y
	var cell = board[r][c]
	if cell != null and cell.owner == current:
		selected = {"row": r, "col": c}
		valid_moves = _calculate_valid_moves(r, c)
		queue_redraw()
	else:
		drag_layer.clear_selection()
		selected = null
		valid_moves.clear()
		queue_redraw()

func _on_piece_dropped(to_cell: Vector2i) -> void:
	if winner != -1 or selected == null or animating: return
	var from_row = selected.row
	var from_col = selected.col
	var to_row = to_cell.x
	var to_col = to_cell.y

	var caps = _get_pieces_with_captures(current)
	if caps.size() > 0 and abs(to_row - from_row) != 2:
		_show_mandatory_capture_warning()

	selected = null
	valid_moves.clear()
	queue_redraw()
	bridge.send_move(current, from_row, from_col, to_row, to_col)

func _calculate_valid_moves(row: int, col: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	if row < 0 or row >= BOARD or col < 0 or col >= BOARD:
		return moves
	var cell = board[row][col]
	if cell == null or cell.owner != current:
		return moves

	var directions: Array[Vector2i] = []
	if cell.king:
		directions = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
	elif cell.owner == P_TOP:
		directions = [Vector2i(1, -1), Vector2i(1, 1)]
	else:
		directions = [Vector2i(-1, -1), Vector2i(-1, 1)]

	for d in directions:
		var nr = row + d.x
		var nc = col + d.y
		if nr >= 0 and nr < BOARD and nc >= 0 and nc < BOARD:
			if board[nr][nc] == null:
				moves.append(Vector2i(nr, nc))
			elif board[nr][nc].owner != current:
				var jr = row + d.x * 2
				var jc = col + d.y * 2
				if jr >= 0 and jr < BOARD and jc >= 0 and jc < BOARD:
					if board[jr][jc] == null:
						moves.append(Vector2i(jr, jc))
	return moves

func _init_board() -> void:
	if pieces_container == null:
		pieces_container = Node2D.new()
		pieces_container.name = "Pieces"
		add_child(pieces_container)
	else:
		for child in pieces_container.get_children():
			child.queue_free()

	board = []
	piece_sprites = []
	for row in BOARD:
		var line: Array = []
		var sprite_line: Array = []
		for col in BOARD:
			var cell = null
			var sprite = null
			if (row + col) % 2 == 1:  # solo casillas oscuras
				if row <= 2:
					cell = {"owner": P_TOP, "king": false}
					sprite = _create_piece_sprite(P_TOP, false, row, col)
				elif row >= 5:
					cell = {"owner": P_BOTTOM, "king": false}
					sprite = _create_piece_sprite(P_BOTTOM, false, row, col)
			line.append(cell)
			sprite_line.append(sprite)
		board.append(line)
		piece_sprites.append(sprite_line)

func _create_piece_sprite(p_owner: int, is_king: bool, row: int, col: int) -> PieceSprite:
	var ps = PieceSprite.new()
	ps.owner_id = p_owner
	ps.king = is_king
	ps.cell_size = CELL
	ps.position = Vector2(col * CELL + CELL / 2.0, row * CELL + CELL / 2.0)
	pieces_container.add_child(ps)
	return ps

# --- Input --------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if winner != -1 or animating:
		return

	var handled := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handled = true
	elif event is InputEventScreenTouch and event.pressed:
		handled = true

	if handled:
		_handle_click(event.position)

func _handle_click(pos: Vector2) -> void:
	if animating:
		return

	var col := int(pos.x / CELL)
	var row := int(pos.y / CELL)

	if row < 0 or row >= BOARD or col < 0 or col >= BOARD:
		selected = null
		valid_moves.clear()
		queue_redraw()
		return

	if selected == null:
		var cell = board[row][col]
		if cell != null and cell.owner == current:
			selected = {"row": row, "col": col}
			valid_moves = _calculate_valid_moves(row, col)
			queue_redraw()
		return

	# Si se hace click sobre una de las casillas resaltadas
	var clicked_dest = Vector2i(row, col)
	if clicked_dest in valid_moves:
		var from = selected
		selected = null
		valid_moves.clear()
		queue_redraw()
		var caps = _get_pieces_with_captures(current)
		if caps.size() > 0 and abs(row - from.row) != 2:
			_show_mandatory_capture_warning()
		bridge.send_move(current, from.row, from.col, row, col)
		return

	# Si se hace click sobre otra ficha propia -> cambiar selección
	var cell = board[row][col]
	if cell != null and cell.owner == current:
		selected = {"row": row, "col": col}
		valid_moves = _calculate_valid_moves(row, col)
		queue_redraw()
		return

	# Click en otra casilla no válida -> deseleccionar
	selected = null
	valid_moves.clear()
	queue_redraw()

# --- Señales del motor ---------------------------------------------------

func _on_piece_moved(player: int, from_row: int, from_col: int, to_row: int, to_col: int,
		captured_row: int, captured_col: int, promoted: bool) -> void:
	animating = true
	selected = null
	valid_moves.clear()

	var piece = board[from_row][from_col]
	board[from_row][from_col] = null
	if captured_row >= 0 and captured_col >= 0:
		board[captured_row][captured_col] = null
	if promoted and piece != null:
		piece.king = true
	board[to_row][to_col] = piece

	var moving_sprite: PieceSprite = piece_sprites[from_row][from_col]
	piece_sprites[from_row][from_col] = null

	var captured_sprite: PieceSprite = null
	if captured_row >= 0 and captured_col >= 0:
		captured_sprite = piece_sprites[captured_row][captured_col]
		piece_sprites[captured_row][captured_col] = null

	piece_sprites[to_row][to_col] = moving_sprite

	if captured_row >= 0 and captured_col >= 0:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_capture()
	else:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_move()

	current = bridge.current_player()
	_update_status()
	queue_redraw()

	if moving_sprite != null:
		var target_pos := Vector2(to_col * CELL + CELL / 2.0, to_row * CELL + CELL / 2.0)
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(moving_sprite, "position", target_pos, 0.25)
		if captured_sprite != null and is_instance_valid(captured_sprite):
			tween.chain().tween_property(captured_sprite, "scale", Vector2.ZERO, 0.15)
		tween.finished.connect(func():
			if captured_sprite != null and is_instance_valid(captured_sprite):
				captured_sprite.queue_free()
			if promoted and moving_sprite != null and is_instance_valid(moving_sprite):
				moving_sprite.king = true
				moving_sprite.queue_redraw()
			animating = false
			animation_finished.emit()
		)
	else:
		if captured_sprite != null and is_instance_valid(captured_sprite):
			captured_sprite.queue_free()
		animating = false
		animation_finished.emit()

func _on_game_over(w: int) -> void:
	winner = w
	selected = null
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
	_show_mandatory_capture_warning()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_invalid()

# --- Dibujo --------------------------------------------------------------

func _draw() -> void:
	var col_l = current_theme.light_color if current_theme else COL_LIGHT
	var col_d = current_theme.dark_color if current_theme else COL_DARK
	var col_sel = current_theme.select_color if current_theme else COL_SELECT

	# Casillas
	for row in BOARD:
		for col in BOARD:
			var dark: bool = (row + col) % 2 == 1
			var color: Color = col_d if dark else col_l
			draw_rect(Rect2(col * CELL, row * CELL, CELL, CELL), color)

	# Casilla seleccionada
	if selected != null:
		draw_rect(Rect2(selected.col * CELL, selected.row * CELL, CELL, CELL), col_sel)

	# Resaltar movimientos válidos con círculos semitransparentes
	for move_pos in valid_moves:
		var center = Vector2(move_pos.y * CELL + CELL / 2.0, move_pos.x * CELL + CELL / 2.0)
		draw_circle(center, 20.0, Color(1.0, 1.0, 1.0, 0.5))

func _update_status() -> void:
	if winner != -1:
		var who: String = "rojo (1)" if winner == P_TOP else "negro (2)"
		status.text = "¡Ganó el jugador %s!" % who
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var who := "Jugador 1" if current == P_TOP else "Jugador 2"
		var p_col = GameManager.get_player_color(current)
		status.text = "Turno: %s" % who
		if turn_indicator != null:
			turn_indicator.set_turn(current, who, p_col)
