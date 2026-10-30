extends Node2D

const P1 = 1
const P2 = 2

# Card Categories and Styles
const CARD_CATEGORIES = {
	"DISTANCE": {
		"color": Color("#2B6CB0"),      # Blue
		"border": Color("#63B3ED"),
		"text_color": Color("#EBF8FF"),
		"badge": "🏁"
	},
	"HAZARD": {
		"color": Color("#C53030"),        # Red
		"border": Color("#FC8181"),
		"text_color": Color("#FFF5F5"),
		"badge": "⚠️"
	},
	"REMEDY": {
		"color": Color("#276749"),        # Green
		"border": Color("#68D391"),
		"text_color": Color("#F0FFF4"),
		"badge": "🔧"
	},
	"SAFETY": {
		"color": Color("#744210"),        # Golden/Amber
		"border": Color("#F6E05E"),
		"text_color": Color("#FFFFF0"),
		"badge": "⭐"
	},
	"DEFAULT": {
		"color": Color("#2D3748"),
		"border": Color("#718096"),
		"text_color": Color("#EDF2F7"),
		"badge": "🎴"
	}
}

var bridge
var current: int = P1
var winner: int = -1

# Player state
const SHIELD_INACTIVE = "INACTIVE"
const SHIELD_ACTIVE = "ACTIVE"
const SHIELD_COUP_FOURRE = "COUP_FOURRE"

var distance = {P1: 0, P2: 0}
var hazards = {P1: "Luz Verde (Siga)", P2: "Luz Verde (Siga)"}
var safeties = {P1: [], P2: []}
var coup_fourre_safeties = {P1: [], P2: []}
var shield_states = {
	P1: {"RightOfWay": SHIELD_INACTIVE, "ExtraTank": SHIELD_INACTIVE, "PunctureProof": SHIELD_INACTIVE, "DrivingAce": SHIELD_INACTIVE},
	P2: {"RightOfWay": SHIELD_INACTIVE, "ExtraTank": SHIELD_INACTIVE, "PunctureProof": SHIELD_INACTIVE, "DrivingAce": SHIELD_INACTIVE}
}
var hand_p1 = ["Distance 25", "Distance 50", "Distance 75", "Distance 100", "Luz Verde", "Gasolina"]
var speed_limit = {P1: false, P2: false}
var deck_count: int = 44
var discard_pile: Array = []
var local_player: int = P1
var is_vs_ai: bool = false

# UI Nodes
var main_vbox: VBoxContainer
var top_bar: HBoxContainer
var hand_panel: Panel
var hand_container: HBoxContainer
var local_tableau: Panel
var opponent_tableau: Panel
var draw_button: Button
var discard_mode: CheckBox
var coup_fourre_btn: Button = null
var mode_option_button: OptionButton = null
var selected_card_idx: int = -1

# Hazard & Status HUD overlays
var p1_hazard_banner: PanelContainer
var p1_hazard_label: Label
var p2_hazard_banner: PanelContainer
var p2_hazard_label: Label

var p1_dist_label: Label
var p1_prog_bar: ProgressBar
var p1_safeties_label: Label
var p2_dist_label: Label
var p2_prog_bar: ProgressBar
var p2_safeties_label: Label

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
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
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
		bridge.start_local_match_mille_bornes_vs_ai(human_p, ai_p, diff)
	else:
		is_vs_ai = false
		local_player = P1
		bridge.start_local_match_mille_bornes(P1, P2)
	current = bridge.current_player()
	_sync_hand_from_bridge()

	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_hand_ui()
	_update_tableaus()
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
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	winner = -1
	distance = {P1: 0, P2: 0}
	hazards = {P1: "Luz Verde (Siga)", P2: "Luz Verde (Siga)"}
	safeties = {P1: [], P2: []}
	coup_fourre_safeties = {P1: [], P2: []}
	shield_states = {
		P1: {"RightOfWay": SHIELD_INACTIVE, "ExtraTank": SHIELD_INACTIVE, "PunctureProof": SHIELD_INACTIVE, "DrivingAce": SHIELD_INACTIVE},
		P2: {"RightOfWay": SHIELD_INACTIVE, "ExtraTank": SHIELD_INACTIVE, "PunctureProof": SHIELD_INACTIVE, "DrivingAce": SHIELD_INACTIVE}
	}
	if index == 0:
		if gm != null and gm.has_method("set_game_mode"):
			gm.set_game_mode("local")
		is_vs_ai = false
		local_player = P1
		bridge.start_local_match_mille_bornes(P1, P2)
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
		bridge.start_local_match_mille_bornes_vs_ai(human_p, ai_p, diff)
	current = bridge.current_player()
	_sync_hand_from_bridge()
	_update_hand_ui()
	_update_tableaus()
	_update_status()

func _sync_hand_from_bridge() -> void:
	if bridge != null and bridge.has_method("get_mille_bornes_hand"):
		var target_p: int = local_player if is_vs_ai else current
		var raw_hand = bridge.get_mille_bornes_hand(target_p)
		if raw_hand is Array and raw_hand.size() > 0:
			hand_p1.clear()
			for c in raw_hand:
				hand_p1.append(str(c))

