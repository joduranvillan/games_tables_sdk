# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
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
	"PromotedBishop": "馬",
	"PromotedRook": "龍",
	"Horse": "馬",
	"Dragon": "龍"
}

# Colors
const COL_BOARD = Color(0.86, 0.70, 0.47)
const COL_BOARD_FRAME = Color(0.33, 0.20, 0.11)
const COL_LINE = Color(0.18, 0.12, 0.07)
const COL_PIECE_BG = Color(0.97, 0.92, 0.80)
const COL_PIECE_BORDER = Color(0.22, 0.14, 0.08)
const COL_SELECT = Color(1.0, 0.85, 0.20, 0.48)
const COL_VALID_MOVE = Color(0.18, 0.78, 0.30, 0.62)
const COL_LAST_MOVE = Color(0.95, 0.62, 0.15, 0.30)

var bridge
var board: Array = [] # 9x9 array of piece dictionaries or null
var hands = {P_SENTE: {}, P_GOTE: {}} # player_id -> {piece_kind: count}
var current: int = P_SENTE
var winner: int = -1

var selected_board_pos = null # Vector2i(row, col)
var selected_hand_piece: String = "" # e.g. "Pawn"
var valid_moves: Array = [] # Array of Vector2i
var last_move_from = null # Vector2i(row, col)
var last_move_to = null # Vector2i(row, col)

var grid_container: GridContainer
var pieces_container: Node2D
var board_overlay: Node2D
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
var promotion_dialog_panel: PanelContainer = null
var auto_promote_choice: bool = true
var _pending_shogi_move: Dictionary = {}

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
			var hud_script = load("res://network_status_hud.gd")
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
	_request_board_redraw()

	# --- Botón de reglas (integrado en GameAppMenu / Opciones) ---
	var btn_rules: Button = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.position = Vector2(820, 230)
	btn_rules.custom_minimum_size = Vector2(120, 36)
	btn_rules.visible = false
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

func _restore_piece_label_fonts() -> void:
	for r in range(piece_nodes.size()):
		var row_nodes = piece_nodes[r]
		if row_nodes is Array:
			for c in range(row_nodes.size()):
				var p_node = row_nodes[c]
				if p_node != null and is_instance_valid(p_node):
					for child in p_node.get_children():
						if child is Label and child.has_meta("shogi_piece_font_size"):
							child.add_theme_font_size_override("font_size", int(child.get_meta("shogi_piece_font_size")))

func _request_board_redraw() -> void:
	queue_redraw()
	if board_overlay != null and is_instance_valid(board_overlay):
		board_overlay.queue_redraw()

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	_restore_piece_label_fonts()
	_request_board_redraw()

func _on_layout_changed(_layout: int) -> void:
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)
	_restore_piece_label_fonts()
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz: Vector2 = get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz
	if _layout == 2 and vp_size.x >= 1000.0:
		vp_size = Vector2(375, 667)
	var min_x: float = 36.0
	var min_y: float = -64.0
	var design_w: float = 602.0
	var design_h: float = 788.0
	var s: float = clampf(minf((vp_size.x - 40.0) / design_w, (vp_size.y - 24.0) / design_h), 0.30, 1.0)
	scale = Vector2(s, s)
	position = Vector2(
		(vp_size.x - design_w * s) * 0.5 - min_x * s,
		(vp_size.y - design_h * s) * 0.5 - min_y * s
	)

func _ensure_board_containers() -> void:
	if pieces_container == null or not is_instance_valid(pieces_container):
		pieces_container = Node2D.new()
		pieces_container.name = "PiecesContainer"
		pieces_container.z_index = 1
		add_child(pieces_container)
	if board_overlay == null or not is_instance_valid(board_overlay):
		board_overlay = Node2D.new()
		board_overlay.name = "BoardOverlay"
		board_overlay.z_index = 2
		board_overlay.draw.connect(_draw_board_overlay)
		add_child(board_overlay)

