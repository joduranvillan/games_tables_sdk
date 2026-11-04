# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

func _ready():
	print("TEST: Intentando crear OpenTableBridge...")
	var bridge = OpenTableBridge.new()
	print("TEST: ✅ OpenTableBridge creado: ", bridge)
	print("TEST: ✅ Todas las clases se cargaron correctamente")
	get_tree().quit()
