# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## Escáner de Código QR, Lector de Imagen QR en Disco y Entrada Manual para OpenTable.
## Permite conectar dos jugadores en red local (LAN / Offline sin servidor central)
## mediante cámara, archivo de imagen QR (.svg/.png/.json) o código/IP manual.

class_name QRScanner
extends Control

signal qr_scanned(ip: String, port: int)
signal qr_payload_decoded(payload: Dictionary)
signal closed

const QR_COMMENT_PREFIX: String = "<!--OPENTABLE_QR_JSON:"
const QR_COMMENT_SUFFIX: String = "-->"

var bridge: Object = null
var camera_plugin: Object = null
var discovered_lan_rooms: Array = []
var last_decoded_payload: Dictionary = {}
var auto_connect_on_scan: bool = true

var line_edit: LineEdit
var status_label: Label
var camera_container: PanelContainer
var preview_texture_rect: TextureRect
var camera_hint_label: Label
var load_image_button: Button
var paste_button: Button
var file_dialog: FileDialog = null

func _ready() -> void:
	_setup_ui()
	_detect_camera_plugin()

## Permite inyectar el nodo OpenTableBridge y salas LAN descubiertas
func setup(target_bridge: Object, lan_rooms: Array = []) -> void:
	bridge = target_bridge
	if not lan_rooms.is_empty():
		discovered_lan_rooms = lan_rooms.duplicate(true)

func set_discovered_rooms(lan_rooms: Array) -> void:
	discovered_lan_rooms = lan_rooms.duplicate(true)

## Visualiza la UI en pantalla
func open(target_bridge: Object = null) -> void:
	if target_bridge != null:
		bridge = target_bridge
	show()
	if camera_plugin and camera_plugin.has_method("start_camera"):
		camera_plugin.start_camera()

## Cierra el diálogo de escáner
func close() -> void:
	if camera_plugin and camera_plugin.has_method("stop_camera"):
		camera_plugin.stop_camera()
	hide()
	closed.emit()

func _detect_camera_plugin() -> void:
	if Engine.has_singleton("CameraPlugin"):
		camera_plugin = Engine.get_singleton("CameraPlugin")
	elif Engine.has_singleton("OpenTableCamera"):
		camera_plugin = Engine.get_singleton("OpenTableCamera")
	elif Engine.has_singleton("QRCameraPlugin"):
		camera_plugin = Engine.get_singleton("QRCameraPlugin")

	var has_camera_feeds: bool = false
	if ClassDB.class_exists("CameraServer") and CameraServer.get_feed_count() > 0:
		has_camera_feeds = true

	if camera_plugin:
		if camera_plugin.has_signal("qr_scanned"):
			var cb := Callable(self, "_on_native_qr_scanned")
			if not camera_plugin.is_connected("qr_scanned", cb):
				camera_plugin.connect("qr_scanned", cb)
		if status_label:
			status_label.text = "Cámara activa. Apunte al código QR del creador de la partida:"
		if camera_hint_label:
			camera_hint_label.text = "📷 Cámara activa — Escaneando QR en tiempo real..."
	elif has_camera_feeds:
		if status_label:
			status_label.text = "Cámara detectada. También puede cargar una imagen QR o ingresar IP:Puerto:"
		if camera_hint_label:
			camera_hint_label.text = "📷 Cámara lista — O cargue imagen QR (.png / .svg)"
	else:
		if status_label:
			status_label.text = "Escanee con cámara, cargue una imagen QR de disco o ingrese el código / IP:Puerto:"
		if camera_hint_label:
			camera_hint_label.text = "📷 Vista previa de cámara / Imagen QR cargada"

func _setup_ui() -> void:
	if status_label != null:
		return

	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 420)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "📷 Escanear QR / Conectar a Partida"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Escanee con cámara, cargue una imagen QR de disco o ingrese el código / IP:Puerto:"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)

	camera_container = PanelContainer.new()
	camera_container.name = "CameraContainer"
	camera_container.custom_minimum_size = Vector2(320, 140)
	vbox.add_child(camera_container)

	preview_texture_rect = TextureRect.new()
	preview_texture_rect.name = "PreviewTextureRect"
	preview_texture_rect.custom_minimum_size = Vector2(130, 130)
	preview_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture_rect.hide()
	camera_container.add_child(preview_texture_rect)

	camera_hint_label = Label.new()
	camera_hint_label.name = "CameraHintLabel"
	camera_hint_label.text = "📷 Vista previa de cámara / Imagen QR"
	camera_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	camera_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camera_container.add_child(camera_hint_label)

	var tools_hbox = HBoxContainer.new()
	tools_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tools_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(tools_hbox)

	load_image_button = Button.new()
	load_image_button.name = "LoadQrImageButton"
	load_image_button.text = "🖼️ Cargar Imagen QR (.png/.svg)"
	load_image_button.custom_minimum_size = Vector2(220, 38)
	load_image_button.pressed.connect(_on_load_image_pressed)
	tools_hbox.add_child(load_image_button)

	paste_button = Button.new()
	paste_button.name = "PasteQrButton"
	paste_button.text = "📋 Pegar QR / IP"
	paste_button.custom_minimum_size = Vector2(150, 38)
	paste_button.pressed.connect(_on_paste_pressed)
	tools_hbox.add_child(paste_button)

	line_edit = LineEdit.new()
	line_edit.name = "ManualInputLineEdit"
	line_edit.placeholder_text = "192.168.1.50:9090, JSON QR o Código de Sala"
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.custom_minimum_size = Vector2(360, 42)
	line_edit.text_submitted.connect(_on_text_submitted)
	vbox.add_child(line_edit)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var connect_btn = Button.new()
	connect_btn.name = "ConnectButton"
	connect_btn.text = "🔌 Conectar"
	connect_btn.custom_minimum_size = Vector2(150, 44)
	connect_btn.pressed.connect(func(): _on_text_submitted(line_edit.text))
	hbox.add_child(connect_btn)

	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "✖️ Cancelar"
	cancel_btn.custom_minimum_size = Vector2(150, 44)
	cancel_btn.pressed.connect(close)
	hbox.add_child(cancel_btn)