func _setup_ui() -> void:
	if status == null:
		status = get_node_or_null("Status")
	if status == null:
		status = Label.new()
		status.name = "Status"
		add_child(status)
	# Zona Superior Centrada: Turno, Reloj y Capturas Gote (P2)
	status.position = Vector2(310, -54)
	status.custom_minimum_size = Vector2(324, 34)

	# 9x9 GridContainer for structural compatibility; visual grid is drawn crisply via _draw()
	grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = BOARD_SIZE
	grid_container.position = Vector2(BOARD_ORIGIN_X, BOARD_ORIGIN_Y)
	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	add_child(grid_container)
	
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var cell = ColorRect.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.color = Color(0, 0, 0, 0)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_container.add_child(cell)

	_ensure_board_containers()
			
	# Zona Superior Centrada: Gote Hand / Capturas del Oponente (P2)
	var gote_label = Label.new()
	gote_label.text = "Gote (P2) Mano (Komadai):"
	gote_label.position = Vector2(40, -14)
	add_child(gote_label)
	
	gote_hand_panel = VBoxContainer.new()
	gote_hand_panel.position = Vector2(235, -18)
	gote_hand_panel.custom_minimum_size = Vector2(210, 44)
	add_child(gote_hand_panel)
	
	# Zona Inferior Centrada: Sente Hand / Piezas Propias para Drop en el Turno (P1)
	var sente_label = Label.new()
	sente_label.text = "Sente (P1) Mano (Komadai — Selecciona para Drop):"
	sente_label.position = Vector2(40, 642)
	add_child(sente_label)
	
	sente_hand_panel = VBoxContainer.new()
	sente_hand_panel.position = Vector2(40, 666)
	sente_hand_panel.custom_minimum_size = Vector2(240, 52)
	add_child(sente_hand_panel)

	# Mode Option Button (integrado en GameAppMenu / Opciones)
	mode_option_button = OptionButton.new()
	mode_option_button.name = "ModeOptionButton"
	mode_option_button.position = Vector2(150, -56)
	mode_option_button.custom_minimum_size = Vector2(360, 36)
	mode_option_button.visible = false
	mode_option_button.add_item("Hotseat (2 jugadores)")
	mode_option_button.add_item("vs IA (Humano Sente - J1)")
	mode_option_button.add_item("vs IA (Humano Gote - J2, IA inicia)")
	mode_option_button.item_selected.connect(_on_mode_selected)
	add_child(mode_option_button)

	# Turn Indicator Widget (Zona Superior Centrada)
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(40, -58)
	add_child(turn_indicator)

	# Botón Tutorial Interactivo de Shogi (integrado en GameAppMenu / Opciones)
	var tutorial_btn: Button = Button.new()
	tutorial_btn.name = "ShogiTutorialButton"
	tutorial_btn.text = "🎓 Tutorial"
	tutorial_btn.position = Vector2(260, 642)
	tutorial_btn.custom_minimum_size = Vector2(145, 36)
	tutorial_btn.visible = false
	tutorial_btn.pressed.connect(start_shogi_tutorial)
	add_child(tutorial_btn)

	# Diálogo Modal Estilizado de Promoción Opcional FESA (PromotionDialogPanel en Zona Inferior Centrada)
	promotion_dialog_panel = PanelContainer.new()
	promotion_dialog_panel.name = "PromotionDialogPanel"
	promotion_dialog_panel.position = Vector2(155, 644)
	promotion_dialog_panel.z_index = 25
	promotion_dialog_panel.visible = false
	var shogi_promo_style: StyleBoxFlat = StyleBoxFlat.new()
	shogi_promo_style.bg_color = Color(0.11, 0.13, 0.18, 0.96)
	shogi_promo_style.border_color = Color(0.92, 0.76, 0.28, 0.95)
	shogi_promo_style.set_border_width_all(2)
	shogi_promo_style.set_corner_radius_all(10)
	shogi_promo_style.content_margin_left = 16
	shogi_promo_style.content_margin_right = 16
	shogi_promo_style.content_margin_top = 12
	shogi_promo_style.content_margin_bottom = 12
	promotion_dialog_panel.add_theme_stylebox_override("panel", shogi_promo_style)
	var promo_vb: VBoxContainer = VBoxContainer.new()
	promo_vb.add_theme_constant_override("separation", 10)
	var promo_lbl: Label = Label.new()
	promo_lbl.text = "⛩️ ¿Promocionar pieza (Nari / 成)? (Teclas 1–2)"
	promo_lbl.add_theme_font_size_override("font_size", 17)
	promo_lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.55))
	promo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	promo_vb.add_child(promo_lbl)
	var promo_hb: HBoxContainer = HBoxContainer.new()
	promo_hb.add_theme_constant_override("separation", 12)
	var btn_yes: Button = Button.new()
	btn_yes.name = "PromoteYesButton"
	btn_yes.text = "[1] ⬆️ Promocionar"
	btn_yes.custom_minimum_size = Vector2(155, 42)
	btn_yes.pressed.connect(func(): set_promotion_choice(true))
	promo_hb.add_child(btn_yes)
	var btn_no: Button = Button.new()
	btn_no.name = "PromoteNoButton"
	btn_no.text = "[2] ➡️ No promocionar"
	btn_no.custom_minimum_size = Vector2(165, 42)
	btn_no.pressed.connect(func(): set_promotion_choice(false))
	promo_hb.add_child(btn_no)
	promo_vb.add_child(promo_hb)
	promotion_dialog_panel.add_child(promo_vb)
	add_child(promotion_dialog_panel)

	_setup_hand_panels()

