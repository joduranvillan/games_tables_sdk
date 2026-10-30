extends Node

const SAVE_PATH = "user://scores.json"
const STATS_CFG_PATH = "user://stats.cfg"
const STEAM_STATS_SLOT = "local_stats_cfg"

const ALL_GAMES := [
	{"id": "checkers", "name": "Damas (Checkers)"},
	{"id": "chess", "name": "Ajedrez (Chess)"},
	{"id": "shogi", "name": "Shogi"},
	{"id": "xiangqi", "name": "Xiangqi"},
	{"id": "go", "name": "Go"},
	{"id": "uno", "name": "Uno"},
	{"id": "crisis", "name": "Crisis / TEG"},
	{"id": "chinese_checkers", "name": "Damas Chinas"},
	{"id": "mille_bornes", "name": "Mille Bornes"},
	{"id": "backgammon", "name": "Backgammon"},
	{"id": "monopoly", "name": "Monopoly"},
	{"id": "ludo", "name": "Ludo"},
	{"id": "battleship", "name": "Batalla Naval"},
]

# Schema:
# {
#   "player_name": {
#     "game_type": {
#       "games_played": 0,
#       "wins": 0,
#       "losses": 0,
#       "draws": 0,
#       "win_streak": 0,
#       "best_streak": 0,
#       "elo": 1200.0,
#       "ai_wins_by_difficulty": {"easy": 0, "normal": 0, "hard": 0, "expert": 0}
#     }
#   }
# }
var scores: Dictionary = {}
var bridge_node: Node = null
var active_stats_cfg_path: String = STATS_CFG_PATH

func _ready() -> void:
	load_scores()
	load_stats_cfg(active_stats_cfg_path)
	call_deferred("_find_and_bind_bridge")

static func get_default_ai_wins_dict() -> Dictionary:
	return {
		"easy": 0,
		"normal": 0,
		"hard": 0,
		"expert": 0,
	}

static func get_default_game_stats() -> Dictionary:
	return {
		"games_played": 0,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"win_streak": 0,
		"best_streak": 0,
		"elo": 1200.0,
		"ai_wins_by_difficulty": get_default_ai_wins_dict(),
	}

static func normalize_difficulty_key(diff_val: Variant) -> String:
	var s := str(diff_val).strip_edges().to_lower()
	match s:
		"0", "easy", "facil", "fácil":
			return "easy"
		"1", "normal", "medium", "medio":
			return "normal"
		"2", "hard", "dificil", "difícil":
			return "hard"
		"3", "expert", "experto":
			return "expert"
		_:
			return ""

func _ensure_entry(player_name: String, game_type: String) -> Dictionary:
	if not scores.has(player_name) or not (scores[player_name] is Dictionary):
		scores[player_name] = {}
	var p_scores: Dictionary = scores[player_name]
	if not p_scores.has(game_type) or not (p_scores[game_type] is Dictionary):
		p_scores[game_type] = get_default_game_stats()
	var g_scores: Dictionary = p_scores[game_type]
	var defaults := get_default_game_stats()
	for k in defaults.keys():
		if not g_scores.has(k):
			g_scores[k] = defaults[k]
	if not (g_scores["ai_wins_by_difficulty"] is Dictionary):
		g_scores["ai_wins_by_difficulty"] = get_default_ai_wins_dict()
	else:
		var ai_d: Dictionary = g_scores["ai_wins_by_difficulty"]
		for dk in ["easy", "normal", "hard", "expert"]:
			if not ai_d.has(dk):
				ai_d[dk] = 0
	var min_played: int = int(g_scores.get("wins", 0)) + int(g_scores.get("losses", 0)) + int(g_scores.get("draws", 0))
	if int(g_scores.get("games_played", 0)) < min_played:
		g_scores["games_played"] = min_played
	return g_scores

func _find_and_bind_bridge() -> void:
	if not is_inside_tree():
		return
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
	var game_type: String = get_node("/root/GameManager").get_active_game() if is_inside_tree() and has_node("/root/GameManager") else "unknown"
	update_elo(winner, loser, game_type)

func update_elo(winner: int, loser: int, game_type: String = "") -> void:
	if game_type == "" and is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_active_game"):
			game_type = gm.get_active_game()
		elif gm.get("current_game") != null:
			game_type = str(gm.current_game)
	if game_type == "":
		game_type = "chess"

	var p1_name = "Player 1"
	var p2_name = "Player 2"
	var is_vs_ai := false
	var ai_diff_key := ""
	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_player_name"):
			p1_name = gm.get_player_name(1)
			p2_name = gm.get_player_name(2)
		if "game_mode" in gm and String(gm.game_mode) == "vs_ai":
			is_vs_ai = true
			var cfg := ConfigFile.new()
			if cfg.load("user://settings.cfg") == OK:
				ai_diff_key = normalize_difficulty_key(cfg.get_value("ai", "difficulty", 1))
			else:
				ai_diff_key = "normal"

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

	var w_ai_diff := ai_diff_key if (is_vs_ai and winner == 1) else ""
	record_match(winner_name, game_type, true, new_winner_elo, w_ai_diff)
	record_match(loser_name, game_type, false, new_loser_elo)

