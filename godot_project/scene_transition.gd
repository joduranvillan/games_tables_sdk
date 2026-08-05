## Gestor de transiciones visuales entre escenas (Fade in/out negro de 0.2s).
class_name SceneTransition
extends CanvasLayer

var color_rect: ColorRect
var anim_player: AnimationPlayer

func _ready() -> void:
	layer = 128
	color_rect = ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.modulate.a = 0.0
	add_child(color_rect)
	
	_setup_animation_player()

func _setup_animation_player() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	
	var lib = AnimationLibrary.new()
	
	# Fade Out: 0.0 -> 1.0 en 0.2s
	var anim_out = Animation.new()
	anim_out.length = 0.2
	var track_out = anim_out.add_track(Animation.TYPE_VALUE)
	anim_out.track_set_path(track_out, "ColorRect:modulate:a")
	anim_out.track_insert_key(track_out, 0.0, 0.0)
	anim_out.track_insert_key(track_out, 0.2, 1.0)
	lib.add_animation("fade_out", anim_out)
	
	# Fade In: 1.0 -> 0.0 en 0.2s
	var anim_in = Animation.new()
	anim_in.length = 0.2
	var track_in = anim_in.add_track(Animation.TYPE_VALUE)
	anim_in.track_set_path(track_in, "ColorRect:modulate:a")
	anim_in.track_insert_key(track_in, 0.0, 1.0)
	anim_in.track_insert_key(track_in, 0.2, 0.0)
	lib.add_animation("fade_in", anim_in)
	
	anim_player.add_animation_library("", lib)
	add_child(anim_player)

func fade_out() -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	anim_player.play("fade_out")
	await anim_player.animation_finished

func fade_in() -> void:
	anim_player.play("fade_in")
	await anim_player.animation_finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
