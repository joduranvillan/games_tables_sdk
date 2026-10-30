extends Node2D

const GOBAN_PIXEL_SPAN = 612.0
const P_BLACK = 1
const P_WHITE = 2
const KOMI = 6.5

var BOARD_SIZE: int = 9
var CELL_SIZE: float = 68.0

# Colors
const COL_BOARD = Color(0.85, 0.70, 0.35)
const COL_LINE = Color(0.15, 0.10, 0.05)
const COL_BLACK_STONE = Color(0.10, 0.10, 0.10)
const COL_WHITE_STONE = Color(0.95, 0.95, 0.95)

var bridge
var board: Array = [] # NxN array: null | P_BLACK | P_WHITE
var stone_nodes: Array = [] # NxN array: TextureRect/Control nodes
var territory_map: Array = [] # NxN array: null | P_BLACK | P_WHITE
var current: int = P_BLACK
var winner: int = -1
var black_score: float = 0.0
var white_score: float = 0.0
var black_captured: int = 0
var white_captured: int = 0
var consecutive_passes: int = 0
var last_placed_cell: Vector2i = Vector2i(-1, -1)
var _ko_point: Vector2i = Vector2i(-1, -1)
var _local_oversize_hotseat: bool = false

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
var mode_option_button: OptionButton
var size_option_button: OptionButton
var handicap_option_button: OptionButton = null
var scoring_phase_banner: PanelContainer = null
var scoring_banner_label: Label = null
var confirm_dead_button: Button = null
var dead_stones: Array[Vector2i] = []
var scoring_phase: bool = false
var auto_confirm_dead_in_headless: bool = true
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
	if is_inside_tree() and get_viewport() != null:
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)

	_setup_ui()
	_init_board()
	
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
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	var initial_mode_idx: int = 0
	if gm != null and gm.get_game_mode() == "vs_ai":
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else P_BLACK
		initial_mode_idx = 1 if human_p == P_BLACK else 2
	if mode_option_button != null:
		mode_option_button.selected = initial_mode_idx
	if size_option_button != null:
		size_option_button.selected = 0

	_start_or_reset_match()
	_on_layout_changed(gm.get_layout() if gm != null else 0)

	# --- Botón de reglas ---
	var btn_rules: Button = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(930, 310)
	btn_rules.custom_minimum_size = Vector2(110, 36)
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
	var side_x: float = 640.0
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	status.position = Vector2(side_x, 185)

	stones_container = Node2D.new()
	stones_container.name = "StonesContainer"
	stones_container.z_index = 1
	add_child(stones_container)

	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(side_x, 18)
	mode_option_button.custom_minimum_size = Vector2(360, 34)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano Negras - J1)")
	mode_option_button.add_item("vs IA (Humano Blancas - J2, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	size_option_button = OptionButton.new()
	size_option_button.name = "BoardSizeOptionButton"
	size_option_button.position = Vector2(side_x, 60)
	size_option_button.custom_minimum_size = Vector2(360, 34)
	size_option_button.add_item("Tablero 9x9 (Rápido)")
	size_option_button.add_item("Tablero 13x13 (Intermedio)")
	size_option_button.add_item("Tablero 19x19 (Estándar / Oficial)")
	size_option_button.item_selected.connect(_on_size_selected)
	add_child(size_option_button)

	# Board Info & Komi Label in right sidebar
	captured_score_label = Label.new()
	captured_score_label.name = "CapturedScoreLabel"
	captured_score_label.position = Vector2(side_x, 220)
	captured_score_label.size = Vector2(420, 28)
	captured_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	captured_score_label.add_theme_font_size_override("font_size", 15)
	captured_score_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	add_child(captured_score_label)

	# Captured Stones Counters in right sidebar
	var captures_container = HBoxContainer.new()
	captures_container.name = "CapturesContainer"
	captures_container.position = Vector2(side_x, 252)
	captures_container.size = Vector2(420, 30)
	captures_container.add_theme_constant_override("separation", 28)
	add_child(captures_container)

	captures_label_n = Label.new()
	captures_label_n.name = "CapturesLabelN"
	captures_label_n.text = "● Capturas N: 0"
	captures_label_n.add_theme_font_size_override("font_size", 16)
	captures_label_n.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	captures_container.add_child(captures_label_n)

	captures_label_b = Label.new()
	captures_label_b.name = "CapturesLabelB"
	captures_label_b.text = "○ Capturas B: 0"
	captures_label_b.add_theme_font_size_override("font_size", 16)
	captures_label_b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	captures_container.add_child(captures_label_b)

	# Drag & Drop / Input Layer (pasivo para evitar doble envío con _input)
	drag_layer = DragDropLayer.new()
	drag_layer.name = "DragDropLayer"
	drag_layer.cell_size = CELL_SIZE
	drag_layer.board_bounds = Vector2i(BOARD_SIZE, BOARD_SIZE)
	drag_layer.enabled = false
	drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_layer)
	drag_layer.set_process_input(false)
	drag_layer.set_process_unhandled_input(false)

	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(side_x, 108)
	add_child(turn_indicator)

	# Botón Pasar Turno (PassCommand)
	var pass_btn: Button = Button.new()
	pass_btn.name = "PassTurnButton"
	pass_btn.text = "⏭️ Pasar"
	pass_btn.position = Vector2(side_x, 310)
	pass_btn.custom_minimum_size = Vector2(120, 36)
	pass_btn.pressed.connect(_on_pass_pressed)
	add_child(pass_btn)

	# Botón Tutorial Interactivo de Go (5 pasos)
	var tutorial_btn: Button = Button.new()
	tutorial_btn.name = "GoTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(side_x + 135, 310)
	tutorial_btn.custom_minimum_size = Vector2(140, 36)
	tutorial_btn.pressed.connect(start_go_tutorial)
	add_child(tutorial_btn)

	# Botón Exportar Partida (SGF)
	export_game_button = Button.new()
	export_game_button.name = "ExportGameButton"
	export_game_button.text = "Exportar Partida"
	export_game_button.position = Vector2(side_x, 360)
	export_game_button.custom_minimum_size = Vector2(170, 36)
	export_game_button.pressed.connect(_on_export_game_pressed)
	add_child(export_game_button)

	# Selector de Handicap Inicial (PlaceHandicapCommand: 0, 2, 3, 4 piedras Hoshi)
	handicap_option_button = OptionButton.new()
	handicap_option_button.name = "HandicapOptionButton"
	handicap_option_button.position = Vector2(side_x + 180, 360)
	handicap_option_button.custom_minimum_size = Vector2(210, 36)
	handicap_option_button.add_item("Handicap: 0 piedras")
	handicap_option_button.add_item("Handicap: 2 piedras (Hoshi)")
	handicap_option_button.add_item("Handicap: 3 piedras (Hoshi)")
	handicap_option_button.add_item("Handicap: 4 piedras (Hoshi)")
	handicap_option_button.item_selected.connect(_on_handicap_selected)
	add_child(handicap_option_button)

	# Banner de Fase de Conteo con Puntaje Parcial en Vivo + ConfirmDeadButton
	scoring_phase_banner = PanelContainer.new()
	scoring_phase_banner.name = "ScoringPhaseBanner"
	scoring_phase_banner.position = Vector2(side_x, 404)
	scoring_phase_banner.visible = false
	var sb_style: StyleBoxFlat = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.11, 0.14, 0.20, 0.96)
	sb_style.border_color = Color(0.92, 0.76, 0.28, 0.95)
	sb_style.set_border_width_all(2)
	sb_style.set_corner_radius_all(8)
	sb_style.content_margin_left = 10
	sb_style.content_margin_right = 10
	sb_style.content_margin_top = 8
	sb_style.content_margin_bottom = 8
	scoring_phase_banner.add_theme_stylebox_override("panel", sb_style)
	var sb_vbox: VBoxContainer = VBoxContainer.new()
	sb_vbox.add_theme_constant_override("separation", 6)
	scoring_banner_label = Label.new()
	scoring_banner_label.name = "ScoringBannerLabel"
	scoring_banner_label.text = "⚖️ Fase de Conteo: Marca piedras muertas (✕)"
	scoring_banner_label.add_theme_font_size_override("font_size", 14)
	scoring_banner_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.65))
	sb_vbox.add_child(scoring_banner_label)

	confirm_dead_button = Button.new()
	confirm_dead_button.name = "ConfirmDeadButton"
	confirm_dead_button.text = "✅ Confirmar Piedras Muertas"
	confirm_dead_button.custom_minimum_size = Vector2(260, 36)
	confirm_dead_button.pressed.connect(_on_confirm_dead_pressed)
	sb_vbox.add_child(confirm_dead_button)
	scoring_phase_banner.add_child(sb_vbox)
	add_child(scoring_phase_banner)

	export_toast_label = Label.new()
	export_toast_label.name = "ExportToastLabel"
	export_toast_label.text = ""
	export_toast_label.visible = false
	export_toast_label.position = Vector2(side_x, 495)
	export_toast_label.add_theme_font_size_override("font_size", 14)
	export_toast_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	add_child(export_toast_label)

