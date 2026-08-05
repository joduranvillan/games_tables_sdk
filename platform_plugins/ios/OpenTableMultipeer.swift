import Foundation
import MultipeerConnectivity
import UIKit

/**
 * Gestor principal de Multipeer Connectivity y modo background para iOS.
 *
 * Registra observadores para `UIApplication.didEnterBackgroundNotification` y
 * `UIApplication.willEnterForegroundNotification` utilizando `beginBackgroundTask`
 * para solicitar tiempo de ejecución adicional (~30s otorgados por iOS) al minimizar
 * la aplicación, manteniendo o pausando/reanudando la sesión P2P de forma limpia.
 */
@objc(OpenTableMultipeer)
public class OpenTableMultipeer: NSObject, OpenTableMultipeerDelegate {

    private let network = OpenTableMultipeerNetwork()
    private var peerMap = [String: MCPeerID]()
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var isSessionPaused: Bool = false

    public override init() {
        super.init()
        network.delegate = self
        setupBackgroundObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }

    // MARK: - Manejo de Notificaciones de Background & Foreground

    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleDidEnterBackground() {
        print("📱 OpenTableMultipeer: La app entró a segundo plano (didEnterBackground). Solicitando tiempo adicional a iOS...")
        beginBackgroundTask()
    }

    @objc private func handleWillEnterForeground() {
        print("📱 OpenTableMultipeer: La app regresó a primer plano (willEnterForeground). Reanudando sesión...")
        if isSessionPaused {
            isSessionPaused = false
            print("🟢 OpenTableMultipeer: Sesión reanudada limpiamente.")
        }
        endBackgroundTask()
    }

    /// Solicita tiempo adicional en segundo plano (máximo ~30 segundos en iOS)
    public func beginBackgroundTask() {
        guard backgroundTaskId == .invalid else { return }

        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "OpenTableMultipeerBackgroundSession") { [weak self] in
            print("⚠️ OpenTableMultipeer: El tiempo adicional de background (~30s) ha expirado. Pausando sesión limpiamente...")
            self?.isSessionPaused = true
            self?.endBackgroundTask()
        }
    }

    /// Finaliza la tarea de background activa
    public func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    // MARK: - API Pública para GDScript / OpenTableBridge

    @objc public func startHosting(_ joinCode: String) {
        isSessionPaused = false
        network.startHosting(joinCode: joinCode)
    }

    @objc public func startDiscovery(_ joinCode: String, autoConnect: Bool = true) {
        isSessionPaused = false
        network.startDiscovery(joinCode: joinCode, autoConnect: autoConnect)
    }

    @objc public func requestConnection(_ endpointId: String) {
        if let peer = peerMap[endpointId] {
            network.connectToPeer(peer)
        }
    }

    @objc public func sendBytes(_ endpointId: String, data: Data) {
        guard !isSessionPaused else {
            print("⚠️ OpenTableMultipeer: No se enviaron bytes, la sesión está pausada en background.")
            return
        }
        if let peer = peerMap[endpointId] {
            network.sendBytes(data, to: peer)
        }
    }

    @objc public func broadcastBytes(_ data: Data) {
        guard !isSessionPaused else {
            print("⚠️ OpenTableMultipeer: No se emitió broadcast, la sesión está pausada en background.")
            return
        }
        network.broadcastBytes(data)
    }

    @objc public func stopAll() {
        network.stopAll()
        peerMap.removeAll()
        endBackgroundTask()
        isSessionPaused = false
    }

    // MARK: - Delegates de OpenTableMultipeerDelegate

    public func onPeerDiscovered(_ peer: MCPeerID) {
        peerMap[peer.displayName] = peer
    }

    public func onPeerConnected(_ peer: MCPeerID) {
        peerMap[peer.displayName] = peer
    }

    public func onPeerDisconnected(_ peer: MCPeerID) {
        peerMap.removeValue(forKey: peer.displayName)
    }

    public func onDataReceived(_ peer: MCPeerID, _ data: Data) {
    }
}
