extends Node
class_name LanDiscovery

## Servicio de Auto-Descubrimiento de Partidas en Red Local (UDP Broadcast / LAN Beacon).
##
## - En modo Host: emite cada 1.5s un paquete UDP broadcast a `255.255.255.255:42423` con:
##   `{"magic": "OPENTABLE_LAN_V1", "host_name": "...", "game_id": "chess", "port": 7000, "players": "1/2"}`.
## - En modo Cliente: escucha en el puerto UDP `42423`, mantiene la tabla de salas activas
##   (expirando entradas sin beacon tras 5.0 segundos) y emite `lan_rooms_updated(rooms: Array)`.

signal lan_rooms_updated(rooms: Array)

const DISCOVERY_PORT: int = 42423
const BROADCAST_ADDRESS: String = "255.255.255.255"
const LOOPBACK_ADDRESS: String = "127.0.0.1"
const MAGIC_HEADER: String = "OPENTABLE_LAN_V1"
const BEACON_INTERVAL_SEC: float = 1.5
const ROOM_TTL_SEC: float = 5.0

var discovery_port: int = DISCOVERY_PORT
var is_broadcasting: bool = false
var is_listening: bool = false

var broadcast_host_name: String = "HostPlayer"
var broadcast_game_id: String = "chess"
var broadcast_port: int = 7000
var broadcast_players: String = "1/2"

var _sender_udp: PacketPeerUDP = null
var _listener_udp: PacketPeerUDP = null
var _beacon_accum: float = 0.0
var _active_rooms: Dictionary = {}

func _process(delta: float) -> void:
	if is_broadcasting:
		_beacon_accum += delta
		if _beacon_accum >= BEACON_INTERVAL_SEC:
			_beacon_accum = fmod(_beacon_accum, BEACON_INTERVAL_SEC)
			send_beacon_once()

	if is_listening and _listener_udp != null:
		while _listener_udp.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _listener_udp.get_packet()
			var sender_ip: String = _listener_udp.get_packet_ip()
			if sender_ip.is_empty():
				sender_ip = LOOPBACK_ADDRESS
			process_incoming_packet(pkt.get_string_from_utf8(), sender_ip)

	prune_expired_rooms()

func _exit_tree() -> void:
	stop_broadcasting()
	stop_listening()

## Construye el diccionario de beacon LAN según la especificación OPENTABLE_LAN_V1.
func build_beacon_payload(
	p_host_name: String = broadcast_host_name,
	p_game_id: String = broadcast_game_id,
	p_port: int = broadcast_port,
	p_players: String = broadcast_players
) -> Dictionary:
	return {
		"magic": MAGIC_HEADER,
		"host_name": p_host_name,
		"game_id": p_game_id,
		"port": int(p_port),
		"players": p_players,
	}

## Serializa el paquete beacon LAN a JSON.
func build_beacon_json(
	p_host_name: String = broadcast_host_name,
	p_game_id: String = broadcast_game_id,
	p_port: int = broadcast_port,
	p_players: String = broadcast_players
) -> String:
	return JSON.stringify(build_beacon_payload(p_host_name, p_game_id, p_port, p_players))

## Inicia la emisión periódica (cada 1.5s) de paquetes UDP broadcast al puerto 42423.
func start_broadcasting(
	p_host_name: String,
	p_game_id: String,
	p_port: int,
	p_players: String = "1/2"
) -> void:
	broadcast_host_name = p_host_name.strip_edges()
	if broadcast_host_name.is_empty():
		broadcast_host_name = "HostPlayer"
	broadcast_game_id = p_game_id.strip_edges()
	if broadcast_game_id.is_empty():
		broadcast_game_id = "chess"
	broadcast_port = int(p_port)
	broadcast_players = p_players.strip_edges()
	if broadcast_players.is_empty():
		broadcast_players = "1/2"

	if _sender_udp == null:
		_sender_udp = PacketPeerUDP.new()
	_sender_udp.set_broadcast_enabled(true)

	is_broadcasting = true
	_beacon_accum = 0.0
	send_beacon_once()

## Actualiza el contador de jugadores anunciado en el beacon (ej. "1/2" o "2/2").
func update_broadcast_players(current_players: int, max_players: int = 2) -> void:
	broadcast_players = "%d/%d" % [current_players, max_players]

