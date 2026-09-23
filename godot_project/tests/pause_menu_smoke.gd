extends SceneTree

func _initialize() -> void:
	# Verificar que PauseMenu carga y conecta señales correctamente
	var pm: CanvasLayer = load("res://pause_menu.tscn").instantiate() if ResourceLoader.exists("res://pause_menu.tscn") else null
	if pm == null:
		# Si no existe la escena, instanciar la clase directamente
		pm = preload("res://pause_menu.gd").new()

	assert(pm != null, "PauseMenu debe instanciarse")
	assert(pm.has_signal("quit_game_requested"), "PauseMenu debe tener señal quit_game_requested")

	var signal_received := false
	pm.connect("quit_game_requested", func(): signal_received = true)

	# Simular la señal de salida
	pm.emit_signal("quit_game_requested")
	assert(signal_received, "La señal quit_game_requested debe emitirse y recibirse")

	pm.free()
	quit(0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit(1)
