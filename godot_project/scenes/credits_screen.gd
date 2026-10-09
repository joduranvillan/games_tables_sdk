extends Control

## Pantalla de Créditos, Licencias Open Source y Exportación de Diagnóstico Técnico (Prompt 493).
## Incluye la pestaña "Licencias Open Source" (MIT / Apache-2.0 / MPL-2.0) y el botón
## "Exportar Diagnóstico" que genera `opentable_diag.json` sin datos personales.

signal diagnostics_exported(path: String, success: bool)

const DEFAULT_DIAGNOSTICS_PATH := "user://opentable_diag.json"

const CREDITS_TEXT := """[b]OpenTable — 13 Classic Board & Card Games[/b]
Versión 3.0.0 (2026)

Motor determinista: Rust + GDExtension (`open_table_core`, `open_table_engine`, `open_table_godot`)
Servidor autoritativo: `open_table_relay` (TLS/WSS, JWT, Anti-Cheat 13/13, SQLite ELO)
Interfaz y Runtime: Godot 4 / Redot 4.5

[b]Juegos incluidos en la colección (13/13):[/b]
  • Ajedrez (Chess)
  • Damas (Checkers)
  • Go (Weiqi / Baduk)
  • Shogi
  • Xiangqi (Ajedrez Chino)
  • Backgammon
  • Batalla Naval (Battleship)
  • Ludo
  • Mille Bornes
  • Monopoly
  • UNO
  • Crisis (TEG)
  • Damas Chinas (Chinese Checkers)

Licencia del SDK: MIT
"""

const FALLBACK_OSS_LICENSES_TEXT := """[b]Licencias Open Source de Terceros (MIT / Apache-2.0 / MPL-2.0)[/b]

• [b]Godot Engine & Redot Engine[/b] — MIT License
  Copyright (c) 2014-present Godot Engine contributors, Juan Linietsky, Ariel Manzur.

• [b]godot-rust (`gdext`)[/b] — Mozilla Public License 2.0 (MPL-2.0)

• [b]Ecosistema Rust (MIT / Apache-2.0):[/b]
  - `serde`, `serde_json` (MIT OR Apache-2.0)
  - `tokio`, `tokio-tungstenite`, `axum`, `tower-http` (MIT)
  - `rustls`, `tokio-rustls`, `rcgen` (Apache-2.0 OR ISC OR MIT)
  - `jsonwebtoken`, `hmac`, `sha2`, `base64` (MIT OR Apache-2.0)
  - `rusqlite`, `libsqlite3-sys` (MIT)
  - `rand`, `rand_chacha`, `qrcode`, `image`, `flate2` (MIT OR Apache-2.0)
"""

var tabs_container: TabContainer
var credits_label: RichTextLabel
var licenses_label: RichTextLabel
var export_diag_button: Button
var back_button: Button
var status_label: Label
var last_exported_diag_path: String = ""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header_lbl := Label.new()
	header_lbl.name = "HeaderLabel"
	header_lbl.text = "ℹ️ Acerca de OpenTable & Licencias Open Source"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(header_lbl)

	tabs_container = TabContainer.new()
	tabs_container.name = "CreditsTabContainer"
	tabs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs_container)

	# Pestaña 0: Créditos
	var credits_tab := MarginContainer.new()
	credits_tab.name = "Créditos"
	credits_tab.add_theme_constant_override("margin_top", 12)
	credits_tab.add_theme_constant_override("margin_bottom", 12)
	credits_tab.add_theme_constant_override("margin_left", 16)
	credits_tab.add_theme_constant_override("margin_right", 16)
	tabs_container.add_child(credits_tab)
	tabs_container.set_tab_title(0, "Créditos")

	credits_label = RichTextLabel.new()
	credits_label.name = "CreditsRichText"
	credits_label.bbcode_enabled = true
	credits_label.text = CREDITS_TEXT
	credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	credits_tab.add_child(credits_label)

	# Pestaña 1: Licencias Open Source
	var licenses_tab := MarginContainer.new()
	licenses_tab.name = "Licencias Open Source"
	licenses_tab.add_theme_constant_override("margin_top", 12)
	licenses_tab.add_theme_constant_override("margin_bottom", 12)
	licenses_tab.add_theme_constant_override("margin_left", 16)
	licenses_tab.add_theme_constant_override("margin_right", 16)
	tabs_container.add_child(licenses_tab)
	tabs_container.set_tab_title(1, "Licencias Open Source")

	licenses_label = RichTextLabel.new()
	licenses_label.name = "LicensesRichText"
	licenses_label.bbcode_enabled = true
	licenses_label.text = load_oss_licenses_text()
	licenses_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	licenses_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	licenses_tab.add_child(licenses_label)

	status_label = Label.new()
	status_label.name = "DiagnosticsStatusLabel"
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.55, 0.90, 0.65))
	vbox.add_child(status_label)

	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(footer_hbox)

	export_diag_button = Button.new()
	export_diag_button.name = "ExportDiagnosticsButton"
	export_diag_button.text = "Exportar Diagnóstico"
	export_diag_button.custom_minimum_size = Vector2(220, 44)
	export_diag_button.pressed.connect(func():
		export_diagnostics_to_file(DEFAULT_DIAGNOSTICS_PATH)
	)
	footer_hbox.add_child(export_diag_button)

	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "← Volver al Menú"
	back_button.custom_minimum_size = Vector2(200, 44)
	back_button.pressed.connect(_on_back_pressed)
	footer_hbox.add_child(back_button)

func load_oss_licenses_text() -> String:
	var candidate_paths := [
		ProjectSettings.globalize_path("res://").path_join("../THIRD_PARTY_LICENSES.md"),
		"THIRD_PARTY_LICENSES.md",
	]
	for p in candidate_paths:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				var content := f.get_as_text()
				if not content.strip_edges().is_empty():
					return content
	return FALLBACK_OSS_LICENSES_TEXT

func export_diagnostics_to_file(target_path: String = DEFAULT_DIAGNOSTICS_PATH) -> bool:
	var ok := false
	if is_inside_tree() and has_node("/root/ErrorLogger"):
		var logger = get_node("/root/ErrorLogger")
		if logger.has_method("export_diagnostics"):
			ok = bool(logger.call("export_diagnostics", target_path))
	else:
		var logger_script = load("res://error_logger.gd")
		if logger_script != null:
			var temp_logger = logger_script.new()
			ok = bool(temp_logger.export_diagnostics(target_path))
			temp_logger.free()

	if ok:
		last_exported_diag_path = target_path
		if status_label != null:
			status_label.text = "✅ Diagnóstico exportado en: %s" % target_path
	else:
		if status_label != null:
			status_label.text = "⚠️ No se pudo exportar el diagnóstico"

	diagnostics_exported.emit(target_path, ok)
	return ok

func _on_back_pressed() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")
