//! Native cross-platform CLI shim for `gdext` (`godot-bindings`) when building `open_table_godot`
//! on Windows, macOS, or Linux without a full GUI Godot/Redot installation.

use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let exe_dir = env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("tools"));

    for arg in &args {
        if arg == "--version" {
            println!("4.5.2.stable.redot.custom_build");
            return;
        }
        if arg == "--help" || arg == "-h" {
            println!("Godot Engine / Redot CLI shim (--dump-extension-api --dump-gdextension-interface)");
            return;
        }
    }

    for arg in &args {
        if arg == "--dump-gdextension-interface" {
            let src = exe_dir.join("gdextension_interface.h");
            if src.is_file() {
                let _ = fs::copy(&src, "gdextension_interface.h");
            }
        }
        if arg == "--dump-extension-api" || arg == "--dump-extension-api-with-docs" {
            let src = exe_dir.join("extension_api.json");
            if src.is_file() {
                let _ = fs::copy(&src, "extension_api.json");
            }
        }
    }
}
