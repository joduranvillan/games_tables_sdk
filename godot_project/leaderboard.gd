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

@export var relay_http_url: String = "http://127.0.0.1:8081"

var http_request: HTTPRequest
var game_option: OptionButton
var refresh_btn: Button
var back_btn: Button
var loading_label: Label
var status_label: Label
var table_grid: GridContainer
var current_game_id: String = "chess"

func _ready() -> void:
	_build_ui()
	http_request = HTTPRequest.new()
	http_request.timeout = 4.0
	http_request.request_completed.connect(_on_request_completed)
	add_child(http_request)
	fetch_rankings(current_game_id)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.14, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.position = Vector2(60, 36)
	main_vbox.custom_minimum_size = Vector2(1160, 640)
	main_vbox.add_theme_constant_override("separation", 16)
	add_child(main_vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏆 Clasificación Global ELO (Top 10)"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	game_option = OptionButton.new()
	game_option.custom_minimum_size = Vector2(240, 40)
	for g in GAMES:
		game_option.add_item(g["name"])
	game_option.item_selected.connect(_on_game_selected)
	header_hbox.add_child(game_option)

	refresh_btn = Button.new()
	refresh_btn.text = "🔄 Actualizar"
	refresh_btn.custom_minimum_size = Vector2(140, 40)
	refresh_btn.pressed.connect(func(): fetch_rankings(current_game_id))
	header_hbox.add_child(refresh_btn)

	back_btn = Button.new()
	back_btn.text = "⬅ Volver"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.pressed.connect(_on_back_pressed)
	header_hbox.add_child(back_btn)

	loading_label = Label.new()
	loading_label.text = "⏳ Consultando servidor de ranking..."
	loading_label.add_theme_font_size_override("font_size", 16)
	loading_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	loading_label.visible = false
	main_vbox.add_child(loading_label)

	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	status_label.visible = false
	main_vbox.add_child(status_label)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.21, 0.95)
	style.border_color = Color(0.3, 0.4, 0.55, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	main_vbox.add_child(panel)

	table_grid = GridContainer.new()
	table_grid.columns = 5
	table_grid.add_theme_constant_override("h_separation", 28)
	table_grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(table_grid)

	_render_table_headers()

func _render_table_headers() -> void:
	for child in table_grid.get_children():
		child.queue_free()

	var headers := ["Posición", "Nombre de jugador", "ELO", "Victorias", "Derrotas"]
	for h in headers:
		var lbl := Label.new()
		lbl.text = h
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table_grid.add_child(lbl)

func fetch_rankings(game_id: String) -> void:
	current_game_id = game_id
	loading_label.visible = true
	status_label.visible = false
	refresh_btn.disabled = true

	var endpoint := "%s/rankings/%s" % [relay_http_url.trim_suffix("/"), game_id]
	var err := http_request.request(endpoint)
	if err != OK:
		_show_offline_message()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	loading_label.visible = false
	refresh_btn.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_show_offline_message()
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not (parsed is Array):
		_show_offline_message()
		return

	populate_rankings(parsed)

func populate_rankings(entries: Array) -> void:
	status_label.visible = false
	_render_table_headers()

	var max_rows := mini(entries.size(), 10)
	if max_rows == 0:
		status_label.text = "Aún no hay partidas registradas para este juego."
		status_label.visible = true
		return

	for i in range(max_rows):
		var item: Dictionary = entries[i] if entries[i] is Dictionary else {}
		var cells := [
			"#%d" % (i + 1),
			str(item.get("player_id", "Jugador")),
			str(item.get("elo", 1200)),
			str(item.get("wins", 0)),
			str(item.get("losses", 0)),
		]
		for c_txt in cells:
			var lbl := Label.new()
			lbl.text = c_txt
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			table_grid.add_child(lbl)

func _show_offline_message() -> void:
	loading_label.visible = false
	refresh_btn.disabled = false
	_render_table_headers()
	status_label.text = "Sin conexión al servidor de ranking"
	status_label.visible = true

func _on_game_selected(idx: int) -> void:
	if idx >= 0 and idx < GAMES.size():
		fetch_rankings(GAMES[idx]["id"])

func _on_back_pressed() -> void:
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")
