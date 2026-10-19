extends Node2D

# =========================================================================
# UNO BOARD - REDISEÑO VISUAL & ARQUITECTURA
# -------------------------------------------------------------------------
# SEPARACIÓN CLARA ENTRE TEMA Y REGLAS DE JUEGO:
# 1. Colores fijos de UNO (CARD_COLORS):
#    - Rojo (#D32F2F), Azul (#1976D2), Verde (#388E3C), Amarillo (#FBC02D) y
#      Negro Especial (#212121) para cartas Wild/Comodín.
#    - Estos colores son normativos e intrínsecos al reglamento oficial de UNO.
#      NO cambian con el tema para preservar la legibilidad y las reglas de juego.
# 2. Integración con ThemeManager:
#    - ThemeManager modula el tapete de la mesa (board_color), paneles de HUD,
#      bordes exteriores, marcos de información y fondo general de la escena.
# =========================================================================

const P1 = 1
const P2 = 2

# Colores Oficiales e Inmutables de las Cartas de UNO
const CARD_COLORS = {
	"Red": Color("#D32F2F"),
	"Blue": Color("#1976D2"),
	"Green": Color("#388E3C"),
	"Yellow": Color("#FBC02D"),
	"Wild": Color("#212121"),
	"WildColor": Color("#212121")
}

const CARD_TEXT_COLORS = {
	"Red": Color.WHITE,
	"Blue": Color.WHITE,
	"Green": Color.WHITE,
	"Yellow": Color("#1A1A1A"),
	"Wild": Color.WHITE,
	"WildColor": Color.WHITE
}

const COLOR_NAMES_ES = {
	"Red": "Rojo",
	"Blue": "Azul",
	"Green": "Verde",
	"Yellow": "Amarillo",
	"Wild": "Comodín",
	"WildColor": "Comodín"
}

# Iconos / Símbolos de cartas especiales
const CARD_SYMBOLS = {
	"Skip": "🚫",
	"Reverse": "🔁",
	"DrawTwo": "+2",
	"Wild": "🌈",
	"WildDrawFour": "+4"
}

var bridge
var current = P1
var winner = -1
var is_clockwise: bool = true

# Game State
var discard_pile: Array = []
var player_hand: Array = []
var opponent_card_count: int = 7
var deck_count: int = 50
var active_color: String = "Red"
var pending_wild_card_idx: int = -1

# UI Containers & Elements
var table_mat_panel: Panel
var top_bar: HBoxContainer
var status_header_panel: PanelContainer
var top_info_label: Label
var event_banner_panel: PanelContainer
var event_banner_label: Label
var uno_alert_banner: PanelContainer
var uno_alert_label: Label

# Opponent area
var opponent_hand_container: HBoxContainer
var opponent_count_badge: Label

# Center play area
var center_play_area: Panel
var discard_card_node: Control
var discard_inner_panel: PanelContainer
var active_color_badge: PanelContainer
var active_color_rect: ColorRect
var active_color_label: Label
var direction_label: Label
var draw_pile_container: Control
var draw_pile_button: Button
var draw_count_badge: Label

# Local Hand Area
var hand_container: Control
var wild_picker_modal: PanelContainer

# Navigation & HUD
var turn_indicator: TurnIndicator
var network_hud: NetworkStatusHUD
var rules_popup: RulesPopup
var current_theme: BoardTheme
var _pause_menu: CanvasLayer

# Local Player & Official UNO Rule State (Prompts 512, 513)
var local_player: int = P1
var uno_called_players: Array = []
var last_wild_draw_four_player: int = -1

