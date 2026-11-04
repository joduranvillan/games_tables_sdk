# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Node2D

const P1 = 1
const P2 = 2
const TOTAL_SPACES = 40

# Color definitions for property groups
const GROUP_COLORS = {
	"Marrón": Color("#8B4513"),
	"Celeste": Color("#5DADE2"),
	"Rosa": Color("#EC407A"),
	"Naranja": Color("#FF9800"),
	"Rojo": Color("#E53935"),
	"Amarillo": Color("#FBC02D"),
	"Verde": Color("#2E7D32"),
	"Azul Oscuro": Color("#1565C0"),
	"Ferrocarril": Color("#37474F"),
	"Suministros": Color("#F57F17"),
	"Impuesto": Color("#607D8B"),
	"Especial": Color("#455A64")
}

# 40 official board spaces definitions matching open_table engine
const SPACES = [
	# 0: GO
	{"name": "SALIDA", "short": "SALIDA", "group": "Especial", "price": 0, "rent": 0, "icon": "🏁", "desc": "Cobra $200 al pasar"},
	# 1..3: Marrón
	{"name": "Av. Mediterráneo", "short": "Mediter.", "group": "Marrón", "price": 60, "rent": 2, "icon": "🏠", "desc": "Propiedad Marrón"},
	{"name": "Arca Comunal", "short": "Arca", "group": "Especial", "price": 0, "rent": 0, "icon": "🎁", "desc": "Toma una carta de Arca Comunal"},
	{"name": "Av. Báltica", "short": "Báltica", "group": "Marrón", "price": 60, "rent": 4, "icon": "🏠", "desc": "Propiedad Marrón"},
	# 4: Impuesto Renta
	{"name": "Imp. sobre la Renta", "short": "Imp. $200", "group": "Impuesto", "price": 0, "rent": 200, "icon": "💸", "desc": "Paga $200 al Banco"},
	# 5: Ferrocarril Reading
	{"name": "Ferrocarril Reading", "short": "FC Reading", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren ($25-$200 según estaciones)"},
	# 6..9: Celeste
	{"name": "Av. Oriental", "short": "Oriental", "group": "Celeste", "price": 100, "rent": 6, "icon": "🏠", "desc": "Propiedad Celeste"},
	{"name": "Suerte", "short": "Suerte", "group": "Especial", "price": 0, "rent": 0, "icon": "❓", "desc": "Toma una carta de Suerte"},
	{"name": "Av. Vermont", "short": "Vermont", "group": "Celeste", "price": 100, "rent": 6, "icon": "🏠", "desc": "Propiedad Celeste"},
	{"name": "Av. Connecticut", "short": "Connect.", "group": "Celeste", "price": 120, "rent": 8, "icon": "🏠", "desc": "Propiedad Celeste"},
	# 10: Cárcel / Solo Visita
	{"name": "CÁRCEL / VISITA", "short": "CÁRCEL", "group": "Especial", "price": 0, "rent": 0, "icon": "🔒", "desc": "Solo Visita o En Prisión (Fianza $50)"},
	# 11..14: Rosa + Compañía Eléctrica
	{"name": "Plaza San Carlos", "short": "S. Carlos", "group": "Rosa", "price": 140, "rent": 10, "icon": "🏠", "desc": "Propiedad Rosa"},
	{"name": "Cía. Eléctrica", "short": "Eléctrica", "group": "Suministros", "price": 150, "rent": 10, "icon": "💡", "desc": "Servicio Público (x4 o x10 dados)"},
	{"name": "Av. Estados", "short": "Estados", "group": "Rosa", "price": 140, "rent": 10, "icon": "🏠", "desc": "Propiedad Rosa"},
	{"name": "Av. Virginia", "short": "Virginia", "group": "Rosa", "price": 160, "rent": 12, "icon": "🏠", "desc": "Propiedad Rosa"},
	# 15: Ferrocarril Pennsylvania
	{"name": "Ferrocarril Pennsylvania", "short": "FC Penns.", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren ($25-$200 según estaciones)"},
	# 16..19: Naranja
	{"name": "Plaza St. James", "short": "St. James", "group": "Naranja", "price": 180, "rent": 14, "icon": "🏠", "desc": "Propiedad Naranja"},
	{"name": "Arca Comunal", "short": "Arca", "group": "Especial", "price": 0, "rent": 0, "icon": "🎁", "desc": "Toma una carta de Arca Comunal"},
	{"name": "Av. Tennessee", "short": "Tennessee", "group": "Naranja", "price": 180, "rent": 14, "icon": "🏠", "desc": "Propiedad Naranja"},
	{"name": "Av. Nueva York", "short": "N. York", "group": "Naranja", "price": 200, "rent": 16, "icon": "🏠", "desc": "Propiedad Naranja"},
	# 20: Parking Gratuito
	{"name": "PARKING GRATIS", "short": "PARKING", "group": "Especial", "price": 0, "rent": 0, "icon": "🅿️", "desc": "Zona de descanso libre de pagos"},
	# 21..24: Rojo
	{"name": "Av. Kentucky", "short": "Kentucky", "group": "Rojo", "price": 220, "rent": 18, "icon": "🏠", "desc": "Propiedad Roja"},
	{"name": "Suerte", "short": "Suerte", "group": "Especial", "price": 0, "rent": 0, "icon": "❓", "desc": "Toma una carta de Suerte"},
	{"name": "Av. Indiana", "short": "Indiana", "group": "Rojo", "price": 220, "rent": 18, "icon": "🏠", "desc": "Propiedad Roja"},
	{"name": "Av. Illinois", "short": "Illinois", "group": "Rojo", "price": 240, "rent": 20, "icon": "🏠", "desc": "Propiedad Roja"},
	# 25: Ferrocarril B. & O.
	{"name": "Ferrocarril B. & O.", "short": "FC B.&O.", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren ($25-$200 según estaciones)"},
	# 26..29: Amarillo + Planta de Agua
	{"name": "Av. Atlántico", "short": "Atlántico", "group": "Amarillo", "price": 260, "rent": 22, "icon": "🏠", "desc": "Propiedad Amarilla"},
	{"name": "Av. Ventnor", "short": "Ventnor", "group": "Amarillo", "price": 260, "rent": 22, "icon": "🏠", "desc": "Propiedad Amarilla"},
	{"name": "Planta de Agua", "short": "Agua", "group": "Suministros", "price": 150, "rent": 10, "icon": "🚰", "desc": "Servicio Público (x4 o x10 dados)"},
	{"name": "Jardines Marvin", "short": "Marvin", "group": "Amarillo", "price": 280, "rent": 24, "icon": "🏠", "desc": "Propiedad Amarilla"},
	# 30: Ve a la Cárcel
	{"name": "VAYA A LA CÁRCEL", "short": "A CÁRCEL", "group": "Especial", "price": 0, "rent": 0, "icon": "🚔", "desc": "Envía tu ficha directo a la Cárcel"},
	# 31..34: Verde
	{"name": "Av. Pacífico", "short": "Pacífico", "group": "Verde", "price": 300, "rent": 26, "icon": "🏠", "desc": "Propiedad Verde"},
	{"name": "Av. Carolina Norte", "short": "Carolina", "group": "Verde", "price": 300, "rent": 26, "icon": "🏠", "desc": "Propiedad Verde"},
	{"name": "Arca Comunal", "short": "Arca", "group": "Especial", "price": 0, "rent": 0, "icon": "🎁", "desc": "Toma una carta de Arca Comunal"},
	{"name": "Av. Pennsylvania", "short": "Pennsylv.", "group": "Verde", "price": 320, "rent": 28, "icon": "🏠", "desc": "Propiedad Verde"},
	# 35: Ferrocarril Short Line
	{"name": "Ferrocarril Short Line", "short": "FC Short", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren ($25-$200 según estaciones)"},
	# 36..39: Suerte, Azul Oscuro, Impuesto de Lujo
	{"name": "Suerte", "short": "Suerte", "group": "Especial", "price": 0, "rent": 0, "icon": "❓", "desc": "Toma una carta de Suerte"},
	{"name": "Plaza Park", "short": "Park Pl.", "group": "Azul Oscuro", "price": 350, "rent": 35, "icon": "🏠", "desc": "Propiedad Azul Oscuro"},
	{"name": "Impuesto de Lujo", "short": "Lujo $100", "group": "Impuesto", "price": 0, "rent": 100, "icon": "💎", "desc": "Paga $100 al Banco"},
	{"name": "Paseo Tablado", "short": "Tablado", "group": "Azul Oscuro", "price": 400, "rent": 50, "icon": "🏠", "desc": "Propiedad Azul Oscuro"}
]

const PLAYER_COLORS = {
	1: Color("#E53935"), # Red
	2: Color("#1E88E5")  # Blue
}

var bridge
var current = P1
var winner = -1
var is_vs_ai: bool = false
var local_player: int = P1

# Game State
var positions = {P1: 0, P2: 0}
var money = {P1: 1500, P2: 1500}
var property_owners = {} # space_idx -> player_id
var property_houses = {} # space_idx -> count (1..4 houses, 5 = hotel)
var jailed_players = {P1: 0, P2: 0}
var selected_space: int = 0

var last_dice_1: int = 1
var last_dice_2: int = 1
var last_roll_doubles: bool = false
var pending_buy_space: int = -1
var current_screen_layout: int = 0

# Board Geometry
var board_rect: Rect2 = Rect2(16, 48, 430, 430)
var corner_size: float = 54.0
var space_step: float = 35.78

# UI Containers
var top_bar: HBoxContainer
var title_lbl: Label
var control_dashboard: PanelContainer
var dashboard_vbox: VBoxContainer
var players_hud_hbox: BoxContainer
var simple_turn_banner: PanelContainer
var simple_turn_lbl: Label
var mode_option_button: OptionButton = null

# UI Components
var player_tokens = {P1: null, P2: null}
var roll_button: Button
var pay_jail_btn: Button
var card_event_banner: PanelContainer
var card_event_label: Label

# Space Inspector UI (tapping any space shows full details & context actions)
var space_inspector_panel: PanelContainer
var inspector_header_bar: ColorRect
var inspector_title_lbl: Label
var inspector_status_lbl: Label
var inspector_rent_lbl: Label

# Property Management & Trade UI
var mortgaged_properties: Array = []
var active_trade_offer: Dictionary = {}
var property_mgmt_panel: PanelContainer
var mgmt_btns_grid: GridContainer
var build_house_btn: Button
var mortgage_btn: Button
var trade_btn: Button
var accept_trade_btn: Button
var reject_trade_btn: Button

# Purchase Dialog
var buy_modal: PanelContainer
var buy_header_bar: ColorRect
var buy_title_lbl: Label
var buy_price_lbl: Label
var buy_rent_info_lbl: Label
var buy_btn_confirm: Button
var buy_btn_auction: Button

# Auction Dialog
var auction_modal: PanelContainer
var auction_title_lbl: Label
var auction_current_bid_lbl: Label
var auction_bid_input: SpinBox
var auction_btn_bid: Button
var auction_btn_pass: Button
var current_auction_space: int = -1
var current_auction_bid: int = 0
var highest_bidder: int = 0

# Center & Player HUDs
var center_panel: Panel
var logo_lbl: Label
var p1_hud: PanelContainer
var p1_money_lbl: Label
var p1_props_lbl: Label
var p1_pos_lbl: Label
var p2_hud: PanelContainer
var p2_money_lbl: Label
var p2_props_lbl: Label
var p2_pos_lbl: Label
var dice_display_lbl: Label
var dice_widget: DiceWidget

var turn_indicator: TurnIndicator
var rules_popup: RulesPopup
var current_theme: BoardTheme
var _pause_menu: CanvasLayer

@onready var status: Label = get_node_or_null("Status") if has_node("Status") else null

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)
	else:
		_create_default_theme()

	_setup_ui()

	var gm = (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)
	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)

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
	if bridge.has_signal("turn_changed"):
		bridge.connect("turn_changed", _on_turn_changed)

	var is_ai_mode = (gm != null and gm.has_method("get_game_mode") and gm.get_game_mode() == "vs_ai")
	if is_ai_mode:
		var human_p = gm.get_human_player_id() if gm.has_method("get_human_player_id") else P1
		var ai_p = P2 if human_p == P1 else P1
		var diff = gm.get_ai_difficulty() if gm.has_method("get_ai_difficulty") else 1
		is_vs_ai = true
		local_player = human_p
		bridge.start_local_match_monopoly_vs_ai(human_p, ai_p, diff)
	else:
		is_vs_ai = false
		local_player = P1
		bridge.start_local_match_monopoly(P1, P2)
	current = bridge.current_player()

	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_token_positions()
	_update_hud_display()
	_update_space_inspector(selected_space)
	_update_status()
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

func _on_mode_selected(index: int) -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	winner = -1
	positions = {P1: 0, P2: 0}
	money = {P1: 1500, P2: 1500}
	property_owners.clear()
	property_houses.clear()
	mortgaged_properties.clear()
	jailed_players = {P1: 0, P2: 0}
	if buy_modal != null:
		buy_modal.visible = false
	if auction_modal != null:
		auction_modal.visible = false
	if index == 0:
		if gm != null and gm.has_method("set_game_mode"):
			gm.set_game_mode("local")
		is_vs_ai = false
		local_player = P1
		bridge.start_local_match_monopoly(P1, P2)
	else:
		var human_p = P1 if index == 1 else P2
		var ai_p = P2 if human_p == P1 else P1
		var diff = gm.get_ai_difficulty() if (gm != null and gm.has_method("get_ai_difficulty")) else 1
		if gm != null and gm.has_method("set_game_mode"):
			gm.set_game_mode("vs_ai")
		if gm != null and gm.has_method("set_human_player_id"):
			gm.set_human_player_id(human_p)
		is_vs_ai = true
		local_player = human_p
		bridge.start_local_match_monopoly_vs_ai(human_p, ai_p, diff)
	current = bridge.current_player()
	_update_token_positions()
	_update_hud_display()
	_update_space_inspector(selected_space)
	_update_status()
	queue_redraw()

func _create_default_theme() -> void:
	current_theme = BoardTheme.new()
	current_theme.theme_name = "Monopoly Clásico"
	current_theme.board_color = Color("#0D1B2A")
	current_theme.line_color = Color("#415A77")
	current_theme.light_color = Color("#E0E1DD")
	current_theme.dark_color = Color("#1B263B")
	current_theme.select_color = Color(1.0, 0.85, 0.25, 0.85)
	current_theme.valid_move_color = Color(0.2, 0.9, 0.5, 0.85)

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	_apply_theme_styling()
	queue_redraw()

func _apply_theme_styling() -> void:
	if current_theme == null:
		return

	if center_panel:
		var c_style = StyleBoxFlat.new()
		c_style.bg_color = current_theme.dark_color.darkened(0.18)
		c_style.border_color = current_theme.line_color.lightened(0.1)
		c_style.set_border_width_all(2)
		c_style.set_corner_radius_all(8)
		center_panel.add_theme_stylebox_override("panel", c_style)

	if control_dashboard:
		var d_style = StyleBoxFlat.new()
		d_style.bg_color = current_theme.dark_color.darkened(0.28)
		d_style.border_color = current_theme.line_color
		d_style.set_border_width_all(2)
		d_style.set_corner_radius_all(10)
		d_style.content_margin_left = 8
		d_style.content_margin_right = 8
		d_style.content_margin_top = 8
		d_style.content_margin_bottom = 8
		control_dashboard.add_theme_stylebox_override("panel", d_style)

func _setup_ui() -> void:
	# 1. Compact Header Bar aligned above the board
	top_bar = HBoxContainer.new()
	top_bar.name = "BoardHeaderBar"
	top_bar.position = Vector2(16, 8)
	top_bar.size = Vector2(430, 34)
	top_bar.add_theme_constant_override("separation", 8)
	add_child(top_bar)

	title_lbl = Label.new()
	title_lbl.text = "🎩 MONOPOLY"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(78, 30)
	btn_rules.add_theme_font_size_override("font_size", 12)
	btn_rules.visible = false
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("monopoly"))
	top_bar.add_child(btn_rules)

	var mode_opt := OptionButton.new()
	mode_opt.name = "ModeOptionButton"
	mode_option_button = mode_opt
	mode_opt.custom_minimum_size = Vector2(105, 30)
	mode_opt.add_theme_font_size_override("font_size", 12)
	mode_opt.add_item("👥 Hotseat", 0)
	mode_opt.add_item("🤖 vs IA (J1)", 1)
	mode_opt.add_item("🤖 vs IA (J2)", 2)
	var gm_ref = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm_ref != null and gm_ref.has_method("get_game_mode") and gm_ref.get_game_mode() == "vs_ai":
		var hp = gm_ref.get_human_player_id() if gm_ref.has_method("get_human_player_id") else P1
		mode_opt.selected = 1 if hp == P1 else 2
	else:
		mode_opt.selected = 0
	mode_opt.visible = false
	mode_opt.item_selected.connect(_on_mode_selected)
	top_bar.add_child(mode_opt)

	# 2. Clean Center Board Area (Logo, Dice, Event Feed, and Roll Action)
	center_panel = Panel.new()
	center_panel.name = "CenterPanel"
	center_panel.clip_contents = true
	add_child(center_panel)

	var center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_vbox.offset_left = 8
	center_vbox.offset_top = 6
	center_vbox.offset_right = -8
	center_vbox.offset_bottom = -6
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 5)
	center_panel.add_child(center_vbox)

	logo_lbl = Label.new()
	logo_lbl.text = "🎩 M O N O P O L Y"
	logo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_lbl.add_theme_font_size_override("font_size", 16)
	logo_lbl.add_theme_color_override("font_color", Color(0.95, 0.32, 0.32))
	center_vbox.add_child(logo_lbl)

	dice_display_lbl = Label.new()
	dice_display_lbl.name = "DiceDisplayLabel"
	dice_display_lbl.text = "🎲 [ ⚀ ]  [ ⚀ ]  (Total: 2)"
	dice_display_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_display_lbl.add_theme_font_size_override("font_size", 14)
	dice_display_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.8))
	center_vbox.add_child(dice_display_lbl)

	dice_widget = DiceWidget.new()
	dice_widget.name = "DiceWidget"
	dice_widget.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_vbox.add_child(dice_widget)

	card_event_banner = PanelContainer.new()
	card_event_banner.name = "EventBanner"
	card_event_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ev_style = StyleBoxFlat.new()
	ev_style.bg_color = Color(0.08, 0.16, 0.28, 0.92)
	ev_style.border_color = Color(0.3, 0.45, 0.65, 0.6)
	ev_style.set_border_width_all(1)
	ev_style.set_corner_radius_all(6)
	ev_style.content_margin_left = 6
	ev_style.content_margin_right = 6
	ev_style.content_margin_top = 4
	ev_style.content_margin_bottom = 4
	card_event_banner.add_theme_stylebox_override("panel", ev_style)

	card_event_label = Label.new()
	card_event_label.text = "¡Tira los dados o toca una casilla para ver detalles!"
	card_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_event_label.add_theme_font_size_override("font_size", 11)
	card_event_banner.add_child(card_event_label)
	center_vbox.add_child(card_event_banner)

	var actions_hbox = HBoxContainer.new()
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_hbox.add_theme_constant_override("separation", 6)
	center_vbox.add_child(actions_hbox)

	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.custom_minimum_size = Vector2(120, 34)
	roll_button.text = "🎲 Tirar Dados"
	roll_button.add_theme_font_size_override("font_size", 13)
	roll_button.pressed.connect(_on_roll_pressed)
	actions_hbox.add_child(roll_button)

	pay_jail_btn = Button.new()
	pay_jail_btn.name = "PayJailButton"
	pay_jail_btn.custom_minimum_size = Vector2(100, 34)
	pay_jail_btn.text = "🔓 Fianza $50"
	pay_jail_btn.add_theme_font_size_override("font_size", 11)
	pay_jail_btn.visible = false
	pay_jail_btn.pressed.connect(_on_pay_jail_pressed)
	actions_hbox.add_child(pay_jail_btn)

	# Keep TurnIndicator node in tree for compatibility, hidden so its Undo/Redo buttons never force horizontal overflow
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.visible = false
	add_child(turn_indicator)

	# 3. Zona Superior Centrada: Simple Turn Banner y Tarjetas de Resumen de Jugadores (J1 / J2)
	simple_turn_banner = PanelContainer.new()
	simple_turn_banner.name = "SimpleTurnBanner"
	simple_turn_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.14, 0.19, 0.28, 0.96)
	tb_style.border_color = PLAYER_COLORS[P1]
	tb_style.set_border_width_all(1)
	tb_style.set_corner_radius_all(6)
	tb_style.content_margin_left = 8
	tb_style.content_margin_right = 8
	tb_style.content_margin_top = 4
	tb_style.content_margin_bottom = 4
	simple_turn_banner.add_theme_stylebox_override("panel", tb_style)

	simple_turn_lbl = Label.new()
	simple_turn_lbl.name = "SimpleTurnLabel"
	simple_turn_lbl.text = "🎯 Turno: ▲ Jugador 1"
	simple_turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	simple_turn_lbl.add_theme_font_size_override("font_size", 12)
	simple_turn_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78))
	simple_turn_banner.add_child(simple_turn_lbl)
	top_bar.add_child(simple_turn_banner)

	# Players HUD: Horizontal 1-Line Summary Cards centered above the board
	players_hud_hbox = HBoxContainer.new()
	players_hud_hbox.name = "PlayersHudContainer"
	players_hud_hbox.add_theme_constant_override("separation", 8)
	add_child(players_hud_hbox)

	p1_hud = _create_player_hud_card(P1, "▲ J1")
	players_hud_hbox.add_child(p1_hud)

	p2_hud = _create_player_hud_card(P2, "● J2")
	players_hud_hbox.add_child(p2_hud)

	# Zona Inferior Centrada: Control Dashboard (Inspector de Casilla y Gestión de Propiedades)
	control_dashboard = PanelContainer.new()
	control_dashboard.name = "ControlDashboard"
	add_child(control_dashboard)

	dashboard_vbox = VBoxContainer.new()
	dashboard_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard_vbox.add_theme_constant_override("separation", 4)
	control_dashboard.add_child(dashboard_vbox)

	# Interactive Space Inspector Card (updates on tap/click or player movement)
	_setup_space_inspector()

	# Compact Property Management & Trade Panel
	property_mgmt_panel = PanelContainer.new()
	property_mgmt_panel.name = "PropertyManagementPanel"
	var mgmt_style = StyleBoxFlat.new()
	mgmt_style.bg_color = Color(0.11, 0.15, 0.22, 0.95)
	mgmt_style.border_color = Color(0.3, 0.4, 0.55, 0.8)
	mgmt_style.set_border_width_all(1)
	mgmt_style.set_corner_radius_all(6)
	mgmt_style.content_margin_left = 6
	mgmt_style.content_margin_right = 6
	mgmt_style.content_margin_top = 5
	mgmt_style.content_margin_bottom = 5
	property_mgmt_panel.add_theme_stylebox_override("panel", mgmt_style)
	dashboard_vbox.add_child(property_mgmt_panel)

	var mgmt_vbox = VBoxContainer.new()
	mgmt_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mgmt_vbox.add_theme_constant_override("separation", 4)
	property_mgmt_panel.add_child(mgmt_vbox)

	mgmt_btns_grid = GridContainer.new()
	mgmt_btns_grid.columns = 3
	mgmt_btns_grid.add_theme_constant_override("h_separation", 4)
	mgmt_btns_grid.add_theme_constant_override("v_separation", 4)
	mgmt_vbox.add_child(mgmt_btns_grid)

	build_house_btn = Button.new()
	build_house_btn.name = "BuildHouseButton"
	build_house_btn.text = "🏠 Casa"
	build_house_btn.tooltip_text = "Construir Casa u Hotel en grupo completo"
	build_house_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_house_btn.custom_minimum_size = Vector2(72, 28)
	build_house_btn.add_theme_font_size_override("font_size", 11)
	build_house_btn.pressed.connect(_on_build_house_pressed)
	mgmt_btns_grid.add_child(build_house_btn)

	mortgage_btn = Button.new()
	mortgage_btn.name = "MortgageButton"
	mortgage_btn.text = "🏦 Hipot."
	mortgage_btn.tooltip_text = "Hipotecar o Deshipotecar propiedad seleccionada"
	mortgage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mortgage_btn.custom_minimum_size = Vector2(72, 28)
	mortgage_btn.add_theme_font_size_override("font_size", 11)
	mortgage_btn.pressed.connect(_on_mortgage_pressed)
	mgmt_btns_grid.add_child(mortgage_btn)

	trade_btn = Button.new()
	trade_btn.name = "TradeButton"
	trade_btn.text = "🤝 Trato"
	trade_btn.tooltip_text = "Proponer intercambio al otro jugador"
	trade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade_btn.custom_minimum_size = Vector2(72, 28)
	trade_btn.add_theme_font_size_override("font_size", 11)
	trade_btn.pressed.connect(_on_trade_pressed)
	mgmt_btns_grid.add_child(trade_btn)

	var trade_resp_hbox = HBoxContainer.new()
	trade_resp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	trade_resp_hbox.add_theme_constant_override("separation", 6)
	mgmt_vbox.add_child(trade_resp_hbox)

	accept_trade_btn = Button.new()
	accept_trade_btn.name = "AcceptTradeButton"
	accept_trade_btn.text = "✅ Aceptar"
	accept_trade_btn.visible = false
	accept_trade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept_trade_btn.custom_minimum_size = Vector2(88, 26)
	accept_trade_btn.add_theme_font_size_override("font_size", 11)
	accept_trade_btn.pressed.connect(_on_accept_trade_pressed)
	trade_resp_hbox.add_child(accept_trade_btn)

	reject_trade_btn = Button.new()
	reject_trade_btn.name = "RejectTradeButton"
	reject_trade_btn.text = "❌ Rechazar"
	reject_trade_btn.visible = false
	reject_trade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reject_trade_btn.custom_minimum_size = Vector2(88, 26)
	reject_trade_btn.add_theme_font_size_override("font_size", 11)
	reject_trade_btn.pressed.connect(_on_reject_trade_pressed)
	trade_resp_hbox.add_child(reject_trade_btn)

	# 4. Player Token Sprites
	for p in [P1, P2]:
		var token = Control.new()
		token.name = "PlayerToken%d" % p
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token.size = Vector2(20, 20)
		token.pivot_offset = Vector2(10, 10)

		var img = Image.create(20, 20, false, Image.FORMAT_RGBA8)
		var p_col = _get_player_token_color(p)
		for x in range(20):
			for y in range(20):
				var dist = Vector2(x - 10, y - 10).length()
				if dist <= 7.5:
					img.set_pixel(x, y, p_col)
				elif dist <= 9.0:
					img.set_pixel(x, y, Color.WHITE)
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))

		var tex = TextureRect.new()
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.texture = ImageTexture.create_from_image(img)
		tex.size = Vector2(20, 20)
		token.add_child(tex)

		var sym_lbl = Label.new()
		sym_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sym_lbl.text = "▲" if p == P1 else "●"
		sym_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sym_lbl.add_theme_font_size_override("font_size", 9)
		sym_lbl.add_theme_color_override("font_color", Color.WHITE)
		token.add_child(sym_lbl)

		add_child(token)
		player_tokens[p] = token

	_setup_purchase_modal()
	_setup_auction_modal()

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 60)
	add_child(rules_popup)

	_apply_theme_styling()

