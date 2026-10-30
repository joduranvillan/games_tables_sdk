extends Node2D

# =========================================================================
# UNO BOARD - REDISEÑO VISUAL & ARQUITECTURA
# -------------------------------------------------------------------------
# 1. Colores fijos de UNO (CARD_COLORS):
#    - Rojo (#D32F2F), Azul (#1976D2), Verde (#388E3C), Amarillo (#FBC02D) y
#      Negro Especial (#212121) para cartas Wild/Comodín.
# 2. Integración con ThemeManager:
#    - ThemeManager modula el tapete de la mesa (board_color), paneles de HUD,
#      bordes exteriores y marcos de información.
# =========================================================================

const P1 = 1
const P2 = 2

const CARD_COLORS = {
	"Red": Color("#D32F2F"),
	"Blue": Color("#1976D2"),
	"Green": Color("#388E3C"),
	"Yellow": Color("#F5B800"),
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

const CARD_SYMBOLS = {
	"Skip": "SALTA",
	"Reverse": "REV",
	"DrawTwo": "+2",
	"Wild": "WILD",
	"WildDrawFour": "+4"
}

var bridge
var current: int = P1
var winner: int = -1
var is_clockwise: bool = true

# Game State
var discard_pile: Array = []
var player_hand: Array = []
var opponent_card_count: int = 7
var deck_count: int = 50
var active_color: String = "Red"
var draw_penalty: int = 0
var pending_wild_card_idx: int = -1

# UI Containers & Elements
var table_mat_panel: Panel
var top_bar: HBoxContainer
var status_header_panel: PanelContainer
var top_info_label: Label
var mode_option_button: OptionButton
var opp_vbox: VBoxContainer
var event_banner_panel: PanelContainer
var event_banner_label: Label
var uno_alert_banner: PanelContainer
var uno_alert_label: Label

# Opponent area
var opponent_hand_container: HBoxContainer
var opponent_count_badge: Label

# Center play area
var center_play_area: Panel
var discard_zone_box: VBoxContainer
var center_info_vbox: VBoxContainer
var deck_zone_box: VBoxContainer
var discard_card_node: Control
var active_color_badge: PanelContainer
var active_color_rect: ColorRect
var active_color_label: Label
var direction_label: Label
var penalty_label: Label
var draw_pile_container: Control
var draw_pile_button: Button
var draw_count_badge: Label

# Local Hand Area
var hand_container: Control
var wild_picker_modal: PanelContainer

# Navigation & HUD
var turn_indicator: TurnIndicator
var rules_popup: RulesPopup
var current_theme: BoardTheme
var _pause_menu: CanvasLayer

# Local Player & Official UNO Rule State
var local_player: int = P1
var is_vs_ai: bool = false
var ai_difficulty: int = 1
var uno_called_players: Array = []
var last_wild_draw_four_player: int = -1

# AI Paced Presentation State
var _ai_visual_queue: Array = []
var _is_playing_ai_sequence: bool = false
var _last_move_rejected: bool = false
var _human_action_origin: Vector2 = Vector2.ZERO
var _pending_drawn_wild_pick: bool = false
var _applying_auto_penalty: bool = false
var _executing_ai_turn: bool = false
var _rust_draw_penalty: int = 0
var _drawn_wild_override_color: String = ""
var _drawn_wild_card_val: String = ""

# Action buttons bar & special buttons
var action_buttons_bar: HBoxContainer
var call_uno_btn: Button
var catch_uno_btn: Button
var challenge_wild_four_btn: Button
var jump_in_btn: Button

var status: Label = null

func _ready() -> void:
	if has_node("Status"):
		status = get_node_or_null("Status") as Label

	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm: Node = null
		if is_inside_tree():
			tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)
	else:
		_create_default_theme()

	_setup_ui()
	_init_default_game_state()

	var gm: Node = null
	if is_inside_tree():
		gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)
	if is_inside_tree() and get_viewport() != null:
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)

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
			var hud_script = load("res://network_status_hud.gd")
			if hud_script:
				var hud: Node = hud_script.new()
				if hud.has_method("setup"):
					hud.setup(bridge)
				elif hud.has_method("bind_bridge"):
					hud.bind_bridge(bridge)
				add_child(hud)

	# En ejecución interactiva, si GameManager no especificó modo explícito o está en vs_ai,
	# arrancamos contra la IA (J1 humano vs J2 IA) para que el oponente juegue desde el inicio.
	var gm_mode: String = str(gm.get_game_mode()) if (gm != null and gm.has_method("get_game_mode")) else "vs_ai"
	var start_vs_ai: bool = (gm_mode == "vs_ai") or (not OS.has_feature("headless") and gm_mode == "hotseat")
	if start_vs_ai:
		var human_p: int = int(gm.get_human_player_id()) if (gm != null and gm.has_method("get_human_player_id")) else P1
		var diff: int = int(gm.get_ai_difficulty()) if (gm != null and gm.has_method("get_ai_difficulty")) else 1
		is_vs_ai = true
		local_player = human_p
		ai_difficulty = diff
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_p == P1 else 2
		bridge.start_local_match_uno(P1, P2)
		_run_uno_ai_turns_if_needed()
	else:
		is_vs_ai = false
		local_player = P1
		if mode_option_button != null:
			mode_option_button.selected = 0
		bridge.start_local_match_uno(P1, P2)

	current = bridge.current_player()
	if not _is_playing_ai_sequence:
		_sync_uno_state_from_bridge()

	var initial_layout: int = int(gm.get_layout()) if (gm != null and gm.has_method("get_layout")) else 0
	_on_layout_changed(initial_layout)
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

func _on_mode_selected(index: int) -> void:
	var gm: Node = null
	if is_inside_tree():
		gm = get_node_or_null("/root/GameManager")
	winner = -1
	_ai_visual_queue.clear()
	_is_playing_ai_sequence = false
	_pending_drawn_wild_pick = false
	_applying_auto_penalty = false
	_executing_ai_turn = false
	_rust_draw_penalty = 0
	_drawn_wild_override_color = ""
	_drawn_wild_card_val = ""
	_init_default_game_state()
	if index == 0:
		if gm != null and gm.has_method("set_game_mode"):
			gm.set_game_mode("local")
		is_vs_ai = false
		local_player = P1
		bridge.start_local_match_uno(P1, P2)
		event_banner_label.text = "Modo 2 Jugadores Local iniciado. Turno del Jugador 1."
	else:
		var human_p: int = P1 if index == 1 else P2
		var diff: int = int(gm.get_ai_difficulty()) if (gm != null and gm.has_method("get_ai_difficulty")) else 1
		if gm != null and gm.has_method("set_game_mode"):
			gm.set_game_mode("vs_ai")
		if gm != null and gm.has_method("set_human_player_id"):
			gm.set_human_player_id(human_p)
		is_vs_ai = true
		local_player = human_p
		ai_difficulty = diff
		event_banner_label.text = "Partida vs IA iniciada (Tú eres Jugador %d)." % human_p
		bridge.start_local_match_uno(P1, P2)
		_run_uno_ai_turns_if_needed()
	current = bridge.current_player()
	if not _is_playing_ai_sequence:
		_sync_uno_state_from_bridge()
	_update_ui()
	_update_status()

func _create_default_theme() -> void:
	current_theme = BoardTheme.new()
	current_theme.theme_name = "Noche Azul"
	current_theme.board_color = Color("#162636")
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
		mat_style.bg_color = current_theme.board_color.darkened(0.12)
		mat_style.border_color = current_theme.line_color.lightened(0.15)
		mat_style.set_border_width_all(3)
		mat_style.set_corner_radius_all(18)
		mat_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		mat_style.shadow_size = 10
		table_mat_panel.add_theme_stylebox_override("panel", mat_style)

	if center_play_area != null:
		var c_style = StyleBoxFlat.new()
		c_style.bg_color = current_theme.dark_color.darkened(0.28)
		c_style.border_color = current_theme.line_color
		c_style.set_border_width_all(2)
		c_style.set_corner_radius_all(16)
		center_play_area.add_theme_stylebox_override("panel", c_style)

	if status_header_panel != null:
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = current_theme.dark_color.darkened(0.18)
		h_style.border_color = current_theme.line_color
		h_style.set_border_width_all(1)
		h_style.set_corner_radius_all(8)
		h_style.content_margin_left = 12
		h_style.content_margin_right = 12
		status_header_panel.add_theme_stylebox_override("panel", h_style)