func _setup_hand_panels() -> void:
	_hand_p1 = VBoxContainer.new()
	_hand_p1.name = "HandP1"
	_hand_p1.position = Vector2(360, 666)
	_hand_p1.custom_minimum_size = Vector2(120, 52)
	add_child(_hand_p1)

	_hand_p2 = VBoxContainer.new()
	_hand_p2.name = "HandP2"
	_hand_p2.position = Vector2(465, -18)
	_hand_p2.custom_minimum_size = Vector2(120, 44)
	add_child(_hand_p2)

func _update_hand_display(player: int, pieces: Array) -> void:
	var panel: VBoxContainer = _hand_p1 if player == 1 else _hand_p2
	if panel == null:
		return
	for child in panel.get_children():
		child.queue_free()
	for piece_name in pieces:
		var lbl: Label = Label.new()
		lbl.text = tr(str(piece_name))  # nombre de pieza en idioma activo via tr()
		panel.add_child(lbl)

func _on_mode_selected(index: int) -> void:
	winner = -1
	selected_board_pos = null
	selected_hand_piece = ""
	valid_moves.clear()
	last_move_from = null
	last_move_to = null
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
	_request_board_redraw()

func _init_board_state() -> void:
	_ensure_board_containers()
	board.clear()
	piece_nodes.clear()
	
	for r in range(BOARD_SIZE):
		var row_arr = []
		var node_arr = []
		for col_idx in range(BOARD_SIZE):
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
		"Dragon", "PromotedRook": return "+R"
		"Horse", "PromotedBishop": return "+B"
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
	piece_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Pentagon points (traditional Koma wedge silhouette)
	var pts = PackedVector2Array()
	var sh_pts = PackedVector2Array()
	if player == P_SENTE: # Pointing UP
		pts.append(Vector2(w * 0.5, 2.0))
		pts.append(Vector2(w - 4.0, h * 0.28))
		pts.append(Vector2(w - 6.0, h - 3.0))
		pts.append(Vector2(6.0, h - 3.0))
		pts.append(Vector2(4.0, h * 0.28))
	else: # Pointing DOWN for Gote
		pts.append(Vector2(w * 0.5, h - 2.0))
		pts.append(Vector2(w - 4.0, h * 0.72))
		pts.append(Vector2(w - 6.0, 3.0))
		pts.append(Vector2(6.0, 3.0))
		pts.append(Vector2(4.0, h * 0.72))

	for pt in pts:
		sh_pts.append(pt + Vector2(1.5, 2.5))

	var shadow_poly = Polygon2D.new()
	shadow_poly.polygon = sh_pts
	shadow_poly.color = Color(0, 0, 0, 0.28)
	piece_ctrl.add_child(shadow_poly)

	var bg_poly = Polygon2D.new()
	bg_poly.polygon = pts
	bg_poly.color = COL_PIECE_BG
	piece_ctrl.add_child(bg_poly)

	var border_line = Line2D.new()
	border_line.width = 2.0
	border_line.default_color = COL_PIECE_BORDER
	for pt in pts:
		border_line.add_point(pt)
	border_line.add_point(pts[0])
	piece_ctrl.add_child(border_line)

	# Promoted pieces display traditional vermilion/red ink; standard pieces use deep sumi ink
	var is_prom = _is_promoted(kind)
	var primary_col: Color = Color(0.76, 0.10, 0.08) if is_prom else Color(0.08, 0.06, 0.04)
	var secondary_col: Color = Color(0.76, 0.10, 0.08, 0.88) if is_prom else Color(0.20, 0.15, 0.10, 0.88)

	# Primary glyph: Large Western letter (K, R, B, G, S, N, L, P, +R, +B, +S, +N, +L, +P)
	var abbr = Label.new()
	abbr.name = "WesternLabel"
	abbr.text = _get_western_abbr(kind)
	abbr.set_meta("shogi_piece_font_size", 22)
	abbr.add_theme_font_size_override("font_size", 22)
	abbr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abbr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	abbr.size = Vector2(w, 28.0)
	abbr.position = Vector2(0, 10.0 if player == P_SENTE else 20.0)
	abbr.add_theme_color_override("font_color", primary_col)
	abbr.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.92, 0.90))
	abbr.add_theme_constant_override("outline_size", 2)
	abbr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece_ctrl.add_child(abbr)

	# Secondary glyph: Small Kanji cleanly separated from the Western letter
	var kanji = Label.new()
	kanji.name = "KanjiLabel"
	kanji.text = KANJI_MAP.get(kind, "?")
	kanji.set_meta("shogi_piece_font_size", 12)
	kanji.add_theme_font_size_override("font_size", 12)
	kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kanji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kanji.size = Vector2(w, 18.0)
	kanji.position = Vector2(0, 38.0 if player == P_SENTE else 4.0)
	kanji.add_theme_color_override("font_color", secondary_col)
	kanji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece_ctrl.add_child(kanji)

	return piece_ctrl

