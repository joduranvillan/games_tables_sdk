extends Control

const LanDiscoveryScript = preload("res://scripts/lan_discovery.gd")

enum ConnectionMode {
	LOCAL_LAN = 0,
	ONLINE_RELAY = 1,
}

@export var port: int = 9090
@export var join_code: String = "ABCD"
@export var host_name: String = "HostPlayer"
@export var game_type: String = "checkers"
@export var relay_url: String = "ws://127.0.0.1:8080"

var bridge
var lan_discovery: Node = null
var connection_mode: int = ConnectionMode.LOCAL_LAN
var room_code: String = "ABCD"
var player_count: int = 1  # Host counts as 1 initial player
var connected_players: Array = [1] # Array of player_ids
var discovered_lan_rooms: Array = []
var last_joined_lan_endpoint: String = ""

var mode_selector: OptionButton
var room_code_container: HBoxContainer
var room_code_label: Label
var copy_code_button: Button
var copy_feedback_label: Label
var qr_texture_rect: TextureRect
var qr_fallback_label: Label
var ip_port_label: Label
var player_count_label: Label
var player_list_vbox: VBoxContainer
var lan_rooms_section: VBoxContainer
var lan_rooms_title_label: Label
var lan_rooms_list_vbox: VBoxContainer
var lan_empty_label: Label
var start_game_button: Button
var join_room_button: Button
var status_label: Label
var join_dialog: Control = null