func set_board_size(new_size: int) -> void:
	if not (new_size in [9, 13, 19]):
		new_size = 9
	BOARD_SIZE = new_size
	CELL_SIZE = GOBAN_PIXEL_SPAN / float(BOARD_SIZE)
	if size_option_button != null:
		match BOARD_SIZE:
			13: size_option_button.selected = 1
			19: size_option_button.selected = 2
			_: size_option_button.selected = 0
	if drag_layer != null:
		drag_layer.cell_size = CELL_SIZE
		drag_layer.board_bounds = Vector2i(BOARD_SIZE, BOARD_SIZE)
	_start_or_reset_match()

func _on_size_selected(index: int) -> void:
	var target_size: int = 9
	match index:
		1: target_size = 13
		2: target_size = 19
		_: target_size = 9
	set_board_size(target_size)

func _on_mode_selected(_index: int) -> void:
	_start_or_reset_match()

func _on_handicap_selected(index: int) -> void:
	var stones_count: int = 0
	match index:
		1: stones_count = 2
		2: stones_count = 3
		3: stones_count = 4
		_: stones_count = 0
	apply_handicap(stones_count)

func apply_handicap(stones: int) -> void:
	_start_or_reset_match()
	if stones <= 0 or bridge == null:
		return
	var cmd: Dictionary = {
		"command_type": "go_game::PlaceHandicapCommand",
		"stones": stones
	}
	bridge.send_command_json(P_BLACK, JSON.stringify(cmd))
	var hoshi_coords: Array[Vector2i] = [
		Vector2i(2, 6),
		Vector2i(6, 2),
		Vector2i(6, 6),
		Vector2i(2, 2)
	]
	for i in range(min(stones, hoshi_coords.size())):
		var hc: Vector2i = hoshi_coords[i]
		if hc.x < BOARD_SIZE and hc.y < BOARD_SIZE and board[hc.x][hc.y] == null:
			_place_stone(hc.x, hc.y, P_BLACK)
	current = bridge.current_player()
	_update_status()
	queue_redraw()

