extends Control

const CREDITS_TEXT := """
OpenTable SDK — Games Tables SDK
Versión 0.1.0 (2026)

Motor de juego: Rust + GDExtension
UI: Godot 4 / Redot 4.5

Juegos incluidos:
  Ajedrez, Damas, Go, Shogi, Xiangqi, Backgammon,
  Batalla Naval, Ludo, Mille Bornes, Monopoly,
  Uno, Crisis/TEG, Damas Chinas

Licencia: MIT
"""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.text = CREDITS_TEXT
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl)

	var back := Button.new()
	back.text = "← Volver al Menú"
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

func _on_back_pressed() -> void:
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")
