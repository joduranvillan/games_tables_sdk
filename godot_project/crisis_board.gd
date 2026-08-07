extends Node2D

const TERRITORY_NAMES: Array[String] = [
	"Argentina", "Brasil", "Chile", "Colombia", "Perú",
	"México", "California", "Nueva York", "Oregón", "Alaska", "Yukon", "Labrador",
	"España", "Francia", "Gran Bretaña", "Italia", "Alemania", "Suecia", "Rusia",
	"Sahara", "Egipto", "Etiopía", "Sudáfrica",
	"China", "India", "Japón", "Kamchatka", "Siberia", "Taimir",
	"Australia"
]

const PLAYER_COLORS: Dictionary = {
	1: Color(0.8, 0.2, 0.2),
	2: Color(0.2, 0.4, 0.8),
	3: Color(0.2, 0.8, 0.2),
	4: Color(0.9, 0.8, 0.2),
	5: Color(0.8, 0.4, 0.9),
	6: Color(0.9, 0.5, 0.2)
}

var bridge
var current_player_id: int = 1
var current_phase: String = "Placement"
var winner: int = -1

var territory_owners: Dictionary = {}
var territory_armies: Dictionary = {}
var territory_labels: Dictionary = {}

@onready var status_label: Label = $Status if has_node("Status") else null
var map_panel: Panel
var sidebar_panel: Panel
var dice_popup: PopupPanel
var dice_label: Label
var dice_widget: DiceWidget
var rules_popup: RulesPopup

var btn_place: Button
var btn_attack: Button
var btn_fortify: Button
var btn_end_phase: Button
var btn_exchange: Button

var player_stats_label: Label

func _ready() -> void:
	_setup_ui()
	
	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	
	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)
	
	if bridge.has_signal("territory_conquered"):
		bridge.connect("territory_conquered", _on_territory_conquered)
	if bridge.has_signal("attack_resolved"):
		bridge.connect("attack_resolved", _on_attack_resolved)
	if bridge.has_signal("armies_placed"):
		bridge.connect("armies_placed", _on_armies_placed)
	if bridge.has_signal("player_eliminated"):
		bridge.connect("player_eliminated", _on_player_eliminated)
	if bridge.has_signal("phase_changed"):
		bridge.connect("phase_changed", _on_phase_changed)
	if bridge.has_signal("cards_exchanged"):
		bridge.connect("cards_exchanged", _on_cards_exchanged)
	if bridge.has_signal("crisis_game_over"):
		bridge.connect("crisis_game_over", _on_crisis_game_over)
		
	bridge.start_local_match_crisis(42, [1, 2])
	current_player_id = bridge.current_player()
	
	_update_ui_state()

