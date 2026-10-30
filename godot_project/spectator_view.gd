extends Control

signal spectating_started(room_code: String, player_count: int)
signal relay_event_applied(event_data: Variant)
signal relay_error_received(reason: String)

const MAX_SPECTATORS := 10
const VALID_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 4

@export var relay_url: String = "ws://127.0.0.1:8080"

var bridge: Node
var room_code: String = ""
var is_relay_spectator: bool = false
var player_count: int = 0
var last_error_reason: String = ""
var applied_relay_events: Array = []

var _ws: WebSocketPeer = null
var _room_code_input: LineEdit
var _join_spectator_button: Button
var _status_label: Label
var _log: RichTextLabel

func setup(p_bridge: Node, p_relay_url: String = "ws://127.0.0.1:8080") -> void:
	bridge = p_bridge
	if not p_relay_url.strip_edges().is_empty():
		relay_url = p_relay_url
	if bridge != null:
		if bridge.has_signal("spectator_event"):
			if not bridge.is_connected("spectator_event", _on_spectator_event):
				bridge.connect("spectator_event", _on_spectator_event)
		if bridge.has_signal("spectator_event_received"):
			if not bridge.is_connected("spectator_event_received", _on_spectator_event):
				bridge.connect("spectator_event_received", _on_spectator_event)

func _ready() -> void:
	_build_ui()

func _process(_delta: float) -> void:
	if _ws != null:
		_ws.poll()
		var state := _ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while _ws.get_available_packet_count() > 0:
				var pkt := _ws.get_packet()
				var text := pkt.get_string_from_utf8()
				receive_relay_message(text)
	if bridge != null and bridge.has_method("poll_events"):
		bridge.poll_events()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "Modo Espectador (Online Relay)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 10)
	vbox.add_child(top_bar)

	_room_code_input = LineEdit.new()
	_room_code_input.name = "RoomCodeInput"
	_room_code_input.placeholder_text = "Código de sala (ej. XKCD)"
	_room_code_input.max_length = CODE_LENGTH
	_room_code_input.custom_minimum_size = Vector2(200, 40)
	top_bar.add_child(_room_code_input)

	_join_spectator_button = Button.new()
	_join_spectator_button.name = "JoinSpectatorButton"
	_join_spectator_button.text = "👁 Observar Sala Relay"
	_join_spectator_button.custom_minimum_size = Vector2(180, 40)
	_join_spectator_button.pressed.connect(_on_join_spectator_pressed)
	top_bar.add_child(_join_spectator_button)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "Ingresa un código de 4 caracteres para observar la partida en vivo."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_log)

	var back := Button.new()
	back.text = "← Salir"
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(func():
		if (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://main.tscn")
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file("res://main.tscn")
	)
	vbox.add_child(back)

func _on_join_spectator_pressed() -> void:
	if _room_code_input == null:
		return
	join_relay_spectator(_room_code_input.text, relay_url)

func build_join_spectator_request(code: String) -> Dictionary:
	return {
		"op": "join_spectator",
		"room_code": code.strip_edges().to_upper(),
	}

func join_relay_spectator(code: String, url: String = "") -> String:
	room_code = code.strip_edges().to_upper()
	if not url.strip_edges().is_empty():
		relay_url = url.strip_edges()

	var req := build_join_spectator_request(room_code)
	var payload := JSON.stringify(req)

	if _ws == null:
		_ws = WebSocketPeer.new()
	if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_ws.connect_to_url(relay_url)
	elif _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(payload)

	if _status_label != null:
		_status_label.text = "Conectando como espectador a la sala %s..." % room_code
	if _log != null:
		_log.append_text("[color=gray]→ %s[/color]\n" % payload)
	return payload

func send_relay_command(_data: Variant) -> Dictionary:
	# Los espectadores tienen permisos de solo lectura y no pueden enviar op: "relay"
	last_error_reason = "spectator_cannot_relay"
	var err_resp := {
		"op": "error",
		"reason": "spectator_cannot_relay",
	}
	receive_relay_message(JSON.stringify(err_resp))
	return err_resp

func receive_relay_message(raw_json: String) -> bool:
	var parsed = JSON.parse_string(raw_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	var msg: Dictionary = parsed
	var op: String = str(msg.get("op", ""))
	match op:
		"spectating":
			is_relay_spectator = true
			player_count = int(msg.get("player_count", 0))
			if _status_label != null:
				_status_label.text = "Observando sala %s (%d jugadores en partida)" % [room_code, player_count]
			if _log != null:
				_log.append_text("[color=green]✓ Espectando sala %s (jugadores: %d)[/color]\n" % [room_code, player_count])
			spectating_started.emit(room_code, player_count)
			return true
		"relay":
			var event_data = msg.get("data", null)
			var from_pid: int = int(msg.get("from", 0))
			apply_relay_event(event_data, from_pid)
			return true
		"error":
			var reason: String = str(msg.get("reason", msg.get("message", "unknown_error")))
			last_error_reason = reason
			if _status_label != null:
				if reason == "spectator_limit":
					_status_label.text = "Error: Límite de espectadores alcanzado (%d máx.)" % MAX_SPECTATORS
				elif reason == "spectator_cannot_relay":
					_status_label.text = "Error: Los espectadores no tienen permiso para enviar movimientos"
				else:
					_status_label.text = "Error Relay: %s" % reason
			if _log != null:
				_log.append_text("[color=red]✖ Error Relay: %s[/color]\n" % reason)
			relay_error_received.emit(reason)
			return false
		_:
			return false

func apply_relay_event(event_data: Variant, from_player: int = 0) -> void:
	applied_relay_events.append({
		"from": from_player,
		"data": event_data,
	})
	var serialized: String = str(event_data) if typeof(event_data) == TYPE_STRING else JSON.stringify(event_data)
	if bridge != null and bridge.has_method("apply_spectator_event"):
		bridge.call("apply_spectator_event", serialized)
	_on_spectator_event(serialized)
	relay_event_applied.emit(event_data)

func _on_spectator_event(event_json: String) -> void:
	if _log != null:
		_log.append_text("[color=cyan]%s[/color]\n" % event_json)
