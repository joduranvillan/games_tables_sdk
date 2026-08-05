import Foundation
import MultipeerConnectivity

/// Envuelve `MultipeerConnectivity` con la misma interfaz lógica que
/// `OpenTableNearbyPlugin.kt` en Android — mismo `join_code` para filtrar
/// salas, mismo modelo de "auto-aceptar a nivel de transporte, validar
/// identidad de jugador en el handshake de OpenTable".
///
/// Soporta transporte transparente por Wi-Fi Local, Wi-Fi P2P y Bluetooth.
@objc public class OpenTableMultipeerNetwork: NSObject {

    private let serviceType = "opentable"
    private let peerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var joinCode: String = ""
    private var autoConnectEnabled: BooleanLiteralType = true

    public weak var delegate: OpenTableMultipeerDelegate?

    public override init() {
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        self.session.delegate = self
    }

    /// El host llama esto al crear la sala. `joinCode` viene de `open_table_qr::generate_join_code()`.
    public func startHosting(joinCode: String) {
        self.joinCode = joinCode
        let discoveryInfo = ["join_code": joinCode]
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    /// El cliente llama esto tras escanear/tipear el `join_code`. Si `autoConnect` es true, conecta automáticamente.
    public func startDiscovery(joinCode: String, autoConnect: Bool = true) {
        self.joinCode = joinCode
        self.autoConnectEnabled = autoConnect
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    public func connectToPeer(_ peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    public func sendBytes(_ data: Data, to peer: MCPeerID) {
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    public func broadcastBytes(_ data: Data) {
        guard !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    public func stopAll() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }
}

extension OpenTableMultipeerNetwork: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            delegate?.onPeerConnected(peerID)
        case .notConnected:
            delegate?.onPeerDisconnected(peerID)
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        delegate?.onDataReceived(peerID, data)
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension OpenTableMultipeerNetwork: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Auto-aceptar a nivel de transporte
        invitationHandler(true, session)
    }
}

extension OpenTableMultipeerNetwork: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Filtra por join_code
        guard info?["join_code"] == joinCode else { return }
        delegate?.onPeerDiscovered(peerID)

        if autoConnectEnabled {
            // Conexión P2P transparente automática al encontrar la sala
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Manejado por MCSessionDelegate
    }
}

public protocol OpenTableMultipeerDelegate: AnyObject {
    func onPeerDiscovered(_ peer: MCPeerID)
    func onPeerConnected(_ peer: MCPeerID)
    func onPeerDisconnected(_ peer: MCPeerID)
    func onDataReceived(_ peer: MCPeerID, _ data: Data)
}
