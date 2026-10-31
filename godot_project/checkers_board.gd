## Vista de damas: dibuja el tablero, toma el input táctil/mouse y habla
## con el motor Rust a través del nodo nativo `OpenTableBridge` (del
## GDExtension open_table_godot). Este script NUNCA valida reglas: manda
## el movimiento al bridge y solo actualiza lo que dibuja cuando el motor
## confirma con la señal `piece_moved`. Así la vista no puede
## "desincronizarse" de la verdad que vive en Rust.
extends Node2D

signal animation_finished

const BOARD := 8
const CELL := 76.0
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
		# Sombra proyectada suave
		draw_circle(Vector2(3, 4), cell_size * 0.38, Color(0, 0, 0, 0.42))
		# Colores clásicos de Damas: Carmesí Rubí (P1) vs Ébano/Marfil Oscuro (P2)
		var base_col: Color = Color(0.80, 0.16, 0.18) if owner_id == 1 else Color(0.16, 0.19, 0.25)
		var rim_col: Color = Color(0.98, 0.78, 0.72, 0.85) if owner_id == 1 else Color(0.78, 0.84, 0.92, 0.85)
		var inner_col: Color = base_col.lightened(0.14)
		draw_circle(Vector2.ZERO, cell_size * 0.38, base_col)
		draw_circle(Vector2(-2, -3), cell_size * 0.31, inner_col)
		draw_circle(Vector2.ZERO, cell_size * 0.24, base_col.darkened(0.10))
		draw_arc(Vector2.ZERO, cell_size * 0.38, 0.0, TAU, 40, rim_col, 2.4)
		draw_arc(Vector2.ZERO, cell_size * 0.27, 0.0, TAU, 36, Color(rim_col.r, rim_col.g, rim_col.b, 0.55), 1.6)
		draw_arc(Vector2.ZERO, cell_size * 0.33, PI * 1.1, PI * 1.75, 20, Color(1, 1, 1, 0.35), 2.0)
		if king:
			draw_circle(Vector2.ZERO, cell_size * 0.17, COL_KING)
			draw_arc(Vector2.ZERO, cell_size * 0.17, 0.0, TAU, 28, Color(0.55, 0.38, 0.02), 1.8)
			var font: Font = ThemeDB.fallback_font
			if font != null:
				draw_string(font, Vector2(-cell_size * 0.14, cell_size * 0.07), "♛", HORIZONTAL_ALIGNMENT_CENTER, cell_size * 0.28, int(cell_size * 0.22), Color(0.28, 0.16, 0.0))

var bridge                # OpenTableBridge (nodo nativo del GDExtension)
var board: Array = []     # board[row][col] = null | {"owner": int, "king": bool}
var piece_sprites: Array = [] # piece_sprites[row][col] = PieceSprite | null
var pieces_container: Node2D
var selected = null       # {"row": int, "col": int} o null
var valid_moves: Array[Vector2i] = [] # Posiciones de destino válidas para resaltar
var animating: bool = false # Bloquea el input durante las animaciones
var current: int = P_TOP  # de quién es el turno (según el motor)
var winner: int = -1
var multi_capture_cell = null # {"row": int, "col": int} o null para salto obligatorio múltiple

var drag_layer: DragDropLayer
var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var mandatory_label: Label
var mode_option_button: OptionButton
var rules_popup: RulesPopup
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

	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	_init_board()
	_setup_ui_layers()

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

	# Señales del motor -> actualizaciones de la vista.
	bridge.connect("piece_moved", _on_piece_moved)
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)

	if gm != null and gm.get_game_mode() == "vs_ai":
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else P_TOP
		var ai_p: int = P_BOTTOM if human_p == P_TOP else P_TOP
		bridge.start_local_match_checkers_vs_ai(42, human_p, ai_p)
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_p == P_TOP else 2
	else:
		bridge.start_local_match(P_TOP, P_BOTTOM)
		if mode_option_button != null:
			mode_option_button.selected = 0
	current = bridge.current_player()

	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_status()
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	
	if mode_option_button != null:
		mode_option_button.position = Vector2(124, -52)
		mode_option_button.visible = false
	# Zona Superior Centrada: Turno y Reloj
	if turn_indicator != null:
		turn_indicator.position = Vector2(12, -52)
	if status != null:
		status.position = Vector2(280, -48)
	# Zona Inferior Centrada: Aviso de acción del turno (Captura obligatoria)
	if mandatory_label != null:
		mandatory_label.position = Vector2(24, 616)

	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz: Vector2 = get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if _layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)
	var min_x: float = 0.0
	var min_y: float = -58.0
	var design_w: float = float(BOARD * CELL)
	var design_h: float = 724.0
	var s: float = clampf(minf((vp_size.x - 40.0) / design_w, (vp_size.y - 24.0) / design_h), 0.30, 1.0)
	scale = Vector2(s, s)
	position = Vector2(
		(vp_size.x - design_w * s) * 0.5 - min_x * s,
		(vp_size.y - design_h * s) * 0.5 - min_y * s
	)