func _create_default_theme() -> void:
	current_theme = BoardTheme.new()
	current_theme.theme_name = "Noche Azul"
	current_theme.board_color = Color("#121A24")
	current_theme.line_color = Color("#7C9BB8")
	current_theme.light_color = Color("#5B7A9C")
	current_theme.dark_color = Color("#1A2634")
	current_theme.select_color = Color(1.0, 0.85, 0.25, 0.85)
	current_theme.valid_move_color = Color(0.2, 0.9, 0.5, 0.85)

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	_apply_theme_styling()
	_update_tableaus()
	_update_hand_ui()

func _apply_theme_styling() -> void:
	if current_theme == null:
		return

	if local_tableau:
		var tab_style = StyleBoxFlat.new()
		tab_style.bg_color = current_theme.dark_color.darkened(0.2)
		tab_style.border_color = Color(0.2, 0.8, 0.4)
		tab_style.set_border_width_all(2)
		tab_style.corner_radius_top_left = 10
		tab_style.corner_radius_top_right = 10
		tab_style.corner_radius_bottom_left = 10
		tab_style.corner_radius_bottom_right = 10
		local_tableau.add_theme_stylebox_override("panel", tab_style)

	if opponent_tableau:
		var opp_style = StyleBoxFlat.new()
		opp_style.bg_color = current_theme.dark_color.darkened(0.25)
		opp_style.border_color = Color(0.85, 0.35, 0.35)
		opp_style.set_border_width_all(2)
		opp_style.corner_radius_top_left = 10
		opp_style.corner_radius_top_right = 10
		opp_style.corner_radius_bottom_left = 10
		opp_style.corner_radius_bottom_right = 10
		opponent_tableau.add_theme_stylebox_override("panel", opp_style)

	if hand_panel:
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = current_theme.board_color.darkened(0.15)
		h_style.border_color = current_theme.line_color.darkened(0.3)
		h_style.set_border_width_all(2)
		h_style.corner_radius_top_left = 10
		h_style.corner_radius_top_right = 10
		h_style.corner_radius_bottom_left = 10
		h_style.corner_radius_bottom_right = 10
		hand_panel.add_theme_stylebox_override("panel", h_style)

func _setup_ui() -> void:
	# Top bar with game title, rules popup button and turn indicator
	top_bar = HBoxContainer.new()
	top_bar.position = Vector2(50, 20)
	top_bar.size = Vector2(700, 45)
	top_bar.add_theme_constant_override("separation", 15)
	add_child(top_bar)

	var title_lbl = Label.new()
	title_lbl.text = "🏎️ MILLE BORNES (1000 Millas)"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(90, 36)
	btn_rules.visible = false
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("mille_bornes"))
	top_bar.add_child(btn_rules)

	var mode_opt: OptionButton = OptionButton.new()
	mode_opt.name = "ModeOptionButton"
	mode_option_button = mode_opt
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

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(50, 72)
	add_child(turn_indicator)

	# Local Player Tableau (Left side)
	local_tableau = Panel.new()
	local_tableau.name = "LocalTableau"
	local_tableau.position = Vector2(50, 130)
	local_tableau.size = Vector2(400, 310)
	add_child(local_tableau)

	# Opponent Tableau (Right side)
	opponent_tableau = Panel.new()
	opponent_tableau.name = "OpponentTableau"
	opponent_tableau.position = Vector2(480, 130)
	opponent_tableau.size = Vector2(270, 310)
	add_child(opponent_tableau)

	# Deck Draw Button & Discard toggle
	var controls_hbox = HBoxContainer.new()
	controls_hbox.position = Vector2(50, 460)
	controls_hbox.size = Vector2(700, 45)
	controls_hbox.add_theme_constant_override("separation", 20)
	add_child(controls_hbox)

	draw_button = Button.new()
	draw_button.name = "DrawButton"
	draw_button.custom_minimum_size = Vector2(160, 42)
	draw_button.text = "🎴 Robar Carta (44)"
	draw_button.add_theme_font_size_override("font_size", 15)
	draw_button.pressed.connect(_on_draw_pressed)
	controls_hbox.add_child(draw_button)

	discard_mode = CheckBox.new()
	discard_mode.name = "DiscardModeCheckbox"
	discard_mode.text = "Modo Descarte 🗑️"
	discard_mode.add_theme_font_size_override("font_size", 14)
	controls_hbox.add_child(discard_mode)

	coup_fourre_btn = Button.new()
	coup_fourre_btn.name = "CoupFourreButton"
	coup_fourre_btn.custom_minimum_size = Vector2(170, 42)
	coup_fourre_btn.text = "⚡ ¡Coup Fourré!"
	coup_fourre_btn.tooltip_text = "Declarar Coup Fourré reactivo con un Escudo (Safety) ante un peligro (+300 pts)"
	coup_fourre_btn.add_theme_font_size_override("font_size", 14)
	coup_fourre_btn.pressed.connect(_on_coup_fourre_pressed)
	controls_hbox.add_child(coup_fourre_btn)

	# Hand Container & Panel (Bottom)
	hand_panel = Panel.new()
	hand_panel.name = "HandPanel"
	hand_panel.position = Vector2(50, 520)
	hand_panel.size = Vector2(700, 140)
	add_child(hand_panel)

	hand_container = HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.position = Vector2(12, 10)
	hand_container.size = Vector2(676, 120)
	hand_container.add_theme_constant_override("separation", 10)
	hand_panel.add_child(hand_container)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(100, 80)
	add_child(rules_popup)

	_apply_theme_styling()

