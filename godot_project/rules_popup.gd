class_name RulesPopup
extends PanelContainer

const GAME_RULES: Dictionary = {
	"teg": """[b][font_size=18]Crisis (TEG) — Resumen de Reglas[/font_size][/b]

[b]1. Fases del Turno[/b]
• [b]PlaceArmies[/b]: Colocación de ejércitos al inicio del turno según territorios ocupados y bonos por continentes completados.
• [b]Attack[/b]: Declaración y ejecución de ataques a territorios enemigos adyacentes.
• [b]Fortify[/b]: Reubicación táctica de ejércitos entre territorios propios conectados.
• [b]EndPhase[/b]: Pasar a la siguiente fase o finalizar turno.

[b]2. Fórmula de Combate[/b]
• Atacante tira hasta 3 dados (según tropas en territorio atacante minus 1).
• Defensor tira hasta 3 dados (según tropas en territorio defensor).
• Se ordenan los dados de mayor a menor y se comparan uno a uno.
• [b]En caso de empate en un dado, el defensor siempre gana.[/b]

[b]3. Tipos de Objetivos Secretos y Victoria[/b]
• [b]Conquista Global[/b]: Ocupar los 30 territorios del mapa.
• [b]Objetivos Secretos[/b]:
  - Conquistar continentes específicos (ej. América del Sur + Europa).
  - Conquistar 2 continentes pequeños.
  - Exterminar a un jugador rival específico.
  - Conquistar N territorios con al menos 2 ejércitos en cada uno.

[b]4. Tarjetas y Canje[/b]
• Al conquistar al menos 1 territorio en el turno, se roba 1 tarjeta de país.
• Canje de 3 tarjetas iguales o 3 distintas otorga ejércitos acumulativos adicionales.""",

	"backgammon": """[b][font_size=18]Backgammon — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Mover las 15 fichas a lo largo de las 24 casillas en forma de triángulo hasta retirarlas (bearing off) de la tabla propia.
• [b]Tirada de dados[/b]: El jugador tira 2 dados. Si obtiene un doble, juega cada dado 2 veces (4 movimientos).
• [b]Captura (Hit)[/b]: Caer en una casilla con una sola ficha enemiga la envía a la Barra central.
• [b]Reingreso[/b]: Si tienes fichas en la barra, debes reingresarlas antes de realizar otros movimientos.""",

	"ludo": """[b][font_size=18]Ludo (Parchís) — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Llevar tus 4 fichas desde la base hasta la casilla central de llegada.
• [b]Salida[/b]: Para sacar una ficha de la base a la casilla de salida se requiere sacar un [b]6[/b] en el dado.
• [b]Captura[/b]: Caer en una casilla ocupada por una ficha rival no protegida la regresa a su base.
• [b]Turno extra[/b]: Sacar un 6 otorga un lanzamiento adicional de dado.""",

	"checkers": """[b][font_size=18]Damas (Checkers) — Resumen de Reglas[/font_size][/b]

• [b]Movimiento[/b]: Las fichas peón mueven en diagonal hacia adelante 1 casilla.
• [b]Captura obligatoria[/b]: Si hay una captura disponible, se debe realizar. Las capturas son saltando sobre fichas enemigas adyacentes.
• [b]Dama (King)[/b]: Al llegar a la última fila enemiga, la ficha promociona a Dama y puede mover hacia adelante y atrás.""",

	"chess": """[b][font_size=18]Ajedrez (Chess) — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Dar jaque mate al rey enemigo.
• [b]Piezas[/b]: Rey, Dama, Torre, Alfil, Caballo, Peón.
• [b]Enroque[/b]: Movimiento especial entre Rey y Torre si ninguna pieza se ha movido y no hay obstáculos ni jaques.
• [b]Peón al paso y Promoción[/b]: Promociona al llegar a la 8va fila.""",

	"go": """[b][font_size=18]Go — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Controlar más territorio y capturas que el rival colocándolo en intersecciones del tablero.
• [b]Libertades y Captura[/b]: Un grupo de piedras sin libertades (intersecciones adyacentes vacías) es capturado y retirado del tablero.
• [b]Regla del Ko[/b]: Prohibido repetir una posición exacta previa del tablero.""",

	"uno": """[b][font_size=18]Uno — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Descartar todas las cartas coincidiendo en color o número con la carta superior del mazo.
• [b]Especiales[/b]: Reversa, Salto, +2, Comodín y Comodín +4.""",

	"shogi": """[b][font_size=18]Shogi (Ajedrez Japonés) — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Dar jaque mate al rey rival.
• [b]Reingreso (Drop)[/b]: Las piezas capturadas pasan a tu reserva y puedes reingresarlas en cualquier casilla vacía.""",

	"xiangqi": """[b][font_size=18]Xiangqi (Ajedrez Chino) — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Dar jaque mate al General (Rey) rival.
• [b]Palacio y Río[/b]: El General y Asesores no salen del Palacio. Los Elefantes no cruzan el Río.""",

	"mille_bornes": """[b][font_size=18]Mille Bornes — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Acumular exactamente 1000 kilómetros jugando cartas de distancia.
• [b]Peligros y Reparaciones[/b]: Semáforo rojo, accidente, pinchazo, falta de gasolina y sus antídotos.""",

	"monopoly": """[b][font_size=18]Monopolio — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Arruinar a tus oponentes comprando, alquilando y negociando propiedades.
• [b]Edificación[/b]: Construye casas y hoteles al poseer el grupo de color completo.""",

	"chinese_checkers": """[b][font_size=18]Damas Chinas — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Mover tus 10 fichas a la estrella opuesta saltando sobre fichas propias o enemigas.""",

	"battleship": """[b][font_size=18]Batalla Naval (Battleship) — Resumen de Reglas[/font_size][/b]

• [b]Objetivo[/b]: Hundir la flota enemiga descubriendo la ubicación de sus barcos mediante disparos coordinados."""
}

