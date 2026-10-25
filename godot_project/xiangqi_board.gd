extends Node2D

##
## Tablero de Xiangqi (Ajedrez Chino) para Games & Tables SDK
##
## Características implementadas:
## (a) Fondo de líneas con el Río marcado entre las filas 4 y 5 (楚河 漢界).
## (b) Palacios de 3x3 marcados con las diagonales características (九宮).
## (c) Piezas como discos circulares de madera con caracteres chinos tradicionales (Hanzi)
##     en rojo (帥, 仕, 相, 傌, 俥, 炮, 兵) y negro (將, 士, 象, 馬, 車, 砲, 卒),
##     con anillos concéntricos biselados, sombras táctiles, subtítulos de apoyo y animaciones fluidas.
## (d) Integración total con ThemeManager (colores de tablero, líneas, selección y movimientos válidos),
##     GameManager (modos de juego y layouts responsivos), AudioManager y RulesPopup.
##

const BOARD_ROWS = 10
const BOARD_COLS = 9
const CELL_SIZE = 62.0

const P_RED = 1    # Jugador 1 (Rojo / Inferior / filas 6..9)
const P_BLACK = 2  # Jugador 2 (Negro / Superior / filas 0..3)

# Caracteres chinos tradicionales (Hanzi) para piezas Rojas y Negras
const KANJI_RED = {
	"General": "帥",
	"Advisor": "仕",
	"Elephant": "相",
	"Knight": "傌",
	"Horse": "傌",
	"Rook": "俥",
	"Chariot": "俥",
	"Cannon": "炮",
	"Pawn": "兵",
	"Soldier": "兵"
}

const KANJI_BLACK = {
	"General": "將",
	"Advisor": "士",
	"Elephant": "象",
	"Knight": "馬",
	"Horse": "馬",
	"Rook": "車",
	"Chariot": "車",
	"Cannon": "砲",
	"Pawn": "卒",
	"Soldier": "卒"
}

const NAMES_ES = {
	"General": "General",
	"Advisor": "Asesor",
	"Elephant": "Elefante",
	"Knight": "Caballo",
	"Horse": "Caballo",
	"Rook": "Carro",
	"Chariot": "Carro",
	"Cannon": "Cañón",
	"Pawn": "Soldado",
	"Soldier": "Soldado"
}

# Paletas de color por defecto (sincronizadas con ThemeManager)
const COL_RED_TOKEN = Color(0.82, 0.15, 0.15)
const COL_BLACK_TOKEN = Color(0.14, 0.14, 0.16)
const COL_TOKEN_BODY_LIGHT = Color(0.98, 0.95, 0.88)
const COL_TOKEN_BODY_DARK = Color(0.92, 0.87, 0.78)

var offset_x: float = 76.0
var offset_y: float = 64.0

var bridge
var board: Array = [] # 10x9 array: {"player": int, "kind": String} o null
var piece_nodes: Array = [] # 10x9 array: Control de pieza o null
var current: int = P_RED
var winner: int = -1

var selected_pos = null # Vector2i(row, col) o null
var valid_moves: Array = [] # Array de Vector2i(row, col)
var last_move_from = null
var last_move_to = null
var is_check: bool = false
var checked_player: int = 0

# UI Controls
var table_mat_panel: Panel
var top_bar: HBoxContainer
var mode_option_button: OptionButton
var rules_button: Button
var reset_button: Button
var turn_indicator: TurnIndicator
var event_banner: PanelContainer
var event_label: Label

var captured_red_box: HBoxContainer
var captured_black_box: HBoxContainer
var captured_red_pieces: Array = []
var captured_black_pieces: Array = []

var current_theme: BoardTheme
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

	_setup_ui_layout()
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

	if gm != null and gm.get_game_mode() == "vs_ai":
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else P_RED
		var ai_p: int = P_BLACK if human_p == P_RED else P_RED
		bridge.start_local_match_xiangqi_vs_ai(human_p, ai_p)
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_p == P_RED else 2
	else:
		bridge.start_local_match_xiangqi(P_RED, P_BLACK)
		if mode_option_button != null:
			mode_option_button.selected = 0

	current = bridge.current_player()
	_update_status()
	queue_redraw()

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
	_apply_theme_to_ui()
	queue_redraw()

