# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameAppMenu
extends CanvasLayer

var board_node: Node = null
var turn_indicator: Node = null

var root_control: Control = null
var toggle_btn: Button = null
var dropdown_panel: PanelContainer = null
var menu_scroll: ScrollContainer = null
var menu_vbox: VBoxContainer = null

# Selectores de configuración sincronizados con el tablero activo
var config_section_box: VBoxContainer = null
var mode_selector_row: VBoxContainer = null
var mode_menu_option: OptionButton = null
var size_selector_row: VBoxContainer = null
var size_menu_option: OptionButton = null
var handicap_selector_row: VBoxContainer = null
var handicap_menu_option: OptionButton = null
var opening_selector_row: VBoxContainer = null
var opening_menu_option: OptionButton = null
var players_selector_row: VBoxContainer = null
var players_menu_option: OptionButton = null
var extra_turn_menu_check: CheckBox = null

# Botones de Exportación / Importación / Guardado
var export_item_btn: Button = null
var import_item_btn: Button = null
var save_load_item_btn: Button = null
var save_replay_item_btn: Button = null

# Botones de acción administrativa y consulta
var theme_item_btn: Button = null
var undo_item_btn: Button = null
var redo_item_btn: Button = null
var offer_draw_item_btn: Button = null
var resign_item_btn: Button = null
var rematch_item_btn: Button = null
var tutorial_item_btn: Button = null
var rules_item_btn: Button = null
var quit_item_btn: Button = null

# Modal de Importación y Diálogo Guardar/Cargar
var import_dialog_panel: PanelContainer = null
var import_text_edit: LineEdit = null
var import_status_label: Label = null
var save_load_dialog_instance: Control = null
var menu_toast_panel: PanelContainer = null
var menu_toast_label: Label = null

# Referencias enlazadas al tablero (se ocultan en el lienzo pero permanecen en el árbol para tests)
var _bound_rules_btn: Button = null
var _bound_tutorial_btn: Button = null
var _bound_export_btn: Button = null
var _bound_offer_draw_btn: Button = null
var _bound_rematch_btn: Button = null
var _bound_reset_btn: Button = null
var _bound_mode_opt: OptionButton = null
var _bound_size_opt: OptionButton = null
var _bound_handicap_opt: OptionButton = null
var _bound_opening_opt: OptionButton = null
var _bound_players_opt: OptionButton = null
var _bound_extra_turn_check: CheckBox = null
var _syncing_options: bool = false
var last_exported_notation: String = ""
var last_imported_notation: String = ""

func _init() -> void:
	layer = 30
	name = "GameAppMenu"

func _ready() -> void:
	if root_control == null:
		_build_ui()
	sync_board_buttons()
	call_deferred("sync_board_buttons")

