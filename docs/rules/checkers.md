# Reglas de Damas (`checkers_game`)

## Resumen de Reglas Implementadas
- **Tablero**: Grilla de 8x8 con casillas oscuras activas.
- **Movimiento**: Fichas normales mueven 1 paso en diagonal hacia adelante.
- **Captura**: Salto sobre ficha rival a casilla vacía posterior, retirando la ficha capturada. Soporta capturas obligatorias y cadenas de múltiples capturas.
- **Coronación**: Una ficha que alcanza la última fila rival se corona como Dama (Rey), permitiendo movimiento y captura en ambas direcciones diagonales.
- **Condición de Victoria**: Un jugador gana cuando el oponente se queda sin fichas o no tiene movimientos legales disponibles.

## Simplificaciones respecto al Juego Estándar
- Tablero estándar de 8x8 (Damas americanas/inglesas). No se implementa la variante internacional de 10x10.
- Movimiento de Dama de 1 casilla (no "dama voladora" de longitud libre).

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `MovePieceCommand` | Solicita mover o capturar con una ficha desde `from` hasta `to`. |
| Event | `PieceMovedEvent` | Notifica que una ficha se movió, capturó o fue coronada. |
| Event | `GameOverEvent` | Notifica la finalización de la partida y el jugador ganador. |
