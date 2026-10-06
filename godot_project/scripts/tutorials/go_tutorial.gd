class_name GoTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Colocar piedra
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Colocar piedra: haz clic en una intersección del tablero (4,4) para colocar tu piedra y ganar libertades.",
		Vector2i(4, 4),
		Vector2i(2, 2),
		Vector2i(4, 4),
		true
	))

	# Paso 2: Capturar grupo
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Capturar grupo: rodea todas las libertades ortogonales de un grupo rival (Atari -> Captura) para retirar sus piedras.",
		Vector2i(4, 5),
		Vector2i(4, 4),
		Vector2i(4, 5),
		false
	))

	# Paso 3: Ko
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Regla de Ko: está prohibido repetir inmediatamente el estado previo del tablero mediante una recaptura instantánea.",
		Vector2i(3, 4),
		Vector2i(3, 3),
		Vector2i(3, 4),
		false
	))

	# Paso 4: Pass
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Pass (Pasar turno): cuando no existan jugadas útiles, pasa el turno; dos pases seguidos terminan la partida.",
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		false
	))

	# Paso 5: Puntuar territorio
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Puntuar territorio: el puntaje final suma las intersecciones vacías rodeadas más las capturas y el Komi.",
		Vector2i(2, 2),
		Vector2i(1, 1),
		Vector2i(3, 3),
		false
	))

	return steps

static func start_on_board(board_node: Node) -> void:
	if board_node == null:
		return
	var steps := get_steps()
	if board_node.has_node("/root/TutorialManager"):
		board_node.get_node("/root/TutorialManager").call("start", steps, board_node)
