extends Node2D

const P1 = 1
const P2 = 2

# Colors
const CARD_COLORS = {
	"Red": Color("#FF0000"),
	"Blue": Color("#0000FF"),
	"Green": Color("#00AA00"),
	"Yellow": Color("#FFCC00"),
	"Wild": Color("#33333E")
}

var bridge
var current = P1
var winner = -1

var discard_pile: Array = [] # Top card on discard
var player_hand: Array = []  # Array of card Dictionaries {"color": "Red", "value": "7"}
var opponent_card_count: int = 7
var deck_count: int = 50
var active_color: String = "Red"

var hand_container: Control
var discard_card_node: PanelContainer
var discard_label: Label
var active_color_indicator: ColorRect
var draw_pile_button: Button
var deck_button: Button
var top_info_label: Label

var turn_indicator: TurnIndicator
var network_hud: NetworkStatusHUD

@onready var status: Label = $Status

func _ready() -> void:
	_setup_ui()
	_init_default_game_state()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	if network_hud != null:
		network_hud.bind_bridge(bridge)
	
	bridge.start_local_match_uno(P1, P2)
	current = bridge.current_player()
	
	_update_ui()
	_update_status()

func _setup_ui() -> void:
	# Top info bar for player card counts
	top_info_label = Label.new()
	top_info_label.name = "TopInfoLabel"
	top_info_label.position = Vector2(50, 20)
	top_info_label.size = Vector2(700, 40)
	top_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_info_label.add_theme_font_size_override("font_size", 18)
	top_info_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	add_child(top_info_label)

	# Discard pile visual
	discard_card_node = PanelContainer.new()
	discard_card_node.name = "DiscardPile"
	discard_card_node.custom_minimum_size = Vector2(120, 180)
	discard_card_node.size = Vector2(120, 180)
	discard_card_node.position = Vector2(250, 140)
	discard_card_node.pivot_offset = Vector2(60, 90)
	add_child(discard_card_node)
	
	discard_label = Label.new()
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discard_label.add_theme_font_size_override("font_size", 24)
	discard_label.add_theme_color_override("font_color", Color.WHITE)
	discard_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	discard_card_node.add_child(discard_label)

	# Active Color Indicator (24x24 px ColorRect in top-right of discard area)
	active_color_indicator = ColorRect.new()
	active_color_indicator.name = "ActiveColorIndicator"
	active_color_indicator.custom_minimum_size = Vector2(24, 24)
	active_color_indicator.size = Vector2(24, 24)
	active_color_indicator.position = Vector2(discard_card_node.position.x + discard_card_node.size.x - 28, discard_card_node.position.y + 6)
	active_color_indicator.color = CARD_COLORS.get("Red", Color("#FF0000"))
	add_child(active_color_indicator)
	
	# Draw pile button & counter
	draw_pile_button = Button.new()
	draw_pile_button.name = "DrawPileButton"
	draw_pile_button.position = Vector2(420, 170)
	draw_pile_button.custom_minimum_size = Vector2(140, 120)
	draw_pile_button.text = "Robar Carta\n(Pila: 50)"
	draw_pile_button.add_theme_font_size_override("font_size", 16)
	draw_pile_button.pressed.connect(_on_draw_pile_pressed)
	add_child(draw_pile_button)
	deck_button = draw_pile_button
	
	# Fan layout container for hand
	hand_container = Control.new()
	hand_container.name = "HandContainer"
	hand_container.position = Vector2(50, 420)
	hand_container.custom_minimum_size = Vector2(700, 220)
	add_child(hand_container)

	# Turn Indicator Widget
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(50, 80)
	add_child(turn_indicator)

	# Network Status HUD
	network_hud = NetworkStatusHUD.new()
	network_hud.name = "NetworkStatusHUD"
	add_child(network_hud)

