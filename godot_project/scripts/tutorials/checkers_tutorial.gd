# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name CheckersTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Movimiento diagonal básico
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Movimiento diagonal: avanza tu peón una casilla en diagonal hacia adelante sobre las casillas oscuras.",
		Vector2i(1, 5),
		Vector2i(1, 5),
		Vector2i(2, 4),
		true
	))

	# Paso 2: Captura obligatoria
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Captura obligatoria: cuando una ficha rival está adyacente y la casilla detrás está vacía, estás obligado a saltar sobre ella para capturarla.",
		Vector2i(3, 3),
		Vector2i(2, 4),
		Vector2i(4, 2),
		false
	))

	# Paso 3: Captura múltiple en cadena
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Saltos encadenados: si tras capturar una ficha puedes seguir saltando con la misma pieza, debes continuar la captura múltiple en el mismo turno.",
		Vector2i(4, 2),
		Vector2i(4, 2),
		Vector2i(6, 0),
		true
	))

	# Paso 4: Coronación a Dama (Rey)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Coronación: al llegar a la última fila del rival tu ficha se corona como Dama (Rey), pudiendo mover y capturar en diagonal hacia adelante y hacia atrás.",
		Vector2i(6, 0),
		Vector2i(5, 1),
		Vector2i(6, 0),
		false
	))

	# Paso 5: Victoria
	steps.append(TutorialManagerScript.TutorialStep.new(
		"¡Victoria en Damas! Gana quien capture todas las piezas enemigas o deje al oponente sin ningún movimiento legal.",
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		false
	))

	return steps

static func start_on_board(board_node: Node) -> void:
	if board_node == null:
		return
	var steps := get_steps()
	if (board_node.is_inside_tree() and board_node.has_node("/root/TutorialManager")):
		board_node.get_node("/root/TutorialManager").call("start", steps, board_node)
