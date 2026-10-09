extends Node2D

const TERRITORY_NAMES: Array = [
	"Argentina", "Brasil", "Chile", "Colombia", "Perú",
	"México", "California", "Nueva York", "Canadá",
	"Gran Bretaña", "España", "Francia", "Alemania", "Rusia",
	"Sahara", "Egipto", "Congo", "Sudáfrica",
	"Aral", "Tartaria", "Taymir", "Siberia", "Kamchatka", "China", "India", "Japón",
	"Australia", "Java", "Sumatra", "Borneo"
]

const CONTINENTS_DATA: Array = [
	{
		"id": 0,
		"name": "América del Sur",
		"bonus": 2,
		"territories": [0, 1, 2, 3, 4],
		"color": Color(0.90, 0.42, 0.42)
	},
	{
		"id": 1,
		"name": "América del Norte",
		"bonus": 3,
		"territories": [5, 6, 7, 8],
		"color": Color(0.38, 0.68, 0.95)
	},
	{
		"id": 2,
		"name": "Europa",
		"bonus": 5,
		"territories": [9, 10, 11, 12, 13],
		"color": Color(0.45, 0.80, 0.48)
	},
	{
		"id": 3,
		"name": "África",
		"bonus": 3,
		"territories": [14, 15, 16, 17],
		"color": Color(0.98, 0.68, 0.28)
	},
	{
		"id": 4,
		"name": "Asia",
		"bonus": 7,
		"territories": [18, 19, 20, 21, 22, 23, 24, 25],
		"color": Color(0.74, 0.44, 0.84)
	},
	{
		"id": 5,
		"name": "Oceanía",
		"bonus": 2,
		"territories": [26, 27, 28, 29],
		"color": Color(0.28, 0.82, 0.88)
	}
]

var TERRITORY_POLYGONS: Array = [
	# 0: Argentina
	PackedVector2Array([Vector2(140, 480), Vector2(220, 480), Vector2(200, 560), Vector2(150, 560)]),
	# 1: Brasil
	PackedVector2Array([Vector2(200, 400), Vector2(280, 400), Vector2(270, 470), Vector2(190, 470)]),
	# 2: Chile
	PackedVector2Array([Vector2(130, 460), Vector2(160, 460), Vector2(150, 540), Vector2(120, 500)]),
	# 3: Colombia
	PackedVector2Array([Vector2(130, 360), Vector2(210, 360), Vector2(200, 410), Vector2(140, 410)]),
	# 4: Perú
	PackedVector2Array([Vector2(130, 410), Vector2(200, 410), Vector2(190, 460), Vector2(130, 460)]),

	# 5: México
	PackedVector2Array([Vector2(100, 250), Vector2(180, 250), Vector2(170, 320), Vector2(110, 320)]),
	# 6: California
	PackedVector2Array([Vector2(80, 160), Vector2(160, 160), Vector2(150, 240), Vector2(90, 240)]),
	# 7: Nueva York
	PackedVector2Array([Vector2(160, 150), Vector2(240, 150), Vector2(230, 230), Vector2(160, 230)]),
	# 8: Canadá
	PackedVector2Array([Vector2(100, 70), Vector2(220, 70), Vector2(210, 140), Vector2(110, 140)]),

	# 9: Gran Bretaña
	PackedVector2Array([Vector2(320, 90), Vector2(400, 90), Vector2(390, 150), Vector2(320, 150)]),
	# 10: España
	PackedVector2Array([Vector2(310, 180), Vector2(380, 180), Vector2(370, 250), Vector2(310, 250)]),
	# 11: Francia
	PackedVector2Array([Vector2(370, 160), Vector2(430, 160), Vector2(420, 220), Vector2(370, 220)]),
	# 12: Alemania
	PackedVector2Array([Vector2(420, 130), Vector2(480, 130), Vector2(470, 200), Vector2(420, 200)]),
	# 13: Rusia
	PackedVector2Array([Vector2(470, 90), Vector2(560, 90), Vector2(550, 180), Vector2(470, 180)]),

	# 14: Sahara
	PackedVector2Array([Vector2(330, 280), Vector2(420, 280), Vector2(410, 360), Vector2(330, 360)]),
	# 15: Egipto
	PackedVector2Array([Vector2(410, 270), Vector2(490, 270), Vector2(480, 340), Vector2(410, 340)]),
	# 16: Congo
	PackedVector2Array([Vector2(380, 360), Vector2(470, 360), Vector2(460, 440), Vector2(380, 440)]),
	# 17: Sudáfrica
	PackedVector2Array([Vector2(390, 450), Vector2(480, 450), Vector2(460, 530), Vector2(390, 530)]),

	# 18: Aral
	PackedVector2Array([Vector2(500, 180), Vector2(580, 180), Vector2(570, 240), Vector2(500, 240)]),
	# 19: Tartaria
	PackedVector2Array([Vector2(560, 120), Vector2(640, 120), Vector2(630, 180), Vector2(560, 180)]),
	# 20: Taymir
	PackedVector2Array([Vector2(610, 70), Vector2(690, 70), Vector2(680, 120), Vector2(610, 120)]),
	# 21: Siberia
	PackedVector2Array([Vector2(650, 110), Vector2(730, 110), Vector2(720, 170), Vector2(650, 170)]),
	# 22: Kamchatka
	PackedVector2Array([Vector2(690, 80), Vector2(770, 80), Vector2(760, 150), Vector2(690, 150)]),
	# 23: China
	PackedVector2Array([Vector2(570, 200), Vector2(670, 200), Vector2(660, 270), Vector2(570, 270)]),
	# 24: India
	PackedVector2Array([Vector2(510, 250), Vector2(600, 250), Vector2(590, 320), Vector2(510, 320)]),
	# 25: Japón
	PackedVector2Array([Vector2(690, 180), Vector2(760, 180), Vector2(750, 250), Vector2(690, 250)]),

	# 26: Australia
	PackedVector2Array([Vector2(650, 440), Vector2(750, 440), Vector2(730, 530), Vector2(640, 530)]),
	# 27: Java
	PackedVector2Array([Vector2(610, 360), Vector2(680, 360), Vector2(670, 410), Vector2(610, 410)]),
	# 28: Sumatra
	PackedVector2Array([Vector2(560, 330), Vector2(630, 330), Vector2(620, 370), Vector2(560, 370)]),
	# 29: Borneo
	PackedVector2Array([Vector2(630, 310), Vector2(700, 310), Vector2(690, 360), Vector2(630, 360)])
]

const TERRITORY_CENTERS: Array = [
	Vector2(180, 520), # 0: Argentina
	Vector2(240, 440), # 1: Brasil
	Vector2(150, 480), # 2: Chile
	Vector2(170, 390), # 3: Colombia
	Vector2(160, 430), # 4: Perú

	Vector2(140, 280), # 5: México
	Vector2(120, 200), # 6: California
	Vector2(200, 190), # 7: Nueva York
	Vector2(160, 110), # 8: Canadá

	Vector2(360, 130), # 9: Gran Bretaña
	Vector2(350, 220), # 10: España
	Vector2(400, 190), # 11: Francia
	Vector2(450, 170), # 12: Alemania
	Vector2(520, 140), # 13: Rusia

	Vector2(380, 320), # 14: Sahara
	Vector2(450, 310), # 15: Egipto
	Vector2(430, 400), # 16: Congo
	Vector2(440, 490), # 17: Sudáfrica

	Vector2(540, 210), # 18: Aral
	Vector2(600, 150), # 19: Tartaria
	Vector2(650, 100), # 20: Taymir
	Vector2(690, 140), # 21: Siberia
	Vector2(730, 120), # 22: Kamchatka
	Vector2(620, 240), # 23: China
	Vector2(560, 290), # 24: India
	Vector2(730, 220), # 25: Japón

	Vector2(700, 480), # 26: Australia
	Vector2(650, 380), # 27: Java
	Vector2(600, 350), # 28: Sumatra
	Vector2(660, 340)  # 29: Borneo
]

