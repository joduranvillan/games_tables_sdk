extends Node2D

const BOARD_SIZE := 10
const CELL_SIZE := 40.0
const P1 := 1
const P2 := 2
const SHIP_SPECS := [
	{"name": "Portaaviones", "size": 5, "color": Color(0.2, 0.6, 0.9)},
	{"name": "Acorazado", "size": 4, "color": Color(0.3, 0.8, 0.4)},
	{"name": "Crucero", "size": 3, "color": Color(0.8, 0.4, 0.8)},
	{"name": "Submarino", "size": 3, "color": Color(0.9, 0.7, 0.2)},
	{"name": "Destructor", "size": 2, "color": Color(0.9, 0.3, 0.3)}
]

enum Phase { PLACEMENT_P1, PLACEMENT_P2, FIRE, GAME_OVER }

var bridge
var phase: Phase = Phase.PLACEMENT_P1
var current: int = P1
var winner: int = -1
var is_vs_ai: bool = false
var local_player: int = P1
var current_screen_layout: int = 0
var current_cell_size: float = CELL_SIZE
var _last_move_rejected: bool = false

var p1_ships: Array = [] # Array of Arrays of Vector2i
var p2_ships: Array = []
var current_ship_index: int = 0
var is_horizontal: bool = true

var own_shot_grid: Array = [] # 10x10: null | "hit" | "miss" | "sunk"
var opp_shot_grid: Array = [] # 10x10: null | "hit" | "miss" | "sunk"
var sunken_cells: Array[Vector2i] = []
var opp_sunken_ships: Array = [] # Array of Arrays of Vector2i
var hovered_cell: Vector2i = Vector2i(-1, -1)

var own_grid_buttons: Array = []
var opp_grid_buttons: Array = []

var main_margin: MarginContainer
var main_vbox: VBoxContainer
var header_top_hbox: HBoxContainer
var controls_flow: HFlowContainer
var grids_container: BoxContainer
var own_vbox: VBoxContainer
var opp_vbox: VBoxContainer
var own_title_lbl: Label
var opp_title_lbl: Label
var own_grid_container: GridContainer
var opp_grid_container: GridContainer
var own_ships_layer: Control
var opp_ships_layer: Control
var status_label: Label
var phase_label: Label
var rotate_btn: Button
var auto_fleet_btn: Button
var clear_fleet_btn: Button
var btn_rules: Button
var ships_container: Control
var ship_sprites_container: Node2D

var turn_indicator: TurnIndicator
var mode_option_button: OptionButton
var network_hud: NetworkStatusHUD
var current_theme: BoardTheme
var _rules_popup: RulesPopup
var _pause_menu: CanvasLayer

func _ready() -> void:
	if main_margin != null:
		return
	if has_node("Status"):
		var legacy_status = get_node_or_null("Status")
		if legacy_status != null:
			legacy_status.visible = false
	if has_node("GridContainer"):
		var legacy_grid = get_node_or_null("GridContainer")
		if legacy_grid != null:
			legacy_grid.visible = false

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

	_init_grids()
	_setup_ui()

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

	bridge.connect("shot_result", _on_shot_result)
	bridge.connect("event_json", _on_event_json)
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)

	var gm_mode: String = str(gm.get_game_mode()) if (gm != null and gm.has_method("get_game_mode")) else "hotseat"
	var start_vs_ai: bool = (gm_mode == "vs_ai") or (not OS.has_feature("headless") and gm_mode == "hotseat")
	if start_vs_ai:
		var human_p: int = gm.get_human_player_id() if (gm != null and gm.has_method("get_human_player_id")) else P1
		var ai_p: int = P2 if human_p == P1 else P1
		var diff: int = gm.get_ai_difficulty() if (gm != null and gm.has_method("get_ai_difficulty")) else 1
		is_vs_ai = true
		local_player = human_p
		bridge.start_local_match_battleship_vs_ai(human_p, ai_p, diff)
		phase = Phase.PLACEMENT_P1 if human_p == P1 else Phase.PLACEMENT_P2
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_p == P1 else 2
	else:
		is_vs_ai = false
		local_player = P1
		bridge.start_local_match_battleship(P1, P2)
		if mode_option_button != null:
			mode_option_button.selected = 0
	current = bridge.current_player()

	_rules_popup = RulesPopup.new()
	_rules_popup.visible = false
	_rules_popup.position = Vector2(40, 60)
	add_child(_rules_popup)

	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_status()
	_update_grid_ui()
	queue_redraw()

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_viewport_size_changed() -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	var layout_mode = gm.get_layout() if gm != null else current_screen_layout
	_on_layout_changed(layout_mode)

func _on_quit_to_menu() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	_update_grid_ui()
	queue_redraw()

func _on_layout_changed(layout: int) -> void:
	current_screen_layout = layout
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	var vp_size := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz := get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)

	if main_margin != null:
		main_margin.position = Vector2.ZERO
		main_margin.size = vp_size

	var is_vertical_stack: bool = (layout == 2) or (vp_size.x < 780.0) or (vp_size.y > vp_size.x)

	if grids_container != null:
		grids_container.vertical = is_vertical_stack
		grids_container.add_theme_constant_override("separation", 10 if is_vertical_stack else 28)

	if is_vertical_stack:
		var avail_w: float = maxf(vp_size.x - 52.0, 200.0)
		var avail_h: float = maxf(vp_size.y - 165.0, 360.0)
		current_cell_size = clampf(floorf(minf(avail_w / float(BOARD_SIZE), (avail_h * 0.5) / float(BOARD_SIZE))), 20.0, 32.0)
		if status_label != null:
			status_label.add_theme_font_size_override("font_size", 14)
		if own_title_lbl != null:
			own_title_lbl.add_theme_font_size_override("font_size", 13)
		if opp_title_lbl != null:
			opp_title_lbl.add_theme_font_size_override("font_size", 13)
		if mode_option_button != null:
			mode_option_button.custom_minimum_size = Vector2(165, 30)
		if rotate_btn != null:
			rotate_btn.custom_minimum_size = Vector2(135, 30)
		if auto_fleet_btn != null:
			auto_fleet_btn.custom_minimum_size = Vector2(115, 30)
		if clear_fleet_btn != null:
			clear_fleet_btn.custom_minimum_size = Vector2(95, 30)
	else:
		var avail_w_h: float = maxf((vp_size.x - 110.0) * 0.5, 240.0)
		var avail_h_h: float = maxf(vp_size.y - 155.0, 260.0)
		current_cell_size = clampf(floorf(minf(avail_w_h / float(BOARD_SIZE), avail_h_h / float(BOARD_SIZE))), 26.0, 40.0)
		if status_label != null:
			status_label.add_theme_font_size_override("font_size", 17)
		if own_title_lbl != null:
			own_title_lbl.add_theme_font_size_override("font_size", 15)
		if opp_title_lbl != null:
			opp_title_lbl.add_theme_font_size_override("font_size", 15)
		if mode_option_button != null:
			mode_option_button.custom_minimum_size = Vector2(210, 34)
		if rotate_btn != null:
			rotate_btn.custom_minimum_size = Vector2(170, 34)
		if auto_fleet_btn != null:
			auto_fleet_btn.custom_minimum_size = Vector2(130, 34)
		if clear_fleet_btn != null:
			clear_fleet_btn.custom_minimum_size = Vector2(105, 34)

	var btn_font_sz: int = 11 if current_cell_size < 28.0 else 14
	for r in range(own_grid_buttons.size()):
		for c in range(own_grid_buttons[r].size()):
			var b_own: Button = own_grid_buttons[r][c]
			b_own.custom_minimum_size = Vector2(current_cell_size, current_cell_size)
			b_own.size = Vector2(current_cell_size, current_cell_size)
			b_own.add_theme_font_size_override("font_size", btn_font_sz)
	for r in range(opp_grid_buttons.size()):
		for c in range(opp_grid_buttons[r].size()):
			var b_opp: Button = opp_grid_buttons[r][c]
			b_opp.custom_minimum_size = Vector2(current_cell_size, current_cell_size)
			b_opp.size = Vector2(current_cell_size, current_cell_size)
			b_opp.add_theme_font_size_override("font_size", btn_font_sz)

	_refresh_ship_svg_overlays()
	queue_redraw()

