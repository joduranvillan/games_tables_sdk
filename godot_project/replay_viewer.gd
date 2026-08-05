class_name ReplayViewer
extends Control

var raw_log_bytes: PackedByteArray = PackedByteArray()
var game_type: String = "checkers"
var total_steps: int = 0
var current_step: int = 0
var is_playing: bool = false
var play_timer: Timer

var board_instance: Node = null
var bridge: Node = null

var board_container: Control
var status_label: Label
var step_label: Label
var step_slider: HSlider
var btn_play_pause: Button
var btn_prev: Button
var btn_next: Button
var game_type_option: OptionButton
var file_dialog: FileDialog

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

	var bytes = GameManager.get_replay_log_bytes()
	var gtype = GameManager.get_replay_game_type()
	if bytes.size() > 0:
		load_replay_data(bytes, gtype)
	else:
		_update_status("Selecciona o carga un archivo .otlog para reproducir")

func _setup_timer() -> void:
	play_timer = Timer.new()
	play_timer.wait_time = 1.0
	play_timer.one_shot = false
	play_timer.timeout.connect(_on_play_timer_timeout)
	add_child(play_timer)

func _setup_ui() -> void:
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
	title_lbl.text = " 🎬 Visualizador de Replay (.otlog)"
	title_lbl.add_theme_font_size_override("font_size", 20)

	var btn_open = Button.new()
	btn_open.text = "📂 Cargar Archivo .otlog"
	btn_open.pressed.connect(_on_open_file_pressed)

	game_type_option = OptionButton.new()
	for gt in GAME_SCENES.keys():
		game_type_option.add_item(gt.capitalize(), GAME_SCENES.keys().find(gt))
	game_type_option.item_selected.connect(_on_game_type_selected)

	var btn_back = Button.new()
	btn_back.text = "← Volver al Menú"
	btn_back.pressed.connect(_on_back_pressed)

	top_hbox.add_child(title_lbl)
	top_hbox.add_child(btn_open)
	top_hbox.add_child(game_type_option)
	top_hbox.add_child(Control.new())
	top_hbox.get_child(3).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(btn_back)
	top_panel.add_child(top_hbox)
	main_vbox.add_child(top_panel)

	# Board Area
	board_container = Control.new()
	board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(board_container)

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
	controls_hbox.add_theme_constant_override("separation", 20)

	btn_prev = Button.new()
	btn_prev.text = "⏮"
	btn_prev.custom_minimum_size = Vector2(80, 40)
	btn_prev.pressed.connect(_on_prev_pressed)

	btn_play_pause = Button.new()
	btn_play_pause.text = "▶"
	btn_play_pause.custom_minimum_size = Vector2(100, 40)
	btn_play_pause.pressed.connect(_on_play_pause_pressed)

	btn_next = Button.new()
	btn_next.text = "⏭"
	btn_next.custom_minimum_size = Vector2(80, 40)
	btn_next.pressed.connect(_on_next_pressed)

	step_label = Label.new()
	step_label.text = "Paso 0 / 0"
	step_label.add_theme_font_size_override("font_size", 16)

	controls_hbox.add_child(btn_prev)
	controls_hbox.add_child(btn_play_pause)
	controls_hbox.add_child(btn_next)
	controls_hbox.add_child(step_label)

	step_slider = HSlider.new()
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
	file_dialog.filters = PackedStringArray(["*.otlog ; Archivos de Replay OpenTable", "* ; Todos los archivos"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

func load_replay_data(bytes: PackedByteArray, type_str: String) -> void:
	raw_log_bytes = bytes
	game_type = type_str

	var json_text = bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(json_text)
	if parsed is Array:
		total_steps = parsed.size()
	else:
		total_steps = 0

	step_slider.max_value = total_steps
	current_step = 0
	_reload_board_scene()
	seek_to_step(0)

func _reload_board_scene() -> void:
	if board_instance != null:
		board_instance.queue_free()
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

	for i in range(target_step):
		if bridge != null:
			bridge.step_replay()

	current_step = target_step
	_update_ui()

func _update_ui() -> void:
	step_slider.set_value_no_signal(current_step)
	step_label.text = "Paso %d / %d" % [current_step, total_steps]
	if is_playing:
		btn_play_pause.text = "⏸"
	else:
		btn_play_pause.text = "▶"

	_update_status("Replay cargado (%s) - Paso %d de %d" % [game_type.capitalize(), current_step, total_steps])

func _update_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg

func _on_play_pause_pressed() -> void:
	is_playing = !is_playing
	if is_playing:
		if current_step >= total_steps:
			seek_to_step(0)
		play_timer.start(1.0)
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

func _on_file_selected(path: String) -> void:
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
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://main_menu.tscn")