const ADJACENCIES: Array = [
	[0, 1], [0, 2], [0, 4],
	[1, 2], [1, 3], [1, 4], [1, 14],
	[2, 4], [2, 26],
	[3, 4], [3, 5],
	[5, 6],
	[6, 7], [6, 8],
	[7, 8], [7, 10],
	[8, 22],
	[9, 10], [9, 11], [9, 12],
	[10, 11], [10, 14],
	[11, 12],
	[12, 13],
	[13, 18], [13, 19],
	[14, 15], [14, 16],
	[15, 16], [15, 17], [15, 18],
	[16, 17],
	[18, 19], [18, 24],
	[19, 20], [19, 21], [19, 23],
	[20, 21],
	[21, 22], [21, 23],
	[22, 25],
	[23, 24], [23, 25], [23, 28],
	[24, 28],
	[26, 27],
	[27, 29],
	[28, 29]
]

const SEA_LANES: Array = [
	[1, 14],   # Brasil <-> Sahara
	[2, 26],   # Chile <-> Australia
	[3, 5],    # Colombia <-> México
	[7, 10],   # Nueva York <-> España
	[8, 22],   # Canadá <-> Kamchatka
	[10, 14],  # España <-> Sahara
	[15, 18],  # Egipto <-> Aral
	[22, 25],  # Kamchatka <-> Japón
	[23, 28],  # China <-> Sumatra
	[24, 28],  # India <-> Sumatra
	[26, 27],  # Australia <-> Java
	[27, 29],  # Java <-> Borneo
	[28, 29],  # Sumatra <-> Borneo
	[9, 10],   # Gran Bretaña <-> España
	[9, 11],   # Gran Bretaña <-> Francia
	[9, 12]    # Gran Bretaña <-> Alemania
]

const PLAYER_COLORS: Dictionary = {
	1: Color(0.92, 0.25, 0.25), # P1: Rojo Imperial
	2: Color(0.22, 0.52, 0.95), # P2: Azul Cobalto
	3: Color(0.18, 0.82, 0.38), # P3: Verde Esmeralda
	4: Color(0.96, 0.80, 0.15), # P4: Amarillo Oro
	5: Color(0.74, 0.30, 0.92), # P5: Púrpura Real
	6: Color(0.96, 0.52, 0.18)  # P6: Naranja Fuego
}

const PLAYER_NAMES: Dictionary = {
	1: "Rojo (1)",
	2: "Azul (2)",
	3: "Verde (3)",
	4: "Amarillo (4)",
	5: "Púrpura (5)",
	6: "Naranja (6)"
}

const CARD_TYPES: Dictionary = {
	0: { "name": "Infantería", "icon": "🪖" },
	1: { "name": "Caballería", "icon": "🐎" },
	2: { "name": "Artillería", "icon": "💥" },
	3: { "name": "Comodín", "icon": "⭐" }
}

var bridge
var current_player_id: int = 1
var current_phase: String = "PlaceArmies"
var armies_remaining_to_place: int = 0
var winner: int = -1

var territory_owners: Dictionary = {}
var territory_armies: Dictionary = {}
var territory_labels: Dictionary = {} # For backward-compatibility

var selected_from: int = -1
var selected_to: int = -1
var hovered_territory: int = -1
var valid_targets: Array[int] = []

# Cards and Objectives state
var player_cards: Dictionary = { 1: [], 2: [], 3: [], 4: [], 5: [], 6: [] }
var selected_card_indices: Array[int] = []
var exchange_count: int = 0
var player_objectives: Dictionary = {}

# UI Nodes
@onready var status_label: Label = $Status if has_node("Status") else null
var map_panel: Panel
var map_canvas: Control
var sidebar_panel: Panel
var tab_container: TabContainer

var objective_card_panel: PanelContainer
var objective_title_label: Label
var objective_desc_label: Label
var objective_progress_bar: ProgressBar
var objective_progress_label: Label

var cards_container: HBoxContainer
var cards_info_label: Label
var btn_exchange: Button

var action_panel: VBoxContainer
var action_title_label: Label
var action_info_label: Label
var btn_place: Button
var btn_place_5: Button
var btn_place_all: Button
var btn_attack: Button
var btn_fortify: Button
var btn_end_phase: Button
var attack_dice_spinbox: SpinBox
var fortify_armies_spinbox: SpinBox

var player_stats_label: Label
var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var rules_popup: RulesPopup
var dice_popup: PopupPanel
var dice_label: Label
var dice_widget: DiceWidget
var _pause_menu: CanvasLayer

# Pulse animation timer
var pulse_time: float = 0.0

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)
	else:
		_create_default_theme()

	_setup_default_objectives()
	_setup_default_cards()
	_setup_ui()

	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)

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

	if bridge.has_signal("territory_conquered"):
		bridge.connect("territory_conquered", _on_territory_conquered)
	if bridge.has_signal("attack_resolved"):
		bridge.connect("attack_resolved", _on_attack_resolved)
	if bridge.has_signal("armies_placed"):
		bridge.connect("armies_placed", _on_armies_placed)
	if bridge.has_signal("player_eliminated"):
		bridge.connect("player_eliminated", _on_player_eliminated)
	if bridge.has_signal("phase_changed"):
		bridge.connect("phase_changed", _on_phase_changed)
	if bridge.has_signal("cards_exchanged"):
		bridge.connect("cards_exchanged", _on_cards_exchanged)
	if bridge.has_signal("crisis_game_over"):
		bridge.connect("crisis_game_over", _on_crisis_game_over)
	if bridge.has_signal("turn_changed"):
		bridge.connect("turn_changed", _on_turn_changed)

	bridge.start_local_match_crisis(42, [1, 2])
	current_player_id = bridge.current_player()

	_sync_all_from_bridge()
	_on_layout_changed(GameManager.get_layout() if gm != null else 0)
	_update_ui_state()

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_quit_to_menu() -> void:
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	if selected_from != -1 or valid_targets.size() > 0:
		if map_canvas:
			map_canvas.queue_redraw()

func _create_default_theme() -> void:
	current_theme = BoardTheme.new()
	current_theme.theme_name = "Noche Azul"
	current_theme.board_color = Color("#121A24")
	current_theme.line_color = Color("#7C9BB8")
	current_theme.light_color = Color("#5B7A9C")
	current_theme.dark_color = Color("#1A2634")
	current_theme.select_color = Color(1.0, 0.85, 0.25, 0.85)
	current_theme.valid_move_color = Color(0.2, 0.9, 0.5, 0.85)