func _init_grids() -> void:
	own_shot_grid = []
	opp_shot_grid = []
	for r in BOARD_SIZE:
		var r_own = []
		var r_opp = []
		for c in BOARD_SIZE:
			r_own.append(null)
			r_opp.append(null)
		own_shot_grid.append(r_own)
		opp_shot_grid.append(r_opp)

func _setup_ui() -> void:
	main_margin = MarginContainer.new()
	main_margin.name = "MainMargin"
	main_margin.position = Vector2.ZERO
	main_margin.size = Vector2(1280, 720)
	main_margin.add_theme_constant_override("margin_left", 14)
	main_margin.add_theme_constant_override("margin_right", 14)
	main_margin.add_theme_constant_override("margin_top", 8)
	main_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(main_margin)

	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	main_margin.add_child(main_vbox)

	# Row 1: Status + Turn Indicator + Rules (Rules oculto: agrupado en GameAppMenu superior derecho)
	header_top_hbox = HBoxContainer.new()
	header_top_hbox.add_theme_constant_override("separation", 10)
	header_top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header_top_hbox)

	status_label = Label.new()
	status_label.name = "BattleStatusLabel"
	status_label.text = "Batalla Naval - Colocación de flota"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_top_hbox.add_child(status_label)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.custom_minimum_size = Vector2(180, 32)
	header_top_hbox.add_child(turn_indicator)

	btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(96, 32)
	btn_rules.visible = false
	btn_rules.pressed.connect(_on_rules_pressed)
	header_top_hbox.add_child(btn_rules)

	var top_menu_spacer := Control.new()
	top_menu_spacer.name = "TopMenuSpacer"
	top_menu_spacer.custom_minimum_size = Vector2(126, 32)
	header_top_hbox.add_child(top_menu_spacer)

	# Row 2: Mode selector + Orientation + Auto-Fleet + Reset Fleet
	controls_flow = HFlowContainer.new()
	controls_flow.add_theme_constant_override("h_separation", 8)
	controls_flow.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(controls_flow)

	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.custom_minimum_size = Vector2(210, 34)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano J1)")
	mode_option_button.add_item("vs IA (Humano J2, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	controls_flow.add_child(mode_option_button)

	rotate_btn = Button.new()
	rotate_btn.name = "RotateButton"
	rotate_btn.text = "🔄 Orientación: Horizontal (R)"
	rotate_btn.tooltip_text = "Alternar colocación Horizontal / Vertical (Tecla R o Clic Derecho en el tablero)"
	rotate_btn.custom_minimum_size = Vector2(190, 34)
	rotate_btn.pressed.connect(_on_rotate_pressed)
	controls_flow.add_child(rotate_btn)

	auto_fleet_btn = Button.new()
	auto_fleet_btn.name = "AutoFleetButton"
	auto_fleet_btn.text = "🎲 Auto-Flota"
	auto_fleet_btn.tooltip_text = "Colocar automáticamente los 5 barcos con separación válida"
	auto_fleet_btn.custom_minimum_size = Vector2(130, 34)
	auto_fleet_btn.pressed.connect(_on_auto_fleet_pressed)
	controls_flow.add_child(auto_fleet_btn)

	clear_fleet_btn = Button.new()
	clear_fleet_btn.name = "ClearFleetButton"
	clear_fleet_btn.text = "🗑️ Reiniciar"
	clear_fleet_btn.tooltip_text = "Limpiar los barcos colocados y volver a empezar"
	clear_fleet_btn.custom_minimum_size = Vector2(105, 34)
	clear_fleet_btn.pressed.connect(_on_clear_fleet_pressed)
	controls_flow.add_child(clear_fleet_btn)

	# Two Grids Container (Horizontal on Desktop/Landscape, Vertical on Mobile/Portrait)
	grids_container = BoxContainer.new()
	grids_container.name = "GridsContainer"
	grids_container.vertical = false
	grids_container.add_theme_constant_override("separation", 28)
	grids_container.alignment = BoxContainer.ALIGNMENT_CENTER
	grids_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grids_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(grids_container)

	# --- Panel 1: Own Grid (Mi Flota) ---
	own_vbox = VBoxContainer.new()
	own_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grids_container.add_child(own_vbox)

	own_title_lbl = Label.new()
	own_title_lbl.text = "🛡️ Mi Flota (Tablero Propio)"
	own_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	own_title_lbl.add_theme_font_size_override("font_size", 15)
	own_vbox.add_child(own_title_lbl)

	var own_margin = MarginContainer.new()
	own_margin.add_theme_constant_override("margin_left", 20)
	own_margin.add_theme_constant_override("margin_top", 18)
	own_vbox.add_child(own_margin)

	own_grid_container = GridContainer.new()
	own_grid_container.columns = BOARD_SIZE
	own_grid_container.add_theme_constant_override("h_separation", 0)
	own_grid_container.add_theme_constant_override("v_separation", 0)
	own_grid_container.resized.connect(func():
		_refresh_ship_svg_overlays()
		queue_redraw()
	)
	own_margin.add_child(own_grid_container)

	own_ships_layer = Control.new()
	own_ships_layer.name = "OwnShipsLayer"
	own_ships_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own_margin.add_child(own_ships_layer)

	own_grid_buttons = []
	for r in BOARD_SIZE:
		var row_btns = []
		for c in BOARD_SIZE:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			btn.text = "~"
			btn.pressed.connect(_on_own_cell_pressed.bind(r, c))
			btn.gui_input.connect(_on_own_cell_gui_input.bind(r, c))
			btn.mouse_entered.connect(_on_own_cell_mouse_entered.bind(r, c))
			btn.mouse_exited.connect(_on_own_cell_mouse_exited.bind(r, c))
			own_grid_container.add_child(btn)
			row_btns.append(btn)
		own_grid_buttons.append(row_btns)

	# --- Panel 2: Opponent Grid (Radar) ---
	opp_vbox = VBoxContainer.new()
	opp_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grids_container.add_child(opp_vbox)

	opp_title_lbl = Label.new()
	opp_title_lbl.text = "🎯 Radar (Flota Enemiga)"
	opp_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opp_title_lbl.add_theme_font_size_override("font_size", 15)
	opp_vbox.add_child(opp_title_lbl)

	var opp_margin = MarginContainer.new()
	opp_margin.add_theme_constant_override("margin_left", 20)
	opp_margin.add_theme_constant_override("margin_top", 18)
	opp_vbox.add_child(opp_margin)

	opp_grid_container = GridContainer.new()
	opp_grid_container.columns = BOARD_SIZE
	opp_grid_container.add_theme_constant_override("h_separation", 0)
	opp_grid_container.add_theme_constant_override("v_separation", 0)
	opp_grid_container.resized.connect(func():
		_refresh_ship_svg_overlays()
		queue_redraw()
	)
	opp_margin.add_child(opp_grid_container)

	opp_ships_layer = Control.new()
	opp_ships_layer.name = "OppShipsLayer"
	opp_ships_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_margin.add_child(opp_ships_layer)

	opp_grid_buttons = []
	for r in BOARD_SIZE:
		var row_btns = []
		for c in BOARD_SIZE:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			btn.text = "~"
			btn.pressed.connect(_on_opp_cell_pressed.bind(r, c))
			opp_grid_container.add_child(btn)
			row_btns.append(btn)
		opp_grid_buttons.append(row_btns)

	# Container for animated ship textures
	ship_sprites_container = Node2D.new()
	ship_sprites_container.name = "ShipSpritesContainer"
	add_child(ship_sprites_container)

func _on_rules_pressed() -> void:
	if _rules_popup != null:
		_rules_popup.show_for_game("battleship")

func _input(event: InputEvent) -> void:
	if phase != Phase.PLACEMENT_P1 and phase != Phase.PLACEMENT_P2:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_on_rotate_pressed()
		get_viewport().set_input_as_handled()

func _on_own_cell_gui_input(event: InputEvent, row: int, col: int) -> void:
	if phase != Phase.PLACEMENT_P1 and phase != Phase.PLACEMENT_P2:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		hovered_cell = Vector2i(row, col)
		_on_rotate_pressed()

func _on_own_cell_mouse_entered(row: int, col: int) -> void:
	hovered_cell = Vector2i(row, col)
	if phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2:
		_update_grid_ui()

func _on_own_cell_mouse_exited(row: int, col: int) -> void:
	if hovered_cell == Vector2i(row, col):
		hovered_cell = Vector2i(-1, -1)
		if phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2:
			_update_grid_ui()

func _on_mode_selected(index: int) -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	winner = -1
	p1_ships.clear()
	p2_ships.clear()
	sunken_cells.clear()
	opp_sunken_ships.clear()
	current_ship_index = 0
	_last_move_rejected = false
	_init_grids()
	if bridge != null:
		match index:
			1:
				is_vs_ai = true
				local_player = P1
				phase = Phase.PLACEMENT_P1
				if gm != null and gm.has_method("set_game_mode"):
					gm.set_game_mode("vs_ai")
				if gm != null and gm.has_method("set_human_player_id"):
					gm.set_human_player_id(P1)
				bridge.start_local_match_battleship_vs_ai(P1, P2, 1)
			2:
				is_vs_ai = true
				local_player = P2
				phase = Phase.PLACEMENT_P2
				if gm != null and gm.has_method("set_game_mode"):
					gm.set_game_mode("vs_ai")
				if gm != null and gm.has_method("set_human_player_id"):
					gm.set_human_player_id(P2)
				bridge.start_local_match_battleship_vs_ai(P2, P1, 1)
			_:
				is_vs_ai = false
				local_player = P1
				phase = Phase.PLACEMENT_P1
				if gm != null and gm.has_method("set_game_mode"):
					gm.set_game_mode("local")
				bridge.start_local_match_battleship(P1, P2)
	current = bridge.current_player() if bridge else P1
	_update_status()
	_update_grid_ui()
	queue_redraw()

func _draw() -> void:
	var font: Font = null
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			var th = tm.get_current_theme() if tm.has_method("get_current_theme") else tm.get_theme()
			if th != null and th.piece_font != null:
				font = th.piece_font
	if font == null:
		font = ThemeDB.fallback_font

	var font_sz := 11 if current_cell_size < 28.0 else 13
	var coord_color := Color(0.85, 0.85, 0.9, 0.9)

	_draw_grid_coordinates(own_grid_buttons, font, font_sz, coord_color)
	_draw_grid_coordinates(opp_grid_buttons, font, font_sz, coord_color)

func _draw_grid_coordinates(grid_buttons: Array, font: Font, font_sz: int, coord_color: Color) -> void:
	if grid_buttons.is_empty() or grid_buttons[0].is_empty():
		return

	# Números 1–10 en la fila superior (columnas 0..9)
	for c in range(BOARD_SIZE):
		var btn: Button = grid_buttons[0][c]
		if btn != null and btn.is_inside_tree():
			var b_pos = to_local(btn.global_position)
			var num_str = str(c + 1)
			draw_string(font, Vector2(b_pos.x, b_pos.y - 4), num_str, HORIZONTAL_ALIGNMENT_CENTER, current_cell_size, font_sz, coord_color)

	# Letras A–J en la columna izquierda (filas 0..9)
	for r in range(BOARD_SIZE):
		var btn: Button = grid_buttons[r][0]
		if btn != null and btn.is_inside_tree():
			var b_pos = to_local(btn.global_position)
			var letter = String.chr("A".unicode_at(0) + r)
			draw_string(font, Vector2(b_pos.x - 18, b_pos.y + current_cell_size * 0.68), letter, HORIZONTAL_ALIGNMENT_CENTER, 16, font_sz, coord_color)

func _on_rotate_pressed() -> void:
	is_horizontal = not is_horizontal
	if rotate_btn != null:
		rotate_btn.text = "🔄 Orientación: " + ("Horizontal (R)" if is_horizontal else "Vertical (R)")
	_update_status()
	_update_grid_ui()

func _on_clear_fleet_pressed() -> void:
	if phase != Phase.PLACEMENT_P1 and phase != Phase.PLACEMENT_P2:
		return
	var target_ships := p1_ships if phase == Phase.PLACEMENT_P1 else p2_ships
	target_ships.clear()
	current_ship_index = 0
	_last_move_rejected = false
	_update_status()
	_update_grid_ui()
	queue_redraw()

func _on_auto_fleet_pressed() -> void:
	if phase != Phase.PLACEMENT_P1 and phase != Phase.PLACEMENT_P2:
		return
	var target_ships := p1_ships if phase == Phase.PLACEMENT_P1 else p2_ships
	target_ships.clear()

	var generated := _generate_valid_random_fleet()
	for ship in generated:
		target_ships.append(ship)
	current_ship_index = SHIP_SPECS.size()

	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

	_submit_fleet_for_active_player()

func _generate_valid_random_fleet() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for _attempt in range(200):
		var candidate_ships: Array = []
		var all_placed := true
		for spec in SHIP_SPECS:
			var ship_len: int = int(spec["size"])
			var placed_this := false
			for _try_pos in range(120):
				var horiz: bool = (rng.randi_range(0, 1) == 0)
				var max_r: int = BOARD_SIZE - (1 if horiz else ship_len)
				var max_c: int = BOARD_SIZE - (ship_len if horiz else 1)
				var sr: int = rng.randi_range(0, max_r)
				var sc: int = rng.randi_range(0, max_c)
				var cells: Array[Vector2i] = []
				var valid := true
				for i in range(ship_len):
					var r: int = sr + (0 if horiz else i)
					var c: int = sc + (i if horiz else 0)
					var pos := Vector2i(r, c)
					if _is_cell_occupied_in_ships(pos, candidate_ships) or _is_cell_adjacent_to_ships(pos, candidate_ships):
						valid = false
						break
					cells.append(pos)
				if valid:
					candidate_ships.append(cells)
					placed_this = true
					break
			if not placed_this:
				all_placed = false
				break
		if all_placed and candidate_ships.size() == SHIP_SPECS.size():
			return candidate_ships

	# Fallback determinista garantizado con separación de 1 fila entre cada barco
	var fallback: Array = []
	var rows := [0, 2, 4, 6, 8]
	for idx in range(SHIP_SPECS.size()):
		var s_len: int = int(SHIP_SPECS[idx]["size"])
		var r_idx: int = rows[idx]
		var ship_cells: Array[Vector2i] = []
		for c_idx in range(s_len):
			ship_cells.append(Vector2i(r_idx, c_idx))
		fallback.append(ship_cells)
	return fallback

func _on_own_cell_pressed(row: int, col: int) -> void:
	if phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2:
		_handle_placement(row, col)

func _on_opp_cell_pressed(row: int, col: int) -> void:
	if phase == Phase.FIRE and winner == -1:
		_handle_fire_click(row, col)

func _resolve_placement_origin(start_row: int, start_col: int, ship_size: int, horizontal: bool) -> Vector2i:
	var r := start_row
	var c := start_col
	if r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE:
		if horizontal:
			c = mini(c, BOARD_SIZE - ship_size)
		else:
			r = mini(r, BOARD_SIZE - ship_size)
	return Vector2i(r, c)

func _handle_placement(start_row: int, start_col: int) -> void:
	if current_ship_index >= SHIP_SPECS.size():
		return

	var spec = SHIP_SPECS[current_ship_index]
	var ship_size: int = spec["size"]
	var target_ships := p1_ships if phase == Phase.PLACEMENT_P1 else p2_ships
	var clamped_origin := _resolve_placement_origin(start_row, start_col, ship_size, is_horizontal)
	var base_row := clamped_origin.x
	var base_col := clamped_origin.y
	var ship_cells: Array[Vector2i] = []

	for i in range(ship_size):
		var r = base_row + (0 if is_horizontal else i)
		var c = base_col + (i if is_horizontal else 0)
		if r < 0 or r >= BOARD_SIZE or c < 0 or c >= BOARD_SIZE:
			if status_label != null:
				status_label.text = "❌ ¡El barco no cabe ahí! Prueba otra casilla o cambia la orientación."
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_error_buzz()
			return

		var pos = Vector2i(r, c)
		if _is_cell_occupied_in_ships(pos, target_ships):
			if status_label != null:
				status_label.text = "❌ ¡Casilla ocupada por otro barco!"
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_error_buzz()
			return
		if _is_cell_adjacent_to_ships(pos, target_ships):
			if status_label != null:
				status_label.text = "⚠️ Los barcos no pueden tocarse (deja 1 casilla de separación o usa 🎲 Auto-Flota)."
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_error_buzz()
			return
		ship_cells.append(pos)

	target_ships.append(ship_cells)
	current_ship_index += 1

	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

	if current_ship_index >= SHIP_SPECS.size():
		_submit_fleet_for_active_player()
		return

	_update_status()
	_update_grid_ui()
	queue_redraw()

func _submit_fleet_for_active_player() -> void:
	var active_player := P1 if phase == Phase.PLACEMENT_P1 else P2
	var target_ships := p1_ships if phase == Phase.PLACEMENT_P1 else p2_ships
	var formatted_ships = []
	for ship in target_ships:
		var ship_dict = []
		for cell_pos in ship:
			ship_dict.append({"row": cell_pos.x, "col": cell_pos.y})
		formatted_ships.append(ship_dict)

	var place_cmd = {
		"command_type": "PlaceFleetCommand",
		"player": active_player,
		"ships": formatted_ships
	}
	_last_move_rejected = false
	if bridge != null:
		bridge.send_command_json(active_player, JSON.stringify(place_cmd))

	if _last_move_rejected:
		if not target_ships.is_empty():
			target_ships.pop_back()
		current_ship_index = target_ships.size()
		_update_grid_ui()
		queue_redraw()
		return

	# Garantizar transición inmediata de fase si el comando fue aceptado
	if phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2:
		if is_vs_ai:
			phase = Phase.FIRE
		elif active_player == P1 and phase == Phase.PLACEMENT_P1:
			phase = Phase.PLACEMENT_P2
			current_ship_index = 0
		elif active_player == P2 and phase == Phase.PLACEMENT_P2:
			phase = Phase.FIRE

	if bridge != null:
		current = bridge.current_player()
	_update_status()
	_update_grid_ui()
	queue_redraw()

func _is_cell_occupied_in_ships(cell: Vector2i, ships: Array) -> bool:
	for ship in ships:
		for pos in ship:
			if pos == cell:
				return true
	return false

func _is_cell_adjacent_to_ships(cell: Vector2i, ships: Array) -> bool:
	for ship in ships:
		for pos in ship:
			if absi(pos.x - cell.x) <= 1 and absi(pos.y - cell.y) <= 1:
				return true
	return false

func _handle_fire_click(row: int, col: int) -> void:
	if row < opp_shot_grid.size() and col < opp_shot_grid[row].size() and opp_shot_grid[row][col] != null:
		if status_label != null:
			status_label.text = "⚠️ Ya disparaste en esa casilla (%s%d)" % [String.chr("A".unicode_at(0) + row), col + 1]
		return

	var shooter: int = local_player if is_vs_ai else current
	var fire_cmd = {
		"command_type": "FireShotCommand",
		"player": shooter,
		"target": {"row": row, "col": col}
	}
	_last_move_rejected = false
	bridge.send_command_json(shooter, JSON.stringify(fire_cmd))

func _spawn_shot_animation(player: int, row: int, col: int, is_hit: bool) -> void:
	if OS.has_feature("headless"):
		return

	var my_player := local_player if is_vs_ai else P1
	var is_opp_target = (player == my_player)
	var btn: Button = null
	if is_opp_target and row < opp_grid_buttons.size() and col < opp_grid_buttons[row].size():
		btn = opp_grid_buttons[row][col]
	elif not is_opp_target and row < own_grid_buttons.size() and col < own_grid_buttons[row].size():
		btn = own_grid_buttons[row][col]

	if btn == null or not btn.is_inside_tree():
		return

	var center_pos = btn.global_position + Vector2(btn.size.x / 2.0, btn.size.y / 2.0)
	var local_pos = to_local(center_pos)

	var explosion_tex: Texture2D = null
	var explosion_tex_path := "res://assets/explosion.png"
	if ResourceLoader.exists(explosion_tex_path + ".import"):
		explosion_tex = load(explosion_tex_path) as Texture2D
	else:
		var abs_exp := ProjectSettings.globalize_path(explosion_tex_path)
		if FileAccess.file_exists(abs_exp):
			var img := Image.load_from_file(abs_exp)
			if img != null and not img.is_empty():
				explosion_tex = ImageTexture.create_from_image(img)

	if explosion_tex != null:
		var sprite = Sprite2D.new()
		sprite.texture = explosion_tex
		sprite.position = local_pos
		sprite.scale = Vector2(0.2, 0.2)
		sprite.z_index = 20
		add_child(sprite)
		var tw = sprite.create_tween().set_parallel(true)
		tw.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.35).set_delay(0.15)
		tw.chain().tween_callback(sprite.queue_free)
	else:
		var particles = CPUParticles2D.new()
		particles.position = local_pos
		particles.emitting = true
		particles.one_shot = true
		particles.amount = 16
		particles.lifetime = 0.5
		particles.explosiveness = 0.8
		particles.direction = Vector2(0, -1)
		particles.spread = 180.0
		particles.gravity = Vector2(0, 200)
		particles.initial_velocity_min = 80.0
		particles.initial_velocity_max = 160.0
		particles.scale_amount_min = 3.0
		particles.scale_amount_max = 6.0
		particles.color = Color(1.0, 0.2, 0.2) if is_hit else Color(0.3, 0.7, 1.0)
		particles.z_index = 20
		add_child(particles)

		var pulse_circle = Node2D.new()
		pulse_circle.position = local_pos
		pulse_circle.z_index = 19
		var circle_col = Color(1.0, 0.15, 0.15, 0.85) if is_hit else Color(0.2, 0.6, 1.0, 0.85)
		pulse_circle.draw.connect(func():
			pulse_circle.draw_circle(Vector2.ZERO, current_cell_size * 0.45, circle_col)
		)
		add_child(pulse_circle)
		pulse_circle.queue_redraw()
		var tw_circle = pulse_circle.create_tween().set_parallel(true)
		tw_circle.tween_property(pulse_circle, "scale", Vector2(1.4, 1.4), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_circle.tween_property(pulse_circle, "modulate:a", 0.0, 0.3)
		tw_circle.chain().tween_callback(pulse_circle.queue_free)

		var timer = get_tree().create_timer(0.6)
		timer.timeout.connect(particles.queue_free)

func _on_shot_result(player: int, row: int, col: int, is_hit: bool) -> void:
	var my_player := local_player if is_vs_ai else P1
	if player == my_player:
		opp_shot_grid[row][col] = "hit" if is_hit else "miss"
	else:
		own_shot_grid[row][col] = "hit" if is_hit else "miss"

	_spawn_shot_animation(player, row, col, is_hit)

	if is_hit:
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_piece_place(2.0)
	else:
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_piece_place()

	_update_grid_ui()
	queue_redraw()

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type: String = str(event.get("event_type", event.get("command_type", "")))
			var ev_type: String = raw_type.split("::")[-1]
			if ev_type == "FleetPlacedEvent":
				var player_id = int(event.get("player", 1))
				if is_vs_ai:
					if player_id == local_player:
						phase = Phase.FIRE
				else:
					if player_id == P1:
						phase = Phase.PLACEMENT_P2
						current_ship_index = 0
					elif player_id == P2:
						phase = Phase.FIRE
			elif ev_type == "ShotResultEvent":
				var target = event.get("target", {})
				var r = int(target.get("row", 0))
				var c = int(target.get("col", 0))
				var res_str: String = event.get("result", "")
				var is_hit = (res_str == "Hit" or res_str == "Sunk")
				var shooting_player = int(event.get("player", event.get("shooter", current)))
				var my_player := local_player if is_vs_ai else P1
				if shooting_player == my_player:
					opp_shot_grid[r][c] = "sunk" if res_str == "Sunk" else ("hit" if is_hit else "miss")
				else:
					own_shot_grid[r][c] = "sunk" if res_str == "Sunk" else ("hit" if is_hit else "miss")

				_spawn_shot_animation(shooting_player, r, c, is_hit)

				if res_str == "Sunk" and event.has("sunken_ship"):
					var sunk_coords = event["sunken_ship"]
					var sunk_ship_cells: Array[Vector2i] = []
					for coord in sunk_coords:
						var sr = int(coord.get("row", 0))
						var sc = int(coord.get("col", 0))
						var spos = Vector2i(sr, sc)
						sunk_ship_cells.append(spos)
						if not spos in sunken_cells:
							sunken_cells.append(spos)
					if shooting_player == my_player and not sunk_ship_cells.is_empty():
						opp_sunken_ships.append(sunk_ship_cells)
			elif ev_type == "SunkenShipEvent" or ev_type == "SunkShipEvent":
				var sunk_ship_cells2: Array[Vector2i] = []
				if event.has("positions"):
					for pos_obj in event["positions"]:
						var sr = int(pos_obj.get("row", 0)) if pos_obj is Dictionary else int(pos_obj[0])
						var sc = int(pos_obj.get("col", 0)) if pos_obj is Dictionary else int(pos_obj[1])
						var spos = Vector2i(sr, sc)
						sunk_ship_cells2.append(spos)
						if not spos in sunken_cells:
							sunken_cells.append(spos)
				elif event.has("coords"):
					for pair in event["coords"]:
						var sr = int(pair[0]) if pair is Array else int(pair.get("row", 0))
						var sc = int(pair[1]) if pair is Array else int(pair.get("col", 0))
						var spos = Vector2i(sr, sc)
						sunk_ship_cells2.append(spos)
						if not spos in sunken_cells:
							sunken_cells.append(spos)
				if not sunk_ship_cells2.is_empty():
					opp_sunken_ships.append(sunk_ship_cells2)
			elif ev_type == "GameOverEvent":
				winner = int(event.get("winner", -1))
				phase = Phase.GAME_OVER

	current = bridge.current_player()
	_update_status()
	_update_grid_ui()
	queue_redraw()

func _on_game_over(w: int) -> void:
	winner = w
	phase = Phase.GAME_OVER
	_update_status()
	_update_grid_ui()
	queue_redraw()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	_last_move_rejected = true
	if status_label != null:
		status_label.text = "⚠️ Acción inválida: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _update_status() -> void:
	var in_placement := (phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2)
	if rotate_btn != null:
		rotate_btn.disabled = not in_placement
	if auto_fleet_btn != null:
		auto_fleet_btn.disabled = not in_placement
	if clear_fleet_btn != null:
		clear_fleet_btn.disabled = not in_placement

	var orient_txt := "Horizontal ↔" if is_horizontal else "Vertical ↕"
	if winner != -1 or phase == Phase.GAME_OVER:
		if status_label != null:
			status_label.text = "🏆 ¡Fin del juego! Ganó el Jugador %d" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 0.4)
	elif phase == Phase.PLACEMENT_P1:
		var spec = SHIP_SPECS[current_ship_index] if current_ship_index < SHIP_SPECS.size() else null
		if status_label != null:
			if spec:
				status_label.text = "⚓ J1: Coloca %s (%d casillas, %s) [%d/%d] — R/Clic Der. rota" % [
					spec["name"], spec["size"], orient_txt, current_ship_index + 1, SHIP_SPECS.size()
				]
			else:
				status_label.text = "⚓ Jugador 1: Flota lista."
		if turn_indicator != null:
			var p_col = get_node("/root/GameManager").get_player_color(P1) if (is_inside_tree() and has_node("/root/GameManager")) else Color(0.2, 0.6, 0.9)
			turn_indicator.set_turn(P1, "Jugador 1", p_col)
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif phase == Phase.PLACEMENT_P2:
		var spec = SHIP_SPECS[current_ship_index] if current_ship_index < SHIP_SPECS.size() else null
		if status_label != null:
			if spec:
				status_label.text = "⚓ J2: Coloca %s (%d casillas, %s) [%d/%d] — R/Clic Der. rota" % [
					spec["name"], spec["size"], orient_txt, current_ship_index + 1, SHIP_SPECS.size()
				]
			else:
				status_label.text = "⚓ Jugador 2: Flota lista."
		if turn_indicator != null:
			var p_col = get_node("/root/GameManager").get_player_color(P2) if (is_inside_tree() and has_node("/root/GameManager")) else Color(0.9, 0.3, 0.3)
			turn_indicator.set_turn(P2, "Jugador 2", p_col)
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif phase == Phase.FIRE:
		var p_name = "Jugador 1" if current == P1 else ("IA (J2)" if is_vs_ai and local_player == P1 else "Jugador 2")
		if status_label != null:
			status_label.text = "🎯 Fase de Combate — Turno de %s: Dispara en el Radar" % p_name
		if turn_indicator != null:
			var p_col = get_node("/root/GameManager").get_player_color(current) if (is_inside_tree() and has_node("/root/GameManager")) else (Color(0.2, 0.6, 0.9) if current == P1 else Color(0.9, 0.3, 0.3))
			turn_indicator.set_turn(current, p_name, p_col)
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Resaltar el tablero donde el jugador debe interactuar en cada fase
	if own_vbox != null:
		own_vbox.modulate = Color(1.0, 1.0, 1.0, 1.0) if in_placement else Color(1.0, 1.0, 1.0, 0.85)
	if opp_vbox != null:
		opp_vbox.modulate = Color(1.0, 1.0, 1.0, 1.0) if phase == Phase.FIRE else Color(1.0, 1.0, 1.0, 0.65)

