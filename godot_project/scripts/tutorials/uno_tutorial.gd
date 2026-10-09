class_name UnoTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Coincidir por color o número
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Colores y números: juega una carta de tu mano que coincida en color, número o símbolo con la carta superior de la pila de descarte.",
		Vector2i(2, 4),
		Vector2i(2, 5),
		Vector2i(2, 4),
		true
	))

	# Paso 2: Cartas de acción (+2, Salto y Reversa)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Cartas de acción: Toma Dos (+2) hace robar 2 cartas y perder el turno, Salto omite al siguiente jugador y Reversa cambia la dirección de juego.",
		Vector2i(3, 4),
		Vector2i(3, 5),
		Vector2i(3, 4),
		false
	))

	# Paso 3: Comodines y Stacking (+2 / +4)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Comodines y Stacking: los comodines cambian el color activo. Con Stacking activo, puedes apilar otro +2 sobre un +2 para acumular el castigo.",
		Vector2i(4, 4),
		Vector2i(4, 5),
		Vector2i(4, 4),
		true
	))

	# Paso 4: Regla especial Jump-In
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Jump-In (Intercepción): si tienes una carta exactamente idéntica (mismo color y valor) a la del descarte, puedes jugarla fuera de turno.",
		Vector2i(5, 4),
		Vector2i(5, 5),
		Vector2i(5, 4),
		false
	))

	# Paso 5: Gritar ¡UNO! y ganar
	steps.append(TutorialManagerScript.TutorialStep.new(
		"¡Grita UNO!: al quedarte con 1 sola carta presiona el botón ¡UNO! para evitar 2 cartas de penalización. Gana quien descarte toda su mano.",
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
	if board_node.has_node("/root/TutorialManager"):
		board_node.get_node("/root/TutorialManager").call("start", steps, board_node)