func _on_game_over(winner_id: int) -> void:
	if winner_id == -1:
		return
	var game_type = "chess"
	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_active_game"):
			game_type = gm.get_active_game()
		elif gm.get("current_game") != null:
			game_type = str(gm.current_game)
	if winner_id == 0:
		record_match("Player 1", game_type, false, -1.0, "", true)
		return
	if winner_id == 1 or winner_id == 2:
		var loser_id = 2 if winner_id == 1 else 1
		update_elo(winner_id, loser_id, game_type)

func get_elo(player_name: String, game_type: String) -> float:
	if scores.has(player_name) and scores[player_name].has(game_type):
		var g_dict: Dictionary = scores[player_name][game_type]
		return float(g_dict.get("elo", 1200.0))
	return 1200.0

func get_total_games(player_name: String, game_type: String) -> int:
	if scores.has(player_name) and scores[player_name].has(game_type):
		var g_dict: Dictionary = scores[player_name][game_type]
		var gp: int = int(g_dict.get("games_played", 0))
		var wl: int = int(g_dict.get("wins", 0)) + int(g_dict.get("losses", 0)) + int(g_dict.get("draws", 0))
		return maxi(gp, wl)
	return 0

func record_match(
	player_name: String,
	game_type: String,
	is_win: bool,
	new_elo: float = -1.0,
	vs_ai_difficulty: Variant = "",
	is_draw: bool = false
) -> void:
	var g_scores := _ensure_entry(player_name, game_type)
	g_scores["games_played"] = int(g_scores.get("games_played", 0)) + 1

	if is_draw:
		g_scores["draws"] = int(g_scores.get("draws", 0)) + 1
		g_scores["win_streak"] = 0
	elif is_win:
		g_scores["wins"] = int(g_scores.get("wins", 0)) + 1
		var new_streak: int = int(g_scores.get("win_streak", 0)) + 1
		g_scores["win_streak"] = new_streak
		if new_streak > int(g_scores.get("best_streak", 0)):
			g_scores["best_streak"] = new_streak

		var diff_key := normalize_difficulty_key(vs_ai_difficulty)
		if not diff_key.is_empty():
			var ai_dict: Dictionary = g_scores["ai_wins_by_difficulty"]
			ai_dict[diff_key] = int(ai_dict.get(diff_key, 0)) + 1
	else:
		g_scores["losses"] = int(g_scores.get("losses", 0)) + 1
		g_scores["win_streak"] = 0

	if new_elo >= 0.0:
		g_scores["elo"] = new_elo
	elif not g_scores.has("elo"):
		g_scores["elo"] = 1200.0

	save_scores()
	save_stats_cfg(active_stats_cfg_path)

func get_game_stats(game_type: String, player_name: String = "Player 1") -> Dictionary:
	var g := _ensure_entry(player_name, game_type)
	var gp: int = int(g.get("games_played", 0))
	var wins: int = int(g.get("wins", 0))
	var losses: int = int(g.get("losses", 0))
	var draws: int = int(g.get("draws", 0))
	var win_rate: float = (float(wins) * 100.0 / float(gp)) if gp > 0 else 0.0
	return {
		"game_id": game_type,
		"games_played": gp,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": win_rate,
		"win_streak": int(g.get("win_streak", 0)),
		"best_streak": int(g.get("best_streak", 0)),
		"elo": float(g.get("elo", 1200.0)),
		"ai_wins_by_difficulty": (g.get("ai_wins_by_difficulty", get_default_ai_wins_dict()) as Dictionary).duplicate(),
	}

func get_all_13_games_summary(player_name: String = "Player 1") -> Array:
	var result: Array = []
	for g_meta in ALL_GAMES:
		var gid: String = g_meta["id"]
		var item := get_game_stats(gid, player_name)
		item["game_name"] = g_meta["name"]
		result.append(item)
	return result