func _get_hover_preview_info(active_ships: Array) -> Dictionary:
	var result := {"cells": [], "valid": true}
	var in_placement := (phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2)
	if not in_placement or current_ship_index >= SHIP_SPECS.size():
		return result
	if hovered_cell.x < 0 or hovered_cell.x >= BOARD_SIZE or hovered_cell.y < 0 or hovered_cell.y >= BOARD_SIZE:
		return result

	var ship_size: int = int(SHIP_SPECS[current_ship_index]["size"])
	var origin := _resolve_placement_origin(hovered_cell.x, hovered_cell.y, ship_size, is_horizontal)
	var cells: Array[Vector2i] = []
	var is_valid := true
	for i in range(ship_size):
		var r: int = origin.x + (0 if is_horizontal else i)
		var c: int = origin.y + (i if is_horizontal else 0)
		if r < 0 or r >= BOARD_SIZE or c < 0 or c >= BOARD_SIZE:
			is_valid = false
			continue
		var pos := Vector2i(r, c)
		if _is_cell_occupied_in_ships(pos, active_ships) or _is_cell_adjacent_to_ships(pos, active_ships):
			is_valid = false
		cells.append(pos)
	result["cells"] = cells
	result["valid"] = is_valid
	return result

func _update_grid_ui() -> void:
	if own_grid_buttons.is_empty() or opp_grid_buttons.is_empty() or own_shot_grid.is_empty() or opp_shot_grid.is_empty():
		return
	var active_ships = p2_ships if (phase == Phase.PLACEMENT_P2 or (is_vs_ai and local_player == P2)) else p1_ships
	var in_placement := (phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2)
	var preview_info := _get_hover_preview_info(active_ships)
	var preview_cells: Array = preview_info["cells"]
	var preview_valid: bool = bool(preview_info["valid"])

	# Update Own Grid UI
	for r in BOARD_SIZE:
		for c in BOARD_SIZE:
			var btn: Button = own_grid_buttons[r][c]
			var pos = Vector2i(r, c)
			var shot = own_shot_grid[r][c]
			var in_preview := pos in preview_cells

			if shot == "sunk" or pos in sunken_cells:
				btn.text = "⚓"
				btn.modulate = Color(0.45, 0.45, 0.5, 0.9)
			elif shot == "hit":
				btn.text = "💥"
				btn.modulate = Color(1.0, 0.25, 0.25)
			elif shot == "miss":
				btn.text = "💧"
				btn.modulate = Color(0.3, 0.7, 1.0)
			elif _is_cell_occupied_in_ships(pos, active_ships):
				# Texto vacío para dejar visible la silueta cenital SVG del barco sobre las casillas
				btn.text = ""
				btn.modulate = Color(0.22, 0.48, 0.65, 0.92) if not in_preview else Color(0.95, 0.35, 0.35, 0.95)
			elif in_preview:
				btn.text = "▭" if is_horizontal else "▮"
				btn.modulate = Color(0.35, 0.95, 0.55, 0.95) if preview_valid else Color(1.0, 0.35, 0.35, 0.95)
			elif in_placement and _is_cell_adjacent_to_ships(pos, active_ships):
				btn.text = "·"
				btn.modulate = Color(0.55, 0.65, 0.78, 0.75)
			else:
				btn.text = "~"
				btn.modulate = Color.WHITE

	# Update Opponent Radar Grid UI
	for r in BOARD_SIZE:
		for c in BOARD_SIZE:
			var btn: Button = opp_grid_buttons[r][c]
			var pos = Vector2i(r, c)
			var shot = opp_shot_grid[r][c]

			if shot == "sunk" or pos in sunken_cells:
				btn.text = "⚓"
				btn.modulate = Color(0.45, 0.45, 0.5, 0.88)
				btn.disabled = true
			elif shot == "hit":
				btn.text = "💥"
				btn.modulate = Color(1.0, 0.2, 0.2)
				btn.disabled = true
			elif shot == "miss":
				btn.text = "💧"
				btn.modulate = Color(0.3, 0.7, 1.0)
				btn.disabled = true
			else:
				btn.text = "~"
				btn.modulate = Color.WHITE
				btn.disabled = (phase != Phase.FIRE or winner != -1)

	_refresh_ship_svg_overlays()

