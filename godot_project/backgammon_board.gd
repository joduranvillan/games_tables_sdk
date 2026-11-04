extends Node2D

const P1 = 1 # Increasing (Red / White)
const P2 = 2 # Decreasing (Dark Blue / Black)
const TOTAL_POINTS = 24

# Colors
const COL_BOARD = Color(0.32, 0.20, 0.12)
const COL_BOARD_INNER = Color(0.82, 0.72, 0.58)
const COL_POINT_A = Color(0.80, 0.25, 0.20) # Red triangular point
const COL_POINT_B = Color(0.95, 0.92, 0.85) # White/cream triangular point
const COL_BAR = Color(0.18, 0.12, 0.08)
const COL_BEARING = Color(0.22, 0.14, 0.07)

const PLAYER_COLORS = {
	1: Color(0.90, 0.25, 0.20), # Red
	2: Color(0.20, 0.25, 0.35)  # Dark Blue
}

var bridge
var current = P1
var winner = -1
var rolled_dice: Array = []
var selected_from = -2 # -2: none, -1: bar, 0..23: point index

# Board state: points array [24] with count (+ for P1, - for P2)
var points = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
var bar_checkers = {1: 0, 2: 0}
var borne_off_checkers = {1: 0, 2: 0}

# Checker node elements: point_idx / bar / bearing -> Array of Control/TextureButton
var checker_nodes = []

# UI Controls
var roll_btn: Button
var double_btn: Button
var cube_label: Label
var double_modal: PanelContainer
var dice_label: Label
var dice_widget: DiceWidget
var rules_popup: RulesPopup
var mode_option_button: OptionButton
var cube_value: int = 1
var cube_owner: int = 0
var cube_offered: bool = false

var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
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

	_init_board_state()
	_setup_ui()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
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

	if gm != null and gm.get_game_mode() == "vs_ai":
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else P1
		var ai_p: int = P2 if human_p == P1 else P1
		bridge.start_local_match_backgammon_vs_ai(human_p, ai_p)
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_p == P1 else 2
	else:
		bridge.start_local_match_backgammon(P1, P2)
		if mode_option_button != null:
			mode_option_button.selected = 0
	current = bridge.current_player()
	
	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_checker_positions()
	_update_status()
	queue_redraw()

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_viewport_size_changed() -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	_on_layout_changed(gm.get_layout() if gm != null else 0)

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
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	var vp_size := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz := get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if _layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)
	var min_x := 40.0
	var min_y := -26.0
	var design_w := 720.0
	var design_h := 616.0
	var s := clampf(minf((vp_size.x - 40.0) / design_w, (vp_size.y - 24.0) / design_h), 0.28, 1.0)
	scale = Vector2(s, s)
	position = Vector2(
		(vp_size.x - design_w * s) * 0.5 - min_x * s,
		(vp_size.y - design_h * s) * 0.5 - min_y * s
	)

func _init_board_state() -> void:
	points = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	# Standard Backgammon setup
	points[0] = 2
	points[11] = 5
	points[16] = 3
	points[18] = 5
	
	points[23] = -2
	points[12] = -5
	points[7] = -3
	points[5] = -5
	
	bar_checkers = {1: 0, 2: 0}
	borne_off_checkers = {1: 0, 2: 0}