func _init_default_game_state() -> void:
	player_hand = [
		{"color": "Red", "value": "5"},
		{"color": "Blue", "value": "5"},
		{"color": "Green", "value": "Skip"},
		{"color": "Yellow", "value": "9"},
		{"color": "Wild", "value": "Wild"},
		{"color": "Red", "value": "Reverse"}
	]
	discard_pile = [{"color": "Red", "value": "5"}]
	active_color = "Red"
	deck_count = 50
	opponent_card_count = 6

func _update_active_color_indicator() -> void:
	if active_color_indicator != null:
		active_color_indicator.color = CARD_COLORS.get(active_color, Color("#FF0000"))

func _update_ui(animate_drawn_index: int = -1) -> void:
	# Top card counts display
	var p1_count = player_hand.size() if current == P1 else opponent_card_count
	var p2_count = opponent_card_count if current == P1 else player_hand.size()
	top_info_label.text = "🎴  Jugador 1: %d cartas   |   Jugador 2: %d cartas" % [p1_count, p2_count]

	# Update Discard Pile & Active color
	_update_discard_display()
	_update_active_color_indicator()
	
	# Update Draw Pile counter text
	draw_pile_button.text = "Robar Carta\n(Pila: %d)" % deck_count
	
	# Update Hand Buttons with Fan Layout & PanelContainer
	for child in hand_container.get_children():
		child.queue_free()
		
	var n_cards = player_hand.size()
	if n_cards == 0:
		return

	var center_x = 350.0
	var card_width = 90.0
	var spread = min(60.0, 600.0 / max(1, n_cards))
	var start_x = center_x - ((n_cards - 1) * spread) / 2.0 - card_width / 2.0

	var top_card = discard_pile.back() if not discard_pile.is_empty() else {"color": "Red", "value": "1"}
	var top_val = str(top_card.get("value", "1"))

	for i in range(n_cards):
		var card = player_hand[i]
		var c_color = card.get("color", "Red")
		var c_value = str(card.get("value", "0"))
		
		var is_playable = (c_color == active_color) or (c_value == top_val) or (c_color == "Wild")
		
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(90, 140)
		panel.size = Vector2(90, 140)
		panel.pivot_offset = Vector2(45, 140) # Fan pivot at bottom center
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

		# StyleBoxFlat with corner_radius_*_px = 8 and border_width = 2
		var style = StyleBoxFlat.new()
		var base_col = CARD_COLORS.get(c_color, Color("#33333E"))
		style.bg_color = base_col
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		if is_playable:
			style.border_color = Color(1.0, 0.85, 0.1) # Golden border if playable
		else:
			style.border_color = Color(1.0, 1.0, 1.0, 0.8) # Crisp white border
		panel.add_theme_stylebox_override("panel", style)

		# Label with white centered text
		var lbl = Label.new()
		lbl.text = "%s\n%s" % [c_color, c_value]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(lbl)

		# Angle spread between -15° and +15°
		var angle_deg = 0.0
		if n_cards > 1:
			angle_deg = lerp(-15.0, 15.0, float(i) / float(n_cards - 1))
		panel.rotation_degrees = angle_deg
		
		var resting_pos = Vector2(start_x + i * spread, 30.0 + abs(angle_deg) * 0.8)
		panel.position = resting_pos
		panel.set_meta("resting_y", resting_pos.y)

		# Flashing golden animation on playable cards
		if is_playable:
			var tw_pulse = panel.create_tween().set_loops()
			tw_pulse.tween_property(panel, "modulate", Color(1.25, 1.25, 0.7), 0.4)
			tw_pulse.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.4)

		# Hover elevation (+25px lift)
		panel.mouse_entered.connect(func():
			var tw = panel.create_tween().set_parallel(true)
			tw.tween_property(panel, "position:y", panel.get_meta("resting_y") - 25.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.15)
			panel.z_index = 10
		)
		panel.mouse_exited.connect(func():
			var tw = panel.create_tween().set_parallel(true)
			tw.tween_property(panel, "position:y", panel.get_meta("resting_y"), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15)
			panel.z_index = 0
		)

		var card_idx = i
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_pressed(card_idx, panel)
		)

		hand_container.add_child(panel)

		# Animación de robo: entra desde el mazo (deck_button.global_position) hasta su posición final con Tween de 0.3 s
		if i == animate_drawn_index and deck_button != null:
			var deck_global = deck_button.global_position
			var start_local = hand_container.to_local(deck_global)
			panel.position = start_local
			panel.scale = Vector2(0.6, 0.6)
			var tw_draw = panel.create_tween().set_parallel(true)
			tw_draw.tween_property(panel, "position", resting_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_draw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_discard_display() -> void:
	var top_card = discard_pile.back() if not discard_pile.is_empty() else {"color": "Red", "value": "1"}
	var top_col_name = top_card.get("color", "Red")
	var top_val = str(top_card.get("value", "1"))
	
	discard_label.text = "%s\n%s" % [top_col_name, top_val]
	var bg_col = CARD_COLORS.get(top_col_name, Color("#33333E"))
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	discard_card_node.add_theme_stylebox_override("panel", style)

func _animate_card_to_discard(card_dict: Dictionary, start_global_pos: Vector2) -> void:
	# Create sliding temp panel to discard pile
	var anim_panel = PanelContainer.new()
	anim_panel.size = Vector2(90, 140)
	anim_panel.position = start_global_pos
	anim_panel.pivot_offset = Vector2(45, 70)
	
	var bg_col = CARD_COLORS.get(card_dict.get("color", "Red"), Color("#33333E"))
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color.GOLD
	anim_panel.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = "%s\n%s" % [card_dict.get("color", "Red"), str(card_dict.get("value", "0"))]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	anim_panel.add_child(lbl)

	add_child(anim_panel)
	
	var target_pos = discard_card_node.position + Vector2(15, 20)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(anim_panel, "position", target_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(anim_panel, "rotation_degrees", randf_range(-15.0, 15.0), 0.3)
	tween.chain().tween_callback(func():
		_update_discard_display()
		_update_active_color_indicator()
		anim_panel.queue_free()
	)

func _on_card_pressed(idx: int, card_btn: Control) -> void:
	if winner != -1:
		return
		
	var cmd = {
		"command_type": "PlayCardCommand",
		"player": current,
		"card_index": idx,
		"chosen_color": "Red"
	}
	bridge.send_command_json(current, JSON.stringify(cmd))
	
	if idx >= 0 and idx < player_hand.size():
		var played_card = player_hand[idx]
		var btn_global_pos = card_btn.global_position
		player_hand.remove_at(idx)
		discard_pile.append(played_card)
		active_color = played_card.get("color", active_color)
		
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_move()

		_animate_card_to_discard(played_card, btn_global_pos)
		_update_ui()

func _on_draw_pile_pressed() -> void:
	if winner != -1:
		return
		
	var cmd = {
		"command_type": "DrawCardCommand",
		"player": current
	}
	bridge.send_command_json(current, JSON.stringify(cmd))
	
	if deck_count > 0:
		deck_count -= 1
		player_hand.append({"color": "Yellow", "value": "7"})
		var drawn_idx = player_hand.size() - 1
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_move()
		_update_ui(drawn_idx)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "CardPlayedEvent":
				if event.has("card"):
					var c = event["card"]
					discard_pile.append(c)
					_animate_card_to_discard(c, Vector2(350, 50))
				if event.has("new_color"):
					active_color = str(event["new_color"])
				_update_active_color_indicator()
			elif event_type == "ColorChangedEvent":
				if event.has("color"):
					active_color = str(event["color"])
				elif event.has("new_color"):
					active_color = str(event["new_color"])
				_update_active_color_indicator()
			elif event_type == "CardsDrawnEvent":
				var cnt = int(event.get("count", 1))
				deck_count = max(0, deck_count - cnt)
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))
				
	current = bridge.current_player()
	_update_ui()
	_update_status()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_game_over()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_invalid()

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Ganó el jugador %s!" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
	else:
		var name = "Jugador %s" % current
		var col = GameManager.get_player_color(current)
		status.text = "Turno: Jugador %s (UNO)" % current
		if turn_indicator != null:
			turn_indicator.set_turn(current, name, col)
