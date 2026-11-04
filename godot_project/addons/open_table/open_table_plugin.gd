# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
@tool
extends EditorPlugin

func _enter_tree() -> void:
	# Registra nodos personalizados del SDK cuando el addon está activo en el editor
	if ResourceLoader.exists("res://scripts/touch_camera_controller.gd"):
		add_custom_type(
			"TouchCameraController",
			"Camera2D",
			load("res://scripts/touch_camera_controller.gd"),
			null
		)

func _exit_tree() -> void:
	remove_custom_type("TouchCameraController")
