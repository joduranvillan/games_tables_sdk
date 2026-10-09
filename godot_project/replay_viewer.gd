class_name ReplayViewer
extends Control

const PLAYBACK_SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var raw_log_bytes: PackedByteArray = PackedByteArray()
var game_type: String = "checkers"
var total_steps: int = 0
var current_step: int = 0
var is_playing: bool = false
var playback_speed: float = 1.0
var play_timer: Timer
var parsed_commands: Array = []

var board_instance: Node = null
var bridge: Node = null

var content_hbox: HBoxContainer
var board_container: Control
var move_list_panel: PanelContainer
var move_list_scroll: ScrollContainer
var move_list_vbox: VBoxContainer
var move_row_nodes: Array[Control] = []

var status_label: Label
var step_label: Label
var step_slider: HSlider
var btn_start: Button
var btn_prev: Button
var btn_play_pause: Button
var btn_next: Button
var btn_end: Button
var speed_selector: OptionButton
var game_type_option: OptionButton
var btn_import_replay: Button
var btn_export_replay: Button
var file_dialog: FileDialog
var import_otr_dialog: FileDialog
var export_otr_dialog: FileDialog
var player_names: Array[String] = ["Jugador 1", "Jugador 2"]

const GAME_SCENES = {
	"checkers": "res://checkers_board.tscn",
	"chess": "res://chess_board.tscn",
	"shogi": "res://shogi_board.tscn",
	"xiangqi": "res://xiangqi_board.tscn",
	"go": "res://go_board.tscn",
	"uno": "res://uno_board.tscn",
	"crisis": "res://crisis_board.tscn",
	"chinese_checkers": "res://chinese_checkers_board.tscn",
	"mille_bornes": "res://mille_bornes_board.tscn",
	"backgammon": "res://backgammon_board.tscn",
	"monopoly": "res://monopoly_board.tscn",
	"ludo": "res://ludo_board.tscn",
	"battleship": "res://battleship_board.tscn"
}

func _ready() -> void:
	_setup_ui()
	_setup_timer()

	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	var bytes: PackedByteArray = gm.get_replay_log_bytes() if gm != null and gm.has_method("get_replay_log_bytes") else PackedByteArray()
	var gtype: String = gm.get_replay_game_type() if gm != null and gm.has_method("get_replay_game_type") else "checkers"
	if bytes.size() > 0:
		load_replay_data(bytes, gtype)
	else:
		_update_status("Selecciona o carga un archivo .otlog para reproducir")

func _setup_timer() -> void:
	if play_timer != null:
		return
	play_timer = Timer.new()
	play_timer.wait_time = 1.0 / playback_speed
	play_timer.one_shot = false
	play_timer.timeout.connect(_on_play_timer_timeout)
	add_child(play_timer)