func _on_viewport_size_changed() -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	_on_layout_changed(gm.get_layout() if gm != null else 0)

func _on_layout_changed(layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	top_bar.position = Vector2(50, 20)
	top_bar.size = Vector2(700, 45)
	turn_indicator.position = Vector2(50, 75)
	local_tableau.position = Vector2(50, 130)
	local_tableau.size = Vector2(400, 310)
	opponent_tableau.position = Vector2(480, 130)
	opponent_tableau.size = Vector2(270, 310)
	hand_panel.position = Vector2(50, 520)
	hand_panel.size = Vector2(700, 140)
	hand_container.size = Vector2(676, 120)

	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz: Vector2 = get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)

	var design_w: float = 800.0
	var design_h: float = 680.0
	if layout == 2 or vp_size.x < design_w or vp_size.y < design_h:
		var s: float = clampf(minf(vp_size.x / design_w, vp_size.y / design_h), 0.35, 1.0)
		scale = Vector2(s, s)
		position = Vector2(maxf(0.0, (vp_size.x - design_w * s) * 0.5), maxf(0.0, (vp_size.y - design_h * s) * 0.5))
	else:
		scale = Vector2.ONE
		position = Vector2.ZERO

# -------------------------------------------------------------------------
# CARD PARSING & VISUAL RENDERING (a)
# -------------------------------------------------------------------------
func _get_card_info(raw_card_name: String) -> Dictionary:
	var name_lower = raw_card_name.to_lower()
	var category = "DEFAULT"
	var icon = "🎴"
	var title = raw_card_name
	var subtitle = ""

	if "distance" in name_lower or "distancia" in name_lower or "25" in name_lower or "50" in name_lower or "75" in name_lower or "100" in name_lower or "200" in name_lower:
		category = "DISTANCE"
		icon = "🚗"
		var num_str = ""
		for part in raw_card_name.split(" "):
			if part.is_valid_int():
				num_str = part
				break
		if num_str == "":
			num_str = "50"
		title = "%s km" % num_str
		subtitle = "Distancia"

	elif "luz verde" in name_lower or "roll" in name_lower or "siga" in name_lower:
		category = "REMEDY"
		icon = "🟢"
		title = "Luz Verde"
		subtitle = "¡En Marcha!"

	elif "gasolina" in name_lower or "gas" in name_lower:
		category = "REMEDY"
		icon = "⛽"
		title = "Gasolina"
		subtitle = "Carga de Gas"

	elif "reparaciones" in name_lower or "reparación" in name_lower or "repairs" in name_lower:
		category = "REMEDY"
		icon = "🛠️"
		title = "Reparación"
		subtitle = "Taller Mecánico"

	elif "rueda de repuesto" in name_lower or "repuesto" in name_lower or "spare" in name_lower:
		category = "REMEDY"
		icon = "🛞"
		title = "Repuesto"
		subtitle = "Neumático OK"

	elif "fin de límite" in name_lower or "fin limite" in name_lower or "end of limit" in name_lower:
		category = "REMEDY"
		icon = "🏁"
		title = "Fin Límite"
		subtitle = "Sin Restricción"

	elif "semáforo rojo" in name_lower or "luz roja" in name_lower or "stop" in name_lower:
		category = "HAZARD"
		icon = "🔴"
		title = "Luz Roja"
		subtitle = "¡Detenido!"

	elif "accidente" in name_lower or "accident" in name_lower:
		category = "HAZARD"
		icon = "💥"
		title = "Accidente"
		subtitle = "Choque frontal"

	elif "sin gasolina" in name_lower or "out of gas" in name_lower:
		category = "HAZARD"
		icon = "⛽❌"
		title = "Sin Gasolina"
		subtitle = "Tanque Vacío"

	elif "pinchazo" in name_lower or "flat tire" in name_lower or "pinchadura" in name_lower:
		category = "HAZARD"
		icon = "🛞💥"
		title = "Pinchazo"
		subtitle = "Rueda Desinflada"

	elif "límite de velocidad" in name_lower or "speed limit" in name_lower or "limite de velocidad" in name_lower:
		category = "HAZARD"
		icon = "⚠️50"
		title = "Límite 50"
		subtitle = "Máx 50 km/h"

	elif "prioridad" in name_lower or "right of way" in name_lower or "priorité" in name_lower:
		category = "SAFETY"
		icon = "🌟"
		title = "Prioridad"
		subtitle = "Inmune a Luz Roja"

	elif "cisterna" in name_lower or "extra tank" in name_lower:
		category = "SAFETY"
		icon = "🚛"
		title = "Cisterna"
		subtitle = "Combustible Infinito"

	elif "blindaje" in name_lower or "driving ace" in name_lower or "as del volante" in name_lower:
		category = "SAFETY"
		icon = "🛡️"
		title = "As Volante"
		subtitle = "Inmune a Choques"

	elif "a prueba de pinchazos" in name_lower or "puncture proof" in name_lower or "impenetrable" in name_lower:
		category = "SAFETY"
		icon = "🛞⭐"
		title = "Impenetrable"
		subtitle = "Ruedas Blindadas"

	var cat_style = CARD_CATEGORIES.get(category, CARD_CATEGORIES["DEFAULT"])
	return {
		"raw": raw_card_name,
		"title": title,
		"subtitle": subtitle,
		"icon": icon,
		"category": category,
		"style": cat_style
	}

