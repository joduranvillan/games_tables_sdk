class_name SettingsMenu
extends Control

signal settings_saved()

@export var close_on_save: bool = true

var sfx_slider: HSlider
var sfx_checkbox: CheckBox
var anim_checkbox: CheckBox
var font_size_slider: HSlider
var font_size_label: Label
var theme_option: OptionButton
var p1_line: LineEdit
var p2_line: LineEdit
var lang_option: OptionButton
var highlight_checkbox: CheckBox
var save_button: Button
var close_button: Button

const LANG_KEYS = [
	{"code": "es", "name": "Español"},
	{"code": "en", "name": "English"},
	{"code": "de", "name": "Deutsch"},
	{"code": "fr", "name": "Français"},
	{"code": "it", "name": "Italiano"},
	{"code": "pt", "name": "Português"},
	{"code": "zh", "name": "中文"},
	{"code": "ja", "name": "日本語"},
	{"code": "ko", "name": "한국어"}
]

const THEME_KEYS = [
	{"key": "wood", "name": "THEME_WOOD"},
	{"key": "minimal", "name": "THEME_MINIMAL"}
]

const FONT_TIER_NAMES = ["Pequeño", "Mediano", "Grande"]

func _ready() -> void:
	_setup_ui()
	_load_current_settings()

