extends SceneTree

# Smoke test para Prompt 475: Auto-Descubrimiento de Partidas en Red Local (UDP Broadcast / LAN Beacon)

const LanDiscoveryScript = preload("res://scripts/lan_discovery.gd")
const HostLobbyScript = preload("res://scenes/host_lobby.gd")

class MockLanBridge extends Node:
	var last_connected_host: String = ""
	var last_connected_port: int = 0
	var last_player_name: String = ""

	func connect_to_host(host: String, p_port: int, player_name: String) -> bool:
		last_connected_host = host
		last_connected_port = p_port
		last_player_name = player_name
		return true

func _init() -> void:
	var discovery = LanDiscoveryScript.new()

	# 1. Verificar formato del paquete JSON de beacon LAN
	var beacon_json: String = discovery.build_beacon_json("MesaSala1", "chess", 7000, "1/2")
	var parsed = JSON.parse_string(beacon_json)
	if not (parsed is Dictionary):
		printerr("FAIL: El beacon generado no es un JSON Dictionary válido")
		quit(1)
		return

	if parsed.get("magic") != "OPENTABLE_LAN_V1" or parsed.get("game_id") != "chess" or int(parsed.get("port", 0)) != 7000 or parsed.get("players") != "1/2":
		printerr("FAIL: Campos inesperados en beacon JSON: %s" % beacon_json)
		quit(1)
		return

	# 2. Verificar recepción de beacon y señal lan_rooms_updated(rooms: Array)
	var emitted_snapshots: Array = []
	discovery.lan_rooms_updated.connect(func(rooms: Array):
		emitted_snapshots.append(rooms)
	)

	var ok_pkt: bool = discovery.process_incoming_packet(beacon_json, "192.168.1.45", 100.0)
	if not ok_pkt or emitted_snapshots.size() != 1:
		printerr("FAIL: process_incoming_packet no emitió lan_rooms_updated")
		quit(1)
		return

	var active: Array = discovery.get_active_rooms()
	if active.size() != 1 or active[0].get("ip") != "192.168.1.45" or int(active[0].get("port", 0)) != 7000:
		printerr("FAIL: Tabla de salas activas incorrecta: %s" % str(active))
		quit(1)
		return

	# 3. Verificar expiración tras 5 segundos sin beacon
	if discovery.prune_expired_rooms(104.0):
		printerr("FAIL: La sala no debería expirar antes de 5 segundos (t=104.0)")
		quit(1)
		return

	if not discovery.prune_expired_rooms(105.1) or discovery.get_active_rooms().size() != 0:
		printerr("FAIL: La sala debería expirar tras >= 5 segundos sin beacon (t=105.1)")
		quit(1)
		return

	# 4. Verificar integración con host_lobby.gd y unión en 1 clic a <ip_origen>:<port>
	var lobby = HostLobbyScript.new()
	var mock_bridge := MockLanBridge.new()
	lobby.bridge = mock_bridge
	lobby._setup_ui()
	lobby._on_lan_rooms_updated([
		{
			"ip": "192.168.1.45",
			"port": 7000,
			"host_name": "MesaSala1",
			"game_id": "chess",
			"players": "1/2",
		}
	])

	var joined: bool = lobby.join_lan_room("192.168.1.45", 7000)
	if not joined or mock_bridge.last_connected_host != "192.168.1.45" or mock_bridge.last_connected_port != 7000:
		printerr("FAIL: join_lan_room no conectó a 192.168.1.45:7000")
		quit(1)
		return

	lobby.free()
	discovery.free()

	print("PASS: lan_discovery_smoke.gd — UDP Beacon OPENTABLE_LAN_V1 (42423), TTL 5s y unión en 1 clic verificados")
	quit(0)
