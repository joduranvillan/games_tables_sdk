extends Node2D

const BOARD_SIZE = 9
const CELL_SIZE = 66.0
const BOARD_ORIGIN_X = 40.0
const BOARD_ORIGIN_Y = 40.0
const P_SENTE = 1 # Player 1 (Sente / Black / Points UP)
const P_GOTE = 2  # Player 2 (Gote / White / Points DOWN)

# Kanji mapping for Shogi pieces
const KANJI_MAP = {
	"King": "王",
	"Jewel": "玉",
	"Rook": "飛",
	"Bishop": "角",
	"Gold": "金",
	"Silver": "銀",
	"Knight": "桂",
	"Lance": "香",
	"Pawn": "歩",
	"PromotedPawn": "と",
	"PromotedLance": "杏",
	"PromotedKnight": "圭",
	"PromotedSilver": "全",
	"Horse": "馬",
	"Dragon": "龍"
}

# Colors
const COL_BOARD = Color(0.92, 0.82, 0.62)
const COL_LINE = Color(0.2, 0.15, 0.1)
const COL_PIECE_BG = Color(0.96, 0.90, 0.75)
const COL_SELECT = Color(1.0, 0.9, 0.2, 0.55)
const COL_VALID_MOVE = Color(0.2, 0.8, 0.2, 0.55)

var bridge
var board: Array = [] # 9x9 array of piece dictionaries or null
var hands = {P_SENTE: {}, P_GOTE: {}} # player_id -> {piece_kind: count}
var current: int = P_SENTE
var winner: int = -1

var selected_board_pos = null # Vector2i(row, col)
var selected_hand_piece: String = "" # e.g. "Pawn"
var valid_moves: Array = [] # Array of Vector2i

var grid_container: GridContainer
var sente_hand_panel: VBoxContainer
var gote_hand_panel: VBoxContainer
var _hand_p1: VBoxContainer
var _hand_p2: VBoxContainer
var piece_nodes: Array = [] # 9x9 array of Node2D/Control nodes
var mode_option_button: OptionButton

var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var network_hud: NetworkStatusHUD
var _rules_popup: RulesPopup
var _pause_menu: CanvasLayer

@onready var status: Label = get_node_or_null("Status")

func _ready() -> void:
	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm = (get_node_or_null("/root/ThemeManager") if is_inside_tree() else null)
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)

	var gm = (get_node_or_null("/root/GameManager") if is_inside_tree() else null)
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)

	_setup_ui()
	_init_board_state()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	# HUD de red — solo en modo Host/Client, nunca en headless
	if not OS.has_feature("headless"):
		if bridge.has_method("is_network_mode") and bridge.call("is_network_mode"):
			var hud_script := load("res://network_status_hud.gd")
			if hud_script:
				var hud: Node = hud_script.new()
				if hud.has_method("setup"):
					hud.setup(bridge)
				elif hud.has_method("bind_bridge"):
					hud.bind_bridge(bridge)
				add_child(hud)

	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)

	if gm != null and gm.get_game_mode() == "vs_ai":
		var human_p: int = gm.get_human_player_id() if gm.has_method("get_human_player_id") else P_SENTE
		var ai_p: int = P_GOTE if human_p == P_SENTE else P_SENTE
		var diff: int = gm.get_ai_difficulty() if gm.has_method("get_ai_difficulty") else 1
		bridge.start_local_match_shogi_vs_ai(human_p, ai_p, diff)
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_p == P_SENTE else 2
	else:
		bridge.start_local_match_shogi(P_SENTE, P_GOTE)
		if mode_option_button != null:
			mode_option_button.selected = 0
	current = bridge.current_player()
	
	_on_layout_changed(gm.get_layout() if gm != null else 0)
	_update_hand_panels()
	_update_status()
	queue_redraw()

	# --- Botón de reglas ---
	var btn_rules := Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(820, 230)
	btn_rules.custom_minimum_size = Vector2(120, 36)
	btn_rules.pressed.connect(func(): _rules_popup.show_for_game("shogi"))
	add_child(btn_rules)

	_rules_popup = RulesPopup.new()
	_rules_popup.visible = false
	_rules_popup.position = Vector2(80, 100)
	add_child(_rules_popup)

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_quit_to_menu() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if grid_container:
		for cell in grid_container.get_children():
			if cell is ColorRect:
				cell.color = theme.board_color
				for ch in cell.get_children():
					if ch is ReferenceRect:
						ch.border_color = theme.line_color
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	queue_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

