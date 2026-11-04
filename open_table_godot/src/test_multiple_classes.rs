// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

// Experimento: ¿gdext registra múltiples clases?
// Referencia: https://github.com/godot-rust/gdext/discussions

use godot::prelude::*;
use godot::classes::INode;

#[derive(GodotClass)]
#[class(base=Node)]
pub struct TestClassA {
    base: Base<Node>,
}

#[godot_api]
impl INode for TestClassA {
    fn init(base: Base<Node>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl TestClassA {
    #[func]
    fn class_a_method(&self) {
        godot_print!("TestClassA método");
    }
}

#[derive(GodotClass)]
#[class(base=Node)]
pub struct TestClassB {
    base: Base<Node>,
}

#[godot_api]
impl INode for TestClassB {
    fn init(base: Base<Node>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl TestClassB {
    #[func]
    fn class_b_method(&self) {
        godot_print!("TestClassB método");
    }
}