func _setup_space_inspector() -> void:
	space_inspector_panel = PanelContainer.new()
	space_inspector_panel.name = "SpaceInspectorPanel"
	space_inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var insp_style = StyleBoxFlat.new()
	insp_style.bg_color = Color(0.10, 0.14, 0.20, 0.96)
	insp_style.border_color = Color(0.95, 0.80, 0.30, 0.85)
	insp_style.set_border_width_all(1)
	insp_style.set_corner_radius_all(6)
	insp_style.content_margin_left = 6
	insp_style.content_margin_right = 6
	insp_style.content_margin_top = 5
	insp_style.content_margin_bottom = 5
	space_inspector_panel.add_theme_stylebox_override("panel", insp_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	space_inspector_panel.add_child(vbox)

	inspector_header_bar = ColorRect.new()
	inspector_header_bar.custom_minimum_size = Vector2(0, 6)
	inspector_header_bar.color = GROUP_COLORS["Especial"]
	vbox.add_child(inspector_header_bar)

	inspector_title_lbl = Label.new()
	inspector_title_lbl.name = "InspectorTitleLabel"
	inspector_title_lbl.text = "🏁 #0 — SALIDA"
	inspector_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_title_lbl.add_theme_font_size_override("font_size", 12)
	inspector_title_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(inspector_title_lbl)

	inspector_status_lbl = Label.new()
	inspector_status_lbl.name = "InspectorStatusLabel"
	inspector_status_lbl.text = "Especial • Casilla Pública"
	inspector_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_status_lbl.add_theme_font_size_override("font_size", 10)
	inspector_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	vbox.add_child(inspector_status_lbl)

	inspector_rent_lbl = Label.new()
	inspector_rent_lbl.name = "InspectorRentLabel"
	inspector_rent_lbl.text = "Cobra $200 al pasar"
	inspector_rent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_rent_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_rent_lbl.add_theme_font_size_override("font_size", 10)
	inspector_rent_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(inspector_rent_lbl)

	dashboard_vbox.add_child(space_inspector_panel)

func select_space(space_idx: int) -> void:
	if space_idx < 0 or space_idx >= TOTAL_SPACES:
		return
	selected_space = space_idx
	_update_space_inspector(selected_space)
	queue_redraw()

func _update_space_inspector(space_idx: int) -> void:
	if space_inspector_panel == null or space_idx < 0 or space_idx >= SPACES.size():
		return
	var prop = SPACES[space_idx]
	var grp = prop["group"]
	var grp_col = _get_group_color(grp)
	inspector_header_bar.color = grp_col if grp_col != Color.TRANSPARENT else Color("#455A64")
	inspector_title_lbl.text = "%s #%d — %s" % [prop.get("icon", "📍"), space_idx, prop["name"]]

	if prop["price"] > 0:
		var owner_id = property_owners.get(space_idx, -1)
		var owner_str = "Libre ($%d)" % prop["price"]
		if owner_id != -1:
			var is_mort = mortgaged_properties.has(space_idx)
			var h_lvl = property_houses.get(space_idx, 0)
			var h_text = ""
			if h_lvl == 5:
				h_text = " | 🏨Hotel"
			elif h_lvl > 0:
				h_text = " | 🏠x%d" % h_lvl
			owner_str = "J%d%s%s" % [owner_id, " (HIP.)" if is_mort else "", h_text]
		inspector_status_lbl.text = "%s • %s" % [grp, owner_str]

		var base_r = int(prop["rent"])
		if grp == "Ferrocarril":
			inspector_rent_lbl.text = "Renta: 1-4 Est.: $25/$50/$100/$200 • Hip: $100"
		elif grp == "Suministros":
			inspector_rent_lbl.text = "Renta: 4x dados (1) | 10x dados (ambos)"
		else:
			inspector_rent_lbl.text = "Renta: $%d | Grupo $%d | Casas $%d-$%d | Hotel $%d" % [
				base_r, base_r * 2, base_r * 4, base_r * 12, base_r * 20
			]
	else:
		inspector_status_lbl.text = "Grupo: %s" % grp
		inspector_rent_lbl.text = str(prop.get("desc", "Casilla especial"))

func _unhandled_input(event: InputEvent) -> void:
	if buy_modal != null and buy_modal.visible:
		return
	if auction_modal != null and auction_modal.visible:
		return

	var click_pos: Vector2 = Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_pos = to_local(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = to_local(event.position)

	if click_pos.x >= 0.0:
		for i in range(TOTAL_SPACES):
			if _get_space_rect(i).has_point(click_pos):
				select_space(i)
				_sfx_piece_place()
				break

func _create_player_hud_card(p_id: int, p_name: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(210, 28)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.16, 0.24, 0.95)
	sb.border_color = PLAYER_COLORS[p_id]
	sb.set_border_width_all(2 if p_id == P1 else 1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", sb)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	var title = Label.new()
	title.text = p_name
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", PLAYER_COLORS[p_id].lightened(0.25))
	row.add_child(title)

	var m_lbl = Label.new()
	m_lbl.text = "💰$1500"
	m_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(m_lbl)

	var p_lbl = Label.new()
	p_lbl.text = "🏠0"
	p_lbl.add_theme_font_size_override("font_size", 11)
	p_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	row.add_child(p_lbl)

	var pos_lbl = Label.new()
	pos_lbl.text = "📍SALIDA"
	pos_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos_lbl.add_theme_font_size_override("font_size", 10)
	pos_lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 0.98))
	row.add_child(pos_lbl)

	if p_id == P1:
		p1_money_lbl = m_lbl
		p1_props_lbl = p_lbl
		p1_pos_lbl = pos_lbl
	else:
		p2_money_lbl = m_lbl
		p2_props_lbl = p_lbl
		p2_pos_lbl = pos_lbl

	return panel

# -------------------------------------------------------------------------
# TITLE DEED PURCHASE MODAL (d)
# -------------------------------------------------------------------------
func _setup_purchase_modal() -> void:
	buy_modal = PanelContainer.new()
	buy_modal.name = "BuyModal"
	buy_modal.position = Vector2(95, 160)
	buy_modal.custom_minimum_size = Vector2(280, 220)
	buy_modal.visible = false
	buy_modal.z_index = 25

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.22, 0.98)
	style.border_color = Color(0.95, 0.85, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	buy_modal.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	buy_modal.add_child(vbox)

	buy_header_bar = ColorRect.new()
	buy_header_bar.custom_minimum_size = Vector2(0, 14)
	buy_header_bar.color = Color("#8B4513")
	vbox.add_child(buy_header_bar)

	buy_title_lbl = Label.new()
	buy_title_lbl.text = "TÍTULO DE PROPIEDAD"
	buy_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_title_lbl.add_theme_font_size_override("font_size", 15)
	buy_title_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(buy_title_lbl)

	buy_price_lbl = Label.new()
	buy_price_lbl.text = "PRECIO: $200"
	buy_price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_price_lbl.add_theme_font_size_override("font_size", 13)
	buy_price_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	vbox.add_child(buy_price_lbl)

	buy_rent_info_lbl = Label.new()
	buy_rent_info_lbl.text = "Renta Base: $10\nRenta con Grupo Completo: $20\nCasa 1: $50 | Casa 2: $150 | Hotel: $450"
	buy_rent_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_rent_info_lbl.add_theme_font_size_override("font_size", 11)
	buy_rent_info_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(buy_rent_info_lbl)

	var btns_hbox = HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btns_hbox)

	buy_btn_confirm = Button.new()
	buy_btn_confirm.custom_minimum_size = Vector2(110, 34)
	buy_btn_confirm.text = "🟢 Comprar"
	buy_btn_confirm.pressed.connect(func(): _send_buy_decision(true))
	btns_hbox.add_child(buy_btn_confirm)

	buy_btn_auction = Button.new()
	buy_btn_auction.custom_minimum_size = Vector2(110, 34)
	buy_btn_auction.text = "🔨 Subastar"
	buy_btn_auction.pressed.connect(func(): _send_buy_decision(false))
	btns_hbox.add_child(buy_btn_auction)

	add_child(buy_modal)

