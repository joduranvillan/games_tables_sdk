# Registro de Cambios (Changelog) - Games Tables SDK

Aquí se documentan las reglas y mecánicas incorporadas recientemente en los juegos de referencia del SDK.

## Backgammon
Se mejoraron las mecánicas centrales para acercar el juego a las reglas oficiales:
* **Tiradas Dobles:** Cuando un jugador saca el mismo valor en ambos dados (ej. 4 y 4), ahora recibe 4 movimientos de ese valor en lugar de 2.
* **Paso de Turno Automático:** Se implementó la lógica para verificar si un jugador tiene movimientos válidos. Si, con los dados actuales, el jugador está completamente bloqueado, se emite el nuevo evento `NoValidMovesEvent` y el turno pasa automáticamente al oponente sin requerir acción manual.
* **Regla estricta de Bear-off (Sacar fichas):** Se ajustó la regla de sacar fichas. Ahora, si intentas usar un dado que es *mayor* a la distancia exacta requerida para sacar una ficha, el juego solo te lo permitirá si **no tienes** otras fichas en posiciones más lejanas dentro de tu cuadrante final.

## Batalla Naval (Battleship)
Se introdujeron validaciones estrictas en la fase de colocación y de ataque (con sus respectivos tests):
* **Validación de Flota:** El juego ahora rechaza la colocación de barcos de forma diagonal o barcos que se superpongan en la misma casilla.
* **Validación de Disparos:** El sistema rechaza cualquier comando para disparar a una coordenada a la que el jugador ya había disparado previamente, evitando turnos desperdiciados o estados inválidos.

## Monopoly
Se expandió el tablero y las mecánicas económicas del juego:
* **Grupos de Color:** El tablero pasó a tener grupos de propiedades por color (Av. Roja 1, Av. Roja 2, etc.).
* **Renta Duplicada (Monopolio):** Se añadió una regla al motor donde, al caer en una propiedad, se revisa si el dueño posee *todas* las propiedades de ese mismo grupo de color. Si es así, la renta base a cobrar se multiplica automáticamente por dos.
* **Turnos por Dobles:** Se introdujo la mecánica de los dobles. Si en tu tirada los dos dados coinciden (`is_doubles = true`), mantienes tu turno y vuelves a tirar después de resolver tu movimiento actual.
* **Decisiones Pendientes de Dobles:** Si caes en una casilla sin dueño sacando dobles, el sistema registra que sacaste dobles y espera a que decidas si compras o no antes de concederte la siguiente tirada.

## Shogi, Xiangqi y Go
Se añadieron tres nuevos juegos de referencia al SDK:
* **Shogi (Ajedrez Japonés):** Tablero 9x9 con mecánica de drops (reintroducir piezas capturadas). Se implementó la estructura de comandos básica (`MovePieceCommand`, `DropPieceCommand`) y el sistema de promoción.
* **Xiangqi (Ajedrez Chino):** Tablero de 9x10 con estructura de piezas tradicionales (General, Consejero, Elefante, Caballo, Carro, Cañón, Soldado) y sus eventos.
* **Go (Weiqi):** Tablero con opciones de tamaño (9x9 por defecto para tests) con mecánica de colocación de piedras (`PlaceStoneCommand`) y captura basada en el algoritmo de búsqueda de libertades (las piedras sin libertades adyacentes son eliminadas).

### Validaciones Agregadas a Juegos de Tablero Asiáticos
* **Shogi:** Se implementó `is_legal_move` (validando el movimiento exacto del Rey, Torre, Alfil, Generales de Oro/Plata, Caballo, Lancero, Peón y sus versiones promovidas). También se incorporó `is_legal_drop` y las reglas de _Nifu_ (dos peones en la misma columna) y prohibición de drops en casillas sin movimientos válidos, junto a la lógica de promoción (zona de promoción y promociones forzadas).
* **Xiangqi:** Se implementó `is_legal_move` (validando General, Consejeros confinados al palacio, Elefantes cruzando el río y el "ojo del elefante", Caballos y su restricción de bloqueo, Carros ortogonales, Cañones con captura por salto, y Peones antes y después del río). Se incorporó la regla del "General Volador" (`check_flying_general`) para prohibir movimientos que dejen a los generales mirándose directamente.
* **Go:** Se incorporó el soporte para la regla del *Ko* (impidiendo la captura inmediata de ida y vuelta que revertiría el tablero al estado anterior) y validación anti-suicidio, ambas agregadas a las mecánicas base de colocación y captura por libertades.

## UNO
Se añadió el juego de cartas multijugador UNO con:
* **Estructura completa de cartas y estado (`UnoState`):** Baraja completa con 108 cartas incluyendo números, Saltar, Reversa, Robar Dos y Comodines. Repartición inicial automática de 7 cartas por jugador y gestión del mazo de descarte y robo, todo determinista para soportar replayability.
* **Mecánicas Centrales y Comandos:** `PlayCardCommand` y `DrawCardCommand` con validación estricta (coincidencia por color, número o uso válido de comodines).
* **Gestión de Turnos Extendida:** Se extendió la herramienta `TurnOrder` a nivel del motor central (`open_table_engine`) para soportar direccionalidad (`reverse`) y salto de turnos, habilitando la mecánica de las cartas Reversa, Saltar, Robar Dos y Comodín Robar Cuatro.

* **Modo de Apilamiento (Stacking):** Las cartas "+2" y "Comodín Robar Cuatro" ahora no saltan automáticamente al siguiente jugador. En su lugar, acumulan la penalidad (`draw_penalty`), obligando al siguiente jugador a jugar otra carta de apilamiento válida o consumir su turno robando el total de cartas acumulado.
