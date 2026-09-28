extends Control

@export var port: int = 9090
@export var join_code: String = "LOBBY1"
@export var host_name: String = "HostPlayer"
@export var game_type: String = "checkers"

var bridge
var player_count: int = 1  # Host counts as 1 initial player
var connected_players: Array = [1] # Array of player_ids

var qr_texture_rect: TextureRect
var qr_fallback_label: Label
var ip_port_label: Label
var player_count_label: Label
var player_list_vbox: VBoxContainer
var start_game_button: Button
var status_label: Label

func _ready() -> void:
	if bridge == null:
		if ClassDB.class_exists("OpenTableBridge"):
			bridge = ClassDB.instantiate("OpenTableBridge")
		else:
			bridge = Node.new()
		add_child(bridge)

	if bridge.has_signal("player_joined"):
		bridge.connect("player_joined", _on_player_joined)
	elif bridge.has_signal("peer_joined"):
		bridge.connect("peer_joined", _on_player_joined)

	_setup_ui()

	if bridge.has_method("start_hosting"):
		bridge.start_hosting(port, 1, 2)
		if status_label:
			status_label.text = "Hosting en puerto %d | Código: %s" % [port, join_code]

	_update_player_list()
	_display_qr_code()

func _setup_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.18, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 600)
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "🌐 Sala LAN Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)
	
	# Large IP:Port text label
	var local_ip = _get_local_ip()
	ip_port_label = Label.new()
	ip_port_label.text = "IP: %s  |  Puerto: %d" % [local_ip, port]
	ip_port_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_port_label.add_theme_font_size_override("font_size", 20)
	ip_port_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(ip_port_label)

	status_label = Label.new()
	status_label.text = "Hosting en puerto %d" % port
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(status_label)

	# QR Code Container
	var qr_panel = PanelContainer.new()
	qr_panel.custom_minimum_size = Vector2(200, 200)
	vbox.add_child(qr_panel)

	qr_texture_rect = TextureRect.new()
	qr_texture_rect.custom_minimum_size = Vector2(200, 200)
	qr_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_panel.add_child(qr_texture_rect)

	qr_fallback_label = Label.new()
	qr_fallback_label.custom_minimum_size = Vector2(200, 200)
	qr_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qr_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qr_fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	qr_panel.add_child(qr_fallback_label)

	# Player count & list
	player_count_label = Label.new()
	player_count_label.text = "Jugadores conectados: 1"
	player_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_count_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(player_count_label)

	player_list_vbox = VBoxContainer.new()
	player_list_vbox.custom_minimum_size = Vector2(300, 80)
	vbox.add_child(player_list_vbox)

	# Action buttons
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var scan_btn = Button.new()
	scan_btn.text = "📷 Escanear QR"
	scan_btn.custom_minimum_size = Vector2(140, 44)
	scan_btn.add_theme_font_size_override("font_size", 15)
	scan_btn.pressed.connect(_on_scan_qr_pressed)
	hbox.add_child(scan_btn)

	var spec_btn = Button.new()
	spec_btn.text = "👁 Espectador"
	spec_btn.custom_minimum_size = Vector2(140, 44)
	spec_btn.add_theme_font_size_override("font_size", 15)
	spec_btn.pressed.connect(_on_spectator_pressed)
	hbox.add_child(spec_btn)

	start_game_button = Button.new()
	start_game_button.text = "🚀 Iniciar Partida"
	start_game_button.custom_minimum_size = Vector2(160, 44)
	start_game_button.add_theme_font_size_override("font_size", 16)
	start_game_button.disabled = true
	start_game_button.pressed.connect(_on_start_game_pressed)
	hbox.add_child(start_game_button)

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if not ip.begins_with("127.") and not ip.contains(":") and ip.count(".") == 3:
			return ip
	return "127.0.0.1"

func _on_spectator_pressed() -> void:
	if bridge != null and bridge.has_method("join_as_spectator"):
		bridge.call("join_as_spectator")
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to("res://spectator_view.tscn")
	else:
		get_tree().change_scene_to_file("res://spectator_view.tscn")