# -------------------------------------------------------------------------
# AUCTION MODAL DIALOG (d)
# -------------------------------------------------------------------------
func _setup_auction_modal() -> void:
	auction_modal = PanelContainer.new()
	auction_modal.name = "AuctionModal"
	auction_modal.position = Vector2(95, 160)
	auction_modal.custom_minimum_size = Vector2(280, 210)
	auction_modal.visible = false
	auction_modal.z_index = 25

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.22, 0.98)
	style.border_color = Color(0.9, 0.6, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	auction_modal.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	auction_modal.add_child(vbox)

	auction_title_lbl = Label.new()
	auction_title_lbl.text = "🏛️ SUBASTA DE PROPIEDAD"
	auction_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auction_title_lbl.add_theme_font_size_override("font_size", 14)
	auction_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	vbox.add_child(auction_title_lbl)

	auction_current_bid_lbl = Label.new()
	auction_current_bid_lbl.text = "Puja actual: $0\nLíder: Ninguno"
	auction_current_bid_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auction_current_bid_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(auction_current_bid_lbl)

	var input_hbox = HBoxContainer.new()
	input_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(input_hbox)

	var lbl_bid = Label.new()
	lbl_bid.text = "Tu Oferta: $"
	lbl_bid.add_theme_font_size_override("font_size", 13)
	input_hbox.add_child(lbl_bid)

	auction_bid_input = SpinBox.new()
	auction_bid_input.min_value = 10
	auction_bid_input.max_value = 2000
	auction_bid_input.step = 10
	auction_bid_input.value = 50
	input_hbox.add_child(auction_bid_input)

	var btns_hbox = HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btns_hbox)

	auction_btn_bid = Button.new()
	auction_btn_bid.custom_minimum_size = Vector2(110, 34)
	auction_btn_bid.text = "🔨 Ofertar"
	auction_btn_bid.pressed.connect(_on_send_bid_pressed)
	btns_hbox.add_child(auction_btn_bid)

	auction_btn_pass = Button.new()
	auction_btn_pass.custom_minimum_size = Vector2(110, 34)
	auction_btn_pass.text = "❌ Pasar"
	auction_btn_pass.pressed.connect(_on_pass_bid_pressed)
	btns_hbox.add_child(auction_btn_pass)

	add_child(auction_modal)

