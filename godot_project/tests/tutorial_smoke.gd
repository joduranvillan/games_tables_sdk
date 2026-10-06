extends SceneTree

# ==============================================================================
# Smoke Test del Tutorial Interactivo de Ajedrez (Prompts 439 y 440)
# Verifica que ChessTutorial genere los 8 pasos interactivos, que TutorialManager
# valide las casillas permitidas, avance en pasos interactivos e informativos
# y soporte saltar o completar el tutorial.
# ==============================================================================

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")
const ChessTutorialScript = preload("res://scripts/tutorials/chess_tutorial.gd")
const GoTutorialScript = preload("res://scripts/tutorials/go_tutorial.gd")
const ShogiTutorialScript = preload("res://scripts/tutorials/shogi_tutorial.gd")

func _init() -> void:
	print("=== Iniciando Test: tutorial_smoke.gd ===")
	var steps: Array = ChessTutorialScript.get_steps()
	if steps.size() != 8:
		printerr("FAIL: Se esperaban 8 pasos en ChessTutorial, se obtuvieron %d" % steps.size())
		quit(1)
		return

	var go_steps: Array = GoTutorialScript.get_steps()
	if go_steps.size() != 5:
		printerr("FAIL: Se esperaban 5 pasos en GoTutorial, se obtuvieron %d" % go_steps.size())
		quit(1)
		return

	var shogi_steps: Array = ShogiTutorialScript.get_steps()
	if shogi_steps.size() != 5:
		printerr("FAIL: Se esperaban 5 pasos en ShogiTutorial, se obtuvieron %d" % shogi_steps.size())
		quit(1)
		return

	var tm := TutorialManagerScript.new()
	var dummy_board := Node2D.new()
	root.add_child(dummy_board)
	root.add_child(tm)

	tm.start(steps, dummy_board)
	if not tm.is_running or tm.current_step_index != 0:
		printerr("FAIL: TutorialManager no inició en el paso 0")
		quit(1)
		return

	# Paso 1 espera acción en (4, 1) o (4, 3); una casilla fuera como (0, 0) debe ser bloqueada
	if tm.is_cell_allowed(Vector2i(0, 0)):
		printerr("FAIL: TutorialManager permitió una casilla fuera del paso activo")
		quit(1)
		return

	if not tm.notify_cell_action(Vector2i(4, 3)):
		printerr("FAIL: TutorialManager rechazó la casilla objetivo del paso 1")
		quit(1)
		return

	if tm.current_step_index != 1:
		printerr("FAIL: TutorialManager no avanzó al paso 2 tras completar la acción")
		quit(1)
		return

	# Avanzar por el resto de los 8 pasos hasta completar el tutorial
	while tm.is_running:
		tm.advance_step()

	print("PASS: tutorial_smoke.gd — 8 pasos de Ajedrez y TutorialManager verificados")
	quit(0)
