class_name ShogiTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Promoción
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Promoción (Nari): al entrar o mover dentro de las últimas 3 filas rivales, tus piezas pueden promocionar a su versión mejorada.",
		Vector2i(4, 2),
		Vector2i(4, 3),
		Vector2i(4, 2),
		true
	))

	# Paso 2: Pieza capturada como propia
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Pieza capturada como propia: las piezas que capturas pasan a tu reserva (Komadai) y pueden luchar a tu favor.",
		Vector2i(4, 4),
		Vector2i(4, 5),
		Vector2i(4, 4),
		false
	))

	# Paso 3: Movimiento del caballo
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Movimiento del caballo (Keima 桂): salta en L únicamente hacia adelante (dos casillas al frente y una al costado).",
		Vector2i(6, 6),
		Vector2i(7, 8),
		Vector2i(6, 6),
		true
	))

	# Paso 4: Jaque
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Jaque (Ōte): amenaza directamente al Rey rival (玉/王) obligándolo a defenderse de inmediato.",
		Vector2i(4, 0),
		Vector2i(4, 2),
		Vector2i(4, 0),
		false
	))

	# Paso 5: Drop piece
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Drop piece (Uchi 打): reingresa una pieza capturada de tu mano en cualquier casilla vacía válida del tablero.",
		Vector2i(4, 5),
		Vector2i(8, 4),
		Vector2i(4, 5),
		false
	))

	return steps

static func start_on_board(board_node: Node) -> void:
	if board_node == null:
		return
	var steps := get_steps()
	if (board_node.is_inside_tree() and board_node.has_node("/root/TutorialManager")):
		board_node.get_node("/root/TutorialManager").call("start", steps, board_node)