func _setup_default_objectives() -> void:
	player_objectives[1] = {
		"title": "Conquistar 24 Territorios",
		"desc": "Ocupar 24 territorios cualesquiera en el planeta con al menos 1 ejército.",
		"target_type": "territories",
		"target_count": 24
	}
	player_objectives[2] = {
		"title": "Conquistar América del Sur y Europa",
		"desc": "Ocupar la totalidad de América del Sur (5 territorios) y Europa (5 territorios).",
		"target_type": "continents",
		"continents": [0, 2]
	}
	for p in range(3, 7):
		player_objectives[p] = {
			"title": "Ocupar 18 Territorios",
			"desc": "Ocupar 18 territorios con al menos 2 ejércitos cada uno.",
			"target_type": "territories",
			"target_count": 18
		}

func _setup_default_cards() -> void:
	# Initial cards for players so exchange mechanics can be tested & visualized immediately
	player_cards[1] = [
		{ "territory": 0, "card_type": 0 }, # Argentina - Infantería
		{ "territory": 1, "card_type": 1 }, # Brasil - Caballería
		{ "territory": 2, "card_type": 2 }, # Chile - Artillería
		{ "territory": 10, "card_type": 3 } # España - Comodín
	]
	player_cards[2] = [
		{ "territory": 5, "card_type": 0 },
		{ "territory": 6, "card_type": 0 },
		{ "territory": 7, "card_type": 0 }
	]

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	_apply_theme_styling()
	if map_canvas:
		map_canvas.queue_redraw()

func _apply_theme_styling() -> void:
	if current_theme == null:
		return
	
	if map_panel:
		var map_style = StyleBoxFlat.new()
		map_style.bg_color = current_theme.board_color.darkened(0.2)
		map_style.border_color = current_theme.line_color.darkened(0.2)
		map_style.set_border_width_all(2)
		map_style.corner_radius_top_left = 10
		map_style.corner_radius_top_right = 10
		map_style.corner_radius_bottom_left = 10
		map_style.corner_radius_bottom_right = 10
		map_panel.add_theme_stylebox_override("panel", map_style)

	if sidebar_panel:
		var side_style = StyleBoxFlat.new()
		side_style.bg_color = current_theme.dark_color.darkened(0.1)
		side_style.border_color = current_theme.line_color.darkened(0.3)
		side_style.set_border_width_all(2)
		side_style.corner_radius_top_left = 10
		side_style.corner_radius_top_right = 10
		side_style.corner_radius_bottom_left = 10
		side_style.corner_radius_bottom_right = 10
		sidebar_panel.add_theme_stylebox_override("panel", side_style)

