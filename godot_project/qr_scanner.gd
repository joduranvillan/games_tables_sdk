## Escáner de Código QR y Cámara Nativa para OpenTable.
## Soporta escaneo mediante plugin de cámara nativo o ingreso manual por LineEdit.

class_name QRScanner
extends Control

signal qr_scanned(ip: String, port: int)
signal closed

var bridge: Object = null
var camera_plugin: Object = null

@onready var line_edit: LineEdit
@onready var status_label: Label
@onready var camera_container: Control

func _ready() -> void:
	_setup_ui()
	_detect_camera_plugin()

## Permite inyectar el nodo OpenTableBridge
func setup(target_bridge: Object) -> void:
	bridge = target_bridge

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

	if camera_plugin:
		print("📷 QRScanner: Plugin de cámara nativo detectado")
		if camera_plugin.has_signal("qr_scanned"):
			camera_plugin.qr_scanned.connect(_on_native_qr_scanned)
		if status_label:
			status_label.text = "Cámara activa. Apunte al código QR del Host..."
	else:
		print("ℹ️ QRScanner: Plugin de cámara no disponible. Usando modo manual")
		if status_label:
			status_label.text = "Cámara no disponible en este dispositivo.\nIngrese el código o IP:Puerto manualmente:"

func _setup_ui() -> void:
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
	panel.custom_minimum_size = Vector2(420, 320)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "📷 Escanear QR / Conectar a Sala"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	status_label = Label.new()
	status_label.text = "Cámara no disponible en este dispositivo.\nIngrese IP:Puerto manualmente:"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)

	camera_container = Control.new()
	camera_container.custom_minimum_size = Vector2(300, 120)
	vbox.add_child(camera_container)

	line_edit = LineEdit.new()
	line_edit.placeholder_text = "192.168.1.50:9090 o Código Join"
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.custom_minimum_size = Vector2(320, 44)
	line_edit.text_submitted.connect(_on_text_submitted)
	vbox.add_child(line_edit)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var connect_btn = Button.new()
	connect_btn.text = "🔌 Conectar"
	connect_btn.custom_minimum_size = Vector2(140, 44)
	connect_btn.pressed.connect(func(): _on_text_submitted(line_edit.text))
	hbox.add_child(connect_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "✖️ Cancelar"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.pressed.connect(close)
	hbox.add_child(cancel_btn)

func _on_native_qr_scanned(raw_text: String) -> void:
	print("📷 QRScanner: QR escaneado por cámara nativa: '%s'" % raw_text)
	_parse_qr_and_connect(raw_text)

func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_parse_qr_and_connect(text)

func _parse_qr_and_connect(raw_text: String) -> void:
	var cleaned = raw_text.strip_edges()
	var ip = "127.0.0.1"
	var port = 9090

	# 1. Intentar parsear JSON
	var parser = JSON.new()
	if parser.parse(cleaned) == OK and parser.data is Dictionary:
		var dict: Dictionary = parser.data
		ip = str(dict.get("ip", dict.get("host", "127.0.0.1")))
		port = int(dict.get("port", 9090))
	else:
		# 2. Remover esquemas tipo opentable:// o http://
		if cleaned.begins_with("opentable://"):
			cleaned = cleaned.replace("opentable://", "")
		elif cleaned.begins_with("http://"):
			cleaned = cleaned.replace("http://", "")

		# 3. Separar IP:Puerto
		if ":" in cleaned:
			var parts = cleaned.split(":")
			ip = parts[0]
			port = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 9090
		else:
			ip = cleaned

	print("🔌 QRScanner: Conectando como Cliente TCP a %s:%d" % [ip, port])

	if bridge != null:
		if bridge.has_method("connect_as_client"):
			bridge.connect_as_client(ip, port)
		elif bridge.has_method("connect_to_host"):
			bridge.connect_to_host(ip, port, "Jugador")

	qr_scanned.emit(ip, port)
	close()