# -------------------------------------------------------------------------
# PERIMETER COORDINATE MAPPING (a)
# -------------------------------------------------------------------------
func _get_space_rect(space_idx: int) -> Rect2:
	var idx = posmod(space_idx, 40)
	var ox = board_rect.position.x
	var oy = board_rect.position.y
	var bw = board_rect.size.x
	var bh = board_rect.size.y
	var cs = corner_size
	var step = (bw - (cs * 2.0)) / 9.0

	# Side 0: Bottom row (0..10) from Right to Left
	if idx == 0:
		return Rect2(ox + bw - cs, oy + bh - cs, cs, cs)
	elif idx < 10:
		var k = idx
		return Rect2(ox + bw - cs - (k * step), oy + bh - cs, step, cs)
	elif idx == 10:
		return Rect2(ox, oy + bh - cs, cs, cs)

	# Side 1: Left column (11..19) from Bottom to Top
	elif idx < 20:
		var k = idx - 10
		return Rect2(ox, oy + bh - cs - (k * step), cs, step)
	elif idx == 20:
		return Rect2(ox, oy, cs, cs)

	# Side 2: Top row (21..29) from Left to Right
	elif idx < 30:
		var k = idx - 20
		return Rect2(ox + cs + ((k - 1) * step), oy, step, cs)
	elif idx == 30:
		return Rect2(ox + bw - cs, oy, cs, cs)

	# Side 3: Right column (31..39) from Top to Bottom
	else:
		var k = idx - 30
		return Rect2(ox + bw - cs, oy + cs + ((k - 1) * step), cs, step)

