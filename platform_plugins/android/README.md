# Integrar `OpenTableNearbyPlugin.kt` en un proyecto Godot Android

No compilado ni probado acá (no hay Android Studio en el sandbox).
La estructura Gradle + AndroidManifest ya está armada. Esto es la checklist
de lo que hace falta para que Godot lo cargue como plugin — compilación
local, empaquetado en AAR, integración en Godot.

## 1. Estructura Gradle (YA EXISTE)

La estructura está armada en este directorio:

```
platform_plugins/
  settings.gradle.kts       # incluye módulo :android
  gradle.properties         # configuración global
  android/
    build.gradle.kts        # dependencias: godot, play-services-nearby
    src/main/
      java/org/opentable/network/nearby/OpenTableNearbyPlugin.kt
      AndroidManifest.xml   # todos los permisos necesarios
```

### 1.1 Compilar el plugin localmente

Desde `platform_plugins/`:

```bash
# Limpiar builds previos
./gradlew clean

# Compilar el módulo Android
./gradlew assembleRelease
# (O alternativamente: ./gradlew :android:assembleRelease)

# El AAR se genera en:
# platform_plugins/android/build/outputs/aar/android-release.aar
```

Si ves errores de compilación Kotlin o dependencias missing, revisá que
Android Studio tenga instalada la versión de Android SDK (API 34) y Gradle
(8.0+) que el `build.gradle.kts` pide.

## 2. Permisos y Compatibilidad por Versión de Android (API Levels)

Nearby Connections y el servicio en segundo plano requieren la declaración de permisos específicos según el nivel de API de Android:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />

<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />

<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation" />

<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />

<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />
```

### Desglose por Versión de Android:

- **Android 6.0 a 11 (API 23 - 30)**:
  - `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`: Requerido obligatoriamente en runtime para escaneo y publicidad vía Bluetooth LE y Wi-Fi Direct.
  - `BLUETOOTH` y `BLUETOOTH_ADMIN`: Para controlar el radio Bluetooth.
  - `ACCESS_WIFI_STATE` y `CHANGE_WIFI_STATE`: Para Wi-Fi Direct / Local Hotspot.

- **Android 12 (API ≥ 31)**:
  - Requiere los nuevos permisos granulares de Bluetooth:
    - `BLUETOOTH_SCAN`: Escaneo de dispositivos cercanos. Bandera `neverForLocation` indica que el escaneo no se usa para derivar la ubicación del usuario.
    - `BLUETOOTH_ADVERTISE`: Anuncio de sala P2P para que otros jugadores descubran el host.
    - `BLUETOOTH_CONNECT`: Establecimiento del socket de conexión Bluetooth entre pares.

- **Android 13 (API ≥ 33)**:
  - `NEARBY_WIFI_DEVICES`: Permite el descubrimiento y conexión por Wi-Fi Direct/P2P sin necesidad de solicitar permisos de ubicación GPS al usuario.

- **Android 14+ (API ≥ 34)**:
  - `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_CONNECTED_DEVICE`: Requerido para iniciar `OpenTableNearbyService` con tipo de servicio `connectedDevice` (`android:foregroundServiceType="connectedDevice"`).

## 2.1 Ciclo de Vida del Servicio Foreground (`OpenTableNearbyService`)

Para evitar que Android destruya la conexión P2P o pause los sockets cuando la aplicación pasa a segundo plano (p. ej., pantalla apagada, minimizar app), el plugin cuenta con `OpenTableNearbyService.kt`:

1. **Inicio (`startForegroundService`)**:
   - `NativeP2PAdapter` o el desarrollador llama `nearby.startForegroundService()` al iniciar la publicidad o búsqueda de sala.
   - Crea un `NotificationChannel` de prioridad baja (`IMPORTANCE_LOW`) para Android 8.0+.
   - Llama a `startForeground(...)` asociando la notificación con el tipo `FOREGROUND_SERVICE_CONNECTED_DEVICE` (API 29+).

2. **Ejecución Continua**:
   - El servicio retorna `START_STICKY`, garantizando que el sistema operativo mantenga vivo el proceso del plugin mientras la partida esté activa.

3. **Detención (`stopForegroundService` / `stopAll`)**:
   - Al finalizar la partida o cerrar la sala, `nearby.stopAll()` invoca `stopForegroundService()`, deteniendo el servicio y removiendo la notificación persistente.

En **runtime** (Android 6+), el app también pide permisos interactivamente.
Eso se configura en el proyecto Godot que consume este plugin.

## 3. Archivo de configuración del plugin (`.gdap`)

Godot 4 identifica plugins Android nativos vía un archivo `.gdap` en la
raíz del proyecto Godot (NO en este directorio):

**Ubicación:** `[TU_PROYECTO_GODOT]/OpenTableNearby.gdap`

**Contenido:**

```ini
[config]
name="OpenTableNearby"
binary_type="local"
binary="res://addons/opentable_nearby/bin/OpenTableNearby.aar"

