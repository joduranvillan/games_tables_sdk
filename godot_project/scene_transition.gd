# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## Gestor de transiciones visuales y pantalla de carga entre escenas.
class_name SceneTransition
extends CanvasLayer

var color_rect: ColorRect
var center_container: VBoxContainer
var loading_label: Label
var progress_bar: ProgressBar
var anim_player: AnimationPlayer
var _tween: Tween

func _ready() -> void:
	layer = 128
	_setup_loading_screen()
	_setup_animation_player()

func _setup_loading_screen() -> void:
	color_rect = ColorRect.new()
	color_rect.name = "LoadingScreen"
	color_rect.color = Color(0.05, 0.05, 0.08)
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.modulate.a = 0.0
	add_child(color_rect)

	center_container = VBoxContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_theme_constant_override("separation", 16)
	color_rect.add_child(center_container)

	loading_label = Label.new()
	loading_label.name = "LoadingLabel"
	var text_val = tr("LOADING")
	if text_val == "LOADING":
		text_val = "Cargando…"
	loading_label.text = text_val
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_container.add_child(loading_label)

	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.show_percentage = false
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.custom_minimum_size = Vector2(220, 12)
	center_container.add_child(progress_bar)

func _setup_animation_player() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	
	var lib = AnimationLibrary.new()
	
	# Fade Out: 0.0 -> 1.0 en 0.2s
	var anim_out = Animation.new()
	anim_out.length = 0.2
	var track_out = anim_out.add_track(Animation.TYPE_VALUE)
	anim_out.track_set_path(track_out, "LoadingScreen:modulate:a")
	anim_out.track_insert_key(track_out, 0.0, 0.0)
	anim_out.track_insert_key(track_out, 0.2, 1.0)
	lib.add_animation("fade_out", anim_out)
	
	# Fade In: 1.0 -> 0.0 en 0.2s
	var anim_in = Animation.new()
	anim_in.length = 0.2
	var track_in = anim_in.add_track(Animation.TYPE_VALUE)
	anim_in.track_set_path(track_in, "LoadingScreen:modulate:a")
	anim_in.track_insert_key(track_in, 0.0, 1.0)
	anim_in.track_insert_key(track_in, 0.2, 0.0)
	lib.add_animation("fade_in", anim_in)
	
	anim_player.add_animation_library("", lib)
	add_child(anim_player)

func _play_transition_out() -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var text_val = tr("LOADING")
	if text_val == "LOADING":
		text_val = "Cargando…"
	loading_label.text = text_val

	if not OS.has_feature("headless"):
		if _tween and _tween.is_valid():
			_tween.kill()
		progress_bar.value = 0.0
		_tween = create_tween().set_loops()
		_tween.tween_property(progress_bar, "value", 100.0, 0.8).from(0.0)

	anim_player.play("fade_out")
	await anim_player.animation_finished

func _play_transition_in() -> void:
	anim_player.play("fade_in")
	await anim_player.animation_finished

	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	progress_bar.value = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out() -> void:
	await _play_transition_out()

func fade_in() -> void:
	await _play_transition_in()
