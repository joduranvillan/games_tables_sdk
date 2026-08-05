# Reglas de Shogi (`shogi_game`)

## Resumen de Reglas Implementadas
- **Tablero**: Grilla de 9x9 con dos bandos (Sente y Gote).
- **Mecánica de Drops (Reingreso)**: Piezas capturadas pasan a la mano del captor y pueden ser reintroducidas en el tablero mediante `DropPieceCommand`.
- **Promoción**: Promoción de piezas al ingresar o mover dentro de la zona de promoción rival.
- **Jaque y Jaque Mate**: Validación de seguridad del Rey y detección de fin de partida.

## Simplificaciones respecto al Juego Estándar
- Restricciones avanzadas de reingreso (como la prohibición de dos peones no promovidos en la misma columna - *Nifu*) se simplifican en la primera fase del motor.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `MovePieceCommand` | Mueve o captura con una pieza en el tablero. |
| Command | `DropPieceCommand` | Reintroduce una pieza capturada desde la mano al tablero. |
| Event | `PieceMovedEvent` | Notifica el movimiento o promoción de una pieza. |
| Event | `PieceDroppedEvent` | Notifica la reintroducción de una pieza desde la mano. |
| Event | `GameOverEvent` | Notifica la victoria por jaque mate o rendición. |
