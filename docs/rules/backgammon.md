# Reglas de Backgammon (`backgammon_game`)

## Resumen de Reglas Implementadas
- **Tablero**: 24 puntos (triángulos), barra central y área de bear-off (extracción).
- **Dados**: Tirada de 2 dados de 6 caras. Si se sacan dobles, se otorgan 4 movimientos del valor del dado.
- **Movimiento**: Fichas avanzan según los dados. Captura de fichas individuales ("blots") enviándolas a la barra. Reingreso obligatorio desde la barra antes de mover otras fichas.
- **Bear-off**: Extracción de fichas cuando todas las fichas del jugador están en el cuadrante de casa.
- **Doubling Cube**: Oferta, aceptación y rechazo del dado de doblaje.
- **Paso Automático**: Notificación de falta de movimientos válidos (`NoValidMovesEvent`).

## Simplificaciones respecto al Juego Estándar
- La regla de extracción en caso de tiro superior ("overshoot") se simplifica cuando no hay fichas en puntos más lejanos.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `RollDiceCommand` | Solicita lanzar los dados al inicio del turno. |
| Command | `MoveCheckerCommand` | Mueve una ficha de un punto a otro consumiendo un dado. |
| Command | `OfferDoubleCommand` | Ofrece doblar la apuesta con el Doubling Cube. |
| Command | `AcceptDoubleCommand` | Acepta el doblaje propuesto. |
| Command | `RejectDoubleCommand` | Rechaza el doblaje, rindiéndose en la ronda. |
| Event | `DiceRolledEvent` | Notifica los valores de los dados obtenidos. |
| Event | `CheckerMovedEvent` | Notifica el desplazamiento o captura de una ficha. |
| Event | `DoubleOfferedEvent` | Notifica la propuesta de doblaje. |
| Event | `DoubleAcceptedEvent` | Notifica la aceptación del doblaje. |
| Event | `DoubleRejectedEvent` | Notifica el rechazo del doblaje. |
| Event | `NoValidMovesEvent` | Notifica que el jugador no tiene movimientos válidos. |
| Event | `GameOverEvent` | Notifica la victoria por bear-off completo o abandono. |
