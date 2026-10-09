class_name StatsScreen
extends Control

const ScoreTrackerScript = preload("res://score_tracker.gd")

var tracker_ref: Node = null
var owns_tracker: bool = false
var current_player_name: String = "Player 1"

var total_matches_label: Label
var favorite_game_label: Label
var highest_elo_label: Label
var table_grid: GridContainer
var refresh_btn: Button
var back_btn: Button

func _ready() -> void:
	_build_ui()
	refresh_stats()

func _exit_tree() -> void:
	if owns_tracker and tracker_ref != null and is_instance_valid(tracker_ref):
		tracker_ref.free()
		tracker_ref = null

func _resolve_tracker() -> Node:
	if tracker_ref != null and is_instance_valid(tracker_ref):
		return tracker_ref
	if is_inside_tree() and has_node("/root/ScoreTracker"):
		return get_node("/root/ScoreTracker")
	tracker_ref = ScoreTrackerScript.new()
	owns_tracker = true
	tracker_ref.load_scores()
	tracker_ref.load_stats_cfg()
	return tracker_ref

func _build_ui() -> void:
	if table_grid != null:
		return

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.14, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.position = Vector2(48, 28)
	main_vbox.custom_minimum_size = Vector2(1184, 660)
	main_vbox.add_theme_constant_override("separation", 16)
	add_child(main_vbox)

	# Header
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "📊 Mis Estadísticas Locales y Progreso"
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	refresh_btn = Button.new()
	refresh_btn.name = "RefreshButton"
	refresh_btn.text = "🔄 Actualizar"
	refresh_btn.custom_minimum_size = Vector2(130, 38)
	refresh_btn.pressed.connect(refresh_stats)
	header_hbox.add_child(refresh_btn)

	back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "⬅ Volver"
	back_btn.custom_minimum_size = Vector2(120, 38)
	back_btn.pressed.connect(_on_back_pressed)
	header_hbox.add_child(back_btn)

	# Tarjetas de Hitos Personales (Total de partidas, Juego favorito, Mayor ELO alcanzado)
	var milestones_hbox := HBoxContainer.new()
	milestones_hbox.name = "MilestonesContainer"
	milestones_hbox.add_theme_constant_override("separation", 18)
	main_vbox.add_child(milestones_hbox)

	total_matches_label = _create_milestone_card(
		milestones_hbox,
		"TotalMatchesCard",
		"🎮 Total de partidas",
		"0",
		Color(0.28, 0.72, 0.96)
	)
	favorite_game_label = _create_milestone_card(
		milestones_hbox,
		"FavoriteGameCard",
		"⭐ Juego favorito",
		"Sin partidas",
		Color(0.95, 0.76, 0.25)
	)
	highest_elo_label = _create_milestone_card(
		milestones_hbox,
		"HighestEloCard",
		"🏆 Mayor ELO alcanzado",
		"1200 (Ajedrez)",
		Color(0.38, 0.88, 0.54)
	)

	# Tabla Resumen de los 13 Juegos
	var table_panel := PanelContainer.new()
	table_panel.name = "TablePanel"
	table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.14, 0.20, 0.96)
	panel_style.border_color = Color(0.28, 0.38, 0.54, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	table_panel.add_theme_stylebox_override("panel", panel_style)
	main_vbox.add_child(table_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_panel.add_child(scroll)

	table_grid = GridContainer.new()
	table_grid.name = "StatsTableGrid"
	table_grid.columns = 7
	table_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_grid.add_theme_constant_override("h_separation", 24)
	table_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(table_grid)

func _create_milestone_card(
	parent: Container,
	card_name: String,
	heading_text: String,
	initial_value: String,
	accent_color: Color
) -> Label:
	var card := PanelContainer.new()
	card.name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(360, 88)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.96)
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = heading_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	vbox.add_child(title_lbl)

	var val_lbl := Label.new()
	val_lbl.name = "ValueLabel"
	val_lbl.text = initial_value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 20)
	val_lbl.add_theme_color_override("font_color", accent_color)
	vbox.add_child(val_lbl)

	return val_lbl

func _render_table_headers() -> void:
	for child in table_grid.get_children():
		child.free()

	var headers := [
		"Juego",
		"Partidas",
		"% Victorias",
		"Racha Actual",
		"Racha Máxima",
		"ELO Local",
		"Victorias vs IA (F/N/D/E)",
	]
	for h in headers:
		var lbl := Label.new()
		lbl.text = h
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.35))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table_grid.add_child(lbl)

func refresh_stats() -> void:
	_build_ui()
	var tracker := _resolve_tracker()
	var milestones: Dictionary = tracker.call("get_personal_milestones", current_player_name)
	var rows: Array = tracker.call("get_all_13_games_summary", current_player_name)

	total_matches_label.text = str(milestones.get("total_matches", 0))
	favorite_game_label.text = str(milestones.get("favorite_game_name", "Sin partidas"))
	highest_elo_label.text = "%d (%s)" % [
		int(round(float(milestones.get("highest_elo", 1200.0)))),
		str(milestones.get("highest_elo_game_name", "Ajedrez (Chess)")),
	]

	_render_table_headers()

	for item in rows:
		var ai_dict: Dictionary = item.get("ai_wins_by_difficulty", {})
		var ai_summary := "%d / %d / %d / %d" % [
			int(ai_dict.get("easy", 0)),
			int(ai_dict.get("normal", 0)),
			int(ai_dict.get("hard", 0)),
			int(ai_dict.get("expert", 0)),
		]
		var cells := [
			str(item.get("game_name", item.get("game_id", ""))),
			str(item.get("games_played", 0)),
			"%.1f%%" % float(item.get("win_rate", 0.0)),
			str(item.get("win_streak", 0)),
			str(item.get("best_streak", 0)),
			str(int(round(float(item.get("elo", 1200.0))))),
			ai_summary,
		]
		for c_txt in cells:
			var lbl := Label.new()
			lbl.text = c_txt
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			table_grid.add_child(lbl)

func get_rendered_game_row_count() -> int:
	if table_grid == null:
		return 0
	var total_children := table_grid.get_child_count()
	if total_children <= 7:
		return 0
	return (total_children - 7) / 7

func _on_back_pressed() -> void:
	if is_inside_tree() and has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	elif is_inside_tree() and get_tree() != null:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")
