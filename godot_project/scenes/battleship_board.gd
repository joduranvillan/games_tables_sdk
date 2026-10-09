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

var p1_ships: Array = [] # Array of Arrays of Vector2i
var p2_ships: Array = []
var current_ship_index: int = 0
var is_horizontal: bool = true

var own_shot_grid: Array = [] # 8x8: null | "hit" | "miss" | "sunk"
var opp_shot_grid: Array = [] # 8x8: null | "hit" | "miss" | "sunk"
var sunken_cells: Array[Vector2i] = []

var own_grid_buttons: Array = []
var opp_grid_buttons: Array = []

var own_vbox: VBoxContainer
var opp_vbox: VBoxContainer
var status_label: Label
var phase_label: Label
var rotate_btn: Button
var ships_container: Control
var ship_sprites_container: Node2D

var turn_indicator: TurnIndicator
var network_hud: NetworkStatusHUD
var current_theme: BoardTheme
var _rules_popup: RulesPopup
var _pause_menu: CanvasLayer

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	var gm = (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)

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

	bridge.start_local_match_battleship(P1, P2)
	current = bridge.current_player()

	_on_layout_changed(GameManager.get_layout() if gm != null else 0)
	_update_status()
	_update_grid_ui()
	queue_redraw()

	# --- Botón de reglas ---
	var btn_rules := Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(get_viewport_rect().size.x - 105, 10)
	btn_rules.custom_minimum_size = Vector2(90, 36)
	btn_rules.pressed.connect(func(): _rules_popup.show_for_game("battleship"))
	add_child(btn_rules)

	_rules_popup = RulesPopup.new()
	_rules_popup.visible = false
	_rules_popup.position = Vector2(80, 100)
	add_child(_rules_popup)

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

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	_update_grid_ui()
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

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
	# Main Container layout
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# Header / Status
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	status_label = Label.new()
	status_label.text = "Batalla Naval - Colocación de flota"
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(status_label)

	rotate_btn = Button.new()
	rotate_btn.text = "🔄 Orientación: Horizontal"
	rotate_btn.custom_minimum_size = Vector2(200, 36)
	rotate_btn.pressed.connect(_on_rotate_pressed)
	header_hbox.add_child(rotate_btn)

	# Two Grids Side-by-Side
	var grids_hbox = HBoxContainer.new()
	grids_hbox.add_theme_constant_override("separation", 35)
	grids_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(grids_hbox)

	# --- Left Panel: Own Grid ---
	own_vbox = VBoxContainer.new()
	grids_hbox.add_child(own_vbox)

	var own_title = Label.new()
	own_title.text = "🛡️ Mi Flota (Tablero Propio)"
	own_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	own_title.add_theme_font_size_override("font_size", 16)
	own_vbox.add_child(own_title)

	var own_margin = MarginContainer.new()
	own_margin.add_theme_constant_override("margin_left", 22)
	own_margin.add_theme_constant_override("margin_top", 22)
	own_vbox.add_child(own_margin)

	var own_grid_container = GridContainer.new()
	own_grid_container.columns = BOARD_SIZE
	own_margin.add_child(own_grid_container)

	own_grid_buttons = []
	for r in BOARD_SIZE:
		var row_btns = []
		for c in BOARD_SIZE:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			btn.text = "~"
			btn.pressed.connect(_on_own_cell_pressed.bind(r, c))
			own_grid_container.add_child(btn)
			row_btns.append(btn)
		own_grid_buttons.append(row_btns)

	# --- Right Panel: Opponent Grid ---
	opp_vbox = VBoxContainer.new()
	grids_hbox.add_child(opp_vbox)

	var opp_title = Label.new()
	opp_title.text = "🎯 Radar (Flota Enemiga)"
	opp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opp_title.add_theme_font_size_override("font_size", 16)
	opp_vbox.add_child(opp_title)

	var opp_margin = MarginContainer.new()
	opp_margin.add_theme_constant_override("margin_left", 22)
	opp_margin.add_theme_constant_override("margin_top", 22)
	opp_vbox.add_child(opp_margin)

	var opp_grid_container = GridContainer.new()
	opp_grid_container.columns = BOARD_SIZE
	opp_margin.add_child(opp_grid_container)

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
	add_child(ship_sprites_container)

	turn_indicator = TurnIndicator.new()
	turn_indicator.position = Vector2(10, BOARD_SIZE * CELL_SIZE + 120)
	add_child(turn_indicator)

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

	var font_sz := 14
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
			draw_string(font, Vector2(b_pos.x, b_pos.y - 6), num_str, HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, font_sz, coord_color)

	# Letras A–J en la columna izquierda (filas 0..9)
	for r in range(BOARD_SIZE):
		var btn: Button = grid_buttons[r][0]
		if btn != null and btn.is_inside_tree():
			var b_pos = to_local(btn.global_position)
			var letter = String.chr("A".unicode_at(0) + r)
			draw_string(font, Vector2(b_pos.x - 20, b_pos.y + CELL_SIZE * 0.65), letter, HORIZONTAL_ALIGNMENT_CENTER, 18, font_sz, coord_color)

