# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

# Suite integral E2E de Integración de Red para lanzamiento de producción:
# 1. Persistencia y configuración de relay_url en GameManager, SettingsMenu, HostLobby y JoinDialog.
# 2. Flujo Online Relay completo: envío automático de SyncState al unirse un par, señal game_started
#    en RelayClient y traspaso del bridge a GameManager desde JoinDialog.
# 3. Bloqueo de turno por jugador local (is_local_player_turn() e is_local_turn_allowed()) en los 14 juegos
#    tanto para Host (Jugador 1) como para Cliente (Jugador 2).
# 4. Reconexión automática TCP LAN con ReconnectToken y GameManager.attempt_auto_reconnect().

const GameManagerScript = preload("res://game_manager.gd")
const SettingsMenuScript = preload("res://settings_menu.gd")
const HostLobbyScript = preload("res://host_lobby.gd")
const JoinDialogScript = preload("res://join_dialog.gd")

const ALL_14_BOARDS: Array = [
	{"game": "checkers", "script": "res://checkers_board.gd"},
	{"game": "chess", "script": "res://chess_board.gd"},
	{"game": "ludo", "script": "res://ludo_board.gd"},
	{"game": "uno", "script": "res://uno_board.gd"},
	{"game": "mille_bornes", "script": "res://mille_bornes_board.gd"},
	{"game": "monopoly", "script": "res://monopoly_board.gd"},
	{"game": "backgammon", "script": "res://backgammon_board.gd"},
	{"game": "battleship", "script": "res://battleship_board.gd"},
	{"game": "chinese_checkers", "script": "res://chinese_checkers_board.gd"},
	{"game": "crisis", "script": "res://crisis_board.gd"},
	{"game": "go", "script": "res://go_board.gd"},
	{"game": "shogi", "script": "res://shogi_board.gd"},
	{"game": "xiangqi", "script": "res://xiangqi_board.gd"},
	{"game": "goose", "script": "res://goose_board.gd"}
]

