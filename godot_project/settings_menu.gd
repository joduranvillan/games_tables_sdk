# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name SettingsMenu
extends Control

signal settings_saved()

@export var close_on_save: bool = true

var music_slider: HSlider
var sfx_slider: HSlider
var sfx_checkbox: CheckBox
var anim_checkbox: CheckBox
var haptics_checkbox: CheckBox
var fullscreen_check: CheckButton
var font_size_slider: HSlider
var font_size_label: Label
var theme_option: OptionButton
var p1_line: LineEdit
var p2_line: LineEdit
var lang_option: OptionButton
var highlight_checkbox: CheckBox
var colorblind_checkbox: CheckBox
var colorblind_mode_label: Label
var colorblind_mode_option: OptionButton
var font_scale_label: Label
var font_scale_option: OptionButton
var save_button: Button
var close_button: Button
var title_label: Label
var lang_label: Label
var music_label: Label
var sfx_label: Label
var theme_label: Label
var p1_label: Label
var p2_label: Label
var relay_url_label: Label
var relay_url_line: LineEdit
var test_relay_button: Button
var relay_health_label: Label
var _health_http: HTTPRequest = null
var _ping_started_usec: int = 0

const DEFAULT_RELAY_URL: String = "ws://127.0.0.1:8080"

const LANG_KEYS = [
	{"code": "en", "name": "English"},
	{"code": "es", "name": "Español"},
	{"code": "pt", "name": "Português"},
	{"code": "fr", "name": "Français"},
	{"code": "de", "name": "Deutsch"},
	{"code": "it", "name": "Italiano"},
	{"code": "zh", "name": "中文"},
	{"code": "ja", "name": "日本語"},
	{"code": "ko", "name": "한국어"}
]

const THEME_KEYS = [
	{"key": "wood", "name": "THEME_WOOD"},
	{"key": "minimal", "name": "THEME_MINIMAL"},
	{"key": "stone", "name": "THEME_STONE"},
	{"key": "night", "name": "THEME_NIGHT"},
	{"key": "jade", "name": "THEME_JADE"}
]

const FONT_TIER_NAMES = ["Pequeño (1.0x)", "Mediano (1.15x)", "Grande (1.3x)"]

const COLORBLIND_MODE_OPTIONS = [
	{"mode": "none", "name": "Ninguno (Estándar)"},
	{"mode": "deuteranopia", "name": "Deuteranopia (Okabe-Ito)"},
	{"mode": "protanopia", "name": "Protanopia (Okabe-Ito)"},
	{"mode": "tritanopia", "name": "Tritanopia (Okabe-Ito)"},
	{"mode": "high_contrast", "name": "Alto Contraste"}
]