func _setup_ui() -> void:
	# 1. Wide Centered Table Mat Panel (1200x692 on 1280x720 screen)
	table_mat_panel = Panel.new()
	table_mat_panel.name = "TableMatPanel"
	table_mat_panel.position = Vector2(40, 14)
	table_mat_panel.size = Vector2(1200, 692)
	add_child(table_mat_panel)

	# 2. Top Control Bar (Title, Card Counts, Rules, Tutorial, Mode)
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(70, 24)
	top_bar.size = Vector2(1140, 40)
	top_bar.add_theme_constant_override("separation", 14)
	add_child(top_bar)

	var title_lbl = Label.new()
	title_lbl.text = "🎴 U N O"
	title_lbl.custom_minimum_size = Vector2(110, 36)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	title_lbl.set_meta("uno_fixed_font_size", 24)
	top_bar.add_child(title_lbl)

	status_header_panel = PanelContainer.new()
	status_header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_header_panel.custom_minimum_size = Vector2(360, 36)
	top_bar.add_child(status_header_panel)

	top_info_label = Label.new()
	top_info_label.name = "TopInfoLabel"
	top_info_label.text = "Jugador 1: 7 cartas   |   Jugador 2: 7 cartas"
	top_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_info_label.add_theme_font_size_override("font_size", 15)
	top_info_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	top_info_label.set_meta("uno_fixed_font_size", 15)
	status_header_panel.add_child(top_info_label)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(105, 36)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("uno"))
	top_bar.add_child(btn_rules)

	var tutorial_btn := Button.new()
	tutorial_btn.name = "UnoTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.custom_minimum_size = Vector2(110, 36)
	tutorial_btn.pressed.connect(start_uno_tutorial)
	top_bar.add_child(tutorial_btn)

	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.custom_minimum_size = Vector2(165, 36)
	mode_option_button.add_item("👥 2 Jugadores", 0)
	mode_option_button.add_item("🤖 vs IA (J1)", 1)
	mode_option_button.add_item("🤖 vs IA (J2)", 2)
	mode_option_button.selected = 1
	mode_option_button.item_selected.connect(_on_mode_selected)
	top_bar.add_child(mode_option_button)

	# 3. Turn Indicator Bar (Full width inside table mat so buttons never overflow)
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(70, 70)
	turn_indicator.custom_minimum_size = Vector2(1140, 38)
	turn_indicator.size = Vector2(1140, 38)
	add_child(turn_indicator)
	if turn_indicator.label != null:
		turn_indicator.label.custom_minimum_size = Vector2(220, 28)

	# 4. Opponent Hand Visualizer (Top Area)
	opp_vbox = VBoxContainer.new()
	opp_vbox.name = "OpponentArea"
	opp_vbox.position = Vector2(190, 110)
	opp_vbox.size = Vector2(900, 74)
	opp_vbox.add_theme_constant_override("separation", 3)
	add_child(opp_vbox)

	opponent_count_badge = Label.new()
	opponent_count_badge.text = "🤖 Mano del Oponente (7 cartas)"
	opponent_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_count_badge.add_theme_font_size_override("font_size", 13)
	opponent_count_badge.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	opponent_count_badge.set_meta("uno_fixed_font_size", 13)
	opp_vbox.add_child(opponent_count_badge)

	opponent_hand_container = HBoxContainer.new()
	opponent_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_hand_container.custom_minimum_size = Vector2(900, 52)
	opponent_hand_container.add_theme_constant_override("separation", -10)
	opp_vbox.add_child(opponent_hand_container)

	# 5. Event Notification Banner
	event_banner_panel = PanelContainer.new()
	event_banner_panel.name = "EventBanner"
	event_banner_panel.position = Vector2(240, 190)
	event_banner_panel.size = Vector2(800, 34)
	var ev_sb = StyleBoxFlat.new()
	ev_sb.bg_color = Color(0.08, 0.14, 0.22, 0.94)
	ev_sb.border_color = Color(0.35, 0.65, 0.95, 0.8)
	ev_sb.set_border_width_all(1)
	ev_sb.set_corner_radius_all(8)
	ev_sb.content_margin_left = 12
	ev_sb.content_margin_right = 12
	event_banner_panel.add_theme_stylebox_override("panel", ev_sb)

	event_banner_label = Label.new()
	event_banner_label.text = "¡Partida iniciada! Juega una carta que coincida en color o símbolo."
	event_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_banner_label.add_theme_font_size_override("font_size", 14)
	event_banner_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	event_banner_label.set_meta("uno_fixed_font_size", 14)
	event_banner_panel.add_child(event_banner_label)
	add_child(event_banner_panel)

	# 6. UNO Warning Banner (Shown when 1 card left)
	uno_alert_banner = PanelContainer.new()
	uno_alert_banner.name = "UnoAlertBanner"
	uno_alert_banner.position = Vector2(520, 184)
	uno_alert_banner.size = Vector2(240, 40)
	uno_alert_banner.visible = false
	uno_alert_banner.z_index = 20
	var u_sb = StyleBoxFlat.new()
	u_sb.bg_color = Color(0.88, 0.12, 0.12, 0.96)
	u_sb.border_color = Color(1.0, 0.9, 0.2)
	u_sb.set_border_width_all(3)
	u_sb.set_corner_radius_all(10)
	uno_alert_banner.add_theme_stylebox_override("panel", u_sb)

	uno_alert_label = Label.new()
	uno_alert_label.text = "🔥 ¡¡ U N O !! 🔥"
	uno_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uno_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	uno_alert_label.add_theme_font_size_override("font_size", 17)
	uno_alert_label.add_theme_color_override("font_color", Color.WHITE)
	uno_alert_label.set_meta("uno_fixed_font_size", 17)
	uno_alert_banner.add_child(uno_alert_label)
	add_child(uno_alert_banner)

	# 7. Center Felt Playing Area
	center_play_area = Panel.new()
	center_play_area.name = "CenterPlayArea"
	center_play_area.position = Vector2(190, 230)
	center_play_area.size = Vector2(900, 200)
	add_child(center_play_area)

	_setup_center_play_area()

	# 8. Local Hand Container (Wide Fan Spread)
	hand_container = Control.new()
	hand_container.name = "HandContainer"
	hand_container.position = Vector2(90, 476)
	hand_container.size = Vector2(1100, 215)
	add_child(hand_container)

	# 9. Action Buttons Bar (🔥 ¡UNO!, 🚨 Acusar UNO, ⚡ Desafiar +4, ⚡ Jump-In)
	_setup_action_buttons()

	# 10. Wild Color Picker Dialog Modal
	_setup_wild_picker_modal()

	# 11. Rules Popup
	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(240, 80)
	add_child(rules_popup)

	_apply_theme_styling()

func _setup_action_buttons() -> void:
	action_buttons_bar = HBoxContainer.new()
	action_buttons_bar.name = "ActionButtonsBar"
	action_buttons_bar.position = Vector2(240, 436)
	action_buttons_bar.size = Vector2(800, 36)
	action_buttons_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_buttons_bar.add_theme_constant_override("separation", 16)
	add_child(action_buttons_bar)

	# 1. Botón "🔥 ¡UNO!"
	call_uno_btn = Button.new()
	call_uno_btn.name = "CallUnoButton"
	call_uno_btn.text = "🔥 ¡UNO!"
	call_uno_btn.custom_minimum_size = Vector2(130, 34)
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
	catch_uno_btn.custom_minimum_size = Vector2(140, 34)
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
	challenge_wild_four_btn.custom_minimum_size = Vector2(140, 34)
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
	jump_in_btn.custom_minimum_size = Vector2(120, 34)
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
	discard_zone_box = VBoxContainer.new()
	discard_zone_box.position = Vector2(80, 10)
	discard_zone_box.size = Vector2(200, 180)
	discard_zone_box.alignment = BoxContainer.ALIGNMENT_CENTER
	discard_zone_box.add_theme_constant_override("separation", 6)
	center_play_area.add_child(discard_zone_box)

	var discard_title = Label.new()
	discard_title.text = "PILA DE DESCARTE"
	discard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_title.add_theme_font_size_override("font_size", 12)
	discard_title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98))
	discard_title.set_meta("uno_fixed_font_size", 12)
	discard_zone_box.add_child(discard_title)

	discard_card_node = Control.new()
	discard_card_node.name = "DiscardCardNode"
	discard_card_node.custom_minimum_size = Vector2(108, 154)
	discard_card_node.size = Vector2(108, 154)
	discard_card_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	discard_zone_box.add_child(discard_card_node)

	# 2. Central Active Color & Direction Indicator (Center)
	center_info_vbox = VBoxContainer.new()
	center_info_vbox.position = Vector2(330, 16)
	center_info_vbox.size = Vector2(240, 168)
	center_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_info_vbox.add_theme_constant_override("separation", 8)
	center_play_area.add_child(center_info_vbox)

	var color_title = Label.new()
	color_title.text = "COLOR ACTIVO"
	color_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_title.add_theme_font_size_override("font_size", 12)
	color_title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98))
	color_title.set_meta("uno_fixed_font_size", 12)
	center_info_vbox.add_child(color_title)

	active_color_badge = PanelContainer.new()
	active_color_badge.custom_minimum_size = Vector2(170, 50)
	active_color_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ac_sb = StyleBoxFlat.new()
	ac_sb.bg_color = Color(0.10, 0.13, 0.20, 0.96)
	ac_sb.border_color = CARD_COLORS["Red"]
	ac_sb.set_border_width_all(3)
	ac_sb.set_corner_radius_all(10)
	ac_sb.content_margin_left = 14
	ac_sb.content_margin_right = 14
	active_color_badge.add_theme_stylebox_override("panel", ac_sb)

	var ac_hbox = HBoxContainer.new()
	ac_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ac_hbox.add_theme_constant_override("separation", 10)
	active_color_badge.add_child(ac_hbox)

	active_color_rect = ColorRect.new()
	active_color_rect.custom_minimum_size = Vector2(24, 24)
	active_color_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	active_color_rect.color = CARD_COLORS["Red"]
	ac_hbox.add_child(active_color_rect)

	active_color_label = Label.new()
	active_color_label.text = "ROJO"
	active_color_label.add_theme_font_size_override("font_size", 16)
	active_color_label.add_theme_color_override("font_color", Color.WHITE)
	active_color_label.set_meta("uno_fixed_font_size", 16)
	ac_hbox.add_child(active_color_label)
	center_info_vbox.add_child(active_color_badge)

	direction_label = Label.new()
	direction_label.text = "Sentido: Horario"
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	direction_label.add_theme_font_size_override("font_size", 13)
	direction_label.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	direction_label.set_meta("uno_fixed_font_size", 13)
	center_info_vbox.add_child(direction_label)

	penalty_label = Label.new()
	penalty_label.text = ""
	penalty_label.visible = false
	penalty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	penalty_label.add_theme_font_size_override("font_size", 13)
	penalty_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	penalty_label.set_meta("uno_fixed_font_size", 13)
	center_info_vbox.add_child(penalty_label)

	# 3. Draw Pile / Deck Area (Right Center)
	deck_zone_box = VBoxContainer.new()
	deck_zone_box.position = Vector2(620, 10)
	deck_zone_box.size = Vector2(200, 180)
	deck_zone_box.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_zone_box.add_theme_constant_override("separation", 6)
	center_play_area.add_child(deck_zone_box)

	var deck_title = Label.new()
	deck_title.text = "MAZO DE ROBO"
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_title.add_theme_font_size_override("font_size", 12)
	deck_title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98))
	deck_title.set_meta("uno_fixed_font_size", 12)
	deck_zone_box.add_child(deck_title)

	draw_pile_container = Control.new()
	draw_pile_container.custom_minimum_size = Vector2(108, 154)
	draw_pile_container.size = Vector2(108, 154)
	draw_pile_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_zone_box.add_child(draw_pile_container)

	_setup_draw_deck_visual()

