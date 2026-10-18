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
	{"name": "SALIDA", "group": "Especial", "price": 0, "rent": 0, "icon": "🏁", "desc": "Cobra $200 al pasar"},
	# 1..3: Marrón
	{"name": "Av. Mediterráneo", "group": "Marrón", "price": 60, "rent": 2, "icon": "🏠", "desc": "Propiedad Marrón"},
	{"name": "Arca Comunal", "group": "Especial", "price": 0, "rent": 0, "icon": "🎁", "desc": "Toma una carta"},
	{"name": "Av. Báltica", "group": "Marrón", "price": 60, "rent": 4, "icon": "🏠", "desc": "Propiedad Marrón"},
	# 4: Impuesto Renta
	{"name": "Imp. sobre la Renta", "group": "Impuesto", "price": 0, "rent": 200, "icon": "💸", "desc": "Paga $200"},
	# 5: Ferrocarril Reading
	{"name": "Ferrocarril Reading", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren"},
	# 6..9: Celeste
	{"name": "Av. Oriental", "group": "Celeste", "price": 100, "rent": 6, "icon": "🏠", "desc": "Propiedad Celeste"},
	{"name": "Suerte", "group": "Especial", "price": 0, "rent": 0, "icon": "❓", "desc": "Toma una carta"},
	{"name": "Av. Vermont", "group": "Celeste", "price": 100, "rent": 6, "icon": "🏠", "desc": "Propiedad Celeste"},
	{"name": "Av. Connecticut", "group": "Celeste", "price": 120, "rent": 8, "icon": "🏠", "desc": "Propiedad Celeste"},
	# 10: Cárcel / Solo Visita
	{"name": "CÁRCEL / VISITA", "group": "Especial", "price": 0, "rent": 0, "icon": "🔒", "desc": "Solo Visita o Preso"},
	# 11..14: Rosa + Compañía Eléctrica
	{"name": "Plaza San Carlos", "group": "Rosa", "price": 140, "rent": 10, "icon": "🏠", "desc": "Propiedad Rosa"},
	{"name": "Cía. Eléctrica", "group": "Suministros", "price": 150, "rent": 10, "icon": "💡", "desc": "Servicio Eléctrico"},
	{"name": "Av. Estados", "group": "Rosa", "price": 140, "rent": 10, "icon": "🏠", "desc": "Propiedad Rosa"},
	{"name": "Av. Virginia", "group": "Rosa", "price": 160, "rent": 12, "icon": "🏠", "desc": "Propiedad Rosa"},
	# 15: Ferrocarril Pennsylvania
	{"name": "Ferrocarril Pennsylvania", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren"},
	# 16..19: Naranja
	{"name": "Plaza St. James", "group": "Naranja", "price": 180, "rent": 14, "icon": "🏠", "desc": "Propiedad Naranja"},
	{"name": "Arca Comunal", "group": "Especial", "price": 0, "rent": 0, "icon": "🎁", "desc": "Toma una carta"},
	{"name": "Av. Tennessee", "group": "Naranja", "price": 180, "rent": 14, "icon": "🏠", "desc": "Propiedad Naranja"},
	{"name": "Av. Nueva York", "group": "Naranja", "price": 200, "rent": 16, "icon": "🏠", "desc": "Propiedad Naranja"},
	# 20: Parking Gratuito
	{"name": "PARKING GRATIS", "group": "Especial", "price": 0, "rent": 0, "icon": "🅿️", "desc": "Descanso seguro"},
	# 21..24: Rojo
	{"name": "Av. Kentucky", "group": "Rojo", "price": 220, "rent": 18, "icon": "🏠", "desc": "Propiedad Roja"},
	{"name": "Suerte", "group": "Especial", "price": 0, "rent": 0, "icon": "❓", "desc": "Toma una carta"},
	{"name": "Av. Indiana", "group": "Rojo", "price": 220, "rent": 18, "icon": "🏠", "desc": "Propiedad Roja"},
	{"name": "Av. Illinois", "group": "Rojo", "price": 240, "rent": 20, "icon": "🏠", "desc": "Propiedad Roja"},
	# 25: Ferrocarril B. & O.
	{"name": "Ferrocarril B. & O.", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren"},
	# 26..29: Amarillo + Planta de Agua
	{"name": "Av. Atlántico", "group": "Amarillo", "price": 260, "rent": 22, "icon": "🏠", "desc": "Propiedad Amarilla"},
	{"name": "Av. Ventnor", "group": "Amarillo", "price": 260, "rent": 22, "icon": "🏠", "desc": "Propiedad Amarilla"},
	{"name": "Planta de Agua", "group": "Suministros", "price": 150, "rent": 10, "icon": "🚰", "desc": "Servicio de Agua"},
	{"name": "Jardines Marvin", "group": "Amarillo", "price": 280, "rent": 24, "icon": "🏠", "desc": "Propiedad Amarilla"},
	# 30: Ve a la Cárcel
	{"name": "VAYA A LA CÁRCEL", "group": "Especial", "price": 0, "rent": 0, "icon": "🚔", "desc": "Directo a prisión"},
	# 31..34: Verde
	{"name": "Av. Pacífico", "group": "Verde", "price": 300, "rent": 26, "icon": "🏠", "desc": "Propiedad Verde"},
	{"name": "Av. Carolina Norte", "group": "Verde", "price": 300, "rent": 26, "icon": "🏠", "desc": "Propiedad Verde"},
	{"name": "Arca Comunal", "group": "Especial", "price": 0, "rent": 0, "icon": "🎁", "desc": "Toma una carta"},
	{"name": "Av. Pennsylvania", "group": "Verde", "price": 320, "rent": 28, "icon": "🏠", "desc": "Propiedad Verde"},
	# 35: Ferrocarril Short Line
	{"name": "Ferrocarril Short Line", "group": "Ferrocarril", "price": 200, "rent": 25, "icon": "🚂", "desc": "Estación de Tren"},
	# 36..39: Suerte, Azul Oscuro, Impuesto de Lujo
	{"name": "Suerte", "group": "Especial", "price": 0, "rent": 0, "icon": "❓", "desc": "Toma una carta"},
	{"name": "Plaza Park", "group": "Azul Oscuro", "price": 350, "rent": 35, "icon": "🏠", "desc": "Propiedad Azul"},
	{"name": "Impuesto de Lujo", "group": "Impuesto", "price": 0, "rent": 100, "icon": "💎", "desc": "Paga $100"},
	{"name": "Paseo Tablado", "group": "Azul Oscuro", "price": 400, "rent": 50, "icon": "🏠", "desc": "Propiedad Azul"}
]

const PLAYER_COLORS = {
	1: Color("#E53935"), # Red
	2: Color("#1E88E5")  # Blue
}

var bridge
var current = P1
var winner = -1

# Game State
var positions = {P1: 0, P2: 0}
var money = {P1: 1500, P2: 1500}
var property_owners = {} # space_idx -> player_id
var property_houses = {} # space_idx -> count (1..4 houses, 5 = hotel)
var jailed_players = {P1: 0, P2: 0}

var last_dice_1: int = 1
var last_dice_2: int = 1
var last_roll_doubles: bool = false
var pending_buy_space: int = -1

# Board Geometry
var board_rect: Rect2 = Rect2(60, 130, 580, 580)
var corner_size: float = 70.0
var space_step: float = 48.88

# UI Components
var player_tokens = {P1: null, P2: null}
var roll_button: Button
var pay_jail_btn: Button
var card_event_banner: PanelContainer
var card_event_label: Label

# Property Management & Trade UI
var mortgaged_properties: Array = []
var active_trade_offer: Dictionary = {}
var property_mgmt_panel: PanelContainer
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

# Center HUD
var center_panel: Panel
var p1_hud: PanelContainer
var p1_money_lbl: Label
var p1_props_lbl: Label
var p2_hud: PanelContainer
var p2_money_lbl: Label
var p2_props_lbl: Label
var dice_display_lbl: Label

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
	if bridge.has_signal("turn_changed"):
		bridge.connect("turn_changed", _on_turn_changed)

	bridge.start_local_match_monopoly(P1, P2)
	current = bridge.current_player()

	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_token_positions()
	_update_hud_display()
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
		c_style.bg_color = current_theme.dark_color.darkened(0.2)
		c_style.border_color = current_theme.line_color.darkened(0.2)
		c_style.set_border_width_all(2)
		c_style.set_corner_radius_all(12)
		center_panel.add_theme_stylebox_override("panel", c_style)

func _setup_ui() -> void:
	# Top bar
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(60, 20)
	top_bar.size = Vector2(580, 45)
	top_bar.add_theme_constant_override("separation", 15)
	add_child(top_bar)

	var title_lbl = Label.new()
	title_lbl.text = "🎩 MONOPOLY 40 CASILLAS"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(90, 36)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("monopoly"))
	top_bar.add_child(btn_rules)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(60, 75)
	add_child(turn_indicator)

	# Center Game Controls & HUD
	center_panel = Panel.new()
	center_panel.name = "CenterPanel"
	center_panel.position = Vector2(board_rect.position.x + corner_size + 10, board_rect.position.y + corner_size + 10)
	center_panel.size = Vector2(board_rect.size.x - (corner_size * 2) - 20, board_rect.size.y - (corner_size * 2) - 20)
	add_child(center_panel)

	var center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_vbox.offset_left = 15
	center_vbox.offset_top = 15
	center_vbox.offset_right = -15
	center_vbox.offset_bottom = -15
	center_vbox.add_theme_constant_override("separation", 10)
	center_panel.add_child(center_vbox)

	# Monopoly Center Logo
	var logo_lbl = Label.new()
	logo_lbl.text = "🎩 M O N O P O L Y"
	logo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_lbl.add_theme_font_size_override("font_size", 22)
	logo_lbl.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
	center_vbox.add_child(logo_lbl)

	# Players Money HUD Cards
	var hud_hbox = HBoxContainer.new()
	hud_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_hbox.add_theme_constant_override("separation", 12)
	center_vbox.add_child(hud_hbox)

	p1_hud = _create_player_hud_card(P1, "Jugador 1 (Rojo)")
	hud_hbox.add_child(p1_hud)

	p2_hud = _create_player_hud_card(P2, "Jugador 2 (Azul)")
	hud_hbox.add_child(p2_hud)

	# Dice Display
	dice_display_lbl = Label.new()
	dice_display_lbl.text = "🎲 Dados: [ ⚂ ]  [ ⚃ ]  (Total: 7)"
	dice_display_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_display_lbl.add_theme_font_size_override("font_size", 16)
	center_vbox.add_child(dice_display_lbl)

	# Card / Game Event Banner
	card_event_banner = PanelContainer.new()
	card_event_banner.custom_minimum_size = Vector2(0, 42)
	var ev_style = StyleBoxFlat.new()
	ev_style.bg_color = Color(0.1, 0.2, 0.35, 0.9)
	ev_style.set_corner_radius_all(8)
	ev_style.content_margin_left = 10
	ev_style.content_margin_right = 10
	ev_style.content_margin_top = 4
	ev_style.content_margin_bottom = 4
	card_event_banner.add_theme_stylebox_override("panel", ev_style)

	card_event_label = Label.new()
	card_event_label.text = "Bienvenido a Monopoly. ¡Tira los dados para comenzar!"
	card_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_event_label.add_theme_font_size_override("font_size", 12)
	card_event_banner.add_child(card_event_label)
	center_vbox.add_child(card_event_banner)

	# Roll & Action Buttons
	var actions_hbox = HBoxContainer.new()
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_hbox.add_theme_constant_override("separation", 15)
	center_vbox.add_child(actions_hbox)

	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.custom_minimum_size = Vector2(160, 44)
	roll_button.text = "🎲 Tirar y Mover"
	roll_button.add_theme_font_size_override("font_size", 16)
	roll_button.pressed.connect(_on_roll_pressed)
	actions_hbox.add_child(roll_button)

	pay_jail_btn = Button.new()
	pay_jail_btn.name = "PayJailButton"
	pay_jail_btn.custom_minimum_size = Vector2(140, 44)
	pay_jail_btn.text = "🔓 Fianza ($50)"
	pay_jail_btn.visible = false
	pay_jail_btn.pressed.connect(_on_pay_jail_pressed)
	actions_hbox.add_child(pay_jail_btn)

	# Property Management & Trade Panel
	property_mgmt_panel = PanelContainer.new()
	property_mgmt_panel.name = "PropertyManagementPanel"
	var mgmt_style = StyleBoxFlat.new()
	mgmt_style.bg_color = Color(0.12, 0.16, 0.22, 0.85)
	mgmt_style.corner_radius_top_left = 6
	mgmt_style.corner_radius_top_right = 6
	mgmt_style.corner_radius_bottom_right = 6
	mgmt_style.corner_radius_bottom_left = 6
	mgmt_style.content_margin_left = 6
	mgmt_style.content_margin_right = 6
	mgmt_style.content_margin_top = 4
	mgmt_style.content_margin_bottom = 4
	property_mgmt_panel.add_theme_stylebox_override("panel", mgmt_style)
	center_vbox.add_child(property_mgmt_panel)

	var mgmt_vbox = VBoxContainer.new()
	mgmt_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mgmt_vbox.add_theme_constant_override("separation", 4)
	property_mgmt_panel.add_child(mgmt_vbox)

	var mgmt_title = Label.new()
	mgmt_title.text = "🏢 Gestión de Propiedades e Intercambios"
	mgmt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mgmt_title.add_theme_font_size_override("font_size", 11)
	mgmt_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	mgmt_vbox.add_child(mgmt_title)

	var mgmt_btns_hbox = HBoxContainer.new()
	mgmt_btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mgmt_btns_hbox.add_theme_constant_override("separation", 8)
	mgmt_vbox.add_child(mgmt_btns_hbox)

	build_house_btn = Button.new()
	build_house_btn.name = "BuildHouseButton"
	build_house_btn.text = "🏠 Construir Casa/Hotel"
	build_house_btn.custom_minimum_size = Vector2(140, 32)
	build_house_btn.add_theme_font_size_override("font_size", 11)
	build_house_btn.pressed.connect(_on_build_house_pressed)
	mgmt_btns_hbox.add_child(build_house_btn)

	mortgage_btn = Button.new()
	mortgage_btn.name = "MortgageButton"
	mortgage_btn.text = "🏦 Hipotecar/Deshipotecar"
	mortgage_btn.custom_minimum_size = Vector2(150, 32)
	mortgage_btn.add_theme_font_size_override("font_size", 11)
	mortgage_btn.pressed.connect(_on_mortgage_pressed)
	mgmt_btns_hbox.add_child(mortgage_btn)

	trade_btn = Button.new()
	trade_btn.name = "TradeButton"
	trade_btn.text = "🤝 Proponer Intercambio"
	trade_btn.custom_minimum_size = Vector2(150, 32)
	trade_btn.add_theme_font_size_override("font_size", 11)
	trade_btn.pressed.connect(_on_trade_pressed)
	mgmt_btns_hbox.add_child(trade_btn)

	var trade_resp_hbox = HBoxContainer.new()
	trade_resp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	trade_resp_hbox.add_theme_constant_override("separation", 8)
	mgmt_vbox.add_child(trade_resp_hbox)

	accept_trade_btn = Button.new()
	accept_trade_btn.name = "AcceptTradeButton"
	accept_trade_btn.text = "✅ Aceptar Trato"
	accept_trade_btn.visible = false
	accept_trade_btn.custom_minimum_size = Vector2(120, 28)
	accept_trade_btn.add_theme_font_size_override("font_size", 11)
	accept_trade_btn.pressed.connect(_on_accept_trade_pressed)
	trade_resp_hbox.add_child(accept_trade_btn)

	reject_trade_btn = Button.new()
	reject_trade_btn.name = "RejectTradeButton"
	reject_trade_btn.text = "❌ Rechazar Trato"
	reject_trade_btn.visible = false
	reject_trade_btn.custom_minimum_size = Vector2(120, 28)
	reject_trade_btn.add_theme_font_size_override("font_size", 11)
	reject_trade_btn.pressed.connect(_on_reject_trade_pressed)
	trade_resp_hbox.add_child(reject_trade_btn)

	# Player Token Sprites
	for p in [P1, P2]:
		var token = Control.new()
		token.size = Vector2(22, 22)
		token.pivot_offset = Vector2(11, 11)

		var img = Image.create(22, 22, false, Image.FORMAT_RGBA8)
		var p_col = _get_player_token_color(p)
		for x in range(22):
			for y in range(22):
				var dist = Vector2(x - 11, y - 11).length()
				if dist <= 8.5:
					img.set_pixel(x, y, p_col)
				elif dist <= 10.0:
					img.set_pixel(x, y, Color.BLACK)
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))

		var tex = TextureRect.new()
		tex.texture = ImageTexture.create_from_image(img)
		tex.size = Vector2(22, 22)
		token.add_child(tex)

		var sym_lbl = Label.new()
		sym_lbl.text = "▲" if p == P1 else "●"
		sym_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sym_lbl.add_theme_font_size_override("font_size", 10)
		sym_lbl.add_theme_color_override("font_color", Color.WHITE)
		token.add_child(sym_lbl)

		add_child(token)
		player_tokens[p] = token

	_setup_purchase_modal()
	_setup_auction_modal()

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(100, 80)
	add_child(rules_popup)

	_apply_theme_styling()

