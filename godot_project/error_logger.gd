# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# ErrorLogger Autoload: Captura y registra errores/warnings en user://error.log
# Muestra overlay debug semi-transparente en esquina inferior (toggleable con F12)
# y permite exportar diagnóstico técnico sin datos personales (Prompt 493).
extends Node

const LOG_PATH = "user://error.log"
const DEFAULT_DIAG_PATH = "user://opentable_diag.json"
const MAX_RECENT_LOGS = 50

var recent_logs: Array[String] = []
var plain_logs: Array[String] = []
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
	# Oculto por defecto en todas las escenas para no ocupar espacio en pantalla (activable solo manualmente con F12)
	overlay_panel.visible = false

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
	_append_plain_log(formatted)
	_append_overlay("[color=#ff6666][%s] [ERROR] %s[/color]" % [ts, msg])

func log_warning(msg: String) -> void:
	var ts = _get_timestamp()
	var formatted = "[%s] [WARN] %s" % [ts, msg]
	push_warning(msg)
	_write_to_file(formatted)
	_append_plain_log(formatted)
	_append_overlay("[color=#ffcc66][%s] [WARN] %s[/color]" % [ts, msg])

func log_info(msg: String) -> void:
	var ts = _get_timestamp()
	var formatted = "[%s] [INFO] %s" % [ts, msg]
	_write_to_file(formatted)
	_append_plain_log(formatted)
	_append_overlay("[color=#88ccff][%s] [INFO] %s[/color]" % [ts, msg])

func _write_to_file(line: String) -> void:
	if file_handle == null:
		var mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE_READ
		file_handle = FileAccess.open(LOG_PATH, mode)
	if file_handle != null:
		file_handle.seek_end()
		file_handle.store_line(line)

func _append_plain_log(plain_line: String) -> void:
	plain_logs.append(plain_line)
	if plain_logs.size() > MAX_RECENT_LOGS:
		plain_logs.pop_front()

func _append_overlay(bbcode_line: String) -> void:
	recent_logs.append(bbcode_line)
	if recent_logs.size() > MAX_RECENT_LOGS:
		recent_logs.pop_front()
	if is_instance_valid(log_label):
		log_label.text = "\n".join(recent_logs)

func get_last_logs(limit: int = MAX_RECENT_LOGS) -> Array[String]:
	var max_items := clampi(limit, 1, MAX_RECENT_LOGS)
	var source := plain_logs
	if source.is_empty() and not recent_logs.is_empty():
		source = recent_logs
	var start_idx := maxi(0, source.size() - max_items)
	var out: Array[String] = []
	for i in range(start_idx, source.size()):
		out.append(str(source[i]))
	return out

func build_diagnostics_payload() -> Dictionary:
	var bridge_registered := ClassDB.class_exists("OpenTableBridge")
	var active_game := ""
	var current_mode := "hotseat"
	var online_enabled := true

	if is_inside_tree():
		var gm = (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
		if gm != null:
			if gm.has_method("get_active_game"):
				active_game = str(gm.call("get_active_game"))
			if gm.has_method("get_game_mode"):
				current_mode = str(gm.call("get_game_mode"))
			if gm.has_method("is_online_features_enabled"):
				online_enabled = bool(gm.call("is_online_features_enabled"))

	var adapter_name := ""
	var adapter_vendor := ""
	var adapter_api := ""
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter_name = str(RenderingServer.get_video_adapter_name())
	if RenderingServer.has_method("get_video_adapter_vendor"):
		adapter_vendor = str(RenderingServer.get_video_adapter_vendor())
	if RenderingServer.has_method("get_video_adapter_api_version"):
		adapter_api = str(RenderingServer.get_video_adapter_api_version())

	return {
		"schema_version": "1.0",
		"exported_at": _get_timestamp(),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "3.0.0")),
		"pii_collected": false,
		"os": {
			"name": OS.get_name(),
			"version": OS.get_version(),
			"locale": OS.get_locale_language(),
			"processor_count": OS.get_processor_count()
		},
		"renderer": {
			"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")),
			"video_adapter_name": adapter_name,
			"video_adapter_vendor": adapter_vendor,
			"video_adapter_api_version": adapter_api
		},
		"bridge_status": {
			"class_registered": bridge_registered,
			"active_game": active_game,
			"game_mode": current_mode,
			"online_features_enabled": online_enabled
		},
		"recent_logs": get_last_logs(MAX_RECENT_LOGS)
	}

func export_diagnostics(path: String = DEFAULT_DIAG_PATH) -> bool:
	var target_path := path.strip_edges() if not path.strip_edges().is_empty() else DEFAULT_DIAG_PATH
	var payload = build_diagnostics_payload()
	var json_str := JSON.stringify(payload, "  ")
	var out_file := FileAccess.open(target_path, FileAccess.WRITE)
	if out_file == null:
		return false
	out_file.store_string(json_str)
	out_file.flush()
	return true