func _get_space_center(space_idx: int) -> Vector2:
	var r = _get_space_rect(space_idx)
	return r.position + (r.size * 0.5)

func _update_token_positions() -> void:
	for p in [P1, P2]:
		if player_tokens[p] == null:
			continue
		var pos_idx = positions[p]
		var base_pos = _get_space_center(pos_idx)
		var spread = clampf(corner_size * 0.14, 5.0, 9.0)
		var offset = Vector2(-spread, -spread) if p == P1 else Vector2(spread, spread)
		player_tokens[p].position = base_pos + offset - Vector2(10, 10)

func _animate_player_move(p: int, target_space: int) -> void:
	positions[p] = target_space
	selected_space = target_space
	_update_space_inspector(selected_space)

	var base_pos = _get_space_center(target_space)
	var spread = clampf(corner_size * 0.14, 5.0, 9.0)
	var offset = Vector2(-spread, -spread) if p == P1 else Vector2(spread, spread)
	var target_pos = base_pos + offset - Vector2(10, 10)

	if dice_widget != null and dice_widget.is_rolling and is_inside_tree() and not OS.has_feature("headless"):
		await dice_widget.wait_if_rolling()

	_check_pending_purchase(p, target_space)
	if is_inside_tree():
		var tween = create_tween()
		tween.tween_property(player_tokens[p], "position", target_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func(): _check_pending_purchase(p, target_space))
	else:
		player_tokens[p].position = target_pos

func _center_modal_over_board(modal: PanelContainer) -> void:
	if modal == null:
		return
	var m_size = modal.custom_minimum_size
	var target_x = board_rect.position.x + (board_rect.size.x - m_size.x) * 0.5
	var target_y = board_rect.position.y + (board_rect.size.y - m_size.y) * 0.5
	modal.position = Vector2(maxf(8.0, target_x), maxf(48.0, target_y))

func _check_pending_purchase(p: int, space: int) -> void:
	if space < 0 or space >= SPACES.size():
		return
	if is_vs_ai and p != local_player:
		return
	var prop = SPACES[space]
	if prop["price"] > 0 and not property_owners.has(space):
		if (is_vs_ai and p == local_player) or (not is_vs_ai and p == current):
			pending_buy_space = space
			buy_title_lbl.text = prop["name"]
			buy_header_bar.color = GROUP_COLORS.get(prop["group"], Color.DARK_GRAY)
			buy_price_lbl.text = "PRECIO: $%d  (Tu saldo: $%d)" % [prop["price"], money[p]]
			var base_r = prop["rent"]
			buy_rent_info_lbl.text = "Renta Base: $%d\nRenta con Grupo Completo: $%d\nCon 1-4 Casas: $%d - $%d\nCon Hotel: $%d" % [
				base_r, base_r * 2, base_r * 4, base_r * 12, base_r * 20
			]
			buy_btn_confirm.disabled = (money[p] < prop["price"])
			_center_modal_over_board(buy_modal)
			buy_modal.visible = true

func _send_buy_decision(buy: bool) -> void:
	buy_modal.visible = false
	var cmd = {
		"command_type": "BuyPropertyCommand",
		"player": current,
		"buy": buy
	}
	bridge.send_command_json(current, JSON.stringify(cmd))
	pending_buy_space = -1

func _on_send_bid_pressed() -> void:
	var bid_val = int(auction_bid_input.value)
	var cmd = {
		"command_type": "AuctionBidCommand",
		"player": current,
		"amount": bid_val
	}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _on_pass_bid_pressed() -> void:
	var cmd = {
		"command_type": "AuctionBidCommand",
		"player": current,
		"amount": 0
	}
	bridge.send_command_json(current, JSON.stringify(cmd))
	auction_modal.visible = false

