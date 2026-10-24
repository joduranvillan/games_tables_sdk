extends Node2D

signal animation_finished

@export var use_texture_pieces: bool = true
@export var fallback_to_unicode: bool = true

const BOARD_SIZE = 8
const CELL_SIZE = 76.0
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
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_moves: Array[Vector2i] = []
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
var export_game_button: Button
var export_toast_label: Label
var _rules_popup: RulesPopup
var _pause_menu: CanvasLayer

var in_opening_practice: bool = false
var current_opening_key: String = ""
var opening_step_index: int = 0
var opening_moves: Array = []

@onready var status: Label = get_node_or_null("Status")

func _ready() -> void:
	highlight_moves_enabled = SettingsMenu.get_saved_settings().get("highlight_moves", true)
	
	if is_inside_tree() and (Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)
			
	_setup_ui()
	_init_board_state()
	
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
	bridge.connect("piece_moved", _on_piece_moved_signal)
	
	if gm != null and gm.get_game_mode() == "vs_ai":
		var depth: int = gm.get_chess_ai_depth() if gm != null else 2
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else P1
		var ai_p: int = P2 if human_p == P1 else P1
		bridge.start_local_match_chess_vs_ai(human_p, ai_p, depth)
		if mode_option_button != null:
			if human_p == P2:
				mode_option_button.selected = 4
			else:
				mode_option_button.selected = clampi(depth, 1, 3)
	else:
		bridge.start_local_match_chess(P1, P2)
		if mode_option_button != null:
			mode_option_button.selected = 0
	current = bridge.current_player()
	
	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_status()
	queue_redraw()

	# --- Botón de reglas ---
	var btn_rules := Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(990, 270)
	btn_rules.custom_minimum_size = Vector2(120, 36)
	btn_rules.pressed.connect(func(): _rules_popup.show_for_game("chess"))
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
	if is_inside_tree() and has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	elif is_inside_tree() and get_tree():
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")

func _on_layout_changed(_layout: int) -> void:
	if is_inside_tree() and has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	var side_x := 640.0
	if mode_option_button != null:
		mode_option_button.position = Vector2(side_x, 24)
	if opening_option_button != null:
		opening_option_button.position = Vector2(side_x, 72)
	if turn_indicator != null:
		turn_indicator.position = Vector2(side_x, 125)
	if status != null:
		status.position = Vector2(side_x, 210)
	if export_game_button != null:
		export_game_button.position = Vector2(side_x, 270)
	var tut_btn = get_node_or_null("ChessTutorialButton")
	if tut_btn != null:
		tut_btn.position = Vector2(side_x + 175, 270)
	var rules_btn = get_node_or_null("RulesButton")
	if rules_btn != null:
		rules_btn.position = Vector2(side_x + 350, 270)
	if export_toast_label != null:
		export_toast_label.position = Vector2(side_x, 315)

