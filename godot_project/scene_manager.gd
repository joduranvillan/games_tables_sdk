## Autoload SceneManager que controla el cambio de escenas con animación de transición.
extends SceneTransition

func transition_to(scene_path: String) -> void:
	await fade_out()
	get_tree().change_scene_to_file(scene_path)
	await fade_in()
