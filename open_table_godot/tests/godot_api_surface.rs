use godot::prelude::*;
use open_table_godot::OpenTableBridge;

#[test]
fn test_godot_bridge_api_surface_compilation() {
    let _f1: fn(&mut OpenTableBridge, i64, i64) = OpenTableBridge::start_local_match;
    let _f2: fn(&mut OpenTableBridge, i64, GString) = OpenTableBridge::send_command_json;
    let _f3: fn(&OpenTableBridge) -> i64 = OpenTableBridge::current_player;
    let _f4: fn(&OpenTableBridge) -> PackedByteArray = OpenTableBridge::export_log;
    let _f5: fn(&mut OpenTableBridge, PackedByteArray, GString) -> bool =
        OpenTableBridge::load_replay;
    let _f6: fn(&mut OpenTableBridge) -> bool = OpenTableBridge::step_replay;
    let _f7: fn(&mut OpenTableBridge, i64, i64, i64) = OpenTableBridge::start_hosting;
    let _f8: fn(&mut OpenTableBridge, GString, i64, GString) -> bool =
        OpenTableBridge::connect_to_host;

    let type_name = std::any::type_name::<OpenTableBridge>();
    assert!(type_name.contains("OpenTableBridge"));
}