func _place_piece_on_board(row: int, col: int, player: int, kind: String) -> void:
	_ensure_board_containers()
	board[row][col] = {"player": player, "kind": kind}
	
	var piece_ctrl = _create_pentagon_piece_node(player, kind)
	piece_ctrl.position = Vector2(BOARD_ORIGIN_X + col * CELL_SIZE + 3, BOARD_ORIGIN_Y + row * CELL_SIZE + 3)
	pieces_container.add_child(piece_ctrl)
	piece_nodes[row][col] = piece_ctrl

func _event_to_board_pos(event_pos: Vector2, is_mouse: bool = true) -> Vector2:
	if is_inside_tree() and not OS.has_feature("headless"):
		if is_mouse:
			return get_local_mouse_position()
		return make_canvas_position_local(event_pos)
	return event_pos

func _input(event: InputEvent) -> void:
	if winner != -1:
		return
	if promotion_dialog_panel != null and promotion_dialog_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1, KEY_Y:
				set_promotion_choice(true)
				return
			KEY_2, KEY_KP_2, KEY_N:
				set_promotion_choice(false)
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = _event_to_board_pos(event.position, true)
		_handle_unified_input(local_pos, event.pressed, not event.pressed)
	elif event is InputEventScreenTouch:
		var local_pos: Vector2 = _event_to_board_pos(event.position, false)
		_handle_unified_input(local_pos, event.pressed, not event.pressed)

func _handle_unified_input(pos: Vector2, is_press: bool, is_release: bool) -> void:
	var board_x = pos.x - BOARD_ORIGIN_X
	var board_y = pos.y - BOARD_ORIGIN_Y
	if board_x < 0.0 or board_x >= BOARD_SIZE * CELL_SIZE or board_y < 0.0 or board_y >= BOARD_SIZE * CELL_SIZE:
		return

	var col: int = int(board_x / CELL_SIZE)
	var row: int = int(board_y / CELL_SIZE)
	if row < 0 or row >= BOARD_SIZE or col < 0 or col >= BOARD_SIZE:
		return

	if is_press:
		_handle_board_click(row, col)
	elif is_release:
		# Support drag-and-drop: if a piece is already selected and user releases on a valid destination square
		if selected_board_pos != null and (selected_board_pos.x != row or selected_board_pos.y != col):
			var target_cell = board[row][col]
			if target_cell == null or target_cell.get("player") != current:
				_handle_board_click(row, col)

func _calculate_valid_shogi_moves(r: int, c: int) -> Array:
	var moves: Array = []
	var piece = board[r][c]
	if piece == null:
		return moves

	if bridge != null and bridge.has_method("get_legal_moves"):
		var legal = bridge.get_legal_moves(current)
		for m in legal:
			if m is Dictionary and m.has("from") and m.has("to"):
				var f = m["from"]
				var t = m["to"]
				if f is Array and f.size() >= 2 and t is Array and t.size() >= 2:
					# En Rust shogi_game, from/to son [col, row]
					if int(f[0]) == c and int(f[1]) == r:
						var dest: Vector2i = Vector2i(int(t[1]), int(t[0]))
						if not dest in moves:
							moves.append(dest)
		return moves

	var player = piece.get("player")
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var target_r = r + dr
			var target_c = c + dc
			if target_r >= 0 and target_r < BOARD_SIZE and target_c >= 0 and target_c < BOARD_SIZE:
				var target = board[target_r][target_c]
				if target == null or target.get("player") != player:
					moves.append(Vector2i(target_r, target_c))
	return moves

