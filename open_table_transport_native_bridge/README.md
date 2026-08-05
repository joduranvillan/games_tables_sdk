# `open_table_transport_native_bridge`

Capa de protocolo compartida por CUALQUIER transporte móvil nativo
(Nearby Connections en Android, MultipeerConnectivity en iOS, o
cualquier otro que aparezca). Contiene todo lo que `open_table_transport_tcp`
ya probó — handshake `Join`/`Reconnect`, validación de identidad, tokens
CSPRNG, timeout de reconexión — pero generalizado sobre un trait mínimo
en vez de sockets TCP.

## La idea central

```rust
pub trait RawByteLink: Send {
    fn send_raw(&mut self, peer_tag: &str, bytes: &[u8]) -> EngineResult<()>;
    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()>;
    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)>;
    fn poll_link_events(&mut self) -> Vec<RawLinkEvent>;
}
```

Cualquier cosa que sepa mover bytes hacia/desde un `peer_tag` (un
string opaco — el `endpointId` de Nearby, el `MCPeerID` de Multipeer)
puede envolverse en `NativeHostTransport<L>` o `NativeClientTransport<L>`
y automáticamente hereda:

- Handshake `Join` (jugador nuevo → `PlayerId` + `reconnect_token`) /
  `Reconnect` (prueba de identidad con el token).
- `ConnectionEvent::{Joined, Reconnected, Disconnected, TimedOut}`.
- Timeout configurable, con purga del token al expirar.
- Implementación de `open_table_core::Transport` — o sea, `Session`
  nunca sabe ni le importa qué hay debajo.

Ver `tests/handshake_flow.rs` para el ejemplo completo: un
`FakeRawByteLink` (dos canales en memoria) prueba las 5 propiedades de
arriba sin ningún dispositivo real.

## Cómo conectarlo a un plugin nativo real

Para Android (`OpenTableNearbyPlugin.kt`, en `platform_plugins/android/`):

```rust
struct NearbyLink {
    // handles hacia los métodos de OpenTableNearbyPlugin vía gdext,
    // más una cola interna donde vuelcan las señales de Godot
    // (data_received, peer_disconnected) que le llegan desde GDScript.
}

impl RawByteLink for NearbyLink {
    fn send_raw(&mut self, peer_tag: &str, bytes: &[u8]) -> EngineResult<()> {
        // llama a nearby_plugin.sendBytes(peer_tag, bytes) vía gdext
    }
    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()> {
        // llama a nearby_plugin.broadcastBytes(bytes)
    }
    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)> {
        // drena la cola que se llena cuando GDScript reenvía data_received
    }
    fn poll_link_events(&mut self) -> Vec<RawLinkEvent> {
        // drena la cola que se llena con peer_disconnected
    }
}
```

Esa `NearbyLink` (o su equivalente `MultipeerLink` para iOS) es la
ÚNICA pieza nueva que hace falta escribir por plataforma — y es
mecánica: solo reenvía llamadas, no toma ninguna decisión. Vive dentro
de `open_table_godot` (todavía sin compilar/verificar, ver su
`LIMITACION.md`), no en este crate.

## Estado

Probado (5 tests, sin dispositivos reales): `join_asigna_un_player_id_y_un_token`,
`los_datos_viajan_en_los_dos_sentidos_despues_del_handshake`,
`reconectar_con_el_token_correcto_recupera_el_mismo_player_id`,
`reconectar_con_un_token_incorrecto_es_rechazado`,
`un_jugador_que_no_vuelve_a_tiempo_pierde_su_sesion`.

NO probado: la implementación real de `RawByteLink` sobre
`OpenTableNearbyPlugin`/`OpenTableMultipeerNetwork` — eso necesita
Android Studio/Xcode, que no hay en el entorno donde se armó esto.
