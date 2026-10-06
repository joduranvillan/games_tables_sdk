extends Node

signal step_changed(step_index: int, step_data: Object)
signal tutorial_completed()
signal tutorial_skipped()

class TutorialStep:
	var text: String = ""
	var highlight_cell: Vector2i = Vector2i(-1, -1)
	var arrow_from: Vector2i = Vector2i(-1, -1)
	var arrow_to: Vector2i = Vector2i(-1, -1)
	var wait_for_action: bool = false

	func _init(
		p_text: String = "",
		p_highlight: Vector2i = Vector2i(-1, -1),
		p_from: Vector2i = Vector2i(-1, -1),
		p_to: Vector2i = Vector2i(-1, -1),
		p_wait: bool = false
	) -> void:
		text = p_text
		highlight_cell = p_highlight
		arrow_from = p_from
		arrow_to = p_to
		wait_for_action = p_wait

var active_steps: Array = []
var current_step_index: int = -1
var current_board: Node = null
var active_overlay: CanvasLayer = null
var is_running: bool = false

func start(steps: Array, board_node: Node) -> void:
	stop_overlay()
	active_steps = steps.duplicate()
	current_board = board_node
	current_step_index = 0
	is_running = not active_steps.is_empty()
	if not is_running:
		return

	if ResourceLoader.exists("res://scenes/tutorial_overlay.tscn"):
		var scene: PackedScene = load("res://scenes/tutorial_overlay.tscn")
		if scene != null:
			active_overlay = scene.instantiate()
	if active_overlay == null:
		var OverlayScript = load("res://scenes/tutorial_overlay.gd")
		if OverlayScript != null:
			active_overlay = OverlayScript.new()

	if active_overlay != null and current_board != null:
		current_board.add_child(active_overlay)
		if active_overlay.has_signal("next_requested"):
			active_overlay.connect("next_requested", _on_overlay_next_requested)
		if active_overlay.has_signal("skip_requested"):
			active_overlay.connect("skip_requested", skip_tutorial)

	_apply_current_step()

func _apply_current_step() -> void:
	if not is_running or current_step_index < 0 or current_step_index >= active_steps.size():
		complete_tutorial()
		return

	var step = active_steps[current_step_index]
	if active_overlay != null and active_overlay.has_method("display_tutorial_step"):
		active_overlay.call("display_tutorial_step", step, current_step_index, active_steps.size(), current_board)
	step_changed.emit(current_step_index, step if step is Object else null)

func _on_overlay_next_requested() -> void:
	if not is_running:
		return
	var step = active_steps[current_step_index]
	var must_wait := false
	if step is TutorialStep:
		must_wait = step.wait_for_action
	elif step is Dictionary:
		must_wait = bool(step.get("wait_for_action", false))
	if not must_wait:
		advance_step()

func advance_step() -> void:
	if not is_running:
		return
	current_step_index += 1
	if current_step_index >= active_steps.size():
		complete_tutorial()
	else:
		_apply_current_step()

func is_cell_allowed(cell: Vector2i) -> bool:
	if not is_running or current_step_index < 0 or current_step_index >= active_steps.size():
		return true
	var step = active_steps[current_step_index]
	var target := Vector2i(-1, -1)
	var dest := Vector2i(-1, -1)
	if step is TutorialStep:
		target = step.highlight_cell
		dest = step.arrow_to
	elif step is Dictionary:
		target = step.get("highlight_cell", Vector2i(-1, -1))
		dest = step.get("arrow_to", Vector2i(-1, -1))

	if target == Vector2i(-1, -1) and dest == Vector2i(-1, -1):
		return true
	return cell == target or cell == dest

func notify_cell_action(cell: Vector2i) -> bool:
	if not is_cell_allowed(cell):
		return false
	if is_running and current_step_index >= 0 and current_step_index < active_steps.size():
		var step = active_steps[current_step_index]
		var wait := step.wait_for_action if step is TutorialStep else bool(step.get("wait_for_action", false))
		if wait:
			advance_step()
	return true

func skip_tutorial() -> void:
	stop_overlay()
	tutorial_skipped.emit()

func complete_tutorial() -> void:
	stop_overlay()
	tutorial_completed.emit()

func stop_overlay() -> void:
	is_running = false
	current_step_index = -1
	active_steps.clear()
	if active_overlay != null and is_instance_valid(active_overlay):
		active_overlay.queue_free()
	active_overlay = null