# Action buttons bar & special buttons
var action_buttons_bar: HBoxContainer
var call_uno_btn: Button
var catch_uno_btn: Button
var challenge_wild_four_btn: Button
var jump_in_btn: Button

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
	_init_default_game_state()

	var gm = (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	if bridge.has_signal("turn_changed"):
		bridge.connect("turn_changed", _on_turn_changed)

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

	bridge.start_local_match_uno(P1, P2)
	current = bridge.current_player()

	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_ui()
	_update_status()

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
	current_theme.theme_name = "Noche Azul"
	current_theme.board_color = Color("#101923")
	current_theme.line_color = Color("#415A77")
	current_theme.light_color = Color("#5B7A9C")
	current_theme.dark_color = Color("#1B263B")
	current_theme.select_color = Color(1.0, 0.85, 0.25, 0.85)
	current_theme.valid_move_color = Color(0.2, 0.9, 0.5, 0.85)

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	_apply_theme_styling()
	_update_ui()

func _apply_theme_styling() -> void:
	if current_theme == null:
		return

	if table_mat_panel != null:
		var mat_style = StyleBoxFlat.new()
		mat_style.bg_color = current_theme.board_color.darkened(0.15)
		mat_style.border_color = current_theme.line_color
		mat_style.set_border_width_all(2)
		mat_style.set_corner_radius_all(14)
		table_mat_panel.add_theme_stylebox_override("panel", mat_style)

	if center_play_area != null:
		var c_style = StyleBoxFlat.new()
		c_style.bg_color = current_theme.dark_color.darkened(0.3)
		c_style.border_color = current_theme.line_color.darkened(0.1)
		c_style.set_border_width_all(2)
		c_style.set_corner_radius_all(16)
		center_play_area.add_theme_stylebox_override("panel", c_style)

	if status_header_panel != null:
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = current_theme.dark_color.darkened(0.1)
		h_style.border_color = current_theme.line_color
		h_style.set_border_width_all(1)
		h_style.set_corner_radius_all(8)
		status_header_panel.add_theme_stylebox_override("panel", h_style)

func _setup_ui() -> void:
	# Background Table Mat Panel
	table_mat_panel = Panel.new()
	table_mat_panel.name = "TableMatPanel"
	table_mat_panel.position = Vector2(20, 15)
	table_mat_panel.size = Vector2(680, 690)
	add_child(table_mat_panel)

	# Top Control Bar (Title, Rules, Turn, Network)
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(40, 25)
	top_bar.size = Vector2(640, 42)
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	var title_lbl = Label.new()
	title_lbl.text = "🎴 U N O"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	top_bar.add_child(title_lbl)

	status_header_panel = PanelContainer.new()
	status_header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(status_header_panel)

	top_info_label = Label.new()
	top_info_label.name = "TopInfoLabel"
	top_info_label.text = "Jugador 1: 7 cartas   |   Jugador 2: 7 cartas"
	top_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_info_label.add_theme_font_size_override("font_size", 14)
	top_info_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	status_header_panel.add_child(top_info_label)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(90, 36)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("uno"))
	top_bar.add_child(btn_rules)

	var tutorial_btn := Button.new()
	tutorial_btn.name = "UnoTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.custom_minimum_size = Vector2(105, 36)
	tutorial_btn.pressed.connect(start_uno_tutorial)
	top_bar.add_child(tutorial_btn)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(40, 75)
	add_child(turn_indicator)

	# Opponent Hand Visualizer (Top Area)
	var opp_vbox = VBoxContainer.new()
	opp_vbox.position = Vector2(40, 115)
	opp_vbox.size = Vector2(640, 70)
	opp_vbox.add_theme_constant_override("separation", 2)
	add_child(opp_vbox)

	opponent_count_badge = Label.new()
	opponent_count_badge.text = "👤 Mano del Oponente (7 cartas)"
	opponent_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_count_badge.add_theme_font_size_override("font_size", 12)
	opponent_count_badge.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	opp_vbox.add_child(opponent_count_badge)

	opponent_hand_container = HBoxContainer.new()
	opponent_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_hand_container.custom_minimum_size = Vector2(640, 48)
	opponent_hand_container.add_theme_constant_override("separation", -18) # Overlapping back cards
	opp_vbox.add_child(opponent_hand_container)

	# Event Notification Banner
	event_banner_panel = PanelContainer.new()
	event_banner_panel.name = "EventBanner"
	event_banner_panel.position = Vector2(100, 192)
	event_banner_panel.size = Vector2(520, 32)
	var ev_sb = StyleBoxFlat.new()
	ev_sb.bg_color = Color(0.08, 0.14, 0.22, 0.92)
	ev_sb.border_color = Color(0.3, 0.6, 0.9, 0.7)
	ev_sb.set_border_width_all(1)
	ev_sb.set_corner_radius_all(6)
	event_banner_panel.add_theme_stylebox_override("panel", ev_sb)

	event_banner_label = Label.new()
	event_banner_label.text = "¡Partida iniciada! Juega una carta que coincida en color o número."
	event_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_banner_label.add_theme_font_size_override("font_size", 12)
	event_banner_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	event_banner_panel.add_child(event_banner_label)
	add_child(event_banner_panel)

	# UNO Warning Banner (Hidden by default, shown when 1 card left)
	uno_alert_banner = PanelContainer.new()
	uno_alert_banner.name = "UnoAlertBanner"
	uno_alert_banner.position = Vector2(260, 185)
	uno_alert_banner.size = Vector2(200, 42)
	uno_alert_banner.visible = false
	var u_sb = StyleBoxFlat.new()
	u_sb.bg_color = Color(0.9, 0.1, 0.1, 0.95)
	u_sb.border_color = Color(1.0, 0.9, 0.2)
	u_sb.set_border_width_all(3)
	u_sb.set_corner_radius_all(10)
	uno_alert_banner.add_theme_stylebox_override("panel", u_sb)

	uno_alert_label = Label.new()
	uno_alert_label.text = "🔥 ¡¡ U N O !! 🔥"
	uno_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uno_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	uno_alert_label.add_theme_font_size_override("font_size", 18)
	uno_alert_label.add_theme_color_override("font_color", Color.WHITE)
	uno_alert_banner.add_child(uno_alert_label)
	add_child(uno_alert_banner)

	# Center Felt Playing Area
	center_play_area = Panel.new()
	center_play_area.name = "CenterPlayArea"
	center_play_area.position = Vector2(50, 230)
	center_play_area.size = Vector2(620, 210)
	add_child(center_play_area)

	_setup_center_play_area()

	# Local Hand Container (Fan Spread)
	hand_container = Control.new()
	hand_container.name = "HandContainer"
	hand_container.position = Vector2(30, 460)
	hand_container.size = Vector2(660, 220)
	add_child(hand_container)

	# Action Buttons Bar (🔥 ¡UNO!, 🚨 Acusar UNO, ⚡ Desafiar +4, ⚡ Jump-In)
	_setup_action_buttons()

	# Wild Color Picker Dialog Modal
	_setup_wild_picker_modal()

	# Rules Popup
	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 80)
	add_child(rules_popup)

	_apply_theme_styling()

func _setup_action_buttons() -> void:
	action_buttons_bar = HBoxContainer.new()
	action_buttons_bar.name = "ActionButtonsBar"
	action_buttons_bar.position = Vector2(60, 442)
	action_buttons_bar.size = Vector2(600, 34)
	action_buttons_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_buttons_bar.add_theme_constant_override("separation", 14)
	add_child(action_buttons_bar)

	# 1. Botón "🔥 ¡UNO!"
	call_uno_btn = Button.new()
	call_uno_btn.name = "CallUnoButton"
	call_uno_btn.text = "🔥 ¡UNO!"
	call_uno_btn.custom_minimum_size = Vector2(120, 34)
	var cu_sb = StyleBoxFlat.new()
	cu_sb.bg_color = Color(0.85, 0.2, 0.1, 0.95)
	cu_sb.border_color = Color(1.0, 0.85, 0.2)
	cu_sb.set_border_width_all(2)
	cu_sb.set_corner_radius_all(8)
	call_uno_btn.add_theme_stylebox_override("normal", cu_sb)
	var cu_sb_h = cu_sb.duplicate()
	cu_sb_h.border_color = Color(1.0, 1.0, 0.4)
	cu_sb_h.set_border_width_all(3)
	call_uno_btn.add_theme_stylebox_override("hover", cu_sb_h)
	call_uno_btn.add_theme_color_override("font_color", Color.WHITE)
	call_uno_btn.add_theme_font_size_override("font_size", 13)
	call_uno_btn.pressed.connect(_on_call_uno_pressed)
	action_buttons_bar.add_child(call_uno_btn)

	# 2. Botón "🚨 Acusar UNO"
	catch_uno_btn = Button.new()
	catch_uno_btn.name = "CatchUnoButton"
	catch_uno_btn.text = "🚨 Acusar UNO"
	catch_uno_btn.custom_minimum_size = Vector2(130, 34)
	var ca_sb = StyleBoxFlat.new()
	ca_sb.bg_color = Color(0.65, 0.12, 0.25, 0.95)
	ca_sb.border_color = Color(1.0, 0.4, 0.3)
	ca_sb.set_border_width_all(2)
	ca_sb.set_corner_radius_all(8)
	catch_uno_btn.add_theme_stylebox_override("normal", ca_sb)
	var ca_sb_h = ca_sb.duplicate()
	ca_sb_h.border_color = Color(1.0, 0.7, 0.5)
	ca_sb_h.set_border_width_all(3)
	catch_uno_btn.add_theme_stylebox_override("hover", ca_sb_h)
	catch_uno_btn.add_theme_color_override("font_color", Color.WHITE)
	catch_uno_btn.add_theme_font_size_override("font_size", 13)
	catch_uno_btn.visible = false
	catch_uno_btn.pressed.connect(_on_catch_uno_pressed)
	action_buttons_bar.add_child(catch_uno_btn)

	# 3. Botón "⚡ Desafiar +4"
	challenge_wild_four_btn = Button.new()
	challenge_wild_four_btn.name = "ChallengeWildFourButton"
	challenge_wild_four_btn.text = "⚡ Desafiar +4"
	challenge_wild_four_btn.custom_minimum_size = Vector2(130, 34)
	var ch_sb = StyleBoxFlat.new()
	ch_sb.bg_color = Color(0.2, 0.15, 0.45, 0.95)
	ch_sb.border_color = Color(0.85, 0.6, 1.0)
	ch_sb.set_border_width_all(2)
	ch_sb.set_corner_radius_all(8)
	challenge_wild_four_btn.add_theme_stylebox_override("normal", ch_sb)
	var ch_sb_h = ch_sb.duplicate()
	ch_sb_h.border_color = Color(1.0, 0.85, 0.3)
	ch_sb_h.set_border_width_all(3)
	challenge_wild_four_btn.add_theme_stylebox_override("hover", ch_sb_h)
	challenge_wild_four_btn.add_theme_color_override("font_color", Color.WHITE)
	challenge_wild_four_btn.add_theme_font_size_override("font_size", 13)
	challenge_wild_four_btn.visible = false
	challenge_wild_four_btn.pressed.connect(_on_challenge_wild_four_pressed)
	action_buttons_bar.add_child(challenge_wild_four_btn)

	# 4. Botón "⚡ Jump-In (Intercepción)"
	jump_in_btn = Button.new()
	jump_in_btn.name = "JumpInButton"
	jump_in_btn.text = "⚡ Jump-In"
	jump_in_btn.custom_minimum_size = Vector2(110, 34)
	var ji_sb = StyleBoxFlat.new()
	ji_sb.bg_color = Color(0.08, 0.35, 0.5, 0.95)
	ji_sb.border_color = Color(0.2, 0.9, 1.0)
	ji_sb.set_border_width_all(2)
	ji_sb.set_corner_radius_all(8)
	jump_in_btn.add_theme_stylebox_override("normal", ji_sb)
	var ji_sb_h = ji_sb.duplicate()
	ji_sb_h.border_color = Color(0.6, 1.0, 1.0)
	ji_sb_h.set_border_width_all(3)
	jump_in_btn.add_theme_stylebox_override("hover", ji_sb_h)
	jump_in_btn.add_theme_color_override("font_color", Color.WHITE)
	jump_in_btn.add_theme_font_size_override("font_size", 13)
	jump_in_btn.visible = false
	jump_in_btn.pressed.connect(_on_jump_in_pressed)
	action_buttons_bar.add_child(jump_in_btn)

