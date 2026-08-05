## CanvasLayer overlay para el estado de la red (Conectado, Reconectando, Desconectado).
class_name NetworkStatusHUD
extends CanvasLayer

enum State { CONNECTED, RECONNECTING, DISCONNECTED }

var current_state: State = State.CONNECTED
var panel: PanelContainer
var label: Label
var style_box: StyleBoxFlat
var blink_time: float = 0.0

func _ready() -> void:
	layer = 95
	_build_ui()
	set_state(State.CONNECTED)

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 36)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -120
	panel.offset_right = 120
	panel.offset_top = 8
	panel.offset_bottom = 44

	style_box = StyleBoxFlat.new()
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	style_box.content_margin_top = 6
	style_box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style_box)

	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)

	add_child(panel)

func bind_bridge(bridge: Node) -> void:
	if bridge == null: return
	
	if bridge.has_signal("connection_lost"):
		bridge.connect("connection_lost", Callable(self, "_on_connection_lost"))
	if bridge.has_signal("disconnected"):
		bridge.connect("disconnected", Callable(self, "_on_disconnected"))
	if bridge.has_signal("reconnecting"):
		bridge.connect("reconnecting", Callable(self, "_on_reconnecting"))
	if bridge.has_signal("reconnected"):
		bridge.connect("reconnected", Callable(self, "_on_reconnected"))
	if bridge.has_signal("connected"):
		bridge.connect("connected", Callable(self, "_on_connected"))

func set_state(state: State) -> void:
	current_state = state
	match current_state:
		State.CONNECTED:
			style_box.bg_color = Color(0.18, 0.65, 0.32, 0.95)
			label.text = "🟢 " + tr("STATUS_CONNECTED")
			panel.modulate.a = 1.0
		State.RECONNECTING:
			style_box.bg_color = Color(0.9, 0.68, 0.1, 0.95)
			label.text = "🟡 " + tr("STATUS_RECONNECTING")
			blink_time = 0.0
		State.DISCONNECTED:
			style_box.bg_color = Color(0.85, 0.22, 0.22, 0.95)
			label.text = "🔴 " + tr("STATUS_DISCONNECTED")
			panel.modulate.a = 1.0

func _on_connection_lost() -> void:
	set_state(State.RECONNECTING)

func _on_disconnected() -> void:
	set_state(State.DISCONNECTED)

func _on_reconnecting() -> void:
	set_state(State.RECONNECTING)

func _on_reconnected(_arg = null) -> void:
	set_state(State.CONNECTED)

func _on_connected(_arg = null) -> void:
	set_state(State.CONNECTED)

func _process(delta: float) -> void:
	if current_state == State.RECONNECTING:
		blink_time += delta * 6.0
		panel.modulate.a = 0.3 + 0.7 * abs(sin(blink_time))
	else:
		panel.modulate.a = 1.0