func _initialize() -> void:
	print("=== INICIANDO TEST: network_full_integration_smoke.gd ===")

	var gm = GameManagerScript.new()
	gm.name = "GameManager"
	root.add_child(gm)

	# -------------------------------------------------------------------------
	# 1. Configuración y persistencia de relay_url en GameManager, HostLobby y JoinDialog
	# -------------------------------------------------------------------------
	var custom_relay: String = "ws://127.0.0.1:9099"
	gm.set_relay_url(custom_relay)
	assert(gm.get_relay_url() == custom_relay, "GameManager debe almacenar y devolver el relay_url configurado")

	var lobby = HostLobbyScript.new()
	lobby.auto_start_on_connect = false
	lobby._setup_ui()
	lobby.set_relay_url(custom_relay)
	assert(lobby.get_relay_url() == custom_relay, "HostLobby debe permitir configurar y leer relay_url")

	var join_dlg = JoinDialogScript.new()
	root.add_child(join_dlg)
	join_dlg.set_relay_url(custom_relay)
	assert(join_dlg.get_relay_url() == custom_relay, "JoinDialog debe permitir configurar y leer relay_url")

	var settings_menu = SettingsMenuScript.new()
	root.add_child(settings_menu)
	if settings_menu.relay_url_edit != null:
		settings_menu.relay_url_edit.text = custom_relay
		settings_menu.save_settings()
		assert(gm.get_relay_url() == custom_relay, "SettingsMenu.save_settings() debe sincronizar relay_url con GameManager")

	settings_menu.free()
	join_dlg.free()
	lobby.free()

	# -------------------------------------------------------------------------
	# 2. Flujo Online Relay E2E + SyncState automático + JoinDialog -> GameManager
	# -------------------------------------------------------------------------
	var relay_host = OpenTableBridge.new()
	var relay_guest = OpenTableBridge.new()
	root.add_child(relay_host)
	root.add_child(relay_guest)

	relay_host.connect_to_relay("ws://127.0.0.1:8080")
	var room_code: String = relay_host.create_relay_room("shogi")
	assert(room_code.length() == 4, "create_relay_room debe generar un código de 4 caracteres")
	assert(relay_host.get_network_transport_kind() == "relay", "RelayHost debe reportar transporte 'relay'")
	assert(relay_host.get_network_local_player_id() == 1, "RelayHost debe tener local_player_id == 1")

	var guest_started_games: Array = []
	relay_guest.connect("game_started", func(gtype: String):
		guest_started_games.append(gtype)
	)
	relay_guest.connect_to_relay("ws://127.0.0.1:8080")
	relay_guest.join_relay_room(room_code)
	assert(relay_guest.get_network_local_player_id() == 2, "RelayClient debe tener local_player_id == 2")

	for _i in range(15):
		relay_host.poll_events()
		relay_guest.poll_events()
		OS.delay_msec(5)

	assert(relay_guest.get_current_game_type() == "shogi", "RelayClient debe sincronizar automáticamente game_type='shogi' vía SyncState al unirse")
	assert(guest_started_games.has("shogi"), "RelayClient debe emitir game_started('shogi') al recibir SyncState del Host")
	assert(relay_host.is_local_player_turn() == true, "En turno inicial (J1), is_local_player_turn() debe ser true en RelayHost")
	assert(relay_guest.is_local_player_turn() == false, "En turno inicial (J1), is_local_player_turn() debe ser false en RelayClient")

	relay_guest.free()
	relay_host.free()

	# -------------------------------------------------------------------------
	# 3. Bloqueo de turno por jugador local (is_local_turn_allowed) en los 14 tableros
	#    y sincronización en red TCP LAN para los 14 juegos
	# -------------------------------------------------------------------------
	var base_port: int = 19510
	for idx in range(ALL_14_BOARDS.size()):
		var entry: Dictionary = ALL_14_BOARDS[idx]
		var gname: String = str(entry["game"])
		var script_path: String = str(entry["script"])
		var port: int = base_port + idx

		var h_bridge = OpenTableBridge.new()
		var c_bridge = OpenTableBridge.new()
		root.add_child(h_bridge)
		root.add_child(c_bridge)

		h_bridge.start_hosting_game(port, gname, 1, 2)
		var conn_ok: bool = c_bridge.connect_to_host("127.0.0.1", port, "Cliente_" + gname)
		assert(conn_ok, "Cliente TCP debe conectar con Host para el juego '%s' en puerto %d" % [gname, port])

		for _step in range(15):
			h_bridge._process(0.02)
			c_bridge._process(0.02)
			OS.delay_msec(5)

		assert(h_bridge.set_hosted_game_type(gname), "Host debe configurar y sincronizar '%s'" % gname)
		for _step in range(15):
			h_bridge._process(0.02)
			c_bridge._process(0.02)
			OS.delay_msec(5)

		assert(c_bridge.get_current_game_type() == gname, "Cliente debe recibir game_type='%s' en SyncState" % gname)
		assert(h_bridge.get_network_local_player_id() == 1, "Host debe ser Jugador 1 en '%s'" % gname)
		assert(c_bridge.get_network_local_player_id() == 2, "Cliente debe ser Jugador 2 en '%s'" % gname)
		assert(h_bridge.is_local_player_turn() == true, "Host (J1) debe tener turno activo al inicio de '%s'" % gname)
		assert(c_bridge.is_local_player_turn() == false, "Cliente (J2) debe tener turno bloqueado al inicio de '%s'" % gname)

		var BoardScript = load(script_path)
		assert(BoardScript != null, "Debe cargar el script de tablero %s" % script_path)

		# Instanciar tablero para el Host (J1) y verificar is_local_turn_allowed() == true
		gm.register_network_bridge(h_bridge, "host", 1, gname)
		var host_board = BoardScript.new()
		root.add_child(host_board)
		assert(host_board.has_method("is_local_turn_allowed"), "El tablero '%s' debe implementar is_local_turn_allowed()" % gname)
		assert(bool(host_board.call("is_local_turn_allowed")) == true, "En turno J1, host_board.is_local_turn_allowed() debe ser true en '%s'" % gname)

		# Instanciar tablero para el Cliente (J2) y verificar is_local_turn_allowed() == false en turno de J1
		gm.register_network_bridge(c_bridge, "client", 2, gname)
		var client_board = BoardScript.new()
		root.add_child(client_board)
		assert(bool(client_board.call("is_local_turn_allowed")) == false, "En turno J1, client_board.is_local_turn_allowed() debe ser false en '%s'" % gname)

		host_board.free()
		client_board.free()
		c_bridge.free()
		h_bridge.free()

	print("✅ Bloqueo de turno por jugador local verificado en los 14 tableros")

	# -------------------------------------------------------------------------
	# 4. Reconexión automática TCP LAN con ReconnectToken y GameManager
	# -------------------------------------------------------------------------
	var reconn_port: int = 19540
	var host_reconn = OpenTableBridge.new()
	var client_reconn = OpenTableBridge.new()
	root.add_child(host_reconn)
	root.add_child(client_reconn)

	host_reconn.start_hosting_game(reconn_port, "checkers", 1, 2)
	assert(client_reconn.connect_to_host("127.0.0.1", reconn_port, "ClienteReconn"), "Cliente inicial debe conectar al puerto %d" % reconn_port)

	for _i in range(20):
		host_reconn._process(0.02)
		client_reconn._process(0.02)
		OS.delay_msec(10)

	var saved_token: String = client_reconn.get_reconnect_token()
	assert(not saved_token.is_empty(), "El Cliente debe recibir un ReconnectToken no vacío tras el Handshake")

	# Registrar en GameManager y ejecutar reconexión automática
	gm.register_network_bridge(client_reconn, "client", 2, "checkers")
	gm.set_tcp_connection_info("127.0.0.1", reconn_port, saved_token)
	var auto_reconn_ok: bool = gm.attempt_auto_reconnect()
	assert(auto_reconn_ok, "GameManager.attempt_auto_reconnect() debe iniciar reconexión TCP con el ReconnectToken")

	for _i in range(20):
		host_reconn._process(0.02)
		client_reconn._process(0.02)
		OS.delay_msec(10)

	assert(client_reconn.is_network_connected(), "El Cliente debe quedar reconectado tras attempt_auto_reconnect()")

	client_reconn.free()
	host_reconn.free()
	gm.free()

	print("PASS: network_full_integration_smoke.gd — Suite E2E de red (Relay SyncState, 14 juegos turn-lock y reconexión) verificada")
	quit(0)