const FONT_SCALE_OPTIONS = [
	{"scale": 1.0, "name": "100% (1.0x)"},
	{"scale": 1.15, "name": "115% (1.15x)"},
	{"scale": 1.3, "name": "130% (1.3x)"}
]

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
	
	title_label = Label.new()
	title_label.text = tr("LABEL_SETTINGS_TITLE")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title_label)
	
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
	lang_label = Label.new()
	lang_label.text = tr("LABEL_LANGUAGE")
	parent.add_child(lang_label)
	
	lang_option = OptionButton.new()
	for l in LANG_KEYS:
		lang_option.add_item(l["name"])
	lang_option.item_selected.connect(_on_lang_selected)
	parent.add_child(lang_option)

	# Font size tier slider & selector de Tamaño de Texto (1.0, 1.15, 1.3)
	font_size_label = Label.new()
	font_size_label.text = "Tamaño de fuente: Pequeño (1.0x)"
	parent.add_child(font_size_label)

	font_size_slider = HSlider.new()
	font_size_slider.min_value = 0
	font_size_slider.max_value = 2
	font_size_slider.step = 1
	font_size_slider.value = 0
	font_size_slider.value_changed.connect(_on_font_size_changed)
	parent.add_child(font_size_slider)

	font_scale_label = Label.new()
	font_scale_label.name = "FontScaleLabel"
	font_scale_label.text = "Tamaño de Texto (Escalado UI)"
	parent.add_child(font_scale_label)

	font_scale_option = OptionButton.new()
	font_scale_option.name = "FontScaleOptionButton"
	for fs_item in FONT_SCALE_OPTIONS:
		font_scale_option.add_item(fs_item["name"])
	font_scale_option.selected = 0
	font_scale_option.item_selected.connect(_on_font_scale_selected)
	parent.add_child(font_scale_option)
	
	# Audio settings: Música & SFX independientes (en decibelios)
	music_label = Label.new()
	music_label.text = tr("LABEL_MUSIC_VOLUME")
	parent.add_child(music_label)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = 0.7
	music_slider.value_changed.connect(func(v: float):
		if (is_inside_tree() and has_node("/root/AudioManager")):
			var am = get_node("/root/AudioManager")
			if am.has_method("set_music_volume_linear"):
				am.call("set_music_volume_linear", v)
	)
	parent.add_child(music_slider)

	sfx_label = Label.new()
	sfx_label.text = tr("LABEL_SFX_VOLUME")
	parent.add_child(sfx_label)
	
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = 0.8
	sfx_slider.value_changed.connect(func(v: float):
		if (is_inside_tree() and has_node("/root/AudioManager")):
			var am = get_node("/root/AudioManager")
			if am.has_method("set_sfx_volume_linear"):
				am.call("set_sfx_volume_linear", v)
	)
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

	# Haptics Checkbox (Móvil)
	haptics_checkbox = CheckBox.new()
	haptics_checkbox.name = "HapticsCheckBox"
	haptics_checkbox.text = "Vibración háptica (Móvil)"
	haptics_checkbox.button_pressed = true
	haptics_checkbox.toggled.connect(func(on: bool):
		if (is_inside_tree() and has_node("/root/HapticsManager")):
			var hm = get_node("/root/HapticsManager")
			if hm.has_method("set_haptics_enabled"):
				hm.call("set_haptics_enabled", on)
	)
	parent.add_child(haptics_checkbox)

	# Fullscreen CheckButton
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Pantalla completa"
	var is_fs: bool = false
	if DisplayServer.has_method("window_get_mode"):
		is_fs = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_check.button_pressed = is_fs
	fullscreen_check.toggled.connect(func(on: bool):
		if DisplayServer.has_method("window_set_mode"):
			if on:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	parent.add_child(fullscreen_check)
	
	# Theme option button
	theme_label = Label.new()
	theme_label.text = tr("LABEL_BOARD_THEME")
	parent.add_child(theme_label)
	
	theme_option = OptionButton.new()
	for item in THEME_KEYS:
		theme_option.add_item(tr(item["name"]))
	parent.add_child(theme_option)
	
	# Player names
	p1_label = Label.new()
	p1_label.text = tr("LABEL_PLAYER_1")
	parent.add_child(p1_label)
	
	p1_line = LineEdit.new()
	p1_line.text = "Jugador 1"
	parent.add_child(p1_line)
	
	p2_label = Label.new()
	p2_label.text = tr("LABEL_PLAYER_2")
	parent.add_child(p2_label)
	
	p2_line = LineEdit.new()
	p2_line.text = "Jugador 2"
	parent.add_child(p2_line)
	
	highlight_checkbox = CheckBox.new()
	highlight_checkbox.text = "Resaltar movimientos válidos"
	parent.add_child(highlight_checkbox)

	colorblind_mode_label = Label.new()
	colorblind_mode_label.name = "ColorblindModeLabel"
	colorblind_mode_label.text = "Modo Daltónico / Contraste"
	parent.add_child(colorblind_mode_label)

	colorblind_mode_option = OptionButton.new()
	colorblind_mode_option.name = "ColorblindModeOptionButton"
	for cb_item in COLORBLIND_MODE_OPTIONS:
		colorblind_mode_option.add_item(cb_item["name"])
	colorblind_mode_option.selected = 0
	colorblind_mode_option.item_selected.connect(_on_colorblind_mode_selected)
	parent.add_child(colorblind_mode_option)

	colorblind_checkbox = CheckBox.new()
	colorblind_checkbox.text = "Modo Accesibilidad Daltónicos"
	colorblind_checkbox.toggled.connect(func(on: bool):
		var target_mode := "deuteranopia" if on else "none"
		if colorblind_mode_option != null:
			colorblind_mode_option.selected = 1 if on else 0
		if (is_inside_tree() and has_node("/root/ThemeManager")):
			var tm = get_node("/root/ThemeManager")
			if tm.has_method("set_colorblind_mode"):
				tm.call("set_colorblind_mode", target_mode)
	)
	parent.add_child(colorblind_checkbox)

	parent.add_child(HSeparator.new())
	relay_url_label = Label.new()
	relay_url_label.name = "RelayUrlLabel"
	relay_url_label.text = "Relay Server URL"
	parent.add_child(relay_url_label)

	var relay_hbox = HBoxContainer.new()
	relay_hbox.add_theme_constant_override("separation", 8)
	parent.add_child(relay_hbox)

	relay_url_line = LineEdit.new()
	relay_url_line.name = "RelayUrlLineEdit"
	relay_url_line.text = DEFAULT_RELAY_URL
	relay_url_line.placeholder_text = DEFAULT_RELAY_URL
	relay_url_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relay_hbox.add_child(relay_url_line)

	test_relay_button = Button.new()
	test_relay_button.name = "TestRelayButton"
	test_relay_button.text = "Probar Conexión"
	test_relay_button.custom_minimum_size = Vector2(135, 34)
	test_relay_button.pressed.connect(_on_test_relay_connection_pressed)
	relay_hbox.add_child(test_relay_button)

	relay_health_label = Label.new()
	relay_health_label.name = "RelayHealthLabel"
	relay_health_label.text = ""
	relay_health_label.add_theme_font_size_override("font_size", 13)
	relay_health_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	parent.add_child(relay_health_label)

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
	if (is_inside_tree() and has_node("/root/OpenTableBridge")):
		return get_node("/root/OpenTableBridge")
	var root = get_tree().root if is_inside_tree() else null
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
	lbl.text = "Estadísticas de Victorias, Derrotas y ELO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

	var stats_tree = Tree.new()
	stats_tree.columns = 5
	stats_tree.set_column_title(0, "Jugador")
	stats_tree.set_column_title(1, "Juego")
	stats_tree.set_column_title(2, "Victorias")
	stats_tree.set_column_title(3, "Derrotas")
	stats_tree.set_column_title(4, "ELO")
	stats_tree.column_titles_visible = true
	stats_tree.hide_root = true
	stats_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_tree.custom_minimum_size = Vector2(0, 320)
	parent.add_child(stats_tree)

	var root = stats_tree.create_item()
	var scores_dict = {}
	if is_inside_tree() and has_node("/root/ScoreTracker"):
		scores_dict = get_node("/root/ScoreTracker").scores

	if scores_dict.is_empty():
		var empty_item = stats_tree.create_item(root)
		empty_item.set_text(0, "Sin registros")
		empty_item.set_text(1, "-")
		empty_item.set_text(2, "0")
		empty_item.set_text(3, "0")
		empty_item.set_text(4, "1200")
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
						item.set_text(4, "%.1f" % float(g_data.get("elo", 1200.0)))

func _on_lang_selected(index: int) -> void:
	if index >= 0 and index < LANG_KEYS.size():
		var selected_locale: String = LANG_KEYS[index]["code"]
		TranslationServer.set_locale(selected_locale)
		var cfg := ConfigFile.new()
		cfg.load("user://settings.cfg")
		cfg.set_value("locale", "language", selected_locale)
		cfg.save("user://settings.cfg")
		_refresh_localized_texts()

func _refresh_localized_texts() -> void:
	if title_label != null:
		title_label.text = tr("LABEL_SETTINGS_TITLE")
	if lang_label != null:
		lang_label.text = tr("LABEL_LANGUAGE")
	if music_label != null:
		music_label.text = tr("LABEL_MUSIC_VOLUME")
	if sfx_label != null:
		sfx_label.text = tr("LABEL_SFX_VOLUME")
	if theme_label != null:
		theme_label.text = tr("LABEL_BOARD_THEME")
	if p1_label != null:
		p1_label.text = tr("LABEL_PLAYER_1")
	if p2_label != null:
		p2_label.text = tr("LABEL_PLAYER_2")
	if close_button != null:
		close_button.text = tr("BTN_CLOSE")
	if save_button != null:
		save_button.text = tr("BTN_SAVE")
	if theme_option != null:
		var sel := theme_option.selected
		theme_option.clear()
		for item in THEME_KEYS:
			theme_option.add_item(tr(item["name"]))
		if sel >= 0 and sel < THEME_KEYS.size():
			theme_option.selected = sel

func _on_font_size_changed(value: float) -> void:
	var tier = clampi(int(value), 0, 2)
	font_size_label.text = "Tamaño de fuente: %s" % FONT_TIER_NAMES[tier]
	if font_scale_option != null and font_scale_option.selected != tier:
		font_scale_option.selected = tier
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			tm.set_font_tier(tier)

func _on_font_scale_selected(index: int) -> void:
	if index < 0 or index >= FONT_SCALE_OPTIONS.size():
		return
	var scale_val: float = float(FONT_SCALE_OPTIONS[index]["scale"])
	if font_size_slider != null and int(font_size_slider.value) != index:
		font_size_slider.value = index
	if font_size_label != null:
		font_size_label.text = "Tamaño de fuente: %s" % FONT_TIER_NAMES[index]
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null and tm.has_method("set_ui_font_scale"):
			tm.call("set_ui_font_scale", scale_val)

func _on_colorblind_mode_selected(index: int) -> void:
	if index < 0 or index >= COLORBLIND_MODE_OPTIONS.size():
		return
	var mode_val: String = String(COLORBLIND_MODE_OPTIONS[index]["mode"])
	if colorblind_checkbox != null:
		colorblind_checkbox.set_block_signals(true)
		colorblind_checkbox.button_pressed = (mode_val != "none")
		colorblind_checkbox.set_block_signals(false)
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null and tm.has_method("set_colorblind_mode"):
			tm.call("set_colorblind_mode", mode_val)

func _load_current_settings() -> void:
	var settings = get_saved_settings()
	if music_slider != null:
		music_slider.value = settings.get("music_volume", 0.7)
	sfx_slider.value = settings["sfx_volume"]
	sfx_checkbox.button_pressed = settings.get("sfx_enabled", true)
	anim_checkbox.button_pressed = settings.get("animations_enabled", true)
	if haptics_checkbox != null:
		haptics_checkbox.button_pressed = bool(settings.get("haptics_enabled", true))
	if fullscreen_check != null:
		var fs_val: bool = settings.get("fullscreen", false)
		fullscreen_check.button_pressed = fs_val
	var tier_val: int = clampi(int(settings.get("font_size_tier", 0)), 0, 2)
	font_size_slider.value = tier_val
	font_size_label.text = "Tamaño de fuente: %s" % FONT_TIER_NAMES[tier_val]
	if font_scale_option != null:
		var saved_scale: float = float(settings.get("ui_font_scale", 1.0))
		for scale_idx in range(FONT_SCALE_OPTIONS.size()):
			if is_equal_approx(float(FONT_SCALE_OPTIONS[scale_idx]["scale"]), saved_scale):
				font_scale_option.selected = scale_idx
				break

	var saved_cb_mode: String = String(settings.get("colorblind_mode", "none"))
	if colorblind_mode_option != null:
		for cb_idx in range(COLORBLIND_MODE_OPTIONS.size()):
			if COLORBLIND_MODE_OPTIONS[cb_idx]["mode"] == saved_cb_mode:
				colorblind_mode_option.selected = cb_idx
				break
	if colorblind_checkbox != null:
		colorblind_checkbox.set_block_signals(true)
		colorblind_checkbox.button_pressed = (saved_cb_mode != "none")
		colorblind_checkbox.set_block_signals(false)
	
	p1_line.text = settings["player1_name"]
	p2_line.text = settings["player2_name"]
	highlight_checkbox.button_pressed = settings.get("highlight_moves", true)
	if relay_url_line != null:
		relay_url_line.text = String(settings.get("relay_url", DEFAULT_RELAY_URL))
	
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

static func resolve_health_url(raw_relay_url: String) -> String:
	var cleaned := raw_relay_url.strip_edges()
	if cleaned.is_empty():
		cleaned = DEFAULT_RELAY_URL
	while cleaned.ends_with("/"):
		cleaned = cleaned.left(cleaned.length() - 1)
	if cleaned.begins_with("wss://"):
		cleaned = "https://" + cleaned.substr(6)
	elif cleaned.begins_with("ws://"):
		cleaned = "http://" + cleaned.substr(5)
	elif not cleaned.begins_with("http://") and not cleaned.begins_with("https://"):
		cleaned = "http://" + cleaned
	if cleaned.ends_with(":8080"):
		cleaned = cleaned.left(cleaned.length() - 5) + ":8081"
	if not cleaned.ends_with("/health"):
		cleaned += "/health"
	return cleaned

func format_health_probe_result(http_code: int, body_text: String, rtt_ms: int) -> String:
	var safe_rtt: int = maxi(1, rtt_ms)
	if http_code == 200:
		var parsed = JSON.parse_string(body_text)
		if parsed is Dictionary and String(parsed.get("status", "")) == "ok":
			return "Conectado — %d ms" % safe_rtt
	return "Error de conexión (HTTP %d)" % http_code

func simulate_health_probe_response(http_code: int, body_text: String, rtt_ms: int) -> String:
	var formatted := format_health_probe_result(http_code, body_text, rtt_ms)
	if relay_health_label != null:
		relay_health_label.text = formatted
	return formatted

func _on_test_relay_connection_pressed() -> void:
	var target_relay := DEFAULT_RELAY_URL
	if relay_url_line != null and not relay_url_line.text.strip_edges().is_empty():
		target_relay = relay_url_line.text.strip_edges()
	var health_url := resolve_health_url(target_relay)
	if relay_health_label != null:
		relay_health_label.text = "Probando conexión..."
	_ping_started_usec = Time.get_ticks_usec()

	if is_inside_tree():
		if _health_http == null:
			_health_http = HTTPRequest.new()
			_health_http.timeout = 5.0
			add_child(_health_http)
			_health_http.request_completed.connect(_on_health_request_completed)
		var err: Error = _health_http.request(health_url)
		if err != OK and relay_health_label != null:
			relay_health_label.text = "Error de conexión"

func _on_health_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var elapsed_ms: int = maxi(1, int(round(float(Time.get_ticks_usec() - _ping_started_usec) / 1000.0)))
	if result != HTTPRequest.RESULT_SUCCESS:
		if relay_health_label != null:
			relay_health_label.text = "Error de conexión"
		return
	var body_text: String = body.get_string_from_utf8()
	simulate_health_probe_response(response_code, body_text, elapsed_ms)

static func save_relay_url_to_config(
	new_relay_url: String,
	cfg_path: String = "user://settings.cfg"
) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	var sanitized := new_relay_url.strip_edges()
	if sanitized.is_empty():
		sanitized = DEFAULT_RELAY_URL
	cfg.set_value("network", "relay_url", sanitized)
	return cfg.save(cfg_path)

static func get_saved_settings(cfg_path: String = "user://settings.cfg") -> Dictionary:
	var cfg = ConfigFile.new()
	var err = cfg.load(cfg_path)
	var sys_lang = OS.get_locale_language()
	var valid_codes = ["es", "en", "de", "fr", "it", "pt", "zh", "ja", "ko"]
	var default_lang = sys_lang if sys_lang in valid_codes else "es"
	
	if err != OK:
		return {
			"sfx_volume": 0.8,
			"sfx_enabled": true,
			"animations_enabled": true,
			"haptics_enabled": true,
			"fullscreen": false,
			"font_size_tier": 0,
			"ui_font_scale": 1.0,
			"colorblind_mode": "none",
			"board_theme": "wood",
			"player1_name": "Jugador 1",
			"player2_name": "Jugador 2",
			"language": default_lang,
			"highlight_moves": true,
			"relay_url": DEFAULT_RELAY_URL
		}
	return {
		"sfx_volume": cfg.get_value("audio", "sfx_volume", 0.8),
		"sfx_enabled": cfg.get_value("audio", "sfx_enabled", true),
		"animations_enabled": cfg.get_value("display", "animations_enabled", true),
		"haptics_enabled": bool(cfg.get_value("accessibility", "haptics_enabled", true)),
		"fullscreen": cfg.get_value("display", "fullscreen", false),
		"font_size_tier": cfg.get_value("display", "font_size_tier", 0),
		"ui_font_scale": float(cfg.get_value("accessibility", "ui_font_scale", 1.0)),
		"colorblind_mode": String(cfg.get_value("accessibility", "colorblind_mode", "none")),
		"board_theme": cfg.get_value("theme", "board_theme", "wood"),
		"player1_name": cfg.get_value("players", "player1_name", "Jugador 1"),
		"player2_name": cfg.get_value("players", "player2_name", "Jugador 2"),
		"language": cfg.get_value("locale", "language", default_lang),
		"highlight_moves": cfg.get_value("gameplay", "highlight_moves", true),
		"relay_url": cfg.get_value("network", "relay_url", DEFAULT_RELAY_URL)
	}

func _on_save_pressed() -> void:
	var music_vol = music_slider.value if music_slider != null else 0.7
	var sfx_vol = sfx_slider.value
	var sfx_on = sfx_checkbox.button_pressed
	var anim_on = anim_checkbox.button_pressed
	var haptics_on = haptics_checkbox.button_pressed if haptics_checkbox != null else true
	var is_fs = fullscreen_check.button_pressed if fullscreen_check != null else false
	var font_tier = int(font_size_slider.value)
	var fs_idx = font_scale_option.selected if font_scale_option != null else font_tier
	var ui_scale_val: float = float(FONT_SCALE_OPTIONS[fs_idx]["scale"]) if fs_idx >= 0 and fs_idx < FONT_SCALE_OPTIONS.size() else 1.0
	var cb_idx = colorblind_mode_option.selected if colorblind_mode_option != null else 0
	var cb_mode_val: String = String(COLORBLIND_MODE_OPTIONS[cb_idx]["mode"]) if cb_idx >= 0 and cb_idx < COLORBLIND_MODE_OPTIONS.size() else "none"
	var theme_idx = theme_option.selected
	var theme_key = THEME_KEYS[theme_idx]["key"] if theme_idx >= 0 and theme_idx < THEME_KEYS.size() else "wood"
	var p1_name = p1_line.text
	var p2_name = p2_line.text
	var lang_idx = lang_option.selected
	var lang_code = LANG_KEYS[lang_idx]["code"] if lang_idx >= 0 and lang_idx < LANG_KEYS.size() else "es"
	var highlight_moves = highlight_checkbox.button_pressed
	var relay_url_val = relay_url_line.text.strip_edges() if relay_url_line != null else DEFAULT_RELAY_URL
	if relay_url_val.is_empty():
		relay_url_val = DEFAULT_RELAY_URL
	
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_vol)
	cfg.set_value("audio", "sfx_volume", sfx_vol)
	cfg.set_value("audio", "sfx_enabled", sfx_on)
	cfg.set_value("display", "animations_enabled", anim_on)
	cfg.set_value("display", "fullscreen", is_fs)
	cfg.set_value("display", "font_size_tier", font_tier)
	cfg.set_value("accessibility", "ui_font_scale", ui_scale_val)
	cfg.set_value("accessibility", "colorblind_mode", cb_mode_val)
	cfg.set_value("accessibility", "haptics_enabled", haptics_on)
	cfg.set_value("theme", "board_theme", theme_key)
	cfg.set_value("players", "player1_name", p1_name)
	cfg.set_value("players", "player2_name", p2_name)
	cfg.set_value("locale", "language", lang_code)
	cfg.set_value("gameplay", "highlight_moves", highlight_moves)
	cfg.set_value("network", "relay_url", relay_url_val)
	cfg.save("user://settings.cfg")
	
	if DisplayServer.has_method("window_set_mode"):
		if is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if (is_inside_tree() and has_node("/root/AudioManager")):
		var am = get_node("/root/AudioManager")
		if am.has_method("set_music_volume_db"):
			am.call("set_music_volume_db", linear_to_db(music_vol) if music_vol > 0.0001 else -80.0)
		if am.has_method("set_sfx_volume_db"):
			am.call("set_sfx_volume_db", linear_to_db(sfx_vol) if (sfx_on and sfx_vol > 0.0001) else -80.0)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(sfx_vol if sfx_on else 0.0))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sfx_on)
	TranslationServer.set_locale(lang_code)
	
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			tm.set_theme(theme_key)
			tm.set_ui_font_scale(ui_scale_val)
			tm.set_colorblind_mode(cb_mode_val)

	if (is_inside_tree() and has_node("/root/HapticsManager")):
		var hm = get_node("/root/HapticsManager")
		if hm.has_method("set_haptics_enabled"):
			hm.call("set_haptics_enabled", haptics_on)

	if (is_inside_tree() and has_node("/root/GameManager")):
		var gm = get_node("/root/GameManager")
		gm.sfx_enabled = sfx_on
		gm.animations_enabled = anim_on
		gm.font_size_tier = font_tier
			
	settings_saved.emit()
	
	if close_on_save:
		if get_parent() is Window or get_parent() is CanvasLayer or get_parent() is Control and (not is_inside_tree() or get_parent() != get_tree().root):
			queue_free()
		elif (is_inside_tree() and has_node("/root/SceneManager")):
			get_node("/root/SceneManager").transition_to("res://main_menu.tscn")
		else:
			if is_inside_tree():
				get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_close_pressed() -> void:
	if get_parent() is Window or get_parent() is CanvasLayer or get_parent() is Control and (not is_inside_tree() or get_parent() != get_tree().root):
		queue_free()
	elif (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main_menu.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main_menu.tscn")