func _on_load_image_pressed() -> void:
	if file_dialog == null or not is_instance_valid(file_dialog):
		file_dialog = FileDialog.new()
		file_dialog.name = "QrFileDialog"
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = PackedStringArray([
			"*.svg, *.png, *.jpg, *.jpeg, *.json ; Archivos de Código QR",
			"* ; Todos los archivos"
		])
		file_dialog.file_selected.connect(func(path: String):
			load_qr_from_file(path)
		)
		add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(720, 500))

func _on_paste_pressed() -> void:
	var clip: String = DisplayServer.clipboard_get().strip_edges()
	if not clip.is_empty():
		if line_edit != null:
			line_edit.text = clip
		_parse_qr_and_connect(clip)

## Carga un archivo QR desde disco (.svg, .png, .json) y extrae su payload de conexión LAN.
func load_qr_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		if status_label:
			status_label.text = "No se encontró el archivo QR: %s" % path
		return false

	var lower_path: String = path.to_lower()
	var extracted_raw: String = ""

	if lower_path.ends_with(".svg") or lower_path.ends_with(".json") or lower_path.ends_with(".txt"):
		var f = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var content: String = f.get_as_text()
			extracted_raw = extract_payload_from_text(content)
			if lower_path.ends_with(".svg"):
				var img := Image.new()
				if img.load_svg_from_string(content) == OK and not img.is_empty() and preview_texture_rect != null:
					preview_texture_rect.texture = ImageTexture.create_from_image(img)
					preview_texture_rect.show()
					if camera_hint_label != null:
						camera_hint_label.hide()
	elif lower_path.ends_with(".png") or lower_path.ends_with(".jpg") or lower_path.ends_with(".jpeg"):
		var img := Image.new()
		if img.load(path) == OK and not img.is_empty():
			if preview_texture_rect != null:
				preview_texture_rect.texture = ImageTexture.create_from_image(img)
				preview_texture_rect.show()
				if camera_hint_label != null:
					camera_hint_label.hide()
			extracted_raw = decode_payload_from_image(img)

		if extracted_raw.is_empty():
			var sidecar_svg: String = path.get_basename() + ".svg"
			var sidecar_json: String = path + ".json"
			if FileAccess.file_exists(sidecar_svg):
				var fs = FileAccess.open(sidecar_svg, FileAccess.READ)
				if fs != null:
					extracted_raw = extract_payload_from_text(fs.get_as_text())
			elif FileAccess.file_exists(sidecar_json):
				var fj = FileAccess.open(sidecar_json, FileAccess.READ)
				if fj != null:
					extracted_raw = extract_payload_from_text(fj.get_as_text())

	if extracted_raw.is_empty():
		if status_label:
			status_label.text = "No se pudo decodificar un QR válido desde: %s" % path.get_file()
		return false

	if line_edit != null:
		line_edit.text = extracted_raw
	_parse_qr_and_connect(extracted_raw)
	return true

## Extrae el JSON embebido desde un SVG de OpenTable o un texto JSON directo.
func extract_payload_from_text(raw_content: String) -> String:
	var trimmed: String = raw_content.strip_edges()
	if trimmed.is_empty():
		return ""
	if bridge != null and bridge.has_method("extract_qr_payload_json"):
		var from_bridge: String = str(bridge.call("extract_qr_payload_json", trimmed))
		if not from_bridge.is_empty():
			return from_bridge
	var start_idx: int = trimmed.find(QR_COMMENT_PREFIX)
	if start_idx >= 0:
		var json_start: int = start_idx + QR_COMMENT_PREFIX.length()
		var end_idx: int = trimmed.find(QR_COMMENT_SUFFIX, json_start)
		if end_idx > json_start:
			return trimmed.substr(json_start, end_idx - json_start).strip_edges()
	return trimmed