func _on_roll_pressed() -> void:
	_sfx_dice_roll()
	if winner != -1 or buy_modal.visible or auction_modal.visible:
		return
	var cmd = {"command_type": "RollAndMoveCommand", "player": current}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _on_pay_jail_pressed() -> void:
	if winner != -1:
		return
	var cmd = {"command_type": "PayJailFeeCommand", "player": current}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _can_build_on_space(space_idx: int, player_id: int) -> bool:
	if space_idx < 0 or space_idx >= SPACES.size():
		return false
	if property_owners.get(space_idx, -1) != player_id:
		return false
	var grp = SPACES[space_idx]["group"]
	if grp in ["Especial", "Ferrocarril", "Suministros", "Impuesto"]:
		return false
	for i in range(SPACES.size()):
		if SPACES[i]["group"] == grp and property_owners.get(i, -1) != player_id:
			return false
	return property_houses.get(space_idx, 0) < 5

func _on_build_house_pressed() -> void:
	if winner != -1:
		return
	var target_space: int = -1
	if _can_build_on_space(selected_space, current):
		target_space = selected_space
	else:
		for space_idx in property_owners.keys():
			if _can_build_on_space(space_idx, current):
				target_space = space_idx
				break

	if target_space != -1:
		var cmd = {
			"command_type": "BuildHouseCommand",
			"player": current,
			"space": target_space
		}
		bridge.send_command_json(current, JSON.stringify(cmd))
	else:
		if card_event_label:
			card_event_label.text = "ℹ️ Necesitas un grupo de color completo para construir casas."

func _on_mortgage_pressed() -> void:
	if winner != -1:
		return
	var target_space: int = -1
	var is_unmortgage: bool = false

	if property_owners.get(selected_space, -1) == current:
		target_space = selected_space
		is_unmortgage = mortgaged_properties.has(selected_space)
	else:
		for space_idx in property_owners.keys():
			if property_owners[space_idx] == current:
				if mortgaged_properties.has(space_idx):
					target_space = space_idx
					is_unmortgage = true
					break
				elif target_space == -1:
					target_space = space_idx

	if target_space != -1:
		var cmd_type = "UnmortgagePropertyCommand" if is_unmortgage else "MortgagePropertyCommand"
		var cmd = {
			"command_type": cmd_type,
			"player": current,
			"space": target_space
		}
		bridge.send_command_json(current, JSON.stringify(cmd))
	else:
		if card_event_label:
			card_event_label.text = "ℹ️ No tienes propiedades para hipotecar."

func _on_trade_pressed() -> void:
	if winner != -1:
		return
	var opponent = P2 if current == P1 else P1
	var offered: Array = []
	var requested: Array = []

	if property_owners.get(selected_space, -1) == current:
		offered.append(selected_space)
	elif property_owners.get(selected_space, -1) == opponent:
		requested.append(selected_space)

	for s in property_owners.keys():
		if property_owners[s] == current and offered.is_empty():
			offered.append(s)
		elif property_owners[s] == opponent and requested.is_empty():
			requested.append(s)

	var cmd = {
		"command_type": "ProposeTradeCommand",
		"player": current,
		"target": opponent,
		"offered_spaces": offered,
		"requested_spaces": requested,
		"offered_cash": 50 if money.get(current, 0) >= 50 else 0,
		"requested_cash": 0
	}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _on_accept_trade_pressed() -> void:
	if winner != -1:
		return
	var cmd = {
		"command_type": "AcceptTradeCommand",
		"player": current
	}
	bridge.send_command_json(current, JSON.stringify(cmd))
	accept_trade_btn.visible = false
	reject_trade_btn.visible = false

func _on_reject_trade_pressed() -> void:
	if winner != -1:
		return
	var cmd = {
		"command_type": "RejectTradeCommand",
		"player": current
	}
	bridge.send_command_json(current, JSON.stringify(cmd))
	accept_trade_btn.visible = false
	reject_trade_btn.visible = false

func _update_hud_display() -> void:
	var p1_count = 0
	var p2_count = 0
	for sp in property_owners:
		if property_owners[sp] == P1:
			p1_count += 1
		elif property_owners[sp] == P2:
			p2_count += 1

	# Update simple turn banner & active card border
	if simple_turn_lbl:
		var sym = "▲" if current == P1 else "●"
		simple_turn_lbl.text = "🎯 Turno: %s Jugador %d" % [sym, current]
	if simple_turn_banner:
		var tb_sb = simple_turn_banner.get_theme_stylebox("panel")
		if tb_sb is StyleBoxFlat:
			tb_sb.border_color = _get_player_token_color(current)

	if p1_hud:
		var sb1 = p1_hud.get_theme_stylebox("panel")
		if sb1 is StyleBoxFlat:
			sb1.border_color = _get_player_token_color(P1) if current == P1 else _get_player_token_color(P1).darkened(0.45)
			sb1.set_border_width_all(2 if current == P1 else 1)
	if p2_hud:
		var sb2 = p2_hud.get_theme_stylebox("panel")
		if sb2 is StyleBoxFlat:
			sb2.border_color = _get_player_token_color(P2) if current == P2 else _get_player_token_color(P2).darkened(0.45)
			sb2.set_border_width_all(2 if current == P2 else 1)

	if p1_money_lbl:
		p1_money_lbl.text = "💰$%d" % money[P1]
	if p1_props_lbl:
		p1_props_lbl.text = "🏠%d" % p1_count
	if p1_pos_lbl:
		var p1_sp = clampi(positions.get(P1, 0), 0, TOTAL_SPACES - 1)
		var p1_jail_str = "🔒" if jailed_players.get(P1, 0) > 0 else ""
		p1_pos_lbl.text = "📍%s%s" % [SPACES[p1_sp]["short"], p1_jail_str]

	if p2_money_lbl:
		p2_money_lbl.text = "💰$%d" % money[P2]
	if p2_props_lbl:
		p2_props_lbl.text = "🏠%d" % p2_count
	if p2_pos_lbl:
		var p2_sp = clampi(positions.get(P2, 0), 0, TOTAL_SPACES - 1)
		var p2_jail_str = "🔒" if jailed_players.get(P2, 0) > 0 else ""
		p2_pos_lbl.text = "📍%s%s" % [SPACES[p2_sp]["short"], p2_jail_str]

	# Update Jail Fee button visibility
	if pay_jail_btn:
		var in_jail = (jailed_players.get(current, 0) > 0)
		pay_jail_btn.visible = in_jail

	# Update Dice Unicode display
	var dice_icons = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
	var d1_idx = clampi(last_dice_1 - 1, 0, 5)
	var d2_idx = clampi(last_dice_2 - 1, 0, 5)
	if dice_display_lbl:
		dice_display_lbl.text = "🎲 [ %s ]  [ %s ]  (Total: %d)%s" % [
			dice_icons[d1_idx], dice_icons[d2_idx], last_dice_1 + last_dice_2,
			" ¡DOBLE!" if last_roll_doubles else ""
		]

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type = str(event.get("command_type", event.get("event_type", "")))
			var event_type = raw_type.split("::")[-1]
			if event_type == "PlayerMovedEvent":
				var p = int(event.get("player", current))
				var new_pos = int(event.get("new_position", 0))
				last_dice_1 = int(event.get("d1", 1))
				last_dice_2 = int(event.get("d2", 1))
				last_roll_doubles = bool(event.get("is_doubles", false))
				if dice_widget != null:
					dice_widget.show_roll([last_dice_1, last_dice_2])

				if event.get("passed_go", false):
					money[p] += 200
					card_event_label.text = "Jugador %d pasó por la Salida (+ $200)" % p
				else:
					card_event_label.text = "J%d avanzó a %s" % [p, SPACES[clampi(new_pos, 0, 39)]["name"]]

				_animate_player_move(p, new_pos)

			elif event_type == "PropertyPurchasedEvent":
				var p = int(event.get("player", current))
				var sp = int(event.get("space", 0))
				var pr = int(event.get("price", 0))
				property_owners[sp] = p
				money[p] -= pr
				if pending_buy_space == sp:
					pending_buy_space = -1
					buy_modal.visible = false
				card_event_label.text = "J%d compró %s por $%d" % [p, SPACES[sp]["name"], pr]
				_check_monopoly_houses(sp, p)

			elif event_type == "RentPaidEvent":
				var payer = int(event.get("payer", 0))
				var prop_owner = int(event.get("owner", 0))
				var amt = int(event.get("amount", 0))
				var sp = int(event.get("space", 0))
				if money.has(payer):
					money[payer] -= amt
				if money.has(prop_owner):
					money[prop_owner] += amt
				card_event_label.text = "J%d pagó $%d de renta a J%d en %s" % [payer, amt, prop_owner, SPACES[sp]["name"]]

			elif event_type == "TaxPaidEvent":
				var p = int(event.get("player", current))
				var amt = int(event.get("amount", 0))
				var t_name = str(event.get("name", "Impuesto"))
				money[p] -= amt
				card_event_label.text = "J%d pagó $%d en %s" % [p, amt, t_name]

			elif event_type == "ChanceCardDrawnEvent":
				var p = int(event.get("player", current))
				var desc = str(event.get("description", "Carta de Suerte"))
				card_event_label.text = "❓ SUERTE (J%d): %s" % [p, desc]

			elif event_type == "CommunityChestCardDrawnEvent":
				var p = int(event.get("player", current))
				var desc = str(event.get("description", "Arca Comunal"))
				card_event_label.text = "🎁 ARCA (J%d): %s" % [p, desc]

			elif event_type == "JailedEvent":
				var p = int(event.get("player", current))
				jailed_players[p] = 3
				card_event_label.text = "🚔 ¡Jugador %d fue enviado a la Cárcel!" % p

			elif event_type == "AuctionStartedEvent":
				var sp = int(event.get("space", 0))
				current_auction_space = sp
				current_auction_bid = 0
				highest_bidder = 0
				auction_title_lbl.text = "🏛️ SUBASTA: %s" % SPACES[sp]["name"]
				auction_current_bid_lbl.text = "Puja Inicial: $0 | Líder: Ninguno"
				auction_bid_input.value = 20
				_center_modal_over_board(auction_modal)
				auction_modal.visible = true

			elif event_type == "AuctionWonEvent":
				var p = int(event.get("player", current))
				var sp = int(event.get("space", 0))
				var pr = int(event.get("price", 0))
				property_owners[sp] = p
				money[p] -= pr
				auction_modal.visible = false
				card_event_label.text = "🏆 ¡J%d ganó la subasta de %s por $%d!" % [p, SPACES[sp]["name"], pr]
				_check_monopoly_houses(sp, p)

			elif event_type == "BankruptcyEvent":
				var p = int(event.get("player", 0))
				card_event_label.text = "💥 ¡Jugador %d cayó en BANCARROTA!" % p

			elif event_type == "TradeProposedEvent":
				var p = int(event.get("player", 0))
				var target_p = int(event.get("target", 0))
				active_trade_offer = event
				card_event_label.text = "🤝 ¡J%d propuso un intercambio a J%d!" % [p, target_p]
				if current == target_p:
					accept_trade_btn.visible = true
					reject_trade_btn.visible = true

			elif event_type == "TradeAcceptedEvent":
				var p = int(event.get("player", 0))
				var target_p = int(event.get("target", 0))
				var off_spaces = event.get("offered_spaces", [])
				var req_spaces = event.get("requested_spaces", [])
				var off_cash = int(event.get("offered_cash", 0))
				var req_cash = int(event.get("requested_cash", 0))

				for s in off_spaces:
					property_owners[int(s)] = p
				for s in req_spaces:
					property_owners[int(s)] = target_p

				money[target_p] -= off_cash
				money[p] += off_cash
				money[p] -= req_cash
				money[target_p] += req_cash

				active_trade_offer = {}
				accept_trade_btn.visible = false
				reject_trade_btn.visible = false
				card_event_label.text = "🎉 ¡Intercambio aceptado entre J%d y J%d!" % [target_p, p]

			elif event_type == "TradeRejectedEvent":
				active_trade_offer = {}
				accept_trade_btn.visible = false
				reject_trade_btn.visible = false
				card_event_label.text = "❌ Oferta de intercambio rechazada."

			elif event_type == "HouseBuiltEvent":
				var sp = int(event.get("space", 0))
				var lvl = int(event.get("level", 1))
				var cost = int(event.get("cost", 50))
				var p = int(event.get("player", current))
				property_houses[sp] = lvl
				money[p] -= cost
				card_event_label.text = "🏠 ¡J%d construyó en %s (Nivel %d)!" % [p, SPACES[sp]["name"], lvl]

			elif event_type == "HouseSoldEvent":
				var sp = int(event.get("space", 0))
				var lvl = int(event.get("level", 0))
				var refund = int(event.get("refund", 25))
				var p = int(event.get("player", current))
				if lvl == 0:
					property_houses.erase(sp)
				else:
					property_houses[sp] = lvl
				money[p] += refund
				card_event_label.text = "🏠 ¡J%d vendió casa en %s por $%d!" % [p, SPACES[sp]["name"], refund]

			elif event_type == "PropertyMortgagedEvent":
				var sp = int(event.get("space", 0))
				var amt = int(event.get("amount", 0))
				var p = int(event.get("player", current))
				if not mortgaged_properties.has(sp):
					mortgaged_properties.append(sp)
				money[p] += amt
				card_event_label.text = "🏦 ¡J%d hipotecó %s por $%d!" % [p, SPACES[sp]["name"], amt]

			elif event_type == "PropertyUnmortgagedEvent":
				var sp = int(event.get("space", 0))
				var cost = int(event.get("cost", 0))
				var p = int(event.get("player", current))
				mortgaged_properties.erase(sp)
				money[p] -= cost
				card_event_label.text = "🏦 ¡J%d deshipotecó %s pagando $%d!" % [p, SPACES[sp]["name"], cost]

			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null:
					w = 0
				_on_game_over(int(w))

	current = bridge.current_player()
	_update_hud_display()
	_update_space_inspector(selected_space)
	_update_status()
	queue_redraw()

