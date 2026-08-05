# Reglas de Mil Millas (`mille_bornes_game`)

## Resumen de Reglas Implementadas
- **Mazo y Manos Privadas**: Manos secretas de cartas filtradas mediante visibilidad de eventos.
- **Acumulación de Distancia**: Cartas de 25, 50, 75, 100 y 200 km.
- **Peligros y Remedios**: Ataques (Límite de velocidad, Sin gasolina, Pinchazo, Accidente, Luz roja) y sus defensas.
- **Cartas de Seguridad**: Protección permanente contra ataques específicos.
- **Rebarajado**: Reconstitución automática del mazo cuando se agotan las cartas.

## Simplificaciones respecto al Juego Estándar
- Meta fija en 1000 km (o 200 km en partidas cortas).
- Sin implementación de la regla "coup fourré" con respuesta inmediata fuera de turno.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `SetupDeckCommand` | Inicializa el mazo y reparte cartas iniciales. |
| Command | `DrawCardCommand` | Roba una carta del mazo. |
| Command | `PlayDistanceCommand` | Juega una carta de distancia. |
| Command | `PlayHazardCommand` | Aplica una carta de peligro al rival. |
| Command | `PlaySafetyCommand` | Equipa una carta de seguridad. |
| Command | `DiscardCardCommand` | Descarta una carta de la mano. |
| Event | `CardDrawnEvent` | Notifica el robo de carta. |
| Event | `DistancePlayedEvent` | Notifica el avance de kilómetros. |
| Event | `HazardPlayedEvent` | Notifica un ataque al rival. |
| Event | `RemedyPlayedEvent` | Notifica la reparación de un ataque. |
| Event | `SafetyPlayedEvent` | Notifica la activación de seguridad. |
| Event | `CardDiscardedEvent` | Notifica el descarte de una carta. |
| Event | `GameOverEvent` | Notifica la llegada a la distancia meta. |
