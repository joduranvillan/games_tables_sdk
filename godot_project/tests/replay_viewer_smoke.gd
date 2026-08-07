# Test headless de humo del ReplayViewer en Godot.
#
# Correr: redot --headless --path godot_project --script res://tests/replay_viewer_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []

	# 1. Arrancar una partida de damas
	var bridge = OpenTableBridge.new()
	bridge.start_local_match(1, 2)

	# 2. Hacer 3 movimientos válidos
	# Movimiento 1 (P1): (2,1) -> (3,2)
	bridge.send_move(1, 2, 1, 3, 2)
	# Movimiento 2 (P2): (5,0) -> (4,1)
	bridge.send_move(2, 5, 0, 4, 1)
	# Movimiento 3 (P1): (2,3) -> (3,4)
	bridge.send_move(1, 2, 3, 3, 4)

	# 3. Exportar log
	var log_bytes: PackedByteArray = bridge.export_log()
	results.append(["export_log generó bytes de replay", log_bytes.size() > 0])

	# 4. Crear ReplayViewer y cargar datos
	var viewer = ReplayViewer.new()
	var move_events_count: int = 0

	# Escuchar los eventos de movimiento del bridge de ReplayViewer
	viewer.load_replay_data(log_bytes, "checkers")
	if viewer.bridge != null:
		viewer.bridge.connect("piece_moved", func(_p, _fr, _fc, _tr, _tc, _cr, _cc, _pr):
			move_events_count += 1
		)

	results.append(["ReplayViewer calculó total_steps == 3", viewer.total_steps == 3])

	# 5. Iterar con step_replay y verificar eventos
	var step1_ok: bool = viewer.bridge.step_replay() if viewer.bridge else false
	var step2_ok: bool = viewer.bridge.step_replay() if viewer.bridge else false
	var step3_ok: bool = viewer.bridge.step_replay() if viewer.bridge else false

	results.append(["step 1 retornó true", step1_ok])
	results.append(["step 2 retornó true", step2_ok])
	results.append(["step 3 retornó true", step3_ok])
	results.append(["step_replay() emitió exactamente 3 eventos de movimiento", move_events_count == 3])

	# 6. Verificar que step_replay() retorna false al final del replay
	var step4_ok: bool = viewer.bridge.step_replay() if viewer.bridge else true
	results.append(["step_replay() retorna false al final del replay", not step4_ok])

	var ok := true
	for r in results:
		var status = "PASS" if r[1] else "FAIL"
		print("%s  %s" % [status, r[0]])
		if not r[1]:
			ok = false

	if ok:
		print("RESULTADO: TODOS LOS TESTS PASARON EXITOSAMENTE")
		quit(0)
	else:
		print("HAY FALLOS EN LOS TESTS DE REPLAY VIEWER")
		quit(1)
