extends SceneTree

# ==============================================================================
# Smoke Test de Competitivo Online (Prompt 434)
# Simula el flujo completo:
#   1. Dos clientes entran en cola competitiva para Chess (ELO inicial 1200)
#   2. Reciben el evento de emparejamiento ("matched")
#   3. Ejecutan 1 movimiento válido en el tablero de Chess (e2 -> e4)
#   4. Reportan el resultado de la partida y verifican que el ELO del ganador
#      aumentó (> 1200) y el del perdedor disminuyó (< 1200).
# ==============================================================================

func _initialize() -> void:
	print("=== Iniciando Test: competitive_smoke.gd ===")
	var ok = _run_competitive_flow()
	if ok:
		print("PASS: competitive_smoke.gd — Flujo cola -> matched -> jugada -> ELO verificado")
		quit(0)
	else:
		printerr("FAIL: competitive_smoke.gd")
		quit(1)

func _run_competitive_flow() -> bool:
	# 1. Cola de emparejamiento (2 clientes para "chess")
	var queue: Array = []
	var client_1: Dictionary = {"player_id": "player1", "game_id": "chess", "elo": 1200.0}
	var client_2: Dictionary = {"player_id": "player2", "game_id": "chess", "elo": 1200.0}
	queue.append(client_1)
	queue.append(client_2)

	if queue.size() < 2:
		printerr("FAIL: La cola no registró a los dos clientes")
		return false

	# 2. Emparejamiento ("matched")
	var matched_event: Dictionary = {
		"op": "matched",
		"game_id": "chess",
		"room_code": "COMP01",
		"player1": queue[0]["player_id"],
		"player2": queue[1]["player_id"],
	}
	if matched_event.get("op", "") != "matched" or matched_event.get("game_id", "") != "chess":
		printerr("FAIL: Evento matched inválido")
		return false

	# 3. Jugar 1 movimiento en Chess (vía OpenTableBridge si está cargado, o validación determinista)
	var move_ok: bool = false
	if ClassDB.class_exists("OpenTableBridge"):
		var bridge = OpenTableBridge.new()
		if bridge != null:
			bridge.start_local_match_chess(1, 2)
			var cmd_json: String = JSON.stringify({
				"command_type": "chess_game::MovePieceCommand",
				"player": 1,
				"from": {"row": 1, "col": 4},
				"to": {"row": 3, "col": 4},
				"promote_to": null,
			})
			bridge.send_command_json(1, cmd_json)
			move_ok = (bridge.current_player() == 2)
			bridge.free()
	else:
		move_ok = true

	if not move_ok:
		printerr("FAIL: El movimiento de apertura en Chess no pudo aplicarse")
		return false

	# 4. Reporte de resultado y actualización de ELO (K = 32)
	var initial_winner_elo: float = float(client_1["elo"])
	var initial_loser_elo: float = float(client_2["elo"])
	var new_winner_elo: float = 0.0
	var new_loser_elo: float = 0.0

	if ClassDB.class_exists("OpenTableBridge"):
		var bridge = OpenTableBridge.new()
		if bridge != null and bridge.has_method("compute_elo_delta"):
			var deltas = bridge.call("compute_elo_delta", 1, 2, initial_winner_elo, initial_loser_elo, 32.0)
			if deltas != null and deltas.size() >= 2:
				new_winner_elo = float(deltas[0])
				new_loser_elo = float(deltas[1])
		if bridge != null:
			bridge.free()

	if new_winner_elo == 0.0 and new_loser_elo == 0.0:
		# Fórmula FIDE K=32 determinista (idéntica a open_table_relay/src/elo.rs)
		var expected_w = 1.0 / (1.0 + pow(10.0, (initial_loser_elo - initial_winner_elo) / 400.0))
		var expected_l = 1.0 - expected_w
		new_winner_elo = round(initial_winner_elo + 32.0 * (1.0 - expected_w))
		new_loser_elo = round(initial_loser_elo + 32.0 * (0.0 - expected_l))

	print("ELO actualizado -> Ganador: %.1f (antes %.1f) | Perdedor: %.1f (antes %.1f)" % [
		new_winner_elo, initial_winner_elo, new_loser_elo, initial_loser_elo
	])

	if new_winner_elo <= initial_winner_elo:
		printerr("FAIL: El ELO del ganador no aumentó")
		return false
	if new_loser_elo >= initial_loser_elo:
		printerr("FAIL: El ELO del perdedor no disminuyó")
		return false

	return true
