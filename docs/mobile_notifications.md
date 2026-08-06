# Notificaciones Push Locales para Multijugador por Turnos (Android e iOS)

Este documento describe la arquitectura e integración de notificaciones push locales en Godot para el modo multijugador por turnos (`notification_manager.gd`).

## Arquitectura

Cuando llega el turno de un jugador y la aplicación se encuentra en segundo plano (modo timer-based multiplayer), `NotificationManager.schedule_turn_reminder(player_name: String, delay_seconds: int)` programa una notificación push local para avisar al usuario.

## Plugins de Terceros Recomendados

### 1. Plataforma Android
- **Nombre del Plugin:** `notification_scheduler`
- **Librería Recomendada:** [godot-notification-scheduler](https://github.com/Shin-NiL/godot-notification-scheduler) o `godot-local-notification` (GDNative / Android Plugin).
- **Nombre del Singleton en Godot:** `NotificationScheduler`
- **Pasos de Integración:**
  1. Copiar el archivo `.aar` del plugin en `android/plugins/`.
  2. Habilitar el plugin en los Ajustes de Exportación de Godot (Android -> Build Personalizado -> Plugins -> NotificationScheduler).
  3. Método invocado: `schedule_notification(title: String, message: String, delay_seconds: int)`.

### 2. Plataforma iOS
- **Nombre del Plugin:** `UNUserNotificationCenter`
- **Librería Recomendada:** `godot-ios-notification` (basado en el framework nativo `UNUserNotificationCenter` de Apple).
- **Nombre del Singleton en Godot:** `UNUserNotificationCenter`
- **Pasos de Integración:**
  1. Incluir el plugin/GDExtension para iOS en `ios/plugins/`.
  2. Solicitar permisos de notificación (`UNUserNotificationCenter.requestAuthorization`) al iniciar la app.
  3. Método invocado: `schedule_local_notification(title: String, message: String, delay_seconds: int)`.

## Ejemplo de Uso en GDScript

```gdscript
# Programar un recordatorio en 30 segundos para "Jugador 2"
NotificationManager.instance.schedule_turn_reminder("Jugador 2", 30)

# Cancelar notificaciones pendientes
NotificationManager.instance.cancel_all_notifications()
```
