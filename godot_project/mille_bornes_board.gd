extends Node2D

const P1 = 1
const P2 = 2

var bridge
var current = P1
var winner = -1

# Player state
var distance = {P1: 0, P2: 0}
var hazards = {P1: "Luz Verde (Siga)", P2: "Luz Verde (Siga)"}
var safeties = {P1: [], P2: []}
var hand_p1 = ["Distance 25", "Distance 50", "Distance 75", "Distance 100", "Luz Verde", "Gasolina"]

# UI Nodes
var hand_container: HBoxContainer
var local_tableau: Panel
var opponent_tableau: Panel
var draw_button: Button
var discard_mode: CheckBox
var selected_card_idx: int = -1

@onready var status: Label = $Status

func _ready() -> void:
	_setup_ui()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	bridge.start_local_match_mille_bornes(P1, P2)
	bridge.send_command_json(P1, JSON.stringify({"command_type": "SetupDeckCommand"}))
	current = bridge.current_player()
	
	_update_hand_ui()
	_update_tableaus()
	_update_status()

func _setup_ui() -> void:
	# Draw Button
	draw_button = Button.new()
	draw_button.position = Vector2(50, 480)
	draw_button.custom_minimum_size = Vector2(130, 45)
	draw_button.text = "🎴 Robar Carta"
	draw_button.add_theme_font_size_override("font_size", 16)
	draw_button.pressed.connect(_on_draw_pressed)
	add_child(draw_button)
	
	# Discard checkbox toggle
	discard_mode = CheckBox.new()
	discard_mode.position = Vector2(200, 485)
	discard_mode.text = "Modo Descarte 🗑️"
	add_child(discard_mode)
	
	# Hand Container (a)
	var hand_panel = Panel.new()
	hand_panel.position = Vector2(50, 530)
	hand_panel.size = Vector2(700, 110)
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	h_style.set_corner_radius_all(8)
	hand_panel.add_theme_stylebox_override("panel", h_style)
	add_child(hand_panel)
	
	hand_container = HBoxContainer.new()
	hand_container.position = Vector2(10, 10)
	hand_container.size = Vector2(680, 90)
	hand_container.add_theme_constant_override("separation", 10)
	hand_panel.add_child(hand_container)
	
	# Local Player Tableau (b) & Distance Stack (c)
	local_tableau = Panel.new()
	local_tableau.position = Vector2(50, 160)
	local_tableau.size = Vector2(400, 290)
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = Color(0.16, 0.22, 0.18, 0.95)
	tab_style.set_corner_radius_all(10)
	tab_style.border_width_left = 2
	tab_style.border_color = Color(0.2, 0.8, 0.4)
	local_tableau.add_theme_stylebox_override("panel", tab_style)
	add_child(local_tableau)
	
	# Opponent Tableau (Reduced mode) (d)
	opponent_tableau = Panel.new()
	opponent_tableau.position = Vector2(480, 160)
	opponent_tableau.size = Vector2(270, 290)
	var opp_style = StyleBoxFlat.new()
	opp_style.bg_color = Color(0.22, 0.16, 0.18, 0.95)
	opp_style.set_corner_radius_all(10)
	opp_style.border_width_left = 2
	opp_style.border_color = Color(0.8, 0.3, 0.3)
	opponent_tableau.add_theme_stylebox_override("panel", opp_style)
	add_child(opponent_tableau)