func mark_dead_stone(row: int, col: int) -> void:
	if row < 0 or row >= BOARD_SIZE or col < 0 or col >= BOARD_SIZE:
		return
	var pos: Vector2i = Vector2i(row, col)
	if pos in dead_stones:
		dead_stones.erase(pos)
	else:
		dead_stones.append(pos)
	if bridge != null:
		var cmd: Dictionary = {
			"command_type": "go_game::MarkDeadCommand",
			"player": current,
			"positions": [[col, row]]
		}
		bridge.send_command_json(current, JSON.stringify(cmd))
	_update_scoring_banner()
	queue_redraw()

func _update_scoring_banner() -> void:
	if scoring_banner_label == null:
		return
	var dead_black: int = 0
	var dead_white: int = 0
	for dp in dead_stones:
		if dp.x >= 0 and dp.x < BOARD_SIZE and dp.y >= 0 and dp.y < BOARD_SIZE:
			var owner = board[dp.x][dp.y]
			if owner == P_BLACK:
				dead_black += 1
			elif owner == P_WHITE:
				dead_white += 1
	_calculate_territory()
	var est_black: float = black_score + float(dead_white)
	var est_white: float = white_score + float(dead_black)
	scoring_banner_label.text = "⚖️ Conteo en vivo — Negro: %.1f | Blanco: %.1f (Komi %.1f) · Muertas: %d" % [est_black, est_white, KOMI, dead_stones.size()]

