extends SceneTree

func _initialize() -> void:
	# Verificar que credits_screen carga
	var credits_res := ResourceLoader.exists("res://credits_screen.tscn")
	assert(credits_res, "credits_screen.tscn debe existir")

	# Verificar que spectator_view carga
	var spectator_res := ResourceLoader.exists("res://spectator_view.tscn")
	assert(spectator_res, "spectator_view.tscn debe existir")

	# Verificar que spectator_view tiene método setup
	var sv_script = load("res://spectator_view.gd")
	var sv_inst: Node = sv_script.new()
	assert(sv_inst.has_method("setup"), "SpectatorView debe tener método setup")
	sv_inst.free()

	print("credits_spectator_smoke: OK")
	quit(0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit(1)
