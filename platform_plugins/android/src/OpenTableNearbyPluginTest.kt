package org.opentable.network.nearby

import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.Payload
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.*

/**
 * Test unitario con Mockito para verificar la emisión de payloads
 * a través de Google Play Services Nearby Connections API.
 *
 * Ejecutar con: ./gradlew test (dentro de platform_plugins/)
 */
class OpenTableNearbyPluginTest {

    @Test
    fun testSendBytes_invokesConnectionsClientSendPayloadWithCorrectBytes() {
        val mockConnectionsClient = mock(ConnectionsClient::class.java)
        val endpointId = "tag"
        val expectedBytes = byteArrayOf(1, 2, 3)

        val payloadCaptor = ArgumentCaptor.forClass(Payload::class.java)

        // Simular envío de payload a través del ConnectionsClient mockeado
        val payload = Payload.fromBytes(expectedBytes)
        mockConnectionsClient.sendPayload(endpointId, payload)

        // Verificar que sendPayload fue invocado con el tag y el payload correcto
        verify(mockConnectionsClient, times(1)).sendPayload(eq(endpointId), payloadCaptor.capture())

        val capturedPayload = payloadCaptor.value
        assertNotNull(capturedPayload)
        assertArrayEquals(expectedBytes, capturedPayload.asBytes())
    }
}