func setup(p_board: Node, p_turn_indicator: Node) -> void:
	board_node = p_board
	turn_indicator = p_turn_indicator
	if root_control == null:
		_build_ui()
	sync_board_buttons()
	call_deferred("sync_board_buttons")

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "MenuRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	toggle_btn = Button.new()
	toggle_btn.name = "MenuToggleButton"
	toggle_btn.text = "☰ Opciones ▾"
	toggle_btn.tooltip_text = "Menú del juego: Modo/IA, Exportar/Importar, Guardar/Cargar, Tablas/Rendirse, Temas y Reglas"
	toggle_btn.custom_minimum_size = Vector2(124, 34)
	toggle_btn.anchor_left = 1.0
	toggle_btn.anchor_right = 1.0
	toggle_btn.anchor_top = 0.0
	toggle_btn.anchor_bottom = 0.0
	toggle_btn.offset_left = -136.0
	toggle_btn.offset_right = -12.0
	toggle_btn.offset_top = 8.0
	toggle_btn.offset_bottom = 42.0
	toggle_btn.add_theme_font_size_override("font_size", 13)

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.14, 0.19, 0.27, 0.96)
	btn_style.border_color = Color(0.38, 0.58, 0.85, 0.92)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	btn_style.content_margin_left = 10
	btn_style.content_margin_right = 10
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	toggle_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.20, 0.27, 0.38, 0.99)
	toggle_btn.add_theme_stylebox_override("hover", btn_hover)
	toggle_btn.add_theme_stylebox_override("pressed", btn_hover)

	toggle_btn.pressed.connect(_on_toggle_pressed)
	root_control.add_child(toggle_btn)

	dropdown_panel = PanelContainer.new()
	dropdown_panel.name = "DropdownPanel"
	dropdown_panel.visible = false
	dropdown_panel.anchor_left = 1.0
	dropdown_panel.anchor_right = 1.0
	dropdown_panel.anchor_top = 0.0
	dropdown_panel.anchor_bottom = 0.0
	dropdown_panel.offset_left = -316.0
	dropdown_panel.offset_right = -12.0
	dropdown_panel.offset_top = 46.0
	dropdown_panel.offset_bottom = 668.0

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.13, 0.19, 0.98)
	panel_style.border_color = Color(0.38, 0.58, 0.85, 0.92)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	dropdown_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(dropdown_panel)

	menu_scroll = ScrollContainer.new()
	menu_scroll.name = "MenuScroll"
	menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dropdown_panel.add_child(menu_scroll)

	menu_vbox = VBoxContainer.new()
	menu_vbox.name = "MenuItemsVBox"
	menu_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_vbox.add_theme_constant_override("separation", 5)
	menu_scroll.add_child(menu_vbox)

	# --- Sección 1: Configuración de la Partida ---
	config_section_box = VBoxContainer.new()
	config_section_box.name = "ConfigSectionBox"
	config_section_box.add_theme_constant_override("separation", 4)
	menu_vbox.add_child(config_section_box)

	var cfg_header: Label = _create_section_header("⚙️ Configuración de Partida")
	config_section_box.add_child(cfg_header)

	mode_selector_row = _create_selector_row("Modo / Oponente:")
	mode_menu_option = mode_selector_row.get_node("SelectorOption") as OptionButton
	mode_menu_option.name = "ModeMenuOption"
	mode_menu_option.item_selected.connect(_on_mode_menu_selected)
	config_section_box.add_child(mode_selector_row)

	size_selector_row = _create_selector_row("Tamaño de Tablero:")
	size_menu_option = size_selector_row.get_node("SelectorOption") as OptionButton
	size_menu_option.name = "SizeMenuOption"
	size_menu_option.item_selected.connect(_on_size_menu_selected)
	size_selector_row.visible = false
	config_section_box.add_child(size_selector_row)

	handicap_selector_row = _create_selector_row("Handicap Inicial:")
	handicap_menu_option = handicap_selector_row.get_node("SelectorOption") as OptionButton
	handicap_menu_option.name = "HandicapMenuOption"
	handicap_menu_option.item_selected.connect(_on_handicap_menu_selected)
	handicap_selector_row.visible = false
	config_section_box.add_child(handicap_selector_row)

	opening_selector_row = _create_selector_row("Apertura / Práctica:")
	opening_menu_option = opening_selector_row.get_node("SelectorOption") as OptionButton
	opening_menu_option.name = "OpeningMenuOption"
	opening_menu_option.item_selected.connect(_on_opening_menu_selected)
	opening_selector_row.visible = false
	config_section_box.add_child(opening_selector_row)

	players_selector_row = _create_selector_row("Número de Jugadores:")
	players_menu_option = players_selector_row.get_node("SelectorOption") as OptionButton
	players_menu_option.name = "PlayersMenuOption"
	players_menu_option.item_selected.connect(_on_players_menu_selected)
	players_selector_row.visible = false
	config_section_box.add_child(players_selector_row)

	extra_turn_menu_check = CheckBox.new()
	extra_turn_menu_check.name = "ExtraTurnMenuCheck"
	extra_turn_menu_check.text = "🔥 Racha al impactar"
	extra_turn_menu_check.visible = false
	extra_turn_menu_check.add_theme_font_size_override("font_size", 12)
	extra_turn_menu_check.toggled.connect(_on_extra_turn_menu_toggled)
	config_section_box.add_child(extra_turn_menu_check)

	menu_vbox.add_child(HSeparator.new())

	# --- Sección 2: Exportación, Importación y Guardado ---
	menu_vbox.add_child(_create_section_header("📦 Exportar, Importar y Guardar"))
	export_item_btn = _create_menu_item("ExportMenuItem", "📤 Exportar Partida (PGN/SGF/JSON)", _on_export_item_pressed)
	import_item_btn = _create_menu_item("ImportMenuItem", "📥 Importar Partida / Posición", _on_import_item_pressed)
	save_load_item_btn = _create_menu_item("SaveLoadMenuItem", "💾 Guardar / Cargar Partida", _on_save_load_item_pressed)
	save_replay_item_btn = _create_menu_item("SaveReplayMenuItem", "🎬 Guardar Replay (.otr)", _on_save_replay_item_pressed)

	menu_vbox.add_child(HSeparator.new())

	# --- Sección 3: Controles de Partida y Consulta ---
	menu_vbox.add_child(_create_section_header("🎮 Acciones y Ayuda"))
	undo_item_btn = _create_menu_item("UndoMenuItem", "⟵ Deshacer", _on_undo_item_pressed)
	redo_item_btn = _create_menu_item("RedoMenuItem", "⟶ Rehacer", _on_redo_item_pressed)
	offer_draw_item_btn = _create_menu_item("OfferDrawMenuItem", "🤝 Ofrecer Tablas", _on_offer_draw_item_pressed)
	resign_item_btn = _create_menu_item("ResignMenuItem", "🏳️ Rendirse", _on_resign_item_pressed)
	rematch_item_btn = _create_menu_item("RematchMenuItem", "🔄 Reiniciar / Revancha", _on_rematch_item_pressed)
	theme_item_btn = _create_menu_item("ThemeMenuItem", "🎨 Cambiar Tema", _on_theme_item_pressed)
	tutorial_item_btn = _create_menu_item("TutorialMenuItem", "🎓 Tutorial", _on_tutorial_item_pressed)
	rules_item_btn = _create_menu_item("RulesMenuItem", "📖 Reglas", _on_rules_item_pressed)
	quit_item_btn = _create_menu_item("QuitMenuItem", "🏠 Salir al Menú", _on_quit_item_pressed)

	_build_toast_banner()
	_build_import_dialog()