func _setup_ui_layers() -> void:
	# Mandatory capture banner in bottom zone (Acción del turno actual)
	mandatory_label = Label.new()
	mandatory_label.name = "MandatoryCaptureLabel"
	mandatory_label.text = "¡Captura obligatoria!"
	mandatory_label.position = Vector2(24, 616)
	mandatory_label.size = Vector2(560, 40)
	mandatory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mandatory_label.add_theme_font_size_override("font_size", 22)
	mandatory_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	mandatory_label.hide()
	add_child(mandatory_label)

	drag_layer = DragDropLayer.new()
	drag_layer.name = "DragDropLayer"
	drag_layer.cell_size = CELL
	drag_layer.board_bounds = Vector2i(BOARD, BOARD)
	drag_layer.enabled = false
	drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_layer)
	drag_layer.set_process_input(false)
	drag_layer.set_process_unhandled_input(false)

	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(124, -52)
	mode_option_button.custom_minimum_size = Vector2(360, 36)
	mode_option_button.visible = false
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano J1 - Rojo)")
	mode_option_button.add_item("vs IA (Humano J2 - Negro, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(12, -52)
	add_child(turn_indicator)

	if status != null:
		status.position = Vector2(280, -48)

	var tutorial_btn := Button.new()
	tutorial_btn.name = "CheckersTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(234, 616)
	tutorial_btn.custom_minimum_size = Vector2(140, 36)
	tutorial_btn.visible = false
	tutorial_btn.pressed.connect(start_checkers_tutorial)
	add_child(tutorial_btn)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(234, 616)
	btn_rules.custom_minimum_size = Vector2(120, 36)
	btn_rules.visible = false
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("checkers"))
	add_child(btn_rules)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 100)
	add_child(rules_popup)

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_mode_selected(index: int) -> void:
	winner = -1
	selected = null
	multi_capture_cell = null
	valid_moves.clear()
	animating = false
	_init_board()
	if bridge != null:
		match index:
			0:
				bridge.start_local_match(P_TOP, P_BOTTOM)
			1:
				bridge.start_local_match_checkers_vs_ai(42, P_TOP, P_BOTTOM)
			2:
				bridge.start_local_match_checkers_vs_ai(42, P_BOTTOM, P_TOP)
	current = bridge.current_player() if bridge else P_TOP
	_update_status()
	queue_redraw()

func start_checkers_tutorial() -> void:
	var CheckersTut = load("res://scripts/tutorials/checkers_tutorial.gd")
	if CheckersTut != null:
		CheckersTut.start_on_board(self)

func _on_quit_to_menu() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")

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

func _reset_all_piece_scales() -> void:
	for r in range(BOARD):
		for c in range(BOARD):
			var sprite = piece_sprites[r][c]
			if sprite != null and is_instance_valid(sprite):
				sprite.scale = Vector2(1.0, 1.0)

func _bounce_piece(r: int, c: int) -> void:
	if animating:
		return
	if r < 0 or r >= BOARD or c < 0 or c >= BOARD:
		return
	var sprite = piece_sprites[r][c]
	if sprite != null and is_instance_valid(sprite):
		sprite.scale = Vector2(1.0, 1.0)
		var tw = sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.08)
		tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

func _on_drag_started(from_cell: Vector2i) -> void:
	_sfx_piece_slide()
	if winner != -1 or animating: return
	var r = from_cell.x
	var c = from_cell.y
	var cell = board[r][c]
	if cell != null and cell.owner == current:
		_reset_all_piece_scales()
		selected = {"row": r, "col": c}
		valid_moves = _calculate_valid_moves(r, c)
		_bounce_piece(r, c)
		queue_redraw()
	else:
		_reset_all_piece_scales()
		drag_layer.clear_selection()
		selected = null
		valid_moves.clear()
		queue_redraw()

