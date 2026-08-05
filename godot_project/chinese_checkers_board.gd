extends Node2D

const P1 = 1
const P2 = 2
const BOARD_RADIUS = 4

const CENTER = Vector2(400, 320)
const HEX_SPACING = 52.0

const DIRECTIONS = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

const PLAYER_COLORS = {
	1: Color(0.9, 0.2, 0.2), # Red
	2: Color(0.2, 0.4, 0.9)  # Blue
}

var bridge
var current = P1
var winner = -1
var selected_pos = null # Vector2i(q, r)
var valid_dests: Array = [] # Array of Vector2i(q, r)

# Grid of positions: Vector2i(q, r) -> player_id (0 = empty, 1 = P1, 2 = P2)
var board_pegs = {}
# Grid of buttons: Vector2i(q, r) -> TextureButton
var peg_buttons = {}

@onready var status: Label = $Status

func _ready() -> void:
	_init_board_positions()
	_setup_ui()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	bridge.start_local_match_chinese_checkers(P1, P2)
	current = bridge.current_player()
	
	_update_peg_visuals()
	_update_status()
	queue_redraw()

func _init_board_positions() -> void:
	board_pegs.clear()
	for q in range(-BOARD_RADIUS, BOARD_RADIUS + 1):
		for r in range(-BOARD_RADIUS, BOARD_RADIUS + 1):
			if max(abs(q), max(abs(r), abs(q + r))) <= BOARD_RADIUS:
				# Default starting pegs
				var pos = Vector2i(q, r)
				if r >= 2:
					board_pegs[pos] = P1
				elif r <= -2:
					board_pegs[pos] = P2
				else:
					board_pegs[pos] = 0

func _axial_to_pixel(q: int, r: int) -> Vector2:
	var x = CENTER.x + HEX_SPACING * (q + r / 2.0)
	var y = CENTER.y + HEX_SPACING * (r * sqrt(3.0) / 2.0)
	return Vector2(x, y)

func _setup_ui() -> void:
	peg_buttons.clear()
	for pos in board_pegs.keys():
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(36, 36)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.pivot_offset = Vector2(18, 18)
		
		var px_pos = _axial_to_pixel(pos.x, pos.y)
		btn.position = px_pos - Vector2(18, 18)
		
		var grid_pos = pos
		btn.pressed.connect(func(): _on_peg_clicked(grid_pos))
		add_child(btn)
		peg_buttons[pos] = btn

func _update_peg_visuals() -> void:
	for pos in board_pegs.keys():
		var btn = peg_buttons[pos]
		var p_id = board_pegs[pos]
		
		var img = Image.create(36, 36, false, Image.FORMAT_RGBA8)
		var p_color = PLAYER_COLORS.get(p_id, Color(0.85, 0.85, 0.85, 0.4))
		
		for x in range(36):
			for y in range(36):
				var dist = Vector2(x - 18, y - 18).length()
				if p_id > 0:
					if dist <= 14:
						img.set_pixel(x, y, p_color)
					elif dist <= 16:
						img.set_pixel(x, y, Color.BLACK)
					else:
						img.set_pixel(x, y, Color(0,0,0,0))
				else:
					if dist <= 8:
						img.set_pixel(x, y, Color(0.3, 0.3, 0.35, 0.5))
					elif dist <= 10:
						img.set_pixel(x, y, Color(0.6, 0.6, 0.6, 0.8))
					else:
						img.set_pixel(x, y, Color(0,0,0,0))
						
		btn.texture_normal = ImageTexture.create_from_image(img)

func _on_peg_clicked(pos: Vector2i) -> void:
	if winner != -1:
		return
		
	if selected_pos == null:
		if board_pegs.get(pos, 0) == current:
			selected_pos = pos
			valid_dests = _calculate_valid_destinations(pos)
			queue_redraw()
	else:
		if selected_pos == pos:
			selected_pos = null
			valid_dests.clear()
			queue_redraw()
			return
			
		if board_pegs.get(pos, 0) == current:
			selected_pos = pos
			valid_dests.clear()
			valid_dests = _calculate_valid_destinations(pos)
			queue_redraw()
			return
			
		var from_pos = selected_pos
		selected_pos = null
		valid_dests.clear()
		queue_redraw()
		
		var cmd = {
			"command_type": "MovePegCommand",
			"player": current,
			"from": {"q": from_pos.x, "r": from_pos.y},
			"to": {"q": pos.x, "r": pos.y},
			"path": []
		}
		bridge.send_command_json(current, JSON.stringify(cmd))

func _calculate_valid_destinations(start: Vector2i) -> Array:
	var dests: Array = []
	# 1. Single steps
	for dir in DIRECTIONS:
		var target = start + dir
		if board_pegs.has(target) and board_pegs[target] == 0:
			dests.append(target)
			
	# 2. Jumps & jump chains
	var visited = {}
	var queue = [start]
	visited[start] = true
	
	while not queue.is_empty():
		var curr = queue.pop_front()
		for dir in DIRECTIONS:
			var mid = curr + dir
			var landing = curr + dir * 2
			if board_pegs.has(mid) and board_pegs[mid] > 0: # Jump over peg
				if board_pegs.has(landing) and board_pegs[landing] == 0:
					if not visited.has(landing):
						visited[landing] = true
						if landing != start and not dests.has(landing):
							dests.append(landing)
						queue.append(landing)
	return dests

func _animate_peg_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var p_id = board_pegs.get(from_pos, current)
	board_pegs[from_pos] = 0
	board_pegs[to_pos] = p_id
	
	_update_peg_visuals()
	var btn = peg_buttons[to_pos]
	var from_px = _axial_to_pixel(from_pos.x, from_pos.y) - Vector2(18, 18)
	var to_px = _axial_to_pixel(to_pos.x, to_pos.y) - Vector2(18, 18)
	btn.position = from_px
	
	var tween = create_tween()
	tween.tween_property(btn, "position", to_px, 0.25)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "PegMovedEvent" or event_type == "TokenMovedEvent":
				var from_dict = event.get("from", {})
				var to_dict = event.get("to", {})
				var from_p = Vector2i(int(from_dict.get("q", 0)), int(from_dict.get("r", 0)))
				var to_p = Vector2i(int(to_dict.get("q", 0)), int(to_dict.get("r", 0)))
				_animate_peg_move(from_p, to_p)
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
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason

func _draw() -> void:
	# Draw board star/hexagon polygon background
	var points = PackedVector2Array()
	var outer_r = 260.0
	for i in range(6):
		var angle = deg_to_rad(60 * i + 30)
		points.append(CENTER + Vector2(cos(angle), sin(angle)) * outer_r)
	draw_colored_polygon(points, Color(0.18, 0.18, 0.24))
	draw_polyline(points, Color(0.8, 0.7, 0.3), 3.0)
	
	# Selection highlight
	if selected_pos != null:
		var px = _axial_to_pixel(selected_pos.x, selected_pos.y)
		draw_circle(px, 22.0, Color(1.0, 0.9, 0.2, 0.6))
		
	# Destination highlights
	for dest in valid_dests:
		var px = _axial_to_pixel(dest.x, dest.y)
		draw_circle(px, 14.0, Color(0.2, 0.9, 0.3, 0.7))

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Ganó el jugador %s (Damas Chinas)!" % winner
	else:
		var col_name = "Rojo (1)" if current == P1 else "Azul (2)"
		status.text = "Turno: %s (Damas Chinas)" % col_name
