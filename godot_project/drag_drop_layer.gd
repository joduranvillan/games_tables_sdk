## Capa de input drag-and-drop reutilizable para tableros de juego grid-based.
## Soporta mouse y touch (un toque para seleccionar, segundo toque para mover, o drag & drop).
class_name DragDropLayer
extends Control

signal piece_drag_started(from: Vector2i)
signal piece_dropped(to: Vector2i)
signal cell_clicked(cell: Vector2i)
signal drag_cancelled()

@export var cell_size: float = 80.0
@export var board_bounds: Vector2i = Vector2i(8, 8)
@export var board_offset: Vector2 = Vector2.ZERO
@export var enabled: bool = true

var selected_from: Vector2i = Vector2i(-1, -1)
var is_dragging: bool = false
var touch_down_pos: Vector2 = Vector2.ZERO
var drag_threshold: float = 8.0 # 8px dead zone for touch gestures
var highlight_color: Color = Color(1.0, 0.95, 0.30, 0.5)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(cell_size * board_bounds.y, cell_size * board_bounds.x)
	size = custom_minimum_size
	position = board_offset

func set_selected_cell(cell: Vector2i) -> void:
	selected_from = cell
	queue_redraw()

func clear_selection() -> void:
	selected_from = Vector2i(-1, -1)
	is_dragging = false
	queue_redraw()

func pos_to_cell(pos: Vector2) -> Vector2i:
	var rel_pos = pos - board_offset - global_position
	# If input is local to this control:
	if pos.x < global_position.x or pos.y < global_position.y:
		rel_pos = pos - global_position
	var col = int(floor(rel_pos.x / cell_size))
	var row = int(floor(rel_pos.y / cell_size))
	return Vector2i(row, col)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_bounds.x and cell.y >= 0 and cell.y < board_bounds.y

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
		
	var event_pos = Vector2.ZERO
	var is_press = false
	var is_release = false
	var is_motion = false
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			event_pos = event.position
			is_press = event.pressed
			is_release = not event.pressed
	elif event is InputEventMouseMotion:
		event_pos = event.position
		is_motion = true
	elif event is InputEventScreenTouch:
		event_pos = event.position
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventScreenDrag:
		event_pos = event.position
		is_motion = true

	if is_press:
		_handle_press(event_pos)
	elif is_motion and is_dragging:
		_handle_motion(event_pos)
	elif is_release:
		_handle_release(event_pos)

func _input(event: InputEvent) -> void:
	# Fallback if _gui_input doesn't catch root clicks
	if not enabled or get_rect().has_point(get_local_mouse_position()):
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = pos_to_cell(event.position)
		if is_in_bounds(cell):
			_handle_press(event.position)
			accept_event()

func _handle_press(pos: Vector2) -> void:
	var cell = pos_to_cell(pos)
	touch_down_pos = pos
	
	if not is_in_bounds(cell):
		clear_selection()
		drag_cancelled.emit()
		return
		
	cell_clicked.emit(cell)
	
	if selected_from == Vector2i(-1, -1):
		# First tap / press: select source piece
		selected_from = cell
		is_dragging = true
		piece_drag_started.emit(cell)
		queue_redraw()
	elif selected_from == cell:
		# Tapped same cell again: toggle/cancel
		clear_selection()
		drag_cancelled.emit()
	else:
		# Second tap on destination cell
		var _from_cell = selected_from
		clear_selection()
		piece_dropped.emit(cell)

func _handle_motion(pos: Vector2) -> void:
	if not is_dragging or selected_from == Vector2i(-1, -1):
		return
	if pos.distance_to(touch_down_pos) > drag_threshold:
		queue_redraw()

func _handle_release(pos: Vector2) -> void:
	if not is_dragging:
		return
		
	var release_cell = pos_to_cell(pos)
	var drag_dist = pos.distance_to(touch_down_pos)
	
	if drag_dist > drag_threshold and is_in_bounds(release_cell) and release_cell != selected_from:
		# Drag & Drop release over target cell
		var _from_cell = selected_from
		clear_selection()
		piece_dropped.emit(release_cell)
	else:
		# Tap release (keep selected_from active for two-tap movement)
		is_dragging = false
		queue_redraw()

func _draw() -> void:
	if selected_from != Vector2i(-1, -1):
		var sel_rect = Rect2(selected_from.y * cell_size, selected_from.x * cell_size, cell_size, cell_size)
		draw_rect(sel_rect, highlight_color)
		draw_rect(sel_rect, Color(1, 0.9, 0.2, 0.9), false, 2.5)
