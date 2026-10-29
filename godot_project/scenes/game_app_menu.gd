class_name GameAppMenu
extends CanvasLayer

var board_node: Node = null
var turn_indicator: Node = null

var root_control: Control
var toggle_btn: Button
var dropdown_panel: PanelContainer
var menu_vbox: VBoxContainer

var theme_item_btn: Button
var undo_item_btn: Button
var redo_item_btn: Button
var tutorial_item_btn: Button
var rules_item_btn: Button

var _bound_rules_btn: Button = null
var _bound_tutorial_btn: Button = null

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
	toggle_btn.tooltip_text = "Menú de opciones (Temas, Deshacer, Rehacer, Tutorial y Reglas)"
	toggle_btn.custom_minimum_size = Vector2(118, 34)
	toggle_btn.anchor_left = 1.0
	toggle_btn.anchor_right = 1.0
	toggle_btn.anchor_top = 0.0
	toggle_btn.anchor_bottom = 0.0
	toggle_btn.offset_left = -130.0
	toggle_btn.offset_right = -12.0
	toggle_btn.offset_top = 8.0
	toggle_btn.offset_bottom = 42.0
	toggle_btn.add_theme_font_size_override("font_size", 13)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.14, 0.19, 0.27, 0.95)
	btn_style.border_color = Color(0.38, 0.58, 0.85, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	btn_style.content_margin_left = 10
	btn_style.content_margin_right = 10
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	toggle_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.20, 0.27, 0.38, 0.98)
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
	dropdown_panel.offset_left = -212.0
	dropdown_panel.offset_right = -12.0
	dropdown_panel.offset_top = 46.0
	dropdown_panel.offset_bottom = 244.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.14, 0.20, 0.97)
	panel_style.border_color = Color(0.38, 0.58, 0.85, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	dropdown_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(dropdown_panel)

	menu_vbox = VBoxContainer.new()
	menu_vbox.name = "MenuItemsVBox"
	menu_vbox.add_theme_constant_override("separation", 5)
	dropdown_panel.add_child(menu_vbox)

	theme_item_btn = _create_menu_item("ThemeMenuItem", "🎨 Cambiar Tema", _on_theme_item_pressed)
	undo_item_btn = _create_menu_item("UndoMenuItem", "⟵ Deshacer", _on_undo_item_pressed)
	redo_item_btn = _create_menu_item("RedoMenuItem", "⟶ Rehacer", _on_redo_item_pressed)
	tutorial_item_btn = _create_menu_item("TutorialMenuItem", "🎓 Tutorial", _on_tutorial_item_pressed)
	rules_item_btn = _create_menu_item("RulesMenuItem", "📖 Reglas", _on_rules_item_pressed)

func _create_menu_item(item_name: String, item_text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.name = item_name
	b.text = item_text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(180, 32)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(callback)
	menu_vbox.add_child(b)
	return b

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
	var found_rules: Button = _find_button_recursive(board_node, "RulesButton", "Reglas")
	if found_rules != null:
		_bound_rules_btn = found_rules
		_bound_rules_btn.visible = false

	var found_tutorial: Button = _find_tutorial_button_recursive(board_node)
	if found_tutorial != null:
		_bound_tutorial_btn = found_tutorial
		_bound_tutorial_btn.visible = false

	_refresh_menu_state()

func _find_button_recursive(node: Node, target_name: String, text_hint: String) -> Button:
	if node == self:
		return null
	if node is Button:
		var b := node as Button
		if b.name == target_name or (text_hint != "" and b.text.find(text_hint) != -1):
			return b
	for child in node.get_children():
		var res := _find_button_recursive(child, target_name, text_hint)
		if res != null:
			return res
	return null

func _find_tutorial_button_recursive(node: Node) -> Button:
	if node == self:
		return null
	if node is Button:
		var b := node as Button
		if b.name.ends_with("TutorialButton") or b.text.find("Tutorial") != -1:
			return b
	for child in node.get_children():
		var res := _find_tutorial_button_recursive(child)
		if res != null:
			return res
	return null

func _refresh_menu_state() -> void:
	if turn_indicator != null and is_instance_valid(turn_indicator):
		if turn_indicator.has_method("_update_undo_redo_status"):
			turn_indicator._update_undo_redo_status()
		var u_btn: Button = turn_indicator.get("undo_btn")
		var r_btn: Button = turn_indicator.get("redo_btn")
		if undo_item_btn != null and u_btn != null:
			undo_item_btn.disabled = u_btn.disabled
		if redo_item_btn != null and r_btn != null:
			redo_item_btn.disabled = r_btn.disabled

	if theme_item_btn != null and is_inside_tree() and has_node("/root/ThemeManager"):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null and tm.has_method("get_theme"):
			var th = tm.get_theme()
			if th != null and th.get("theme_name") != null:
				theme_item_btn.text = "🎨 Tema: " + str(th.theme_name)

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
			var m_name: String = str(method_info.get("name", ""))
			if m_name.begins_with("_on_start_") and m_name.ends_with("_tutorial_pressed"):
				board_node.call(m_name)
				close_menu()
				return
	# Si el juego no tiene tutorial interactivo dedicado, abrimos la guía de reglas
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
			var rp = board_node.get("_rules_popup")
			if rp != null and rp.has_method("show_for_game"):
				rp.show_for_game(_infer_game_id(board_node))
		elif board_node.get("rules_popup") != null:
			var rp2 = board_node.get("rules_popup")
			if rp2 != null and rp2.has_method("show_for_game"):
				rp2.show_for_game(_infer_game_id(board_node))
	close_menu()

func _infer_game_id(node: Node) -> String:
	var scr = node.get_script()
	if scr != null and scr.resource_path != "":
		var fname: String = scr.resource_path.get_file().replace("_board.gd", "")
		if fname != "":
			return fname
	return "chess"
