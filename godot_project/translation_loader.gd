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

	_load_multilingual_csv("res://assets/translations/translations.csv")

func _load_multilingual_csv(csv_path: String) -> void:
	if not FileAccess.file_exists(csv_path):
		return
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
	if header.size() < 2:
		file.close()
		return
	var translations_by_col: Dictionary = {}
	for col_idx in range(1, header.size()):
		var lang_code := header[col_idx].strip_edges()
		if not lang_code.is_empty():
			var tr_obj := Translation.new()
			tr_obj.locale = lang_code
			translations_by_col[col_idx] = tr_obj

	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2:
			continue
		var key := row[0].strip_edges()
		if key.is_empty():
			continue
		for c_idx in translations_by_col.keys():
			if c_idx < row.size():
				var tr_obj: Translation = translations_by_col[c_idx]
				tr_obj.add_message(key, row[c_idx].strip_edges())
	file.close()

	for col_idx in translations_by_col.keys():
		TranslationServer.add_translation(translations_by_col[col_idx])

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
