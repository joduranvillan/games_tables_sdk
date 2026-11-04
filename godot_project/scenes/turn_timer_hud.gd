# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name TurnTimerHud
extends HBoxContainer

## Reloj visual de turno con barra regresiva, contador MM:SS, parpadeo en ámbar/rojo
## y pulso sonoro suave en los últimos 10 segundos. Si está activo y llega a 00:00
## en modo local/vs IA, adjudica la victoria al rival.

signal turn_timeout(expired_player_id: int, winner_player_id: int)
signal low_time_warning(seconds_left: int)

const COLOR_NORMAL_TEXT := Color(0.92, 0.96, 1.0, 1.0)
const COLOR_NORMAL_BAR := Color(0.30, 0.82, 0.55, 1.0)
const COLOR_WARNING_AMBER := Color(1.0, 0.72, 0.15, 1.0)
const COLOR_WARNING_RED := Color(1.0, 0.22, 0.20, 1.0)

@export var timer_enabled: bool = true
@export var duration_seconds: float = 30.0

var time_left: float = 30.0
var is_running: bool = false
var current_player_id: int = 1
var is_warning_state: bool = false
var current_alert_color: Color = COLOR_NORMAL_TEXT
var blink_phase: float = 0.0
var last_tick_second: int = -1
var last_winner_id: int = -1

var progress_bar: ProgressBar
var time_label: Label
var bridge_node: Object = null
var audio_manager_ref: Node = null
var game_over_overlay_ref: Node = null

func _init() -> void:
	name = "TurnTimerHud"
	custom_minimum_size = Vector2(68, 26)
	add_theme_constant_override("separation", 6)
	_ensure_ui()

func _ready() -> void:
	_ensure_ui()
	_update_visuals(0.0)

func _ensure_ui() -> void:
	if progress_bar == null:
		progress_bar = get_node_or_null("TimerProgressBar")
		if progress_bar == null:
			progress_bar = ProgressBar.new()
			progress_bar.name = "TimerProgressBar"
			progress_bar.custom_minimum_size = Vector2(54, 8)
			progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			progress_bar.show_percentage = false
			progress_bar.min_value = 0.0
			progress_bar.max_value = maxf(duration_seconds, 1.0)
			progress_bar.value = time_left
			progress_bar.visible = false
			add_child(progress_bar)

	if time_label == null:
		time_label = get_node_or_null("TimeLabel")
		if time_label == null:
			time_label = Label.new()
			time_label.name = "TimeLabel"
			time_label.custom_minimum_size = Vector2(64, 24)
			time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			time_label.add_theme_font_size_override("font_size", 14)
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = Color(0.12, 0.15, 0.22, 0.88)
			badge_style.border_color = Color(0.32, 0.42, 0.58, 0.75)
			badge_style.set_border_width_all(1)
			badge_style.set_corner_radius_all(6)
			badge_style.content_margin_left = 8
			badge_style.content_margin_right = 8
			badge_style.content_margin_top = 2
			badge_style.content_margin_bottom = 2
			time_label.add_theme_stylebox_override("normal", badge_style)
			time_label.text = format_mm_ss(time_left)
			add_child(time_label)

static func format_mm_ss(seconds: float) -> String:
	if seconds <= 0.0:
		return "00:00"
	var total_sec := maxi(0, int(ceil(seconds)))
	var mins := int(floor(float(total_sec) / 60.0))
	var secs := total_sec % 60
	return "%02d:%02d" % [mins, secs]

func bind_bridge(p_bridge: Object) -> void:
	if bridge_node != null and bridge_node.has_signal("turn_changed") and bridge_node.is_connected("turn_changed", _on_bridge_turn_changed):
		bridge_node.disconnect("turn_changed", _on_bridge_turn_changed)
	bridge_node = p_bridge
	if bridge_node != null and bridge_node.has_signal("turn_changed"):
		if not bridge_node.is_connected("turn_changed", _on_bridge_turn_changed):
			bridge_node.connect("turn_changed", _on_bridge_turn_changed)

