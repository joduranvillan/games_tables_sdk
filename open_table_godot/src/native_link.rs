//! Implementación real de `RawByteLink` para el bridge GDExtension (`open_table_godot`).
//!
//! `GodotRawByteLink` reemplaza a `FakeRawByteLink` en producción conectando
//! `open_table_transport_native_bridge` con los plugins nativos de plataforma
//! (`OpenTableNearby` en Android y `OpenTableMultipeer` en iOS) mediante las señales
//! GDExtension `native_send_bytes(bytes: PackedByteArray)` y
//! `native_bytes_received(bytes: PackedByteArray)`.

use godot::classes::{Engine, Node};
use godot::prelude::*;
use open_table_core::error::EngineResult;
use open_table_transport_native_bridge::{RawByteLink, RawLinkEvent};
use std::sync::{Arc, Mutex};

pub use open_table_transport_native_bridge::NativeBridgeTransport;

#[derive(Clone, Default)]
pub struct SharedLinkQueue {
    pub incoming: Vec<(String, Vec<u8>)>,
    pub events: Vec<RawLinkEvent>,
    pub outgoing_sends: Vec<(String, Vec<u8>)>,
    pub outgoing_broadcasts: Vec<Vec<u8>>,
    pub outgoing_raw_bytes: Vec<Vec<u8>>,
}

/// Enlace P2P real sobre señales GDExtension (`native_send_bytes` / `native_bytes_received`).
#[derive(Clone, Default)]
pub struct GodotRawByteLink {
    pub queue: Arc<Mutex<SharedLinkQueue>>,
}

/// Alias de compatibilidad para Android Nearby Connections.
pub type GodotNearbyLink = GodotRawByteLink;

/// Alias de compatibilidad para iOS MultipeerConnectivity.
pub type GodotMultipeerLink = GodotRawByteLink;

impl GodotRawByteLink {
    pub fn new(queue: Arc<Mutex<SharedLinkQueue>>) -> Self {
        Self { queue }
    }

    /// Envía bytes hacia el plugin nativo mediante la señal Godot
    /// `native_send_bytes(bytes: PackedByteArray)`.
    pub fn send(&mut self, data: &[u8]) -> EngineResult<()> {
        let mut q = self.queue.lock().unwrap();
        q.outgoing_raw_bytes.push(data.to_vec());
        Ok(())
    }

    /// Retorna los paquetes de bytes recibidos desde la señal Godot
    /// `native_bytes_received(bytes: PackedByteArray)`.
    pub fn receive(&mut self) -> Vec<Vec<u8>> {
        let mut q = self.queue.lock().unwrap();
        std::mem::take(&mut q.incoming)
            .into_iter()
            .map(|(_, bytes)| bytes)
            .collect()
    }

    /// Registra bytes entrantes provenientes de la señal `native_bytes_received(bytes: PackedByteArray)`.
    pub fn push_received_bytes(&self, peer_tag: &str, bytes: Vec<u8>) {
        let mut q = self.queue.lock().unwrap();
        q.incoming.push((peer_tag.to_string(), bytes));
    }

    /// Emite en el nodo Godot las señales `native_send_bytes(bytes: PackedByteArray)`,
    /// `native_send_requested(peer_tag: GString, bytes: PackedByteArray)` y
    /// `native_broadcast_requested(bytes: PackedByteArray)` pendientes en la cola.
    pub fn flush_to_node(queue: &Arc<Mutex<SharedLinkQueue>>, node: &mut Gd<Node>) {
        let (sends, broadcasts, raw_bytes) = {
            let mut q = queue.lock().unwrap();
            let sends = std::mem::take(&mut q.outgoing_sends);
            let broadcasts = std::mem::take(&mut q.outgoing_broadcasts);
            let raw_bytes = std::mem::take(&mut q.outgoing_raw_bytes);
            (sends, broadcasts, raw_bytes)
        };

        for bytes in raw_bytes {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            node.emit_signal("native_send_bytes", &[Variant::from(packed)]);
        }

        for (peer_tag, bytes) in sends {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            node.emit_signal(
                "native_send_requested",
                &[Variant::from(peer_tag), Variant::from(packed.clone())],
            );
            node.emit_signal("native_send_bytes", &[Variant::from(packed)]);
        }

        for bytes in broadcasts {
            let mut packed = PackedByteArray::new();
            for b in bytes {
                packed.push(b);
            }
            node.emit_signal(
                "native_broadcast_requested",
                &[Variant::from(packed.clone())],
            );
            node.emit_signal("native_send_bytes", &[Variant::from(packed)]);
        }
    }

    /// Comprueba si el plugin nativo (`OpenTableNearby` en Android o `OpenTableMultipeer` en iOS)
    /// está disponible en `Engine`. Si no está disponible (desktop), registra un warning en Godot
    /// y retorna `false` sin fallar.
    pub fn check_native_plugin_available() -> bool {
        let engine = Engine::singleton();
        let has_nearby = engine.has_singleton("OpenTableNearby");
        let has_multipeer = engine.has_singleton("OpenTableMultipeer");
        if !has_nearby && !has_multipeer {
            godot_warn!(
                "OpenTable P2P: Plugin nativo (OpenTableNearby / OpenTableMultipeer) no disponible en desktop; inicializando NativeBridgeTransport<GodotRawByteLink> en modo seguro."
            );
            return false;
        }
        true
    }
}

impl RawByteLink for GodotRawByteLink {
    fn send_raw(&mut self, peer_tag: &str, bytes: &[u8]) -> EngineResult<()> {
        let mut q = self.queue.lock().unwrap();
        q.outgoing_sends
            .push((peer_tag.to_string(), bytes.to_vec()));
        Ok(())
    }

    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()> {
        let mut q = self.queue.lock().unwrap();
        q.outgoing_broadcasts.push(bytes.to_vec());
        Ok(())
    }

    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)> {
        let mut q = self.queue.lock().unwrap();
        std::mem::take(&mut q.incoming)
    }

    fn poll_link_events(&mut self) -> Vec<RawLinkEvent> {
        let mut q = self.queue.lock().unwrap();
        std::mem::take(&mut q.events)
    }
}
