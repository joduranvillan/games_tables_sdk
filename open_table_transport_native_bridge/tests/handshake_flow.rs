//! Un `RawByteLink` de prueba: un host con N clientes conectados por
//! canales en memoria (`std::sync::mpsc`), simulando lo que haría un
//! plugin nativo real sin necesitar Android/iOS. Esto es lo que permite
//! probar TODA la lógica de `NativeHostTransport`/`NativeClientTransport`
//! de verdad en este sandbox, aunque el plugin real (Kotlin/Swift) no se
//! pueda compilar acá.

use std::collections::HashMap;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::time::Duration;

use open_table_core::error::EngineResult;
use open_table_core::ids::PlayerId;
use open_table_core::transport::Transport;
use open_table_transport_native_bridge::{
    ConnectionEvent, HandshakeStatus, NativeClientTransport, NativeHostTransport, RawByteLink,
    RawLinkEvent,
};

pub struct FakeHostLink {
    inbox: Receiver<(String, Vec<u8>)>,
    inbox_sender: Sender<(String, Vec<u8>)>,
    outboxes: HashMap<String, Sender<Vec<u8>>>,
    pending_link_events: Vec<RawLinkEvent>,
}

pub struct FakeClientLink {
    my_tag: String,
    host_inbox: Sender<(String, Vec<u8>)>,
    my_inbox: Receiver<Vec<u8>>,
}

impl FakeHostLink {
    pub fn new() -> Self {
        let (tx, rx) = channel();
        Self {
            inbox: rx,
            inbox_sender: tx,
            outboxes: HashMap::new(),
            pending_link_events: Vec::new(),
        }
    }

    /// Conecta un nuevo "dispositivo" al host, como si Nearby/Multipeer
    /// acabaran de establecer la conexión de bajo nivel (todavía sin
    /// handshake de OpenTable).
    pub fn connect(&mut self, tag: &str) -> FakeClientLink {
        let (tx, rx) = channel();
        self.outboxes.insert(tag.to_string(), tx);
        FakeClientLink {
            my_tag: tag.to_string(),
            host_inbox: self.inbox_sender.clone(),
            my_inbox: rx,
        }
    }

    /// Simula que la plataforma nativa avisó que un peer se cayó.
    pub fn simulate_disconnect(&mut self, tag: &str) {
        self.outboxes.remove(tag);
        self.pending_link_events
            .push(RawLinkEvent::Disconnected(tag.to_string()));
    }
}

impl RawByteLink for FakeHostLink {
    fn send_raw(&mut self, peer_tag: &str, bytes: &[u8]) -> EngineResult<()> {
        if let Some(tx) = self.outboxes.get(peer_tag) {
            let _ = tx.send(bytes.to_vec());
        }
        Ok(())
    }

    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()> {
        for tx in self.outboxes.values() {
            let _ = tx.send(bytes.to_vec());
        }
        Ok(())
    }

    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)> {
        let mut out = Vec::new();
        while let Ok(msg) = self.inbox.try_recv() {
            out.push(msg);
        }
        out
    }

    fn poll_link_events(&mut self) -> Vec<RawLinkEvent> {
        std::mem::take(&mut self.pending_link_events)
    }
}

impl RawByteLink for FakeClientLink {
    fn send_raw(&mut self, _peer_tag: &str, bytes: &[u8]) -> EngineResult<()> {
        let _ = self.host_inbox.send((self.my_tag.clone(), bytes.to_vec()));
        Ok(())
    }

    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()> {
        let _ = self.host_inbox.send((self.my_tag.clone(), bytes.to_vec()));
        Ok(())
    }

    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)> {
        let mut out = Vec::new();
        while let Ok(bytes) = self.my_inbox.try_recv() {
            out.push(("host".to_string(), bytes));
        }
        out
    }

    fn poll_link_events(&mut self) -> Vec<RawLinkEvent> {
        Vec::new()
    }
}

fn wait_for_established(client: &mut NativeClientTransport<FakeClientLink>) -> (PlayerId, String) {
    for _ in 0..100 {
        match client.poll_handshake() {
            HandshakeStatus::Established {
                player_id,
                reconnect_token,
            } => return (player_id, reconnect_token),
            HandshakeStatus::Rejected { reason } => panic!("handshake rechazado: {reason}"),
            HandshakeStatus::Pending => std::thread::sleep(Duration::from_millis(1)),
        }
    }
    panic!("el handshake nunca se completó");
}

#[test]
fn join_asigna_un_player_id_y_un_token() {
    let mut host_link = FakeHostLink::new();
    let client_link = host_link.connect("device-a");
    let mut host = NativeHostTransport::new(host_link);
    let mut client =
        NativeClientTransport::begin_join(client_link, "Alice").expect("arranca el join");

    // El host tiene que procesar el handshake para que el cliente vea la respuesta.
    host.poll_received();
    let (player_id, token) = wait_for_established(&mut client);

    assert_eq!(player_id, PlayerId(1));
    assert!(!token.is_empty());

    let events = host.poll_connection_events();
    assert!(events.contains(&ConnectionEvent::Joined {
        player: PlayerId(1)
    }));
}

