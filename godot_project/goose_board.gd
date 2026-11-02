# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Node2D

const MAX_PLAYERS: int = 4
const GARDEN_SQUARE: int = 63
const GOOSE_SQUARES: Array[int] = [5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59]

# Espiral clásica de 64 posiciones en grilla 8x8 (índice 0 = Salida, 1..63 = recorrido hacia el centro)
const SPIRAL_GRID: Array[Vector2] = [
	Vector2(0, 7), Vector2(1, 7), Vector2(2, 7), Vector2(3, 7), Vector2(4, 7), Vector2(5, 7), Vector2(6, 7), Vector2(7, 7),
	Vector2(7, 6), Vector2(7, 5), Vector2(7, 4), Vector2(7, 3), Vector2(7, 2), Vector2(7, 1), Vector2(7, 0),
	Vector2(6, 0), Vector2(5, 0), Vector2(4, 0), Vector2(3, 0), Vector2(2, 0), Vector2(1, 0), Vector2(0, 0),
	Vector2(0, 1), Vector2(0, 2), Vector2(0, 3), Vector2(0, 4), Vector2(0, 5), Vector2(0, 6),
	Vector2(1, 6), Vector2(2, 6), Vector2(3, 6), Vector2(4, 6), Vector2(5, 6), Vector2(6, 6),
	Vector2(6, 5), Vector2(6, 4), Vector2(6, 3), Vector2(6, 2), Vector2(6, 1),
	Vector2(5, 1), Vector2(4, 1), Vector2(3, 1), Vector2(2, 1), Vector2(1, 1),
	Vector2(1, 2), Vector2(1, 3), Vector2(1, 4), Vector2(1, 5),
	Vector2(2, 5), Vector2(3, 5), Vector2(4, 5), Vector2(5, 5),
	Vector2(5, 4), Vector2(5, 3), Vector2(5, 2),
	Vector2(4, 2), Vector2(3, 2), Vector2(2, 2),
	Vector2(2, 3), Vector2(2, 4),
	Vector2(3, 4), Vector2(4, 4),
	Vector2(4, 3), Vector2(3, 3)
]

var bridge: Node
var current_p: int = 1
var active_player_count: int = 2
var winner: int = -1
var last_dice_val: int = 0
var has_pending_roll: bool = false
var last_effect_text: String = "Tira el dado para comenzar la carrera hacia el Jardín de la Oca (63)."

var player_positions: Dictionary = {
	1: 0,
	2: 0,
	3: 0,
	4: 0
}

var player_wait_turns: Dictionary = {
	1: 0,
	2: 0,
	3: 0,
	4: 0
}

var token_buttons: Dictionary = {}
var dice_button: Button
var advance_button: Button
var dice_label: Label
var effect_label: Label
var dice_widget: DiceWidget
var mode_option_button: OptionButton
var rules_popup: RulesPopup
var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var _pause_menu: CanvasLayer

@onready var status: Label = get_node_or_null("Status")

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm: Node = get_node_or_null("/root/ThemeManager") if is_inside_tree() else null
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	var gm: Node = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)
	if is_inside_tree() and get_viewport() != null:
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)

	_setup_ui()

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	if not OS.has_feature("headless"):
		if bridge.has_method("is_network_mode") and bool(bridge.call("is_network_mode")):
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

	if gm != null and gm.get_game_mode() == "vs_ai":
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else 1
		var ai_p: int = 2 if human_p == 1 else 1
		var diff: int = gm.get_ai_difficulty() if gm.has_method("get_ai_difficulty") else 1
		if bridge.has_method("set_ai_difficulty"):
			bridge.set_ai_difficulty(diff)
		active_player_count = 2
		bridge.start_local_match_goose_vs_ai(human_p, ai_p)
		if mode_option_button != null:
			mode_option_button.selected = 3 if human_p == 1 else 4
	else:
		active_player_count = 2
		bridge.start_local_match_goose(1, 2)
		if mode_option_button != null:
			mode_option_button.selected = 0

	current_p = bridge.current_player()
	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_token_positions()
	_update_status()
	queue_redraw()

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_viewport_size_changed() -> void:
	var gm: Node = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	_on_layout_changed(gm.get_layout() if gm != null else 0)