func _update_hand_ui() -> void:
	for child in hand_container.get_children():
		child.queue_free()
		
	for i in range(hand_p1.size()):
		var card_name = hand_p1[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(95, 80)
		btn.text = card_name
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.add_theme_font_size_override("font_size", 13)
		
		var idx = i
		btn.pressed.connect(func(): _on_card_pressed(idx))
		hand_container.add_child(btn)

func _on_card_pressed(idx: int) -> void:
	if winner != -1 or current != P1:
		return
		
	if discard_mode.button_pressed:
		var cmd = {
			"command_type": "DiscardCardCommand",
			"player": P1,
			"card_index": idx
		}
		bridge.send_command_json(P1, JSON.stringify(cmd))
		if idx < hand_p1.size():
			hand_p1.remove_at(idx)
		_update_hand_ui()
	else:
		var cmd = {
			"command_type": "PlayCardCommand",
			"player": P1,
			"card_index": idx
		}
		bridge.send_command_json(P1, JSON.stringify(cmd))
		if idx < hand_p1.size():
			var card = hand_p1[idx]
			if "Distance" in card:
				var dist_val = int(card.replace("Distance ", ""))
				distance[P1] += dist_val
			hand_p1.remove_at(idx)
		_update_hand_ui()
		_update_tableaus()

func _on_draw_pressed() -> void:
	if winner != -1:
		return
	var cmd = {"command_type": "DrawCardCommand", "player": current}
	bridge.send_command_json(current, JSON.stringify(cmd))

func _update_tableaus() -> void:
	# Clear children of tableaus
	for child in local_tableau.get_children(): child.queue_free()
	for child in opponent_tableau.get_children(): child.queue_free()
	
	# --- LOCAL TABLEAU ---
	var lbl_title = Label.new()
	lbl_title.position = Vector2(15, 12)
	lbl_title.text = "🚗 Mi Vehículo (Jugador 1)"
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	local_tableau.add_child(lbl_title)
	
	var lbl_dist = Label.new()
	lbl_dist.position = Vector2(15, 50)
	lbl_dist.text = "Millas Recorridas: %d / 1000 km" % distance[P1]
	lbl_dist.add_theme_font_size_override("font_size", 16)
	local_tableau.add_child(lbl_dist)
	
	# Progress Bar
	var pbar = ProgressBar.new()
	pbar.position = Vector2(15, 80)
	pbar.size = Vector2(360, 24)
	pbar.max_value = 1000
	pbar.value = distance[P1]
	local_tableau.add_child(pbar)
	
	var lbl_haz = Label.new()
	lbl_haz.position = Vector2(15, 120)
	lbl_haz.text = "Estado / Batalla: %s" % hazards[P1]
	lbl_haz.add_theme_font_size_override("font_size", 15)
	local_tableau.add_child(lbl_haz)
	
	var lbl_saf = Label.new()
	lbl_saf.position = Vector2(15, 160)
	lbl_saf.text = "Protecciones (Safeties): %s" % (", ".join(safeties[P1]) if safeties[P1].size() > 0 else "Ninguna")
	lbl_saf.add_theme_font_size_override("font_size", 14)
	lbl_saf.autowrap_mode = TextServer.AUTOWRAP_WORD
	local_tableau.add_child(lbl_saf)
	
	# --- OPPONENT TABLEAU (REDUCED MODE) ---
	var opp_title = Label.new()
	opp_title.position = Vector2(12, 12)
	opp_title.text = "🏎️ Oponente (Jugador 2)"
	opp_title.add_theme_font_size_override("font_size", 16)
	opp_title.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	opponent_tableau.add_child(opp_title)
	
	var opp_dist = Label.new()
	opp_dist.position = Vector2(12, 50)
	opp_dist.text = "Distancia: %d / 1000 km" % distance[P2]
	opp_dist.add_theme_font_size_override("font_size", 14)
	opponent_tableau.add_child(opp_dist)
	
	var opp_pbar = ProgressBar.new()
	opp_pbar.position = Vector2(12, 75)
	opp_pbar.size = Vector2(245, 18)
	opp_pbar.max_value = 1000
	opp_pbar.value = distance[P2]
	opponent_tableau.add_child(opp_pbar)
	
	var opp_haz = Label.new()
	opp_haz.position = Vector2(12, 110)
	opp_haz.text = "Estado: %s" % hazards[P2]
	opp_haz.add_theme_font_size_override("font_size", 13)
	opponent_tableau.add_child(opp_haz)
	
	var opp_saf = Label.new()
	opp_saf.position = Vector2(12, 150)
	opp_saf.text = "Safeties: %s" % (", ".join(safeties[P2]) if safeties[P2].size() > 0 else "Ninguna")
	opp_saf.add_theme_font_size_override("font_size", 13)
	opponent_tableau.add_child(opp_saf)

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var event = parser.data
		if event is Dictionary:
			var event_type = event.get("command_type", event.get("event_type", ""))
			if event_type == "CardDrawnEvent":
				var card = event.get("card", "Carta")
				if event.get("player", current) == P1:
					hand_p1.append(str(card))
					_update_hand_ui()
			elif event_type == "DistancePlayedEvent":
				var p = int(event.get("player", current))
				var new_d = int(event.get("new_distance", 0))
				distance[p] = new_d
				_update_tableaus()
			elif event_type == "HazardPlayedEvent":
				var target = int(event.get("target", P2))
				var hz = str(event.get("hazard", "Peligro"))
				hazards[target] = hz
				_update_tableaus()
			elif event_type == "RemedyPlayedEvent":
				var p = int(event.get("player", current))
				hazards[p] = "Luz Verde (Siga)"
				_update_tableaus()
			elif event_type == "SafetyPlayedEvent":
				var p = int(event.get("player", current))
				var sf = str(event.get("safety", "Protección"))
				safeties[p].append(sf)
				_update_tableaus()
			elif event_type == "GameOverEvent":
				var w = event.get("winner", -1)
				if w == null: w = 0
				_on_game_over(int(w))
				
	current = bridge.current_player()
	_update_status()

func _on_game_over(w: int) -> void:
	winner = w
	_update_status()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(w)

func _on_move_rejected(reason: String) -> void:
	status.text = "Movimiento inválido: %s" % reason

func _update_status() -> void:
	if winner != -1:
		status.text = "¡Alcanzó 1000 Millas! Ganó el jugador %s (Mille Bornes)" % winner
	else:
		status.text = "Turno: Jugador %s (Mil Millas / Mille Bornes)" % current
