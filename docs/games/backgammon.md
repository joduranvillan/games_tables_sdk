# Backgammon (`backgammon_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Tablero estándar de 24 picos (`POINTS = 24`)** con 15 fichas por jugador, Barra central (`bar`) y zona de retirada (*Bear-Off*).
- **Tiradas, Dobles y Uso Obligatorio de Dados**:
  - Tirada de dos dados de 6 caras (`RollDiceCommand`); si ambos dados coinciden (dobles), el jugador dispone de 4 movimientos de ese valor.
  - **Regla oficial de uso obligatorio del máximo de dados**: si el jugador puede utilizar ambos dados en algún orden legal, está obligado a no elegir una jugada que bloquee el segundo dado; si solo puede usar uno de los dos dados, debe jugar obligatoriamente el dado de mayor valor.
- **Capturas (*Blot / Hit*) y Reingreso desde la Barra**:
  - Aterrizar sobre un pico ocupado por una sola ficha rival la envía a la Barra (`captured_opponent: true`).
  - Ninguna ficha puede moverse en el tablero mientras el jugador tenga fichas pendientes de reingresar desde la Barra (`from: null`).
- **Retirada (*Bearing Off*) y Puntuación Triple**:
  - Una vez que las 15 fichas propias se encuentran en el cuadrante interior (*Home Board*), pueden retirarse con tirada exacta o con un dado superior desde el pico ocupado más lejano.
  - Victoria simple (×1), **Gammon** (×2 si el rival no retiró ninguna ficha) y **Backgammon** (×3 si además el rival conserva fichas en la Barra o en el cuadrante interior del ganador).
- **Cubo de Doblaje (*Doubling Cube*) y Regla Crawford (`MatchStateResource`)**:
  - Antes de lanzar los dados en su turno, el jugador que posee el acceso al cubo puede proponer duplicar el valor de la partida (`OfferDoubleCommand`), salvo durante el juego Crawford (`crawford_game: true`).
  - El rival debe responder con `AcceptDoubleCommand` (duplicando el cubo y tomando su posesión exclusiva) o `RejectDoubleCommand` (cediendo el juego actual por el valor vigente del cubo).

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `RollDiceCommand` | Lanza los dos dados al inicio del turno. | `{"command_type": "backgammon_game::RollDiceCommand", "player": 1}` |
| `MoveCheckerCommand` | Mueve una ficha desde el pico `from` (`null` si entra desde la barra) usando el dado `die`. | `{"command_type": "backgammon_game::MoveCheckerCommand", "player": 1, "from": 0, "die": 3}` |
| `OfferDoubleCommand` | Propone doblar la apuesta actual con el Cubo de Doblaje antes de tirar los dados. | `{"command_type": "backgammon_game::OfferDoubleCommand", "player": 1}` |
| `AcceptDoubleCommand` | Acepta el doblaje propuesto por el rival, duplica el cubo y asume su propiedad. | `{"command_type": "backgammon_game::AcceptDoubleCommand", "player": 2}` |
| `RejectDoubleCommand` | Rechaza el doblaje propuesto y concede la partida actual al valor previo del cubo. | `{"command_type": "backgammon_game::RejectDoubleCommand", "player": 2}` |
| `ResignCommand` | Se rinde inmediatamente y adjudica la victoria al adversario. | `{"command_type": "backgammon_game::ResignCommand", "player": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `DiceRolledEvent` | `player: PlayerId`, `values: Vec<u32>` | `{"event_type": "backgammon_game::DiceRolledEvent", "player": 1, "values": [3, 5]}` |
| `CheckerMovedEvent` | `player: PlayerId`, `from: Option<usize>`, `to: Option<usize>`, `captured_opponent: bool`, `borne_off: bool` | `{"event_type": "backgammon_game::CheckerMovedEvent", "player": 1, "from": 0, "to": 3, "captured_opponent": false, "borne_off": false}` |
| `NoValidMovesEvent` | `player: PlayerId` | `{"event_type": "backgammon_game::NoValidMovesEvent", "player": 1}` |
| `DoubleOfferedEvent` | `player: PlayerId` | `{"event_type": "backgammon_game::DoubleOfferedEvent", "player": 1}` |
| `DoubleAcceptedEvent` | `player: PlayerId`, `value: u32` | `{"event_type": "backgammon_game::DoubleAcceptedEvent", "player": 2, "value": 2}` |
| `DoubleRejectedEvent` | `player: PlayerId`, `value: u32` | `{"event_type": "backgammon_game::DoubleRejectedEvent", "player": 2, "value": 1}` |
| `GameOverEvent` | `winner: PlayerId`, `gammon: bool`, `backgammon: bool`, `score: u32` | `{"event_type": "backgammon_game::GameOverEvent", "winner": 1, "gammon": true, "backgammon": false, "score": 4}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_backgammon_session(SessionId(1), seed, PlayerId(1), PlayerId(2))` coloca las 15 fichas de cada jugador en su disposición clásica y el cubo en `1` centrado.
2. **Tirada y Movimiento**: Jugador 1 envía `RollDiceCommand` y ejecuta `MoveCheckerCommand` para cada dado disponible.
3. **Doblaje**: Con ventaja posicional o de pips, Jugador 1 envía `OfferDoubleCommand`; Jugador 2 acepta con `AcceptDoubleCommand` (`value: 2`).
4. **Cierre**: Al retirar la decimoquinta ficha (`borne_off: true`) se emite `GameOverEvent` con el cálculo de Gammon/Backgammon multiplicado por el cubo.
