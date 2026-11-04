# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

signal guest_token_updated(token: String, player_id: String, expires_at: int)
signal guest_auth_failed(reason: String)

const IDENTITY_CONFIG_PATH := "user://identity.cfg"
const IDENTITY_SECTION := "identity"
const GUEST_TOKEN_TTL_SECS := 604800 # 7 días (7 * 24 * 3600)
const RENEWAL_THRESHOLD_SECS := 86400 # 24 horas (24 * 3600)
const DEV_DEFAULT_SECRET := "open_table_dev_local_secret"

var relay_http_url: String = "http://127.0.0.1:8081"
var online_enabled: bool = true
var device_id: String = ""
var token: String = ""
var player_id: String = ""
var expires_at: int = 0

var _http_request: HTTPRequest = null
var _request_in_flight: bool = false

func _ready() -> void:
	_load_privacy_online_preference()
	load_or_init_identity()
	if online_enabled:
		ensure_valid_token()

func _load_privacy_online_preference(settings_path: String = "user://settings.cfg") -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		var offline_only := bool(cfg.get_value("privacy", "offline_only_mode", false))
		var allow_online := bool(cfg.get_value("privacy", "online_enabled", not offline_only))
		online_enabled = allow_online and not offline_only

func set_online_enabled(enabled: bool) -> void:
	online_enabled = enabled

func is_online_enabled() -> bool:
	return online_enabled

func load_or_init_identity(config_path: String = IDENTITY_CONFIG_PATH) -> void:
	var cfg := ConfigFile.new()
	var err = cfg.load(config_path)
	if err == OK:
		device_id = str(cfg.get_value(IDENTITY_SECTION, "device_id", "")).strip_edges()
		token = str(cfg.get_value(IDENTITY_SECTION, "token", "")).strip_edges()
		player_id = str(cfg.get_value(IDENTITY_SECTION, "player_id", "")).strip_edges()
		expires_at = int(cfg.get_value(IDENTITY_SECTION, "expires_at", 0))

	if not is_valid_uuid_v4(device_id):
		device_id = generate_uuid_v4()

	if player_id.is_empty():
		player_id = derive_guest_player_id(device_id)

	save_identity(config_path)

func save_identity(config_path: String = IDENTITY_CONFIG_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(IDENTITY_SECTION, "device_id", device_id)
	cfg.set_value(IDENTITY_SECTION, "token", token)
	cfg.set_value(IDENTITY_SECTION, "player_id", player_id)
	cfg.set_value(IDENTITY_SECTION, "expires_at", expires_at)
	return cfg.save(config_path)

static func generate_uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in range(16):
		bytes[i] = rng.randi_range(0, 255)

	# RFC 4122 versión 4 y variante 10xx
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80

	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]

static func is_valid_uuid_v4(candidate: String) -> bool:
	var clean := candidate.strip_edges().to_lower()
	if clean.length() != 36:
		return false
	var parts: PackedStringArray = clean.split("-")
	if parts.size() != 5:
		return false
	if parts[0].length() != 8 or parts[1].length() != 4 or parts[2].length() != 4 or parts[3].length() != 4 or parts[4].length() != 12:
		return false
	if not parts[2].begins_with("4"):
		return false
	var variant_char := parts[3].substr(0, 1)
	return variant_char in ["8", "9", "a", "b"]

static func derive_guest_player_id(p_device_id: String) -> String:
	var clean := p_device_id.strip_edges()
	if clean.is_empty():
		clean = "anonymous"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(clean.to_utf8_buffer())
	var digest := ctx.finish()
	var hex8 := digest.slice(0, 4).hex_encode().to_lower()
	return "guest_%s" % hex8

func should_renew_token(now_unix: int = -1) -> bool:
	var now_secs := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	if token.strip_edges().is_empty():
		return true
	return (expires_at - now_secs) < RENEWAL_THRESHOLD_SECS