func _setup_ui() -> void:
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	# Zona Superior Centrada: Turno, Reloj y Estado del Cubo de Doblaje
	status.position = Vector2(310, -14)

	# Mode Option Button (integrado en GameAppMenu / Opciones)
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(220, -18)
	mode_option_button.custom_minimum_size = Vector2(360, 34)
	mode_option_button.visible = false
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano Rojo - J1)")
	mode_option_button.add_item("vs IA (Humano Azul - J2, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	# Zona Inferior Centrada: Acciones del Turno (Tirar Dados y Doblar Apuesta)
	roll_btn = Button.new()
	roll_btn.position = Vector2(390, 532)
	roll_btn.custom_minimum_size = Vector2(135, 44)
	roll_btn.text = "🎲 Tirar Dados"
	roll_btn.add_theme_font_size_override("font_size", 15)
	roll_btn.pressed.connect(_on_roll_pressed)
	add_child(roll_btn)
	
	dice_label = Label.new()
	dice_label.position = Vector2(250, 538)
	dice_label.size = Vector2(130, 36)
	dice_label.text = "Dados: -"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.add_theme_font_size_override("font_size", 16)
	add_child(dice_label)

	dice_widget = DiceWidget.new()
	dice_widget.position = Vector2(135, 530)
	add_child(dice_widget)

	# Doubling Cube Panel (Zona Superior Centrada) & Action Button (Zona Inferior Centrada)
	cube_label = Label.new()
	cube_label.name = "CubeLabel"
	cube_label.position = Vector2(580, -14)
	cube_label.size = Vector2(180, 26)
	cube_label.text = "Cubo: ×1 (Centro)"
	cube_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cube_label.add_theme_font_size_override("font_size", 14)
	cube_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.60))
	add_child(cube_label)

	double_btn = Button.new()
	double_btn.name = "OfferDoubleButton"
	double_btn.position = Vector2(540, 532)
	double_btn.custom_minimum_size = Vector2(155, 44)
	double_btn.text = "🎲×2 Doblar Apuesta"
	double_btn.add_theme_font_size_override("font_size", 13)
	double_btn.pressed.connect(func():
		if winner == -1 and bridge != null:
			bridge.send_command_json(current, JSON.stringify({"command_type": "OfferDoubleCommand", "player": current}))
	)
	add_child(double_btn)

	double_modal = PanelContainer.new()
	double_modal.name = "DoubleOfferModal"
	double_modal.position = Vector2(250, 220)
	double_modal.custom_minimum_size = Vector2(300, 120)
	double_modal.visible = false
	var dm_vbox := VBoxContainer.new()
	dm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var dm_lbl := Label.new()
	dm_lbl.text = "¡El rival ofrece doblar la apuesta!"
	dm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dm_vbox.add_child(dm_lbl)
	var dm_hbox := HBoxContainer.new()
	dm_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_acc := Button.new()
	btn_acc.name = "AcceptDoubleButton"
	btn_acc.text = "✅ Aceptar Doblaje"
	btn_acc.pressed.connect(func():
		double_modal.visible = false
		var resp_p := P2 if current == P1 else P1
		bridge.send_command_json(resp_p, JSON.stringify({"command_type": "AcceptDoubleCommand", "player": resp_p}))
	)
	dm_hbox.add_child(btn_acc)
	var btn_rej := Button.new()
	btn_rej.name = "RejectDoubleButton"
	btn_rej.text = "🏳️ Rechazar"
	btn_rej.pressed.connect(func():
		double_modal.visible = false
		var resp_p := P2 if current == P1 else P1
		bridge.send_command_json(resp_p, JSON.stringify({"command_type": "RejectDoubleCommand", "player": resp_p}))
	)
	dm_hbox.add_child(btn_rej)
	dm_vbox.add_child(dm_hbox)
	double_modal.add_child(dm_vbox)
	add_child(double_modal)

	# Rules Button (integrado en GameAppMenu / Opciones)
	var rules_btn = Button.new()
	rules_btn.name = "RulesButton"
	rules_btn.text = "📖 Reglas"
	rules_btn.position = Vector2(390, 532)
	rules_btn.custom_minimum_size = Vector2(110, 36)
	rules_btn.visible = false
	rules_btn.pressed.connect(func(): rules_popup.show_for_game("backgammon"))
	add_child(rules_btn)

	var tutorial_btn := Button.new()
	tutorial_btn.name = "BackgammonTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(390, 532)
	tutorial_btn.custom_minimum_size = Vector2(110, 36)
	tutorial_btn.visible = false
	tutorial_btn.pressed.connect(start_backgammon_tutorial)
	add_child(tutorial_btn)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 100)
	add_child(rules_popup)

	# Turn Indicator Widget (Zona Superior Centrada)
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(40, -20)
	add_child(turn_indicator)

func start_backgammon_tutorial() -> void:
	var BackgammonTut = load("res://scripts/tutorials/backgammon_tutorial.gd")
	if BackgammonTut != null:
		BackgammonTut.start_on_board(self)

func _get_point_base_pos(pt_idx: int) -> Vector2:
	var col_width = 38.0
	var left_start = 65.0
	var right_start = 350.0
	
	if pt_idx < 6: # Bottom left (0..5)
		return Vector2(left_start + pt_idx * col_width + col_width / 2.0, 500)
	elif pt_idx < 12: # Bottom right (6..11)
		return Vector2(right_start + (pt_idx - 6) * col_width + col_width / 2.0, 500)
	elif pt_idx < 18: # Top right (12..17)
		return Vector2(right_start + (17 - pt_idx) * col_width + col_width / 2.0, 60)
	else: # Top left (18..23)
		return Vector2(left_start + (23 - pt_idx) * col_width + col_width / 2.0, 60)