func _setup_ui_layout() -> void:
	var side_x := 640.0
	# Panel de base para el tapete del tablero (z_index negativo para NO tapar _draw())
	table_mat_panel = Panel.new()
	table_mat_panel.name = "TableMatPanel"
	table_mat_panel.z_index = -2
	table_mat_panel.position = Vector2(32, 20)
	table_mat_panel.size = Vector2(584, 650)
	table_mat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table_mat_panel)

	# Barra de controles en el panel lateral derecho
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(side_x, 24)
	top_bar.size = Vector2(600, 38)
	top_bar.add_theme_constant_override("separation", 10)
	add_child(top_bar)

	# Selector de modo
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.custom_minimum_size = Vector2(280, 34)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano Rojo - J1)")
	mode_option_button.add_item("vs IA (Humano Negro - J2, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	top_bar.add_child(mode_option_button)

	# Botón de Reglas
	rules_button = Button.new()
	rules_button.name = "RulesButton"
	rules_button.text = "📖 Reglas"
	rules_button.custom_minimum_size = Vector2(105, 34)
	rules_button.pressed.connect(_on_rules_pressed)
	top_bar.add_child(rules_button)

	# Botón de Reiniciar
	reset_button = Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "🔄 Reiniciar"
	reset_button.custom_minimum_size = Vector2(110, 34)
	reset_button.pressed.connect(_on_reset_pressed)
	top_bar.add_child(reset_button)

	# Indicador de Turno en el panel lateral derecho
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(side_x, 80)
	turn_indicator.custom_minimum_size = Vector2(260, 40)
	add_child(turn_indicator)

	# Banner de eventos / anuncios en el panel lateral derecho
	event_banner = PanelContainer.new()
	event_banner.name = "EventBanner"
	event_banner.position = Vector2(side_x, 160)
	event_banner.size = Vector2(580, 44)
	var ev_style = StyleBoxFlat.new()
	ev_style.bg_color = Color(0.12, 0.14, 0.18, 0.88)
	ev_style.border_width_left = 1
	ev_style.border_width_top = 1
	ev_style.border_width_right = 1
	ev_style.border_width_bottom = 1
	ev_style.border_color = Color(0.3, 0.4, 0.55, 0.6)
	ev_style.corner_radius_top_left = 8
	ev_style.corner_radius_top_right = 8
	ev_style.corner_radius_bottom_left = 8
	ev_style.corner_radius_bottom_right = 8
	event_banner.add_theme_stylebox_override("panel", ev_style)
	add_child(event_banner)

	event_label = Label.new()
	event_label.text = "Xiangqi (Ajedrez Chino) — Selecciona una pieza para mover."
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 14)
	event_banner.add_child(event_label)

	# Bandeja lateral para capturas Negras (capturadas por Rojo)
	var black_tray_lbl = Label.new()
	black_tray_lbl.text = "Capturas Negras:"
	black_tray_lbl.position = Vector2(side_x, 225)
	black_tray_lbl.add_theme_font_size_override("font_size", 13)
	black_tray_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	add_child(black_tray_lbl)

	captured_black_box = HBoxContainer.new()
	captured_black_box.position = Vector2(side_x, 250)
	captured_black_box.size = Vector2(580, 90)
	captured_black_box.add_theme_constant_override("separation", 6)
	add_child(captured_black_box)

	# Bandeja lateral para capturas Rojas (capturadas por Negro)
	var red_tray_lbl = Label.new()
	red_tray_lbl.text = "Capturas Rojas:"
	red_tray_lbl.position = Vector2(side_x, 360)
	red_tray_lbl.add_theme_font_size_override("font_size", 13)
	red_tray_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	add_child(red_tray_lbl)

	captured_red_box = HBoxContainer.new()
	captured_red_box.position = Vector2(side_x, 385)
	captured_red_box.size = Vector2(580, 90)
	captured_red_box.add_theme_constant_override("separation", 6)
	add_child(captured_red_box)

	if status != null:
		status.visible = false

	_apply_theme_to_ui()

func _apply_theme_to_ui() -> void:
	if table_mat_panel == null:
		return

	var bg_col = Color(0.18, 0.15, 0.12, 0.95)
	var border_col = Color(0.45, 0.35, 0.22, 0.9)
	if current_theme != null:
		bg_col = current_theme.board_color.darkened(0.55)
		border_col = current_theme.line_color

	var mat_style = StyleBoxFlat.new()
	mat_style.bg_color = bg_col
	mat_style.border_width_left = 3
	mat_style.border_width_top = 3
	mat_style.border_width_right = 3
	mat_style.border_width_bottom = 3
	mat_style.border_color = border_col
	mat_style.corner_radius_top_left = 12
	mat_style.corner_radius_top_right = 12
	mat_style.corner_radius_bottom_left = 12
	mat_style.corner_radius_bottom_right = 12
	table_mat_panel.add_theme_stylebox_override("panel", mat_style)

	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