#[test]
fn los_datos_viajan_en_los_dos_sentidos_despues_del_handshake() {
    let mut host_link = FakeHostLink::new();
    let client_link = host_link.connect("device-a");
    let mut host = NativeHostTransport::new(host_link);
    let mut client =
        NativeClientTransport::begin_join(client_link, "Alice").expect("arranca el join");

    host.poll_received();
    let (player_id, _token) = wait_for_established(&mut client);

    client.send(player_id, b"hola desde el cliente").unwrap();
    let received = host.poll_received();
    assert_eq!(
        received,
        vec![(player_id, b"hola desde el cliente".to_vec())]
    );

    host.broadcast(b"hola desde el host").unwrap();
    let received_by_client = client.poll_received();
    assert_eq!(received_by_client.len(), 1);
    assert_eq!(received_by_client[0].1, b"hola desde el host".to_vec());
}

#[test]
fn reconectar_con_el_token_correcto_recupera_el_mismo_player_id() {
    let mut host_link = FakeHostLink::new();
    let client_link = host_link.connect("device-a");
    let mut host = NativeHostTransport::new(host_link);
    let mut client =
        NativeClientTransport::begin_join(client_link, "Alice").expect("arranca el join");

    host.poll_received();
    let (player_id, token) = wait_for_established(&mut client);

    // Se cae: el host se entera por un evento de link simulado.
    host.link_mut().simulate_disconnect("device-a");
    let events = host.poll_connection_events();
    assert!(events.contains(&ConnectionEvent::Disconnected { player: player_id }));

    // Reconecta con una conexión nueva ("device-a-2"), probando el token.
    let new_client_link = host.link_mut().connect("device-a-2");
    let mut reconnecting_client =
        NativeClientTransport::begin_reconnect(new_client_link, player_id, token)
            .expect("arranca la reconexión");

    host.poll_received();
    let (reconnected_id, _) = wait_for_established(&mut reconnecting_client);
    assert_eq!(reconnected_id, player_id);

    let events = host.poll_connection_events();
    assert!(events.contains(&ConnectionEvent::Reconnected { player: player_id }));
}

#[test]
fn reconectar_con_un_token_incorrecto_es_rechazado() {
    let mut host_link = FakeHostLink::new();
    let client_link = host_link.connect("device-a");
    let mut host = NativeHostTransport::new(host_link);
    let mut client =
        NativeClientTransport::begin_join(client_link, "Alice").expect("arranca el join");

    host.poll_received();
    let (player_id, _real_token) = wait_for_established(&mut client);

    host.link_mut().simulate_disconnect("device-a");
    host.poll_connection_events();

    let new_client_link = host.link_mut().connect("device-a-2");
    let mut impostor = NativeClientTransport::begin_reconnect(
        new_client_link,
        player_id,
        "token-falso".to_string(),
    )
    .expect("arranca la reconexión (el rechazo pasa después, no acá)");

    host.poll_received();
    for _ in 0..100 {
        match impostor.poll_handshake() {
            HandshakeStatus::Rejected { .. } => return, // esperado
            HandshakeStatus::Established { .. } => {
                panic!("no debería haberse aceptado un token falso")
            }
            HandshakeStatus::Pending => std::thread::sleep(Duration::from_millis(1)),
        }
    }
    panic!("el handshake nunca resolvió");
}

#[test]
fn un_jugador_que_no_vuelve_a_tiempo_pierde_su_sesion() {
    let mut host_link = FakeHostLink::new();
    let client_link = host_link.connect("device-a");
    let mut host = NativeHostTransport::with_timeout(host_link, Duration::from_millis(100));
    let mut client =
        NativeClientTransport::begin_join(client_link, "Alice").expect("arranca el join");

    host.poll_received();
    let (player_id, token) = wait_for_established(&mut client);

    host.link_mut().simulate_disconnect("device-a");
    host.poll_connection_events();

    std::thread::sleep(Duration::from_millis(150));
    let events = host.poll_connection_events();
    assert!(events.contains(&ConnectionEvent::TimedOut { player: player_id }));

    let new_client_link = host.link_mut().connect("device-a-2");
    let mut too_late =
        NativeClientTransport::begin_reconnect(new_client_link, player_id, token).unwrap();
    host.poll_received();
    for _ in 0..100 {
        match too_late.poll_handshake() {
            HandshakeStatus::Rejected { .. } => return,
            HandshakeStatus::Established { .. } => {
                panic!("no debería poder reconectar después del timeout")
            }
            HandshakeStatus::Pending => std::thread::sleep(Duration::from_millis(1)),
        }
    }
    panic!("el handshake nunca resolvió");
}
