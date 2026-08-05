## Adaptador de red P2P nativo para OpenTable (Android Nearby / iOS Multipeer).
## Vincula de forma transparente el nodo OpenTableBridge (Rust/GDExtension)
## con los plugins nativos de plataforma (OpenTableNearby / OpenTableMultipeer).

class_name NativeP2PAdapter
extends Node

signal offline_mode_changed(is_offline: bool)

var bridge: OpenTableBridge
var plugin: Object = null
var is_active: bool = false

var saved_player_id: int = -1
var saved_token: String = ""
var saved_join_code: String = ""
var saved_display_name: String = "Jugador"

var reconnect_timer: float = 0.0
const RECONNECT_BACKOFF: float = 3.0

var offline_check_timer: float = 0.0
const OFFLINE_CHECK_INTERVAL: float = 5.0
var is_offline_mode: bool = false
var banner_node: Node = null

func _ready() -> void:
	_detect_native_plugin()

func _process(delta: float) -> void:
	_handle_offline_check(delta)

	if not is_active or not bridge:
		return

	if bridge.is_native_connected():
		reconnect_timer = 0.0
	else:
		if saved_player_id > 0 and not saved_token.is_empty():
			reconnect_timer += delta
			if reconnect_timer >= RECONNECT_BACKOFF:
				reconnect_timer = 0.0
				print("🔄 NativeP2PAdapter: Reintentando reconexión automática tras backoff (PlayerId=%d)..." % saved_player_id)
				reconnect_client(saved_join_code, saved_player_id, saved_token, saved_display_name)

func _handle_offline_check(delta: float) -> void:
	offline_check_timer += delta
	if offline_check_timer >= OFFLINE_CHECK_INTERVAL:
		offline_check_timer = 0.0
		_check_connectivity()

func _check_connectivity() -> void:
	var connected := false
	if bridge and bridge.has_method("is_native_connected"):
		connected = bridge.is_native_connected()

	var should_be_offline = not connected and not is_active

	if should_be_offline != is_offline_mode:
		is_offline_mode = should_be_offline
		_update_offline_ui(is_offline_mode)
		offline_mode_changed.emit(is_offline_mode)

func _update_offline_ui(offline: bool) -> void:
	if offline:
		if not banner_node or not is_instance_valid(banner_node):
			_create_offline_banner()
		if banner_node and banner_node.has_method("show"):
			banner_node.show()
	else:
		if banner_node and is_instance_valid(banner_node):
			banner_node.hide()

	var scene_root = get_tree().current_scene if get_tree() else null
	if scene_root:
		_toggle_network_buttons(scene_root, not offline)

func _create_offline_banner() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "OfflineBannerCanvas"
	canvas.layer = 100

	var margin = MarginContainer.new()
	margin.anchors_preset = Control.PRESET_TOP_WIDE
	margin.anchor_right = 1.0
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.2, 0.2, 0.95)
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "⚠️ Sin conexión — solo juego local disponible"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)

	panel.add_child(label)
	margin.add_child(panel)
	canvas.add_child(margin)
	add_child(canvas)
	banner_node = canvas

func _toggle_network_buttons(node: Node, enabled: bool) -> void:
	if node is Button:
		var btn_name = node.name.to_lower()
		var btn_text = node.text.to_lower()
		if "host" in btn_name or "host" in btn_text or "client" in btn_name or "client" in btn_text or "tcp" in btn_name or "tcp" in btn_text or "network" in btn_name or node.is_in_group("network_buttons"):
			node.disabled = not enabled
	for child in node.get_children():
		_toggle_network_buttons(child, enabled)

## Detecta el singleton nativo disponible según la plataforma (Android o iOS)
func _detect_native_plugin() -> void:
	if Engine.has_singleton("OpenTableNearby"):
		plugin = Engine.get_singleton("OpenTableNearby")
		print("✅ NativeP2PAdapter: Plugin Android 'OpenTableNearby' detectado")
	elif Engine.has_singleton("OpenTableMultipeer"):
		plugin = Engine.get_singleton("OpenTableMultipeer")
		print("✅ NativeP2PAdapter: Plugin iOS 'OpenTableMultipeer' detectado")
	else:
		print("ℹ️ NativeP2PAdapter: Ningún plugin P2P nativo detectado (modo fallback o escritorio)")