func _setup_ui() -> void:
	# Main Map Panel (Left side)
	map_panel = Panel.new()
	map_panel.name = "MapPanel"
	map_panel.position = Vector2(20, 20)
	map_panel.custom_minimum_size = Vector2(750, 680)
	add_child(map_panel)

	# Interactive Canvas for rendering polygons, connection lines, badges, and highlights
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_canvas.draw.connect(_on_map_canvas_draw)
	map_canvas.gui_input.connect(_on_map_canvas_gui_input)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.add_child(map_canvas)

	# Hidden labels container for backward compatibility with older tests that check territory_labels[i]
	for i in range(30):
		var lbl = Label.new()
		lbl.name = "Territory_" + str(i)
		lbl.visible = false
		add_child(lbl)
		territory_labels[i] = lbl

	# Sidebar Panel (Right side)
	sidebar_panel = Panel.new()
	sidebar_panel.name = "SidebarPanel"
	sidebar_panel.position = Vector2(790, 20)
	sidebar_panel.custom_minimum_size = Vector2(350, 680)
	add_child(sidebar_panel)

	var sidebar_vbox = VBoxContainer.new()
	sidebar_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	sidebar_vbox.add_theme_constant_override("separation", 10)
	sidebar_vbox.offset_left = 12
	sidebar_vbox.offset_top = 12
	sidebar_vbox.offset_right = -12
	sidebar_vbox.offset_bottom = -12
	sidebar_panel.add_child(sidebar_vbox)

	# Header: Game Title & Top HUD
	var header_hbox = HBoxContainer.new()
	sidebar_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "CRISIS — TEG"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(85, 32)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("crisis"))
	header_hbox.add_child(btn_rules)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	sidebar_vbox.add_child(turn_indicator)

	# Player Statistics & Phase info
	player_stats_label = Label.new()
	player_stats_label.text = "Cargando estado..."
	player_stats_label.add_theme_font_size_override("font_size", 13)
	sidebar_vbox.add_child(player_stats_label)

	# Tab Container for Cards, Objectives, and Continents Summary
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_vbox.add_child(tab_container)

	# --- Tab 1: Acciones de Turno ---
	var actions_tab = VBoxContainer.new()
	actions_tab.name = "Acciones"
	actions_tab.add_theme_constant_override("separation", 8)
	tab_container.add_child(actions_tab)

	action_title_label = Label.new()
	action_title_label.text = "Fase: Colocación de Tropas"
	action_title_label.add_theme_font_size_override("font_size", 14)
	action_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	actions_tab.add_child(action_title_label)

	action_info_label = Label.new()
	action_info_label.text = "Haz click en tus territorios en el mapa para colocar ejércitos."
	action_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	action_info_label.add_theme_font_size_override("font_size", 12)
	actions_tab.add_child(action_info_label)

	var place_hbox = HBoxContainer.new()
	place_hbox.add_theme_constant_override("separation", 6)
	actions_tab.add_child(place_hbox)

	btn_place = Button.new()
	btn_place.text = "+1 Tropa"
	btn_place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_place.custom_minimum_size = Vector2(0, 36)
	btn_place.pressed.connect(_on_btn_place_pressed)
	place_hbox.add_child(btn_place)

	btn_place_5 = Button.new()
	btn_place_5.text = "+5 Tropas"
	btn_place_5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_place_5.custom_minimum_size = Vector2(0, 36)
	btn_place_5.pressed.connect(func(): _place_armies(5))
	place_hbox.add_child(btn_place_5)

	btn_place_all = Button.new()
	btn_place_all.text = "Todas"
	btn_place_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_place_all.custom_minimum_size = Vector2(0, 36)
	btn_place_all.pressed.connect(func(): _place_armies(armies_remaining_to_place))
	place_hbox.add_child(btn_place_all)

	var attack_hbox = HBoxContainer.new()
	actions_tab.add_child(attack_hbox)

	var dice_lbl = Label.new()
	dice_lbl.text = "Dados:"
	dice_lbl.add_theme_font_size_override("font_size", 12)
	attack_hbox.add_child(dice_lbl)

	attack_dice_spinbox = SpinBox.new()
	attack_dice_spinbox.min_value = 1
	attack_dice_spinbox.max_value = 3
	attack_dice_spinbox.value = 3
	attack_hbox.add_child(attack_dice_spinbox)

	btn_attack = Button.new()
	btn_attack.text = "⚔️ Atacar"
	btn_attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_attack.custom_minimum_size = Vector2(0, 36)
	btn_attack.pressed.connect(_on_btn_attack_pressed)
	attack_hbox.add_child(btn_attack)

	var fortify_hbox = HBoxContainer.new()
	actions_tab.add_child(fortify_hbox)

	var fort_lbl = Label.new()
	fort_lbl.text = "Tropas:"
	fort_lbl.add_theme_font_size_override("font_size", 12)
	fortify_hbox.add_child(fort_lbl)

	fortify_armies_spinbox = SpinBox.new()
	fortify_armies_spinbox.min_value = 1
	fortify_armies_spinbox.max_value = 10
	fortify_armies_spinbox.value = 1
	fortify_hbox.add_child(fortify_armies_spinbox)

	btn_fortify = Button.new()
	btn_fortify.text = "🛡️ Fortificar"
	btn_fortify.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_fortify.custom_minimum_size = Vector2(0, 36)
	btn_fortify.pressed.connect(_on_btn_fortify_pressed)
	fortify_hbox.add_child(btn_fortify)

	btn_end_phase = Button.new()
	btn_end_phase.text = "Fin de Fase ➡️"
	btn_end_phase.custom_minimum_size = Vector2(0, 40)
	btn_end_phase.pressed.connect(_on_btn_end_phase_pressed)
	actions_tab.add_child(btn_end_phase)

	# --- Tab 2: Objetivo Secreto (ObjectiveCard UI) ---
	var obj_tab = VBoxContainer.new()
	obj_tab.name = "Objetivo"
	obj_tab.add_theme_constant_override("separation", 10)
	tab_container.add_child(obj_tab)

	objective_card_panel = PanelContainer.new()
	var obj_style = StyleBoxFlat.new()
	obj_style.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	obj_style.border_color = Color(0.95, 0.8, 0.3)
	obj_style.set_border_width_all(2)
	obj_style.corner_radius_top_left = 8
	obj_style.corner_radius_top_right = 8
	obj_style.corner_radius_bottom_left = 8
	obj_style.corner_radius_bottom_right = 8
	obj_style.content_margin_left = 12
	obj_style.content_margin_right = 12
	obj_style.content_margin_top = 10
	obj_style.content_margin_bottom = 10
	objective_card_panel.add_theme_stylebox_override("panel", obj_style)
	obj_tab.add_child(objective_card_panel)

	var obj_vbox = VBoxContainer.new()
	obj_vbox.add_theme_constant_override("separation", 6)
	objective_card_panel.add_child(obj_vbox)

	var badge_lbl = Label.new()
	badge_lbl.text = "🎯 MISIÓN SECRETA"
	badge_lbl.add_theme_font_size_override("font_size", 14)
	badge_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	obj_vbox.add_child(badge_lbl)

	objective_title_label = Label.new()
	objective_title_label.text = "Conquistar 24 Territorios"
	objective_title_label.add_theme_font_size_override("font_size", 15)
	obj_vbox.add_child(objective_title_label)

	objective_desc_label = Label.new()
	objective_desc_label.text = "Ocupar 24 territorios cualesquiera en el planeta con al menos 1 ejército."
	objective_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	objective_desc_label.add_theme_font_size_override("font_size", 12)
	objective_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	obj_vbox.add_child(objective_desc_label)

	var prog_title = Label.new()
	prog_title.text = "Progreso de Conquista:"
	prog_title.add_theme_font_size_override("font_size", 12)
	obj_vbox.add_child(prog_title)

	objective_progress_bar = ProgressBar.new()
	objective_progress_bar.custom_minimum_size = Vector2(0, 20)
	objective_progress_bar.max_value = 24
	objective_progress_bar.value = 15
	obj_vbox.add_child(objective_progress_bar)

	objective_progress_label = Label.new()
	objective_progress_label.text = "15 / 24 territorios"
	objective_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_progress_label.add_theme_font_size_override("font_size", 12)
	obj_vbox.add_child(objective_progress_label)

	# --- Tab 3: Tarjetas de Canje (Territory Cards UI) ---
	var cards_tab = VBoxContainer.new()
	cards_tab.name = "Tarjetas"
	cards_tab.add_theme_constant_override("separation", 8)
	tab_container.add_child(cards_tab)

	cards_info_label = Label.new()
	cards_info_label.text = "Selecciona 3 tarjetas (3 iguales o 1 de cada tipo) para canjear por ejércitos."
	cards_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	cards_info_label.add_theme_font_size_override("font_size", 12)
	cards_tab.add_child(cards_info_label)

	var scroll_cards = ScrollContainer.new()
	scroll_cards.custom_minimum_size = Vector2(0, 130)
	scroll_cards.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_cards.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_tab.add_child(scroll_cards)

	cards_container = HBoxContainer.new()
	cards_container.add_theme_constant_override("separation", 8)
	scroll_cards.add_child(cards_container)

	btn_exchange = Button.new()
	btn_exchange.text = "🔄 Canjear Tarjetas (+4 Ejércitos)"
	btn_exchange.custom_minimum_size = Vector2(0, 38)
	btn_exchange.pressed.connect(_on_btn_exchange_pressed)
	cards_tab.add_child(btn_exchange)

	# --- Tab 4: Continentes y Bonificaciones ---
	var cont_tab = VBoxContainer.new()
	cont_tab.name = "Continentes"
	cont_tab.add_theme_constant_override("separation", 6)
	tab_container.add_child(cont_tab)

	for c in CONTINENTS_DATA:
		var cont_panel = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = c["color"].darkened(0.65)
		cs.border_color = c["color"]
		cs.set_border_width_all(1)
		cs.corner_radius_top_left = 6
		cs.corner_radius_top_right = 6
		cs.corner_radius_bottom_left = 6
		cs.corner_radius_bottom_right = 6
		cs.content_margin_left = 8
		cs.content_margin_right = 8
		cs.content_margin_top = 4
		cs.content_margin_bottom = 4
		cont_panel.add_theme_stylebox_override("panel", cs)
		cont_tab.add_child(cont_panel)

		var chbox = HBoxContainer.new()
		cont_panel.add_child(chbox)

		var clbl = Label.new()
		clbl.text = "%s (%d terr.)" % [c["name"], c["territories"].size()]
		clbl.add_theme_font_size_override("font_size", 12)
		clbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chbox.add_child(clbl)

		var cbonus = Label.new()
		cbonus.text = "+%d Tropas" % c["bonus"]
		cbonus.add_theme_font_size_override("font_size", 12)
		cbonus.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
		chbox.add_child(cbonus)

	# Dice Popup for Combat resolution
	dice_popup = PopupPanel.new()
	dice_popup.title = "Resultado del Combate"
	dice_popup.size = Vector2i(340, 220)
	add_child(dice_popup)

	var dice_vbox = VBoxContainer.new()
	dice_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_vbox.add_theme_constant_override("separation", 10)
	dice_popup.add_child(dice_vbox)

	dice_label = Label.new()
	dice_label.custom_minimum_size = Vector2(300, 70)
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dice_vbox.add_child(dice_label)

	dice_widget = DiceWidget.new()
	dice_vbox.add_child(dice_widget)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(100, 80)
	add_child(rules_popup)

	_apply_theme_styling()