func _on_confirm_dead_pressed() -> void:
	scoring_phase = false
	if scoring_phase_banner != null:
		scoring_phase_banner.visible = false
	if confirm_dead_button != null:
		confirm_dead_button.visible = false
	if bridge != null and winner == -1:
		bridge.send_command_json(P_BLACK, JSON.stringify({"command_type": "go_game::ConfirmDeadCommand", "player": P_BLACK}))
		bridge.send_command_json(P_WHITE, JSON.stringify({"command_type": "go_game::ConfirmDeadCommand", "player": P_WHITE}))
	_update_status()
	queue_redraw()

func _start_or_reset_match() -> void:
	winner = -1
	black_captured = 0
	white_captured = 0
	black_score = 0.0
	white_score = 0.0
	consecutive_passes = 0
	scoring_phase = false
	dead_stones.clear()
	if scoring_phase_banner != null:
		scoring_phase_banner.visible = false
	if confirm_dead_button != null:
		confirm_dead_button.visible = false
	last_placed_cell = Vector2i(-1, -1)
	_ko_point = Vector2i(-1, -1)
	_local_oversize_hotseat = false
	CELL_SIZE = GOBAN_PIXEL_SPAN / float(BOARD_SIZE)

	if stones_container != null:
		for ch in stones_container.get_children():
			ch.queue_free()
	_init_board()

	var mode_idx: int = mode_option_button.selected if mode_option_button != null else 0
	var gm = (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
	var diff: int = gm.get_ai_difficulty() if (gm != null and gm.has_method("get_ai_difficulty")) else 1

	if bridge != null:
		var has_set_size: bool = bridge.has_method("set_go_board_size")
		match mode_idx:
			1:
				var ai_param: int = diff if (BOARD_SIZE == 9 or has_set_size) else BOARD_SIZE
				bridge.start_local_match_go_vs_ai(P_BLACK, P_WHITE, ai_param)
				if has_set_size and BOARD_SIZE != 9:
					bridge.call("set_go_board_size", BOARD_SIZE)
			2:
				var ai_param: int = diff if (BOARD_SIZE == 9 or has_set_size) else BOARD_SIZE
				bridge.start_local_match_go_vs_ai(P_WHITE, P_BLACK, ai_param)
				if has_set_size and BOARD_SIZE != 9:
					bridge.call("set_go_board_size", BOARD_SIZE)
			_:
				bridge.start_local_match_go(P_BLACK, P_WHITE)
				if has_set_size and BOARD_SIZE != 9:
					bridge.call("set_go_board_size", BOARD_SIZE)
				elif BOARD_SIZE != 9:
					_local_oversize_hotseat = true

	current = bridge.current_player() if (bridge != null and not _local_oversize_hotseat) else P_BLACK
	_update_status()
	_update_captured_score()
	queue_redraw()

func _on_pass_pressed() -> void:
	if winner != -1:
		return
	if _local_oversize_hotseat:
		_handle_local_pass()
		return
	if bridge != null:
		bridge.send_command_json(current, JSON.stringify({"command_type": "go_game::PassCommand", "player": current}))

func _on_export_game_pressed() -> void:
	var sgf_text: String = ""
	if bridge != null and bridge.has_method("export_go_sgf") and not _local_oversize_hotseat:
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
		var timer: SceneTreeTimer = get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(export_toast_label):
				export_toast_label.visible = false
		)

func _update_captured_score() -> void:
	if captures_label_b != null:
		captures_label_b.text = "○ Capturas B: %d" % white_captured
	if captures_label_n != null:
		captures_label_n.text = "● Capturas N: %d" % black_captured
	if captured_score_label != null:
		captured_score_label.text = "Tablero %dx%d · Komi: %.1f · Capturas N: %d | B: %d" % [BOARD_SIZE, BOARD_SIZE, KOMI, black_captured, white_captured]

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	queue_redraw()

