extends CanvasLayer

signal quit_game_requested
signal undo_move_requested()
signal resign_confirmed(resigning_player_id: int, winner_id: int)
signal draw_accepted()

const RulesCatalogRef = preload("res://scripts/rules_catalog.gd")

var active_game_id: String = ""
var active_player_id: int = 1
var active_bridge: Object = null
var is_network_match: bool = false
var rules_popup: RulesPopup = null
var game_over_overlay: CanvasLayer = null

var confirm_dialog: PanelContainer = null
var confirm_label: Label = null
var confirm_yes_button: Button = null
var confirm_no_button: Button = null
var pending_action: String = ""

@onready var continue_button: Button = get_node_or_null("Panel/VBoxContainer/ContinueButton")
@onready var undo_move_button: Button = get_node_or_null("Panel/VBoxContainer/UndoMoveButton")
@onready var rules_button: Button = get_node_or_null("Panel/VBoxContainer/RulesButton")
@onready var resign_button: Button = get_node_or_null("Panel/VBoxContainer/ResignButton")
@onready var offer_draw_button: Button = get_node_or_null("Panel/VBoxContainer/OfferDrawButton")
@onready var settings_button: Button = get_node_or_null("Panel/VBoxContainer/SettingsButton")
@onready var quit_button: Button = get_node_or_null("Panel/VBoxContainer/QuitButton")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_ensure_ui_nodes()
	_update_undo_button_state()

func _ensure_ui_nodes() -> void:
	if continue_button == null:
		continue_button = get_node_or_null("Panel/VBoxContainer/ContinueButton")
	if undo_move_button == null:
		undo_move_button = get_node_or_null("Panel/VBoxContainer/UndoMoveButton")
	if rules_button == null:
		rules_button = get_node_or_null("Panel/VBoxContainer/RulesButton")
	if resign_button == null:
		resign_button = get_node_or_null("Panel/VBoxContainer/ResignButton")
	if offer_draw_button == null:
		offer_draw_button = get_node_or_null("Panel/VBoxContainer/OfferDrawButton")
	if settings_button == null:
		settings_button = get_node_or_null("Panel/VBoxContainer/SettingsButton")
	if quit_button == null:
		quit_button = get_node_or_null("Panel/VBoxContainer/QuitButton")

	if continue_button != null and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)

	if undo_move_button == null and has_node("Panel/VBoxContainer"):
		undo_move_button = Button.new()
		undo_move_button.name = "UndoMoveButton"
		undo_move_button.text = "↩️ Deshacer Jugada"
		$Panel/VBoxContainer.add_child(undo_move_button)
		$Panel/VBoxContainer.move_child(undo_move_button, 1)
	if undo_move_button != null:
		undo_move_button.text = "↩️ Deshacer Jugada"
		if not undo_move_button.pressed.is_connected(_on_undo_move_pressed):
			undo_move_button.pressed.connect(_on_undo_move_pressed)

	if rules_button == null and has_node("Panel/VBoxContainer"):
		rules_button = Button.new()
		rules_button.name = "RulesButton"
		rules_button.text = "📖 Ver Reglas del Juego"
		$Panel/VBoxContainer.add_child(rules_button)
		$Panel/VBoxContainer.move_child(rules_button, 2)
	if rules_button != null:
		rules_button.text = "📖 Ver Reglas del Juego"
		if not rules_button.pressed.is_connected(_on_rules_pressed):
			rules_button.pressed.connect(_on_rules_pressed)

	if resign_button == null and has_node("Panel/VBoxContainer"):
		resign_button = Button.new()
		resign_button.name = "ResignButton"
		resign_button.text = "🏳️ Rendirse"
		$Panel/VBoxContainer.add_child(resign_button)
		$Panel/VBoxContainer.move_child(resign_button, 3)
	if resign_button != null:
		resign_button.text = "🏳️ Rendirse"
		if not resign_button.pressed.is_connected(_on_resign_pressed):
			resign_button.pressed.connect(_on_resign_pressed)

	if offer_draw_button == null and has_node("Panel/VBoxContainer"):
		offer_draw_button = Button.new()
		offer_draw_button.name = "OfferDrawButton"
		offer_draw_button.text = "🤝 Ofrecer Tablas"
		$Panel/VBoxContainer.add_child(offer_draw_button)
		$Panel/VBoxContainer.move_child(offer_draw_button, 4)
	if offer_draw_button != null:
		offer_draw_button.text = "🤝 Ofrecer Tablas"
		if not offer_draw_button.pressed.is_connected(_on_offer_draw_pressed):
			offer_draw_button.pressed.connect(_on_offer_draw_pressed)

	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	_ensure_confirmation_dialog()