func _create_player_hud_card(p_id: int, p_name: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(160, 70)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	sb.border_color = PLAYER_COLORS[p_id]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = p_name
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", PLAYER_COLORS[p_id])
	vbox.add_child(title)

	var m_lbl = Label.new()
	m_lbl.text = "💰 Dinero: $1500"
	m_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(m_lbl)

	var p_lbl = Label.new()
	p_lbl.text = "🏠 Propiedades: 0"
	p_lbl.add_theme_font_size_override("font_size", 11)
	p_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(p_lbl)

	if p_id == P1:
		p1_money_lbl = m_lbl
		p1_props_lbl = p_lbl
	else:
		p2_money_lbl = m_lbl
		p2_props_lbl = p_lbl

	return panel

# -------------------------------------------------------------------------
# TITLE DEED PURCHASE MODAL (d)
# -------------------------------------------------------------------------
func _setup_purchase_modal() -> void:
	buy_modal = PanelContainer.new()
	buy_modal.position = Vector2(180, 240)
	buy_modal.custom_minimum_size = Vector2(340, 270)
	buy_modal.visible = false
	buy_modal.z_index = 25

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.98)
	style.border_color = Color(0.95, 0.85, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	buy_modal.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	buy_modal.add_child(vbox)

	buy_header_bar = ColorRect.new()
	buy_header_bar.custom_minimum_size = Vector2(0, 18)
	buy_header_bar.color = Color("#8B4513")
	vbox.add_child(buy_header_bar)

	buy_title_lbl = Label.new()
	buy_title_lbl.text = "TÍTULO DE PROPIEDAD"
	buy_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_title_lbl.add_theme_font_size_override("font_size", 16)
	buy_title_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(buy_title_lbl)

	buy_price_lbl = Label.new()
	buy_price_lbl.text = "PRECIO: $200"
	buy_price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_price_lbl.add_theme_font_size_override("font_size", 15)
	buy_price_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	vbox.add_child(buy_price_lbl)

	buy_rent_info_lbl = Label.new()
	buy_rent_info_lbl.text = "Renta Base: $10\nRenta con Grupo Completo: $20\nCasa 1: $50 | Casa 2: $150 | Hotel: $450"
	buy_rent_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_rent_info_lbl.add_theme_font_size_override("font_size", 12)
	buy_rent_info_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(buy_rent_info_lbl)

	var btns_hbox = HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(btns_hbox)

	buy_btn_confirm = Button.new()
	buy_btn_confirm.custom_minimum_size = Vector2(130, 40)
	buy_btn_confirm.text = "🟢 Comprar"
	buy_btn_confirm.pressed.connect(func(): _send_buy_decision(true))
	btns_hbox.add_child(buy_btn_confirm)

	buy_btn_auction = Button.new()
	buy_btn_auction.custom_minimum_size = Vector2(130, 40)
	buy_btn_auction.text = "🔨 Subastar"
	buy_btn_auction.pressed.connect(func(): _send_buy_decision(false))
	btns_hbox.add_child(buy_btn_auction)

	add_child(buy_modal)

# -------------------------------------------------------------------------
# AUCTION MODAL DIALOG (d)
# -------------------------------------------------------------------------
func _setup_auction_modal() -> void:
	auction_modal = PanelContainer.new()
	auction_modal.position = Vector2(180, 240)
	auction_modal.custom_minimum_size = Vector2(340, 250)
	auction_modal.visible = false
	auction_modal.z_index = 25

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.22, 0.98)
	style.border_color = Color(0.9, 0.6, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	auction_modal.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	auction_modal.add_child(vbox)

	auction_title_lbl = Label.new()
	auction_title_lbl.text = "🏛️ SUBASTA DE PROPIEDAD"
	auction_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auction_title_lbl.add_theme_font_size_override("font_size", 16)
	auction_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	vbox.add_child(auction_title_lbl)

	auction_current_bid_lbl = Label.new()
	auction_current_bid_lbl.text = "Puja actual: $0\nLíder: Ninguno"
	auction_current_bid_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auction_current_bid_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(auction_current_bid_lbl)

	var input_hbox = HBoxContainer.new()
	input_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(input_hbox)

	var lbl_bid = Label.new()
	lbl_bid.text = "Tu Oferta: $"
	lbl_bid.add_theme_font_size_override("font_size", 14)
	input_hbox.add_child(lbl_bid)

	auction_bid_input = SpinBox.new()
	auction_bid_input.min_value = 10
	auction_bid_input.max_value = 2000
	auction_bid_input.step = 10
	auction_bid_input.value = 50
	input_hbox.add_child(auction_bid_input)

	var btns_hbox = HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(btns_hbox)

	auction_btn_bid = Button.new()
	auction_btn_bid.custom_minimum_size = Vector2(130, 40)
	auction_btn_bid.text = "🔨 Ofertar"
	auction_btn_bid.pressed.connect(_on_send_bid_pressed)
	btns_hbox.add_child(auction_btn_bid)

	auction_btn_pass = Button.new()
	auction_btn_pass.custom_minimum_size = Vector2(130, 40)
	auction_btn_pass.text = "❌ Pasar"
	auction_btn_pass.pressed.connect(_on_pass_bid_pressed)
	btns_hbox.add_child(auction_btn_pass)

	add_child(auction_modal)

# -------------------------------------------------------------------------
# PERIMETER COORDINATE MAPPING (a)
# -------------------------------------------------------------------------
func _get_space_rect(space_idx: int) -> Rect2:
	var idx = space_idx % 40
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
		var pos_idx = positions[p]
		var base_pos = _get_space_center(pos_idx)
		var offset = Vector2(-10, -10) if p == P1 else Vector2(10, 10)
		player_tokens[p].position = base_pos + offset - Vector2(11, 11)

func _animate_player_move(p: int, target_space: int) -> void:
	positions[p] = target_space
	var base_pos = _get_space_center(target_space)
	var offset = Vector2(-10, -10) if p == P1 else Vector2(10, 10)
	var target_pos = base_pos + offset - Vector2(11, 11)

	var tween = create_tween()
	tween.tween_property(player_tokens[p], "position", target_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): _check_pending_purchase(p, target_space))