var raw_text: String = ""
var title_label: Label
var search_line: LineEdit
var rich_label: RichTextLabel
var close_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 480)
	pivot_offset = Vector2(280, 240)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.15, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.55, 0.85, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Header hbox
	var hbox_header = HBoxContainer.new()
	vbox.add_child(hbox_header)

	title_label = Label.new()
	title_label.text = "📖 Reglas del Juego"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox_header.add_child(title_label)

	close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): visible = false)
	hbox_header.add_child(close_btn)

	# Search LineEdit
	search_line = LineEdit.new()
	search_line.placeholder_text = "🔍 Buscar en reglas (ej. combate, dado, objetivo)..."
	search_line.clear_button_enabled = true
	search_line.text_changed.connect(_on_search_changed)
	vbox.add_child(search_line)

	# Scroll Container with RichTextLabel
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	rich_label = RichTextLabel.new()
	rich_label.bbcode_enabled = true
	rich_label.custom_minimum_size = Vector2(500, 370)
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_label.add_theme_font_size_override("normal_font_size", 13)
	scroll.add_child(rich_label)

func show_for_game(game_id: String) -> void:
	var key = game_id.to_lower()
	if key == "crisis" or key == "teg":
		key = "teg"
	raw_text = GAME_RULES.get(key, GAME_RULES.get("teg", "Reglas no disponibles."))
	rich_label.text = raw_text
	search_line.text = ""
	visible = true

func _on_search_changed(new_text: String) -> void:
	var q = new_text.strip_edges()
	if q.is_empty():
		rich_label.text = raw_text
		return

	# Simple BBCode search highlighting
	var lower_raw = raw_text.to_lower()
	var lower_q = q.to_lower()

	var result_text = ""
	var last_pos = 0
	var pos = lower_raw.find(lower_q, 0)
	while pos != -1:
		result_text += raw_text.substr(last_pos, pos - last_pos)
		var matched_slice = raw_text.substr(pos, lower_q.length())
		result_text += "[color=yellow][b]%s[/b][/color]" % matched_slice
		last_pos = pos + lower_q.length()
		pos = lower_raw.find(lower_q, last_pos)

	result_text += raw_text.substr(last_pos)
	rich_label.text = result_text
