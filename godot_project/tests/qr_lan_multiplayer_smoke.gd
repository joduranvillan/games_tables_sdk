# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

# Smoke test integral de conexión entre 2 jugadores humanos (no IA) por Código QR y LAN Offline:
# 1. Generación de QR LAN con IP, puerto, código de sala y tipo de juego.
# 2. Escaneo de QR desde archivo .svg, imagen .png en disco y entrada manual en QRScanner.
# 3. Auto-inicio y traspaso del bridge de red mediante GameManager (Host y Cliente).
# 4. Partida bidireccional en red local (TCP loopback sin servidor externo) con sincronización de estado.

const HostLobbyScript = preload("res://host_lobby.gd")
const QRScannerScript = preload("res://qr_scanner.gd")
const GameManagerScript = preload("res://game_manager.gd")
const MainMenuScript = preload("res://main_menu.gd")

func _initialize() -> void:
	print("=== INICIANDO TEST: qr_lan_multiplayer_smoke.gd ===")

	# 1. Verificar generación y extracción de payload QR LAN en OpenTableBridge
	var host_bridge = OpenTableBridge.new()
	var client_bridge = OpenTableBridge.new()
	root.add_child(host_bridge)
	root.add_child(client_bridge)

	var test_port: int = 19450
	host_bridge.start_hosting_game(test_port, "chess", 1, 2)
	var qr_svg: String = host_bridge.generate_lan_qr_svg("127.0.0.1", test_port, "QRLN", "MesaHost", "chess")
	assert(qr_svg.find("<svg") != -1, "generate_lan_qr_svg debe producir un SVG válido")

	var extracted_json: String = client_bridge.extract_qr_payload_json(qr_svg)
	assert(not extracted_json.is_empty(), "extract_qr_payload_json debe extraer el JSON embebido del SVG")

	# 2. Verificar QRScanner en sus 3 modalidades (archivo .svg, imagen .png y texto manual)
	var lobby = HostLobbyScript.new()
	lobby.auto_start_on_connect = false
	lobby.port = test_port
	lobby.join_code = "QRLN"
	lobby.host_name = "MesaHost"
	lobby.game_type = "chess"
	lobby.bridge = host_bridge
	lobby._setup_ui()
	lobby.set_selected_game("chess")

	var svg_path: String = "user://test_qr_match.svg"
	var png_path: String = "user://test_qr_match.png"
	assert(lobby.save_qr_to_file(svg_path), "HostLobby debe poder guardar el QR en formato .svg")
	assert(lobby.save_qr_to_file(png_path), "HostLobby debe poder guardar el QR en formato .png")

	var scanner = QRScannerScript.new()
	scanner.auto_connect_on_scan = false
	scanner._setup_ui()
	scanner.setup(client_bridge)

	assert(scanner.load_qr_from_file(svg_path), "QRScanner debe cargar y decodificar un archivo .svg de disco")
	assert(String(scanner.last_decoded_payload.get("game_type", "")) == "chess", "Payload QR desde .svg debe preservar game_type=chess")
	assert(int(scanner.last_decoded_payload.get("port", 0)) == test_port, "Payload QR desde .svg debe preservar el puerto del Host")

	scanner.last_decoded_payload = {}
	assert(scanner.load_qr_from_file(png_path), "QRScanner debe cargar y decodificar una imagen .png de disco")
	assert(String(scanner.last_decoded_payload.get("game_type", "")) == "chess", "Payload QR desde .png debe preservar game_type=chess")
	assert(int(scanner.last_decoded_payload.get("port", 0)) == test_port, "Payload QR desde .png debe preservar el puerto del Host")

	var manual_parsed: Dictionary = scanner.parse_qr_text("127.0.0.1:%d" % test_port)
	assert(String(manual_parsed.get("ip", "")) == "127.0.0.1" and int(manual_parsed.get("port", 0)) == test_port, "QRScanner debe parsear IP:Puerto manual")

	if FileAccess.file_exists(svg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(svg_path))
	if FileAccess.file_exists(png_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(png_path))

	# 3. Conectar Cliente al Host usando el payload escaneado del QR y verificar sincronización bidireccional
	var qr_payload: Dictionary = scanner.parse_qr_text(extracted_json)
	var connected_ok: bool = client_bridge.connect_to_host(
		String(qr_payload.get("ip", "127.0.0.1")),
		int(qr_payload.get("port", test_port)),
		"JugadorCliente"
	)
	assert(connected_ok, "El Cliente debe conectarse por TCP al Host usando los datos del QR")

	for _i in range(20):
		host_bridge._process(0.02)
		client_bridge._process(0.02)
		OS.delay_msec(10)

	assert(host_bridge.set_hosted_game_type("chess"), "set_hosted_game_type debe configurar ajedrez en el Host y sincronizar con el Cliente")
	for _i in range(20):
		host_bridge._process(0.02)
		client_bridge._process(0.02)
		OS.delay_msec(10)

	assert(client_bridge.get_current_game_type() == "chess", "El Cliente debe sincronizar game_type=chess al iniciar la partida")
	assert(host_bridge.current_player() == 1 and client_bridge.current_player() == 1, "Ambos jugadores deben ver turno inicial del Jugador 1")

	# Verificar traspaso de bridge mediante GameManager
	var gm = GameManagerScript.new()
	root.add_child(gm)
	gm.register_network_bridge(client_bridge, "client", 2, "chess")
	assert(gm.has_active_network_bridge(), "GameManager debe retener el bridge de red activo durante la transición de escena")
	assert(gm.get_network_local_player_id() == 2, "El jugador cliente debe quedar registrado como Jugador 2")
	var claimed = gm.claim_network_bridge(root)
	assert(claimed == client_bridge, "claim_network_bridge debe devolver la misma instancia de OpenTableBridge conectada")

	# Jugada 1: Host (Jugador 1 - Blancas) mueve peón e2 (row 1, col 4) -> e4 (row 3, col 4)
	var move_p1: String = JSON.stringify({
		"command_type": "chess_game::MovePieceCommand",
		"player": 1,
		"from": {"row": 1, "col": 4},
		"to": {"row": 3, "col": 4},
		"promote_to": null
	})
	host_bridge.send_command_json(1, move_p1)
	assert(host_bridge.current_player() == 2, "Host (J1) debe pasar turno a J2 tras mover e2->e4")

	for _i in range(25):
		host_bridge._process(0.02)
		client_bridge._process(0.02)
		if client_bridge.current_player() == 2:
			break
		OS.delay_msec(10)

	assert(client_bridge.current_player() == 2, "Tras la jugada del Host, el Cliente debe tener current_player() == 2")
	var client_legal_moves: Array = client_bridge.get_legal_moves(2)
	assert(client_legal_moves.size() > 0, "El Cliente (J2) debe poder consultar sus movimientos legales en su sesión sincronizada")

	# Jugada 2: Cliente (Jugador 2 - Negras) responde e7 (row 6, col 4) -> e5 (row 4, col 4)
	var move_p2: String = JSON.stringify({
		"command_type": "chess_game::MovePieceCommand",
		"player": 2,
		"from": {"row": 6, "col": 4},
		"to": {"row": 4, "col": 4},
		"promote_to": null
	})
	client_bridge.send_command_json(2, move_p2)

	for _i in range(25):
		host_bridge._process(0.02)
		client_bridge._process(0.02)
		if host_bridge.current_player() == 1 and client_bridge.current_player() == 1:
			break
		OS.delay_msec(10)

	assert(host_bridge.current_player() == 1 and client_bridge.current_player() == 1, "Tras la respuesta del Cliente, ambos deben volver al turno del Jugador 1")

	# 4. Verificar botones QR en el popup de cada juego en MainMenu
	var menu = MainMenuScript.new()
	root.add_child(menu)
	menu._show_mode_popup(MainMenuScript.GAMES[0])
	assert(menu.current_popup_overlay != null, "MainMenu debe abrir el popup de selección de modo")
	var host_qr_btn = menu.current_popup_overlay.find_child("HostQrPopupButton", true, false)
	var scan_qr_btn = menu.current_popup_overlay.find_child("ScanQrPopupButton", true, false)
	assert(host_qr_btn != null and scan_qr_btn != null, "El popup de cada juego debe incluir botones para Crear Partida QR/LAN y Escanear QR")
	menu._close_mode_popup()

	menu.free()
	scanner.free()
	lobby.free()
	gm.free()
	client_bridge.free()
	host_bridge.free()

	print("PASS: qr_lan_multiplayer_smoke.gd — Conexión QR/LAN entre 2 jugadores humanos sin servidor verificada")
	quit(0)
