extends Node

const SAVE_PATH = "user://scores.json"

# Schema: { "player_name": { "game_type": { "wins": 0, "losses": 0, "elo": 1200.0 } } }
var scores: Dictionary = {}
var bridge_node: Node = null

func _ready() -> void:
	load_scores()
	call_deferred("_find_and_bind_bridge")

func _find_and_bind_bridge() -> void:
	var tree = get_tree()
	if tree and tree.root:
		for child in tree.root.get_children():
			var b = _search_bridge(child)
			if b:
				bind_bridge(b)
				return

func _search_bridge(node: Node) -> Node:
	if node.name == "Bridge":
		return node
	if node.get("bridge") != null and node.get("bridge") is Node:
		return node.get("bridge")
	for child in node.get_children():
		var res = _search_bridge(child)
		if res:
			return res
	return null

func bind_bridge(p_bridge: Node) -> void:
	if bridge_node != null:
		if bridge_node.is_connected("game_over", _on_game_over):
			bridge_node.disconnect("game_over", _on_game_over)
		if bridge_node.has_signal("game_ended") and bridge_node.is_connected("game_ended", _on_game_ended):
			bridge_node.disconnect("game_ended", _on_game_ended)
	bridge_node = p_bridge
	if bridge_node != null:
		if not bridge_node.is_connected("game_over", _on_game_over):
			bridge_node.connect("game_over", _on_game_over)
		if bridge_node.has_signal("game_ended"):
			if not bridge_node.is_connected("game_ended", _on_game_ended):
				bridge_node.connect("game_ended", _on_game_ended)

func _connect_bridge(b: Node) -> void:
	if b == null:
		return
	if b.has_signal("game_ended"):
		if not b.is_connected("game_ended", _on_game_ended):
			b.connect("game_ended", _on_game_ended)

func _on_game_ended(winner: int, loser: int) -> void:
	var game_type: String = GameManager.get_active_game() if has_node("/root/GameManager") else "unknown"
	update_elo(winner, loser, game_type)

func update_elo(winner: int, loser: int, game_type: String = "") -> void:
	if game_type == "" and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_active_game"):
			game_type = gm.get_active_game()
		elif gm.get("current_game") != null:
			game_type = str(gm.current_game)
	if game_type == "":
		game_type = "chess"

	var p1_name = "Player 1"
	var p2_name = "Player 2"
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_player_name"):
			p1_name = gm.get_player_name(1)
			p2_name = gm.get_player_name(2)

	var winner_name = p1_name if winner == 1 else p2_name
	var loser_name = p2_name if winner == 1 else p1_name
	var winner_p_id = winner
	var loser_p_id = loser if loser > 0 else (2 if winner == 1 else 1)

	var winner_elo = get_elo(winner_name, game_type)
	var loser_elo = get_elo(loser_name, game_type)

	var winner_games = get_total_games(winner_name, game_type)
	var loser_games = get_total_games(loser_name, game_type)

	var k_factor = 32.0
	if winner_games >= 30 or loser_games >= 30:
		k_factor = 16.0

	var new_winner_elo = winner_elo
	var new_loser_elo = loser_elo

	if bridge_node != null and bridge_node.has_method("compute_elo_delta"):
		var res = bridge_node.compute_elo_delta(winner_p_id, loser_p_id, winner_elo, loser_elo, k_factor)
		if res is Array and res.size() >= 2:
			new_winner_elo = float(res[0])
			new_loser_elo = float(res[1])
	else:
		var e_w = 1.0 / (1.0 + pow(10.0, (loser_elo - winner_elo) / 400.0))
		var e_l = 1.0 / (1.0 + pow(10.0, (winner_elo - loser_elo) / 400.0))
		new_winner_elo = winner_elo + k_factor * (1.0 - e_w)
		new_loser_elo = loser_elo + k_factor * (0.0 - e_l)

	record_match(winner_name, game_type, true, new_winner_elo)
	record_match(loser_name, game_type, false, new_loser_elo)

func _on_game_over(winner_id: int) -> void:
	if winner_id == -1:
		return
	if winner_id == 1 or winner_id == 2:
		var loser_id = 2 if winner_id == 1 else 1
		var game_type = "chess"
		if has_node("/root/GameManager"):
			var gm = get_node("/root/GameManager")
			if gm.has_method("get_active_game"):
				game_type = gm.get_active_game()
			elif gm.get("current_game") != null:
				game_type = str(gm.current_game)
		update_elo(winner_id, loser_id, game_type)

func get_elo(player_name: String, game_type: String) -> float:
	if scores.has(player_name) and scores[player_name].has(game_type):
		var g_dict: Dictionary = scores[player_name][game_type]
		return float(g_dict.get("elo", 1200.0))
	return 1200.0

func get_total_games(player_name: String, game_type: String) -> int:
	if scores.has(player_name) and scores[player_name].has(game_type):
		var g_dict: Dictionary = scores[player_name][game_type]
		return int(g_dict.get("wins", 0)) + int(g_dict.get("losses", 0))
	return 0

func record_match(player_name: String, game_type: String, is_win: bool, new_elo: float = -1.0) -> void:
	if not scores.has(player_name):
		scores[player_name] = {}
	var p_scores: Dictionary = scores[player_name]
	if not p_scores.has(game_type):
		p_scores[game_type] = {"wins": 0, "losses": 0, "elo": 1200.0}
	
	var g_scores: Dictionary = p_scores[game_type]
	if is_win:
		g_scores["wins"] = int(g_scores.get("wins", 0)) + 1
	else:
		g_scores["losses"] = int(g_scores.get("losses", 0)) + 1

	if new_elo >= 0.0:
		g_scores["elo"] = new_elo
	elif not g_scores.has("elo"):
		g_scores["elo"] = 1200.0
	
	save_scores()

func save_scores() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scores, "  "))

func load_scores() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		scores = {}
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var txt = file.get_as_text()
		var json = JSON.new()
		if json.parse(txt) == OK:
			if json.data is Dictionary:
				scores = json.data
