extends Node

var player: AudioStreamPlayer

var sfx_move: AudioStream
var sfx_capture: AudioStream
var sfx_invalid: AudioStream
var sfx_game_over: AudioStream
var sfx_win: AudioStream
var sfx_lose: AudioStream
var sfx_turn: AudioStream
var sfx_connect: AudioStream
var sfx_disconnect: AudioStream

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "AudioPlayer"
	add_child(player)
	_load_sounds()

func _load_sounds() -> void:
	sfx_move = _try_load("res://assets/audio/move.wav")
	sfx_capture = _try_load("res://assets/audio/capture.wav")
	sfx_invalid = _try_load("res://assets/audio/invalid.wav")
	sfx_game_over = _try_load("res://assets/audio/game_over.wav")
	sfx_win = _try_load("res://assets/audio/win.wav")
	sfx_lose = _try_load("res://assets/audio/lose.wav")
	sfx_turn = _try_load("res://assets/audio/turn.wav")
	sfx_connect = _try_load("res://assets/audio/connect.wav")
	sfx_disconnect = _try_load("res://assets/audio/disconnect.wav")

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

func _play_stream(stream: AudioStream) -> void:
	if stream == null or player == null:
		return
	
	# Check global settings via GameManager if available
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if "sfx_enabled" in gm and not gm.sfx_enabled:
			return

	player.stream = stream
	player.play()

func play_move() -> void:
	_play_stream(sfx_move)

func play_capture() -> void:
	_play_stream(sfx_capture)

func play_invalid() -> void:
	_play_stream(sfx_invalid)

func play_victory() -> void:
	_play_stream(sfx_win)

func play_defeat() -> void:
	_play_stream(sfx_lose)

func play_turn_notify() -> void:
	_play_stream(sfx_turn)

func play_net_connect() -> void:
	_play_stream(sfx_connect)

func play_net_disconnect() -> void:
	_play_stream(sfx_disconnect)
