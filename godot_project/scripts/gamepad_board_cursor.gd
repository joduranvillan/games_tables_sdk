extends CanvasLayer

## Cursor virtual reutilizable de tablero y cartas para Gamepad (Xbox, DualSense, Steam Deck).
## Traduce las acciones `ui_gamepad_*` e inputs de mando a movimiento de grilla, selección (A),
## cancelación (B) y menú de pausa (Start). Se activa automáticamente al detectar eventos
## de mando y se oculta al detectar ratón o pantalla táctil.

signal cursor_activated()
signal cursor_hidden()
signal cursor_moved(cell: Vector2i)
signal cell_selected(cell: Vector2i)
signal selection_cancelled()
signal pause_requested()

const STICK_DEADZONE: float = 0.5
const STICK_REPEAT_DELAY: float = 0.18

var cursor_active: bool = false
var cursor_cell: Vector2i = Vector2i(0, 0)
var grid_size: Vector2i = Vector2i(8, 8)
var cell_pixel_size: Vector2 = Vector2(64.0, 64.0)
var board_origin: Vector2 = Vector2(0.0, 0.0)

var target_board: Node = null
var pause_menu_ref: Node = null
var cursor_visual: Polygon2D = null
var pulse_phase: float = 0.0
var stick_cooldown: float = 0.0

func _init() -> void:
	name = "GamepadBoardCursor"
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_visual()
	_set_cursor_visible(false)

func _ready() -> void:
	_ensure_visual()
	_set_cursor_visible(cursor_active)

func _ensure_visual() -> void:
	if cursor_visual != null and is_instance_valid(cursor_visual):
		return
	cursor_visual = Polygon2D.new()
	cursor_visual.name = "CursorVisual"
	cursor_visual.color = Color(1.0, 0.86, 0.18, 0.42)
	_rebuild_cursor_polygon()
	add_child(cursor_visual)

func _rebuild_cursor_polygon() -> void:
	if cursor_visual == null:
		return
	cursor_visual.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(cell_pixel_size.x, 0.0),
		Vector2(cell_pixel_size.x, cell_pixel_size.y),
		Vector2(0.0, cell_pixel_size.y),
	])

func bind_board(board_node: Node, cols: int = 8, rows: int = 8, cell_px: float = 64.0, origin_px: Vector2 = Vector2.ZERO) -> void:
	target_board = board_node
	grid_size = Vector2i(maxi(1, cols), maxi(1, rows))
	cell_pixel_size = Vector2(maxf(8.0, cell_px), maxf(8.0, cell_px))
	board_origin = origin_px
	cursor_cell = Vector2i(
		clampi(cursor_cell.x, 0, grid_size.x - 1),
		clampi(cursor_cell.y, 0, grid_size.y - 1)
	)
	_rebuild_cursor_polygon()
	_update_visual_position()

func _resolve_active_board() -> Node:
	if target_board != null and is_instance_valid(target_board):
		return target_board
	if not is_inside_tree():
		return null
	var root_node := get_tree().root
	if root_node == null:
		return null
	for child in root_node.get_children():
		var scr: Script = child.get_script()
		if scr != null and scr.resource_path.ends_with("_board.gd"):
			target_board = child
			_infer_board_geometry(child)
			return child
	return null

func _infer_board_geometry(board_node: Node) -> void:
	if board_node == null:
		return
	if board_node.get("BOARD_SIZE") != null:
		var bs := int(board_node.get("BOARD_SIZE"))
		grid_size = Vector2i(bs, bs)
	elif board_node.get("BOARD") != null:
		var b := int(board_node.get("BOARD"))
		grid_size = Vector2i(b, b)
	elif board_node.get("ROWS") != null and board_node.get("COLS") != null:
		grid_size = Vector2i(int(board_node.get("COLS")), int(board_node.get("ROWS")))

	if board_node.get("CELL_SIZE") != null:
		var cs := float(board_node.get("CELL_SIZE"))
		cell_pixel_size = Vector2(cs, cs)
	elif board_node.get("CELL") != null:
		var c := float(board_node.get("CELL"))
		cell_pixel_size = Vector2(c, c)
	_rebuild_cursor_polygon()