func _setup_ui() -> void:
	if step_slider != null:
		return

	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Top Panel
	var top_panel = PanelContainer.new()
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 15)

	var title_lbl = Label.new()
	title_lbl.text = " 🎬 Visor Interactivo de Repeticiones"
	title_lbl.add_theme_font_size_override("font_size", 20)

	var btn_open = Button.new()
	btn_open.text = "📂 Cargar Archivo .otlog"
	btn_open.pressed.connect(_on_open_file_pressed)

	btn_import_replay = Button.new()
	btn_import_replay.name = "BtnImportReplay"
	btn_import_replay.text = "Importar Replay"
	btn_import_replay.pressed.connect(_on_import_replay_pressed)

	btn_export_replay = Button.new()
	btn_export_replay.name = "BtnExportReplay"
	btn_export_replay.text = "Exportar Replay (.otr)"
	btn_export_replay.pressed.connect(_on_export_replay_pressed)

	game_type_option = OptionButton.new()
	for gt in GAME_SCENES.keys():
		game_type_option.add_item(gt.capitalize(), GAME_SCENES.keys().find(gt))
	game_type_option.item_selected.connect(_on_game_type_selected)

	var btn_back = Button.new()
	btn_back.text = "← Volver al Menú"
	btn_back.pressed.connect(_on_back_pressed)

	top_hbox.add_child(title_lbl)
	top_hbox.add_child(btn_open)
	top_hbox.add_child(btn_import_replay)
	top_hbox.add_child(btn_export_replay)
	top_hbox.add_child(game_type_option)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)
	top_hbox.add_child(btn_back)
	top_panel.add_child(top_hbox)
	main_vbox.add_child(top_panel)

	# Center Area: Board + Side Panel with Move List
	content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(content_hbox)

	board_container = Control.new()
	board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(board_container)

	# Panel lateral con lista de movimientos y scroll automático al turno activo
	move_list_panel = PanelContainer.new()
	move_list_panel.name = "MoveListPanel"
	move_list_panel.custom_minimum_size = Vector2(280, 0)
	move_list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(move_list_panel)

	var side_vbox = VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 8)
	move_list_panel.add_child(side_vbox)

	var side_title = Label.new()
	side_title.text = "📜 Historial de Movimientos"
	side_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side_title.add_theme_font_size_override("font_size", 16)
	side_vbox.add_child(side_title)

	move_list_scroll = ScrollContainer.new()
	move_list_scroll.name = "MoveListScroll"
	move_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	move_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(move_list_scroll)

	move_list_vbox = VBoxContainer.new()
	move_list_vbox.name = "MoveListVBox"
	move_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_list_vbox.add_theme_constant_override("separation", 4)
	move_list_scroll.add_child(move_list_vbox)

	# Status Label
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(status_label)

	# Bottom Playback Controls Panel
	var bottom_panel = PanelContainer.new()
	var bottom_vbox = VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 8)

	var controls_hbox = HBoxContainer.new()
	controls_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_hbox.add_theme_constant_override("separation", 12)

	btn_start = Button.new()
	btn_start.name = "BtnStart"
	btn_start.text = "⏮ Inicio"
	btn_start.custom_minimum_size = Vector2(95, 40)
	btn_start.pressed.connect(_on_start_pressed)

	btn_prev = Button.new()
	btn_prev.name = "BtnPrev"
	btn_prev.text = "◀ Paso Anterior"
	btn_prev.custom_minimum_size = Vector2(130, 40)
	btn_prev.pressed.connect(_on_prev_pressed)

	btn_play_pause = Button.new()
	btn_play_pause.name = "BtnPlayPause"
	btn_play_pause.text = "▶/⏸ Play/Pausa"
	btn_play_pause.custom_minimum_size = Vector2(140, 40)
	btn_play_pause.pressed.connect(_on_play_pause_pressed)

	btn_next = Button.new()
	btn_next.name = "BtnNext"
	btn_next.text = "▶ Paso Siguiente"
	btn_next.custom_minimum_size = Vector2(135, 40)
	btn_next.pressed.connect(_on_next_pressed)

	btn_end = Button.new()
	btn_end.name = "BtnEnd"
	btn_end.text = "⏭ Fin"
	btn_end.custom_minimum_size = Vector2(90, 40)
	btn_end.pressed.connect(_on_end_pressed)

	var speed_lbl = Label.new()
	speed_lbl.text = "Velocidad:"

	speed_selector = OptionButton.new()
	speed_selector.name = "SpeedSelector"
	speed_selector.custom_minimum_size = Vector2(85, 40)
	speed_selector.add_item("1x", 0)
	speed_selector.add_item("2x", 1)
	speed_selector.add_item("4x", 2)
	speed_selector.selected = 0
	speed_selector.item_selected.connect(_on_speed_selected)

	step_label = Label.new()
	step_label.text = "Paso 0 / 0"
	step_label.add_theme_font_size_override("font_size", 16)

	controls_hbox.add_child(btn_start)
	controls_hbox.add_child(btn_prev)
	controls_hbox.add_child(btn_play_pause)
	controls_hbox.add_child(btn_next)
	controls_hbox.add_child(btn_end)
	controls_hbox.add_child(speed_lbl)
	controls_hbox.add_child(speed_selector)
	controls_hbox.add_child(step_label)

	step_slider = HSlider.new()
	step_slider.name = "TimelineSlider"
	step_slider.custom_minimum_size = Vector2(0, 30)
	step_slider.min_value = 0
	step_slider.max_value = 0
	step_slider.step = 1
	step_slider.value_changed.connect(_on_slider_value_changed)

	bottom_vbox.add_child(controls_hbox)
	bottom_vbox.add_child(step_slider)
	bottom_panel.add_child(bottom_vbox)
	main_vbox.add_child(bottom_panel)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.otr ; OpenTable Replay (*.otr)", "*.otlog ; Archivos de Replay OpenTable", "* ; Todos los archivos"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	import_otr_dialog = FileDialog.new()
	import_otr_dialog.name = "ImportOtrDialog"
	import_otr_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_otr_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_otr_dialog.filters = PackedStringArray(["*.otr ; OpenTable Replay (*.otr)"])
	import_otr_dialog.file_selected.connect(_on_otr_file_selected)
	add_child(import_otr_dialog)

	export_otr_dialog = FileDialog.new()
	export_otr_dialog.name = "ExportOtrDialog"
	export_otr_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_otr_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_otr_dialog.filters = PackedStringArray(["*.otr ; OpenTable Replay (*.otr)"])
	export_otr_dialog.file_selected.connect(_on_export_otr_file_selected)
	add_child(export_otr_dialog)