func _on_mode_selected(index: int) -> void:
	_init_board_state()
	selected_from = -2
	rolled_dice.clear()
	if dice_label != null:
		dice_label.text = "Dados: -"
	winner = -1

	if bridge != null:
		match index:
			1:
				bridge.start_local_match_backgammon_vs_ai(P1, P2)
			2:
				bridge.start_local_match_backgammon_vs_ai(P2, P1)
			_:
				bridge.start_local_match_backgammon(P1, P2)

	current = bridge.current_player() if bridge else P1
	_update_checker_positions()
	_update_status()
	queue_redraw()

func _on_roll_pressed() -> void:
	_sfx_dice_roll()
	if winner != -1:
		return
	var cmd = {"command_type": "RollDiceCommand", "player": current}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _input(event: InputEvent) -> void:
	if winner != -1:
		return
		
	var click_pos = Vector2.ZERO
	var handled = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_pos = get_local_mouse_position() if (is_inside_tree() and not OS.has_feature("headless")) else event.position
		handled = true
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = to_local(event.position) if (is_inside_tree() and not OS.has_feature("headless")) else event.position
		handled = true
		
	if handled:
		# Check click on bar (x: 290..350)
		if click_pos.x >= 290 and click_pos.x <= 350 and click_pos.y >= 40 and click_pos.y <= 520:
			if bar_checkers[current] > 0:
				selected_from = -1
				queue_redraw()
				return
				
		# Check click on Bearing-Off tray (when a checker is selected)
		if selected_from >= 0 and Rect2(610, 40, 150, 200).has_point(click_pos):
			var die_val = rolled_dice.front() if rolled_dice.size() > 0 else 1
			var needed_die = (24 - selected_from) if current == P1 else (selected_from + 1)
			if needed_die in rolled_dice:
				die_val = needed_die
			else:
				for d in rolled_dice:
					if int(d) >= needed_die:
						die_val = int(d)
						break
			var cmd = {
				"command_type": "MoveCheckerCommand",
				"player": current,
				"from": selected_from,
				"die": die_val
			}
			selected_from = -2
			queue_redraw()
			bridge.send_command_json(current, JSON.stringify(cmd))
			return

		# Check click on points 0..23
		for pt in range(TOTAL_POINTS):
			var base_px = _get_point_base_pos(pt)
			var is_top = (pt >= 12)
			var pt_rect: Rect2
			if is_top:
				pt_rect = Rect2(base_px.x - 18, 40, 36, 220)
			else:
				pt_rect = Rect2(base_px.x - 18, 300, 36, 220)
				
			if pt_rect.has_point(click_pos):
				_handle_point_click(pt)
				return

func _handle_point_click(pt: int) -> void:
	if selected_from == -2 and bar_checkers[current] > 0:
		selected_from = -1
	if selected_from == -2:
		var count = points[pt]
		var belongs_to_current = (count > 0 and current == P1) or (count < 0 and current == P2)
		if belongs_to_current and bar_checkers[current] == 0:
			selected_from = pt
			queue_redraw()
	elif selected_from == pt:
		selected_from = -2
		queue_redraw()
	else:
		var from_val = null if selected_from == -1 else selected_from
		var die_val = rolled_dice.front() if rolled_dice.size() > 0 else 1
		
		if from_val != null and rolled_dice.size() > 0:
			var diff = abs(pt - from_val)
			if diff in rolled_dice:
				die_val = diff
		elif from_val == null and rolled_dice.size() > 0:
			var bar_die = (pt + 1) if current == P1 else (24 - pt)
			if bar_die in rolled_dice:
				die_val = bar_die
				
		var cmd = {
			"command_type": "MoveCheckerCommand",
			"player": current,
			"from": from_val,
			"die": die_val
		}
		selected_from = -2
		queue_redraw()
		bridge.send_command_json(current, JSON.stringify(cmd))

func _update_checker_positions() -> void:
	for node in checker_nodes:
		if is_instance_valid(node):
			node.queue_free()
	checker_nodes.clear()
	
	# Draw checkers on 24 points with stack limit of 5
	for pt in range(TOTAL_POINTS):
		var count = points[pt]
		if count == 0:
			continue
		var pt_owner = P1 if count > 0 else P2
		var total_num = abs(count)
		var visible_num = min(total_num, 5)
		var base_pos = _get_point_base_pos(pt)
		var is_top = (pt >= 12)
		
		for k in range(visible_num):
			var is_top_stack = (k == visible_num - 1) and (total_num > 5)
			var badge_text = str(total_num) if is_top_stack else ""
			var btn = _create_checker_button(pt_owner, badge_text)
			var y_off = k * 28.0 if is_top else -k * 28.0
			var pos = base_pos + Vector2(-15, y_off - (0 if is_top else 30))
			btn.position = pos
			add_child(btn)
			checker_nodes.append(btn)
			
	# Draw bar checkers
	for p in [P1, P2]:
		var b_cnt = bar_checkers[p]
		for k in range(min(b_cnt, 5)):
			var is_top_stack = (k == 4) and (b_cnt > 5)
			var badge_text = str(b_cnt) if is_top_stack else ""
			var btn = _create_checker_button(p, badge_text)
			var y_pos = 280 + k * 28 if p == P1 else 240 - k * 28
			btn.position = Vector2(320 - 15, y_pos)
			add_child(btn)
			checker_nodes.append(btn)

