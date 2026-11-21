# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## Tutorial interactivo guiado para TEG / Crisis en Godot.
## Muestra burbujas de diálogo y flechas animadas en un CanvasLayer
## guíando al usuario a través de los conceptos básicos del juego.
extends Node2D

const STEPS: Array[Dictionary] = [
	{
		"step": 1,
		"text": "1. Haz click en un territorio tuyo para ver tus ejércitos",
		"target_pos": Vector2(100, 100),
		"hint": "Haz click en el territorio de Argentina o en tu lista de territorios."
	},
	{
		"step": 2,
		"text": "2. Coloca 3 ejércitos en Argentina",
		"target_pos": Vector2(950, 270),
		"hint": "Haz click en 'Colocar 1 ejército' 3 veces."
	},
	{
		"step": 3,
		"text": "3. Declara un ataque sobre Chile",
		"target_pos": Vector2(950, 320),
		"hint": "Haz click en el botón 'Atacar' para seleccionar objetivo."
	},
	{
		"step": 4,
		"text": "4. Tira los dados",
		"target_pos": Vector2(500, 350),
		"hint": "Observa el resultado de la tirada de dados en el panel."
	},
	{
		"step": 5,
		"text": "5. Fin de fase",
		"target_pos": Vector2(950, 420),
		"hint": "Haz click en 'Fin de Fase' para pasar al siguiente turno."
	}
]

var current_step_idx: int = 0
var placed_armies_count: int = 0

var board_node: Node2D
var canvas_layer: CanvasLayer
var dialogue_panel: Panel
var dialogue_title: Label
var dialogue_label: Label
var step_counter_label: Label
var btn_next: Button
var btn_skip: Button

var arrow_control: Control
var arrow_label: Label
var arrow_tween: Tween

func _ready() -> void:
	_setup_board()
	_setup_tutorial_ui()
	_show_step(0)

func _setup_board() -> void:
	var board_scene = load("res://crisis_board.tscn")
	if board_scene:
		board_node = board_scene.instantiate()
		add_child(board_node)

		# Escuchar señales del bridge si está disponible
		var bridge = board_node.get_node_or_null("Bridge")
		if bridge:
			if bridge.has_signal("armies_placed"):
				bridge.connect("armies_placed", _on_armies_placed)
			if bridge.has_signal("attack_resolved"):
				bridge.connect("attack_resolved", _on_attack_resolved)
			if bridge.has_signal("phase_changed"):
				bridge.connect("phase_changed", _on_phase_changed)

func _setup_tutorial_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TutorialOverlay"
	canvas_layer.layer = 10
	add_child(canvas_layer)

	# Panel de diálogo (Burbuja guiada)
	dialogue_panel = Panel.new()
	dialogue_panel.name = "DialogueBubble"
	dialogue_panel.position = Vector2(20, 520)
	dialogue_panel.custom_minimum_size = Vector2(750, 150)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	style.border_color = Color(0.9, 0.75, 0.2)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	dialogue_panel.add_theme_stylebox_override("normal", style)
	canvas_layer.add_child(dialogue_panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(16, 12)
	vbox.custom_minimum_size = Vector2(718, 126)
	dialogue_panel.add_child(vbox)

	var hbox_header = HBoxContainer.new()
	vbox.add_child(hbox_header)

	dialogue_title = Label.new()
	dialogue_title.text = "🎓 TUTORIAL INTERACTIVO — TEG"
	dialogue_title.add_theme_font_size_override("font_size", 18)
	dialogue_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	dialogue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_child(dialogue_title)

	step_counter_label = Label.new()
	step_counter_label.text = "Paso 1 / 5"
	step_counter_label.add_theme_font_size_override("font_size", 16)
	step_counter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hbox_header.add_child(step_counter_label)

	dialogue_label = Label.new()
	dialogue_label.text = STEPS[0]["text"]
	dialogue_label.add_theme_font_size_override("font_size", 17)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_label.custom_minimum_size = Vector2(718, 50)
	vbox.add_child(dialogue_label)

	var hbox_btns = HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(hbox_btns)

	btn_skip = Button.new()
	btn_skip.text = "Omitir Tutorial"
	btn_skip.add_theme_font_size_override("font_size", 14)
	btn_skip.pressed.connect(_on_skip_pressed)
	hbox_btns.add_child(btn_skip)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	hbox_btns.add_child(spacer)

	btn_next = Button.new()
	btn_next.text = "Siguiente Paso ➡️"
	btn_next.add_theme_font_size_override("font_size", 14)
	btn_next.pressed.connect(_on_next_pressed)
	hbox_btns.add_child(btn_next)

	# Flecha animada que apunta a las zonas clave
	arrow_control = Control.new()
	arrow_control.name = "AnimatedArrow"
	canvas_layer.add_child(arrow_control)

	arrow_label = Label.new()
	arrow_label.text = "🏹 ⬇️"
	arrow_label.add_theme_font_size_override("font_size", 28)
	arrow_label.position = Vector2(-20, -40)
	arrow_control.add_child(arrow_label)

	_animate_arrow()

func _animate_arrow() -> void:
	if arrow_tween and arrow_tween.is_running():
		arrow_tween.kill()

	arrow_tween = create_tween().set_loops()
	arrow_tween.tween_property(arrow_label, "position:y", -55.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arrow_tween.tween_property(arrow_label, "position:y", -35.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _show_step(idx: int) -> void:
	if idx >= STEPS.size():
		_finish_tutorial()
		return

	current_step_idx = idx
	var data = STEPS[idx]

	step_counter_label.text = "Paso %d / %d" % [idx + 1, STEPS.size()]
	dialogue_label.text = data["text"] + "\n[color=#aaaaaa]" + data["hint"] + "[/color]"

	# Posicionar la flecha animada sobre el objetivo del paso
	arrow_control.position = data["target_pos"]

	if idx == STEPS.size() - 1:
		btn_next.text = "Completar Tutorial 🏁"

func _on_next_pressed() -> void:
	if current_step_idx < STEPS.size() - 1:
		_show_step(current_step_idx + 1)
	else:
		_finish_tutorial()

func _on_skip_pressed() -> void:
	_finish_tutorial()

func _on_armies_placed(_player_id: int, _territory_id: int, count: int, _remaining: int) -> void:
	if current_step_idx == 1: # Paso 2: Colocar 3 ejércitos en Argentina
		placed_armies_count += count
		if placed_armies_count >= 3:
			_show_step(2)

func _on_attack_resolved(_from_id: int, _to_id: int, _att_rolls: Array, _def_rolls: Array, _att_loss: int, _def_loss: int) -> void:
	if current_step_idx == 2 or current_step_idx == 3: # Paso 3 y 4
		_show_step(4)

func _on_phase_changed(_player_id: int, _new_phase: String) -> void:
	if current_step_idx == 4: # Paso 5: Fin de fase
		_finish_tutorial()

func _finish_tutorial() -> void:
	dialogue_label.text = "🎉 ¡Tutorial completado! Iniciando partida completa contra la IA..."
	btn_next.disabled = true
	btn_skip.disabled = true

	# Transicionar a partida contra la IA después de un breve delay
	if is_inside_tree() and get_tree() != null:
		var timer = get_tree().create_timer(1.5)
		timer.timeout.connect(func():
			if is_inside_tree() and has_node("/root/GameManager"):
				get_node("/root/GameManager").set_active_game("crisis")
			if (is_inside_tree() and has_node("/root/SceneManager")):
				get_node("/root/SceneManager").transition_to("res://crisis_board.tscn")
			else:
				if is_inside_tree():
					get_tree().change_scene_to_file("res://crisis_board.tscn")
		)
