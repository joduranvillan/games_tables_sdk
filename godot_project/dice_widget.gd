class_name DiceWidget
extends PanelContainer

signal animation_done

var dice_textures: Array[ImageTexture] = []
var dice_rects: Array[TextureRect] = []
var hbox: HBoxContainer
var is_rolling: bool = false

func _init() -> void:
	_generate_dice_textures()

func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 0.8)
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
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	for i in range(3):
		var rect = TextureRect.new()
		rect.custom_minimum_size = Vector2(44, 44)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = dice_textures[0] if dice_textures.size() > 0 else null
		rect.visible = false
		hbox.add_child(rect)
		dice_rects.append(rect)

func _generate_dice_textures() -> void:
	dice_textures.clear()
	for val in range(1, 7):
		var img = Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
		# Background: warm ivory white
		img.fill(Color(0.96, 0.96, 0.92, 1.0))

		# Border: dark gray
		for x in range(48):
			for y in range(48):
				if x < 2 or x >= 46 or y < 2 or y >= 46:
					img.set_pixel(x, y, Color(0.2, 0.2, 0.2, 1.0))
				# Rounded corners
				if (x < 4 and y < 4 and (x-4)*(x-4) + (y-4)*(y-4) > 16) or \
				   (x >= 44 and y < 4 and (x-43)*(x-43) + (y-4)*(y-4) > 16) or \
				   (x < 4 and y >= 44 and (x-4)*(x-4) + (y-43)*(y-43) > 16) or \
				   (x >= 44 and y >= 44 and (x-43)*(x-43) + (y-43)*(y-43) > 16):
					img.set_pixel(x, y, Color(0, 0, 0, 0))

		# Pips (dots)
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
					if dx*dx + dy*dy <= 16:
						var px = center.x + dx
						var py = center.y + dy
						if px >= 0 and px < 48 and py >= 0 and py < 48:
							img.set_pixel(px, py, Color(0.15, 0.15, 0.20, 1.0))

		var tex = ImageTexture.create_from_image(img)
		dice_textures.append(tex)

func show_roll(values: Array) -> void:
	if values.is_empty():
		return
	is_rolling = true
	var count = min(values.size(), 3)
	for i in range(dice_rects.size()):
		dice_rects[i].visible = (i < count)

	var total_frames = 15 # 15 frames at 30fps = 0.5s
	var frame_delay = 0.5 / total_frames

	if is_inside_tree():
		for f in range(total_frames):
			for i in range(count):
				var rand_val = randi() % 6
				dice_rects[i].texture = dice_textures[rand_val]
			await get_tree().create_timer(frame_delay).timeout

	for i in range(count):
		var v = int(values[i])
		var idx = clamp(v - 1, 0, 5)
		dice_rects[i].texture = dice_textures[idx]

	is_rolling = false
	animation_done.emit()

func roll_animation(val: int, duration: float = 0.4, steps: int = 3) -> void:
	is_rolling = true
	if dice_rects.size() > 0:
		dice_rects[0].visible = true
	for i in range(1, dice_rects.size()):
		dice_rects[i].visible = false

	var step_delay = duration / float(max(1, steps))
	if is_inside_tree():
		for s in range(steps):
			var rand_val = randi() % 6
			if dice_textures.size() > rand_val and dice_rects.size() > 0:
				dice_rects[0].texture = dice_textures[rand_val]
			await get_tree().create_timer(step_delay).timeout

	if dice_rects.size() > 0 and dice_textures.size() > 0:
		var idx = clamp(val - 1, 0, dice_textures.size() - 1)
		dice_rects[0].texture = dice_textures[idx]

	is_rolling = false
	animation_done.emit()
