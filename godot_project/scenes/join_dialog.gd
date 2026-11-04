# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Control

signal code_submitted(room_code: String)
signal join_completed(success: bool, player_id: int)
signal closed()

const VALID_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 4

@export var relay_url: String = "ws://127.0.0.1:8080"

var bridge: Node = null
var code_input: LineEdit
var connect_button: Button
var cancel_button: Button
var status_label: Label

func _ready() -> void:
	_setup_ui()

func setup(p_bridge: Node, p_relay_url: String = "ws://127.0.0.1:8080") -> void:
	bridge = p_bridge
	if not p_relay_url.strip_edges().is_empty():
		relay_url = p_relay_url
	_connect_bridge_signals()

func open(p_bridge: Node = null) -> void:
	if p_bridge != null:
		setup(p_bridge, relay_url)
	show()
	if code_input != null:
		code_input.grab_focus()

func close() -> void:
	hide()
	closed.emit()

func _connect_bridge_signals() -> void:
	if bridge == null:
		return
	if bridge.has_signal("room_joined"):
		var cb := Callable(self, "_on_bridge_room_joined")
		if not bridge.is_connected("room_joined", cb):
			bridge.connect("room_joined", cb)

func _setup_ui() -> void:
	if code_input != null:
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.06, 0.09, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.20, 0.98)
	style.border_color = Color(0.35, 0.65, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🔑 Unirse a Sala en Línea"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Ingresa el código de invitación de 4 caracteres:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(subtitle)

	code_input = LineEdit.new()
	code_input.name = "CodeInput"
	code_input.placeholder_text = "ABCD"
	code_input.max_length = CODE_LENGTH
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.custom_minimum_size = Vector2(220, 52)
	code_input.add_theme_font_size_override("font_size", 28)
	code_input.text_changed.connect(_on_code_text_changed)
	code_input.text_submitted.connect(func(_txt: String): _on_connect_pressed())
	vbox.add_child(code_input)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	connect_button = Button.new()
	connect_button.name = "ConnectButton"
	connect_button.text = "Conectar"
	connect_button.custom_minimum_size = Vector2(140, 44)
	connect_button.disabled = true
	connect_button.pressed.connect(_on_connect_pressed)
	btn_row.add_child(connect_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "Cancelar"
	cancel_button.custom_minimum_size = Vector2(120, 44)
	cancel_button.pressed.connect(close)
	btn_row.add_child(cancel_button)

func sanitize_room_code(raw: String) -> String:
	var upper := raw.to_upper()
	var cleaned := ""
	for i in range(upper.length()):
		var ch := upper.substr(i, 1)
		if VALID_CHARS.contains(ch):
			cleaned += ch
			if cleaned.length() >= CODE_LENGTH:
				break
	return cleaned

func set_code(raw: String) -> void:
	if code_input == null:
		_setup_ui()
	_on_code_text_changed(raw)

func get_code() -> String:
	if code_input == null:
		return ""
	return code_input.text

func _on_code_text_changed(new_text: String) -> void:
	var sanitized := sanitize_room_code(new_text)
	if code_input != null and code_input.text != sanitized:
		code_input.text = sanitized
		code_input.caret_column = sanitized.length()
	if connect_button != null:
		connect_button.disabled = (sanitized.length() != CODE_LENGTH)

func _on_connect_pressed() -> void:
	if code_input == null:
		return
	var code := sanitize_room_code(code_input.text)
	if code.length() != CODE_LENGTH:
		if status_label != null:
			status_label.text = "Código inválido (debe tener 4 caracteres)"
		return

	if status_label != null:
		status_label.text = "Conectando a sala %s..." % code

	code_submitted.emit(code)

	if bridge != null:
		_connect_bridge_signals()
		if (is_inside_tree() and has_node("/root/AuthClient")):
			get_node("/root/AuthClient").call("configure_bridge_auth", bridge)
		if bridge.has_method("connect_to_relay"):
			bridge.call("connect_to_relay", relay_url)
		if bridge.has_method("join_relay_room"):
			bridge.call("join_relay_room", code)

func _on_bridge_room_joined(success: bool, player_id: int) -> void:
	if status_label != null:
		if success:
			status_label.text = "¡Unido como Jugador %d!" % player_id
		else:
			status_label.text = "No se pudo unir a la sala"
	join_completed.emit(success, player_id)