func _check_pending_purchase(p: int, space: int) -> void:
	if space < 0 or space >= SPACES.size():
		return
	var prop = SPACES[space]
	if prop["price"] > 0 and not property_owners.has(space):
		if p == current:
			pending_buy_space = space
			buy_title_lbl.text = prop["name"]
			buy_header_bar.color = GROUP_COLORS.get(prop["group"], Color.DARK_GRAY)
			buy_price_lbl.text = "PRECIO: $%d  (Tu saldo: $%d)" % [prop["price"], money[p]]
			var base_r = prop["rent"]
			buy_rent_info_lbl.text = "Renta Base: $%d\nRenta con Grupo Completo: $%d\nCon 1-4 Casas: $%d - $%d\nCon Hotel: $%d" % [
				base_r, base_r * 2, base_r * 4, base_r * 12, base_r * 20
			]
			buy_btn_confirm.disabled = (money[p] < prop["price"])
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

func _on_build_house_pressed() -> void:
	if winner != -1:
		return
	var target_space: int = -1
	for space_idx in property_owners.keys():
		if property_owners[space_idx] == current:
			var grp = SPACES[space_idx]["group"]
			if grp in ["Especial", "Ferrocarril", "Suministros", "Impuesto"]:
				continue
			var owns_full = true
			for i in range(SPACES.size()):
				if SPACES[i]["group"] == grp and property_owners.get(i, -1) != current:
					owns_full = false
					break
			if owns_full:
				var lvl = property_houses.get(space_idx, 0)
				if lvl < 5:
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
			card_event_label.text = "ℹ️ No posees un grupo completo apto para construir casas."

