import Foundation
import MultipeerConnectivity

/**
 * Plugin de Godot para iOS (MultipeerConnectivity).
 *
 * Registra el singleton "OpenTableMultipeer" accesible en GDScript para
 * gestionar conexiones P2P transparentes sobre Bluetooth y Wi-Fi sin internet.
 */
@objc(OpenTableMultipeerPlugin)
public class OpenTableMultipeerPlugin: NSObject, OpenTableMultipeerDelegate {

    private let network = OpenTableMultipeerNetwork()
    private var peerMap = [String: MCPeerID]()

    public override init() {
        super.init()
        network.delegate = self
    }

    @objc public func startHosting(_ joinCode: String) {
        network.startHosting(joinCode: joinCode)
    }

    @objc public func startDiscovery(_ joinCode: String, autoConnect: Bool = true) {
        network.startDiscovery(joinCode: joinCode, autoConnect: autoConnect)
    }

    @objc public func requestConnection(_ endpointId: String) {
        if let peer = peerMap[endpointId] {
            network.connectToPeer(peer)
        }
    }

    @objc public func sendBytes(_ endpointId: String, data: Data) {
        if let peer = peerMap[endpointId] {
            network.sendBytes(data, to: peer)
        }
    }

    @objc public func broadcastBytes(_ data: Data) {
        network.broadcastBytes(data)
    }

    @objc public func stopAll() {
        network.stopAll()
        peerMap.removeAll()
    }

    // MARK: - OpenTableMultipeerDelegate

    public func onPeerDiscovered(_ peer: MCPeerID) {
        peerMap[peer.displayName] = peer
        // Emitir señal a Godot
    }

    public func onPeerConnected(_ peer: MCPeerID) {
        peerMap[peer.displayName] = peer
        // Emitir señal a Godot: peer_connected
    }

    public func onPeerDisconnected(_ peer: MCPeerID) {
        peerMap.removeValue(forKey: peer.displayName)
        // Emitir señal a Godot: peer_disconnected
    }

    public func onDataReceived(_ peer: MCPeerID, _ data: Data) {
        // Emitir señal a Godot: data_received
    }
}
