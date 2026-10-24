extends Control

const GAMES := [
	{"id": "chess", "name": "Ajedrez (Chess)"},
	{"id": "go", "name": "Go"},
	{"id": "checkers", "name": "Damas (Checkers)"},
	{"id": "shogi", "name": "Shogi"},
	{"id": "xiangqi", "name": "Xiangqi"},
	{"id": "chinese_checkers", "name": "Damas Chinas"},
	{"id": "backgammon", "name": "Backgammon"},
	{"id": "battleship", "name": "Batalla Naval"},
	{"id": "ludo", "name": "Ludo"},
	{"id": "mille_bornes", "name": "Mille Bornes"},
	{"id": "monopoly", "name": "Monopoly"},
	{"id": "uno", "name": "Uno"},
	{"id": "crisis", "name": "Crisis / TEG"},
]

const SIZES := [4, 8, 16]

var game_option: OptionButton
var size_option: OptionButton
var code_input: LineEdit
var create_btn: Button
var join_btn: Button
var back_btn: Button
var status_label: Label
var bracket_canvas: Control

var current_tournament: Dictionary = {}

func _ready() -> void:
	_build_ui()
	_populate_sample_bracket(4)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.14, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.position = Vector2(50, 30)
	main_vbox.custom_minimum_size = Vector2(1180, 660)
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 14)
	main_vbox.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏟 Torneos — Llaves de Eliminación Simple"
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_lbl)

	game_option = OptionButton.new()
	game_option.custom_minimum_size = Vector2(200, 38)
	for g in GAMES:
		game_option.add_item(g["name"])
	top_hbox.add_child(game_option)

	size_option = OptionButton.new()
	size_option.custom_minimum_size = Vector2(140, 38)
	for sz in SIZES:
		size_option.add_item("%d Jugadores" % sz)
	top_hbox.add_child(size_option)

	create_btn = Button.new()
	create_btn.text = "➕ Crear Torneo"
	create_btn.custom_minimum_size = Vector2(150, 38)
	create_btn.pressed.connect(_on_create_tournament_pressed)
	top_hbox.add_child(create_btn)

	code_input = LineEdit.new()
	code_input.placeholder_text = "Código (ej. T-AB12)"
	code_input.custom_minimum_size = Vector2(160, 38)
	top_hbox.add_child(code_input)

	join_btn = Button.new()
	join_btn.text = "Unirse"
	join_btn.custom_minimum_size = Vector2(100, 38)
	join_btn.pressed.connect(_on_join_tournament_pressed)
	top_hbox.add_child(join_btn)

	back_btn = Button.new()
	back_btn.text = "⬅ Volver"
	back_btn.custom_minimum_size = Vector2(110, 38)
	back_btn.pressed.connect(_on_back_pressed)
	top_hbox.add_child(back_btn)

	status_label = Label.new()
	status_label.text = "Selecciona cupo (4, 8 o 16) para crear un torneo o ingresa un código T-XXXX."
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	main_vbox.add_child(status_label)

	bracket_canvas = Control.new()
	bracket_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bracket_canvas.custom_minimum_size = Vector2(1160, 520)
	bracket_canvas.draw.connect(_draw_bracket)
	main_vbox.add_child(bracket_canvas)

func _on_create_tournament_pressed() -> void:
	var sz_idx := size_option.selected
	var max_p: int = SIZES[clampi(sz_idx, 0, SIZES.size() - 1)]
	var g_idx := game_option.selected
	var game_id: String = GAMES[clampi(g_idx, 0, GAMES.size() - 1)]["id"]

	var req := {
		"op": "create_tournament",
		"game_id": game_id,
		"max_players": max_p,
	}
	status_label.text = "Torneo creado (%s, %d jugadores) — Protocolo: %s" % [game_id, max_p, JSON.stringify(req)]
	_populate_sample_bracket(max_p)

func _on_join_tournament_pressed() -> void:
	var tid := code_input.text.strip_edges().to_upper()
	if tid.is_empty():
		tid = "T-AB12"
	var req := {
		"op": "join_tournament",
		"tournament_id": tid,
	}
	status_label.text = "Unido al torneo %s — Protocolo: %s" % [tid, JSON.stringify(req)]
	bracket_canvas.queue_redraw()

func _populate_sample_bracket(max_players: int) -> void:
	var rounds: Array = []
	var match_count := max_players / 2
	var r := 0
	while match_count >= 1:
		var r_matches: Array = []
		for m in range(match_count):
			var p1_name := "Jugador %d" % (m * 2 + 1) if r == 0 else "Por definir"
			var p2_name := "Jugador %d" % (m * 2 + 2) if r == 0 else "Por definir"
			r_matches.append({
				"round": r,
				"match_index": m,
				"player1": p1_name,
				"player2": p2_name,
				"winner": "",
			})
		rounds.append(r_matches)
		match_count /= 2
		r += 1

	current_tournament = {
		"tournament_id": "T-AB12",
		"max_players": max_players,
		"rounds": rounds,
	}
	if bracket_canvas != null:
		bracket_canvas.queue_redraw()

func _draw_bracket() -> void:
	if current_tournament.is_empty() or not current_tournament.has("rounds"):
		return
	var rounds: Array = current_tournament["rounds"]
	if rounds.is_empty():
		return

	var font: Font = ThemeDB.fallback_font
	var col_width := 260.0
	var box_w := 190.0
	var box_h := 46.0
	var canvas_h := bracket_canvas.size.y if bracket_canvas.size.y > 100.0 else 500.0

	for r in range(rounds.size()):
		var matches: Array = rounds[r]
		var m_count := matches.size()
		var x := 30.0 + r * col_width
		var step_y := canvas_h / float(m_count)

		for m in range(m_count):
			var match_data: Dictionary = matches[m]
			var center_y := (m + 0.5) * step_y
			var rect := Rect2(x, center_y - box_h / 2.0, box_w, box_h)

			bracket_canvas.draw_rect(rect, Color(0.15, 0.20, 0.28, 0.95), true)
			bracket_canvas.draw_rect(rect, Color(0.4, 0.65, 0.95, 0.9), false, 2.0)

			var p1 := str(match_data.get("player1", "TBD"))
			var p2 := str(match_data.get("player2", "TBD"))
			if font != null:
				bracket_canvas.draw_string(font, Vector2(x + 10, center_y - 4), p1, HORIZONTAL_ALIGNMENT_LEFT, box_w - 20, 13, Color.WHITE)
				bracket_canvas.draw_string(font, Vector2(x + 10, center_y + 16), p2, HORIZONTAL_ALIGNMENT_LEFT, box_w - 20, 13, Color(0.8, 0.9, 1.0))

			# Líneas de conexión hacia la siguiente ronda
			if r + 1 < rounds.size():
				var next_step_y := canvas_h / float(rounds[r + 1].size())
				var next_center_y := (int(m / 2) + 0.5) * next_step_y
				var start_pt := Vector2(x + box_w, center_y)
				var mid_x := x + box_w + (col_width - box_w) * 0.5
				var end_pt := Vector2(x + col_width, next_center_y)
				var line_col := Color(0.95, 0.80, 0.30, 0.85)
				bracket_canvas.draw_line(start_pt, Vector2(mid_x, center_y), line_col, 2.0)
				bracket_canvas.draw_line(Vector2(mid_x, center_y), Vector2(mid_x, next_center_y), line_col, 2.0)
				bracket_canvas.draw_line(Vector2(mid_x, next_center_y), end_pt, line_col, 2.0)

func _on_back_pressed() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")
