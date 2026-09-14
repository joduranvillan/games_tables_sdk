extends CanvasLayer

signal quit_game_requested

@onready var continue_button = $Panel/VBoxContainer/ContinueButton
@onready var settings_button = $Panel/VBoxContainer/SettingsButton
@onready var quit_button = $Panel/VBoxContainer/QuitButton

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()
    
    continue_button.pressed.connect(_on_continue_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    quit_button.pressed.connect(_on_quit_pressed)

func _input(event):
    if event.is_action_pressed("ui_cancel"):
        _toggle_pause()

func _toggle_pause():
    if visible:
        hide()
        get_tree().paused = false
    else:
        show()
        get_tree().paused = true

func _on_continue_pressed():
    _toggle_pause()

func _on_settings_pressed():
    # Load settings menu as an overlay
    var settings = load("res://settings_menu.tscn").instantiate()
    get_tree().root.add_child(settings)

func _on_quit_pressed():
    # Trigger quit logic
    emit_signal("quit_game_requested")
    get_tree().paused = false
    SceneManager.change_scene("res://main.tscn")