func _build_ship_svg(ship_index: int, ship_size: int, horizontal: bool, cell_px: float, is_sunk: bool = false) -> String:
	var length_px: float = maxf(float(ship_size) * cell_px, 32.0)
	var breadth_px: float = maxf(cell_px, 20.0)
	var svg_w: int = int(round(length_px if horizontal else breadth_px))
	var svg_h: int = int(round(breadth_px if horizontal else length_px))

	var hull_fill := "#3b2323" if is_sunk else "#2b3b4b"
	var hull_stroke := "#ff5555" if is_sunk else "#8fb4d4"
	var deck_fill := "#4d2f2f" if is_sunk else "#445b73"
	var bridge_fill := "#633b3b" if is_sunk else "#6a88a6"
	var turret_fill := "#291818" if is_sunk else "#1c2733"

	if not is_sunk and ship_index >= 0 and ship_index < SHIP_SPECS.size():
		var c: Color = SHIP_SPECS[ship_index]["color"]
		hull_stroke = "#%02x%02x%02x" % [int(clampf(c.r * 255.0, 0, 255)), int(clampf(c.g * 255.0, 0, 255)), int(clampf(c.b * 255.0, 0, 255))]

	var L: float = length_px
	var B: float = breadth_px
	var cy: float = B * 0.5
	var pad: float = maxf(B * 0.14, 3.0)
	var top_y: float = pad
	var bot_y: float = B - pad
	var stern_x: float = pad * 1.1
	var bow_tip_x: float = L - pad * 0.9
	var bow_shoulder_x: float = L - B * 0.65

	var inner := ""
	if ship_index == 3:
		# Submarino (casco elíptico fusiforme + vela central + hidroplanos)
		var rx: float = (L - pad * 2.0) * 0.5
		var ry: float = (B - pad * 2.4) * 0.5
		var cx: float = L * 0.5
		inner += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" stroke-width="2"/>' % [cx, cy, rx, ry, hull_fill, hull_stroke]
		inner += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % [cx, cy, rx * 0.72, ry * 0.55, deck_fill]
		inner += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" stroke-width="1.2"/>' % [cx + rx * 0.12, cy, rx * 0.22, ry * 0.48, bridge_fill, hull_stroke]
		inner += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.5"/>' % [stern_x, cy, bow_tip_x - 4.0, cy, hull_stroke]
	elif ship_index == 0:
		# Portaaviones (cubierta de vuelo angulada + pista punteada + isla a estribor)
		inner += '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" stroke="%s" stroke-width="2"/>' % [
			stern_x, top_y + 2.0,
			bow_shoulder_x, top_y,
			bow_tip_x, cy,
			bow_shoulder_x, bot_y,
			stern_x + 4.0, bot_y,
			stern_x, bot_y - 3.0,
			hull_fill, hull_stroke
		]
		inner += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#e8f0f8" stroke-width="1.6" stroke-dasharray="6,4"/>' % [
			stern_x + 8.0, cy + 2.0, bow_shoulder_x - 4.0, cy - 2.0
		]
		inner += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="2" fill="%s" stroke="%s" stroke-width="1.2"/>' % [
			L * 0.38, top_y + 2.0, L * 0.22, B * 0.24, bridge_fill, hull_stroke
		]
	else:
		# Acorazado, Crucero, Destructor (casco naval cenital en punta de proa + cubierta + puente + torretas)
		inner += '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" stroke="%s" stroke-width="2"/>' % [
			stern_x, top_y + 1.0,
			bow_shoulder_x, top_y + 1.0,
			bow_tip_x, cy,
			bow_shoulder_x, bot_y - 1.0,
			stern_x, bot_y - 1.0,
			hull_fill, hull_stroke
		]
		inner += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="%s"/>' % [
			stern_x + 6.0, top_y + 4.0, maxf(bow_shoulder_x - stern_x - 10.0, 12.0), maxf(B - pad * 2.0 - 8.0, 6.0), deck_fill
		]
		# Superestructura / Puente central
		var bridge_w: float = L * 0.22
		var bridge_h: float = (B - pad * 2.0) * 0.52
		inner += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="%s" stroke="%s" stroke-width="1"/>' % [
			L * 0.42, cy - bridge_h * 0.5, bridge_w, bridge_h, bridge_fill, hull_stroke
		]
		# Torretas de artillería en proa y popa
		var turret_r: float = maxf(B * 0.14, 3.2)
		var fore_x: float = L * 0.74
		var aft_x: float = L * 0.24
		inner += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1.2"/>' % [fore_x, cy, turret_r, turret_fill, hull_stroke]
		inner += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"/>' % [fore_x, cy - 1.5, fore_x + turret_r * 1.9, cy - 1.5, hull_stroke]
		inner += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"/>' % [fore_x, cy + 1.5, fore_x + turret_r * 1.9, cy + 1.5, hull_stroke]
		if ship_size >= 3:
			inner += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1.2"/>' % [aft_x, cy, turret_r, turret_fill, hull_stroke]
			inner += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"/>' % [aft_x, cy, aft_x - turret_r * 1.8, cy, hull_stroke]

	var group_transform := "" if horizontal else ('transform="translate(%.1f, 0) rotate(90)"' % breadth_px)
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><g %s>%s</g></svg>' % [
		svg_w, svg_h, svg_w, svg_h, group_transform, inner
	]