func _setup_draw_deck_visual() -> void:
	for offset_idx in [3, 2, 1]:
		var layer = Panel.new()
		layer.position = Vector2(offset_idx * 2, offset_idx * 2)
		layer.size = Vector2(104, 148)
		var l_style = StyleBoxFlat.new()
		l_style.bg_color = Color(0.12, 0.12, 0.16)
		l_style.border_color = Color(0.4, 0.4, 0.5)
		l_style.set_border_width_all(1)
		l_style.set_corner_radius_all(10)
		layer.add_theme_stylebox_override("panel", l_style)
		draw_pile_container.add_child(layer)

	draw_pile_button = Button.new()
	draw_pile_button.name = "DrawPileButton"
	draw_pile_button.position = Vector2(0, 0)
	draw_pile_button.size = Vector2(104, 148)
	draw_pile_button.custom_minimum_size = Vector2(104, 148)

	var d_style = StyleBoxFlat.new()
	d_style.bg_color = Color("#18181C")
	d_style.border_color = Color(0.95, 0.85, 0.25)
	d_style.set_border_width_all(3)
	d_style.set_corner_radius_all(10)
	draw_pile_button.add_theme_stylebox_override("normal", d_style)

	var d_hover = d_style.duplicate()
	d_hover.border_color = Color(1.0, 0.96, 0.45)
	d_hover.set_border_width_all(4)
	draw_pile_button.add_theme_stylebox_override("hover", d_hover)

	draw_pile_container.add_child(draw_pile_button)

	# Centered Slanted Red UNO Oval on Deck Back
	var oval = Panel.new()
	oval.size = Vector2(80, 64)
	oval.position = Vector2(12, 34)
	oval.pivot_offset = Vector2(40, 32)
	oval.rotation_degrees = -16.0
	var o_style = StyleBoxFlat.new()
	o_style.bg_color = Color("#D32F2F")
	o_style.border_color = Color(0.98, 0.88, 0.30)
	o_style.set_border_width_all(2)
	o_style.set_corner_radius_all(28)
	oval.add_theme_stylebox_override("panel", o_style)
	oval.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile_button.add_child(oval)

	var uno_lbl = Label.new()
	uno_lbl.text = "UNO"
	uno_lbl.position = Vector2(0, 12)
	uno_lbl.size = Vector2(80, 40)
	uno_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uno_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	uno_lbl.add_theme_font_size_override("font_size", 20)
	uno_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.22))
	uno_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 0.9))
	uno_lbl.add_theme_constant_override("outline_size", 3)
	uno_lbl.set_meta("uno_fixed_font_size", 20)
	uno_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oval.add_child(uno_lbl)

	draw_count_badge = Label.new()
	draw_count_badge.position = Vector2(0, 118)
	draw_count_badge.size = Vector2(104, 24)
	draw_count_badge.text = "Robar (50)"
	draw_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_count_badge.add_theme_font_size_override("font_size", 12)
	draw_count_badge.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	draw_count_badge.set_meta("uno_fixed_font_size", 12)
	draw_count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile_button.add_child(draw_count_badge)

	draw_pile_button.pressed.connect(_on_draw_pile_pressed)

func start_uno_tutorial() -> void:
	var UnoTut = load("res://scripts/tutorials/uno_tutorial.gd")
	if UnoTut != null:
		UnoTut.start_on_board(self)

func _setup_wild_picker_modal() -> void:
	wild_picker_modal = PanelContainer.new()
	wild_picker_modal.name = "WildPickerModal"
	wild_picker_modal.position = Vector2(460, 230)
	wild_picker_modal.size = Vector2(360, 220)
	wild_picker_modal.visible = false
	wild_picker_modal.z_index = 40

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
	title.text = "ELIGE UN COLOR PARA EL COMODÍN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.set_meta("uno_fixed_font_size", 15)
	vbox.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	var color_options = [
		{"key": "Red", "label": "ROJO", "color": CARD_COLORS["Red"]},
		{"key": "Blue", "label": "AZUL", "color": CARD_COLORS["Blue"]},
		{"key": "Green", "label": "VERDE", "color": CARD_COLORS["Green"]},
		{"key": "Yellow", "label": "AMARILLO", "color": CARD_COLORS["Yellow"]}
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
		btn.add_theme_color_override("font_color", Color.WHITE if opt["key"] != "Yellow" else Color("#1A1A1A"))

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
	draw_penalty = 0
	_rust_draw_penalty = 0
	deck_count = 50
	opponent_card_count = 7
	is_clockwise = true

func _normalize_card_dict(raw_card: Dictionary) -> Dictionary:
	var col_str: String = str(raw_card.get("color", "Red"))
	if col_str == "WildColor":
		col_str = "Wild"
	var raw_val = raw_card.get("value", "0")
	var val_str := "0"
	if raw_val is Dictionary:
		if raw_val.has("Number"):
			val_str = str(int(raw_val["Number"]))
		elif not raw_val.is_empty():
			val_str = str(raw_val.keys()[0])
	else:
		val_str = str(raw_val)
	return {"color": col_str, "value": val_str}

func _sync_uno_state_from_bridge(preserve_active_color: bool = false) -> void:
	if bridge == null or not bridge.has_method("get_uno_state"):
		return
	var target_p: int = local_player if is_vs_ai else current
	var st = bridge.get_uno_state(target_p)
	if not (st is Dictionary) or st.is_empty():
		return
	if st.has("hand") and st["hand"] is Array:
		player_hand.clear()
		for c in st["hand"]:
			if c is Dictionary:
				player_hand.append(_normalize_card_dict(c))
	if st.has("top_card") and st["top_card"] is Dictionary:
		var formatted_tc = _normalize_card_dict(st["top_card"])
		if discard_pile.is_empty():
			discard_pile.append(formatted_tc)
		else:
			discard_pile[discard_pile.size() - 1] = formatted_tc
		var tc_col: String = str(formatted_tc.get("color", ""))
		var tc_val: String = str(formatted_tc.get("value", ""))
		if not (tc_col in ["Wild", "WildColor"] or tc_val in ["Wild", "WildDrawFour"]):
			_drawn_wild_override_color = ""
	if st.has("active_color") and not preserve_active_color:
		if not _drawn_wild_override_color.is_empty():
			active_color = _drawn_wild_override_color
		else:
			var ac = str(st["active_color"])
			active_color = "Wild" if ac == "WildColor" else ac
	if st.has("deck_count"):
		deck_count = int(st["deck_count"])
	if st.has("opponent_card_count"):
		opponent_card_count = int(st["opponent_card_count"])
	if st.has("draw_penalty"):
		draw_penalty = int(st["draw_penalty"])
		_rust_draw_penalty = draw_penalty
	elif not _is_playing_ai_sequence:
		draw_penalty = _rust_draw_penalty

# =========================================================================
# CARD CREATION & RENDERING HELPER (Panel-based for exact UNO proportions)
# =========================================================================
func _create_card_visual(card: Dictionary, is_playable: bool = true, is_large: bool = false, is_interceptable: bool = false) -> Control:
	var norm_card := _normalize_card_dict(card)
	var c_color: String = norm_card["color"]
	var c_val: String = norm_card["value"]

	var width: float = 108.0 if is_large else 100.0
	var height: float = 154.0 if is_large else 146.0

	# IMPORTANT: Use Panel (NOT PanelContainer) so child controls keep their exact positions and sizes!
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(width, height)
	card_panel.size = Vector2(width, height)
	card_panel.pivot_offset = Vector2(width / 2.0, height)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var base_col: Color = _get_accessible_card_color(c_color)
	var style = StyleBoxFlat.new()
	style.bg_color = base_col
	style.set_corner_radius_all(12)

	if is_interceptable:
		style.set_border_width_all(4)
		style.border_color = Color(0.2, 0.95, 1.0, 1.0)
		style.shadow_color = Color(0.0, 0.85, 1.0, 0.85)
		style.shadow_size = 9
	elif is_playable:
		style.set_border_width_all(4)
		style.border_color = Color(1.0, 0.92, 0.28, 1.0)
		style.shadow_color = Color(1.0, 0.85, 0.2, 0.5)
		style.shadow_size = 7
	else:
		style.set_border_width_all(3)
		style.border_color = Color(0.96, 0.96, 0.98, 0.92)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		style.shadow_size = 4
		if not is_large:
			card_panel.modulate = Color(0.92, 0.92, 0.95, 0.94)

	card_panel.add_theme_stylebox_override("panel", style)

	# Inner Slanted White Oval (Centered pivot so rotation stays symmetric)
	var oval_w: float = width - 24.0
	var oval_h: float = height - 54.0
	var oval = Panel.new()
	oval.size = Vector2(oval_w, oval_h)
	oval.position = Vector2((width - oval_w) / 2.0, (height - oval_h) / 2.0)
	oval.pivot_offset = Vector2(oval_w / 2.0, oval_h / 2.0)
	oval.rotation_degrees = -15.0
	oval.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var is_wild_card: bool = (c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"])
	var oval_style = StyleBoxFlat.new()
	if is_wild_card:
		oval_style.bg_color = Color(0.14, 0.15, 0.20)
		if c_color in ["Red", "Blue", "Green", "Yellow"]:
			oval_style.border_color = base_col.lightened(0.35)
			oval_style.set_border_width_all(3)
		else:
			oval_style.border_color = Color(1.0, 0.88, 0.25)
			oval_style.set_border_width_all(2)
	else:
		oval_style.bg_color = Color(0.98, 0.98, 0.99)
		oval_style.border_color = base_col.darkened(0.2)
		oval_style.set_border_width_all(2)

	oval_style.set_corner_radius_all(int(oval_w / 2.2))
	oval.add_theme_stylebox_override("panel", oval_style)
	card_panel.add_child(oval)

	# For Wild Cards, draw 4-color inner quadrants inside the oval
	if is_wild_card:
		var quad_grid = GridContainer.new()
		quad_grid.columns = 2
		quad_grid.position = Vector2(oval_w / 2.0 - 20.0, oval_h / 2.0 - 20.0)
		quad_grid.add_theme_constant_override("h_separation", 4)
		quad_grid.add_theme_constant_override("v_separation", 4)
		quad_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for q_col in [CARD_COLORS["Red"], CARD_COLORS["Blue"], CARD_COLORS["Yellow"], CARD_COLORS["Green"]]:
			var q_rect = ColorRect.new()
			q_rect.custom_minimum_size = Vector2(18, 18)
			q_rect.color = q_col
			q_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			quad_grid.add_child(q_rect)
		oval.add_child(quad_grid)

	# Central Upright Symbol / Number
	var center_symbol: String = _get_card_display_symbol(c_val)
	var center_lbl = Label.new()
	center_lbl.text = center_symbol
	center_lbl.position = Vector2(6, (height - 54.0) / 2.0)
	center_lbl.size = Vector2(width - 12.0, 54.0)
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center_font_sz: int = 36
	if c_val in ["Skip", "Wild"]:
		center_font_sz = 19 if is_large else 17
	elif c_val == "Reverse":
		center_font_sz = 23 if is_large else 21
	elif c_val in ["DrawTwo", "WildDrawFour"]:
		center_font_sz = 34 if is_large else 30
	else:
		center_font_sz = 40 if is_large else 36

	center_lbl.add_theme_font_size_override("font_size", center_font_sz)
	center_lbl.set_meta("uno_fixed_font_size", center_font_sz)

	if is_wild_card:
		center_lbl.add_theme_color_override("font_color", Color.WHITE)
		center_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
		center_lbl.add_theme_constant_override("outline_size", 5)
	else:
		var num_col: Color = base_col.darkened(0.18) if c_color == "Yellow" else base_col
		center_lbl.add_theme_color_override("font_color", num_col)
		center_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.12, 0.15, 0.65))
		center_lbl.add_theme_constant_override("outline_size", 2)

	card_panel.add_child(center_lbl)

	# Corner Mini Indices (Top-Left and Bottom-Right)
	var mini_sym: String = _get_card_mini_symbol(c_val)
	var cb_active: bool = false
	if (is_inside_tree() and has_node("/root/ThemeManager")) and get_node("/root/ThemeManager").has_method("is_colorblind_mode"):
		cb_active = bool(get_node("/root/ThemeManager").call("is_colorblind_mode"))
	var cb_tag: String = _get_colorblind_symbol(c_color) if cb_active else ""
	var corner_text: String = "%s %s" % [mini_sym, cb_tag] if not cb_tag.is_empty() else mini_sym

	var tl_lbl = Label.new()
	tl_lbl.text = corner_text
	tl_lbl.position = Vector2(8, 5)
	tl_lbl.size = Vector2(width - 16.0, 22.0)
	tl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tl_lbl.add_theme_font_size_override("font_size", 14)
	tl_lbl.add_theme_color_override("font_color", Color.WHITE)
	tl_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1, 0.85))
	tl_lbl.add_theme_constant_override("outline_size", 3)
	tl_lbl.set_meta("uno_fixed_font_size", 14)
	tl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(tl_lbl)

	var br_lbl = Label.new()
	br_lbl.text = corner_text
	br_lbl.position = Vector2(8, height - 25.0)
	br_lbl.size = Vector2(width - 16.0, 22.0)
	br_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	br_lbl.add_theme_font_size_override("font_size", 14)
	br_lbl.add_theme_color_override("font_color", Color.WHITE)
	br_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1, 0.85))
	br_lbl.add_theme_constant_override("outline_size", 3)
	br_lbl.set_meta("uno_fixed_font_size", 14)
	br_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(br_lbl)

	if is_interceptable:
		var ji_badge = Label.new()
		ji_badge.text = "JUMP-IN"
		ji_badge.position = Vector2(0, height - 20.0)
		ji_badge.size = Vector2(width, 16.0)
		ji_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ji_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ji_badge.add_theme_font_size_override("font_size", 10)
		ji_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
		ji_badge.set_meta("uno_fixed_font_size", 10)
		ji_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_panel.add_child(ji_badge)

	return card_panel