func _on_piece_dropped(to_cell: Vector2i) -> void:
	if winner != -1 or selected == null or animating: return
	_reset_all_piece_scales()
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
	if bridge != null and bridge.has_method("get_legal_moves"):
		var legal_moves = bridge.get_legal_moves(current)
		for m in legal_moves:
			if not (m is Dictionary):
				continue
			var f_row: int = -1
			var f_col: int = -1
			var t_row: int = -1
			var t_col: int = -1

			if m.has("from") and m["from"] is Dictionary:
				var f_dict: Dictionary = m["from"]
				f_row = int(f_dict.get("row", -1))
				f_col = int(f_dict.get("col", -1))
			elif m.has("from_row"):
				f_row = int(m.get("from_row", -1))
				f_col = int(m.get("from_col", -1))

			if m.has("to") and m["to"] is Dictionary:
				var t_dict: Dictionary = m["to"]
				t_row = int(t_dict.get("row", -1))
				t_col = int(t_dict.get("col", -1))
			elif m.has("to_row"):
				t_row = int(m.get("to_row", -1))
				t_col = int(m.get("to_col", -1))

			if f_row == row and f_col == col and t_row >= 0 and t_col >= 0:
				var dest: Vector2i = Vector2i(t_row, t_col)
				if not moves.has(dest):
					moves.append(dest)
		if not legal_moves.is_empty():
			return moves

	return _calculate_local_valid_moves(row, col)

