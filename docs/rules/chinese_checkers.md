# Reglas de Damas Chinas (`chinese_checkers_game`)

Motor de Damas Chinas (*Sternhalma*) implementado en Rust sobre `open_table_engine` y Bevy ECS, con integración completa para Godot 4 vía GDExtension.

---

## 1. Geometría del Tablero: Estrella de 6 Puntas Tradicional (121 Casillas)

El tablero implementa la geometría tradicional completa en forma de estrella de David / estrella de 6 puntas (*centered hexagram*), totalizando exactamente **121 casillas** indexadas mediante un sistema de coordenadas axiales hexagonales `Position(q, r)`:

- **Hexágono Central**: **61 casillas** con radio hexagonal `BOARD_RADIUS = 4`, definidas por la condición:
  $$\max(|q|, |r|, |q + r|) \le 4$$
- **6 Puntas / Esquinas Triangulares**: **10 casillas por punta** ($6 \times 10 = 60$ casillas), rotadas simétricamente a $60^\circ$ alrededor del centro:
  - Esquina base (índice 0): `(-5, 1)`, `(-5, 2)`, `(-5, 3)`, `(-6, 2)`, `(-6, 3)`, `(-6, 4)`, `(-7, 3)`, `(-7, 4)`, `(-8, 4)`, `(-5, 4)`.
  - Esquinas 1 a 5: Obtenidas aplicando la transformación cíclica $(q, r) \mapsto (-r, q + r)$ repetida según el índice de la esquina.
- **Total de casillas jugables**: $61 \text{ (centro)} + 60 \text{ (6 puntas)} = \mathbf{121 \text{ casillas}}$.

---

## 2. Soporte Dinámico de Jugadores (2 a 6 Jugadores)

El motor soporta de **2 a 6 jugadores** en tiempo de ejecución, gestionado a través de la API `start_local_match_chinese_checkers_n_players(num_players)` (manteniendo compatibilidad con `start_local_match_chinese_checkers(p1, p2)` para partidas de 2 jugadores):

| Cantidad de Jugadores | Esquinas Iniciales Ocupadas | Distribución en la Estrella | Meta de Cada Jugador |
|:---:|:---:|---|---|
| **2 Jugadores** | `[0, 3]` | Puntas opuestas (180°) con 10 fichas cada una | La casa inicial del rival opuesto |
| **3 Jugadores** | `[0, 2, 4]` | Puntas alternas equidistantes (120°) | La punta vacía diametralmente opuesta |
| **4 Jugadores** | `[0, 1, 3, 4]` | Dos pares de puntas enfrentadas | La punta opuesta asignada |
| **6 Jugadores** | `[0, 1, 2, 3, 4, 5]` | Todas las 6 puntas ocupadas | La punta opuesta $(\text{origen} + 3) \bmod 6$ |

---

## 3. Movimiento y Mecánicas de Juego

En su turno, un jugador puede realizar una de las siguientes acciones con cualquiera de sus fichas:

1. **Paso Simple**:
   - Mover la clavija a cualquiera de las **6 casillas adyacentes** desocupadas en las direcciones axiales:
     $$(\pm 1, 0),\ (1, -1),\ (-1, 1),\ (0, \pm 1)$$

2. **Salto Simple**:
   - Saltar por encima de una ficha adyacente (propia o contraria) en línea recta hacia la casilla inmediatamente posterior en la misma dirección, siempre que dicha casilla esté vacía.
   - $\Delta = (2 \cdot d_q, 2 \cdot d_r)$, verificando que la casilla intermedia $(q + d_q, r + d_r)$ contenga una ficha.

3. **Saltos Múltiples Encadenados**:
   - Una ficha puede encadenar una secuencia de saltos consecutivos en un solo turno, cambiando de dirección en cada salto si lo desea, mediante el parámetro `path` en `MovePegCommand`.
   - Cada segmento del camino debe ser un salto válido sobre una casilla ocupada hacia una casilla libre.

4. **Sin Capturas**:
   - Las fichas sobre las que se salta nunca se retiran ni se capturan; permanecen en el tablero para ser usadas como pivotes en turnos posteriores.

---

## 4. Objetivo y Condición de Victoria

- **Victoria Inmediata**: Un jugador gana la partida en el momento exacto en que logra colocar **todas sus 10 fichas** en el triángulo meta asignado (la casa objetivo opuesta).
- La condición se evalúa automáticamente tras cada ejecución exitosa de `MovePegCommand`.

---

## 5. Comandos y Eventos Públicos

### Comandos

| Comando | Parámetros | Descripción |
|---|---|---|
| `MovePegCommand` | `player: PlayerId`<br>`from: Position`<br>`to: Position`<br>`path: Vec<Position>` | Solicita el movimiento o la cadena de saltos de una clavija desde `from` hasta `to`. |

### Eventos

| Evento | Parámetros | Descripción |
|---|---|---|
| `PegMovedEvent` | `player: PlayerId`<br>`from: Position`<br>`to: Position`<br>`was_jump: bool` | Emitido tras concretarse un paso o salto simple/encadenado. |
| `GameOverEvent` | `winner: Option<PlayerId>` | Emitido cuando un jugador completa la ocupación total de su casa meta opuesta. |
