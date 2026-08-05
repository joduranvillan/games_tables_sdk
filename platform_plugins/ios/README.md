# Integrar `OpenTableMultipeerNetwork.swift` en un proyecto Godot iOS

No compilado ni probado acá (no hay Xcode en el sandbox). El sistema de
plugins iOS de Godot 4 es menos estandarizado que el de Android — varía
más entre versiones del editor, así que esta guía es más una checklist
de piezas que necesitás armar que una receta exacta.

## 1. Empaquetado

El archivo `.swift` de este directorio es la lógica de red pura (no
depende de Godot). Necesitás:

1. Compilarlo como parte de un `.xcframework` (o directamente como
   fuente dentro del proyecto Xcode que genera Godot al exportar a iOS).
2. Un archivo `plugin.cfg` (formato similar al de GDExtension) que le
   diga a Godot qué framework/librería cargar.
3. Una capa de glue (típicamente Objective-C++ o el propio GDExtension
   en Rust vía `gdext`, si tu versión de Godot lo soporta) que exponga
   `startHosting`, `startDiscovery`, `sendBytes`, `broadcastBytes` a
   GDScript, y traduzca los callbacks de `OpenTableMultipeerDelegate` a
   señales de Godot — el mismo rol que `GodotPlugin`/`@UsedByGodot`
   cumple en Android.

Esta tercera pieza es la que más varía según la versión de Godot que
uses (el soporte de GDExtension para iOS maduró bastante entre 4.1 y
4.3+), así que no la incluyo acá para no darte glue código que podría
estar desactualizado para tu versión específica — mejor que la arms
mirando la documentación de exportación iOS de tu versión exacta.

## 2. Info.plist y Entitlements

MultipeerConnectivity requiere que la aplicación iOS exportada declare permisos de red local, Bluetooth y servicios Bonjour en el archivo `Info.plist`, así como el entitlement correspondiente en `OpenTableMultipeer.entitlements`:

### 2.1 Info.plist (`platform_plugins/ios/Info.plist`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocalNetworkUsageDescription</key>
    <string>OpenTable SDK utiliza la red local para conectar salas P2P sin necesidad de servidor central.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>OpenTable SDK utiliza Bluetooth para descubrir dispositivos cercanos y crear salas de juego P2P.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_opentable._tcp</string>
        <string>_opentable._udp</string>
    </array>
</dict>
</plist>
```

### 2.2 Entitlements (`platform_plugins/ios/OpenTableMultipeer.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.multipeer-connectivity</key>
    <true/>
</dict>
</plist>
```

## 3. Modo Background y Tiempo de Ejecución Adicional (`OpenTableMultipeer.swift`)

A diferencia de Android (donde se utiliza un Foreground Service con notificación persistente), iOS no permite ejecutar servicios continuos ilimitados en segundo plano para aplicaciones de juegos o redes genéricas.

Para gestionar las transiciones en segundo plano sin interrumpir partidas P2P durante bloqueos temporales o minimizaciones rápidas:

1. **Gestión de Notificaciones**:
   - `OpenTableMultipeer.swift` registra observadores para `UIApplication.didEnterBackgroundNotification` y `UIApplication.willEnterForegroundNotification`.

2. **Extensión de Tiempo (`UIApplication.shared.beginBackgroundTask`)**:
   - Al minimizar la app, se invoca `beginBackgroundTask(withName: "OpenTableMultipeerBackgroundSession")`. Esto solicita a iOS tiempo de ejecución extra en segundo plano.

3. **Limitaciones de iOS**:
   - **Tiempo máximo otorgado por iOS**: iOS concede un máximo estricto de **~30 segundos** de tiempo de ejecución continuo tras minimizar la aplicación.
   - Si la aplicación permanece en segundo plano más de 30 segundos, el closure de expiración es ejecutado por el SO, pausando la sesión limpiamente (`isSessionPaused = true`) y llamando a `endBackgroundTask()` para evitar la terminación forzosa de la app por parte de iOS.
   - Al regresar a primer plano (`willEnterForegroundNotification`), la sesión se reanuda limpiamente.

## 4. Desde GDScript (una vez armada la capa de glue)

```gdscript
var multipeer = Engine.get_singleton("OpenTableMultipeer")
multipeer.peer_connected.connect(_on_peer_connected)
multipeer.data_received.connect(_on_data_received)
multipeer.start_hosting(join_code)
```

## Lo que ya NO hace falta conectar del lado de Rust

Igual que en Android: la lógica de identidad/reconexión (`Join`/
`Reconnect`, validación de token) ya NO vive acá ni en Kotlin — vive en
`open_table_transport_native_bridge`, un crate de Rust puro compartido
entre Android e iOS, con 5 tests que prueban todo el mecanismo (join,
datos en los dos sentidos, reconexión, token falso rechazado, timeout)
sin necesitar un dispositivo real.

Esta clase (`OpenTableMultipeerNetwork`) sigue siendo lo que ya era: un
caño de bytes. La capa de glue que falta armar (Objective-C++ o
`gdext`, según la versión de Godot) tiene que implementar el trait
`RawByteLink` de ese crate — `send_raw`/`broadcast_raw` llamando a
`sendBytes`/`broadcastBytes` de esta clase, y `poll_raw_received`/
`poll_link_events` drenando lo que llega por `onDataReceived`/
`onPeerDisconnected` del `OpenTableMultipeerDelegate`.
