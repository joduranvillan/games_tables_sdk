# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Control

const LanDiscoveryScript = preload("res://scripts/lan_discovery.gd")

enum ConnectionMode {
	LOCAL_LAN = 0,
	ONLINE_RELAY = 1,
}

const SUPPORTED_GAMES: Array[Dictionary] = [
	{"id": "checkers", "name": "Damas (Checkers)"},
	{"id": "chess", "name": "Ajedrez (Chess)"},
	{"id": "shogi", "name": "Shogi"},
	{"id": "xiangqi", "name": "Xiangqi"},
	{"id": "go", "name": "Go"},
	{"id": "uno", "name": "Uno"},
	{"id": "crisis", "name": "Crisis (TEG)"},
	{"id": "chinese_checkers", "name": "Damas Chinas"},
	{"id": "mille_bornes", "name": "Mille Bornes"},
	{"id": "backgammon", "name": "Backgammon"},
	{"id": "monopoly", "name": "Monopoly"},
	{"id": "ludo", "name": "Ludo"},
	{"id": "battleship", "name": "Batalla Naval"},
	{"id": "goose", "name": "Juego de la Oca"},
]

@export var port: int = 9090
@export var join_code: String = "ABCD"
@export var host_name: String = "HostPlayer"
@export var game_type: String = "checkers"
@export var relay_url: String = "ws://127.0.0.1:8080"
@export var auto_start_on_connect: bool = true

var bridge
var lan_discovery: Node = null
var connection_mode: int = ConnectionMode.LOCAL_LAN
var room_code: String = "ABCD"
var player_count: int = 1  # Host counts as 1 initial player
var connected_players: Array = [1] # Array of player_ids
var discovered_lan_rooms: Array = []
var last_joined_lan_endpoint: String = ""
var current_qr_svg: String = ""
var current_qr_payload_json: String = ""
var current_qr_image: Image = null
var is_client_role: bool = false
var match_transition_triggered: bool = false

var mode_selector: OptionButton
var game_selector: OptionButton
var room_code_container: HBoxContainer
var room_code_label: Label
var copy_code_button: Button
var copy_feedback_label: Label
var qr_texture_rect: TextureRect
var qr_fallback_label: Label
var save_qr_button: Button
var copy_qr_button: Button
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
var relay_url_hbox: HBoxContainer
var relay_url_input: LineEdit
var apply_relay_button: Button
var join_dialog: Control = null
var save_qr_file_dialog: FileDialog = null

func _ready() -> void:
	var open_scanner_immediately: bool = false
	_load_saved_relay_url()
	if (is_inside_tree() and has_node("/root/GameManager")):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_active_game") and not String(gm.get_active_game()).is_empty():
			game_type = String(gm.get_active_game())
		elif "active_game" in gm and not String(gm.active_game).is_empty():
			game_type = String(gm.active_game)
		if "open_qr_scanner_on_lobby_ready" in gm and bool(gm.open_qr_scanner_on_lobby_ready):
			open_scanner_immediately = true
			gm.open_qr_scanner_on_lobby_ready = false

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

	_connect_bridge_signals()
	_setup_ui()
	_apply_connection_mode(connection_mode)
	_update_player_list()
	_display_qr_code()

	if open_scanner_immediately:
		call_deferred("_on_scan_qr_pressed")

func _load_saved_relay_url() -> void:
	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_relay_url"):
			var gm_url: String = str(gm.call("get_relay_url")).strip_edges()
			if not gm_url.is_empty():
				relay_url = gm_url
				return
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var saved: String = str(cfg.get_value("network", "relay_url", relay_url)).strip_edges()
		if not saved.is_empty():
			relay_url = saved

