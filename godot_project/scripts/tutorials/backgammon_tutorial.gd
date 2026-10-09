class_name BackgammonTutorial
extends RefCounted

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")

static func get_steps() -> Array:
	var steps: Array = []

	# Paso 1: Tirada de dados y avance por los 24 picos
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Dados y movimiento: lanza los dos dados y avanza tus fichas por los picos (Points) hacia tu cuadrante casa. Si sacas dobles, juegas 4 movimientos.",
		Vector2i(0, 0),
		Vector2i(0, 0),
		Vector2i(3, 0),
		true
	))

	# Paso 2: Captura de Blot y la Barra (Bar)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Blot y la Barra (Bar): un pico con una sola ficha rival está desprotegido (Blot). Al caer sobre él envías esa ficha a la Barra central.",
		Vector2i(5, 0),
		Vector2i(3, 0),
		Vector2i(5, 0),
		false
	))

	# Paso 3: Reingreso desde la Barra y Picos Bloqueados
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Reingreso y bloqueos: si tienes fichas en la Barra debes reingresarlas primero. Dos o más fichas propias en un pico bloquean el paso al rival.",
		Vector2i(4, 1),
		Vector2i(2, 1),
		Vector2i(4, 1),
		true
	))

	# Paso 4: Dado de Doblaje (Doubling Cube)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Doubling Cube (Dado de Doblaje): antes de tirar puedes proponer duplicar el valor de la partida (2, 4, 8...). El rival acepta el reto o concede.",
		Vector2i(6, 1),
		Vector2i(5, 1),
		Vector2i(6, 1),
		false
	))

	# Paso 5: Bear Off (Retirar fichas)
	steps.append(TutorialManagerScript.TutorialStep.new(
		"Bear Off y Victoria: cuando tus 15 fichas estén en tu cuadrante casa, retíralas con tus tiradas. El primero en retirar las 15 fichas gana.",
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