# -------------------------------------------------------------------------
# INICIALIZACIÓN DEL ESTADO DEL TABLERO
# -------------------------------------------------------------------------
func _init_board_state() -> void:
	board.clear()
	for r in range(BOARD_ROWS):
		for col_idx in range(BOARD_COLS):
			if piece_nodes.size() > r and piece_nodes[r].size() > col_idx:
				var old_node = piece_nodes[r][col_idx]
				if old_node != null and is_instance_valid(old_node):
					old_node.queue_free()

	piece_nodes.clear()
	captured_red_pieces.clear()
	captured_black_pieces.clear()
	_refresh_captured_trays()

	for r in range(BOARD_ROWS):
		var row_arr = []
		var node_arr = []
		for col_idx in range(BOARD_COLS):
			row_arr.append(null)
			node_arr.append(null)
		board.append(row_arr)
		piece_nodes.append(node_arr)

	# Piezas Negras (P2) en filas 0..3
	var black_back = ["Chariot", "Horse", "Elephant", "Advisor", "General", "Advisor", "Elephant", "Horse", "Chariot"]
	for c in range(9):
		_create_piece(0, c, P_BLACK, black_back[c])
	_create_piece(2, 1, P_BLACK, "Cannon")
	_create_piece(2, 7, P_BLACK, "Cannon")
	for c in [0, 2, 4, 6, 8]:
		_create_piece(3, c, P_BLACK, "Soldier")

	# Piezas Rojas (P1) en filas 6..9
	var red_back = ["Chariot", "Horse", "Elephant", "Advisor", "General", "Advisor", "Elephant", "Horse", "Chariot"]
	for c in range(9):
		_create_piece(9, c, P_RED, red_back[c])
	_create_piece(7, 1, P_RED, "Cannon")
	_create_piece(7, 7, P_RED, "Cannon")
	for c in [0, 2, 4, 6, 8]:
		_create_piece(6, c, P_RED, "Soldier")

func _get_intersection_center(row: int, col: int) -> Vector2:
	return Vector2(offset_x + col * CELL_SIZE, offset_y + row * CELL_SIZE)

# -------------------------------------------------------------------------
# CREACIÓN DE DISCOS DE PIEZAS CHINAS (HANZI / MADERA)
# -------------------------------------------------------------------------
func _create_piece(row: int, col: int, player: int, kind: String) -> void:
	board[row][col] = {"player": player, "kind": kind}
	var node = _build_piece_control(player, kind)
	var center = _get_intersection_center(row, col)
	node.position = center - node.size / 2.0
	add_child(node)
	piece_nodes[row][col] = node