func _setup_center_play_area() -> void:
	# 1. Discard Pile Area (Left Center)
	var discard_zone = VBoxContainer.new()
	discard_zone.position = Vector2(40, 15)
	discard_zone.size = Vector2(170, 180)
	discard_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	discard_zone.add_theme_constant_override("separation", 6)
	center_play_area.add_child(discard_zone)

	var discard_title = Label.new()
	discard_title.text = "PILA DE DESCARTE"
	discard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_title.add_theme_font_size_override("font_size", 11)
	discard_title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	discard_zone.add_child(discard_title)

	discard_card_node = Control.new()
	discard_card_node.name = "DiscardCardNode"
	discard_card_node.custom_minimum_size = Vector2(100, 150)
	discard_card_node.size = Vector2(100, 150)
	discard_card_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	discard_zone.add_child(discard_card_node)

	# 2. Central Active Color & Direction Indicator (Center)
	var center_info_vbox = VBoxContainer.new()
	center_info_vbox.position = Vector2(230, 20)
	center_info_vbox.size = Vector2(160, 170)
	center_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_info_vbox.add_theme_constant_override("separation", 10)
	center_play_area.add_child(center_info_vbox)

	var color_title = Label.new()
	color_title.text = "COLOR ACTIVO"
	color_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_title.add_theme_font_size_override("font_size", 11)
	color_title.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	center_info_vbox.add_child(color_title)

	active_color_badge = PanelContainer.new()
	active_color_badge.custom_minimum_size = Vector2(140, 48)
	var ac_sb = StyleBoxFlat.new()
	ac_sb.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	ac_sb.border_color = CARD_COLORS["Red"]
	ac_sb.set_border_width_all(3)
	ac_sb.set_corner_radius_all(10)
	ac_sb.content_margin_left = 10
	ac_sb.content_margin_right = 10
	active_color_badge.add_theme_stylebox_override("panel", ac_sb)

	var ac_hbox = HBoxContainer.new()
	ac_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ac_hbox.add_theme_constant_override("separation", 8)
	active_color_badge.add_child(ac_hbox)

	active_color_rect = ColorRect.new()
	active_color_rect.custom_minimum_size = Vector2(22, 22)
	active_color_rect.color = CARD_COLORS["Red"]
	ac_hbox.add_child(active_color_rect)

	active_color_label = Label.new()
	active_color_label.text = "ROJO"
	active_color_label.add_theme_font_size_override("font_size", 14)
	active_color_label.add_theme_color_override("font_color", Color.WHITE)
	ac_hbox.add_child(active_color_label)
	center_info_vbox.add_child(active_color_badge)

	# Turn Direction Indicator
	direction_label = Label.new()
	direction_label.text = "Sentido: ↻ Horario"
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	direction_label.add_theme_font_size_override("font_size", 12)
	direction_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	center_info_vbox.add_child(direction_label)

	# 3. Draw Pile / Deck Area (Right Center)
	var deck_zone = VBoxContainer.new()
	deck_zone.position = Vector2(410, 15)
	deck_zone.size = Vector2(170, 180)
	deck_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_zone.add_theme_constant_override("separation", 6)
	center_play_area.add_child(deck_zone)

	var deck_title = Label.new()
	deck_title.text = "MAZO DE ROBO"
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_title.add_theme_font_size_override("font_size", 11)
	deck_title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	deck_zone.add_child(deck_title)

	draw_pile_container = Control.new()
	draw_pile_container.custom_minimum_size = Vector2(100, 150)
	draw_pile_container.size = Vector2(100, 150)
	draw_pile_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_zone.add_child(draw_pile_container)

	_setup_draw_deck_visual()

