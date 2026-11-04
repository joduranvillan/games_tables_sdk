# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name TouchCameraController
extends Camera2D

const MIN_ZOOM: float = 0.8
const MAX_ZOOM: float = 2.5

@export var pan_bounds: Rect2 = Rect2(-320.0, -240.0, 1280.0, 960.0)
@export var zoom_smoothing: float = 14.0

var touch_points: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: float = 1.0
var target_zoom_factor: float = 1.0
var target_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	zoom = Vector2(target_zoom_factor, target_zoom_factor)
	offset = target_offset

func _process(delta: float) -> void:
	var weight := clampf(delta * zoom_smoothing, 0.0, 1.0)
	var next_z := lerpf(zoom.x, target_zoom_factor, weight)
	zoom = Vector2(next_z, next_z)
	offset = offset.lerp(target_offset, weight)

func _input(event: InputEvent) -> void:
	handle_touch_event(event)

func handle_touch_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() == 2:
				var keys := touch_points.keys()
				var p0: Vector2 = touch_points[keys[0]]
				var p1: Vector2 = touch_points[keys[1]]
				initial_pinch_distance = maxf(p0.distance_to(p1), 1.0)
				initial_pinch_zoom = target_zoom_factor
		else:
			touch_points.erase(event.index)
			if touch_points.size() < 2:
				initial_pinch_distance = 0.0

	elif event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			# Paneo con un dedo cuando hay zoom activo o con arrastre suave
			if target_zoom_factor > 1.01:
				apply_pan(-event.relative / target_zoom_factor)
		elif touch_points.size() >= 2:
			var keys := touch_points.keys()
			var p0: Vector2 = touch_points[keys[0]]
			var p1: Vector2 = touch_points[keys[1]]
			var cur_dist := maxf(p0.distance_to(p1), 1.0)
			var pinch_center := (p0 + p1) * 0.5
			if initial_pinch_distance <= 0.0:
				initial_pinch_distance = cur_dist
				initial_pinch_zoom = target_zoom_factor
			var ratio := cur_dist / initial_pinch_distance
			var desired_zoom := clampf(initial_pinch_zoom * ratio, MIN_ZOOM, MAX_ZOOM)
			set_zoom_anchored(desired_zoom, pinch_center)
			apply_pan(-event.relative * 0.5 / target_zoom_factor)

	elif event is InputEventMagnifyGesture:
		var desired_zoom := clampf(target_zoom_factor * event.factor, MIN_ZOOM, MAX_ZOOM)
		set_zoom_anchored(desired_zoom, event.position)

	elif event is InputEventPanGesture:
		apply_pan(event.delta * 16.0 / target_zoom_factor)

func set_zoom_anchored(new_zoom: float, anchor_screen_pos: Vector2) -> void:
	var old_zoom := maxf(target_zoom_factor, 0.001)
	var clamped_zoom := clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	# Mantener el punto bajo el centro del gesto anclado en el mundo
	var world_before := target_offset + (anchor_screen_pos / old_zoom)
	target_zoom_factor = clamped_zoom
	target_offset = world_before - (anchor_screen_pos / target_zoom_factor)
	_clamp_offset()
	zoom = Vector2(target_zoom_factor, target_zoom_factor)
	offset = target_offset

func apply_pan(delta_world: Vector2) -> void:
	target_offset += delta_world
	_clamp_offset()
	offset = target_offset

func reset_view() -> void:
	target_zoom_factor = 1.0
	target_offset = Vector2.ZERO
	zoom = Vector2.ONE
	offset = Vector2.ZERO

func _clamp_offset() -> void:
	var min_x := pan_bounds.position.x
	var max_x := pan_bounds.position.x + pan_bounds.size.x
	var min_y := pan_bounds.position.y
	var max_y := pan_bounds.position.y + pan_bounds.size.y
	target_offset.x = clampf(target_offset.x, min_x, max_x)
	target_offset.y = clampf(target_offset.y, min_y, max_y)