[dependencies]
remote=["com.google.android.gms:play-services-nearby:19.3.0"]
```

**Pasos para compilar y copiar el AAR:**
1. Compilá este plugin localmente desde `platform_plugins/`:
   ```bash
   ./gradlew assembleRelease
   ```
2. Copiá el AAR generado:
   ```bash
   mkdir -p godot_project/addons/opentable_nearby/bin
   cp platform_plugins/android/build/outputs/aar/android-release.aar godot_project/addons/opentable_nearby/bin/OpenTableNearby.aar
   ```
3. En Godot, vas a Proyecto → Configuración del Proyecto → Plugins y habilitás "OpenTableNearby".

## 4. Desde GDScript

```gdscript
var nearby = Engine.get_singleton("OpenTableNearby")
nearby.peer_connected.connect(_on_peer_connected)
nearby.data_received.connect(_on_data_received)
nearby.start_hosting(join_code, "Mesa de Alice")
```

## 6. Pruebas Unitarias de Integración (JUnit + Mockito)

El plugin incluye pruebas unitarias automatizadas para verificar el envío de payloads y comportamiento con la API de Google Play Services Nearby:

**Ubicación del test:** `platform_plugins/android/src/OpenTableNearbyPluginTest.kt`

**Ejecución de los tests:**
```bash
cd platform_plugins
./gradlew test
```

Los resultados del reporte de pruebas se generarán en: `platform_plugins/android/build/reports/tests/testReleaseUnitTest/index.html`.
       print("El plugin OpenTableNearby no está disponible en la plataforma actual")
   ```

2. **Verificar los logs del lado de Kotlin (Android):**
   Ejecuta `adb logcat` filtrando por el tag `OpenTableNearby`:
   ```bash
   adb logcat -s OpenTableNearby
   ```
   
   Deberás verificar en la consola de salida líneas similares a:
   ```
   D OpenTableNearby: sendBytes: sending 3 bytes to test-tag - payload: 1,2,3
   D OpenTableNearby: broadcastBytes: broadcasting 3 bytes to 0 endpoints - payload: 1,2,3
   ```
   
   Y al recibir paquetes de peers conectados:
   ```
   D OpenTableNearby: onPayloadReceived: received 3 bytes from <endpointId> - payload: 1,2,3
   ```

## Lo que ya NO hace falta conectar del lado de Rust

Antes esta sección decía que faltaba mapear `endpointId` a `PlayerId` vía
el handshake `Join`/`Reconnect`. Eso ya está resuelto — pero no acá, en
Kotlin, sino en el crate `open_table_transport_native_bridge` (Rust
puro, probado con 5 tests sin necesitar Android real). La razón: la
lógica de identidad/reconexión es código sensible que ya escribimos y
probamos una vez para TCP; no tiene sentido reescribirla en Kotlin y
tener que auditarla dos veces.

Este plugin (`OpenTableNearbyPlugin.kt`) queda como lo que es: un caño
de bytes tonto. Lo único que le falta conectar es el puente GDExtension
(`open_table_godot`, todavía sin compilar/verificar) implementando el
trait `RawByteLink` de `open_table_transport_native_bridge` — que en la
práctica significa:
- `send_raw`/`broadcast_raw` → llamar a `sendBytes`/`broadcastBytes` de
  este plugin desde Rust vía los bindings de Godot.
- `poll_raw_received` → drenar una cola que se llena cuando GDScript
  reciba la señal `data_received` de este plugin y se la reenvíe al
  bridge de Rust.
- `poll_link_events` → lo mismo, pero con la señal `peer_disconnected`.

Ver `open_table_transport_native_bridge/README.md` (o su `lib.rs`) para
el detalle completo del trait y cómo probarlo con el `FakeRawByteLink`
de sus tests antes de intentar la integración real.