func is_network_mode() -> bool:
	if is_network_match:
		return true
	var br := _resolve_active_bridge()
	if br != null:
		if br.has_method("is_network_mode") and bool(br.call("is_network_mode")):
			return true
		if br.has_method("is_multiplayer") and bool(br.call("is_multiplayer")):
			return true
	return false

func set_network_mode(net_active: bool) -> void:
	is_network_match = net_active
	_update_undo_button_state()

func _update_undo_button_state() -> void:
	_ensure_ui_nodes()
	if undo_move_button == null:
		return
	var net := is_network_mode()
	undo_move_button.disabled = net
	undo_move_button.visible = not net

func undo_last_move() -> bool:
	if is_network_mode():
		_update_undo_button_state()
		return false

	var br := _resolve_active_bridge()
	if br != null:
		if br.has_method("undo_last_move"):
			if not bool(br.call("undo_last_move")):
				return false
		elif br.has_method("undo"):
			if not bool(br.call("undo")):
				return false

	undo_move_requested.emit()
	return true

func _on_undo_move_pressed() -> void:
	if undo_last_move():
		if is_inside_tree() and get_tree() != null:
			get_tree().paused = false
		hide()

func _ensure_confirmation_dialog() -> void:
	if confirm_dialog != null:
		return

	confirm_dialog = PanelContainer.new()
	confirm_dialog.name = "ConfirmDialog"
	confirm_dialog.visible = false
	confirm_dialog.custom_minimum_size = Vector2(360, 150)
	confirm_dialog.position = Vector2(460, 285)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.19, 0.98)
	style.border_color = Color(0.90, 0.72, 0.22, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	confirm_dialog.add_theme_stylebox_override("panel", style)
	add_child(confirm_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	confirm_dialog.add_child(vbox)

	confirm_label = Label.new()
	confirm_label.name = "ConfirmLabel"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.custom_minimum_size = Vector2(320, 48)
	confirm_label.text = "¿Confirmar acción?"
	vbox.add_child(confirm_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	confirm_yes_button = Button.new()
	confirm_yes_button.name = "ConfirmYesButton"
	confirm_yes_button.text = "Confirmar"
	confirm_yes_button.custom_minimum_size = Vector2(120, 36)
	confirm_yes_button.pressed.connect(_on_confirm_action_pressed)
	btn_hbox.add_child(confirm_yes_button)

	confirm_no_button = Button.new()
	confirm_no_button.name = "ConfirmNoButton"
	confirm_no_button.text = "Cancelar"
	confirm_no_button.custom_minimum_size = Vector2(120, 36)
	confirm_no_button.pressed.connect(cancel_confirmation)
	btn_hbox.add_child(confirm_no_button)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if confirm_dialog != null and confirm_dialog.visible:
			cancel_confirmation()
			return
		if rules_popup != null and rules_popup.visible:
			rules_popup.visible = false
			return
		_toggle_pause()

func _toggle_pause() -> void:
	if visible:
		if confirm_dialog != null:
			confirm_dialog.visible = false
		if rules_popup != null:
			rules_popup.visible = false
		hide()
		if is_inside_tree() and get_tree() != null:
			get_tree().paused = false
	else:
		_update_undo_button_state()
		show()
		if is_inside_tree() and get_tree() != null:
			get_tree().paused = true

func _detect_active_game_id() -> String:
	if not active_game_id.is_empty():
		return RulesCatalogRef.normalize_game_id(active_game_id)

	var p := get_parent()
	if p != null:
		var scr: Script = p.get_script()
		if scr != null and not scr.resource_path.is_empty():
			var fname := scr.resource_path.get_file().get_basename()
			if fname.ends_with("_board"):
				var gid := fname.substr(0, fname.length() - 6)
				return RulesCatalogRef.normalize_game_id(gid)

	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if "selected_game" in gm and not String(gm.selected_game).is_empty():
			return RulesCatalogRef.normalize_game_id(String(gm.selected_game))

	return "checkers"

func _resolve_active_bridge() -> Object:
	if active_bridge != null and is_instance_valid(active_bridge):
		return active_bridge
	var p := get_parent()
	while p != null:
		if p.has_node("Bridge"):
			return p.get_node("Bridge")
		elif p.get("bridge") != null:
			return p.get("bridge")
		p = p.get_parent()
	return null

func _resolve_active_player_id() -> int:
	var br := _resolve_active_bridge()
	if br != null and br.has_method("current_player"):
		var cp: int = int(br.call("current_player"))
		if cp > 0:
			return cp
	var p := get_parent()
	if p != null and p.get("current") != null:
		var c: int = int(p.get("current"))
		if c > 0:
			return c
	return active_player_id if active_player_id > 0 else 1

func _ensure_game_over_overlay() -> CanvasLayer:
	if game_over_overlay != null and is_instance_valid(game_over_overlay):
		return game_over_overlay

	var p := get_parent()
	if p != null:
		if p.get("game_over_overlay") != null and is_instance_valid(p.get("game_over_overlay")):
			game_over_overlay = p.get("game_over_overlay")
			return game_over_overlay

	if ResourceLoader.exists("res://game_over_overlay.tscn"):
		var scene: PackedScene = load("res://game_over_overlay.tscn")
		if scene != null:
			game_over_overlay = scene.instantiate()
	if game_over_overlay == null:
		game_over_overlay = preload("res://game_over_overlay.gd").new()

	var host_node: Node = get_parent() if get_parent() != null else self
	host_node.add_child(game_over_overlay)
	if not host_node.is_inside_tree() and game_over_overlay.has_method("_ready"):
		game_over_overlay._ready()
	return game_over_overlay

func _on_continue_pressed() -> void:
	_toggle_pause()

func _on_rules_pressed() -> void:
	if rules_popup == null:
		rules_popup = RulesPopup.new()
		rules_popup.position = Vector2(120, 80)
		add_child(rules_popup)
	rules_popup.show_for_game(_detect_active_game_id())

func _on_resign_pressed() -> void:
	_ensure_confirmation_dialog()
	pending_action = "resign"
	confirm_label.text = "¿Seguro que deseas rendirte?\nSe adjudicará la victoria a tu oponente."
	confirm_dialog.visible = true

func _on_offer_draw_pressed() -> void:
	_ensure_confirmation_dialog()
	pending_action = "draw"
	confirm_label.text = "¿Deseas ofrecer y declarar tablas (empate) en esta partida?"
	confirm_dialog.visible = true

func cancel_confirmation() -> void:
	pending_action = ""
	if confirm_dialog != null:
		confirm_dialog.visible = false

func _on_confirm_action_pressed() -> void:
	if pending_action == "resign":
		confirm_resign()
	elif pending_action == "draw":
		confirm_draw()

func confirm_resign() -> void:
	if confirm_dialog != null:
		confirm_dialog.visible = false
	pending_action = ""
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
	hide()

	var resigning_player := _resolve_active_player_id()
	var winner_id: int = 2 if resigning_player == 1 else 1
	var br := _resolve_active_bridge()
	if br != null and br.has_method("resign_match"):
		var res = br.call("resign_match", resigning_player)
		if typeof(res) == TYPE_INT and int(res) > 0:
			winner_id = int(res)

	var overlay := _ensure_game_over_overlay()
	if overlay != null and overlay.has_method("show_result"):
		overlay.call("show_result", winner_id, false)

	resign_confirmed.emit(resigning_player, winner_id)

func confirm_draw() -> void:
	if confirm_dialog != null:
		confirm_dialog.visible = false
	pending_action = ""
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
	hide()

	var br := _resolve_active_bridge()
	if br != null and br.has_method("declare_draw"):
		br.call("declare_draw")

	var overlay := _ensure_game_over_overlay()
	if overlay != null and overlay.has_method("show_result"):
		overlay.call("show_result", 0, true)

	draw_accepted.emit()

func _on_settings_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		var settings = load("res://settings_menu.tscn").instantiate()
		get_tree().root.add_child(settings)

func _on_quit_pressed() -> void:
	emit_signal("quit_game_requested")
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
	if is_inside_tree() and has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	elif is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://main.tscn")
