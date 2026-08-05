# Reglas de Go (`go_game`)

## Resumen de Reglas Implementadas
- **Tablero**: Grilla de intersecciones (por defecto 9x9).
- **Colocación y Libertades**: Piedras colocadas en intersecciones. Grupo de piedras sin libertades es capturado y retirado.
- **Regla de Ko**: Prohibición de repetir la posición exacta del tablero inmediatamente anterior.
- **Pasos**: Un jugador puede pasar su turno. Dos pasos consecutivos inician la fase de recuento / marcado de piedras muertas.
- **Handicap**: Colocación inicial de piedras de handicap.

## Simplificaciones respecto al Juego Estándar
- Tablero 9x9 optimizado para partidas rápidas de prueba.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `PlaceStoneCommand` | Coloca una piedra en las coordenadas `(x, y)`. |
| Command | `PassCommand` | Pasa el turno actual. |
| Command | `PlaceHandicapCommand` | Coloca piedras de handicap en la fase inicial. |
| Command | `MarkDeadCommand` | Marca grupos como muertos en la fase de finalización. |
| Command | `ConfirmDeadCommand` | Confirma la marcación de piedras muertas para el cálculo de puntos. |
| Event | `StonePlacedEvent` | Notifica la colocación de una piedra. |
| Event | `StonesCapturedEvent` | Notifica la captura y eliminación de piedras enemigas. |
| Event | `PassedEvent` | Notifica la acción de pasar turno. |
| Event | `GameOverEvent` | Notifica la victoria por puntaje de territorio o resignación. |
