extends Node2D

const BOARD_SIZE := 8
const CELL_SIZE := 46.0
const P1 := 1
const P2 := 2
const SHIP_SPECS := [
	{"name": "Portaaviones", "size": 4, "color": Color(0.2, 0.6, 0.9)},
	{"name": "Acorazado", "size": 3, "color": Color(0.3, 0.8, 0.4)},
	{"name": "Submarino", "size": 2, "color": Color(0.9, 0.7, 0.2)}
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

var status_label: Label
var phase_label: Label
var rotate_btn: Button
var ships_container: Control
var ship_sprites_container: Node2D

var turn_indicator: TurnIndicator
var network_hud: NetworkStatusHUD
var current_theme: BoardTheme

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()

	_init_grids()
	_setup_ui()

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	if network_hud != null:
		network_hud.bind_bridge(bridge)

	bridge.connect("shot_result", _on_shot_result)
	bridge.connect("event_json", _on_event_json)
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)

	bridge.start_local_match_battleship(P1, P2)
	current = bridge.current_player()

	_update_status()
	_update_grid_ui()

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
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	canvas.add_child(margin)

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
	grids_hbox.add_theme_constant_override("separation", 25)
	grids_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(grids_hbox)

	# --- Left Panel: Own Grid ---
	var own_vbox = VBoxContainer.new()
	grids_hbox.add_child(own_vbox)

	var own_title = Label.new()
	own_title.text = "🛡️ Mi Flota (Tablero Propio)"
	own_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	own_title.add_theme_font_size_override("font_size", 16)
	own_vbox.add_child(own_title)

	var own_grid_container = GridContainer.new()
	own_grid_container.columns = BOARD_SIZE
	own_vbox.add_child(own_grid_container)

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
	var opp_vbox = VBoxContainer.new()
	grids_hbox.add_child(opp_vbox)

	var opp_title = Label.new()
	opp_title.text = "🎯 Radar (Flota Enemiga)"
	opp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opp_title.add_theme_font_size_override("font_size", 16)
	opp_vbox.add_child(opp_title)

	var opp_grid_container = GridContainer.new()
	opp_grid_container.columns = BOARD_SIZE
	opp_vbox.add_child(opp_grid_container)

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

	network_hud = NetworkStatusHUD.new()
	add_child(network_hud)

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
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_invalid()
			return
		
		var pos = Vector2i(r, c)
		if _is_cell_occupied_in_ships(pos, target_ships):
			status_label.text = "❌ ¡Casilla ocupada por otro barco!"
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_invalid()
			return
		ship_cells.append(pos)

	target_ships.append(ship_cells)
	current_ship_index += 1

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_move()

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

func _on_shot_result(player: int, row: int, col: int, is_hit: bool) -> void:
	if player == current:
		opp_shot_grid[row][col] = "hit" if is_hit else "miss"
	else:
		own_shot_grid[row][col] = "hit" if is_hit else "miss"

	if is_hit:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_capture()
	else:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_move()

	_update_grid_ui()

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
				var shooting_player = int(event.get("player", current))
				if shooting_player == current:
					opp_shot_grid[r][c] = "sunk" if res_str == "Sunk" else ("hit" if is_hit else "miss")
				else:
					own_shot_grid[r][c] = "sunk" if res_str == "Sunk" else ("hit" if is_hit else "miss")

				if res_str == "Sunk" and event.has("sunken_ship"):
					var sunk_coords = event["sunken_ship"]
					for coord in sunk_coords:
						var sr = int(coord.get("row", 0))
						var sc = int(coord.get("col", 0))
						sunken_cells.append(Vector2i(sr, sc))
			elif ev_type == "SunkenShipEvent":
				if event.has("coords"):
					for pair in event["coords"]:
						sunken_cells.append(Vector2i(pair[0], pair[1]))
			elif ev_type == "GameOverEvent":
				winner = int(event.get("winner", -1))
				phase = Phase.GAME_OVER

	current = bridge.current_player()
	_update_status()
	_update_grid_ui()

func _on_game_over(w: int) -> void:
	winner = w
	phase = Phase.GAME_OVER
	_update_status()
	_update_grid_ui()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_game_over()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status_label.text = "⚠️ Acción inválida: %s" % reason
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_invalid()

func _update_status() -> void:
	if winner != -1 or phase == Phase.GAME_OVER:
		status_label.text = "🏆 ¡Fin del juego! Ganó el Jugador %d" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	elif phase == Phase.PLACEMENT_P1:
		var spec = SHIP_SPECS[current_ship_index] if current_ship_index < SHIP_SPECS.size() else null
		if spec:
			status_label.text = "⚓ Jugador 1: Coloca %s (Tamaño %d) [%d/%d]" % [
				spec["name"], spec["size"], current_ship_index + 1, SHIP_SPECS.size()
			]
		else:
			status_label.text = "⚓ Jugador 1: Flota lista."
	elif phase == Phase.PLACEMENT_P2:
		var spec = SHIP_SPECS[current_ship_index] if current_ship_index < SHIP_SPECS.size() else null
		if spec:
			status_label.text = "⚓ Jugador 2: Coloca %s (Tamaño %d) [%d/%d]" % [
				spec["name"], spec["size"], current_ship_index + 1, SHIP_SPECS.size()
			]
		else:
			status_label.text = "⚓ Jugador 2: Flota lista."
	elif phase == Phase.FIRE:
		var p_name = "Jugador 1" if current == P1 else "Jugador 2"
		status_label.text = "🚀 Fase de Disparo - Turno de %s" % p_name
		if turn_indicator != null:
			turn_indicator.set_turn(current, p_name, GameManager.get_player_color(current))

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
				btn.modulate = Color(0.5, 0.0, 0.0) # Darker red for sunken ship cells
			elif shot == "hit":
				btn.text = "💥"
				btn.modulate = Color(1.0, 0.2, 0.2) # Explosion icon (red)
			elif shot == "miss":
				btn.text = "💧"
				btn.modulate = Color(0.3, 0.7, 1.0) # Water splash (blue)
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
				btn.modulate = Color(0.5, 0.0, 0.0) # Darker red for sunken ship cells
				btn.disabled = true
			elif shot == "hit":
				btn.text = "💥"
				btn.modulate = Color(1.0, 0.2, 0.2) # Explosion icon (red)
				btn.disabled = true
			elif shot == "miss":
				btn.text = "💧"
				btn.modulate = Color(0.3, 0.7, 1.0) # Water splash (blue)
				btn.disabled = true
			else:
				btn.text = "~"
				btn.modulate = Color.WHITE
				btn.disabled = (phase != Phase.FIRE or winner != -1)