func _setup_ui() -> void:
	map_panel = Panel.new()
	map_panel.position = Vector2(20, 20)
	map_panel.custom_minimum_size = Vector2(750, 680)
	add_child(map_panel)
	
	if FileAccess.file_exists("res://assets/crisis/world_map.svg"):
		var map_tex = load("res://assets/crisis/world_map.svg")
		if map_tex:
			var bg_rect = TextureRect.new()
			bg_rect.texture = map_tex
			bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
			bg_rect.custom_minimum_size = Vector2(750, 680)
			map_panel.add_child(bg_rect)
	
	for i in range(30):
		var row: int = int(float(i) / 5.0)
		var col: int = i % 5
		var pos_x: float = 20.0 + col * 144.0
		var pos_y: float = 20.0 + row * 105.0
		
		var lbl = Label.new()
		lbl.name = "Territory_" + str(i)
		lbl.position = Vector2(pos_x, pos_y)
		lbl.text = "%s\n[Sin dueño: 0]" % TERRITORY_NAMES[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(135, 95)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.25, 0.25, 0.9)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		lbl.add_theme_stylebox_override("normal", style)
		
		map_panel.add_child(lbl)
		territory_labels[i] = lbl

	sidebar_panel = Panel.new()
	sidebar_panel.position = Vector2(790, 20)
	sidebar_panel.custom_minimum_size = Vector2(350, 680)
	add_child(sidebar_panel)
	
	var sidebar_title = Label.new()
	sidebar_title.text = "CRISIS - TEG"
	sidebar_title.position = Vector2(15, 15)
	sidebar_title.add_theme_font_size_override("font_size", 22)
	sidebar_panel.add_child(sidebar_title)
	
	var turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(15, 50)
	sidebar_panel.add_child(turn_indicator)

	player_stats_label = Label.new()
	player_stats_label.position = Vector2(15, 100)
	player_stats_label.custom_minimum_size = Vector2(320, 140)
	sidebar_panel.add_child(player_stats_label)

	var btn_y: float = 250.0
	
	btn_place = Button.new()
	btn_place.text = "Colocar 1 ejército"
	btn_place.position = Vector2(15, btn_y)
	btn_place.custom_minimum_size = Vector2(320, 40)
	btn_place.pressed.connect(_on_btn_place_pressed)
	sidebar_panel.add_child(btn_place)
	btn_y += 50.0
	
	btn_attack = Button.new()
	btn_attack.text = "Atacar"
	btn_attack.position = Vector2(15, btn_y)
	btn_attack.custom_minimum_size = Vector2(320, 40)
	btn_attack.pressed.connect(_on_btn_attack_pressed)
	sidebar_panel.add_child(btn_attack)
	btn_y += 50.0
	
	btn_fortify = Button.new()
	btn_fortify.text = "Fortificar"
	btn_fortify.position = Vector2(15, btn_y)
	btn_fortify.custom_minimum_size = Vector2(320, 40)
	btn_fortify.pressed.connect(_on_btn_fortify_pressed)
	sidebar_panel.add_child(btn_fortify)
	btn_y += 50.0

	btn_end_phase = Button.new()
	btn_end_phase.text = "Fin de Fase"
	btn_end_phase.position = Vector2(15, btn_y)
	btn_end_phase.custom_minimum_size = Vector2(320, 40)
	btn_end_phase.pressed.connect(_on_btn_end_phase_pressed)
	sidebar_panel.add_child(btn_end_phase)
	btn_y += 50.0

	btn_exchange = Button.new()
	btn_exchange.text = "Canjear Tarjetas"
	btn_exchange.position = Vector2(15, btn_y)
	btn_exchange.custom_minimum_size = Vector2(320, 40)
	btn_exchange.pressed.connect(_on_btn_exchange_pressed)
	sidebar_panel.add_child(btn_exchange)
	
	dice_popup = PopupPanel.new()
	dice_popup.title = "Resultado del Ataque"
	dice_popup.size = Vector2i(320, 200)
	dice_popup.position = Vector2i(400, 300)
	add_child(dice_popup)
	
	var dice_vbox = VBoxContainer.new()
	dice_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_popup.add_child(dice_vbox)

	dice_label = Label.new()
	dice_label.custom_minimum_size = Vector2(280, 80)
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_vbox.add_child(dice_label)

	dice_widget = DiceWidget.new()
	dice_vbox.add_child(dice_widget)

	# Rules Button
	var btn_rules = Button.new()
	btn_rules.text = "📖 Reglas (?)"
	btn_rules.position = Vector2(15, btn_y)
	btn_rules.custom_minimum_size = Vector2(320, 40)
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("teg"))
	sidebar_panel.add_child(btn_rules)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(100, 80)
	add_child(rules_popup)

func _update_ui_state() -> void:
	current_player_id = bridge.current_player()
	
	var is_active = (winner == -1)
	btn_place.disabled = not (is_active and current_phase == "Placement")
	btn_attack.disabled = not (is_active and current_phase == "Attack")
	btn_fortify.disabled = not (is_active and current_phase == "Fortify")
	btn_end_phase.disabled = not is_active
	btn_exchange.disabled = not (is_active and current_phase == "Placement")
	
	var p1_count: int = 0
	var p2_count: int = 0
	for t_id in territory_owners:
		if territory_owners[t_id] == 1:
			p1_count += 1
		elif territory_owners[t_id] == 2:
			p2_count += 1
			
	player_stats_label.text = "Turno Actual: Jugador %d\nFase: %s\n\n- Jugador 1: %d terr.\n- Jugador 2: %d terr." % [
		current_player_id, current_phase, p1_count, p2_count
	]
	
	if status_label:
		if winner != -1:
			status_label.text = "¡Juego Terminado! Ganador: Jugador %d" % winner
		else:
			status_label.text = "Turno Jugador %d - Fase %s" % [current_player_id, current_phase]

