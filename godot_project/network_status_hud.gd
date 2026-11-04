# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## CanvasLayer overlay para el estado de la red (Conectado, Reconectando, Desconectado).
class_name NetworkStatusHUD
extends CanvasLayer

signal reconnect_failed

const MAX_RECONNECT_ATTEMPTS: int = 5

enum State { CONNECTED, RECONNECTING, DISCONNECTED }

var current_state: State = State.CONNECTED
var current_attempt: int = 1
var max_attempts: int = MAX_RECONNECT_ATTEMPTS
var expelled_to_menu: bool = false
var return_to_menu_on_exhausted: bool = true

var panel: PanelContainer
var label: Label
var style_box: StyleBoxFlat
var blink_time: float = 0.0

func _ready() -> void:
	layer = 95
	_build_ui()
	set_state(State.CONNECTED)

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 36)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = 8
	panel.offset_bottom = 44

	style_box = StyleBoxFlat.new()
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	style_box.content_margin_top = 6
	style_box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style_box)

	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)

	add_child(panel)

func setup(p_bridge: Node) -> void:
	bind_bridge(p_bridge)

func bind_bridge(bridge: Node) -> void:
	if bridge == null:
		return

	if bridge.has_signal("connection_reconnecting"):
		var cb_reconn := Callable(self, "_on_connection_reconnecting")
		if not bridge.is_connected("connection_reconnecting", cb_reconn):
			bridge.connect("connection_reconnecting", cb_reconn)
	if bridge.has_signal("connection_restored"):
		var cb_restored := Callable(self, "_on_connection_restored")
		if not bridge.is_connected("connection_restored", cb_restored):
			bridge.connect("connection_restored", cb_restored)
	if bridge.has_signal("connection_lost"):
		var cb_lost := Callable(self, "_on_connection_lost")
		if not bridge.is_connected("connection_lost", cb_lost):
			bridge.connect("connection_lost", cb_lost)
	if bridge.has_signal("disconnected"):
		var cb_disc := Callable(self, "_on_disconnected")
		if not bridge.is_connected("disconnected", cb_disc):
			bridge.connect("disconnected", cb_disc)
	if bridge.has_signal("reconnecting"):
		var cb_legacy_reconn := Callable(self, "_on_reconnecting")
		if not bridge.is_connected("reconnecting", cb_legacy_reconn):
			bridge.connect("reconnecting", cb_legacy_reconn)
	if bridge.has_signal("reconnected"):
		var cb_legacy_restored := Callable(self, "_on_reconnected")
		if not bridge.is_connected("reconnected", cb_legacy_restored):
			bridge.connect("reconnected", cb_legacy_restored)
	if bridge.has_signal("connected"):
		var cb_conn := Callable(self, "_on_connected")
		if not bridge.is_connected("connected", cb_conn):
			bridge.connect("connected", cb_conn)

func format_reconnecting_banner(attempt: int, total: int = MAX_RECONNECT_ATTEMPTS) -> String:
	return "Reconectando (intento %d/%d)..." % [clampi(attempt, 1, total), total]

func set_state(state: State) -> void:
	current_state = state
	match current_state:
		State.CONNECTED:
			style_box.bg_color = Color(0.18, 0.65, 0.32, 0.95)
			label.text = "🟢 " + tr("STATUS_CONNECTED")
			panel.modulate.a = 1.0
		State.RECONNECTING:
			if current_attempt <= 0:
				current_attempt = 1
			style_box.bg_color = Color(0.9, 0.68, 0.1, 0.95)
			label.text = format_reconnecting_banner(current_attempt, max_attempts)
			blink_time = 0.0
			visible = true
			if panel != null:
				panel.visible = true
		State.DISCONNECTED:
			style_box.bg_color = Color(0.85, 0.22, 0.22, 0.95)
			label.text = "🔴 " + tr("STATUS_DISCONNECTED")
			panel.modulate.a = 1.0
			visible = true
			if panel != null:
				panel.visible = true

func _on_connection_reconnecting(attempt: int) -> void:
	current_attempt = clampi(attempt, 1, max_attempts)
	expelled_to_menu = false
	set_state(State.RECONNECTING)

func _on_connection_restored() -> void:
	current_attempt = 0
	expelled_to_menu = false
	set_state(State.CONNECTED)
	if panel != null:
		panel.visible = false
	visible = false

func _on_connection_lost() -> void:
	_on_connection_reconnecting(1)

func _on_disconnected() -> void:
	set_state(State.DISCONNECTED)
	expelled_to_menu = true
	reconnect_failed.emit()
	if return_to_menu_on_exhausted and is_inside_tree():
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://main.tscn")
		elif get_tree():
			if is_inside_tree():
				get_tree().change_scene_to_file("res://main.tscn")

func _on_reconnecting(attempt: int = 1) -> void:
	_on_connection_reconnecting(attempt)

func _on_reconnected(_arg = null) -> void:
	_on_connection_restored()

func _on_connected(_arg = null) -> void:
	set_state(State.CONNECTED)

func _process(delta: float) -> void:
	if current_state == State.RECONNECTING:
		blink_time += delta * 6.0
		panel.modulate.a = 0.3 + 0.7 * abs(sin(blink_time))
	else:
		panel.modulate.a = 1.0

