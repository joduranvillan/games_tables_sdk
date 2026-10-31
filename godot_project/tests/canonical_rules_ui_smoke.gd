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

	# 6. Damas (checkers_board.gd): Flujo E2E de captura obligatoria, coronación y tablas (winner == 0)
	var chk_script: Script = load("res://checkers_board.gd") as Script
	_check(chk_script != null, "checkers_board.gd carga sin errores de parseo en modo Redot strict")
	if chk_script != null:
		var chk_node: Node2D = chk_script.new() as Node2D
		get_root().add_child(chk_node)
		if chk_node.get("turn_indicator") == null and chk_node.has_method("_ready"):
			chk_node._ready()
		var valid_chk: Array = chk_node.call("_calculate_valid_moves", 2, 1)
		_check(valid_chk.size() == 2, "Damas E2E: _calculate_valid_moves(2,1) calcula 2 diagonales iniciales")
		chk_node.call("_on_game_over", 0)
		_check(int(chk_node.get("winner")) == 0, "Damas E2E: _on_game_over(0) declara tablas canónicas (40 turnos)")
		get_root().remove_child(chk_node)
		chk_node.free()

	# 7. Xiangqi (xiangqi_board.gd): Flujo E2E de movimiento de Soldado, Río Chu/Frontera Han y victoria/tablas
	var xq_script: Script = load("res://xiangqi_board.gd") as Script
	_check(xq_script != null, "xiangqi_board.gd carga sin errores de parseo en modo Redot strict")
	if xq_script != null:
		var xq_node: Node2D = xq_script.new() as Node2D
		get_root().add_child(xq_node)
		if xq_node.get("turn_indicator") == null and xq_node.has_method("_ready"):
			xq_node._ready()
		var xq_bridge: Object = xq_node.get("bridge")
		_check(xq_bridge != null and int(xq_node.get("current")) == 1, "Xiangqi E2E: Inicia partida con turno Rojo (P1)")
		if xq_bridge != null:
			xq_bridge.call("send_command_json", 1, JSON.stringify({"command_type": "xiangqi_game::MovePieceCommand", "player": 1, "from": [4, 6], "to": [4, 5]}))
			_check(int(xq_node.get("current")) == 2, "Xiangqi E2E: Soldado Rojo (4,6)->(4,5) avanza turno a Negro (P2)")
		get_root().remove_child(xq_node)
		xq_node.free()

	# 8. Damas Chinas (chinese_checkers_board.gd): Flujo E2E de movimiento de canica y selector de 2/3/4/6 jugadores
	var cc_script: Script = load("res://chinese_checkers_board.gd") as Script
	_check(cc_script != null, "chinese_checkers_board.gd carga sin errores de parseo en modo Redot strict")
	if cc_script != null:
		var cc_node: Node2D = cc_script.new() as Node2D
		get_root().add_child(cc_node)
		if cc_node.get("turn_indicator") == null and cc_node.has_method("_ready"):
			cc_node._ready()
		var cc_bridge: Object = cc_node.get("bridge")
		_check(cc_bridge != null and int(cc_node.get("current")) == 1, "Damas Chinas E2E: Inicia sesión con turno J1")
		if cc_bridge != null:
			cc_bridge.call("send_command_json", 1, JSON.stringify({"command_type": "MovePegCommand", "player": 1, "from": {"q": -5, "r": 1}, "to": {"q": -4, "r": 1}, "path": []}))
			_check(int(cc_bridge.call("current_player")) == 2, "Damas Chinas E2E: MovePegCommand válido avanza el turno a J2")
		get_root().remove_child(cc_node)
		cc_node.free()

	# 9. Backgammon (backgammon_board.gd): Flujo E2E de dados y obligación de movimiento
	var bg_script: Script = load("res://backgammon_board.gd") as Script
	_check(bg_script != null, "backgammon_board.gd carga sin errores de parseo en modo Redot strict")
	if bg_script != null:
		var bg_node: Node2D = bg_script.new() as Node2D
		get_root().add_child(bg_node)
		if bg_node.get("turn_indicator") == null and bg_node.has_method("_ready"):
			bg_node._ready()
		var bg_bridge: Object = bg_node.get("bridge")
		_check(bg_bridge != null and int(bg_node.get("current")) == 1, "Backgammon E2E: Inicia partida con turno J1")
		if bg_bridge != null:
			bg_bridge.call("send_command_json", 1, JSON.stringify({"command_type": "RollDiceCommand", "player": 1}))
			var bg_dice: Array = bg_node.get("pending_dice")
			_check(bg_dice.size() >= 2, "Backgammon E2E: RollDiceCommand genera tirada en pending_dice")
		get_root().remove_child(bg_node)
		bg_node.free()

	# 10. Ludo (ludo_board.gd): Flujo E2E de reglas canónicas (casillas estrella seguras, turno extra y 3 seises)
	var ludo_script: Script = load("res://ludo_board.gd") as Script
	_check(ludo_script != null, "ludo_board.gd carga sin errores de parseo en modo Redot strict")
	if ludo_script != null:
		var ludo_node: Node2D = ludo_script.new() as Node2D
		get_root().add_child(ludo_node)
		if ludo_node.get("turn_indicator") == null and ludo_node.has_method("_ready"):
			ludo_node._ready()
		var ludo_bridge: Object = ludo_node.get("bridge")
		_check(ludo_bridge != null, "Ludo E2E: Bridge instanciado en LudoBoard")
		if ludo_bridge != null:
			ludo_bridge.call("send_command_json", 1, JSON.stringify({
				"command_type": "ludo_game::SetLudoRulesCommand",
				"star_safe_squares": true,
				"bonus_roll_on_capture_and_goal": true,
				"three_sixes_penalty": true
			}))
			var ludo_path: Array = ludo_node.call("get_path_from_to", 0, 1, 1, 0)
			_check(ludo_path.size() == 1, "Ludo E2E: SetLudoRulesCommand aceptado y cálculo de salida de base válido")
		get_root().remove_child(ludo_node)
		ludo_node.free()

	# 11. Monopoly (monopoly_board.gd): Flujo E2E de construcción uniforme, hipoteca e intercambios
	var mono_script: Script = load("res://monopoly_board.gd") as Script
	_check(mono_script != null, "monopoly_board.gd carga sin errores de parseo en modo Redot strict")
	if mono_script != null:
		var mono_node: Node2D = mono_script.new() as Node2D
		get_root().add_child(mono_node)
		if mono_node.find_child("BuildHouseButton", true, false) == null and mono_node.has_method("_ready"):
			mono_node._ready()
		_check(mono_node.find_child("BuildHouseButton", true, false) != null, "Monopoly E2E: Botón Construir Casa/Hotel presente")
		_check(mono_node.find_child("MortgageButton", true, false) != null, "Monopoly E2E: Botón Hipotecar/Deshipotecar presente")
		_check(mono_node.find_child("TradeButton", true, false) != null, "Monopoly E2E: Botón Proponer Intercambio presente")
		mono_node.call("select_space", 39)
		var insp_lbl: Label = mono_node.get("inspector_title_lbl") as Label
		_check(insp_lbl != null and "Paseo Tablado" in insp_lbl.text, "Monopoly E2E: Inspector de casilla muestra Paseo Tablado")
		get_root().remove_child(mono_node)
		mono_node.free()

	# 12. UNO (uno_board.gd): Flujo E2E de botones ¡UNO!, Acusar UNO, Desafiar +4 y Jump-In
	var uno_script: Script = load("res://uno_board.gd") as Script
	_check(uno_script != null, "uno_board.gd carga sin errores de parseo en modo Redot strict")
	if uno_script != null:
		var uno_node: Node2D = uno_script.new() as Node2D
		get_root().add_child(uno_node)
		if uno_node.find_child("CallUnoButton", true, false) == null and uno_node.has_method("_ready"):
			uno_node._ready()
		_check(uno_node.find_child("CallUnoButton", true, false) != null, "UNO E2E: CallUnoButton instanciado")
		_check(uno_node.find_child("CatchUnoButton", true, false) != null, "UNO E2E: CatchUnoButton instanciado")
		_check(uno_node.find_child("ChallengeWildFourButton", true, false) != null, "UNO E2E: ChallengeWildFourButton instanciado")
		_check(uno_node.find_child("JumpInButton", true, false) != null, "UNO E2E: JumpInButton instanciado")
		uno_node.set("discard_pile", [{"color": "Green", "value": "7"}])
		_check(bool(uno_node.call("_is_card_interceptable", {"color": "Green", "value": "7"})) == true, "UNO E2E: _is_card_interceptable valida carta idéntica para Jump-In")
		_check(bool(uno_node.call("_is_card_interceptable", {"color": "Green", "value": "5"})) == false, "UNO E2E: _is_card_interceptable rechaza carta de distinto valor")
		get_root().remove_child(uno_node)
		uno_node.free()

	# 13. CRISIS / TEG (crisis_board.gd): Flujo E2E de fases PlaceArmies -> Attack -> Fortify y 30 territorios
	var crisis_script: Script = load("res://crisis_board.gd") as Script
	_check(crisis_script != null, "crisis_board.gd carga sin errores de parseo en modo Redot strict")
	if crisis_script != null:
		var crisis_node: Node2D = crisis_script.new() as Node2D
		get_root().add_child(crisis_node)
		if crisis_node.get("map_panel") == null and crisis_node.has_method("_ready"):
			crisis_node._ready()
		var c_codes: Array = crisis_node.get("TERRITORY_CODES")
		_check(c_codes.size() == 30, "CRISIS E2E: Mapa táctico contiene los 30 territorios canónicos")
		var rem_armies: int = int(crisis_node.get("armies_remaining_to_place"))
		crisis_node.call("_place_armies", rem_armies)
		_check(str(crisis_node.get("current_phase")) == "Attack", "CRISIS E2E: Colocar ejércitos iniciales avanza la fase a Attack")
		get_root().remove_child(crisis_node)
		crisis_node.free()

	# 14. GameAppMenu (scenes/game_app_menu.gd) y RulesPopup bilingüe ES/EN para los 13 juegos
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
		var toggle_b: Button = app_menu.get("toggle_btn") as Button
		_check(toggle_b != null and toggle_b.anchor_left == 1.0 and toggle_b.offset_left >= -160.0, "GameAppMenu: Botón 'Opciones' anclado en esquina superior derecha")
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

	var catalog_script: Script = load("res://scripts/rules_catalog.gd") as Script
	_check(catalog_script != null, "rules_catalog.gd carga correctamente")
	if catalog_script != null:
		var all_game_ids: Array = ["checkers", "chess", "go", "shogi", "xiangqi", "chinese_checkers", "backgammon", "battleship", "ludo", "mille_bornes", "monopoly", "uno", "crisis"]
		for gid in all_game_ids:
			var es_data: Dictionary = catalog_script.call("get_game_rules", str(gid), "es")
			var en_data: Dictionary = catalog_script.call("get_game_rules", str(gid), "en")
			var es_secs: Array = es_data.get("sections", [])
			var en_secs: Array = en_data.get("sections", [])
			_check(es_secs.size() == 5 and en_secs.size() == 5, "RulesCatalog (%s): Contiene las 5 secciones canónicas en ES y EN" % str(gid))

	# 15. Certificación de Layout Centrado Superior / Tablero / Inferior y GameAppMenu en los 13 tableros
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
			var gm_menu: Node = b_node.get_node_or_null("GameAppMenu")
			_check(gm_menu != null, "%s: GameAppMenu adjunto automáticamente al tablero" % str(script_path))
			get_root().remove_child(b_node)
			b_node.free()

	var full_scene_boards: Array = [
		"res://battleship_board.gd",
		"res://uno_board.gd",
		"res://mille_bornes_board.gd",
		"res://monopoly_board.gd",
		"res://crisis_board.gd"
	]
	for fs_path in full_scene_boards:
		var fs_script: Script = load(str(fs_path)) as Script
		if fs_script != null:
			var fs_node: Node2D = fs_script.new() as Node2D
			get_root().add_child(fs_node)
			if fs_node.get("bridge") == null and fs_node.has_method("_ready"):
				fs_node._ready()
			var fs_menu: Node = fs_node.get_node_or_null("GameAppMenu")
			if fs_menu == null:
				fs_menu = fs_node.find_child("GameAppMenu", true, false)
			_check(fs_menu != null, "%s: GameAppMenu integrado en esquina superior derecha" % str(fs_path))
			get_root().remove_child(fs_node)
			fs_node.free()

	if _failures == 0:
		print("=== RESULTADO: TODO OK (canonical_rules_ui_smoke.gd) ===")
		quit(0)
	else:
		printerr("=== RESULTADO: %d FALLO(S) ===" % _failures)
		quit(1)