func _on_layout_changed(layout: int) -> void:
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	if layout == 2: # PHONE
		map_panel.position = Vector2(10, 10)
		map_panel.custom_minimum_size = Vector2(355, 330)
		map_panel.size = Vector2(355, 330)
		sidebar_panel.position = Vector2(10, 350)
		sidebar_panel.custom_minimum_size = Vector2(355, 300)
		sidebar_panel.size = Vector2(355, 300)
	else: # DESKTOP or TABLET
		map_panel.position = Vector2(20, 20)
		map_panel.custom_minimum_size = Vector2(750, 680)
		map_panel.size = Vector2(750, 680)
		sidebar_panel.position = Vector2(790, 20)
		sidebar_panel.custom_minimum_size = Vector2(350, 680)
		sidebar_panel.size = Vector2(350, 680)

	if map_canvas:
		map_canvas.queue_redraw()

func _get_map_transform() -> Dictionary:
	var canvas_size = map_canvas.size if map_canvas else Vector2(750, 680)
	var scale_x = (canvas_size.x - 24.0) / 800.0
	var scale_y = (canvas_size.y - 24.0) / 600.0
	var s = min(scale_x, scale_y)
	var offset = (canvas_size - Vector2(800, 600) * s) * 0.5
	return { "scale": s, "offset": offset }

func _to_screen(map_pos: Vector2, trans: Dictionary) -> Vector2:
	return trans["offset"] + map_pos * trans["scale"]

func _from_screen(screen_pos: Vector2, trans: Dictionary) -> Vector2:
	return (screen_pos - trans["offset"]) / trans["scale"]

