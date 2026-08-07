# Test test_get_recent_events_retorna_eventos_en_orden en Godot.
#
# Correr: redot --headless --path godot_project --script res://tests/test_get_recent_events.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []

	var bridge = OpenTableBridge.new()
	bridge.start_local_match(1, 2)

	# Hacer 2 movimientos
	bridge.send_move(1, 2, 1, 3, 2)
	bridge.send_move(2, 5, 0, 4, 1)

	var recent: Array = bridge.get_recent_events()
	results.append(["get_recent_events() retorna un Array no vacío", recent.size() >= 2])

	# Verificar orden de los eventos
	var in_order := true
	if recent.size() >= 2:
		var ev1 = recent[0]
		var ev2 = recent[1]
		results.append(["eventos son diccionarios", ev1 is Dictionary and ev2 is Dictionary])
		# El primer evento corresponde a P1 y el segundo a P2
		if ev1.has("player") and ev2.has("player"):
			in_order = (ev1["player"] == 1 or (ev1["player"] is Dictionary and ev1["player"].get("0") == 1)) and (ev2["player"] == 2 or (ev2["player"] is Dictionary and ev2["player"].get("0") == 2))

	results.append(["test_get_recent_events_retorna_eventos_en_orden", in_order])

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
		print("HAY FALLOS EN TEST GET RECENT EVENTS")
		quit(1)