func _get_accessible_category_color(category: String, fallback: Color) -> Color:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = get_node("/root/ThemeManager")
		if tm.has_method("is_colorblind_mode") and bool(tm.call("is_colorblind_mode")):
			if tm.has_method("get_accessible_color"):
				return tm.call("get_accessible_color", category, fallback)
	return fallback

func _get_category_symbol(category: String) -> String:
	match category:
		"HAZARD": return "▲"   # Rojo
		"DISTANCE": return "●" # Azul
		"REMEDY": return "■"   # Verde
		"SAFETY": return "◆"   # Amarillo
		_: return "★"

func _create_card_button(card_info: Dictionary, idx: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(95, 115)
	panel.size = Vector2(95, 115)
	panel.pivot_offset = Vector2(47, 57)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style_info = card_info["style"]
	var category_key: String = String(card_info.get("category", "DEFAULT"))
	var sb = StyleBoxFlat.new()
	sb.bg_color = _get_accessible_category_color(category_key, style_info["color"])
	sb.border_color = style_info["border"]
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var icon_lbl = Label.new()
	var geom_sym = _get_category_symbol(category_key)
	icon_lbl.text = "%s %s" % [geom_sym, card_info["icon"]]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 19)
	vbox.add_child(icon_lbl)

	var title_lbl = Label.new()
	title_lbl.text = card_info["title"]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_lbl)

	if card_info["subtitle"] != "":
		var sub_lbl = Label.new()
		sub_lbl.text = card_info["subtitle"]
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 9)
		sub_lbl.add_theme_color_override("font_color", style_info["text_color"])
		vbox.add_child(sub_lbl)

	# Hover micro-animation (+12px elevation & scale)
	panel.mouse_entered.connect(func():
		var tw = panel.create_tween().set_parallel(true)
		tw.tween_property(panel, "position:y", -12.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.12)
		panel.z_index = 5
	)
	panel.mouse_exited.connect(func():
		var tw = panel.create_tween().set_parallel(true)
		tw.tween_property(panel, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.12)
		panel.z_index = 0
	)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_clicked_with_animation(idx, panel)
	)

	return panel

func _update_hand_ui() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for i in range(hand_p1.size()):
		var card_name = hand_p1[i]
		var info = _get_card_info(card_name)
		var card_widget = _create_card_button(info, i)
		hand_container.add_child(card_widget)

