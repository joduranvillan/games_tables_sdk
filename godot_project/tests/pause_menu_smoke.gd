extends SceneTree

const RulesCatalogRef = preload("res://scripts/rules_catalog.gd")
const TurnTimerHudScript = preload("res://scenes/turn_timer_hud.gd")
const AudioManagerScript = preload("res://audio_manager.gd")

func _initialize() -> void:
	# 1. Verificar que RulesCatalog devuelve {title, summary, sections} para los 13 juegos en ES y EN
	var all_games: Array[String] = RulesCatalogRef.get_all_game_ids()
	assert(all_games.size() == 13, "RulesCatalog debe contener los 13 juegos de la suite")
	for game_id in all_games:
		for locale in ["es", "en"]:
			var rules: Dictionary = RulesCatalogRef.get_rules(game_id, locale)
			assert(rules.has("title") and not String(rules["title"]).is_empty(), "Falta title para %s (%s)" % [game_id, locale])
			assert(rules.has("summary") and not String(rules["summary"]).is_empty(), "Falta summary para %s (%s)" % [game_id, locale])
			assert(rules.has("sections") and rules["sections"] is Array and (rules["sections"] as Array).size() >= 4, "Faltan las 4 secciones estructuradas para %s (%s)" % [game_id, locale])

	# 2. Verificar TurnTimerHud (barra regresiva, MM:SS, alerta visual <= 10s, pulso de AudioManager y adjudicación en 00:00)
	var timer_hud: TurnTimerHud = TurnTimerHudScript.new()
	var am := AudioManagerScript.new()
	root.add_child(am)
	timer_hud.audio_manager_ref = am
	timer_hud.timer_enabled = true
	root.add_child(timer_hud)

	timer_hud.start_turn_timer(1, 12.0)
	assert(timer_hud.time_label.text == "00:12", "TurnTimerHud debe iniciar mostrando 00:12")
	assert(not timer_hud.is_warning_state, "TurnTimerHud no debe estar en alerta antes de los últimos 10 segundos")

	# Avanzar 3 segundos -> quedan 9.0 segundos (entra en últimos 10s)
	timer_hud.advance_timer(3.0)
	assert(timer_hud.time_label.text == "00:09", "TurnTimerHud debe mostrar 00:09 tras avanzar 3s")
	assert(timer_hud.is_warning_state, "TurnTimerHud debe activar parpadeo ámbar/rojo en los últimos 10s")
	assert(am.last_played_sfx == "timer_tick", "AudioManager debe reproducir pulso sonoro suave (timer_tick) en los últimos 10s")

	# Avanzar los 9 segundos restantes -> 00:00 y adjudicación al rival (Jugador 2)
	var state := {
		"timeout_winner": -1,
		"resigned_winner": -1,
		"draw_ok": false,
		"signal_received": false,
	}
	timer_hud.turn_timeout.connect(func(_expired_p: int, win_p: int): state["timeout_winner"] = win_p)
	timer_hud.advance_timer(9.0)
	assert(timer_hud.time_label.text == "00:00", "TurnTimerHud debe llegar a 00:00")
	assert(state["timeout_winner"] == 2, "Al expirar el turno del Jugador 1, debe adjudicar la victoria al Jugador 2")

	# 3. Verificar PauseMenu: Reglas, Deshacer Jugada, Rendirse con confirmación, Ofrecer Tablas y GameOverOverlay
	var pm: CanvasLayer = load("res://pause_menu.tscn").instantiate() if ResourceLoader.exists("res://pause_menu.tscn") else null
	if pm == null:
		pm = load("res://pause_menu.gd").new()

	root.add_child(pm)
	assert(pm != null, "PauseMenu debe instanciarse")
	assert(pm.has_signal("quit_game_requested"), "PauseMenu debe tener señal quit_game_requested")
	assert(pm.has_node("Panel/VBoxContainer/UndoMoveButton"), "PauseMenu debe incluir UndoMoveButton (↩️ Deshacer Jugada)")
	assert(pm.has_node("Panel/VBoxContainer/RulesButton"), "PauseMenu debe incluir RulesButton (📖 Ver Reglas del Juego)")
	assert(pm.has_node("Panel/VBoxContainer/ResignButton"), "PauseMenu debe incluir ResignButton (🏳️ Rendirse)")
	assert(pm.has_node("Panel/VBoxContainer/OfferDrawButton"), "PauseMenu debe incluir OfferDrawButton (🤝 Ofrecer Tablas)")

	# Verificar Deshacer Jugada en modo local vs modo online/Relay (Tarea 487)
	pm.set_network_mode(false)
	assert(pm.undo_move_button.visible and not pm.undo_move_button.disabled, "En modo local/vs IA, ↩️ Deshacer Jugada debe estar visible y habilitado")
	assert(pm.undo_last_move() == true, "undo_last_move() debe retornar true en modo local")

	pm.set_network_mode(true)
	assert(not pm.undo_move_button.visible and pm.undo_move_button.disabled, "En partidas online/Relay, el botón ↩️ Deshacer Jugada debe ocultarse y deshabilitarse")
	assert(pm.undo_last_move() == false, "En partidas de red (is_network_mode() == true), undo_last_move() debe retornar false")
	pm.set_network_mode(false)

	pm.active_game_id = "chess"
	pm._on_rules_pressed()
	assert(pm.rules_popup != null and pm.rules_popup.visible, "RulesPopup debe abrirse desde PauseMenu sin perder la partida")

	# Verificar diálogo de confirmación antes de rendirse
	pm.active_player_id = 1
	pm._on_resign_pressed()
	assert(pm.confirm_dialog != null and pm.confirm_dialog.visible, "Rendirse debe mostrar diálogo de confirmación para evitar clics accidentales")
	pm.cancel_confirmation()
	assert(not pm.confirm_dialog.visible, "Cancelar confirmación debe cerrar el diálogo sin terminar la partida")

	pm.resign_confirmed.connect(func(_resigning: int, winner: int): state["resigned_winner"] = winner)
	pm._on_resign_pressed()
	pm.confirm_resign()
	assert(state["resigned_winner"] == 2, "Confirmar rendición del Jugador 1 debe adjudicar victoria al Jugador 2")
	assert(pm.game_over_overlay != null and pm.game_over_overlay.visible, "Confirmar rendición debe disparar game_over_overlay.gd")

	# Verificar Ofrecer Tablas con confirmación
	pm.draw_accepted.connect(func(): state["draw_ok"] = true)
	pm._on_offer_draw_pressed()
	assert(pm.confirm_dialog.visible, "Ofrecer Tablas debe mostrar diálogo de confirmación")
	pm.confirm_draw()
	assert(state["draw_ok"], "Confirmar tablas debe emitir draw_accepted")

	pm.connect("quit_game_requested", func(): state["signal_received"] = true)
	pm.emit_signal("quit_game_requested")
	assert(state["signal_received"], "La señal quit_game_requested debe emitirse y recibirse")

	if pm.game_over_overlay != null and is_instance_valid(pm.game_over_overlay):
		pm.game_over_overlay.free()
	timer_hud.free()
	am.free()
	pm.free()
	print("PASS: pause_menu_smoke.gd OK")
	quit(0)

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		quit(1)
