extends Node

func _ready():
    # Smoke test: Check if pause menu signals work and tree pausing behaves correctly
    var pause_menu = preload("res://pause_menu.tscn").instantiate()
    add_child(pause_menu)
    
    # Simulate pause
    get_tree().paused = true
    assert(get_tree().paused == true, "Game should be paused")
    
    # Simulate quit request
    pause_menu._on_quit_pressed()
    assert(get_tree().paused == false, "Game should be unpaused after quit")
    
    print("Pause menu smoke test passed!")
    get_tree().quit()
