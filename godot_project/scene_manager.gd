## Autoload SceneManager que controla el cambio de escenas con animación de transición y pantalla de carga.
extends SceneTransition

func transition_to(scene_path: String) -> void:
	var start_time = Time.get_ticks_msec()
	await _play_transition_out()
	if is_inside_tree():
		get_tree().change_scene_to_file(scene_path)
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	if elapsed < 0.3:
		await get_tree().create_timer(0.3 - elapsed).timeout
	await _play_transition_in()
