extends CanvasLayer

var steps = []
var current_step = 0

@onready var text_label = $Panel/TextLabel

func load_tutorial(game_name: String):
    var file = FileAccess.open("res://tutorials/" + game_name + ".json", FileAccess.READ)
    if file:
        var json = JSON.new()
        json.parse(file.get_as_text())
        steps = json.get_data()
        current_step = 0
        show_step()
        show()

func show_step():
    if current_step < steps.size():
        text_label.text = steps[current_step]["text"]
        # Logic to highlight areas on board would go here
    else:
        hide()

func _on_next_pressed():
    current_step += 1
    show_step()
