## Smoke test for NetworkStatusHUD, SettingsMenu, SceneManager, TranslationLoader, and GameOverOverlay.
extends SceneTree

func _init() -> void:
	print("--- Smoke Test HUD & Settings starting ---")
	
	# 1. TranslationLoader
	var tl = load("res://translation_loader.gd").new()
	tl._ready()
	print("TranslationLoader initialized. Current locale:", TranslationServer.get_locale())
	print("Test translation 'BTN_SETTINGS':", tr("BTN_SETTINGS"))
	print("Test translation 'STATUS_CONNECTED':", tr("STATUS_CONNECTED"))
	for lang in ["en", "es", "pt", "fr"]:
		TranslationServer.set_locale(lang)
		assert(tr("MENU_PLAY") != "MENU_PLAY", "MENU_PLAY debe estar traducido en " + lang)
		assert(tr("STATUS_CHECKMATE") != "STATUS_CHECKMATE", "STATUS_CHECKMATE debe estar traducido en " + lang)
		assert(tr("GAME_CHESS") != "GAME_CHESS", "GAME_CHESS debe estar traducido en " + lang)
	TranslationServer.set_locale("es")
	tl.free()
	
	# 2. NetworkStatusHUD
	var hud = NetworkStatusHUD.new()
	hud._ready()
	hud.set_state(NetworkStatusHUD.State.RECONNECTING)
	hud._process(0.1)
	hud.set_state(NetworkStatusHUD.State.DISCONNECTED)
	hud.set_state(NetworkStatusHUD.State.CONNECTED)
	print("NetworkStatusHUD instantiated and states verified.")
	hud.free()
	
	# 3. SettingsMenu
	var settings = SettingsMenu.new()
	settings._ready()
	settings._on_lang_selected(2) # Português ("pt")
	assert(TranslationServer.get_locale().begins_with("pt"), "TranslationServer debe cambiar a pt en tiempo real")
	settings._on_lang_selected(3) # Français ("fr")
	assert(TranslationServer.get_locale().begins_with("fr"), "TranslationServer debe cambiar a fr en tiempo real")
	settings._on_lang_selected(1) # Español ("es")
	assert(TranslationServer.get_locale().begins_with("es"), "TranslationServer debe cambiar a es en tiempo real")

	# Verificar campo Relay Server URL, resolución de /health y diagnóstico Probar Conexión (Prompt 476)
	assert(settings.relay_url_line != null, "SettingsMenu debe incluir el campo RelayUrlLineEdit")
	assert(settings.test_relay_button != null and settings.test_relay_button.text == "Probar Conexión", "SettingsMenu debe incluir botón Probar Conexión")
	var resolved_health := SettingsMenu.resolve_health_url("ws://127.0.0.1:8080")
	assert(resolved_health == "http://127.0.0.1:8081/health", "resolve_health_url debe mapear ws://127.0.0.1:8080 a http://127.0.0.1:8081/health")
	var probe_msg: String = settings.simulate_health_probe_response(200, '{"status":"ok","version":"0.1.0","active_rooms":2}', 28)
	assert(probe_msg == "Conectado — 28 ms" and settings.relay_health_label.text == "Conectado — 28 ms", "Probar Conexión debe mostrar 'Conectado — 28 ms'")

	var test_settings_cfg := "user://test_settings_476.cfg"
	SettingsMenu.save_relay_url_to_config("wss://relay.opentable.gg", test_settings_cfg)
	var loaded_cfg: Dictionary = SettingsMenu.get_saved_settings(test_settings_cfg)
	assert(loaded_cfg.get("relay_url") == "wss://relay.opentable.gg", "user://settings.cfg debe persistir relay_url")
	if FileAccess.file_exists(test_settings_cfg):
		DirAccess.remove_absolute(test_settings_cfg)

	print("SettingsMenu instantiated, language selector and Relay health diagnostics verified.")
	settings.free()
	
	# 4. SceneTransition
	var trans = SceneTransition.new()
	trans._ready()
	print("SceneTransition instantiated successfully.")
	trans.free()

	# 5. GameOverOverlay
	var overlay = load("res://game_over_overlay.gd").new()
	overlay._ready()
	overlay.show_result(1, false)
	assert(overlay.visible == true, "overlay debe estar visible tras show_result")
	overlay._on_go_to_menu_pressed()
	assert(overlay.visible == false, "overlay debe ocultarse al navegar al menú")
	print("GameOverOverlay verified.")
	overlay.free()
	
	print("--- Smoke Test HUD & Settings PASSED ---")
	quit(0)