func _on_scan_qr_pressed() -> void:
	var scanner = QRScanner.new()
	add_child(scanner)
	scanner.open(bridge)

func _on_start_game_pressed() -> void:
	if player_count < 2:
		return

	if bridge.has_method("start_game_from_lobby"):
		bridge.start_game_from_lobby(game_type)

	var scene_path = "res://%s_board.tscn" % game_type
	if not ResourceLoader.exists(scene_path):
		scene_path = "res://checkers_board.tscn"

	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").transition_to(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

func _display_qr_code() -> void:
	var local_ip = _get_local_ip()
	var svg_str := ""
	if bridge.has_method("generate_qr_svg"):
		svg_str = bridge.generate_qr_svg(local_ip, port)
	elif bridge.has_method("generate_join_qr_svg"):
		svg_str = bridge.generate_join_qr_svg(join_code, host_name, game_type)
	elif bridge.has_method("get_join_qr_svg"):
		svg_str = bridge.get_join_qr_svg(join_code, host_name, game_type)
	else:
		svg_str = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200"><rect width="200" height="200" fill="#ffffff"/><rect x="20" y="20" width="160" height="160" fill="#000000"/></svg>'

	var tex = _render_svg(svg_str)
	if tex != null and qr_texture_rect != null:
		qr_texture_rect.texture = tex
		qr_texture_rect.show()
		qr_fallback_label.hide()
	else:
		qr_fallback_label.text = "IP: %s:%d\n(Escanea o ingresa manualmente)" % [local_ip, port]
		qr_fallback_label.show()
		qr_texture_rect.hide()

func _render_svg(svg_str: String) -> Texture2D:
	if svg_str.is_empty():
		return null
	var img := Image.new()
	var err: Error = img.load_svg_from_string(svg_str)
	if err == OK and not img.is_empty():
		return ImageTexture.create_from_image(img)

	var parser := XMLParser.new()
	var parse_err: Error = parser.parse_buffer(svg_str.to_utf8_buffer())
	if parse_err == OK:
		var canvas := Image.create(200, 200, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.WHITE)
		var drawn := false
		while parser.read() == OK:
			if parser.get_node_type() == XMLParser.NODE_ELEMENT:
				var node_name := parser.get_node_name()
				if node_name == "rect":
					var x := parser.get_named_attribute_value_safe("x").to_float()
					var y := parser.get_named_attribute_value_safe("y").to_float()
					var w := parser.get_named_attribute_value_safe("width").to_float()
					var h := parser.get_named_attribute_value_safe("height").to_float()
					var fill := parser.get_named_attribute_value_safe("fill")
					var is_black := fill.is_empty() or fill == "#000000" or fill == "black"
					var col := Color.BLACK if is_black else Color.WHITE
					if w > 0 and h > 0:
						drawn = true
						for px in range(int(x), int(x + w)):
							for py in range(int(y), int(y + h)):
								if px >= 0 and px < 200 and py >= 0 and py < 200:
									canvas.set_pixel(px, py, col)
		if drawn:
			return ImageTexture.create_from_image(canvas)
	return null

func _on_player_joined(player_id: int) -> void:
	if not connected_players.has(player_id):
		connected_players.append(player_id)
		player_count = connected_players.size()
		_update_player_list()

func _update_player_list() -> void:
	player_count = connected_players.size()
	if player_count_label:
		player_count_label.text = "Jugadores conectados: %d" % player_count

	if player_list_vbox:
		for child in player_list_vbox.get_children():
			child.queue_free()

		for pid in connected_players:
			var lbl = Label.new()
			lbl.text = "👤 Jugador %d %s" % [pid, "(Host)" if pid == 1 else ""]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color.LIGHT_GREEN if pid == 1 else Color.WHITE)
			player_list_vbox.add_child(lbl)

	if start_game_button:
		start_game_button.disabled = (player_count < 2)