func _on_quit_to_menu() -> void:
	if is_inside_tree() and has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	elif is_inside_tree():
		get_tree().change_scene_to_file("res://main.tscn")

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if is_inside_tree() and has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if is_inside_tree() and has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz: Vector2 = get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if _layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)
	var min_x: float = 20.0
	var min_y: float = -42.0
	var design_w: float = 560.0
	var design_h: float = 710.0
	var s: float = clampf(minf((vp_size.x - 40.0) / design_w, (vp_size.y - 24.0) / design_h), 0.30, 1.0)
	scale = Vector2(s, s)
	position = Vector2(
		(vp_size.x - design_w * s) * 0.5 - min_x * s,
		(vp_size.y - design_h * s) * 0.5 - min_y * s
	)

func _setup_ui() -> void:
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	status.position = Vector2(290, -32)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(20, -36)
	add_child(turn_indicator)

	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(355, -36)
	mode_option_button.custom_minimum_size = Vector2(225, 32)
	mode_option_button.add_item("2 Jugadores (Local)")
	mode_option_button.add_item("3 Jugadores (Local)")
	mode_option_button.add_item("4 Jugadores (Local)")
	mode_option_button.add_item("vs IA (Humano J1)")
	mode_option_button.add_item("vs IA (Humano J2)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	effect_label = Label.new()
	effect_label.name = "EffectLabel"
	effect_label.position = Vector2(20, 584)
	effect_label.size = Vector2(560, 26)
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.add_theme_font_size_override("font_size", 15)
	effect_label.text = last_effect_text
	add_child(effect_label)

	dice_widget = DiceWidget.new()
	dice_widget.position = Vector2(45, 616)
	add_child(dice_widget)

	dice_label = Label.new()
	dice_label.name = "DiceLabel"
	dice_label.position = Vector2(145, 610)
	dice_label.size = Vector2(90, 56)
	dice_label.text = "🎲 -"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.add_theme_font_size_override("font_size", 36)
	add_child(dice_label)

	dice_button = Button.new()
	dice_button.name = "RollDiceButton"
	dice_button.position = Vector2(250, 614)
	dice_button.custom_minimum_size = Vector2(155, 48)
	dice_button.text = "🎲 Tirar Dado"
	dice_button.add_theme_font_size_override("font_size", 17)
	dice_button.pressed.connect(_on_roll_dice_pressed)
	add_child(dice_button)

	advance_button = Button.new()
	advance_button.name = "AdvanceTokenButton"
	advance_button.position = Vector2(415, 614)
	advance_button.custom_minimum_size = Vector2(165, 48)
	advance_button.text = "🪿 Avanzar Ficha"
	advance_button.add_theme_font_size_override("font_size", 17)
	advance_button.disabled = true
	advance_button.pressed.connect(_on_advance_pressed)
	add_child(advance_button)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(80, 80)
	add_child(rules_popup)

	for p in range(1, MAX_PLAYERS + 1):
		var btn: TextureButton = TextureButton.new()
		btn.custom_minimum_size = Vector2(28, 28)
		btn.size = Vector2(28, 28)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.pivot_offset = Vector2(14, 14)

		var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var p_col: Color = _get_token_color(p)
		for x in range(32):
			for y in range(32):
				var dist: float = Vector2(x - 16, y - 16).length()
				if dist <= 12.0:
					img.set_pixel(x, y, p_col)
				elif dist <= 14.5:
					img.set_pixel(x, y, Color.BLACK)
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		btn.texture_normal = ImageTexture.create_from_image(img)
		var pid: int = p
		btn.pressed.connect(func(): _on_token_pressed(pid))
		add_child(btn)
		token_buttons[p] = btn

func _get_token_color(player_id: int) -> Color:
	var palette: Array[Color] = [
		Color(0.90, 0.22, 0.22),
		Color(0.20, 0.48, 0.92),
		Color(0.18, 0.72, 0.36),
		Color(0.92, 0.72, 0.12)
	]
	return palette[posmod(player_id - 1, palette.size())]

func _on_mode_selected(index: int) -> void:
	winner = -1
	last_dice_val = 0
	has_pending_roll = false
	last_effect_text = "Nueva partida iniciada. ¡Tira el dado!"
	if effect_label != null:
		effect_label.text = last_effect_text
	if advance_button != null:
		advance_button.disabled = true
	for p in range(1, MAX_PLAYERS + 1):
		player_positions[p] = 0
		player_wait_turns[p] = 0

	if bridge != null:
		match index:
			0:
				active_player_count = 2
				bridge.start_local_match_goose(1, 2)
			1:
				active_player_count = 3
				bridge.start_local_match_goose_n_players(3)
			2:
				active_player_count = 4
				bridge.start_local_match_goose_n_players(4)
			3:
				active_player_count = 2
				bridge.start_local_match_goose_vs_ai(1, 2)
			4:
				active_player_count = 2
				bridge.start_local_match_goose_vs_ai(2, 1)

	current_p = bridge.current_player() if bridge != null else 1
	_update_token_positions()
	_update_status()
	queue_redraw()

func _on_roll_dice_pressed() -> void:
	if winner != -1:
		return
	var cmd: Dictionary = {"command_type": "RollDiceCommand", "player": current_p}
	bridge.send_command_json(current_p, JSON.stringify(cmd))

func _on_advance_pressed() -> void:
	if winner != -1:
		return
	var cmd: Dictionary = {"command_type": "MoveTokenCommand", "player": current_p}
	bridge.send_command_json(current_p, JSON.stringify(cmd))

func _on_token_pressed(p: int) -> void:
	if winner != -1 or p != current_p:
		return
	if has_pending_roll:
		_on_advance_pressed()
	else:
		_on_roll_dice_pressed()

func get_square_center(square: int) -> Vector2:
	var idx: int = clampi(square, 0, GARDEN_SQUARE)
	var grid_pt: Vector2 = SPIRAL_GRID[idx]
	var margin: float = 20.0
	var cell_size: float = 70.0
	return Vector2(margin + grid_pt.x * cell_size + cell_size * 0.5, margin + grid_pt.y * cell_size + cell_size * 0.5)

func _update_token_positions() -> void:
	var offsets: Array[Vector2] = [
		Vector2(-12, -12),
		Vector2(12, -12),
		Vector2(-12, 12),
		Vector2(12, 12)
	]
	for p in range(1, MAX_PLAYERS + 1):
		if not token_buttons.has(p):
			continue
		var btn: TextureButton = token_buttons[p]
		btn.visible = p <= active_player_count
		var sq: int = int(player_positions.get(p, 0))
		var center: Vector2 = get_square_center(sq)
		var off: Vector2 = offsets[(p - 1) % offsets.size()]
		btn.position = center + off - btn.size * 0.5

func _animate_token_to(p: int, to_sq: int) -> void:
	player_positions[p] = to_sq
	if not token_buttons.has(p):
		return
	var btn: TextureButton = token_buttons[p]
	var offsets: Array[Vector2] = [
		Vector2(-12, -12),
		Vector2(12, -12),
		Vector2(-12, 12),
		Vector2(12, 12)
	]
	var target: Vector2 = get_square_center(to_sq) + offsets[(p - 1) % offsets.size()] - btn.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(btn, "position", target, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_event_json(json_str: String) -> void:
	var parser: JSON = JSON.new()
	if parser.parse(json_str) == OK:
		var ev_data: Variant = parser.data
		if ev_data is Dictionary:
			var event: Dictionary = ev_data
			var raw_type: String = str(event.get("command_type", event.get("event_type", "")))
			var parts: PackedStringArray = raw_type.split("::")
			var event_type: String = parts[parts.size() - 1] if parts.size() > 0 else raw_type

			if event_type == "DiceRolledEvent":
				var val: int = int(event.get("value", 1))
				last_dice_val = val
				has_pending_roll = true
				if advance_button != null:
					advance_button.disabled = false
				if dice_label != null:
					var faces: Array[String] = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
					dice_label.text = faces[val - 1] if (val >= 1 and val <= 6) else ("🎲 %d" % val)
				if dice_widget != null and dice_widget.has_method("show_roll"):
					dice_widget.show_roll([val])
				last_effect_text = "Jugador %d sacó un %d. Pulsa 'Avanzar Ficha' o tu ficha." % [int(event.get("player", current_p)), val]
				if effect_label != null:
					effect_label.text = last_effect_text

			elif event_type == "GooseMovedEvent":
				var p: int = int(event.get("player", current_p))
				var to_sq: int = int(event.get("to_square", 0))
				var wait_t: int = int(event.get("wait_turns", 0))
				var eff: String = str(event.get("effect", ""))
				has_pending_roll = false
				if advance_button != null:
					advance_button.disabled = true
				player_wait_turns[p] = wait_t
				last_effect_text = eff
				if effect_label != null:
					effect_label.text = last_effect_text
				_animate_token_to(p, to_sq)

			elif event_type == "TurnSkippedEvent":
				var skipped_p: int = int(event.get("player", 1))
				var rem: int = int(event.get("remaining_wait", 0))
				player_wait_turns[skipped_p] = rem

			elif event_type == "GameOverEvent":
				var w_val: Variant = event.get("winner", -1)
				var w: int = int(w_val) if w_val != null else 0
				_on_game_over(w)

	if bridge != null:
		current_p = bridge.current_player()
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	if status != null:
		status.text = "Jugada inválida: %s" % reason
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_error_buzz()

func _get_square_style(sq: int) -> Dictionary:
	if sq == 0:
		return {"col": Color(0.86, 0.84, 0.78), "tag": "SALIDA"}
	if sq == GARDEN_SQUARE:
		return {"col": Color(0.18, 0.68, 0.36), "tag": "👑 META"}
	if GOOSE_SQUARES.has(sq):
		return {"col": Color(0.95, 0.76, 0.18), "tag": "🪿 OCA"}
	if sq == 6 or sq == 12:
		return {"col": Color(0.28, 0.68, 0.92), "tag": "🌉 PUENTE"}
	if sq == 19:
		return {"col": Color(0.95, 0.52, 0.20), "tag": "🏠 POSADA"}
	if sq == 26 or sq == 53:
		return {"col": Color(0.24, 0.78, 0.48), "tag": "🎲 DADOS"}
	if sq == 31:
		return {"col": Color(0.72, 0.42, 0.16), "tag": "🕳 POZO"}
	if sq == 42:
		return {"col": Color(0.66, 0.38, 0.88), "tag": "🌀 LAB.30"}
	if sq == 52:
		return {"col": Color(0.86, 0.26, 0.26), "tag": "⛓ CÁRCEL"}
	if sq == 58:
		return {"col": Color(0.22, 0.26, 0.34), "tag": "💀 CALAV."}
	return {"col": Color(0.97, 0.95, 0.90), "tag": ""}

func _draw() -> void:
	var bg_col: Color = current_theme.board_color if current_theme != null else Color(0.94, 0.91, 0.84)
	var line_col: Color = current_theme.line_color if current_theme != null else Color(0.18, 0.16, 0.14)
	var font: Font = ThemeDB.fallback_font

	var board_rect: Rect2 = Rect2(20, 20, 560, 560)
	draw_rect(board_rect, bg_col)
	draw_rect(board_rect, line_col, false, 3.0)

	var cell_size: float = 70.0
	for sq in range(0, GARDEN_SQUARE + 1):
		var center: Vector2 = get_square_center(sq)
		var rect: Rect2 = Rect2(center.x - cell_size * 0.5 + 2.0, center.y - cell_size * 0.5 + 2.0, cell_size - 4.0, cell_size - 4.0)
		var style: Dictionary = _get_square_style(sq)
		var fill_col: Color = style["col"] as Color
		var tag_txt: String = str(style["tag"])

		draw_rect(rect, fill_col)
		draw_rect(rect, line_col, false, 2.0 if sq == GARDEN_SQUARE else 1.2)

		if font != null:
			var text_col: Color = Color.WHITE if (sq == 58 or sq == 52 or sq == 63 or sq == 42 or sq == 31) else Color(0.12, 0.12, 0.12)
			draw_string(font, Vector2(rect.position.x + 5.0, rect.position.y + 16.0), str(sq), HORIZONTAL_ALIGNMENT_LEFT, 60.0, 13, text_col)
			if not tag_txt.is_empty():
				draw_string(font, Vector2(rect.position.x + 2.0, rect.position.y + 38.0), tag_txt, HORIZONTAL_ALIGNMENT_CENTER, cell_size - 8.0, 10, text_col)

	# Dibujar línea guía sutil siguiendo el orden de la espiral 0 -> 63
	for sq in range(0, GARDEN_SQUARE):
		var a: Vector2 = get_square_center(sq)
		var b: Vector2 = get_square_center(sq + 1)
		draw_line(a, b, Color(line_col.r, line_col.g, line_col.b, 0.22), 2.0)

func _update_status() -> void:
	if winner != -1:
		if status != null:
			status.text = "¡Jardín de la Oca alcanzado! Ganó el Jugador %d" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var p_name: String = "Jugador %d" % current_p
		var col: Color = _get_token_color(current_p)
		if status != null:
			status.text = ""
		if turn_indicator != null:
			turn_indicator.set_turn(current_p, p_name, col)
