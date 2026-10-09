extends CanvasLayer

## Modal de Consentimiento de Privacidad y Términos de Servicio en Primer Arranque (Prompt 492).
## Cumplimiento GDPR / CCPA / Google Play / Apple App Store / Steam.
## Se muestra una sola vez si `privacy_accepted != true` en `user://settings.cfg`.
## Permite elegir entre habilitar funciones Online (UUID anónimo) o jugar en "Solo Modo Local / Offline"
## (100% local / vs IA sin realizar ninguna conexión HTTP ni WebSocket externa).

signal consent_completed(online_enabled: bool)
signal accepted_online()
signal selected_offline_only()

const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const PRIVACY_SECTION := "privacy"

var config_path: String = DEFAULT_SETTINGS_PATH
var privacy_accepted: bool = false
var online_enabled: bool = true

var accept_online_button: Button
var offline_only_button: Button
var view_privacy_button: Button
var view_terms_button: Button
var details_text_box: RichTextLabel
var status_label: Label

func _init(p_config_path: String = DEFAULT_SETTINGS_PATH) -> void:
	config_path = p_config_path
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()

static func should_show_on_startup(p_config_path: String = DEFAULT_SETTINGS_PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(p_config_path) != OK:
		return true
	var accepted := bool(cfg.get_value(PRIVACY_SECTION, "privacy_accepted", false))
	return not accepted

static func is_online_enabled(p_config_path: String = DEFAULT_SETTINGS_PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(p_config_path) != OK:
		return true
	return bool(cfg.get_value(PRIVACY_SECTION, "online_enabled", true))

static func is_offline_only_mode(p_config_path: String = DEFAULT_SETTINGS_PATH) -> bool:
	return not is_online_enabled(p_config_path)

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.04, 0.07, 0.85)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ConsentPanel"
	panel.custom_minimum_size = Vector2(680, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.17, 0.98)
	style.border_color = Color(0.35, 0.62, 0.92, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "🔒 Privacidad y Modo de Conectividad"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.name = "SubtitleLabel"
	subtitle_lbl.text = "Cumplimiento GDPR / CCPA — Cero Rastreadores de Terceros"
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 14)
	subtitle_lbl.add_theme_color_override("font_color", Color(0.65, 0.82, 0.98))
	vbox.add_child(subtitle_lbl)

	vbox.add_child(HSeparator.new())

	details_text_box = RichTextLabel.new()
	details_text_box.name = "PrivacySummaryText"
	details_text_box.bbcode_enabled = true
	details_text_box.fit_content = false
	details_text_box.custom_minimum_size = Vector2(600, 210)
	details_text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_text_box.text = _get_summary_bbcode()
	vbox.add_child(details_text_box)

	var docs_hbox := HBoxContainer.new()
	docs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	docs_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(docs_hbox)

	view_privacy_button = Button.new()
	view_privacy_button.name = "ViewPrivacyButton"
	view_privacy_button.text = "📄 Ver Política de Privacidad"
	view_privacy_button.custom_minimum_size = Vector2(220, 34)
	view_privacy_button.pressed.connect(_on_view_privacy_pressed)
	docs_hbox.add_child(view_privacy_button)

	view_terms_button = Button.new()
	view_terms_button.name = "ViewTermsButton"
	view_terms_button.text = "📜 Ver Términos de Servicio"
	view_terms_button.custom_minimum_size = Vector2(220, 34)
	view_terms_button.pressed.connect(_on_view_terms_pressed)
	docs_hbox.add_child(view_terms_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Puedes cambiar esta preferencia en cualquier momento desde Ajustes."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	vbox.add_child(status_label)

	var actions_hbox := HBoxContainer.new()
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_hbox.add_theme_constant_override("separation", 18)
	vbox.add_child(actions_hbox)

	offline_only_button = Button.new()
	offline_only_button.name = "OfflineOnlyButton"
	offline_only_button.text = "Solo Modo Local / Offline"
	offline_only_button.custom_minimum_size = Vector2(260, 48)
	offline_only_button.add_theme_font_size_override("font_size", 16)
	_style_action_button(offline_only_button, Color(0.32, 0.38, 0.46))
	offline_only_button.pressed.connect(func():
		select_offline_only_mode(config_path)
	)
	actions_hbox.add_child(offline_only_button)

	accept_online_button = Button.new()
	accept_online_button.name = "AcceptOnlineButton"
	accept_online_button.text = "Aceptar y Habilitar Online"
	accept_online_button.custom_minimum_size = Vector2(280, 48)
	accept_online_button.add_theme_font_size_override("font_size", 16)
	_style_action_button(accept_online_button, Color(0.18, 0.58, 0.36))
	accept_online_button.pressed.connect(func():
		accept_online_features(config_path)
	)
	actions_hbox.add_child(accept_online_button)

func _style_action_button(btn: Button, base_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.border_color = base_color.lightened(0.25)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)

func _get_summary_bbcode() -> String:
	return (
		"[b]Bienvenido a OpenTable — 13 Classic Board & Card Games[/b]\n\n"
		+ "• [b]Sin rastreadores ni publicidad:[/b] Esta aplicación no incluye analíticas de terceros, telemetría oculta ni SDKs publicitarios.\n"
		+ "• [b]Identificador Anónimo Online (UUID v4):[/b] Si habilitas las funciones online (Servidor Relay, Matchmaking y Clasificación ELO), únicamente se almacena un UUID aleatorio anónimo en tu dispositivo ([code]user://identity.cfg[/code]) para mantener tu puntuación ELO y reconectar partidas. No se recopilan datos personales ni se comparten con terceros.\n"
		+ "• [b]Modo 100% Local / Offline:[/b] Si eliges [b]\"Solo Modo Local / Offline\"[/b], los 13 juegos funcionan al 100% en modo local (Hotseat) y contra la IA sin realizar ninguna conexión HTTP ni WebSocket externa."
	)

func _on_view_privacy_pressed() -> void:
	var content := _load_markdown_doc(["res://../PRIVACY_POLICY.md", "PRIVACY_POLICY.md"])
	if details_text_box != null:
		details_text_box.text = content if not content.is_empty() else _get_summary_bbcode()

func _on_view_terms_pressed() -> void:
	var content := _load_markdown_doc(["res://../TERMS_OF_SERVICE.md", "TERMS_OF_SERVICE.md"])
	if details_text_box != null:
		details_text_box.text = content if not content.is_empty() else _get_summary_bbcode()

func _load_markdown_doc(candidate_paths: Array) -> String:
	for p in candidate_paths:
		var path_str := String(p)
		if FileAccess.file_exists(path_str):
			var f := FileAccess.open(path_str, FileAccess.READ)
			if f != null:
				return f.get_as_text()
	return ""

func accept_online_features(p_config_path: String = "") -> void:
	var target_path := p_config_path if not p_config_path.is_empty() else config_path
	privacy_accepted = true
	online_enabled = true
	_save_decision(target_path, true, true)
	_apply_runtime_mode(true)
	accepted_online.emit()
	consent_completed.emit(true)
	if is_inside_tree():
		queue_free()

func select_offline_only_mode(p_config_path: String = "") -> void:
	var target_path := p_config_path if not p_config_path.is_empty() else config_path
	privacy_accepted = true
	online_enabled = false
	_save_decision(target_path, true, false)
	_apply_runtime_mode(false)
	selected_offline_only.emit()
	consent_completed.emit(false)
	if is_inside_tree():
		queue_free()

func _save_decision(target_path: String, accepted: bool, allow_online: bool) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(target_path)
	cfg.set_value(PRIVACY_SECTION, "privacy_accepted", accepted)
	cfg.set_value(PRIVACY_SECTION, "online_enabled", allow_online)
	cfg.set_value(PRIVACY_SECTION, "offline_only_mode", not allow_online)
	cfg.set_value(PRIVACY_SECTION, "consent_timestamp", int(Time.get_unix_time_from_system()))
	return cfg.save(target_path)

func _apply_runtime_mode(allow_online: bool) -> void:
	if is_inside_tree():
		var gm := (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
		if gm != null and gm.has_method("set_online_features_enabled"):
			gm.call("set_online_features_enabled", allow_online)
		var auth := (get_node_or_null("/root/AuthClient") if is_inside_tree() else null)
		if auth != null and auth.has_method("set_online_enabled"):
			auth.call("set_online_enabled", allow_online)
