extends SceneTree

func _initialize() -> void:
	# Verificar que credits_screen carga y cuenta con pestaña "Licencias Open Source" y botón "Exportar Diagnóstico" (Prompt 493)
	var credits_res := ResourceLoader.exists("res://credits_screen.tscn")
	assert(credits_res, "credits_screen.tscn debe existir")

	var credits_script = load("res://scenes/credits_screen.gd")
	assert(credits_script != null, "Debe existir res://scenes/credits_screen.gd")
	var credits_inst: Control = credits_script.new()
	credits_inst._ready()
	assert(credits_inst.tabs_container != null and credits_inst.tabs_container.get_tab_count() >= 2, "CreditsScreen debe tener TabContainer con al menos 2 pestañas")
	assert(credits_inst.tabs_container.get_tab_title(1) == "Licencias Open Source", "La segunda pestaña debe titularse 'Licencias Open Source'")
	assert(credits_inst.licenses_label != null and "MIT" in credits_inst.licenses_label.text and "Apache" in credits_inst.licenses_label.text, "La pestaña de licencias debe mostrar atribución MIT y Apache-2.0")
	assert(credits_inst.export_diag_button != null and credits_inst.export_diag_button.text == "Exportar Diagnóstico", "CreditsScreen debe incluir botón 'Exportar Diagnóstico'")

	# Verificar ErrorLogger.export_diagnostics(path) -> bool
	var logger_script = load("res://error_logger.gd")
	assert(logger_script != null, "Debe existir res://error_logger.gd")
	var logger_inst = logger_script.new()
	for i in range(60):
		logger_inst.log_info("Test log entry #%d" % i)

	var diag_path := "user://test_opentable_diag.json"
	if FileAccess.file_exists(diag_path):
		DirAccess.remove_absolute(diag_path)

	var exported_ok: bool = logger_inst.export_diagnostics(diag_path)
	assert(exported_ok == true and FileAccess.file_exists(diag_path), "export_diagnostics debe generar el archivo JSON de diagnóstico")

	var f_diag := FileAccess.open(diag_path, FileAccess.READ)
	var diag_text := f_diag.get_as_text()
	f_diag.close()
	var diag_json = JSON.parse_string(diag_text)
	assert(diag_json is Dictionary, "El archivo de diagnóstico debe ser un JSON válido")
	assert(diag_json.has("os") and diag_json.has("renderer") and diag_json.has("bridge_status") and diag_json.has("recent_logs"), "El diagnóstico debe contener os, renderer, bridge_status y recent_logs")
	assert(diag_json.get("pii_collected") == false, "El diagnóstico no debe incluir datos personales (pii_collected == false)")
	var logs_arr: Array = diag_json.get("recent_logs", [])
	assert(logs_arr.size() == 50, "El diagnóstico debe conservar exactamente los últimos 50 logs")

	var btn_export_ok: bool = credits_inst.export_diagnostics_to_file(diag_path)
	assert(btn_export_ok == true, "CreditsScreen.export_diagnostics_to_file debe exportar correctamente")

	if FileAccess.file_exists(diag_path):
		DirAccess.remove_absolute(diag_path)
	logger_inst.free()
	credits_inst.free()

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
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		quit(1)