func _calculate_local_valid_moves(row: int, col: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	if row < 0 or row >= BOARD or col < 0 or col >= BOARD:
		return moves
	var cell = board[row][col]
	if cell == null or int(cell.owner) != current:
		return moves
	if multi_capture_cell != null:
		if int(multi_capture_cell.row) != row or int(multi_capture_cell.col) != col:
			return moves

	var directions: Array[Vector2i] = []
	if bool(cell.king):
		directions = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
	elif int(cell.owner) == P_TOP:
		directions = [Vector2i(1, -1), Vector2i(1, 1)]
	else:
		directions = [Vector2i(-1, -1), Vector2i(-1, 1)]

	var all_captures: Array[Vector2i] = _get_pieces_with_captures(current)
	if not all_captures.is_empty() or multi_capture_cell != null:
		for d in directions:
			var mid_r: int = row + d.x
			var mid_c: int = col + d.y
			var land_r: int = row + d.x * 2
			var land_c: int = col + d.y * 2
			if land_r >= 0 and land_r < BOARD and land_c >= 0 and land_c < BOARD:
				if board[mid_r][mid_c] != null and int(board[mid_r][mid_c].owner) != int(cell.owner) and board[land_r][land_c] == null:
					moves.append(Vector2i(land_r, land_c))
		return moves

	for d in directions:
		var nr: int = row + d.x
		var nc: int = col + d.y
		if nr >= 0 and nr < BOARD and nc >= 0 and nc < BOARD and board[nr][nc] == null:
			moves.append(Vector2i(nr, nc))
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

var touch_down_pos: Vector2 = Vector2.ZERO
var touch_start_cell: Vector2i = Vector2i(-1, -1)
var is_touch_dragging: bool = false
var _selected_on_current_press: bool = false
const DEAD_ZONE: float = 8.0

func _event_to_board_pos(event_pos: Vector2, is_mouse: bool = true) -> Vector2:
	if is_inside_tree() and not OS.has_feature("headless"):
		if is_mouse:
			return get_local_mouse_position()
		return make_canvas_position_local(event_pos)
	return event_pos

func _gui_input(_event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	_handle_gamepad_input(event)
	_handle_unified_input(event)

func _handle_unified_input(event: InputEvent) -> void:
	if winner != -1:
		return
	if rules_popup != null and rules_popup.visible:
		return

	var event_pos: Vector2 = Vector2.ZERO
	var is_press: bool = false
	var is_release: bool = false
	var is_drag: bool = false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			event_pos = _event_to_board_pos(event.position, true)
			is_press = event.pressed
			is_release = not event.pressed
	elif event is InputEventScreenTouch:
		event_pos = _event_to_board_pos(event.position, false)
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			event_pos = _event_to_board_pos(event.position, true)
			is_drag = true
	elif event is InputEventScreenDrag:
		event_pos = _event_to_board_pos(event.position, false)
		is_drag = true
	else:
		return

	if is_press:
		touch_down_pos = event_pos
		var press_col: int = int(floor(event_pos.x / CELL))
		var press_row: int = int(floor(event_pos.y / CELL))
		touch_start_cell = Vector2i(press_row, press_col)
		is_touch_dragging = false
		_selected_on_current_press = false
		if press_row >= 0 and press_row < BOARD and press_col >= 0 and press_col < BOARD:
			var p_cell = board[press_row][press_col]
			if p_cell != null and int(p_cell.owner) == current:
				var already_sel: bool = (selected != null and int(selected.get("row", -1)) == press_row and int(selected.get("col", -1)) == press_col)
				if not already_sel:
					_sfx_piece_slide()
					_reset_all_piece_scales()
					selected = {"row": press_row, "col": press_col}
					valid_moves = _calculate_valid_moves(press_row, press_col)
					_bounce_piece(press_row, press_col)
					queue_redraw()
					_selected_on_current_press = true
			elif selected != null:
				_handle_click(event_pos)
				_selected_on_current_press = true
	elif is_drag:
		if touch_down_pos.distance_to(event_pos) > DEAD_ZONE:
			is_touch_dragging = true
	elif is_release:
		var release_col: int = int(floor(event_pos.x / CELL))
		var release_row: int = int(floor(event_pos.y / CELL))
		var release_cell: Vector2i = Vector2i(release_row, release_col)
		if release_cell == touch_start_cell:
			if not _selected_on_current_press:
				_handle_click(event_pos)
		else:
			if not _selected_on_current_press and selected == null and touch_start_cell.x >= 0 and touch_start_cell.x < BOARD and touch_start_cell.y >= 0 and touch_start_cell.y < BOARD:
				var start_cell = board[touch_start_cell.x][touch_start_cell.y]
				if start_cell != null and int(start_cell.owner) == current:
					_reset_all_piece_scales()
					selected = {"row": touch_start_cell.x, "col": touch_start_cell.y}
					valid_moves = _calculate_valid_moves(touch_start_cell.x, touch_start_cell.y)
					_bounce_piece(touch_start_cell.x, touch_start_cell.y)
			if selected != null:
				_handle_click(event_pos)
		touch_start_cell = Vector2i(-1, -1)
		is_touch_dragging = false
		_selected_on_current_press = false

func _handle_click(pos: Vector2) -> void:
	var col: int = int(floor(pos.x / CELL))
	var row: int = int(floor(pos.y / CELL))

	if row < 0 or row >= BOARD or col < 0 or col >= BOARD:
		_reset_all_piece_scales()
		selected = null
		valid_moves.clear()
		queue_redraw()
		return

	if selected == null:
		var clicked_cell = board[row][col]
		if clicked_cell != null and int(clicked_cell.owner) == current:
			_reset_all_piece_scales()
			selected = {"row": row, "col": col}
			valid_moves = _calculate_valid_moves(row, col)
			_bounce_piece(row, col)
			queue_redraw()
		return

	# Si se hace click sobre otra ficha propia -> cambiar selección (o deseleccionar si es la misma)
	var cell = board[row][col]
	if cell != null and int(cell.owner) == current:
		if int(selected.row) == row and int(selected.col) == col:
			_reset_all_piece_scales()
			selected = null
			valid_moves.clear()
			queue_redraw()
			return
		_reset_all_piece_scales()
		selected = {"row": row, "col": col}
		valid_moves = _calculate_valid_moves(row, col)
		_bounce_piece(row, col)
		queue_redraw()
		return

	# Si se hace click sobre una de las casillas resaltadas o casilla diagonal oscura vacía
	var clicked_dest: Vector2i = Vector2i(row, col)
	var from_r: int = int(selected.row)
	var from_c: int = int(selected.col)
	var is_diag_step: bool = (cell == null and (row + col) % 2 == 1 and abs(row - from_r) in [1, 2] and abs(col - from_c) == abs(row - from_r))
	if valid_moves.has(clicked_dest) or is_diag_step:
		_reset_all_piece_scales()
		selected = null
		valid_moves.clear()
		queue_redraw()
		var caps: Array[Vector2i] = _get_pieces_with_captures(current)
		if caps.size() > 0 and abs(row - from_r) != 2:
			_show_mandatory_capture_warning()
		if bridge != null:
			bridge.send_move(current, from_r, from_c, row, col)
		return

	# Click en otra casilla no válida -> deseleccionar
	_reset_all_piece_scales()
	selected = null
	valid_moves.clear()
	queue_redraw()

# --- Señales del motor ---------------------------------------------------

func _on_piece_moved(player: int, from_row: int, from_col: int, to_row: int, to_col: int,
		captured_row: int, captured_col: int, promoted: bool) -> void:
	animating = true
	_reset_all_piece_scales()
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
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_piece_place(2.0)
	else:
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_piece_place()

	if bridge != null and bridge.has_method("current_player"):
		current = bridge.current_player()
	if captured_row >= 0 and captured_col >= 0 and current == player:
		multi_capture_cell = {"row": to_row, "col": to_col}
		selected = {"row": to_row, "col": to_col}
		valid_moves = _calculate_valid_moves(to_row, to_col)
	else:
		multi_capture_cell = null
	_update_status()
	queue_redraw()

	if moving_sprite != null and is_inside_tree():
		var target_pos: Vector2 = Vector2(to_col * CELL + CELL / 2.0, to_row * CELL + CELL / 2.0)
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
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
		if moving_sprite != null and is_instance_valid(moving_sprite):
			moving_sprite.position = Vector2(to_col * CELL + CELL / 2.0, to_row * CELL + CELL / 2.0)
			if promoted:
				moving_sprite.king = true
				moving_sprite.queue_redraw()
		if captured_sprite != null and is_instance_valid(captured_sprite):
			captured_sprite.queue_free()
		animating = false
		animation_finished.emit()

func _on_game_over(w: int) -> void:
	winner = w
	selected = null
	multi_capture_cell = null
	valid_moves.clear()
	_update_status()
	queue_redraw()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	_show_mandatory_capture_warning()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

# --- Dibujo --------------------------------------------------------------

func _draw() -> void:
	var col_l = current_theme.light_color if current_theme else COL_LIGHT
	var col_d = current_theme.dark_color if current_theme else COL_DARK
	var col_sel = current_theme.select_color if current_theme else COL_SELECT

	# Marco exterior de madera y casillas
	draw_rect(Rect2(-4, -4, BOARD * CELL + 8, BOARD * CELL + 8), Color(0.22, 0.13, 0.07))
	for row in BOARD:
		for col in BOARD:
			var dark: bool = (row + col) % 2 == 1
			var color: Color = col_d if dark else col_l
			var cell_rect: Rect2 = Rect2(col * CELL, row * CELL, CELL, CELL)
			draw_rect(cell_rect, color)
			if dark:
				draw_rect(Rect2(col * CELL + 2, row * CELL + 2, CELL - 4, CELL - 4), color.darkened(0.08), false, 1.0)
	draw_rect(Rect2(0, 0, BOARD * CELL, BOARD * CELL), Color(0.18, 0.10, 0.05), false, 3.0)

	# Casilla seleccionada
	if selected != null:
		draw_rect(Rect2(float(selected.col) * CELL, float(selected.row) * CELL, CELL, CELL), col_sel)
		draw_rect(Rect2(float(selected.col) * CELL + 2.0, float(selected.row) * CELL + 2.0, CELL - 4.0, CELL - 4.0), Color(1.0, 0.85, 0.15, 0.95), false, 3.0)

	# Resaltar casilla de multicaptura obligatoria con borde dorado
	if multi_capture_cell != null:
		var mc_rect: Rect2 = Rect2(float(multi_capture_cell.col) * CELL + 2.0, float(multi_capture_cell.row) * CELL + 2.0, CELL - 4.0, CELL - 4.0)
		draw_rect(mc_rect, Color(1.0, 0.84, 0.0, 0.95), false, 4.0)

	# Resaltar movimientos válidos con anillos esmeralda
	for move_pos in valid_moves:
		var center: Vector2 = Vector2(move_pos.y * CELL + CELL / 2.0, move_pos.x * CELL + CELL / 2.0)
		draw_circle(center, 18.0, Color(0.15, 0.88, 0.45, 0.45))
		draw_arc(center, 18.0, 0.0, TAU, 28, Color(0.35, 1.0, 0.60, 0.90), 2.5)

	# Cursor virtual de Gamepad / Steam Deck
	if gamepad_cursor_active and gamepad_cursor.x >= 0 and gamepad_cursor.x < BOARD and gamepad_cursor.y >= 0 and gamepad_cursor.y < BOARD:
		var cur_rect: Rect2 = Rect2(gamepad_cursor.y * CELL + 3.0, gamepad_cursor.x * CELL + 3.0, CELL - 6.0, CELL - 6.0)
		draw_rect(cur_rect, Color(0.2, 0.95, 1.0, 0.95), false, 3.0)

# --- Soporte de Gamepad y Steam Deck con cursor virtual ---
var gamepad_cursor: Vector2i = Vector2i(5, 0)
var gamepad_cursor_active: bool = false

func move_gamepad_cursor(delta: Vector2i) -> void:
	gamepad_cursor_active = true
	gamepad_cursor.x = clampi(gamepad_cursor.x + delta.x, 0, BOARD - 1)
	gamepad_cursor.y = clampi(gamepad_cursor.y + delta.y, 0, BOARD - 1)
	_sfx_piece_slide()
	queue_redraw()

func gamepad_select_current_cell() -> void:
	gamepad_cursor_active = true
	var center_pos: Vector2 = Vector2(gamepad_cursor.y * CELL + CELL / 2.0, gamepad_cursor.x * CELL + CELL / 2.0)
	_handle_click(center_pos)

func gamepad_cancel_selection() -> void:
	_reset_all_piece_scales()
	selected = null
	valid_moves.clear()
	queue_redraw()

func gamepad_open_pause_menu() -> void:
	if ResourceLoader.exists("res://pause_menu.tscn"):
		var pm = load("res://pause_menu.tscn").instantiate()
		add_child(pm)
		if pm.has_method("toggle_pause"):
			pm.call("toggle_pause")

func _handle_gamepad_input(event: InputEvent) -> void:
	if InputMap.has_action("ui_gamepad_up") and event.is_action_pressed("ui_gamepad_up"):
		move_gamepad_cursor(Vector2i(-1, 0))
	elif InputMap.has_action("ui_gamepad_down") and event.is_action_pressed("ui_gamepad_down"):
		move_gamepad_cursor(Vector2i(1, 0))
	elif InputMap.has_action("ui_gamepad_left") and event.is_action_pressed("ui_gamepad_left"):
		move_gamepad_cursor(Vector2i(0, -1))
	elif InputMap.has_action("ui_gamepad_right") and event.is_action_pressed("ui_gamepad_right"):
		move_gamepad_cursor(Vector2i(0, 1))
	elif InputMap.has_action("ui_gamepad_select") and event.is_action_pressed("ui_gamepad_select"):
		gamepad_select_current_cell()
	elif InputMap.has_action("ui_gamepad_cancel") and event.is_action_pressed("ui_gamepad_cancel"):
		gamepad_cancel_selection()
	elif InputMap.has_action("ui_gamepad_start") and event.is_action_pressed("ui_gamepad_start"):
		gamepad_open_pause_menu()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: move_gamepad_cursor(Vector2i(-1, 0))
			JOY_BUTTON_DPAD_DOWN: move_gamepad_cursor(Vector2i(1, 0))
			JOY_BUTTON_DPAD_LEFT: move_gamepad_cursor(Vector2i(0, -1))
			JOY_BUTTON_DPAD_RIGHT: move_gamepad_cursor(Vector2i(0, 1))
			JOY_BUTTON_A: gamepad_select_current_cell()
			JOY_BUTTON_B: gamepad_cancel_selection()
			JOY_BUTTON_START: gamepad_open_pause_menu()

func _update_status() -> void:
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		return
	if winner != -1:
		var who: String = "rojo (1)" if winner == P_TOP else "negro (2)"
		status.text = "¡Ganó el jugador %s!" % who
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var who: String = "Jugador 1" if current == P_TOP else "Jugador 2"
		var p_col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(current) - 1, 6)] as Color)
		status.text = "Turno: %s" % who
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
	var particles: CPUParticles2D = CPUParticles2D.new()
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
