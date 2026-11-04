# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name NotificationManager
extends Node

## NotificationManager gestiona las notificaciones push locales para partidas multijugador por turnos.
##
## Plugins de terceros soportados:
## - Android: 'NotificationScheduler' (plugin GDNative / Android AAR godot-notification-scheduler)
## - iOS: 'UNUserNotificationCenter' / 'LocalNotification' (plugin nativo iOS para Godot)

static var instance: NotificationManager = null

func _ready() -> void:
	instance = self

## Programa un recordatorio de turno cuando la app está en background o en modo timer-based.
func schedule_turn_reminder(player_name: String, delay_seconds: int) -> void:
	var title = "¡Es tu turno!"
	var message = "Es el turno de %s para jugar." % player_name if player_name != "" else "Es tu turno para mover."
	
	if Engine.has_singleton("NotificationScheduler"):
		var plugin = Engine.get_singleton("NotificationScheduler")
		if plugin.has_method("schedule_notification"):
			plugin.schedule_notification(title, message, delay_seconds)
	elif Engine.has_singleton("UNUserNotificationCenter"):
		var plugin = Engine.get_singleton("UNUserNotificationCenter")
		if plugin.has_method("schedule_local_notification"):
			plugin.schedule_local_notification(title, message, delay_seconds)
	elif Engine.has_singleton("LocalNotification"):
		var plugin = Engine.get_singleton("LocalNotification")
		if plugin.has_method("schedule"):
			plugin.schedule(title, message, delay_seconds)
	else:
		print("[NotificationManager] Recordatorio de turno programado para '%s' en %d s: %s - %s" % [player_name, delay_seconds, title, message])

## Cancela todas las notificaciones pendientes.
func cancel_all_notifications() -> void:
	if Engine.has_singleton("NotificationScheduler"):
		var plugin = Engine.get_singleton("NotificationScheduler")
		if plugin.has_method("cancel_all"):
			plugin.cancel_all()
	elif Engine.has_singleton("UNUserNotificationCenter"):
		var plugin = Engine.get_singleton("UNUserNotificationCenter")
		if plugin.has_method("cancel_all"):
			plugin.cancel_all()
	elif Engine.has_singleton("LocalNotification"):
		var plugin = Engine.get_singleton("LocalNotification")
		if plugin.has_method("cancel_all"):
			plugin.cancel_all()