func _setup_draw_deck_visual() -> void:
	# Layered 3D deck back aesthetic
	for offset_idx in [3, 2, 1]:
		var layer = Panel.new()
		layer.position = Vector2(offset_idx * 2, offset_idx * 2)
		layer.size = Vector2(100, 145)
		var l_style = StyleBoxFlat.new()
		l_style.bg_color = Color(0.12, 0.12, 0.16)
		l_style.border_color = Color(0.3, 0.3, 0.4)
		l_style.set_border_width_all(1)
		l_style.set_corner_radius_all(8)
		layer.add_theme_stylebox_override("panel", l_style)
		draw_pile_container.add_child(layer)

	# Main interactive deck button (styled as UNO Card Back)
	draw_pile_button = Button.new()
	draw_pile_button.name = "DrawPileButton"
	draw_pile_button.position = Vector2(0, 0)
	draw_pile_button.size = Vector2(100, 145)
	draw_pile_button.custom_minimum_size = Vector2(100, 145)

	var d_style = StyleBoxFlat.new()
	d_style.bg_color = Color("#1A1A1A")
	d_style.border_color = Color(0.9, 0.8, 0.2)
	d_style.set_border_width_all(2)
	d_style.set_corner_radius_all(8)
	draw_pile_button.add_theme_stylebox_override("normal", d_style)

	var d_hover = d_style.duplicate()
	d_hover.border_color = Color(1.0, 1.0, 0.4)
	d_hover.set_border_width_all(3)
	draw_pile_button.add_theme_stylebox_override("hover", d_hover)

	draw_pile_container.add_child(draw_pile_button)

	# UNO Oval on Deck Back
	var oval = Panel.new()
	oval.position = Vector2(12, 38)
	oval.size = Vector2(76, 68)
	oval.rotation_degrees = -20.0
	var o_style = StyleBoxFlat.new()
	o_style.bg_color = Color("#D32F2F") # Red UNO oval
	o_style.border_color = Color(0.95, 0.85, 0.3)
	o_style.set_border_width_all(2)
	o_style.set_corner_radius_all(30)
	oval.add_theme_stylebox_override("panel", o_style)
	oval.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile_button.add_child(oval)

	var uno_lbl = Label.new()
	uno_lbl.text = "UNO"
	uno_lbl.position = Vector2(8, 14)
	uno_lbl.size = Vector2(60, 40)
	uno_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uno_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	uno_lbl.add_theme_font_size_override("font_size", 20)
	uno_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	uno_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oval.add_child(uno_lbl)

	draw_count_badge = Label.new()
	draw_count_badge.position = Vector2(0, 115)
	draw_count_badge.size = Vector2(100, 24)
	draw_count_badge.text = "Robar (50)"
	draw_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_count_badge.add_theme_font_size_override("font_size", 12)
	draw_count_badge.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	draw_count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile_button.add_child(draw_count_badge)

	draw_pile_button.pressed.connect(_on_draw_pile_pressed)

func start_uno_tutorial() -> void:
	var UnoTut = load("res://scripts/tutorials/uno_tutorial.gd")
	if UnoTut != null:
		UnoTut.start_on_board(self)