func _on_rotate_pressed() -> void:
	is_horizontal = not is_horizontal
	if rotate_btn != null:
		rotate_btn.text = "🔄 Orientación: " + ("Horizontal" if is_horizontal else "Vertical")

func _on_own_cell_pressed(row: int, col: int) -> void:
	if phase == Phase.PLACEMENT_P1 or phase == Phase.PLACEMENT_P2:
		_handle_placement(row, col)

func _on_opp_cell_pressed(row: int, col: int) -> void:
	if phase == Phase.FIRE and winner == -1:
		_handle_fire_click(row, col)

func _handle_placement(start_row: int, start_col: int) -> void:
	if current_ship_index >= SHIP_SPECS.size():
		return

	var spec = SHIP_SPECS[current_ship_index]
	var ship_size: int = spec["size"]
	var target_ships := p1_ships if phase == Phase.PLACEMENT_P1 else p2_ships
	var ship_cells: Array[Vector2i] = []

	for i in range(ship_size):
		var r = start_row + (0 if is_horizontal else i)
		var c = start_col + (i if is_horizontal else 0)
		if r < 0 or r >= BOARD_SIZE or c < 0 or c >= BOARD_SIZE:
			status_label.text = "❌ ¡El barco no cabe en el tablero!"
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_error_buzz()
			return
		
		var pos = Vector2i(r, c)
		if _is_cell_occupied_in_ships(pos, target_ships):
			status_label.text = "❌ ¡Casilla ocupada por otro barco!"
			if (is_inside_tree() and has_node("/root/AudioManager")):
				get_node("/root/AudioManager").play_error_buzz()
			return
		ship_cells.append(pos)

	target_ships.append(ship_cells)
	current_ship_index += 1

	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

	if current_ship_index >= SHIP_SPECS.size():
		var active_player := P1 if phase == Phase.PLACEMENT_P1 else P2
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
		bridge.send_command_json(active_player, JSON.stringify(place_cmd))

	_update_status()
	_update_grid_ui()
	queue_redraw()

func _is_cell_occupied_in_ships(cell: Vector2i, ships: Array) -> bool:
	for ship in ships:
		for pos in ship:
			if pos == cell:
				return true
	return false

func _handle_fire_click(row: int, col: int) -> void:
	if opp_shot_grid[row][col] != null:
		status_label.text = "⚠️ Ya disparaste en esa casilla (%d, %d)" % [row + 1, col + 1]
		return

	var fire_cmd = {
		"command_type": "FireShotCommand",
		"player": current,
		"target": {"row": row, "col": col}
	}
	bridge.send_command_json(current, JSON.stringify(fire_cmd))