# -------------------------------------------------------------------------
# CARD PLAY ANIMATION (b) & EXECUTION
# -------------------------------------------------------------------------
func _on_card_clicked_with_animation(idx: int, card_panel: Control) -> void:
	if winner != -1 or (is_vs_ai and current != local_player):
		return

	# Animación de salida: desplazar hacia el tablero superior y desvanecer
	var target_tableau = opponent_tableau if (idx < hand_p1.size() and "hazard" in hand_p1[idx].to_lower()) else local_tableau
	var target_pos = target_tableau.global_position + Vector2(60, 60)
	var start_pos = card_panel.global_position

	# Create flying visual clone
	var flying_card = card_panel.duplicate()
	add_child(flying_card)
	flying_card.global_position = start_pos
	flying_card.z_index = 20

	var tw = flying_card.create_tween().set_parallel(true)
	tw.tween_property(flying_card, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(flying_card, "scale", Vector2(0.6, 0.6), 0.35)
	tw.tween_property(flying_card, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(flying_card.queue_free)

	_on_card_pressed(idx)

func _on_card_pressed(idx: int) -> void:
	_sfx_card_flip()
	if winner != -1 or (is_vs_ai and current != local_player):
		return

	var acting_p: int = int(current)
	if discard_mode.button_pressed:
		if idx < hand_p1.size():
			discard_pile.append(hand_p1[idx])
		var cmd = {
			"command_type": "DiscardCardCommand",
			"player": acting_p,
			"card_index": idx
		}
		bridge.send_command_json(acting_p, JSON.stringify(cmd))
	else:
		var cmd = {
			"command_type": "PlayCardCommand",
			"player": acting_p,
			"card_index": idx
		}
		bridge.send_command_json(acting_p, JSON.stringify(cmd))

	_sync_hand_from_bridge()
	_update_hand_ui()
	_update_tableaus()

func _on_draw_pressed() -> void:
	_sfx_card_flip()
	if winner != -1:
		return
	var cmd = {"command_type": "DrawCardCommand", "player": current}
	bridge.send_command_json(current, JSON.stringify(cmd))
	if deck_count > 0:
		deck_count -= 1
	draw_button.text = "🎴 Robar Carta (%d)" % deck_count

func _normalize_shield_key(raw_name: String) -> String:
	var low: String = raw_name.to_lower()
	if "right" in low or "prioridad" in low or "paso" in low or "prioritario" in low:
		return "RightOfWay"
	if "tank" in low or "cisterna" in low:
		return "ExtraTank"
	if "puncture" in low or "impinchable" in low or "sellador" in low:
		return "PunctureProof"
	if "ace" in low or "volante" in low:
		return "DrivingAce"
	return ""

func _get_required_shield_for_hazard(hazard_str: String, has_speed_lim: bool = false) -> String:
	var low: String = hazard_str.to_lower()
	if not ("luz verde" in low or "siga" in low or low.is_empty()):
		if "gas" in low or "combustible" in low:
			return "ExtraTank"
		if "tire" in low or "pinchazo" in low or "llanta" in low or "neumático" in low or "neumatico" in low:
			return "PunctureProof"
		if "accident" in low or "accidente" in low or "choque" in low:
			return "DrivingAce"
		if "stop" in low or "roja" in low or "pare" in low or "límite" in low or "limite" in low or "speed" in low:
			return "RightOfWay"
	if has_speed_lim:
		return "RightOfWay"
	return ""

func _find_matching_coup_fourre_card_index(p_id: int = P1) -> int:
	var h_str: String = str(hazards.get(p_id, ""))
	var spd: bool = bool(speed_limit.get(p_id, false))
	var req_shield: String = _get_required_shield_for_hazard(h_str, spd)
	if req_shield == "":
		return -1
	for i in range(hand_p1.size()):
		var c_name: String = str(hand_p1[i])
		if _normalize_shield_key(c_name) == req_shield:
			return i
	return -1

func is_coup_fourre_playable(p_id: int = P1) -> bool:
	return _find_matching_coup_fourre_card_index(p_id) >= 0

func get_shield_state(p_id: int, shield_key: String) -> String:
	var norm_key = _normalize_shield_key(shield_key)
	if norm_key == "":
		norm_key = shield_key
	var p_map: Dictionary = shield_states.get(p_id, {})
	var recorded: String = str(p_map.get(norm_key, SHIELD_INACTIVE))
	if recorded == SHIELD_COUP_FOURRE:
		return SHIELD_COUP_FOURRE
	var cf_list: Array = coup_fourre_safeties.get(p_id, [])
	for item in cf_list:
		if _normalize_shield_key(str(item)) == norm_key:
			return SHIELD_COUP_FOURRE
	if recorded == SHIELD_ACTIVE:
		return SHIELD_ACTIVE
	var act_list: Array = safeties.get(p_id, [])
	for item in act_list:
		if _normalize_shield_key(str(item)) == norm_key:
			return SHIELD_ACTIVE
	return SHIELD_INACTIVE

func set_shield_state(p_id: int, shield_key: String, state: String) -> void:
	var norm_key = _normalize_shield_key(shield_key)
	if norm_key == "":
		norm_key = shield_key
	if not shield_states.has(p_id):
		shield_states[p_id] = {}
	shield_states[p_id][norm_key] = state
	var act_list: Array = safeties.get(p_id, [])
	var cf_list: Array = coup_fourre_safeties.get(p_id, [])
	if state == SHIELD_INACTIVE:
		act_list.erase(norm_key)
		cf_list.erase(norm_key)
	elif state == SHIELD_ACTIVE:
		if not (norm_key in act_list):
			act_list.append(norm_key)
		cf_list.erase(norm_key)
	elif state == SHIELD_COUP_FOURRE:
		if not (norm_key in act_list):
			act_list.append(norm_key)
		if not (norm_key in cf_list):
			cf_list.append(norm_key)
	_update_tableaus()

func _on_coup_fourre_pressed() -> void:
	_sfx_card_flip()
	if winner != -1 or bridge == null:
		return
	var acting_p: int = local_player if is_vs_ai else current
	var auto_idx: int = _find_matching_coup_fourre_card_index(acting_p)
	var card_idx: int = auto_idx if auto_idx >= 0 else maxi(0, selected_card_idx)
	if card_idx >= 0 and card_idx < hand_p1.size():
		var played_card_name: String = str(hand_p1[card_idx])
		var norm_s: String = _normalize_shield_key(played_card_name)
		if norm_s != "":
			if not shield_states.has(acting_p):
				shield_states[acting_p] = {}
			shield_states[acting_p][norm_s] = SHIELD_COUP_FOURRE
			if not (norm_s in safeties[acting_p]):
				safeties[acting_p].append(norm_s)
			if not (norm_s in coup_fourre_safeties[acting_p]):
				coup_fourre_safeties[acting_p].append(norm_s)
			hazards[acting_p] = "Luz Verde (Siga)"
			if norm_s == "RightOfWay":
				speed_limit[acting_p] = false
	var cmd: Dictionary = {
		"command_type": "CoupFourreCommand",
		"player": acting_p,
		"card_index": card_idx
	}
	bridge.send_command_json(acting_p, JSON.stringify(cmd))
	_sync_hand_from_bridge()
	_update_hand_ui()
	_update_tableaus()

func _refresh_coup_fourre_button_style() -> void:
	if coup_fourre_btn == null:
		return
	var check_p: int = local_player if is_vs_ai else P1
	var match_idx: int = _find_matching_coup_fourre_card_index(check_p)
	var playable: bool = (match_idx >= 0)
	coup_fourre_btn.disabled = not playable
	var cf_style: StyleBoxFlat = StyleBoxFlat.new()
	cf_style.set_corner_radius_all(8)
	cf_style.content_margin_left = 10
	cf_style.content_margin_right = 10
	cf_style.content_margin_top = 6
	cf_style.content_margin_bottom = 6
	if playable:
		var matched_card: String = str(hand_p1[match_idx])
		coup_fourre_btn.text = "⚡ ¡Coup Fourré! (%s)" % matched_card
		cf_style.bg_color = Color(0.55, 0.35, 0.05, 0.98)
		cf_style.border_color = Color(1.0, 0.85, 0.25, 1.0)
		cf_style.set_border_width_all(2)
		coup_fourre_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	else:
		coup_fourre_btn.text = "⚡ ¡Coup Fourré!"
		cf_style.bg_color = Color(0.16, 0.18, 0.22, 0.75)
		cf_style.border_color = Color(0.38, 0.40, 0.46, 0.65)
		cf_style.set_border_width_all(1)
		coup_fourre_btn.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	coup_fourre_btn.add_theme_stylebox_override("normal", cf_style)
	coup_fourre_btn.add_theme_stylebox_override("disabled", cf_style)

func _create_safety_shields_hbox(p_id: int) -> HBoxContainer:
	var shields_hb: HBoxContainer = HBoxContainer.new()
	shields_hb.name = "SafetyShieldsP%d" % p_id
	shields_hb.add_theme_constant_override("separation", 6)
	var shield_defs: Array = [
		{"id": "RightOfWay", "label": "🚦 Prioridad"},
		{"id": "ExtraTank", "label": "⛽ Cisterna"},
		{"id": "PunctureProof", "label": "🛞 Impinchable"},
		{"id": "DrivingAce", "label": "🏆 As Volante"}
	]
	for s_def in shield_defs:
		var sd: Dictionary = s_def
		var s_id: String = str(sd.get("id", "RightOfWay"))
		var base_label: String = str(sd.get("label", "Escudo"))
		var st: String = get_shield_state(p_id, s_id)
		var pill: PanelContainer = PanelContainer.new()
		pill.name = "ShieldBadge_%s" % s_id
		pill.set_meta("shield_id", s_id)
		pill.set_meta("shield_state", st)
		var p_style: StyleBoxFlat = StyleBoxFlat.new()
		p_style.set_corner_radius_all(5)
		p_style.content_margin_left = 6
		p_style.content_margin_right = 6
		p_style.content_margin_top = 2
		p_style.content_margin_bottom = 2
		var badge: Label = Label.new()
		badge.name = "BadgeLabel"
		badge.add_theme_font_size_override("font_size", 11)
		if st == SHIELD_COUP_FOURRE:
			p_style.bg_color = Color(0.56, 0.40, 0.04, 0.98)
			p_style.border_color = Color(1.0, 0.88, 0.22, 1.0)
			p_style.set_border_width_all(2)
			badge.text = "%s ⚡ CF +300" % base_label
			badge.add_theme_color_override("font_color", Color(1.0, 0.96, 0.55))
		elif st == SHIELD_ACTIVE:
			p_style.bg_color = Color(0.42, 0.32, 0.06, 0.95)
			p_style.border_color = Color(0.98, 0.84, 0.25, 0.98)
			p_style.set_border_width_all(1)
			badge.text = "%s ✨" % base_label
			badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.40))
		else:
			p_style.bg_color = Color(0.14, 0.16, 0.20, 0.65)
			p_style.border_color = Color(0.35, 0.38, 0.44, 0.55)
			p_style.set_border_width_all(1)
			badge.text = base_label
			badge.add_theme_color_override("font_color", Color(0.58, 0.60, 0.65, 0.75))
		pill.add_theme_stylebox_override("panel", p_style)
		pill.add_child(badge)
		shields_hb.add_child(pill)
	return shields_hb