# -------------------------------------------------------------------------
# MAP CANVAS DRAWING (Points a, b, c)
# -------------------------------------------------------------------------
func _on_map_canvas_draw() -> void:
	var trans = _get_map_transform()
	var s = trans["scale"]
	var offset = trans["offset"]

	# 1. Draw Ocean Background & Nautical Grid
	var ocean_col = current_theme.board_color.darkened(0.1) if current_theme else Color("#121A24")
	map_canvas.draw_rect(Rect2(Vector2.ZERO, map_canvas.size), ocean_col, true)

	var grid_col = current_theme.line_color if current_theme else Color("#7C9BB8")
	var faint_grid = Color(grid_col.r, grid_col.g, grid_col.b, 0.12)
	
	# Lat/Long lines
	for y_val in [150.0, 300.0, 450.0]:
		var p1 = _to_screen(Vector2(50, y_val), trans)
		var p2 = _to_screen(Vector2(750, y_val), trans)
		map_canvas.draw_line(p1, p2, faint_grid, 1.0)
	for x_val in [200.0, 400.0, 600.0]:
		var p1 = _to_screen(Vector2(x_val, 50), trans)
		var p2 = _to_screen(Vector2(x_val, 550), trans)
		map_canvas.draw_line(p1, p2, faint_grid, 1.0)

	# 2. Draw Adjacencies & Borders (Land connections & Sea lanes)
	for edge in ADJACENCIES:
		var t1 = edge[0]
		var t2 = edge[1]
		var c1 = _to_screen(TERRITORY_CENTERS[t1], trans)
		var c2 = _to_screen(TERRITORY_CENTERS[t2], trans)

		var is_sea = SEA_LANES.has(edge) or SEA_LANES.has([t2, t1])
		var is_active_connection = (selected_from == t1 and selected_to == t2) or (selected_from == t2 and selected_to == t1)
		var is_available_target = (selected_from == t1 and valid_targets.has(t2)) or (selected_from == t2 and valid_targets.has(t1))

		if is_active_connection:
			var pulse_val = 0.7 + 0.3 * sin(pulse_time * 2.0)
			var line_c = Color(1.0, 0.9, 0.2, pulse_val)
			map_canvas.draw_line(c1, c2, line_c, 3.5 * s)
		elif is_available_target:
			var pulse_val = 0.6 + 0.4 * sin(pulse_time * 2.5)
			var target_c = Color(0.2, 0.95, 0.4, pulse_val)
			map_canvas.draw_line(c1, c2, target_c, 2.5 * s)
		elif is_sea:
			# Dashed nautical line
			_draw_dashed_line(c1, c2, Color(0.35, 0.75, 0.90, 0.45), 1.5 * s, 8.0 * s, 4.0 * s)
		else:
			var land_c = Color(grid_col.r, grid_col.g, grid_col.b, 0.25)
			map_canvas.draw_line(c1, c2, land_c, 1.2 * s)

	# 3. Draw Territory Polygons colored by Owner with Continent base tint
	for i in range(30):
		var base_poly = TERRITORY_POLYGONS[i]
		var screen_poly = PackedVector2Array()
		for pt in base_poly:
			screen_poly.append(_to_screen(pt, trans))

		var t_owner = territory_owners.get(i, 0)
		var continent_id = _get_territory_continent(i)
		var cont_col = CONTINENTS_DATA[continent_id]["color"]

		var fill_color: Color
		if t_owner > 0 and PLAYER_COLORS.has(t_owner):
			var p_col = PLAYER_COLORS[t_owner]
			# Blend owner color with subtle continent tone
			fill_color = Color(p_col.r, p_col.g, p_col.b, 0.72)
		else:
			fill_color = Color(cont_col.r, cont_col.g, cont_col.b, 0.40)

		# State highlights
		if selected_from == i:
			var pulse_factor = 0.8 + 0.2 * sin(pulse_time)
			fill_color = fill_color.lightened(0.35)
			fill_color.a = pulse_factor
		elif selected_to == i:
			fill_color = Color(0.2, 0.9, 0.4, 0.85)
		elif valid_targets.has(i):
			var pulse_val = 0.65 + 0.25 * sin(pulse_time * 1.5)
			if current_phase == "Attack":
				fill_color = fill_color.blend(Color(1.0, 0.2, 0.2, pulse_val * 0.4))
			else:
				fill_color = fill_color.blend(Color(0.2, 0.9, 0.4, pulse_val * 0.4))
		elif hovered_territory == i:
			fill_color = fill_color.lightened(0.20)

		# Draw filled polygon
		map_canvas.draw_colored_polygon(screen_poly, fill_color)

		# Polygon Border
		var stroke_color = grid_col.darkened(0.2)
		var stroke_width = 1.5 * s

		if selected_from == i:
			stroke_color = current_theme.select_color if current_theme else Color(1.0, 0.9, 0.2)
			stroke_width = 3.5 * s
		elif selected_to == i:
			stroke_color = current_theme.valid_move_color if current_theme else Color(0.2, 0.9, 0.5)
			stroke_width = 3.5 * s
		elif valid_targets.has(i):
			stroke_color = Color(0.3, 0.95, 0.45)
			stroke_width = 2.5 * s
		elif hovered_territory == i:
			stroke_color = Color.WHITE
			stroke_width = 2.0 * s

		var poly_closed = Array(screen_poly)
		poly_closed.append(screen_poly[0])
		map_canvas.draw_polyline(PackedVector2Array(poly_closed), stroke_color, stroke_width, true)

	# 4. Draw Center Badges & Army counts & Territory Names
	for i in range(30):
		var center_pos = _to_screen(TERRITORY_CENTERS[i], trans)
		var t_owner = territory_owners.get(i, 0)
		var armies = territory_armies.get(i, 0)
		var badge_radius = clamp(13.0 * s, 9.0, 16.0)

		var badge_color = PLAYER_COLORS.get(t_owner, Color(0.25, 0.25, 0.30))

		# Outer shield/circle
		map_canvas.draw_circle(center_pos, badge_radius + 2.0 * s, Color(0.08, 0.1, 0.14, 0.9))
		map_canvas.draw_circle(center_pos, badge_radius, badge_color)
		map_canvas.draw_circle(center_pos, badge_radius - 2.0 * s, badge_color.lightened(0.15))

		# Army count text
		var count_str = str(armies)
		var font = ThemeDB.fallback_font
		var font_size = int(clamp(11.0 * s, 9.0, 14.0))
		var str_size = font.get_string_size(count_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = center_pos + Vector2(-str_size.x * 0.5, str_size.y * 0.35)
		map_canvas.draw_string(font, text_pos, count_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

		# Territory Name Pill (Rendered right below center badge)
		var name_str = TERRITORY_NAMES[i]
		var name_font_size = int(clamp(9.0 * s, 8.0, 11.0))
		var name_size = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, name_font_size)
		var pill_rect = Rect2(
			center_pos.x - name_size.x * 0.5 - 4.0 * s,
			center_pos.y + badge_radius + 2.0 * s,
			name_size.x + 8.0 * s,
			name_size.y + 2.0 * s
		)
		map_canvas.draw_rect(pill_rect, Color(0.05, 0.08, 0.12, 0.75), true)
		map_canvas.draw_rect(pill_rect, Color(0.4, 0.5, 0.6, 0.4), false, 1.0)
		var name_text_pos = Vector2(center_pos.x - name_size.x * 0.5, pill_rect.position.y + name_size.y - 1.0 * s)
		map_canvas.draw_string(font, name_text_pos, name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, name_font_size, Color(0.95, 0.95, 0.95))

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	var dir = (to - from)
	var dist = dir.length()
	if dist <= 0.001:
		return
	var norm = dir / dist
	var curr = 0.0
	while curr < dist:
		var end_p = min(curr + dash_len, dist)
		map_canvas.draw_line(from + norm * curr, from + norm * end_p, color, width)
		curr += dash_len + gap_len

func _get_territory_continent(t_id: int) -> int:
	for c in CONTINENTS_DATA:
		if c["territories"].has(t_id):
			return c["id"]
	return 0

func _on_map_canvas_gui_input(event: InputEvent) -> void:
	var trans = _get_map_transform()

	if event is InputEventMouseMotion:
		var mouse_map = _from_screen(event.position, trans)
		var found_t = -1
		for i in range(30):
			if Geometry2D.is_point_in_polygon(mouse_map, TERRITORY_POLYGONS[i]):
				found_t = i
				break
			elif TERRITORY_CENTERS[i].distance_to(mouse_map) <= 25.0:
				found_t = i
				break
		if found_t != hovered_territory:
			hovered_territory = found_t
			map_canvas.queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_map = _from_screen(event.position, trans)
		for i in range(30):
			if Geometry2D.is_point_in_polygon(mouse_map, TERRITORY_POLYGONS[i]) or TERRITORY_CENTERS[i].distance_to(mouse_map) <= 25.0:
				_on_territory_clicked(i)
				break

func _on_territory_clicked(t_id: int) -> void:
	var t_owner = territory_owners.get(t_id, 0)
	var armies = territory_armies.get(t_id, 0)

	if current_phase == "PlaceArmies" or current_phase.begins_with("PlaceArmies") or current_phase == "Placement":
		if t_owner == current_player_id:
			selected_from = t_id
			selected_to = -1
			valid_targets.clear()
			action_info_label.text = "Seleccionado: %s (%d tropas). Haz click en '+1 Tropa' para colocar." % [
				TERRITORY_NAMES[t_id], armies
			]
		else:
			action_info_label.text = "%s no te pertenece (dueño: Jugador %d)." % [TERRITORY_NAMES[t_id], t_owner]

	elif current_phase == "Attack":
		if selected_from == -1:
			if t_owner == current_player_id:
				if armies > 1:
					selected_from = t_id
					_calculate_valid_attack_targets(t_id)
					action_info_label.text = "Atacando desde: %s (%d tropas). Elige un territorio enemigo adyacente." % [
						TERRITORY_NAMES[t_id], armies
					]
				else:
					action_info_label.text = "%s solo tiene 1 ejército (se necesitan >1 para atacar)." % TERRITORY_NAMES[t_id]
			else:
				action_info_label.text = "Debes seleccionar uno de tus territorios con al menos 2 ejércitos."
		else:
			if t_owner == current_player_id:
				# Switch attacking origin
				if armies > 1:
					selected_from = t_id
					_calculate_valid_attack_targets(t_id)
					selected_to = -1
					action_info_label.text = "Cambiado origen a: %s. Elige objetivo enemigo." % TERRITORY_NAMES[t_id]
				else:
					action_info_label.text = "%s solo tiene 1 ejército." % TERRITORY_NAMES[t_id]
			elif valid_targets.has(t_id):
				selected_to = t_id
				var max_dice = min(3, territory_armies.get(selected_from, 1) - 1)
				attack_dice_spinbox.max_value = max_dice
				attack_dice_spinbox.value = max_dice
				action_info_label.text = "Listo para atacar: %s ⚔️ %s (%d tropas enemigas). Dados: %d." % [
					TERRITORY_NAMES[selected_from], TERRITORY_NAMES[selected_to], armies, max_dice
				]
			else:
				action_info_label.text = "%s no es adyacente o no es un objetivo válido." % TERRITORY_NAMES[t_id]

	elif current_phase == "Fortify":
		if selected_from == -1:
			if t_owner == current_player_id:
				if armies > 1:
					selected_from = t_id
					_calculate_valid_fortify_targets(t_id)
					fortify_armies_spinbox.max_value = armies - 1
					fortify_armies_spinbox.value = 1
					action_info_label.text = "Fortificando desde: %s (%d tropas). Selecciona territorio destino propio." % [
						TERRITORY_NAMES[t_id], armies
					]
				else:
					action_info_label.text = "%s no tiene tropas sobrantes para mover." % TERRITORY_NAMES[t_id]
			else:
				action_info_label.text = "Selecciona un territorio propio."
		else:
			if valid_targets.has(t_id):
				selected_to = t_id
				action_info_label.text = "Mover tropas de %s ➡️ %s. Selecciona cantidad y presiona Fortificar." % [
					TERRITORY_NAMES[selected_from], TERRITORY_NAMES[selected_to]
				]
			elif t_owner == current_player_id:
				selected_from = t_id
				_calculate_valid_fortify_targets(t_id)
				selected_to = -1

	map_canvas.queue_redraw()

func _calculate_valid_attack_targets(from_id: int) -> void:
	valid_targets.clear()
	for edge in ADJACENCIES:
		var other = -1
		if edge[0] == from_id:
			other = edge[1]
		elif edge[1] == from_id:
			other = edge[0]
		if other != -1:
			if territory_owners.get(other, 0) != current_player_id:
				valid_targets.append(other)

func _calculate_valid_fortify_targets(from_id: int) -> void:
	valid_targets.clear()
	for edge in ADJACENCIES:
		var other = -1
		if edge[0] == from_id:
			other = edge[1]
		elif edge[1] == from_id:
			other = edge[0]
		if other != -1:
			if territory_owners.get(other, 0) == current_player_id:
				valid_targets.append(other)

# -------------------------------------------------------------------------
# GAME ACTIONS (Place, Attack, Fortify, EndPhase, Exchange)
# -------------------------------------------------------------------------
func _on_btn_place_pressed() -> void:
	_place_armies(1)

func _place_armies(count: int) -> void:
	var target_t = selected_from
	if target_t == -1 or territory_owners.get(target_t, 0) != current_player_id:
		for t in territory_owners:
			if territory_owners[t] == current_player_id:
				target_t = t
				break
	if target_t != -1:
		var place_count = max(1, count)
		if armies_remaining_to_place > 0:
			place_count = min(place_count, armies_remaining_to_place)
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "PlaceArmiesCommand",
			"player": current_player_id,
			"territory": target_t,
			"count": place_count
		}))