func _calculate_valid_drops() -> Array:
	var drops: Array = []
	if bridge != null and bridge.has_method("get_legal_moves") and selected_hand_piece != "":
		var legal = bridge.get_legal_moves(current)
		for m in legal:
			if m is Dictionary and m.has("piece") and m.has("to") and not m.has("from"):
				if str(m.get("piece", "")) == selected_hand_piece:
					var t = m["to"]
					if t is Array and t.size() >= 2:
						var dest: Vector2i = Vector2i(int(t[1]), int(t[0]))
						if not dest in drops:
							drops.append(dest)
		if not drops.is_empty():
			return drops

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
		var target_cell = board[row][col]
		if target_cell != null:
			if target_cell.get("player") == current:
				selected_hand_piece = ""
				selected_board_pos = Vector2i(row, col)
				valid_moves = _calculate_valid_shogi_moves(row, col)
				_update_status()
				_request_board_redraw()
			return

		var drop_kind = selected_hand_piece
		selected_hand_piece = ""
		valid_moves.clear()
		_update_status()
		_request_board_redraw()
		
		var cmd = {
			"command_type": "shogi_game::DropPieceCommand",
			"player": current,
			"piece": drop_kind,
			"to": [col, row]
		}
		if bridge != null:
			bridge.send_command_json(current, JSON.stringify(cmd))
		return
		
	# 2. Board selection & movement
	if selected_board_pos == null:
		var cell = board[row][col]
		if cell != null and cell.get("player") == current:
			selected_board_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_shogi_moves(row, col)
			_request_board_redraw()
	else:
		if selected_board_pos.x == row and selected_board_pos.y == col:
			selected_board_pos = null
			valid_moves.clear()
			_request_board_redraw()
			return

		var target_cell = board[row][col]
		if target_cell != null and target_cell.get("player") == current:
			selected_board_pos = Vector2i(row, col)
			valid_moves = _calculate_valid_shogi_moves(row, col)
			_request_board_redraw()
			return

		# If valid_moves is populated by the bridge, ignore clicks on squares that aren't legal destinations
		var dest_vec: Vector2i = Vector2i(row, col)
		if bridge != null and not valid_moves.is_empty() and not (dest_vec in valid_moves):
			return
			
		var from_pos = selected_board_pos
		selected_board_pos = null
		valid_moves.clear()
		_request_board_redraw()
		
		var moving_piece = board[from_pos.x][from_pos.y]
		var should_promote: bool = false
		if moving_piece != null:
			var p_kind: String = str(moving_piece.get("kind", ""))
			if _is_promotion_mandatory_fesa(p_kind, row, current):
				should_promote = true
			elif _can_piece_promote(p_kind, from_pos.x, row, current):
				if not OS.has_feature("headless") and promotion_dialog_panel != null:
					_pending_shogi_move = {
						"from_r": from_pos.x,
						"from_c": from_pos.y,
						"to_r": row,
						"to_c": col
					}
					promotion_dialog_panel.visible = true
					return
				should_promote = auto_promote_choice

		_dispatch_shogi_move(from_pos.x, from_pos.y, row, col, should_promote)

func set_promotion_choice(promote: bool) -> void:
	auto_promote_choice = promote
	if promotion_dialog_panel != null:
		promotion_dialog_panel.visible = false
	if not _pending_shogi_move.is_empty():
		var f_r: int = int(_pending_shogi_move.get("from_r", 0))
		var f_c: int = int(_pending_shogi_move.get("from_c", 0))
		var t_r: int = int(_pending_shogi_move.get("to_r", 0))
		var t_c: int = int(_pending_shogi_move.get("to_c", 0))
		_pending_shogi_move.clear()
		_dispatch_shogi_move(f_r, f_c, t_r, t_c, promote)