# -------------------------------------------------------------------------
# TABLEAUS & HAZARD INDICATORS (c, d)
# -------------------------------------------------------------------------
func _is_player_stopped(p_id: int) -> bool:
	var h_str = hazards.get(p_id, "").to_lower()
	if "luz verde" in h_str or "siga" in h_str:
		return false
	return true

func _update_tableaus() -> void:
	for child in local_tableau.get_children(): child.queue_free()
	for child in opponent_tableau.get_children(): child.queue_free()

	# Sync distance from bridge if method is available
	if bridge != null and bridge.has_method("get_distance"):
		var d1 = bridge.call("get_distance", P1)
		var d2 = bridge.call("get_distance", P2)
		if d1 > 0: distance[P1] = d1
		if d2 > 0: distance[P2] = d2

	# ----------------- LOCAL TABLEAU (P1) -----------------
	var p1_vbox = VBoxContainer.new()
	p1_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	p1_vbox.offset_left = 12
	p1_vbox.offset_top = 10
	p1_vbox.offset_right = -12
	p1_vbox.offset_bottom = -10
	p1_vbox.add_theme_constant_override("separation", 8)
	local_tableau.add_child(p1_vbox)

	var p1_header = HBoxContainer.new()
	p1_vbox.add_child(p1_header)

	var lbl_title = Label.new()
	lbl_title.text = "🚗 Mi Vehículo (Jugador 1)"
	lbl_title.add_theme_font_size_override("font_size", 17)
	lbl_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1_header.add_child(lbl_title)

	# HAZARD STOPPED INDICATOR BANNER (c)
	p1_hazard_banner = PanelContainer.new()
	var p1_is_stopped = _is_player_stopped(P1)
	var p1_banner_style = StyleBoxFlat.new()
	p1_banner_style.set_corner_radius_all(6)
	p1_banner_style.content_margin_left = 8
	p1_banner_style.content_margin_right = 8
	p1_banner_style.content_margin_top = 3
	p1_banner_style.content_margin_bottom = 3

	p1_hazard_label = Label.new()
	p1_hazard_label.add_theme_font_size_override("font_size", 12)

	if p1_is_stopped:
		p1_banner_style.bg_color = Color(0.85, 0.2, 0.2, 0.95)
		p1_hazard_label.text = "⛔ DETENIDO: %s" % hazards[P1]
		p1_hazard_label.add_theme_color_override("font_color", Color.WHITE)
		# Pulse flash tween
		var tw = p1_hazard_banner.create_tween().set_loops()
		tw.tween_property(p1_hazard_banner, "modulate:a", 0.6, 0.5)
		tw.tween_property(p1_hazard_banner, "modulate:a", 1.0, 0.5)
	else:
		p1_banner_style.bg_color = Color(0.15, 0.65, 0.25, 0.9)
		p1_hazard_label.text = "🟢 EN MARCHA: %s" % hazards[P1]
		p1_hazard_label.add_theme_color_override("font_color", Color.WHITE)

	p1_hazard_banner.add_theme_stylebox_override("panel", p1_banner_style)
	p1_hazard_banner.add_child(p1_hazard_label)
	p1_vbox.add_child(p1_hazard_banner)

	p1_dist_label = Label.new()
	p1_dist_label.text = "Distancia Recorrida: %d / 1000 km" % distance[P1]
	p1_dist_label.add_theme_font_size_override("font_size", 14)
	p1_vbox.add_child(p1_dist_label)

	p1_prog_bar = ProgressBar.new()
	p1_prog_bar.custom_minimum_size = Vector2(0, 22)
	p1_prog_bar.max_value = 1000
	p1_prog_bar.value = distance[P1]
	p1_vbox.add_child(p1_prog_bar)

	p1_safeties_label = Label.new()
	p1_safeties_label.text = "🛡️ Protecciones Activas: %s" % (", ".join(safeties[P1]) if safeties[P1].size() > 0 else "Ninguna")
	p1_safeties_label.add_theme_font_size_override("font_size", 12)
	p1_safeties_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	p1_vbox.add_child(p1_safeties_label)
	p1_vbox.add_child(_create_safety_shields_hbox(P1))
	_refresh_coup_fourre_button_style()

	# ----------------- OPPONENT TABLEAU (P2) -----------------
	var p2_vbox = VBoxContainer.new()
	p2_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	p2_vbox.offset_left = 10
	p2_vbox.offset_top = 10
	p2_vbox.offset_right = -10
	p2_vbox.offset_bottom = -10
	p2_vbox.add_theme_constant_override("separation", 8)
	opponent_tableau.add_child(p2_vbox)

	var p2_header = HBoxContainer.new()
	p2_vbox.add_child(p2_header)

	var opp_title = Label.new()
	opp_title.text = "🏎️ Rival (Jugador 2)"
	opp_title.add_theme_font_size_override("font_size", 16)
	opp_title.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
	opp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p2_header.add_child(opp_title)

	# OPPONENT HAZARD BANNER (c)
	p2_hazard_banner = PanelContainer.new()
	var p2_is_stopped = _is_player_stopped(P2)
	var p2_banner_style = StyleBoxFlat.new()
	p2_banner_style.set_corner_radius_all(6)
	p2_banner_style.content_margin_left = 8
	p2_banner_style.content_margin_right = 8
	p2_banner_style.content_margin_top = 3
	p2_banner_style.content_margin_bottom = 3

	p2_hazard_label = Label.new()
	p2_hazard_label.add_theme_font_size_override("font_size", 12)

	if p2_is_stopped:
		p2_banner_style.bg_color = Color(0.85, 0.2, 0.2, 0.95)
		p2_hazard_label.text = "⛔ DETENIDO: %s" % hazards[P2]
		p2_hazard_label.add_theme_color_override("font_color", Color.WHITE)
		var tw = p2_hazard_banner.create_tween().set_loops()
		tw.tween_property(p2_hazard_banner, "modulate:a", 0.6, 0.5)
		tw.tween_property(p2_hazard_banner, "modulate:a", 1.0, 0.5)
	else:
		p2_banner_style.bg_color = Color(0.15, 0.65, 0.25, 0.9)
		p2_hazard_label.text = "🟢 EN MARCHA: %s" % hazards[P2]
		p2_hazard_label.add_theme_color_override("font_color", Color.WHITE)

	p2_hazard_banner.add_theme_stylebox_override("panel", p2_banner_style)
	p2_hazard_banner.add_child(p2_hazard_label)
	p2_vbox.add_child(p2_hazard_banner)

	p2_dist_label = Label.new()
	p2_dist_label.text = "Distancia: %d / 1000 km" % distance[P2]
	p2_dist_label.add_theme_font_size_override("font_size", 13)
	p2_vbox.add_child(p2_dist_label)

	p2_prog_bar = ProgressBar.new()
	p2_prog_bar.custom_minimum_size = Vector2(0, 18)
	p2_prog_bar.max_value = 1000
	p2_prog_bar.value = distance[P2]
	p2_vbox.add_child(p2_prog_bar)

	p2_safeties_label = Label.new()
	p2_safeties_label.text = "🛡️ Safeties: %s" % (", ".join(safeties[P2]) if safeties[P2].size() > 0 else "Ninguna")
	p2_safeties_label.add_theme_font_size_override("font_size", 12)
	p2_vbox.add_child(p2_safeties_label)
	p2_vbox.add_child(_create_safety_shields_hbox(P2))