func _on_btn_attack_pressed() -> void:
	if selected_from != -1 and selected_to != -1:
		var dice_count = int(attack_dice_spinbox.value)
		# 1. Declare Attack
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "DeclareAttackCommand",
			"player": current_player_id,
			"from": selected_from,
			"to": selected_to,
			"dice": dice_count
		}))
		# 2. Roll Attack
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "RollAttackCommand",
			"player": current_player_id
		}))
	else:
		# Fallback general attack roll
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "RollAttackCommand",
			"player": current_player_id
		}))

func _on_btn_fortify_pressed() -> void:
	if selected_from != -1 and selected_to != -1:
		var armies_to_move = int(fortify_armies_spinbox.value)
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "FortifyCommand",
			"player": current_player_id,
			"from": selected_from,
			"to": selected_to,
			"armies": armies_to_move
		}))
		selected_from = -1
		selected_to = -1
		valid_targets.clear()
		if map_canvas:
			map_canvas.queue_redraw()

func _on_btn_end_phase_pressed() -> void:
	selected_from = -1
	selected_to = -1
	valid_targets.clear()
	bridge.send_command_json(current_player_id, JSON.stringify({
		"command_type": "EndPhaseCommand",
		"player": current_player_id
	}))

func _on_btn_exchange_pressed() -> void:
	if selected_card_indices.size() == 3:
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "ExchangeCardsCommand",
			"player": current_player_id,
			"card_indices": selected_card_indices
		}))
		# Remove exchanged cards locally
		var cards = player_cards.get(current_player_id, [])
		var sorted_idxs = selected_card_indices.duplicate()
		sorted_idxs.sort()
		sorted_idxs.reverse()
		for idx in sorted_idxs:
			if idx < cards.size():
				cards.remove_at(idx)
		selected_card_indices.clear()
		_render_cards_deck()
		_update_ui_state()

# -------------------------------------------------------------------------
# STATE SYNCHRONIZATION & BRIDGE SIGNALS
# -------------------------------------------------------------------------
func _sync_all_from_bridge() -> void:
	current_player_id = bridge.current_player()
	
	if bridge.has_method("get_crisis_territory_owner"):
		for i in range(30):
			var o = bridge.call("get_crisis_territory_owner", i)
			var a = bridge.call("get_crisis_territory_armies", i)
			territory_owners[i] = o
			territory_armies[i] = a
			_update_territory_label(i)

	if bridge.has_method("get_crisis_remaining_armies"):
		armies_remaining_to_place = bridge.call("get_crisis_remaining_armies")

	if bridge.has_method("get_crisis_turn_phase"):
		var ph_str = bridge.call("get_crisis_turn_phase")
		if ph_str != "":
			current_phase = ph_str

	_render_cards_deck()
	_update_objective_progress()
	if map_canvas:
		map_canvas.queue_redraw()

func _update_ui_state() -> void:
	current_player_id = bridge.current_player()
	var is_active = (winner == -1)

	var is_placement = current_phase == "PlaceArmies" or current_phase.begins_with("PlaceArmies") or current_phase == "Placement"
	var is_attack = current_phase == "Attack"
	var is_fortify = current_phase == "Fortify"

	btn_place.disabled = not (is_active and is_placement)
	btn_place_5.disabled = not (is_active and is_placement and armies_remaining_to_place >= 5)
	btn_place_all.disabled = not (is_active and is_placement and armies_remaining_to_place > 0)
	btn_attack.disabled = not (is_active and is_attack)
	btn_fortify.disabled = not (is_active and is_fortify)
	btn_end_phase.disabled = not is_active
	btn_exchange.disabled = not (is_active and is_placement and selected_card_indices.size() == 3)

	var p1_count: int = 0
	var p2_count: int = 0
	for t_id in territory_owners:
		if territory_owners[t_id] == 1:
			p1_count += 1
		elif territory_owners[t_id] == 2:
			p2_count += 1

	player_stats_label.text = "Turno: %s\nFase: %s %s\n\n🛡️ Tropas / Territorios:\n• P1 (Rojo): %d territorios\n• P2 (Azul): %d territorios" % [
		PLAYER_NAMES.get(current_player_id, "Jugador " + str(current_player_id)),
		current_phase,
		("(%d tropas restantes)" % armies_remaining_to_place) if is_placement and armies_remaining_to_place > 0 else "",
		p1_count,
		p2_count
	]

	if status_label:
		if winner != -1:
			status_label.text = "¡Partida Finalizada! Ganador: %s" % PLAYER_NAMES.get(winner, "Jugador " + str(winner))
		else:
			status_label.text = "Turno %s — Fase %s" % [PLAYER_NAMES.get(current_player_id, "P" + str(current_player_id)), current_phase]

	if turn_indicator:
		turn_indicator.set_current_player(current_player_id)

	_update_objective_progress()
	if map_canvas:
		map_canvas.queue_redraw()

func _update_territory_label(t_id: int) -> void:
	if not territory_labels.has(t_id):
		return
	var lbl: Label = territory_labels[t_id]
	var t_owner: int = territory_owners.get(t_id, 0)
	var armies: int = territory_armies.get(t_id, 0)
	lbl.text = "%s\n[P%d: %d]" % [TERRITORY_NAMES[t_id], t_owner, armies]

func _on_armies_placed(player_id: int, territory_id: int, count: int, remaining: int) -> void:
	territory_owners[territory_id] = player_id
	territory_armies[territory_id] = territory_armies.get(territory_id, 0) + count
	armies_remaining_to_place = remaining
	_update_territory_label(territory_id)
	_update_ui_state()

func _on_attack_resolved(from_id: int, to_id: int, attacker_rolls: Array, defender_rolls: Array, attacker_losses: int, defender_losses: int) -> void:
	var att_str = " ".join(attacker_rolls.map(func(r): return "🎲" + str(r)))
	var def_str = " ".join(defender_rolls.map(func(r): return "🎲" + str(r)))

	dice_label.text = "Ataque: %s ⚔️ %s\nAtacante: [%s] (-%d tropas)\nDefensor: [%s] (-%d tropas)" % [
		TERRITORY_NAMES[from_id], TERRITORY_NAMES[to_id], att_str, attacker_losses, def_str, defender_losses
	]
	if dice_widget != null and attacker_rolls.size() > 0:
		dice_widget.show_roll(attacker_rolls)
	dice_popup.popup_centered()
	_update_ui_state()

func _on_territory_conquered(player_id: int, territory_id: int, _from_armies: int, to_armies: int) -> void:
	territory_owners[territory_id] = player_id
	territory_armies[territory_id] = to_armies
	_update_territory_label(territory_id)

	# Draw a random card upon conquest
	var random_type = randi() % 3
	var cards = player_cards.get(player_id, [])
	cards.append({ "territory": territory_id, "card_type": random_type })
	player_cards[player_id] = cards
	_render_cards_deck()

	_update_ui_state()