func _spawn_shot_animation(player: int, row: int, col: int, is_hit: bool) -> void:
	if OS.has_feature("headless"):
		return

	var is_opp_target = (player == current)
	var btn: Button = null
	if is_opp_target and row < opp_grid_buttons.size() and col < opp_grid_buttons[row].size():
		btn = opp_grid_buttons[row][col]
	elif not is_opp_target and row < own_grid_buttons.size() and col < own_grid_buttons[row].size():
		btn = own_grid_buttons[row][col]

	if btn == null or not btn.is_inside_tree():
		return

	var center_pos = btn.global_position + Vector2(btn.size.x / 2.0, btn.size.y / 2.0)
	var local_pos = to_local(center_pos)

	var explosion_tex_path = "res://assets/explosion.png"
	if not ResourceLoader.exists(explosion_tex_path):
		explosion_tex_path = "res://assets/icons/explosion.svg"

	if ResourceLoader.exists(explosion_tex_path):
		var sprite = Sprite2D.new()
		sprite.texture = load(explosion_tex_path)
		sprite.position = local_pos
		sprite.scale = Vector2(0.2, 0.2)
		sprite.z_index = 20
		add_child(sprite)
		var tw = sprite.create_tween().set_parallel(true)
		tw.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.35).set_delay(0.15)
		tw.chain().tween_callback(sprite.queue_free)
	else:
		# Círculo rojo pulsante con CPUParticles2D
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

		# Círculo pulsante visual
		var pulse_circle = Node2D.new()
		pulse_circle.position = local_pos
		pulse_circle.z_index = 19
		var circle_col = Color(1.0, 0.15, 0.15, 0.85) if is_hit else Color(0.2, 0.6, 1.0, 0.85)
		pulse_circle.draw.connect(func():
			pulse_circle.draw_circle(Vector2.ZERO, CELL_SIZE * 0.45, circle_col)
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
	if player == current:
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
			var ev_type: String = event.get("event_type", event.get("command_type", ""))
			if ev_type == "FleetPlacedEvent":
				var player_id = int(event.get("player", 1))
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
				if shooting_player == current:
					opp_shot_grid[r][c] = "sunk" if res_str == "Sunk" else ("hit" if is_hit else "miss")
				else:
					own_shot_grid[r][c] = "sunk" if res_str == "Sunk" else ("hit" if is_hit else "miss")

				_spawn_shot_animation(shooting_player, r, c, is_hit)

				if res_str == "Sunk" and event.has("sunken_ship"):
					var sunk_coords = event["sunken_ship"]
					for coord in sunk_coords:
						var sr = int(coord.get("row", 0))
						var sc = int(coord.get("col", 0))
						var spos = Vector2i(sr, sc)
						if not spos in sunken_cells:
							sunken_cells.append(spos)
			elif ev_type == "SunkenShipEvent" or ev_type == "SunkShipEvent":
				if event.has("positions"):
					for pos_obj in event["positions"]:
						var sr = int(pos_obj.get("row", 0)) if pos_obj is Dictionary else int(pos_obj[0])
						var sc = int(pos_obj.get("col", 0)) if pos_obj is Dictionary else int(pos_obj[1])
						var spos = Vector2i(sr, sc)
						if not spos in sunken_cells:
							sunken_cells.append(spos)
				elif event.has("coords"):
					for pair in event["coords"]:
						var sr = int(pair[0]) if pair is Array else int(pair.get("row", 0))
						var sc = int(pair[1]) if pair is Array else int(pair.get("col", 0))
						var spos = Vector2i(sr, sc)
						if not spos in sunken_cells:
							sunken_cells.append(spos)
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
	status_label.text = "⚠️ Acción inválida: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _update_status() -> void:
	if winner != -1 or phase == Phase.GAME_OVER:
		status_label.text = "🏆 ¡Fin del juego! Ganó el Jugador %d" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 0.4)
	elif phase == Phase.PLACEMENT_P1:
		var spec = SHIP_SPECS[current_ship_index] if current_ship_index < SHIP_SPECS.size() else null
		if spec:
			status_label.text = "⚓ Jugador 1: Coloca %s (Tamaño %d) [%d/%d]" % [
				spec["name"], spec["size"], current_ship_index + 1, SHIP_SPECS.size()
			]
		else:
			status_label.text = "⚓ Jugador 1: Flota lista."
		if turn_indicator != null:
			var p_col = GameManager.get_player_color(P1) if (is_inside_tree() and has_node("/root/GameManager")) else Color(0.2, 0.6, 0.9)
			turn_indicator.set_turn(P1, "Jugador 1", p_col)
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif phase == Phase.PLACEMENT_P2:
		var spec = SHIP_SPECS[current_ship_index] if current_ship_index < SHIP_SPECS.size() else null
		if spec:
			status_label.text = "⚓ Jugador 2: Coloca %s (Tamaño %d) [%d/%d]" % [
				spec["name"], spec["size"], current_ship_index + 1, SHIP_SPECS.size()
			]
		else:
			status_label.text = "⚓ Jugador 2: Flota lista."
		if turn_indicator != null:
			var p_col = GameManager.get_player_color(P2) if (is_inside_tree() and has_node("/root/GameManager")) else Color(0.9, 0.3, 0.3)
			turn_indicator.set_turn(P2, "Jugador 2", p_col)
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif phase == Phase.FIRE:
		var p_name = "Jugador 1" if current == P1 else "Jugador 2"
		status_label.text = "🚀 Fase de Disparo - Turno de %s" % p_name
		if turn_indicator != null:
			var p_col = GameManager.get_player_color(current) if (is_inside_tree() and has_node("/root/GameManager")) else (Color(0.2, 0.6, 0.9) if current == P1 else Color(0.9, 0.3, 0.3))
			turn_indicator.set_turn(current, p_name, p_col)
			turn_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Modulate panels based on active board
	if own_vbox != null:
		var is_own_active = (phase == Phase.PLACEMENT_P1 or (phase == Phase.FIRE and current == P1))
		own_vbox.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_own_active else Color(1.0, 1.0, 1.0, 0.6)
	if opp_vbox != null:
		var is_opp_active = (phase == Phase.PLACEMENT_P2 or (phase == Phase.FIRE and current == P2))
		opp_vbox.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_opp_active else Color(1.0, 1.0, 1.0, 0.6)