func _create_ship_visual_node(ship_cells: Array, ship_idx: int, is_sunk: bool) -> Control:
	if ship_cells.is_empty():
		return null
	var min_r: int = 999
	var max_r: int = -999
	var min_c: int = 999
	var max_c: int = -999
	for cell in ship_cells:
		var pos: Vector2i = cell
		min_r = mini(min_r, pos.x)
		max_r = maxi(max_r, pos.x)
		min_c = mini(min_c, pos.y)
		max_c = maxi(max_c, pos.y)

	var ship_size: int = ship_cells.size()
	var horizontal: bool = (min_r == max_r)
	var w_cells: int = maxi(max_c - min_c + 1, 1)
	var h_cells: int = maxi(max_r - min_r + 1, 1)
	var box_size := Vector2(float(w_cells) * current_cell_size, float(h_cells) * current_cell_size)

	var holder := Control.new()
	holder.name = "ShipSVG_%d" % ship_idx
	holder.position = Vector2(float(min_c) * current_cell_size, float(min_r) * current_cell_size)
	holder.size = box_size
	holder.custom_minimum_size = box_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var svg_str := _build_ship_svg(ship_idx, ship_size, horizontal, current_cell_size, is_sunk)
	holder.set_meta("svg_source", svg_str)
	holder.set_meta("is_horizontal", horizontal)
	holder.set_meta("ship_size", ship_size)

	var rasterized_ok := false
	var img := Image.new()
	if img.has_method("load_svg_from_string"):
		var err := img.load_svg_from_string(svg_str)
		if err == OK and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			var tex_rect := TextureRect.new()
			tex_rect.name = "ShipTextureRect"
			tex_rect.texture = tex
			tex_rect.position = Vector2.ZERO
			tex_rect.size = box_size
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(tex_rect)
			rasterized_ok = true

	if not rasterized_ok:
		var stroke_col: Color = Color(1.0, 0.35, 0.35) if is_sunk else (SHIP_SPECS[ship_idx]["color"] if ship_idx >= 0 and ship_idx < SHIP_SPECS.size() else Color(0.55, 0.75, 0.95))
		var hull_col: Color = Color(0.24, 0.14, 0.14, 0.92) if is_sunk else Color(0.17, 0.24, 0.31, 0.94)
		holder.draw.connect(func():
			var pad := maxf(current_cell_size * 0.14, 3.0)
			var pts := PackedVector2Array()
			if horizontal:
				var cy := box_size.y * 0.5
				pts.append(Vector2(pad, pad))
				pts.append(Vector2(box_size.x - current_cell_size * 0.55, pad))
				pts.append(Vector2(box_size.x - pad, cy))
				pts.append(Vector2(box_size.x - current_cell_size * 0.55, box_size.y - pad))
				pts.append(Vector2(pad, box_size.y - pad))
			else:
				var cx := box_size.x * 0.5
				pts.append(Vector2(pad, pad))
				pts.append(Vector2(box_size.x - pad, pad))
				pts.append(Vector2(box_size.x - pad, box_size.y - current_cell_size * 0.55))
				pts.append(Vector2(cx, box_size.y - pad))
				pts.append(Vector2(pad, box_size.y - current_cell_size * 0.55))
			holder.draw_colored_polygon(pts, hull_col)
			pts.append(pts[0])
			holder.draw_polyline(pts, stroke_col, 2.0)
		)
		holder.queue_redraw()

	return holder