func _build_piece_control(player: int, kind: String, size_scale: float = 1.0) -> Control:
	var diameter = CELL_SIZE * 0.86 * size_scale
	var ctrl = Control.new()
	ctrl.custom_minimum_size = Vector2(diameter, diameter)
	ctrl.size = Vector2(diameter, diameter)
	ctrl.mouse_filter = Control.MOUSE_FILTER_PASS

	var center = Vector2(diameter / 2.0, diameter / 2.0)
	var radius = diameter / 2.0

	var is_red = (player == P_RED)
	var primary_color = COL_RED_TOKEN if is_red else COL_BLACK_TOKEN
	var kanji_dict = KANJI_RED if is_red else KANJI_BLACK
	var kanji_char = kanji_dict.get(kind, "?")
	var name_es = NAMES_ES.get(kind, "")

	# Texture personalizada de disco de madera biselado con dibujo concéntrico
	var disc_tex_rect = TextureRect.new()
	disc_tex_rect.size = ctrl.size
	disc_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var img_size = int(round(diameter))
	var img = Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
	var img_center = Vector2(img_size / 2.0, img_size / 2.0)
	var r_max = img_size / 2.0 - 1.0

	for x in range(img_size):
		for y in range(img_size):
			var dist = Vector2(x + 0.5, y + 0.5).distance_to(img_center)
			if dist <= r_max:
				var t = dist / r_max
				# Gradiente cálido de madera con bisel
				var body_col = COL_TOKEN_BODY_LIGHT.lerp(COL_TOKEN_BODY_DARK, t * 0.7)
				
				# Anillo exterior biselado
				if dist >= r_max - 2.8:
					img.set_pixel(x, y, primary_color)
				# Ranura concéntrica grabada
				elif dist >= r_max - 5.5 and dist <= r_max - 4.2:
					img.set_pixel(x, y, primary_color.lerp(body_col, 0.35))
				else:
					# Ligero brillo cenital (3D look)
					var light_shift = (y - img_center.y) / (r_max * 1.5)
					var shaded_body = body_col.darkened(max(0.0, light_shift * 0.15))
					img.set_pixel(x, y, shaded_body)
			elif dist <= r_max + 0.8:
				# Antialiasing sutil
				var alpha = 1.0 - (dist - r_max) / 0.8
				img.set_pixel(x, y, Color(primary_color.r, primary_color.g, primary_color.b, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	disc_tex_rect.texture = ImageTexture.create_from_image(img)
	ctrl.add_child(disc_tex_rect)

	# Carácter Chino tradicional (Hanzi)
	var label = Label.new()
	label.text = kanji_char
	var font_size = int(round(28.0 * size_scale))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", primary_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(diameter, diameter * 0.82)
	label.position = Vector2(0, diameter * 0.04)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(label)

	# Subtítulo en español para accesibilidad visual
	if size_scale >= 0.8:
		var sub_lbl = Label.new()
		sub_lbl.text = name_es
		sub_lbl.add_theme_font_size_override("font_size", int(round(9.0 * size_scale)))
		sub_lbl.add_theme_color_override("font_color", primary_color.lerp(Color(0.2, 0.2, 0.2), 0.4))
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.size = Vector2(diameter, 14)
		sub_lbl.position = Vector2(0, diameter - 15)
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(sub_lbl)

	# Animación de hover interactivo al pasar el cursor
	ctrl.mouse_entered.connect(func():
		if winner == -1 and player == current:
			var tw = ctrl.create_tween()
			tw.tween_property(ctrl, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_SINE)
	)
	ctrl.mouse_exited.connect(func():
		var tw = ctrl.create_tween()
		tw.tween_property(ctrl, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
	)

	return ctrl

# -------------------------------------------------------------------------
# INTERACCIÓN DEL USUARIO (CLICK Y MOVIMIENTO)
# -------------------------------------------------------------------------
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
		var col = int(round((click_pos.x - offset_x) / CELL_SIZE))
		var row = int(round((click_pos.y - offset_y) / CELL_SIZE))
		if row >= 0 and row < BOARD_ROWS and col >= 0 and col < BOARD_COLS:
			var target_center = _get_intersection_center(row, col)
			# Tolerancia de clic alrededor de la intersección
			if click_pos.distance_to(target_center) <= CELL_SIZE * 0.55:
				_handle_intersection_click(row, col)

func _handle_intersection_click(row: int, col: int) -> void:
	if selected_pos == null:
		var piece = board[row][col]
		if piece != null and piece.get("player") == current:
			selected_pos = Vector2i(row, col)
			valid_moves = _calculate_legal_moves(row, col)
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_piece_place()
			queue_redraw()
	else:
		# Deselección al tocar la misma pieza
		if selected_pos.x == row and selected_pos.y == col:
			selected_pos = null
			valid_moves.clear()
			queue_redraw()
			return

		# Cambio a otra pieza propia
		var piece_at_target = board[row][col]
		if piece_at_target != null and piece_at_target.get("player") == current:
			selected_pos = Vector2i(row, col)
			valid_moves = _calculate_legal_moves(row, col)
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_piece_place()
			queue_redraw()
			return

		# Ejecutar movimiento
		var from_r = selected_pos.x
		var from_c = selected_pos.y
		selected_pos = null
		valid_moves.clear()
		queue_redraw()

		# Enviar comando a Rust OpenTable Bridge (coordenadas [col, row])
		var cmd = {
			"command_type": "xiangqi_game::MovePieceCommand",
			"player": current,
			"from": [from_c, from_r],
			"to": [col, row]
		}
		bridge.send_command_json(current, JSON.stringify(cmd))

func _move_piece_node(from_r: int, from_c: int, to_r: int, to_c: int) -> void:
	var piece_data = board[from_r][from_c]
	if piece_data == null:
		return

	last_move_from = Vector2i(from_r, from_c)
	last_move_to = Vector2i(to_r, to_c)

	# Captura de pieza rival
	var target_node = piece_nodes[to_r][to_c]
	var captured_data = board[to_r][to_c]
	if target_node != null and is_instance_valid(target_node):
		if captured_data != null:
			_register_capture(captured_data)
		_animate_piece_capture(target_node)
		piece_nodes[to_r][to_c] = null
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_piece_place(2.0)
	else:
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_piece_place()

	board[to_r][to_c] = piece_data
	board[from_r][from_c] = null

	var node = piece_nodes[from_r][from_c]
	piece_nodes[from_r][from_c] = null
	piece_nodes[to_r][to_c] = node

	if node != null:
		var target_center = _get_intersection_center(to_r, to_c)
		var target_pos = target_center - node.size / 2.0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(node, "position", target_pos, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Efecto de elevación parabólica
		tw.tween_property(node, "scale", Vector2(1.15, 1.15), 0.11).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_property(node, "scale", Vector2(1.0, 1.0), 0.11).set_trans(Tween.TRANS_SINE)

	var p_name = "Rojo" if piece_data.player == P_RED else "Negro"
	var k_name = NAMES_ES.get(piece_data.kind, piece_data.kind)
	var k_char = (KANJI_RED if piece_data.player == P_RED else KANJI_BLACK).get(piece_data.kind, "")
	event_label.text = "%s movió %s %s a [%d, %d]" % [p_name, k_name, k_char, to_c, to_r]

	_check_for_general_threat()
	queue_redraw()

func _animate_piece_capture(node: Control) -> void:
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 0.0, 0.25)
	tw.tween_property(node, "scale", Vector2(0.4, 0.4), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if is_instance_valid(node):
			node.queue_free()
	)

func _register_capture(p_data: Dictionary) -> void:
	if p_data.player == P_RED:
		captured_red_pieces.append(p_data)
	else:
		captured_black_pieces.append(p_data)
	_refresh_captured_trays()

func _refresh_captured_trays() -> void:
	if captured_black_box != null:
		for ch in captured_black_box.get_children():
			ch.queue_free()
		for p in captured_black_pieces:
			var mini = _build_piece_control(p.player, p.kind, 0.55)
			captured_black_box.add_child(mini)

	if captured_red_box != null:
		for ch in captured_red_box.get_children():
			ch.queue_free()
		for p in captured_red_pieces:
			var mini = _build_piece_control(p.player, p.kind, 0.55)
			captured_red_box.add_child(mini)

# -------------------------------------------------------------------------
# CÁLCULO DE MOVIMIENTOS VÁLIDOS (PARA GUÍA VISUAL)
# -------------------------------------------------------------------------
func _calculate_legal_moves(r: int, c: int) -> Array:
	var moves: Array = []
	var piece = board[r][c]
	if piece == null:
		return moves

	var p = piece.player
	var kind = piece.kind

	match kind:
		"General":
			# 1 paso ortogonal dentro del palacio
			var row_min = 7 if p == P_RED else 0
			var row_max = 9 if p == P_RED else 2
			for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nr = r + dir.x
				var nc = c + dir.y
				if nr >= row_min and nr <= row_max and nc >= 3 and nc <= 5:
					if _can_land_on(nr, nc, p):
						moves.append(Vector2i(nr, nc))

		"Advisor":
			# 1 paso diagonal dentro del palacio (exactamente 5 posiciones posibles)
			var row_min = 7 if p == P_RED else 0
			var row_max = 9 if p == P_RED else 2
			for dir in [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
				var nr = r + dir.x
				var nc = c + dir.y
				if nr >= row_min and nr <= row_max and nc >= 3 and nc <= 5:
					if _can_land_on(nr, nc, p):
						moves.append(Vector2i(nr, nc))

		"Elephant":
			# 2 pasos diagonales, no cruza el río, ojo de elefante desbloqueado
			var row_min = 5 if p == P_RED else 0
			var row_max = 9 if p == P_RED else 4
			for dir in [Vector2i(-2, -2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(2, 2)]:
				var nr = r + dir.x
				var nc = c + dir.y
				if nr >= row_min and nr <= row_max and nc >= 0 and nc <= 8:
					var eye_r = r + dir.x / 2
					var eye_c = c + dir.y / 2
					if board[eye_r][eye_c] == null:
						if _can_land_on(nr, nc, p):
							moves.append(Vector2i(nr, nc))

		"Horse", "Knight":
			# Movimiento en L, pata de caballo no bloqueada
			var horse_moves = [
				{"dir": Vector2i(-2, -1), "block": Vector2i(-1, 0)},
				{"dir": Vector2i(-2, 1), "block": Vector2i(-1, 0)},
				{"dir": Vector2i(2, -1), "block": Vector2i(1, 0)},
				{"dir": Vector2i(2, 1), "block": Vector2i(1, 0)},
				{"dir": Vector2i(-1, -2), "block": Vector2i(0, -1)},
				{"dir": Vector2i(1, -2), "block": Vector2i(0, -1)},
				{"dir": Vector2i(-1, 2), "block": Vector2i(0, 1)},
				{"dir": Vector2i(1, 2), "block": Vector2i(0, 1)}
			]
			for hm in horse_moves:
				var nr = r + hm.dir.x
				var nc = c + hm.dir.y
				var br = r + hm.block.x
				var bc = c + hm.block.y
				if nr >= 0 and nr < BOARD_ROWS and nc >= 0 and nc < BOARD_COLS:
					if board[br][bc] == null:
						if _can_land_on(nr, nc, p):
							moves.append(Vector2i(nr, nc))

		"Rook", "Chariot":
			# Mueve cualquier distancia ortogonal sin saltar
			for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nr = r + dir.x
				var nc = c + dir.y
				while nr >= 0 and nr < BOARD_ROWS and nc >= 0 and nc < BOARD_COLS:
					if board[nr][nc] == null:
						moves.append(Vector2i(nr, nc))
					else:
						if board[nr][nc].player != p:
							moves.append(Vector2i(nr, nc))
						break
					nr += dir.x
					nc += dir.y

		"Cannon":
			# Mueve como torre si no captura; si captura debe saltar exactamente 1 pieza (pantalla)
			for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nr = r + dir.x
				var nc = c + dir.y
				var jumped = false
				while nr >= 0 and nr < BOARD_ROWS and nc >= 0 and nc < BOARD_COLS:
					if not jumped:
						if board[nr][nc] == null:
							moves.append(Vector2i(nr, nc))
						else:
							jumped = true
					else:
						if board[nr][nc] != null:
							if board[nr][nc].player != p:
								moves.append(Vector2i(nr, nc))
							break
					nr += dir.x
					nc += dir.y

		"Soldier", "Pawn":
			if p == P_RED:
				# Avanza hacia arriba
				var nr = r - 1
				if nr >= 0 and _can_land_on(nr, c, p):
					moves.append(Vector2i(nr, c))
				# Si ya cruzó el río (filas <= 4), puede mover lateralmente
				if r <= 4:
					if c > 0 and _can_land_on(r, c - 1, p):
						moves.append(Vector2i(r, c - 1))
					if c < 8 and _can_land_on(r, c + 1, p):
						moves.append(Vector2i(r, c + 1))
			else:
				# Avanza hacia abajo
				var nr = r + 1
				if nr < BOARD_ROWS and _can_land_on(nr, c, p):
					moves.append(Vector2i(nr, c))
				# Si ya cruzó el río (filas >= 5), puede mover lateralmente
				if r >= 5:
					if c > 0 and _can_land_on(r, c - 1, p):
						moves.append(Vector2i(r, c - 1))
					if c < 8 and _can_land_on(r, c + 1, p):
						moves.append(Vector2i(r, c + 1))

	return moves

func _can_land_on(r: int, c: int, player: int) -> bool:
	if board[r][c] == null:
		return true
	return board[r][c].player != player

func _check_for_general_threat() -> void:
	# Búsqueda de amenaza de jaque básica para avisos
	is_check = false
	queue_redraw()

# -------------------------------------------------------------------------
# EVENTOS DEL ENGINE DE OPENTABLE BRIDGE
# -------------------------------------------------------------------------
func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type := str(event.get("command_type", event.get("event_type", "")))
			var event_type := raw_type.split("::")[-1]
			if event_type == "PieceMovedEvent":
				var from = event.get("from", [0, 0])
				var to = event.get("to", [0, 0])
				# Coordenadas Rust: [col, row]
				var from_c = int(from[0])
				var from_r = int(from[1])
				var to_c = int(to[0])
				var to_r = int(to[1])
				_move_piece_node(from_r, from_c, to_r, to_c)
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
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	if ResourceLoader.exists("res://game_over_overlay.tscn"):
		var overlay = preload("res://game_over_overlay.tscn").instantiate()
		add_child(overlay)
		if overlay.has_method("show_winner"):
			overlay.call("show_winner", w)

func _on_move_rejected(reason: String) -> void:
	event_label.text = "❌ Movimiento no permitido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _on_mode_selected(index: int) -> void:
	winner = -1
	selected_pos = null
	valid_moves.clear()
	last_move_from = null
	last_move_to = null

	_init_board_state()

	if bridge != null:
		match index:
			1:
				bridge.start_local_match_xiangqi_vs_ai(P_RED, P_BLACK)
			2:
				bridge.start_local_match_xiangqi_vs_ai(P_BLACK, P_RED)
			_:
				bridge.start_local_match_xiangqi(P_RED, P_BLACK)

	current = bridge.current_player() if bridge else P_RED
	event_label.text = "Nueva partida iniciada (%s)" % ("vs IA" if index >= 1 else "Hotseat")
	_update_status()
	queue_redraw()

func _on_rules_pressed() -> void:
	if rules_popup == null:
		rules_popup = RulesPopup.new()
		add_child(rules_popup)
	rules_popup.show_for_game("xiangqi")

func _on_reset_pressed() -> void:
	_on_mode_selected(mode_option_button.selected if mode_option_button else 0)

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	offset_x = 76.0
	offset_y = 64.0
	if table_mat_panel != null:
		table_mat_panel.position = Vector2(32, 20)
		table_mat_panel.size = Vector2(584, 650)

	_update_piece_node_positions()
	queue_redraw()

func _update_piece_node_positions() -> void:
	for r in range(BOARD_ROWS):
		for c in range(BOARD_COLS):
			var node = piece_nodes[r][c]
			if node != null and is_instance_valid(node):
				var center = _get_intersection_center(r, c)
				node.position = center - node.size / 2.0

func _update_status() -> void:
	var p_name = "Rojo (帅)" if current == P_RED else "Negro (将)"
	var p_col = COL_RED_TOKEN if current == P_RED else COL_BLACK_TOKEN

	if winner != -1:
		var win_name = "Rojo" if winner == P_RED else "Negro"
		event_label.text = "¡Jaque Mate! Ganó el jugador %s (Xiangqi)" % win_name
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		if turn_indicator != null:
			turn_indicator.set_turn(current, p_name, p_col)
			turn_indicator.set_active(true)

# -------------------------------------------------------------------------
# DIBUJADO DEL TABLERO TRADICIONAL DE XIANGQI (RÍO, PALACIOS, LÍNEAS, ESTRELLAS)
# -------------------------------------------------------------------------
func _draw() -> void:
	# 1. Colores activos del ThemeManager
	var board_bg = Color(0.92, 0.82, 0.62)
	var line_color = Color(0.24, 0.16, 0.08)
	var select_color = Color(1.0, 0.92, 0.25, 0.6)
	var valid_move_color = Color(0.25, 0.85, 0.35, 0.65)
	var river_tint = Color(0.2, 0.45, 0.7, 0.12)

	if current_theme != null:
		board_bg = current_theme.board_color
		line_color = current_theme.line_color
		select_color = current_theme.select_color
		valid_move_color = current_theme.valid_move_color

	var board_width = (BOARD_COLS - 1) * CELL_SIZE
	var board_height = (BOARD_ROWS - 1) * CELL_SIZE
	var pad = 24.0

	# 2. Rectángulo principal del tablero de madera
	var outer_rect = Rect2(offset_x - pad, offset_y - pad, board_width + pad * 2.0, board_height + pad * 2.0)
	draw_rect(outer_rect, board_bg, true)

	# Borde exterior doble ornamental
	draw_rect(outer_rect, line_color, false, 3.0)
	var inner_border = Rect2(offset_x - pad + 6, offset_y - pad + 6, board_width + (pad - 6) * 2.0, board_height + (pad - 6) * 2.0)
	draw_rect(inner_border, line_color, false, 1.2)

	# 3. Franja del Río (Chu River / Han Border entre filas 4 y 5)
	var river_y_top = offset_y + 4 * CELL_SIZE
	var river_y_bot = offset_y + 5 * CELL_SIZE
	var river_rect = Rect2(offset_x, river_y_top, board_width, CELL_SIZE)
	draw_rect(river_rect, river_tint, true)

	# 4. Líneas Horizontales (10 líneas continuas de col 0 a col 8)
	for r in range(BOARD_ROWS):
		var p1 = _get_intersection_center(r, 0)
		var p2 = _get_intersection_center(r, BOARD_COLS - 1)
		draw_line(p1, p2, line_color, 2.0)

	# 5. Líneas Verticales (9 columnas):
	# - Columnas exteriores (0 y 8) son continuas de fila 0 a 9.
	# - Columnas interiores (1 a 7) se interrumpen en el Río (0..4 y 5..9).
	for c in range(BOARD_COLS):
		if c == 0 or c == BOARD_COLS - 1:
			var p1 = _get_intersection_center(0, c)
			var p2 = _get_intersection_center(BOARD_ROWS - 1, c)
			draw_line(p1, p2, line_color, 2.0)
		else:
			# Tramo superior (Negro)
			var p1 = _get_intersection_center(0, c)
			var p2 = _get_intersection_center(4, c)
			draw_line(p1, p2, line_color, 2.0)
			# Tramo inferior (Rojo)
			var p3 = _get_intersection_center(5, c)
			var p4 = _get_intersection_center(BOARD_ROWS - 1, c)
			draw_line(p3, p4, line_color, 2.0)

	# 6. Palacios (Jiugong / 3x3) con Diagonales características:
	# Palacio Negro superior (filas 0..2, columnas 3..5)
	draw_line(_get_intersection_center(0, 3), _get_intersection_center(2, 5), line_color, 2.0)
	draw_line(_get_intersection_center(0, 5), _get_intersection_center(2, 3), line_color, 2.0)
	# Palacio Rojo inferior (filas 7..9, columnas 3..5)
	draw_line(_get_intersection_center(7, 3), _get_intersection_center(9, 5), line_color, 2.0)
	draw_line(_get_intersection_center(7, 5), _get_intersection_center(9, 3), line_color, 2.0)

	# 7. Marcas de Estrella / Cruces de intersección tradicionales (Cañones y Soldados)
	var star_positions = [
		# Cañones Negros
		Vector2i(2, 1), Vector2i(2, 7),
		# Soldados Negros
		Vector2i(3, 0), Vector2i(3, 2), Vector2i(3, 4), Vector2i(3, 6), Vector2i(3, 8),
		# Soldados Rojos
		Vector2i(6, 0), Vector2i(6, 2), Vector2i(6, 4), Vector2i(6, 6), Vector2i(6, 8),
		# Cañones Rojos
		Vector2i(7, 1), Vector2i(7, 7)
	]
	for sp in star_positions:
		_draw_intersection_star(sp.x, sp.y, line_color)

	# 8. Caligrafía tradicional del Río (楚河 漢界 — Río Chu y Frontera Han)
	var river_center_y = (river_y_top + river_y_bot) / 2.0
	var font = ThemeDB.fallback_font

	# "楚 河" a la izquierda
	var left_river_x = offset_x + 1.2 * CELL_SIZE
	draw_string(font, Vector2(left_river_x, river_center_y + 8), "楚  河", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, line_color.darkened(0.2))
	draw_string(font, Vector2(left_river_x - 10, river_center_y + 22), "RÍO CHU", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, line_color.lerp(board_bg, 0.4))

	# "漢 界" a la derecha
	var right_river_x = offset_x + 5.5 * CELL_SIZE
	draw_string(font, Vector2(right_river_x, river_center_y + 8), "漢  界", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, line_color.darkened(0.2))
	draw_string(font, Vector2(right_river_x - 10, river_center_y + 22), "FRONTERA HAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, line_color.lerp(board_bg, 0.4))

	# 9. Resaltado del último movimiento (origen y destino)
	if last_move_from != null and last_move_to != null:
		var last_from_pos = _get_intersection_center(last_move_from.x, last_move_from.y)
		var last_to_pos = _get_intersection_center(last_move_to.x, last_move_to.y)
		draw_circle(last_from_pos, CELL_SIZE * 0.45, Color(1.0, 0.85, 0.3, 0.22))
		draw_arc(last_from_pos, CELL_SIZE * 0.45, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.6), 2.0)
		draw_arc(last_to_pos, CELL_SIZE * 0.46, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.85), 2.5)

	# 10. Resaltado de la pieza seleccionada
	if selected_pos != null:
		var sel_center = _get_intersection_center(selected_pos.x, selected_pos.y)
		# Halo resplandeciente
		draw_circle(sel_center, CELL_SIZE * 0.48, select_color)
		draw_arc(sel_center, CELL_SIZE * 0.48, 0, TAU, 36, Color(1.0, 0.9, 0.1, 0.95), 3.0)

	# 11. Destinos de movimientos válidos
	for vm in valid_moves:
		var vm_center = _get_intersection_center(vm.x, vm.y)
		var target_is_enemy = (board[vm.x][vm.y] != null)
		if target_is_enemy:
			# Anillo de captura en rojo/dorado
			draw_circle(vm_center, CELL_SIZE * 0.46, Color(0.9, 0.2, 0.2, 0.35))
			draw_arc(vm_center, CELL_SIZE * 0.46, 0, TAU, 32, Color(0.95, 0.2, 0.2, 0.9), 2.5)
		else:
			# Punto guía verde radiante
			draw_circle(vm_center, CELL_SIZE * 0.18, valid_move_color)
			draw_arc(vm_center, CELL_SIZE * 0.18, 0, TAU, 24, valid_move_color.lightened(0.3), 1.5)

# Función auxiliar para dibujar los 4 corchetes de esquina tradicionales en intersecciones clave
func _draw_intersection_star(row: int, col: int, col_line: Color) -> void:
	var center = _get_intersection_center(row, col)
	var d = 4.0   # Separación del centro
	var len = 7.0 # Longitud de la patilla del corchete

	# Superior Izquierda
	if col > 0:
		draw_line(center + Vector2(-d, -d), center + Vector2(-d - len, -d), col_line, 1.2)
		draw_line(center + Vector2(-d, -d), center + Vector2(-d, -d - len), col_line, 1.2)
	# Superior Derecha
	if col < BOARD_COLS - 1:
		draw_line(center + Vector2(d, -d), center + Vector2(d + len, -d), col_line, 1.2)
		draw_line(center + Vector2(d, -d), center + Vector2(d, -d - len), col_line, 1.2)
	# Inferior Izquierda
	if col > 0:
		draw_line(center + Vector2(-d, d), center + Vector2(-d - len, d), col_line, 1.2)
		draw_line(center + Vector2(-d, d), center + Vector2(-d, d + len), col_line, 1.2)
	# Inferior Derecha
	if col < BOARD_COLS - 1:
		draw_line(center + Vector2(d, d), center + Vector2(d + len, d), col_line, 1.2)
		draw_line(center + Vector2(d, d), center + Vector2(d, d + len), col_line, 1.2)

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
