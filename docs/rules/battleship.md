# Reglas de Batalla Naval (`battleship_game`)

## Resumen de Reglas Implementadas
- **Información Oculta**: Cada jugador posee una flota privada oculta al oponente mediante filtrado de visibilidad de eventos (`Visibility`).
- **Fase de Setup**: Colocación de barcos de forma horizontal o vertical sin solapamiento.
- **Fase de Disparos**: Turnos alternados disparando a coordenadas (X, Y) del tablero enemigo.
- **Detección**: Eventos de disparo retornan Agua (Miss), Impacto (Hit) o Hundido (Sunk).
- **Victoria**: Destrucción total de todos los barcos de la flota enemiga.

## Simplificaciones respecto al Juego Estándar
- Tablero de 8x8 (en lugar de 10x10).
- Flota de 3 barcos con tamaños prefijados.
- Sin turno extra tras acertar un disparo.

## Comandos y Eventos Públicos

| Tipo | Nombre | Descripción |
|---|---|---|
| Command | `PlaceFleetCommand` | Posiciona la flota completa durante la fase de preparación. |
| Command | `FireShotCommand` | Efectúa un disparo sobre la grilla oponente. |
| Command | `RematchCommand` | Solicita una revancha al terminar la partida. |
| Event | `FleetPlacedEvent` | Notifica que un jugador ha posicionado sus barcos. |
| Event | `ShotResultEvent` | Notifica el resultado del disparo (Agua, Impacto, Hundido). |
| Event | `SunkenShipEvent` | Notifica que un barco específico ha sido destruido. |
| Event | `GameOverEvent` | Notifica la victoria por eliminación de flota. |
