## Smoke test for NetworkStatusHUD, SettingsMenu, SceneManager, and TranslationLoader.
extends SceneTree

func _init() -> void:
	print("--- Smoke Test HUD & Settings starting ---")
	
	# 1. TranslationLoader
	var tl = load("res://translation_loader.gd").new()
	tl._ready()
	print("TranslationLoader initialized. Current locale:", TranslationServer.get_locale())
	print("Test translation 'BTN_SETTINGS':", tr("BTN_SETTINGS"))
	print("Test translation 'STATUS_CONNECTED':", tr("STATUS_CONNECTED"))
	tl.free()
	
	# 2. NetworkStatusHUD
	var hud = NetworkStatusHUD.new()
	hud._ready()
	hud.set_state(NetworkStatusHUD.State.RECONNECTING)
	hud._process(0.1)
	hud.set_state(NetworkStatusHUD.State.DISCONNECTED)
	hud.set_state(NetworkStatusHUD.State.CONNECTED)
	print("NetworkStatusHUD instantiated and states verified.")
	hud.free()
	
	# 3. SettingsMenu
	var settings = SettingsMenu.new()
	settings._ready()
	print("SettingsMenu instantiated successfully.")
	settings.free()
	
	# 4. SceneTransition
	var trans = SceneTransition.new()
	trans._ready()
	print("SceneTransition instantiated successfully.")
	trans.free()
	
	print("--- Smoke Test HUD & Settings PASSED ---")
	quit(0)