func _setup_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 580)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_top = -290
	panel.offset_right = 220
	panel.offset_bottom = 290
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = tr("LABEL_SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	var tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.custom_minimum_size = Vector2(0, 420)
	vbox.add_child(tab_container)

	var settings_tab = VBoxContainer.new()
	settings_tab.name = "Ajustes"
	settings_tab.add_theme_constant_override("separation", 8)
	tab_container.add_child(settings_tab)

	var stats_tab = VBoxContainer.new()
	stats_tab.name = "Estadísticas"
	stats_tab.add_theme_constant_override("separation", 8)
	tab_container.add_child(stats_tab)

	_setup_settings_tab(settings_tab)
	_setup_stats_tab(stats_tab)

	vbox.add_child(HSeparator.new())
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	close_button = Button.new()
	close_button.text = tr("BTN_CLOSE")
	close_button.custom_minimum_size = Vector2(120, 38)
	close_button.pressed.connect(_on_close_pressed)
	hbox.add_child(close_button)
	
	save_button = Button.new()
	save_button.text = tr("BTN_SAVE")
	save_button.custom_minimum_size = Vector2(120, 38)
	save_button.pressed.connect(_on_save_pressed)
	hbox.add_child(save_button)

func _setup_settings_tab(parent: VBoxContainer) -> void:
	# Language option button
	var lang_label = Label.new()
	lang_label.text = tr("LABEL_LANGUAGE")
	parent.add_child(lang_label)
	
	lang_option = OptionButton.new()
	for l in LANG_KEYS:
		lang_option.add_item(l["name"])
	lang_option.item_selected.connect(_on_lang_selected)
	parent.add_child(lang_option)

	# Font size tier slider
	font_size_label = Label.new()
	font_size_label.text = "Tamaño de fuente: Mediano"
	parent.add_child(font_size_label)

	font_size_slider = HSlider.new()
	font_size_slider.min_value = 0
	font_size_slider.max_value = 2
	font_size_slider.step = 1
	font_size_slider.value = 1
	font_size_slider.value_changed.connect(_on_font_size_changed)
	parent.add_child(font_size_slider)
	
	# Audio settings & SFX Checkbox
	var sfx_label = Label.new()
	sfx_label.text = tr("LABEL_SFX_VOLUME")
	parent.add_child(sfx_label)
	
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = 0.8
	parent.add_child(sfx_slider)

	sfx_checkbox = CheckBox.new()
	sfx_checkbox.text = "Habilitar efectos de sonido (SFX)"
	sfx_checkbox.button_pressed = true
	parent.add_child(sfx_checkbox)

	# Animations Checkbox
	anim_checkbox = CheckBox.new()
	anim_checkbox.text = "Habilitar animaciones visuales"
	anim_checkbox.button_pressed = true
	parent.add_child(anim_checkbox)
	
	# Theme option button
	var theme_label = Label.new()
	theme_label.text = tr("LABEL_BOARD_THEME")
	parent.add_child(theme_label)
	
	theme_option = OptionButton.new()
	for item in THEME_KEYS:
		theme_option.add_item(tr(item["name"]))
	parent.add_child(theme_option)
	
	# Player names
	var p1_label = Label.new()
	p1_label.text = tr("LABEL_PLAYER_1")
	parent.add_child(p1_label)
	
	p1_line = LineEdit.new()
	p1_line.text = "Jugador 1"
	parent.add_child(p1_line)
	
	var p2_label = Label.new()
	p2_label.text = tr("LABEL_PLAYER_2")
	parent.add_child(p2_label)
	
	p2_line = LineEdit.new()
	p2_line.text = "Jugador 2"
	parent.add_child(p2_line)
	
	highlight_checkbox = CheckBox.new()
	highlight_checkbox.text = "Resaltar movimientos válidos"
	parent.add_child(highlight_checkbox)

	parent.add_child(HSeparator.new())
	var save_load_lbl = Label.new()
	save_load_lbl.text = "Persistencia Local de Partida"
	parent.add_child(save_load_lbl)

	var save_load_hbox = HBoxContainer.new()
	save_load_hbox.add_theme_constant_override("separation", 10)
	parent.add_child(save_load_hbox)

	var save_game_btn = Button.new()
	save_game_btn.text = "Guardar partida"
	save_game_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_game_btn.pressed.connect(_on_save_game_pressed)
	save_load_hbox.add_child(save_game_btn)

	var load_game_btn = Button.new()
	load_game_btn.text = "Cargar partida"
	load_game_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_game_btn.pressed.connect(_on_load_game_pressed)
	save_load_hbox.add_child(load_game_btn)

func _on_save_game_pressed() -> void:
	var user_dir = OS.get_user_data_dir()
	var save_path = user_dir + "/saved_game.json"
	var bridge = _find_active_bridge()
	if bridge != null and bridge.has_method("save_game"):
		var ok: bool = bridge.save_game(save_path)
		if ok:
			print("Partida guardada exitosamente en: ", save_path)
		else:
			print("Error al guardar la partida.")
	else:
		print("No se encontró el nodo OpenTableBridge activo.")

func _on_load_game_pressed() -> void:
	var user_dir = OS.get_user_data_dir()
	var save_path = user_dir + "/saved_game.json"
	var bridge = _find_active_bridge()
	if bridge != null and bridge.has_method("load_game"):
		var ok: bool = bridge.load_game(save_path)
		if ok:
			print("Partida cargada exitosamente desde: ", save_path)
		else:
			print("Error al cargar la partida.")
	else:
		print("No se encontró el nodo OpenTableBridge activo.")

func _find_active_bridge() -> Object:
	if has_node("/root/OpenTableBridge"):
		return get_node("/root/OpenTableBridge")
	var root = get_tree().root
	if root != null:
		for child in root.get_children():
			if child.get_class() == "OpenTableBridge" or child.has_method("save_game"):
				return child
			for grandchild in child.get_children():
				if grandchild.get_class() == "OpenTableBridge" or grandchild.has_method("save_game"):
					return grandchild
	return null

func _setup_stats_tab(parent: VBoxContainer) -> void:
	var lbl = Label.new()
	lbl.text = "Estadísticas de Victorias y Derrotas"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

	var stats_tree = Tree.new()
	stats_tree.columns = 4
	stats_tree.set_column_title(0, "Jugador")
	stats_tree.set_column_title(1, "Juego")
	stats_tree.set_column_title(2, "Victorias")
	stats_tree.set_column_title(3, "Derrotas")
	stats_tree.column_titles_visible = true
	stats_tree.hide_root = true
	stats_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_tree.custom_minimum_size = Vector2(0, 320)
	parent.add_child(stats_tree)

	var root = stats_tree.create_item()
	var scores_dict = {}
	if has_node("/root/ScoreTracker"):
		scores_dict = get_node("/root/ScoreTracker").scores

	if scores_dict.is_empty():
		var empty_item = stats_tree.create_item(root)
		empty_item.set_text(0, "Sin registros")
		empty_item.set_text(1, "-")
		empty_item.set_text(2, "0")
		empty_item.set_text(3, "0")
	else:
		for p_name in scores_dict.keys():
			var games = scores_dict[p_name]
			if games is Dictionary:
				for g_type in games.keys():
					var g_data = games[g_type]
					if g_data is Dictionary:
						var item = stats_tree.create_item(root)
						item.set_text(0, str(p_name))
						item.set_text(1, str(g_type).capitalize())
						item.set_text(2, str(g_data.get("wins", 0)))
						item.set_text(3, str(g_data.get("losses", 0)))

func _on_lang_selected(index: int) -> void:
	if index >= 0 and index < LANG_KEYS.size():
		var code = LANG_KEYS[index]["code"]
		TranslationServer.set_locale(code)

func _on_font_size_changed(value: float) -> void:
	var tier = int(value)
	font_size_label.text = "Tamaño de fuente: %s" % FONT_TIER_NAMES[tier]
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			tm.set_font_tier(tier)

func _load_current_settings() -> void:
	var settings = get_saved_settings()
	sfx_slider.value = settings["sfx_volume"]
	sfx_checkbox.button_pressed = settings.get("sfx_enabled", true)
	anim_checkbox.button_pressed = settings.get("animations_enabled", true)
	font_size_slider.value = settings.get("font_size_tier", 1)
	font_size_label.text = "Tamaño de fuente: %s" % FONT_TIER_NAMES[int(font_size_slider.value)]
	
	p1_line.text = settings["player1_name"]
	p2_line.text = settings["player2_name"]
	highlight_checkbox.button_pressed = settings.get("highlight_moves", true)
	
	var theme_key = settings["board_theme"]
	for i in range(THEME_KEYS.size()):
		if THEME_KEYS[i]["key"] == theme_key:
			theme_option.selected = i
			break
			
	var lang_code = settings["language"]
	for i in range(LANG_KEYS.size()):
		if LANG_KEYS[i]["code"] == lang_code:
			lang_option.selected = i
			break

static func get_saved_settings() -> Dictionary:
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	var sys_lang = OS.get_locale_language()
	var valid_codes = ["es", "en", "de", "fr", "it", "pt", "zh", "ja", "ko"]
	var default_lang = sys_lang if sys_lang in valid_codes else "es"
	
	if err != OK:
		return {
			"sfx_volume": 0.8,
			"sfx_enabled": true,
			"animations_enabled": true,
			"font_size_tier": 1,
			"board_theme": "wood",
			"player1_name": "Jugador 1",
			"player2_name": "Jugador 2",
			"language": default_lang,
			"highlight_moves": true
		}
	return {
		"sfx_volume": cfg.get_value("audio", "sfx_volume", 0.8),
		"sfx_enabled": cfg.get_value("audio", "sfx_enabled", true),
		"animations_enabled": cfg.get_value("display", "animations_enabled", true),
		"font_size_tier": cfg.get_value("display", "font_size_tier", 1),
		"board_theme": cfg.get_value("theme", "board_theme", "wood"),
		"player1_name": cfg.get_value("players", "player1_name", "Jugador 1"),
		"player2_name": cfg.get_value("players", "player2_name", "Jugador 2"),
		"language": cfg.get_value("locale", "language", default_lang),
		"highlight_moves": cfg.get_value("gameplay", "highlight_moves", true)
	}

func _on_save_pressed() -> void:
	var sfx_vol = sfx_slider.value
	var sfx_on = sfx_checkbox.button_pressed
	var anim_on = anim_checkbox.button_pressed
	var font_tier = int(font_size_slider.value)
	var theme_idx = theme_option.selected
	var theme_key = THEME_KEYS[theme_idx]["key"] if theme_idx >= 0 and theme_idx < THEME_KEYS.size() else "wood"
	var p1_name = p1_line.text
	var p2_name = p2_line.text
	var lang_idx = lang_option.selected
	var lang_code = LANG_KEYS[lang_idx]["code"] if lang_idx >= 0 and lang_idx < LANG_KEYS.size() else "es"
	var highlight_moves = highlight_checkbox.button_pressed
	
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "sfx_volume", sfx_vol)
	cfg.set_value("audio", "sfx_enabled", sfx_on)
	cfg.set_value("display", "animations_enabled", anim_on)
	cfg.set_value("display", "font_size_tier", font_tier)
	cfg.set_value("theme", "board_theme", theme_key)
	cfg.set_value("players", "player1_name", p1_name)
	cfg.set_value("players", "player2_name", p2_name)
	cfg.set_value("locale", "language", lang_code)
	cfg.set_value("gameplay", "highlight_moves", highlight_moves)
	cfg.save("user://settings.cfg")
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(sfx_vol if sfx_on else 0.0))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sfx_on)
	TranslationServer.set_locale(lang_code)
	
	if Engine.has_singleton("ThemeManager") or has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			tm.set_theme(theme_key)
			tm.set_font_tier(font_tier)

	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.sfx_enabled = sfx_on
		gm.animations_enabled = anim_on
		gm.font_size_tier = font_tier
			
	settings_saved.emit()
	
	if close_on_save:
		if get_parent() is Window or get_parent() is CanvasLayer or get_parent() is Control and get_parent() != get_tree().root:
			queue_free()
		elif has_node("/root/SceneManager"):
			get_node("/root/SceneManager").transition_to("res://main_menu.tscn")
		else:
			get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_close_pressed() -> void:
	if get_parent() is Window or get_parent() is CanvasLayer or get_parent() is Control and get_parent() != get_tree().root:
		queue_free()
	elif has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://main_menu.tscn")