func set_relay_url(new_url: String) -> void:
	var clean := new_url.strip_edges()
	if clean.is_empty():
		clean = "ws://127.0.0.1:8080"
	if not clean.begins_with("ws://") and not clean.begins_with("wss://"):
		clean = "ws://" + clean
	relay_url = clean
	if relay_url_input != null and relay_url_input.text != relay_url:
		relay_url_input.text = relay_url
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("network", "relay_url", relay_url)
	cfg.save("user://settings.cfg")
	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("set_relay_url"):
			gm.call("set_relay_url", relay_url, false)
	if connection_mode == ConnectionMode.ONLINE_RELAY:
		_apply_connection_mode(ConnectionMode.ONLINE_RELAY)

func get_relay_url() -> String:
	if relay_url_input != null and not relay_url_input.text.strip_edges().is_empty():
		return relay_url_input.text.strip_edges()
	return relay_url

func _connect_bridge_signals() -> void:
	if bridge == null:
		return
	if bridge.has_signal("player_joined"):
		var cb_pj := Callable(self, "_on_player_joined")
		if not bridge.is_connected("player_joined", cb_pj):
			bridge.connect("player_joined", cb_pj)
	elif bridge.has_signal("peer_joined"):
		var cb_pej := Callable(self, "_on_player_joined")
		if not bridge.is_connected("peer_joined", cb_pej):
			bridge.connect("peer_joined", cb_pej)

	if bridge.has_signal("peer_connected"):
		var cb_pc := Callable(self, "_on_player_joined")
		if not bridge.is_connected("peer_connected", cb_pc):
			bridge.connect("peer_connected", cb_pc)

	if bridge.has_signal("peer_disconnected"):
		var cb_pd := Callable(self, "_on_peer_disconnected")
		if not bridge.is_connected("peer_disconnected", cb_pd):
			bridge.connect("peer_disconnected", cb_pd)

	if bridge.has_signal("room_created"):
		var cb_rc := Callable(self, "_on_room_created")
		if not bridge.is_connected("room_created", cb_rc):
			bridge.connect("room_created", cb_rc)

	if bridge.has_signal("room_joined"):
		var cb_rj := Callable(self, "_on_room_joined")
		if not bridge.is_connected("room_joined", cb_rj):
			bridge.connect("room_joined", cb_rj)

	if bridge.has_signal("game_started"):
		var cb_gs := Callable(self, "_on_remote_game_started")
		if not bridge.is_connected("game_started", cb_gs):
			bridge.connect("game_started", cb_gs)

