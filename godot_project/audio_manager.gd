extends Node

signal sfx_played(sfx_name: String)
signal volume_changed(bus_name: String, volume_db: float)

const MIX_RATE := 22050

var player: AudioStreamPlayer
var music_player: AudioStreamPlayer

var music_volume_db: float = -4.0
var sfx_volume_db: float = 0.0
var music_enabled: bool = true
var sfx_enabled: bool = true

var last_played_sfx: String = ""
var last_boost_db: float = 0.0
var played_events: Array[String] = []
var procedural_cache: Dictionary = {}

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
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "AudioPlayer"
		player.volume_db = sfx_volume_db
		add_child(player)
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		music_player.volume_db = music_volume_db
		add_child(music_player)
	_load_sounds()
	_build_procedural_bank()

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

func _build_procedural_bank() -> void:
	procedural_cache["piece_slide"] = _synth_piece_slide()
	procedural_cache["piece_place"] = _synth_piece_place()
	procedural_cache["dice_roll"] = _synth_dice_roll()
	procedural_cache["card_flip"] = _synth_card_flip()
	procedural_cache["check_alert"] = _synth_check_alert()
	procedural_cache["victory_fanfare"] = _synth_victory_fanfare()
	procedural_cache["error_buzz"] = _synth_error_buzz()
	procedural_cache["timer_tick"] = _synth_timer_tick()

func _create_wav_from_samples(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false

	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in range(samples.size()):
		var clamped := clampf(samples[i], -1.0, 1.0)
		var val := int(clamped * 32767.0)
		pcm.encode_s16(i * 2, val)
	wav.data = pcm
	return wav

func _synth_piece_slide() -> AudioStreamWAV:
	var duration := 0.14
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var freq := lerpf(125.0, 82.0, t / duration)
		phase += TAU * freq / float(MIX_RATE)
		var env := exp(-15.0 * t)
		var friction := rng.randf_range(-0.25, 0.25) * exp(-20.0 * t)
		samples[i] = (sin(phase) * 0.55 + friction) * env
	return _create_wav_from_samples(samples)

func _synth_piece_place() -> AudioStreamWAV:
	var duration := 0.10
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-28.0 * t)
		var body := sin(TAU * 185.0 * t) * 0.65
		var knock := sin(TAU * 390.0 * t) * 0.35 * exp(-42.0 * t)
		samples[i] = (body + knock) * env
	return _create_wav_from_samples(samples)

func _synth_dice_roll() -> AudioStreamWAV:
	var duration := 0.28
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var pulse_times := [0.0, 0.055, 0.11, 0.17, 0.22]
	var pulse_freqs := [320.0, 480.0, 390.0, 540.0, 430.0]
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var sample := 0.0
		for p in range(pulse_times.size()):
			var dt: float = t - pulse_times[p]
			if dt >= 0.0 and dt < 0.05:
				var env := exp(-45.0 * dt)
				var tone := sin(TAU * pulse_freqs[p] * dt)
				var noise := rng.randf_range(-0.6, 0.6)
				sample += (tone * 0.5 + noise * 0.5) * env
		samples[i] = sample * 0.8
	return _create_wav_from_samples(samples)

func _synth_card_flip() -> AudioStreamWAV:
	var duration := 0.09
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := sin(PI * (t / duration)) * exp(-16.0 * t)
		var sweep := sin(TAU * lerpf(900.0, 1750.0, t / duration) * t) * 0.25
		var white := rng.randf_range(-0.75, 0.75) * 0.65
		samples[i] = (white + sweep) * env
	return _create_wav_from_samples(samples)

func _synth_check_alert() -> AudioStreamWAV:
	var duration := 0.32
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var freq1 := 880.0
		var freq2 := 1318.5
		var env := exp(-8.5 * t)
		var tone := (sin(TAU * freq1 * t) * 0.55 + sin(TAU * freq2 * t) * 0.45)
		samples[i] = tone * env * 0.8
	return _create_wav_from_samples(samples)

func _synth_victory_fanfare() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99]
	var note_dur := 0.15
	var duration := note_dur * notes.size()
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var note_idx := clampi(int(t / note_dur), 0, notes.size() - 1)
		var local_t := t - float(note_idx) * note_dur
		var freq: float = notes[note_idx]
		var env := exp(-6.0 * local_t)
		var fundamental := sin(TAU * freq * local_t) * 0.65
		var harmonic := sin(TAU * (freq * 2.0) * local_t) * 0.20
		samples[i] = (fundamental + harmonic) * env
	return _create_wav_from_samples(samples)

