# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name ChessTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Resaltar e1-e2
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Mueve tu peón del rey dos casillas adelante (e2 -> e4).",
		Vector2i(4, 1),
		Vector2i(4, 1),
		Vector2i(4, 3),
		true
	))

	# Paso 2: Casillas de movimiento válidas del peón
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Observa las casillas de movimiento válidas del peón resaltadas en el tablero.",
		Vector2i(4, 3),
		Vector2i(4, 1),
		Vector2i(4, 3),
		false
	))

	# Paso 3: Guiar al caballo a f3
	steps.append(TutorialManagerScript.TutorialStep.new(
		"El caballo salta en forma de L — intenta moverlo a f3.",
		Vector2i(6, 0),
		Vector2i(6, 0),
		Vector2i(5, 2),
		true
	))

	# Paso 4: Explicar captura con el peón de dama
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Captura en diagonal con tu peón de dama (d2 -> d4 -> exd5).",
		Vector2i(3, 1),
		Vector2i(3, 3),
		Vector2i(4, 4),
		false
	))

	# Paso 5: Mostrar la pieza del oponente en jaque
	steps.append(TutorialManagerScript.TutorialStep.new(
		"¡Jaque! El rey oponente está bajo ataque directo y está obligado a defenderse.",
		Vector2i(4, 7),
		Vector2i(2, 3),
		Vector2i(4, 7),
		false
	))

	# Paso 6: Guiar el enroque corto
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Enroque corto: mueve tu rey dos casillas hacia la torre (e1 -> g1) para protegerlo.",
		Vector2i(4, 0),
		Vector2i(4, 0),
		Vector2i(6, 0),
		true
	))

	# Paso 7: Jaque mate de pastor simplificado
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Jaque mate de pastor: el alfil en c4 y la dama en f7 dejan al rey rival sin escapatoria.",
		Vector2i(5, 6),
		Vector2i(3, 0),
		Vector2i(5, 6),
		false
	))

	# Paso 8: Felicitación final
	steps.append(TutorialManagerScript.TutorialStep.new(
		"¡Felicitaciones! Ahora practica contra la IA en modo Fácil.",
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