func _setup_ui() -> void:
	var side_x := 640.0
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	status.position = Vector2(side_x, 210)
	status.custom_minimum_size = Vector2(580, 40)

	grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = BOARD_SIZE
	grid_container.position = Vector2.ZERO
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
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
	drag_layer.set_process_unhandled_input(false)
	
	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(side_x, 125)
	add_child(turn_indicator)

	# Game Mode Selector
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(side_x, 24)
	mode_option_button.custom_minimum_size = Vector2(380, 36)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Blancas J1 - Fácil)")
	mode_option_button.add_item("vs IA (Blancas J1 - Medio)")
	mode_option_button.add_item("vs IA (Blancas J1 - Difícil)")
	mode_option_button.add_item("vs IA (Negras J2 - IA mueve primero)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	# Opening Practice Selector
	opening_option_button = OptionButton.new()
	opening_option_button.name = "OpeningOptionButton"
	opening_option_button.position = Vector2(side_x, 72)
	opening_option_button.custom_minimum_size = Vector2(380, 36)
	opening_option_button.add_item("Partida libre (Sin apertura)")
	opening_option_button.add_item("Ruy López (e4 e5 Nf3 Nc6 Bb5)")
	opening_option_button.add_item("Gambito de Dama (d4 d5 c4)")
	opening_option_button.add_item("Defensa Siciliana (e4 c5 Nf3 d6 d4)")
	opening_option_button.add_item("Defensa Francesa (e4 e6 d4 d5)")
	opening_option_button.add_item("Apertura Italiana (e4 e5 Nf3 Nc6 Bc4)")
	opening_option_button.add_item("Defensa Caro-Kann (e4 c6 d4 d5)")
	opening_option_button.item_selected.connect(_on_opening_selected)
	add_child(opening_option_button)

	# Botón Exportar Partida (PGN / FEN)
	export_game_button = Button.new()
	export_game_button.name = "ExportGameButton"
	export_game_button.text = "Exportar Partida"
	export_game_button.position = Vector2(side_x, 270)
	export_game_button.custom_minimum_size = Vector2(160, 36)
	export_game_button.pressed.connect(_on_export_game_pressed)
	add_child(export_game_button)

	# Botón Tutorial Interactivo (8 pasos)
	var tutorial_btn := Button.new()
	tutorial_btn.name = "ChessTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(side_x + 175, 270)
	tutorial_btn.custom_minimum_size = Vector2(160, 36)
	tutorial_btn.pressed.connect(start_chess_tutorial)
	add_child(tutorial_btn)

	export_toast_label = Label.new()
	export_toast_label.name = "ExportToastLabel"
	export_toast_label.text = ""
	export_toast_label.visible = false
	export_toast_label.position = Vector2(side_x, 315)
	export_toast_label.add_theme_font_size_override("font_size", 14)
	export_toast_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	add_child(export_toast_label)

func _on_export_game_pressed() -> void:
	var pgn_text := ""
	var fen_text := ""
	if bridge != null:
		if bridge.has_method("export_chess_pgn"):
			pgn_text = str(bridge.call("export_chess_pgn"))
		if bridge.has_method("export_chess_fen"):
			fen_text = str(bridge.call("export_chess_fen"))
	var payload := pgn_text
	if not fen_text.is_empty():
		payload = "%s\n[FEN \"%s\"]" % [pgn_text, fen_text] if not pgn_text.is_empty() else fen_text
	DisplayServer.clipboard_set(payload)
	_show_clipboard_notification("Copiado al portapapeles")

func _show_clipboard_notification(msg: String = "Copiado al portapapeles") -> void:
	if export_toast_label != null:
		export_toast_label.text = msg
		export_toast_label.visible = true
	if is_inside_tree() and has_node("/root/NotificationManager"):
		var nm = get_node("/root/NotificationManager")
		if nm.has_method("show_toast"):
			nm.call("show_toast", msg)
	if is_inside_tree():
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(export_toast_label):
				export_toast_label.visible = false
		)

func _on_mode_selected(index: int) -> void:
	in_opening_practice = false
	current_opening_key = ""
	opening_step_index = 0
	opening_moves.clear()
	if opening_option_button != null:
		opening_option_button.selected = 0

	selected_pos = null
	valid_moves.clear()
	winner = -1
	animating = false
	active_animations = 0
	_init_board_state()

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
			4:
				bridge.start_local_match_chess_vs_ai(P2, P1, 2)

	current = bridge.current_player() if bridge else P1
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
	_sfx_piece_slide()
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
	
	_send_chess_move(from_r, from_c, to_r, to_c)

