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
					"body": "En cada turno debes mover una ficha propia en diagonal hacia adelante una casilla libre, o saltar por encima de una ficha rival adyacente hacia la casilla vacía inmediatamente posterior."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Captura obligatoria: Si al inicio de tu turno existe una captura posible, estás obligado a ejecutarla.\n• Saltos múltiples: Si tras capturar una ficha la misma pieza puede seguir capturando, el turno continúa encadenando saltos.\n• Coronación (Dama): Al alcanzar la última fila del rival, el peón corona como Dama y puede desplazarse y capturar en diagonal tanto hacia adelante como hacia atrás."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el jugador que deja al rival sin piezas en el tablero o sin movimientos legales disponibles."
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
					"body": "Move one of your pieces diagonally forward to an empty adjacent square, or jump over an adjacent enemy piece onto the empty square directly beyond it."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Mandatory capture: Whenever a capture is available, you must take it.\n• Multi-jumps: If a capturing piece lands where another capture is immediately possible, it continues jumping in the same turn.\n• King promotion: Reaching the farthest row crowns the piece as a King, allowing diagonal movement and captures both forward and backward."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The player who captures all enemy pieces or leaves the opponent with no legal moves wins."
				}
			]
		}
	},
	"chess": {
		"es": {
			"title": "Ajedrez (Chess)",
			"summary": "Juego de estrategia milenario sobre 64 casillas con seis tipos de piezas y maniobras tácticas de jaque mate.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Acorralar al Rey adversario bajo ataque directo (jaque) sin que tenga escapatoria legal (jaque mate)."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Blancas mueven primero. En tu turno debes mover exactamente una pieza según su patrón (Rey, Dama, Torre, Alfil, Caballo o Peón). Ningún movimiento puede dejar a tu propio Rey en jaque."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Enroque (corto o largo): Maniobra conjunta entre el Rey y una Torre si ninguno se ha movido, no hay piezas entre ambos y el Rey no está en jaque ni pasa por casillas atacadas.\n• Captura al paso (En Passant): Si un peón rival avanza dos casillas desde su fila inicial y queda junto a tu peón, puedes capturarlo como si hubiera avanzado solo una.\n• Promoción: Todo peón que alcanza la octava fila se transforma inmediatamente en Dama, Torre, Alfil o Caballo."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Victoria por jaque mate o rendición rival. Es tablas por ahogado (sin jugadas legales sin estar en jaque), triple repetición o regla de los 50 movimientos."
				}
			]
		},
		"en": {
			"title": "Chess",
			"summary": "Timeless 64-square strategy game featuring six distinct piece types and checkmate tactics.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Place the opponent's King under inescapable attack (checkmate)."
				},
				{
					"heading": "2. Turn Structure",
					"body": "White moves first. Each turn, move one piece according to its movement pattern (King, Queen, Rook, Bishop, Knight, or Pawn). You may never make a move that leaves your own King in check."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Castling: Simultaneous King and Rook move when neither has moved, the path is clear, and the King does not start in, pass through, or end in check.\n• En Passant: A pawn advancing two squares from its starting rank past an enemy pawn may be captured on the immediately following turn.\n• Promotion: A pawn reaching the eighth rank promotes immediately to a Queen, Rook, Bishop, or Knight."
				},
				{
					"heading": "4. Victory Condition",
					"body": "Win by checkmate or opponent resignation. Draws occur by stalemate, threefold repetition, insufficient material, or the 50-move rule."
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
					"body": "El bando Rojo inicia la partida. En cada turno mueves una pieza sobre las intersecciones del tablero: General, Consejero, Elefante, Caballo, Carro (Torre), Cañón o Soldado (Peón)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• El Palacio (3×3): El General y los Consejeros nunca pueden salir de su Palacio.\n• El Río Central: Los Elefantes no pueden cruzar el río; los Soldados que lo cruzan ganan movimiento horizontal.\n• Bloqueo del Caballo y Elefante: El Caballo y el Elefante no saltan; si la intersección adyacente ortogonal/diagonal está ocupada, el movimiento queda bloqueado.\n• Cañón: Mueve como el Carro, pero para capturar necesita saltar exactamente sobre una pieza intermedia (pantalla).\n• Generales enfrentados: Los dos Generales nunca pueden mirarse directamente en la misma columna sin piezas entre ellos."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana quien da jaque mate o deja sin jugadas legales al rival (en Xiangqi el ahogado otorga la victoria a quien lo provoca)."
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
					"body": "Red moves first. Move one piece along grid intersections according to its role: General, Advisor, Elephant, Horse, Chariot, Cannon, or Soldier."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Palace (3×3): The General and Advisors may never leave their Palace.\n• Central River: Elephants cannot cross the river; Soldiers gain horizontal movement once they cross it.\n• Hobbling the Horse/Elephant: Horses and Elephants can be blocked if the adjacent pivot point is occupied.\n• Cannon: Moves like a Chariot, but must jump over exactly one intervening screen piece to capture.\n• Flying General: The two Generals may never face each other along an open file with no pieces in between."
				},
				{
					"heading": "4. Victory Condition",
					"body": "Win by checkmate or by leaving the opponent with no legal moves (stalemate is a win in Xiangqi)."
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
					"body": "Sente (Negras) juega primero. En tu turno puedes mover una pieza en el tablero (y promocionarla si entra, sale o se mueve dentro de las 3 últimas filas) o bien reingresar (Drop) una pieza previamente capturada en cualquier casilla vacía."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Reingreso (Drop): Las piezas capturadas pasan a tu reserva (Komadai) y pueden colocarse sin promocionar en una casilla vacía consumiendo el turno.\n• Nifu (Dos Peones): Está prohibido reingresar un peón en una columna que ya contenga otro peón propio sin promocionar.\n• Uchifuzume: No se permite dar jaque mate inmediato reingresando un peón; sí está permitido dar jaque mate moviendo un peón que ya estaba en el tablero.\n• Promoción obligatoria: Peones, Lanzas y Caballos deben promocionar si alcanzan una fila desde la cual ya no tendrían movimientos futuros."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el jugador que da jaque mate al Rey rival."
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
					"body": "Sente (Black) moves first. On your turn, either move one piece on the board (optionally promoting it within the farthest three ranks) or drop a captured piece from your hand onto any legal empty square."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Drops: Captured pieces join your hand unpromoted and can be dropped onto empty squares.\n• Nifu (Two Pawns): You may not drop an unpromoted pawn onto a file that already contains one of your unpromoted pawns.\n• Uchifuzume: Dropping a pawn to deliver immediate checkmate is illegal.\n• Mandatory Promotion: Pawns, Lances, and Knights must promote upon reaching a rank from which they could no longer move."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The player who checkmates the opposing King wins."
				}
			]
		}
	},
	"backgammon": {
		"es": {
			"title": "Backgammon",
			"summary": "Carrera estratégica de 15 fichas a lo largo de 24 picos combinando tiradas de dados, bloqueo y capturas a la barra.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Llevar tus 15 fichas hasta tu cuadrante interior (Home Board) y ser el primero en retirarlas todas (Bearing Off) fuera del tablero."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Tira dos dados y avanza tus fichas según los valores obtenidos (puedes usar ambos dados con una misma ficha o repartirlos entre dos). No puedes aterrizar en un pico ocupado por 2 o más fichas rivales."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Tirada Doble: Si ambos dados muestran el mismo número, juegas cuatro veces ese valor.\n• Captura (Blot / Hit): Si aterrizas sobre un pico con una única ficha rival descubierta (Blot), la golpeas y la envías a la Barra central.\n• Reingreso desde la Barra: Mientras tengas fichas en la Barra, no puedes mover ninguna otra ficha hasta reingresarlas en el cuadrante inicial enemigo.\n• Retirada (Bearing Off): Solo puedes retirar fichas fuera del tablero cuando tus 15 fichas estén dentro de tu cuadrante interior (picos 1 a 6)."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el primer jugador que retira sus 15 fichas del tablero (Victoria simple, Gammon si el rival no retiró ninguna, o Backgammon si aún tiene fichas en la barra o en tu cuadrante)."
				}
			]
		},
		"en": {
			"title": "Backgammon",
			"summary": "Strategic race of 15 checkers across 24 points combining dice rolls, blocking primes, and hitting blots.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Bring all 15 of your checkers into your home board and be the first to bear them all off."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Roll two dice and move your checkers forward according to each die value. You cannot land on a point occupied by two or more opposing checkers."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Doubles: Rolling matching dice grants four moves of that number.\n• Hitting a Blot: Landing on a single opposing checker sends it to the central Bar.\n• Entering from the Bar: Checkers on the Bar must re-enter through the opponent's home board before any other checker can move.\n• Bearing Off: Once all 15 of your checkers are in your home board, you may bear them off according to the dice rolls."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to bear off all 15 checkers wins the match."
				}
			]
		}
	},
	"ludo": {
		"es": {
			"title": "Ludo (Parchís)",
			"summary": "Carrera clásica de 4 fichas alrededor del circuito en cruz desde la base hasta la meta central.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Recorrer todo el circuito del tablero con tus 4 fichas desde tu base inicial hasta el triángulo central de meta."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Lanza el dado de 6 caras y elige cuál de tus fichas activas avanzar el número exacto de casillas indicado."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Salida con 6: Para poner una ficha desde la base en la casilla de salida necesitas obtener un 6 en el dado.\n• Turno extra: Sacar un 6 otorga una tirada adicional inmediata.\n• Captura: Si terminas tu movimiento en una casilla normal ocupada por una ficha rival, la devuelves a su base inicial.\n• Casillas Seguras y Pasillo Final: Las casillas marcadas con estrella son seguras; en el pasillo de color hacia la meta debes entrar con tirada exacta."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el primer jugador que logra introducir sus 4 fichas en la casilla central de meta."
				}
			]
		},
		"en": {
			"title": "Ludo",
			"summary": "Classic race of 4 tokens around a cross-shaped track from your starting yard to the central home triangle.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Move all 4 of your tokens from your starting yard around the track and into the center home triangle."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Roll the six-sided die and advance one of your valid tokens by the exact number rolled."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Entering Play: A roll of 6 is required to move a token out of your starting yard onto the starting square.\n• Bonus Roll: Rolling a 6 grants an extra roll.\n• Capturing: Landing on an opponent's token on a non-safe square sends that token back to its starting yard.\n• Safe Squares & Home Column: Starred squares protect tokens from capture; entering the center home triangle requires an exact roll."
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
			"summary": "Juego abstracto de rodeo territorial y captura por libertades colocando piedras negras y blancas en las intersecciones.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Controlar una mayor puntuación combinada de territorio vacío rodeado y piedras capturadas que tu adversario al final de la partida."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Negras juegan primero. En tu turno colocas una piedra en cualquier intersección vacía del tablero o eliges Pasar el turno."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Libertades y Captura: Las intersecciones vacías ortogonalmente adyacentes a una piedra o cadena conectada son sus libertades. Si una jugada deja a un grupo rival con 0 libertades, todas las piedras de ese grupo son capturadas.\n• Prohibición de Suicidio: No puedes colocar una piedra en un punto donde tu propio grupo quedaría sin libertades, salvo que esa misma jugada capture piedras enemigas.\n• Regla del Ko: Está prohibido realizar una jugada que repita exactamente el estado previo completo del tablero."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Cuando ambos jugadores pasan consecutivamente, finaliza la partida y se cuentan puntos de área/territorio más el Komi de compensación para Blancas."
				}
			]
		},
		"en": {
			"title": "Go (Weiqi / Baduk)",
			"summary": "Ancient abstract game of surrounding territory and capturing stones by removing their liberties.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Control more total points of surrounded territory and captured stones than your opponent."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Black plays first. On your turn, place one stone on any vacant intersection or Pass."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Liberties & Capture: Orthogonally connected stones share liberties (adjacent empty intersections). Any group reduced to zero liberties is captured and removed.\n• No Suicide: You may not play a stone that leaves your own group with zero liberties unless that play immediately captures enemy stones.\n• Ko Rule: You may not make a move that recreates the exact previous board position."
				},
				{
					"heading": "4. Victory Condition",
					"body": "When both players pass consecutively, scores are tallied (surrounded territory + captures + Komi for White). Highest score wins."
				}
			]
		}
	},
	"mille_bornes": {
		"es": {
			"title": "Mille Bornes (1000 Kilómetros)",
			"summary": "Carrera automovilística de cartas donde avanzas kilómetros mientras saboteas al rival con peligros de ruta y te proteges con escudos.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Ser el primero en recorrer exactamente 1000 kilómetros (o liderar en distancia cuando se agota el mazo y las manos)."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "En tu turno robas una carta para tener 7 en mano y luego debes jugar una carta (de Distancia, Peligro, Reparación o Escudo/Safety) o descartar una al pozo."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Semáforo Verde (Roll): Necesitas tener un Semáforo Verde activo (o el escudo Prioridad de Paso) para poder jugar cartas de distancia.\n• Peligros y Reparaciones: Pinchazo → Rueda de Auxilio; Sin Gasolina → Gasolina; Accidente → Taller; Límite de 50 km/h → Fin de Límite; Semáforo Rojo → Semáforo Verde.\n• Escudos (Safeties): As del Volante, Camión Cisterna, Inpinchable y Prioridad de Paso te inmunizan permanentemente contra sus peligros correspondientes.\n• Coup Fourré: Jugar un Escudo en respuesta al Peligro correspondiente otorga bonificación y turno extra.\n• Límite de cartas de 200 km: Cada jugador puede jugar como máximo dos cartas de 200 km por partida."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana quien alcanza primero los 1000 km exactos (sin pasarse) o quien acumula mayor kilometraje al agotarse todas las cartas."
				}
			]
		},
		"en": {
			"title": "Mille Bornes (1000 Miles)",
			"summary": "French road-race card game where you play distance cards, sabotage rivals with hazards, and deploy permanent safeties.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Be the first driver to accumulate exactly 1000 kilometers (or have the highest distance when the deck and hands run out)."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Draw a card and either play one card (Distance, Hazard, Remedy, or Safety) or discard one card."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Roll (Green Light): You must have a Roll card active (or the Right of Way safety) to play distance cards unless capped by a Speed Limit (50 km max).\n• Hazards & Remedies: Flat Tire → Spare Tire; Out of Gas → Gasoline; Accident → Repairs; Speed Limit → End of Limit; Stop → Roll.\n• Safeties: Driving Ace, Extra Tank, Puncture-Proof, and Right of Way provide permanent immunity against their matching hazards and grant an extra turn.\n• 200 km Limit: A player may play at most two 200 km cards per hand."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to reach exactly 1000 km (or the leader when all cards are exhausted) wins."
				}
			]
		}
	},
	"monopoly": {
		"es": {
			"title": "Monopolio (Monopoly)",
			"summary": "Juego económico de compraventa de propiedades, cobro de alquileres, subastas y construcción sobre un circuito de 40 casillas.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Multiplicar tu capital comprando propiedades, formando monopolios de color y edificando casas y hoteles hasta llevar a la bancarrota a tus rivales."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Lanza los dos dados, avanza tu peón por las 40 casillas y resuelve el efecto de la casilla (comprar solar libre, subastarlo, pagar alquiler al dueño, robar tarjeta de Suerte/Arca Comunal o pagar impuestos)."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Salida (GO): Cada vez que pasas o caes en la casilla de Salida cobras $200 del banco.\n• Monopolio y Construcción: Al poseer todos los solares de un mismo color cobras doble alquiler en solares sin edificar y habilitas la construcción uniforme de casas y hoteles.\n• Subastas: Si un jugador cae en una propiedad sin dueño y decide no comprarla al precio de lista, se subasta entre todos los jugadores.\n• Cárcel: Puedes salir pagando fianza, usando tarjeta de libertad o sacando dobles; tres dobles seguidos te envían directamente a la Cárcel."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el último jugador que permanece solvente tras la bancarrota de los demás, o quien posea el mayor patrimonio neto al límite de rondas."
				}
			]
		},
		"en": {
			"title": "Monopoly",
			"summary": "Classic real-estate trading game across 40 spaces featuring property purchases, auctions, rent collection, and building upgrades.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Acquire property groups, build houses and hotels, and bankrupt your opponents through rent collection."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Roll two dice, advance your token around the 40-space board, and resolve the space you land on (buy unowned property, trigger an auction, pay rent, draw Chance/Community Chest, or pay tax)."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Passing GO: Collect $200 every time you land on or pass GO.\n• Color Monopolies & Building: Owning a complete color group doubles unimproved rent and unlocks building houses and hotels evenly.\n• Auctions: Declining to purchase an unowned property puts it up for immediate auction.\n• Jail: Leave Jail by rolling doubles, using a Get Out of Jail Free card, or paying bail; rolling three consecutive doubles sends you to Jail."
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
			"summary": "Juego dinámico de descarte por color o símbolo con cartas de acción que alteran el orden del turno y penalizan al rival.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Ser el primer jugador en descartar todas las cartas de su mano."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Juega una carta de tu mano que coincida en color, número o símbolo con la carta superior de la pila de descarte, o bien juega un Comodín. Si no tienes jugada válida, debes robar una carta del mazo."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Salto (Skip): El siguiente jugador pierde su turno.\n• Reversa (Reverse): Invierte el sentido de giro de los turnos (en partidas de 2 jugadores actúa como un Salto).\n• Roba Dos (+2): El siguiente jugador roba 2 cartas y pierde su turno.\n• Comodín (Wild): Permite cambiar el color activo de la pila de descarte.\n• Comodín Roba Cuatro (Wild +4): Cambia el color activo y obliga al siguiente jugador a robar 4 cartas y perder su turno."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el primer jugador que se queda con 0 cartas en la mano."
				}
			]
		},
		"en": {
			"title": "Uno",
			"summary": "Fast-paced shedding card game matching colors or symbols while using action and wild cards to disrupt opponents.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Be the first player to play all cards from your hand."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Play a card matching the active color, number, or symbol of the top discard card, or play a Wild card. If you cannot play, draw a card from the deck."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Skip: Skips the next player's turn.\n• Reverse: Reverses turn direction (acts like a Skip in 2-player matches).\n• Draw Two (+2): Next player draws 2 cards and loses their turn.\n• Wild: Choose the new active color.\n• Wild Draw Four (+4): Choose the new active color and force the next player to draw 4 cards and skip their turn."
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
			"summary": "Gran estrategia geopolítica por turnos con refuerzos por continentes, combate con dados, tarjetas de país y objetivos secretos.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Cumplir tu Objetivo Secreto asignado al comienzo de la partida o alcanzar la Conquista Global ocupando todos los territorios del mapa."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "Cada turno se divide en tres fases secuenciales:\n1) Incorporación (PlaceArmies): Coloca tus ejércitos de refuerzo según la cantidad de países propios (mínimo 3) más bonos por continentes dominados.\n2) Ataque (Attack): Ataca desde cualquier territorio con 2 o más ejércitos hacia territorios enemigos limítrofes.\n3) Reagrupamiento (Fortify): Desplaza ejércitos entre territorios propios adyacentes antes de finalizar el turno."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Resolución de Combate: El atacante lanza hasta 3 dados (ejércitos menos 1) y el defensor hasta 3 dados. Se ordenan de mayor a menor y se comparan par a par; en caso de empate en un dado, gana siempre el defensor.\n• Conquista y Ocupación: Al dejar un país enemigo con 0 ejércitos, debes desplazar entre 1 y 3 tropas desde el país atacante.\n• Tarjetas y Canje: Si conquistas al menos un territorio en tu turno recibes tarjeta de país; canjear 3 tarjetas iguales o 3 distintas otorga refuerzos crecientes."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Victoria inmediata al verificar el cumplimiento de tu Objetivo Secreto o al controlar los 30 territorios del mapa."
				}
			]
		},
		"en": {
			"title": "Crisis (T.E.G. — Tactical & Strategic War Plan)",
			"summary": "Turn-based global strategy featuring continent bonuses, dice combat where ties favor the defender, country cards, and secret objectives.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Complete your assigned Secret Objective or achieve Global Conquest by controlling all 30 territories on the map."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Every turn follows three phases:\n1) Place Armies: Deploy reinforcements based on territories owned (minimum 3) plus continent control bonuses.\n2) Attack: Launch attacks from any territory with at least 2 armies against adjacent enemy territories.\n3) Fortify: Redeploy armies between connected friendly territories before ending your turn."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Combat Formula: Attacker rolls up to 3 dice (armies minus 1) and defender rolls up to 3 dice. Dice are sorted highest-to-lowest and compared pair by pair; defenders win all ties.\n• Territory Cards: Conquering at least one territory during your turn earns a country card; trading sets of 3 matching or 3 distinct symbols grants escalating army bonuses."
				},
				{
					"heading": "4. Victory Condition",
					"body": "Win immediately upon fulfilling your Secret Objective or conquering all territories on the map."
				}
			]
		}
	},
	"chinese_checkers": {
		"es": {
			"title": "Damas Chinas (Chinese Checkers)",
			"summary": "Carrera táctica de 2 a 6 jugadores sobre una estrella hexagonal de 121 casillas encadenando saltos sin capturas.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Trasladar tus 10 canicas desde tu punta inicial de la estrella hasta rellenar por completo el triángulo de la punta directamente opuesta."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "En tu turno mueves una sola canica: bien desplazándola un paso a una casilla adyacente vacía en cualquiera de las 6 direcciones hexagonales, o bien realizando uno o varios saltos encadenados."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Saltos en Cadena: Puedes saltar sobre una canica adyacente (propia o rival) hacia la casilla vacía inmediatamente simétrica en línea recta, y seguir encadenando saltos con la misma pieza.\n• Sin Capturas: Las canicas saltadas nunca se retiran del tablero; sirven como puentes o escaleras para ambos bandos.\n• Regla Anti-Bloqueo: Una canica que ya entró en su triángulo de meta opuesto no puede salir de él para no bloquear permanentemente la victoria."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el primer jugador que ocupa las 10 posiciones del triángulo opuesto."
				}
			]
		},
		"en": {
			"title": "Chinese Checkers",
			"summary": "Hexagonal star race for 2 to 6 players across 121 spaces using chain jumps without captures.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Be the first player to move all 10 of your marbles from your starting star point into the opposite target triangle."
				},
				{
					"heading": "2. Turn Structure",
					"body": "Move one marble either a single step to an adjacent empty hole in any of the 6 hexagonal directions, or via a chain of hops over adjacent marbles."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Chain Hops: Hop over any adjacent marble (friendly or enemy) into the empty space directly beyond it in a straight line, chaining as many hops as available.\n• No Captures: Jumped marbles remain on the board, allowing players to build long jumping ladders.\n• Destination Lock: Marbles that have entered their target triangle may move within it but cannot leave it."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first player to fill all 10 spaces of the opposite star point wins."
				}
			]
		}
	},
	"battleship": {
		"es": {
			"title": "Batalla Naval (Battleship)",
			"summary": "Duelo táctico de deducción naval en cuadrícula de 10×10 con despliegue oculto de flota y fuego por coordenadas.",
			"sections": [
				{
					"heading": "1. Objetivo",
					"body": "Localizar y hundir los 5 buques de la flota enemiga antes de que el adversario destruya la tuya."
				},
				{
					"heading": "2. Desarrollo del Turno",
					"body": "1) Fase de Despliegue: Cada comandante posiciona en secreto sus 5 barcos (Portaaviones [5], Acorazado [4], Crucero [3], Submarino [3] y Destructor [2]) en orientación horizontal o vertical.\n2) Fase de Combate: En tu turno disparas a una coordenada (A1–J10) del radar enemigo."
				},
				{
					"heading": "3. Reglas Especiales",
					"body": "• Agua, Tocado y Hundido: Cada disparo informa si cayó en Agua, si impactó un barco (Tocado) o si destruyó la última casilla intacta de ese buque (Hundido).\n• Coordenadas Únicas: No se puede volver a disparar sobre una coordenada ya bombardeada previamente.\n• Despliegue Válido: Los barcos deben permanecer íntegramente dentro de la cuadrícula de 10×10 y no pueden superponerse entre sí."
				},
				{
					"heading": "4. Condición de Victoria",
					"body": "Gana el comandante que logra hundir las 17 casillas totales que componen los 5 barcos de la flota rival."
				}
			]
		},
		"en": {
			"title": "Battleship",
			"summary": "Naval deduction duel on a 10×10 grid featuring hidden fleet deployment and coordinate salvoes.",
			"sections": [
				{
					"heading": "1. Objective",
					"body": "Locate and sink all 5 ships in the enemy fleet before your own fleet is destroyed."
				},
				{
					"heading": "2. Turn Structure",
					"body": "1) Deployment Phase: Secretly place your 5 ships (Carrier [5], Battleship [4], Cruiser [3], Submarine [3], and Destroyer [2]) horizontally or vertically.\n2) Combat Phase: Fire at one unrevealed coordinate (A1–J10) on the opponent's radar grid each turn."
				},
				{
					"heading": "3. Special Rules",
					"body": "• Miss, Hit & Sunk: Every shot reports whether it was a Miss, a Hit, or Sunk an entire ship.\n• No Repeat Shots: Coordinates already targeted cannot be fired upon again.\n• Fleet Placement: Ships must fit entirely within the 10×10 grid and cannot overlap."
				},
				{
					"heading": "4. Victory Condition",
					"body": "The first commander to sink all 5 enemy ships (17 total ship segments) wins."
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
	return {
		"game_id": canonical_id,
		"locale": lang,
		"title": String(localized.get("title", canonical_id.capitalize())),
		"summary": String(localized.get("summary", "")),
		"sections": localized.get("sections", []).duplicate(true)
	}

static func format_bbcode(game_id: String, locale: String = "es") -> String:
	var data := get_rules(game_id, locale)
	var lines := PackedStringArray()
	lines.append("[b][font_size=18]%s[/font_size][/b]" % String(data.get("title", "")))
	var summary := String(data.get("summary", ""))
	if not summary.is_empty():
		lines.append("[i][color=#B8C7E0]%s[/color][/i]" % summary)
	lines.append("")
	var sections: Array = data.get("sections", [])
	for sec in sections:
		if typeof(sec) == TYPE_DICTIONARY:
			var heading := String(sec.get("heading", ""))
			var body := String(sec.get("body", ""))
			lines.append("[b][color=#F5D061]%s[/color][/b]" % heading)
			lines.append(body)
			lines.append("")
	return "\n".join(lines).strip_edges()
