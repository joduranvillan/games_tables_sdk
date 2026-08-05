extends Node2D

const P1 = 1
const P2 = 2
const TOTAL_SPACES = 16

# Property colors & names around the 16 perimeter spaces
const PROPERTY_INFO = [
	{"name": "SALIDA 🏁", "price": 0, "color": Color(0.9, 0.9, 0.9)},
	{"name": "Av. Mediterráneo", "price": 60, "color": Color(0.6, 0.3, 0.1)},
	{"name": "Caja de Comunidad", "price": 0, "color": Color(0.9, 0.8, 0.6)},
	{"name": "Av. Báltica", "price": 60, "color": Color(0.6, 0.3, 0.1)},
	{"name": "CÁRCEL 🔒", "price": 0, "color": Color(0.7, 0.7, 0.7)},
	{"name": "Av. Oriental", "price": 100, "color": Color(0.5, 0.8, 0.9)},
	{"name": "Compañía Electricidad", "price": 150, "color": Color(0.9, 0.9, 0.4)},
	{"name": "Av. Vermont", "price": 100, "color": Color(0.5, 0.8, 0.9)},
	{"name": "PARADA LIBRE 🅿️", "price": 0, "color": Color(0.9, 0.9, 0.9)},
	{"name": "Av. San Carlos", "price": 140, "color": Color(0.9, 0.5, 0.7)},
	{"name": "Ferrocarril", "price": 200, "color": Color(0.3, 0.3, 0.3)},
	{"name": "Av. Estados", "price": 140, "color": Color(0.9, 0.5, 0.7)},
	{"name": "IR A LA CÁRCEL 🚔", "price": 0, "color": Color(0.7, 0.2, 0.2)},
	{"name": "Av. Virginia", "price": 160, "color": Color(0.9, 0.6, 0.2)},
	{"name": "Compañía de Agua", "price": 150, "color": Color(0.4, 0.7, 0.9)},
	{"name": "Plaza San James", "price": 180, "color": Color(0.9, 0.6, 0.2)}
]

const PLAYER_COLORS = {
	1: Color(0.9, 0.2, 0.2), # Red
	2: Color(0.2, 0.4, 0.9)  # Blue
}

var bridge
var current = P1
var winner = -1

var positions = {P1: 0, P2: 0}
var money = {P1: 1500, P2: 1500}
var property_owners = {} # space_idx -> player_id

# UI components
var player_tokens = {P1: null, P2: null}
var roll_button: Button
var purchase_dialog: Panel
var purchase_label: Label
var money_label: Label

@onready var status: Label = $Status

func _ready() -> void:
	_setup_ui()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	bridge.start_local_match_monopoly(P1, P2)
	current = bridge.current_player()
	
	_update_token_positions()
	_update_money_display()
	_update_status()
	queue_redraw()

func _setup_ui() -> void:
	# Roll button
	roll_button = Button.new()
	roll_button.position = Vector2(250, 250)
	roll_button.custom_minimum_size = Vector2(160, 50)
	roll_button.text = "🎲 Tirar y Mover"
	roll_button.add_theme_font_size_override("font_size", 18)
	roll_button.pressed.connect(_on_roll_pressed)
	add_child(roll_button)
	
	# Money display panel
	money_label = Label.new()
	money_label.position = Vector2(200, 180)
	money_label.size = Vector2(260, 60)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 18)
	add_child(money_label)
	
	# Player tokens
	for p in [P1, P2]:
		var token = Control.new()
		token.size = Vector2(24, 24)
		token.pivot_offset = Vector2(12, 12)
		
		var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
		var p_col = PLAYER_COLORS[p]
		for x in range(24):
			for y in range(24):
				if Vector2(x - 12, y - 12).length() <= 10:
					img.set_pixel(x, y, p_col)
				elif Vector2(x - 12, y - 12).length() <= 11:
					img.set_pixel(x, y, Color.BLACK)
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					
		var tex = TextureRect.new()
		tex.texture = ImageTexture.create_from_image(img)
		tex.size = Vector2(24, 24)
		token.add_child(tex)
		
		add_child(token)
		player_tokens[p] = token
		
	# Purchase Dialog Overlay
	purchase_dialog = Panel.new()
	purchase_dialog.position = Vector2(180, 310)
	purchase_dialog.size = Vector2(300, 160)
	purchase_dialog.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.set_corner_radius_all(12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.8, 0.2)
	purchase_dialog.add_theme_stylebox_override("panel", style)
	
	purchase_label = Label.new()
	purchase_label.position = Vector2(10, 15)
	purchase_label.size = Vector2(280, 70)
	purchase_label.text = "¿Deseas comprar esta propiedad?"
	purchase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purchase_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	purchase_label.add_theme_font_size_override("font_size", 16)
	purchase_dialog.add_child(purchase_label)
	
	var buy_btn = Button.new()
	buy_btn.position = Vector2(20, 95)
	buy_btn.size = Vector2(120, 45)
	buy_btn.text = "Comprar"
	buy_btn.pressed.connect(func(): _send_buy_decision(true))
	purchase_dialog.add_child(buy_btn)
	
	var pass_btn = Button.new()
	pass_btn.position = Vector2(160, 95)
	pass_btn.size = Vector2(120, 45)
	pass_btn.text = "Pasar"
	pass_btn.pressed.connect(func(): _send_buy_decision(false))
	purchase_dialog.add_child(pass_btn)
	
	add_child(purchase_dialog)

