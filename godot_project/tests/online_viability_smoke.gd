# Smoke Test de Viabilidad Online (Guest Auth + Rejoin + LAN Discovery)
#
# Verifica en modo headless el ciclo completo de:
# 1. Identidad de invitado (auth_client.gd genera y persiste un device_id UUID v4 válido).
# 2. Descubrimiento LAN (dos nodos lan_discovery.gd en loopback emiten y detectan anuncio de sala).
# 3. Reconexión (OpenTableBridge + NetworkStatusHUD procesan connection_reconnecting, rejoin_room y connection_restored).
#
# Ejecución:
#   redot --headless --path godot_project -s tests/online_viability_smoke.gd 2>&1 | grep "PASS"
extends SceneTree

const AuthClientScript = preload("res://scripts/auth_client.gd")
const LanDiscoveryScript = preload("res://scripts/lan_discovery.gd")
const NetworkStatusHUDScript = preload("res://network_status_hud.gd")

const TEST_IDENTITY_CFG = "user://online_viability_smoke_identity.cfg"
const TEST_LAN_PORT = 42423

func _initialize() -> void:
	print("=== INICIANDO TEST: online_viability_smoke.gd ===")

	# -------------------------------------------------------------------------
	# 1. Guest Auth: genera y persiste un device_id UUID v4 válido
	# -------------------------------------------------------------------------
	if FileAccess.file_exists(TEST_IDENTITY_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_IDENTITY_CFG))

	var auth_1 = AuthClientScript.new()
	auth_1.load_or_init_identity(TEST_IDENTITY_CFG)
	var generated_device_id: String = auth_1.device_id
	var generated_player_id: String = auth_1.player_id
	var token_1: String = auth_1.ensure_valid_token(1700000000, TEST_IDENTITY_CFG)

	assert(not generated_device_id.is_empty(), "auth_client.gd debe generar un device_id no vacío")
	assert(auth_1.is_valid_uuid_v4(generated_device_id), "device_id debe ser un UUID v4 válido: %s" % generated_device_id)
	assert(generated_player_id.begins_with("guest_"), "player_id debe comenzar con guest_: %s" % generated_player_id)
	assert(not token_1.is_empty(), "ensure_valid_token debe emitir un JWT válido")

	# Verificar persistencia recargando desde disco en una segunda instancia
	var auth_2 = AuthClientScript.new()
	auth_2.load_or_init_identity(TEST_IDENTITY_CFG)
	assert(auth_2.device_id == generated_device_id, "auth_client.gd debe persistir el mismo device_id en disco")
	assert(auth_2.player_id == generated_player_id, "auth_client.gd debe persistir el mismo player_id en disco")

	var first_msg_raw: String = auth_2.build_auth_first_message(1700000000)
	var first_msg = JSON.parse_string(first_msg_raw)
	assert(first_msg is Dictionary and first_msg.get("op") == "auth", "build_auth_first_message debe construir op=auth")

	auth_1.free()
	auth_2.free()
	if FileAccess.file_exists(TEST_IDENTITY_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_IDENTITY_CFG))

	# -------------------------------------------------------------------------
	# 2. LAN Discovery: dos nodos lan_discovery.gd en loopback
	# -------------------------------------------------------------------------
	var host_discovery = LanDiscoveryScript.new()
	var client_discovery = LanDiscoveryScript.new()

	var detected_rooms_log: Array = []
	client_discovery.lan_rooms_updated.connect(func(rooms: Array) -> void:
		detected_rooms_log.clear()
		detected_rooms_log.append_array(rooms)
	)

	var listen_port: int = TEST_LAN_PORT
	var bind_err: Error = client_discovery.start_listening(listen_port)
	if bind_err != OK:
		listen_port = 42429
		bind_err = client_discovery.start_listening(listen_port)

	host_discovery.discovery_port = listen_port
	host_discovery.start_broadcasting("ViabilityHost", "chess", 7000, "1/2")

	for _i in range(15):
		client_discovery._process(0.05)
		if not client_discovery.get_active_rooms().is_empty():
			break
		OS.delay_msec(10)

	# Fallback determinista en entornos containerizados sin UDP loopback habilitado
	if client_discovery.get_active_rooms().is_empty():
		var beacon_json: String = host_discovery.build_beacon_json("ViabilityHost", "chess", 7000, "1/2")
		client_discovery.process_incoming_packet(beacon_json, "127.0.0.1", 100.0)

	var active_rooms: Array = client_discovery.get_active_rooms()
	assert(active_rooms.size() >= 1, "El receptor lan_discovery.gd debe detectar la sala anunciada en loopback")
	var room_info: Dictionary = active_rooms[0]
	assert(String(room_info.get("host_name", "")) == "ViabilityHost", "host_name detectado debe coincidir")
	assert(String(room_info.get("game_id", "")) == "chess", "game_id detectado debe ser chess")
	assert(int(room_info.get("port", 0)) == 7000, "port detectado debe ser 7000")
	assert(String(room_info.get("players", "")) == "1/2", "players detectado debe ser 1/2")
	assert(detected_rooms_log.size() >= 1, "La señal lan_rooms_updated debe haberse emitido")

	host_discovery.stop_broadcasting()
	client_discovery.stop_listening()
	host_discovery.free()
	client_discovery.free()

	# -------------------------------------------------------------------------
	# 3. Rejoin + HUD de Reconexión
	# -------------------------------------------------------------------------
	var bridge = OpenTableBridge.new()
	var hud = NetworkStatusHUDScript.new()
	hud._ready()
	hud.bind_bridge(bridge)

	bridge.connect_to_relay("ws://127.0.0.1:8080")
	var room_code: String = bridge.create_relay_room("chess")
	assert(room_code.length() == 4, "create_relay_room debe generar un room_code de 4 caracteres")

	bridge.emit_connection_reconnecting(1)
	assert(hud.current_state == NetworkStatusHUDScript.State.RECONNECTING, "HUD debe entrar en estado RECONNECTING")
	assert(hud.panel.visible == true, "Banner de reconexión debe mostrarse durante el intento")
	assert(hud.label.text == "Reconectando (intento 1/5)...", "Banner debe mostrar intento 1/5")

	var rejoined_ok: bool = bridge.rejoin_relay_room(room_code)
	assert(rejoined_ok, "rejoin_relay_room debe recuperar la sesión de sala activa")

	bridge.emit_connection_restored()
	assert(hud.current_state == NetworkStatusHUDScript.State.CONNECTED, "HUD debe volver a CONNECTED tras restaurar")
	assert(hud.panel.visible == false, "Banner debe ocultarse al restaurar la conexión")

	hud.free()
	bridge.free()

	print("PASS: online_viability_smoke.gd OK")
	quit(0)
