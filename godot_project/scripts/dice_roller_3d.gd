# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiceRoller3D
extends SubViewportContainer

signal roll_completed(values: Array)

const MAX_DICE: int = 3

var sub_viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var dice_nodes: Array[Node3D] = []
var face_textures: Array[ImageTexture] = []
var current_values: Array[int] = [1]
var is_animating: bool = false

func _init(viewport_size: Vector2i = Vector2i(260, 160)) -> void:
	stretch = true
	custom_minimum_size = Vector2(float(viewport_size.x), float(viewport_size.y))
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_generate_face_textures()
	_build_3d_scene(viewport_size)

func _generate_face_textures() -> void:
	face_textures.clear()
	for val in range(1, 7):
		var img: Image = Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.97, 0.96, 0.92, 1.0))

		# Bevel border & subtle corner shading
		for x in range(128):
			for y in range(128):
				var edge_dist: int = mini(mini(x, 127 - x), mini(y, 127 - y))
				if edge_dist < 4:
					img.set_pixel(x, y, Color(0.22, 0.22, 0.26, 1.0))
				elif edge_dist < 8:
					img.set_pixel(x, y, Color(0.88, 0.86, 0.80, 1.0))

		var pips: Array[Vector2i] = []
		match val:
			1:
				pips = [Vector2i(64, 64)]
			2:
				pips = [Vector2i(36, 36), Vector2i(92, 92)]
			3:
				pips = [Vector2i(34, 34), Vector2i(64, 64), Vector2i(94, 94)]
			4:
				pips = [Vector2i(36, 36), Vector2i(92, 36), Vector2i(36, 92), Vector2i(92, 92)]
			5:
				pips = [Vector2i(34, 34), Vector2i(94, 34), Vector2i(64, 64), Vector2i(34, 94), Vector2i(94, 94)]
			6:
				pips = [Vector2i(36, 30), Vector2i(92, 30), Vector2i(36, 64), Vector2i(92, 64), Vector2i(36, 98), Vector2i(92, 98)]

		var pip_color: Color = Color(0.78, 0.14, 0.14, 1.0) if (val == 1 or val == 4) else Color(0.12, 0.14, 0.20, 1.0)
		var radius: int = 14 if val == 1 else 11
		var r_sq: int = radius * radius
		for center in pips:
			for dx in range(-radius - 1, radius + 2):
				for dy in range(-radius - 1, radius + 2):
					var d_sq: int = dx * dx + dy * dy
					if d_sq <= r_sq:
						var px: int = center.x + dx
						var py: int = center.y + dy
						if px >= 0 and px < 128 and py >= 0 and py < 128:
							img.set_pixel(px, py, pip_color)

		var tex: ImageTexture = ImageTexture.create_from_image(img)
		face_textures.append(tex)

func _build_3d_scene(viewport_size: Vector2i) -> void:
	sub_viewport = SubViewport.new()
	sub_viewport.name = "DiceSubViewport"
	sub_viewport.own_world_3d = true
	sub_viewport.transparent_bg = true
	sub_viewport.size = viewport_size
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub_viewport)

	world_root = Node3D.new()
	world_root.name = "DiceWorld3D"
	sub_viewport.add_child(world_root)

	camera = Camera3D.new()
	camera.name = "DiceCamera3D"
	camera.position = Vector3(0.0, 4.35, 1.85)
	camera.rotation_degrees = Vector3(-67.0, 0.0, 0.0)
	camera.fov = 38.0
	world_root.add_child(camera)

	key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight3D"
	key_light.rotation_degrees = Vector3(-58.0, 28.0, 0.0)
	key_light.light_energy = 1.25
	world_root.add_child(key_light)

	fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight3D"
	fill_light.rotation_degrees = Vector3(-35.0, -45.0, 0.0)
	fill_light.light_energy = 0.55
	world_root.add_child(fill_light)

	dice_nodes.clear()
	for i in range(MAX_DICE):
		var die: Node3D = _create_single_die_3d(i)
		die.visible = (i == 0)
		world_root.add_child(die)
		dice_nodes.append(die)

func _create_single_die_3d(idx: int) -> Node3D:
	var die_root: Node3D = Node3D.new()
	die_root.name = "Die3D_%d" % idx

	# Inner bevel core block
	var core_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(0.96, 0.96, 0.96)
	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.88, 0.86, 0.80, 1.0)
	core_mat.roughness = 0.35
	box_mesh.material = core_mat
	core_inst.mesh = box_mesh
	die_root.add_child(core_inst)

	# Canonical 6 faces (opposite faces sum to 7):
	# 1: +Y, 6: -Y, 2: +Z, 5: -Z, 3: +X, 4: -X
	var face_defs: Array[Dictionary] = [
		{"val": 1, "pos": Vector3(0.0, 0.485, 0.0), "rot": Vector3(-90.0, 0.0, 0.0)},
		{"val": 6, "pos": Vector3(0.0, -0.485, 0.0), "rot": Vector3(90.0, 0.0, 0.0)},
		{"val": 2, "pos": Vector3(0.0, 0.0, 0.485), "rot": Vector3(0.0, 0.0, 0.0)},
		{"val": 5, "pos": Vector3(0.0, 0.0, -0.485), "rot": Vector3(0.0, 180.0, 0.0)},
		{"val": 3, "pos": Vector3(0.485, 0.0, 0.0), "rot": Vector3(0.0, 90.0, 0.0)},
		{"val": 4, "pos": Vector3(-0.485, 0.0, 0.0), "rot": Vector3(0.0, -90.0, 0.0)}
	]

	for f_def in face_defs:
		var f_val: int = int(f_def["val"])
		var f_pos: Vector3 = f_def["pos"]
		var f_rot: Vector3 = f_def["rot"]

		var face_inst: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.92, 0.92)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		if f_val >= 1 and f_val <= face_textures.size():
			mat.albedo_texture = face_textures[f_val - 1]
		mat.roughness = 0.25
		mat.metallic = 0.05
		quad.material = mat
		face_inst.mesh = quad
		face_inst.position = f_pos
		face_inst.rotation_degrees = f_rot
		die_root.add_child(face_inst)

	return die_root

