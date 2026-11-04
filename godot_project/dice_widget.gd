# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiceWidget
extends PanelContainer

signal animation_done

var dice_textures: Array[ImageTexture] = []
var dice_rects: Array[TextureRect] = []
var hbox: HBoxContainer
var dock_roller_3d: DiceRoller3D
var is_rolling: bool = false
var last_values: Array[int] = []

var _overlay_layer: CanvasLayer
var _overlay_panel: PanelContainer
var _overlay_roller_3d: DiceRoller3D
var _overlay_title_label: Label
var _overlay_outcome_label: Label

func _init() -> void:
	_generate_dice_textures()

func _ready() -> void:
	if not dice_rects.is_empty():
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.18, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.52, 0.68, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	# 3D Dock SubViewport in the corner HUD widget
	dock_roller_3d = DiceRoller3D.new(Vector2i(96, 48))
	dock_roller_3d.name = "DockRoller3D"
	dock_roller_3d.set_values_immediate([1])
	hbox.add_child(dock_roller_3d)

	for i in range(3):
		var rect: TextureRect = TextureRect.new()
		rect.custom_minimum_size = Vector2(36, 36)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = dice_textures[0] if dice_textures.size() > 0 else null
		rect.visible = false
		hbox.add_child(rect)
		dice_rects.append(rect)

func _ensure_center_overlay() -> void:
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		return

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "Dice3DOverlayLayer"
	_overlay_layer.layer = 45
	add_child(_overlay_layer)

	var center_wrap: CenterContainer = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(center_wrap)

	_overlay_panel = PanelContainer.new()
	_overlay_panel.name = "CenterThrowPanel3D"
	_overlay_panel.custom_minimum_size = Vector2(300, 210)
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_panel.visible = false

	var ov_style: StyleBoxFlat = StyleBoxFlat.new()
	ov_style.bg_color = Color(0.07, 0.11, 0.17, 0.92)
	ov_style.border_color = Color(0.95, 0.80, 0.32, 0.95)
	ov_style.set_border_width_all(2)
	ov_style.set_corner_radius_all(14)
	ov_style.content_margin_left = 14
	ov_style.content_margin_right = 14
	ov_style.content_margin_top = 10
	ov_style.content_margin_bottom = 10
	_overlay_panel.add_theme_stylebox_override("panel", ov_style)
	center_wrap.add_child(_overlay_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_panel.add_child(vbox)

	_overlay_title_label = Label.new()
	_overlay_title_label.text = "🎲 TIRADA 3D"
	_overlay_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title_label.add_theme_font_size_override("font_size", 14)
	_overlay_title_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.42))
	vbox.add_child(_overlay_title_label)

	_overlay_roller_3d = DiceRoller3D.new(Vector2i(268, 136))
	_overlay_roller_3d.name = "OverlayRoller3D"
	vbox.add_child(_overlay_roller_3d)

	_overlay_outcome_label = Label.new()
	_overlay_outcome_label.text = "Lanzando dados..."
	_overlay_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_outcome_label.add_theme_font_size_override("font_size", 17)
	_overlay_outcome_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	vbox.add_child(_overlay_outcome_label)

