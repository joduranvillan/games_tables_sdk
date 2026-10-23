# Damas Chinas (`chinese_checkers_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Estrella hexagonal oficial de 121 casillas**: centro hexagonal de radio 4 (`BOARD_RADIUS = 4`) más 6 puntas triangulares de 10 casillas cada una en coordenadas axiales `(q, r)`.
- **Soporte multijugador simétrico (2, 3, 4 o 6 jugadores)**: asignación automática de triángulos de salida y triángulos de meta directamente opuestos.
- **Movimiento y Saltos en Cadena**:
  - Paso simple a cualquiera de las 6 casillas hexagonales adyacentes vacías.
  - Saltos encadenados (`path`) sobre canicas adyacentes (propias o ajenas) aterrizando en la casilla simétrica inmediatamente posterior, sin retirar nunca las fichas saltadas.
- **Regla Oficial Anti-Bloqueo (*Home-Camp Spoiling Rule*)**:
  - Ninguna canica que haya ingresado a su triángulo de meta opuesto puede abandonarlo.
  - Si las 10 casillas del triángulo objetivo de un jugador están completamente ocupadas y al menos una canica pertenece a dicho jugador (aunque existan canicas rivales bloqueando posiciones internas), se adjudica la victoria legítima.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `MovePegCommand` | Mueve una canica desde `from` hasta `to`, especificando opcionalmente la secuencia de saltos en `path`. | `{"command_type": "chinese_checkers_game::MovePegCommand", "player": 1, "from": {"q": -5, "r": 1}, "to": {"q": -3, "r": 1}, "path": [{"q": -3, "r": 1}]}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al adversario. | `{"command_type": "chinese_checkers_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `PegMovedEvent` | `player: PlayerId`, `from: Position`, `to: Position`, `was_jump: bool` | `{"event_type": "chinese_checkers_game::PegMovedEvent", "player": 1, "from": {"q": -5, "r": 1}, "to": {"q": -3, "r": 1}, "was_jump": true}` |
| `GameOverEvent` | `winner: Option<PlayerId>` | `{"event_type": "chinese_checkers_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_chinese_checkers_session(SessionId(1), seed, vec![PlayerId(1), PlayerId(2)])` coloca 10 canicas en las puntas norte y sur de la estrella de 121 casillas.
2. **Despliegue**: Jugador 1 avanza una canica un paso adyacente (`was_jump: false`).
3. **Escalera de Saltos**: Jugador 1 encadena múltiples saltos sobre fichas propias y rivales usando `MovePegCommand` (`was_jump: true`).
4. **Fin**: Al completar las 10 casillas del triángulo objetivo opuesto se emite `GameOverEvent`.