func _check_monopoly_houses(new_space: int, player_id: int) -> void:
	var grp = SPACES[new_space]["group"]
	if grp in ["Especial", "Ferrocarril", "Suministros", "Impuesto"]:
		return

	var all_in_grp = []
	for i in range(SPACES.size()):
		if SPACES[i]["group"] == grp:
			all_in_grp.append(i)

	var owns_all = true
	for sp_idx in all_in_grp:
		if property_owners.get(sp_idx, -1) != player_id:
			owns_all = false
			break

	if owns_all:
		for sp_idx in all_in_grp:
			if not property_houses.has(sp_idx):
				property_houses[sp_idx] = 2

func _on_turn_changed(player_id: int) -> void:
	current = player_id
	_update_hud_display()
	_update_space_inspector(selected_space)
	_update_status()
	if turn_indicator != null:
		turn_indicator.current_player_id = player_id

func _on_game_over(w: int) -> void:
	_sfx_victory_fanfare()
	winner = w
	_update_status()
	if ResourceLoader.exists("res://game_over_overlay.tscn"):
		var overlay = preload("res://game_over_overlay.tscn").instantiate()
		add_child(overlay)
		if overlay.has_method("show_winner"):
			overlay.call("show_winner", w)

func _on_move_rejected(reason: String) -> void:
	_sfx_error_buzz()
	if status != null:
		status.text = "Movimiento rechazado: %s" % reason

func _on_layout_changed(layout: int) -> void:
	current_screen_layout = layout
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	var vp_size := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz = get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)

	var is_portrait_or_phone: bool = (layout == 2) or (vp_size.x < 700.0) or (vp_size.y > vp_size.x)
	var b_size: float = 340.0 if is_portrait_or_phone else 420.0
	var bx: float = 16.0
	var by: float = 78.0

	board_rect = Rect2(bx, by, b_size, b_size)
	corner_size = roundf(b_size * 0.125)

	if top_bar:
		top_bar.position = Vector2(bx, 6.0)
		top_bar.size = Vector2(b_size, 32.0)
	if title_lbl:
		title_lbl.text = "🎩 MONOPOLY"
		title_lbl.add_theme_font_size_override("font_size", 15 if is_portrait_or_phone else 16)
	if players_hud_hbox:
		players_hud_hbox.position = Vector2(bx, 42.0)
		players_hud_hbox.size = Vector2(b_size, 30.0)

	if control_dashboard:
		control_dashboard.position = Vector2(bx, board_rect.end.y + 8.0)
		control_dashboard.size = Vector2(b_size, 152.0)

	if logo_lbl:
		logo_lbl.add_theme_font_size_override("font_size", 14 if is_portrait_or_phone else 16)
	if dice_display_lbl:
		dice_display_lbl.add_theme_font_size_override("font_size", 12 if is_portrait_or_phone else 14)
	if roll_button:
		roll_button.custom_minimum_size = Vector2(115, 32)
		roll_button.add_theme_font_size_override("font_size", 12)
	if pay_jail_btn:
		pay_jail_btn.custom_minimum_size = Vector2(96, 32)
		pay_jail_btn.add_theme_font_size_override("font_size", 11)

	if status != null:
		status.position = Vector2(bx, board_rect.end.y + 164.0)
		status.add_theme_font_size_override("font_size", 13)

	# Keep CenterPanel strictly inside the inner hole of the board (never overlapping perimeter tiles)
	if center_panel:
		var pad = 6.0 if is_portrait_or_phone else 8.0
		center_panel.position = Vector2(
			board_rect.position.x + corner_size + pad,
			board_rect.position.y + corner_size + pad
		)
		center_panel.size = Vector2(
			board_rect.size.x - (corner_size * 2.0) - (pad * 2.0),
			board_rect.size.y - (corner_size * 2.0) - (pad * 2.0)
		)

	_center_modal_over_board(buy_modal)
	_center_modal_over_board(auction_modal)
	_update_token_positions()

	var min_x: float = bx
	var min_y: float = 6.0
	var total_w: float = b_size
	var total_h: float = (board_rect.end.y + 164.0) - min_y
	var sx: float = (vp_size.x - 24.0) / total_w
	var sy: float = (vp_size.y - 16.0) / total_h
	var s: float = clampf(minf(sx, sy), 0.3, 1.0)
	scale = Vector2(s, s)
	position = Vector2(
		(vp_size.x - total_w * s) * 0.5 - min_x * s,
		(vp_size.y - total_h * s) * 0.5 - min_y * s
	)

	queue_redraw()