func _generate_dice_textures() -> void:
	dice_textures.clear()
	for val in range(1, 7):
		var img: Image = Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.96, 0.96, 0.92, 1.0))

		for x in range(48):
			for y in range(48):
				if x < 2 or x >= 46 or y < 2 or y >= 46:
					img.set_pixel(x, y, Color(0.2, 0.2, 0.2, 1.0))
				var c1: bool = x < 4 and y < 4 and (x - 4) * (x - 4) + (y - 4) * (y - 4) > 16
				var c2: bool = x >= 44 and y < 4 and (x - 43) * (x - 43) + (y - 4) * (y - 4) > 16
				var c3: bool = x < 4 and y >= 44 and (x - 4) * (x - 4) + (y - 43) * (y - 43) > 16
				var c4: bool = x >= 44 and y >= 44 and (x - 43) * (x - 43) + (y - 43) * (y - 43) > 16
				if c1 or c2 or c3 or c4:
					img.set_pixel(x, y, Color(0, 0, 0, 0))

		var pips: Array[Vector2i] = []
		match val:
			1:
				pips = [Vector2i(24, 24)]
			2:
				pips = [Vector2i(14, 14), Vector2i(34, 34)]
			3:
				pips = [Vector2i(14, 14), Vector2i(24, 24), Vector2i(34, 34)]
			4:
				pips = [Vector2i(14, 14), Vector2i(34, 14), Vector2i(14, 34), Vector2i(34, 34)]
			5:
				pips = [Vector2i(14, 14), Vector2i(34, 14), Vector2i(24, 24), Vector2i(14, 34), Vector2i(34, 34)]
			6:
				pips = [Vector2i(14, 12), Vector2i(34, 12), Vector2i(14, 24), Vector2i(34, 24), Vector2i(14, 36), Vector2i(34, 36)]

		for center in pips:
			for dx in range(-4, 5):
				for dy in range(-4, 5):
					if dx * dx + dy * dy <= 16:
						var px: int = center.x + dx
						var py: int = center.y + dy
						if px >= 0 and px < 48 and py >= 0 and py < 48:
							img.set_pixel(px, py, Color(0.15, 0.15, 0.20, 1.0))

		var tex: ImageTexture = ImageTexture.create_from_image(img)
		dice_textures.append(tex)

func _format_outcome_summary(clean_vals: Array[int]) -> String:
	var faces: Array[String] = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
	var parts: PackedStringArray = PackedStringArray()
	var total: int = 0
	for v in clean_vals:
		var idx: int = clampi(v - 1, 0, 5)
		parts.append("%s %d" % [faces[idx], v])
		total += v
	if clean_vals.size() == 1:
		return "Resultado: %s" % parts[0]
	return "Resultado: %s  (Total: %d)" % [" + ".join(parts), total]

func _apply_final_values_to_dock(clean_vals: Array[int]) -> void:
	var count: int = mini(clean_vals.size(), 3)
	for i in range(dice_rects.size()):
		dice_rects[i].visible = (i < count)
		if i < count:
			var idx: int = clampi(clean_vals[i] - 1, 0, dice_textures.size() - 1)
			dice_rects[i].texture = dice_textures[idx]
	if dock_roller_3d != null:
		dock_roller_3d.set_values_immediate(clean_vals)

func wait_if_rolling() -> void:
	if is_rolling and is_inside_tree() and not OS.has_feature("headless"):
		await animation_done

func show_roll(values: Array) -> void:
	if values.is_empty():
		return
	if dice_rects.is_empty():
		_ready()

	var clean_vals: Array[int] = []
	var count: int = mini(values.size(), 3)
	for i in range(count):
		clean_vals.append(clampi(int(values[i]), 1, 6))
	last_values = clean_vals.duplicate()
	is_rolling = true

	for i in range(dice_rects.size()):
		dice_rects[i].visible = (i < count)

	if is_inside_tree() and not OS.has_feature("headless"):
		_ensure_center_overlay()
		_overlay_panel.modulate = Color(1, 1, 1, 1)
		_overlay_panel.visible = true
		_overlay_title_label.text = "🎲 DADO 3D EN AIRE" if count == 1 else "🎲 DADOS 3D EN AIRE"
		_overlay_outcome_label.text = "Rodando..."

		# Launch 3D dock & 3D center overlay simultaneously
		if dock_roller_3d != null:
			dock_roller_3d.play_3d_roll(clean_vals, 0.46, 0.0)
		if _overlay_roller_3d != null:
			await _overlay_roller_3d.play_3d_roll(clean_vals, 0.46, 0.08)

		_apply_final_values_to_dock(clean_vals)
		_overlay_title_label.text = "✨ RESULTADO CONFIRMADO"
		_overlay_outcome_label.text = _format_outcome_summary(clean_vals)

		# Brief pause on the settled 3D outcome before player tokens move
		await get_tree().create_timer(0.34).timeout
		if _overlay_panel != null and is_instance_valid(_overlay_panel):
			_overlay_panel.visible = false
	else:
		_apply_final_values_to_dock(clean_vals)

	is_rolling = false
	animation_done.emit()

func roll_animation(val: int, _duration: float = 0.45, _steps: int = 3) -> void:
	await show_roll([val])