func _setup_ui() -> void:
	var side_x := 660.0
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	status.position = Vector2(side_x, 180)
	status.custom_minimum_size = Vector2(560, 36)

	# 9x9 GridContainer for the board
	grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = BOARD_SIZE
	grid_container.position = Vector2(BOARD_ORIGIN_X, BOARD_ORIGIN_Y)
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	add_child(grid_container)
	
	var bg_col = current_theme.board_color if current_theme != null else COL_BOARD
	var line_col = current_theme.line_color if current_theme != null else COL_LINE
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var cell = ColorRect.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.color = bg_col
			
			var border = ReferenceRect.new()
			border.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			border.border_color = line_col
			border.border_width = 1.0
			border.editor_only = false
			cell.add_child(border)
			
			grid_container.add_child(cell)
			
	# Right Side Panel for Gote Hand (P2)
	var gote_label = Label.new()
	gote_label.text = "Gote (P2) Mano (Komadai):"
	gote_label.position = Vector2(side_x, 285)
	add_child(gote_label)
	
	gote_hand_panel = VBoxContainer.new()
	gote_hand_panel.position = Vector2(side_x, 315)
	gote_hand_panel.custom_minimum_size = Vector2(240, 180)
	add_child(gote_hand_panel)
	
	# Right Side Panel for Sente Hand (P1)
	var sente_label = Label.new()
	sente_label.text = "Sente (P1) Mano (Komadai):"
	sente_label.position = Vector2(side_x + 280, 285)
	add_child(sente_label)
	
	sente_hand_panel = VBoxContainer.new()
	sente_hand_panel.position = Vector2(side_x + 280, 315)
	sente_hand_panel.custom_minimum_size = Vector2(240, 180)
	add_child(sente_hand_panel)

	# Mode Option Button
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(side_x, 24)
	mode_option_button.custom_minimum_size = Vector2(360, 36)
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano Sente - J1)")
	mode_option_button.add_item("vs IA (Humano Gote - J2, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(side_x, 80)
	add_child(turn_indicator)

	# Botón Tutorial Interactivo de Shogi (5 pasos)
	var tutorial_btn := Button.new()
	tutorial_btn.name = "ShogiTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(side_x, 230)
	tutorial_btn.custom_minimum_size = Vector2(145, 36)
	tutorial_btn.pressed.connect(start_shogi_tutorial)
	add_child(tutorial_btn)

	_setup_hand_panels()

func _setup_hand_panels() -> void:
	_hand_p1 = VBoxContainer.new()
	_hand_p1.name = "HandP1"
	_hand_p1.position = Vector2(940, 500)
	_hand_p1.custom_minimum_size = Vector2(120, 140)
	add_child(_hand_p1)

	_hand_p2 = VBoxContainer.new()
	_hand_p2.name = "HandP2"
	_hand_p2.position = Vector2(660, 500)
	_hand_p2.custom_minimum_size = Vector2(120, 140)
	add_child(_hand_p2)

func _update_hand_display(player: int, pieces: Array) -> void:
	var panel := _hand_p1 if player == 1 else _hand_p2
	if panel == null:
		return
	for child in panel.get_children():
		child.queue_free()
	for piece_name in pieces:
		var lbl := Label.new()
		lbl.text = tr(str(piece_name))  # nombre de pieza en idioma activo via tr()
		panel.add_child(lbl)

func _on_mode_selected(index: int) -> void:
	winner = -1
	selected_board_pos = null
	selected_hand_piece = ""
	valid_moves.clear()
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if piece_nodes.size() > r and piece_nodes[r].size() > c:
				if piece_nodes[r][c] != null and is_instance_valid(piece_nodes[r][c]):
					piece_nodes[r][c].queue_free()
					piece_nodes[r][c] = null

	_init_board_state()

	if bridge != null:
		match index:
			1:
				bridge.start_local_match_shogi_vs_ai(P_SENTE, P_GOTE, 1)
			2:
				bridge.start_local_match_shogi_vs_ai(P_GOTE, P_SENTE, 1)
			_:
				bridge.start_local_match_shogi(P_SENTE, P_GOTE)

	current = bridge.current_player() if bridge else P_SENTE
	_update_hand_panels()
	_update_status()
	queue_redraw()

func _init_board_state() -> void:
	board.clear()
	piece_nodes.clear()
	
	for r in range(BOARD_SIZE):
		var row_arr = []
		var node_arr = []
		for c in range(BOARD_SIZE):
			row_arr.append(null)
			node_arr.append(null)
		board.append(row_arr)
		piece_nodes.append(node_arr)
		
	# Initial Shogi setup
	var row0 = ["Lance", "Knight", "Silver", "Gold", "Jewel", "Gold", "Silver", "Knight", "Lance"]
	for c in range(9):
		_place_piece_on_board(0, c, P_GOTE, row0[c])
	_place_piece_on_board(1, 1, P_GOTE, "Rook")
	_place_piece_on_board(1, 7, P_GOTE, "Bishop")
	for c in range(9):
		_place_piece_on_board(2, c, P_GOTE, "Pawn")
		
	var row8 = ["Lance", "Knight", "Silver", "Gold", "King", "Gold", "Silver", "Knight", "Lance"]
	for c in range(9):
		_place_piece_on_board(8, c, P_SENTE, row8[c])
	_place_piece_on_board(7, 7, P_SENTE, "Rook")
	_place_piece_on_board(7, 1, P_SENTE, "Bishop")
	for c in range(9):
		_place_piece_on_board(6, c, P_SENTE, "Pawn")
		
	hands = {
		P_SENTE: {"Pawn": 0, "Silver": 0, "Gold": 0, "Bishop": 0, "Rook": 0, "Lance": 0, "Knight": 0},
		P_GOTE: {"Pawn": 0, "Silver": 0, "Gold": 0, "Bishop": 0, "Rook": 0, "Lance": 0, "Knight": 0}
	}

func _is_promoted(kind: String) -> bool:
	return kind.begins_with("Promoted") or kind == "Horse" or kind == "Dragon"

func _get_western_abbr(kind: String) -> String:
	match kind:
		"King", "Jewel": return "K"
		"Rook": return "R"
		"Bishop": return "B"
		"Gold": return "G"
		"Silver": return "S"
		"Knight": return "N"
		"Lance": return "L"
		"Pawn": return "P"
		"Dragon": return "+R"
		"Horse": return "+B"
		"PromotedSilver": return "+S"
		"PromotedKnight": return "+N"
		"PromotedLance": return "+L"
		"PromotedPawn": return "+P"
		_: return ""

func _create_pentagon_piece_node(player: int, kind: String) -> Control:
	var w = CELL_SIZE - 6.0
	var h = CELL_SIZE - 6.0
	
	var piece_ctrl = Control.new()
	piece_ctrl.custom_minimum_size = Vector2(w, h)
	piece_ctrl.size = Vector2(w, h)

	# Pentagon points
	var pts = PackedVector2Array()
	var sh_pts = PackedVector2Array()
	if player == P_SENTE: # Pointing UP
		pts.append(Vector2(w * 0.5, 2.0))
		pts.append(Vector2(w - 3.0, h * 0.32))
		pts.append(Vector2(w - 5.0, h - 2.0))
		pts.append(Vector2(5.0, h - 2.0))
		pts.append(Vector2(3.0, h * 0.32))
	else: # Pointing DOWN for Gote
		pts.append(Vector2(w * 0.5, h - 2.0))
		pts.append(Vector2(w - 3.0, h * 0.68))
		pts.append(Vector2(w - 5.0, 2.0))
		pts.append(Vector2(5.0, 2.0))
		pts.append(Vector2(3.0, h * 0.68))

	for pt in pts:
		sh_pts.append(pt + Vector2(2.0, 3.0))

	var shadow_poly = Polygon2D.new()
	shadow_poly.polygon = sh_pts
	shadow_poly.color = Color(0, 0, 0, 0.30)
	piece_ctrl.add_child(shadow_poly)

	var bg_poly = Polygon2D.new()
	bg_poly.polygon = pts
	bg_poly.color = COL_PIECE_BG
	piece_ctrl.add_child(bg_poly)

	var border_line = Line2D.new()
	border_line.width = 2.0
	border_line.default_color = COL_LINE
	for pt in pts: border_line.add_point(pt)
	border_line.add_point(pts[0])
	piece_ctrl.add_child(border_line)

	var kanji = Label.new()
	kanji.text = KANJI_MAP.get(kind, "?")
	kanji.add_theme_font_size_override("font_size", 26)
	kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kanji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kanji.size = Vector2(w, h - 10.0)
	kanji.position = Vector2(0, 0 if player == P_SENTE else 6.0)

	# Promoted pieces display RED text
	var text_col = Color(0.82, 0.12, 0.12) if _is_promoted(kind) else Color(0.10, 0.08, 0.06)
	kanji.add_theme_color_override("font_color", text_col)
	piece_ctrl.add_child(kanji)

	var abbr = Label.new()
	abbr.text = _get_western_abbr(kind)
	abbr.add_theme_font_size_override("font_size", 10)
	abbr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abbr.size = Vector2(w, 14.0)
	abbr.position = Vector2(0, h - 15.0 if player == P_SENTE else 2.0)
	abbr.add_theme_color_override("font_color", Color(text_col.r, text_col.g, text_col.b, 0.72))
	piece_ctrl.add_child(abbr)

	return piece_ctrl

func _place_piece_on_board(row: int, col: int, player: int, kind: String) -> void:
	board[row][col] = {"player": player, "kind": kind}
	
	var piece_ctrl = _create_pentagon_piece_node(player, kind)
	piece_ctrl.position = Vector2(BOARD_ORIGIN_X + col * CELL_SIZE + 3, BOARD_ORIGIN_Y + row * CELL_SIZE + 3)
	add_child(piece_ctrl)
	piece_nodes[row][col] = piece_ctrl

func _input(event: InputEvent) -> void:
	if winner != -1:
		return
		
	var click_pos = Vector2.ZERO
	var handled = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_pos = event.position
		handled = true
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = event.position
		handled = true
		
	if handled:
		var board_x = click_pos.x - BOARD_ORIGIN_X
		var board_y = click_pos.y - BOARD_ORIGIN_Y
		
		if board_x >= 0 and board_x < BOARD_SIZE * CELL_SIZE and board_y >= 0 and board_y < BOARD_SIZE * CELL_SIZE:
			var col = int(board_x / CELL_SIZE)
			var row = int(board_y / CELL_SIZE)
			_handle_board_click(row, col)

func _calculate_valid_shogi_moves(r: int, c: int) -> Array:
	var moves: Array = []
	var piece = board[r][c]
	if piece == null: return moves

	if bridge != null and bridge.has_method("get_legal_moves"):
		var legal = bridge.get_legal_moves(current)
		for m in legal:
			if m is Dictionary and m.has("from") and m.has("to"):
				var f = m["from"]
				var t = m["to"]
				if f is Array and f.size() >= 2 and t is Array and t.size() >= 2:
					# En Rust shogi_game, from/to son [col, row]
					if int(f[0]) == c and int(f[1]) == r:
						var dest := Vector2i(int(t[1]), int(t[0]))
						if not dest in moves:
							moves.append(dest)
		if not moves.is_empty():
			return moves

	var player = piece.get("player")
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0: continue
			var tr = r + dr
			var tc = c + dc
			if tr >= 0 and tr < BOARD_SIZE and tc >= 0 and tc < BOARD_SIZE:
				var target = board[tr][tc]
				if target == null or target.get("player") != player:
					moves.append(Vector2i(tr, tc))
	return moves

func _calculate_valid_drops() -> Array:
	var drops: Array = []
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if board[r][c] == null:
				drops.append(Vector2i(r, c))
	return drops

func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(BOARD_ORIGIN_X + cell.x * CELL_SIZE, BOARD_ORIGIN_Y + cell.y * CELL_SIZE)

func start_shogi_tutorial() -> void:
	var ShogiTut = load("res://scripts/tutorials/shogi_tutorial.gd")
	if ShogiTut != null:
		ShogiTut.start_on_board(self)

func _handle_board_click(row: int, col: int) -> void:
	if (is_inside_tree() and has_node("/root/TutorialManager")):
		var tm = get_node("/root/TutorialManager")
		if tm.get("is_running") == true:
			if not tm.call("notify_cell_action", Vector2i(col, row)):
				return
	# 1. Drop piece from hand
	if selected_hand_piece != "":
		var drop_kind = selected_hand_piece
		selected_hand_piece = ""
		valid_moves.clear()
		queue_redraw()
		
		var cmd = {
			"command_type": "shogi_game::DropPieceCommand",
			"player": current,
			"piece": drop_kind,
			"to": [col, row]
		}
		bridge.send_command_json(current, JSON.stringify(cmd))
		return
		
	# 2. Board selection & movement
	if selected_board_pos == null:
		var cell = board[row][col]
		if cell != null and cell.get("player") == current:
			selected_board_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_shogi_moves(row, col)
			queue_redraw()
	else:
		if selected_board_pos.x == row and selected_board_pos.y == col:
			selected_board_pos = null
			valid_moves.clear()
			queue_redraw()
			return

		var target_cell = board[row][col]
		if target_cell != null and target_cell.get("player") == current:
			selected_board_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_shogi_moves(row, col)
			queue_redraw()
			return
			
		var from_pos = selected_board_pos
		selected_board_pos = null
		valid_moves.clear()
		queue_redraw()
		
		var moving_piece = board[from_pos.x][from_pos.y]
		var should_promote := false
		if moving_piece != null:
			var p_kind: String = str(moving_piece.get("kind", ""))
			if p_kind in ["Pawn", "Lance", "Knight", "Silver", "Bishop", "Rook"]:
				if current == P_SENTE and (row <= 2 or from_pos.x <= 2):
					should_promote = true
				elif current == P_GOTE and (row >= 6 or from_pos.x >= 6):
					should_promote = true

		var cmd = {
			"command_type": "shogi_game::MovePieceCommand",
			"player": current,
			"from": [from_pos.y, from_pos.x],
			"to": [col, row],
			"promote": should_promote
		}
		bridge.send_command_json(current, JSON.stringify(cmd))

func _update_hand_panels() -> void:
	for child in sente_hand_panel.get_children(): child.queue_free()
	for child in gote_hand_panel.get_children(): child.queue_free()
	
	_populate_hand_container(sente_hand_panel, P_SENTE)
	_populate_hand_container(gote_hand_panel, P_GOTE)
	_refresh_hand_displays_from_event_or_state({})

func _refresh_hand_displays_from_event_or_state(event: Dictionary = {}) -> void:
	var p1_pieces: Array = []
	var p2_pieces: Array = []
	
	if event.has("hand_p1") and event["hand_p1"] is Array:
		p1_pieces = event["hand_p1"]
	elif event.has("hands") and event["hands"] is Dictionary:
		p1_pieces = event["hands"].get("1", event["hands"].get(1, []))
	
	if event.has("hand_p2") and event["hand_p2"] is Array:
		p2_pieces = event["hand_p2"]
	elif event.has("hands") and event["hands"] is Dictionary:
		p2_pieces = event["hands"].get("2", event["hands"].get(2, []))
		
	if p1_pieces.is_empty() and bridge != null and bridge.has_method("get_state_json"):
		var state_str = bridge.get_state_json()
		var p_json = JSON.new()
		if p_json.parse(state_str) == OK and p_json.data is Dictionary:
			var s_data = p_json.data
			if s_data.has("hand_p1") and s_data["hand_p1"] is Array:
				p1_pieces = s_data["hand_p1"]
			if s_data.has("hand_p2") and s_data["hand_p2"] is Array:
				p2_pieces = s_data["hand_p2"]
				
	if p1_pieces.is_empty() and bridge != null and bridge.has_method("get_hand_json"):
		var h1_str = bridge.get_hand_json(1)
		var p_json = JSON.new()
		if p_json.parse(h1_str) == OK and p_json.data is Array:
			p1_pieces = p_json.data
		var h2_str = bridge.get_hand_json(2)
		if p_json.parse(h2_str) == OK and p_json.data is Array:
			p2_pieces = p_json.data
			
	if p1_pieces.is_empty() and hands.has(P_SENTE):
		for k in hands[P_SENTE].keys():
			for i in range(hands[P_SENTE][k]):
				p1_pieces.append(k)
				
	if p2_pieces.is_empty() and hands.has(P_GOTE):
		for k in hands[P_GOTE].keys():
			for i in range(hands[P_GOTE][k]):
				p2_pieces.append(k)
				
	_update_hand_display(1, p1_pieces)
	_update_hand_display(2, p2_pieces)

func _populate_hand_container(panel: VBoxContainer, player: int) -> void:
	var player_hand = hands.get(player, {})
	for kind in player_hand.keys():
		var count = player_hand[kind]
		if count > 0:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(85, 45)
			var kanji_symbol = KANJI_MAP.get(kind, kind)
			btn.text = "%s x%d" % [kanji_symbol, count]
			btn.add_theme_font_size_override("font_size", 18)
			
			if player == current:
				btn.pressed.connect(func():
					selected_board_pos = null
					selected_hand_piece = kind
					valid_moves = _calculate_valid_drops()
					queue_redraw()
				)
			panel.add_child(btn)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type := str(event.get("command_type", event.get("event_type", "")))
			var event_type := raw_type.split("::")[-1]
			if event_type == "PieceMovedEvent":
				var from = event.get("from", [0, 0])
				var to = event.get("to", [0, 0])
				# Coordenadas en shogi_game (Rust): [col, row]
				var from_c = int(from[0])
				var from_r = int(from[1])
				var to_c = int(to[0])
				var to_r = int(to[1])
				var promoted_flag: bool = event.get("promoted", false) == true
				
				var piece_data = board[from_r][from_c]
				var cap_evt = event.get("captured", null)
				var is_cap = (cap_evt != null) or (board[to_r][to_c] != null)
				if piece_data != null:
					if is_cap:
						var cap_kind = "Pawn"
						if cap_evt != null and cap_evt is Dictionary:
							cap_kind = cap_evt.get("kind", "Pawn")
						elif cap_evt != null and cap_evt is String:
							cap_kind = cap_evt
						elif board[to_r][to_c] != null:
							cap_kind = board[to_r][to_c].get("kind", "Pawn")

						if cap_kind.begins_with("Promoted"):
							cap_kind = cap_kind.replace("Promoted", "")
						elif cap_kind == "Horse":
							cap_kind = "Bishop"
						elif cap_kind == "Dragon":
							cap_kind = "Rook"

						var p_hand = hands[piece_data.player]
						p_hand[cap_kind] = p_hand.get(cap_kind, 0) + 1
						if piece_nodes[to_r][to_c] != null:
							piece_nodes[to_r][to_c].queue_free()
							piece_nodes[to_r][to_c] = null
						if (is_inside_tree() and has_node("/root/AudioManager")):
							get_node("/root/AudioManager").play_piece_place(2.0)
					else:
						if (is_inside_tree() and has_node("/root/AudioManager")):
							get_node("/root/AudioManager").play_piece_place()

					if promoted_flag:
						var base_k: String = str(piece_data.get("kind", ""))
						match base_k:
							"Pawn": piece_data["kind"] = "PromotedPawn"
							"Lance": piece_data["kind"] = "PromotedLance"
							"Knight": piece_data["kind"] = "PromotedKnight"
							"Silver": piece_data["kind"] = "PromotedSilver"
							"Bishop": piece_data["kind"] = "Horse"
							"Rook": piece_data["kind"] = "Dragon"

					board[from_r][from_c] = null
					board[to_r][to_c] = piece_data
					
					var node = piece_nodes[from_r][from_c]
					piece_nodes[from_r][from_c] = null
					if promoted_flag and node != null:
						node.queue_free()
						_place_piece_on_board(to_r, to_c, piece_data.player, piece_data.kind)
					else:
						piece_nodes[to_r][to_c] = node
						if node != null:
							node.position = Vector2(BOARD_ORIGIN_X + to_c * CELL_SIZE + 3, BOARD_ORIGIN_Y + to_r * CELL_SIZE + 3)

				if is_cap:
					_refresh_hand_displays_from_event_or_state(event)
						
			elif event_type == "PieceDroppedEvent":
				var to = event.get("to", [0, 0])
				var kind = str(event.get("piece", "Pawn"))
				var p = int(event.get("player", current))
				var to_c = int(to[0])
				var to_r = int(to[1])
				
				_place_piece_on_board(to_r, to_c, p, kind)
				if hands.has(p) and hands[p].has(kind):
					hands[p][kind] = max(0, hands[p][kind] - 1)
				if (is_inside_tree() and has_node("/root/AudioManager")):
					get_node("/root/AudioManager").play_piece_place()

				_refresh_hand_displays_from_event_or_state(event)
					
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))
				
	current = bridge.current_player()
	_update_hand_panels()
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _draw() -> void:
	# Marco exterior del Shogiban y puntos estelares de zona de promoción (Hoshi)
	var b_rect := Rect2(BOARD_ORIGIN_X, BOARD_ORIGIN_Y, BOARD_SIZE * CELL_SIZE, BOARD_SIZE * CELL_SIZE)
	draw_rect(Rect2(BOARD_ORIGIN_X - 4, BOARD_ORIGIN_Y - 4, BOARD_SIZE * CELL_SIZE + 8, BOARD_SIZE * CELL_SIZE + 8), Color(0.28, 0.18, 0.10), false, 4.0)
	draw_rect(b_rect, COL_LINE, false, 2.0)
	for r_idx in [3, 6]:
		for c_idx in [3, 6]:
			draw_circle(Vector2(BOARD_ORIGIN_X + c_idx * CELL_SIZE, BOARD_ORIGIN_Y + r_idx * CELL_SIZE), 4.0, COL_LINE)

	if selected_board_pos != null:
		var rect = Rect2(BOARD_ORIGIN_X + selected_board_pos.y * CELL_SIZE, BOARD_ORIGIN_Y + selected_board_pos.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(rect, COL_SELECT)

	# Draw valid move / drop destinations with green circles
	for pos in valid_moves:
		var center = Vector2(BOARD_ORIGIN_X + pos.y * CELL_SIZE + CELL_SIZE / 2.0, BOARD_ORIGIN_Y + pos.x * CELL_SIZE + CELL_SIZE / 2.0)
		draw_circle(center, CELL_SIZE * 0.25, COL_VALID_MOVE)

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Jaque mate! Ganó el jugador %s" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var name = "Sente (P1)" if current == P_SENTE else "Gote (P2)"
		var col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(current) - 1, 6)] as Color)
		var hand_sel_text = " (Mano: %s)" % selected_hand_piece if selected_hand_piece != "" else ""
		status.text = "Turno: Jugador %s (Shogi)%s" % [name, hand_sel_text]
		if turn_indicator != null:
			turn_indicator.set_turn(current, name, col)
			turn_indicator.set_active(true)

# --- Conexión de eventos sonoros procedurales (AudioManager) ---
func _sfx_piece_slide() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_slide()

func _sfx_piece_place() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

func _sfx_capture(world_pos: Vector2 = Vector2(240, 240)) -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place(2.0)
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.45
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 110.0
	particles.color = Color(1.0, 0.85, 0.3, 0.9)
	add_child(particles)
	if is_inside_tree():
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)

func _sfx_dice_roll() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_dice_roll()

func _sfx_card_flip() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_card_flip()

func _sfx_check_alert() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_check_alert()

func _sfx_victory_fanfare() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()

func _sfx_error_buzz() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()