func _on_viewport_size_changed() -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	_on_layout_changed(gm.get_layout() if gm != null else 0)

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz: Vector2 = get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if _layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)
	var design_w: float = 1060.0
	var design_h: float = 620.0
	if _layout == 2 or vp_size.x < design_w or vp_size.y < design_h:
		var s: float = clampf(minf(vp_size.x / design_w, vp_size.y / design_h), 0.30, 1.0)
		scale = Vector2(s, s)
		position = Vector2(maxf(0.0, (vp_size.x - design_w * s) * 0.5), maxf(0.0, (vp_size.y - design_h * s) * 0.5))
	else:
		scale = Vector2.ONE
		position = Vector2.ZERO

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
	if winner != -1:
		return
	var row = cell.x
	var col = cell.y
	if row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE:
		if scoring_phase and board[row][col] != null:
			mark_dead_stone(row, col)
			return
		if board[row][col] == null:
			if _local_oversize_hotseat:
				_handle_local_place_stone(row, col)
				return
			var cmd = {
				"command_type": "go_game::PlaceStoneCommand",
				"player": current,
				"x": col,
				"y": row
			}
			if bridge != null:
				bridge.send_command_json(current, JSON.stringify(cmd))
			if drag_layer != null:
				drag_layer.clear_selection()

func _handle_local_place_stone(row: int, col: int) -> void:
	if _ko_point == Vector2i(row, col):
		_on_move_rejected("Violación de la regla de Ko")
		return

	board[row][col] = current
	var enemy: bool = P_WHITE if current == P_BLACK else P_BLACK
	var captured_coords: Array = []
	for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nr: int = row + dir.x
		var nc: int = col + dir.y
		if nr >= 0 and nr < BOARD_SIZE and nc >= 0 and nc < BOARD_SIZE:
			if board[nr][nc] == enemy:
				var gl: Dictionary = _get_group_and_liberties(nr, nc)
				if int(gl["liberties"]) == 0:
					for pos in gl["group"]:
						if not (pos in captured_coords):
							captured_coords.append(pos)

	if captured_coords.is_empty():
		var self_gl: Dictionary = _get_group_and_liberties(row, col)
		if int(self_gl["liberties"]) == 0:
			board[row][col] = null
			_on_move_rejected("Movimiento suicida no permitido")
			return

	board[row][col] = null
	_place_stone(row, col, current)
	consecutive_passes = 0

	if not captured_coords.is_empty():
		if current == P_BLACK:
			black_captured += captured_coords.size()
		else:
			white_captured += captured_coords.size()
		_ko_point = captured_coords[0] if captured_coords.size() == 1 else Vector2i(-1, -1)
		_animate_captures(captured_coords)
		_update_captured_score()
	else:
		_ko_point = Vector2i(-1, -1)

	current = P_WHITE if current == P_BLACK else P_BLACK
	_update_status()
	queue_redraw()

func _handle_local_pass() -> void:
	consecutive_passes += 1
	_ko_point = Vector2i(-1, -1)
	if consecutive_passes >= 2:
		_calculate_territory()
		var w: int = 0
		if black_score > white_score:
			w = P_BLACK
		elif white_score > black_score:
			w = P_WHITE
		_on_game_over(w)
	else:
		current = P_WHITE if current == P_BLACK else P_BLACK
		_update_status()
		queue_redraw()

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

func _get_group_and_liberties(start_r: int, start_c: int) -> Dictionary:
	var group: Array = []
	var liberties_map: Dictionary = {}
	if start_r < 0 or start_r >= BOARD_SIZE or start_c < 0 or start_c >= BOARD_SIZE:
		return {"group": group, "liberties": 0}
	var color = board[start_r][start_c]
	if color == null:
		return {"group": group, "liberties": 0}

	var visited: Dictionary = {}
	var stack: Array = [Vector2i(start_r, start_c)]
	visited[Vector2i(start_r, start_c)] = true

	while not stack.is_empty():
		var curr: Vector2i = stack.pop_back()
		group.append(curr)
		for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nr: int = curr.x + dir.x
			var nc: int = curr.y + dir.y
			if nr >= 0 and nr < BOARD_SIZE and nc >= 0 and nc < BOARD_SIZE:
				var npos: Vector2i = Vector2i(nr, nc)
				var n_stone = board[nr][nc]
				if n_stone == null:
					liberties_map[npos] = true
				elif n_stone == color and not visited.has(npos):
					visited[npos] = true
					stack.append(npos)

	return {"group": group, "liberties": liberties_map.size()}