func _setup_ui() -> void:
	if mode_selector != null:
		return

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
	vbox.custom_minimum_size = Vector2(480, 660)
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "🌐 Sala Multiplayer (QR / LAN)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Selector de modo de conexión: "Local (LAN / Direct IP)" o "En Línea (Código de Sala)"
	var mode_hbox = HBoxContainer.new()
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(mode_hbox)

	var mode_lbl = Label.new()
	mode_lbl.text = "Modo:"
	mode_lbl.add_theme_font_size_override("font_size", 15)
	mode_hbox.add_child(mode_lbl)

	mode_selector = OptionButton.new()
	mode_selector.name = "ModeSelector"
	mode_selector.custom_minimum_size = Vector2(250, 36)
	mode_selector.add_item("Local (LAN / QR Offline)", ConnectionMode.LOCAL_LAN)
	mode_selector.add_item("En Línea (Código de Sala)", ConnectionMode.ONLINE_RELAY)
	mode_selector.selected = connection_mode
	mode_selector.item_selected.connect(_on_mode_selected)
	mode_hbox.add_child(mode_selector)

	# Selector de Juego
	var game_hbox = HBoxContainer.new()
	game_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(game_hbox)

	var game_lbl = Label.new()
	game_lbl.text = "Juego:"
	game_lbl.add_theme_font_size_override("font_size", 15)
	game_hbox.add_child(game_lbl)

	game_selector = OptionButton.new()
	game_selector.name = "GameSelector"
	game_selector.custom_minimum_size = Vector2(250, 36)
	var selected_idx: int = 0
	for i in range(SUPPORTED_GAMES.size()):
		var g_info: Dictionary = SUPPORTED_GAMES[i]
		game_selector.add_item(str(g_info["name"]), i)
		if str(g_info["id"]) == game_type:
			selected_idx = i
	game_selector.selected = selected_idx
	game_selector.item_selected.connect(_on_game_selected)
	game_hbox.add_child(game_selector)

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
	room_code_label.add_theme_font_size_override("font_size", 28)
	room_code_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	room_code_container.add_child(room_code_label)

	copy_code_button = Button.new()
	copy_code_button.name = "CopyCodeButton"
	copy_code_button.text = "Copiar Código"
	copy_code_button.custom_minimum_size = Vector2(125, 36)
	copy_code_button.add_theme_font_size_override("font_size", 14)
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	room_code_container.add_child(copy_code_button)

	copy_feedback_label = Label.new()
	copy_feedback_label.name = "CopyFeedbackLabel"
	copy_feedback_label.text = ""
	copy_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_feedback_label.add_theme_font_size_override("font_size", 13)
	copy_feedback_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	vbox.add_child(copy_feedback_label)

	# Large IP:Port text label
	var local_ip = _get_local_ip()
	ip_port_label = Label.new()
	ip_port_label.name = "IpPortLabel"
	ip_port_label.text = "IP: %s  |  Puerto: %d" % [local_ip, port]
	ip_port_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_port_label.add_theme_font_size_override("font_size", 18)
	ip_port_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(ip_port_label)

	relay_url_hbox = HBoxContainer.new()
	relay_url_hbox.name = "RelayUrlHBox"
	relay_url_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	relay_url_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(relay_url_hbox)

	var relay_lbl := Label.new()
	relay_lbl.text = "Relay:"
	relay_lbl.add_theme_font_size_override("font_size", 14)
	relay_url_hbox.add_child(relay_lbl)

	relay_url_input = LineEdit.new()
	relay_url_input.name = "RelayUrlInput"
	relay_url_input.text = relay_url
	relay_url_input.placeholder_text = "ws://127.0.0.1:8080"
	relay_url_input.custom_minimum_size = Vector2(240, 32)
	relay_url_input.text_submitted.connect(func(new_txt: String):
		set_relay_url(new_txt)
	)
	relay_url_hbox.add_child(relay_url_input)

	apply_relay_button = Button.new()
	apply_relay_button.name = "ApplyRelayButton"
	apply_relay_button.text = "Aplicar"
	apply_relay_button.custom_minimum_size = Vector2(80, 32)
	apply_relay_button.pressed.connect(func():
		if relay_url_input != null:
			set_relay_url(relay_url_input.text)
	)
	relay_url_hbox.add_child(apply_relay_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Hosting en puerto %d" % port
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)

	# QR Code Container + Herramientas de exportación QR
	var qr_hbox = HBoxContainer.new()
	qr_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(qr_hbox)

	var qr_panel = PanelContainer.new()
	qr_panel.custom_minimum_size = Vector2(180, 180)
	qr_hbox.add_child(qr_panel)

	qr_texture_rect = TextureRect.new()
	qr_texture_rect.name = "QrTextureRect"
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

	var qr_actions_vbox = VBoxContainer.new()
	qr_actions_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_actions_vbox.add_theme_constant_override("separation", 8)
	qr_hbox.add_child(qr_actions_vbox)

	save_qr_button = Button.new()
	save_qr_button.name = "SaveQrButton"
	save_qr_button.text = "💾 Guardar QR (.png/.svg)"
	save_qr_button.custom_minimum_size = Vector2(185, 38)
	save_qr_button.pressed.connect(_on_save_qr_pressed)
	qr_actions_vbox.add_child(save_qr_button)

	copy_qr_button = Button.new()
	copy_qr_button.name = "CopyQrPayloadButton"
	copy_qr_button.text = "📋 Copiar Datos QR"
	copy_qr_button.custom_minimum_size = Vector2(185, 38)
	copy_qr_button.pressed.connect(_on_copy_qr_payload_pressed)
	qr_actions_vbox.add_child(copy_qr_button)

	# Player count & list
	player_count_label = Label.new()
	player_count_label.text = "Jugadores conectados: 1"
	player_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_count_label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(player_count_label)

	player_list_vbox = VBoxContainer.new()
	player_list_vbox.custom_minimum_size = Vector2(300, 56)
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
	lan_rooms_title_label.add_theme_font_size_override("font_size", 16)
	lan_rooms_title_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	lan_rooms_section.add_child(lan_rooms_title_label)

	lan_rooms_list_vbox = VBoxContainer.new()
	lan_rooms_list_vbox.name = "LanRoomsListVBox"
	lan_rooms_list_vbox.custom_minimum_size = Vector2(360, 44)
	lan_rooms_list_vbox.add_theme_constant_override("separation", 6)
	lan_rooms_section.add_child(lan_rooms_list_vbox)

	_render_lan_rooms_list(discovered_lan_rooms)

	# Action buttons
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	join_room_button = Button.new()
	join_room_button.name = "JoinRoomButton"
	join_room_button.text = "🔑 Unirse con Código"
	join_room_button.custom_minimum_size = Vector2(145, 42)
	join_room_button.add_theme_font_size_override("font_size", 14)
	join_room_button.pressed.connect(_on_open_join_dialog_pressed)
	hbox.add_child(join_room_button)

	var scan_btn = Button.new()
	scan_btn.name = "ScanQrButton"
	scan_btn.text = "📷 Escanear QR"
	scan_btn.custom_minimum_size = Vector2(135, 42)
	scan_btn.add_theme_font_size_override("font_size", 14)
	scan_btn.pressed.connect(_on_scan_qr_pressed)
	hbox.add_child(scan_btn)

	var spec_btn = Button.new()
	spec_btn.text = "👁 Espectador"
	spec_btn.custom_minimum_size = Vector2(120, 42)
	spec_btn.add_theme_font_size_override("font_size", 14)
	spec_btn.pressed.connect(_on_spectator_pressed)
	hbox.add_child(spec_btn)

	start_game_button = Button.new()
	start_game_button.name = "StartGameButton"
	start_game_button.text = "🚀 Iniciar Partida"
	start_game_button.custom_minimum_size = Vector2(145, 42)
	start_game_button.add_theme_font_size_override("font_size", 15)
	start_game_button.disabled = true
	start_game_button.pressed.connect(_on_start_game_pressed)
	hbox.add_child(start_game_button)

	var back_btn = Button.new()
	back_btn.name = "BackToMenuButton"
	back_btn.text = "⬅ Volver al Menú Principal"
	back_btn.custom_minimum_size = Vector2(220, 36)
	back_btn.pressed.connect(_on_back_to_menu_pressed)
	vbox.add_child(back_btn)

