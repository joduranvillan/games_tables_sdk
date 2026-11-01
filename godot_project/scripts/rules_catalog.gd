class_name RulesCatalog
extends RefCounted

## Catálogo centralizado con el reglamento completo y estructurado (Objetivo, Turno,
## Reglas Especiales y Condición de Victoria) en Español ("es") e Inglés ("en")
## para los 13 juegos de la suite OpenTable.

const CANONICAL_GAMES: Array[String] = [
	"checkers",
	"chess",
	"xiangqi",
	"shogi",
	"backgammon",
	"ludo",
	"go",
	"mille_bornes",
	"monopoly",
	"uno",
	"crisis",
	"chinese_checkers",
	"battleship"
]

const CATALOG: Dictionary = {
	"checkers": {
		"es": {
			"title": "Damas (Checkers)",
			"summary": "Clásico duelo táctico en tablero de 8×8 donde las piezas avanzan en diagonal y las capturas por salto son obligatorias.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Capturar todas las fichas del oponente o bloquearlas de modo que no disponga de ningún movimiento legal en su turno."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "En cada turno debes mover una ficha propia en diagonal hacia adelante una casilla libre, o saltar por encima de una ficha rival adyacente hacia la casilla vacía inmediatamente posterior (`MovePieceCommand`)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Captura obligatoria: Si al inicio de tu turno existe una captura posible, estás obligado a ejecutarla.\n• Saltos múltiples encadenados: Si tras capturar una ficha la misma pieza puede seguir capturando, el turno continúa encadenando saltos.\n• Coronación (Dama): Al alcanzar la última fila del rival, el peón corona como Dama y puede desplazarse y capturar en las 4 diagonales.\n• Regla de 40 medios turnos: Si transcurren 40 medios turnos sin capturas ni avances de peón, se declara empate."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el jugador que deja al rival sin piezas en el tablero, sin movimientos legales disponibles o por rendición (`ResignCommand`)."
				}
			]
		},
		"en": {
			"title": "Checkers (Draughts)",
			"summary": "Classic 8×8 tactical duel where pieces advance diagonally and jump captures are mandatory.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Capture all opponent pieces or block them so your opponent has no legal moves on their turn."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Move one of your pieces diagonally forward to an empty adjacent square, or jump over an adjacent enemy piece onto the empty square directly beyond it (`MovePieceCommand`)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Mandatory capture: Whenever a capture is available, you must take it.\n• Multi-jumps: If a capturing piece lands where another capture is immediately possible, it continues jumping in the same turn.\n• King promotion: Reaching the farthest row crowns the piece as a King, allowing diagonal movement and captures both forward and backward.\n• 40-Halfmove Draw Rule: 40 consecutive half-moves without a capture or pawn advance result in a draw."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The player who captures all enemy pieces, leaves the opponent with no legal moves, or accepts opponent resignation (`ResignCommand`) wins."
				}
			]
		}
	},
	"chess": {
		"es": {
			"title": "Ajedrez (Chess)",
			"summary": "Juego de estrategia milenario sobre 64 casillas con seis tipos de piezas, subpromoción, enroque, captura al paso y ofertas de tablas.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Acorralar al Rey adversario bajo ataque directo (jaque) sin que tenga escapatoria legal (jaque mate)."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Blancas mueven primero. En tu turno debes mover exactamente una pieza según su patrón (`MovePieceCommand`: Rey, Dama, Torre, Alfil, Caballo o Peón) o proponer tablas (`OfferDrawCommand`). Ningún movimiento puede dejar a tu propio Rey en jaque."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Enroque (corto o largo): Maniobra conjunta entre el Rey y una Torre si ninguno se ha movido, no hay piezas entre ambos y el Rey no está en jaque ni pasa por casillas atacadas.\n• Captura al paso (En Passant): Si un peón rival avanza dos casillas desde su fila inicial y queda junto a tu peón, puedes capturarlo en el turno inmediato siguiente.\n• Subpromoción (`promote_to`): Todo peón que alcanza la octava fila puede coronar a elección en Dama (`Queen`), Torre (`Rook`), Alfil (`Bishop`) o Caballo (`Knight`)."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Victoria por jaque mate o rendición rival (`ResignCommand`). Es tablas por acuerdo mutuo (`AcceptDrawCommand`), ahogado, triple repetición, insuficiencia de material o regla de los 50 movimientos."
				}
			]
		},
		"en": {
			"title": "Chess",
			"summary": "Timeless 64-square strategy game featuring six distinct piece types, underpromotion, castling, en passant, and draw offers.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Place the opponent's King under inescapable attack (checkmate)."
				},
				{
					"heading": "2. Turn Structure",
					"body": "White moves first. Each turn, move one piece according to its movement pattern (`MovePieceCommand`: King, Queen, Rook, Bishop, Knight, or Pawn) or offer a draw (`OfferDrawCommand`). You may never leave your own King in check."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Castling: Simultaneous King and Rook move when neither has moved, the path is clear, and the King does not start in, pass through, or end in check.\n• En Passant: A pawn advancing two squares from its starting rank past an enemy pawn may be captured on the immediately following turn.\n• Promotion (`promote_to`): A pawn reaching the eighth rank promotes to Queen, Rook, Bishop, or Knight."
				},
				{
					"heading": "4. Victory Condition",
					"body": "Win by checkmate or opponent resignation (`ResignCommand`). Draws occur by mutual agreement (`AcceptDrawCommand`), stalemate, threefold repetition, insufficient material, or the 50-move rule."
				}
			]
		}
	},
	"xiangqi": {
		"es": {
			"title": "Xiangqi (Ajedrez Chino)",
			"summary": "Batalla estratégica sobre las intersecciones de una cuadrícula de 9×10 dividida por el Río Central y dos Palacios Imperiales.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Dar jaque mate o ahogar (dejar sin movimientos legales) al General (Rey) enemigo."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "El bando Rojo inicia la partida. En cada turno mueves una pieza sobre las intersecciones del tablero (`MovePieceCommand`): General, Consejero, Elefante, Caballo, Carro (Torre), Cañón o Soldado (Peón)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• El Palacio (3×3): El General y los Consejeros nunca pueden salir de su Palacio.\n• El Río Central: Los Elefantes no pueden cruzar el río; los Soldados que lo cruzan ganan movimiento horizontal.\n• Bloqueo del Caballo y Elefante: El Caballo y el Elefante no saltan; si la intersección adyacente ortogonal/diagonal está ocupada, el movimiento queda bloqueado.\n• Cañón: Mueve como el Carro, pero para capturar necesita saltar exactamente sobre una pieza intermedia (pantalla).\n• Generales enfrentados y Jaque Perpetuo: Los dos Generales nunca pueden mirarse directamente en una columna abierta, y está prohibido repetir indefinidamente una posición de jaque."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana quien da jaque mate, deja sin jugadas legales al rival (el ahogado otorga la victoria) o recibe la rendición adversaria (`ResignCommand`)."
				}
			]
		},
		"en": {
			"title": "Xiangqi (Chinese Chess)",
			"summary": "Strategic battle played on the intersections of a 9×10 grid divided by the Central River and two Imperial Palaces.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Deliver checkmate or stalemate to the opposing General."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Red moves first. Move one piece along grid intersections (`MovePieceCommand`) according to its role: General, Advisor, Elephant, Horse, Chariot, Cannon, or Soldier."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Palace (3×3): The General and Advisors may never leave their Palace.\n• Central River: Elephants cannot cross the river; Soldiers gain horizontal movement once they cross it.\n• Hobbling the Horse/Elephant: Horses and Elephants are blocked if their adjacent pivot point is occupied.\n• Cannon: Moves like a Chariot, but must jump over exactly one intervening screen piece to capture.\n• Flying General & Perpetual Check: The two Generals may never face each other along an open file, and perpetual repetition is forbidden."
				},
				{
					"heading": "4. Victory Condition",
					"body": "Win by checkmate, leaving the opponent with no legal moves (stalemate is a win in Xiangqi), or opponent resignation (`ResignCommand`)."
				}
			]
		}
	},
	"shogi": {
		"es": {
			"title": "Shogi (Ajedrez Japonés)",
			"summary": "Ajedrez táctico japonés en tablero de 9×9 donde las piezas capturadas pueden reingresar como refuerzos propios.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Capturar o dar jaque mate al Rey (Gyoku/Ou) del adversario."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Sente (Negras) juega primero. En tu turno puedes mover una pieza en el tablero (`MovePieceCommand`, promocionándola si entra, sale o se mueve dentro de las 3 últimas filas) o reingresar (`DropPieceCommand`) una pieza capturada en una casilla vacía."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Reingreso (Drop): Las piezas capturadas pasan a tu reserva (Komadai) y pueden colocarse sin promocionar en una casilla vacía.\n• Nifu (Dos Peones): Está prohibido reingresar un peón en una columna que ya contenga otro peón propio sin promocionar.\n• Uchifuzume: No se permite dar jaque mate inmediato reingresando un peón.\n• Promoción obligatoria FESA y Sennichite: Peones, Lanzas y Caballos promocionan obligatoriamente si alcanzan una fila sin salida futura; la cuádruple repetición exacta de posición finaliza por Sennichite."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el jugador que da jaque mate al Rey rival o cuando el oponente se rinde (`ResignCommand`)."
				}
			]
		},
		"en": {
			"title": "Shogi (Japanese Chess)",
			"summary": "Dynamic 9×9 Japanese chess where captured enemy pieces can be dropped back onto the board on your side.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Checkmate the opponent's King."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Sente (Black) moves first. On your turn, either move one piece on the board (`MovePieceCommand`) or drop a captured piece from your hand onto any legal empty square (`DropPieceCommand`)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Drops: Captured pieces join your hand unpromoted and can be dropped onto empty squares.\n• Nifu (Two Pawns): You may not drop an unpromoted pawn onto a file that already contains one of your unpromoted pawns.\n• Uchifuzume: Dropping a pawn to deliver immediate checkmate is illegal.\n• Mandatory Promotion & Sennichite: Pawns, Lances, and Knights must promote upon reaching a rank with no future moves; fourfold repetition triggers Sennichite."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The player who checkmates the opposing King or accepts opponent resignation (`ResignCommand`) wins."
				}
			]
		}
	},
	"backgammon": {
		"es": {
			"title": "Backgammon",
			"summary": "Carrera estratégica de 15 fichas a lo largo de 24 picos con Cubo de Doblaje, regla Crawford, bloqueo y capturas a la barra.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Llevar tus 15 fichas hasta tu cuadrante interior (Home Board) y ser el primero en retirarlas todas (Bearing Off) fuera del tablero."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Antes de tirar puedes proponer doblar la apuesta (`OfferDoubleCommand`). Luego lanzas dos dados (`RollDiceCommand`) y avanzas tus fichas (`MoveCheckerCommand`). Estás obligado a usar ambos dados si es legalmente posible (o el dado de mayor valor si solo uno puede jugarse)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Tirada Doble: Si ambos dados muestran el mismo número, juegas cuatro veces ese valor.\n• Captura (Blot / Hit) y Barra: Aterrizar sobre una ficha rival sola la envía a la Barra central, de donde debe reingresar antes de mover cualquier otra ficha.\n• Cubo de Doblaje y Regla Crawford: Permite multiplicar el valor del juego (2, 4, 8, 16, 32, 64) mediante `OfferDoubleCommand`, `AcceptDoubleCommand` y `RejectDoubleCommand`, deshabilitándose durante el juego Crawford.\n• Retirada (Bearing Off): Solo puedes retirar fichas cuando tus 15 fichas estén dentro de tu cuadrante interior."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana quien retira primero sus 15 fichas o cuando el rival rechaza un doblaje o se rinde (Victoria simple ×1, Gammon ×2 o Backgammon ×3, multiplicado por el cubo)."
				}
			]
		},
		"en": {
			"title": "Backgammon",
			"summary": "Strategic race of 15 checkers across 24 points featuring the Doubling Cube, Crawford rule, blocking primes, and hitting blots.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Bring all 15 of your checkers into your home board and be the first to bear them all off."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Before rolling, you may offer to double the stakes (`OfferDoubleCommand`). Then roll two dice (`RollDiceCommand`) and move your checkers (`MoveCheckerCommand`). You must use both dice if legally possible (or the higher die if only one can be played)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Doubles: Rolling matching dice grants four moves of that number.\n• Hitting a Blot & Bar Entry: Landing on a single opposing checker sends it to the Bar, which must re-enter first.\n• Doubling Cube & Crawford Rule: Stakes can be doubled (`OfferDoubleCommand`, `AcceptDoubleCommand`, `RejectDoubleCommand`) except during the Crawford game.\n• Bearing Off: Once all 15 of your checkers are in your home board, bear them off according to the dice rolls."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to bear off all 15 checkers (or when the opponent declines a double or resigns) wins 1× (Single), 2× (Gammon), or 3× (Backgammon) times the cube value."
				}
			]
		}
	},
	"ludo": {
		"es": {
			"title": "Ludo (Parchís)",
			"summary": "Carrera clásica de 4 fichas a lo largo de un circuito de 52 casillas más pasillo de meta de 5 pasos.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Recorrer las 52 casillas del circuito exterior y las 5 casillas del pasillo interior con tus 4 fichas hasta la meta central (`steps = 57`)."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Lanza el dado de 6 caras (`RollDiceCommand`) y elige cuál de tus fichas válidas avanzar (`MoveTokenCommand`) el número exacto de casillas indicado."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Salida con 6 y Tres Seises Seguidos: Para sacar una ficha de la base necesitas un 6. Sacar un 6 da tirada extra, pero obtener tres 6 consecutivos anula el tercer movimiento y cede el turno.\n• Casillas Seguras y Estrellas (+8): Las 4 salidas de color y las 4 casillas con estrella protegen tus fichas de ser capturadas.\n• Captura y Bono de Tirada Extra: Aterrizar sobre una ficha rival en casilla normal la devuelve a su base y te otorga una tirada extra inmediata, al igual que meter una ficha en la meta con cuenta exacta."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el primer jugador que logra introducir sus 4 fichas en la casilla central de meta."
				}
			]
		},
		"en": {
			"title": "Ludo",
			"summary": "Classic race of 4 tokens around a 52-square outer track and 5-step home column into the central goal.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Move all 4 of your tokens from your starting yard around the 52-square track and up the home column into the goal (`steps = 57`)."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Roll the six-sided die (`RollDiceCommand`) and advance one of your valid tokens (`MoveTokenCommand`) by the exact number rolled."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Entering Play & Three-Sixes Penalty: A 6 is required to leave the starting yard and grants a bonus roll, but rolling three consecutive 6s forfeits the turn.\n• Safe Squares & Stars (+8): Starting squares and the 4 starred squares protect tokens from capture.\n• Capture & Goal Bonus Rolls: Capturing an opponent token on a non-safe square or reaching the center goal on an exact roll grants an immediate bonus roll."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to bring all 4 tokens into the center home triangle wins."
				}
			]
		}
	},
	"go": {
		"es": {
			"title": "Go (Weiqi / Baduk)",
			"summary": "Juego abstracto de rodeo territorial y captura por libertades en tableros de 9×9, 13×13 o 19×19 con Superko, Komi y acuerdo de piedras muertas.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Controlar una mayor puntuación combinada de territorio rodeado, prisioneros capturados y Komi que tu adversario al final de la partida."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Negras juegan primero (o Blancas si se colocaron piedras de ventaja con `PlaceHandicapCommand`). En tu turno colocas una piedra en cualquier intersección vacía (`PlaceStoneCommand`) o pasas el turno (`PassCommand`)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Libertades y Captura: Las intersecciones vacías ortogonalmente adyacentes a una cadena son sus libertades. Si una jugada deja a un grupo rival con 0 libertades, todas las piedras de ese grupo son capturadas.\n• Prohibición de Suicidio y Superko Posicional: No puedes jugar donde tu grupo quede sin libertades (salvo que capture piedras enemigas) ni repetir ningún estado previo del tablero.\n• Fase de Piedras Muertas y Komi: Tras dos pases consecutivos se marcan y confirman los grupos muertos (`MarkDeadCommand`, `ConfirmDeadCommand`) y se suma el Komi configurable (`SetKomiCommand`, 6.5 por defecto)."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana quien obtiene mayor puntuación tras confirmar las piedras muertas o cuando el oponente se rinde (`ResignCommand`)."
				}
			]
		},
		"en": {
			"title": "Go (Weiqi / Baduk)",
			"summary": "Abstract strategy game of surrounding territory and capturing stones on 9×9, 13×13, or 19×19 boards with Positional Superko, Komi, and dead-stone agreement.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Control more total points of surrounded territory, captured stones, and Komi than your opponent."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Black plays first (or White after `PlaceHandicapCommand`). On your turn, place one stone on any vacant intersection (`PlaceStoneCommand`) or Pass (`PassCommand`)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Liberties & Capture: Orthogonally connected stones share liberties. Any group reduced to zero liberties is captured.\n• No Suicide & Positional Superko: You may not leave your own group with zero liberties (unless capturing) or recreate any previous board state.\n• Dead Stone Marking & Komi: After two consecutive passes, players mark and confirm dead groups (`MarkDeadCommand`, `ConfirmDeadCommand`) and apply Komi (`SetKomiCommand`, default 6.5)."
				},
				{
					"heading": "4. Victory Condition",
					"body": "Highest final score after dead-stone confirmation (or opponent resignation via `ResignCommand`) wins."
				}
			]
		}
	},
	"mille_bornes": {
		"es": {
			"title": "Mille Bornes (1000 Kilómetros)",
			"summary": "Carrera automovilística de cartas hasta 1000 km (extensible a 1200 km) con peligros de ruta, reparaciones, 4 escudos y Coup Fourré.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Ser el primero en recorrer exactamente 1000 kilómetros (o 1200 km si se activa la Extensión de Viaje)."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Robas una carta del mazo (`DrawCardCommand`) y juegas una carta de tu mano (`PlayCardCommand`: Distancia, Peligro, Remedio o Escudo/Safety) o descartas una al pozo (`DiscardCardCommand`)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Semáforo Verde (Roll): Necesitas tener Luz Verde activa (o el escudo Prioridad de Paso) para jugar cartas de distancia.\n• Peligros y Remedios: Pinchazo → Rueda de Auxilio; Sin Gasolina → Gasolina; Accidente → Taller; Límite de 50 km/h → Fin de Límite; Pare → Siga.\n• Las 4 Cartas de Seguridad (Safeties): As del Volante (`DrivingAce`), Tanque Extra (`ExtraTank`), Llantas Inpinchables (`PunctureProof`) y Prioridad de Paso (`RightOfWay`) inmunizan permanentemente y otorgan un turno extra inmediato.\n• Coup Fourré y Límite de 200 km: Responder a un peligro con su Escudo (`CoupFourreCommand`) otorga +300 puntos y turno extra; máximo dos cartas de 200 km por jugador."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana quien alcanza primero los 1000 km exactos (o 1200 km en viaje extendido) o quien lidera al agotarse el mazo y las manos."
				}
			]
		},
		"en": {
			"title": "Mille Bornes (1000 Miles)",
			"summary": "French road-race card game to 1000 km (extensible to 1200 km) featuring hazards, remedies, all 4 permanent safeties, and Coup Fourré.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Be the first driver to accumulate exactly 1000 kilometers (or 1200 km when Trip Extension is triggered)."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Draw a card (`DrawCardCommand`) and either play one card (`PlayCardCommand`: Distance, Hazard, Remedy, or Safety) or discard one card (`DiscardCardCommand`)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Roll (Green Light): You must have a Roll card active (or Right of Way) to play distance cards.\n• Hazards & Remedies: Flat Tire → Spare Tire; Out of Gas → Gasoline; Accident → Repairs; Speed Limit → End of Limit; Stop → Roll.\n• All 4 Safeties: Driving Ace, Extra Tank, Puncture-Proof, and Right of Way provide permanent immunity against their matching hazards and grant an immediate extra turn.\n• Coup Fourré & 200 km Limit: Playing a Safety in immediate response to a Hazard (`CoupFourreCommand`) awards a 300-point bonus and extra turn; at most two 200 km cards per player."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to reach exactly 1000 km (or 1200 km on extension) or the distance leader when all cards are exhausted wins."
				}
			]
		}
	},
	"monopoly": {
		"es": {
			"title": "Monopolio (Monopoly)",
			"summary": "Juego económico sobre el circuito oficial de 40 casillas con subastas, construcción uniforme de casas y hoteles, hipotecas e intercambios.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Multiplicar tu capital comprando propiedades, formando monopolios de color, negociando e invirtiendo en casas y hoteles hasta llevar a la bancarrota a tus rivales."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Lanza los dos dados (`RollAndMoveCommand`), avanza por las 40 casillas y resuelve la casilla (comprar con `BuyPropertyCommand`, pujar en subasta con `AuctionBidCommand`, pagar alquiler, robar Suerte/Arca Comunal o gestionar tus propiedades)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Monopolio y Construcción Uniforme: Poseer todo un grupo de color duplica la renta sin edificar y permite construir casas y hoteles (`BuildHouseCommand`, `SellHouseCommand`) de forma pareja.\n• Hipotecas (`MortgagePropertyCommand`, `UnmortgagePropertyCommand`): Hipotecar un solar sin edificios otorga el 50% de su valor; deshipotecarlo cuesta el préstamo más 10% de interés.\n• Intercambios Comerciales: Puedes proponer y responder trueques de propiedades y efectivo (`ProposeTradeCommand`, `AcceptTradeCommand`, `RejectTradeCommand`).\n• Cárcel y 3 Dobles: Tres dobles seguidos te envían a la Cárcel; sales con dobles, pagando $50 (`PayJailFeeCommand`) o usando tu tarjeta retenida (`UseJailCardCommand`)."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el último jugador que permanece solvente tras la bancarrota de los demás."
				}
			]
		},
		"en": {
			"title": "Monopoly",
			"summary": "Full 40-space real-estate trading game featuring auctions, even house/hotel building, mortgages, and player-to-player trades.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Acquire complete color groups, build houses and hotels, trade strategically, and bankrupt your opponents."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Roll two dice (`RollAndMoveCommand`), advance around the 40-space board, and resolve the space (`BuyPropertyCommand`, `AuctionBidCommand`, rent, Chance/Community Chest, or property management)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Color Monopolies & Even Building: Owning a full color group doubles base rent and unlocks uniform house/hotel construction (`BuildHouseCommand`, `SellHouseCommand`).\n• Mortgages (`MortgagePropertyCommand`, `UnmortgagePropertyCommand`): Mortgage unimproved properties for 50% of their price; unmortgage for 50% plus 10% interest.\n• Trading: Propose and settle property and cash trades (`ProposeTradeCommand`, `AcceptTradeCommand`, `RejectTradeCommand`).\n• Jail & Three Doubles: Three consecutive doubles send you to Jail; exit by rolling doubles, paying $50 (`PayJailFeeCommand`), or playing a retained card (`UseJailCardCommand`)."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The last solvent player remaining after all others go bankrupt wins."
				}
			]
		}
	},
	"uno": {
		"es": {
			"title": "Uno",
			"summary": "Juego dinámico con mazo oficial de 108 cartas, grito y penalización de ¡UNO!, desafío de Comodín +4 e intercepción Jump-In.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Ser el primer jugador en descartar todas las cartas de su mano."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Juega una carta que coincida en color, número o símbolo con el descarte (`PlayCardCommand`), o roba del mazo (`DrawCardCommand`, jugándose de inmediato si es compatible)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Cartas de Acción: Salto (`Skip`), Reversa (`Reverse`, actúa como Salto entre 2 jugadores), Roba Dos (`+2`), Comodín (`Wild`) y Comodín Roba Cuatro (`Wild +4`).\n• Grito de ¡UNO! y Penalización: Al quedar con 1 sola carta debes cantar `CallUnoCommand`; si un rival te sorprende antes con `CatchUnoFailureCommand`, robas 2 cartas de castigo.\n• Desafío de Wild +4 (`ChallengeWildDrawFourCommand`): Si el rival lanzó `+4` teniendo el color previo, él roba 4 cartas; si fue legal, el desafiante roba 6 cartas.\n• Intercepción (Jump-In): Con una carta idéntica en color y valor al tope del descarte puedes intervenir fuera de turno (`InterceptCommand`)."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el primer jugador que se queda con 0 cartas en la mano."
				}
			]
		},
		"en": {
			"title": "Uno",
			"summary": "Fast-paced 108-card shedding game with UNO call & penalty, Wild Draw Four challenges, and Jump-In interceptions.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Be the first player to play all cards from your hand."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Play a matching card (`PlayCardCommand`) or draw from the deck (`DrawCardCommand`, auto-playing if immediately playable)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Action Cards: Skip, Reverse (acts as Skip in 2-player games), Draw Two (+2), Wild, and Wild Draw Four (+4).\n• Calling UNO & Penalty: When down to 1 card, declare `CallUnoCommand`; if caught first via `CatchUnoFailureCommand`, draw 2 penalty cards.\n• Wild +4 Challenge (`ChallengeWildDrawFourCommand`): Challenge a Wild +4—if played illegally, the offender draws 4; if legal, the challenger draws 6.\n• Jump-In (`InterceptCommand`): Play an exact color-and-value match out of turn."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to empty their hand (0 cards remaining) wins."
				}
			]
		}
	},
	"crisis": {
		"es": {
			"title": "Crisis (T.E.G. — Plan Táctico y Estratégico de la Guerra)",
			"summary": "Gran estrategia geopolítica en 30 territorios y 6 continentes con refuerzos, combate 3v3, tarjetas de país (+2 en propio) y objetivos secretos.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Cumplir tu Objetivo Secreto asignado al comienzo de la partida o alcanzar la Conquista Global ocupando los 30 territorios del mapa."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Cada turno se divide en tres fases secuenciales avanzadas con `EndPhaseCommand`:\n1) Incorporación (`PlaceArmiesCommand`): Coloca refuerzos según países propios (mínimo 3) más bonos por continentes y canjes.\n2) Ataque (`DeclareAttackCommand` + `RollAttackCommand`): Ataca desde territorios con ≥2 ejércitos hacia limítrofes enemigos.\n3) Reagrupamiento (`FortifyCommand`): Desplaza ejércitos entre territorios propios adyacentes."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Resolución de Combate: Atacante y defensor tiran hasta 3 dados ordenados de mayor a menor; en caso de empate en un par de dados, gana siempre el defensor.\n• Tarjeta por Conquista y Bono +2: Conquistar al menos un país en tu turno otorga 1 tarjeta de territorio; si posees el país de la tarjeta recibes +2 ejércitos en él.\n• Canje de Tríos (`ExchangeCardsCommand`): Canjear 3 tarjetas iguales, 3 distintas o con comodín otorga refuerzos crecientes (4, 7, 10, 15...)."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Victoria inmediata al verificar el cumplimiento de tu Objetivo Secreto o al controlar los 30 territorios del mapa (`TegGameOverEvent`)."
				}
			]
		},
		"en": {
			"title": "Crisis (T.E.G. — Tactical & Strategic War Plan)",
			"summary": "Turn-based global strategy across 30 territories and 6 continents with 3v3 dice combat, territory cards (+2 owned bonus), and secret objectives.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Complete your assigned Secret Objective or achieve Global Conquest by controlling all 30 territories on the map."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Every turn follows three phases advanced via `EndPhaseCommand`:\n1) Place Armies (`PlaceArmiesCommand`): Deploy reinforcements based on territories owned (min 3) plus continent bonuses.\n2) Attack (`DeclareAttackCommand` + `RollAttackCommand`): Attack adjacent enemy territories from any territory with ≥2 armies.\n3) Fortify (`FortifyCommand`): Redeploy armies between adjacent friendly territories."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Combat Formula: Attacker and defender roll up to 3 dice sorted highest-to-lowest; defenders win all ties.\n• Territory Cards & +2 Owned Bonus: Conquering at least one territory during your turn earns a country card; owning the matching territory grants +2 bonus armies on it.\n• Card Trades (`ExchangeCardsCommand`): Trading sets of 3 matching or 3 distinct symbols grants escalating army bonuses (4, 7, 10, 15...)."
				},
				{
					"heading": "4. Victory Condition",
					"body": "Win immediately upon fulfilling your Secret Objective or conquering all 30 territories (`TegGameOverEvent`)."
				}
			]
		}
	},
	"chinese_checkers": {
		"es": {
			"title": "Damas Chinas (Chinese Checkers)",
			"summary": "Carrera táctica de 2 a 6 jugadores sobre una estrella hexagonal de 121 casillas encadenando saltos sin capturas y regla anti-bloqueo.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Trasladar tus 10 canicas desde tu punta inicial de la estrella hasta rellenar por completo el triángulo de la punta directamente opuesta."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "En tu turno mueves una sola canica (`MovePegCommand`): bien desplazándola un paso a una casilla adyacente vacía en cualquiera de las 6 direcciones hexagonales, o realizando saltos encadenados (`path`)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Saltos en Cadena: Puedes saltar sobre una canica adyacente (propia o rival) hacia la casilla vacía inmediatamente simétrica en línea recta, encadenando tantos saltos como estén disponibles.\n• Sin Capturas: Las canicas saltadas nunca se retiran del tablero; sirven como puentes o escaleras para todos los jugadores.\n• Regla Oficial Anti-Bloqueo (Home-Camp Spoiling): Una canica que entró en su triángulo meta no puede salir de él; si las 10 casillas destino están llenas y al menos una es del dueño de esa meta, se le adjudica la victoria."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el primer jugador que completa las 10 posiciones del triángulo opuesto o cuando el rival se rinde (`ResignCommand`)."
				}
			]
		},
		"en": {
			"title": "Chinese Checkers",
			"summary": "Hexagonal star race for 2 to 6 players across 121 spaces using chain jumps without captures and the official Home-Camp Spoiling rule.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Be the first player to move all 10 of your marbles from your starting star point into the opposite target triangle."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Move one marble (`MovePegCommand`) either a single step to an adjacent empty hole in any of the 6 hexagonal directions, or via a chain of hops (`path`) over adjacent marbles."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Chain Hops: Hop over any adjacent marble (friendly or enemy) into the empty space directly beyond it in a straight line, chaining multiple hops.\n• No Captures: Jumped marbles remain on the board as jumping ladders.\n• Home-Camp Spoiling Rule: Marbles inside their target triangle cannot leave it; if all 10 target spaces are occupied and at least one belongs to the target owner, that player wins."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to fill all 10 spaces of the opposite star point (or upon opponent `ResignCommand`) wins."
				}
			]
		}
	},
	"battleship": {
		"es": {
			"title": "Batalla Naval (Battleship)",
			"summary": "Duelo táctico de deducción naval en cuadrícula de 10×10 con despliegue oculto de 5 buques, fuego por coordenadas y variante de turno extra al acertar.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Localizar y hundir los 5 buques (17 segmentos) de la flota enemiga antes de que el adversario destruya la tuya."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "1) Fase de Despliegue (`PlaceFleetCommand`): Cada comandante posiciona en secreto sus 5 barcos (Portaaviones [5], Acorazado [4], Crucero [3], Submarino [3] y Destructor [2]).\n2) Fase de Combate (`FireShotCommand`): En tu turno disparas a una coordenada (0–9, 0–9) del radar enemigo."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Agua, Tocado y Hundido (`ShotResultEvent`, `SunkenShipEvent`): Cada disparo informa si cayó en Agua (`Miss`), si impactó un barco (`Hit`) o si lo hundió por completo (`Sunk`).\n• Variante de Ráfaga (`SetBattleshipRulesCommand`): Si se activa `extra_turn_on_hit`, cada impacto exitoso concede un disparo adicional inmediato.\n• Separación y Revancha: Los barcos deben caber íntegramente en la grilla de 10×10 sin superponerse; al terminar se puede solicitar revancha (`RematchCommand`)."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el comandante que logra hundir los 5 barcos rivales o cuando el oponente se rinde (`ResignCommand`)."
				}
			]
		},
		"en": {
			"title": "Battleship",
			"summary": "Naval deduction duel on a 10×10 grid featuring hidden 5-ship fleet deployment, coordinate salvoes, and optional extra turn on hit.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Locate and sink all 5 ships (17 segments) in the enemy fleet before your own fleet is destroyed."
				},
				{
					"heading": "2. Turn Structure",
					"body": "1) Deployment Phase (`PlaceFleetCommand`): Secretly place your 5 ships (Carrier [5], Battleship [4], Cruiser [3], Submarine [3], and Destroyer [2]).\n2) Combat Phase (`FireShotCommand`): Fire at an unrevealed coordinate on the opponent's 10×10 radar grid."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Miss, Hit & Sunk (`ShotResultEvent`, `SunkenShipEvent`): Every shot reports whether it was a Miss, a Hit, or Sunk an entire ship.\n• Extra Turn on Hit (`SetBattleshipRulesCommand`): When `extra_turn_on_hit` is enabled, hitting a ship grants an immediate bonus shot.\n• Valid Fleet & Rematch: Ships must fit within the 10×10 grid without overlapping; players can request a rematch (`RematchCommand`) after the game."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first commander to sink all 5 enemy ships (or upon opponent `ResignCommand`) wins."
				}
			]
		}
	}
}

