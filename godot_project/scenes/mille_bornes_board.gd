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
var current = P1
var winner = -1

# Player state
var distance = {P1: 0, P2: 0}
var hazards = {P1: "Luz Verde (Siga)", P2: "Luz Verde (Siga)"}
var safeties = {P1: [], P2: []}
var hand_p1 = ["Distance 25", "Distance 50", "Distance 75", "Distance 100", "Luz Verde", "Gasolina"]
var speed_limit = {P1: false, P2: false}
var deck_count: int = 44
var discard_pile: Array = []

# UI Nodes
var main_vbox: VBoxContainer
var top_bar: HBoxContainer
var hand_panel: Panel
var hand_container: HBoxContainer
var local_tableau: Panel
var opponent_tableau: Panel
var draw_button: Button
var discard_mode: CheckBox
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

@onready var status: Label = $Status if has_node("Status") else null

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)
	else:
		_create_default_theme()

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
	if bridge.has_signal("turn_changed"):
		bridge.connect("turn_changed", _on_turn_changed)

	bridge.start_local_match_mille_bornes(P1, P2)
	bridge.send_command_json(P1, JSON.stringify({"command_type": "SetupDeckCommand"}))
	current = bridge.current_player()

	_on_layout_changed(GameManager.get_layout() if gm != null else 0)
	_update_hand_ui()
	_update_tableaus()
	_update_status()

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_quit_to_menu() -> void:
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")

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
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(90, 36)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("mille_bornes"))
	top_bar.add_child(btn_rules)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(50, 75)
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

func _on_layout_changed(layout: int) -> void:
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	if layout == 2: # PHONE
		top_bar.position = Vector2(10, 10)
		top_bar.size = Vector2(355, 40)
		turn_indicator.position = Vector2(10, 55)
		local_tableau.position = Vector2(10, 100)
		local_tableau.size = Vector2(355, 200)
		opponent_tableau.position = Vector2(10, 310)
		opponent_tableau.size = Vector2(355, 130)
		draw_button.position = Vector2(10, 450)
		hand_panel.position = Vector2(10, 500)
		hand_panel.size = Vector2(355, 140)
		hand_container.size = Vector2(340, 120)
	else: # DESKTOP or TABLET
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

func _create_card_button(card_info: Dictionary, idx: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(95, 115)
	panel.size = Vector2(95, 115)
	panel.pivot_offset = Vector2(47, 57)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style_info = card_info["style"]
	var sb = StyleBoxFlat.new()
	sb.bg_color = style_info["color"]
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
	icon_lbl.text = card_info["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 22)
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
	if winner != -1 or current != P1:
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
	if winner != -1 or current != P1:
		return

	if discard_mode.button_pressed:
		var cmd = {
			"command_type": "DiscardCardCommand",
			"player": P1,
			"card_index": idx
		}
		bridge.send_command_json(P1, JSON.stringify(cmd))
		if idx < hand_p1.size():
			discard_pile.append(hand_p1[idx])
			hand_p1.remove_at(idx)
		_update_hand_ui()
		_update_tableaus()
	else:
		var cmd = {
			"command_type": "PlayCardCommand",
			"player": P1,
			"card_index": idx
		}
		bridge.send_command_json(P1, JSON.stringify(cmd))
		if idx < hand_p1.size():
			var card = hand_p1[idx]
			if "Distance" in card or "distancia" in card.to_lower() or card.to_lower().begins_with("25") or card.to_lower().begins_with("50") or card.to_lower().begins_with("75") or card.to_lower().begins_with("100") or card.to_lower().begins_with("200"):
				var dist_val = 0
				for part in card.split(" "):
					if part.is_valid_int():
						dist_val = int(part)
						break
				if dist_val > 0:
					distance[P1] += dist_val
			hand_p1.remove_at(idx)
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

# -------------------------------------------------------------------------
# EVENT JSON & TURN MANAGEMENT
# -------------------------------------------------------------------------
func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
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
				safeties[p].append(sf)
				_update_tableaus()
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))

	current = bridge.current_player()
	_update_status()

func _on_turn_changed(player_id: int) -> void:
	current = player_id
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