func _on_back_to_menu_pressed() -> void:
	if lan_discovery != null:
		lan_discovery.stop_broadcasting()
		lan_discovery.stop_listening()
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main_menu.tscn")
	elif is_inside_tree():
		get_tree().change_scene_to_file("res://main_menu.tscn")

func set_selected_game(new_game_id: String) -> void:
	if new_game_id.is_empty():
		return
	game_type = new_game_id
	if game_selector != null:
		for i in range(SUPPORTED_GAMES.size()):
			if str(SUPPORTED_GAMES[i]["id"]) == game_type:
				game_selector.selected = i
				break
	if bridge != null and bridge.has_method("set_hosted_game_type"):
		bridge.call("set_hosted_game_type", game_type)
	if is_inside_tree() and has_node("/root/GameManager"):
		get_node("/root/GameManager").set_active_game(game_type)
	if connection_mode == ConnectionMode.LOCAL_LAN and lan_discovery != null:
		lan_discovery.start_broadcasting(host_name, game_type, port, "%d/2" % player_count)
	_display_qr_code()

func _on_game_selected(index: int) -> void:
	if index >= 0 and index < SUPPORTED_GAMES.size():
		var gid: String = str(SUPPORTED_GAMES[index]["id"])
		set_selected_game(gid)

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
		if relay_url_hbox != null:
			relay_url_hbox.show()
		if ip_port_label != null:
			ip_port_label.text = "Relay: %s" % relay_url
		if bridge != null:
			if (is_inside_tree() and has_node("/root/AuthClient")):
				get_node("/root/AuthClient").call("configure_bridge_auth", bridge)
			if bridge.has_method("connect_to_relay"):
				bridge.call("connect_to_relay", relay_url)
			if bridge.has_method("create_relay_room"):
				var created_code: String = str(bridge.call("create_relay_room", game_type))
				if not created_code.is_empty():
					_set_room_code(created_code)
		if is_inside_tree() and has_node("/root/GameManager"):
			var gm = get_node("/root/GameManager")
			if gm.has_method("set_relay_connection_info"):
				gm.call("set_relay_connection_info", relay_url, room_code, true)
		if status_label != null:
			status_label.text = "En Línea | SALA: %s" % room_code
	else:
		if lan_rooms_section != null:
			lan_rooms_section.show()
		if relay_url_hbox != null:
			relay_url_hbox.hide()
		var local_ip = _get_local_ip()
		if ip_port_label != null:
			ip_port_label.text = "IP: %s  |  Puerto: %d" % [local_ip, port]
		if bridge != null:
			if bridge.has_method("start_hosting_game"):
				bridge.call("start_hosting_game", port, game_type, 1, 2)
			elif bridge.has_method("start_hosting"):
				bridge.start_hosting(port, 1, 2)
		if lan_discovery != null:
			lan_discovery.start_listening()
			lan_discovery.start_broadcasting(host_name, game_type, port, "%d/2" % player_count)
		_set_room_code(join_code)
		if status_label != null:
			status_label.text = "Hosting (%s) en puerto %d | Escanea el QR para iniciar" % [game_type, port]
	_display_qr_code()

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
			join_lan_room(room_ip, room_port, room_game)
		)
		row.add_child(join_btn)

