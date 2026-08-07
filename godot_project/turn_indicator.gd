## Widget de indicador de turno con avatar de color, nombre de jugador y timer.
class_name TurnIndicator
extends HBoxContainer

@export var default_time: float = 30.0

var color_rect: ColorRect
var label: Label
var timer_bar: ProgressBar
var theme_btn: Button
var undo_btn: Button
var redo_btn: Button

var timer_active: bool = false
var time_max: float = 30.0
var time_left: float = 30.0
var current_player_id: int = 1

var pulse_tween: Tween
var bridge_node = null

func _init() -> void:
	custom_minimum_size = Vector2(360, 40)
	add_theme_constant_override("separation", 12)
	
func _ready() -> void:
	_setup_nodes()
	_find_and_bind_bridge()

func _find_and_bind_bridge() -> void:
	var p = get_parent()
	while p != null:
		if p.has_node("Bridge"):
			bind_bridge(p.get_node("Bridge"))
			return
		elif p.get("bridge") != null:
			bind_bridge(p.get("bridge"))
			return
		p = p.get_parent()

func bind_bridge(p_bridge) -> void:
	if bridge_node != null and bridge_node.is_connected("turn_changed", _on_turn_changed):
		bridge_node.disconnect("turn_changed", _on_turn_changed)
	bridge_node = p_bridge
	if bridge_node != null:
		if not bridge_node.is_connected("turn_changed", _on_turn_changed):
			bridge_node.connect("turn_changed", _on_turn_changed)
		var p_id = bridge_node.current_player()
		if p_id > 0:
			_on_turn_changed(p_id)

func _on_turn_changed(player_id: int) -> void:
	var p_col = Color.WHITE
	if is_inside_tree() and has_node("/root/GameManager"):
		p_col = get_node("/root/GameManager").get_player_color(player_id)
	var p_name = get_configured_player_name(player_id)
	set_turn(player_id, p_name, p_col)

func _setup_nodes() -> void:
	# 1. Color avatar box
	color_rect = ColorRect.new()
	color_rect.name = "PlayerColor"
	color_rect.custom_minimum_size = Vector2(28, 28)
	color_rect.size_flags_vertical = SIZE_SHRINK_CENTER
	color_rect.color = Color.WHITE
	add_child(color_rect)
	
	# 2. Player name label
	label = Label.new()
	label.name = "PlayerLabel"
	label.text = "Turno: Jugador 1"
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	
	# 3. Timer ProgressBar
	timer_bar = ProgressBar.new()
	timer_bar.name = "TurnTimer"
	timer_bar.custom_minimum_size = Vector2(100, 20)
	timer_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	timer_bar.show_percentage = false
	timer_bar.value = 100.0
	add_child(timer_bar)
	
	# 4. Undo button
	undo_btn = Button.new()
	undo_btn.name = "UndoButton"
	undo_btn.text = "⟵ Deshacer"
	undo_btn.custom_minimum_size = Vector2(80, 30)
	undo_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	undo_btn.add_theme_font_size_override("font_size", 12)
	undo_btn.pressed.connect(_on_undo_pressed)
	add_child(undo_btn)

	# 5. Redo button
	redo_btn = Button.new()
	redo_btn.name = "RedoButton"
	redo_btn.text = "Rehacer ⟶"
	redo_btn.custom_minimum_size = Vector2(80, 30)
	redo_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	redo_btn.add_theme_font_size_override("font_size", 12)
	redo_btn.pressed.connect(_on_redo_pressed)
	add_child(redo_btn)

	# 6. Theme switcher button
	theme_btn = Button.new()
	theme_btn.name = "ThemeButton"
	theme_btn.text = "🎨 Tema"
	theme_btn.custom_minimum_size = Vector2(75, 30)
	theme_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	theme_btn.add_theme_font_size_override("font_size", 12)
	theme_btn.pressed.connect(_on_theme_pressed)
	add_child(theme_btn)

func get_configured_player_name(player_id: int, fallback_name: String = "") -> String:
	if is_inside_tree() and has_node("/root/SettingsMenu"):
		var settings = SettingsMenu.get_saved_settings()
		if player_id == 1:
			var p1 = settings.get("player1_name", "")
			if p1 != "":
				return p1
		elif player_id == 2:
			var p2 = settings.get("player2_name", "")
			if p2 != "":
				return p2
	if fallback_name != "" and not fallback_name.begins_with("Turno: Jugador") and not fallback_name.begins_with("Jugador"):
		return fallback_name
	return "Jugador %d" % player_id

func set_turn(player_id: int, player_name: String, player_color: Color) -> void:
	current_player_id = player_id
	if color_rect:
		color_rect.color = player_color
		
	var display_name = get_configured_player_name(player_id, player_name)
	if label:
		label.text = "Turno: " + display_name
		_animate_label_slide()
		
	_start_pulse_animation()
	start_timer(default_time)

func _start_pulse_animation() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	if color_rect == null:
		return
	color_rect.pivot_offset = Vector2(14, 14)
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(color_rect, "scale", Vector2(1.05, 1.05), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(color_rect, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _animate_label_slide() -> void:
	if label == null:
		return
	var orig_pos = label.position
	label.position.x = orig_pos.x + 30.0
	label.modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:x", orig_pos.x, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.3)

func start_timer(seconds: float) -> void:
	time_max = seconds
	time_left = seconds
	timer_active = true
	timer_bar.value = 100.0

func stop_timer() -> void:
	timer_active = false
	timer_bar.value = 0.0
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()

func _process(delta: float) -> void:
	if timer_active and time_max > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			timer_active = false
		timer_bar.value = (time_left / time_max) * 100.0
	_update_undo_redo_status()

func _on_undo_pressed() -> void:
	if bridge_node != null and bridge_node.has_method("undo"):
		bridge_node.undo()
		_update_undo_redo_status()

func _on_redo_pressed() -> void:
	if bridge_node != null and bridge_node.has_method("redo"):
		bridge_node.redo()
		_update_undo_redo_status()

func _update_undo_redo_status() -> void:
	if bridge_node == null:
		if undo_btn: undo_btn.disabled = true
		if redo_btn: redo_btn.disabled = true
		return

	if bridge_node.has_method("is_multiplayer") and bridge_node.is_multiplayer():
		if undo_btn: undo_btn.disabled = true
		if redo_btn: redo_btn.disabled = true
		return

	if undo_btn:
		if bridge_node.has_method("can_undo"):
			undo_btn.disabled = not bridge_node.can_undo()
		else:
			undo_btn.disabled = false

	if redo_btn:
		if bridge_node.has_method("can_redo"):
			redo_btn.disabled = not bridge_node.can_redo()
		else:
			redo_btn.disabled = false

func _on_theme_pressed() -> void:
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			var new_t = tm.toggle_theme()
			theme_btn.text = "🎨 " + new_t.theme_name
