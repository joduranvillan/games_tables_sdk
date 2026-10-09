class_name RulesPopup
extends PanelContainer

const RulesCatalogRef = preload("res://scripts/rules_catalog.gd")

var current_game_id: String = "checkers"
var current_locale: String = "es"
var raw_text: String = ""
var title_label: Label
var lang_btn: Button
var search_line: LineEdit
var rich_label: RichTextLabel
var close_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(580, 480)
	pivot_offset = Vector2(290, 240)
	z_index = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.15, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.83, 0.68, 0.21, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_bottom = 2
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Header hbox
	var hbox_header := HBoxContainer.new()
	hbox_header.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_header)

	title_label = Label.new()
	title_label.text = "📖 Reglas del Juego"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	hbox_header.add_child(title_label)

	lang_btn = Button.new()
	lang_btn.name = "LangToggleButton"
	lang_btn.text = "ES / EN"
	lang_btn.custom_minimum_size = Vector2(68, 32)
	lang_btn.pressed.connect(_on_toggle_locale)
	hbox_header.add_child(lang_btn)

	close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): visible = false)
	hbox_header.add_child(close_btn)

	# Search LineEdit
	search_line = LineEdit.new()
	search_line.placeholder_text = "🔍 Buscar en reglas (ej. objetivo, turno, captura)..."
	search_line.clear_button_enabled = true
	search_line.text_changed.connect(_on_search_changed)
	vbox.add_child(search_line)

	# Scroll Container with RichTextLabel
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	rich_label = RichTextLabel.new()
	rich_label.bbcode_enabled = true
	rich_label.custom_minimum_size = Vector2(520, 370)
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_label.add_theme_font_size_override("normal_font_size", 14)
	scroll.add_child(rich_label)

func _resolve_default_locale() -> String:
	var tr_locale := TranslationServer.get_locale()
	if tr_locale.to_lower().begins_with("en"):
		return "en"
	return "es"

func show_for_game(game_id: String, locale: String = "") -> void:
	current_game_id = RulesCatalogRef.normalize_game_id(game_id)
	if not locale.is_empty():
		current_locale = RulesCatalogRef.normalize_locale(locale)
	elif current_locale.is_empty():
		current_locale = _resolve_default_locale()

	var rules_data: Dictionary = RulesCatalogRef.get_rules(current_game_id, current_locale)
	if title_label != null:
		title_label.text = "📖 %s" % String(rules_data.get("title", "Reglas del Juego"))
	if lang_btn != null:
		lang_btn.text = "🌐 %s" % current_locale.to_upper()

	raw_text = RulesCatalogRef.format_bbcode(current_game_id, current_locale)
	if rich_label != null:
		rich_label.text = raw_text
	if search_line != null:
		search_line.text = ""
	visible = true

func popup_for_game(game_id: String, locale: String = "") -> void:
	show_for_game(game_id, locale)

func get_current_rules_dict() -> Dictionary:
	return RulesCatalogRef.get_rules(current_game_id, current_locale)

func _on_toggle_locale() -> void:
	current_locale = "en" if current_locale == "es" else "es"
	show_for_game(current_game_id, current_locale)

func _on_search_changed(new_text: String) -> void:
	var q := new_text.strip_edges()
	if q.is_empty():
		rich_label.text = raw_text
		return

	var lower_raw := raw_text.to_lower()
	var lower_q := q.to_lower()

	var result_text := ""
	var last_pos := 0
	var pos := lower_raw.find(lower_q, 0)
	while pos != -1:
		result_text += raw_text.substr(last_pos, pos - last_pos)
		var matched_slice := raw_text.substr(pos, lower_q.length())
		result_text += "[color=yellow][b]%s[/b][/color]" % matched_slice
		last_pos = pos + lower_q.length()
		pos = lower_raw.find(lower_q, last_pos)

	result_text += raw_text.substr(last_pos)
	rich_label.text = result_text
