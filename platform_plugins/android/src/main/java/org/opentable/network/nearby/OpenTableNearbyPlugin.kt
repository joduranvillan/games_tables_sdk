package org.opentable.network.nearby

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Plugin de Godot para Android (Nearby Connections API).
 *
 * Proporciona transporte P2P transparente multi-soporte (Wi-Fi Direct, Bluetooth,
 * Wi-Fi Local / Hotspot) sin intervención manual del usuario.
 *
 * Estrategia: Strategy.P2P_STAR (Topología 1 Host - N Clientes).
 * El filtrado de salas utiliza `serviceId` derivado del `join_code` generado por `open_table_qr`.
 */
class OpenTableNearbyPlugin(godot: Godot) : GodotPlugin(godot) {

    private val connectionsClient: ConnectionsClient by lazy { Nearby.getConnectionsClient(activity!!) }
    private val strategy = Strategy.P2P_STAR
    private val connectedEndpoints = mutableSetOf<String>()
    private var currentServiceId: String = ""
    private var autoConnectEnabled: Boolean = true
    private var myDisplayName: String = "Jugador"

    override fun getPluginName(): String = "OpenTableNearby"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("peer_discovered", String::class.java, String::class.java), // endpointId, endpointName
        SignalInfo("peer_connected", String::class.java),
        SignalInfo("peer_disconnected", String::class.java),
        SignalInfo("data_received", String::class.java, ByteArray::class.java),
        SignalInfo("advertising_failed", String::class.java),
        SignalInfo("discovery_failed", String::class.java),
        SignalInfo("permissions_granted"),
        SignalInfo("permissions_denied", String::class.java)
    )

    /** Verifica permisos requeridos según la versión de Android */
    @UsedByGodot
    fun checkPermissions(): Boolean {
        val activity = activity ?: return false
        val requiredPermissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            requiredPermissions.add(Manifest.permission.BLUETOOTH_SCAN)
            requiredPermissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            requiredPermissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requiredPermissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }

        val missing = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }

        return missing.isEmpty()
    }

    /** Inicia Advertising como Host para el `joinCode` dado. */
    @UsedByGodot
    fun startHosting(joinCode: String, localDisplayName: String) {
        if (!checkPermissions()) {
            emitSignal("advertising_failed", "Permisos de red/ubicación/bluetooth no concedidos")
            return
        }
        myDisplayName = localDisplayName
        currentServiceId = serviceIdFor(joinCode)
        val options = AdvertisingOptions.Builder().setStrategy(strategy).build()

        connectionsClient
            .startAdvertising(localDisplayName, currentServiceId, connectionLifecycleCallback, options)
            .addOnFailureListener { e -> emitSignal("advertising_failed", e.message ?: "error al anunciar sala") }
    }

    /** Inicia Discovery como Cliente. Si `autoConnect` es true, solicita conexión transparente automáticamente. */
    @UsedByGodot
    fun startDiscovery(joinCode: String, localDisplayName: String, autoConnect: Boolean) {
        if (!checkPermissions()) {
            emitSignal("discovery_failed", "Permisos de red/ubicación/bluetooth no concedidos")
            return
        }
        myDisplayName = localDisplayName
        autoConnectEnabled = autoConnect
        currentServiceId = serviceIdFor(joinCode)
        val options = DiscoveryOptions.Builder().setStrategy(strategy).build()

        connectionsClient
            .startDiscovery(currentServiceId, endpointDiscoveryCallback, options)
            .addOnFailureListener { e -> emitSignal("discovery_failed", e.message ?: "error al buscar sala") }
    }

    /** Solicita conexión manual a un endpoint descubierto. */
    @UsedByGodot
    fun requestConnection(endpointId: String, localDisplayName: String) {
        connectionsClient.requestConnection(localDisplayName, endpointId, connectionLifecycleCallback)
            .addOnFailureListener { e -> emitSignal("discovery_failed", "Error al conectar: ${e.message}") }
    }

    @UsedByGodot
    fun sendBytes(endpointId: String, bytes: ByteArray) {
        Log.d(TAG, "sendBytes: sending ${bytes.size} bytes to $endpointId - payload: ${bytes.joinToString(",")}")
        connectionsClient.sendPayload(endpointId, Payload.fromBytes(bytes))
    }

    @UsedByGodot
    fun broadcastBytes(bytes: ByteArray) {
        Log.d(TAG, "broadcastBytes: broadcasting ${bytes.size} bytes to ${connectedEndpoints.size} endpoints - payload: ${bytes.joinToString(",")}")
        if (connectedEndpoints.isEmpty()) return
        val payload = Payload.fromBytes(bytes)
        connectedEndpoints.forEach { endpointId ->
            connectionsClient.sendPayload(endpointId, payload)
        }
    }

    @UsedByGodot
    fun startForegroundService() {
        val activity = activity ?: return
        OpenTableNearbyService.startService(activity.applicationContext)
    }

    @UsedByGodot
    fun stopForegroundService() {
        val activity = activity ?: return
        OpenTableNearbyService.stopService(activity.applicationContext)
    }

    @UsedByGodot
    fun stopAll() {
        stopForegroundService()
        connectionsClient.stopAdvertising()
        connectionsClient.stopDiscovery()
        connectionsClient.stopAllEndpoints()
        connectedEndpoints.clear()
    }

    private fun serviceIdFor(joinCode: String): String = "org.opentable.$joinCode"

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            // Auto-aceptar a nivel de transporte (la validación de jugador pasa por el handshake de OpenTable)
            connectionsClient.acceptConnection(endpointId, payloadCallback)
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            if (result.status.isSuccess) {
                connectedEndpoints.add(endpointId)
                emitSignal("peer_connected", endpointId)
            }
        }

        override fun onDisconnected(endpointId: String) {
            connectedEndpoints.remove(endpointId)
            emitSignal("peer_disconnected", endpointId)
        }
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            emitSignal("peer_discovered", endpointId, info.endpointName)
            if (autoConnectEnabled) {
                // Conexión P2P transparente al encontrar la mesa que coincide con el join_code
                requestConnection(endpointId, myDisplayName)
            }
        }

        override fun onEndpointLost(endpointId: String) {
            // Manejado por onDisconnected si ya estaba conectado
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            payload.asBytes()?.let { bytes ->
                Log.d(TAG, "onPayloadReceived: received ${bytes.size} bytes from $endpointId - payload: ${bytes.joinToString(",")}")
                emitSignal("data_received", endpointId, bytes)
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // Sin uso especial para mensajes livianos
        }
    }

    companion object {
        private const val TAG = "OpenTableNearby"
    }
}