func _send_chess_move(from_r: int, from_c: int, to_r: int, to_c: int) -> void:
	var eng_from_r := (BOARD_SIZE - 1) - from_r
	var eng_to_r := (BOARD_SIZE - 1) - to_r
	var promo = null
	var moving_piece = piece_sprites[from_r][from_c]
	if moving_piece != null and moving_piece.has_meta("kind") and moving_piece.get_meta("kind") == "Pawn":
		if to_r == 0 or to_r == BOARD_SIZE - 1:
			promo = "Queen"
	var cmd = {
		"command_type": "chess_game::MovePieceCommand",
		"player": current,
		"from": {"row": eng_from_r, "col": from_c},
		"to": {"row": eng_to_r, "col": to_c},
		"promote_to": promo
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
	if pieces_container != null:
		for child in pieces_container.get_children():
			child.queue_free()
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

var _piece_texture_cache: Dictionary = {}

func _get_piece_texture_path(kind: String, player: int) -> String:
	var color_prefix = "white" if player == P1 else "black"
	var type_name = kind.to_lower()
	return "res://assets/chess/" + color_prefix + "_" + type_name + ".png"

func _load_piece_texture_safe(tex_path: String) -> Texture2D:
	if _piece_texture_cache.has(tex_path):
		return _piece_texture_cache[tex_path]
	if ResourceLoader.exists(tex_path + ".import"):
		var imported = load(tex_path) as Texture2D
		if imported != null:
			_piece_texture_cache[tex_path] = imported
			return imported
	var abs_path := ProjectSettings.globalize_path(tex_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_piece_texture_cache[tex_path] = tex
			return tex
	return null

func _create_piece_sprite(row: int, col: int, player: int, kind: String) -> Node2D:
	var piece_node = Node2D.new()
	piece_node.position = Vector2(col * CELL_SIZE + CELL_SIZE / 2.0, row * CELL_SIZE + CELL_SIZE / 2.0)
	
	var created_texture = false
	if use_texture_pieces:
		var tex_path = _get_piece_texture_path(kind, player)
		var tex = _load_piece_texture_safe(tex_path)
		if tex != null:
			var sprite = Sprite2D.new()
			sprite.texture = tex
			var tex_size = tex.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_factor = (CELL_SIZE * 0.82) / max(tex_size.x, tex_size.y)
				sprite.scale = Vector2(scale_factor, scale_factor)
			piece_node.add_child(sprite)
			created_texture = true

	if not created_texture and fallback_to_unicode:
		var badge := Node2D.new()
		var is_white := (player == P1)
		var disc_fill := Color(0.98, 0.95, 0.88) if is_white else Color(0.14, 0.16, 0.21)
		var disc_rim := Color(0.22, 0.18, 0.14) if is_white else Color(0.85, 0.78, 0.58)
		badge.draw.connect(func():
			badge.draw_circle(Vector2(2, 3), CELL_SIZE * 0.36, Color(0, 0, 0, 0.35))
			badge.draw_circle(Vector2.ZERO, CELL_SIZE * 0.36, disc_fill)
			badge.draw_arc(Vector2.ZERO, CELL_SIZE * 0.36, 0.0, TAU, 36, disc_rim, 2.5)
			badge.draw_arc(Vector2.ZERO, CELL_SIZE * 0.30, 0.0, TAU, 36, Color(disc_rim.r, disc_rim.g, disc_rim.b, 0.45), 1.2)
		)
		piece_node.add_child(badge)

		var label = Label.new()
		label.text = _get_piece_symbol(kind, player)
		label.add_theme_font_size_override("font_size", 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(CELL_SIZE, CELL_SIZE)
		label.position = -Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var text_color = Color(0.12, 0.12, 0.15) if is_white else Color(0.96, 0.93, 0.84)
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

func _pixel_to_cell(pos: Vector2) -> Vector2i:
	var r = int(pos.y / CELL_SIZE)
	var c = int(pos.x / CELL_SIZE)
	if _is_in_bounds(r, c):
		return Vector2i(r, c)
	return Vector2i(-1, -1)

func _handle_mouse_hover(pos: Vector2) -> void:
	if winner != -1 or animating:
		if _hover_cell != Vector2i(-1, -1):
			_hover_cell = Vector2i(-1, -1)
			_hover_moves.clear()
			queue_redraw()
		return

	var cell = _pixel_to_cell(pos)
	if cell != _hover_cell:
		_hover_cell = cell
		_hover_moves.clear()
		if cell != Vector2i(-1, -1) and _is_in_bounds(cell.x, cell.y):
			var piece = piece_sprites[cell.x][cell.y]
			if piece != null and piece.get_meta("player") == current:
				_hover_moves = _get_moves_for_hover_cell(cell)
		queue_redraw()

func _get_moves_for_hover_cell(cell: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	if not _is_in_bounds(cell.x, cell.y):
		return moves

	var calc = _calculate_valid_moves(cell.x, cell.y)
	for m in calc:
		if m is Vector2i:
			moves.append(m)
		elif m is Vector2:
			moves.append(Vector2i(int(m.x), int(m.y)))
	return moves

func _gui_input(event: InputEvent) -> void:
	if OS.has_feature("headless"):
		return
	if event is InputEventMouseMotion:
		_handle_mouse_hover(event.position)

func _input(event: InputEvent) -> void:
	_handle_gamepad_input(event)
	if OS.has_feature("headless"):
		return
	if event is InputEventMouseMotion:
		_handle_mouse_hover(event.position)
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

func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)

func start_chess_tutorial() -> void:
	var ChessTut = load("res://scripts/tutorials/chess_tutorial.gd")
	if ChessTut != null:
		ChessTut.start_on_board(self)

func _handle_cell_click(row: int, col: int) -> void:
	if (is_inside_tree() and has_node("/root/TutorialManager")):
		var tm = get_node("/root/TutorialManager")
		if tm.get("is_running") == true:
			if not tm.call("notify_cell_action", Vector2i(col, row)):
				return
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
		
		_send_chess_move(from_pos.x, from_pos.y, row, col)

func _calculate_valid_moves(r: int, c: int) -> Array:
	var moves: Array = []
	if bridge == null or not bridge.has_method("get_legal_moves"):
		return moves
	var eng_r := (BOARD_SIZE - 1) - r
	var legal_moves = bridge.get_legal_moves(current)
	for m in legal_moves:
		var f_row := -1
		var f_col := -1
		var t_row := -1
		var t_col := -1

		if m.has("from") and m.from is Dictionary:
			f_row = int(m.from.get("row", -1))
			f_col = int(m.from.get("col", -1))
		elif m.has("from_row"):
			f_row = int(m.get("from_row", -1))
			f_col = int(m.get("from_col", -1))

		if m.has("to") and m.to is Dictionary:
			t_row = int(m.to.get("row", -1))
			t_col = int(m.to.get("col", -1))
		elif m.has("to_row"):
			t_row = int(m.get("to_row", -1))
			t_col = int(m.get("to_col", -1))

		if f_row == eng_r and f_col == c and t_row >= 0 and t_col >= 0:
			var vis_to_r := (BOARD_SIZE - 1) - t_row
			var dest = Vector2i(vis_to_r, t_col)
			if not dest in moves:
				moves.append(dest)
	return moves

func _is_in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE

func _move_piece_sprite(from_r: int, from_c: int, to_r: int, to_c: int, is_promotion: bool = false, promoted_kind: String = "Queen") -> void:
	last_move_from = Vector2i(from_r, from_c)
	last_move_to = Vector2i(to_r, to_c)
	var piece = piece_sprites[from_r][from_c]
	if piece == null:
		return
		
	animating = true
	_reset_all_piece_scales()
	active_animations += 1

	var piece_kind: String = str(piece.get_meta("kind")) if piece.has_meta("kind") else ""
	var piece_player: int = int(piece.get_meta("player")) if piece.has_meta("player") else P1

	# En passant visual cleanup: pawn moved diagonally into empty target square
	if piece_kind == "Pawn" and from_c != to_c and piece_sprites[to_r][to_c] == null:
		var ep_target = piece_sprites[from_r][to_c]
		if ep_target != null and is_instance_valid(ep_target):
			ep_target.queue_free()
			piece_sprites[from_r][to_c] = null

	var target_piece = piece_sprites[to_r][to_c]
	if target_piece != null:
		target_piece.queue_free()
		piece_sprites[to_r][to_c] = null
		
	piece_sprites[from_r][from_c] = null
	piece_sprites[to_r][to_c] = piece

	# Castling rook movement: King moved 2 columns
	if piece_kind == "King" and abs(to_c - from_c) == 2:
		var rook_from_c := 7 if to_c > from_c else 0
		var rook_to_c := 5 if to_c > from_c else 3
		var rook_sprite = piece_sprites[to_r][rook_from_c]
		if rook_sprite != null and is_instance_valid(rook_sprite):
			piece_sprites[to_r][rook_from_c] = null
			piece_sprites[to_r][rook_to_c] = rook_sprite
			var rook_pos := Vector2(rook_to_c * CELL_SIZE + CELL_SIZE / 2.0, to_r * CELL_SIZE + CELL_SIZE / 2.0)
			var r_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			r_tw.tween_property(rook_sprite, "position", rook_pos, 0.22)
	
	var target_pos = Vector2(to_c * CELL_SIZE + CELL_SIZE / 2.0, to_r * CELL_SIZE + CELL_SIZE / 2.0)
	if not is_inside_tree():
		piece.position = target_pos
		if is_promotion and is_instance_valid(piece):
			piece.queue_free()
			piece_sprites[to_r][to_c] = null
			_create_piece_sprite(to_r, to_c, piece_player, promoted_kind)
		active_animations = max(0, active_animations - 1)
		if active_animations <= 0:
			animating = false
			animation_finished.emit()
		return

	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(piece, "position", target_pos, 0.22)

	tween.finished.connect(func():
		if is_promotion and is_instance_valid(piece):
			piece.queue_free()
			piece_sprites[to_r][to_c] = null
			_create_piece_sprite(to_r, to_c, piece_player, promoted_kind)
		active_animations -= 1
		if active_animations <= 0:
			active_animations = 0
			animating = false
			animation_finished.emit()
	)

func _on_piece_moved_signal(_player: int, _from_r: int, _from_c: int, _to_r: int, _to_c: int, _cap_r: int, _cap_c: int, _prom: bool) -> void:
	# Chess events are handled in _on_event_json with visual row conversion.
	pass

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type := str(event.get("command_type", event.get("event_type", "")))
			var event_type := raw_type.split("::")[-1]
			if event_type == "PieceMovedEvent":
				var from_dict = event.get("from", {})
				var to_dict = event.get("to", {})
				var from_r = (BOARD_SIZE - 1) - int(from_dict.get("row", 0))
				var from_c = int(from_dict.get("col", 0))
				var to_r = (BOARD_SIZE - 1) - int(to_dict.get("row", 0))
				var to_c = int(to_dict.get("col", 0))
				var is_prom: bool = event.get("promotion") != null or event.get("promoted", false) == true
				var prom_kind := str(event.get("promoted_to", "Queen"))
				if prom_kind == "" or prom_kind == "<null>" or prom_kind == "null":
					prom_kind = "Queen"

				if in_opening_practice and opening_step_index < opening_moves.size():
					var expected = opening_moves[opening_step_index]
					if from_r == expected.from.x and from_c == expected.from.y and to_r == expected.to.x and to_c == expected.to.y:
						opening_step_index += 1
						if opening_step_index >= opening_moves.size():
							in_opening_practice = false
					else:
						in_opening_practice = false

				var is_capture: bool = (event.get("captured") != null) or (_is_in_bounds(to_r, to_c) and piece_sprites[to_r][to_c] != null)
				if is_capture:
					if is_inside_tree() and has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_piece_place(2.0)
				else:
					if is_inside_tree() and has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_piece_place()

				_move_piece_sprite(from_r, from_c, to_r, to_c, is_prom, prom_kind)
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null:
					w = 0
				_on_game_over(int(w))

			current = bridge.current_player()
			var is_check: bool = (event_type == "CheckEvent") or (event.get("in_check") == true) or (event.get("opponent_in_check") == true)
			if is_check:
				check_king_pos = _find_king_pos(current)
				if check_king_pos != null:
					_play_check_shake()
			else:
				check_king_pos = null

	current = bridge.current_player()
	_update_status()
	queue_redraw()

func _play_check_shake() -> void:
	if OS.has_feature("headless"):
		return
	var original_pos := position
	var t := create_tween()
	if t != null:
		t.tween_property(self, "position", original_pos + Vector2(6, 0), 0.05)
		t.tween_property(self, "position", original_pos - Vector2(6, 0), 0.05)
		t.tween_property(self, "position", original_pos + Vector2(4, 0), 0.04)
		t.tween_property(self, "position", original_pos - Vector2(4, 0), 0.04)
		t.tween_property(self, "position", original_pos, 0.03)

func _on_game_over(w: int) -> void:
	winner = w
	check_king_pos = null
	selected_pos = null
	valid_moves.clear()
	_hover_cell = Vector2i(-1, -1)
	_hover_moves.clear()
	_update_status()
	queue_redraw()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()
		
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

	if highlight_moves_enabled and selected_pos == null and _hover_cell != Vector2i(-1, -1):
		for move_pos in _hover_moves:
			var center = Vector2(move_pos.y * CELL_SIZE + CELL_SIZE / 2.0, move_pos.x * CELL_SIZE + CELL_SIZE / 2.0)
			draw_circle(center, CELL_SIZE * 0.15, Color(0.5, 0.9, 0.5, 0.3))

	if highlight_moves_enabled and selected_pos != null:
		for move_pos in valid_moves:
			var center = Vector2(move_pos.y * CELL_SIZE + CELL_SIZE / 2.0, move_pos.x * CELL_SIZE + CELL_SIZE / 2.0)
			draw_circle(center, CELL_SIZE * 0.25, COL_VALID_MOVE)

	# Coordenadas del tablero (a-h en la fila inferior, 1-8 en la columna izquierda)
	var font: Font = null
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
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

	# Cursor virtual de Gamepad / Steam Deck
	if gamepad_cursor_active and _is_in_bounds(gamepad_cursor.x, gamepad_cursor.y):
		var cur_rect := Rect2(gamepad_cursor.y * CELL_SIZE + 3.0, gamepad_cursor.x * CELL_SIZE + 3.0, CELL_SIZE - 6.0, CELL_SIZE - 6.0)
		draw_rect(cur_rect, Color(0.2, 0.95, 1.0, 0.95), false, 3.0)

# --- Soporte de Gamepad y Steam Deck con cursor virtual ---
var gamepad_cursor: Vector2i = Vector2i(6, 4)
var gamepad_cursor_active: bool = false

func move_gamepad_cursor(delta: Vector2i) -> void:
	gamepad_cursor_active = true
	gamepad_cursor.x = clampi(gamepad_cursor.x + delta.x, 0, BOARD_SIZE - 1)
	gamepad_cursor.y = clampi(gamepad_cursor.y + delta.y, 0, BOARD_SIZE - 1)
	_sfx_piece_slide()
	queue_redraw()

func gamepad_select_current_cell() -> void:
	gamepad_cursor_active = true
	_handle_cell_click(gamepad_cursor.x, gamepad_cursor.y)

func gamepad_cancel_selection() -> void:
	_reset_all_piece_scales()
	selected_pos = null
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
	if winner != -1:
		status.text = "¡Jaque mate! Ganó el jugador %s" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var p_name = "Jugador %s" % current
		var p_col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(current) - 1, 6)] as Color)
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
			turn_indicator.set_active(true)

# --- Conexión de eventos sonoros procedurales (AudioManager) ---
func _sfx_piece_slide() -> void:
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_piece_slide()

func _sfx_piece_place() -> void:
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_piece_place()

func _sfx_capture(world_pos: Vector2 = Vector2(240, 240)) -> void:
	if is_inside_tree() and has_node("/root/AudioManager"):
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
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_dice_roll()

func _sfx_card_flip() -> void:
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_card_flip()

func _sfx_check_alert() -> void:
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_check_alert()

func _sfx_victory_fanfare() -> void:
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_victory_fanfare()

func _sfx_error_buzz() -> void:
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_error_buzz()
