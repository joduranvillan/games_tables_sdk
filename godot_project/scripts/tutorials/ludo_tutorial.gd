# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name LudoTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Salida de la base con un 6
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Salida con 6: necesitas sacar un 6 en el dado para sacar un peón de tu base inicial a la casilla de salida y obtener un turno extra.",
		Vector2i(1, 6),
		Vector2i(1, 1),
		Vector2i(1, 6),
		true
	))

	# Paso 2: Avance y captura de fichas rivales
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Recorrido y captura: avanza tus fichas en sentido horario según el dado. Si caes sobre una ficha rival solitaria, la devuelves a su base.",
		Vector2i(4, 6),
		Vector2i(1, 6),
		Vector2i(4, 6),
		false
	))

	# Paso 3: Casillas seguras (Estrellas) y barreras
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Casillas seguras (⭐): las casillas de salida y las casillas con estrella protegen tus fichas de cualquier captura enemiga.",
		Vector2i(6, 2),
		Vector2i(4, 6),
		Vector2i(6, 2),
		true
	))

	# Paso 4: Recta final de tu color (Home Stretch)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Pasillo de meta: tras dar la vuelta completa al tablero, tus fichas entran en la columna de tu color donde ningún rival puede entrar.",
		Vector2i(7, 6),
		Vector2i(6, 6),
		Vector2i(7, 6),
		false
	))

	# Paso 5: Tirada exacta a la Meta central
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Meta central: necesitas el valor exacto en el dado para entrar al triángulo central. ¡Gana el primero en llevar sus 4 fichas a la meta!",
		Vector2i(7, 7),
		Vector2i(7, 6),
		Vector2i(7, 7),
		false
	))

	return steps

static func start_on_board(board_node: Node) -> void:
	if board_node == null:
		return
	var steps := get_steps()
	if (board_node.is_inside_tree() and board_node.has_node("/root/TutorialManager")):
		board_node.get_node("/root/TutorialManager").call("start", steps, board_node)
