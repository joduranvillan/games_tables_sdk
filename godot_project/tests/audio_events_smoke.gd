# Test headless de humo para el sintetizador de SFX procedural en AudioManager.
# Valida la generación de buffers PCM para los 7 efectos procedurales y los
# controles de volumen independientes en decibelios para Música y SFX.
#
# Correr: redot --headless --path godot_project -s tests/audio_events_smoke.gd
extends SceneTree

func _initialize() -> void:
	var results: Array = []

	var audio_mgr = load("res://scripts/audio_manager.gd").new()
	audio_mgr._ready()

	results.append([
		"AudioManager inicializa reproductores no nulos (player y music_player)",
		audio_mgr.player != null and audio_mgr.music_player != null
	])

	var sfx_methods := [
		["piece_slide", "play_piece_slide"],
		["piece_place", "play_piece_place"],
		["dice_roll", "play_dice_roll"],
		["card_flip", "play_card_flip"],
		["check_alert", "play_check_alert"],
		["victory_fanfare", "play_victory_fanfare"],
		["error_buzz", "play_error_buzz"],
	]

	for item in sfx_methods:
		var key: String = item[0]
		var method_name: String = item[1]
		var has_m: bool = audio_mgr.has_method(method_name)
		if has_m:
			audio_mgr.call(method_name)
		var stream: AudioStreamWAV = audio_mgr.get_procedural_stream(key)
		var valid_pcm: bool = stream != null and stream.data.size() > 0 and audio_mgr.player.stream != null
		results.append([
			"%s() sintetiza AudioStreamWAV válido sin nulos (%d bytes)" % [method_name, stream.data.size() if stream else 0],
			has_m and valid_pcm and audio_mgr.last_played_sfx == key
		])

	# Verificar captura con ganancia +2dB
	audio_mgr.play_piece_place(2.0)
	results.append([
		"play_piece_place(2.0) aplica ganancia +2dB sin errores",
		is_equal_approx(audio_mgr.last_boost_db, 2.0)
	])

	# Iterar sobre todos los métodos semánticos adicionales de AudioManager
	var semantic_methods := [
		"play_move",
		"play_capture",
		"play_invalid",
		"play_game_over",
		"play_victory",
		"play_defeat",
		"play_turn_notify",
		"play_net_connect",
		"play_net_disconnect",
	]
	for sem_m in semantic_methods:
		var has_sem: bool = audio_mgr.has_method(sem_m)
		if has_sem:
			audio_mgr.call(sem_m)
		results.append([
			"%s() invocable en modo headless sin nulos ni errores de bus" % sem_m,
			has_sem and audio_mgr.player.stream != null
		])

	# Verificar controles independientes en decibelios para Música y SFX
	audio_mgr.set_music_volume_db(-12.5)
	audio_mgr.set_sfx_volume_db(-6.0)

	results.append([
		"volumen de Música en dB independiente (-12.5 dB)",
		is_equal_approx(audio_mgr.get_music_volume_db(), -12.5)
	])
	results.append([
		"volumen de SFX en dB independiente (-6.0 dB)",
		is_equal_approx(audio_mgr.get_sfx_volume_db(), -6.0)
	])

	var boards := [
		"backgammon_board.gd",
		"battleship_board.gd",
		"checkers_board.gd",
		"chess_board.gd",
		"chinese_checkers_board.gd",
		"crisis_board.gd",
		"go_board.gd",
		"ludo_board.gd",
		"mille_bornes_board.gd",
		"monopoly_board.gd",
		"shogi_board.gd",
		"uno_board.gd",
		"xiangqi_board.gd",
	]
	for b_file in boards:
		var b_script = load("res://" + b_file)
		var b_inst = b_script.new() if b_script != null else null
		var ok_board: bool = (
			b_inst != null
			and b_inst.has_method("_sfx_piece_slide")
			and b_inst.has_method("_sfx_piece_place")
			and b_inst.has_method("_sfx_capture")
			and b_inst.has_method("_sfx_dice_roll")
			and b_inst.has_method("_sfx_card_flip")
			and b_inst.has_method("_sfx_victory_fanfare")
		)
		results.append([
			"%s conecta eventos sonoros procedurales" % b_file,
			ok_board
		])
		if b_inst != null:
			b_inst.free()

	var ok := true
	for r in results:
		var passed: bool = r[1]
		print(("PASS  " if passed else "FAIL  ") + r[0])
		if not passed:
			ok = false

	print("=== RESULTADO AUDIO EVENTS SMOKE: %s ===" % ("TODO OK" if ok else "HAY FALLOS"))

	audio_mgr.free()
	quit(0 if ok else 1)
