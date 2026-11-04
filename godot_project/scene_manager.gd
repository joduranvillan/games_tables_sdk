# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## Autoload SceneManager que controla el cambio de escenas con animación de transición y pantalla de carga.
extends SceneTransition

func transition_to(scene_path: String) -> void:
	var start_time = Time.get_ticks_msec()
	await _play_transition_out()
	if is_inside_tree():
		if scene_path.ends_with(".gd"):
			var scr = load(scene_path)
			if scr is Script:
				var inst = scr.new()
				if inst is Node:
					var packed := PackedScene.new()
					packed.pack(inst)
					inst.free()
					get_tree().change_scene_to_packed(packed)
		else:
			get_tree().change_scene_to_file(scene_path)
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	if elapsed < 0.3 and is_inside_tree():
		await get_tree().create_timer(0.3 - elapsed).timeout
	await _play_transition_in()