func load_replay_data(bytes: PackedByteArray, type_str: String) -> void:
	if step_slider == null:
		_setup_ui()
		_setup_timer()

	raw_log_bytes = bytes
	game_type = type_str

	var json_text = bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(json_text)
	if parsed is Array:
		parsed_commands = parsed
		total_steps = parsed.size()
	else:
		parsed_commands = []
		total_steps = 0

	step_slider.max_value = total_steps
	current_step = 0
	_populate_move_list()
	_reload_board_scene()
	seek_to_step(0)

func _format_move_entry(index: int, entry: Variant) -> String:
	if entry is Array and entry.size() >= 3 and entry[2] is Dictionary:
		var cmd: Dictionary = entry[2]
		var ctype := str(cmd.get("command_type", " Jugada"))
		var player := int(cmd.get("player", 0))
		return "#%d (J%d): %s" % [index + 1, player, ctype]
	elif entry is Dictionary:
		var ctype := str(entry.get("command_type", "Jugada"))
		return "#%d: %s" % [index + 1, ctype]
	return "Turno #%d" % (index + 1)

func _populate_move_list() -> void:
	move_row_nodes.clear()
	if move_list_vbox == null:
		return
	for child in move_list_vbox.get_children():
		move_list_vbox.remove_child(child)
		child.free()

	for i in range(parsed_commands.size()):
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = _format_move_entry(i, parsed_commands[i])
		var step_target := i + 1
		btn.pressed.connect(func(): seek_to_step(step_target))
		move_list_vbox.add_child(btn)
		move_row_nodes.append(btn)

func _reload_board_scene() -> void:
	if board_instance != null:
		if board_instance.get_parent() != null:
			board_instance.get_parent().remove_child(board_instance)
		board_instance.free()
		board_instance = null

	var scene_path = GAME_SCENES.get(game_type, "res://checkers_board.tscn")
	var scene = load(scene_path)
	if scene:
		board_instance = scene.instantiate()
		board_container.add_child(board_instance)

		if board_instance.has_node("Bridge"):
			bridge = board_instance.get_node("Bridge")
		elif "bridge" in board_instance and board_instance.bridge != null:
			bridge = board_instance.bridge
		else:
			bridge = OpenTableBridge.new()
			board_instance.add_child(bridge)

		bridge.load_replay(raw_log_bytes, game_type)

func seek_to_step(target_step: int) -> void:
	target_step = clamp(target_step, 0, total_steps)

	if bridge == null:
		_reload_board_scene()

	if bridge != null:
		bridge.load_replay(raw_log_bytes, game_type)

	if board_instance != null and board_instance.has_method("_init_board"):
		board_instance._init_board()

	for _i in range(target_step):
		if bridge != null:
			bridge.step_replay()

	current_step = target_step
	_update_ui()

func _update_ui() -> void:
	if step_slider != null:
		step_slider.set_value_no_signal(current_step)
	if step_label != null:
		step_label.text = "Paso %d / %d" % [current_step, total_steps]
	if btn_play_pause != null:
		if is_playing:
			btn_play_pause.text = "⏸ Pausa"
		else:
			btn_play_pause.text = "▶ Play"

	for i in range(move_row_nodes.size()):
		var row_btn := move_row_nodes[i]
		if not is_instance_valid(row_btn):
			continue
		var is_active := (i == current_step - 1)
		row_btn.modulate = Color(1.0, 0.92, 0.4) if is_active else Color(1.0, 1.0, 1.0)
		if is_active and move_list_scroll != null:
			move_list_scroll.ensure_control_visible(row_btn)

	_update_status("Replay cargado (%s) - Paso %d de %d (%.0fx)" % [game_type.capitalize(), current_step, total_steps, playback_speed])

func _update_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg

func set_playback_speed(multiplier: float) -> void:
	if multiplier <= 0.0:
		multiplier = 1.0
	playback_speed = multiplier
	if play_timer != null:
		play_timer.wait_time = 1.0 / playback_speed
	_update_ui()