func join_lan_room(target_ip: String, target_port: int, target_game: String = "") -> bool:
	var clean_ip := target_ip.strip_edges()
	if clean_ip.is_empty():
		clean_ip = "127.0.0.1"
	last_joined_lan_endpoint = "%s:%d" % [clean_ip, target_port]
	is_client_role = true
	if not target_game.is_empty():
		game_type = target_game

	if lan_discovery != null:
		lan_discovery.stop_broadcasting()

	var connected := false
	if bridge != null:
		if bridge.has_method("connect_to_host"):
			connected = bool(bridge.call("connect_to_host", clean_ip, target_port, host_name))
		elif bridge.has_method("connect_as_client"):
			connected = bool(bridge.call("connect_as_client", clean_ip, target_port))

	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("set_tcp_connection_info"):
			gm.call("set_tcp_connection_info", clean_ip, target_port)

	if status_label != null:
		if connected:
			status_label.text = "Conectado a %s:%d" % [clean_ip, target_port]
		else:
			status_label.text = "Conectando a %s:%d..." % [clean_ip, target_port]

	if connected and auto_start_on_connect and is_inside_tree():
		_transition_to_match_board("client", 2, game_type)

	return connected

func connect_to_host_from_qr(payload: Dictionary) -> bool:
	var target_ip: String = str(payload.get("ip", "127.0.0.1"))
	var target_port: int = int(payload.get("port", port))
	var qr_game: String = str(payload.get("game_type", ""))
	var qr_code: String = str(payload.get("join_code", ""))
	if not qr_code.is_empty():
		_set_room_code(qr_code)
	if not qr_game.is_empty():
		game_type = qr_game
	return join_lan_room(target_ip, target_port, game_type)

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

