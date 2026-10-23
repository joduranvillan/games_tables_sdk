# UNO (`uno_game`) — Documentación Técnica del Juego

## 1. Resumen de Reglas Oficiales Implementadas
- **Mazo oficial de 108 cartas** distribuido en 4 colores (`Red`, `Yellow`, `Green`, `Blue`) con cartas numéricas (`0..9`), cartas de acción (`Skip`, `Reverse`, `DrawTwo`) y comodines (`Wild`, `WildDrawFour`), repartiendo 7 cartas iniciales por jugador.
- **Reglas de Acción y 2 Jugadores**:
  - En partidas de 2 jugadores, `Reverse` actúa exactamente como `Skip`, otorgando turno inmediato de nuevo al jugador que la lanzó.
  - Si al robar del mazo (`DrawCardCommand`) la carta obtenida es jugable sobre el descarte actual, el motor la juega automáticamente emitiendo `DrewAndPlayedEvent`.
- **Grito de "¡UNO!" y Penalización (`CallUnoCommand`, `CatchUnoFailureCommand`)**:
  - Cuando un jugador queda con exactamente **1 carta** en la mano, debe cantar `"¡UNO!"` mediante `CallUnoCommand`.
  - Si no lo hace antes de que un rival envíe `CatchUnoFailureCommand`, el jugador infractor recibe una penalización automática de **+2 cartas** (`UnoPenaltyEvent`).
- **Desafío Formal de `WildDrawFour` (`ChallengeWildDrawFourCommand`)**:
  - Si un jugador lanza `WildDrawFour`, el jugador afectado puede desafiar la legalidad de la jugada con `ChallengeWildDrawFourCommand`:
    - Si el lanzador tenía en su mano alguna carta del color activo previo (`was_illegal: true`), el lanzador es penalizado robando **4 cartas**.
    - Si el `WildDrawFour` fue jugado legalmente (`was_illegal: false`), el desafiante roba **6 cartas** (las 4 del comodín más 2 de penalización).
- **Intercepción Exacta (*Jump-In* — `InterceptCommand`)**:
  - Cualquier jugador que posea una carta idéntica en color y valor a la carta superior del descarte puede interceptar el turno fuera de orden.

## 2. Tabla Completa de Comandos (`Commands`)
| Comando | Descripción | Esquema JSON Exacto (`#[typetag::serde]`) |
|---|---|---|
| `PlayCardCommand` | Juega la carta en `card_index` de la mano, eligiendo `chosen_color` si es comodín (`"Red"`, `"Yellow"`, `"Green"`, `"Blue"` o `null`). | `{"command_type": "uno_game::PlayCardCommand", "player": 1, "card_index": 0, "chosen_color": "Red"}` |
| `DrawCardCommand` | Roba del mazo (o absorbe la pila acumulada de `+2`/`+4`). | `{"command_type": "uno_game::DrawCardCommand", "player": 1}` |
| `CallUnoCommand` | Declara `"¡UNO!"` al quedarse con 1 sola carta en la mano. | `{"command_type": "uno_game::CallUnoCommand", "player": 1}` |
| `CatchUnoFailureCommand` | Acusa al jugador `target` que tiene 1 carta y olvidó cantar `"¡UNO!"`, haciéndole robar 2 cartas. | `{"command_type": "uno_game::CatchUnoFailureCommand", "accuser": 2, "target": 1}` |
| `ChallengeWildDrawFourCommand` | Desafía la legalidad de un `WildDrawFour` recién jugado contra el jugador `challenger`. | `{"command_type": "uno_game::ChallengeWildDrawFourCommand", "challenger": 2}` |
| `InterceptCommand` | Ejecuta un *Jump-In* fuera de turno jugando una carta exactamente igual a la cima del descarte. | `{"command_type": "uno_game::InterceptCommand", "player": 2, "card_index": 1}` |

## 3. Tabla Completa de Eventos (`Events`)
| Evento | Campos | Esquema JSON Exacto |
|---|---|---|
| `CardPlayedEvent` | `player: PlayerId`, `card: Card`, `new_color: CardColor` | `{"event_type": "uno_game::CardPlayedEvent", "player": 1, "card": {"color": "Red", "value": {"Number": 5}}, "new_color": "Red"}` |
| `CardsDrawnEvent` | `player: PlayerId`, `count: usize` | `{"event_type": "uno_game::CardsDrawnEvent", "player": 2, "count": 2}` |
| `DrewAndPlayedEvent` | `player: PlayerId`, `card: Card`, `new_color: CardColor` | `{"event_type": "uno_game::DrewAndPlayedEvent", "player": 1, "card": {"color": "Blue", "value": "Skip"}, "new_color": "Blue"}` |
| `TurnReversedEvent` | *(unidad)* | `{"event_type": "uno_game::TurnReversedEvent"}` |
| `PlayerSkippedEvent` | `skipped_player: PlayerId` | `{"event_type": "uno_game::PlayerSkippedEvent", "skipped_player": 2}` |
| `InterceptedEvent` | `player: PlayerId`, `card: Card` | `{"event_type": "uno_game::InterceptedEvent", "player": 2, "card": {"color": "Red", "value": {"Number": 5}}}` |
| `UnoCalledEvent` | `player: PlayerId` | `{"event_type": "uno_game::UnoCalledEvent", "player": 1}` |
| `UnoPenaltyEvent` | `target: PlayerId`, `accuser: PlayerId`, `drawn: usize` | `{"event_type": "uno_game::UnoPenaltyEvent", "target": 1, "accuser": 2, "drawn": 2}` |
| `WildDrawFourChallengedEvent` | `challenger: PlayerId`, `target: PlayerId`, `was_illegal: bool`, `penalty_player: PlayerId`, `cards_drawn: usize` | `{"event_type": "uno_game::WildDrawFourChallengedEvent", "challenger": 2, "target": 1, "was_illegal": true, "penalty_player": 1, "cards_drawn": 4}` |
| `GameOverEvent` | `winner: PlayerId` | `{"event_type": "uno_game::GameOverEvent", "winner": 1}` |

## 4. Flujo de Partida de Referencia
1. **Inicio**: `new_uno_session(SessionId(1), seed, vec![PlayerId(1), PlayerId(2)])` reparte 7 cartas a cada jugador y voltea la primera carta numérica.
2. **Descarte y Acción**: Los jugadores alternan `PlayCardCommand` y `DrawCardCommand`.
3. **Penúltima Carta**: Al quedar con 1 carta, Jugador 1 envía `CallUnoCommand` (`UnoCalledEvent`) evitando ser penalizado por `CatchUnoFailureCommand`.
4. **Fin**: Al descartar su última carta se emite `GameOverEvent`.
