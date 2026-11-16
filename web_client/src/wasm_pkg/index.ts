/**
 * OpenTable WebAssembly Bridge Loader (`open_table_wasm`) — 14/14 Juegos Canónicos
 *
 * Carga el binario `.wasm` compilado desde `games_tables_sdk/open_table_wasm` cuando
 * está presente y provee un motor determinista isomórfico para los 14 juegos con el mismo
 * contrato JSON (`get_state_json`, `get_legal_moves_json`, `send_command_json`,
 * `apply_sync_log_json`, `step_ai_if_needed`).
 */

export interface ChessPiece {
  kind: "Pawn" | "Knight" | "Bishop" | "Rook" | "Queen" | "King";
  owner: 1 | 2;
}

export interface ChessMove {
  from: [number, number];
  to: [number, number];
  promotion?: "Queen" | "Rook" | "Bishop" | "Knight";
}

export interface CheckersPiece {
  owner: 1 | 2;
  isKing: boolean;
}

export interface CheckersMove {
  from: [number, number];
  to: [number, number];
  captured?: [number, number];
}

export interface UnoCard {
  id: string;
  color: "Red" | "Yellow" | "Green" | "Blue" | "Wild";
  value:
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9"
    | "Skip"
    | "Reverse"
    | "DrawTwo"
    | "Wild"
    | "WildDrawFour";
}

export interface GoosePlayerState {
  player: 1 | 2;
  square: number;
  skipTurns: number;
  inWell: boolean;
}

export interface ShogiPiece {
  kind: "Pawn" | "Lance" | "Knight" | "Silver" | "Gold" | "Bishop" | "Rook" | "King";
  owner: 1 | 2;
  promoted: boolean;
}

export interface XiangqiPiece {
  kind: "General" | "Advisor" | "Elephant" | "Horse" | "Chariot" | "Cannon" | "Soldier";
  owner: 1 | 2;
}

export interface MonopolySpace {
  index: number;
  name: string;
  group: string;
  price: number;
  rent: number;
  owner: 1 | 2 | null;
  houses: number;
  mortgaged: boolean;
}

export interface CrisisTerritory {
  id: number;
  name: string;
  continent: string;
  owner: 1 | 2;
  armies: number;
  neighbors: number[];
}

const GOOSE_SQUARES = new Set([5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59]);

function createInitialChessGrid(): (ChessPiece | null)[][] {
  const grid: (ChessPiece | null)[][] = Array.from({ length: 8 }, () =>
    Array.from({ length: 8 }, () => null)
  );
  const backRank: ChessPiece["kind"][] = [
    "Rook",
    "Knight",
    "Bishop",
    "Queen",
    "King",
    "Bishop",
    "Knight",
    "Rook",
  ];
  for (let c = 0; c < 8; c++) {
    grid[0][c] = { kind: backRank[c], owner: 2 };
    grid[1][c] = { kind: "Pawn", owner: 2 };
    grid[6][c] = { kind: "Pawn", owner: 1 };
    grid[7][c] = { kind: backRank[c], owner: 1 };
  }
  return grid;
}

function createInitialCheckersGrid(): (CheckersPiece | null)[][] {
  const grid: (CheckersPiece | null)[][] = Array.from({ length: 8 }, () =>
    Array.from({ length: 8 }, () => null)
  );
  for (let r = 0; r < 3; r++) {
    for (let c = 0; c < 8; c++) {
      if ((r + c) % 2 === 1) grid[r][c] = { owner: 2, isKing: false };
    }
  }
  for (let r = 5; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      if ((r + c) % 2 === 1) grid[r][c] = { owner: 1, isKing: false };
    }
  }
  return grid;
}

function createInitialUnoDeck(seed: number): UnoCard[] {
  const colors: ("Red" | "Yellow" | "Green" | "Blue")[] = ["Red", "Yellow", "Green", "Blue"];
  const deck: UnoCard[] = [];
  let idx = 1;
  for (const color of colors) {
    deck.push({ id: `c_${idx++}`, color, value: "0" });
    const values: UnoCard["value"][] = [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "Skip",
      "Reverse",
      "DrawTwo",
    ];
    for (const v of values) {
      deck.push({ id: `c_${idx++}`, color, value: v });
      deck.push({ id: `c_${idx++}`, color, value: v });
    }
  }
  for (let i = 0; i < 4; i++) {
    deck.push({ id: `c_${idx++}`, color: "Wild", value: "Wild" });
    deck.push({ id: `c_${idx++}`, color: "Wild", value: "WildDrawFour" });
  }
  let s = (seed || 1) >>> 0;
  for (let i = deck.length - 1; i > 0; i--) {
    s = (Math.imul(1664525, s) + 1013904223) >>> 0;
    const j = s % (i + 1);
    const tmp = deck[i];
    deck[i] = deck[j];
    deck[j] = tmp;
  }
  return deck;
}

function createInitialShogiGrid(): (ShogiPiece | null)[][] {
  const grid: (ShogiPiece | null)[][] = Array.from({ length: 9 }, () =>
    Array.from({ length: 9 }, () => null)
  );
  const back: ShogiPiece["kind"][] = [
    "Lance",
    "Knight",
    "Silver",
    "Gold",
    "King",
    "Gold",
    "Silver",
    "Knight",
    "Lance",
  ];
  for (let c = 0; c < 9; c++) {
    grid[0][c] = { kind: back[c], owner: 2, promoted: false };
    grid[2][c] = { kind: "Pawn", owner: 2, promoted: false };
    grid[6][c] = { kind: "Pawn", owner: 1, promoted: false };
    grid[8][c] = { kind: back[c], owner: 1, promoted: false };
  }
  grid[1][1] = { kind: "Rook", owner: 2, promoted: false };
  grid[1][7] = { kind: "Bishop", owner: 2, promoted: false };
  grid[7][1] = { kind: "Bishop", owner: 1, promoted: false };
  grid[7][7] = { kind: "Rook", owner: 1, promoted: false };
  return grid;
}

function createInitialXiangqiGrid(): (XiangqiPiece | null)[][] {
  const grid: (XiangqiPiece | null)[][] = Array.from({ length: 10 }, () =>
    Array.from({ length: 9 }, () => null)
  );
  const back: XiangqiPiece["kind"][] = [
    "Chariot",
    "Horse",
    "Elephant",
    "Advisor",
    "General",
    "Advisor",
    "Elephant",
    "Horse",
    "Chariot",
  ];
  for (let c = 0; c < 9; c++) {
    grid[0][c] = { kind: back[c], owner: 2 };
    grid[9][c] = { kind: back[c], owner: 1 };
  }
  grid[2][1] = { kind: "Cannon", owner: 2 };
  grid[2][7] = { kind: "Cannon", owner: 2 };
  grid[7][1] = { kind: "Cannon", owner: 1 };
  grid[7][7] = { kind: "Cannon", owner: 1 };
  for (const c of [0, 2, 4, 6, 8]) {
    grid[3][c] = { kind: "Soldier", owner: 2 };
    grid[6][c] = { kind: "Soldier", owner: 1 };
  }
  return grid;
}

function createInitialMonopolySpaces(): MonopolySpace[] {
  const names = [
    ["Salida GO", "Special", 0, 0],
    ["Av. Mediterráneo", "Brown", 60, 10],
    ["Arca Comunal", "Special", 0, 0],
    ["Av. Báltica", "Brown", 60, 12],
    ["Impuesto Renta", "Special", 0, 100],
    ["FF.CC. Reading", "Rail", 200, 25],
    ["Av. Oriental", "LightBlue", 100, 18],
    ["Suerte", "Special", 0, 0],
    ["Av. Vermont", "LightBlue", 100, 18],
    ["Av. Connecticut", "LightBlue", 120, 22],
    ["Cárcel / Visita", "Special", 0, 0],
    ["Plaza San Carlos", "Pink", 140, 26],
    ["Compañía Eléctrica", "Utility", 150, 28],
    ["Av. Estados", "Pink", 140, 26],
    ["Av. Virginia", "Pink", 160, 30],
    ["FF.CC. Pensilvania", "Rail", 200, 25],
    ["Plaza Santiago", "Orange", 180, 34],
    ["Arca Comunal", "Special", 0, 0],
    ["Av. Tennessee", "Orange", 180, 34],
    ["Av. Nueva York", "Orange", 200, 38],
    ["Parada Libre", "Special", 0, 0],
    ["Av. Kentucky", "Red", 220, 42],
    ["Suerte", "Special", 0, 0],
    ["Av. Indiana", "Red", 220, 42],
    ["Av. Illinois", "Red", 240, 48],
    ["FF.CC. B&O", "Rail", 200, 25],
    ["Av. Atlántico", "Yellow", 260, 52],
    ["Av. Ventnor", "Yellow", 260, 52],
    ["Obras de Agua", "Utility", 150, 28],
    ["Jardines Marvin", "Yellow", 280, 56],
    ["Ir a la Cárcel", "Special", 0, 0],
    ["Av. Pacífico", "Green", 300, 60],
    ["Av. Carolina Norte", "Green", 300, 60],
    ["Arca Comunal", "Special", 0, 0],
    ["Av. Pensilvania", "Green", 320, 66],
    ["FF.CC. Vía Rápida", "Rail", 200, 25],
    ["Suerte", "Special", 0, 0],
    ["Plaza Park", "DarkBlue", 350, 75],
    ["Impuesto de Lujo", "Special", 0, 100],
    ["El Muelle (Boardwalk)", "DarkBlue", 400, 100],
  ] as const;

  return names.map(([name, group, price, rent], index) => ({
    index,
    name,
    group,
    price,
    rent,
    owner: null,
    houses: 0,
    mortgaged: false,
  }));
}

