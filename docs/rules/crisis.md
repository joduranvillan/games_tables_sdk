# Reglas de Crisis (`crisis_game`)

Motor de estrategia y conquista territorial por turnos inspirado en las reglas clásicas de T.E.G. (Plan Táctico y Estratégico de Guerra) y Risk, implementado sobre `open_table_engine` y Bevy ECS.

---

## 1. Tablero Geográfico y Continentes (`board.rs`)

El mapa mundial está compuesto por **30 territorios** conectados mediante un grafo de adyacencias (`ADJACENCIES`), organizados en **6 continentes**:

| Continente | ID | Territorios | Bonus de Ejércitos |
|---|---|---|:---:|
| **América del Sur** | `0` | Argentina, Brasil, Chile, Colombia, Perú (5) | **+3** |
| **América del Norte** | `1` | México, California, Nueva York, Canadá (4) | **+5** |
| **Europa** | `2` | Gran Bretaña, España, Francia, Alemania, Polonia (5) | **+5** |
| **África** | `3` | Sahara, Egipto, Etiopía, Sudáfrica (4) | **+3** |
| **Asia** | `4` | Rusia, China, India, Japón, Siberia, Kamchatka, Medio Oriente, Sudeste Asiático (8) | **+7** |
| **Oceanía** | `5` | Australia, Sumatra, Borneo, Java (4) | **+2** |

### Conexiones Intercontinentales Clave
- **América del Sur ↔ América del Norte**: Colombia ↔ México.
- **América del Sur ↔ África**: Brasil ↔ Sahara.
- **América del Sur ↔ Oceanía**: Chile ↔ Australia.
- **América del Norte ↔ Europa**: Nueva York ↔ España.
- **América del Norte ↔ Asia**: Canadá ↔ Siberia.
- **Europa ↔ África**: España ↔ Sahara.
- **Europa ↔ Asia**: Alemania ↔ Rusia, Polonia ↔ Rusia, Polonia ↔ China.
- **África ↔ Asia**: Egipto ↔ Medio Oriente.
- **Asia ↔ Oceanía**: Sudeste Asiático ↔ Sumatra, India ↔ Sumatra, China ↔ Borneo.

---

## 2. Estructura de Fases del Turno (`TurnPhase`)

Cada turno de un jugador transcurre a través de las siguientes fases secuenciales gestionadas en `TurnStateResource`:

```
┌─────────────────────────┐
│   1. Colocar Ejércitos  │ ◄─── Incorporación base + bonus continental + canjes
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│       2. Ataque         │ ◄─── Declaración y resolución de combates con dados
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│     3. Reagrupamiento   │ ◄─── Movimiento táctico entre territorios conectados
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│     4. Fin de Turno     │ ◄─── Pasa al siguiente jugador activo
└─────────────────────────┘
```

1. **`PlaceArmies { armies_remaining }`**:
   - Al inicio del turno se calculan los ejércitos disponibles: $\max(3, \lfloor \text{territorios} / 2 \rfloor) + \text{bonus de continentes completos}$.
   - Si el jugador posee **5 o más tarjetas de territorio**, está obligado a realizar un canje (`ExchangeCardsCommand`) antes de colocar tropas.
   - El jugador asigna sus tropas con `PlaceArmiesCommand`. Al agotar sus ejércitos (`armies_remaining == 0`), la fase avanza automáticamente a `Attack`.

2. **`Attack`**:
   - El jugador puede declarar y resolver múltiples ataques a territorios enemigos adyacentes.
   - Para concluir la fase de combate, emite `EndPhaseCommand`, avanzando a `Fortify`.

3. **`Fortify`**:
   - Permite un único movimiento táctico de tropas (`FortifyCommand`) entre territorios controlados por el jugador que se encuentren conectados por una ruta ininterrumpida de territorios propios (`are_connected_by_owner`).
   - Siempre debe quedar al menos **1 ejército** de guarnición en el territorio de origen.
   - Para finalizar, emite `EndPhaseCommand` (o se avanza automáticamente tras fortificar).

4. **`EndTurn`**:
   - Cierre del turno y rotación del control al siguiente jugador activo en `TurnResource`, salteando jugadores eliminados.

---

## 3. Combate y Conquista Territorial

### Declaración y Tirada de Dados
1. **Declaración (`DeclareAttackCommand`)**:
   - Se selecciona territorio atacante (`from`), territorio defensor (`to`) adyacente y cantidad de dados (`dice`: entre 1 y 3).
   - Condición: El atacante debe disponer de al menos `dice + 1` ejércitos en `from`.
2. **Resolución (`RollAttackCommand`)**:
   - El atacante lanza sus dados declarados (1 a 3).
   - El defensor lanza automáticamente $\min(3, \text{ejércitos en } to)$ dados.
   - Los dados se ordenan de mayor a menor y se comparan individualmente:
     - Si el dado del atacante es estrictamente mayor que el del defensor, el defensor pierde 1 ejército.
     - **En caso de empate o dado menor, el atacante pierde 1 ejército** (el empate favorece a la defensa).
   - Se emite `AttackResolvedEvent` detallando las tiradas y bajas de ambos bandos.

### Conquista (`TerritoryConqueredEvent`)
- Si los ejércitos del territorio defensor llegan a 0:
  1. El territorio pasa a ser propiedad del atacante.
  2. Las tropas atacantes victoriosas se trasladan al territorio conquistado.
  3. Si es la **primera conquista del turno**, el atacante roba una tarjeta de territorio (`TerritoryCard`), con símbolo `Infantry`, `Cavalry`, `Cannon` o comodín `Wild`.

