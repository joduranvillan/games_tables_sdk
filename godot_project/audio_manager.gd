class_name AudioManager
extends Node

var player: AudioStreamPlayer

var sfx_move: AudioStream
var sfx_capture: AudioStream
var sfx_invalid: AudioStream
var sfx_game_over: AudioStream

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

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

func _play_stream(stream: AudioStream) -> void:
	if stream == null or player == null:
		return
	player.stream = stream
	player.play()

func play_move() -> void:
	_play_stream(sfx_move)

func play_capture() -> void:
	_play_stream(sfx_capture)

func play_invalid() -> void:
	_play_stream(sfx_invalid)

func play_game_over() -> void:
	_play_stream(sfx_game_over)
