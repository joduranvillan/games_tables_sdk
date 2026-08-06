# Manager de Logros (Achievements) para OpenTable.
# Guarda y carga el progreso en user://achievements.json y muestra
# animaciones de notificación flotantes en pantalla.
extends Node

signal achievement_unlocked(id: String, info: Dictionary)

const SAVE_PATH = "user://achievements.json"

var achievements: Dictionary = {
	"primera_victoria": {
		"title": "Primera Victoria",
		"description": "Obtuviste tu primera victoria en cualquier juego.",
		"unlocked": false
	},
	"primera_victoria_damas": {
		"title": "Primera victoria en damas",
		"description": "Ganaste una partida de Damas.",
		"unlocked": false
	},
	"gane_jaque_mate": {
		"title": "Gané en Jaque Mate",
		"description": "Lograste un jaque mate victorioso en Ajedrez.",
		"unlocked": false
	},
	"conquiste_europa": {
		"title": "Conquisté Europa en TEG",
		"description": "Conquistaste el continente de Europa en Crisis / TEG.",
		"unlocked": false
	},
	"estratega_backgammon": {
		"title": "Estratega de Backgammon",
		"description": "Ganaste una partida de Backgammon.",
		"unlocked": false
	},
	"comandante_flota": {
		"title": "Comandante de Flota",
		"description": "Hundiste la flota enemiga en Batalla Naval.",
		"unlocked": false
	}
}

var popup_container: CanvasLayer = null

func _ready() -> void:
	load_achievements()
	_setup_popup_ui()

func _setup_popup_ui() -> void:
	popup_container = CanvasLayer.new()
	popup_container.layer = 100
	add_child(popup_container)

func load_achievements() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var parser = JSON.new()
	if parser.parse(content) == OK:
		var data = parser.data
		if data is Dictionary:
			for k in data.keys():
				if achievements.has(k) and data[k] is Dictionary:
					achievements[k]["unlocked"] = data[k].get("unlocked", false)

func save_achievements() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(achievements, "\t"))
		file.close()

func unlock(id: String) -> bool:
	if not achievements.has(id):
		return false
	if achievements[id]["unlocked"]:
		return false
	achievements[id]["unlocked"] = true
	save_achievements()
	emit_signal("achievement_unlocked", id, achievements[id])
	_show_notification(achievements[id]["title"], achievements[id]["description"])
	return true

func is_unlocked(id: String) -> bool:
	if achievements.has(id):
		return achievements[id]["unlocked"]
	return false

func _show_notification(title: String, description: String) -> void:
	if not is_inside_tree() or popup_container == null:
		return
		
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.2, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.7, 0.2)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	var lbl_badge = Label.new()
	lbl_badge.text = "🏆 ¡LOGRO DESBLOQUEADO!"
	lbl_badge.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	lbl_badge.add_theme_font_size_override("font_size", 12)
	
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.add_theme_color_override("font_color", Color.WHITE)
	lbl_title.add_theme_font_size_override("font_size", 15)
	
	var lbl_desc = Label.new()
	lbl_desc.text = description
	lbl_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	lbl_desc.add_theme_font_size_override("font_size", 12)
	
	vbox.add_child(lbl_badge)
	vbox.add_child(lbl_title)
	vbox.add_child(lbl_desc)
	panel.add_child(vbox)
	
	popup_container.add_child(panel)
	
	var vp = get_viewport()
	var vp_size = vp.get_visible_rect().size if vp else Vector2(720, 800)
	panel.custom_minimum_size = Vector2(260, 70)
	var end_x = vp_size.x - 280
	var start_x = vp_size.x + 10
	var pos_y = 20.0
	
	panel.position = Vector2(start_x, pos_y)
	
	var tween = create_tween()
	if tween:
		# Slide-in animación
		tween.tween_property(panel, "position:x", end_x, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Duración visible de 2 segundos
		tween.tween_interval(2.0)
		# Slide-out animación
		tween.tween_property(panel, "position:x", start_x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(panel.queue_free)

# Conecta las señales de game_over y eventos JSON de una partida al manager
func register_bridge(bridge: Node, game_name: String = "") -> void:
	if bridge.has_signal("game_over"):
		bridge.connect("game_over", func(winner_id: int):
			_on_game_over(winner_id, game_name)
		)
	if bridge.has_signal("event_json"):
		bridge.connect("event_json", func(json_str: String):
			_on_event_json(json_str, game_name)
		)

func _on_game_over(winner_id: int, game_name: String) -> void:
	if winner_id > 0:
		unlock("primera_victoria")
		if game_name == "checkers":
			unlock("primera_victoria_damas")
		elif game_name == "chess":
			unlock("gane_jaque_mate")
		elif game_name == "backgammon":
			unlock("estratega_backgammon")
		elif game_name == "battleship":
			unlock("comandante_flota")

func _on_event_json(json_str: String, _game_name: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var data = parser.data
		if data is Dictionary:
			var et = data.get("event_type", data.get("command_type", ""))
			if "ContinentConquered" in et or "TerritoryConquered" in et:
				if data.get("continent", "") == "Europa":
					unlock("conquiste_europa")
