# Test de rendimiento del bridge Godot en modo headless.
#
# Correr: RUN_PERF_TESTS=1 redot --headless --path godot_project --script res://tests/performance_smoke.gd
extends SceneTree

func _initialize() -> void:
	var run_perf: String = OS.get_environment("RUN_PERF_TESTS")
	if run_perf != "1":
		print("SKIP: RUN_PERF_TESTS no está configurado a 1. Omitiendo test de rendimiento.")
		quit(0)
		return

	var bridge: Object = null
	if ClassDB.class_exists("OpenTableBridge"):
		bridge = ClassDB.instantiate("OpenTableBridge")

	if bridge == null:
		print("FAIL: No se pudo instanciar OpenTableBridge para el test de rendimiento.")
		quit(1)
		return

	bridge.call("start_local_match", 1, 2)

	var iterations: int = 1000
	var start_time: int = Time.get_ticks_msec()

	for i in range(iterations):
		var p: int = bridge.call("current_player")
		if i % 2 == 0:
			bridge.call("send_move", p, 2, 1, 3, 2)
		else:
			bridge.call("send_move", p, 5, 0, 4, 1)

	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	if elapsed_ms <= 0:
		elapsed_ms = 1

	var cmds_per_sec: float = (iterations * 1000.0) / float(elapsed_ms)
	print("Performance Smoke Test: %.2f comandos/segundo (1000 iteraciones en %d ms)" % [cmds_per_sec, elapsed_ms])
	bridge.free()

	if cmds_per_sec < 500.0:
		print("FAIL: Throughput menor a 500 cmd/s (%.2f cmd/s)" % cmds_per_sec)
		quit(1)
	else:
		print("PASS: Performance smoke test superó el umbral de 500 cmd/s")
		quit(0)
