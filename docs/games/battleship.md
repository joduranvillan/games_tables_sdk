# Batalla Naval (`battleship_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Cuadrícula oficial de 10×10** (`row: 0..9`, `col: 0..9`) con niebla de guerra estricta.
- **Flota completa de 5 buques (17 segmentos en total)**:
  - Portaaviones (longitud `5`), Acorazado (`4`), Crucero (`3`), Submarino (`3`) y Destructor (`2`).
- **Fase de Despliegue Simultáneo (`PlaceFleetCommand`)**:
  - Cada jugador posiciona sus 5 barcos dentro de los límites de 10×10, sin superposiciones ni contacto adyacente inválido.
  - `FleetPlacedEvent` confirma públicamente que el jugador desplegó su flota sin revelar ninguna coordenada.
- **Fase de Combate y Regla Configurable de Ráfaga (`BattleshipRulesConfig`)**:
  - Cada disparo (`FireShotCommand`) devuelve `ShotResult::Miss`, `ShotResult::Hit` o `ShotResult::Sunk`.
  - Cuando se hunde un buque completo, se emite `SunkenShipEvent` con sus posiciones exactas.
  - Mediante `SetBattleshipRulesCommand { extra_turn_on_hit: true }`, acertar un disparo (`Hit` o `Sunk`) conserva el turno para seguir disparando.
- **Revancha y Rendición**: soporte para `RematchCommand` (reinicia al recibir confirmación de ambos jugadores) y `ResignCommand`.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `PlaceFleetCommand` | Despliega la flota completa de 5 barcos durante la fase inicial. | `{"command_type": "battleship_game::PlaceFleetCommand", "player": 1, "ships": [{"origin": {"row": 0, "col": 0}, "length": 5, "orientation": "Horizontal"}, {"origin": {"row": 2, "col": 0}, "length": 4, "orientation": "Horizontal"}, {"origin": {"row": 4, "col": 0}, "length": 3, "orientation": "Horizontal"}, {"origin": {"row": 6, "col": 0}, "length": 3, "orientation": "Horizontal"}, {"origin": {"row": 8, "col": 0}, "length": 2, "orientation": "Horizontal"}]}` |
| `FireShotCommand` | Dispara un proyectil a la coordenada `target` del tablero enemigo. | `{"command_type": "battleship_game::FireShotCommand", "player": 1, "target": {"row": 3, "col": 4}}` |
| `SetBattleshipRulesCommand` | Activa o desactiva la variante de turno extra al acertar (`extra_turn_on_hit`). | `{"command_type": "battleship_game::SetBattleshipRulesCommand", "extra_turn_on_hit": true}` |
| `RematchCommand` | Solicita revancha tras finalizar la partida. | `{"command_type": "battleship_game::RematchCommand", "player": 1}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al comandante rival. | `{"command_type": "battleship_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `FleetPlacedEvent` | `player: PlayerId` | `{"event_type": "battleship_game::FleetPlacedEvent", "player": 1}` |
| `ShotResultEvent` | `shooter: PlayerId`, `target: Position`, `result: ShotResult` (`"Miss"`, `"Hit"`, `"Sunk"`) | `{"event_type": "battleship_game::ShotResultEvent", "shooter": 1, "target": {"row": 3, "col": 4}, "result": "Hit"}` |
| `SunkenShipEvent` | `player: PlayerId`, `ship_type: usize`, `positions: Vec<Position>` | `{"event_type": "battleship_game::SunkenShipEvent", "player": 2, "ship_type": 2, "positions": [{"row": 8, "col": 0}, {"row": 8, "col": 1}]}` |
| `GameOverEvent` | `winner: Option<PlayerId>` | `{"event_type": "battleship_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio y Configuración**: Opcionalmente se envía `SetBattleshipRulesCommand` y ambos comandantes ejecutan `PlaceFleetCommand`.
2. **Bombardeo**: Jugador 1 envía `FireShotCommand` hacia `{"row": 0, "col": 0}`; se emite `ShotResultEvent`.
3. **Hundimiento**: Al impactar todas las casillas de un barco rival, se emite `ShotResultEvent` con `"Sunk"` seguido de `SunkenShipEvent`.
4. **Fin**: Al hundir los 5 buques rivales (17 impactos) se emite `GameOverEvent`.
