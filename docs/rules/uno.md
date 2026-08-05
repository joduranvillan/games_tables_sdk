# Reglas de Uno (`uno_game`)

## Resumen de Reglas Implementadas
- **Mazo y Cartas**: Cartas de colores (Rojo, Azul, Verde, Amarillo) y números (0-9). Cartas especiales: Reversa, Salto, Roba 2, Comodín y Comodín Roba 4.
- **Descarte e Impugnación**: Coincidencia por color o valor con la carta superior de la pila de descarte.
- **Dirección de Juego**: Sentido horario que se invierte con la carta Reversa.
- **Robo Automático**: Si no hay carta jugable, se debe robar del mazo.
- **Condición de Victoria**: Primer jugador en quedarse sin cartas en la mano.

## Simplificaciones respecto al Juego Estándar
- Sin botón / penalización por omitir gritar "UNO" verbalmente.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `PlayCardCommand` | Descarta una carta válida de la mano. |
| Command | `DrawCardCommand` | Roba una carta de la pila de robo. |
| Event | `CardPlayedEvent` | Notifica la jugada de una carta. |
| Event | `CardsDrawnEvent` | Notifica la incorporación de cartas a la mano. |
| Event | `TurnReversedEvent` | Notifica la inversión de la dirección de juego. |
| Event | `PlayerSkippedEvent` | Notifica la pérdida del turno de un jugador. |
| Event | `GameOverEvent` | Notifica que un jugador agotó sus cartas. |