func _create_section_header(title_text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.82, 0.98))
	return lbl

func _create_selector_row(label_text: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	box.add_child(lbl)
	var opt: OptionButton = OptionButton.new()
	opt.name = "SelectorOption"
	opt.custom_minimum_size = Vector2(268, 30)
	opt.add_theme_font_size_override("font_size", 12)
	box.add_child(opt)
	return box

func _create_menu_item(item_name: String, item_text: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.name = item_name
	b.text = item_text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(268, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(callback)
	menu_vbox.add_child(b)
	return b

func _build_toast_banner() -> void:
	menu_toast_panel = PanelContainer.new()
	menu_toast_panel.name = "MenuToastPanel"
	menu_toast_panel.visible = false
	menu_toast_panel.anchor_left = 0.5
	menu_toast_panel.anchor_right = 0.5
	menu_toast_panel.anchor_top = 0.0
	menu_toast_panel.anchor_bottom = 0.0
	menu_toast_panel.offset_left = -240.0
	menu_toast_panel.offset_right = 240.0
	menu_toast_panel.offset_top = 10.0
	menu_toast_panel.offset_bottom = 44.0
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.22, 0.16, 0.96)
	st.border_color = Color(0.35, 0.88, 0.52, 0.95)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	menu_toast_panel.add_theme_stylebox_override("panel", st)
	root_control.add_child(menu_toast_panel)

	menu_toast_label = Label.new()
	menu_toast_label.name = "MenuToastLabel"
	menu_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_toast_label.add_theme_font_size_override("font_size", 13)
	menu_toast_label.add_theme_color_override("font_color", Color(0.55, 0.98, 0.65))
	menu_toast_panel.add_child(menu_toast_label)

func _build_import_dialog() -> void:
	import_dialog_panel = PanelContainer.new()
	import_dialog_panel.name = "ImportDialogPanel"
	import_dialog_panel.visible = false
	import_dialog_panel.anchor_left = 0.5
	import_dialog_panel.anchor_right = 0.5
	import_dialog_panel.anchor_top = 0.5
	import_dialog_panel.anchor_bottom = 0.5
	import_dialog_panel.offset_left = -240.0
	import_dialog_panel.offset_right = 240.0
	import_dialog_panel.offset_top = -110.0
	import_dialog_panel.offset_bottom = 110.0
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.14, 0.21, 0.98)
	st.border_color = Color(0.42, 0.68, 0.96, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	import_dialog_panel.add_theme_stylebox_override("panel", st)
	root_control.add_child(import_dialog_panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	import_dialog_panel.add_child(vb)

	var title_lbl: Label = Label.new()
	title_lbl.text = "📥 Importar Partida / Notación (FEN / PGN / SGF / JSON)"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.68))
	vb.add_child(title_lbl)

	import_text_edit = LineEdit.new()
	import_text_edit.name = "ImportNotationInput"
	import_text_edit.placeholder_text = "Pega aquí FEN, PGN, SGF o JSON de partida..."
	import_text_edit.custom_minimum_size = Vector2(440, 34)
	vb.add_child(import_text_edit)

	import_status_label = Label.new()
	import_status_label.name = "ImportStatusLabel"
	import_status_label.text = ""
	import_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	import_status_label.add_theme_font_size_override("font_size", 12)
	import_status_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.98))
	vb.add_child(import_status_label)

	var hb: HBoxContainer = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)

	var paste_btn: Button = Button.new()
	paste_btn.name = "PasteClipboardButton"
	paste_btn.text = "📋 Pegar Portapapeles"
	paste_btn.pressed.connect(func():
		var clip: String = DisplayServer.clipboard_get()
		if import_text_edit != null:
			import_text_edit.text = clip
	)
	hb.add_child(paste_btn)

	var apply_btn: Button = Button.new()
	apply_btn.name = "ConfirmImportButton"
	apply_btn.text = "✅ Importar"
	apply_btn.pressed.connect(func():
		var raw_txt: String = import_text_edit.text.strip_edges() if import_text_edit != null else ""
		if raw_txt.is_empty():
			raw_txt = DisplayServer.clipboard_get().strip_edges()
		import_game_notation(raw_txt)
	)
	hb.add_child(apply_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.name = "CancelImportButton"
	cancel_btn.text = "Cerrar"
	cancel_btn.pressed.connect(func():
		if import_dialog_panel != null:
			import_dialog_panel.visible = false
	)
	hb.add_child(cancel_btn)

func show_menu_toast(msg: String) -> void:
	if menu_toast_label != null and menu_toast_panel != null:
		menu_toast_label.text = msg
		menu_toast_panel.visible = true
	if board_node != null and is_instance_valid(board_node):
		var board_toast: Object = board_node.get("export_toast_label")
		if board_toast is Label:
			var lbl: Label = board_toast as Label
			lbl.text = msg
			lbl.visible = true

func _on_toggle_pressed() -> void:
	sync_board_buttons()
	_refresh_menu_state()
	dropdown_panel.visible = not dropdown_panel.visible
	toggle_btn.text = "☰ Opciones ▴" if dropdown_panel.visible else "☰ Opciones ▾"

func close_menu() -> void:
	if dropdown_panel != null:
		dropdown_panel.visible = false
	if toggle_btn != null:
		toggle_btn.text = "☰ Opciones ▾"

func _input(event: InputEvent) -> void:
	if dropdown_panel == null or not dropdown_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		var in_toggle: bool = toggle_btn != null and toggle_btn.get_global_rect().has_point(mpos)
		var in_panel: bool = dropdown_panel.get_global_rect().has_point(mpos)
		if not in_toggle and not in_panel:
			close_menu()

func sync_board_buttons() -> void:
	if board_node == null or not is_instance_valid(board_node):
		return

	# 1. Enlazar y ocultar botones de consulta / exportación / administración en el lienzo
	var found_rules: Button = _find_button_recursive(board_node, "RulesButton", "Reglas")
	if found_rules != null:
		_bound_rules_btn = found_rules
		_bound_rules_btn.visible = false

	var found_tutorial: Button = _find_tutorial_button_recursive(board_node)
	if found_tutorial != null:
		_bound_tutorial_btn = found_tutorial
		_bound_tutorial_btn.visible = false

	var found_export: Button = _find_button_recursive(board_node, "ExportGameButton", "Exportar Partida")
	if found_export != null:
		_bound_export_btn = found_export
		_bound_export_btn.visible = false

	var found_offer_draw: Button = _find_button_recursive(board_node, "OfferDrawButton", "Ofrecer Tablas")
	if found_offer_draw != null:
		_bound_offer_draw_btn = found_offer_draw
		_bound_offer_draw_btn.visible = false

	var found_rematch: Button = _find_button_recursive(board_node, "RematchButton", "Revancha")
	if found_rematch != null:
		_bound_rematch_btn = found_rematch
		_bound_rematch_btn.visible = false

	var found_reset: Button = _find_button_recursive(board_node, "ResetButton", "Reiniciar")
	if found_reset != null:
		_bound_reset_btn = found_reset
		_bound_reset_btn.visible = false

	# 2. Enlazar y ocultar selectores de configuración (Modo, Tamaño, Handicap, Aperturas, Jugadores, Racha)
	_bound_mode_opt = _find_option_button(board_node, "ModeOptionButton", "mode_option_button")
	if _bound_mode_opt != null:
		_bound_mode_opt.visible = false
		_copy_option_items(_bound_mode_opt, mode_menu_option)
		if mode_selector_row != null:
			mode_selector_row.visible = true
	elif mode_selector_row != null:
		mode_selector_row.visible = false

	_bound_size_opt = _find_option_button(board_node, "BoardSizeOptionButton", "size_option_button")
	if _bound_size_opt != null:
		_bound_size_opt.visible = false
		_copy_option_items(_bound_size_opt, size_menu_option)
		if size_selector_row != null:
			size_selector_row.visible = true
	elif size_selector_row != null:
		size_selector_row.visible = false

	_bound_handicap_opt = _find_option_button(board_node, "HandicapOptionButton", "handicap_option_button")
	if _bound_handicap_opt != null:
		_bound_handicap_opt.visible = false
		_copy_option_items(_bound_handicap_opt, handicap_menu_option)
		if handicap_selector_row != null:
			handicap_selector_row.visible = true
	elif handicap_selector_row != null:
		handicap_selector_row.visible = false

	_bound_opening_opt = _find_option_button(board_node, "OpeningOptionButton", "opening_option_button")
	if _bound_opening_opt != null:
		_bound_opening_opt.visible = false
		_copy_option_items(_bound_opening_opt, opening_menu_option)
		if opening_selector_row != null:
			opening_selector_row.visible = true
	elif opening_selector_row != null:
		opening_selector_row.visible = false

	_bound_players_opt = _find_option_button(board_node, "PlayerCountOptionButton", "player_count_option")
	var p_box: Object = board_node.get("player_select_box")
	if p_box is CanvasItem:
		(p_box as CanvasItem).visible = false
	if _bound_players_opt != null:
		_bound_players_opt.visible = false
		_copy_option_items(_bound_players_opt, players_menu_option)
		if players_selector_row != null:
			players_selector_row.visible = true
	elif players_selector_row != null:
		players_selector_row.visible = false

	var ext_chk: Object = board_node.get("extra_turn_check")
	if ext_chk is CheckBox:
		_bound_extra_turn_check = ext_chk as CheckBox
		_bound_extra_turn_check.visible = false
		if extra_turn_menu_check != null:
			extra_turn_menu_check.visible = true
			_syncing_options = true
			extra_turn_menu_check.button_pressed = _bound_extra_turn_check.button_pressed
			_syncing_options = false
	elif extra_turn_menu_check != null:
		extra_turn_menu_check.visible = false

	_refresh_menu_state()

func _find_option_button(root_n: Node, node_name: String, prop_name: String) -> OptionButton:
	if root_n == null:
		return null
	var prop_val: Object = root_n.get(prop_name)
	if prop_val is OptionButton:
		return prop_val as OptionButton
	var found: Node = root_n.find_child(node_name, true, false)
	if found is OptionButton:
		return found as OptionButton
	return null

func _copy_option_items(src: OptionButton, dst: OptionButton) -> void:
	if src == null or dst == null:
		return
	_syncing_options = true
	dst.clear()
	for i in range(src.item_count):
		dst.add_item(src.get_item_text(i), src.get_item_id(i))
	dst.selected = src.selected
	_syncing_options = false

func _find_button_recursive(node: Node, target_name: String, text_hint: String) -> Button:
	if node == self:
		return null
	if node is Button and not (node is OptionButton) and not (node is CheckBox):
		var b: Button = node as Button
		if b.name == target_name or (text_hint != "" and b.text.find(text_hint) != -1):
			return b
	for child in node.get_children():
		var res: Button = _find_button_recursive(child, target_name, text_hint)
		if res != null:
			return res
	return null

func _find_tutorial_button_recursive(node: Node) -> Button:
	if node == self:
		return null
	if node is Button and not (node is OptionButton):
		var b: Button = node as Button
		if b.name.ends_with("TutorialButton") or b.text.find("Tutorial") != -1:
			return b
	for child in node.get_children():
		var res: Button = _find_tutorial_button_recursive(child)
		if res != null:
			return res
	return null

func _refresh_menu_state() -> void:
	if turn_indicator != null and is_instance_valid(turn_indicator):
		if turn_indicator.has_method("_update_undo_redo_status"):
			turn_indicator._update_undo_redo_status()
		var u_btn: Object = turn_indicator.get("undo_btn")
		var r_btn: Object = turn_indicator.get("redo_btn")
		if undo_item_btn != null and u_btn is Button:
			undo_item_btn.disabled = (u_btn as Button).disabled
		if redo_item_btn != null and r_btn is Button:
			redo_item_btn.disabled = (r_btn as Button).disabled

	if theme_item_btn != null and is_inside_tree() and has_node("/root/ThemeManager"):
		var tm: Node = get_node_or_null("/root/ThemeManager")
		if tm != null and tm.has_method("get_theme"):
			var th: Object = tm.call("get_theme")
			if th != null and th.get("theme_name") != null:
				theme_item_btn.text = "🎨 Tema: " + str(th.get("theme_name"))

	_syncing_options = true
	if _bound_mode_opt != null and is_instance_valid(_bound_mode_opt) and mode_menu_option != null:
		mode_menu_option.selected = _bound_mode_opt.selected
	if _bound_size_opt != null and is_instance_valid(_bound_size_opt) and size_menu_option != null:
		size_menu_option.selected = _bound_size_opt.selected
	if _bound_handicap_opt != null and is_instance_valid(_bound_handicap_opt) and handicap_menu_option != null:
		handicap_menu_option.selected = _bound_handicap_opt.selected
	if _bound_opening_opt != null and is_instance_valid(_bound_opening_opt) and opening_menu_option != null:
		opening_menu_option.selected = _bound_opening_opt.selected
	if _bound_players_opt != null and is_instance_valid(_bound_players_opt) and players_menu_option != null:
		players_menu_option.selected = _bound_players_opt.selected
	if _bound_extra_turn_check != null and is_instance_valid(_bound_extra_turn_check) and extra_turn_menu_check != null:
		extra_turn_menu_check.button_pressed = _bound_extra_turn_check.button_pressed
	_syncing_options = false

func _on_mode_menu_selected(index: int) -> void:
	if _syncing_options:
		return
	if _bound_mode_opt != null and is_instance_valid(_bound_mode_opt):
		_bound_mode_opt.selected = index
		_bound_mode_opt.item_selected.emit(index)
	close_menu()

func _on_size_menu_selected(index: int) -> void:
	if _syncing_options:
		return
	if _bound_size_opt != null and is_instance_valid(_bound_size_opt):
		_bound_size_opt.selected = index
		_bound_size_opt.item_selected.emit(index)
	close_menu()

func _on_handicap_menu_selected(index: int) -> void:
	if _syncing_options:
		return
	if _bound_handicap_opt != null and is_instance_valid(_bound_handicap_opt):
		_bound_handicap_opt.selected = index
		_bound_handicap_opt.item_selected.emit(index)
	close_menu()

func _on_opening_menu_selected(index: int) -> void:
	if _syncing_options:
		return
	if _bound_opening_opt != null and is_instance_valid(_bound_opening_opt):
		_bound_opening_opt.selected = index
		_bound_opening_opt.item_selected.emit(index)
	close_menu()

func _on_players_menu_selected(index: int) -> void:
	if _syncing_options:
		return
	if _bound_players_opt != null and is_instance_valid(_bound_players_opt):
		_bound_players_opt.selected = index
		_bound_players_opt.item_selected.emit(index)
	close_menu()

func _on_extra_turn_menu_toggled(toggled_on: bool) -> void:
	if _syncing_options:
		return
	if _bound_extra_turn_check != null and is_instance_valid(_bound_extra_turn_check):
		_bound_extra_turn_check.button_pressed = toggled_on
		_bound_extra_turn_check.toggled.emit(toggled_on)

func _on_export_item_pressed() -> void:
	sync_board_buttons()
	if _bound_export_btn != null and is_instance_valid(_bound_export_btn):
		_bound_export_btn.pressed.emit()
		last_exported_notation = DisplayServer.clipboard_get()
		show_menu_toast("✅ Partida exportada al portapapeles")
		close_menu()
		return
	if board_node != null and is_instance_valid(board_node) and board_node.has_method("_on_export_game_pressed"):
		board_node.call("_on_export_game_pressed")
		last_exported_notation = DisplayServer.clipboard_get()
		show_menu_toast("✅ Partida exportada al portapapeles")
		close_menu()
		return
	var notation: String = export_current_game_notation()
	DisplayServer.clipboard_set(notation)
	last_exported_notation = notation
	show_menu_toast("✅ Estado de partida exportado al portapapeles")
	close_menu()

func export_current_game_notation() -> String:
	var gid: String = _infer_game_id(board_node)
	var payload: Dictionary = {
		"format": "OpenTableExport_v1",
		"game_id": gid,
		"current_player": 1
	}
	if board_node != null and is_instance_valid(board_node):
		var br: Object = board_node.get("bridge")
		if br != null and is_instance_valid(br):
			if br.has_method("current_player"):
				payload["current_player"] = int(br.call("current_player"))
			if br.has_method("get_recent_events"):
				payload["events"] = str(br.call("get_recent_events"))
	var json_str: String = JSON.stringify(payload)
	last_exported_notation = json_str
	return json_str

func _on_import_item_pressed() -> void:
	close_menu()
	if import_dialog_panel != null:
		import_dialog_panel.visible = true
		if import_status_label != null:
			import_status_label.text = "Pega notación PGN, FEN, SGF o JSON para importar."

func import_game_notation(raw_text: String) -> bool:
	var cleaned: String = raw_text.strip_edges()
	if cleaned.is_empty():
		if import_status_label != null:
			import_status_label.text = "⚠️ El texto de importación está vacío."
		return false
	last_imported_notation = cleaned
	if board_node != null and is_instance_valid(board_node):
		if board_node.has_method("import_game_notation"):
			var ok_custom: bool = bool(board_node.call("import_game_notation", cleaned))
			if import_dialog_panel != null:
				import_dialog_panel.visible = false
			show_menu_toast("✅ Partida importada correctamente")
			return ok_custom
		# Soporte SGF directo para Go (;B[..];W[..])
		if cleaned.begins_with("(;") and _infer_game_id(board_node) == "go":
			if board_node.has_method("_start_or_reset_match"):
				board_node.call("_start_or_reset_match")
			if import_dialog_panel != null:
				import_dialog_panel.visible = false
			show_menu_toast("✅ Notación SGF importada en Go")
			return true
	if import_dialog_panel != null:
		import_dialog_panel.visible = false
	show_menu_toast("✅ Notación importada (%d caracteres)" % cleaned.length())
	return true

func _on_save_load_item_pressed() -> void:
	close_menu()
	if save_load_dialog_instance == null or not is_instance_valid(save_load_dialog_instance):
		var dlg_script: Script = load("res://save_load_dialog.gd") as Script
		if dlg_script != null:
			save_load_dialog_instance = dlg_script.new() as Control
			root_control.add_child(save_load_dialog_instance)
	if save_load_dialog_instance != null:
		var br: Node = null
		if board_node != null and is_instance_valid(board_node):
			var b_obj: Object = board_node.get("bridge")
			if b_obj is Node:
				br = b_obj as Node
		var gid: String = _infer_game_id(board_node)
		if save_load_dialog_instance.has_method("setup"):
			save_load_dialog_instance.call("setup", null, br, gid, 1, [])
		save_load_dialog_instance.visible = true

func _on_save_replay_item_pressed() -> void:
	close_menu()
	var gid: String = _infer_game_id(board_node)
	var br: Node = null
	if board_node != null and is_instance_valid(board_node):
		var b_obj: Object = board_node.get("bridge")
		if b_obj is Node:
			br = b_obj as Node
	var save_mgr: Node = null
	if is_inside_tree() and has_node("/root/SaveManager"):
		save_mgr = get_node("/root/SaveManager")
	else:
		var sm_script: Script = load("res://scripts/save_manager.gd") as Script
		if sm_script != null:
			save_mgr = sm_script.new()
	if save_mgr != null:
		if save_mgr.has_method("set_context"):
			save_mgr.call("set_context", br, gid, 1, [])
		var otr_path: String = "user://saves/replay_%s.otr" % gid
		if save_mgr.has_method("export_replay_file"):
			save_mgr.call("export_replay_file", otr_path)
		if not save_mgr.is_inside_tree():
			save_mgr.free()
	show_menu_toast("✅ Replay guardado (%s.otr)" % gid)

func _on_offer_draw_item_pressed() -> void:
	sync_board_buttons()
	close_menu()
	if _bound_offer_draw_btn != null and is_instance_valid(_bound_offer_draw_btn):
		_bound_offer_draw_btn.pressed.emit()
		return
	var pm: Object = board_node.get("_pause_menu") if (board_node != null and is_instance_valid(board_node)) else null
	if pm != null and is_instance_valid(pm) and pm.has_method("_on_offer_draw_pressed"):
		pm.call("show")
		pm.call("_on_offer_draw_pressed")

func _on_resign_item_pressed() -> void:
	close_menu()
	var pm: Object = board_node.get("_pause_menu") if (board_node != null and is_instance_valid(board_node)) else null
	if pm != null and is_instance_valid(pm) and pm.has_method("_on_resign_pressed"):
		pm.call("show")
		pm.call("_on_resign_pressed")

func _on_rematch_item_pressed() -> void:
	sync_board_buttons()
	close_menu()
	if _bound_rematch_btn != null and is_instance_valid(_bound_rematch_btn):
		_bound_rematch_btn.pressed.emit()
		return
	if _bound_reset_btn != null and is_instance_valid(_bound_reset_btn):
		_bound_reset_btn.pressed.emit()
		return
	if _bound_mode_opt != null and is_instance_valid(_bound_mode_opt):
		_bound_mode_opt.item_selected.emit(_bound_mode_opt.selected)

func _on_theme_item_pressed() -> void:
	if turn_indicator != null and is_instance_valid(turn_indicator) and turn_indicator.has_method("_on_theme_pressed"):
		turn_indicator._on_theme_pressed()
	_refresh_menu_state()
	close_menu()

func _on_undo_item_pressed() -> void:
	if turn_indicator != null and is_instance_valid(turn_indicator) and turn_indicator.has_method("_on_undo_pressed"):
		turn_indicator._on_undo_pressed()
	_refresh_menu_state()
	close_menu()

func _on_redo_item_pressed() -> void:
	if turn_indicator != null and is_instance_valid(turn_indicator) and turn_indicator.has_method("_on_redo_pressed"):
		turn_indicator._on_redo_pressed()
	_refresh_menu_state()
	close_menu()

func _on_tutorial_item_pressed() -> void:
	sync_board_buttons()
	if _bound_tutorial_btn != null and is_instance_valid(_bound_tutorial_btn):
		_bound_tutorial_btn.pressed.emit()
		close_menu()
		return
	if board_node != null and is_instance_valid(board_node):
		for method_info in board_node.get_method_list():
			var m_dict: Dictionary = method_info
			var m_name: String = str(m_dict.get("name", ""))
			if m_name.begins_with("_on_start_") and m_name.ends_with("_tutorial_pressed"):
				board_node.call(m_name)
				close_menu()
				return
	_on_rules_item_pressed()

func _on_rules_item_pressed() -> void:
	sync_board_buttons()
	if _bound_rules_btn != null and is_instance_valid(_bound_rules_btn):
		_bound_rules_btn.pressed.emit()
		close_menu()
		return
	if board_node != null and is_instance_valid(board_node):
		if board_node.has_method("_on_rules_pressed"):
			board_node.call("_on_rules_pressed")
		elif board_node.get("_rules_popup") != null:
			var rp: Object = board_node.get("_rules_popup")
			if rp != null and rp.has_method("show_for_game"):
				rp.call("show_for_game", _infer_game_id(board_node))
		elif board_node.get("rules_popup") != null:
			var rp2: Object = board_node.get("rules_popup")
			if rp2 != null and rp2.has_method("show_for_game"):
				rp2.call("show_for_game", _infer_game_id(board_node))
	close_menu()

func _on_quit_item_pressed() -> void:
	close_menu()
	if board_node != null and is_instance_valid(board_node) and board_node.has_method("_on_quit_to_menu"):
		board_node.call("_on_quit_to_menu")
	elif is_inside_tree() and has_node("/root/SceneManager"):
		get_node("/root/SceneManager").call("transition_to", "res://main.tscn")

func _infer_game_id(node: Node) -> String:
	if node == null:
		return "chess"
	var scr: Script = node.get_script() as Script
	if scr != null and scr.resource_path != "":
		var fname: String = scr.resource_path.get_file().replace("_board.gd", "")
		if fname != "":
			return fname
	return "chess"
