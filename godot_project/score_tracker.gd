extends Node

const SAVE_PATH = "user://scores.json"

# Schema: { "player_name": { "game_type": { "wins": 0, "losses": 0 } } }
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
	if bridge_node != null and bridge_node.is_connected("game_over", _on_game_over):
		bridge_node.disconnect("game_over", _on_game_over)
	bridge_node = p_bridge
	if bridge_node != null:
		if not bridge_node.is_connected("game_over", _on_game_over):
			bridge_node.connect("game_over", _on_game_over)

func _on_game_over(winner_id: int) -> void:
	var game_type = "chess"
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.get("current_game") != null:
			game_type = str(gm.current_game)

	var p1_name = "Player 1"
	var p2_name = "Player 2"
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_player_name"):
			p1_name = gm.get_player_name(1)
			p2_name = gm.get_player_name(2)

	if winner_id == 1:
		record_match(p1_name, game_type, true)
		record_match(p2_name, game_type, false)
	elif winner_id == 2:
		record_match(p1_name, game_type, false)
		record_match(p2_name, game_type, true)

func record_match(player_name: String, game_type: String, is_win: bool) -> void:
	if not scores.has(player_name):
		scores[player_name] = {}
	var p_scores: Dictionary = scores[player_name]
	if not p_scores.has(game_type):
		p_scores[game_type] = {"wins": 0, "losses": 0}
	
	var g_scores: Dictionary = p_scores[game_type]
	if is_win:
		g_scores["wins"] = int(g_scores.get("wins", 0)) + 1
	else:
		g_scores["losses"] = int(g_scores.get("losses", 0)) + 1
	
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