func _create_checker_button(owner: int, badge_text: String = "") -> Control:
	var ctrl = Control.new()
	ctrl.size = Vector2(30, 30)
	
	var img = Image.create(30, 30, false, Image.FORMAT_RGBA8)
	var col = PLAYER_COLORS[owner]
	for x in range(30):
		for y in range(30):
			var dist = Vector2(x - 15, y - 15).length()
			if dist <= 12.5:
				var ring = abs(dist - 8.5) < 1.1
				var light = clampf(1.0 - Vector2(x - 11, y - 10).length() / 18.0, 0.65, 1.2)
				var pixel_col = col.lightened(0.28) if ring else Color(col.r * light, col.g * light, col.b * light, 1.0)
				img.set_pixel(x, y, pixel_col)
			elif dist <= 14.2:
				img.set_pixel(x, y, Color(0.92, 0.84, 0.65, 0.95) if owner == P2 else Color(0.25, 0.08, 0.06, 0.95))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	var tex = TextureRect.new()
	tex.texture = ImageTexture.create_from_image(img)
	tex.size = Vector2(30, 30)
	ctrl.add_child(tex)

	if badge_text != "":
		var lbl = Label.new()
		lbl.text = badge_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(30, 30)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color.YELLOW)
		ctrl.add_child(lbl)

	return ctrl

