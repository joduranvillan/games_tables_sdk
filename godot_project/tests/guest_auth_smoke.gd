extends SceneTree

# Smoke test para Prompt 469: Emisión de JWT de Invitado y Cliente de Identidad (auth_client.gd)

const AuthClientScript = preload("res://scripts/auth_client.gd")

class MockWsPeer extends RefCounted:
	var sent_messages: Array[String] = []
	func send_text(msg: String) -> void:
		sent_messages.append(msg)

func _initialize() -> void:
	var test_cfg_path: String = "user://test_identity_469.cfg"
	if FileAccess.file_exists(test_cfg_path):
		DirAccess.remove_absolute(test_cfg_path)

	var auth = AuthClientScript.new()
	auth.load_or_init_identity(test_cfg_path)

	if not AuthClientScript.is_valid_uuid_v4(auth.device_id):
		printerr("FAIL: device_id no es un UUID v4 válido: %s" % auth.device_id)
		quit(1)
		return

	if not auth.player_id.begins_with("guest_") or auth.player_id.length() != 14:
		printerr("FAIL: player_id esperado con formato guest_<hash8>, recibido: %s" % auth.player_id)
		quit(1)
		return

	var base_now: int = 1735084800
	var tok: String = auth.ensure_valid_token(base_now, test_cfg_path)
	if tok.is_empty() or tok.split(".").size() != 3:
		printerr("FAIL: JWT inválido generado en modo local: %s" % tok)
		quit(1)
		return

	if auth.expires_at != base_now + 604800:
		printerr("FAIL: expires_at esperado %d (7 días), recibido %d" % [base_now + 604800, auth.expires_at])
		quit(1)
		return

	# Verificar que con más de 24h restantes NO requiere renovación
	if auth.should_renew_token(base_now + 604800 - 90000):
		printerr("FAIL: should_renew_token devolvió true cuando faltan >24h")
		quit(1)
		return

	# Verificar que cuando faltan menos de 24h (< 86400s) SÍ renueva automáticamente
	if not auth.should_renew_token(base_now + 604800 - 3600):
		printerr("FAIL: should_renew_token devolvió false cuando falta <24h")
		quit(1)
		return

	# Verificar primer mensaje WebSocket {"op": "auth", "token": "<jwt>"}
	var ws_mock = MockWsPeer.new()
	auth.send_auth_on_websocket(ws_mock, base_now)
	if ws_mock.sent_messages.size() != 1:
		printerr("FAIL: No se envió el mensaje inicial de autenticación WebSocket")
		quit(1)
		return

	var parsed = JSON.parse_string(ws_mock.sent_messages[0])
	if not (parsed is Dictionary) or parsed.get("op") != "auth" or parsed.get("token") != tok:
		printerr("FAIL: Formato inesperado en primer mensaje auth: %s" % ws_mock.sent_messages[0])
		quit(1)
		return

	auth.free()
	if FileAccess.file_exists(test_cfg_path):
		DirAccess.remove_absolute(test_cfg_path)

	print("PASS: guest_auth_smoke.gd — UUID v4, user://identity.cfg, renovación <24h y handshake WS verificados")
	quit(0)