func _on_mortgage_pressed() -> void:
	if winner != -1:
		return
	var target_space: int = -1
	var is_unmortgage: bool = false
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
		if property_owners[sp] == P1: p1_count += 1
		elif property_owners[sp] == P2: p2_count += 1

	if p1_money_lbl: p1_money_lbl.text = "💰 Dinero: $%d" % money[P1]
	if p1_props_lbl: p1_props_lbl.text = "🏠 Propiedades: %d" % p1_count
	if p2_money_lbl: p2_money_lbl.text = "💰 Dinero: $%d" % money[P2]
	if p2_props_lbl: p2_props_lbl.text = "🏠 Propiedades: %d" % p2_count

	# Update Jail Fee button visibility
	if pay_jail_btn:
		var in_jail = (jailed_players.get(current, 0) > 0)
		pay_jail_btn.visible = in_jail

	# Update Dice Unicode display
	var dice_icons = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
	var d1_idx = clampi(last_dice_1 - 1, 0, 5)
	var d2_idx = clampi(last_dice_2 - 1, 0, 5)
	if dice_display_lbl:
		dice_display_lbl.text = "🎲 Dados: [ %s ]  [ %s ]  (Total: %d)%s" % [
			dice_icons[d1_idx], dice_icons[d2_idx], last_dice_1 + last_dice_2,
			" - ¡DOBLE!" if last_roll_doubles else ""
		]

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "PlayerMovedEvent":
				var p = int(event.get("player", current))
				var new_pos = int(event.get("new_position", 0))
				last_dice_1 = int(event.get("d1", 1))
				last_dice_2 = int(event.get("d2", 1))
				last_roll_doubles = bool(event.get("is_doubles", false))

				if event.get("passed_go", false):
					money[p] += 200
					card_event_label.text = "Jugador %d pasó por la Salida (+ $200)" % p

				_animate_player_move(p, new_pos)

			elif event_type == "PropertyPurchasedEvent":
				var p = int(event.get("player", current))
				var sp = int(event.get("space", 0))
				var pr = int(event.get("price", 0))
				property_owners[sp] = p
				money[p] -= pr
				card_event_label.text = "Jugador %d compró %s por $%d" % [p, SPACES[sp]["name"], pr]
				_check_monopoly_houses(sp, p)

			elif event_type == "RentPaidEvent":
				var payer = int(event.get("payer", 0))
				var owner = int(event.get("owner", 0))
				var amt = int(event.get("amount", 0))
				var sp = int(event.get("space", 0))
				if money.has(payer): money[payer] -= amt
				if money.has(owner): money[owner] += amt
				card_event_label.text = "Jugador %d pagó $%d de renta a Jugador %d en %s" % [payer, amt, owner, SPACES[sp]["name"]]

			elif event_type == "TaxPaidEvent":
				var p = int(event.get("player", current))
				var amt = int(event.get("amount", 0))
				var t_name = str(event.get("name", "Impuesto"))
				money[p] -= amt
				card_event_label.text = "Jugador %d pagó $%d en %s" % [p, amt, t_name]

			elif event_type == "ChanceCardDrawnEvent":
				var p = int(event.get("player", current))
				var desc = str(event.get("description", "Carta de Suerte"))
				card_event_label.text = "❓ SUERTE (P%d): %s" % [p, desc]

			elif event_type == "CommunityChestCardDrawnEvent":
				var p = int(event.get("player", current))
				var desc = str(event.get("description", "Arca Comunal"))
				card_event_label.text = "🎁 ARCA COMUNAL (P%d): %s" % [p, desc]

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
				auction_modal.visible = true

			elif event_type == "AuctionWonEvent":
				var p = int(event.get("player", current))
				var sp = int(event.get("space", 0))
				var pr = int(event.get("price", 0))
				property_owners[sp] = p
				money[p] -= pr
				auction_modal.visible = false
				card_event_label.text = "🏆 ¡Jugador %d ganó la subasta de %s por $%d!" % [p, SPACES[sp]["name"], pr]
				_check_monopoly_houses(sp, p)

			elif event_type == "BankruptcyEvent":
				var p = int(event.get("player", 0))
				card_event_label.text = "💥 ¡Jugador %d cayó en BANCARROTA!" % p

			elif event_type == "TradeProposedEvent":
				var p = int(event.get("player", 0))
				var target_p = int(event.get("target", 0))
				active_trade_offer = event
				card_event_label.text = "🤝 ¡Jugador %d propuso un intercambio a Jugador %d!" % [p, target_p]
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
				card_event_label.text = "🎉 ¡Intercambio aceptado entre Jugador %d y %d!" % [target_p, p]

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
				card_event_label.text = "🏠 ¡Jugador %d construyó en %s (Nivel %d)!" % [p, SPACES[sp]["name"], lvl]

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
				card_event_label.text = "🏠 ¡Jugador %d vendió casa en %s por $%d!" % [p, SPACES[sp]["name"], refund]

			elif event_type == "PropertyMortgagedEvent":
				var sp = int(event.get("space", 0))
				var amt = int(event.get("amount", 0))
				var p = int(event.get("player", current))
				if not mortgaged_properties.has(sp):
					mortgaged_properties.append(sp)
				money[p] += amt
				card_event_label.text = "🏦 ¡Jugador %d hipotecó %s por $%d!" % [p, SPACES[sp]["name"], amt]

			elif event_type == "PropertyUnmortgagedEvent":
				var sp = int(event.get("space", 0))
				var cost = int(event.get("cost", 0))
				var p = int(event.get("player", current))
				mortgaged_properties.erase(sp)
				money[p] -= cost
				card_event_label.text = "🏦 ¡Jugador %d deshipotecó %s pagando $%d!" % [p, SPACES[sp]["name"], cost]

			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))

	current = bridge.current_player()
	_update_hud_display()
	_update_status()
	queue_redraw()