func _on_speed_selected(index: int) -> void:
	if index >= 0 and index < PLAYBACK_SPEEDS.size():
		set_playback_speed(PLAYBACK_SPEEDS[index])

func _on_start_pressed() -> void:
	if is_playing:
		is_playing = false
		play_timer.stop()
	seek_to_step(0)

func _on_end_pressed() -> void:
	if is_playing:
		is_playing = false
		play_timer.stop()
	seek_to_step(total_steps)

func _on_play_pause_pressed() -> void:
	is_playing = !is_playing
	if is_playing:
		if current_step >= total_steps:
			seek_to_step(0)
		play_timer.wait_time = 1.0 / playback_speed
		play_timer.start(play_timer.wait_time)
	else:
		play_timer.stop()
	_update_ui()

func _on_prev_pressed() -> void:
	if is_playing:
		is_playing = false
		play_timer.stop()
	seek_to_step(current_step - 1)

func _on_next_pressed() -> void:
	if is_playing:
		is_playing = false
		play_timer.stop()
	if current_step < total_steps:
		if bridge != null:
			bridge.step_replay()
		current_step += 1
		_update_ui()

func _on_slider_value_changed(val: float) -> void:
	if is_playing:
		is_playing = false
		play_timer.stop()
	seek_to_step(int(val))

func _on_play_timer_timeout() -> void:
	if is_playing:
		if current_step < total_steps:
			if bridge != null:
				bridge.step_replay()
			current_step += 1
			_update_ui()
		else:
			is_playing = false
			play_timer.stop()
			_update_ui()

func _on_open_file_pressed() -> void:
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_import_replay_pressed() -> void:
	if import_otr_dialog != null:
		import_otr_dialog.popup_centered(Vector2i(800, 600))

func _on_export_replay_pressed() -> void:
	if export_otr_dialog != null:
		export_otr_dialog.popup_centered(Vector2i(800, 600))

func _get_save_manager() -> Node:
	if (is_inside_tree() and has_node("/root/SaveManager")):
		return get_node("/root/SaveManager")
	var script_res = load("res://scripts/save_manager.gd")
	if script_res != null:
		var inst: Node = script_res.new()
		inst._ready()
		return inst
	return null

func import_otr_replay(path: String) -> bool:
	var save_mgr := _get_save_manager()
	if save_mgr == null:
		return false
	var ok: bool = bool(save_mgr.call("import_replay_file", path))
	if ok:
		var imported_data: Dictionary = save_mgr.get("last_imported_replay")
		var imported_game_id := str(imported_data.get("game_id", game_type))
		var imported_names: Array = imported_data.get("player_names", [])
		player_names.clear()
		for n in imported_names:
			player_names.append(str(n))
		var moves_bytes: PackedByteArray = save_mgr.call("get_last_imported_replay_bytes")
		load_replay_data(moves_bytes, imported_game_id)
	if not (is_inside_tree() and has_node("/root/SaveManager")):
		save_mgr.free()
	return ok

func export_otr_replay(path: String) -> bool:
	var save_mgr := _get_save_manager()
	if save_mgr == null:
		return false
	var players_meta: Array = []
	for idx in range(player_names.size()):
		players_meta.append({"id": idx + 1, "name": player_names[idx], "score": 0})
	save_mgr.call("set_context", bridge, game_type, current_step, players_meta)
	var ok: bool = bool(save_mgr.call("export_replay_file", path))
	if not (is_inside_tree() and has_node("/root/SaveManager")):
		save_mgr.free()
	return ok

func _on_otr_file_selected(path: String) -> void:
	if not import_otr_replay(path):
		_update_status("Error al importar archivo .otr (formato o versión incompatible)")

func _on_export_otr_file_selected(path: String) -> void:
	if export_otr_replay(path):
		_update_status("Replay exportado a %s" % path)
	else:
		_update_status("Error al exportar archivo .otr")

func _on_file_selected(path: String) -> void:
	if path.ends_with(".otr"):
		_on_otr_file_selected(path)
		return
	var f = FileAccess.open(path, FileAccess.READ)
	if f != null:
		var bytes = f.get_buffer(f.get_length())
		load_replay_data(bytes, game_type)

func _on_game_type_selected(idx: int) -> void:
	var keys = GAME_SCENES.keys()
	if idx >= 0 and idx < keys.size():
		game_type = keys[idx]
		if raw_log_bytes.size() > 0:
			load_replay_data(raw_log_bytes, game_type)

func _on_back_pressed() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main_menu.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main_menu.tscn")