## Detiene la emisión de beacons UDP y cierra el socket emisor.
func stop_broadcasting() -> void:
	is_broadcasting = false
	_beacon_accum = 0.0
	if _sender_udp != null:
		_sender_udp.close()
		_sender_udp = null

## Envía inmediatamente un paquete UDP broadcast a 255.255.255.255:42423.
func send_beacon_once() -> Error:
	if _sender_udp == null:
		_sender_udp = PacketPeerUDP.new()
		_sender_udp.set_broadcast_enabled(true)

	var json_str: String = build_beacon_json()
	var buffer: PackedByteArray = json_str.to_utf8_buffer()

	var err: Error = _sender_udp.set_dest_address(BROADCAST_ADDRESS, discovery_port)
	if err == OK:
		err = _sender_udp.put_packet(buffer)

	# Enviar también a loopback para permitir descubrimiento entre instancias locales en la misma máquina
	if _sender_udp.set_dest_address(LOOPBACK_ADDRESS, discovery_port) == OK:
		_sender_udp.put_packet(buffer)

	return err

## Inicia la escucha de beacons UDP en el puerto 42423.
func start_listening(p_port: int = DISCOVERY_PORT) -> Error:
	stop_listening()
	discovery_port = p_port
	_listener_udp = PacketPeerUDP.new()
	_listener_udp.set_broadcast_enabled(true)
	var err: Error = _listener_udp.bind(discovery_port, "*")
	if err == OK:
		is_listening = true
	else:
		_listener_udp.close()
		_listener_udp = null
		is_listening = false
	return err

## Detiene la escucha de beacons UDP y cierra el socket receptor.
func stop_listening() -> void:
	is_listening = false
	if _listener_udp != null:
		_listener_udp.close()
		_listener_udp = null

## Procesa un paquete JSON recibido desde `sender_ip`, actualiza la tabla de salas y emite `lan_rooms_updated`.
func process_incoming_packet(raw_json: String, sender_ip: String, now_sec: float = -1.0) -> bool:
	var parsed = JSON.parse_string(raw_json)
	if not (parsed is Dictionary):
		return false

	if String(parsed.get("magic", "")) != MAGIC_HEADER:
		return false

	var room_port: int = int(parsed.get("port", 0))
	if room_port <= 0 or room_port > 65535:
		return false

	var host_name_val: String = String(parsed.get("host_name", "HostPlayer")).strip_edges()
	if host_name_val.is_empty():
		host_name_val = "HostPlayer"

	var game_id_val: String = String(parsed.get("game_id", "chess")).strip_edges()
	if game_id_val.is_empty():
		game_id_val = "chess"

	var players_val: String = String(parsed.get("players", "1/2")).strip_edges()
	if players_val.is_empty():
		players_val = "1/2"

	var resolved_ip: String = sender_ip.strip_edges()
	if resolved_ip.is_empty():
		resolved_ip = LOOPBACK_ADDRESS

	var ts: float = now_sec if now_sec >= 0.0 else (Time.get_ticks_msec() / 1000.0)
	var key: String = "%s:%d" % [resolved_ip, room_port]

	_active_rooms[key] = {
		"ip": resolved_ip,
		"port": room_port,
		"host_name": host_name_val,
		"game_id": game_id_val,
		"players": players_val,
		"last_seen": ts,
	}

	lan_rooms_updated.emit(get_active_rooms())
	return true

## Elimina las salas que no hayan recibido un beacon en los últimos 5.0 segundos (`ROOM_TTL_SEC`).
func prune_expired_rooms(now_sec: float = -1.0) -> bool:
	if _active_rooms.is_empty():
		return false

	var ts: float = now_sec if now_sec >= 0.0 else (Time.get_ticks_msec() / 1000.0)
	var expired_keys: Array[String] = []

	for key in _active_rooms.keys():
		var entry: Dictionary = _active_rooms[key]
		var last_seen: float = float(entry.get("last_seen", 0.0))
		if (ts - last_seen) >= ROOM_TTL_SEC:
			expired_keys.append(String(key))

	if expired_keys.is_empty():
		return false

	for key in expired_keys:
		_active_rooms.erase(key)

	lan_rooms_updated.emit(get_active_rooms())
	return true

## Devuelve la lista ordenada de salas LAN activas actualmente.
func get_active_rooms() -> Array:
	var keys: Array = _active_rooms.keys()
	keys.sort()
	var list: Array = []
	for key in keys:
		var entry: Dictionary = _active_rooms[key]
		list.append(entry.duplicate())
	return list