func _animate_arc_movement(owner: int, start_pos: Vector2, end_pos: Vector2) -> void:
	if dice_widget != null and dice_widget.is_rolling and is_inside_tree() and not OS.has_feature("headless"):
		await dice_widget.wait_if_rolling()
	var anim_checker = _create_checker_button(owner)
	anim_checker.position = start_pos
	add_child(anim_checker)
	
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

	var tween = create_tween()
	var duration = 0.35
	var arc_step := func(t: float) -> void:
		if is_instance_valid(anim_checker):
			var linear_pos = start_pos.lerp(end_pos, t)
			var height_arc = sin(t * PI) * 90.0
			anim_checker.position = Vector2(linear_pos.x, linear_pos.y - height_arc)
	tween.tween_method(arc_step, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if is_instance_valid(anim_checker):
			anim_checker.queue_free()
		_update_checker_positions()
	)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type: String = str(event.get("command_type", event.get("event_type", "")))
			var event_type: String = raw_type.split("::")[-1]
			if event_type == "DiceRolledEvent":
				rolled_dice = event.get("values", [])
				dice_label.text = "Dados: %s" % str(rolled_dice)
				if dice_widget != null:
					dice_widget.show_roll(rolled_dice)
			elif event_type == "CheckerMovedEvent":
				var p = int(event.get("player", current))
				var from_p = event.get("from", null)
				var to_p = event.get("to", null)
				
				var start_pos = Vector2(320 - 15, 280) if from_p == null else _get_point_base_pos(int(from_p)) - Vector2(15, 15)
				var end_pos = Vector2(620, 100) if to_p == null else _get_point_base_pos(int(to_p)) - Vector2(15, 15)

				# Update board state
				if from_p == null:
					bar_checkers[p] = max(0, bar_checkers[p] - 1)
				else:
					var f_idx = int(from_p)
					if p == P1: points[f_idx] -= 1
					else: points[f_idx] += 1
					
				if to_p == null:
					borne_off_checkers[p] += 1
				else:
					var t_idx = int(to_p)
					if event.get("captured_opponent", false):
						var opp = P2 if p == P1 else P1
						bar_checkers[opp] += 1
						points[t_idx] = 0
						if (is_inside_tree() and has_node("/root/AudioManager")):
							get_node("/root/AudioManager").play_piece_place(2.0)
					if p == P1: points[t_idx] += 1
					else: points[t_idx] -= 1
					
				if rolled_dice.size() > 0:
					var used_die := -1
					if from_p != null and to_p != null:
						used_die = abs(int(to_p) - int(from_p))
					elif from_p == null and to_p != null:
						used_die = (int(to_p) + 1) if p == P1 else (24 - int(to_p))
					elif from_p != null and to_p == null:
						used_die = (24 - int(from_p)) if p == P1 else (int(from_p) + 1)
					var rm_idx := rolled_dice.find(used_die)
					if rm_idx != -1:
						rolled_dice.remove_at(rm_idx)
					else:
						rolled_dice.pop_front()
				dice_label.text = "Dados: %s" % str(rolled_dice)
				
				_animate_arc_movement(p, start_pos, end_pos)
			elif event_type == "DoubleOfferedEvent":
				cube_offered = true
				var new_stakes: int = int(event.get("new_stakes", cube_value * 2))
				if cube_label != null:
					cube_label.text = "Cubo propuesto: ×%d" % new_stakes
				if double_modal != null:
					double_modal.visible = true
			elif event_type == "DoubleAcceptedEvent":
				cube_offered = false
				cube_value = int(event.get("stakes", cube_value * 2))
				cube_owner = int(event.get("owner", 0))
				if cube_label != null:
					cube_label.text = "Cubo: ×%d (J%d)" % [cube_value, cube_owner]
				if double_modal != null:
					double_modal.visible = false
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
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _draw() -> void:
	var col_board = current_theme.board_color if current_theme != null else COL_BOARD
	var col_inner = current_theme.dark_color.darkened(0.1) if current_theme != null else COL_BOARD_INNER
	var col_bar = current_theme.dark_color.darkened(0.3) if current_theme != null else COL_BAR
	var col_pt_a = current_theme.light_color if current_theme != null else COL_POINT_A
	var col_pt_b = current_theme.dark_color if current_theme != null else COL_POINT_B
	var col_sel = current_theme.select_color if current_theme != null else Color(1.0, 0.9, 0.2, 0.7)

	# Main Outer Board Frame
	var board_rect = Rect2(40, 40, 560, 480)
	draw_rect(board_rect, col_board)
	draw_rect(Rect2(55, 55, 530, 450), col_inner)
	
	# Central Bar for Hit Checkers
	var bar_rect = Rect2(290, 40, 60, 480)
	draw_rect(bar_rect, col_bar)
	draw_rect(bar_rect, Color(0.4, 0.25, 0.15), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(300, 265), "BARRA", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.8, 0.7, 0.5))

	# Bearing-Off Area
	draw_rect(Rect2(610, 40, 150, 200), COL_BEARING)
	draw_string(ThemeDB.fallback_font, Vector2(620, 70), "Bearing Off 🏁", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(620, 110), "P1 (Rojo): %d/15" % borne_off_checkers[P1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PLAYER_COLORS[P1])
	draw_string(ThemeDB.fallback_font, Vector2(620, 140), "P2 (Azul): %d/15" % borne_off_checkers[P2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PLAYER_COLORS[P2])
	
	# 24 Triangular Points with alternate colors, borders, and point numbers
	var font: Font = ThemeDB.fallback_font
	for pt in range(TOTAL_POINTS):
		var base_pos = _get_point_base_pos(pt)
		var is_top = (pt >= 12)
		var tri_col = col_pt_a if (pt % 2 == 0) else col_pt_b
		
		var p1: Vector2 = base_pos + Vector2(-18, 0)
		var p2: Vector2 = base_pos + Vector2(18, 0)
		var p3: Vector2
		if is_top:
			p3 = base_pos + Vector2(0, 195)
		else:
			p3 = base_pos + Vector2(0, -195)
			
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), tri_col)
		draw_polyline(PackedVector2Array([p1, p3, p2]), Color(0.18, 0.12, 0.08, 0.55), 1.4)
		if font != null:
			var num_y := 52.0 if is_top else 514.0
			draw_string(font, Vector2(base_pos.x - 10.0, num_y), str(pt + 1), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 10, Color(0.92, 0.85, 0.72, 0.85))
		
	# Selected highlight
	if selected_from >= 0:
		var sel_base = _get_point_base_pos(selected_from)
		draw_circle(sel_base, 20.0, col_sel)
	elif selected_from == -1:
		draw_circle(Vector2(320, 280), 25.0, col_sel)

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Retiró todas sus fichas! Ganó el jugador %s (Backgammon)" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var p_name = "Rojo (P1)" if current == P1 else "Azul (P2)"
		var col = PLAYER_COLORS[current]
		status.text = ""
		if turn_indicator != null:
			turn_indicator.set_turn(current, p_name, col)
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