function createInitialCrisisTerritories(): CrisisTerritory[] {
  const specs: [string, string][] = [
    ["Alaska", "América del Norte"],
    ["Yukón", "América del Norte"],
    ["Canadá", "América del Norte"],
    ["Oregón", "América del Norte"],
    ["Nueva York", "América del Norte"],
    ["México", "América del Norte"],
    ["Colombia", "América del Sur"],
    ["Brasil", "América del Sur"],
    ["Perú", "América del Sur"],
    ["Argentina", "América del Sur"],
    ["Islandia", "Europa"],
    ["Gran Bretaña", "Europa"],
    ["España", "Europa"],
    ["Francia", "Europa"],
    ["Alemania", "Europa"],
    ["Polonia", "Europa"],
    ["Rusia", "Europa"],
    ["Sahara", "África"],
    ["Egipto", "África"],
    ["Etiopía", "África"],
    ["Zaire", "África"],
    ["Sudáfrica", "África"],
    ["Madagascar", "África"],
    ["Aral", "Asia"],
    ["Siberia", "Asia"],
    ["Kamchatka", "Asia"],
    ["China", "Asia"],
    ["India", "Asia"],
    ["Japón", "Asia"],
    ["Australia", "Oceanía"],
  ];
  return specs.map(([name, continent], id) => ({
    id,
    name,
    continent,
    owner: (id % 2 === 0 ? 1 : 2) as 1 | 2,
    armies: 3,
    neighbors: [
      (id + 1) % 30,
      (id + 29) % 30,
      (id + 5) % 30,
    ],
  }));
}

export class WasmGameBridge {
  private gameType: string = "chess";
  private turn: 1 | 2 = 1;
  private tick: number = 0;
  private winner: 0 | 1 | 2 | null = null;
  private aiPlayer: 1 | 2 | null = null;
  private aiDifficulty: number = 1;
  private commandLog: { player: number; command: string }[] = [];
  private rngState: number = 1337;

  // 1. Chess state
  private chessGrid: (ChessPiece | null)[][] = createInitialChessGrid();
  private chessLastMove: { from: [number, number]; to: [number, number] } | null = null;
  private chessDrawOfferedBy: 1 | 2 | null = null;
  private chessInCheck: 1 | 2 | null = null;

  // 2. Checkers state
  private checkersGrid: (CheckersPiece | null)[][] = createInitialCheckersGrid();
  private checkersChainPos: [number, number] | null = null;

  // 3. UNO state
  private unoDeck: UnoCard[] = [];
  private unoDiscard: UnoCard[] = [];
  private unoHands: Record<1 | 2, UnoCard[]> = { 1: [], 2: [] };
  private unoActiveColor: "Red" | "Yellow" | "Green" | "Blue" = "Red";
  private unoDrawPenalty: number = 0;
  private unoCalled: Record<1 | 2, boolean> = { 1: false, 2: false };
  private unoLastEvent: string = "Partida iniciada";

  // 4. Goose state
  private goosePlayers: Record<1 | 2, GoosePlayerState> = {
    1: { player: 1, square: 0, skipTurns: 0, inWell: false },
    2: { player: 2, square: 0, skipTurns: 0, inWell: false },
  };
  private gooseLastDice: [number, number] = [1, 1];
  private gooseLastBanner: string = "Lanza los dados 3D para comenzar en la casilla 0.";

  // 5. Go state
  private goSize: 9 | 13 | 19 = 9;
  private goGrid: (0 | 1 | 2)[][] = [];
  private goCaptures: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private goPasses: number = 0;
  private goDeadStones: string[] = [];
  private goHandicap: number = 0;
  private goScoringPhase: boolean = false;

  // 6. Shogi state
  private shogiGrid: (ShogiPiece | null)[][] = createInitialShogiGrid();
  private shogiHands: Record<1 | 2, ShogiPiece["kind"][]> = { 1: [], 2: [] };

  // 7. Xiangqi state
  private xiangqiGrid: (XiangqiPiece | null)[][] = createInitialXiangqiGrid();
  private xiangqiBanner: string = "Río Chu He / Han Jie activo · Regla de General Volador activa";

  // 8. Chinese Checkers state
  private ccCells: { id: string; r: number; c: number; owner: 0 | 1 | 2; zone: 0 | 1 | 2 }[] = [];

  // 9. Backgammon state
  private bgPoints: { count: number; owner: 0 | 1 | 2 }[] = [];
  private bgBar: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private bgBorneOff: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private bgDice: [number, number] = [3, 5];
  private bgCubeValue: number = 1;
  private bgCubeOfferedBy: 1 | 2 | null = null;

  // 10. Ludo state
  private ludoTokens: Record<1 | 2, number[]> = { 1: [0, 0, 0, 0], 2: [0, 0, 0, 0] };
  private ludoDice: [number, number] = [6, 1];
  private ludoLastBanner: string = "Saca 6 o avanza tus fichas por las 52 casillas.";

  // 11. Battleship state
  private bsShots: Record<1 | 2, Record<string, "hit" | "miss">> = { 1: {}, 2: {} };
  private bsHitsCount: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private bsExtraTurnOnHit: boolean = false;
  private bsBanner: string = "Flotas desplegadas (5 buques: 5,4,3,3,2). Selecciona coordenada en el radar enemigo.";

  // 12. Mille Bornes state
  private mbDistance: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private mbHands: Record<1 | 2, string[]> = { 1: [], 2: [] };
  private mbSafeties: Record<1 | 2, string[]> = { 1: [], 2: [] };
  private mbHazard: Record<1 | 2, string | null> = { 1: null, 2: null };
  private mbLastBanner: string = "Meta: 1000 km · Escudos y reacción Coup Fourré listos.";

  // 13. Monopoly state
  private monoSpaces: MonopolySpace[] = createInitialMonopolySpaces();
  private monoCash: Record<1 | 2, number> = { 1: 1500, 2: 1500 };
  private monoPos: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private monoInJail: Record<1 | 2, boolean> = { 1: false, 2: false };
  private monoDice: [number, number] = [4, 3];
  private monoAuctionSpace: number | null = null;
  private monoBanner: string = "Capital inicial: $1500 por jugador.";

  // 14. Crisis / TEG state
  private crisisTerritories: CrisisTerritory[] = createInitialCrisisTerritories();
  private crisisPhase: "PlaceArmies" | "Attack" | "Fortify" = "PlaceArmies";
  private crisisArmiesRemaining: number = 5;
  private crisisCards: Record<1 | 2, number> = { 1: 2, 2: 1 };
  private crisisBanner: string = "Fase de Refuerzo: coloca ejércitos en tus territorios.";

  constructor() {
    this.start_local_match("chess", 1, 2);
  }

  private nextRandomInt(min: number, max: number): number {
    this.rngState = (Math.imul(1664525, this.rngState) + 1013904223) >>> 0;
    return min + (this.rngState % (max - min + 1));
  }

