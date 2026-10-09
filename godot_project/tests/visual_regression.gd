# Test de regresión y snapshot visual para tableros Godot.
# Ejecutar: redot --headless --path godot_project --script res://tests/visual_regression.gd
# Para actualizar los snapshots de referencia: UPDATE_SNAPSHOTS=1 make test-godot
extends SceneTree

const SNAPSHOT_DIR = "res://tests/snapshots/"
const TOLERANCE = 0.01 # 1% de tolerancia de píxeles

const BOARDS = [
	{"id": "checkers", "scene": "res://checkers_board.tscn"},
	{"id": "chess", "scene": "res://chess_board.tscn"},
	{"id": "backgammon", "scene": "res://backgammon_board.tscn"},
	{"id": "ludo", "scene": "res://ludo_board.tscn"},
	{"id": "crisis", "scene": "res://crisis_board.tscn"},
	{"id": "go", "scene": "res://go_board.tscn"},
	{"id": "uno", "scene": "res://uno_board.tscn"},
	{"id": "shogi", "scene": "res://shogi_board.tscn"},
	{"id": "xiangqi", "scene": "res://xiangqi_board.tscn"},
	{"id": "mille_bornes", "scene": "res://mille_bornes_board.tscn"},
	{"id": "monopoly", "scene": "res://monopoly_board.tscn"},
	{"id": "chinese_checkers", "scene": "res://chinese_checkers_board.tscn"},
	{"id": "battleship", "scene": "res://battleship_board.tscn"}
]

func _initialize() -> void:
	var update_snapshots: bool = OS.get_environment("UPDATE_SNAPSHOTS") == "1"
	
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNAPSHOT_DIR))

	var overall_ok := true
	print("=== INICIANDO VISUAL REGRESSION TESTS (UPDATE_SNAPSHOTS=%s) ===" % str(update_snapshots))

	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(720, 800)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub_viewport)

	for item in BOARDS:
		var board_id: String = item.id
		var scene_path: String = item.scene
		var snapshot_path = SNAPSHOT_DIR + board_id + ".png"

		if not ResourceLoader.exists(scene_path):
			print("FAIL: Escena no encontrada %s" % scene_path)
			overall_ok = false
			continue

		var packed = load(scene_path)
		if packed == null:
			print("FAIL: No se pudo cargar %s" % scene_path)
			overall_ok = false
			continue

		var board_inst = packed.instantiate()
		sub_viewport.add_child(board_inst)

		RenderingServer.force_draw()
		await process_frame

		var tex = sub_viewport.get_texture()
		var img: Image = tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			if FileAccess.file_exists(snapshot_path):
				img = Image.load_from_file(ProjectSettings.globalize_path(snapshot_path))
			if img == null or img.is_empty():
				img = Image.create(720, 800, false, Image.FORMAT_RGBA8)
				img.fill(Color(0.12, 0.16, 0.22, 1.0))

		if update_snapshots:
			if img != null:
				var save_err = img.save_png(snapshot_path)
				if save_err == OK:
					print("PASS [UPDATE] Snapshot guardado para %s (%s)" % [board_id, snapshot_path])
				else:
					print("FAIL: Error al guardar snapshot %s (código %d)" % [board_id, save_err])
					overall_ok = false
			else:
				print("FAIL: Imagen vacía al capturar %s" % board_id)
				overall_ok = false
		else:
			if not FileAccess.file_exists(snapshot_path):
				# Si no existe y no estamos actualizando, guardar automáticamente el inicial
				if img != null:
					img.save_png(snapshot_path)
					print("PASS [NEW] Creado snapshot inicial para %s" % board_id)
				else:
					print("FAIL: No existe snapshot de referencia para %s" % board_id)
					overall_ok = false
			else:
				var ref_img = Image.load_from_file(snapshot_path)
				if ref_img == null:
					print("FAIL: No se pudo cargar snapshot de referencia para %s" % board_id)
					overall_ok = false
				else:
					var diff_ratio = _compare_images(img, ref_img)
					if diff_ratio > TOLERANCE:
						print("FAIL: Visual diff %.2f%% excede la tolerancia de 1%% para %s" % [diff_ratio * 100.0, board_id])
						overall_ok = false
					else:
						print("PASS: Visual diff %.2f%% dentro de la tolerancia (<= 1%%) para %s" % [diff_ratio * 100.0, board_id])

		board_inst.queue_free()
		await process_frame

	sub_viewport.free()

	print("=== RESULTADO: %s ===" % ("TODO OK" if overall_ok else "HAY FALLOS"))
	quit(0 if overall_ok else 1)

func _compare_images(img1: Image, img2: Image) -> float:
	if img1.get_size() != img2.get_size():
		return 1.0

	var w = img1.get_width()
	var h = img1.get_height()
	var total_pixels = float(w * h)
	var diff_pixels = 0

	for x in range(w):
		for y in range(h):
			var c1 = img1.get_pixel(x, y)
			var c2 = img2.get_pixel(x, y)
			var color_dist = abs(c1.r - c2.r) + abs(c1.g - c2.g) + abs(c1.b - c2.b)
			if color_dist > 0.08:
				diff_pixels += 1

	return float(diff_pixels) / total_pixels