func _get_space_position(space_idx: int) -> Vector2:
	# 16 spaces around a 5x5 board perimeter (110px step)
	# Space 0: Bottom-Left (60, 520)
	# Spaces 0..4: Bottom edge left-to-right
	# Spaces 4..8: Right edge bottom-to-top
	# Spaces 8..12: Top edge right-to-left
	# Spaces 12..15: Left edge top-to-bottom
	var origin_x = 60.0
	var origin_y = 520.0
	var step = 135.0
	
	var i = space_idx % 16
	if i <= 4:
		return Vector2(origin_x + i * step, origin_y)
	elif i <= 8:
		return Vector2(origin_x + 4 * step, origin_y - (i - 4) * step)
	elif i <= 12:
		return Vector2(origin_x + (12 - i) * step, origin_y - 4 * step)
	else:
		return Vector2(origin_x, origin_y - (16 - i) * step)

func _update_token_positions() -> void:
	for p in [P1, P2]:
		var pos_idx = positions[p]
		var base_pos = _get_space_position(pos_idx)
		var offset = Vector2(-12, -12) if p == P1 else Vector2(12, 12)
		player_tokens[p].position = base_pos + offset

func _animate_player_move(p: int, target_space: int) -> void:
	positions[p] = target_space
	var base_pos = _get_space_position(target_space)
	var offset = Vector2(-12, -12) if p == P1 else Vector2(12, 12)
	var target_pos = base_pos + offset
	
	var tween = create_tween()
	tween.tween_property(player_tokens[p], "position", target_pos, 0.3)
	tween.finished.connect(func(): _check_pending_purchase(p, target_space))

func _check_pending_purchase(p: int, space: int) -> void:
	var prop = PROPERTY_INFO[space]
	if prop["price"] > 0 and not property_owners.has(space):
		if p == current:
			purchase_label.text = "¿Comprar %s por $%d?" % [prop["name"], prop["price"]]
			purchase_dialog.visible = true

func _send_buy_decision(buy: bool) -> void:
	purchase_dialog.visible = false
	var cmd = {
		"command_type": "BuyPropertyCommand",
		"player": current,
		"buy": buy
	}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _on_roll_pressed() -> void:
	if winner != -1 or purchase_dialog.visible:
		return
	var cmd = {"command_type": "RollAndMoveCommand", "player": current}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _update_money_display() -> void:
	money_label.text = "💰 P1 (Rojo): $%d\n💰 P2 (Azul): $%d" % [money[P1], money[P2]]

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "PlayerMovedEvent":
				var p = int(event.get("player", current))
				var new_pos = int(event.get("new_position", 0))
				if event.get("passed_go", false):
					money[p] += 200
				_animate_player_move(p, new_pos)
			elif event_type == "PropertyPurchasedEvent":
				var p = int(event.get("player", current))
				var sp = int(event.get("space", 0))
				var pr = int(event.get("price", 0))
				property_owners[sp] = p
				money[p] -= pr
			elif event_type == "RentPaidEvent":
				var payer = int(event.get("payer", 0))
				var owner = int(event.get("owner", 0))
				var amt = int(event.get("amount", 0))
				if money.has(payer): money[payer] -= amt
				if money.has(owner): money[owner] += amt
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))
				
	current = bridge.current_player()
	_update_money_display()
	_update_status()
	queue_redraw()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason

func _draw() -> void:
	# Draw perimeter property boxes (16 spaces)
	for i in range(TOTAL_SPACES):
		var pos = _get_space_position(i)
		var box_rect = Rect2(pos.x - 45, pos.y - 45, 90, 90)
		var prop = PROPERTY_INFO[i]
		
		# Box background
		draw_rect(box_rect, Color(0.96, 0.96, 0.92))
		draw_rect(box_rect, Color.BLACK, false, 2.0)
		
		# Color banner
		if prop["price"] > 0:
			var banner_rect = Rect2(box_rect.position.x, box_rect.position.y, 90, 20)
			draw_rect(banner_rect, prop["color"])
			
		# Ownership indicator
		if property_owners.has(i):
			var owner_p = property_owners[i]
			var owner_color = PLAYER_COLORS.get(owner_p, Color.WHITE)
			draw_circle(pos + Vector2(25, -25), 8.0, owner_color)
			
		# Space Name & Price text
		var name_pos = Vector2(box_rect.position.x + 5, box_rect.position.y + 35)
		draw_string(ThemeDB.fallback_font, name_pos, prop["name"], HORIZONTAL_ALIGNMENT_LEFT, 80, 11, Color.BLACK)
		if prop["price"] > 0:
			var price_pos = Vector2(box_rect.position.x + 5, box_rect.position.y + 75)
			draw_string(ThemeDB.fallback_font, price_pos, "$%d" % prop["price"], HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.2, 0.5, 0.2))

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Bancarrota! Ganó el jugador %s (Monopoly)" % winner
	else:
		status.text = "Turno: Jugador %s (Monopoly)" % current