func get_personal_milestones(player_name: String = "Player 1") -> Dictionary:
	var summary := get_all_13_games_summary(player_name)
	var total_matches: int = 0
	var fav_id: String = "Ninguno"
	var fav_name: String = "Sin partidas"
	var max_played: int = 0
	var highest_elo: float = 1200.0
	var highest_elo_game_id: String = "chess"
	var highest_elo_game_name: String = "Ajedrez (Chess)"
	var best_overall_streak: int = 0

	for row in summary:
		var gp: int = int(row.get("games_played", 0))
		var elo_val: float = float(row.get("elo", 1200.0))
		var b_streak: int = int(row.get("best_streak", 0))
		total_matches += gp
		if gp > max_played:
			max_played = gp
			fav_id = String(row.get("game_id", ""))
			fav_name = String(row.get("game_name", ""))
		if elo_val > highest_elo or (gp > 0 and highest_elo == 1200.0 and elo_val >= highest_elo):
			highest_elo = elo_val
			highest_elo_game_id = String(row.get("game_id", ""))
			highest_elo_game_name = String(row.get("game_name", ""))
		if b_streak > best_overall_streak:
			best_overall_streak = b_streak

	return {
		"total_matches": total_matches,
		"favorite_game_id": fav_id,
		"favorite_game_name": fav_name,
		"highest_elo": highest_elo,
		"highest_elo_game_id": highest_elo_game_id,
		"highest_elo_game_name": highest_elo_game_name,
		"best_overall_streak": best_overall_streak,
	}

func save_stats_cfg(cfg_path: String = STATS_CFG_PATH) -> void:
	var cfg := ConfigFile.new()
	for player_name in scores.keys():
		var p_dict: Dictionary = scores[player_name]
		for game_type in p_dict.keys():
			var g := _ensure_entry(player_name, game_type)
			var section := "%s::%s" % [player_name, game_type]
			cfg.set_value(section, "games_played", int(g.get("games_played", 0)))
			cfg.set_value(section, "wins", int(g.get("wins", 0)))
			cfg.set_value(section, "losses", int(g.get("losses", 0)))
			cfg.set_value(section, "draws", int(g.get("draws", 0)))
			cfg.set_value(section, "win_streak", int(g.get("win_streak", 0)))
			cfg.set_value(section, "best_streak", int(g.get("best_streak", 0)))
			cfg.set_value(section, "elo", float(g.get("elo", 1200.0)))
			cfg.set_value(section, "ai_wins_by_difficulty", g.get("ai_wins_by_difficulty", get_default_ai_wins_dict()))
	cfg.save(cfg_path)

	# Sincronizar con Steam Cloud si SteamManager está activo
	if is_inside_tree() and has_node("/root/SteamManager"):
		var sm = get_node("/root/SteamManager")
		if sm.has_method("is_steam_available") and bool(sm.call("is_steam_available")):
			var raw_bytes := cfg.encode_to_text().to_utf8_buffer()
			sm.call("sync_save", STEAM_STATS_SLOT, raw_bytes)

func load_stats_cfg(cfg_path: String = STATS_CFG_PATH) -> void:
	if not FileAccess.file_exists(cfg_path) and is_inside_tree() and has_node("/root/SteamManager"):
		var sm = get_node("/root/SteamManager")
		if sm.has_method("is_steam_available") and bool(sm.call("is_steam_available")):
			var cloud_bytes: PackedByteArray = sm.call("load_save", STEAM_STATS_SLOT)
			if not cloud_bytes.is_empty():
				var f := FileAccess.open(cfg_path, FileAccess.WRITE)
				if f != null:
					f.store_buffer(cloud_bytes)
					f.close()

	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return

	for section in cfg.get_sections():
		var parts: PackedStringArray = section.split("::", false, 1)
		var player_name: String = parts[0] if parts.size() == 2 else "Player 1"
		var game_type: String = parts[1] if parts.size() == 2 else section
		var g := _ensure_entry(player_name, game_type)
		g["games_played"] = int(cfg.get_value(section, "games_played", g["games_played"]))
		g["wins"] = int(cfg.get_value(section, "wins", g["wins"]))
		g["losses"] = int(cfg.get_value(section, "losses", g["losses"]))
		g["draws"] = int(cfg.get_value(section, "draws", g["draws"]))
		g["win_streak"] = int(cfg.get_value(section, "win_streak", g["win_streak"]))
		g["best_streak"] = int(cfg.get_value(section, "best_streak", g["best_streak"]))
		g["elo"] = float(cfg.get_value(section, "elo", g["elo"]))
		var ai_w = cfg.get_value(section, "ai_wins_by_difficulty", get_default_ai_wins_dict())
		if ai_w is Dictionary:
			g["ai_wins_by_difficulty"] = ai_w

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
				for p_name in scores.keys():
					if scores[p_name] is Dictionary:
						for g_type in (scores[p_name] as Dictionary).keys():
							_ensure_entry(p_name, g_type)