func _update_territory_label(t_id: int) -> void:
	if not territory_labels.has(t_id):
		return
	var lbl: Label = territory_labels[t_id]
	var t_owner: int = territory_owners.get(t_id, 0)
	var armies: int = territory_armies.get(t_id, 0)
	
	lbl.text = "%s\n[P%d: %d]" % [TERRITORY_NAMES[t_id], t_owner, armies]
	
	var color = PLAYER_COLORS.get(t_owner, Color(0.25, 0.25, 0.25))
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	lbl.add_theme_stylebox_override("normal", style)

func _on_territory_conquered(player_id: int, territory_id: int, _from_armies: int, to_armies: int) -> void:
	territory_owners[territory_id] = player_id
	territory_armies[territory_id] = to_armies
	_update_territory_label(territory_id)
	_update_ui_state()

func _on_attack_resolved(from_id: int, to_id: int, attacker_rolls: Array, defender_rolls: Array, attacker_losses: int, defender_losses: int) -> void:
	var att_str = ", ".join(attacker_rolls.map(func(r): return "🎲" + str(r)))
	var def_str = ", ".join(defender_rolls.map(func(r): return "🎲" + str(r)))
	
	dice_label.text = "Ataque: %s -> %s\nAtacante: [%s] (-%d)\nDefensor: [%s] (-%d)" % [
		TERRITORY_NAMES[from_id], TERRITORY_NAMES[to_id], att_str, attacker_losses, def_str, defender_losses
	]
	if dice_widget != null and attacker_rolls.size() > 0:
		dice_widget.show_roll(attacker_rolls)
	dice_popup.popup_centered()
	_update_ui_state()

func _on_armies_placed(player_id: int, territory_id: int, count: int, _remaining: int) -> void:
	territory_owners[territory_id] = player_id
	territory_armies[territory_id] = territory_armies.get(territory_id, 0) + count
	_update_territory_label(territory_id)
	_update_ui_state()

func _on_player_eliminated(player_id: int, by_player_id: int) -> void:
	print("Jugador %d fue eliminado por Jugador %d" % [player_id, by_player_id])
	_update_ui_state()

func _on_phase_changed(_player_id: int, new_phase: String) -> void:
	current_phase = new_phase
	_update_ui_state()

func _on_cards_exchanged(player_id: int, armies_gained: int) -> void:
	print("Jugador %d canjeó tarjetas por %d ejércitos" % [player_id, armies_gained])
	_update_ui_state()

func _on_crisis_game_over(winner_id: int, _objective: String) -> void:
	winner = winner_id
	_update_ui_state()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(winner_id)

func _on_game_over(w: int) -> void:
	winner = w
	_update_ui_state()

func _on_move_rejected(reason: String) -> void:
	if status_label:
		status_label.text = "Movimiento inválido: %s" % reason

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var evt = parser.data
		if evt is Dictionary and evt.has("command_type"):
			if evt["command_type"] == "PhaseChangedEvent":
				current_phase = evt.get("new_phase", current_phase)
	_update_ui_state()

func _on_btn_place_pressed() -> void:
	var my_t = -1
	for t in territory_owners:
		if territory_owners[t] == current_player_id:
			my_t = t
			break
	if my_t != -1:
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "PlaceArmiesCommand",
			"player": current_player_id,
			"territory": my_t,
			"count": 1
		}))

func _on_btn_attack_pressed() -> void:
	bridge.send_command_json(current_player_id, JSON.stringify({
		"command_type": "RollAttackCommand",
		"player": current_player_id
	}))

func _on_btn_fortify_pressed() -> void:
	pass

func _on_btn_end_phase_pressed() -> void:
	bridge.send_command_json(current_player_id, JSON.stringify({
		"command_type": "EndPhaseCommand",
		"player": current_player_id
	}))

func _on_btn_exchange_pressed() -> void:
	bridge.send_command_json(current_player_id, JSON.stringify({
		"command_type": "ExchangeCardsCommand",
		"player": current_player_id,
		"cards": []
	}))
