extends Node2D

const P1 = 1
const P2 = 2

# Colors
const CARD_COLORS = {
	"Red": Color(0.9, 0.2, 0.2),
	"Yellow": Color(0.95, 0.85, 0.1),
	"Green": Color(0.2, 0.75, 0.2),
	"Blue": Color(0.2, 0.4, 0.9),
	"Wild": Color(0.3, 0.3, 0.35)
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
var discard_card_node: Panel
var discard_label: Label
var draw_pile_button: Button
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
	discard_card_node = Panel.new()
	discard_card_node.name = "DiscardPile"
	discard_card_node.custom_minimum_size = Vector2(120, 180)
	discard_card_node.size = Vector2(120, 180)
	discard_card_node.position = Vector2(250, 140)
	discard_card_node.pivot_offset = Vector2(60, 90)
	add_child(discard_card_node)
	
	discard_label = Label.new()
	discard_label.position = Vector2(0, 40)
	discard_label.size = Vector2(120, 100)
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discard_label.add_theme_font_size_override("font_size", 24)
	discard_card_node.add_child(discard_label)
	
	# Draw pile button & counter
	draw_pile_button = Button.new()
	draw_pile_button.position = Vector2(420, 170)
	draw_pile_button.custom_minimum_size = Vector2(140, 120)
	draw_pile_button.text = "Robar Carta\n(Pila: 50)"
	draw_pile_button.add_theme_font_size_override("font_size", 16)
	draw_pile_button.pressed.connect(_on_draw_pile_pressed)
	add_child(draw_pile_button)
	
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

func _update_ui() -> void:
	# Top card counts display
	var p1_count = player_hand.size() if current == P1 else opponent_card_count
	var p2_count = opponent_card_count if current == P1 else player_hand.size()
	top_info_label.text = "🎴  Jugador 1: %d cartas   |   Jugador 2: %d cartas" % [p1_count, p2_count]

	# Update Discard Pile
	_update_discard_display()
	
	# Update Draw Pile counter text
	draw_pile_button.text = "Robar Carta\n(Pila: %d)" % deck_count
	
	# Update Hand Buttons with Fan Layout
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
		
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(90, 140)
		btn.size = Vector2(90, 140)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.pivot_offset = Vector2(45, 140) # Fan pivot at bottom center
		
		# Angle spread between -15° and +15°
		var angle_deg = 0.0
		if n_cards > 1:
			angle_deg = lerp(-15.0, 15.0, float(i) / float(n_cards - 1))
		btn.rotation_degrees = angle_deg
		
		var resting_pos = Vector2(start_x + i * spread, 30.0 + abs(angle_deg) * 0.8)
		btn.position = resting_pos
		btn.set_meta("resting_y", resting_pos.y)

		# Create card texture
		var img = Image.create(90, 140, false, Image.FORMAT_RGBA8)
		var base_col = CARD_COLORS.get(c_color, Color(0.5, 0.5, 0.5))
		
		for x in range(90):
			for y in range(140):
				# Flashing golden border if playable, else crisp white border
				if is_playable and (x < 5 or x >= 85 or y < 5 or y >= 135):
					img.set_pixel(x, y, Color(1.0, 0.84, 0.0)) # Golden border
				elif x < 2 or x >= 88 or y < 2 or y >= 138:
					img.set_pixel(x, y, Color.WHITE)
				else:
					img.set_pixel(x, y, base_col)
					
		btn.texture_normal = ImageTexture.create_from_image(img)
		
		# Label on card
		var lbl = Label.new()
		lbl.text = "%s\n%s" % [c_color, c_value]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(90, 140)
		lbl.add_theme_font_size_override("font_size", 16)
		btn.add_child(lbl)
		
		# Flashing golden animation on playable cards
		if is_playable:
			var tw_pulse = btn.create_tween().set_loops()
			tw_pulse.tween_property(btn, "modulate", Color(1.3, 1.25, 0.6), 0.4)
			tw_pulse.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 0.4)

		# Hover elevation (+20px lift)
		btn.mouse_entered.connect(func():
			var tw = btn.create_tween().set_parallel(true)
			tw.tween_property(btn, "position:y", btn.get_meta("resting_y") - 25.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.15)
			btn.z_index = 10
		)
		btn.mouse_exited.connect(func():
			var tw = btn.create_tween().set_parallel(true)
			tw.tween_property(btn, "position:y", btn.get_meta("resting_y"), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
			btn.z_index = 0
		)

		var card_idx = i
		btn.pressed.connect(func(): _on_card_pressed(card_idx, btn))
		hand_container.add_child(btn)

func _update_discard_display() -> void:
	var top_card = discard_pile.back() if not discard_pile.is_empty() else {"color": "Red", "value": "1"}
	var top_col_name = top_card.get("color", "Red")
	var top_val = str(top_card.get("value", "1"))
	
	discard_label.text = "%s\n%s" % [top_col_name, top_val]
	var bg_col = CARD_COLORS.get(top_col_name, Color(0.5, 0.5, 0.5))
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_corner_radius_all(10)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color.WHITE
	discard_card_node.add_theme_stylebox_override("panel", style)

func _animate_card_to_discard(card_dict: Dictionary, start_global_pos: Vector2) -> void:
	# Create sliding temp panel to discard pile
	var anim_panel = Panel.new()
	anim_panel.size = Vector2(90, 140)
	anim_panel.position = start_global_pos
	anim_panel.pivot_offset = Vector2(45, 70)
	
	var bg_col = CARD_COLORS.get(card_dict.get("color", "Red"), Color(0.5, 0.5, 0.5))
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_corner_radius_all(8)
	style.border_color = Color.GOLD
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	anim_panel.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = "%s\n%s" % [card_dict.get("color", "Red"), str(card_dict.get("value", "0"))]
	lbl.size = Vector2(90, 140)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	anim_panel.add_child(lbl)

	add_child(anim_panel)
	
	var target_pos = discard_card_node.position + Vector2(15, 20)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(anim_panel, "position", target_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(anim_panel, "rotation_degrees", randf_range(-15.0, 15.0), 0.3)
	tween.chain().tween_callback(func():
		_update_discard_display()
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
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_move()
		_update_ui()

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