func _check_monopoly_houses(new_space: int, player_id: int) -> void:
	# Group check to add houses/hotel indicators
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
			# Auto-tier houses when full monopoly is achieved
			if not property_houses.has(sp_idx):
				property_houses[sp_idx] = 2 # 2 houses initially on full set

func _on_turn_changed(player_id: int) -> void:
	current = player_id
	_update_hud_display()
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
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	if layout == 2: # PHONE
		board_rect = Rect2(10, 80, 355, 355)
		corner_size = 46.0
	else: # DESKTOP or TABLET
		board_rect = Rect2(60, 130, 580, 580)
		corner_size = 70.0

	if center_panel:
		center_panel.position = Vector2(board_rect.position.x + corner_size + 8, board_rect.position.y + corner_size + 8)
		center_panel.size = Vector2(board_rect.size.x - (corner_size * 2) - 16, board_rect.size.y - (corner_size * 2) - 16)

	_update_token_positions()
	queue_redraw()

# -------------------------------------------------------------------------
# DRAWING: PERIMETER TILES, COLOR BARS (b), HOUSES/HOTELS (c)
# -------------------------------------------------------------------------
func _draw() -> void:
	# Draw board background
	var bg_color = current_theme.board_color if current_theme else Color("#0D1B2A")
	draw_rect(board_rect, bg_color)
	draw_rect(board_rect, current_theme.line_color if current_theme else Color("#415A77"), false, 3.0)

	var tile_bg = Color(0.96, 0.96, 0.92)
	var border_col = Color(0.2, 0.2, 0.25)

	# Draw 40 perimeter spaces
	for i in range(TOTAL_SPACES):
		var rect = _get_space_rect(i)
		var prop = SPACES[i]
		var grp = prop["group"]

		# Tile background
		draw_rect(rect, tile_bg)
		draw_rect(rect, border_col, false, 1.2)

		# Color Bar (b) based on orientation
		var grp_color = _get_group_color(grp)
		if grp_color != Color.TRANSPARENT and grp not in ["Especial", "Impuesto"]:
			var bar_rect: Rect2
			if i < 10: # Bottom row: color bar on top
				bar_rect = Rect2(rect.position.x, rect.position.y, rect.size.x, 14.0)
			elif i < 20: # Left col: color bar on right
				bar_rect = Rect2(rect.position.x + rect.size.x - 14.0, rect.position.y, 14.0, rect.size.y)
			elif i < 30: # Top row: color bar on bottom
				bar_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - 14.0, rect.size.x, 14.0)
			else: # Right col: color bar on left
				bar_rect = Rect2(rect.position.x, rect.position.y, 14.0, rect.size.y)

			draw_rect(bar_rect, grp_color)
			var grp_sym := _get_group_symbol(grp)
			if not grp_sym.is_empty():
				draw_string(ThemeDB.fallback_font, bar_rect.position + Vector2(2, 11), grp_sym, HORIZONTAL_ALIGNMENT_LEFT, 14, 9, Color.WHITE)

			# House / Hotel Tokens (c)
			if property_houses.has(i):
				var h_count = property_houses[i]
				if h_count == 5: # Hotel (Red Block)
					var h_center = bar_rect.position + (bar_rect.size * 0.5)
					draw_rect(Rect2(h_center.x - 6, h_center.y - 5, 12, 10), Color.RED)
					draw_rect(Rect2(h_center.x - 6, h_center.y - 5, 12, 10), Color.WHITE, false, 1.0)
				else: # Houses (1..4 Green Blocks)
					for h in range(h_count):
						var h_pos = bar_rect.position + Vector2(4 + h * 9, 2)
						if i in [11, 12, 13, 14, 15, 16, 17, 18, 19, 31, 32, 33, 34, 35, 36, 37, 38, 39]:
							h_pos = bar_rect.position + Vector2(2, 4 + h * 9)
						draw_rect(Rect2(h_pos.x, h_pos.y, 7, 7), Color(0.1, 0.8, 0.2))

		# Property Ownership Badge
		if property_owners.has(i):
			var owner_p = property_owners[i]
			var owner_col = PLAYER_COLORS.get(owner_p, Color.WHITE)
			var badge_pos = rect.position + Vector2(rect.size.x - 8, 8)
			draw_circle(badge_pos, 5.0, owner_col)
			draw_circle(badge_pos, 5.0, Color.WHITE, false, 1.0)

		# Space Icon / Glyph
		var icon_str = prop.get("icon", "")
		if icon_str != "":
			var icon_pos = rect.position + (rect.size * 0.5) + Vector2(-6, 4)
			draw_string(ThemeDB.fallback_font, icon_pos, icon_str, HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color.BLACK)

		# Price tag for purchasable spaces
		if prop["price"] > 0 and not property_owners.has(i):
			var pr_pos = rect.position + Vector2(2, rect.size.y - 3)
			draw_string(ThemeDB.fallback_font, pr_pos, "$%d" % prop["price"], HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x - 4), 9, Color(0.1, 0.5, 0.1))

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