func _on_bridge_turn_changed(player_id: int) -> void:
	if player_id > 0:
		start_turn_timer(player_id, duration_seconds)

func start_turn_timer(player_id: int = 1, custom_duration: float = -1.0) -> void:
	_ensure_ui()
	current_player_id = player_id if player_id > 0 else 1
	if custom_duration > 0.0:
		duration_seconds = custom_duration
	time_left = maxf(0.0, duration_seconds)
	is_running = timer_enabled and duration_seconds > 0.0
	is_warning_state = false
	blink_phase = 0.0
	last_tick_second = -1
	last_winner_id = -1
	_update_visuals(0.0)

func stop_turn_timer() -> void:
	is_running = false
	is_warning_state = false
	_update_visuals(0.0)

func reset_turn_timer() -> void:
	start_turn_timer(current_player_id, duration_seconds)

func _process(delta: float) -> void:
	advance_timer(delta)

func advance_timer(delta: float) -> void:
	if not is_running or not timer_enabled:
		return

	time_left = maxf(0.0, time_left - delta)
	_update_visuals(delta)

	if time_left <= 10.0 and time_left > 0.0:
		var sec_remaining := int(ceil(time_left))
		if sec_remaining != last_tick_second:
			last_tick_second = sec_remaining
			low_time_warning.emit(sec_remaining)
			_play_warning_pulse()

	if time_left <= 0.0:
		time_left = 0.0
		is_running = false
		_update_visuals(0.0)
		_adjudicate_timeout()

func _update_visuals(delta: float) -> void:
	_ensure_ui()
	progress_bar.max_value = maxf(duration_seconds, 1.0)
	progress_bar.value = clampf(time_left, 0.0, progress_bar.max_value)
	time_label.text = format_mm_ss(time_left)

	if time_left <= 10.0 and (is_running or time_left == 0.0):
		is_warning_state = true
		blink_phase += delta * 8.0
		var weight := 0.5 + 0.5 * sin(blink_phase)
		current_alert_color = COLOR_WARNING_AMBER.lerp(COLOR_WARNING_RED, weight)
		time_label.add_theme_color_override("font_color", current_alert_color)
		progress_bar.modulate = current_alert_color
	else:
		is_warning_state = false
		current_alert_color = COLOR_NORMAL_TEXT
		time_label.add_theme_color_override("font_color", COLOR_NORMAL_TEXT)
		progress_bar.modulate = COLOR_NORMAL_BAR

func _resolve_audio_manager() -> Node:
	if audio_manager_ref != null and is_instance_valid(audio_manager_ref):
		return audio_manager_ref
	if is_inside_tree() and has_node("/root/AudioManager"):
		return get_node("/root/AudioManager")
	return null

func _play_warning_pulse() -> void:
	var am := _resolve_audio_manager()
	if am != null:
		if am.has_method("play_timer_tick"):
			am.call("play_timer_tick")
		elif am.has_method("play_turn_notify"):
			am.call("play_turn_notify")

func _adjudicate_timeout() -> void:
	var winner_id: int = 2 if current_player_id == 1 else 1
	if bridge_node != null and bridge_node.has_method("resign_match"):
		var res = bridge_node.call("resign_match", current_player_id)
		if typeof(res) == TYPE_INT and int(res) > 0:
			winner_id = int(res)
	last_winner_id = winner_id
	turn_timeout.emit(current_player_id, winner_id)

	if game_over_overlay_ref != null and is_instance_valid(game_over_overlay_ref):
		if game_over_overlay_ref.has_method("show_result"):
			game_over_overlay_ref.call("show_result", winner_id, false)
		elif game_over_overlay_ref.has_method("show_winner"):
			game_over_overlay_ref.call("show_winner", winner_id)