# -------------------------------------------------------------------------
# DRAWING: PERIMETER TILES, COLOR BARS (b), HOUSES/HOTELS (c)
# -------------------------------------------------------------------------
func _draw() -> void:
	var bg_color = current_theme.board_color if current_theme else Color("#0D1B2A")
	draw_rect(board_rect, bg_color)
	draw_rect(board_rect, current_theme.line_color if current_theme else Color("#415A77"), false, 3.0)

	var tile_bg = Color(0.95, 0.95, 0.91)
	var corner_bg = Color(0.90, 0.93, 0.89)
	var border_col = Color(0.20, 0.22, 0.28)
	var is_compact = corner_size < 50.0
	var bar_thickness = 9.0 if is_compact else 12.0

	for i in range(TOTAL_SPACES):
		var rect = _get_space_rect(i)
		var prop = SPACES[i]
		var grp = prop["group"]
		var is_corner = (i % 10 == 0)

		# 1. Tile Background
		var fill_col = corner_bg if is_corner else tile_bg
		if i == selected_space:
			fill_col = Color(1.0, 0.96, 0.80)
		draw_rect(rect, fill_col)
		draw_rect(rect, border_col, false, 1.2)

		# 2. Group Color Bar (oriented toward the inner board)
		var grp_color = _get_group_color(grp)
		var bar_rect := Rect2()
		if grp_color != Color.TRANSPARENT and grp not in ["Especial", "Impuesto"]:
			if i < 10: # Bottom row: bar on top
				bar_rect = Rect2(rect.position.x, rect.position.y, rect.size.x, bar_thickness)
			elif i < 20: # Left col: bar on right
				bar_rect = Rect2(rect.position.x + rect.size.x - bar_thickness, rect.position.y, bar_thickness, rect.size.y)
			elif i < 30: # Top row: bar on bottom
				bar_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - bar_thickness, rect.size.x, bar_thickness)
			else: # Right col: bar on left
				bar_rect = Rect2(rect.position.x, rect.position.y, bar_thickness, rect.size.y)

			draw_rect(bar_rect, grp_color)
			var grp_sym := _get_group_symbol(grp)
			if not grp_sym.is_empty():
				draw_string(
					ThemeDB.fallback_font,
					bar_rect.position + Vector2(2, bar_thickness - 2.0),
					grp_sym,
					HORIZONTAL_ALIGNMENT_LEFT,
					int(bar_thickness),
					7 if is_compact else 8,
					Color.WHITE
				)

			# Houses / Hotel Indicators
			if property_houses.has(i):
				var h_count = property_houses[i]
				if h_count == 5:
					var h_center = bar_rect.position + (bar_rect.size * 0.5)
					draw_rect(Rect2(h_center.x - 4, h_center.y - 3, 8, 6), Color(0.85, 0.1, 0.1))
					draw_rect(Rect2(h_center.x - 4, h_center.y - 3, 8, 6), Color.WHITE, false, 1.0)
				else:
					var h_sz = 4.5 if is_compact else 5.5
					var h_step = 5.5 if is_compact else 7.0
					for h in range(h_count):
						var h_pos = bar_rect.position + Vector2(2 + h * h_step, 2)
						if (i > 10 and i < 20) or (i > 30 and i < 40):
							h_pos = bar_rect.position + Vector2(2, 2 + h * h_step)
						draw_rect(Rect2(h_pos.x, h_pos.y, h_sz, h_sz), Color(0.1, 0.85, 0.25))

		# 3. Ownership Border & Badge
		if property_owners.has(i):
			var owner_p = property_owners[i]
			var owner_col = _get_player_token_color(owner_p)
			draw_rect(rect.grow(-1.5), owner_col, false, 2.0)
			var badge_pos = rect.position + Vector2(rect.size.x - 6, 6)
			draw_circle(badge_pos, 4.0 if is_compact else 5.0, owner_col)
			draw_circle(badge_pos, 4.0 if is_compact else 5.0, Color.WHITE, false, 1.0)
			if mortgaged_properties.has(i):
				draw_string(
					ThemeDB.fallback_font,
					rect.position + Vector2(2, 9),
					"H",
					HORIZONTAL_ALIGNMENT_LEFT,
					10,
					8,
					Color(0.8, 0.1, 0.1)
				)

		# 4. Icon + Short Name + Price
		var icon_str = prop.get("icon", "")
		if icon_str != "":
			var icon_font_sz = 9 if is_compact else 11
			var icon_y_offset = 2.0 if not is_compact else 3.0
			var icon_pos = rect.position + Vector2(1, (rect.size.y * 0.5) + icon_y_offset)
			draw_string(
				ThemeDB.fallback_font,
				icon_pos,
				icon_str,
				HORIZONTAL_ALIGNMENT_CENTER,
				int(rect.size.x - 2),
				icon_font_sz,
				Color.BLACK
			)

		# Abbreviated Name on Desktop/Tablet for horizontal/corner tiles
		if not is_compact and (is_corner or i < 10 or (i > 20 and i < 30)):
			var short_lbl: String = str(prop.get("short", ""))
			var lbl_y = rect.position.y + bar_thickness + 9.0 if (i < 10 and not is_corner) else rect.position.y + 9.5
			draw_string(
				ThemeDB.fallback_font,
				Vector2(rect.position.x + 1, lbl_y),
				short_lbl,
				HORIZONTAL_ALIGNMENT_CENTER,
				int(rect.size.x - 2),
				7,
				Color(0.15, 0.18, 0.22)
			)

		# Price Tag for Unowned Purchasable Spaces
		if prop["price"] > 0 and not property_owners.has(i):
			var pr_font_sz = 7 if is_compact else 8
			var pr_y = rect.position.y + rect.size.y - 2.5
			if i > 20 and i < 30:
				pr_y = rect.position.y + rect.size.y - bar_thickness - 2.0
			draw_string(
				ThemeDB.fallback_font,
				Vector2(rect.position.x + 1, pr_y),
				"$%d" % prop["price"],
				HORIZONTAL_ALIGNMENT_CENTER,
				int(rect.size.x - 2),
				pr_font_sz,
				Color(0.08, 0.45, 0.12)
			)

		# 5. Selected Space Highlight
		if i == selected_space:
			draw_rect(rect.grow(-1.0), Color(0.98, 0.78, 0.15, 0.95), false, 2.5)

func _get_player_token_color(p_id: int) -> Color:
	var fallback: Color = PLAYER_COLORS.get(p_id, Color.WHITE)
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = get_node("/root/ThemeManager")
		if tm.has_method("is_colorblind_mode") and bool(tm.call("is_colorblind_mode")):
			if tm.has_method("get_player_color"):
				return tm.call("get_player_color", p_id, fallback)
	return fallback

func _get_group_color(grp: String) -> Color:
	var fallback: Color = GROUP_COLORS.get(grp, Color.TRANSPARENT)
	if fallback == Color.TRANSPARENT or grp in ["Especial", "Impuesto", "Ferrocarril"]:
		return fallback
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = get_node("/root/ThemeManager")
		if tm.has_method("is_colorblind_mode") and bool(tm.call("is_colorblind_mode")):
			if tm.has_method("get_accessible_color"):
				return tm.call("get_accessible_color", grp, fallback)
	return fallback

func _get_group_symbol(grp: String) -> String:
	match grp:
		"Rojo": return "▲"
		"Azul Oscuro", "Celeste": return "●"
		"Verde": return "■"
		"Amarillo": return "◆"
		"Naranja", "Marrón", "Suministros": return "★"
		"Rosa": return "⬟"
		_: return ""

func _update_status() -> void:
	if turn_indicator != null and turn_indicator.has_method("_ensure_game_app_menu"):
		turn_indicator._ensure_game_app_menu()
	if status == null:
		return
	if winner != -1:
		status.text = "¡Bancarrota! Ganó el jugador %s (Monopoly)" % winner
	else:
		status.text = "Turno: Jugador %s (Monopoly 40 Casillas)" % current

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
