# Platform Plugins — OpenTable SDK (Android & iOS)

Plugins nativos que proporcionan transporte P2P transparente multi-soporte (Wi-Fi Direct, Bluetooth Classic/BLE, Red Local Wi-Fi, Internet) para juegos multijugador local en Godot 4.

## Arquitectura Transparente

```
             ┌───────────────────────────────────────────────┐
             │         OpenTable SDK (Godot / Rust)          │
             └───────────────────────┬───────────────────────┘
                                     │ RawByteLink
                  ┌──────────────────┴──────────────────┐
                  ▼                                     ▼
      Android (Nearby Connections)             iOS (Multipeer Connectivity)
   ┌───────────────────────────────┐         ┌───────────────────────────────┐
   │ • Wi-Fi Direct                │         │ • Wi-Fi Local (P2P / Infra)   │
   │ • Bluetooth Classic / BLE     │         │ • Bluetooth                   │
   │ • Wi-Fi Local / AP            │         │ • Red Local (Bonjour)         │
   └───────────────────────────────┘         └───────────────────────────────┘
```

Ambos plugins abstraen completamente la complejidad del hardware de red:
- **Filtrado por Sala**: Utiliza el `join_code` (generado por `open_table_qr`) para aislar partidas.
- **Auto-Conexión Transparente**: Al iniciar la búsqueda con `startDiscovery(join_code, autoConnect=true)`, el cliente se conecta automáticamente al Host de la mesa sin requerir interacción manual con diálogos o IDs.
- **Auto-Aceptación a Nivel de Transporte**: La capa nativa acepta la conexión y delega la autenticación real del jugador al handshake seguro de OpenTable (`Join`/`Reconnect`).

---

## 1. Plugin Android (`OpenTableNearby`)

- **Ubicación**: `android/src/main/java/org/opentable/network/nearby/OpenTableNearbyPlugin.kt`
- **Configuración**: `android/build.gradle.kts`, `AndroidManifest.xml`, `OpenTableNearby.gdap`
- **Permisos Incluidos**: Location (`ACCESS_FINE_LOCATION`), Bluetooth (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`), Nearby Wi-Fi (`NEARBY_WIFI_DEVICES`), Internet (`INTERNET`, `ACCESS_NETWORK_STATE`).

### Uso en GDScript (Android)
```gdscript
var nearby = Engine.get_singleton("OpenTableNearby")

func _ready():
    if nearby:
        nearby.peer_connected.connect(_on_peer_connected)
        nearby.data_received.connect(_on_data_received)
        nearby.peer_disconnected.connect(_on_peer_disconnected)

# Host crea la mesa
func host_game(join_code: String):
    nearby.startHosting(join_code, "Mesa de Jugador")

# Cliente se une a la mesa (auto-conexión transparente)
func join_game(join_code: String):
    nearby.startDiscovery(join_code, "Jugador 2", true)

func send_data(endpoint_id: String, bytes: PackedByteArray):
    nearby.sendBytes(endpoint_id, bytes)
```

---

## 2. Plugin iOS (`OpenTableMultipeer`)

- **Ubicación**: `ios/OpenTableMultipeerNetwork.swift`, `ios/OpenTableMultipeerPlugin.swift`
- **Configuración**: `ios/OpenTableMultipeer.gdip`, `ios/Info.plist.template`
- **Soportes**: MultipeerConnectivity sobre Wi-Fi Local, P2P Wi-Fi y Bluetooth.

### Uso en GDScript (iOS)
```gdscript
var multipeer = Engine.get_singleton("OpenTableMultipeer")

func _ready():
    if multipeer:
        multipeer.peer_connected.connect(_on_peer_connected)
        multipeer.data_received.connect(_on_data_received)

func host_game(join_code: String):
    multipeer.startHosting(join_code)

func join_game(join_code: String):
    multipeer.startDiscovery(join_code, true)

func send_data(endpoint_id: String, bytes: PackedByteArray):
    multipeer.sendBytes(endpoint_id, bytes)
```

---

## Resumen de Validación

1. **Multi-soporte**: Ambos plugins gestionan automáticamente redes Wi-Fi Direct, Bluetooth y Red Local/Internet sin configuración adicional.
2. **Conexión Transparente**: La búsqueda basada en `join_code` con `autoConnect=true` realiza el enlace P2P en segundo plano sin pedir al usuario que seleccione interfaces ni IP.
3. **Usabilidad en Godot**: Ambos plugins registran singletons en el motor Godot 4 (`OpenTableNearby` en Android y `OpenTableMultipeer` en iOS) exponiendo la misma interfaz de señales y métodos de envío de bytes.
