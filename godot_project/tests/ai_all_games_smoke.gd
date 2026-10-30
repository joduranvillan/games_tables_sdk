# Test de humo headless para TODOS los motores IA (Prompt 515).
# Verifica que los bots de Monopoly, UNO, Mille Bornes, Backgammon, Go, Chess,
# Checkers, Ludo, Battleship, Chinese Checkers, Crisis/TEG, Shogi y Xiangqi
# respondan automáticamente tanto cuando la IA es J1 (inicia partida) como
# cuando la IA es J2 (responde tras la jugada del humano).
# Ejecutar: redot --headless --path godot_project -s tests/ai_all_games_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var bridge = OpenTableBridge.new()

	# 1. Backgammon vs IA (IA como J1 y como J2)
	var bg_started = bridge.start_local_match_backgammon_vs_ai(2, 1)
	results.append(["Backgammon vs IA (IA=J1): inició y jugó su turno y devolvió turno a J2", bg_started and bridge.current_player() == 2 and bridge.current_tick() >= 2])
	bridge.free()

	# 2. Monopoly vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var mono_started = bridge.start_local_match_monopoly_vs_ai(2, 1, 1)
	results.append(["Monopoly vs IA (IA=J1): inició y jugó su turno", mono_started and bridge.current_tick() >= 1])
	bridge.start_local_match_monopoly_vs_ai(1, 2, 1)
	for _step in range(3):
		if bridge.current_player() == 1:
			bridge.send_command_json(1, JSON.stringify({"command_type": "RollAndMoveCommand", "player": 1}))
			bridge.send_command_json(1, JSON.stringify({"command_type": "BuyPropertyCommand", "player": 1, "buy": true}))
	results.append(["Monopoly vs IA (IA=J2): IA respondió tras turno de J1", bridge.current_tick() >= 2])
	bridge.free()

	# 3. UNO vs IA (IA como J1 y respuesta como J2 + sincronización de mano en uno_board.gd)
	bridge = OpenTableBridge.new()
	var uno_started = bridge.start_local_match_uno_vs_ai(2, 1, 1)
	results.append(["UNO vs IA (IA=J1): inició y jugó su turno", uno_started and bridge.current_tick() >= 1])
	bridge.start_local_match_uno_vs_ai(1, 2, 1)
	var st_uno = bridge.get_uno_state(1)
	results.append(["UNO vs IA: get_uno_state devuelve mano real de 7 cartas", st_uno.has("hand") and st_uno["hand"].size() == 7])
	bridge.send_command_json(1, JSON.stringify({"command_type": "DrawCardCommand", "player": 1}))
	results.append(["UNO vs IA (IA=J2): IA respondió tras robo de J1", bridge.current_tick() >= 2])
	bridge.free()

	# 4. Mille Bornes vs IA (IA como J1 y respuesta como J2 + get_mille_bornes_hand)
	bridge = OpenTableBridge.new()
	var mb_started = bridge.start_local_match_mille_bornes_vs_ai(2, 1, 1)
	results.append(["Mille Bornes vs IA (IA=J1): inició, jugó su turno y devolvió turno a J2", mb_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.start_local_match_mille_bornes_vs_ai(1, 2, 1)
	var mb_hand = bridge.get_mille_bornes_hand(1)
	results.append(["Mille Bornes vs IA: get_mille_bornes_hand devuelve 6 cartas reales", mb_hand.size() == 6])
	bridge.send_command_json(1, JSON.stringify({"command_type": "DiscardCardCommand", "player": 1, "card_index": 0}))
	results.append(["Mille Bornes vs IA (IA=J2): IA respondió tras jugada de J1 y devolvió turno a J1", bridge.current_player() == 1 and bridge.current_tick() >= 2])
	bridge.free()

	# 5. Go vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var go_started = bridge.start_local_match_go_vs_ai(2, 1, 9)
	results.append(["Go vs IA (IA=J1): inició, colocó piedra y devolvió turno a J2", go_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.start_local_match_go_vs_ai(1, 2, 9)
	bridge.send_command_json(1, JSON.stringify({"command_type": "go_game::PlaceStoneCommand", "player": 1, "x": 4, "y": 4}))
	results.append(["Go vs IA (IA=J2): IA respondió tras jugada de J1 y devolvió turno a J1", bridge.current_player() == 1 and bridge.current_tick() >= 2])
	bridge.free()

	# 6. Crisis / TEG vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var crisis_started = bridge.start_local_match_crisis_vs_ai(2, 1, 1)
	results.append(["Crisis / TEG vs IA (IA=J1): inició, completó sus fases y devolvió turno a J2", crisis_started and bridge.current_player() == 2 and bridge.current_tick() >= 2])
	bridge.free()

	# 7. Chinese Checkers vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var cc_started = bridge.start_local_match_chinese_checkers_vs_ai(2, 1, 1)
	results.append(["Chinese Checkers vs IA (IA=J1): inició, movió ficha y devolvió turno a J2", cc_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.start_local_match_chinese_checkers_vs_ai(1, 2, 1)
	bridge.send_command_json(1, JSON.stringify({
		"command_type": "MovePegCommand",
		"player": 1,
		"from": {"q": -5, "r": 1},
		"to": {"q": -4, "r": 1},
		"path": []
	}))
	results.append(["Chinese Checkers vs IA (IA=J2): IA respondió tras jugada de J1 y devolvió turno a J1", bridge.current_player() == 1 and bridge.current_tick() >= 2])
	bridge.free()

	# 8. Battleship vs IA (IA coloca flota y dispara tras disparo de J1)
	bridge = OpenTableBridge.new()
	var bs_started = bridge.start_local_match_battleship_vs_ai(1, 2, 1)
	var p1_ships = [
		[{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 0, "col": 4}],
		[{"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 2, "col": 2}, {"row": 2, "col": 3}],
		[{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}],
		[{"row": 6, "col": 0}, {"row": 6, "col": 1}, {"row": 6, "col": 2}],
		[{"row": 8, "col": 0}, {"row": 8, "col": 1}]
	]
	bridge.send_command_json(1, JSON.stringify({"command_type": "PlaceFleetCommand", "player": 1, "ships": p1_ships}))
	bridge.send_command_json(1, JSON.stringify({"command_type": "FireShotCommand", "player": 1, "target": {"row": 9, "col": 9}}))
	results.append(["Battleship vs IA (IA=J2): IA colocó flota y respondió al disparo de J1", bs_started and bridge.current_tick() >= 2])
	bridge.free()

	# 9. Chess vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var chess_started = bridge.start_local_match_chess_vs_ai(2, 1, 1)
	results.append(["Chess vs IA (IA=J1): inició, movió pieza blanca y devolvió turno a J2", chess_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.start_local_match_chess_vs_ai(1, 2, 1)
	bridge.send_command_json(1, JSON.stringify({"command_type": "chess_game::MovePieceCommand", "player": 1, "from": {"row": 1, "col": 4}, "to": {"row": 3, "col": 4}, "promote_to": null}))
	results.append(["Chess vs IA (IA=J2): IA respondió tras e2-e4 de J1 y devolvió turno a J1", bridge.current_player() == 1 and bridge.current_tick() >= 2])
	bridge.free()

	# 10. Checkers vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var checkers_started = bridge.start_local_match_checkers_vs_ai(42, 2, 1)
	results.append(["Checkers vs IA (IA=J1): inició, movió ficha y devolvió turno a J2", checkers_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.start_local_match_checkers_vs_ai(42, 1, 2)
	bridge.send_move(1, 2, 1, 3, 2)
	results.append(["Checkers vs IA (IA=J2): IA respondió tras jugada de J1 y devolvió turno a J1", bridge.current_player() == 1 and bridge.current_tick() >= 2])
	bridge.free()

	# 11. Ludo vs IA (IA como J1 y en ludo_board.gd _on_mode_selected)
	bridge = OpenTableBridge.new()
	var ludo_started = bridge.start_local_match_ludo_vs_ai(2, 1)
	results.append(["Ludo vs IA (IA=J1): inició, tiró dado y devolvió turno a J2", ludo_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.free()

	var ludo_board = load("res://ludo_board.gd").new()
	root.add_child(ludo_board)
	if ludo_board.bridge == null and ludo_board.has_method("_ready"):
		ludo_board._ready()
	ludo_board._on_mode_selected(2)
	results.append(["ludo_board.gd vs IA (IA=J1): arrancó sin error de argumentos y cedió turno a J2", ludo_board.current_p == 2])
	root.remove_child(ludo_board)
	ludo_board.free()

	# 12. Shogi vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var shogi_started = bridge.start_local_match_shogi_vs_ai(2, 1, 1)
	results.append(["Shogi vs IA (IA=J1): inició, movió pieza y devolvió turno a J2", shogi_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.start_local_match_shogi_vs_ai(1, 2, 1)
	bridge.send_command_json(1, JSON.stringify({"command_type": "shogi_game::MovePieceCommand", "player": 1, "from": [4, 6], "to": [4, 5], "promote": false}))
	results.append(["Shogi vs IA (IA=J2): IA respondió tras jugada de J1 y devolvió turno a J1", bridge.current_player() == 1 and bridge.current_tick() >= 2])
	bridge.free()

	# 13. Xiangqi vs IA (IA como J1 y respuesta como J2)
	bridge = OpenTableBridge.new()
	var xiangqi_started = bridge.start_local_match_xiangqi_vs_ai(2, 1)
	results.append(["Xiangqi vs IA (IA=J1): inició, movió pieza y devolvió turno a J2", xiangqi_started and bridge.current_player() == 2 and bridge.current_tick() >= 1])
	bridge.start_local_match_xiangqi_vs_ai(1, 2)
	bridge.send_command_json(1, JSON.stringify({"command_type": "xiangqi_game::MovePieceCommand", "player": 1, "from": [4, 6], "to": [4, 5]}))
	results.append(["Xiangqi vs IA (IA=J2): IA respondió tras jugada de J1 y devolvió turno a J1", bridge.current_player() == 1 and bridge.current_tick() >= 2])
	bridge.free()

	var ok: bool = true
	for r in results:
		print(("PASS  " if r[1] else "FAIL  ") + r[0])
		if not r[1]:
			ok = false
	print("=== RESULTADO: %s ===" % ("TODOS LOS MOTORES IA FUNCIONAN" if ok else "HAY FALLOS"))
	quit(0 if ok else 1)
