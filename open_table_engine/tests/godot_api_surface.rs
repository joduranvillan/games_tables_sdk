use open_table_godot::OpenTableBridge;

#[test]
fn test_godot_bridge_api_surface_compilation() {
    // Verificamos estáticamente que los métodos esperados por el bridge GDScript existen
    // en OpenTableBridge y tienen firmas compatibles.

    let _f1: fn(&mut OpenTableBridge, i64, i64) = OpenTableBridge::start_local_match;
    let _f2: fn(&mut OpenTableBridge, i64, godot::prelude::GString) = OpenTableBridge::send_command_json;
    let _f3: fn(&OpenTableBridge) -> i64 = OpenTableBridge::current_player;
    let _f4: fn(&OpenTableBridge) -> godot::prelude::PackedByteArray = OpenTableBridge::export_log;
    let _f5: fn(&mut OpenTableBridge, godot::prelude::PackedByteArray, godot::prelude::GString) -> bool = OpenTableBridge::load_replay;
    let _f6: fn(&mut OpenTableBridge) -> bool = OpenTableBridge::step_replay;
    let _f7: fn(&mut OpenTableBridge, i64, i64, i64) = OpenTableBridge::start_hosting;
    let _f8: fn(&mut OpenTableBridge, godot::prelude::GString, i64, godot::prelude::GString) -> bool = OpenTableBridge::connect_to_host;

    let type_name = std::any::type_name::<OpenTableBridge>();
    assert!(type_name.contains("OpenTableBridge"));
}