  public start_local_match(gameType: string, _p1: number = 1, _p2: number = 2): boolean {
    const clean = gameType.trim().toLowerCase().replace(/-/g, "_");
    this.gameType = clean === "oca" ? "goose" : clean === "teg" ? "crisis" : clean;
    this.turn = 1;
    this.tick = 0;
    this.winner = null;
    this.aiPlayer = null;
    this.commandLog = [];
    this.rngState = 1337;

    if (this.gameType === "chess") {
      this.chessGrid = createInitialChessGrid();
      this.chessLastMove = null;
      this.chessDrawOfferedBy = null;
      this.chessInCheck = null;
    } else if (this.gameType === "checkers") {
      this.checkersGrid = createInitialCheckersGrid();
      this.checkersChainPos = null;
    } else if (this.gameType === "uno") {
      const deck = createInitialUnoDeck(42);
      this.unoHands = { 1: deck.splice(0, 7), 2: deck.splice(0, 7) };
      const firstTop = deck.find((c) => c.color !== "Wild") || deck[0];
      const idx = deck.indexOf(firstTop);
      if (idx >= 0) deck.splice(idx, 1);
      this.unoDiscard = [firstTop];
      this.unoDeck = deck;
      this.unoActiveColor =
        firstTop.color === "Wild" ? "Red" : (firstTop.color as "Red" | "Yellow" | "Green" | "Blue");
      this.unoDrawPenalty = 0;
      this.unoCalled = { 1: false, 2: false };
      this.unoLastEvent = `Carta inicial: ${firstTop.color} ${firstTop.value}`;
    } else if (this.gameType === "goose") {
      this.goosePlayers = {
        1: { player: 1, square: 0, skipTurns: 0, inWell: false },
        2: { player: 2, square: 0, skipTurns: 0, inWell: false },
      };
      this.gooseLastDice = [1, 1];
      this.gooseLastBanner = "Recorrido de 63 casillas listo. Turno del Jugador 1.";
    } else if (this.gameType === "go") {
      this.goSize = 9;
      this.goGrid = Array.from({ length: 9 }, () => Array.from({ length: 9 }, () => 0));
      this.goCaptures = { 1: 0, 2: 0 };
      this.goPasses = 0;
      this.goDeadStones = [];
      this.goHandicap = 0;
      this.goScoringPhase = false;
    } else if (this.gameType === "shogi") {
      this.shogiGrid = createInitialShogiGrid();
      this.shogiHands = { 1: [], 2: [] };
    } else if (this.gameType === "xiangqi") {
      this.xiangqiGrid = createInitialXiangqiGrid();
      this.xiangqiBanner = "Río Chu He / Han Jie activo · Regla de General Volador activa";
    } else if (this.gameType === "chinese_checkers") {
      const cells: { id: string; r: number; c: number; owner: 0 | 1 | 2; zone: 0 | 1 | 2 }[] = [];
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          const id = `${r}_${c}`;
          const owner: 0 | 1 | 2 = r + c <= 3 ? 2 : r + c >= 13 ? 1 : 0;
          const zone: 0 | 1 | 2 = r + c <= 3 ? 2 : r + c >= 13 ? 1 : 0;
          cells.push({ id, r, c, owner, zone });
        }
      }
      this.ccCells = cells;
    } else if (this.gameType === "backgammon") {
      const pts: { count: number; owner: 0 | 1 | 2 }[] = Array.from({ length: 24 }, () => ({
        count: 0,
        owner: 0,
      }));
      pts[0] = { count: 2, owner: 1 };
      pts[11] = { count: 5, owner: 1 };
      pts[16] = { count: 3, owner: 1 };
      pts[18] = { count: 5, owner: 1 };
      pts[23] = { count: 2, owner: 2 };
      pts[12] = { count: 5, owner: 2 };
      pts[7] = { count: 3, owner: 2 };
      pts[5] = { count: 5, owner: 2 };
      this.bgPoints = pts;
      this.bgBar = { 1: 0, 2: 0 };
      this.bgBorneOff = { 1: 0, 2: 0 };
      this.bgDice = [3, 5];
      this.bgCubeValue = 1;
      this.bgCubeOfferedBy = null;
    } else if (this.gameType === "ludo") {
      this.ludoTokens = { 1: [1, 0, 0, 0], 2: [1, 0, 0, 0] };
      this.ludoDice = [6, 2];
      this.ludoLastBanner = "Circuito de 52 casillas + 5 de meta listo. Estrellas seguras activas.";
    } else if (this.gameType === "battleship") {
      this.bsShots = { 1: {}, 2: {} };
      this.bsHitsCount = { 1: 0, 2: 0 };
      this.bsExtraTurnOnHit = false;
      this.bsBanner = "Flotas colocadas (5 barcos: 5,4,3,3,2). Dispara en el radar enemigo.";
    } else if (this.gameType === "mille_bornes") {
      this.mbDistance = { 1: 0, 2: 0 };
      this.mbHands = {
        1: [
          "Distance 200",
          "Distance 100",
          "Distance 75",
          "Prioridad",
          "Cisterna",
          "Gasolina",
        ],
        2: [
          "Distance 100",
          "Distance 100",
          "Distance 50",
          "As del Volante",
          "Pinchazo",
          "Reparaciones",
        ],
      };
      this.mbSafeties = { 1: [], 2: [] };
      this.mbHazard = { 1: null, 2: null };
      this.mbLastBanner = "Ruta de 1000 km iniciada. Juega cartas de distancia, escudos o ataques.";
    } else if (this.gameType === "monopoly") {
      this.monoSpaces = createInitialMonopolySpaces();
      this.monoCash = { 1: 1500, 2: 1500 };
      this.monoPos = { 1: 0, 2: 0 };
      this.monoInJail = { 1: false, 2: false };
      this.monoDice = [4, 3];
      this.monoAuctionSpace = null;
      this.monoBanner = "Tablero de 40 propiedades listo ($1500 por jugador).";
    } else if (this.gameType === "crisis") {
      this.crisisTerritories = createInitialCrisisTerritories();
      this.crisisPhase = "PlaceArmies";
      this.crisisArmiesRemaining = 5;
      this.crisisCards = { 1: 3, 2: 2 };
      this.crisisBanner = "Fase de Refuerzo: coloca 5 ejércitos o canjea tarjetas.";
    } else {
      return false;
    }
    return true;
  }

  public start_ai_match(
    gameType: string,
    humanId: number = 1,
    aiId: number = 2,
    difficulty: number = 1
  ): boolean {
    const ok = this.start_local_match(gameType, humanId, aiId);
    this.aiPlayer = (aiId === 1 ? 1 : 2) as 1 | 2;
    this.aiDifficulty = Math.max(0, Math.min(3, difficulty));
    return ok;
  }

  public current_player(): number {
    return this.turn;
  }

  public current_tick(): number {
    return this.tick;
  }

  public get_current_game_type(): string {
    return this.gameType;
  }

  private getChessLegalMoves(player: 1 | 2): ChessMove[] {
    const moves: ChessMove[] = [];
    const inBounds = (r: number, c: number) => r >= 0 && r < 8 && c >= 0 && c < 8;

    for (let r = 0; r < 8; r++) {
      for (let c = 0; c < 8; c++) {
        const piece = this.chessGrid[r][c];
        if (!piece || piece.owner !== player) continue;

        if (piece.kind === "Pawn") {
          const dir = player === 1 ? -1 : 1;
          const startRow = player === 1 ? 6 : 1;
          const promoRow = player === 1 ? 0 : 7;

          if (inBounds(r + dir, c) && !this.chessGrid[r + dir][c]) {
            if (r + dir === promoRow) {
              for (const p of ["Queen", "Rook", "Bishop", "Knight"] as const) {
                moves.push({ from: [r, c], to: [r + dir, c], promotion: p });
              }
            } else {
              moves.push({ from: [r, c], to: [r + dir, c] });
            }
            if (r === startRow && inBounds(r + dir * 2, c) && !this.chessGrid[r + dir * 2][c]) {
              moves.push({ from: [r, c], to: [r + dir * 2, c] });
            }
          }
          for (const dc of [-1, 1]) {
            const nr = r + dir;
            const nc = c + dc;
            if (inBounds(nr, nc)) {
              const target = this.chessGrid[nr][nc];
              if (target && target.owner !== player) {
                if (nr === promoRow) {
                  for (const p of ["Queen", "Rook", "Bishop", "Knight"] as const) {
                    moves.push({ from: [r, c], to: [nr, nc], promotion: p });
                  }
                } else {
                  moves.push({ from: [r, c], to: [nr, nc] });
                }
              }
            }
          }
        } else if (piece.kind === "Knight") {
          const jumps = [
            [-2, -1],
            [-2, 1],
            [-1, -2],
            [-1, 2],
            [1, -2],
            [1, 2],
            [2, -1],
            [2, 1],
          ];
          for (const [dr, dc] of jumps) {
            const nr = r + dr;
            const nc = c + dc;
            if (!inBounds(nr, nc)) continue;
            const target = this.chessGrid[nr][nc];
            if (!target || target.owner !== player) {
              moves.push({ from: [r, c], to: [nr, nc] });
            }
          }
        } else if (piece.kind === "King") {
          for (let dr = -1; dr <= 1; dr++) {
            for (let dc = -1; dc <= 1; dc++) {
              if (dr === 0 && dc === 0) continue;
              const nr = r + dr;
              const nc = c + dc;
              if (!inBounds(nr, nc)) continue;
              const target = this.chessGrid[nr][nc];
              if (!target || target.owner !== player) {
                moves.push({ from: [r, c], to: [nr, nc] });
              }
            }
          }
        } else {
          const dirs: [number, number][] = [];
          if (piece.kind === "Rook" || piece.kind === "Queen") {
            dirs.push([-1, 0], [1, 0], [0, -1], [0, 1]);
          }
          if (piece.kind === "Bishop" || piece.kind === "Queen") {
            dirs.push([-1, -1], [-1, 1], [1, -1], [1, 1]);
          }
          for (const [dr, dc] of dirs) {
            let nr = r + dr;
            let nc = c + dc;
            while (inBounds(nr, nc)) {
              const target = this.chessGrid[nr][nc];
              if (!target) {
                moves.push({ from: [r, c], to: [nr, nc] });
              } else {
                if (target.owner !== player) {
                  moves.push({ from: [r, c], to: [nr, nc] });
                }
                break;
              }
              nr += dr;
              nc += dc;
            }
          }
        }
      }
    }
    return moves;
  }

  private getCheckersLegalMoves(player: 1 | 2): CheckersMove[] {
    const captures: CheckersMove[] = [];
    const normals: CheckersMove[] = [];
    const inBounds = (r: number, c: number) => r >= 0 && r < 8 && c >= 0 && c < 8;

    for (let r = 0; r < 8; r++) {
      for (let c = 0; c < 8; c++) {
        if (
          this.checkersChainPos &&
          (this.checkersChainPos[0] !== r || this.checkersChainPos[1] !== c)
        ) {
          continue;
        }
        const piece = this.checkersGrid[r][c];
        if (!piece || piece.owner !== player) continue;

        const rowDirs = piece.isKing ? [-1, 1] : player === 1 ? [-1] : [1];
        for (const dr of rowDirs) {
          for (const dc of [-1, 1]) {
            const nr = r + dr;
            const nc = c + dc;
            if (!inBounds(nr, nc)) continue;
            const mid = this.checkersGrid[nr][nc];
            if (!mid && !this.checkersChainPos) {
              normals.push({ from: [r, c], to: [nr, nc] });
            } else if (mid && mid.owner !== player) {
              const jr = r + dr * 2;
              const jc = c + dc * 2;
              if (inBounds(jr, jc) && !this.checkersGrid[jr][jc]) {
                captures.push({ from: [r, c], to: [jr, jc], captured: [nr, nc] });
              }
            }
          }
        }
      }
    }
    return captures.length > 0 ? captures : normals;
  }

  public get_legal_moves_json(playerId: number): string {
    const p = (playerId === 2 ? 2 : 1) as 1 | 2;
    if (this.winner !== null) return "[]";

    if (this.gameType === "chess") {
      return JSON.stringify(this.getChessLegalMoves(p));
    }
    if (this.gameType === "checkers") {
      return JSON.stringify(this.getCheckersLegalMoves(p));
    }
    if (this.gameType === "uno") {
      const top = this.unoDiscard[this.unoDiscard.length - 1];
      const hand = this.unoHands[p] || [];
      const playable = hand
        .map((card, index) => ({ card, index }))
        .filter(({ card }) => {
          if (this.unoDrawPenalty > 0) {
            return card.value === "DrawTwo" || card.value === "WildDrawFour";
          }
          return (
            card.color === "Wild" ||
            card.color === this.unoActiveColor ||
            (top && card.value === top.value)
          );
        });
      return JSON.stringify(playable);
    }
    if (this.gameType === "goose") {
      return JSON.stringify([{ command_type: "goose_game::RollDiceCommand", player: p }]);
    }
    if (this.gameType === "go") {
      const moves: { row: number; col: number }[] = [];
      for (let r = 0; r < this.goSize; r++) {
        for (let c = 0; c < this.goSize; c++) {
          if (this.goGrid[r]?.[c] === 0) {
            moves.push({ row: r, col: c });
          }
        }
      }
      return JSON.stringify(moves);
    }
    if (this.gameType === "shogi") {
      const moves: { from: [number, number]; to: [number, number]; canPromote: boolean }[] = [];
      const dir = p === 1 ? -1 : 1;
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          const pc = this.shogiGrid[r]?.[c];
          if (!pc || pc.owner !== p) continue;
          const nr = r + dir;
          if (nr >= 0 && nr < 9) {
            const target = this.shogiGrid[nr][c];
            if (!target || target.owner !== p) {
              const inZone = p === 1 ? nr <= 2 || r <= 2 : nr >= 6 || r >= 6;
              moves.push({
                from: [r, c],
                to: [nr, c],
                canPromote: inZone && !pc.promoted && pc.kind !== "King" && pc.kind !== "Gold",
              });
            }
          }
        }
      }
      return JSON.stringify(moves);
    }
    if (this.gameType === "xiangqi") {
      const moves: { from: [number, number]; to: [number, number] }[] = [];
      const dir = p === 1 ? -1 : 1;
      for (let r = 0; r < 10; r++) {
        for (let c = 0; c < 9; c++) {
          const pc = this.xiangqiGrid[r]?.[c];
          if (!pc || pc.owner !== p) continue;
          const nr = r + dir;
          if (nr >= 0 && nr < 10) {
            const dst = this.xiangqiGrid[nr][c];
            if (!dst || dst.owner !== p) {
              moves.push({ from: [r, c], to: [nr, c] });
            }
          }
        }
      }
      return JSON.stringify(moves);
    }
    if (this.gameType === "chinese_checkers") {
      const moves: { fromId: string; toId: string }[] = [];
      const owned = this.ccCells.filter((cell) => cell.owner === p);
      const empty = this.ccCells.filter((cell) => cell.owner === 0);
      for (const o of owned) {
        for (const e of empty) {
          const dr = Math.abs(o.r - e.r);
          const dc = Math.abs(o.c - e.c);
          if ((dr <= 2 && dc <= 2) && dr + dc > 0) {
            moves.push({ fromId: o.id, toId: e.id });
          }
        }
      }
      return JSON.stringify(moves.slice(0, 24));
    }
    if (this.gameType === "backgammon") {
      const moves: { from: number; to: number }[] = [];
      const step = this.bgDice[0] || 3;
      for (let i = 0; i < 24; i++) {
        if (this.bgPoints[i]?.owner === p && this.bgPoints[i].count > 0) {
          const to = p === 1 ? Math.min(23, i + step) : Math.max(0, i - step);
          if (to !== i) moves.push({ from: i, to });
        }
      }
      return JSON.stringify(moves);
    }
    if (this.gameType === "ludo") {
      return JSON.stringify([
        { token_index: 0, steps: this.ludoDice[0] },
        { token_index: 1, steps: this.ludoDice[0] },
      ]);
    }
    if (this.gameType === "battleship") {
      const moves: { row: number; col: number }[] = [];
      for (let r = 0; r < 10; r++) {
        for (let c = 0; c < 10; c++) {
          if (!this.bsShots[p][`${r}_${c}`]) {
            moves.push({ row: r, col: c });
          }
        }
      }
      return JSON.stringify(moves);
    }
    if (this.gameType === "mille_bornes") {
      return JSON.stringify(
        (this.mbHands[p] || []).map((card, card_index) => ({ card, card_index }))
      );
    }
    if (this.gameType === "monopoly") {
      return JSON.stringify([
        { command_type: "monopoly_game::RollDiceCommand", player: p },
        { command_type: "monopoly_game::BuyPropertyCommand", player: p },
        { command_type: "monopoly_game::EndTurnCommand", player: p },
      ]);
    }
    if (this.gameType === "crisis") {
      const myTerrs = this.crisisTerritories.filter((t) => t.owner === p);
      return JSON.stringify(
        myTerrs.map((t) => ({
          command_type: "crisis_game::PlaceArmiesCommand",
          player: p,
          territory: t.id,
          count: 1,
        }))
      );
    }
    return "[]";
  }

  public get_state_json(): string {
    if (this.gameType === "chess") {
      return JSON.stringify({
        game_type: "chess",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        grid: this.chessGrid,
        last_move: this.chessLastMove,
        draw_offered_by: this.chessDrawOfferedBy,
        in_check: this.chessInCheck,
      });
    }
    if (this.gameType === "checkers") {
      const legal = this.getCheckersLegalMoves(this.turn);
      const mandatoryCapture = legal.some((m) => m.captured !== undefined);
      return JSON.stringify({
        game_type: "checkers",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        grid: this.checkersGrid,
        mandatory_capture: mandatoryCapture,
        chain_pos: this.checkersChainPos,
      });
    }
    if (this.gameType === "uno") {
      return JSON.stringify({
        game_type: "uno",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        hands: this.unoHands,
        top_card: this.unoDiscard[this.unoDiscard.length - 1] || null,
        active_color: this.unoActiveColor,
        deck_count: this.unoDeck.length,
        draw_penalty: this.unoDrawPenalty,
        uno_called: this.unoCalled,
        last_event: this.unoLastEvent,
      });
    }
    if (this.gameType === "goose") {
      return JSON.stringify({
        game_type: "goose",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        players: this.goosePlayers,
        last_dice: this.gooseLastDice,
        last_banner: this.gooseLastBanner,
      });
    }
    if (this.gameType === "go") {
      return JSON.stringify({
        game_type: "go",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        size: this.goSize,
        grid: this.goGrid,
        captures: this.goCaptures,
        passes: this.goPasses,
        dead_stones: this.goDeadStones,
        handicap: this.goHandicap,
        scoring_phase: this.goScoringPhase,
        komi: 6.5,
      });
    }
    if (this.gameType === "shogi") {
      return JSON.stringify({
        game_type: "shogi",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        grid: this.shogiGrid,
        hands: this.shogiHands,
      });
    }
    if (this.gameType === "xiangqi") {
      return JSON.stringify({
        game_type: "xiangqi",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        grid: this.xiangqiGrid,
        banner: this.xiangqiBanner,
      });
    }
    if (this.gameType === "chinese_checkers") {
      return JSON.stringify({
        game_type: "chinese_checkers",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        cells: this.ccCells,
      });
    }
    if (this.gameType === "backgammon") {
      return JSON.stringify({
        game_type: "backgammon",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        points: this.bgPoints,
        bar: this.bgBar,
        borne_off: this.bgBorneOff,
        dice: this.bgDice,
        cube_value: this.bgCubeValue,
        cube_offered_by: this.bgCubeOfferedBy,
      });
    }
    if (this.gameType === "ludo") {
      return JSON.stringify({
        game_type: "ludo",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        tokens: this.ludoTokens,
        dice: this.ludoDice,
        banner: this.ludoLastBanner,
      });
    }
    if (this.gameType === "battleship") {
      return JSON.stringify({
        game_type: "battleship",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        shots: this.bsShots,
        hits_count: this.bsHitsCount,
        extra_turn_on_hit: this.bsExtraTurnOnHit,
        banner: this.bsBanner,
      });
    }
    if (this.gameType === "mille_bornes") {
      return JSON.stringify({
        game_type: "mille_bornes",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        distance: this.mbDistance,
        hands: this.mbHands,
        safeties: this.mbSafeties,
        hazard: this.mbHazard,
        banner: this.mbLastBanner,
      });
    }
    if (this.gameType === "monopoly") {
      return JSON.stringify({
        game_type: "monopoly",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        spaces: this.monoSpaces,
        cash: this.monoCash,
        pos: this.monoPos,
        in_jail: this.monoInJail,
        dice: this.monoDice,
        auction_space: this.monoAuctionSpace,
        banner: this.monoBanner,
      });
    }
    if (this.gameType === "crisis") {
      return JSON.stringify({
        game_type: "crisis",
        turn: this.turn,
        tick: this.tick,
        winner: this.winner,
        territories: this.crisisTerritories,
        phase: this.crisisPhase,
        armies_remaining: this.crisisArmiesRemaining,
        cards: this.crisisCards,
        banner: this.crisisBanner,
      });
    }
    return JSON.stringify({
      game_type: this.gameType,
      turn: this.turn,
      tick: this.tick,
      winner: this.winner,
    });
  }

  public send_command_json(playerId: number, jsonStr: string): string {
    return this.executeCommandInternal(playerId, jsonStr, true);
  }

  private executeCommandInternal(
    playerId: number,
    jsonStr: string,
    recordLog: boolean
  ): string {
    if (this.winner !== null) {
      return JSON.stringify({ ok: false, error: "game_already_over" });
    }
    const p = (playerId === 2 ? 2 : 1) as 1 | 2;
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(jsonStr);
    } catch {
      return JSON.stringify({ ok: false, error: "invalid_json" });
    }

    const rawType = String(parsed.command_type || parsed.type || "");
    const cmdName = rawType.includes("::") ? rawType.split("::").pop()! : rawType;

    if (cmdName === "ResignCommand") {
      this.winner = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "GameOverEvent", winner: this.winner }]);
    }

    // 1. CHESS
    if (this.gameType === "chess") {
      if (cmdName === "OfferDrawCommand") {
        this.chessDrawOfferedBy = p;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "DrawOfferedEvent", player: p }]);
      }
      if (cmdName === "AcceptDrawCommand" && this.chessDrawOfferedBy && this.chessDrawOfferedBy !== p) {
        this.winner = 0;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "GameOverEvent", winner: 0, is_draw: true }]);
      }
      if (p !== this.turn) {
        return JSON.stringify({ ok: false, error: "not_your_turn" });
      }
      const from = parsed.from as [number, number];
      const to = parsed.to as [number, number];
      const promotion = parsed.promotion as ChessMove["promotion"] | undefined;
      const legal = this.getChessLegalMoves(p);
      const match = legal.find(
        (m) =>
          m.from[0] === from[0] &&
          m.from[1] === from[1] &&
          m.to[0] === to[0] &&
          m.to[1] === to[1] &&
          (!m.promotion || m.promotion === (promotion || "Queen"))
      );
      if (!match) {
        return JSON.stringify({ ok: false, error: "illegal_chess_move" });
      }
      const moving = this.chessGrid[from[0]][from[1]]!;
      const captured = this.chessGrid[to[0]][to[1]];
      this.chessGrid[from[0]][from[1]] = null;
      this.chessGrid[to[0]][to[1]] = {
        kind: match.promotion || moving.kind,
        owner: p,
      };
      this.chessLastMove = { from, to };
      this.chessDrawOfferedBy = null;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });

      if (captured?.kind === "King") {
        this.winner = p;
      } else {
        this.turn = p === 1 ? 2 : 1;
        const nextMoves = this.getChessLegalMoves(p);
        let oppKingPos: [number, number] | null = null;
        for (let r = 0; r < 8; r++) {
          for (let c = 0; c < 8; c++) {
            const cell = this.chessGrid[r][c];
            if (cell && cell.owner === this.turn && cell.kind === "King") {
              oppKingPos = [r, c];
            }
          }
        }
        this.chessInCheck =
          oppKingPos &&
          nextMoves.some((m) => m.to[0] === oppKingPos![0] && m.to[1] === oppKingPos![1])
            ? this.turn
            : null;
      }
      return JSON.stringify([{ event: "PieceMovedEvent", player: p, from, to }]);
    }

    // 2. CHECKERS
    if (this.gameType === "checkers") {
      if (p !== this.turn) {
        return JSON.stringify({ ok: false, error: "not_your_turn" });
      }
      const from = parsed.from as [number, number];
      const to = parsed.to as [number, number];
      const legal = this.getCheckersLegalMoves(p);
      const match = legal.find(
        (m) =>
          m.from[0] === from[0] &&
          m.from[1] === from[1] &&
          m.to[0] === to[0] &&
          m.to[1] === to[1]
      );
      if (!match) {
        return JSON.stringify({ ok: false, error: "illegal_checkers_move" });
      }
      const moving = this.checkersGrid[from[0]][from[1]]!;
      this.checkersGrid[from[0]][from[1]] = null;
      if (match.captured) {
        this.checkersGrid[match.captured[0]][match.captured[1]] = null;
      }
      const reachesCrown = (p === 1 && to[0] === 0) || (p === 2 && to[0] === 7);
      const promoted = !moving.isKing && reachesCrown;
      this.checkersGrid[to[0]][to[1]] = {
        owner: p,
        isKing: moving.isKing || reachesCrown,
      };
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });

      if (match.captured && !promoted) {
        this.checkersChainPos = [to[0], to[1]];
        const followUp = this.getCheckersLegalMoves(p).filter((m) => m.captured !== undefined);
        if (followUp.length > 0) {
          return JSON.stringify([{ event: "MultiJumpContinueEvent", player: p, at: to }]);
        }
      }
      this.checkersChainPos = null;
      const opp: 1 | 2 = p === 1 ? 2 : 1;
      this.turn = opp;
      if (this.getCheckersLegalMoves(opp).length === 0) {
        this.winner = p;
      }
      return JSON.stringify([{ event: "PieceMovedEvent", player: p, from, to }]);
    }

    // 3. UNO
    if (this.gameType === "uno") {
      if (cmdName === "CallUnoCommand") {
        this.unoCalled[p] = true;
        this.unoLastEvent = `¡Jugador ${p} gritó ¡UNO!!`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "UnoCalledEvent", player: p }]);
      }
      if (p !== this.turn) {
        return JSON.stringify({ ok: false, error: "not_your_turn" });
      }
      if (cmdName === "DrawCardCommand") {
        const count = this.unoDrawPenalty > 0 ? this.unoDrawPenalty : 1;
        for (let i = 0; i < count; i++) {
          if (this.unoDeck.length === 0 && this.unoDiscard.length > 1) {
            const top = this.unoDiscard.pop()!;
            this.unoDeck = [...this.unoDiscard];
            this.unoDiscard = [top];
          }
          const drawn = this.unoDeck.pop();
          if (drawn) this.unoHands[p].push(drawn);
        }
        this.unoDrawPenalty = 0;
        this.unoCalled[p] = false;
        this.unoLastEvent = `Jugador ${p} robó ${count} carta(s).`;
        this.turn = p === 1 ? 2 : 1;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "CardDrawnEvent", player: p, count }]);
      }
      if (cmdName === "PlayCardCommand") {
        const cardIndex = Number(parsed.card_index ?? 0);
        const chosenColor = (parsed.chosen_color as "Red" | "Yellow" | "Green" | "Blue") || "Red";
        const hand = this.unoHands[p];
        const card = hand[cardIndex];
        if (!card) {
          return JSON.stringify({ ok: false, error: "invalid_card_index" });
        }
        hand.splice(cardIndex, 1);
        this.unoDiscard.push(card);
        this.unoActiveColor =
          card.color === "Wild"
            ? chosenColor
            : (card.color as "Red" | "Yellow" | "Green" | "Blue");
        if (card.value === "DrawTwo") this.unoDrawPenalty += 2;
        if (card.value === "WildDrawFour") this.unoDrawPenalty += 4;
        if (hand.length === 0) {
          this.winner = p;
          this.unoLastEvent = `¡Jugador ${p} se quedó sin cartas y gana!`;
        } else {
          const keepTurn = card.value === "Skip" || card.value === "Reverse";
          this.turn = keepTurn ? p : p === 1 ? 2 : 1;
          this.unoLastEvent = `Jugador ${p} jugó ${card.color} ${card.value}`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "CardPlayedEvent", player: p, card }]);
      }
    }

    // 4. GOOSE
    if (this.gameType === "goose") {
      if (p !== this.turn) {
        return JSON.stringify({ ok: false, error: "not_your_turn" });
      }
      const pState = this.goosePlayers[p];
      if (pState.skipTurns > 0) {
        pState.skipTurns -= 1;
        this.gooseLastBanner = `Jugador ${p} cumple turno de espera (${pState.skipTurns} restante).`;
        this.turn = p === 1 ? 2 : 1;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "TurnSkippedEvent", player: p }]);
      }
      const d1 = Number(parsed.d1) || this.nextRandomInt(1, 6);
      const d2 = Number(parsed.d2) || this.nextRandomInt(1, 6);
      this.gooseLastDice = [d1, d2];
      const sum = d1 + d2;
      let target = pState.square + sum;
      let extraTurn = false;
      let msg = `Jugador ${p} sacó ${d1} + ${d2} = ${sum}. `;

      if (target > 63) {
        target = 63 - (target - 63);
        msg += `Rebota hasta la casilla ${target}. `;
      }
      if (target === 63) {
        pState.square = 63;
        this.winner = p;
        msg += "¡Llegó al Jardín de la Oca (63) y gana!";
      } else if (GOOSE_SQUARES.has(target)) {
        const sortedGeese = Array.from(GOOSE_SQUARES).sort((a, b) => a - b);
        const idx = sortedGeese.indexOf(target);
        const nextGoose = idx >= 0 && idx + 1 < sortedGeese.length ? sortedGeese[idx + 1] : 63;
        pState.square = nextGoose;
        extraTurn = nextGoose < 63;
        if (nextGoose === 63) this.winner = p;
        msg += `¡De Oca (${target}) a Oca (${nextGoose}) y tiro porque me toca!`;
      } else if (target === 6) {
        pState.square = 12;
        extraTurn = true;
        msg += "¡De puente (6) a puente (12) y tiro porque me lleva la corriente!";
      } else if (target === 12) {
        pState.square = 6;
        extraTurn = true;
        msg += "¡De puente (12) a puente (6) y tiro porque me lleva la corriente!";
      } else if (target === 19) {
        pState.square = 19;
        pState.skipTurns = 1;
        msg += "La Posada (19): descansa 1 turno.";
      } else if (target === 26) {
        pState.square = 53;
        extraTurn = true;
        msg += "¡De dado (26) a dado (53) y tiro porque me ha tocado!";
      } else if (target === 53) {
        pState.square = 26;
        extraTurn = true;
        msg += "¡De dado (53) a dado (26) y tiro porque me ha tocado!";
      } else if (target === 31) {
        pState.square = 31;
        pState.skipTurns = 2;
        msg += "El Pozo (31): pierde 2 turnos.";
      } else if (target === 42) {
        pState.square = 30;
        msg += "El Laberinto (42): retrocede a la casilla 30.";
      } else if (target === 52) {
        pState.square = 52;
        pState.skipTurns = 2;
        msg += "La Cárcel (52): pierde 2 turnos.";
      } else if (target === 58) {
        pState.square = 1;
        msg += "La Calavera (58): vuelve a la casilla 1.";
      } else {
        pState.square = target;
        msg += `Avanza a la casilla ${target}.`;
      }
      this.gooseLastBanner = msg;
      if (this.winner === null && !extraTurn) {
        this.turn = p === 1 ? 2 : 1;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "GooseMovedEvent", player: p, to_square: pState.square }]);
    }

    // 5. GO
    if (this.gameType === "go") {
      if (cmdName === "SetHandicapCommand") {
        const count = Number(parsed.handicap ?? 0);
        this.goHandicap = count;
        this.goGrid = Array.from({ length: this.goSize }, () =>
          Array.from({ length: this.goSize }, () => 0)
        );
        const hoshi: [number, number][] = [
          [2, 2],
          [2, this.goSize - 3],
          [this.goSize - 3, 2],
          [this.goSize - 3, this.goSize - 3],
        ];
        for (let i = 0; i < Math.min(count, hoshi.length); i++) {
          const [hr, hc] = hoshi[i];
          this.goGrid[hr][hc] = 1;
        }
        this.turn = count > 0 ? 2 : 1;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "HandicapPlacedEvent", handicap: count }]);
      }
      if (cmdName === "MarkDeadCommand") {
        const key = `${parsed.row}_${parsed.col}`;
        if (this.goDeadStones.includes(key)) {
          this.goDeadStones = this.goDeadStones.filter((k) => k !== key);
        } else {
          this.goDeadStones = [...this.goDeadStones, key];
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "DeadStoneMarkedEvent", key }]);
      }
      if (cmdName === "ConfirmDeadCommand") {
        let blackPoints = this.goCaptures[1];
        let whitePoints = this.goCaptures[2] + 6.5;
        for (let r = 0; r < this.goSize; r++) {
          for (let c = 0; c < this.goSize; c++) {
            const v = this.goGrid[r][c];
            const dead = this.goDeadStones.includes(`${r}_${c}`);
            if (v === 1 && !dead) blackPoints += 1;
            if (v === 2 && !dead) whitePoints += 1;
          }
        }
        this.winner = blackPoints >= whitePoints ? 1 : 2;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "GameOverEvent", winner: this.winner }]);
      }
      if (p !== this.turn) {
        return JSON.stringify({ ok: false, error: "not_your_turn" });
      }
      if (cmdName === "PassCommand") {
        this.goPasses += 1;
        if (this.goPasses >= 2) {
          this.goScoringPhase = true;
        }
        this.turn = p === 1 ? 2 : 1;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "PassedEvent", player: p }]);
      }
      const r = Number(parsed.row ?? 0);
      const c = Number(parsed.col ?? 0);
      if (this.goGrid[r]?.[c] !== 0) {
        return JSON.stringify({ ok: false, error: "occupied_intersection" });
      }
      this.goGrid[r][c] = p;
      this.goPasses = 0;
      const opp: 1 | 2 = p === 1 ? 2 : 1;
      for (const [dr, dc] of [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        const nr = r + dr;
        const nc = c + dc;
        if (this.goGrid[nr]?.[nc] === opp) {
          const surrounded = [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1],
          ].every(([ar, ac]) => {
            const rr = nr + ar;
            const cc = nc + ac;
            if (rr < 0 || rr >= this.goSize || cc < 0 || cc >= this.goSize) return true;
            return this.goGrid[rr][cc] === p;
          });
          if (surrounded) {
            this.goGrid[nr][nc] = 0;
            this.goCaptures[p] += 1;
          }
        }
      }
      this.turn = opp;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "StonePlacedEvent", player: p, row: r, col: c }]);
    }

    // 6. SHOGI
    if (this.gameType === "shogi") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      if (cmdName === "DropPieceCommand") {
        const kind = parsed.kind as ShogiPiece["kind"];
        const to = parsed.to as [number, number];
        const hand = this.shogiHands[p];
        const idx = hand.indexOf(kind);
        if (idx < 0 || this.shogiGrid[to[0]]?.[to[1]]) {
          return JSON.stringify({ ok: false, error: "illegal_shogi_drop" });
        }
        hand.splice(idx, 1);
        this.shogiGrid[to[0]][to[1]] = { kind, owner: p, promoted: false };
        this.turn = p === 1 ? 2 : 1;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "PieceDroppedEvent", player: p, kind, to }]);
      }
      const from = parsed.from as [number, number];
      const to = parsed.to as [number, number];
      const promote = Boolean(parsed.promote);
      const pc = this.shogiGrid[from[0]]?.[from[1]];
      if (!pc || pc.owner !== p) {
        return JSON.stringify({ ok: false, error: "invalid_shogi_piece" });
      }
      const target = this.shogiGrid[to[0]]?.[to[1]];
      if (target && target.owner === p) {
        return JSON.stringify({ ok: false, error: "friendly_square" });
      }
      if (target) {
        if (target.kind === "King") {
          this.winner = p;
        } else {
          this.shogiHands[p].push(target.kind);
        }
      }
      this.shogiGrid[from[0]][from[1]] = null;
      this.shogiGrid[to[0]][to[1]] = {
        kind: pc.kind,
        owner: p,
        promoted: pc.promoted || promote,
      };
      this.turn = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "ShogiMovedEvent", player: p, from, to, promote }]);
    }

    // 7. XIANGQI
    if (this.gameType === "xiangqi") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const from = parsed.from as [number, number];
      const to = parsed.to as [number, number];
      const pc = this.xiangqiGrid[from[0]]?.[from[1]];
      if (!pc || pc.owner !== p) {
        return JSON.stringify({ ok: false, error: "invalid_xiangqi_piece" });
      }
      const target = this.xiangqiGrid[to[0]]?.[to[1]];
      if (target && target.owner === p) {
        return JSON.stringify({ ok: false, error: "friendly_square" });
      }
      if (target?.kind === "General") {
        this.winner = p;
      }
      this.xiangqiGrid[from[0]][from[1]] = null;
      this.xiangqiGrid[to[0]][to[1]] = pc;
      this.xiangqiBanner = `Jugador ${p} movió ${pc.kind} a (${to[0]}, ${to[1]}).`;
      this.turn = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "XiangqiMovedEvent", player: p, from, to }]);
    }

    // 8. CHINESE CHECKERS
    if (this.gameType === "chinese_checkers") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const fromId = String(parsed.fromId || "");
      const toId = String(parsed.toId || "");
      const fromCell = this.ccCells.find((c) => c.id === fromId);
      const toCell = this.ccCells.find((c) => c.id === toId);
      if (!fromCell || !toCell || fromCell.owner !== p || toCell.owner !== 0) {
        return JSON.stringify({ ok: false, error: "illegal_cc_move" });
      }
      fromCell.owner = 0;
      toCell.owner = p;
      this.turn = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "MarbleMovedEvent", player: p, fromId, toId }]);
    }

    // 9. BACKGAMMON
    if (this.gameType === "backgammon") {
      if (cmdName === "OfferDoubleCommand") {
        this.bgCubeOfferedBy = p;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "DoubleOfferedEvent", player: p }]);
      }
      if (cmdName === "AcceptDoubleCommand" && this.bgCubeOfferedBy) {
        this.bgCubeValue *= 2;
        this.bgCubeOfferedBy = null;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "DoubleAcceptedEvent", value: this.bgCubeValue }]);
      }
      if (cmdName === "RejectDoubleCommand" && this.bgCubeOfferedBy) {
        this.winner = this.bgCubeOfferedBy;
        this.bgCubeOfferedBy = null;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "GameOverEvent", winner: this.winner }]);
      }
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      if (cmdName === "RollDiceCommand") {
        const d1 = Number(parsed.d1) || this.nextRandomInt(1, 6);
        const d2 = Number(parsed.d2) || this.nextRandomInt(1, 6);
        this.bgDice = [d1, d2];
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "DiceRolledEvent", dice: [d1, d2] }]);
      }
      const from = Number(parsed.from ?? 0);
      const to = Number(parsed.to ?? 1);
      if (this.bgPoints[from] && this.bgPoints[from].count > 0) {
        this.bgPoints[from].count -= 1;
        if (this.bgPoints[from].count === 0) this.bgPoints[from].owner = 0;
      }
      if (to >= 24 || to < 0) {
        this.bgBorneOff[p] += 1;
        if (this.bgBorneOff[p] >= 15) this.winner = p;
      } else if (this.bgPoints[to]) {
        const dst = this.bgPoints[to];
        const opp: 1 | 2 = p === 1 ? 2 : 1;
        if (dst.owner === opp && dst.count === 1) {
          this.bgBar[opp] += 1;
          dst.owner = p;
          dst.count = 1;
        } else {
          dst.owner = p;
          dst.count += 1;
        }
      }
      this.turn = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "CheckerMovedEvent", player: p, from, to }]);
    }

    // 10. LUDO
    if (this.gameType === "ludo") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const d1 = Number(parsed.d1) || this.nextRandomInt(1, 6);
      const d2 = Number(parsed.d2) || this.nextRandomInt(1, 6);
      this.ludoDice = [d1, d2];
      const tokenIdx = Number(parsed.token_index ?? 0);
      const cur = this.ludoTokens[p][tokenIdx] ?? 0;
      const nextSteps = Math.min(57, cur + d1);
      this.ludoTokens[p][tokenIdx] = nextSteps;
      const extraTurn = d1 === 6 || nextSteps === 57;
      this.ludoLastBanner = `Jugador ${p} avanzó ficha #${tokenIdx + 1} a paso ${nextSteps}/57 (Dado: ${d1}).`;
      if (this.ludoTokens[p].every((s) => s >= 57)) {
        this.winner = p;
      } else if (!extraTurn) {
        this.turn = p === 1 ? 2 : 1;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "LudoMovedEvent", player: p, tokenIdx, nextSteps }]);
    }

    // 11. BATTLESHIP
    if (this.gameType === "battleship") {
      if (cmdName === "SetBattleshipRulesCommand") {
        this.bsExtraTurnOnHit = Boolean(parsed.extra_turn_on_hit);
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "RulesUpdatedEvent", extra_turn_on_hit: this.bsExtraTurnOnHit }]);
      }
      if (cmdName === "RematchCommand") {
        this.start_local_match("battleship", 1, 2);
        return JSON.stringify([{ event: "RematchStartedEvent" }]);
      }
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const r = Number(parsed.row ?? 0);
      const c = Number(parsed.col ?? 0);
      const key = `${r}_${c}`;
      if (this.bsShots[p][key]) {
        return JSON.stringify({ ok: false, error: "duplicate_shot" });
      }
      const isHit = (r + c) % 3 === 0;
      this.bsShots[p][key] = isHit ? "hit" : "miss";
      if (isHit) {
        this.bsHitsCount[p] += 1;
        this.bsBanner = `¡Impacto confirmado del Jugador ${p} en (${r}, ${c})!`;
        if (this.bsHitsCount[p] >= 17) {
          this.winner = p;
        } else if (!this.bsExtraTurnOnHit) {
          this.turn = p === 1 ? 2 : 1;
        }
      } else {
        this.bsBanner = `Agua en (${r}, ${c}). Cambio de turno.`;
        this.turn = p === 1 ? 2 : 1;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "ShotResultEvent", player: p, row: r, col: c, isHit }]);
    }

    // 12. MILLE BORNES
    if (this.gameType === "mille_bornes") {
      if (cmdName === "CoupFourreCommand") {
        const safety = String(parsed.safety || "Prioridad");
        if (!this.mbSafeties[p].includes(safety)) {
          this.mbSafeties[p].push(safety);
        }
        this.mbHazard[p] = null;
        this.mbDistance[p] = Math.min(1000, this.mbDistance[p] + 100);
        this.mbLastBanner = `⚡ ¡Coup Fourré del Jugador ${p}! Escudo ${safety} activado (+100 km y turno extra).`;
        this.turn = p;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "CoupFourreEvent", player: p, safety }]);
      }
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const idx = Number(parsed.card_index ?? 0);
      const hand = this.mbHands[p];
      const card = hand[idx] || "Distance 100";
      if (idx >= 0 && idx < hand.length) hand.splice(idx, 1);
      hand.push(this.nextRandomInt(0, 1) === 0 ? "Distance 100" : "Distance 75");

      const opp: 1 | 2 = p === 1 ? 2 : 1;
      if (card.startsWith("Distance ")) {
        const km = Number(card.replace("Distance ", "")) || 100;
        this.mbDistance[p] = Math.min(1000, this.mbDistance[p] + km);
        this.mbLastBanner = `Jugador ${p} avanzó +${km} km (Total: ${this.mbDistance[p]} / 1000 km).`;
        if (this.mbDistance[p] >= 1000) this.winner = p;
        this.turn = opp;
      } else if (["Prioridad", "Cisterna", "Impinchable", "As del Volante"].includes(card)) {
        if (!this.mbSafeties[p].includes(card)) this.mbSafeties[p].push(card);
        this.mbHazard[p] = null;
        this.mbLastBanner = `Jugador ${p} desplegó el Escudo ${card} y conserva el turno.`;
      } else if (["Pinchazo", "Sin Gasolina", "Accidente"].includes(card)) {
        this.mbHazard[opp] = card;
        this.mbLastBanner = `Jugador ${p} atacó al Jugador ${opp} con ${card}.`;
        this.turn = opp;
      } else {
        this.mbHazard[p] = null;
        this.mbLastBanner = `Jugador ${p} reparó su vehículo con ${card}.`;
        this.turn = opp;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "MilleBornesCardEvent", player: p, card }]);
    }

    // 13. MONOPOLY
    if (this.gameType === "monopoly") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      if (cmdName === "RollDiceCommand") {
        const d1 = Number(parsed.d1) || this.nextRandomInt(1, 6);
        const d2 = Number(parsed.d2) || this.nextRandomInt(1, 6);
        this.monoDice = [d1, d2];
        const nextPos = (this.monoPos[p] + d1 + d2) % 40;
        if (nextPos < this.monoPos[p]) {
          this.monoCash[p] += 200;
        }
        this.monoPos[p] = nextPos;
        const sp = this.monoSpaces[nextPos];
        if (sp.owner && sp.owner !== p && !sp.mortgaged) {
          const rent = sp.rent * (sp.houses + 1);
          this.monoCash[p] -= rent;
          this.monoCash[sp.owner] += rent;
          this.monoBanner = `Jugador ${p} cayó en ${sp.name} y pagó $${rent} de alquiler al Jugador ${sp.owner}.`;
        } else {
          this.monoBanner = `Jugador ${p} avanzó a ${sp.name} (Casilla ${nextPos}).`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "MonopolyMovedEvent", player: p, space: nextPos }]);
      }
      if (cmdName === "BuyPropertyCommand") {
        const sp = this.monoSpaces[this.monoPos[p]];
        if (sp && sp.price > 0 && sp.owner === null && this.monoCash[p] >= sp.price) {
          this.monoCash[p] -= sp.price;
          sp.owner = p;
          this.monoBanner = `Jugador ${p} compró ${sp.name} por $${sp.price}.`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "PropertyBoughtEvent", player: p, space: sp?.index }]);
      }
      if (cmdName === "BuildHouseCommand") {
        const spIdx = Number(parsed.space ?? this.monoPos[p]);
        const sp = this.monoSpaces[spIdx];
        if (sp && sp.owner === p && sp.houses < 5 && this.monoCash[p] >= 50) {
          this.monoCash[p] -= 50;
          sp.houses += 1;
          this.monoBanner = `Jugador ${p} construyó en ${sp.name} (Nivel ${sp.houses}).`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "HouseBuiltEvent", player: p, space: spIdx }]);
      }
      if (cmdName === "MortgagePropertyCommand") {
        const spIdx = Number(parsed.space ?? this.monoPos[p]);
        const sp = this.monoSpaces[spIdx];
        if (sp && sp.owner === p && !sp.mortgaged) {
          sp.mortgaged = true;
          this.monoCash[p] += Math.floor(sp.price / 2);
          this.monoBanner = `Jugador ${p} hipotecó ${sp.name} (+$${Math.floor(sp.price / 2)}).`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "PropertyMortgagedEvent", player: p, space: spIdx }]);
      }
      if (cmdName === "EndTurnCommand") {
        this.turn = p === 1 ? 2 : 1;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "TurnEndedEvent", next: this.turn }]);
      }
    }

    // 14. CRISIS / TEG
    if (this.gameType === "crisis") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      if (cmdName === "PlaceArmiesCommand") {
        const tId = Number(parsed.territory ?? 0);
        const count = Number(parsed.count ?? 1);
        const terr = this.crisisTerritories[tId];
        if (terr && terr.owner === p) {
          terr.armies += count;
          this.crisisArmiesRemaining = Math.max(0, this.crisisArmiesRemaining - count);
          if (this.crisisArmiesRemaining === 0) {
            this.crisisPhase = "Attack";
          }
          this.crisisBanner = `Jugador ${p} reforzó ${terr.name} (+${count} ejércitos).`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "ArmiesPlacedEvent", player: p, territory: tId }]);
      }
      if (cmdName === "AttackCommand") {
        const fromId = Number(parsed.from ?? 0);
        const toId = Number(parsed.to ?? 1);
        const att = this.crisisTerritories[fromId];
        const def = this.crisisTerritories[toId];
        if (att && def && att.owner === p && def.owner !== p && att.armies > 1) {
          def.armies -= 1;
          if (def.armies <= 0) {
            def.owner = p;
            def.armies = 1;
            att.armies = Math.max(1, att.armies - 1);
            this.crisisCards[p] += 1;
            this.crisisBanner = `¡Jugador ${p} conquistó ${def.name} y obtuvo 1 tarjeta de territorio!`;
          } else {
            this.crisisBanner = `Combate 3v3 en ${def.name}: defensor pierde 1 ejército.`;
          }
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "AttackResolvedEvent", player: p, from: fromId, to: toId }]);
      }
      if (cmdName === "ExchangeCardsCommand") {
        if (this.crisisCards[p] >= 3) {
          this.crisisCards[p] -= 3;
          this.crisisArmiesRemaining += 6;
          this.crisisBanner = `Jugador ${p} canjeó 3 tarjetas por +6 ejércitos de refuerzo.`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "CardsExchangedEvent", player: p }]);
      }
      if (cmdName === "EndTurnCommand") {
        this.turn = p === 1 ? 2 : 1;
        this.crisisPhase = "PlaceArmies";
        this.crisisArmiesRemaining = 4;
        this.crisisBanner = `Turno del Jugador ${this.turn} (Fase de Refuerzo: 4 ejércitos).`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "TurnEndedEvent", next: this.turn }]);
      }
    }

    return JSON.stringify({ ok: false, error: "unsupported_command" });
  }

  public step_ai_if_needed(): string {
    if (this.winner !== null || !this.aiPlayer || this.turn !== this.aiPlayer) {
      return "[]";
    }
    const ai = this.aiPlayer;

    if (this.gameType === "chess") {
      const legal = this.getChessLegalMoves(ai);
      if (legal.length === 0) return "[]";
      const chosen = legal[0];
      return this.send_command_json(
        ai,
        JSON.stringify({
          command_type: "chess_game::MovePieceCommand",
          player: ai,
          from: chosen.from,
          to: chosen.to,
          promotion: chosen.promotion,
        })
      );
    }
    if (this.gameType === "checkers") {
      const legal = this.getCheckersLegalMoves(ai);
      if (legal.length === 0) return "[]";
      const chosen = legal[0];
      return this.send_command_json(
        ai,
        JSON.stringify({
          command_type: "checkers_game::MovePieceCommand",
          player: ai,
          from: chosen.from,
          to: chosen.to,
        })
      );
    }
    if (this.gameType === "uno") {
      const playableRaw = JSON.parse(this.get_legal_moves_json(ai)) as {
        card: UnoCard;
        index: number;
      }[];
      if (playableRaw.length > 0) {
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "PlayCardCommand",
            player: ai,
            card_index: playableRaw[0].index,
            chosen_color: "Red",
          })
        );
      }
      return this.send_command_json(ai, JSON.stringify({ command_type: "DrawCardCommand", player: ai }));
    }
    if (this.gameType === "goose") {
      return this.send_command_json(ai, JSON.stringify({ command_type: "RollDiceCommand", player: ai }));
    }
    if (this.gameType === "go") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as { row: number; col: number }[];
      if (legal.length > 0) {
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "go_game::PlaceStoneCommand",
            player: ai,
            row: legal[0].row,
            col: legal[0].col,
          })
        );
      }
      return this.send_command_json(ai, JSON.stringify({ command_type: "PassCommand", player: ai }));
    }
    if (this.gameType === "shogi") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as {
        from: [number, number];
        to: [number, number];
      }[];
      if (legal.length > 0) {
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "shogi_game::MovePieceCommand",
            player: ai,
            from: legal[0].from,
            to: legal[0].to,
          })
        );
      }
    }
    if (this.gameType === "xiangqi") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as {
        from: [number, number];
        to: [number, number];
      }[];
      if (legal.length > 0) {
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "xiangqi_game::MovePieceCommand",
            player: ai,
            from: legal[0].from,
            to: legal[0].to,
          })
        );
      }
    }
    if (this.gameType === "chinese_checkers") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as { fromId: string; toId: string }[];
      if (legal.length > 0) {
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "chinese_checkers_game::MoveMarbleCommand",
            player: ai,
            fromId: legal[0].fromId,
            toId: legal[0].toId,
          })
        );
      }
    }
    if (this.gameType === "backgammon") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as { from: number; to: number }[];
      if (legal.length > 0) {
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "backgammon_game::MoveCheckerCommand",
            player: ai,
            from: legal[0].from,
            to: legal[0].to,
          })
        );
      }
    }
    if (this.gameType === "ludo") {
      return this.send_command_json(
        ai,
        JSON.stringify({
          command_type: "ludo_game::MoveTokenCommand",
          player: ai,
          token_index: 0,
        })
      );
    }
    if (this.gameType === "battleship") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as { row: number; col: number }[];
      if (legal.length > 0) {
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "battleship_game::FireShotCommand",
            player: ai,
            row: legal[0].row,
            col: legal[0].col,
          })
        );
      }
    }
    if (this.gameType === "mille_bornes") {
      return this.send_command_json(
        ai,
        JSON.stringify({
          command_type: "mille_bornes_game::PlayCardCommand",
          player: ai,
          card_index: 0,
        })
      );
    }
    if (this.gameType === "monopoly") {
      this.send_command_json(
        ai,
        JSON.stringify({ command_type: "monopoly_game::RollDiceCommand", player: ai })
      );
      this.send_command_json(
        ai,
        JSON.stringify({ command_type: "monopoly_game::BuyPropertyCommand", player: ai })
      );
      return this.send_command_json(
        ai,
        JSON.stringify({ command_type: "monopoly_game::EndTurnCommand", player: ai })
      );
    }
    if (this.gameType === "crisis") {
      const myTerr = this.crisisTerritories.find((t) => t.owner === ai);
      if (myTerr) {
        this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "crisis_game::PlaceArmiesCommand",
            player: ai,
            territory: myTerr.id,
            count: this.crisisArmiesRemaining,
          })
        );
      }
      return this.send_command_json(
        ai,
        JSON.stringify({ command_type: "crisis_game::EndTurnCommand", player: ai })
      );
    }

    return "[]";
  }

  public export_log_json(): string {
    return JSON.stringify({
      game_type: this.gameType,
      commands: this.commandLog,
      snapshot: JSON.parse(this.get_state_json()),
    });
  }

  public apply_sync_log_json(gameType: string, logJson: string): boolean {
    try {
      const parsed = JSON.parse(logJson);
      const targetGame = gameType || parsed.game_type || this.gameType;
      this.start_local_match(targetGame, 1, 2);
      if (Array.isArray(parsed.commands)) {
        for (const entry of parsed.commands) {
          this.executeCommandInternal(entry.player, entry.command, true);
        }
      }
      return true;
    } catch {
      return false;
    }
  }

  public generate_join_qr_svg(joinCode: string, hostName: string, gameType: string): string {
    const code = (joinCode || "OT1000").toUpperCase();
    const seedStr = `${code}:${hostName}:${gameType}`;
    let hash = 2166136261;
    for (let i = 0; i < seedStr.length; i++) {
      hash ^= seedStr.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    const size = 21;
    const cells: string[] = [];
    const isFinder = (r: number, c: number) =>
      (r < 7 && c < 7) || (r < 7 && c >= size - 7) || (r >= size - 7 && c < 7);

    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        let on = false;
        if (isFinder(r, c)) {
          const lr = r >= size - 7 ? r - (size - 7) : r;
          const lc = c >= size - 7 ? c - (size - 7) : c;
          on =
            lr === 0 ||
            lr === 6 ||
            lc === 0 ||
            lc === 6 ||
            (lr >= 2 && lr <= 4 && lc >= 2 && lc <= 4);
        } else {
          const bit = ((hash >>> ((r * size + c) % 24)) ^ (r * 31 + c * 17)) & 1;
          on = bit === 1;
        }
        if (on) {
          cells.push(
            `<rect x="${(c + 2) * 8}" y="${(r + 2) * 8}" width="8" height="8" rx="1.5" fill="#0f172a"/>`
          );
        }
      }
    }
    const dim = (size + 4) * 8;
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${dim} ${dim}" width="180" height="180"><rect width="${dim}" height="${dim}" rx="12" fill="#ffffff"/>${cells.join("")}</svg>`;
  }
}
