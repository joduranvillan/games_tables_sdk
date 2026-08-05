# Reglas de Damas Chinas (`chinese_checkers.md`)

## Resumen de Reglas Implementadas
- **Geometría del Tablero**: Sistema de coordenadas hexagonales axiales `(q, r)`.
- **Movimiento**: Traslado a casilla adyacente o salto sobre una clavija (peg) propia o enemiga a una casilla vacía simétrica.
- **Sin Capturas**: Los saltos no eliminan piezas del tablero.
- **Objetivo**: Mover todas las fichas desde el triángulo inicial de casa hasta la esquina opuesta del tablero.

## Simplificaciones respecto al Juego Estándar
- Tablero hexagonal simplificado (radio de tablero reducido) en lugar del tablero tradicional con forma de estrella de 6 puntas completa.
- Sin saltos múltiples encadenados en una sola acción de comando.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `MovePegCommand` | Solicita mover una clavija desde `from` hasta `to`. |
| Event | `PegMovedEvent` | Notifica el movimiento o salto de una clavija. |
| Event | `GameOverEvent` | Notifica que un jugador completó la ocupación de la esquina meta. |