## Returns the exact Euler rotation (in degrees) that places face `val` (1..6) on top (+Y).
static func get_target_rotation_for_value(val: int) -> Vector3:
	var clamped: int = clampi(val, 1, 6)
	match clamped:
		1:
			return Vector3(0.0, 0.0, 0.0)
		2:
			return Vector3(-90.0, 0.0, 0.0)
		3:
			return Vector3(0.0, 0.0, 90.0)
		4:
			return Vector3(0.0, 0.0, -90.0)
		5:
			return Vector3(90.0, 0.0, 0.0)
		6:
			return Vector3(180.0, 0.0, 0.0)
	return Vector3.ZERO

func _get_rest_position(index: int, total_count: int) -> Vector3:
	if total_count <= 1:
		return Vector3.ZERO
	elif total_count == 2:
		var x_off: float = -0.78 if index == 0 else 0.78
		return Vector3(x_off, 0.0, 0.0)
	else:
		var offsets: Array[Vector3] = [
			Vector3(-1.18, 0.0, 0.08),
			Vector3(0.0, 0.0, -0.10),
			Vector3(1.18, 0.0, 0.08)
		]
		return offsets[clampi(index, 0, 2)]

func set_values_immediate(values: Array) -> void:
	current_values.clear()
	var count: int = mini(values.size(), MAX_DICE)
	if count <= 0:
		return
	for i in range(MAX_DICE):
		var die: Node3D = dice_nodes[i]
		if i < count:
			var v: int = clampi(int(values[i]), 1, 6)
			current_values.append(v)
			die.visible = true
			die.position = _get_rest_position(i, count)
			die.rotation_degrees = get_target_rotation_for_value(v)
			die.scale = Vector3.ONE
		else:
			die.visible = false

func get_die_rotation_degrees(index: int) -> Vector3:
	if index >= 0 and index < dice_nodes.size():
		return dice_nodes[index].rotation_degrees
	return Vector3.ZERO

func play_3d_roll(values: Array, roll_duration: float = 0.48, hold_duration: float = 0.35) -> void:
	if values.is_empty():
		return
	set_values_immediate(values)
	var count: int = mini(values.size(), MAX_DICE)

	if not is_inside_tree() or OS.has_feature("headless"):
		is_animating = false
		roll_completed.emit(current_values.duplicate())
		return

	is_animating = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	for i in range(count):
		var die: Node3D = dice_nodes[i]
		var target_val: int = current_values[i]
		var target_rot: Vector3 = get_target_rotation_for_value(target_val)
		var rest_pos: Vector3 = _get_rest_position(i, count)

		# Launch from lower-back with multi-axis spin
		var start_pos: Vector3 = rest_pos + Vector3(float(i - 1) * 0.25, 1.35, 1.15)
		var spin_turns_x: float = 720.0 + float(i * 360)
		var spin_turns_y: float = 360.0 * float((i % 2) * 2 - 1)
		var spin_turns_z: float = 720.0
		var start_rot: Vector3 = target_rot - Vector3(spin_turns_x, spin_turns_y, spin_turns_z)

		die.position = start_pos
		die.rotation_degrees = start_rot
		die.scale = Vector3(0.88, 0.88, 0.88)

		# Rotational tumble settling on exact target face
		tween.tween_property(die, "rotation_degrees", target_rot, roll_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(die, "scale", Vector3.ONE, roll_duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Parabolic throw + tabletop bounce trajectory
		var d_node: Node3D = die
		var s_pos: Vector3 = start_pos
		var e_pos: Vector3 = rest_pos
		var traj_fn: Callable = func(t: float) -> void:
			if not is_instance_valid(d_node):
				return
			var horiz: Vector3 = s_pos.lerp(e_pos, t)
			var bounce_y: float = 0.0
			if t < 0.72:
				var p1: float = t / 0.72
				bounce_y = sin(p1 * PI) * 1.45 + (1.0 - p1) * s_pos.y
			else:
				var p2: float = (t - 0.72) / 0.28
				bounce_y = sin(p2 * PI) * 0.36
			d_node.position = Vector3(horiz.x, bounce_y, horiz.z)
		tween.tween_method(traj_fn, 0.0, 1.0, roll_duration)

	await tween.finished

	# Outcome settlement highlight pulse & brief hold so player sees the 3D result before tokens move
	if is_inside_tree() and hold_duration > 0.0:
		var pulse_tween: Tween = create_tween()
		pulse_tween.set_parallel(true)
		for i in range(count):
			var die_p: Node3D = dice_nodes[i]
			pulse_tween.tween_property(die_p, "scale", Vector3(1.10, 1.10, 1.10), hold_duration * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			pulse_tween.tween_property(die_p, "scale", Vector3.ONE, hold_duration * 0.65).set_delay(hold_duration * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await pulse_tween.finished

	is_animating = false
	roll_completed.emit(current_values.duplicate())
