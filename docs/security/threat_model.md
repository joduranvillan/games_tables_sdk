# Modelo de Amenazas y Seguridad — OpenTable SDK

Este documento describe las consideraciones de seguridad, supuestos de confianza, vectores de ataque analizados y mitigaciones implementadas en el OpenTable SDK.

---

## 1. Modelo de Confianza y Host Autoritativo

OpenTable Engine opera bajo un esquema de **Host Autoritativo (Single Source of Truth)**.

- **Único Punto de Verdad**: La instancia de `Session` alojada en el Host mantiene el estado canónico de la partida (vía `bevy_ecs`). Los clientes no tienen autoridad para modificar directamente el estado del juego.
- **Validación Estricta de Reglas**: Todos los comandos recibidos a través del transporte de red son evaluados por el `RuleEngine` en el Host. Un cliente modificado o malicioso no puede forzar movimientos ilegales o alterar posiciones en el tablero.

---

## 2. Autenticación e Identidad de Jugadores

Para evitar que un atacante suplante a otro jugador enviando comandos no autorizados:

- **Tokens CSPRNG**: Durante el handshake inicial (`Join`), el Host genera un token criptográficamente seguro (usando generadores CSPRNG como `rand::thread_rng()`) para cada jugador.
- **Validación de `PlayerId`**: Cada `Command` enviado contiene el `PlayerId` del emisor. El Host valida que el paquete provenga de la conexión autenticada asociada a dicho `PlayerId` y token.
- **Reconexión Segura**: Si un jugador se desconecta (por caída de red o cambio de interfaz), debe presentar su `session_id`, `player_id` y el `auth_token` secreto previamente asignado para reanudar su sesión. Un tercero no puede usurpar la sesión sin conocer el token.

---

## 3. Mitigación de Denegación de Servicio (DoS) y Rate Limiting

A nivel de transporte y motor:

- **Búferes de Entrada Acotados**: Los sockets de transporte imponen límites en el tamaño de los paquetes deserializables de tipo `CommandEnvelope` para evitar ataques de agotamiento de memoria por asignación masiva de bytes.
- **Rate Limiting de Comandos**: `Session::process_command` aplica controles de frecuencia de mensajes por socket/jugador. Si un jugador inunda la conexión con comandos en ráfagas no razonables, el paquete es rechazado con `CommandRejectedEvent` sin sobrecargar la evaluación en el `RuleEngine`.
- **Timeouts de Conexión Inactiva**: Conexiones que no responden a los pings periódicos son desconectadas automáticamente para liberar recursos.

---

## 4. Privacidad de Eventos y Manejo de Información Oculta

En juegos con información privada (como las manos de cartas en *Mille Bornes* o *Uno*, o los tableros de barcos en *Batalla Naval*):

- **Filtro por Visibilidad (`Visibility`)**: Cada `Event` generado por el `RuleEngine` especifica su ámbito de visibilidad:
  - `Visibility::Public`: Se transmite a todos los jugadores conectados.
  - `Visibility::Private(PlayerId)`: Únicamente se transmite por la conexión del jugador destinatario.
- **Prevención de Inspección de Memoria de Red**: Los clientes nunca reciben paquetes o eventos con información de las cartas o posiciones del oponente. La filtración ocurre en el Host antes del `broadcast` en la capa de transporte.

---

## 5. Limitaciones Conocidas y Áreas de Mejora

- **Sin Cifrado TLS en Transporte TCP**: El transporte `open_table_transport_tcp` por defecto no incluye cifrado TLS en los sockets TCP directos. Es adecuado para redes locales seguras (LAN) o pruebas local/p2p. Para entornos de producción no confiables sobre Internet público, se recomienda encapsular los sockets en un canal TLS o utilizar el bridge nativo (`open_table_transport_native_bridge`) sobre Nearby Connections / Multipeer Connectivity, los cuales implementan cifrado a nivel de enlace de plataforma.
- **No Resistencia a Colusión entre Jugadores**: Dos clientes legítimos en una partida de más de 2 jugadores podrían comunicarse fuera de banda para compartir información privada entre sí.