func _update_grid_ui() -> void:
	var active_ships = p1_ships if phase == Phase.PLACEMENT_P1 else p2_ships

	# Update Own Grid UI
	for r in BOARD_SIZE:
		for c in BOARD_SIZE:
			var btn: Button = own_grid_buttons[r][c]
			var pos = Vector2i(r, c)
			var shot = own_shot_grid[r][c]

			if shot == "sunk" or pos in sunken_cells:
				btn.text = "⚓"
				btn.modulate = Color(0.3, 0.3, 0.3, 0.8) # Sunken ship in gray
			elif shot == "hit":
				btn.text = "💥"
				btn.modulate = Color(1.0, 0.2, 0.2) # Hit in red
			elif shot == "miss":
				btn.text = "💧"
				btn.modulate = Color(0.3, 0.7, 1.0) # Water splash in blue
			elif _is_cell_occupied_in_ships(pos, active_ships):
				btn.text = "🚢"
				btn.modulate = Color(0.3, 0.8, 0.4) # Ship cell
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
				btn.modulate = Color(0.3, 0.3, 0.3, 0.8) # Sunken ship in gray
				btn.disabled = true
			elif shot == "hit":
				btn.text = "💥"
				btn.modulate = Color(1.0, 0.2, 0.2) # Hit in red
				btn.disabled = true
			elif shot == "miss":
				btn.text = "💧"
				btn.modulate = Color(0.3, 0.7, 1.0) # Water splash in blue
				btn.disabled = true
			else:
				btn.text = "~"
				btn.modulate = Color.WHITE
				btn.disabled = (phase != Phase.FIRE or winner != -1)

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
