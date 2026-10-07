extends SceneTree

func _initialize() -> void:
	# Verificar que credits_screen carga
	var credits_res := ResourceLoader.exists("res://credits_screen.tscn")
	assert(credits_res, "credits_screen.tscn debe existir")

	# Verificar que spectator_view carga
	var spectator_res := ResourceLoader.exists("res://spectator_view.tscn")
	assert(spectator_res, "spectator_view.tscn debe existir")

	# Verificar que spectator_view tiene método setup y soporte Relay Spectator
	var sv_script = load("res://spectator_view.gd")
	var sv_inst: Node = sv_script.new()
	assert(sv_inst.has_method("setup"), "SpectatorView debe tener método setup")
	assert(sv_inst.has_method("join_relay_spectator"), "SpectatorView debe tener join_relay_spectator")
	assert(sv_inst.has_method("receive_relay_message"), "SpectatorView debe tener receive_relay_message")

	var join_req: Dictionary = sv_inst.build_join_spectator_request("xkcd")
	assert(join_req.get("op") == "join_spectator" and join_req.get("room_code") == "XKCD", "Solicitud join_spectator válida")

	var spec_ok: bool = sv_inst.receive_relay_message('{"op":"spectating","player_count":2}')
	assert(spec_ok and sv_inst.is_relay_spectator and sv_inst.player_count == 2, "Debe confirmar spectating con player_count=2")

	var relay_ok: bool = sv_inst.receive_relay_message('{"op":"relay","data":{"move":"e2e4"},"from":1}')
	assert(relay_ok and sv_inst.applied_relay_events.size() == 1, "Debe recibir y aplicar eventos relay")

	var forbid: Dictionary = sv_inst.send_relay_command({"move": "illegal"})
	assert(forbid.get("reason") == "spectator_cannot_relay", "Espectador no puede enviar relay")

	var limit_ok: bool = sv_inst.receive_relay_message('{"op":"error","reason":"spectator_limit"}')
	assert(not limit_ok and sv_inst.last_error_reason == "spectator_limit", "Debe manejar spectator_limit")

	sv_inst.free()

	print("credits_spectator_smoke: OK")
	quit(0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit(1)