## Asocia un nodo OpenTableBridge a este adaptador y conecta todas las señales bi-direccionales
func setup(target_bridge: OpenTableBridge) -> void:
	bridge = target_bridge
	if not bridge:
		push_error("NativeP2PAdapter: target_bridge es null")
		return

	# Outgoing: desde el bridge (Rust) hacia el plugin nativo (Android/iOS)
	bridge.native_send_requested.connect(_on_native_send_requested)
	bridge.native_broadcast_requested.connect(_on_native_broadcast_requested)
	if bridge.has_signal("native_handshake_established"):
		bridge.native_handshake_established.connect(_on_native_handshake_established)

	# Incoming: desde el plugin nativo (Android/iOS) hacia el bridge (Rust)
	if plugin:
		if plugin.has_signal("data_received"):
			plugin.data_received.connect(_on_plugin_data_received)
		if plugin.has_signal("peer_disconnected"):
			plugin.peer_disconnected.connect(_on_plugin_peer_disconnected)

## Inicia el rol de Host P2P
func start_hosting(join_code: String, top_player_id: int = 1, bottom_player_id: int = 2, display_name: String = "Host") -> void:
	if not bridge:
		return
	is_active = true
	saved_join_code = join_code
	saved_display_name = display_name
	bridge.start_native_hosting(top_player_id, bottom_player_id)
	if plugin:
		if plugin.has_method("startForegroundService"):
			plugin.startForegroundService()
		plugin.startHosting(join_code, display_name)
		print("🟢 NativeP2PAdapter: Anunciando sala P2P '%s' como Host" % join_code)

## Inicia el rol de Cliente P2P (auto-conexión transparente)
func start_client(join_code: String, display_name: String = "Jugador") -> void:
	if not bridge:
		return
	is_active = true
	saved_join_code = join_code
	saved_display_name = display_name
	reconnect_timer = 0.0
	bridge.start_native_client(display_name)
	if plugin:
		if plugin.has_method("startForegroundService"):
			plugin.startForegroundService()
		plugin.startDiscovery(join_code, display_name, true)
		print("🟢 NativeP2PAdapter: Buscando sala P2P '%s' como Cliente" % join_code)

## Reconecta un Cliente P2P existente mediante su player_id y token de sesión
func reconnect_client(join_code: String, player_id: int, token: String, display_name: String = "Jugador") -> void:
	if not bridge:
		return
	is_active = true
	saved_join_code = join_code
	saved_player_id = player_id
	saved_token = token
	saved_display_name = display_name
	reconnect_timer = 0.0
	bridge.reconnect_native(player_id, token)
	if plugin:
		if plugin.has_method("startForegroundService"):
			plugin.startForegroundService()
		plugin.startDiscovery(join_code, display_name, true)
		print("🟢 NativeP2PAdapter: Intentando reconexión P2P a sala '%s' (PlayerId=%d)" % [join_code, player_id])

## Detiene la publicidad, búsqueda y conexiones activas
func stop() -> void:
	is_active = false
	saved_player_id = -1
	saved_token = ""
	reconnect_timer = 0.0
	if plugin:
		if plugin.has_method("stopForegroundService"):
			plugin.stopForegroundService()
		plugin.stopAll()

# --- Handlers de Señales ----------------------------------------------------

func _on_native_send_requested(peer_tag: String, bytes: PackedByteArray) -> void:
	if plugin:
		plugin.sendBytes(peer_tag, bytes)

func _on_native_broadcast_requested(bytes: PackedByteArray) -> void:
	if plugin:
		plugin.broadcastBytes(bytes)

func _on_native_handshake_established(p_id: int, token: String) -> void:
	saved_player_id = p_id
	saved_token = token
	reconnect_timer = 0.0
	print("✅ NativeP2PAdapter: Handshake establecido (PlayerId=%d, token=%s)" % [p_id, token])

func _on_plugin_data_received(peer_tag: String, bytes: PackedByteArray) -> void:
	if bridge and is_active:
		bridge.feed_native_data_received(peer_tag, bytes)

func _on_plugin_peer_disconnected(peer_tag: String) -> void:
	if bridge and is_active:
		bridge.feed_native_peer_disconnected(peer_tag)