# -------------------------------------------------------------------------
# EVENT JSON & TURN MANAGEMENT
# -------------------------------------------------------------------------
func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type = str(event.get("command_type", event.get("event_type", "")))
			var event_type = raw_type.split("::")[-1]
			if event_type == "CardDrawnEvent":
				var card = event.get("card", "Carta")
				if event.get("player", current) == P1:
					hand_p1.append(str(card))
					_update_hand_ui()
			elif event_type == "DistancePlayedEvent":
				var p = int(event.get("player", current))
				var new_d = int(event.get("new_distance", 0))
				distance[p] = new_d
				_update_tableaus()
			elif event_type == "HazardPlayedEvent":
				var target = int(event.get("target", P2))
				var hz = str(event.get("hazard", "Peligro"))
				hazards[target] = hz
				_update_tableaus()
			elif event_type == "RemedyPlayedEvent":
				var p = int(event.get("player", current))
				hazards[p] = "Luz Verde (Siga)"
				_update_tableaus()
			elif event_type == "SafetyPlayedEvent":
				var p = int(event.get("player", current))
				var sf = str(event.get("safety", "Protección"))
				var is_cf: bool = bool(event.get("coup_fourre", false))
				var norm_sf: String = _normalize_shield_key(sf)
				safeties[p].append(sf)
				if norm_sf != "":
					if not shield_states.has(p):
						shield_states[p] = {}
					shield_states[p][norm_sf] = SHIELD_COUP_FOURRE if is_cf else SHIELD_ACTIVE
				if is_cf:
					coup_fourre_safeties[p].append(sf)
					hazards[p] = "Luz Verde (Siga)"
				_update_tableaus()
			elif event_type == "CoupFourreEvent":
				var p = int(event.get("player", current))
				var sf = str(event.get("safety", "Protección"))
				var norm_sf: String = _normalize_shield_key(sf)
				if not (sf in safeties[p]):
					safeties[p].append(sf)
				if not (sf in coup_fourre_safeties[p]):
					coup_fourre_safeties[p].append(sf)
				if norm_sf != "":
					if not shield_states.has(p):
						shield_states[p] = {}
					shield_states[p][norm_sf] = SHIELD_COUP_FOURRE
				hazards[p] = "Luz Verde (Siga)"
				_update_tableaus()
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))

	current = bridge.current_player()
	_sync_hand_from_bridge()
	_update_hand_ui()
	_update_tableaus()
	_update_status()

func _on_turn_changed(player_id: int) -> void:
	current = player_id
	if winner == -1 and bridge != null and (not is_vs_ai or current == local_player):
		_sync_hand_from_bridge()
		if hand_p1.size() < 6 and deck_count > 0:
			bridge.send_command_json(current, JSON.stringify({"command_type": "DrawCardCommand", "player": current}))
			_sync_hand_from_bridge()
	_update_hand_ui()
	_update_tableaus()
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
		status.text = "Movimiento inválido: %s" % reason

func _update_status() -> void:
	if status == null:
		return
	if winner != -1:
		status.text = "¡Alcanzó 1000 Millas! Ganó el jugador %s (Mille Bornes)" % winner
	else:
		status.text = "Turno: Jugador %s (Mil Millas / Mille Bornes)" % current

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
