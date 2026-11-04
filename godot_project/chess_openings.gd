# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name ChessOpenings
extends RefCounted

const OPENINGS = {
	"ruy_lopez": {
		"name": "Apertura Ruy López",
		"pgn": "e4 e5 Nf3 Nc6 Bb5",
		"moves": [
			{"from": Vector2i(6, 4), "to": Vector2i(4, 4), "notation": "e4"},
			{"from": Vector2i(1, 4), "to": Vector2i(3, 4), "notation": "e5"},
			{"from": Vector2i(7, 6), "to": Vector2i(5, 5), "notation": "Nf3"},
			{"from": Vector2i(0, 1), "to": Vector2i(2, 2), "notation": "Nc6"},
			{"from": Vector2i(7, 5), "to": Vector2i(3, 1), "notation": "Bb5"}
		]
	},
	"queen_gambit": {
		"name": "Gambito de Dama",
		"pgn": "d4 d5 c4",
		"moves": [
			{"from": Vector2i(6, 3), "to": Vector2i(4, 3), "notation": "d4"},
			{"from": Vector2i(1, 3), "to": Vector2i(3, 3), "notation": "d5"},
			{"from": Vector2i(6, 2), "to": Vector2i(4, 2), "notation": "c4"}
		]
	},
	"sicilian": {
		"name": "Defensa Siciliana",
		"pgn": "e4 c5 Nf3 d6 d4",
		"moves": [
			{"from": Vector2i(6, 4), "to": Vector2i(4, 4), "notation": "e4"},
			{"from": Vector2i(1, 2), "to": Vector2i(3, 2), "notation": "c5"},
			{"from": Vector2i(7, 6), "to": Vector2i(5, 5), "notation": "Nf3"},
			{"from": Vector2i(1, 3), "to": Vector2i(2, 3), "notation": "d6"},
			{"from": Vector2i(6, 3), "to": Vector2i(4, 3), "notation": "d4"}
		]
	},
	"french": {
		"name": "Defensa Francesa",
		"pgn": "e4 e6 d4 d5",
		"moves": [
			{"from": Vector2i(6, 4), "to": Vector2i(4, 4), "notation": "e4"},
			{"from": Vector2i(1, 4), "to": Vector2i(2, 4), "notation": "e6"},
			{"from": Vector2i(6, 3), "to": Vector2i(4, 3), "notation": "d4"},
			{"from": Vector2i(1, 3), "to": Vector2i(3, 3), "notation": "d5"}
		]
	},
	"italian": {
		"name": "Apertura Italiana",
		"pgn": "e4 e5 Nf3 Nc6 Bc4",
		"moves": [
			{"from": Vector2i(6, 4), "to": Vector2i(4, 4), "notation": "e4"},
			{"from": Vector2i(1, 4), "to": Vector2i(3, 4), "notation": "e5"},
			{"from": Vector2i(7, 6), "to": Vector2i(5, 5), "notation": "Nf3"},
			{"from": Vector2i(0, 1), "to": Vector2i(2, 2), "notation": "Nc6"},
			{"from": Vector2i(7, 5), "to": Vector2i(4, 2), "notation": "Bc4"}
		]
	},
	"caro_kann": {
		"name": "Defensa Caro-Kann",
		"pgn": "e4 c6 d4 d5",
		"moves": [
			{"from": Vector2i(6, 4), "to": Vector2i(4, 4), "notation": "e4"},
			{"from": Vector2i(1, 2), "to": Vector2i(2, 2), "notation": "c6"},
			{"from": Vector2i(6, 3), "to": Vector2i(4, 3), "notation": "d4"},
			{"from": Vector2i(1, 3), "to": Vector2i(3, 3), "notation": "d5"}
		]
	}
}

static func get_openings() -> Dictionary:
	return OPENINGS

static func get_opening(key: String) -> Dictionary:
	return OPENINGS.get(key, {})
