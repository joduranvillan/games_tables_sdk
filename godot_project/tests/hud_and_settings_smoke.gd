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
	var bridge = OpenTableBridge.new()
	assert(bridge.has_signal("connection_reconnecting"), "OpenTableBridge debe exponer señal connection_reconnecting")
	assert(bridge.has_signal("connection_restored"), "OpenTableBridge debe exponer señal connection_restored")
	hud.bind_bridge(bridge)
	bridge.emit_connection_reconnecting(1)
	assert(hud.current_state == NetworkStatusHUD.State.RECONNECTING, "HUD debe entrar en RECONNECTING al recibir connection_reconnecting(1)")
	assert(hud.label.text == "Reconectando (intento 1/5)...", "Banner debe mostrar 'Reconectando (intento 1/5)...'")
	assert(hud.visible == true and hud.panel.visible == true, "Banner debe ser visible durante reconexión")
	assert(hud.expelled_to_menu == false, "No debe expulsar al jugador al menú durante los intentos 1..5")
	bridge.emit_connection_reconnecting(3)
	assert(hud.label.text == "Reconectando (intento 3/5)...", "Banner debe mostrar 'Reconectando (intento 3/5)...'")
	hud._process(0.1)
	bridge.emit_connection_restored()
	assert(hud.current_state == NetworkStatusHUD.State.CONNECTED, "HUD debe volver a CONNECTED tras connection_restored")
	assert(hud.visible == false and hud.panel.visible == false, "Banner debe ocultarse al restaurar conexión")
	hud.set_state(NetworkStatusHUD.State.DISCONNECTED)
	hud.set_state(NetworkStatusHUD.State.CONNECTED)
	print("NetworkStatusHUD instantiated, reconnection banner and bridge signals verified.")
	bridge.free()
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

	# 6. ScoreTracker & StatsScreen (Prompt 488: user://stats.cfg, 13 juegos y 3 tarjetas de hitos)
	var test_stats_cfg := "user://test_stats_488.cfg"
	if FileAccess.file_exists(test_stats_cfg):
		DirAccess.remove_absolute(test_stats_cfg)

	var tracker = load("res://score_tracker.gd").new()
	tracker.active_stats_cfg_path = test_stats_cfg
	tracker.scores = {}
	tracker.record_match("Player 1", "chess", true, 1216.0, "easy")
	tracker.record_match("Player 1", "chess", true, 1232.0, "hard")
	tracker.record_match("Player 1", "chess", false, 1218.0, "")
	tracker.record_match("Player 1", "uno", true, 1216.0, "normal")

	var chess_st: Dictionary = tracker.get_game_stats("chess", "Player 1")
	assert(int(chess_st["games_played"]) == 3, "games_played en chess debe ser 3")
	assert(int(chess_st["win_streak"]) == 0, "win_streak debe reiniciarse a 0 tras una derrota")
	assert(int(chess_st["best_streak"]) == 2, "best_streak en chess debe ser 2")
	var ai_wins: Dictionary = chess_st["ai_wins_by_difficulty"]
	assert(int(ai_wins.get("easy", 0)) == 1 and int(ai_wins.get("hard", 0)) == 1, "ai_wins_by_difficulty debe registrar victorias por dificultad")

	var tracker_reloaded = load("res://score_tracker.gd").new()
	tracker_reloaded.scores = {}
	tracker_reloaded.load_stats_cfg(test_stats_cfg)
	var reloaded_chess: Dictionary = tracker_reloaded.get_game_stats("chess", "Player 1")
	assert(int(reloaded_chess["games_played"]) == 3 and int(reloaded_chess["best_streak"]) == 2, "user://stats.cfg debe persistir y recargar estadísticas locales")

	var stats_screen = load("res://scenes/stats_screen.gd").new()
	stats_screen.tracker_ref = tracker_reloaded
	stats_screen._ready()
	assert(stats_screen.get_rendered_game_row_count() == 13, "StatsScreen debe renderizar las 13 filas de juegos")
	assert(stats_screen.total_matches_label.text == "4", "Tarjeta Total de partidas debe mostrar 4")
	assert(stats_screen.favorite_game_label.text.find("Ajedrez") != -1, "Tarjeta Juego favorito debe identificar Ajedrez")
	assert(stats_screen.highest_elo_label.text.find("1218") != -1, "Tarjeta Mayor ELO alcanzado debe mostrar 1218")

	if FileAccess.file_exists(test_stats_cfg):
		DirAccess.remove_absolute(test_stats_cfg)
	stats_screen.free()
	tracker_reloaded.free()
	tracker.free()
	print("ScoreTracker & StatsScreen verified.")

	# 7. GamepadBoardCursor (Prompt 489: activación con mando, movimiento D-Pad/Stick, A selecciona, B cancela, Start pausa, ocultación con ratón/touch)
	var gp_cursor = load("res://scripts/gamepad_board_cursor.gd").new()
	gp_cursor._ready()
	gp_cursor.bind_board(null, 8, 8, 64.0, Vector2(40, 40))
	assert(gp_cursor.cursor_active == false and gp_cursor.visible == false, "GamepadBoardCursor debe iniciar oculto")

	var joy_right := InputEventJoypadButton.new()
	joy_right.button_index = JOY_BUTTON_DPAD_RIGHT
	joy_right.pressed = true
	gp_cursor.handle_input_event(joy_right)
	assert(gp_cursor.cursor_active == true and gp_cursor.visible == true, "GamepadBoardCursor debe activarse al detectar InputEventJoypadButton")
	assert(gp_cursor.cursor_cell == Vector2i(1, 0), "D-Pad Right debe mover el cursor a (1, 0)")

	var joy_motion := InputEventJoypadMotion.new()
	joy_motion.axis = JOY_AXIS_LEFT_Y
	joy_motion.axis_value = 0.85
	gp_cursor.stick_cooldown = 0.0
	gp_cursor.handle_input_event(joy_motion)
	assert(gp_cursor.cursor_cell == Vector2i(1, 1), "InputEventJoypadMotion (Stick izquierdo abajo) debe mover el cursor a (1, 1)")

	var selected_cell := Vector2i(-1, -1)
	gp_cursor.cell_selected.connect(func(c: Vector2i): selected_cell = c)
	var joy_a := InputEventJoypadButton.new()
	joy_a.button_index = JOY_BUTTON_A
	joy_a.pressed = true
	gp_cursor.handle_input_event(joy_a)
	assert(selected_cell == Vector2i(1, 1), "Botón A (ui_gamepad_select) debe seleccionar la celda actual")

	var cancelled := false
	gp_cursor.selection_cancelled.connect(func(): cancelled = true)
	var joy_b := InputEventJoypadButton.new()
	joy_b.button_index = JOY_BUTTON_B
	joy_b.pressed = true
	gp_cursor.handle_input_event(joy_b)
	assert(cancelled == true, "Botón B (ui_gamepad_cancel) debe cancelar la selección")

	var pause_triggered := false
	gp_cursor.pause_requested.connect(func(): pause_triggered = true)
	var joy_start := InputEventJoypadButton.new()
	joy_start.button_index = JOY_BUTTON_START
	joy_start.pressed = true
	gp_cursor.handle_input_event(joy_start)
	assert(pause_triggered == true, "Botón Start (ui_gamepad_start) debe solicitar el menú de pausa")

	var mouse_ev := InputEventMouseMotion.new()
	mouse_ev.position = Vector2(200, 200)
	gp_cursor.handle_input_event(mouse_ev)
	assert(gp_cursor.cursor_active == false and gp_cursor.visible == false, "GamepadBoardCursor debe ocultarse al mover el ratón")
	gp_cursor.free()
	print("GamepadBoardCursor verified.")

	# 8. Accesibilidad Visual: Modo Daltónico (Okabe-Ito + Símbolos Geométricos), Alto Contraste y Escalado de Texto (Prompt 490)
	var tm_test = load("res://theme_manager.gd").new()
	assert(tm_test.colorblind_mode == "none", "ThemeManager debe iniciar con colorblind_mode == 'none'")
	assert(is_equal_approx(tm_test.ui_font_scale, 1.0), "ThemeManager debe iniciar con ui_font_scale == 1.0")

	for cb_mode in ["none", "deuteranopia", "protanopia", "tritanopia", "high_contrast"]:
		tm_test.set_colorblind_mode(cb_mode)
		assert(tm_test.get_colorblind_mode() == cb_mode, "ThemeManager debe aceptar el modo " + cb_mode)
		var red_c: Color = tm_test.get_accessible_color("Red")
		var green_c: Color = tm_test.get_accessible_color("Green")
		var blue_c: Color = tm_test.get_accessible_color("Blue")
		assert(red_c != green_c and green_c != blue_c, "Paleta Okabe-Ito/Contraste debe mantener colores distinguibles en " + cb_mode)

	# Verificar símbolos geométricos (▲ Rojo, ● Azul, ■ Verde, ◆ Amarillo, ★ Naranja, ⬟ Violeta)
	assert(tm_test.get_color_symbol("Rojo") == "▲" and tm_test.get_player_symbol(1) == "▲", "Símbolo para Rojo debe ser ▲")
	assert(tm_test.get_color_symbol("Azul") == "●" and tm_test.get_player_symbol(2) == "●", "Símbolo para Azul debe ser ●")
	assert(tm_test.get_color_symbol("Verde") == "■" and tm_test.get_player_symbol(3) == "■", "Símbolo para Verde debe ser ■")
	assert(tm_test.get_color_symbol("Amarillo") == "◆" and tm_test.get_player_symbol(4) == "◆", "Símbolo para Amarillo debe ser ◆")
	assert(tm_test.get_color_symbol("Naranja") == "★" and tm_test.get_player_symbol(6) == "★", "Símbolo para Naranja debe ser ★")
	assert(tm_test.get_color_symbol("Violeta") == "⬟" and tm_test.get_player_symbol(5) == "⬟", "Símbolo para Violeta debe ser ⬟")

	for f_scale in [1.0, 1.15, 1.3]:
		tm_test.set_ui_font_scale(f_scale)
		assert(is_equal_approx(tm_test.get_ui_font_scale(), f_scale), "ui_font_scale debe actualizarse a " + str(f_scale))

	var settings_490 = SettingsMenu.new()
	settings_490._ready()
	assert(settings_490.colorblind_mode_option != null and settings_490.colorblind_mode_option.item_count == 5, "SettingsMenu debe incluir selector de Modo Daltónico con las 5 opciones")
	assert(settings_490.font_scale_option != null and settings_490.font_scale_option.item_count == 3, "SettingsMenu debe incluir selector de Tamaño de Texto con 3 escalas (1.0, 1.15, 1.3)")
	assert(settings_490.haptics_checkbox != null, "SettingsMenu debe incluir toggle de vibración háptica (HapticsCheckBox)")
	settings_490.free()
	tm_test.free()
	print("Visual Accessibility (Okabe-Ito, Geometric Symbols, High Contrast & Text Scaling) verified.")

	# 9. Pulido Móvil: Safe-Area Adaptativa y Vibración Háptica (Prompt 491)
	var hm_test = load("res://scripts/haptics_manager.gd").new()
	hm_test.simulate_handheld_for_tests = false
	hm_test.set_haptics_enabled(true)
	assert(hm_test.light_tap() == false and hm_test.medium_impact() == false and hm_test.victory_pulse() == false, "En escritorio, HapticsManager debe ser un no-op seguro")

	hm_test.simulate_handheld_for_tests = true
	hm_test.set_haptics_enabled(false)
	assert(hm_test.light_tap() == false, "Cuando haptics_enabled es false, HapticsManager debe ser un no-op seguro")

	hm_test.set_haptics_enabled(true)
	assert(hm_test.light_tap() == true and hm_test.last_vibration_pattern == "light_tap", "light_tap() debe activarse en dispositivo móvil con haptics habilitado")
	assert(hm_test.medium_impact() == true and hm_test.last_vibration_pattern == "medium_impact", "medium_impact() debe activarse al tirar dados o capturar")
	assert(hm_test.victory_pulse() == true and hm_test.last_vibration_pattern == "victory_pulse", "victory_pulse() debe activarse al ganar partida")
	hm_test.free()

	var gm_test = load("res://game_manager.gd").new()
	var simulated_safe_margins: Dictionary = gm_test.get_safe_area_margins(Rect2i(0, 44, 1280, 642), Vector2i(1280, 720))
	assert(int(simulated_safe_margins["top"]) == 44 and int(simulated_safe_margins["bottom"]) == 34, "get_safe_area_margins debe calcular márgenes de notch superior (44) y barra inferior (34)")

	var hud_container := MarginContainer.new()
	hud_container.name = "SafeAreaHudContainer"
	gm_test.apply_safe_area_to_hud(hud_container, simulated_safe_margins)
	assert(hud_container.get_theme_constant("margin_top") == 44 and hud_container.get_theme_constant("margin_bottom") == 34, "apply_safe_area_to_hud debe aplicar márgenes de safe-area a contenedores HUD")
	hud_container.free()
	gm_test.free()
	print("Mobile Safe-Area & HapticsManager verified.")

	# 10. Cumplimiento Legal para Tiendas: Política de Privacidad, Términos y Modal en Primer Arranque (Prompt 492)
	var test_privacy_cfg := "user://test_privacy_492.cfg"
	if FileAccess.file_exists(test_privacy_cfg):
		DirAccess.remove_absolute(test_privacy_cfg)

	var PrivacyModalClass = load("res://scenes/privacy_consent_modal.gd")
	assert(PrivacyModalClass != null, "Debe existir res://scenes/privacy_consent_modal.gd")
	assert(PrivacyModalClass.should_show_on_startup(test_privacy_cfg) == true, "En el primer arranque sin privacy_accepted, should_show_on_startup debe ser true")

	var p_modal = PrivacyModalClass.new(test_privacy_cfg)
	p_modal._ready()
	assert(p_modal.accept_online_button != null and p_modal.offline_only_button != null, "PrivacyConsentModal debe mostrar botones para Aceptar Online y Solo Modo Local / Offline")

	# Caso 1: Elegir "Solo Modo Local / Offline"
	p_modal.select_offline_only_mode(test_privacy_cfg)
	assert(PrivacyModalClass.should_show_on_startup(test_privacy_cfg) == false, "Tras elegir modo en el modal, no debe volver a mostrarse en siguientes arranques")
	assert(PrivacyModalClass.is_online_enabled(test_privacy_cfg) == false and PrivacyModalClass.is_offline_only_mode(test_privacy_cfg) == true, "Al elegir Solo Modo Local / Offline, online_enabled debe ser false")

	var auth_offline = load("res://scripts/auth_client.gd").new()
	auth_offline._load_privacy_online_preference(test_privacy_cfg)
	assert(auth_offline.is_online_enabled() == false, "AuthClient debe deshabilitar conexiones externas cuando se elige Solo Modo Local / Offline")
	assert(auth_offline.request_guest_token_from_relay() == false, "En modo Offline, AuthClient no debe realizar ninguna petición HTTP externa")
	auth_offline.free()

	# Caso 2: Aceptar funciones Online
	p_modal.accept_online_features(test_privacy_cfg)
	assert(PrivacyModalClass.should_show_on_startup(test_privacy_cfg) == false, "Tras aceptar funciones online, should_show_on_startup debe seguir siendo false")
	assert(PrivacyModalClass.is_online_enabled(test_privacy_cfg) == true, "Al aceptar funciones online, online_enabled debe ser true")

	if FileAccess.file_exists(test_privacy_cfg):
		DirAccess.remove_absolute(test_privacy_cfg)
	p_modal.free()
	print("PrivacyConsentModal & Offline/Online legal compliance verified.")

	print("--- Smoke Test HUD & Settings PASSED ---")
	quit(0)