func _ready() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if "active_game" in gm and not String(gm.active_game).is_empty():
			game_type = String(gm.active_game)

	if bridge == null:
		if ClassDB.class_exists("OpenTableBridge"):
			bridge = ClassDB.instantiate("OpenTableBridge")
		else:
			bridge = Node.new()
		add_child(bridge)

	if lan_discovery == null:
		lan_discovery = LanDiscoveryScript.new()
		lan_discovery.name = "LanDiscovery"
		add_child(lan_discovery)
	if lan_discovery.has_signal("lan_rooms_updated"):
		var cb := Callable(self, "_on_lan_rooms_updated")
		if not lan_discovery.is_connected("lan_rooms_updated", cb):
			lan_discovery.connect("lan_rooms_updated", cb)

	if bridge.has_signal("player_joined"):
		bridge.connect("player_joined", _on_player_joined)
	elif bridge.has_signal("peer_joined"):
		bridge.connect("peer_joined", _on_player_joined)

	if bridge.has_signal("peer_disconnected"):
		bridge.connect("peer_disconnected", _on_peer_disconnected)

	if bridge.has_signal("room_created"):
		bridge.connect("room_created", _on_room_created)

	if bridge.has_signal("room_joined"):
		bridge.connect("room_joined", _on_room_joined)

	_setup_ui()
	_apply_connection_mode(connection_mode)
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
	vbox.custom_minimum_size = Vector2(460, 640)
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "🌐 Sala Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	# Selector de modo de conexión: "Local (LAN / Direct IP)" o "En Línea (Código de Sala)"
	var mode_hbox = HBoxContainer.new()
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(mode_hbox)

	var mode_lbl = Label.new()
	mode_lbl.text = "Modo:"
	mode_lbl.add_theme_font_size_override("font_size", 16)
	mode_hbox.add_child(mode_lbl)

	mode_selector = OptionButton.new()
	mode_selector.name = "ModeSelector"
	mode_selector.custom_minimum_size = Vector2(260, 38)
	mode_selector.add_item("Local (LAN / Direct IP)", ConnectionMode.LOCAL_LAN)
	mode_selector.add_item("En Línea (Código de Sala)", ConnectionMode.ONLINE_RELAY)
	mode_selector.selected = connection_mode
	mode_selector.item_selected.connect(_on_mode_selected)
	mode_hbox.add_child(mode_selector)

	# Etiqueta destacada con fuente grande y espaciada: SALA: ABCD + botón Copiar Código
	room_code_container = HBoxContainer.new()
	room_code_container.name = "RoomCodeContainer"
	room_code_container.alignment = BoxContainer.ALIGNMENT_CENTER
	room_code_container.add_theme_constant_override("separation", 14)
	vbox.add_child(room_code_container)

	room_code_label = Label.new()
	room_code_label.name = "RoomCodeLabel"
	room_code_label.text = "SALA: %s" % room_code
	room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_code_label.add_theme_font_size_override("font_size", 32)
	room_code_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	room_code_container.add_child(room_code_label)

	copy_code_button = Button.new()
	copy_code_button.name = "CopyCodeButton"
	copy_code_button.text = "Copiar Código"
	copy_code_button.custom_minimum_size = Vector2(130, 40)
	copy_code_button.add_theme_font_size_override("font_size", 15)
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	room_code_container.add_child(copy_code_button)

	copy_feedback_label = Label.new()
	copy_feedback_label.name = "CopyFeedbackLabel"
	copy_feedback_label.text = ""
	copy_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_feedback_label.add_theme_font_size_override("font_size", 14)
	copy_feedback_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	vbox.add_child(copy_feedback_label)

	# Large IP:Port text label
	var local_ip = _get_local_ip()
	ip_port_label = Label.new()
	ip_port_label.name = "IpPortLabel"
	ip_port_label.text = "IP: %s  |  Puerto: %d" % [local_ip, port]
	ip_port_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_port_label.add_theme_font_size_override("font_size", 20)
	ip_port_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(ip_port_label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Hosting en puerto %d" % port
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(status_label)

	# QR Code Container
	var qr_panel = PanelContainer.new()
	qr_panel.custom_minimum_size = Vector2(180, 180)
	vbox.add_child(qr_panel)

	qr_texture_rect = TextureRect.new()
	qr_texture_rect.custom_minimum_size = Vector2(180, 180)
	qr_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_panel.add_child(qr_texture_rect)

	qr_fallback_label = Label.new()
	qr_fallback_label.custom_minimum_size = Vector2(180, 180)
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
	player_list_vbox.custom_minimum_size = Vector2(300, 70)
	vbox.add_child(player_list_vbox)

	# Sección de Auto-Descubrimiento LAN: "Salas en tu Wi-Fi"
	lan_rooms_section = VBoxContainer.new()
	lan_rooms_section.name = "LanRoomsSection"
	lan_rooms_section.add_theme_constant_override("separation", 6)
	vbox.add_child(lan_rooms_section)

	lan_rooms_title_label = Label.new()
	lan_rooms_title_label.name = "LanRoomsTitleLabel"
	lan_rooms_title_label.text = "📡 Salas en tu Wi-Fi"
	lan_rooms_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_rooms_title_label.add_theme_font_size_override("font_size", 17)
	lan_rooms_title_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	lan_rooms_section.add_child(lan_rooms_title_label)

	lan_rooms_list_vbox = VBoxContainer.new()
	lan_rooms_list_vbox.name = "LanRoomsListVBox"
	lan_rooms_list_vbox.custom_minimum_size = Vector2(360, 48)
	lan_rooms_list_vbox.add_theme_constant_override("separation", 6)
	lan_rooms_section.add_child(lan_rooms_list_vbox)

	_render_lan_rooms_list(discovered_lan_rooms)

	# Action buttons
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	join_room_button = Button.new()
	join_room_button.name = "JoinRoomButton"
	join_room_button.text = "🔑 Unirse con Código"
	join_room_button.custom_minimum_size = Vector2(150, 44)
	join_room_button.add_theme_font_size_override("font_size", 15)
	join_room_button.pressed.connect(_on_open_join_dialog_pressed)
	hbox.add_child(join_room_button)

	var scan_btn = Button.new()
	scan_btn.text = "📷 Escanear QR"
	scan_btn.custom_minimum_size = Vector2(130, 44)
	scan_btn.add_theme_font_size_override("font_size", 15)
	scan_btn.pressed.connect(_on_scan_qr_pressed)
	hbox.add_child(scan_btn)

	var spec_btn = Button.new()
	spec_btn.text = "👁 Espectador"
	spec_btn.custom_minimum_size = Vector2(130, 44)
	spec_btn.add_theme_font_size_override("font_size", 15)
	spec_btn.pressed.connect(_on_spectator_pressed)
	hbox.add_child(spec_btn)

	start_game_button = Button.new()
	start_game_button.name = "StartGameButton"
	start_game_button.text = "🚀 Iniciar Partida"
	start_game_button.custom_minimum_size = Vector2(150, 44)
	start_game_button.add_theme_font_size_override("font_size", 16)
	start_game_button.disabled = true
	start_game_button.pressed.connect(_on_start_game_pressed)
	hbox.add_child(start_game_button)

func set_connection_mode(mode_index: int) -> void:
	if mode_selector != null:
		mode_selector.selected = mode_index
	_on_mode_selected(mode_index)

func _on_mode_selected(index: int) -> void:
	connection_mode = index
	_apply_connection_mode(index)

func _apply_connection_mode(index: int) -> void:
	if index == ConnectionMode.ONLINE_RELAY:
		if lan_discovery != null:
			lan_discovery.stop_broadcasting()
			lan_discovery.stop_listening()
		if lan_rooms_section != null:
			lan_rooms_section.hide()
		if ip_port_label != null:
			ip_port_label.text = "Relay: %s" % relay_url
		if bridge != null:
			if has_node("/root/AuthClient"):
				get_node("/root/AuthClient").call("configure_bridge_auth", bridge)
			if bridge.has_method("connect_to_relay"):
				bridge.call("connect_to_relay", relay_url)
			if bridge.has_method("create_relay_room"):
				var created_code: String = str(bridge.call("create_relay_room", game_type))
				if not created_code.is_empty():
					_set_room_code(created_code)
		if status_label != null:
			status_label.text = "En Línea | SALA: %s" % room_code
	else:
		if lan_rooms_section != null:
			lan_rooms_section.show()
		var local_ip = _get_local_ip()
		if ip_port_label != null:
			ip_port_label.text = "IP: %s  |  Puerto: %d" % [local_ip, port]
		if bridge != null and bridge.has_method("start_hosting"):
			bridge.start_hosting(port, 1, 2)
		if lan_discovery != null:
			lan_discovery.start_listening()
			lan_discovery.start_broadcasting(host_name, game_type, port, "%d/2" % player_count)
		_set_room_code(join_code)
		if status_label != null:
			status_label.text = "Hosting en puerto %d | Código: %s" % [port, join_code]

func _on_lan_rooms_updated(rooms: Array) -> void:
	discovered_lan_rooms = rooms.duplicate(true)
	_render_lan_rooms_list(discovered_lan_rooms)

func _render_lan_rooms_list(rooms: Array) -> void:
	if lan_rooms_list_vbox == null:
		return
	for child in lan_rooms_list_vbox.get_children():
		lan_rooms_list_vbox.remove_child(child)
		child.queue_free()

	if rooms.is_empty():
		lan_empty_label = Label.new()
		lan_empty_label.name = "LanEmptyLabel"
		lan_empty_label.text = "Buscando salas en tu Wi-Fi..."
		lan_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lan_empty_label.add_theme_font_size_override("font_size", 14)
		lan_empty_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
		lan_rooms_list_vbox.add_child(lan_empty_label)
		return

	for room_info in rooms:
		if not (room_info is Dictionary):
			continue
		var room_ip: String = String(room_info.get("ip", "127.0.0.1"))
		var room_port: int = int(room_info.get("port", 7000))
		var room_host: String = String(room_info.get("host_name", "Host"))
		var room_game: String = String(room_info.get("game_id", "chess"))
		var room_players: String = String(room_info.get("players", "1/2"))

		var row := HBoxContainer.new()
		row.name = "LanRoom_%s_%d" % [room_ip.replace(".", "_"), room_port]
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		lan_rooms_list_vbox.add_child(row)

		var info_lbl := Label.new()
		info_lbl.name = "RoomInfoLabel"
		info_lbl.text = "%s — %s (%s) [%s:%d]" % [room_host, room_game, room_players, room_ip, room_port]
		info_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(info_lbl)

		var join_btn := Button.new()
		join_btn.name = "JoinLanButton"
		join_btn.text = "Unirse"
		join_btn.custom_minimum_size = Vector2(88, 32)
		join_btn.pressed.connect(func():
			join_lan_room(room_ip, room_port)
		)
		row.add_child(join_btn)

func join_lan_room(target_ip: String, target_port: int) -> bool:
	var clean_ip := target_ip.strip_edges()
	if clean_ip.is_empty():
		clean_ip = "127.0.0.1"
	last_joined_lan_endpoint = "%s:%d" % [clean_ip, target_port]

	if lan_discovery != null:
		lan_discovery.stop_broadcasting()

	var connected := false
	if bridge != null:
		if bridge.has_method("connect_to_host"):
			connected = bool(bridge.call("connect_to_host", clean_ip, target_port, host_name))
		elif bridge.has_method("connect_as_client"):
			connected = bool(bridge.call("connect_as_client", clean_ip, target_port))

	if status_label != null:
		if connected:
			status_label.text = "Conectado a %s:%d" % [clean_ip, target_port]
		else:
			status_label.text = "Conectando a %s:%d..." % [clean_ip, target_port]

	return connected

func _set_room_code(code: String) -> void:
	room_code = code.strip_edges().to_upper()
	join_code = room_code
	if room_code_label != null:
		room_code_label.text = "SALA: %s" % room_code

func _on_room_created(code: String) -> void:
	_set_room_code(code)
	if status_label != null:
		status_label.text = "En Línea | SALA: %s" % room_code
	_display_qr_code()

func _on_room_joined(success: bool, player_id: int) -> void:
	if success:
		_on_player_joined(player_id)
		if status_label != null:
			status_label.text = "Unido a sala %s como Jugador %d" % [room_code, player_id]
	else:
		if status_label != null:
			status_label.text = "Error al unirse a la sala"

func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(room_code)
	if copy_code_button != null:
		copy_code_button.text = "¡Copiado!"
	if copy_feedback_label != null:
		copy_feedback_label.text = "¡Copiado!"
	if is_inside_tree():
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(copy_code_button):
				copy_code_button.text = "Copiar Código"
			if is_instance_valid(copy_feedback_label):
				copy_feedback_label.text = ""
		)

func _on_open_join_dialog_pressed() -> void:
	if join_dialog == null or not is_instance_valid(join_dialog):
		var dialog_script = load("res://join_dialog.gd")
		if dialog_script != null:
			join_dialog = dialog_script.new()
			add_child(join_dialog)
			join_dialog.setup(bridge, relay_url)
	if join_dialog != null:
		join_dialog.open(bridge)

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

func _on_peer_disconnected(player_id: int) -> void:
	if connected_players.has(player_id):
		connected_players.erase(player_id)
		player_count = connected_players.size()
		_update_player_list()

func _update_player_list() -> void:
	player_count = connected_players.size()
	if lan_discovery != null and lan_discovery.has_method("update_broadcast_players"):
		lan_discovery.update_broadcast_players(player_count, 2)
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
