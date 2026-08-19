extends SceneTree

func _initialize() -> void:
    var bridge := OpenTableBridge.new()

    # Shogi vs IA (depth 1 para velocidad)
    var ok_shogi := bridge.start_local_match_shogi_vs_ai(1, 2, 1)
    assert(ok_shogi, "Shogi vs IA debe inicializarse")
    for i in range(60):
        bridge._process(0.016)
    assert(bridge.session_tick_count() > 2,
        "La IA de Shogi debe haber realizado al menos un movimiento")

    # Xiangqi vs IA (depth 1)
    bridge = OpenTableBridge.new()
    var ok_xq := bridge.start_local_match_xiangqi_vs_ai(1, 2)
    assert(ok_xq, "Xiangqi vs IA debe inicializarse")
    for i in range(60):
        bridge._process(0.016)
    assert(bridge.session_tick_count() > 2,
        "La IA de Xiangqi debe haber realizado al menos un movimiento")

    quit(0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        quit(1)
