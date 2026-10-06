extends CanvasLayer

signal next_requested()
signal skip_requested()

var steps: Array = []
var current_step: int = 0
var blink_phase: float = 0.0
var cell_pixel_size: float = 64.0
var board_origin_px: Vector2 = Vector2(64, 64)

var highlight_polygon: Polygon2D
var arrow_line: Line2D
var panel_container: PanelContainer
var instruction_label: RichTextLabel
var next_button: Button
var skip_button: Button

func _ready() -> void:
	layer = 35
	_ensure_ui()

func _ensure_ui() -> void:
	if highlight_polygon == null:
		highlight_polygon = get_node_or_null("HighlightPolygon")
		if highlight_polygon == null:
			highlight_polygon = Polygon2D.new()
			highlight_polygon.name = "HighlightPolygon"
			highlight_polygon.color = Color(1.0, 0.90, 0.20, 0.45)
			highlight_polygon.polygon = PackedVector2Array([
				Vector2(0, 0),
				Vector2(cell_pixel_size, 0),
				Vector2(cell_pixel_size, cell_pixel_size),
				Vector2(0, cell_pixel_size),
			])
			highlight_polygon.visible = false
			add_child(highlight_polygon)

	if arrow_line == null:
		arrow_line = get_node_or_null("ArrowLine")
		if arrow_line == null:
			arrow_line = Line2D.new()
			arrow_line.name = "ArrowLine"
			arrow_line.width = 6.0
			arrow_line.default_color = Color(0.25, 0.90, 1.0, 0.95)
			arrow_line.visible = false
			add_child(arrow_line)

	if panel_container == null:
		panel_container = get_node_or_null("Panel")
		if panel_container == null:
			panel_container = PanelContainer.new()
			panel_container.name = "Panel"
			panel_container.position = Vector2(180, 560)
			panel_container.custom_minimum_size = Vector2(920, 120)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.08, 0.11, 0.16, 0.88)
			style.border_color = Color(0.4, 0.75, 1.0, 0.9)
			style.set_border_width_all(2)
			style.set_corner_radius_all(10)
			style.set_content_margin_all(14)
			panel_container.add_theme_stylebox_override("panel", style)
			add_child(panel_container)

			var vbox := VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 10)
			panel_container.add_child(vbox)

			instruction_label = RichTextLabel.new()
			instruction_label.name = "InstructionLabel"
			instruction_label.bbcode_enabled = true
			instruction_label.fit_content = true
			instruction_label.custom_minimum_size = Vector2(880, 52)
			vbox.add_child(instruction_label)

			var btn_hbox := HBoxContainer.new()
			btn_hbox.alignment = BoxContainer.ALIGNMENT_END
			btn_hbox.add_theme_constant_override("separation", 12)
			vbox.add_child(btn_hbox)

			skip_button = Button.new()
			skip_button.name = "SkipButton"
			skip_button.text = "Saltar Tutorial"
			skip_button.custom_minimum_size = Vector2(150, 36)
			skip_button.pressed.connect(_on_skip_pressed)
			btn_hbox.add_child(skip_button)

			next_button = Button.new()
			next_button.name = "NextButton"
			next_button.text = "Siguiente ▶"
			next_button.custom_minimum_size = Vector2(150, 36)
			next_button.pressed.connect(_on_next_pressed)
			btn_hbox.add_child(next_button)

func _process(delta: float) -> void:
	blink_phase += delta * 4.0
	if highlight_polygon != null and highlight_polygon.visible:
		highlight_polygon.color.a = 0.25 + 0.30 * (0.5 + 0.5 * sin(blink_phase))
	if arrow_line != null and arrow_line.visible:
		arrow_line.modulate.a = 0.65 + 0.35 * (0.5 + 0.5 * cos(blink_phase))

func _cell_to_pixel(cell: Vector2i, board_node: Node) -> Vector2:
	if board_node != null and board_node.has_method("cell_to_pixel"):
		return board_node.call("cell_to_pixel", cell)
	return board_origin_px + Vector2(cell.x * cell_pixel_size, cell.y * cell_pixel_size)

func display_tutorial_step(step: Variant, step_idx: int, total_steps: int, board_node: Node = null) -> void:
	_ensure_ui()
	var txt := ""
	var hl := Vector2i(-1, -1)
	var a_from := Vector2i(-1, -1)
	var a_to := Vector2i(-1, -1)
	var wait_action := false

	if step is Dictionary:
		txt = str(step.get("text", ""))
		hl = step.get("highlight_cell", Vector2i(-1, -1))
		a_from = step.get("arrow_from", Vector2i(-1, -1))
		a_to = step.get("arrow_to", Vector2i(-1, -1))
		wait_action = bool(step.get("wait_for_action", false))
	elif step is Object:
		txt = str(step.get("text"))
		hl = step.get("highlight_cell")
		a_from = step.get("arrow_from")
		a_to = step.get("arrow_to")
		wait_action = bool(step.get("wait_for_action"))

	instruction_label.text = "[b]Paso %d/%d:[/b] %s" % [step_idx + 1, maxi(total_steps, 1), txt]
	next_button.disabled = wait_action

	if hl != Vector2i(-1, -1):
		highlight_polygon.position = _cell_to_pixel(hl, board_node)
		highlight_polygon.visible = true
	else:
		highlight_polygon.visible = false

	if a_from != Vector2i(-1, -1) and a_to != Vector2i(-1, -1):
		var half := Vector2(cell_pixel_size * 0.5, cell_pixel_size * 0.5)
		var p_start := _cell_to_pixel(a_from, board_node) + half
		var p_end := _cell_to_pixel(a_to, board_node) + half
		arrow_line.points = PackedVector2Array([p_start, p_end])
		arrow_line.visible = true
	else:
		arrow_line.visible = false

	show()

func load_tutorial(game_name: String) -> void:
	_ensure_ui()
	var file := FileAccess.open("res://tutorials/" + game_name + ".json", FileAccess.READ)
	if file != null:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			steps = json.data
			current_step = 0
			show_step()
			show()

func show_step() -> void:
	_ensure_ui()
	if current_step < steps.size():
		display_tutorial_step(steps[current_step], current_step, steps.size())
	else:
		hide()

func _on_next_pressed() -> void:
	next_requested.emit()
	if not steps.is_empty():
		current_step += 1
		show_step()

func _on_skip_pressed() -> void:
	skip_requested.emit()
	hide()
