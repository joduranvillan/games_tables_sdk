extends Node

## Gestor de vibración háptica móvil (iOS y Android) — Tarea 491.
## Wrapper seguro sobre `Input.vibrate_handheld` con intensidades `light_tap()`,
## `medium_impact()` y `victory_pulse()`.
## En dispositivos de escritorio o cuando la vibración está desactivada en `user://settings.cfg`,
## todas las llamadas actúan como un no-op seguro.

signal haptics_toggled(enabled: bool)
signal vibration_triggered(pattern_name: String, duration_ms: int, amplitude: float)

const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"

const LIGHT_TAP_MS: int = 18
const LIGHT_TAP_AMPLITUDE: float = 0.35

const MEDIUM_IMPACT_MS: int = 40
const MEDIUM_IMPACT_AMPLITUDE: float = 0.70

const VICTORY_PULSE_MS: int = 90
const VICTORY_PULSE_AMPLITUDE: float = 1.0

var haptics_enabled: bool = true
var simulate_handheld_for_tests: bool = false
var last_vibration_pattern: String = ""
var last_vibration_duration_ms: int = 0
var vibration_count: int = 0

func _ready() -> void:
	load_from_config(DEFAULT_SETTINGS_PATH)

func is_handheld_device() -> bool:
	if simulate_handheld_for_tests:
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"

func set_haptics_enabled(enabled: bool, cfg_path: String = "") -> void:
	haptics_enabled = enabled
	if not cfg_path.is_empty():
		save_to_config(cfg_path)
	haptics_toggled.emit(haptics_enabled)

func is_haptics_enabled() -> bool:
	return haptics_enabled

func load_from_config(cfg_path: String = DEFAULT_SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return
	if cfg.has_section_key("accessibility", "haptics_enabled"):
		haptics_enabled = bool(cfg.get_value("accessibility", "haptics_enabled", true))
	elif cfg.has_section_key("gameplay", "haptics_enabled"):
		haptics_enabled = bool(cfg.get_value("gameplay", "haptics_enabled", true))

func save_to_config(cfg_path: String = DEFAULT_SETTINGS_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	cfg.set_value("accessibility", "haptics_enabled", haptics_enabled)
	return cfg.save(cfg_path)

func light_tap() -> bool:
	return _trigger_vibration("light_tap", LIGHT_TAP_MS, LIGHT_TAP_AMPLITUDE)

func medium_impact() -> bool:
	return _trigger_vibration("medium_impact", MEDIUM_IMPACT_MS, MEDIUM_IMPACT_AMPLITUDE)

func victory_pulse() -> bool:
	return _trigger_vibration("victory_pulse", VICTORY_PULSE_MS, VICTORY_PULSE_AMPLITUDE)

func _trigger_vibration(pattern_name: String, duration_ms: int, amplitude: float = -1.0) -> bool:
	# En escritorio o cuando la vibración está desactivada en settings.cfg, es un no-op seguro.
	if not haptics_enabled or not is_handheld_device():
		return false

	last_vibration_pattern = pattern_name
	last_vibration_duration_ms = duration_ms
	vibration_count += 1

	if not OS.has_feature("headless"):
		Input.vibrate_handheld(duration_ms, amplitude)

	vibration_triggered.emit(pattern_name, duration_ms, amplitude)
	return true