func _on_copy_qr_payload_pressed() -> void:
	var payload_to_copy: String = current_qr_payload_json
	if payload_to_copy.is_empty():
		var local_ip: String = _get_local_ip()
		payload_to_copy = JSON.stringify({
			"ip": local_ip,
			"port": port,
			"join_code": join_code,
			"host_name": host_name,
			"game_type": game_type
		})
	DisplayServer.clipboard_set(payload_to_copy)
	if copy_feedback_label != null:
		copy_feedback_label.text = "¡Datos QR copiados al portapapeles!"

func _on_save_qr_pressed() -> void:
	if save_qr_file_dialog == null or not is_instance_valid(save_qr_file_dialog):
		save_qr_file_dialog = FileDialog.new()
		save_qr_file_dialog.name = "SaveQrFileDialog"
		save_qr_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		save_qr_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		save_qr_file_dialog.current_file = "partida_%s_%s.png" % [game_type, join_code.to_lower()]
		save_qr_file_dialog.filters = PackedStringArray([
			"*.png ; Imagen PNG con QR",
			"*.svg ; Vector SVG con QR"
		])
		save_qr_file_dialog.file_selected.connect(func(path: String):
			save_qr_to_file(path)
		)
		add_child(save_qr_file_dialog)
	save_qr_file_dialog.popup_centered(Vector2i(720, 500))

## Guarda el código QR actual en disco (.svg o .png con metadatos embebidos) para compartir o escanear.
func save_qr_to_file(path: String) -> bool:
	if current_qr_svg.is_empty():
		_display_qr_code()
	var lower: String = path.to_lower()
	if lower.ends_with(".svg"):
		var f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(current_qr_svg)
		if copy_feedback_label != null:
			copy_feedback_label.text = "QR guardado en %s" % path.get_file()
		return true

	if current_qr_image == null or current_qr_image.is_empty():
		return false
	var err: Error = current_qr_image.save_png(path)
	if err == OK:
		# Guardar también el .svg lateral por compatibilidad universal
		var sidecar_svg: String = path.get_basename() + ".svg"
		var fs = FileAccess.open(sidecar_svg, FileAccess.WRITE)
		if fs != null:
			fs.store_string(current_qr_svg)
		if copy_feedback_label != null:
			copy_feedback_label.text = "QR guardado en %s" % path.get_file()
		return true
	return false

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
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://spectator_view.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://spectator_view.tscn")

func _on_scan_qr_pressed() -> void:
	var scanner = QRScanner.new()
	scanner.auto_connect_on_scan = false
	scanner.setup(bridge, discovered_lan_rooms)
	scanner.qr_payload_decoded.connect(func(payload: Dictionary):
		connect_to_host_from_qr(payload)
	)
	scanner.closed.connect(func():
		if is_instance_valid(scanner):
			scanner.queue_free()
	)
	add_child(scanner)
	scanner.open(bridge)

func _on_remote_game_started(remote_game_type: String) -> void:
	if not remote_game_type.is_empty():
		game_type = remote_game_type
	if is_inside_tree():
		_transition_to_match_board("client", 2, game_type)

func _on_start_game_pressed() -> void:
	if player_count < 2 and not is_client_role:
		return

	if bridge != null and bridge.has_method("start_game_from_lobby"):
		bridge.start_game_from_lobby(game_type)

	var role_str: String = "client" if is_client_role else "host"
	var local_pid: int = 2 if is_client_role else 1
	_transition_to_match_board(role_str, local_pid, game_type)

func _transition_to_match_board(role_str: String, local_pid: int, target_game: String) -> void:
	if match_transition_triggered:
		return
	match_transition_triggered = true

	if lan_discovery != null:
		lan_discovery.stop_broadcasting()
		lan_discovery.stop_listening()

	var resolved_game: String = target_game if not target_game.is_empty() else game_type
	if resolved_game.is_empty():
		resolved_game = "checkers"

	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("register_network_bridge") and bridge != null:
			gm.call("register_network_bridge", bridge, role_str, local_pid, resolved_game)

	var scene_path = "res://%s_board.tscn" % resolved_game
	if not ResourceLoader.exists(scene_path):
		scene_path = "res://checkers_board.tscn"

	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to(scene_path)
	else:
		if is_inside_tree() and get_tree() != null:
			get_tree().change_scene_to_file(scene_path)

