extends SceneTree

func _initialize() -> void:
    var bridge := OpenTableBridge.new()

    # Shogi vs IA (depth 1 para velocidad)
    var ok_shogi = bridge.start_local_match_shogi_vs_ai(1, 2, 1)
    assert(ok_shogi, "Shogi vs IA debe inicializarse")
    bridge.send_command_json(1, JSON.stringify({
        "command_type": "shogi_game::MovePieceCommand",
        "player": 1,
        "from": [4, 6],
        "to": [4, 5],
        "promote": false
    }))
    for i in range(60):
        bridge._process(0.016)
        if bridge.current_player() == 1 and bridge.session_tick_count() < 3:
            bridge.send_command_json(1, JSON.stringify({
                "command_type": "shogi_game::MovePieceCommand",
                "player": 1,
                "from": [4, 5],
                "to": [4, 4],
                "promote": false
            }))
    assert(bridge.session_tick_count() > 2,
        "La IA de Shogi debe haber realizado al menos un movimiento")
    bridge.free()

    # Xiangqi vs IA (depth 1)
    bridge = OpenTableBridge.new()
    var ok_xq = bridge.start_local_match_xiangqi_vs_ai(1, 2)
    assert(ok_xq, "Xiangqi vs IA debe inicializarse")
    bridge.send_command_json(1, JSON.stringify({
        "command_type": "xiangqi_game::MovePieceCommand",
        "player": 1,
        "from": [4, 6],
        "to": [4, 5]
    }))
    for i in range(60):
        bridge._process(0.016)
        if bridge.current_player() == 1 and bridge.session_tick_count() < 3:
            bridge.send_command_json(1, JSON.stringify({
                "command_type": "xiangqi_game::MovePieceCommand",
                "player": 1,
                "from": [4, 5],
                "to": [4, 4]
            }))
    assert(bridge.session_tick_count() > 2,
        "La IA de Xiangqi debe realizado al menos un movimiento")
    bridge.free()

    quit(0)

func _notification(what: int) -> void:
    if what == 6: # NOTIFICATION_WM_CLOSE_REQUEST (Node constant, unavailable in SceneTree)
        quit(1)