func ensure_valid_token(now_unix: int = -1, config_path: String = IDENTITY_CONFIG_PATH) -> String:
	if device_id.is_empty():
		load_or_init_identity(config_path)

	if should_renew_token(now_unix):
		var now_secs := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
		_issue_local_dev_token(now_secs, config_path)
		if online_enabled:
			request_guest_token_from_relay()

	return token

func _issue_local_dev_token(now_secs: int, config_path: String = IDENTITY_CONFIG_PATH) -> void:
	player_id = derive_guest_player_id(device_id)
	expires_at = now_secs + GUEST_TOKEN_TTL_SECS
	var header_b64 := _base64url_encode('{"alg":"HS256","typ":"JWT"}'.to_utf8_buffer())
	var payload_json := JSON.stringify({"sub": player_id, "exp": expires_at})
	var payload_b64 := _base64url_encode(payload_json.to_utf8_buffer())
	var signing_input := "%s.%s" % [header_b64, payload_b64]
	var crypto := Crypto.new()
	var sig := crypto.hmac_digest(HashingContext.HASH_SHA256, DEV_DEFAULT_SECRET.to_utf8_buffer(), signing_input.to_utf8_buffer())
	var sig_b64 := _base64url_encode(sig)
	token = "%s.%s" % [signing_input, sig_b64]
	save_identity(config_path)

func request_guest_token_from_relay(custom_http_url: String = "") -> bool:
	if not online_enabled:
		return false
	if _request_in_flight:
		return false
	if not is_inside_tree() or OS.has_feature("headless"):
		return false

	var base_url := custom_http_url.strip_edges() if not custom_http_url.strip_edges().is_empty() else relay_http_url
	var endpoint := "%s/auth/guest" % base_url.trim_suffix("/")

	if _http_request == null or not is_instance_valid(_http_request):
		_http_request = HTTPRequest.new()
		_http_request.timeout = 5.0
		add_child(_http_request)
		_http_request.request_completed.connect(_on_guest_auth_request_completed)

	var body := JSON.stringify({"device_id": device_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http_request.request(endpoint, headers, HTTPClient.METHOD_POST, body)
	if err == OK:
		_request_in_flight = true
		return true
	return false

func _on_guest_auth_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		guest_auth_failed.emit("http_error_%d" % response_code)
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		apply_guest_auth_response(parsed)

func apply_guest_auth_response(data: Dictionary, config_path: String = IDENTITY_CONFIG_PATH) -> bool:
	var new_token: String = str(data.get("token", "")).strip_edges()
	var new_player_id: String = str(data.get("player_id", "")).strip_edges()
	var new_expires_at: int = int(data.get("expires_at", 0))
	if new_token.is_empty() or not new_player_id.begins_with("guest_") or new_expires_at <= 0:
		return false

	token = new_token
	player_id = new_player_id
	expires_at = new_expires_at
	save_identity(config_path)
	guest_token_updated.emit(token, player_id, expires_at)
	return true

func build_auth_first_message(now_unix: int = -1) -> String:
	var active_token := ensure_valid_token(now_unix)
	return JSON.stringify({
		"op": "auth",
		"token": active_token,
	})

func send_auth_on_websocket(ws_peer: Object, now_unix: int = -1) -> bool:
	if ws_peer == null:
		return false
	var msg := build_auth_first_message(now_unix)
	if ws_peer.has_method("send_text"):
		ws_peer.call("send_text", msg)
		return true
	if ws_peer.has_method("set_relay_auth_token"):
		ws_peer.call("set_relay_auth_token", token)
		return true
	return false

func configure_bridge_auth(bridge: Object, now_unix: int = -1) -> void:
	if bridge == null:
		return
	var active_token := ensure_valid_token(now_unix)
	if bridge.has_method("set_relay_auth_token"):
		bridge.call("set_relay_auth_token", active_token)

static func _base64url_encode(bytes: PackedByteArray) -> String:
	var b64 := Marshalls.raw_to_base64(bytes)
	return b64.replace("+", "-").replace("/", "_").trim_suffix("=")