func _on_player_eliminated(player_id: int, by_player_id: int) -> void:
	action_info_label.text = "💀 ¡El Jugador %d fue eliminado por el Jugador %d!" % [player_id, by_player_id]
	_update_ui_state()

func _on_phase_changed(player_id: int, new_phase: String) -> void:
	current_player_id = player_id
	current_phase = new_phase
	selected_from = -1
	selected_to = -1
	valid_targets.clear()
	_update_ui_state()

func _on_turn_changed(player_id: int) -> void:
	current_player_id = player_id
	selected_from = -1
	selected_to = -1
	valid_targets.clear()
	_render_cards_deck()
	_update_ui_state()

func _on_cards_exchanged(player_id: int, armies_gained: int) -> void:
	exchange_count += 1
	action_info_label.text = "🎉 ¡Jugador %d canjeó tarjetas y obtuvo +%d ejércitos!" % [player_id, armies_gained]
	_render_cards_deck()
	_update_ui_state()

func _on_crisis_game_over(winner_id: int, _objective: String) -> void:
	winner = winner_id
	_update_ui_state()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(winner_id)

func _on_game_over(w: int) -> void:
	_sfx_victory_fanfare()
	winner = w
	_update_ui_state()

func _on_move_rejected(reason: String) -> void:
	_sfx_error_buzz()
	action_info_label.text = "⚠️ Acción no permitida: %s" % reason
	if status_label:
		status_label.text = "Inválido: %s" % reason

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var evt = parser.data
		if evt is Dictionary and evt.has("command_type"):
			if evt["command_type"] == "PhaseChangedEvent":
				current_phase = evt.get("new_phase", current_phase)
	_update_ui_state()

# -------------------------------------------------------------------------
# CARDS & OBJECTIVE UI VISUALIZATION (Point d)
# -------------------------------------------------------------------------
func _render_cards_deck() -> void:
	if not cards_container:
		return
	for child in cards_container.get_children():
		child.queue_free()

	var cards = player_cards.get(current_player_id, [])
	for idx in range(cards.size()):
		var card = cards[idx]
		var t_id = card.get("territory", 0)
		var c_type = card.get("card_type", 0)
		var type_info = CARD_TYPES.get(c_type, { "name": "Infantería", "icon": "🪖" })

		var card_btn = Button.new()
		card_btn.custom_minimum_size = Vector2(85, 110)
		card_btn.toggle_mode = true
		card_btn.button_pressed = selected_card_indices.has(idx)

		var card_vbox = VBoxContainer.new()
		card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_btn.add_child(card_vbox)

		var icon_lbl = Label.new()
		icon_lbl.text = type_info["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 24)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(icon_lbl)

		var type_lbl = Label.new()
		type_lbl.text = type_info["name"]
		type_lbl.add_theme_font_size_override("font_size", 10)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(type_lbl)

		var terr_lbl = Label.new()
		terr_lbl.text = TERRITORY_NAMES[t_id] if t_id < TERRITORY_NAMES.size() else "Territorio"
		terr_lbl.add_theme_font_size_override("font_size", 10)
		terr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		terr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(terr_lbl)

		var c_idx = idx
		card_btn.toggled.connect(func(pressed: bool): _on_card_toggled(c_idx, pressed))
		cards_container.add_child(card_btn)

	var next_bonus = _get_next_exchange_bonus()
	btn_exchange.text = "🔄 Canjear Tarjetas (+%d Tropas)" % next_bonus

func _on_card_toggled(idx: int, pressed: bool) -> void:
	if pressed:
		if not selected_card_indices.has(idx):
			if selected_card_indices.size() < 3:
				selected_card_indices.append(idx)
			else:
				selected_card_indices[2] = idx
	else:
		selected_card_indices.erase(idx)

	_validate_selected_card_combination()
	_render_cards_deck()
	_update_ui_state()

func _validate_selected_card_combination() -> void:
	var cards = player_cards.get(current_player_id, [])
	if selected_card_indices.size() == 3:
		var t1 = cards[selected_card_indices[0]].get("card_type", 0)
		var t2 = cards[selected_card_indices[1]].get("card_type", 0)
		var t3 = cards[selected_card_indices[2]].get("card_type", 0)
		var has_wild = (t1 == 3 or t2 == 3 or t3 == 3)
		var three_same = (t1 == t2 and t2 == t3)
		var one_of_each = (t1 != t2 and t2 != t3 and t1 != t3)

		if has_wild or three_same or one_of_each:
			cards_info_label.text = "✅ ¡Combinación Válida! (+%d tropas al canjear)" % _get_next_exchange_bonus()
			cards_info_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
			btn_exchange.disabled = false
		else:
			cards_info_label.text = "❌ Combinación no válida. Deben ser 3 del mismo tipo o 1 de cada uno."
			cards_info_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
			btn_exchange.disabled = true
	else:
		cards_info_label.text = "Selecciona 3 tarjetas (%d/3 seleccionadas)." % selected_card_indices.size()
		cards_info_label.remove_theme_color_override("font_color")
		btn_exchange.disabled = true

func _get_next_exchange_bonus() -> int:
	match exchange_count:
		0: return 4
		1: return 6
		2: return 8
		_: return 8 + (exchange_count - 2) * 5

func _update_objective_progress() -> void:
	var obj = player_objectives.get(current_player_id, player_objectives.get(1, {}))
	if not obj:
		return

	objective_title_label.text = obj.get("title", "Misión Secreta")
	objective_desc_label.text = obj.get("desc", "")

	var owned_count = 0
	for t in territory_owners:
		if territory_owners[t] == current_player_id:
			owned_count += 1

	if obj.get("target_type") == "continents":
		var target_conts = obj.get("continents", [])
		var complete_conts = 0
		var total_conts = target_conts.size()
		for c_id in target_conts:
			var cont_terrs = CONTINENTS_DATA[c_id]["territories"]
			var all_owned = true
			for tid in cont_terrs:
				if territory_owners.get(tid, 0) != current_player_id:
					all_owned = false
					break
			if all_owned:
				complete_conts += 1
		objective_progress_bar.max_value = total_conts
		objective_progress_bar.value = complete_conts
		objective_progress_label.text = "%d / %d continentes dominados" % [complete_conts, total_conts]
	else:
		var target_num = obj.get("target_count", 24)
		objective_progress_bar.max_value = target_num
		objective_progress_bar.value = min(owned_count, target_num)
		objective_progress_label.text = "%d / %d territorios conquistados (%d%%)" % [
			owned_count, target_num, int(float(owned_count) / float(target_num) * 100.0)
		]

# --- Conexión de eventos sonoros procedurales (AudioManager) ---
func _sfx_piece_slide() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_piece_slide()

func _sfx_piece_place() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_piece_place()

func _sfx_capture(world_pos: Vector2 = Vector2(240, 240)) -> void:
	if has_node("/root/AudioManager"):
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
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_dice_roll()

func _sfx_card_flip() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_card_flip()

func _sfx_check_alert() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_check_alert()

func _sfx_victory_fanfare() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_victory_fanfare()

func _sfx_error_buzz() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_error_buzz()