func _process(delta: float) -> void:
	if stick_cooldown > 0.0:
		stick_cooldown = maxf(0.0, stick_cooldown - delta)
	if cursor_active and cursor_visual != null and cursor_visual.visible:
		pulse_phase += delta * 5.0
		cursor_visual.color.a = 0.28 + 0.22 * (0.5 + 0.5 * sin(pulse_phase))

func _input(event: InputEvent) -> void:
	handle_input_event(event)

func handle_input_event(event: InputEvent) -> bool:
	if event == null:
		return false

	# Ocultar automáticamente al mover el ratón o tocar la pantalla
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		if cursor_active:
			_hide_cursor()
		return false

	# Activar automáticamente con cualquier botón o stick de mando
	if event is InputEventJoypadButton:
		_activate_cursor()
		var joy_btn := event as InputEventJoypadButton
		if not joy_btn.pressed:
			return true
		if event.is_action_pressed("ui_gamepad_up") or joy_btn.button_index == JOY_BUTTON_DPAD_UP:
			move_cursor(Vector2i(0, -1))
			return true
		if event.is_action_pressed("ui_gamepad_down") or joy_btn.button_index == JOY_BUTTON_DPAD_DOWN:
			move_cursor(Vector2i(0, 1))
			return true
		if event.is_action_pressed("ui_gamepad_left") or joy_btn.button_index == JOY_BUTTON_DPAD_LEFT:
			move_cursor(Vector2i(-1, 0))
			return true
		if event.is_action_pressed("ui_gamepad_right") or joy_btn.button_index == JOY_BUTTON_DPAD_RIGHT:
			move_cursor(Vector2i(1, 0))
			return true
		if event.is_action_pressed("ui_gamepad_select") or joy_btn.button_index == JOY_BUTTON_A:
			trigger_select()
			return true
		if event.is_action_pressed("ui_gamepad_cancel") or joy_btn.button_index == JOY_BUTTON_B:
			trigger_cancel()
			return true
		if event.is_action_pressed("ui_gamepad_start") or joy_btn.button_index == JOY_BUTTON_START:
			trigger_start_pause()
			return true
		return true

	if event is InputEventJoypadMotion:
		var joy_mot := event as InputEventJoypadMotion
		if absf(joy_mot.axis_value) >= STICK_DEADZONE:
			_activate_cursor()
			if stick_cooldown <= 0.0:
				if joy_mot.axis == JOY_AXIS_LEFT_X:
					move_cursor(Vector2i(1 if joy_mot.axis_value > 0.0 else -1, 0))
					stick_cooldown = STICK_REPEAT_DELAY
				elif joy_mot.axis == JOY_AXIS_LEFT_Y:
					move_cursor(Vector2i(0, 1 if joy_mot.axis_value > 0.0 else -1))
					stick_cooldown = STICK_REPEAT_DELAY
			return true
		return false

	if event is InputEventAction:
		var act := event as InputEventAction
		if not act.pressed:
			return false
		var action_name := String(act.action)
		if action_name.begins_with("ui_gamepad_"):
			_activate_cursor()
			match action_name:
				"ui_gamepad_up":
					move_cursor(Vector2i(0, -1))
				"ui_gamepad_down":
					move_cursor(Vector2i(0, 1))
				"ui_gamepad_left":
					move_cursor(Vector2i(-1, 0))
				"ui_gamepad_right":
					move_cursor(Vector2i(1, 0))
				"ui_gamepad_select":
					trigger_select()
				"ui_gamepad_cancel":
					trigger_cancel()
				"ui_gamepad_start":
					trigger_start_pause()
			return true

	return false

