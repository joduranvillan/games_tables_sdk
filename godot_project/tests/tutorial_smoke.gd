extends SceneTree

# ==============================================================================
# Smoke Test de los 7 Tutoriales Interactivos (Prompts 439, 440 y 485)
# Verifica que ChessTutorial (8 pasos), GoTutorial (5 pasos),
# ShogiTutorial (5 pasos), CheckersTutorial (5 pasos),
# BackgammonTutorial (5 pasos), UnoTutorial (5 pasos) y LudoTutorial (5 pasos)
# generen sus pasos interactivos correctamente y que TutorialManager
# valide las casillas permitidas, avance en pasos interactivos e informativos
# y soporte saltar o completar los tutoriales.
# ==============================================================================

const TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")
const ChessTutorialScript = preload("res://scripts/tutorials/chess_tutorial.gd")
const GoTutorialScript = preload("res://scripts/tutorials/go_tutorial.gd")
const ShogiTutorialScript = preload("res://scripts/tutorials/shogi_tutorial.gd")
const CheckersTutorialScript = preload("res://scripts/tutorials/checkers_tutorial.gd")
const BackgammonTutorialScript = preload("res://scripts/tutorials/backgammon_tutorial.gd")
const UnoTutorialScript = preload("res://scripts/tutorials/uno_tutorial.gd")
const LudoTutorialScript = preload("res://scripts/tutorials/ludo_tutorial.gd")

func _initialize() -> void:
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

	var checkers_steps: Array = CheckersTutorialScript.get_steps()
	if checkers_steps.size() != 5:
		printerr("FAIL: Se esperaban 5 pasos en CheckersTutorial, se obtuvieron %d" % checkers_steps.size())
		quit(1)
		return

	var backgammon_steps: Array = BackgammonTutorialScript.get_steps()
	if backgammon_steps.size() != 5:
		printerr("FAIL: Se esperaban 5 pasos en BackgammonTutorial, se obtuvieron %d" % backgammon_steps.size())
		quit(1)
		return

	var uno_steps: Array = UnoTutorialScript.get_steps()
	if uno_steps.size() != 5:
		printerr("FAIL: Se esperaban 5 pasos en UnoTutorial, se obtuvieron %d" % uno_steps.size())
		quit(1)
		return

	var ludo_steps: Array = LudoTutorialScript.get_steps()
	if ludo_steps.size() != 5:
		printerr("FAIL: Se esperaban 5 pasos en LudoTutorial, se obtuvieron %d" % ludo_steps.size())
		quit(1)
		return

	var tm: Node = TutorialManagerScript.new()
	var dummy_board: Node2D = Node2D.new()
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

	# Avanzar por el resto de los 8 pasos hasta completar el tutorial de Ajedrez
	while tm.is_running:
		tm.advance_step()

	# Verificar ejecución completa en TutorialManager para los otros 6 tutoriales
	var extra_tutorials: Array = [
		{"name": "Go", "steps": go_steps},
		{"name": "Shogi", "steps": shogi_steps},
		{"name": "Checkers", "steps": checkers_steps},
		{"name": "Backgammon", "steps": backgammon_steps},
		{"name": "UNO", "steps": uno_steps},
		{"name": "Ludo", "steps": ludo_steps},
	]

	for tut in extra_tutorials:
		var t_steps: Array = tut["steps"]
		tm.start(t_steps, dummy_board)
		if not tm.is_running or tm.current_step_index != 0:
			printerr("FAIL: TutorialManager no inició correctamente el tutorial de %s" % tut["name"])
			quit(1)
			return
		for idx in range(t_steps.size()):
			var step_obj = t_steps[idx]
			if step_obj.text.strip_edges().is_empty():
				printerr("FAIL: Paso %d vacío en el tutorial de %s" % [idx + 1, tut["name"]])
				quit(1)
				return
			tm.advance_step()
		if tm.is_running:
			printerr("FAIL: TutorialManager no finalizó tras recorrer todos los pasos de %s" % tut["name"])
			quit(1)
			return

	print("PASS: tutorial_smoke.gd — 7 tutoriales interactivos (Chess, Go, Shogi, Checkers, Backgammon, UNO, Ludo) y TutorialManager verificados")
	quit(0)
