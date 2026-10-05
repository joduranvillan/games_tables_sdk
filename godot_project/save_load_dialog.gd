extends Control

signal save_requested(save_id: String, metadata: Dictionary)
signal load_requested(save_id: String, metadata: Dictionary)
signal delete_requested(save_id: String)
signal closed()

var save_manager: Node = null
var bridge: Node = null
var current_game_id: String = "chess"
var current_turn_number: int = 1
var current_players: Array = [
	{"id": 1, "name": "Jugador 1", "score": 0},
	{"id": 2, "name": "Jugador 2", "score": 0},
]

var slot_input: LineEdit
var save_button: Button
var saves_vbox: VBoxContainer
var status_label: Label
var close_button: Button

func _ready() -> void:
	_ensure_save_manager()
	_setup_ui()
	refresh_saves_list()

func _ensure_save_manager() -> void:
	if save_manager != null and is_instance_valid(save_manager):
		return
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")
	else:
		var script = load("res://scripts/save_manager.gd")
		if script != null:
			save_manager = script.new()
			add_child(save_manager)

func setup(
	p_save_manager: Node = null,
	p_bridge: Node = null,
	p_game_id: String = "chess",
	p_turn_number: int = 1,
	p_players: Array = []
) -> void:
	if p_save_manager != null:
		save_manager = p_save_manager
	else:
		_ensure_save_manager()
	bridge = p_bridge
	if not p_game_id.strip_edges().is_empty():
		current_game_id = p_game_id
	if p_turn_number >= 0:
		current_turn_number = p_turn_number
	if not p_players.is_empty():
		current_players = p_players
	if save_manager != null and save_manager.has_method("set_context"):
		save_manager.call("set_context", bridge, current_game_id, current_turn_number, current_players)
	refresh_saves_list()

func _setup_ui() -> void:
	if slot_input != null:
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.06, 0.09, 0.75)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 460)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.19, 0.98)
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
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "💾 Gestor de Partidas Guardadas"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 10)
	vbox.add_child(save_row)

	slot_input = LineEdit.new()
	slot_input.name = "SlotInput"
	slot_input.placeholder_text = "Nombre de la ranura (ej. Partida 1)..."
	slot_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_input.custom_minimum_size = Vector2(260, 38)
	save_row.add_child(slot_input)

	save_button = Button.new()
	save_button.name = "SaveButton"
	save_button.text = "Guardar Partida"
	save_button.custom_minimum_size = Vector2(150, 38)
	save_button.pressed.connect(_on_save_button_pressed)
	save_row.add_child(save_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	saves_vbox = VBoxContainer.new()
	saves_vbox.name = "SavesVBox"
	saves_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(saves_vbox)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Cerrar"
	close_button.custom_minimum_size = Vector2(120, 38)
	close_button.pressed.connect(func():
		hide()
		closed.emit()
	)
	vbox.add_child(close_button)

func _on_save_button_pressed() -> void:
	var slot_name := slot_input.text.strip_edges() if slot_input != null else ""
	if slot_name.is_empty():
		slot_name = "Ranura %d" % (save_manager.list_saves().size() + 1 if save_manager != null else 1)
	save_slot(slot_name)

func save_slot(slot_name: String) -> String:
	_ensure_save_manager()
	if save_manager == null:
		return ""
	var sid: String = save_manager.save_game(
		slot_name,
		bridge,
		current_game_id,
		current_turn_number,
		current_players
	)
	if status_label != null:
		status_label.text = "Partida guardada: %s (%s)" % [slot_name, sid]
	refresh_saves_list()
	return sid

func load_slot(save_id: String) -> Dictionary:
	_ensure_save_manager()
	if save_manager == null:
		return {}
	var data: Dictionary = save_manager.load_game(save_id, bridge)
	if not data.is_empty():
		if status_label != null:
			status_label.text = "Partida cargada: %s" % str(data.get("slot_name", save_id))
		load_requested.emit(save_id, data)
	return data

func delete_slot(save_id: String) -> bool:
	_ensure_save_manager()
	if save_manager == null:
		return false
	var ok: bool = save_manager.delete_save(save_id)
	if ok:
		if status_label != null:
			status_label.text = "Partida eliminada: %s" % save_id
		delete_requested.emit(save_id)
		refresh_saves_list()
	return ok

func refresh_saves_list() -> void:
	_ensure_save_manager()
	if saves_vbox == null or save_manager == null:
		return

	for child in saves_vbox.get_children():
		child.queue_free()

	var entries: Array = save_manager.list_saves()
	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No hay partidas guardadas."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		saves_vbox.add_child(empty_lbl)
		return

	for entry in entries:
		var sid := str(entry.get("save_id", ""))
		var sname := str(entry.get("slot_name", sid))
		var gid := str(entry.get("game_id", "chess"))
		var turn_num := int(entry.get("turn_number", 1))
		var ts := str(entry.get("timestamp", ""))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		saves_vbox.add_child(row)

		var info := Label.new()
		info.text = "%s | %s (Turno %d) — %s" % [sname, gid, turn_num, ts]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var load_btn := Button.new()
		load_btn.text = "Cargar"
		load_btn.pressed.connect(func(): load_slot(sid))
		row.add_child(load_btn)

		var del_btn := Button.new()
		del_btn.text = "Eliminar"
		del_btn.pressed.connect(func(): delete_slot(sid))
		row.add_child(del_btn)