func _remove_captured_groups_around(placed_r: int, placed_c: int, player: int) -> Array:
	var enemy: bool = P_WHITE if player == P_BLACK else P_BLACK
	var captured: Array = []
	for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nr: int = placed_r + dir.x
		var nc: int = placed_c + dir.y
		if nr >= 0 and nr < BOARD_SIZE and nc >= 0 and nc < BOARD_SIZE:
			if board[nr][nc] == enemy:
				var gl: Dictionary = _get_group_and_liberties(nr, nc)
				if int(gl["liberties"]) == 0:
					for pos in gl["group"]:
						if not (pos in captured):
							captured.append(pos)
	if not captured.is_empty():
		_animate_captures(captured)
	return captured

func _find_all_zero_liberty_groups(target_player: int) -> Array:
	var captured: Array = []
	var checked: Dictionary = {}
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var pos: Vector2i = Vector2i(r, c)
			if board[r][c] == target_player and not checked.has(pos):
				var gl: Dictionary = _get_group_and_liberties(r, c)
				for gpos in gl["group"]:
					checked[gpos] = true
				if int(gl["liberties"]) == 0:
					for gpos in gl["group"]:
						if not (gpos in captured):
							captured.append(gpos)
	return captured

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
		click_pos = get_local_mouse_position() if (is_inside_tree() and not OS.has_feature("headless")) else to_local(event.position)
		handled = true
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = to_local(event.position)
		handled = true
		
	if handled:
		var cell = _find_nearest_intersection(click_pos)
		if cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE:
			_on_cell_clicked(cell)