func _activate_cursor() -> void:
	_ensure_visual()
	var was_active := cursor_active
	cursor_active = true
	_set_cursor_visible(true)
	_update_visual_position()
	if not was_active:
		cursor_activated.emit()

func _hide_cursor() -> void:
	var was_active := cursor_active
	cursor_active = false
	_set_cursor_visible(false)
	if was_active:
		cursor_hidden.emit()

func _set_cursor_visible(vis: bool) -> void:
	visible = vis
	if cursor_visual != null:
		cursor_visual.visible = vis

func _update_visual_position() -> void:
	_ensure_visual()
	var board := _resolve_active_board()
	if board != null and board.has_method("cell_to_pixel"):
		cursor_visual.position = board.call("cell_to_pixel", cursor_cell)
	else:
		cursor_visual.position = board_origin + Vector2(
			cursor_cell.x * cell_pixel_size.x,
			cursor_cell.y * cell_pixel_size.y
		)

func move_cursor(delta: Vector2i) -> Vector2i:
	_resolve_active_board()
	cursor_cell = Vector2i(
		clampi(cursor_cell.x + delta.x, 0, maxi(0, grid_size.x - 1)),
		clampi(cursor_cell.y + delta.y, 0, maxi(0, grid_size.y - 1))
	)
	_update_visual_position()
	cursor_moved.emit(cursor_cell)
	return cursor_cell

func trigger_select() -> bool:
	var board := _resolve_active_board()
	var row := cursor_cell.y
	var col := cursor_cell.x

	if board != null:
		if board.has_method("_handle_cell_click"):
			board.call("_handle_cell_click", row, col)
		elif board.has_method("_handle_board_click"):
			board.call("_handle_board_click", row, col)
		elif board.has_method("_handle_intersection_click"):
			board.call("_handle_intersection_click", row, col)
		elif board.has_method("_on_cell_clicked"):
			board.call("_on_cell_clicked", Vector2i(row, col))
		elif board.has_method("_handle_fire_click"):
			board.call("_handle_fire_click", row, col)
		elif board.has_method("_handle_point_click"):
			board.call("_handle_point_click", clampi(row * 12 + col, 0, 23))
		elif board.has_method("_handle_click"):
			var center_px := board_origin + Vector2((col + 0.5) * cell_pixel_size.x, (row + 0.5) * cell_pixel_size.y)
			board.call("_handle_click", center_px)
		elif board.has_method("_on_gamepad_cell_selected"):
			board.call("_on_gamepad_cell_selected", cursor_cell)

	cell_selected.emit(cursor_cell)
	return true

func trigger_cancel() -> void:
	var board := _resolve_active_board()
	if board != null:
		if board.get("selected_pos") != null:
			board.set("selected_pos", null)
		if board.get("selected") != null:
			board.set("selected", Vector2i(-1, -1))
		if board.get("selected_from") != null:
			board.set("selected_from", -2)
		if board.get("selected_hand_piece") != null:
			board.set("selected_hand_piece", "")
		if board.get("valid_moves") is Array:
			(board.get("valid_moves") as Array).clear()
		if board.has_method("queue_redraw"):
			board.call("queue_redraw")
	selection_cancelled.emit()

func trigger_start_pause() -> bool:
	var pm: Node = pause_menu_ref
	if pm == null or not is_instance_valid(pm):
		var board := _resolve_active_board()
		if board != null and board.get("_pause_menu") != null:
			pm = board.get("_pause_menu")
		elif board != null and board.has_node("PauseMenu"):
			pm = board.get_node("PauseMenu")
	if pm != null and is_instance_valid(pm):
		if pm.has_method("_toggle_pause"):
			pm.call("_toggle_pause")
		elif "visible" in pm:
			pm.set("visible", not bool(pm.get("visible")))
		pause_requested.emit()
		return true
	pause_requested.emit()
	return false