func _display_qr_code() -> void:
	var local_ip = _get_local_ip()
	var svg_str := ""
	if bridge != null and bridge.has_method("generate_lan_qr_svg"):
		svg_str = str(bridge.call("generate_lan_qr_svg", local_ip, port, join_code, host_name, game_type))
	elif bridge != null and bridge.has_method("generate_qr_svg"):
		svg_str = str(bridge.call("generate_qr_svg", local_ip, port))
	elif bridge != null and bridge.has_method("generate_join_qr_svg"):
		svg_str = str(bridge.call("generate_join_qr_svg", join_code, host_name, game_type))
	elif bridge != null and bridge.has_method("get_join_qr_svg"):
		svg_str = str(bridge.call("get_join_qr_svg", join_code, host_name, game_type))
	else:
		current_qr_payload_json = JSON.stringify({
			"session_id": "%s:%d/%s" % [local_ip, port, join_code],
			"join_code": join_code,
			"host_name": host_name,
			"game_type": game_type,
			"ip": local_ip,
			"port": port
		})
		svg_str = '<!--OPENTABLE_QR_JSON:%s--><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200"><rect width="200" height="200" fill="#ffffff"/><rect x="20" y="20" width="160" height="160" fill="#000000"/></svg>' % current_qr_payload_json

	current_qr_svg = svg_str
	if bridge != null and bridge.has_method("extract_qr_payload_json"):
		var extracted: String = str(bridge.call("extract_qr_payload_json", svg_str))
		if not extracted.is_empty():
			current_qr_payload_json = extracted
	if current_qr_payload_json.is_empty():
		current_qr_payload_json = JSON.stringify({
			"session_id": "%s:%d/%s" % [local_ip, port, join_code],
			"join_code": join_code,
			"host_name": host_name,
			"game_type": game_type,
			"ip": local_ip,
			"port": port
		})

	var tex = _render_svg(svg_str)
	if tex != null and qr_texture_rect != null:
		qr_texture_rect.texture = tex
		qr_texture_rect.show()
		if qr_fallback_label != null:
			qr_fallback_label.hide()
	elif qr_fallback_label != null:
		qr_fallback_label.text = "IP: %s:%d\n(Escanea o ingresa manualmente)" % [local_ip, port]
		qr_fallback_label.show()
		if qr_texture_rect != null:
			qr_texture_rect.hide()

func _render_svg(svg_str: String) -> Texture2D:
	if svg_str.is_empty():
		return null
	var img := Image.new()
	var err: Error = img.load_svg_from_string(svg_str)
	if err == OK and not img.is_empty():
		QRScanner.encode_payload_into_image(img, current_qr_payload_json)
		current_qr_image = img
		return ImageTexture.create_from_image(img)

	var parser := XMLParser.new()
	var parse_err: Error = parser.parse_buffer(svg_str.to_utf8_buffer())
	if parse_err == OK:
		var canvas := Image.create(240, 240, false, Image.FORMAT_RGBA8)
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
								if px >= 0 and px < 240 and py >= 0 and py < 240:
									canvas.set_pixel(px, py, col)
		if drawn:
			QRScanner.encode_payload_into_image(canvas, current_qr_payload_json)
			current_qr_image = canvas
			return ImageTexture.create_from_image(canvas)
	return null

func _on_player_joined(player_id: int) -> void:
	if not connected_players.has(player_id):
		connected_players.append(player_id)
		player_count = connected_players.size()
		_update_player_list()
	if player_count >= 2 and not is_client_role and auto_start_on_connect and is_inside_tree():
		_on_start_game_pressed()

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
