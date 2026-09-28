extends Control

var bridge: Node
var _log: RichTextLabel

func setup(p_bridge: Node) -> void:
	bridge = p_bridge
	if bridge.has_signal("spectator_event"):
		if not bridge.is_connected("spectator_event", _on_spectator_event):
			bridge.connect("spectator_event", _on_spectator_event)
	if bridge.has_signal("spectator_event_received"):
		if not bridge.is_connected("spectator_event_received", _on_spectator_event):
			bridge.connect("spectator_event_received", _on_spectator_event)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var title := Label.new()
	title.text = "Modo Espectador"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_log)

	var back := Button.new()
	back.text = "← Salir"
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(func():
		if has_node("/root/SceneManager"):
			get_node("/root/SceneManager").transition_to("res://main.tscn")
		else:
			get_tree().change_scene_to_file("res://main.tscn")
	)
	vbox.add_child(back)

func _on_spectator_event(event_json: String) -> void:
	if _log != null:
		_log.append_text("[color=cyan]%s[/color]\n" % event_json)