func _synth_error_buzz() -> AudioStreamWAV:
	var duration := 0.18
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-10.0 * t)
		var f1 := sin(TAU * 130.81 * t)
		var f2 := sin(TAU * 138.59 * t)
		var f3 := sin(TAU * 261.63 * t) * 0.4
		samples[i] = ((f1 + f2 + f3) / 2.4) * env * 0.85
	return _create_wav_from_samples(samples)

func get_procedural_stream(sfx_key: String) -> AudioStreamWAV:
	if not procedural_cache.has(sfx_key):
		_build_procedural_bank()
	return procedural_cache.get(sfx_key, null)

func set_sfx_volume_db(volume_db: float) -> void:
	sfx_volume_db = clampf(volume_db, -80.0, 6.0)
	if player != null:
		player.volume_db = sfx_volume_db
	volume_changed.emit("SFX", sfx_volume_db)

func get_sfx_volume_db() -> float:
	return sfx_volume_db

func set_music_volume_db(volume_db: float) -> void:
	music_volume_db = clampf(volume_db, -80.0, 6.0)
	if music_player != null:
		music_player.volume_db = music_volume_db
	volume_changed.emit("Music", music_volume_db)

func get_music_volume_db() -> float:
	return music_volume_db

func set_sfx_volume_linear(linear: float) -> void:
	var clamped := clampf(linear, 0.0, 1.0)
	set_sfx_volume_db(linear_to_db(clamped) if clamped > 0.0001 else -80.0)

func set_music_volume_linear(linear: float) -> void:
	var clamped := clampf(linear, 0.0, 1.0)
	set_music_volume_db(linear_to_db(clamped) if clamped > 0.0001 else -80.0)

func _play_stream(stream: AudioStream, event_tag: String = "", boost_db: float = 0.0) -> void:
	last_boost_db = boost_db
	if not event_tag.is_empty():
		last_played_sfx = event_tag
		played_events.append(event_tag)
		sfx_played.emit(event_tag)

	if not sfx_enabled:
		return

	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if "sfx_enabled" in gm and not gm.sfx_enabled:
			return

	if stream == null or player == null:
		return

	player.volume_db = sfx_volume_db + boost_db
	player.stream = stream
	player.play()

func _notify_haptics(method_name: String) -> void:
	if is_inside_tree() and has_node("/root/HapticsManager"):
		var hm = get_node("/root/HapticsManager")
		if hm != null and hm.has_method(method_name):
			hm.call(method_name)

func play_piece_slide() -> void:
	_notify_haptics("light_tap")
	_play_stream(get_procedural_stream("piece_slide"), "piece_slide")

func play_piece_place(boost_db: float = 0.0) -> void:
	_notify_haptics("medium_impact" if boost_db > 0.5 else "light_tap")
	_play_stream(get_procedural_stream("piece_place"), "piece_place", boost_db)

func play_dice_roll() -> void:
	_notify_haptics("medium_impact")
	_play_stream(get_procedural_stream("dice_roll"), "dice_roll")

func play_card_flip() -> void:
	_notify_haptics("light_tap")
	_play_stream(get_procedural_stream("card_flip"), "card_flip")

func play_check_alert() -> void:
	_notify_haptics("medium_impact")
	_play_stream(get_procedural_stream("check_alert"), "check_alert")

func play_victory_fanfare() -> void:
	_notify_haptics("victory_pulse")
	_play_stream(get_procedural_stream("victory_fanfare"), "victory_fanfare")

func play_error_buzz() -> void:
	_play_stream(get_procedural_stream("error_buzz"), "error_buzz")

func play_move() -> void:
	play_piece_place(0.0)

func play_capture() -> void:
	play_piece_place(2.0)

func play_invalid() -> void:
	play_error_buzz()

func play_game_over() -> void:
	play_victory_fanfare()

func play_victory() -> void:
	play_victory_fanfare()

func play_defeat() -> void:
	play_error_buzz()

func play_turn_notify() -> void:
	play_piece_place(0.0)

func play_net_connect() -> void:
	play_check_alert()

func play_net_disconnect() -> void:
	play_error_buzz()

func _synth_timer_tick() -> AudioStreamWAV:
	var duration := 0.06
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-40.0 * t)
		var pulse := sin(TAU * 660.0 * t) * 0.40 + sin(TAU * 990.0 * t) * 0.18
		samples[i] = pulse * env
	return _create_wav_from_samples(samples)

func play_timer_tick() -> void:
	_play_stream(get_procedural_stream("timer_tick"), "timer_tick", -4.0)

