extends SceneTree
# Test headless de certificación end-to-end de controles UI y reglas canónicas (Prompt 519):
#   godot --headless -s res://tests/canonical_rules_ui_smoke.gd

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		printerr("FAIL  ", label)
		_failures += 1

func _initialize() -> void:
	var has_bridge: bool = ClassDB.class_exists(&"OpenTableBridge")
	_check(has_bridge, "OpenTableBridge registrado en ClassDB")
	if not has_bridge:
		quit(1)
		return

	# 1. Ajedrez (chess_board.gd): Flujo E2E con Bridge, coronación con atajos 1-4 y oferta/aceptación de tablas
	var chess_script = load("res://chess_board.gd")
	_check(chess_script != null, "chess_board.gd carga sin errores de parseo en modo Redot strict")
	if chess_script != null:
		var chess_node = chess_script.new()
		get_root().add_child(chess_node)
		if chess_node.get("promotion_panel") == null and chess_node.has_method("_ready"):
			chess_node._ready()
		_check(chess_node.get("promotion_panel") != null, "Ajedrez: PromotionSelectorPanel estilizado instanciado")
		_check(chess_node.get("offer_draw_btn") != null, "Ajedrez: OfferDrawButton instanciado")
		_check(chess_node.get("accept_draw_btn") != null, "Ajedrez: AcceptDrawButton instanciado")
		_check(chess_node.has_method("select_promotion_piece"), "Ajedrez: Expone select_promotion_piece(kind)")
		_check(chess_node.has_method("handle_promotion_shortcut"), "Ajedrez: Expone handle_promotion_shortcut(1..4)")
		chess_node.call("handle_promotion_shortcut", 4)
		_check(str(chess_node.get("selected_promotion_kind")) == "Knight", "Ajedrez: Atajo 4 selecciona Caballo ('Knight')")
		chess_node.call("_send_chess_move", 6, 4, 4, 4)
		_check(int(chess_node.get("current")) == 2, "Ajedrez E2E: Movimiento inicial e2-e4 avanza el turno en el bridge a Negras (P2)")
		chess_node.call("_on_offer_draw_pressed")
		var draw_banner = chess_node.get("draw_offer_banner")
		_check(draw_banner != null and draw_banner.visible == true, "Ajedrez E2E: _on_offer_draw_pressed envía OfferDrawCommand y muestra DrawOfferBanner")
		chess_node.call("_on_accept_draw_pressed")
		_check(int(chess_node.get("winner")) == 0, "Ajedrez E2E: _on_accept_draw_pressed envía AcceptDrawCommand y finaliza la partida en tablas (winner == 0)")
		get_root().remove_child(chess_node)
		chess_node.free()

	# 2. Go (go_board.gd): Flujo E2E de Handicap Hoshi, doble pase, conteo en vivo y marcado/confirmación de piedras muertas
	var go_script = load("res://go_board.gd")
	_check(go_script != null, "go_board.gd carga sin errores de parseo en modo Redot strict")
	if go_script != null:
		var go_node = go_script.new()
		get_root().add_child(go_node)
		if go_node.get("handicap_option_button") == null and go_node.has_method("_ready"):
			go_node._ready()
		_check(go_node.get("handicap_option_button") != null, "Go: HandicapOptionButton instanciado")
		_check(go_node.get("scoring_phase_banner") != null, "Go: ScoringPhaseBanner con puntaje en vivo instanciado")
		_check(go_node.get("confirm_dead_button") != null, "Go: ConfirmDeadButton instanciado")
		go_node.set("auto_confirm_dead_in_headless", false)
		go_node.call("apply_handicap", 2)
		_check(int(go_node.get("current")) == 2, "Go E2E: apply_handicap(2) envía PlaceHandicapCommand, coloca 2 piedras Hoshi y cede turno a Blancas (P2)")
		go_node.call("_on_pass_pressed")
		go_node.call("_on_pass_pressed")
		_check(bool(go_node.get("scoring_phase")) == true, "Go E2E: Doble pase consecutivo activa scoring_phase y despliega ScoringPhaseBanner")
		go_node.call("mark_dead_stone", 2, 6)
		var dead_arr: Array = go_node.get("dead_stones")
		_check(Vector2i(2, 6) in dead_arr, "Go E2E: mark_dead_stone(2, 6) envía MarkDeadCommand y registra la piedra en dead_stones")
		var sb_lbl: Label = go_node.get("scoring_banner_label")
		_check(sb_lbl != null and "Muertas: 1" in sb_lbl.text, "Go E2E: ScoringBannerLabel muestra conteo en vivo con piedras muertas")
		go_node.call("_on_confirm_dead_pressed")
		_check(int(go_node.get("winner")) != -1, "Go E2E: _on_confirm_dead_pressed envía ConfirmDeadCommand y cierra oficialmente la partida")
		get_root().remove_child(go_node)
		go_node.free()

	# 3. Shogi (shogi_board.gd): Flujo E2E de diálogo de promoción opcional, obligatoriedad FESA y eventos JSON
	var shogi_script = load("res://shogi_board.gd")
	_check(shogi_script != null, "shogi_board.gd carga sin errores de parseo en modo Redot strict")
	if shogi_script != null:
		var shogi_node = shogi_script.new()
		get_root().add_child(shogi_node)
		if shogi_node.get("promotion_dialog_panel") == null and shogi_node.has_method("_ready"):
			shogi_node._ready()
		_check(shogi_node.get("promotion_dialog_panel") != null, "Shogi: PromotionDialogPanel estilizado instanciado")
		_check(shogi_node.has_method("set_promotion_choice"), "Shogi: Expone set_promotion_choice(promote)")
		_check(bool(shogi_node.call("_is_promotion_mandatory_fesa", "Pawn", 0, 1)) == true, "Shogi: Peón Sente en fila 0 tiene promoción obligatoria FESA")
		_check(bool(shogi_node.call("_is_promotion_mandatory_fesa", "Knight", 1, 1)) == true, "Shogi: Caballo Sente en fila 1 tiene promoción obligatoria FESA")
		_check(bool(shogi_node.call("_is_promotion_mandatory_fesa", "Silver", 0, 1)) == false, "Shogi: Plata Sente en fila 0 tiene promoción opcional FESA")
		shogi_node.call("set_promotion_choice", false)
		_check(bool(shogi_node.get("auto_promote_choice")) == false, "Shogi: set_promotion_choice(false) actualiza la preferencia")
		shogi_node.call("_dispatch_shogi_move", 6, 6, 5, 6, false)
		_check(int(shogi_node.get("current")) == 2, "Shogi E2E: _dispatch_shogi_move ejecuta MovePieceCommand en el bridge y avanza turno a Gote (P2)")
		get_root().remove_child(shogi_node)
		shogi_node.free()

	# 4. Batalla Naval (battleship_board.gd): Flujo E2E de Racha al impactar, Auto-Flota y Revancha
	var bs_script = load("res://battleship_board.gd")
	_check(bs_script != null, "battleship_board.gd carga sin errores de parseo en modo Redot strict")
	if bs_script != null:
		var bs_node = bs_script.new()
		get_root().add_child(bs_node)
		if bs_node.get("extra_turn_check") == null and bs_node.has_method("_ready"):
			bs_node._ready()
		_check(bs_node.get("extra_turn_check") != null, "Batalla Naval: ExtraTurnCheckBox instanciado")
		_check(bs_node.get("rematch_btn") != null, "Batalla Naval: RematchButton instanciado")
		bs_node.call("_on_extra_turn_toggled", true)
		_check(bool(bs_node.get("extra_turn_on_hit_enabled")) == true, "Batalla Naval E2E: _on_extra_turn_toggled(true) envía SetBattleshipRulesCommand")
		bs_node.call("_on_auto_fleet_pressed")
		bs_node.call("_on_auto_fleet_pressed")
		_check(int(bs_node.get("phase")) == 2, "Batalla Naval E2E: Auto-Flota para P1 y P2 avanza a fase de disparo (Phase.FIRE)")
		bs_node.call("_on_rematch_pressed")
		_check(int(bs_node.get("current_ship_index")) == 0 and int(bs_node.get("winner")) == -1 and int(bs_node.get("phase")) == 0, "Batalla Naval E2E: _on_rematch_pressed envía RematchCommand y reinicia partida a colocación")
		get_root().remove_child(bs_node)
		bs_node.free()

	# 5. Mille Bornes (mille_bornes_board.gd): Flujo E2E del Controlador de 4 Escudos y Botón Coup Fourré reactivo
	var mb_script = load("res://mille_bornes_board.gd")
	_check(mb_script != null, "mille_bornes_board.gd carga sin errores de parseo en modo Redot strict")
	if mb_script != null:
		var mb_node = mb_script.new()
		get_root().add_child(mb_node)
		if mb_node.get("coup_fourre_btn") == null and mb_node.has_method("_ready"):
			mb_node._ready()
		var cf_btn: Button = mb_node.get("coup_fourre_btn")
		_check(cf_btn != null, "Mille Bornes: CoupFourreButton reactivo instanciado")
		mb_node.set("hazards", {1: "Luz Verde (Siga)", 2: "Luz Verde (Siga)"})
		mb_node.set("hand_p1", ["Distance 50", "Distance 100"])
		mb_node.call("_update_tableaus")
		_check(cf_btn != null and cf_btn.disabled == true, "Mille Bornes: CoupFourreButton deshabilitado cuando no hay ataque activo ni escudo en mano")
		mb_node.call("_on_event_json", JSON.stringify({"event_type": "HazardPlayedEvent", "target": 1, "hazard": "Sin Gasolina (OutOfGas)"}))
		mb_node.set("hand_p1", ["Distance 50", "Cisterna (ExtraTank)"])
		mb_node.call("_update_tableaus")
		_check(cf_btn != null and cf_btn.disabled == false and bool(mb_node.call("is_coup_fourre_playable", 1)) == true, "Mille Bornes E2E: CoupFourreButton se habilita y resalta tras HazardPlayedEvent + escudo exacto en mano")
		mb_node.call("set_shield_state", 1, "RightOfWay", "ACTIVE")
		_check(str(mb_node.call("get_shield_state", 1, "RightOfWay")) == "ACTIVE", "Mille Bornes: Controlador de escudos registra estado ACTIVE")
		mb_node.call("_on_coup_fourre_pressed")
		_check(str(mb_node.call("get_shield_state", 1, "ExtraTank")) == "COUP_FOURRE", "Mille Bornes E2E: _on_coup_fourre_pressed autodetecta escudo en mano, envía CoupFourreCommand y activa estado COUP_FOURRE")
		var shields_hb = mb_node.call("_create_safety_shields_hbox", 1)
		_check(shields_hb != null and shields_hb.get_child_count() == 4, "Mille Bornes: Tableau muestra las 4 insignias de escudos (Prioridad, Cisterna, Impinchable, As Volante)")
		if shields_hb != null:
			var tank_badge = shields_hb.get_node_or_null("ShieldBadge_ExtraTank/BadgeLabel")
			_check(tank_badge != null and "CF +300" in str(tank_badge.text), "Mille Bornes: Insignia dorada muestra etiqueta 'CF +300' tras Coup Fourré")
			shields_hb.free()
		get_root().remove_child(mb_node)
		mb_node.free()

	# 6. GameAppMenu (scenes/game_app_menu.gd): Menú unificado de Opciones (Exportar/Importar, Configuración, Guardar/Cargar, Tablas/Rendirse)
	var menu_script: Script = load("res://scenes/game_app_menu.gd") as Script
	_check(menu_script != null, "game_app_menu.gd carga sin errores de parseo en modo Redot strict")
	if menu_script != null and go_script != null:
		var go_board_test: Node = go_script.new()
		get_root().add_child(go_board_test)
		if go_board_test.get("handicap_option_button") == null and go_board_test.has_method("_ready"):
			go_board_test._ready()
		var app_menu: Node = menu_script.new()
		app_menu.set("board_node", go_board_test)
		get_root().add_child(app_menu)
		if app_menu.get("export_item_btn") == null and app_menu.has_method("_ready"):
			app_menu._ready()
		app_menu.call("sync_board_buttons")
		_check(app_menu.get("export_item_btn") != null, "GameAppMenu: Botón Exportar Partida (PGN/SGF/JSON) integrado en el menú Opciones")
		_check(app_menu.get("import_item_btn") != null, "GameAppMenu: Botón Importar Partida / Posición integrado en el menú Opciones")
		_check(app_menu.get("save_load_item_btn") != null, "GameAppMenu: Botón Guardar / Cargar Partida integrado en el menú Opciones")
		_check(app_menu.get("save_replay_item_btn") != null, "GameAppMenu: Botón Guardar Replay (.otr) integrado en el menú Opciones")
		_check(app_menu.get("offer_draw_item_btn") != null, "GameAppMenu: Botón Ofrecer Tablas integrado en el menú Opciones")
		_check(app_menu.get("resign_item_btn") != null, "GameAppMenu: Botón Rendirse integrado en el menú Opciones")
		var mode_opt_menu: OptionButton = app_menu.get("mode_menu_option") as OptionButton
		var size_opt_menu: OptionButton = app_menu.get("size_menu_option") as OptionButton
		var handi_opt_menu: OptionButton = app_menu.get("handicap_menu_option") as OptionButton
		_check(mode_opt_menu != null and mode_opt_menu.item_count >= 2, "GameAppMenu: Selector de Modo/IA sincronizado en el menú Opciones")
		_check(size_opt_menu != null and size_opt_menu.item_count == 3, "GameAppMenu: Selector de Tamaño de Tablero sincronizado en el menú Opciones")
		_check(handi_opt_menu != null and handi_opt_menu.item_count >= 2, "GameAppMenu: Selector de Handicap sincronizado en el menú Opciones")
		var go_exp_btn: Control = go_board_test.get("export_game_button") as Control
		var go_mode_btn: Control = go_board_test.get("mode_option_button") as Control
		_check(go_exp_btn != null and go_exp_btn.visible == false, "HUD Equilibrado: Botón Exportar oculto en el lienzo y trasladado al menú Opciones")
		_check(go_mode_btn != null and go_mode_btn.visible == false, "HUD Equilibrado: Selector de Modo oculto en el lienzo y trasladado al menú Opciones")
		get_root().remove_child(app_menu)
		app_menu.free()
		get_root().remove_child(go_board_test)
		go_board_test.free()

	# 7. Layout Centrado Superior / Tablero / Inferior en los juegos
	var centered_boards: Array = [
		"res://go_board.gd",
		"res://chess_board.gd",
		"res://checkers_board.gd",
		"res://shogi_board.gd",
		"res://xiangqi_board.gd",
		"res://backgammon_board.gd",
		"res://ludo_board.gd",
		"res://chinese_checkers_board.gd"
	]
	for script_path in centered_boards:
		var b_script: Script = load(str(script_path)) as Script
		if b_script != null:
			var b_node: Node2D = b_script.new() as Node2D
			get_root().add_child(b_node)
			if b_node.get("turn_indicator") == null and b_node.has_method("_ready"):
				b_node._ready()
			_check(b_node.position.x > 100.0, "%s: Tablero centrado horizontalmente en escena (x=%.1f)" % [str(script_path), b_node.position.x])
			var ti: Control = b_node.get("turn_indicator") as Control
			if ti != null:
				_check(ti.position.y < 30.0 and ti.position.x < 500.0, "%s: TurnIndicator en barra superior centrada (pos=%s)" % [str(script_path), str(ti.position)])
			get_root().remove_child(b_node)
			b_node.free()

	if _failures == 0:
		print("=== RESULTADO: TODO OK (canonical_rules_ui_smoke.gd) ===")
		quit(0)
	else:
		printerr("=== RESULTADO: %d FALLO(S) ===" % _failures)
		quit(1)