# -------------------------------------------------------------------------
# WILD COLOR SELECTOR MODAL (a, d)
# -------------------------------------------------------------------------
func _setup_wild_picker_modal() -> void:
	wild_picker_modal = PanelContainer.new()
	wild_picker_modal.name = "WildPickerModal"
	wild_picker_modal.position = Vector2(180, 230)
	wild_picker_modal.size = Vector2(360, 220)
	wild_picker_modal.visible = false
	wild_picker_modal.z_index = 30

	var m_style = StyleBoxFlat.new()
	m_style.bg_color = Color(0.10, 0.12, 0.18, 0.98)
	m_style.border_color = Color(1.0, 0.85, 0.2)
	m_style.set_border_width_all(3)
	m_style.set_corner_radius_all(12)
	m_style.content_margin_left = 16
	m_style.content_margin_right = 16
	m_style.content_margin_top = 14
	m_style.content_margin_bottom = 16
	wild_picker_modal.add_theme_stylebox_override("panel", m_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	wild_picker_modal.add_child(vbox)

	var title = Label.new()
	title.text = "🌈 ELIGE UN COLOR PARA EL COMODÍN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	var color_options = [
		{"key": "Red", "label": "🔴 ROJO", "color": CARD_COLORS["Red"]},
		{"key": "Blue", "label": "🔵 AZUL", "color": CARD_COLORS["Blue"]},
		{"key": "Green", "label": "🟢 VERDE", "color": CARD_COLORS["Green"]},
		{"key": "Yellow", "label": "🟡 AMARILLO", "color": CARD_COLORS["Yellow"]}
	]

	for opt in color_options:
		var btn = Button.new()
		btn.text = opt["label"]
		btn.custom_minimum_size = Vector2(150, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var b_style = StyleBoxFlat.new()
		b_style.bg_color = opt["color"]
		b_style.set_corner_radius_all(8)
		b_style.set_border_width_all(2)
		b_style.border_color = Color.WHITE
		btn.add_theme_stylebox_override("normal", b_style)

		var b_hover = b_style.duplicate()
		b_hover.border_color = Color(1.0, 0.9, 0.2)
		b_hover.set_border_width_all(3)
		btn.add_theme_stylebox_override("hover", b_hover)

		var col_key = opt["key"]
		btn.pressed.connect(func(): _on_wild_color_chosen(col_key))
		grid.add_child(btn)

	add_child(wild_picker_modal)

func _init_default_game_state() -> void:
	player_hand = [
		{"color": "Red", "value": "5"},
		{"color": "Blue", "value": "5"},
		{"color": "Green", "value": "Skip"},
		{"color": "Yellow", "value": "DrawTwo"},
		{"color": "Wild", "value": "Wild"},
		{"color": "Red", "value": "Reverse"},
		{"color": "Yellow", "value": "9"}
	]
	discard_pile = [{"color": "Red", "value": "5"}]
	active_color = "Red"
	deck_count = 50
	opponent_card_count = 7
	is_clockwise = true

# -------------------------------------------------------------------------
# CARD CREATION & RENDERING HELPER (a, b)
# -------------------------------------------------------------------------
func _create_card_visual(card: Dictionary, is_playable: bool = true, is_large: bool = false, is_interceptable: bool = false) -> Control:
	var c_color = card.get("color", "Red")
	var c_val = str(card.get("value", "0"))

	var width = 100.0 if is_large else 95.0
	var height = 150.0 if is_large else 145.0

	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(width, height)
	card_panel.size = Vector2(width, height)
	card_panel.pivot_offset = Vector2(width / 2.0, height) # Fan pivot at bottom center
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Base card color (soporta paleta Okabe-Ito / Alto Contraste de ThemeManager)
	var base_col = _get_accessible_card_color(c_color)
	var style = StyleBoxFlat.new()
	style.bg_color = base_col
	style.set_corner_radius_all(10)
	style.set_border_width_all(4 if is_interceptable else (3 if is_playable else 1))

	# Visual Playable Highlight (b) & Jump-In Electric Border (Prompt 513)
	if is_interceptable:
		style.border_color = Color(0.2, 0.95, 1.0, 1.0) # Borde eléctrico neón cian
		style.shadow_color = Color(0.0, 0.85, 1.0, 0.85)
		style.shadow_size = 9
		card_panel.modulate = Color(1.15, 1.25, 1.4, 1.0)
	elif is_playable:
		style.border_color = Color(1.0, 0.88, 0.2, 1.0) # Radiant Gold
		style.shadow_color = Color(1.0, 0.85, 0.2, 0.45)
		style.shadow_size = 6
	else:
		style.border_color = Color(0.4, 0.4, 0.4, 0.6)
		card_panel.modulate = Color(0.65, 0.65, 0.7, 0.75) # Dim non-playable cards

	card_panel.add_theme_stylebox_override("panel", style)

	# Inner White Slanted Oval (Classic UNO aesthetic)
	var oval = Panel.new()
	oval.position = Vector2(10, 22)
	oval.size = Vector2(width - 20, height - 44)
	oval.rotation_degrees = -18.0
	oval.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var oval_style = StyleBoxFlat.new()
	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		# 4-quadrant rainbow style for Wild
		oval_style.bg_color = Color(0.15, 0.15, 0.2)
		oval_style.border_color = Color(1.0, 0.85, 0.2)
		oval_style.set_border_width_all(2)
	else:
		oval_style.bg_color = Color(0.96, 0.96, 0.98) # Crisp white oval
		oval_style.border_color = Color(1.0, 1.0, 1.0, 0.8)
		oval_style.set_border_width_all(1)

	oval_style.set_corner_radius_all(24)
	oval.add_theme_stylebox_override("panel", oval_style)
	card_panel.add_child(oval)

	# Central Large Symbol / Number (a)
	var center_symbol = _get_card_display_symbol(c_val)
	var center_lbl = Label.new()
	center_lbl.text = center_symbol
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		center_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		center_lbl.add_theme_font_size_override("font_size", 34 if is_large else 30)
	else:
		center_lbl.add_theme_color_override("font_color", base_col)
		center_lbl.add_theme_font_size_override("font_size", 42 if is_large else 36)

	oval.add_child(center_lbl)

	# Mini Indices (Top-Left and Bottom-Right) + Símbolo de Accesibilidad Daltónicos
	var mini_sym = _get_card_mini_symbol(c_val)
	var cb_sym = _get_colorblind_symbol(c_color)
	var cb_active: bool = true
	if (is_inside_tree() and has_node("/root/ThemeManager")) and get_node("/root/ThemeManager").has_method("is_colorblind_mode"):
		cb_active = true # Siempre disponible con realce extra cuando colorblind_mode está activo

	var tl_lbl = Label.new()
	tl_lbl.text = "%s %s" % [mini_sym, cb_sym] if cb_active and not cb_sym.is_empty() else mini_sym
	tl_lbl.position = Vector2(6, 4)
	tl_lbl.add_theme_font_size_override("font_size", 13)
	tl_lbl.add_theme_color_override("font_color", Color.WHITE)
	tl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(tl_lbl)

	var br_lbl = Label.new()
	br_lbl.text = "%s %s" % [cb_sym, mini_sym] if cb_active and not cb_sym.is_empty() else mini_sym
	br_lbl.position = Vector2(width - 38, height - 24)
	br_lbl.add_theme_font_size_override("font_size", 13)
	br_lbl.add_theme_color_override("font_color", Color.WHITE)
	br_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(br_lbl)

	# For Wild Cards, add mini 4-color indicators in corners
	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		var quad_container = HBoxContainer.new()
		quad_container.position = Vector2(width / 2.0 - 24, height - 18)
		quad_container.add_theme_constant_override("separation", 3)
		for q_col in [CARD_COLORS["Red"], CARD_COLORS["Blue"], CARD_COLORS["Green"], CARD_COLORS["Yellow"]]:
			var q_rect = ColorRect.new()
			q_rect.custom_minimum_size = Vector2(8, 8)
			q_rect.color = q_col
			quad_container.add_child(q_rect)
		card_panel.add_child(quad_container)

	if is_interceptable:
		var ji_badge = Label.new()
		ji_badge.text = "⚡ JUMP-IN"
		ji_badge.position = Vector2(0, height - 19)
		ji_badge.size = Vector2(width, 16)
		ji_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ji_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ji_badge.add_theme_font_size_override("font_size", 9)
		ji_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
		card_panel.add_child(ji_badge)

	return card_panel

func _create_card_back_visual() -> Control:
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(40, 56)
	card_panel.size = Vector2(40, 56)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1A1A1A")
	style.border_color = Color(0.9, 0.8, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	card_panel.add_theme_stylebox_override("panel", style)

	var oval = Panel.new()
	oval.position = Vector2(6, 12)
	oval.size = Vector2(28, 32)
	oval.rotation_degrees = -18.0
	var o_style = StyleBoxFlat.new()
	o_style.bg_color = Color("#D32F2F")
	o_style.set_corner_radius_all(12)
	oval.add_theme_stylebox_override("panel", o_style)
	card_panel.add_child(oval)

	var lbl = Label.new()
	lbl.text = "UNO"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	oval.add_child(lbl)

	return card_panel

func _get_accessible_card_color(c_color: String) -> Color:
	var fallback: Color = CARD_COLORS.get(c_color, CARD_COLORS["Wild"])
	if c_color in ["Wild", "WildColor"]:
		return fallback
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = get_node("/root/ThemeManager")
		if tm.has_method("is_colorblind_mode") and bool(tm.call("is_colorblind_mode")):
			if tm.has_method("get_accessible_color"):
				return tm.call("get_accessible_color", c_color, fallback)
	return fallback

func _get_colorblind_symbol(c_color: String) -> String:
	match c_color:
		"Red": return "▲"
		"Blue": return "●"
		"Green": return "■"
		"Yellow": return "◆"
		"Orange": return "★"
		"Violet": return "⬟"
		_: return "✦"

func _get_card_display_symbol(val: String) -> String:
	match val:
		"Skip": return "🚫"
		"Reverse": return "🔁"
		"DrawTwo": return "+2"
		"Wild": return "🌈"
		"WildDrawFour": return "+4"
		_: return val

func _get_card_mini_symbol(val: String) -> String:
	match val:
		"Skip": return "🚫"
		"Reverse": return "🔁"
		"DrawTwo": return "+2"
		"Wild": return "W"
		"WildDrawFour": return "+4"
		_: return val

# -------------------------------------------------------------------------
# UI REFRESH & HAND FAN DISPLAY (b)
# -------------------------------------------------------------------------
func _is_card_interceptable(card: Dictionary) -> bool:
	# Jump-In: Si no es el turno del jugador local pero tiene en mano una carta
	# exactamente idéntica (mismo color y valor) al tope del descarte.
	if current == local_player:
		return false
	if discard_pile.is_empty():
		return false

	var c_color = str(card.get("color", ""))
	var c_val = str(card.get("value", ""))

	# No se puede interceptar con comodines (regla oficial UNO)
	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		return false

	var top_card = discard_pile.back()
	var top_color = str(top_card.get("color", ""))
	var top_val = str(top_card.get("value", ""))

	return c_color == top_color and c_val == top_val

func _is_card_playable(card: Dictionary) -> bool:
	var c_color = card.get("color", "Red")
	var c_val = str(card.get("value", "0"))

	var top_card = discard_pile.back() if not discard_pile.is_empty() else {"color": "Red", "value": "1"}
	var top_val = str(top_card.get("value", "1"))

	# Wild cards are always playable
	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		return true

	# Match active color or value
	if c_color == active_color or c_val == top_val:
		return true

	return false

func _update_ui(animate_drawn_index: int = -1) -> void:
	# 1. Update Top Bar Counts
	var p1_count = player_hand.size() if current == P1 else opponent_card_count
	var p2_count = opponent_card_count if current == P1 else player_hand.size()
	top_info_label.text = "🎴  Jugador 1: %d cartas   |   Jugador 2: %d cartas" % [p1_count, p2_count]

	# 2. Update Opponent Hand Backs
	for child in opponent_hand_container.get_children():
		child.queue_free()
	opponent_count_badge.text = "👤 Mano del Oponente (%d cartas)" % opponent_card_count
	for i in range(min(12, opponent_card_count)):
		opponent_hand_container.add_child(_create_card_back_visual())

	# 3. Update Discard Pile Card
	_update_discard_display()

	# 4. Update Active Color & Direction
	_update_active_color_indicator()
	direction_label.text = "Sentido: %s" % ("↻ Horario" if is_clockwise else "↺ Antihorario")

	# 5. Update Deck Count
	if draw_count_badge != null:
		draw_count_badge.text = "Robar (%d)" % deck_count

	# 6. Check UNO Alert (when either player has 1 card)
	if uno_alert_banner != null:
		var has_one = (player_hand.size() == 1 or opponent_card_count == 1)
		uno_alert_banner.visible = has_one
		if has_one:
			var tw_alert = uno_alert_banner.create_tween().set_loops()
			tw_alert.tween_property(uno_alert_banner, "scale", Vector2(1.08, 1.08), 0.3)
			tw_alert.tween_property(uno_alert_banner, "scale", Vector2(1.0, 1.0), 0.3)

	# 7. Render Hand Cards in Fan Spread (b)
	for child in hand_container.get_children():
		child.queue_free()

	var n_cards = player_hand.size()
	if n_cards == 0:
		return

	var center_x = hand_container.size.x / 2.0
	var card_w = 95.0
	var spread = min(68.0, (hand_container.size.x - card_w - 40.0) / max(1, n_cards - 1))
	var start_x = center_x - ((n_cards - 1) * spread) / 2.0 - card_w / 2.0

	var has_any_playable = false
	var has_any_interceptable = false

	for i in range(n_cards):
		var card = player_hand[i]
		var is_playable = (current == local_player) and _is_card_playable(card)
		var is_interceptable = _is_card_interceptable(card)
		if is_playable:
			has_any_playable = true
		if is_interceptable:
			has_any_interceptable = true

		var card_node = _create_card_visual(card, is_playable, false, is_interceptable)

		# Fan angle spread (-18° to +18°)
		var angle_deg = 0.0
		if n_cards > 1:
			angle_deg = lerp(-16.0, 16.0, float(i) / float(n_cards - 1))
		card_node.rotation_degrees = angle_deg

		# Playable or interceptable cards get an inviting slight natural elevation (+8px)
		var extra_lift = -10.0 if (is_playable or is_interceptable) else 0.0
		var resting_pos = Vector2(start_x + i * spread, 35.0 + abs(angle_deg) * 1.1 + extra_lift)
		card_node.position = resting_pos
		card_node.set_meta("resting_y", resting_pos.y)

		# Pulsing glow animation on playable or interceptable cards (b, Prompt 513)
		if is_playable or is_interceptable:
			var tw_pulse = card_node.create_tween().set_loops()
			if is_interceptable:
				tw_pulse.tween_property(card_node, "modulate", Color(1.3, 1.45, 1.6, 1.0), 0.35)
				tw_pulse.tween_property(card_node, "modulate", Color(0.9, 1.05, 1.25, 1.0), 0.35)
			else:
				tw_pulse.tween_property(card_node, "modulate", Color(1.2, 1.2, 0.85, 1.0), 0.5)
				tw_pulse.tween_property(card_node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

			# Hover Elevation & Zoom
			card_node.mouse_entered.connect(func():
				var tw = card_node.create_tween().set_parallel(true)
				tw.tween_property(card_node, "position:y", card_node.get_meta("resting_y") - 28.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(card_node, "scale", Vector2(1.12, 1.12), 0.15)
				card_node.z_index = 15
			)
			card_node.mouse_exited.connect(func():
				var tw = card_node.create_tween().set_parallel(true)
				tw.tween_property(card_node, "position:y", card_node.get_meta("resting_y"), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(card_node, "scale", Vector2(1.0, 1.0), 0.15)
				card_node.z_index = 0
			)

			var card_idx = i
			card_node.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if is_interceptable:
						_execute_intercept_card(card_idx, card_node.global_position)
					elif is_playable:
						_on_card_pressed(card_idx, card_node)
			)

		hand_container.add_child(card_node)

		# Draw animation entrance from deck
		if i == animate_drawn_index and draw_pile_button != null:
			var deck_global = draw_pile_button.global_position
			var start_local = hand_container.to_local(deck_global)
			card_node.position = start_local
			card_node.scale = Vector2(0.5, 0.5)
			var tw_draw = card_node.create_tween().set_parallel(true)
			tw_draw.tween_property(card_node, "position", resting_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw_draw.tween_property(card_node, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Glow on Draw Pile if no playable cards are in hand
	if draw_pile_button != null:
		if not has_any_playable and current == local_player:
			draw_pile_button.modulate = Color(1.2, 1.2, 0.8)
		else:
			draw_pile_button.modulate = Color(1.0, 1.0, 1.0)

	# Actualizar botones de acción de UNO (Prompt 513)
	var opponent_id = P2 if local_player == P1 else P1
	if catch_uno_btn != null:
		var can_catch = (opponent_card_count == 1 and not uno_called_players.has(opponent_id))
		catch_uno_btn.visible = can_catch

	if challenge_wild_four_btn != null:
		var can_challenge = (last_wild_draw_four_player == opponent_id and current == local_player)
		challenge_wild_four_btn.visible = can_challenge

	if jump_in_btn != null:
		jump_in_btn.visible = has_any_interceptable and (current != local_player)

	if call_uno_btn != null:
		var can_call = (player_hand.size() <= 2 and not uno_called_players.has(local_player))
		if can_call:
			call_uno_btn.modulate = Color(1.2, 1.1, 0.9)
		else:
			call_uno_btn.modulate = Color(1.0, 1.0, 1.0)

func _update_discard_display() -> void:
	for child in discard_card_node.get_children():
		child.queue_free()

	var top_card = discard_pile.back() if not discard_pile.is_empty() else {"color": "Red", "value": "1"}
	var card_visual = _create_card_visual(top_card, false, true)
	card_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card_visual.position = Vector2(0, 0)
	discard_card_node.add_child(card_visual)

func _update_active_color_indicator() -> void:
	var col = CARD_COLORS.get(active_color, CARD_COLORS["Red"])
	if active_color_rect != null:
		active_color_rect.color = col
	if active_color_label != null:
		active_color_label.text = COLOR_NAMES_ES.get(active_color, active_color).to_upper()
		active_color_label.add_theme_color_override("font_color", col if active_color != "Yellow" else Color(1.0, 0.9, 0.2))
	if active_color_badge != null:
		var sb = active_color_badge.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb != null:
			sb.border_color = col
			active_color_badge.add_theme_stylebox_override("panel", sb)

# -------------------------------------------------------------------------
# FLYING CARD ANIMATION TO DISCARD PILE (c)
# -------------------------------------------------------------------------
func _animate_card_to_discard(card_dict: Dictionary, start_global_pos: Vector2) -> void:
	var flying_card = _create_card_visual(card_dict, false, true)
	flying_card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	flying_card.z_index = 50
	flying_card.global_position = start_global_pos
	flying_card.pivot_offset = Vector2(50, 75)
	add_child(flying_card)

	var target_global_pos = discard_card_node.global_position

	var tween = create_tween().set_parallel(true)
	tween.tween_property(flying_card, "global_position", target_global_pos, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying_card, "rotation_degrees", randf_range(-14.0, 14.0), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Elevation arc effect (scales up to 1.18 then settles to 1.0)
	var scale_tween = create_tween()
	scale_tween.tween_property(flying_card, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(flying_card, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func():
		_update_discard_display()
		_update_active_color_indicator()
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_card_flip()
		flying_card.queue_free()
	)

# -------------------------------------------------------------------------
# CARD INTERACTIONS & WILD FLOW
# -------------------------------------------------------------------------
func _on_card_pressed(idx: int, card_btn: Control) -> void:
	if winner != -1 or wild_picker_modal.visible:
		return

	if idx < 0 or idx >= player_hand.size():
		return

	var played_card = player_hand[idx]
	var c_color = played_card.get("color", "Red")
	var c_val = str(played_card.get("value", "0"))

	# If it's a Wild or Wild Draw 4 card, open color selector dialog
	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		pending_wild_card_idx = idx
		wild_picker_modal.visible = true
		return

	_execute_play_card(idx, card_btn.global_position, c_color)

func _on_wild_color_chosen(chosen_col: String) -> void:
	wild_picker_modal.visible = false
	if pending_wild_card_idx >= 0 and pending_wild_card_idx < player_hand.size():
		var btn_pos = hand_container.global_position + Vector2(250, 50)
		_execute_play_card(pending_wild_card_idx, btn_pos, chosen_col)
	pending_wild_card_idx = -1

func _execute_play_card(idx: int, start_pos: Vector2, chosen_col: String) -> void:
	var cmd = {
		"command_type": "PlayCardCommand",
		"player": current,
		"card_index": idx,
		"chosen_color": chosen_col
	}
	bridge.send_command_json(current, JSON.stringify(cmd))

	if idx >= 0 and idx < player_hand.size():
		var played_card = player_hand[idx]
		player_hand.remove_at(idx)
		discard_pile.append(played_card)
		active_color = chosen_col

		var val_str = str(played_card.get("value", ""))
		if val_str == "WildDrawFour":
			last_wild_draw_four_player = current
		else:
			last_wild_draw_four_player = -1

		var val_name = _get_card_display_symbol(val_str)
		event_banner_label.text = "Jugador %d jugó %s %s" % [
			current,
			COLOR_NAMES_ES.get(played_card.get("color", ""), ""),
			val_name
		]

		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_card_flip()

		_animate_card_to_discard(played_card, start_pos)
		_update_ui()

func _on_draw_pile_pressed() -> void:
	_sfx_card_flip()
	if winner != -1 or wild_picker_modal.visible:
		return

	var cmd = {
		"command_type": "DrawCardCommand",
		"player": current
	}
	bridge.send_command_json(current, JSON.stringify(cmd))

	if deck_count > 0:
		deck_count -= 1
		# Predictive local draw placeholder until event syncs
		var drawn_card = {"color": active_color, "value": str(randi_range(0, 9))}
		player_hand.append(drawn_card)
		var drawn_idx = player_hand.size() - 1
		event_banner_label.text = "Jugador %d robó una carta del mazo" % current

		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_card_flip()

		_update_ui(drawn_idx)

# -------------------------------------------------------------------------
# UNO OFFICIAL RULES ACTIONS & HANDLERS (Prompt 513)
# -------------------------------------------------------------------------
func _on_call_uno_pressed() -> void:
	if winner != -1:
		return
	var cmd = {
		"type": "CallUnoCommand",
		"command_type": "CallUnoCommand",
		"player": local_player
	}
	bridge.send_command_json(local_player, JSON.stringify(cmd))

func _on_catch_uno_pressed() -> void:
	if winner != -1:
		return
	var opponent_id = P2 if local_player == P1 else P1
	var cmd = {
		"type": "CatchUnoFailureCommand",
		"command_type": "CatchUnoFailureCommand",
		"accuser": local_player,
		"target": opponent_id
	}
	bridge.send_command_json(local_player, JSON.stringify(cmd))

func _on_challenge_wild_four_pressed() -> void:
	if winner != -1:
		return
	var cmd = {
		"type": "ChallengeWildDrawFourCommand",
		"command_type": "ChallengeWildDrawFourCommand",
		"challenger": local_player
	}
	bridge.send_command_json(local_player, JSON.stringify(cmd))

func _on_jump_in_pressed() -> void:
	if winner != -1:
		return
	for i in range(player_hand.size()):
		if _is_card_interceptable(player_hand[i]):
			var btn_pos = hand_container.global_position + Vector2(250, 50)
			_execute_intercept_card(i, btn_pos)
			break

func _execute_intercept_card(idx: int, start_pos: Vector2) -> void:
	if idx < 0 or idx >= player_hand.size():
		return
	var cmd = {
		"type": "InterceptCommand",
		"command_type": "InterceptCommand",
		"player": local_player,
		"card_index": idx
	}
	bridge.send_command_json(local_player, JSON.stringify(cmd))

	var played_card = player_hand[idx]
	player_hand.remove_at(idx)
	discard_pile.append(played_card)
	active_color = played_card.get("color", active_color)

	var val_name = _get_card_display_symbol(str(played_card.get("value", "")))
	event_banner_label.text = "⚡ ¡Jugador %d ejecutó JUMP-IN con %s %s!" % [
		local_player,
		COLOR_NAMES_ES.get(played_card.get("color", ""), ""),
		val_name
	]

	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_card_flip()

	_animate_card_to_discard(played_card, start_pos)
	_update_ui()

# -------------------------------------------------------------------------
# EVENT JSON PROCESSING (SYNC FROM RUST OPEN_TABLE ENGINE)
# -------------------------------------------------------------------------
func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))

			if event_type == "CardPlayedEvent" or event_type == "uno_game::CardPlayedEvent":
				var p = int(event.get("player", current))
				if event.has("card"):
					var c = event["card"]
					discard_pile.append(c)
					if p != current:
						opponent_card_count = max(0, opponent_card_count - 1)
						_animate_card_to_discard(c, Vector2(340, 130))
					var val_str = str(c.get("value", ""))
					if val_str == "WildDrawFour":
						last_wild_draw_four_player = p
					else:
						last_wild_draw_four_player = -1
				if event.has("new_color"):
					active_color = str(event["new_color"])
				_update_active_color_indicator()

			elif event_type == "DrewAndPlayedEvent" or event_type == "uno_game::DrewAndPlayedEvent":
				var p = int(event.get("player", current))
				if event.has("card"):
					var c = event["card"]
					discard_pile.append(c)
					if p != current:
						_animate_card_to_discard(c, Vector2(340, 130))
				if event.has("new_color"):
					active_color = str(event["new_color"])
				_update_active_color_indicator()

			elif event_type == "ColorChangedEvent" or event_type == "uno_game::ColorChangedEvent":
				if event.has("color"):
					active_color = str(event["color"])
				elif event.has("new_color"):
					active_color = str(event["new_color"])
				_update_active_color_indicator()
				event_banner_label.text = "¡Color cambiado a %s!" % COLOR_NAMES_ES.get(active_color, active_color).to_upper()

			elif event_type == "TurnReversedEvent" or event_type == "uno_game::TurnReversedEvent":
				is_clockwise = not is_clockwise
				event_banner_label.text = "🔁 ¡Reversa! Giro de turno cambiado a %s" % ("Horario" if is_clockwise else "Antihorario")

			elif event_type == "PlayerSkippedEvent" or event_type == "uno_game::PlayerSkippedEvent":
				var skipped_p = int(event.get("skipped_player", 0))
				event_banner_label.text = "🚫 ¡Jugador %d fue saltado!" % skipped_p

			elif event_type == "CardsDrawnEvent" or event_type == "uno_game::CardsDrawnEvent":
				var p = int(event.get("player", current))
				var cnt = int(event.get("count", 1))
				deck_count = max(0, deck_count - cnt)
				if p != current:
					opponent_card_count += cnt
				event_banner_label.text = "🎴 Jugador %d robó %d carta(s)" % [p, cnt]

			elif event_type == "GameOverEvent" or event_type == "uno_game::GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))

			elif event_type == "UnoCalledEvent" or event_type == "uno_game::UnoCalledEvent":
				var p = int(event.get("player", 0))
				if not uno_called_players.has(p):
					uno_called_players.append(p)
				event_banner_label.text = "🔥 ¡Jugador %d gritó ¡¡UNO!! 🔥" % p
				if uno_alert_banner != null:
					uno_alert_banner.visible = true
					uno_alert_label.text = "🔥 ¡¡ JUGADOR %d CANTÓ UNO !! 🔥" % p

			elif event_type == "UnoPenaltyEvent" or event_type == "uno_game::UnoPenaltyEvent":
				var target_p = int(event.get("target", 0))
				var accuser_p = int(event.get("accuser", 0))
				var drawn_cnt = int(event.get("drawn", 2))
				event_banner_label.text = "🚨 ¡Jugador %d acusó al Jugador %d! (+%d cartas de penalización)" % [accuser_p, target_p, drawn_cnt]
				uno_called_players.erase(target_p)

			elif event_type == "WildDrawFourChallengedEvent" or event_type == "uno_game::WildDrawFourChallengedEvent":
				var ch = int(event.get("challenger", 0))
				var tg = int(event.get("target", 0))
				var was_illegal = bool(event.get("was_illegal", false))
				var drawn_cnt = int(event.get("cards_drawn", 0))
				if was_illegal:
					event_banner_label.text = "⚡ ¡Desafío exitoso! Jugador %d tenía carta del color y roba %d cartas" % [tg, drawn_cnt]
				else:
					event_banner_label.text = "⚡ ¡Desafío fallido! Jugador %d jugó legal. Jugador %d roba %d cartas" % [tg, ch, drawn_cnt]
				last_wild_draw_four_player = -1

			elif event_type == "InterceptedEvent" or event_type == "uno_game::InterceptedEvent":
				var p = int(event.get("player", 0))
				if event.has("card"):
					var c = event["card"]
					discard_pile.append(c)
					if p != local_player:
						opponent_card_count = max(0, opponent_card_count - 1)
						_animate_card_to_discard(c, Vector2(340, 130))
				event_banner_label.text = "⚡ ¡JUMP-IN! Jugador %d interceptó el juego con una carta idéntica" % p

	current = bridge.current_player()
	_update_ui()
	_update_status()

func _on_turn_changed(player_id: int) -> void:
	current = player_id
	_update_ui()
	_update_status()
	if turn_indicator != null:
		turn_indicator.set_turn(player_id, "Jugador %d" % player_id, ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(player_id) - 1, 6)] as Color))

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	if ResourceLoader.exists("res://game_over_overlay.tscn"):
		var overlay = preload("res://game_over_overlay.tscn").instantiate()
		add_child(overlay)
		if overlay.has_method("show_winner"):
			overlay.call("show_winner", w)

func _on_move_rejected(reason: String) -> void:
	if status != null:
		status.text = "Movimiento inválido: %s" % reason
	if event_banner_label != null:
		event_banner_label.text = "❌ Movimiento no permitido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _on_layout_changed(layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	if layout == 2: # PHONE
		table_mat_panel.position = Vector2(5, 5)
		table_mat_panel.size = Vector2(365, 680)
		top_bar.position = Vector2(10, 15)
		top_bar.size = Vector2(355, 38)
		center_play_area.position = Vector2(10, 210)
		center_play_area.size = Vector2(355, 200)
		if action_buttons_bar != null:
			action_buttons_bar.position = Vector2(10, 415)
			action_buttons_bar.size = Vector2(355, 30)
		hand_container.position = Vector2(5, 450)
		hand_container.size = Vector2(365, 210)
	else: # DESKTOP or TABLET
		table_mat_panel.position = Vector2(20, 15)
		table_mat_panel.size = Vector2(680, 690)
		top_bar.position = Vector2(40, 25)
		top_bar.size = Vector2(640, 42)
		center_play_area.position = Vector2(50, 230)
		center_play_area.size = Vector2(620, 210)
		if action_buttons_bar != null:
			action_buttons_bar.position = Vector2(60, 442)
			action_buttons_bar.size = Vector2(600, 34)
		hand_container.position = Vector2(30, 460)
		hand_container.size = Vector2(660, 220)

	_update_ui()

func _update_status() -> void:
	if status == null:
		return
	if winner != -1:
		status.text = "¡Ganó el jugador %s! (UNO)" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var p_name = "Jugador %s" % current
		var p_col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(current) - 1, 6)] as Color)
		status.text = "Turno: Jugador %s (UNO)" % current
		if turn_indicator != null:
			turn_indicator.set_turn(current, p_name, p_col)

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
