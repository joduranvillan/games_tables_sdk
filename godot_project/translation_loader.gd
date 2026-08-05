extends Node

const LANGUAGES = ["es", "en", "pt", "it", "de", "ja", "fr", "ko", "zh"]

func _ready() -> void:
	load_all_translations()
	_set_default_locale()

func load_all_translations() -> void:
	for lang in LANGUAGES:
		var path = "res://translations/%s.csv" % lang
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file != null:
				var translation = Translation.new()
				translation.locale = lang
				var is_header = true
				while not file.eof_reached():
					var line = file.get_line().strip_edges()
					if line.is_empty():
						continue
					if is_header:
						is_header = false
						continue
					
					var first_comma = line.find(",")
					if first_comma != -1:
						var key = line.substr(0, first_comma).strip_edges().trim_prefix('"').trim_suffix('"')
						var val = line.substr(first_comma + 1).strip_edges().trim_prefix('"').trim_suffix('"')
						translation.add_message(key, val)
				TranslationServer.add_translation(translation)

func _set_default_locale() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	if err == OK and cfg.has_section_key("locale", "language"):
		var lang = cfg.get_value("locale", "language")
		if lang in LANGUAGES:
			TranslationServer.set_locale(lang)
			return

	var sys_lang = OS.get_locale_language()
	if sys_lang in LANGUAGES:
		TranslationServer.set_locale(sys_lang)
	else:
		TranslationServer.set_locale("es")
