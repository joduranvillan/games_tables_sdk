# ErrorLogger Autoload: Captura y registra errores/warnings en user://error.log
# Muestra overlay debug semi-transparente en esquina inferior (toggleable con F12).
extends Node

const LOG_PATH = "user://error.log"
const MAX_RECENT_LOGS = 50

var recent_logs: Array[String] = []
var overlay_canvas: CanvasLayer
var overlay_panel: PanelContainer
var log_label: RichTextLabel
var file_handle: FileAccess

func _ready() -> void:
	_init_log_file()
	_setup_debug_overlay()
	log_info("ErrorLogger inicializado correctamente")

func _init_log_file() -> void:
	file_handle = FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)
	if file_handle == null:
		push_error("ErrorLogger: No se pudo abrir %s" % LOG_PATH)

func _setup_debug_overlay() -> void:
	overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 100
	add_child(overlay_canvas)

	overlay_panel = PanelContainer.new()
	overlay_panel.name = "ErrorDebugOverlay"
	overlay_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	overlay_panel.position = Vector2(-360, -220)
	overlay_panel.custom_minimum_size = Vector2(350, 200)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	overlay_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	overlay_panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "🐛 Log de Errores (F12 para ocultar)"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	vbox.add_child(title_lbl)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.custom_minimum_size = Vector2(330, 160)
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	vbox.add_child(log_label)

	overlay_canvas.add_child(overlay_panel)
	# Visible en modo debug por defecto
	overlay_panel.visible = OS.is_debug_build()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			overlay_panel.visible = !overlay_panel.visible

func _get_timestamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

func log_error(msg: String) -> void:
	var ts = _get_timestamp()
	var formatted = "[%s] [ERROR] %s" % [ts, msg]
	push_error(msg)
	_write_to_file(formatted)
	_append_overlay("[color=#ff6666][%s] [ERROR] %s[/color]" % [ts, msg])

func log_warning(msg: String) -> void:
	var ts = _get_timestamp()
	var formatted = "[%s] [WARN] %s" % [ts, msg]
	push_warning(msg)
	_write_to_file(formatted)
	_append_overlay("[color=#ffcc66][%s] [WARN] %s[/color]" % [ts, msg])

func log_info(msg: String) -> void:
	var ts = _get_timestamp()
	var formatted = "[%s] [INFO] %s" % [ts, msg]
	_write_to_file(formatted)
	_append_overlay("[color=#88ccff][%s] [INFO] %s[/color]" % [ts, msg])

func _write_to_file(line: String) -> void:
	if file_handle == null:
		file_handle = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file_handle != null:
		file_handle.seek_end()
		file_handle.store_line(line)

func _append_overlay(bbcode_line: String) -> void:
	recent_logs.append(bbcode_line)
	if recent_logs.size() > MAX_RECENT_LOGS:
		recent_logs.pop_front()
	if is_instance_valid(log_label):
		log_label.text = "\n".join(recent_logs)