func _refresh_ship_svg_overlays() -> void:
	if own_ships_layer != null:
		for child in own_ships_layer.get_children():
			own_ships_layer.remove_child(child)
			child.queue_free()
	if opp_ships_layer != null:
		for child in opp_ships_layer.get_children():
			opp_ships_layer.remove_child(child)
			child.queue_free()

	var active_ships: Array = p2_ships if (phase == Phase.PLACEMENT_P2 or (is_vs_ai and local_player == P2)) else p1_ships
	if own_ships_layer != null:
		for idx in range(active_ships.size()):
			var ship_cells: Array = active_ships[idx]
			var ship_is_sunk := true
			for cell_pos in ship_cells:
				var p: Vector2i = cell_pos
				if own_shot_grid[p.x][p.y] != "sunk" and not (p in sunken_cells):
					ship_is_sunk = false
					break
			var node := _create_ship_visual_node(ship_cells, idx, ship_is_sunk)
			if node != null:
				own_ships_layer.add_child(node)

	if opp_ships_layer != null:
		for idx in range(opp_sunken_ships.size()):
			var sunk_cells_arr: Array = opp_sunken_ships[idx]
			var node_opp := _create_ship_visual_node(sunk_cells_arr, idx % SHIP_SPECS.size(), true)
			if node_opp != null:
				opp_ships_layer.add_child(node_opp)

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
