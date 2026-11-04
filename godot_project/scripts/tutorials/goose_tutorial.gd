# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name GooseTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Salida y tirada de dado en espiral (Casilla 0 -> 1..63)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Recorrido en espiral: lanza el dado al inicio de tu turno y pulsa 'Avanzar Ficha' para recorrer las 63 casillas hacia el Jardín de la Oca.",
		Vector2i(0, 7),
		Vector2i(0, 7),
		Vector2i(5, 7),
		true
	))

	# Paso 2: Regla «De oca a oca y tiro porque me toca»
	steps.append(TutorialManagerScript.TutorialStep.new(
		"De oca a oca (🪿): al caer en una Oca (5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59) saltas automáticamente a la siguiente Oca y obtienes un turno extra.",
		Vector2i(5, 7),
		Vector2i(5, 7),
		Vector2i(7, 5),
		false
	))

	# Paso 3: Puentes (6 <-> 12) y Dados (26 <-> 53)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Puentes y Dados (🌉 / 🎲): el Puente 6 te lleva al 12 (y viceversa) y los Dados 26 y 53 están conectados entre sí; ambos conceden una tirada adicional.",
		Vector2i(6, 7),
		Vector2i(6, 7),
		Vector2i(7, 2),
		true
	))

	# Paso 4: Casillas de penalización (Posada, Pozo, Laberinto, Cárcel y Calavera)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Obstáculos clásicos: Posada (19, pierdes 1 turno), Pozo (31, 2 turnos), Laberinto (42, retrocedes a la 30), Cárcel (52, 3 turnos) y Calavera (58, vuelves a la casilla 1).",
		Vector2i(3, 0),
		Vector2i(3, 0),
		Vector2i(2, 6),
		false
	))

	# Paso 5: Rebote exacto en el Jardín de la Oca (Casilla 63)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Jardín de la Oca (👑 63): debes entrar con cuenta exacta. Si te pasas de 63, tu ficha rebota hacia atrás tantas casillas como puntos sobren.",
		Vector2i(3, 3),
		Vector2i(4, 3),
		Vector2i(3, 3),
		false
	))

	return steps

static func start_on_board(board_node: Node) -> void:
	if board_node == null:
		return
	var steps: Array = get_steps()
	if board_node.is_inside_tree() and board_node.has_node("/root/TutorialManager"):
		board_node.get_node("/root/TutorialManager").call("start", steps, board_node)