static func normalize_game_id(game_id: String) -> String:
	var key := game_id.strip_edges().to_lower()
	if key == "teg" or key == "crisis_teg":
		return "crisis"
	if key == "damas":
		return "checkers"
	if key == "ajedrez":
		return "chess"
	if key == "parchis":
		return "ludo"
	if CATALOG.has(key):
		return key
	return "checkers"

static func normalize_locale(locale: String) -> String:
	var lang := locale.strip_edges().to_lower()
	if lang.begins_with("en"):
		return "en"
	return "es"

static func get_all_game_ids() -> Array[String]:
	return CANONICAL_GAMES.duplicate()

static func get_rules(game_id: String, locale: String = "es") -> Dictionary:
	var canonical_id := normalize_game_id(game_id)
	var lang := normalize_locale(locale)
	var game_entry: Dictionary = CATALOG.get(canonical_id, CATALOG["checkers"])
	var localized: Dictionary = game_entry.get(lang, game_entry.get("es", {}))
	var secs: Array = localized.get("sections", []).duplicate(true)
	if secs.size() == 4:
		if lang == "en":
			secs.append({
				"heading": "5. Certified Canonical Rules",
				"body": "Strict server-authoritative validation of official tournament rules, illegal move rejection (MoveRejectedEvent), and deterministic replay verification."
			})
		else:
			secs.append({
				"heading": "5. Reglas Canónicas Certificadas",
				"body": "Validación estricta de reglamento oficial de torneo, rechazo determinista de jugadas ilegales (MoveRejectedEvent) y soporte completo de repetición (.otr)."
			})
	return {
		"game_id": canonical_id,
		"locale": lang,
		"title": String(localized.get("title", canonical_id.capitalize())),
		"summary": String(localized.get("summary", "")),
		"sections": secs
	}

static func get_game_rules(game_id: String, locale: String = "es") -> Dictionary:
	return get_rules(game_id, locale)

static func format_bbcode(game_id: String, locale: String = "es") -> String:
	var data := get_rules(game_id, locale)
	var lines := PackedStringArray()
	lines.append("[b][font_size=18]%s[/font_size][/b]" % String(data.get("title", "")))
	var summary: String = String(data.get("summary", ""))
	if not summary.is_empty():
		lines.append("[i][color=#B8C7E0]%s[/color][/i]" % summary)
	lines.append("")
	var sections: Array = data.get("sections", [])
	for sec in sections:
		if typeof(sec) == TYPE_DICTIONARY:
			var heading: String = String(sec.get("heading", ""))
			var body: String = String(sec.get("body", ""))
			lines.append("[b][color=#F5D061]%s[/color][/b]" % heading)
			lines.append(body)
			lines.append("")
	return "\n".join(lines).strip_edges()