## Codifica un payload JSON en la última fila (quiet zone) de un Image PNG para lectura offline determinista.
static func encode_payload_into_image(img: Image, payload_json: String) -> void:
	if img == null or img.is_empty():
		return
	var bytes: PackedByteArray = payload_json.to_utf8_buffer()
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w < 8 or h < 2 or bytes.size() + 4 > w:
		return
	var y: int = h - 1
	# Magic header 'O', 'T', len_hi, len_lo encoded in alpha/blue channel while keeping pixel white visually
	var header: Array[int] = [79, 84, (bytes.size() >> 8) & 0xFF, bytes.size() & 0xFF]
	for i in range(4):
		img.set_pixel(i, y, Color8(254, 255, header[i], 255))
	for i in range(bytes.size()):
		img.set_pixel(i + 4, y, Color8(254, 255, int(bytes[i]), 255))

## Decodifica el payload JSON embebido en la última fila de un Image PNG generado por OpenTable.
static func decode_payload_from_image(img: Image) -> String:
	if img == null or img.is_empty():
		return ""
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w < 8 or h < 2:
		return ""
	var y: int = h - 1
	var p0: Color = img.get_pixel(0, y)
	var p1: Color = img.get_pixel(1, y)
	if int(round(p0.r * 255.0)) != 254 or int(round(p0.b * 255.0)) != 79 or int(round(p1.b * 255.0)) != 84:
		return ""
	var len_hi: int = int(round(img.get_pixel(2, y).b * 255.0))
	var len_lo: int = int(round(img.get_pixel(3, y).b * 255.0))
	var total_len: int = (len_hi << 8) | len_lo
	if total_len <= 0 or total_len + 4 > w:
		return ""
	var out_bytes := PackedByteArray()
	out_bytes.resize(total_len)
	for i in range(total_len):
		var c: Color = img.get_pixel(i + 4, y)
		out_bytes[i] = int(round(c.b * 255.0))
	return out_bytes.get_string_from_utf8()

func _on_native_qr_scanned(raw_text: String) -> void:
	_parse_qr_and_connect(raw_text)

func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_parse_qr_and_connect(text)

func parse_qr_text(raw_text: String) -> Dictionary:
	var cleaned: String = extract_payload_from_text(raw_text)
	var result: Dictionary = {
		"ip": "127.0.0.1",
		"port": 9090,
		"game_type": "",
		"join_code": "",
		"host_name": "HostPlayer",
		"session_id": ""
	}

	var parser = JSON.new()
	if parser.parse(cleaned) == OK and parser.data is Dictionary:
		var dict: Dictionary = parser.data
		result["ip"] = str(dict.get("ip", dict.get("host", "127.0.0.1")))
		result["port"] = int(dict.get("port", 9090))
		result["game_type"] = str(dict.get("game_type", dict.get("game_id", "")))
		result["join_code"] = str(dict.get("join_code", ""))
		result["host_name"] = str(dict.get("host_name", "HostPlayer"))
		result["session_id"] = str(dict.get("session_id", ""))
		return result

	if cleaned.begins_with("opentable://"):
		cleaned = cleaned.replace("opentable://", "")
	elif cleaned.begins_with("http://"):
		cleaned = cleaned.replace("http://", "")

	# Si el usuario ingresó un código corto de sala (ej. ABCD) y hay salas descubiertas en LAN
	if not (":" in cleaned) and cleaned.count(".") == 0:
		var upper_code: String = cleaned.to_upper()
		result["join_code"] = upper_code
		for room_item in discovered_lan_rooms:
			if room_item is Dictionary:
				var r_dict: Dictionary = room_item
				var r_code: String = str(r_dict.get("join_code", r_dict.get("room_code", ""))).to_upper()
				if r_code == upper_code or discovered_lan_rooms.size() == 1:
					result["ip"] = str(r_dict.get("ip", "127.0.0.1"))
					result["port"] = int(r_dict.get("port", 9090))
					result["game_type"] = str(r_dict.get("game_id", r_dict.get("game_type", "")))
					result["host_name"] = str(r_dict.get("host_name", "HostPlayer"))
					return result

	if ":" in cleaned:
		var parts: PackedStringArray = cleaned.split(":")
		result["ip"] = parts[0]
		result["port"] = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 9090
	else:
		result["ip"] = cleaned

	return result

func _parse_qr_and_connect(raw_text: String) -> void:
	var parsed: Dictionary = parse_qr_text(raw_text)
	last_decoded_payload = parsed
	var ip: String = str(parsed.get("ip", "127.0.0.1"))
	var port: int = int(parsed.get("port", 9090))

	if auto_connect_on_scan and bridge != null:
		if bridge.has_method("connect_as_client"):
			bridge.connect_as_client(ip, port)
		elif bridge.has_method("connect_to_host"):
			bridge.connect_to_host(ip, port, "Jugador")

	qr_payload_decoded.emit(parsed)
	qr_scanned.emit(ip, port)
	close()
