# Política de Privacidad — OpenTable: 13 Classic Board & Card Games
**Última actualización:** Octubre 2026  
**Cumplimiento normativo:** GDPR (Unión Europea), CCPA (California), Google Play User Data Policy, Apple App Store Privacy Guidelines y Steam Distribution Terms.

---

## 1. Principio de Privacidad por Diseño (Cero Rastreadores)
**OpenTable** ha sido diseñado bajo el principio de minimización absoluta de datos:
- **Sin SDKs de rastreo ni publicidad:** La aplicación no integra analíticas de terceros, redes publicitarias, píxeles de seguimiento ni perfilado comercial.
- **Sin cuentas obligatorias ni datos personales:** No solicitamos ni recopilamos nombre real, dirección de correo electrónico, número de teléfono, ubicación GPS, lista de contactos ni identificadores publicitarios (IDFA/GAID).

---

## 2. Datos Almacenados Localmente en el Dispositivo
Los siguientes datos se guardan exclusivamente en el almacenamiento local del usuario (`user://`):
- **Preferencias de configuración (`user://settings.cfg`):** Idioma, volumen de audio, tema visual, modo de accesibilidad daltónico, escala tipográfica y preferencia de modo Offline/Online.
- **Estadísticas y partidas guardadas (`user://stats.cfg`, `user://saves/`):** Historial local de partidas, rachas y repeticiones.

---

## 3. Funciones Online Opcionales (UUID Anónimo de Dispositivo)
Si el jugador acepta habilitar las funciones en línea (Servidor Relay, Matchmaking, Torneos y Clasificación ELO):
1. **Identificador Anónimo (`device_id`):** Se genera localmente un identificador aleatorio **UUID v4** (`user://identity.cfg`) del cual se deriva un identificador público pseudónimo (`guest_<hash>`).
2. **Finalidad:** Este identificador se utiliza **exclusivamente** para:
   - Emitir un token temporal de sesión (JWT) para autenticar reconexiones durante una partida activa en el servidor Relay.
   - Asociar la puntuación competitiva ELO y el emparejamiento (matchmaking) sin vincularlo a la identidad civil del jugador.
3. **No Compartición con Terceros:** Ningún dato transmitido al servidor Relay oficial o autoalojado es vendido, cedido ni compartido con terceros bajo ninguna circunstancia.

---

## 4. Modo 100% Local / Offline
En el primer arranque (y en cualquier momento desde los ajustes), el jugador puede elegir **"Solo Modo Local / Offline"**:
- En este modo, el juego funciona al **100% en partidas locales (Hotseat) y contra la Inteligencia Artificial (vs IA)** en los 13 juegos de la colección.
- No se realiza **ninguna conexión HTTP ni WebSocket externa**.

---

## 5. Derechos del Usuario (Acceso, Supresión y Portabilidad)
- **Eliminación instantánea:** El usuario puede restablecer o borrar su UUID anónimo y sus estadísticas eliminando los archivos locales `user://identity.cfg` y `user://stats.cfg` o desinstalando la aplicación.
- **Servidores autoalojados:** Al ser un proyecto de arquitectura abierta, el usuario puede apuntar el cliente a su propio servidor Relay local o privado desde el menú de Ajustes.

---

# Privacy Policy (English Summary)
- **Zero Third-Party Trackers:** OpenTable contains no third-party analytics, telemetry, or advertising SDKs.
- **Anonymous Device UUID Only:** When optional online play (Relay / Matchmaking / ELO) is enabled, OpenTable only generates and stores a random anonymous **UUID v4** (`user://identity.cfg`) to maintain ELO ratings and session reconnection. No personally identifiable information (PII) is collected or shared with third parties.
- **100% Offline Mode:** Players may decline online features on first launch and enjoy all 13 games locally (Hotseat & vs AI) with zero external network requests.