func _place_stone(row: int, col: int, player: int) -> void:
	if row < 0 or row >= BOARD_SIZE or col < 0 or col >= BOARD_SIZE:
		return
	if stone_nodes[row][col] != null and is_instance_valid(stone_nodes[row][col]):
		stone_nodes[row][col].queue_free()
		stone_nodes[row][col] = null

	board[row][col] = player
	last_placed_cell = Vector2i(row, col)
	
	var stone = TextureRect.new()
	stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stone_diam: float = CELL_SIZE * 0.88
	stone.custom_minimum_size = Vector2(stone_diam, stone_diam)
	stone.size = Vector2(stone_diam, stone_diam)
	stone.pivot_offset = stone.size / 2.0
	
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var is_black: bool = (player == P_BLACK)
	for x in range(64):
		for y in range(64):
			var shadow_dist = Vector2(x - 34, y - 35).length()
			var dist = Vector2(x - 32, y - 32).length()
			if dist <= 28.0:
				var light_dist = Vector2(x - 23, y - 22).length() / 36.0
				var shade = clampf(1.0 - light_dist * 0.55, 0.35, 1.0)
				if is_black:
					var v = lerpf(0.08, 0.34, shade * shade)
					img.set_pixel(x, y, Color(v, v, v + 0.02, 1.0))
				else:
					var v = lerpf(0.82, 0.99, shade)
					img.set_pixel(x, y, Color(v, v - 0.01, v - 0.03, 1.0))
			elif dist <= 29.5:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.10, 0.85))
			elif shadow_dist <= 29.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.28))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	stone.texture = ImageTexture.create_from_image(img)
	var pos = Vector2(
		col * CELL_SIZE + CELL_SIZE / 2.0 - stone.size.x / 2.0,
		row * CELL_SIZE + CELL_SIZE / 2.0 - stone.size.y / 2.0
	)
	stone.position = pos
	
	if stones_container == null:
		stones_container = Node2D.new()
		stones_container.name = "StonesContainer"
		add_child(stones_container)
	stones_container.add_child(stone)
	stone_nodes[row][col] = stone

	if is_inside_tree() and not OS.has_feature("headless"):
		stone.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(stone, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		stone.scale = Vector2.ONE
	
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

func _animate_captures(captured_coords: Array) -> void:
	if captured_coords.size() > 0 and (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place(2.0)
		
	for coord in captured_coords:
		var r: int = int(coord.x)
		var c: int = int(coord.y)
		if r < 0 or r >= BOARD_SIZE or c < 0 or c >= BOARD_SIZE:
			continue
		board[r][c] = null
		var stone = stone_nodes[r][c]
		stone_nodes[r][c] = null
		if stone != null and is_instance_valid(stone):
			if is_inside_tree() and not OS.has_feature("headless"):
				var tween = create_tween()
				tween.tween_property(stone, "modulate:a", 0.0, 0.25)
				tween.parallel().tween_property(stone, "scale", Vector2(0.1, 0.1), 0.25)
				tween.finished.connect(func():
					if is_instance_valid(stone):
						stone.queue_free()
				)
			else:
				stone.queue_free()

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = str(event.get("command_type", event.get("event_type", "")))
			if event_type.ends_with("StonePlacedEvent") or event_type == "StonePlacedEvent" or event_type == "stone_placed":
				var r = int(event.get("y", 0))
				var c = int(event.get("x", 0))
				var p = int(event.get("player", current))
				consecutive_passes = 0
				_place_stone(r, c, p)
				# Immediately detect and remove any adjacent enemy groups reduced to 0 liberties
				_remove_captured_groups_around(r, c, p)
			elif event_type.ends_with("StonesCapturedEvent") or event_type.ends_with("StonesRemovedEvent") or event_type == "StonesCapturedEvent" or event_type == "StonesRemovedEvent":
				var cap_coords: Array = []
				if event.has("coords") and event["coords"] is Array:
					for pair in event["coords"]:
						if pair is Array and pair.size() >= 2:
							cap_coords.append(Vector2i(int(pair[1]), int(pair[0])))
				elif event.has("stones") and event["stones"] is Array:
					for pair in event["stones"]:
						if pair is Array and pair.size() >= 2:
							cap_coords.append(Vector2i(int(pair[1]), int(pair[0])))
				var cap_player = int(event.get("player", current))
				var enemy: bool = P_WHITE if cap_player == P_BLACK else P_BLACK
				if cap_coords.is_empty():
					cap_coords = _find_all_zero_liberty_groups(enemy)
				var count = int(event.get("count", cap_coords.size()))
				var num_captured = max(count, cap_coords.size())
				if cap_player == P_BLACK:
					black_captured += num_captured
				else:
					white_captured += num_captured
				if not cap_coords.is_empty():
					_animate_captures(cap_coords)
				_update_captured_score()
			elif event_type.ends_with("PassedEvent") or event_type == "PassedEvent":
				consecutive_passes += 1
				if consecutive_passes >= 2 and winner == -1 and bridge != null:
					scoring_phase = true
					if scoring_phase_banner != null:
						scoring_phase_banner.visible = true
					if confirm_dead_button != null:
						confirm_dead_button.visible = true
					_update_scoring_banner()
					if OS.has_feature("headless") and auto_confirm_dead_in_headless:
						bridge.send_command_json(P_BLACK, JSON.stringify({"command_type": "go_game::ConfirmDeadCommand", "player": P_BLACK}))
						bridge.send_command_json(P_WHITE, JSON.stringify({"command_type": "go_game::ConfirmDeadCommand", "player": P_WHITE}))
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
				
	if bridge != null and not _local_oversize_hotseat:
		current = bridge.current_player()
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	if winner != -1:
		return
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

	if black_score == 0.0 and white_score == 0.0:
		black_score = float(black_territory + black_captured)
		white_score = float(white_territory + white_captured) + KOMI

func _on_move_rejected(reason: String) -> void:
	if status != null:
		status.text = "Movimiento inválido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _draw() -> void:
	var bg_col = current_theme.board_color if current_theme else COL_BOARD
	var line_col = current_theme.line_color if current_theme else COL_LINE

	# Draw wooden Goban board background with outer bevel border
	var board_rect = Rect2(0, 0, BOARD_SIZE * CELL_SIZE, BOARD_SIZE * CELL_SIZE)
	draw_rect(board_rect, bg_col)
	draw_rect(board_rect, line_col.darkened(0.2), false, 4.0)
	draw_rect(Rect2(CELL_SIZE / 2.0 - 2.0, CELL_SIZE / 2.0 - 2.0, (BOARD_SIZE - 1) * CELL_SIZE + 4.0, (BOARD_SIZE - 1) * CELL_SIZE + 4.0), line_col, false, 2.5)
	
	var font: Font = ThemeDB.fallback_font
	var letters: Array = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"]
	var coord_font_sz: int = 12 if BOARD_SIZE <= 13 else 10
	var grid_w: float = 2.0 if BOARD_SIZE <= 13 else 1.5
	# Draw grid lines intersecting at CELL_SIZE * (i + 0.5)
	for i in range(BOARD_SIZE):
		var start_h = Vector2(CELL_SIZE / 2.0, i * CELL_SIZE + CELL_SIZE / 2.0)
		var end_h = Vector2((BOARD_SIZE - 0.5) * CELL_SIZE, i * CELL_SIZE + CELL_SIZE / 2.0)
		draw_line(start_h, end_h, line_col, grid_w)
		
		var start_v = Vector2(i * CELL_SIZE + CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var end_v = Vector2(i * CELL_SIZE + CELL_SIZE / 2.0, (BOARD_SIZE - 0.5) * CELL_SIZE)
		draw_line(start_v, end_v, line_col, grid_w)
		if font != null and i < letters.size():
			draw_string(font, Vector2(i * CELL_SIZE + CELL_SIZE / 2.0 - 5.0, 14.0), letters[i], HORIZONTAL_ALIGNMENT_CENTER, 14.0, coord_font_sz, Color(line_col.r, line_col.g, line_col.b, 0.80))
			draw_string(font, Vector2(3.0, i * CELL_SIZE + CELL_SIZE / 2.0 + 4.0), str(BOARD_SIZE - i), HORIZONTAL_ALIGNMENT_LEFT, 20.0, coord_font_sz, Color(line_col.r, line_col.g, line_col.b, 0.80))
		
	# Star points (Hoshi) for Go board (9x9, 13x13, 19x19)
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
		
	var hoshi_radius = clampf(CELL_SIZE * 0.11, 3.0, 6.0)
	for hp in hoshi_points:
		var pos = Vector2(hp.y * CELL_SIZE + CELL_SIZE / 2.0, hp.x * CELL_SIZE + CELL_SIZE / 2.0)
		draw_circle(pos, hoshi_radius, Color.BLACK)

	# Territory scoring color grid overlay on game over (alpha 0.35 on empty intersections)
	if winner != -1 and territory_map.size() > 0:
		for r in range(BOARD_SIZE):
			for c in range(BOARD_SIZE):
				if board[r][c] == null:
					var terr_owner = territory_map[r][c]
					if terr_owner != null:
						var cell_pos = Vector2(c * CELL_SIZE + 4, r * CELL_SIZE + 4)
						var cell_rect = Rect2(cell_pos, Vector2(CELL_SIZE - 8, CELL_SIZE - 8))
						var t_col = Color(0.1, 0.1, 0.1, 0.35) if terr_owner == P_BLACK else Color(0.95, 0.95, 0.95, 0.35)
						draw_rect(cell_rect, t_col)

	# Marcas de piedras muertas (✕ carmesí con anillo de contraste) durante fase de conteo
	for dp in dead_stones:
		if dp.x >= 0 and dp.x < BOARD_SIZE and dp.y >= 0 and dp.y < BOARD_SIZE:
			var center_pt: Vector2 = Vector2(dp.y * CELL_SIZE + CELL_SIZE * 0.5, dp.x * CELL_SIZE + CELL_SIZE * 0.5)
			var arm: float = CELL_SIZE * 0.24
			draw_arc(center_pt, arm * 1.15, 0.0, TAU, 24, Color(0.95, 0.18, 0.18, 0.85), 2.0)
			draw_line(center_pt + Vector2(-arm, -arm), center_pt + Vector2(arm, arm), Color(0.95, 0.18, 0.18, 0.98), 3.2)
			draw_line(center_pt + Vector2(arm, -arm), center_pt + Vector2(-arm, arm), Color(0.95, 0.18, 0.18, 0.98), 3.2)


func _update_status() -> void:
	if status == null:
		return
	if winner != -1:
		status.text = "¡Fin del juego! Ganó el jugador %s (Negro: %.1f, Blanco: %.1f)" % [winner, black_score, white_score]
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var who = "Negro (1)" if current == P_BLACK else "Blanco (2)"
		var p_col = COL_BLACK_STONE if current == P_BLACK else COL_WHITE_STONE
		var pass_note: bool = " [1 Pase]" if consecutive_passes == 1 else ""
		status.text = "Turno: %s (Go %dx%d)%s" % [who, BOARD_SIZE, BOARD_SIZE, pass_note]
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