---

## 4. Tarjetas de Territorio y Canjes (`ExchangeCardsCommand`)

Los jugadores acumulan tarjetas al conquistar territorios durante sus turnos. En la fase de colocación de tropas, pueden canjear un trío válido (`card_indices: [usize; 3]`):

### Combinaciones Válidas (`is_valid_card_set`)
- **3 del mismo símbolo** (3 Infanterías, 3 Caballerías o 3 Cañones).
- **1 de cada símbolo** (1 Infantería + 1 Caballería + 1 Cañón).
- **Cualquier combinación con comodín (`Wild`)**.

### Escala Progresiva de Ejércitos
Gestionada en `ExchangeCountResource`:
- **1º canje global**: +4 ejércitos.
- **2º canje global**: +6 ejércitos.
- **3º canje global**: +8 ejércitos.
- **$N$-ésimo canje ($N \ge 4$)**: $8 + (N - 3) \times 5$ ejércitos (ej. 4º canje = +13, 5º canje = +18).

---

## 5. Objetivos Secretos y Condición de Victoria

Al inicio de la partida, cada jugador recibe una tarjeta de objetivo secreto (`ObjectiveCard`) almacenada en `PlayerObjectivesResource`:

- **`ConquerContinent(ContinentId)`**: Conquistar la totalidad de un continente específico.
- **`ConquerTwoSmallContinents`**: Conquistar y mantener al menos 2 continentes de 5 territorios o menos.
- **`Exterminate(PlayerId)`**: Destruir y eliminar completamente a un jugador objetivo. *(Si el objetivo es eliminado por otro participante, el objetivo transmuta a conquistar 24 territorios)*.
- **`ConquerTerritories(u8)`**: Ocupar una cantidad requerida de territorios con al menos 2 ejércitos en cada uno.
- **Victoria Común**: Conquistar los 30 territorios del mapa mundial.

Tras cada conquista o resolución de combate, `check_objective` evalúa las condiciones de victoria. Al cumplirse, se emite `TegGameOverEvent` y se declaran `GameOverResource(true)` y `WinnerResource(Some(winner))`.

---

## 6. Eliminación de Jugadores (`PlayerEliminatedEvent`)

- Si un jugador pierde su último territorio en el tablero, queda eliminado de la partida (`EliminatedPlayersResource`).
- El jugador atacante que propinó el golpe de gracia **hereda todas las tarjetas de territorio** del jugador eliminado.
- La rotación de turnos omite permanentemente a los jugadores eliminados.

---

## 7. Comandos y Eventos Públicos

### Comandos (`GameCommand`)

| Comando | Campos | Descripción |
|---|---|---|
| `PlaceArmiesCommand` | `player`, `territory`, `count` | Coloca ejércitos disponibles en un territorio propio durante la fase `PlaceArmies`. |
| `ExchangeCardsCommand` | `player`, `card_indices` | Canjea 3 tarjetas de territorio válidas por un bono de ejércitos adicionales. |
| `DeclareAttackCommand` | `player`, `from`, `to`, `dice` | Declara un ataque desde un territorio propio hacia uno enemigo adyacente. |
| `RollAttackCommand` | `player` | Ejecuta la tirada de dados y resolución del combate declarado pendiente. |
| `FortifyCommand` | `player`, `from`, `to`, `armies` | Desplaza ejércitos entre territorios propios conectados durante la fase `Fortify`. |
| `EndPhaseCommand` | `player` | Concluye voluntariamente la fase actual (`Attack` o `Fortify`). |

### Eventos (`GameEvent`)

| Evento | Campos | Descripción |
|---|---|---|
| `TerritoryClaimedEvent` | `player`, `territory`, `armies` | Notifica la asignación inicial de un territorio en el setup de la partida. |
| `ArmiesPlacedEvent` | `player`, `territory`, `count`, `armies_remaining` | Emite la incorporación de tropas en un territorio y las tropas restantes por ubicar. |
| `CardsExchangedEvent` | `player`, `armies_gained` | Notifica el canje exitoso de tarjetas y los ejércitos adicionales obtenidos. |
| `AttackDeclaredEvent` | `attacker`, `from`, `to`, `dice` | Notifica la declaración de un combate y los dados asignados. |
| `AttackResolvedEvent` | `attacker`, `defender`, `from`, `to`, `attacker_rolls`, `defender_rolls`, `attacker_losses`, `defender_losses`, `territory_conquered` | Detalla el resultado de la tirada de dados, bajas sufridas y si hubo conquista. |
| `TerritoryConqueredEvent` | `player`, `territory`, `from`, `from_armies`, `to_armies`, `card_drawn` | Notifica la captura de un territorio enemigo y la tarjeta obtenida si corresponde. |
| `PlayerEliminatedEvent` | `player`, `by` | Notifica la derrota total de un jugador y la identidad de quien lo eliminó. |
| `FortifiedEvent` | `player`, `from`, `to`, `armies` | Notifica el reagrupamiento táctico de tropas entre territorios conectados. |
| `PhaseChangedEvent` | `player`, `new_phase` | Notifica la transición a una nueva fase del turno. |
| `TegGameOverEvent` | `winner`, `objective` | Notifica el fin de la partida por cumplimiento de objetivo o dominación global. |