func _is_promotion_mandatory_fesa(kind: String, to_row: int, player: int) -> bool:
	if kind in ["Pawn", "Lance"]:
		return (player == P_SENTE and to_row == 0) or (player == P_GOTE and to_row == BOARD_SIZE - 1)
	if kind == "Knight":
		return (player == P_SENTE and to_row <= 1) or (player == P_GOTE and to_row >= BOARD_SIZE - 2)
	return false

func _can_piece_promote(kind: String, from_row: int, to_row: int, player: int) -> bool:
	if not (kind in ["Pawn", "Lance", "Knight", "Silver", "Bishop", "Rook"]):
		return false
	if player == P_SENTE:
		return from_row <= 2 or to_row <= 2
	return from_row >= 6 or to_row >= 6

func _dispatch_shogi_move(from_r: int, from_c: int, to_r: int, to_c: int, should_promote: bool) -> void:
	var cmd = {
		"command_type": "shogi_game::MovePieceCommand",
		"player": current,
		"from": [from_c, from_r],
		"to": [to_c, to_r],
		"promote": should_promote
	}
	if bridge != null:
		bridge.send_command_json(current, JSON.stringify(cmd))

func _update_hand_panels() -> void:
	if sente_hand_panel != null:
		for child in sente_hand_panel.get_children():
			child.queue_free()
		_populate_hand_container(sente_hand_panel, P_SENTE)
	if gote_hand_panel != null:
		for child in gote_hand_panel.get_children():
			child.queue_free()
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
			btn.custom_minimum_size = Vector2(96, 42)
			var abbr_symbol = _get_western_abbr(kind)
			var kanji_symbol = KANJI_MAP.get(kind, kind)
			btn.text = "%s (%s) x%d" % [abbr_symbol, kanji_symbol, count]
			btn.add_theme_font_size_override("font_size", 16)
			
			if player == current:
				btn.pressed.connect(func():
					selected_board_pos = null
					selected_hand_piece = kind
					valid_moves = _calculate_valid_drops()
					_update_status()
					_request_board_redraw()
				)
			panel.add_child(btn)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var raw_type: String = str(event.get("command_type", event.get("event_type", "")))
			var event_type: String = raw_type.split("::")[-1]
			if event_type == "PieceMovedEvent":
				var from = event.get("from", [0, 0])
				var to = event.get("to", [0, 0])
				# Coordenadas en shogi_game (Rust): [col, row]
				var from_c = int(from[0])
				var from_r = int(from[1])
				var to_c = int(to[0])
				var to_r = int(to[1])
				var promoted_flag: bool = event.get("promoted", false) == true
				last_move_from = Vector2i(from_r, from_c)
				last_move_to = Vector2i(to_r, to_c)
				
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
							"Bishop": piece_data["kind"] = "PromotedBishop"
							"Rook": piece_data["kind"] = "PromotedRook"

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
							var target_pos: Vector2 = Vector2(BOARD_ORIGIN_X + to_c * CELL_SIZE + 3, BOARD_ORIGIN_Y + to_r * CELL_SIZE + 3)
							if is_inside_tree() and not OS.has_feature("headless"):
								var tw: Tween = create_tween()
								tw.tween_property(node, "position", target_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
							else:
								node.position = target_pos

				if is_cap:
					_refresh_hand_displays_from_event_or_state(event)
						
			elif event_type == "PieceDroppedEvent":
				var to = event.get("to", [0, 0])
				var kind = str(event.get("piece", "Pawn"))
				var p = int(event.get("player", current))
				var to_c = int(to[0])
				var to_r = int(to[1])
				last_move_from = null
				last_move_to = Vector2i(to_r, to_c)
				
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
				
	if bridge != null:
		current = bridge.current_player()
	_update_hand_panels()
	_update_status()
	_request_board_redraw()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	if status != null:
		status.text = "Movimiento inválido: %s" % reason
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

func _draw() -> void:
	var board_px: float = BOARD_SIZE * CELL_SIZE
	var bg_col: Color = current_theme.board_color if current_theme != null else COL_BOARD
	var line_col: Color = current_theme.line_color if current_theme != null else COL_LINE

	# Outer wooden frame & warm Kaya Shogiban surface
	var outer_rect: Rect2 = Rect2(BOARD_ORIGIN_X - 8.0, BOARD_ORIGIN_Y - 8.0, board_px + 16.0, board_px + 16.0)
	draw_rect(outer_rect, COL_BOARD_FRAME, true)
	draw_rect(outer_rect, Color(0.16, 0.09, 0.04), false, 2.0)

	var b_rect: Rect2 = Rect2(BOARD_ORIGIN_X, BOARD_ORIGIN_Y, board_px, board_px)
	draw_rect(b_rect, bg_col, true)

	# Continuous 2.0px grid lines (never culled at scaled viewport resolutions)
	for i in range(BOARD_SIZE + 1):
		var offset: float = float(i) * CELL_SIZE
		var x = BOARD_ORIGIN_X + offset
		var y = BOARD_ORIGIN_Y + offset
		var w_line: float = 2.5 if (i == 0 or i == BOARD_SIZE) else 2.0
		draw_line(Vector2(x, BOARD_ORIGIN_Y), Vector2(x, BOARD_ORIGIN_Y + board_px), line_col, w_line)
		draw_line(Vector2(BOARD_ORIGIN_X, y), Vector2(BOARD_ORIGIN_X + board_px, y), line_col, w_line)

	# Traditional Hoshi promotion-zone star points
	for r_idx in [3, 6]:
		for c_idx in [3, 6]:
			draw_circle(Vector2(BOARD_ORIGIN_X + c_idx * CELL_SIZE, BOARD_ORIGIN_Y + r_idx * CELL_SIZE), 4.5, line_col)

	if board_overlay != null and is_instance_valid(board_overlay):
		board_overlay.queue_redraw()

func _draw_board_overlay() -> void:
	if board_overlay == null:
		return
	if last_move_from != null:
		var from_rect: Rect2 = Rect2(BOARD_ORIGIN_X + last_move_from.y * CELL_SIZE + 1.0, BOARD_ORIGIN_Y + last_move_from.x * CELL_SIZE + 1.0, CELL_SIZE - 2.0, CELL_SIZE - 2.0)
		board_overlay.draw_rect(from_rect, COL_LAST_MOVE, true)
	if last_move_to != null:
		var to_rect: Rect2 = Rect2(BOARD_ORIGIN_X + last_move_to.y * CELL_SIZE + 1.0, BOARD_ORIGIN_Y + last_move_to.x * CELL_SIZE + 1.0, CELL_SIZE - 2.0, CELL_SIZE - 2.0)
		board_overlay.draw_rect(to_rect, COL_LAST_MOVE, true)

	if selected_board_pos != null:
		var sel_rect: Rect2 = Rect2(BOARD_ORIGIN_X + selected_board_pos.y * CELL_SIZE + 1.0, BOARD_ORIGIN_Y + selected_board_pos.x * CELL_SIZE + 1.0, CELL_SIZE - 2.0, CELL_SIZE - 2.0)
		board_overlay.draw_rect(sel_rect, COL_SELECT, true)
		board_overlay.draw_rect(sel_rect, Color(1.0, 0.92, 0.35, 0.95), false, 2.5)

	for pos in valid_moves:
		var center: Vector2 = Vector2(BOARD_ORIGIN_X + pos.y * CELL_SIZE + CELL_SIZE * 0.5, BOARD_ORIGIN_Y + pos.x * CELL_SIZE + CELL_SIZE * 0.5)
		var target_cell = board[pos.x][pos.y] if (pos.x >= 0 and pos.x < board.size() and pos.y >= 0 and pos.y < board[pos.x].size()) else null
		if target_cell != null:
			# Capture target ring
			board_overlay.draw_arc(center, CELL_SIZE * 0.38, 0.0, TAU, 32, Color(0.92, 0.22, 0.18, 0.85), 3.5)
		else:
			board_overlay.draw_circle(center, CELL_SIZE * 0.22, COL_VALID_MOVE)
			board_overlay.draw_arc(center, CELL_SIZE * 0.22, 0.0, TAU, 24, Color(0.95, 1.0, 0.95, 0.80), 2.0)

func _update_status() -> void:
	if status == null:
		return
	if winner != -1:
		status.text = "¡Jaque mate! Ganó el jugador %s" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		var p_name = "Sente (P1)" if current == P_SENTE else "Gote (P2)"
		var col = ([Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE][posmod(int(current) - 1, 6)] as Color)
		var hand_sel_text = "Mano: %s" % selected_hand_piece if selected_hand_piece != "" else ""
		status.text = hand_sel_text
		if turn_indicator != null:
			turn_indicator.set_turn(current, p_name, col)
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
	var particles: CPUParticles2D = CPUParticles2D.new()
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