func _create_card_back_visual() -> Control:
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(44, 62)
	card_panel.size = Vector2(44, 62)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#18181C")
	style.border_color = Color(0.95, 0.85, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card_panel.add_theme_stylebox_override("panel", style)

	var oval = Panel.new()
	oval.size = Vector2(32, 26)
	oval.position = Vector2(6, 18)
	oval.pivot_offset = Vector2(16, 13)
	oval.rotation_degrees = -16.0
	var o_style = StyleBoxFlat.new()
	o_style.bg_color = Color("#D32F2F")
	o_style.border_color = Color(1.0, 0.9, 0.3)
	o_style.set_border_width_all(1)
	o_style.set_corner_radius_all(12)
	oval.add_theme_stylebox_override("panel", o_style)
	card_panel.add_child(oval)

	var lbl = Label.new()
	lbl.text = "UNO"
	lbl.position = Vector2(0, 4)
	lbl.size = Vector2(32, 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
	lbl.set_meta("uno_fixed_font_size", 9)
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
		"Red": return "[R]"
		"Blue": return "[A]"
		"Green": return "[V]"
		"Yellow": return "[M]"
		_: return "[*]"

func _get_card_display_symbol(val: String) -> String:
	match val:
		"Skip": return "SALTA"
		"Reverse": return "REV"
		"DrawTwo": return "+2"
		"Wild": return "WILD"
		"WildDrawFour": return "+4"
		_: return val

func _get_card_mini_symbol(val: String) -> String:
	match val:
		"Skip": return "Ø"
		"Reverse": return "R"
		"DrawTwo": return "+2"
		"Wild": return "W"
		"WildDrawFour": return "+4"
		_: return val

# =========================================================================
# UI REFRESH & HAND FAN DISPLAY
# =========================================================================
func _is_card_interceptable(card: Dictionary) -> bool:
	if current == local_player or _is_playing_ai_sequence:
		return false
	if discard_pile.is_empty():
		return false

	var norm_card := _normalize_card_dict(card)
	var c_color: String = norm_card["color"]
	var c_val: String = norm_card["value"]

	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		return false

	var top_card := _normalize_card_dict(discard_pile.back())
	return c_color == top_card["color"] and c_val == top_card["value"]

func _is_card_playable(card: Dictionary) -> bool:
	var norm_card := _normalize_card_dict(card)
	var c_color: String = norm_card["color"]
	var c_val: String = norm_card["value"]

	var top_card: Dictionary = _normalize_card_dict(discard_pile.back()) if not discard_pile.is_empty() else {"color": "Red", "value": "1"}
	var top_val: String = top_card["value"]

	# Restricción oficial de WildDrawFour: solo jugable si no se tiene ninguna carta del color activo
	if c_val == "WildDrawFour":
		if active_color in ["Red", "Blue", "Green", "Yellow"]:
			for h_card in player_hand:
				if h_card is Dictionary:
					var hc := _normalize_card_dict(h_card)
					if hc["color"] == active_color:
						return false
		return true

	if c_color in ["Wild", "WildColor"] or c_val == "Wild":
		return true

	if c_color == active_color or c_val == top_val:
		return true

	return false

func _get_player_display_name(p_id: int) -> String:
	if is_vs_ai:
		if p_id == local_player:
			return "Jugador %d (Tú)" % p_id
		return "IA (Jugador %d)" % p_id
	return "Jugador %d" % p_id

func _restore_fixed_fonts(node: Node) -> void:
	if node is Control and node.has_meta("uno_fixed_font_size"):
		(node as Control).add_theme_font_size_override("font_size", int(node.get_meta("uno_fixed_font_size")))
	for child in node.get_children():
		_restore_fixed_fonts(child)

func _update_ui(animate_drawn_index: int = -1) -> void:
	# 1. Update Top Bar Counts accurately for both Hotseat and vs AI
	var p1_count: int = 0
	var p2_count: int = 0
	if is_vs_ai:
		p1_count = player_hand.size() if local_player == P1 else opponent_card_count
		p2_count = opponent_card_count if local_player == P1 else player_hand.size()
	else:
		p1_count = player_hand.size() if current == P1 else opponent_card_count
		p2_count = opponent_card_count if current == P1 else player_hand.size()

	var p1_title: String = _get_player_display_name(P1)
	var p2_title: String = _get_player_display_name(P2)
	top_info_label.text = "%s: %d cartas   |   %s: %d cartas" % [p1_title, p1_count, p2_title, p2_count]

	# 2. Update Opponent Hand Backs
	for child in opponent_hand_container.get_children():
		child.queue_free()
	var opp_id: int = (P2 if local_player == P1 else P1) if is_vs_ai else (P2 if current == P1 else P1)
	opponent_count_badge.text = "Mano de %s (%d cartas)" % [_get_player_display_name(opp_id), opponent_card_count]
	for i in range(min(15, opponent_card_count)):
		opponent_hand_container.add_child(_create_card_back_visual())

	# 3. Update Discard Pile Card
	_update_discard_display()

	# 4. Update Active Color, Direction & Penalty
	_update_active_color_indicator()
	direction_label.text = "Sentido: %s" % ("Horario" if is_clockwise else "Antihorario")
	if penalty_label != null:
		if draw_penalty > 0:
			penalty_label.visible = true
			penalty_label.text = "Penalización acumulada: +%d" % draw_penalty
		else:
			penalty_label.visible = false

	# 5. Update Deck Count
	if draw_count_badge != null:
		if draw_penalty > 0 and current == local_player:
			draw_count_badge.text = "Robar +%d (%d)" % [draw_penalty, deck_count]
		else:
			draw_count_badge.text = "Robar (%d)" % deck_count

	# 6. Check UNO Alert (when either player has 1 card)
	if uno_alert_banner != null:
		var has_one = (player_hand.size() == 1 or opponent_card_count == 1)
		uno_alert_banner.visible = has_one

	# 7. Render Hand Cards in Clean Wide Spread
	for child in hand_container.get_children():
		child.queue_free()

	var n_cards: int = player_hand.size()
	if n_cards == 0:
		return

	var container_w: float = max(660.0, hand_container.size.x)
	var center_x: float = container_w / 2.0
	var card_w: float = 100.0
	var spread: float = min(92.0, (container_w - card_w - 60.0) / max(1, n_cards - 1))
	var start_x: float = center_x - ((n_cards - 1) * spread) / 2.0 - card_w / 2.0

	var is_local_turn: bool = (not _is_playing_ai_sequence) and ((current == local_player) if is_vs_ai else true)
	var has_any_playable: bool = false
	var has_any_interceptable: bool = false

	for i in range(n_cards):
		var card = player_hand[i]
		var is_playable: bool = is_local_turn and _is_card_playable(card)
		var is_interceptable: bool = _is_card_interceptable(card)
		if is_playable:
			has_any_playable = true
		if is_interceptable:
			has_any_interceptable = true

		var card_node = _create_card_visual(card, is_playable, false, is_interceptable)

		# Gentle fan angle (-9° to +9°) so cards never clip or distort numbers
		var angle_deg: float = 0.0
		if n_cards > 1:
			var max_fan: float = min(9.0, float(n_cards) * 1.1)
			angle_deg = lerp(-max_fan, max_fan, float(i) / float(n_cards - 1))
		card_node.rotation_degrees = angle_deg

		var extra_lift: float = -16.0 if (is_playable or is_interceptable) else 0.0
		var resting_pos := Vector2(start_x + i * spread, 34.0 + abs(angle_deg) * 0.7 + extra_lift)
		card_node.position = resting_pos
		card_node.set_meta("resting_y", resting_pos.y)

		if is_playable or is_interceptable:
			card_node.mouse_entered.connect(func():
				var tw = card_node.create_tween().set_parallel(true)
				tw.tween_property(card_node, "position:y", float(card_node.get_meta("resting_y")) - 22.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(card_node, "scale", Vector2(1.10, 1.10), 0.14)
				card_node.z_index = 15
			)
			card_node.mouse_exited.connect(func():
				var tw = card_node.create_tween().set_parallel(true)
				tw.tween_property(card_node, "position:y", float(card_node.get_meta("resting_y")), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(card_node, "scale", Vector2(1.0, 1.0), 0.14)
				card_node.z_index = 0
			)

		var card_idx: int = i
		card_node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if is_interceptable:
					_execute_intercept_card(card_idx, card_node.global_position)
				elif is_playable:
					_on_card_pressed(card_idx, card_node)
				elif is_local_turn:
					_on_unplayable_card_clicked(card)
		)

		hand_container.add_child(card_node)

		if i == animate_drawn_index and draw_pile_button != null:
			var deck_global = draw_pile_button.global_position
			var start_local = hand_container.to_local(deck_global)
			card_node.position = start_local
			card_node.scale = Vector2(0.5, 0.5)
			var tw_draw = card_node.create_tween().set_parallel(true)
			tw_draw.tween_property(card_node, "position", resting_pos, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw_draw.tween_property(card_node, "scale", Vector2(1.0, 1.0), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if draw_pile_button != null:
		if not has_any_playable and is_local_turn:
			draw_pile_button.modulate = Color(1.18, 1.15, 0.85)
		else:
			draw_pile_button.modulate = Color(1.0, 1.0, 1.0)

	var opponent_id: int = P2 if local_player == P1 else P1
	if catch_uno_btn != null:
		var can_catch: bool = (opponent_card_count == 1 and not uno_called_players.has(opponent_id))
		catch_uno_btn.visible = can_catch

	if challenge_wild_four_btn != null:
		var can_challenge: bool = (last_wild_draw_four_player == opponent_id and is_local_turn)
		challenge_wild_four_btn.visible = can_challenge

	if jump_in_btn != null:
		jump_in_btn.visible = has_any_interceptable and (current != local_player)

	if call_uno_btn != null:
		var can_call: bool = (player_hand.size() <= 2 and not uno_called_players.has(local_player))
		call_uno_btn.modulate = Color(1.2, 1.1, 0.9) if can_call else Color(1.0, 1.0, 1.0)

	_restore_fixed_fonts(self)

func _get_discard_display_card(card: Dictionary) -> Dictionary:
	var norm := _normalize_card_dict(card)
	if (norm["color"] in ["Wild", "WildColor"] or norm["value"] in ["Wild", "WildDrawFour"]) and active_color in ["Red", "Blue", "Green", "Yellow"]:
		return {"color": active_color, "value": norm["value"]}
	return norm

func _update_discard_display() -> void:
	for child in discard_card_node.get_children():
		child.queue_free()

	var raw_top: Dictionary = discard_pile.back() if not discard_pile.is_empty() else {"color": "Red", "value": "1"}
	var display_card: Dictionary = _get_discard_display_card(raw_top)
	var card_visual = _create_card_visual(display_card, false, true)
	card_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card_visual.position = Vector2(0, 0)
	var card_sb = card_visual.get_theme_stylebox("panel")
	if card_sb != null:
		discard_card_node.add_theme_stylebox_override("panel", card_sb)
	discard_card_node.add_child(card_visual)

func _update_active_color_indicator() -> void:
	var col: Color = _get_accessible_card_color(active_color) if active_color in ["Red", "Blue", "Green", "Yellow"] else CARD_COLORS.get(active_color, CARD_COLORS["Red"])
	if active_color_rect != null:
		active_color_rect.color = col
	if active_color_label != null:
		active_color_label.text = COLOR_NAMES_ES.get(active_color, active_color).to_upper()
		active_color_label.add_theme_color_override("font_color", Color("#1A1A1A") if active_color == "Yellow" else Color.WHITE)
	if active_color_badge != null:
		var sb = active_color_badge.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb != null:
			sb.bg_color = col.darkened(0.08) if active_color != "Yellow" else col
			sb.border_color = Color.WHITE if active_color != "Yellow" else Color("#1A1A1A")
			active_color_badge.add_theme_stylebox_override("panel", sb)

# =========================================================================
# FLYING CARD ANIMATIONS (Play to Discard & AI Draw to Opponent Hand)
# =========================================================================
func _get_opponent_card_spawn_pos() -> Vector2:
	if opponent_hand_container != null and opponent_hand_container.is_inside_tree():
		return opponent_hand_container.global_position + Vector2(opponent_hand_container.size.x / 2.0 - 50.0, 0.0)
	return Vector2(590, 125)

func _animate_card_to_discard(card_dict: Dictionary, start_global_pos: Vector2) -> void:
	if OS.has_feature("headless"):
		_update_discard_display()
		_update_active_color_indicator()
		return

	var flying_card = _create_card_visual(_get_discard_display_card(card_dict), false, true)
	flying_card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	flying_card.z_index = 50
	flying_card.global_position = start_global_pos
	flying_card.pivot_offset = Vector2(54, 77)
	add_child(flying_card)

	var target_global_pos: Vector2 = discard_card_node.global_position

	var tween = create_tween().set_parallel(true)
	tween.tween_property(flying_card, "global_position", target_global_pos, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying_card, "rotation_degrees", randf_range(-10.0, 10.0), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var scale_tween = create_tween()
	scale_tween.tween_property(flying_card, "scale", Vector2(1.16, 1.16), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(flying_card, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func():
		_update_discard_display()
		_update_active_color_indicator()
		if (is_inside_tree() and has_node("/root/AudioManager")):
			get_node("/root/AudioManager").play_card_flip()
		if is_instance_valid(flying_card):
			flying_card.queue_free()
	)

func _animate_card_draw_to_opponent() -> void:
	if OS.has_feature("headless") or draw_pile_button == null:
		return
	var back_card = _create_card_back_visual()
	back_card.z_index = 45
	back_card.global_position = draw_pile_button.global_position + Vector2(30, 40)
	add_child(back_card)

	var target_pos := _get_opponent_card_spawn_pos()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(back_card, "global_position", target_pos, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(back_card):
			back_card.queue_free()
	)

# =========================================================================
# CARD INTERACTIONS & WILD FLOW
# =========================================================================
func _on_unplayable_card_clicked(card: Dictionary) -> void:
	var norm_c := _normalize_card_dict(card)
	var col_es: String = COLOR_NAMES_ES.get(active_color, active_color)
	if norm_c["value"] == "WildDrawFour":
		event_banner_label.text = "Regla oficial UNO: Solo puedes jugar +4 cuando no tengas ninguna carta de color %s en tu mano." % col_es
	else:
		event_banner_label.text = "Esa carta no coincide con el color activo (%s) ni con el símbolo actual." % col_es
	_sfx_error_buzz()

func _on_card_pressed(idx: int, card_btn: Control) -> void:
	if winner != -1 or wild_picker_modal.visible or _is_playing_ai_sequence:
		return

	if idx < 0 or idx >= player_hand.size():
		return

	var played_card := _normalize_card_dict(player_hand[idx])
	var c_color: String = played_card["color"]
	var c_val: String = played_card["value"]

	# If it's a Wild or Wild Draw 4 card, open color selector dialog
	if c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"]:
		_pending_drawn_wild_pick = false
		pending_wild_card_idx = idx
		_human_action_origin = card_btn.global_position
		wild_picker_modal.visible = true
		return

	# Non-wild cards MUST pass empty/null chosen_color to satisfy uno_game/src/rules.rs!
	_execute_play_card(idx, card_btn.global_position, "")

func _on_wild_color_chosen(chosen_col: String) -> void:
	wild_picker_modal.visible = false
	if _pending_drawn_wild_pick:
		_pending_drawn_wild_pick = false
		var choose_rejected: bool = false
		if bridge != null:
			var choose_cmd: Dictionary = {
				"command_type": "ChooseWildColorCommand",
				"player": local_player,
				"chosen_color": chosen_col
			}
			_last_move_rejected = false
			bridge.send_command_json(local_player, JSON.stringify(choose_cmd))
			choose_rejected = _last_move_rejected
			_last_move_rejected = false

		if not choose_rejected:
			_drawn_wild_override_color = chosen_col
			active_color = chosen_col
		else:
			_drawn_wild_override_color = ""
			if bridge != null and bridge.has_method("get_uno_state"):
				var st_now = bridge.get_uno_state(local_player)
				if st_now is Dictionary and st_now.has("active_color"):
					var ac_str := str(st_now["active_color"])
					active_color = chosen_col if ac_str in ["Wild", "WildColor"] else ac_str

		_update_discard_display()
		_update_active_color_indicator()
		var col_es: String = COLOR_NAMES_ES.get(active_color, active_color)

		if _drawn_wild_card_val == "WildDrawFour" or _rust_draw_penalty > 0 or draw_penalty > 0:
			_drawn_wild_card_val = ""
			_resolve_immediate_penalty_after_card(local_player, active_color, 4)
			return

		_drawn_wild_card_val = ""
		event_banner_label.text = "¡Comodín jugado al instante! Color activo establecido a %s." % col_es.to_upper()
		if is_vs_ai and winner == -1:
			_run_uno_ai_turns_if_needed()
		if not _is_playing_ai_sequence:
			if bridge != null:
				current = int(bridge.current_player())
			_sync_uno_state_from_bridge(not _drawn_wild_override_color.is_empty())
			_update_ui()
			_update_status()
		return

	if pending_wild_card_idx >= 0 and pending_wild_card_idx < player_hand.size():
		var origin_pos := _human_action_origin if _human_action_origin != Vector2.ZERO else (hand_container.global_position + Vector2(450, 40))
		_execute_play_card(pending_wild_card_idx, origin_pos, chosen_col)
	pending_wild_card_idx = -1

func _execute_play_card(idx: int, start_pos: Vector2, chosen_col: String = "") -> void:
	if idx < 0 or idx >= player_hand.size():
		return
	if (_rust_draw_penalty > 0 or draw_penalty > 0) and winner == -1:
		_auto_apply_pending_draw_penalty()
		if idx >= player_hand.size():
			return

	var played_card := _normalize_card_dict(player_hand[idx])
	var c_color: String = played_card["color"]
	var c_val: String = played_card["value"]
	var is_wild: bool = (c_color in ["Wild", "WildColor"] or c_val in ["Wild", "WildDrawFour"])
	var target_color: String = chosen_col if (is_wild and not chosen_col.is_empty()) else c_color

	_drawn_wild_override_color = ""
	var acting_p: int = int(current)
	var cmd: Dictionary = {
		"command_type": "PlayCardCommand",
		"player": acting_p,
		"card_index": idx,
		"chosen_color": null
	}
	if is_wild and not chosen_col.is_empty():
		cmd["chosen_color"] = chosen_col

	_last_move_rejected = false
	_human_action_origin = start_pos
	bridge.send_command_json(acting_p, JSON.stringify(cmd))

	if _last_move_rejected:
		return

	if c_val in ["DrawTwo", "WildDrawFour"] and winner == -1:
		var pen_cnt: int = 4 if c_val == "WildDrawFour" else 2
		_resolve_immediate_penalty_after_card(acting_p, target_color, pen_cnt)
		return

	if is_vs_ai and winner == -1:
		_run_uno_ai_turns_if_needed()

	if not _is_playing_ai_sequence:
		_auto_apply_pending_draw_penalty()
		current = int(bridge.current_player())
		_sync_uno_state_from_bridge()
		_update_ui()
		_update_status()

func _resolve_immediate_penalty_after_card(acting_p: int, expected_color: String, penalty_cards: int) -> void:
	if bridge == null or winner != -1:
		return

	var guard: int = 0
	while (_rust_draw_penalty > 0 or draw_penalty > 0) and winner == -1 and guard < 4:
		guard += 1
		var penalized_p: int = int(bridge.current_player())
		if penalized_p <= 0:
			break
		_applying_auto_penalty = true
		_last_move_rejected = false
		bridge.send_command_json(penalized_p, JSON.stringify({
			"command_type": "DrawCardCommand",
			"player": penalized_p
		}))
		_applying_auto_penalty = false
		if _last_move_rejected:
			_last_move_rejected = false
			break

	draw_penalty = 0
	_rust_draw_penalty = 0
	if expected_color in ["Red", "Blue", "Green", "Yellow"]:
		active_color = expected_color

	if is_vs_ai and winner == -1 and int(bridge.current_player()) != local_player:
		_run_uno_ai_turns_if_needed()

	if not _is_playing_ai_sequence:
		current = int(bridge.current_player())
		_sync_uno_state_from_bridge(true)
		draw_penalty = 0
		_rust_draw_penalty = 0
		var skipped_id: int = P2 if acting_p == P1 else P1
		var skipped_name: String = _get_player_display_name(skipped_id)
		var col_es: String = COLOR_NAMES_ES.get(active_color, active_color)
		event_banner_label.text = "¡%s roba +%d cartas y pierde su turno! Color activo: %s — ¡Juegas de nuevo!" % [skipped_name, penalty_cards, col_es]
		_update_ui()
		_update_status()

func _auto_apply_pending_draw_penalty() -> void:
	var guard: int = 0
	while (_rust_draw_penalty > 0 or draw_penalty > 0) and winner == -1 and bridge != null and guard < 8:
		guard += 1
		var target_p: int = int(bridge.current_player())
		if target_p <= 0:
			break
		var penalty_amount: int = _rust_draw_penalty if _rust_draw_penalty > 0 else draw_penalty
		var draw_cmd: Dictionary = {
			"command_type": "DrawCardCommand",
			"player": target_p
		}
		_last_move_rejected = false
		_applying_auto_penalty = true
		bridge.send_command_json(target_p, JSON.stringify(draw_cmd))
		_applying_auto_penalty = false
		if _last_move_rejected:
			_last_move_rejected = false
			draw_penalty = 0
			_rust_draw_penalty = 0
			break
		draw_penalty = 0
		_rust_draw_penalty = 0
		var target_name: String = _get_player_display_name(target_p)
		var col_es: String = COLOR_NAMES_ES.get(active_color, active_color)
		event_banner_label.text = "¡%s roba +%d cartas automáticamente y pierde el turno! Color activo: %s." % [target_name, penalty_amount, col_es]

func _run_uno_ai_turns_if_needed() -> void:
	if not is_vs_ai or bridge == null or winner != -1 or _pending_drawn_wild_pick or _executing_ai_turn:
		return
	var ai_id: int = P2 if local_player == P1 else P1
	_executing_ai_turn = true
	var step_guard: int = 0
	while winner == -1 and not _pending_drawn_wild_pick and step_guard < 16:
		step_guard += 1
		var curr_p: int = int(bridge.current_player())
		if curr_p != ai_id:
			if _rust_draw_penalty > 0 and curr_p == local_player:
				_auto_apply_pending_draw_penalty()
				continue
			break

		if _rust_draw_penalty > 0:
			_applying_auto_penalty = true
			_last_move_rejected = false
			bridge.send_command_json(ai_id, JSON.stringify({
				"command_type": "DrawCardCommand",
				"player": ai_id
			}))
			_applying_auto_penalty = false
			draw_penalty = 0
			_rust_draw_penalty = 0
			if _last_move_rejected:
				_last_move_rejected = false
				break
			continue

		var ai_st: Dictionary = bridge.get_uno_state(ai_id)
		var raw_hand: Array = ai_st.get("hand", []) if (ai_st.has("hand") and ai_st["hand"] is Array) else []
		var ai_hand: Array = []
		for rc in raw_hand:
			if rc is Dictionary:
				ai_hand.append(_normalize_card_dict(rc))

		var ai_active_col: String = str(ai_st.get("active_color", active_color))
		if ai_active_col == "WildColor":
			ai_active_col = "Wild"
		var ai_top_card: Dictionary = _normalize_card_dict(ai_st.get("top_card", {"color": "Red", "value": "1"})) if (ai_st.has("top_card") and ai_st["top_card"] is Dictionary) else {"color": active_color, "value": "1"}
		var ai_top_val: String = str(ai_top_card.get("value", "1"))

		if ai_hand.size() == 1 and not uno_called_players.has(ai_id):
			_last_move_rejected = false
			bridge.send_command_json(ai_id, JSON.stringify({
				"type": "CallUnoCommand",
				"command_type": "CallUnoCommand",
				"player": ai_id
			}))
			_last_move_rejected = false

		var has_active_color_card: bool = false
		for c in ai_hand:
			if str(c.get("color", "")) == ai_active_col:
				has_active_color_card = true
				break

		var playable_indices: Array = []
		for idx in range(ai_hand.size()):
			var c: Dictionary = ai_hand[idx]
			var c_col: String = str(c.get("color", ""))
			var c_val: String = str(c.get("value", ""))
			if c_val == "WildDrawFour":
				if not has_active_color_card:
					playable_indices.append(idx)
			elif c_col in ["Wild", "WildColor"] or c_val == "Wild":
				playable_indices.append(idx)
			elif c_col == ai_active_col or c_val == ai_top_val:
				playable_indices.append(idx)

		if playable_indices.is_empty():
			_last_move_rejected = false
			bridge.send_command_json(ai_id, JSON.stringify({
				"command_type": "DrawCardCommand",
				"player": ai_id
			}))
			if _last_move_rejected:
				_last_move_rejected = false
				break
			if _rust_draw_penalty > 0 and winner == -1:
				_auto_apply_pending_draw_penalty()
			continue

		var chosen_idx: int = int(playable_indices[0])
		for p_idx in playable_indices:
			var pc: Dictionary = ai_hand[p_idx]
			if not (str(pc.get("color", "")) in ["Wild", "WildColor"] or str(pc.get("value", "")) in ["Wild", "WildDrawFour"]):
				chosen_idx = int(p_idx)
				break

		var chosen_card: Dictionary = ai_hand[chosen_idx]
		var cc_col: String = str(chosen_card.get("color", ""))
		var cc_val: String = str(chosen_card.get("value", ""))
		var cc_is_wild: bool = (cc_col in ["Wild", "WildColor"] or cc_val in ["Wild", "WildDrawFour"])

		var ai_chosen_color = null
		if cc_is_wild:
			var color_counts := {"Red": 0, "Blue": 0, "Green": 0, "Yellow": 0}
			for h_idx in range(ai_hand.size()):
				if h_idx == chosen_idx:
					continue
				var hc_col: String = str(ai_hand[h_idx].get("color", ""))
				if color_counts.has(hc_col):
					color_counts[hc_col] += 1
			var best_col: String = "Red"
			var best_cnt: int = -1
			for col_k in ["Red", "Blue", "Green", "Yellow"]:
				if int(color_counts[col_k]) > best_cnt:
					best_cnt = int(color_counts[col_k])
					best_col = col_k
			ai_chosen_color = best_col

		var play_cmd: Dictionary = {
			"command_type": "PlayCardCommand",
			"player": ai_id,
			"card_index": chosen_idx,
			"chosen_color": ai_chosen_color
		}
		_last_move_rejected = false
		bridge.send_command_json(ai_id, JSON.stringify(play_cmd))
		if _last_move_rejected:
			_last_move_rejected = false
			bridge.send_command_json(ai_id, JSON.stringify({
				"command_type": "DrawCardCommand",
				"player": ai_id
			}))
			if _last_move_rejected:
				_last_move_rejected = false
				break

		if ai_hand.size() == 2 and winner == -1 and not uno_called_players.has(ai_id):
			bridge.send_command_json(ai_id, JSON.stringify({
				"type": "CallUnoCommand",
				"command_type": "CallUnoCommand",
				"player": ai_id
			}))
			_last_move_rejected = false

		if _rust_draw_penalty > 0 and winner == -1:
			_auto_apply_pending_draw_penalty()

	_executing_ai_turn = false

func _on_draw_pile_pressed() -> void:
	if winner != -1 or wild_picker_modal.visible or _is_playing_ai_sequence:
		return
	if is_vs_ai and current != local_player:
		return

	_sfx_card_flip()
	var prev_hand_size: int = player_hand.size()
	var acting_p: int = int(current)
	var cmd: Dictionary = {
		"command_type": "DrawCardCommand",
		"player": acting_p
	}

	_last_move_rejected = false
	_human_action_origin = draw_pile_button.global_position if draw_pile_button != null else Vector2(750, 290)
	bridge.send_command_json(acting_p, JSON.stringify(cmd))

	if _last_move_rejected:
		return

	if _pending_drawn_wild_pick:
		_update_ui()
		_update_status()
		return

	if (_rust_draw_penalty > 0 or draw_penalty > 0) and winner == -1:
		var pen_val: int = _rust_draw_penalty if _rust_draw_penalty > 0 else draw_penalty
		_resolve_immediate_penalty_after_card(acting_p, active_color, pen_val)
		return

	if is_vs_ai and winner == -1:
		_run_uno_ai_turns_if_needed()

	if not _is_playing_ai_sequence:
		_auto_apply_pending_draw_penalty()
		current = int(bridge.current_player())
		_sync_uno_state_from_bridge(_pending_drawn_wild_pick)
		var drawn_idx: int = (player_hand.size() - 1) if player_hand.size() > prev_hand_size else -1
		_update_ui(drawn_idx)
		_update_status()

# =========================================================================
# UNO OFFICIAL RULES ACTIONS & HANDLERS
# =========================================================================
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
			var btn_pos = hand_container.global_position + Vector2(450, 50)
			_execute_intercept_card(i, btn_pos)
			break

func _execute_intercept_card(idx: int, start_pos: Vector2) -> void:
	if idx < 0 or idx >= player_hand.size():
		return
	var intercepted_card := _normalize_card_dict(player_hand[idx])
	var c_val: String = intercepted_card["value"]
	var c_color: String = intercepted_card["color"]
	var cmd = {
		"type": "InterceptCommand",
		"command_type": "InterceptCommand",
		"player": local_player,
		"card_index": idx
	}
	_last_move_rejected = false
	_human_action_origin = start_pos
	bridge.send_command_json(local_player, JSON.stringify(cmd))

	if _last_move_rejected:
		return

	if c_val == "DrawTwo" and winner == -1:
		_resolve_immediate_penalty_after_card(local_player, c_color, 2)
		return

	if is_vs_ai and winner == -1:
		_run_uno_ai_turns_if_needed()

	if not _is_playing_ai_sequence:
		_auto_apply_pending_draw_penalty()
		current = bridge.current_player()
		_sync_uno_state_from_bridge()
		_update_ui()
		_update_status()

# =========================================================================
# EVENT JSON PROCESSING & PACED AI TURN PRESENTATION
# =========================================================================
func _is_ai_event(event: Dictionary) -> bool:
	if not is_vs_ai:
		return false
	var event_type: String = str(event.get("command_type", event.get("event_type", "")))
	if event.has("player"):
		return int(event["player"]) != local_player
	if event_type.ends_with("TurnReversedEvent") or event_type.ends_with("PlayerSkippedEvent") or event_type.ends_with("GameOverEvent"):
		return not _ai_visual_queue.is_empty() or _is_playing_ai_sequence
	return false

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) != OK:
		return
	var event = parser.data
	if not (event is Dictionary):
		return

	var ev_type: String = str(event.get("command_type", event.get("event_type", "")))
	if ev_type.ends_with("CardPlayedEvent") or ev_type.ends_with("DrewAndPlayedEvent") or ev_type.ends_with("InterceptedEvent"):
		if event.has("card") and event["card"] is Dictionary:
			var ev_c := _normalize_card_dict(event["card"])
			if ev_c["value"] == "DrawTwo":
				_rust_draw_penalty += 2
			elif ev_c["value"] == "WildDrawFour":
				_rust_draw_penalty += 4
	elif ev_type.ends_with("CardsDrawnEvent") or ev_type.ends_with("WildDrawFourChallengedEvent"):
		_rust_draw_penalty = 0

	var is_immediate_penalty_draw: bool = _ai_visual_queue.is_empty() and not _is_playing_ai_sequence and (_applying_auto_penalty and ev_type.ends_with("CardsDrawnEvent"))

	# Queue AI opponent events for smooth paced visual playback in interactive mode
	if not is_immediate_penalty_draw and not OS.has_feature("headless") and is_inside_tree() and (_is_ai_event(event) or not _ai_visual_queue.is_empty()):
		_ai_visual_queue.append(event)
		if not _is_playing_ai_sequence:
			_start_ai_visual_sequence()
		return

	_apply_event_immediately(event)
	if not _is_playing_ai_sequence:
		current = bridge.current_player()
		_sync_uno_state_from_bridge(_pending_drawn_wild_pick)
		_update_ui()
		_update_status()

func _start_ai_visual_sequence() -> void:
	_is_playing_ai_sequence = true
	var ai_id: int = P2 if local_player == P1 else P1
	current = ai_id
	_update_ui()
	_update_status()
	if is_inside_tree():
		get_tree().create_timer(0.65).timeout.connect(_step_ai_visual_queue)
	else:
		_flush_ai_visual_queue_immediately()

func _finish_ai_visual_sequence() -> void:
	_is_playing_ai_sequence = false
	if (_rust_draw_penalty > 0 or draw_penalty > 0) and winner == -1:
		_auto_apply_pending_draw_penalty()
		if _is_playing_ai_sequence:
			return
	draw_penalty = _rust_draw_penalty
	if bridge != null:
		current = bridge.current_player()
		_sync_uno_state_from_bridge(_pending_drawn_wild_pick)
	_update_ui()
	_update_status()

func _step_ai_visual_queue() -> void:
	if _ai_visual_queue.is_empty():
		_finish_ai_visual_sequence()
		return

	var next_ev: Dictionary = _ai_visual_queue.pop_front()
	_apply_event_immediately(next_ev)
	_update_ui()
	_update_status()

	if _ai_visual_queue.is_empty():
		if is_inside_tree():
			get_tree().create_timer(0.45).timeout.connect(_finish_ai_visual_sequence)
		else:
			_finish_ai_visual_sequence()
	else:
		var ev_type: String = str(next_ev.get("command_type", next_ev.get("event_type", "")))
		var delay_sec: float = 0.25 if (ev_type.ends_with("PlayerSkippedEvent") or ev_type.ends_with("TurnReversedEvent") or ev_type.ends_with("UnoCalledEvent")) else 0.65
		if is_inside_tree():
			get_tree().create_timer(delay_sec).timeout.connect(_step_ai_visual_queue)
		else:
			_flush_ai_visual_queue_immediately()

func _flush_ai_visual_queue_immediately() -> void:
	while not _ai_visual_queue.is_empty():
		var ev: Dictionary = _ai_visual_queue.pop_front()
		_apply_event_immediately(ev)
	_finish_ai_visual_sequence()

func _apply_event_immediately(event: Dictionary) -> void:
	var event_type: String = str(event.get("command_type", event.get("event_type", "")))

	if event_type == "CardPlayedEvent" or event_type == "uno_game::CardPlayedEvent":
		var p: int = int(event.get("player", current))
		var p_label: String = _get_player_display_name(p)
		if event.has("card") and event["card"] is Dictionary:
			var c := _normalize_card_dict(event["card"])
			discard_pile.append(c)
			var val_str: String = c["value"]
			if val_str == "DrawTwo":
				draw_penalty += 2
			elif val_str == "WildDrawFour":
				draw_penalty += 4
				last_wild_draw_four_player = p
			else:
				last_wild_draw_four_player = -1

			if event.has("new_color"):
				var nc := str(event["new_color"])
				active_color = "Wild" if nc == "WildColor" else nc
			elif c["color"] in ["Red", "Blue", "Green", "Yellow"]:
				active_color = c["color"]

			if p == local_player:
				# Remove one matching card from local player's hand for immediate visual accuracy
				for idx in range(player_hand.size()):
					var hc := _normalize_card_dict(player_hand[idx])
					if hc["color"] == c["color"] and hc["value"] == c["value"]:
						player_hand.remove_at(idx)
						break
				var start_p := _human_action_origin if _human_action_origin != Vector2.ZERO else (hand_container.global_position + Vector2(450, 40))
				_animate_card_to_discard(c, start_p)
			else:
				opponent_card_count = max(0, opponent_card_count - 1)
				_animate_card_to_discard(c, _get_opponent_card_spawn_pos())

			_update_discard_display()
			_update_active_color_indicator()

			var col_es: String = COLOR_NAMES_ES.get(active_color if c["color"] == "Wild" else c["color"], c["color"])
			var sym_es: String = _get_card_display_symbol(val_str)
			event_banner_label.text = "%s jugó %s %s (Color activo: %s)" % [p_label, col_es, sym_es, COLOR_NAMES_ES.get(active_color, active_color)]

	elif event_type == "DrewAndPlayedEvent" or event_type == "uno_game::DrewAndPlayedEvent":
		var p: int = int(event.get("player", current))
		var p_label: String = _get_player_display_name(p)
		deck_count = max(0, deck_count - 1)
		if event.has("card") and event["card"] is Dictionary:
			var c := _normalize_card_dict(event["card"])
			discard_pile.append(c)
			var val_str: String = c["value"]
			if val_str == "DrawTwo":
				draw_penalty += 2
			elif val_str == "WildDrawFour":
				draw_penalty += 4
				last_wild_draw_four_player = p
			else:
				last_wild_draw_four_player = -1

			if event.has("new_color"):
				var nc := str(event["new_color"])
				active_color = "Wild" if nc == "WildColor" else nc
			elif c["color"] in ["Red", "Blue", "Green", "Yellow"]:
				active_color = c["color"]

			var spawn_p := draw_pile_button.global_position if draw_pile_button != null else _get_opponent_card_spawn_pos()
			_animate_card_to_discard(c, spawn_p)
			_update_discard_display()
			_update_active_color_indicator()

			var is_drawn_wild: bool = (c["color"] in ["Wild", "WildColor"] or val_str in ["Wild", "WildDrawFour"])
			if is_drawn_wild and p == local_player:
				_drawn_wild_card_val = val_str
				if not OS.has_feature("headless"):
					_pending_drawn_wild_pick = true
					pending_wild_card_idx = -1
					wild_picker_modal.visible = true

			var col_es: String = COLOR_NAMES_ES.get(active_color if c["color"] == "Wild" else c["color"], c["color"])
			var sym_es: String = _get_card_display_symbol(val_str)
			event_banner_label.text = "%s robó del mazo y jugó %s %s (Color activo: %s)" % [p_label, col_es, sym_es, COLOR_NAMES_ES.get(active_color, active_color)]

	elif event_type == "ColorChangedEvent" or event_type == "uno_game::ColorChangedEvent":
		if event.has("color"):
			active_color = str(event["color"])
		elif event.has("new_color"):
			active_color = str(event["new_color"])
		_update_discard_display()
		_update_active_color_indicator()
		event_banner_label.text = "¡Color activo cambiado a %s!" % COLOR_NAMES_ES.get(active_color, active_color).to_upper()

	elif event_type == "TurnReversedEvent" or event_type == "uno_game::TurnReversedEvent":
		is_clockwise = not is_clockwise
		event_banner_label.text = "¡Reversa! Sentido cambiado a %s" % ("Horario" if is_clockwise else "Antihorario")

	elif event_type == "PlayerSkippedEvent" or event_type == "uno_game::PlayerSkippedEvent":
		var skipped_p: int = int(event.get("skipped_player", 0))
		event_banner_label.text = "¡%s pierde su turno (Salto)!" % _get_player_display_name(skipped_p)

	elif event_type == "CardsDrawnEvent" or event_type == "uno_game::CardsDrawnEvent":
		var p: int = int(event.get("player", current))
		var cnt: int = int(event.get("count", 1))
		draw_penalty = 0
		last_wild_draw_four_player = -1
		deck_count = max(0, deck_count - cnt)
		if p != local_player:
			opponent_card_count += cnt
			_animate_card_draw_to_opponent()
		event_banner_label.text = "%s robó %d carta(s) del mazo" % [_get_player_display_name(p), cnt]

	elif event_type == "GameOverEvent" or event_type == "uno_game::GameOverEvent":
		var w = event.get("winner", -1)
		if w == null:
			w = 0
		_on_game_over(int(w))

	elif event_type == "UnoCalledEvent" or event_type == "uno_game::UnoCalledEvent":
		var p: int = int(event.get("player", 0))
		if not uno_called_players.has(p):
			uno_called_players.append(p)
		event_banner_label.text = "🔥 ¡%s cantó UNO! 🔥" % _get_player_display_name(p)
		if uno_alert_banner != null:
			uno_alert_banner.visible = true
			uno_alert_label.text = "🔥 ¡¡ %s CANTÓ UNO !! 🔥" % _get_player_display_name(p).to_upper()

	elif event_type == "UnoPenaltyEvent" or event_type == "uno_game::UnoPenaltyEvent":
		var target_p: int = int(event.get("target", 0))
		var accuser_p: int = int(event.get("accuser", 0))
		var drawn_cnt: int = int(event.get("drawn", 2))
		event_banner_label.text = "🚨 ¡%s acusó a %s! (+%d cartas)" % [_get_player_display_name(accuser_p), _get_player_display_name(target_p), drawn_cnt]
		uno_called_players.erase(target_p)

	elif event_type == "WildDrawFourChallengedEvent" or event_type == "uno_game::WildDrawFourChallengedEvent":
		var ch: int = int(event.get("challenger", 0))
		var tg: int = int(event.get("target", 0))
		var was_illegal: bool = bool(event.get("was_illegal", false))
		var drawn_cnt: int = int(event.get("cards_drawn", 0))
		draw_penalty = 0
		if was_illegal:
			event_banner_label.text = "⚡ ¡Desafío exitoso! %s jugó +4 ilegal y roba %d cartas" % [_get_player_display_name(tg), drawn_cnt]
		else:
			event_banner_label.text = "⚡ ¡Desafío fallido! %s jugó legal; %s roba %d cartas" % [_get_player_display_name(tg), _get_player_display_name(ch), drawn_cnt]
		last_wild_draw_four_player = -1

	elif event_type == "InterceptedEvent" or event_type == "uno_game::InterceptedEvent":
		var p: int = int(event.get("player", 0))
		if event.has("card") and event["card"] is Dictionary:
			var c := _normalize_card_dict(event["card"])
			discard_pile.append(c)
			if c["color"] in ["Red", "Blue", "Green", "Yellow"]:
				active_color = c["color"]
			if c["value"] == "DrawTwo":
				draw_penalty += 2
			if p != local_player:
				opponent_card_count = max(0, opponent_card_count - 1)
				_animate_card_to_discard(c, _get_opponent_card_spawn_pos())
			else:
				_animate_card_to_discard(c, _human_action_origin)
			_update_discard_display()
			_update_active_color_indicator()
		event_banner_label.text = "⚡ ¡JUMP-IN! %s interceptó con una carta idéntica" % _get_player_display_name(p)

func _on_turn_changed(player_id: int) -> void:
	if _is_playing_ai_sequence:
		return
	current = player_id
	_sync_uno_state_from_bridge(_pending_drawn_wild_pick)
	_update_ui()
	_update_status()

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
	_last_move_rejected = true
	if status != null:
		status.text = "Movimiento inválido: %s" % reason
	if event_banner_label != null:
		event_banner_label.text = "Movimiento no permitido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _on_viewport_size_changed() -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	_on_layout_changed(int(gm.get_layout()) if (gm != null and gm.has_method("get_layout")) else 0)

func _on_layout_changed(layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	table_mat_panel.position = Vector2(40, 14)
	table_mat_panel.size = Vector2(1200, 692)
	top_bar.position = Vector2(70, 24)
	top_bar.size = Vector2(1140, 40)
	turn_indicator.position = Vector2(70, 70)
	turn_indicator.custom_minimum_size = Vector2(1140, 38)
	turn_indicator.size = Vector2(1140, 38)
	opp_vbox.position = Vector2(190, 110)
	opp_vbox.size = Vector2(900, 74)
	event_banner_panel.position = Vector2(240, 190)
	event_banner_panel.size = Vector2(800, 34)
	center_play_area.position = Vector2(190, 230)
	center_play_area.size = Vector2(900, 200)
	if action_buttons_bar != null:
		action_buttons_bar.position = Vector2(240, 436)
		action_buttons_bar.size = Vector2(800, 36)
	hand_container.position = Vector2(90, 476)
	hand_container.size = Vector2(1100, 215)

	var vp_size := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz := get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)

	var design_w := 1280.0
	var design_h := 720.0
	if layout == 2 or vp_size.x < design_w or vp_size.y < design_h:
		var s := clampf(minf(vp_size.x / design_w, vp_size.y / design_h), 0.28, 1.0)
		scale = Vector2(s, s)
		position = Vector2(maxf(0.0, (vp_size.x - design_w * s) * 0.5), maxf(0.0, (vp_size.y - design_h * s) * 0.5))
	else:
		scale = Vector2.ONE
		position = Vector2.ZERO

	_update_ui()
	_restore_fixed_fonts(self)

func _update_status() -> void:
	var p_name: String = _get_player_display_name(current)
	var p_col: Color = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(current) - 1, 6)] as Color)
	if winner != -1:
		if status != null:
			status.text = "¡Ganó %s! (UNO)" % _get_player_display_name(winner)
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		if status != null:
			status.text = "Turno: %s (UNO)" % p_name
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
