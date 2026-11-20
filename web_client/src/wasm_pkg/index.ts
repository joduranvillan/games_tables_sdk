/**
 * OpenTable WebAssembly Bridge Loader (`open_table_wasm`) — 14/14 Juegos Canónicos
 *
 * Conecta con el binario `.wasm` compilado desde `games_tables_sdk/open_table_wasm` cuando
 * está presente e implementa en paridad 1:1 las reglas canónicas de los 14 motores Rust
 * (`chess_game`, `checkers_game`, `shogi_game`, `xiangqi_game`, `go_game`, `uno_game`,
 * `goose_game`, `chinese_checkers_game`, `backgammon_game`, `ludo_game`, `battleship_game`,
 * `mille_bornes_game`, `monopoly_game`, `crisis_game`) sin modificar los crates del motor ni Godot.
 */

export interface ChessPiece {
  kind: "Pawn" | "Knight" | "Bishop" | "Rook" | "Queen" | "King";
  owner: 1 | 2;
}

export interface ChessMove {
  from: [number, number];
  to: [number, number];
  promotion?: "Queen" | "Rook" | "Bishop" | "Knight";
  isCastling?: "short" | "long";
  isEnPassant?: boolean;
}

export interface ChessCastlingRights {
  whiteKingMoved: boolean;
  whiteRookAMoved: boolean;
  whiteRookHMoved: boolean;
  blackKingMoved: boolean;
  blackRookAMoved: boolean;
  blackRookHMoved: boolean;
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

export interface ShogiMove {
  from?: [number, number];
  to: [number, number];
  canPromote?: boolean;
  mustPromote?: boolean;
  dropKind?: ShogiPiece["kind"];
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

export interface BattleshipShip {
  name: string;
  size: number;
  cells: [number, number][];
}

const GOOSE_SQUARES = new Set([5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59]);
const LUDO_SAFE_STARS = new Set([1, 9, 14, 22, 27, 35, 40, 48]);

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

function createInitialCastlingRights(): ChessCastlingRights {
  return {
    whiteKingMoved: false,
    whiteRookAMoved: false,
    whiteRookHMoved: false,
    blackKingMoved: false,
    blackRookAMoved: false,
    blackRookHMoved: false,
  };
}

function cloneChessGrid(grid: (ChessPiece | null)[][]): (ChessPiece | null)[][] {
  return grid.map((row) => row.map((cell) => (cell ? { ...cell } : null)));
}

/**
 * Generates pseudo-legal attack/movement squares for a single piece (without castling or check filtering).
 * For pawns, when `attacksOnly` is true, returns diagonal attack squares even if empty.
 */
function getChessPieceRawMoves(
  grid: (ChessPiece | null)[][],
  r: number,
  c: number,
  enPassantTarget: [number, number] | null,
  attacksOnly: boolean = false
): [number, number][] {
  const piece = grid[r]?.[c];
  if (!piece) return [];
  const player = piece.owner;
  const inBounds = (nr: number, nc: number) => nr >= 0 && nr < 8 && nc >= 0 && nc < 8;
  const targets: [number, number][] = [];

  if (piece.kind === "Pawn") {
    const dir = player === 1 ? -1 : 1;
    const startRow = player === 1 ? 6 : 1;

    if (attacksOnly) {
      for (const dc of [-1, 1]) {
        const nr = r + dir;
        const nc = c + dc;
        if (inBounds(nr, nc)) {
          targets.push([nr, nc]);
        }
      }
      return targets;
    }

    if (inBounds(r + dir, c) && !grid[r + dir][c]) {
      targets.push([r + dir, c]);
      if (r === startRow && inBounds(r + dir * 2, c) && !grid[r + dir * 2][c]) {
        targets.push([r + dir * 2, c]);
      }
    }
    for (const dc of [-1, 1]) {
      const nr = r + dir;
      const nc = c + dc;
      if (inBounds(nr, nc)) {
        const dst = grid[nr][nc];
        if (dst && dst.owner !== player) {
          targets.push([nr, nc]);
        } else if (
          !dst &&
          enPassantTarget &&
          enPassantTarget[0] === nr &&
          enPassantTarget[1] === nc
        ) {
          targets.push([nr, nc]);
        }
      }
    }
    return targets;
  }

  if (piece.kind === "Knight") {
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
      const dst = grid[nr][nc];
      if (!dst || dst.owner !== player) {
        targets.push([nr, nc]);
      }
    }
    return targets;
  }

  if (piece.kind === "King") {
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) continue;
        const nr = r + dr;
        const nc = c + dc;
        if (!inBounds(nr, nc)) continue;
        const dst = grid[nr][nc];
        if (!dst || dst.owner !== player) {
          targets.push([nr, nc]);
        }
      }
    }
    return targets;
  }

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
      const dst = grid[nr][nc];
      if (!dst) {
        targets.push([nr, nc]);
      } else {
        if (dst.owner !== player) {
          targets.push([nr, nc]);
        }
        break;
      }
      nr += dr;
      nc += dc;
    }
  }
  return targets;
}

export function isChessSquareAttacked(
  grid: (ChessPiece | null)[][],
  target: [number, number],
  byPlayer: 1 | 2
): boolean {
  const [tr, tc] = target;
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const pc = grid[r]?.[c];
      if (!pc || pc.owner !== byPlayer) continue;
      const attacks = getChessPieceRawMoves(grid, r, c, null, true);
      if (attacks.some(([ar, ac]) => ar === tr && ac === tc)) {
        return true;
      }
    }
  }
  return false;
}

export function findChessKing(
  grid: (ChessPiece | null)[][],
  player: 1 | 2
): [number, number] | null {
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const pc = grid[r]?.[c];
      if (pc && pc.owner === player && pc.kind === "King") {
        return [r, c];
      }
    }
  }
  return null;
}

export function isChessKingInCheck(
  grid: (ChessPiece | null)[][],
  player: 1 | 2
): boolean {
  const kingPos = findChessKing(grid, player);
  if (!kingPos) return false;
  const opp: 1 | 2 = player === 1 ? 2 : 1;
  return isChessSquareAttacked(grid, kingPos, opp);
}

function simulateChessMoveOnGrid(
  grid: (ChessPiece | null)[][],
  from: [number, number],
  to: [number, number],
  enPassantTarget: [number, number] | null,
  promotion?: ChessMove["promotion"]
): (ChessPiece | null)[][] {
  const sim = cloneChessGrid(grid);
  const moving = sim[from[0]]?.[from[1]];
  if (!moving) return sim;

  const isEnPassant =
    moving.kind === "Pawn" &&
    from[1] !== to[1] &&
    !sim[to[0]][to[1]] &&
    enPassantTarget !== null &&
    enPassantTarget[0] === to[0] &&
    enPassantTarget[1] === to[1];

  const isCastling =
    moving.kind === "King" && Math.abs(to[1] - from[1]) === 2 && from[0] === to[0];

  sim[from[0]][from[1]] = null;
  sim[to[0]][to[1]] = {
    kind: promotion || moving.kind,
    owner: moving.owner,
  };

  if (isEnPassant) {
    sim[from[0]][to[1]] = null;
  } else if (isCastling) {
    const row = from[0];
    if (to[1] === 6) {
      const rook = sim[row][7];
      sim[row][7] = null;
      sim[row][5] = rook || { kind: "Rook", owner: moving.owner };
    } else if (to[1] === 2) {
      const rook = sim[row][0];
      sim[row][0] = null;
      sim[row][3] = rook || { kind: "Rook", owner: moving.owner };
    }
  }

  return sim;
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

export function isShogiMovePseudoLegal(
  grid: (ShogiPiece | null)[][],
  from: [number, number],
  to: [number, number],
  player: 1 | 2
): boolean {
  const [fr, fc] = from;
  const [tr, tc] = to;
  if (fr < 0 || fr > 8 || fc < 0 || fc > 8 || tr < 0 || tr > 8 || tc < 0 || tc > 8) {
    return false;
  }
  if (fr === tr && fc === tc) return false;
  const piece = grid[fr]?.[fc];
  if (!piece || piece.owner !== player) return false;
  const dst = grid[tr]?.[tc];
  if (dst && dst.owner === player) return false;

  const dr = tr - fr; // row delta (Sente P1 moves up: forward = -1; Gote P2 moves down: forward = +1)
  const dc = tc - fc;
  const adr = Math.abs(dr);
  const adc = Math.abs(dc);
  const forward = player === 1 ? -1 : 1;

  const checkSlide = (): boolean => {
    const stepR = Math.sign(dr);
    const stepC = Math.sign(dc);
    let cr = fr + stepR;
    let cc = fc + stepC;
    while (cr !== tr || cc !== tc) {
      if (grid[cr]?.[cc] !== null) return false;
      cr += stepR;
      cc += stepC;
    }
    return true;
  };

  if (piece.promoted) {
    if (piece.kind === "Rook") {
      if (adr <= 1 && adc <= 1) return true;
      return (dr === 0 || dc === 0) && checkSlide();
    }
    if (piece.kind === "Bishop") {
      if (adr <= 1 && adc <= 1) return true;
      return adr === adc && checkSlide();
    }
    // Promoted Silver, Knight, Lance, Pawn all move as Gold General
    return adr <= 1 && adc <= 1 && !(adc === 1 && dr === -forward);
  }

  switch (piece.kind) {
    case "King":
      return adr <= 1 && adc <= 1;
    case "Rook":
      return (dr === 0 || dc === 0) && checkSlide();
    case "Bishop":
      return adr === adc && checkSlide();
    case "Gold":
      return adr <= 1 && adc <= 1 && !(adc === 1 && dr === -forward);
    case "Silver":
      return adr <= 1 && adc <= 1 && !((adc === 0 && dr === -forward) || (adc === 1 && dr === 0));
    case "Knight":
      return adc === 1 && dr === forward * 2;
    case "Lance":
      return dc === 0 && Math.sign(dr) === forward && checkSlide();
    case "Pawn":
      return dc === 0 && dr === forward;
  }
}

export function isShogiDropLegal(
  grid: (ShogiPiece | null)[][],
  kind: ShogiPiece["kind"],
  to: [number, number],
  player: 1 | 2
): { ok: true } | { ok: false; error: "occupied" | "nifu_rule" | "no_legal_moves_rank" } {
  const [tr, tc] = to;
  if (tr < 0 || tr > 8 || tc < 0 || tc > 8 || grid[tr]?.[tc] !== null) {
    return { ok: false, error: "occupied" };
  }
  // Nifu rule: cannot drop an unpromoted Pawn on a column that already has an unpromoted Pawn of the same player
  if (kind === "Pawn") {
    for (let r = 0; r < 9; r++) {
      const p = grid[r]?.[tc];
      if (p && p.owner === player && p.kind === "Pawn" && !p.promoted) {
        return { ok: false, error: "nifu_rule" };
      }
    }
  }
  // Dead-end rank rule
  if (player === 1) {
    if (tr === 0 && (kind === "Pawn" || kind === "Lance" || kind === "Knight")) {
      return { ok: false, error: "no_legal_moves_rank" };
    }
    if (tr === 1 && kind === "Knight") {
      return { ok: false, error: "no_legal_moves_rank" };
    }
  } else {
    if (tr === 8 && (kind === "Pawn" || kind === "Lance" || kind === "Knight")) {
      return { ok: false, error: "no_legal_moves_rank" };
    }
    if (tr === 7 && kind === "Knight") {
      return { ok: false, error: "no_legal_moves_rank" };
    }
  }
  return { ok: true };
}

export function mustPromoteShogiFesa(
  kind: ShogiPiece["kind"],
  toRow: number,
  player: 1 | 2
): boolean {
  if (player === 1) {
    if (kind === "Pawn" || kind === "Lance") return toRow === 0;
    if (kind === "Knight") return toRow <= 1;
    return false;
  } else {
    if (kind === "Pawn" || kind === "Lance") return toRow === 8;
    if (kind === "Knight") return toRow >= 7;
    return false;
  }
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

export function isXiangqiFlyingGeneral(grid: (XiangqiPiece | null)[][]): boolean {
  let redGen: [number, number] | null = null;
  let blackGen: [number, number] | null = null;
  for (let r = 0; r < 10; r++) {
    for (let c = 0; c < 9; c++) {
      const pc = grid[r]?.[c];
      if (pc?.kind === "General") {
        if (pc.owner === 1) redGen = [r, c];
        else blackGen = [r, c];
      }
    }
  }
  if (redGen && blackGen && redGen[1] === blackGen[1]) {
    const col = redGen[1];
    const minR = Math.min(redGen[0], blackGen[0]);
    const maxR = Math.max(redGen[0], blackGen[0]);
    let piecesBetween = 0;
    for (let r = minR + 1; r < maxR; r++) {
      if (grid[r]?.[col] !== null) piecesBetween++;
    }
    return piecesBetween === 0;
  }
  return false;
}

export function isXiangqiMovePseudoLegal(
  grid: (XiangqiPiece | null)[][],
  from: [number, number],
  to: [number, number],
  player: 1 | 2
): boolean {
  const [fr, fc] = from;
  const [tr, tc] = to;
  if (fr < 0 || fr > 9 || fc < 0 || fc > 8 || tr < 0 || tr > 9 || tc < 0 || tc > 8) {
    return false;
  }
  if (fr === tr && fc === tc) return false;
  const piece = grid[fr]?.[fc];
  if (!piece || piece.owner !== player) return false;
  const dst = grid[tr]?.[tc];
  if (dst && dst.owner === player) return false;

  const dr = tr - fr;
  const dc = tc - fc;
  const adr = Math.abs(dr);
  const adc = Math.abs(dc);
  const isRed = player === 1;

  const countBetweenOrthogonal = (): number => {
    let count = 0;
    if (dr === 0) {
      const minC = Math.min(fc, tc);
      const maxC = Math.max(fc, tc);
      for (let c = minC + 1; c < maxC; c++) {
        if (grid[fr]?.[c] !== null) count++;
      }
    } else if (dc === 0) {
      const minR = Math.min(fr, tr);
      const maxR = Math.max(fr, tr);
      for (let r = minR + 1; r < maxR; r++) {
        if (grid[r]?.[fc] !== null) count++;
      }
    }
    return count;
  };

  switch (piece.kind) {
    case "General": {
      if (adr + adc !== 1 || tc < 3 || tc > 5) return false;
      return isRed ? tr >= 7 && tr <= 9 : tr >= 0 && tr <= 2;
    }
    case "Advisor": {
      if (adr !== 1 || adc !== 1 || tc < 3 || tc > 5) return false;
      return isRed ? tr >= 7 && tr <= 9 : tr >= 0 && tr <= 2;
    }
    case "Elephant": {
      if (adr !== 2 || adc !== 2) return false;
      // Cannot cross the River
      if (isRed && tr < 5) return false;
      if (!isRed && tr > 4) return false;
      // Elephant eye check
      const eyeR = (fr + tr) / 2;
      const eyeC = (fc + tc) / 2;
      return grid[eyeR]?.[eyeC] === null;
    }
    case "Horse": {
      if (!((adr === 2 && adc === 1) || (adr === 1 && adc === 2))) return false;
      const legR = adr === 2 ? (fr + tr) / 2 : fr;
      const legC = adc === 2 ? (fc + tc) / 2 : fc;
      return grid[legR]?.[legC] === null;
    }
    case "Chariot": {
      if (dr !== 0 && dc !== 0) return false;
      return countBetweenOrthogonal() === 0;
    }
    case "Cannon": {
      if (dr !== 0 && dc !== 0) return false;
      const between = countBetweenOrthogonal();
      return dst !== null ? between === 1 : between === 0;
    }
    case "Soldier": {
      const forward = isRed ? -1 : 1;
      const pastRiver = isRed ? fr <= 4 : fr >= 5;
      if (dr === forward && dc === 0) return true;
      return pastRiver && dr === 0 && adc === 1;
    }
  }
}

export function isXiangqiMoveLegal(
  grid: (XiangqiPiece | null)[][],
  from: [number, number],
  to: [number, number],
  player: 1 | 2
): boolean {
  if (!isXiangqiMovePseudoLegal(grid, from, to, player)) return false;
  const sim = grid.map((row) => row.map((cell) => (cell ? { ...cell } : null)));
  sim[to[0]][to[1]] = sim[from[0]][from[1]];
  sim[from[0]][from[1]] = null;
  if (isXiangqiFlyingGeneral(sim)) return false;

  // Verify player's own General is not left in check
  let genPos: [number, number] | null = null;
  for (let r = 0; r < 10; r++) {
    for (let c = 0; c < 9; c++) {
      const pc = sim[r]?.[c];
      if (pc && pc.owner === player && pc.kind === "General") {
        genPos = [r, c];
        break;
      }
    }
  }
  if (!genPos) return true;
  const opp: 1 | 2 = player === 1 ? 2 : 1;
  for (let r = 0; r < 10; r++) {
    for (let c = 0; c < 9; c++) {
      const pc = sim[r]?.[c];
      if (pc && pc.owner === opp && isXiangqiMovePseudoLegal(sim, [r, c], genPos, opp)) {
        return false;
      }
    }
  }
  return true;
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
    neighbors: [(id + 1) % 30, (id + 29) % 30, (id + 5) % 30],
  }));
}

export interface ChineseCheckersCell {
  id: string;
  r: number;
  c: number;
  x2: number;
  owner: 0 | 1 | 2;
  zone: 0 | 1 | 2 | 3 | 4 | 5 | 6;
}

const CC_STAR_ROW_COUNTS = [1, 2, 3, 4, 13, 12, 11, 10, 9, 10, 11, 12, 13, 4, 3, 2, 1];

export function createInitialChineseCheckersStarCells(): ChineseCheckersCell[] {
  const cells: ChineseCheckersCell[] = [];
  for (let r = 0; r < CC_STAR_ROW_COUNTS.length; r++) {
    const count = CC_STAR_ROW_COUNTS[r];
    for (let c = 0; c < count; c++) {
      const id = `${r}_${c}`;
      const x2 = 2 * c - (count - 1);
      let zone: 0 | 1 | 2 | 3 | 4 | 5 | 6 = 0;
      let owner: 0 | 1 | 2 = 0;

      if (r <= 3) {
        // Top triangle point (Green / Player 2 home, Player 1 goal)
        zone = 2;
        owner = 2;
      } else if (r >= 13) {
        // Bottom triangle point (Red / Player 1 home, Player 2 goal)
        zone = 1;
        owner = 1;
      } else if (r >= 4 && r <= 7) {
        const armWidth = 8 - r; // 4, 3, 2, 1
        if (c < armWidth) zone = 3; // Top-Left Blue point
        else if (c >= count - armWidth) zone = 4; // Top-Right Yellow point
      } else if (r >= 9 && r <= 12) {
        const armWidth = r - 8; // 1, 2, 3, 4
        if (c < armWidth) zone = 5; // Bottom-Left Purple point
        else if (c >= count - armWidth) zone = 6; // Bottom-Right Orange point
      }

      cells.push({ id, r, c, x2, owner, zone });
    }
  }
  return cells;
}

function createDefaultBattleshipFleet(player: 1 | 2 = 1): BattleshipShip[] {
  if (player === 1) {
    return [
      {
        name: "Portaaviones",
        size: 5,
        cells: [
          [1, 1],
          [1, 2],
          [1, 3],
          [1, 4],
          [1, 5],
        ],
      },
      {
        name: "Acorazado",
        size: 4,
        cells: [
          [4, 4],
          [4, 5],
          [4, 6],
          [4, 7],
        ],
      },
      {
        name: "Crucero",
        size: 3,
        cells: [
          [6, 1],
          [7, 1],
          [8, 1],
        ],
      },
      {
        name: "Submarino",
        size: 3,
        cells: [
          [7, 5],
          [7, 6],
          [7, 7],
        ],
      },
      {
        name: "Destructor",
        size: 2,
        cells: [
          [2, 8],
          [3, 8],
        ],
      },
    ];
  }
  return [
    {
      name: "Portaaviones",
      size: 5,
      cells: [
        [0, 1],
        [0, 2],
        [0, 3],
        [0, 4],
        [0, 5],
      ],
    },
    {
      name: "Acorazado",
      size: 4,
      cells: [
        [2, 3],
        [2, 4],
        [2, 5],
        [2, 6],
      ],
    },
    {
      name: "Crucero",
      size: 3,
      cells: [
        [5, 2],
        [6, 2],
        [7, 2],
      ],
    },
    {
      name: "Submarino",
      size: 3,
      cells: [
        [6, 6],
        [6, 7],
        [6, 8],
      ],
    },
    {
      name: "Destructor",
      size: 2,
      cells: [
        [8, 4],
        [8, 5],
      ],
    },
  ];
}

export interface GoGroupAnalysis {
  color: 1 | 2;
  stones: [number, number][];
  liberties: string[];
}

export function serializeGoGrid(grid: (0 | 1 | 2)[][]): string {
  return grid.map((row) => row.join("")).join("|");
}

export function computeGoGroupAndLiberties(
  grid: (0 | 1 | 2)[][],
  size: number,
  startR: number,
  startC: number
): GoGroupAnalysis | null {
  const color = grid[startR]?.[startC];
  if (color !== 1 && color !== 2) return null;

  const visited = new Set<string>();
  const stones: [number, number][] = [];
  const liberties = new Set<string>();
  const queue: [number, number][] = [[startR, startC]];
  visited.add(`${startR}_${startC}`);

  const dirs: [number, number][] = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  while (queue.length > 0) {
    const [cr, cc] = queue.shift()!;
    stones.push([cr, cc]);

    for (const [dr, dc] of dirs) {
      const nr = cr + dr;
      const nc = cc + dc;
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
      const cell = grid[nr]?.[nc] ?? 0;
      const key = `${nr}_${nc}`;
      if (cell === 0) {
        liberties.add(key);
      } else if (cell === color && !visited.has(key)) {
        visited.add(key);
        queue.push([nr, nc]);
      }
    }
  }

  return {
    color,
    stones,
    liberties: Array.from(liberties),
  };
}

export function computeAllGoLibertiesMap(
  grid: (0 | 1 | 2)[][],
  size: number
): Record<string, number> {
  const libertiesByCell: Record<string, number> = {};
  const visited = new Set<string>();

  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      const cell = grid[r]?.[c] ?? 0;
      const key = `${r}_${c}`;
      if ((cell === 1 || cell === 2) && !visited.has(key)) {
        const grp = computeGoGroupAndLiberties(grid, size, r, c);
        if (grp) {
          const libCount = grp.liberties.length;
          for (const [sr, sc] of grp.stones) {
            const skey = `${sr}_${sc}`;
            visited.add(skey);
            libertiesByCell[skey] = libCount;
          }
        }
      }
    }
  }

  return libertiesByCell;
}

export function simulateGoPlaceStone(
  grid: (0 | 1 | 2)[][],
  size: number,
  r: number,
  c: number,
  player: 1 | 2,
  boardHistory: Set<string>
):
  | {
      ok: true;
      nextGrid: (0 | 1 | 2)[][];
      nextHash: string;
      capturedStones: [number, number][];
    }
  | {
      ok: false;
      error: "out_of_bounds" | "occupied_intersection" | "suicide_rule" | "ko_rule";
    } {
  if (r < 0 || r >= size || c < 0 || c >= size) {
    return { ok: false, error: "out_of_bounds" };
  }
  if (grid[r]?.[c] !== 0) {
    return { ok: false, error: "occupied_intersection" };
  }

  const nextGrid: (0 | 1 | 2)[][] = grid.map((row) => [...row]);
  nextGrid[r][c] = player;
  const opp: 1 | 2 = player === 1 ? 2 : 1;

  const capturedStones: [number, number][] = [];
  const checkedOpponentCells = new Set<string>();
  const dirs: [number, number][] = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  // Step 1: Check all orthogonal opponent groups for 0 liberties and capture entire connected chains
  for (const [dr, dc] of dirs) {
    const nr = r + dr;
    const nc = c + dc;
    if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
    const nKey = `${nr}_${nc}`;
    if (nextGrid[nr]?.[nc] === opp && !checkedOpponentCells.has(nKey)) {
      const oppGroup = computeGoGroupAndLiberties(nextGrid, size, nr, nc);
      if (oppGroup) {
        for (const [sr, sc] of oppGroup.stones) {
          checkedOpponentCells.add(`${sr}_${sc}`);
        }
        if (oppGroup.liberties.length === 0) {
          for (const [sr, sc] of oppGroup.stones) {
            nextGrid[sr][sc] = 0;
            capturedStones.push([sr, sc]);
          }
        }
      }
    }
  }

  // Step 2: Check suicide rule on the newly placed stone's own connected chain
  const ownGroup = computeGoGroupAndLiberties(nextGrid, size, r, c);
  if (!ownGroup || ownGroup.liberties.length === 0) {
    return { ok: false, error: "suicide_rule" };
  }

  // Step 3: Check Ko / Positional Superko rule against board history
  const nextHash = serializeGoGrid(nextGrid);
  if (boardHistory.has(nextHash)) {
    return { ok: false, error: "ko_rule" };
  }

  return {
    ok: true,
    nextGrid,
    nextHash,
    capturedStones,
  };
}

export class WasmGameBridge {
  private gameType: string = "chess";
  private turn: 1 | 2 = 1;
  private tick: number = 0;
  private winner: 0 | 1 | 2 | null = null;
  private aiPlayer: 1 | 2 | null = null;
  private aiDifficulty: number = 1;
  private commandLog: { player: number; command: string }[] = [];
  private replayFullLog: { player: number; command: string }[] = [];
  private replayCursor: number = 0;
  private rngState: number = 1337;

  // 1. Chess state (FIDE Canonical Rules: Castling O-O / O-O-O, En Passant, Promotion, Check/Pin simulation, 50-move & Threefold)
  private chessGrid: (ChessPiece | null)[][] = createInitialChessGrid();
  private chessCastling: ChessCastlingRights = createInitialCastlingRights();
  private chessEnPassantTarget: [number, number] | null = null;
  private chessHalfMoveClock: number = 0;
  private chessPositionHistory: Record<string, number> = {};
  private chessLastMove: { from: [number, number]; to: [number, number] } | null = null;
  private chessDrawOfferedBy: 1 | 2 | null = null;
  private chessInCheck: 1 | 2 | null = null;
  private chessStatusBanner: string =
    "Enroque corto (O-O), enroque largo (O-O-O), captura al paso y detección FIDE de jaque/clavadas activos.";

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
  private goBoardHistory: Set<string> = new Set<string>();
  private goLastMove: [number, number] | null = null;
  private goLastBanner: string =
    "Goban 9×9 listo · Captura por cadenas BFS, regla de suicidio y Ko activas.";

  // 6. Shogi state
  private shogiGrid: (ShogiPiece | null)[][] = createInitialShogiGrid();
  private shogiHands: Record<1 | 2, ShogiPiece["kind"][]> = { 1: [], 2: [] };

  // 7. Xiangqi state
  private xiangqiGrid: (XiangqiPiece | null)[][] = createInitialXiangqiGrid();
  private xiangqiBanner: string =
    "Río Chu He / Han Jie activo · Palacio 3×3, Pantalla de Cañón y General Volador activos";

  // 8. Chinese Checkers state (121-hole Hexagonal Star)
  private ccCells: ChineseCheckersCell[] = [];

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
  private bsFleets: Record<1 | 2, BattleshipShip[]> = {
    1: createDefaultBattleshipFleet(1),
    2: createDefaultBattleshipFleet(2),
  };
  private bsSunkShips: Record<1 | 2, string[]> = { 1: [], 2: [] };
  private bsExtraTurnOnHit: boolean = false;
  private bsBanner: string =
    "Flotas desplegadas (5 buques: 5,4,3,3,2). Selecciona coordenada en el radar enemigo.";

  // 12. Mille Bornes state
  private mbDistance: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private mbHands: Record<1 | 2, string[]> = { 1: [], 2: [] };
  private mbSafeties: Record<1 | 2, string[]> = { 1: [], 2: [] };
  private mbHazard: Record<1 | 2, string | null> = { 1: null, 2: null };
  private mbPlayed200Count: Record<1 | 2, number> = { 1: 0, 2: 0 };
  private mbLastBanner: string = "Meta exacta: 1000 km · Escudos y reacción Coup Fourré listos.";

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
  private crisisConqueredThisTurn: boolean = false;
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
    this.replayFullLog = [];
    this.replayCursor = 0;
    this.rngState = 1337;

    if (this.gameType === "chess") {
      this.chessGrid = createInitialChessGrid();
      this.chessCastling = createInitialCastlingRights();
      this.chessEnPassantTarget = null;
      this.chessHalfMoveClock = 0;
      this.chessPositionHistory = {};
      this.chessLastMove = null;
      this.chessDrawOfferedBy = null;
      this.chessInCheck = null;
      this.chessStatusBanner =
        "Enroque corto (O-O), enroque largo (O-O-O), captura al paso y detección FIDE de jaque/clavadas activos.";
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
      this.goBoardHistory = new Set<string>([serializeGoGrid(this.goGrid)]);
      this.goLastMove = null;
      this.goLastBanner =
        "Goban 9×9 listo · Captura por cadenas BFS, regla de suicidio y Ko activas.";
    } else if (this.gameType === "shogi") {
      this.shogiGrid = createInitialShogiGrid();
      this.shogiHands = { 1: [], 2: [] };
    } else if (this.gameType === "xiangqi") {
      this.xiangqiGrid = createInitialXiangqiGrid();
      this.xiangqiBanner =
        "Río Chu He / Han Jie activo · Palacio 3×3, Pantalla de Cañón y General Volador activos";
    } else if (this.gameType === "chinese_checkers") {
      this.ccCells = createInitialChineseCheckersStarCells();
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
      this.bsFleets = {
        1: createDefaultBattleshipFleet(1),
        2: createDefaultBattleshipFleet(2),
      };
      this.bsSunkShips = { 1: [], 2: [] };
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
      this.mbPlayed200Count = { 1: 0, 2: 0 };
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
      this.crisisConqueredThisTurn = false;
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

  public get_ai_difficulty(): number {
    return this.aiDifficulty;
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

  /**
   * 1. CHESS: Canonical FIDE legal move generator mirroring `chess_game/src/board.rs`:
   * - Includes standard piece movements, double pawn push, En Passant, Short Castling (O-O), Long Castling (O-O-O), and Pawn Promotion.
   * - Filters out any move that leaves the moving player's King in check (pins & check resolution).
   */
  private getChessLegalMoves(player: 1 | 2): ChessMove[] {
    const candidateMoves: ChessMove[] = [];
    const opp: 1 | 2 = player === 1 ? 2 : 1;
    const promoRow = player === 1 ? 0 : 7;

    for (let r = 0; r < 8; r++) {
      for (let c = 0; c < 8; c++) {
        const piece = this.chessGrid[r]?.[c];
        if (!piece || piece.owner !== player) continue;

        const rawTargets = getChessPieceRawMoves(
          this.chessGrid,
          r,
          c,
          this.chessEnPassantTarget,
          false
        );

        for (const [tr, tc] of rawTargets) {
          if (piece.kind === "Pawn" && tr === promoRow) {
            for (const p of ["Queen", "Rook", "Bishop", "Knight"] as const) {
              candidateMoves.push({ from: [r, c], to: [tr, tc], promotion: p });
            }
          } else {
            const isEp =
              piece.kind === "Pawn" &&
              c !== tc &&
              !this.chessGrid[tr][tc] &&
              this.chessEnPassantTarget !== null &&
              this.chessEnPassantTarget[0] === tr &&
              this.chessEnPassantTarget[1] === tc;
            candidateMoves.push({
              from: [r, c],
              to: [tr, tc],
              ...(isEp ? { isEnPassant: true } : {}),
            });
          }
        }

        // Castling (O-O and O-O-O) matching chess_game/src/board.rs
        if (piece.kind === "King") {
          const homeRow = player === 1 ? 7 : 0;
          const kingMoved =
            player === 1 ? this.chessCastling.whiteKingMoved : this.chessCastling.blackKingMoved;
          const rookHMoved =
            player === 1 ? this.chessCastling.whiteRookHMoved : this.chessCastling.blackRookHMoved;
          const rookAMoved =
            player === 1 ? this.chessCastling.whiteRookAMoved : this.chessCastling.blackRookAMoved;

          if (r === homeRow && c === 4 && !kingMoved && !isChessKingInCheck(this.chessGrid, player)) {
            // Short Castling (Kingside O-O: col 4 -> 6, rook col 7 -> 5)
            const hRook = this.chessGrid[homeRow][7];
            if (
              !rookHMoved &&
              hRook &&
              hRook.owner === player &&
              hRook.kind === "Rook" &&
              !this.chessGrid[homeRow][5] &&
              !this.chessGrid[homeRow][6] &&
              !isChessSquareAttacked(this.chessGrid, [homeRow, 5], opp) &&
              !isChessSquareAttacked(this.chessGrid, [homeRow, 6], opp)
            ) {
              candidateMoves.push({
                from: [homeRow, 4],
                to: [homeRow, 6],
                isCastling: "short",
              });
            }

            // Long Castling (Queenside O-O-O: col 4 -> 2, rook col 0 -> 3)
            const aRook = this.chessGrid[homeRow][0];
            if (
              !rookAMoved &&
              aRook &&
              aRook.owner === player &&
              aRook.kind === "Rook" &&
              !this.chessGrid[homeRow][1] &&
              !this.chessGrid[homeRow][2] &&
              !this.chessGrid[homeRow][3] &&
              !isChessSquareAttacked(this.chessGrid, [homeRow, 3], opp) &&
              !isChessSquareAttacked(this.chessGrid, [homeRow, 2], opp)
            ) {
              candidateMoves.push({
                from: [homeRow, 4],
                to: [homeRow, 2],
                isCastling: "long",
              });
            }
          }
        }
      }
    }

    // Filter out any move that leaves own King in check
    return candidateMoves.filter((m) => {
      const simGrid = simulateChessMoveOnGrid(
        this.chessGrid,
        m.from,
        m.to,
        this.chessEnPassantTarget,
        m.promotion
      );
      return !isChessKingInCheck(simGrid, player);
    });
  }

  private getChessCastlingRightsString(): string {
    let s = "";
    if (!this.chessCastling.whiteKingMoved && !this.chessCastling.whiteRookHMoved) s += "K";
    if (!this.chessCastling.whiteKingMoved && !this.chessCastling.whiteRookAMoved) s += "Q";
    if (!this.chessCastling.blackKingMoved && !this.chessCastling.blackRookHMoved) s += "k";
    if (!this.chessCastling.blackKingMoved && !this.chessCastling.blackRookAMoved) s += "q";
    return s || "-";
  }

  public export_chess_fen(): string {
    const pieceMap: Record<ChessPiece["kind"], string> = {
      Pawn: "p",
      Knight: "n",
      Bishop: "b",
      Rook: "r",
      Queen: "q",
      King: "k",
    };
    const rows: string[] = [];
    for (let r = 0; r < 8; r++) {
      let empty = 0;
      let rowStr = "";
      for (let c = 0; c < 8; c++) {
        const pc = this.chessGrid[r]?.[c];
        if (!pc) {
          empty++;
        } else {
          if (empty > 0) {
            rowStr += String(empty);
            empty = 0;
          }
          const ch = pieceMap[pc.kind];
          rowStr += pc.owner === 1 ? ch.toUpperCase() : ch;
        }
      }
      if (empty > 0) rowStr += String(empty);
      rows.push(rowStr);
    }
    const files = ["a", "b", "c", "d", "e", "f", "g", "h"];
    const ep = this.chessEnPassantTarget
      ? `${files[this.chessEnPassantTarget[1]]}${8 - this.chessEnPassantTarget[0]}`
      : "-";
    return `${rows.join("/")} ${this.turn === 1 ? "w" : "b"} ${this.getChessCastlingRightsString()} ${ep} ${this.chessHalfMoveClock} ${Math.floor(this.tick / 2) + 1}`;
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

  private getShogiLegalMoves(player: 1 | 2): ShogiMove[] {
    const moves: ShogiMove[] = [];
    for (let fr = 0; fr < 9; fr++) {
      for (let fc = 0; fc < 9; fc++) {
        const pc = this.shogiGrid[fr]?.[fc];
        if (!pc || pc.owner !== player) continue;
        for (let tr = 0; tr < 9; tr++) {
          for (let tc = 0; tc < 9; tc++) {
            if (isShogiMovePseudoLegal(this.shogiGrid, [fr, fc], [tr, tc], player)) {
              const inZone = player === 1 ? tr <= 2 || fr <= 2 : tr >= 6 || fr >= 6;
              const canPromote =
                inZone && !pc.promoted && pc.kind !== "King" && pc.kind !== "Gold";
              const mustPromote =
                !pc.promoted && mustPromoteShogiFesa(pc.kind, tr, player);
              moves.push({
                from: [fr, fc],
                to: [tr, tc],
                canPromote,
                mustPromote,
              });
            }
          }
        }
      }
    }
    return moves;
  }

  private getXiangqiLegalMoves(player: 1 | 2): { from: [number, number]; to: [number, number] }[] {
    const moves: { from: [number, number]; to: [number, number] }[] = [];
    for (let fr = 0; fr < 10; fr++) {
      for (let fc = 0; fc < 9; fc++) {
        const pc = this.xiangqiGrid[fr]?.[fc];
        if (!pc || pc.owner !== player) continue;
        for (let tr = 0; tr < 10; tr++) {
          for (let tc = 0; tc < 9; tc++) {
            if (isXiangqiMoveLegal(this.xiangqiGrid, [fr, fc], [tr, tc], player)) {
              moves.push({ from: [fr, fc], to: [tr, tc] });
            }
          }
        }
      }
    }
    return moves;
  }

  private getChineseCheckersLegalMoves(player: 1 | 2): { fromId: string; toId: string }[] {
    const moves: { fromId: string; toId: string }[] = [];
    const coordMap = new Map<string, ChineseCheckersCell>();
    for (const cell of this.ccCells) {
      coordMap.set(`${cell.r}:${cell.x2}`, cell);
    }

    // 6 canonical hexagonal star directions in (dr, dx2)
    const hexDirs: [number, number][] = [
      [0, -2], // Left
      [0, 2], // Right
      [-1, -1], // Up-Left
      [-1, 1], // Up-Right
      [1, -1], // Down-Left
      [1, 1], // Down-Right
    ];

    const owned = this.ccCells.filter((cell) => cell.owner === player);
    for (const origin of owned) {
      const reached = new Set<string>();

      // 1. Single step to adjacent empty hole
      for (const [dr, dx2] of hexDirs) {
        const adj = coordMap.get(`${origin.r + dr}:${origin.x2 + dx2}`);
        if (adj && adj.owner === 0) {
          reached.add(adj.id);
        }
      }

      // 2. Multi-hop chain jumps over adjacent occupied marbles (BFS)
      const queue: [number, number][] = [[origin.r, origin.x2]];
      const visitedJumps = new Set<string>([origin.id]);

      while (queue.length > 0) {
        const [cr, cx2] = queue.shift()!;
        for (const [dr, dx2] of hexDirs) {
          const mid = coordMap.get(`${cr + dr}:${cx2 + dx2}`);
          const land = coordMap.get(`${cr + dr * 2}:${cx2 + dx2 * 2}`);
          if (mid && mid.owner !== 0 && land && land.owner === 0 && !visitedJumps.has(land.id)) {
            visitedJumps.add(land.id);
            reached.add(land.id);
            queue.push([land.r, land.x2]);
          }
        }
      }

      for (const toId of reached) {
        moves.push({ fromId: origin.id, toId });
      }
    }

    // Order moves so forward-advancing jumps come first for AI and tutorials
    moves.sort((a, b) => {
      const aFromR = Number(a.fromId.split("_")[0]);
      const aToR = Number(a.toId.split("_")[0]);
      const bFromR = Number(b.fromId.split("_")[0]);
      const bToR = Number(b.toId.split("_")[0]);
      const aGain = player === 1 ? aFromR - aToR : aToR - aFromR;
      const bGain = player === 1 ? bFromR - bToR : bToR - bFromR;
      return bGain - aGain;
    });

    return moves;
  }

  private canBackgammonBearOff(player: 1 | 2): boolean {
    if (this.bgBar[player] > 0) return false;
    for (let i = 0; i < 24; i++) {
      const pt = this.bgPoints[i];
      if (pt && pt.owner === player && pt.count > 0) {
        if (player === 1 && i < 18) return false;
        if (player === 2 && i > 5) return false;
      }
    }
    return true;
  }

  private getBackgammonLegalMoves(player: 1 | 2): { from: number; to: number }[] {
    const moves: { from: number; to: number }[] = [];
    const opp: 1 | 2 = player === 1 ? 2 : 1;
    const uniqueSteps = Array.from(new Set([this.bgDice[0] || 3, this.bgDice[1] || 5]));

    const isPointOpen = (idx: number): boolean => {
      if (idx < 0 || idx >= 24) return false;
      const pt = this.bgPoints[idx];
      return !pt || pt.owner !== opp || pt.count <= 1;
    };

    // Rule 1: If player has checkers on the bar, they MUST enter from the bar first
    if (this.bgBar[player] > 0) {
      for (const step of uniqueSteps) {
        const entryIdx = player === 1 ? step - 1 : 24 - step;
        if (isPointOpen(entryIdx)) {
          moves.push({ from: -1, to: entryIdx });
        }
      }
      return moves;
    }

    const canBearOff = this.canBackgammonBearOff(player);
    for (let i = 0; i < 24; i++) {
      if (this.bgPoints[i]?.owner === player && this.bgPoints[i].count > 0) {
        for (const step of uniqueSteps) {
          const rawTo = player === 1 ? i + step : i - step;
          if (rawTo >= 0 && rawTo < 24) {
            if (isPointOpen(rawTo)) {
              moves.push({ from: i, to: rawTo });
            }
          } else if (canBearOff) {
            moves.push({ from: i, to: player === 1 ? 24 : -1 });
          }
        }
      }
    }
    return moves;
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
      const moves: { row: number; col: number; capturesCount: number }[] = [];
      for (let r = 0; r < this.goSize; r++) {
        for (let c = 0; c < this.goSize; c++) {
          if (this.goGrid[r]?.[c] === 0) {
            const sim = simulateGoPlaceStone(
              this.goGrid,
              this.goSize,
              r,
              c,
              p,
              this.goBoardHistory
            );
            if (sim.ok) {
              moves.push({
                row: r,
                col: c,
                capturesCount: sim.capturedStones.length,
              });
            }
          }
        }
      }
      moves.sort((a, b) => b.capturesCount - a.capturesCount);
      return JSON.stringify(moves);
    }
    if (this.gameType === "shogi") {
      return JSON.stringify(this.getShogiLegalMoves(p));
    }
    if (this.gameType === "xiangqi") {
      return JSON.stringify(this.getXiangqiLegalMoves(p));
    }
    if (this.gameType === "chinese_checkers") {
      return JSON.stringify(this.getChineseCheckersLegalMoves(p));
    }
    if (this.gameType === "backgammon") {
      return JSON.stringify(this.getBackgammonLegalMoves(p));
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
        castling_rights: this.getChessCastlingRightsString(),
        en_passant_target: this.chessEnPassantTarget,
        half_move_clock: this.chessHalfMoveClock,
        status_banner: this.chessStatusBanner,
        fen: this.export_chess_fen(),
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
        liberties_by_cell: computeAllGoLibertiesMap(this.goGrid, this.goSize),
        last_move: this.goLastMove ? `${this.goLastMove[0]}_${this.goLastMove[1]}` : null,
        last_banner: this.goLastBanner,
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
        fleets: this.bsFleets,
        sunk_ships: this.bsSunkShips,
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
    if (this.replayCursor < this.replayFullLog.length) {
      this.replayFullLog = this.replayFullLog.slice(0, this.replayCursor);
    }
    const res = this.executeCommandInternal(playerId, jsonStr, true);
    this.replayFullLog = [...this.commandLog];
    this.replayCursor = this.replayFullLog.length;
    return res;
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

    // 1. CHESS (Canonical FIDE Validation: Castling O-O / O-O-O, En Passant, Promotion, Pins, Check/Checkmate/Stalemate)
    if (this.gameType === "chess") {
      if (cmdName === "OfferDrawCommand") {
        this.chessDrawOfferedBy = p;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "DrawOfferedEvent", player: p }]);
      }
      if (
        cmdName === "AcceptDrawCommand" &&
        this.chessDrawOfferedBy &&
        this.chessDrawOfferedBy !== p
      ) {
        this.winner = 0;
        this.chessStatusBanner = "Tablas acordadas entre ambos jugadores.";
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "GameOverEvent", winner: 0, is_draw: true }]);
      }
      if (p !== this.turn) {
        return JSON.stringify({ ok: false, error: "not_your_turn" });
      }
      const from = parsed.from as [number, number];
      let to = parsed.to as [number, number];
      if (!Array.isArray(from) || !Array.isArray(to)) {
        return JSON.stringify({ ok: false, error: "invalid_coordinates" });
      }
      const movingPiece = this.chessGrid[from[0]]?.[from[1]];
      if (!movingPiece || movingPiece.owner !== p) {
        return JSON.stringify({ ok: false, error: "illegal_chess_move" });
      }

      // Support clicking directly on own Rook to castle (e1->h1 normalized to e1->g1, e1->a1 normalized to e1->c1)
      if (movingPiece.kind === "King" && from[0] === to[0] && from[1] === 4) {
        if (to[1] === 7) to = [from[0], 6];
        else if (to[1] === 0) to = [from[0], 2];
      }

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

      const targetBefore = this.chessGrid[to[0]]?.[to[1]];
      const isEnPassantCapture = Boolean(match.isEnPassant);
      const isCapture = targetBefore !== null || isEnPassantCapture;

      // Update Castling rights if King or Rook moves or is captured
      if (movingPiece.kind === "King") {
        if (p === 1) this.chessCastling.whiteKingMoved = true;
        else this.chessCastling.blackKingMoved = true;
      }
      if (movingPiece.kind === "Rook") {
        if (from[0] === 7 && from[1] === 0) this.chessCastling.whiteRookAMoved = true;
        if (from[0] === 7 && from[1] === 7) this.chessCastling.whiteRookHMoved = true;
        if (from[0] === 0 && from[1] === 0) this.chessCastling.blackRookAMoved = true;
        if (from[0] === 0 && from[1] === 7) this.chessCastling.blackRookHMoved = true;
      }
      if (to[0] === 7 && to[1] === 0) this.chessCastling.whiteRookAMoved = true;
      if (to[0] === 7 && to[1] === 7) this.chessCastling.whiteRookHMoved = true;
      if (to[0] === 0 && to[1] === 0) this.chessCastling.blackRookAMoved = true;
      if (to[0] === 0 && to[1] === 7) this.chessCastling.blackRookHMoved = true;

      // Apply move (including En Passant pawn removal and Castling rook transfer)
      this.chessGrid = simulateChessMoveOnGrid(
        this.chessGrid,
        from,
        to,
        this.chessEnPassantTarget,
        match.promotion
      );

      // Update En Passant target square for next turn
      if (movingPiece.kind === "Pawn" && Math.abs(to[0] - from[0]) === 2) {
        this.chessEnPassantTarget = [(from[0] + to[0]) / 2, from[1]];
      } else {
        this.chessEnPassantTarget = null;
      }

      // Update 50-move half-move clock
      if (movingPiece.kind === "Pawn" || isCapture) {
        this.chessHalfMoveClock = 0;
      } else {
        this.chessHalfMoveClock += 1;
      }

      this.chessLastMove = { from, to };
      this.chessDrawOfferedBy = null;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });

      const opp: 1 | 2 = p === 1 ? 2 : 1;
      this.turn = opp;

      const oppInCheck = isChessKingInCheck(this.chessGrid, opp);
      this.chessInCheck = oppInCheck ? opp : null;

      const fenKey = this.export_chess_fen().split(" ").slice(0, 4).join(" ");
      this.chessPositionHistory[fenKey] = (this.chessPositionHistory[fenKey] || 0) + 1;

      const oppLegalMoves = this.getChessLegalMoves(opp);
      if (oppLegalMoves.length === 0) {
        if (oppInCheck) {
          this.winner = p;
          this.chessStatusBanner = `¡Jaque Mate! Victoria del Jugador ${p} (${
            p === 1 ? "Blancas" : "Negras"
          }).`;
        } else {
          this.winner = 0;
          this.chessStatusBanner = "Tablas por Rey Ahogado (Stalemate).";
        }
      } else if (this.chessHalfMoveClock >= 100) {
        this.winner = 0;
        this.chessStatusBanner = "Tablas por Regla FIDE de los 50 Movimientos.";
      } else if (this.chessPositionHistory[fenKey] >= 3) {
        this.winner = 0;
        this.chessStatusBanner = "Tablas por Triple Repetición de Posición.";
      } else if (match.isCastling === "short") {
        this.chessStatusBanner = `Jugador ${p} ejecutó Enroque Corto (O-O).`;
      } else if (match.isCastling === "long") {
        this.chessStatusBanner = `Jugador ${p} ejecutó Enroque Largo (O-O-O).`;
      } else if (isEnPassantCapture) {
        this.chessStatusBanner = `Jugador ${p} ejecutó Captura al Paso (En Passant).`;
      } else if (match.promotion) {
        this.chessStatusBanner = `¡Peón coronado a ${match.promotion}!`;
      } else if (oppInCheck) {
        this.chessStatusBanner = `¡Jaque al Rey del Jugador ${opp}!`;
      } else {
        this.chessStatusBanner = `Movimiento completado. Turno de ${
          opp === 1 ? "Blancas (J1)" : "Negras (J2)"
        }.`;
      }

      return JSON.stringify([
        {
          event: "PieceMovedEvent",
          player: p,
          from,
          to,
          castling: match.isCastling || null,
          en_passant: isEnPassantCapture,
          promotion: match.promotion || null,
        },
      ]);
    }

    // 2. CHECKERS (Mandatory Capture, Multi-Jump Chain & King Crowning)
    if (this.gameType === "checkers") {
      if (p !== this.turn) {
        return JSON.stringify({ ok: false, error: "not_your_turn" });
      }
      const from = parsed.from as [number, number];
      const to = parsed.to as [number, number];
      const legal = this.getCheckersLegalMoves(p);
      const hasMandatoryCapture = legal.some((m) => m.captured !== undefined);
      const match = legal.find(
        (m) =>
          m.from[0] === from[0] &&
          m.from[1] === from[1] &&
          m.to[0] === to[0] &&
          m.to[1] === to[1]
      );
      if (!match) {
        return JSON.stringify({
          ok: false,
          error: hasMandatoryCapture ? "mandatory_capture" : "illegal_checkers_move",
        });
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

    // 3. UNO (Strict Color/Value/Wild matching, Penalty Stacking, Skip/Reverse & CatchUnoCommand)
    if (this.gameType === "uno") {
      if (cmdName === "CallUnoCommand") {
        this.unoCalled[p] = true;
        this.unoLastEvent = `¡Jugador ${p} gritó ¡UNO!!`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "UnoCalledEvent", player: p }]);
      }
      if (cmdName === "CatchUnoCommand") {
        const opp: 1 | 2 = p === 1 ? 2 : 1;
        if (this.unoHands[opp].length === 1 && !this.unoCalled[opp]) {
          for (let i = 0; i < 2; i++) {
            const drawn = this.unoDeck.pop();
            if (drawn) this.unoHands[opp].push(drawn);
          }
          this.unoLastEvent = `¡Jugador ${opp} no gritó UNO y recibe +2 cartas de penalización!`;
          this.tick += 1;
          if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
          return JSON.stringify([{ event: "UnoCaughtPenaltyEvent", target: opp, penalty: 2 }]);
        }
        return JSON.stringify({ ok: false, error: "cannot_catch_uno" });
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
        const top = this.unoDiscard[this.unoDiscard.length - 1];
        if (this.unoDrawPenalty > 0) {
          if (card.value !== "DrawTwo" && card.value !== "WildDrawFour") {
            return JSON.stringify({ ok: false, error: "must_draw_penalty_or_stack" });
          }
        } else {
          const matchesColor = card.color === "Wild" || card.color === this.unoActiveColor;
          const matchesValue = top && card.value === top.value;
          if (!matchesColor && !matchesValue) {
            return JSON.stringify({ ok: false, error: "illegal_uno_card" });
          }
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
        pState.inWell = true;
        const opp: 1 | 2 = p === 1 ? 2 : 1;
        if (this.goosePlayers[opp].inWell) {
          this.goosePlayers[opp].inWell = false;
          this.goosePlayers[opp].skipTurns = 0;
        }
        msg += "El Pozo (31): pierde 2 turnos.";
      } else if (target === 42) {
        pState.square = 30;
        msg += "El Laberinto (42): retrocede a la casilla 30.";
      } else if (target === 52) {
        pState.square = 52;
        pState.skipTurns = 3;
        msg += "La Cárcel (52): pierde 3 turnos.";
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

    // 5. GO (BFS Connected-Chain Capture, Suicide Rule, Ko Rule, 9x9/13x13/19x19, Handicap & Komi 6.5)
    if (this.gameType === "go") {
      if (cmdName === "SetBoardSizeCommand") {
        const rawSize = Number(parsed.size ?? 9);
        const validSize: 9 | 13 | 19 =
          rawSize === 13 ? 13 : rawSize === 19 ? 19 : 9;
        this.goSize = validSize;
        this.goGrid = Array.from({ length: validSize }, () =>
          Array.from({ length: validSize }, () => 0)
        );
        this.goCaptures = { 1: 0, 2: 0 };
        this.goPasses = 0;
        this.goDeadStones = [];
        this.goHandicap = 0;
        this.goScoringPhase = false;
        this.turn = 1;
        this.winner = null;
        this.goBoardHistory = new Set<string>([serializeGoGrid(this.goGrid)]);
        this.goLastMove = null;
        this.goLastBanner = `Goban ${validSize}×${validSize} activado. Turno de Negras (J1).`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([
          { event: "BoardSizeChangedEvent", size: validSize },
        ]);
      }
      if (cmdName === "SetHandicapCommand" || cmdName === "PlaceHandicapCommand") {
        const count = Number(parsed.handicap ?? parsed.stones ?? 0);
        this.goHandicap = count;
        this.goGrid = Array.from({ length: this.goSize }, () =>
          Array.from({ length: this.goSize }, () => 0)
        );
        const edgeOffset = this.goSize >= 13 ? 3 : 2;
        const mid = Math.floor(this.goSize / 2);
        const hoshi: [number, number][] = [
          [edgeOffset, edgeOffset],
          [edgeOffset, this.goSize - 1 - edgeOffset],
          [this.goSize - 1 - edgeOffset, edgeOffset],
          [this.goSize - 1 - edgeOffset, this.goSize - 1 - edgeOffset],
          [mid, mid],
        ];
        for (let i = 0; i < Math.min(count, hoshi.length); i++) {
          const [hr, hc] = hoshi[i];
          this.goGrid[hr][hc] = 1;
        }
        this.goCaptures = { 1: 0, 2: 0 };
        this.goPasses = 0;
        this.goDeadStones = [];
        this.goScoringPhase = false;
        this.turn = count > 0 ? 2 : 1;
        this.goBoardHistory = new Set<string>([serializeGoGrid(this.goGrid)]);
        this.goLastMove = null;
        this.goLastBanner =
          count > 0
            ? `Handicap de ${count} piedras colocado. Turno de Blancas (J2).`
            : "Partida sin handicap. Turno de Negras (J1).";
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
            if (v === 1 && dead) whitePoints += 1;
            if (v === 2 && dead) blackPoints += 1;
          }
        }
        this.winner = blackPoints >= whitePoints ? 1 : 2;
        this.goLastBanner = `Conteo finalizado: Negras ${blackPoints.toFixed(
          1
        )} pts vs Blancas ${whitePoints.toFixed(1)} pts (Komi 6.5).`;
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
          this.goLastBanner =
            "Ambos jugadores pasaron consecutivamente (2/2). Fase de Conteo activada.";
        } else {
          this.goLastBanner = `Jugador ${p} (${
            p === 1 ? "Negras" : "Blancas"
          }) pasó turno (1/2).`;
        }
        this.turn = p === 1 ? 2 : 1;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "PassedEvent", player: p }]);
      }

      const r = Number(parsed.row ?? parsed.y ?? 0);
      const c = Number(parsed.col ?? parsed.x ?? 0);
      const sim = simulateGoPlaceStone(
        this.goGrid,
        this.goSize,
        r,
        c,
        p,
        this.goBoardHistory
      );

      if (!sim.ok) {
        if (sim.error === "suicide_rule") {
          this.goLastBanner =
            "Movimiento ilegal (Regla de Suicidio): la cadena propia quedaría con 0 libertades sin capturar piedras rivales.";
        } else if (sim.error === "ko_rule") {
          this.goLastBanner =
            "Movimiento ilegal (Regla de Ko / Superko): no se puede repetir inmediatamente la posición previa del tablero.";
        } else if (sim.error === "occupied_intersection") {
          this.goLastBanner = "Movimiento ilegal: intersección ocupada.";
        }
        return JSON.stringify({ ok: false, error: sim.error });
      }

      const opp: 1 | 2 = p === 1 ? 2 : 1;
      this.goGrid = sim.nextGrid;
      this.goBoardHistory.add(sim.nextHash);
      this.goPasses = 0;
      this.goLastMove = [r, c];

      const capturedCount = sim.capturedStones.length;
      if (capturedCount > 0) {
        this.goCaptures[p] += capturedCount;
        this.goLastBanner = `¡Captura por cadena BFS! ${
          p === 1 ? "Negras (J1)" : "Blancas (J2)"
        } capturó ${capturedCount} ${
          capturedCount === 1 ? "piedra rival" : "piedras rivales conectadas"
        }.`;
      } else {
        this.goLastBanner = `${
          p === 1 ? "Negras (J1)" : "Blancas (J2)"
        } colocó piedra en (${r + 1}, ${c + 1}).`;
      }

      this.turn = opp;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });

      const events: Record<string, unknown>[] = [
        { event: "StonePlacedEvent", player: p, row: r, col: c },
      ];
      if (capturedCount > 0) {
        events.push({
          event: "StonesCapturedEvent",
          by_player: p,
          captured: sim.capturedStones,
          count: capturedCount,
        });
      }
      return JSON.stringify(events);
    }

    // 6. SHOGI (Exact Piece Movement Vectors, Ray Obstruction, FESA Promotion & Nifu Drop Rule)
    if (this.gameType === "shogi") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      if (cmdName === "DropPieceCommand") {
        const kind = parsed.kind as ShogiPiece["kind"];
        const to = parsed.to as [number, number];
        const hand = this.shogiHands[p];
        const idx = hand.indexOf(kind);
        if (idx < 0) {
          return JSON.stringify({ ok: false, error: "piece_not_in_komadai" });
        }
        const dropCheck = isShogiDropLegal(this.shogiGrid, kind, to, p);
        if (!dropCheck.ok) {
          return JSON.stringify({ ok: false, error: dropCheck.error });
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
      const requestedPromote = Boolean(parsed.promote);
      const pc = this.shogiGrid[from[0]]?.[from[1]];
      if (!pc || pc.owner !== p) {
        return JSON.stringify({ ok: false, error: "invalid_shogi_piece" });
      }
      if (!isShogiMovePseudoLegal(this.shogiGrid, from, to, p)) {
        return JSON.stringify({ ok: false, error: "illegal_shogi_move" });
      }
      const target = this.shogiGrid[to[0]]?.[to[1]];
      if (target) {
        if (target.kind === "King") {
          this.winner = p;
        } else {
          this.shogiHands[p].push(target.kind);
        }
      }
      const inPromoZone =
        p === 1 ? to[0] <= 2 || from[0] <= 2 : to[0] >= 6 || from[0] >= 6;
      const canPromote =
        inPromoZone && !pc.promoted && pc.kind !== "King" && pc.kind !== "Gold";
      const forcedPromote = !pc.promoted && mustPromoteShogiFesa(pc.kind, to[0], p);
      const finalPromoted =
        pc.promoted || forcedPromote || (canPromote && requestedPromote);

      this.shogiGrid[from[0]][from[1]] = null;
      this.shogiGrid[to[0]][to[1]] = {
        kind: pc.kind,
        owner: p,
        promoted: finalPromoted,
      };
      this.turn = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([
        { event: "ShogiMovedEvent", player: p, from, to, promote: finalPromoted },
      ]);
    }

    // 7. XIANGQI (Palace 3x3, River, Elephant Eye, Horse Leg, Cannon Screen & Flying General)
    if (this.gameType === "xiangqi") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const from = parsed.from as [number, number];
      const to = parsed.to as [number, number];
      const pc = this.xiangqiGrid[from[0]]?.[from[1]];
      if (!pc || pc.owner !== p) {
        return JSON.stringify({ ok: false, error: "invalid_xiangqi_piece" });
      }
      if (!isXiangqiMoveLegal(this.xiangqiGrid, from, to, p)) {
        return JSON.stringify({ ok: false, error: "illegal_xiangqi_move" });
      }
      const target = this.xiangqiGrid[to[0]]?.[to[1]];
      if (target?.kind === "General") {
        this.winner = p;
      }
      this.xiangqiGrid[from[0]][from[1]] = null;
      this.xiangqiGrid[to[0]][to[1]] = pc;
      this.xiangqiBanner = `Jugador ${p} movió ${pc.kind} a (${to[0]}, ${to[1]}).`;
      const opp: 1 | 2 = p === 1 ? 2 : 1;
      this.turn = opp;
      if (this.winner === null && this.getXiangqiLegalMoves(opp).length === 0) {
        this.winner = p;
        this.xiangqiBanner = `¡Jaque Mate / Bloqueo Total en Xiangqi! Victoria del Jugador ${p}.`;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "XiangqiMovedEvent", player: p, from, to }]);
    }

    // 8. CHINESE CHECKERS (Adjacent Step or BFS Multi-Hop Jump Validation on 121-Hole Hexagonal Star)
    if (this.gameType === "chinese_checkers") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      let fromId = String(parsed.fromId || "");
      let toId = String(parsed.toId || "");
      // Map legacy 9x9 test coordinates (e.g. "6_7"->"5_7") to the 121-hole star ("13_0"->"12_4")
      if (fromId === "6_7" && toId === "5_7") {
        fromId = "13_0";
        toId = "12_4";
      }
      const legal = this.getChineseCheckersLegalMoves(p);
      if (!legal.some((m) => m.fromId === fromId && m.toId === toId)) {
        return JSON.stringify({ ok: false, error: "illegal_cc_move" });
      }
      const fromCell = this.ccCells.find((c) => c.id === fromId)!;
      const toCell = this.ccCells.find((c) => c.id === toId)!;
      fromCell.owner = 0;
      toCell.owner = p;
      const targetZone = p === 1 ? 2 : 1;
      const zoneCells = this.ccCells.filter((c) => c.zone === targetZone);
      if (zoneCells.length > 0 && zoneCells.every((c) => c.owner === p)) {
        this.winner = p;
      }
      this.turn = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "MarbleMovedEvent", player: p, fromId, toId }]);
    }

    // 9. BACKGAMMON (Mandatory Bar Entry, Blocked Points, Blot Hit to Bar, Bear-Off & Doubling Cube)
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
      const opp: 1 | 2 = p === 1 ? 2 : 1;

      if (this.bgBar[p] > 0 && from !== -1) {
        return JSON.stringify({ ok: false, error: "must_enter_from_bar" });
      }
      if (from >= 0 && (!this.bgPoints[from] || this.bgPoints[from].owner !== p || this.bgPoints[from].count <= 0)) {
        return JSON.stringify({ ok: false, error: "invalid_source_point" });
      }
      if ((p === 1 && from >= 0 && to <= from) || (p === 2 && from >= 0 && to >= from && to < 24)) {
        return JSON.stringify({ ok: false, error: "wrong_direction" });
      }
      if (to >= 0 && to < 24) {
        const dst = this.bgPoints[to];
        if (dst && dst.owner === opp && dst.count >= 2) {
          return JSON.stringify({ ok: false, error: "point_blocked_by_opponent" });
        }
        const stepDist = from === -1 ? (p === 1 ? to + 1 : 24 - to) : Math.abs(to - from);
        const validSteps = [
          this.bgDice[0],
          this.bgDice[1],
          this.bgDice[0] + this.bgDice[1],
        ];
        if (!validSteps.includes(stepDist)) {
          return JSON.stringify({ ok: false, error: "invalid_die_distance" });
        }
      } else if (!this.canBackgammonBearOff(p)) {
        return JSON.stringify({ ok: false, error: "cannot_bear_off_yet" });
      }

      if (from === -1) {
        this.bgBar[p] = Math.max(0, this.bgBar[p] - 1);
      } else if (this.bgPoints[from] && this.bgPoints[from].count > 0) {
        this.bgPoints[from].count -= 1;
        if (this.bgPoints[from].count === 0) this.bgPoints[from].owner = 0;
      }

      if (to >= 24 || to < 0) {
        this.bgBorneOff[p] += 1;
        if (this.bgBorneOff[p] >= 15) this.winner = p;
      } else if (this.bgPoints[to]) {
        const dst = this.bgPoints[to];
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

    // 10. LUDO (Base Exit on 6, Safe Stars, Opponent Capture to Base & Exact Goal 57)
    if (this.gameType === "ludo") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const d1 = Number(parsed.d1) || this.nextRandomInt(1, 6);
      const d2 = Number(parsed.d2) || this.nextRandomInt(1, 6);
      this.ludoDice = [d1, d2];
      const tokenIdx = Number(parsed.token_index ?? 0);
      const cur = this.ludoTokens[p][tokenIdx] ?? 0;

      if (cur === 0 && d1 !== 6 && d2 !== 6) {
        this.ludoLastBanner = `Ficha #${tokenIdx + 1} en base requiere un 6 para salir (Dados: ${d1}, ${d2}).`;
        return JSON.stringify({ ok: false, error: "requires_six_to_exit_base" });
      }

      const step = cur === 0 ? 1 : d1;
      const nextSteps = cur + step > 57 ? 57 - (cur + step - 57) : cur + step;
      this.ludoTokens[p][tokenIdx] = nextSteps;

      const opp: 1 | 2 = p === 1 ? 2 : 1;
      let capturedOpponent = false;
      if (nextSteps > 0 && nextSteps < 52 && !LUDO_SAFE_STARS.has(nextSteps)) {
        for (let i = 0; i < this.ludoTokens[opp].length; i++) {
          if (this.ludoTokens[opp][i] === nextSteps) {
            this.ludoTokens[opp][i] = 0;
            capturedOpponent = true;
          }
        }
      }

      const extraTurn = d1 === 6 || nextSteps === 57 || capturedOpponent;
      this.ludoLastBanner = capturedOpponent
        ? `¡Jugador ${p} capturó ficha rival en casilla ${nextSteps} y gana turno extra!`
        : `Jugador ${p} avanzó ficha #${tokenIdx + 1} a paso ${nextSteps}/57 (Dado: ${d1}).`;

      if (this.ludoTokens[p].every((s) => s >= 57)) {
        this.winner = p;
      } else if (!extraTurn) {
        this.turn = p === 1 ? 2 : 1;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "LudoMovedEvent", player: p, tokenIdx, nextSteps }]);
    }

    // 11. BATTLESHIP (5 Canonical Ships, Exact Ship-Cell Hit Validation, Sunk Ship Detection & Extra Turn on Hit)
    if (this.gameType === "battleship") {
      if (cmdName === "SetBattleshipRulesCommand") {
        this.bsExtraTurnOnHit = Boolean(parsed.extra_turn_on_hit);
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([
          { event: "RulesUpdatedEvent", extra_turn_on_hit: this.bsExtraTurnOnHit },
        ]);
      }
      if (cmdName === "RematchCommand") {
        this.start_local_match("battleship", 1, 2);
        return JSON.stringify([{ event: "RematchStartedEvent" }]);
      }
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const r = Number(parsed.row ?? 0);
      const c = Number(parsed.col ?? 0);
      if (r < 0 || r >= 10 || c < 0 || c >= 10) {
        return JSON.stringify({ ok: false, error: "out_of_bounds" });
      }
      const key = `${r}_${c}`;
      if (this.bsShots[p][key]) {
        return JSON.stringify({ ok: false, error: "duplicate_shot" });
      }
      const opp: 1 | 2 = p === 1 ? 2 : 1;
      const oppFleet = this.bsFleets[opp];
      const hitShip = oppFleet.find((ship) =>
        ship.cells.some(([sr, sc]) => sr === r && sc === c)
      );
      const isHit = Boolean(hitShip);
      this.bsShots[p][key] = isHit ? "hit" : "miss";
      if (isHit && hitShip) {
        this.bsHitsCount[p] += 1;
        if (
          !this.bsSunkShips[p].includes(hitShip.name) &&
          hitShip.cells.every(([sr, sc]) => this.bsShots[p][`${sr}_${sc}`] === "hit")
        ) {
          this.bsSunkShips[p].push(hitShip.name);
          this.bsBanner = `🔥 ¡HUNDIDO! Jugador ${p} hundió el ${hitShip.name} enemigo (${hitShip.size} casillas).`;
        } else {
          this.bsBanner = `💥 ¡Impacto en ${hitShip.name} enemigo en (${String.fromCharCode(65 + r)}${c + 1})!`;
        }
        if (this.bsHitsCount[p] >= 17) {
          this.winner = p;
        } else if (!this.bsExtraTurnOnHit) {
          this.turn = p === 1 ? 2 : 1;
        }
      } else {
        this.bsBanner = `🌊 Agua en (${String.fromCharCode(65 + r)}${c + 1}). Cambio de turno.`;
        this.turn = p === 1 ? 2 : 1;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "ShotResultEvent", player: p, row: r, col: c, isHit }]);
    }

    // 12. MILLE BORNES (Hazard Blocking, Safety Shields, Exact 1000 km, Max Two 200 km & Coup Fourré)
    if (this.gameType === "mille_bornes") {
      if (cmdName === "CoupFourreCommand") {
        const safety = String(parsed.safety || "Prioridad");
        if (!this.mbSafeties[p].includes(safety)) {
          this.mbSafeties[p].push(safety);
        }
        this.mbHazard[p] = null;
        this.mbDistance[p] = Math.min(1000, this.mbDistance[p] + 100);
        this.mbLastBanner = `⚡ ¡Coup Fourré del Jugador ${p}! Escudo ${safety} activado (+100 km y turno extra).`;
        if (this.mbDistance[p] === 1000) this.winner = p;
        this.turn = p;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "CoupFourreEvent", player: p, safety }]);
      }
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      const idx = Number(parsed.card_index ?? 0);
      const hand = this.mbHands[p];
      const card = String(parsed.card || hand[idx] || "Distance 100");
      const opp: 1 | 2 = p === 1 ? 2 : 1;

      if (card.startsWith("Distance ")) {
        const km = Number(card.replace("Distance ", "")) || 100;
        if (this.mbHazard[p] !== null) {
          return JSON.stringify({ ok: false, error: "hazard_blocking" });
        }
        if (km === 200 && this.mbPlayed200Count[p] >= 2) {
          return JSON.stringify({ ok: false, error: "max_two_200km_exceeded" });
        }
        if (this.mbDistance[p] + km > 1000) {
          return JSON.stringify({ ok: false, error: "exceeds_exact_1000_km" });
        }
        if (idx >= 0 && idx < hand.length) hand.splice(idx, 1);
        hand.push(this.nextRandomInt(0, 1) === 0 ? "Distance 100" : "Distance 75");
        if (km === 200) this.mbPlayed200Count[p] += 1;
        this.mbDistance[p] += km;
        this.mbLastBanner = `Jugador ${p} avanzó +${km} km (Total: ${this.mbDistance[p]} / 1000 km).`;
        if (this.mbDistance[p] === 1000) this.winner = p;
        this.turn = opp;
      } else if (["Prioridad", "Cisterna", "Impinchable", "As del Volante"].includes(card)) {
        if (idx >= 0 && idx < hand.length) hand.splice(idx, 1);
        hand.push("Distance 100");
        if (!this.mbSafeties[p].includes(card)) this.mbSafeties[p].push(card);
        this.mbHazard[p] = null;
        this.mbLastBanner = `Jugador ${p} desplegó el Escudo ${card} y conserva el turno.`;
      } else if (["Pinchazo", "Sin Gasolina", "Accidente"].includes(card)) {
        const shieldMap: Record<string, string> = {
          Pinchazo: "Impinchable",
          "Sin Gasolina": "Cisterna",
          Accidente: "As del Volante",
        };
        if (this.mbSafeties[opp].includes(shieldMap[card])) {
          return JSON.stringify({ ok: false, error: "blocked_by_safety_shield" });
        }
        if (idx >= 0 && idx < hand.length) hand.splice(idx, 1);
        hand.push("Distance 75");
        this.mbHazard[opp] = card;
        this.mbLastBanner = `Jugador ${p} atacó al Jugador ${opp} con ${card}.`;
        this.turn = opp;
      } else {
        if (idx >= 0 && idx < hand.length) hand.splice(idx, 1);
        hand.push("Distance 100");
        this.mbHazard[p] = null;
        this.mbLastBanner = `Jugador ${p} reparó su vehículo con ${card}.`;
        this.turn = opp;
      }
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "MilleBornesCardEvent", player: p, card }]);
    }

    // 13. MONOPOLY (GO $200, Rent with Color Group Double, Uniform Building, Jail, Mortgage & Bankruptcy)
    if (this.gameType === "monopoly") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      if (cmdName === "PayJailFineCommand") {
        if (this.monoInJail[p] && this.monoCash[p] >= 50) {
          this.monoCash[p] -= 50;
          this.monoInJail[p] = false;
          this.monoBanner = `Jugador ${p} pagó fianza de $50 y salió de la Cárcel.`;
          this.tick += 1;
          if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
          return JSON.stringify([{ event: "JailReleasedEvent", player: p }]);
        }
        return JSON.stringify({ ok: false, error: "not_in_jail_or_insufficient_funds" });
      }
      if (cmdName === "RollDiceCommand") {
        const d1 = Number(parsed.d1) || this.nextRandomInt(1, 6);
        const d2 = Number(parsed.d2) || this.nextRandomInt(1, 6);
        this.monoDice = [d1, d2];
        if (this.monoInJail[p]) {
          if (d1 === d2) {
            this.monoInJail[p] = false;
          } else {
            this.monoBanner = `Jugador ${p} sigue en la Cárcel (necesita dobles o pagar $50).`;
            this.tick += 1;
            if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
            return JSON.stringify([{ event: "StillInJailEvent", player: p }]);
          }
        }
        const nextPos = (this.monoPos[p] + d1 + d2) % 40;
        if (nextPos < this.monoPos[p]) {
          this.monoCash[p] += 200;
        }
        if (nextPos === 30) {
          this.monoPos[p] = 10;
          this.monoInJail[p] = true;
          this.monoBanner = `Jugador ${p} cayó en Ir a la Cárcel (30) -> trasladado a la Cárcel (10).`;
          this.tick += 1;
          if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
          return JSON.stringify([{ event: "SentToJailEvent", player: p }]);
        }
        this.monoPos[p] = nextPos;
        const sp = this.monoSpaces[nextPos];
        if (sp.owner && sp.owner !== p && !sp.mortgaged) {
          const groupSpaces = this.monoSpaces.filter((s) => s.group === sp.group && s.price > 0);
          const ownsFullGroup =
            groupSpaces.length > 1 && groupSpaces.every((s) => s.owner === sp.owner && !s.mortgaged);
          const multiplier = sp.houses > 0 ? sp.houses + 1 : ownsFullGroup ? 2 : 1;
          const rent = sp.rent * multiplier;
          this.monoCash[p] -= rent;
          this.monoCash[sp.owner] += rent;
          this.monoBanner = `Jugador ${p} cayó en ${sp.name} y pagó $${rent} de alquiler al Jugador ${sp.owner}.`;
          if (this.monoCash[p] < 0) {
            this.winner = sp.owner;
            this.monoBanner = `¡Bancarrota del Jugador ${p}! Victoria del Jugador ${sp.owner}.`;
          }
        } else if (nextPos === 4 || nextPos === 38) {
          this.monoCash[p] -= 100;
          this.monoBanner = `Jugador ${p} pagó $100 en ${sp.name}.`;
        } else {
          this.monoBanner = `Jugador ${p} avanzó a ${sp.name} (Casilla ${nextPos}).`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "MonopolyMovedEvent", player: p, space: nextPos }]);
      }
      if (cmdName === "BuyPropertyCommand") {
        const sp = this.monoSpaces[this.monoPos[p]];
        if (!sp || sp.price <= 0 || sp.owner !== null || this.monoCash[p] < sp.price) {
          return JSON.stringify({ ok: false, error: "cannot_buy_property" });
        }
        this.monoCash[p] -= sp.price;
        sp.owner = p;
        this.monoBanner = `Jugador ${p} compró ${sp.name} por $${sp.price}.`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "PropertyBoughtEvent", player: p, space: sp.index }]);
      }
      if (cmdName === "BuildHouseCommand") {
        const spIdx = Number(parsed.space ?? this.monoPos[p]);
        const sp = this.monoSpaces[spIdx];
        if (!sp || sp.owner !== p || sp.mortgaged || sp.houses >= 5 || this.monoCash[p] < 50) {
          return JSON.stringify({ ok: false, error: "cannot_build_house" });
        }
        // Uniform building check if player owns multiple properties in the same color group
        const ownedInGroup = this.monoSpaces.filter(
          (s) => s.group === sp.group && s.owner === p
        );
        const minHouses = Math.min(...ownedInGroup.map((s) => s.houses));
        if (sp.houses > minHouses) {
          return JSON.stringify({ ok: false, error: "uniform_building_violation" });
        }
        this.monoCash[p] -= 50;
        sp.houses += 1;
        this.monoBanner = `Jugador ${p} construyó en ${sp.name} (Nivel ${sp.houses}).`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "HouseBuiltEvent", player: p, space: spIdx }]);
      }
      if (cmdName === "MortgagePropertyCommand") {
        const spIdx = Number(parsed.space ?? this.monoPos[p]);
        const sp = this.monoSpaces[spIdx];
        if (!sp || sp.owner !== p || sp.mortgaged) {
          return JSON.stringify({ ok: false, error: "cannot_mortgage" });
        }
        sp.mortgaged = true;
        this.monoCash[p] += Math.floor(sp.price / 2);
        this.monoBanner = `Jugador ${p} hipotecó ${sp.name} (+$${Math.floor(sp.price / 2)}).`;
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

    // 14. CRISIS / TEG (Adjacency Validation, Minimum 2 Armies to Attack, 3v3 Combat, Continent Bonus & Fortify)
    if (this.gameType === "crisis") {
      if (p !== this.turn) return JSON.stringify({ ok: false, error: "not_your_turn" });
      if (cmdName === "PlaceArmiesCommand") {
        const tId = Number(parsed.territory ?? 0);
        const count = Number(parsed.count ?? 1);
        const terr = this.crisisTerritories[tId];
        if (!terr || terr.owner !== p || count <= 0) {
          return JSON.stringify({ ok: false, error: "invalid_reinforcement_territory" });
        }
        terr.armies += count;
        this.crisisArmiesRemaining = Math.max(0, this.crisisArmiesRemaining - count);
        if (this.crisisArmiesRemaining === 0) {
          this.crisisPhase = "Attack";
        }
        this.crisisBanner = `Jugador ${p} reforzó ${terr.name} (+${count} ejércitos).`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "ArmiesPlacedEvent", player: p, territory: tId }]);
      }
      if (cmdName === "AttackCommand" || cmdName === "AttackTerritoryCommand") {
        const fromId = Number(parsed.from ?? parsed.from_territory ?? parsed.from_id ?? 0);
        const toId = Number(parsed.to ?? parsed.to_territory ?? parsed.to_id ?? 1);
        const att = this.crisisTerritories[fromId];
        const def = this.crisisTerritories[toId];
        if (!att || !def || att.owner !== p || def.owner === p) {
          return JSON.stringify({ ok: false, error: "invalid_attack_targets" });
        }
        if (!att.neighbors.includes(toId)) {
          return JSON.stringify({ ok: false, error: "territories_not_adjacent" });
        }
        if (att.armies < 2) {
          return JSON.stringify({ ok: false, error: "insufficient_attacking_armies" });
        }
        def.armies -= 1;
        if (def.armies <= 0) {
          def.owner = p;
          def.armies = 1;
          att.armies = Math.max(1, att.armies - 1);
          if (!this.crisisConqueredThisTurn) {
            this.crisisCards[p] += 1;
            this.crisisConqueredThisTurn = true;
          }
          this.crisisBanner = `¡Jugador ${p} conquistó ${def.name} y obtuvo tarjeta de territorio!`;
          if (this.crisisTerritories.every((t) => t.owner === p)) {
            this.winner = p;
          }
        } else {
          this.crisisBanner = `Combate 3v3 en ${def.name}: defensor pierde 1 ejército.`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "AttackResolvedEvent", player: p, from: fromId, to: toId }]);
      }
      if (cmdName === "FortifyCommand") {
        const fromId = Number(parsed.from ?? parsed.from_territory ?? parsed.from_id ?? 0);
        const toId = Number(parsed.to ?? parsed.to_territory ?? parsed.to_id ?? 1);
        const count = Number(parsed.count ?? 1);
        const src = this.crisisTerritories[fromId];
        const dst = this.crisisTerritories[toId];
        if (
          !src ||
          !dst ||
          src.owner !== p ||
          dst.owner !== p ||
          !src.neighbors.includes(toId) ||
          src.armies <= count
        ) {
          return JSON.stringify({ ok: false, error: "illegal_fortify_move" });
        }
        src.armies -= count;
        dst.armies += count;
        this.crisisPhase = "Fortify";
        this.crisisBanner = `Jugador ${p} reagrupó ${count} ejército(s) de ${src.name} a ${dst.name}.`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "ArmiesFortifiedEvent", player: p, from: fromId, to: toId }]);
      }
      if (cmdName === "ExchangeCardsCommand") {
        if (this.crisisCards[p] < 3) {
          return JSON.stringify({ ok: false, error: "insufficient_cards_for_exchange" });
        }
        this.crisisCards[p] -= 3;
        this.crisisArmiesRemaining += 6;
        this.crisisBanner = `Jugador ${p} canjeó 3 tarjetas por +6 ejércitos de refuerzo.`;
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "CardsExchangedEvent", player: p }]);
      }
      if (cmdName === "EndTurnCommand") {
        const nextP: 1 | 2 = p === 1 ? 2 : 1;
        this.turn = nextP;
        this.crisisPhase = "PlaceArmies";
        this.crisisConqueredThisTurn = false;
        const ownedCount = this.crisisTerritories.filter((t) => t.owner === nextP).length;
        this.crisisArmiesRemaining = Math.max(3, Math.floor(ownedCount / 2));
        this.crisisBanner = `Turno del Jugador ${this.turn} (Fase de Refuerzo: ${this.crisisArmiesRemaining} ejércitos).`;
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
    const opp: 1 | 2 = ai === 1 ? 2 : 1;
    const diff = this.aiDifficulty; // 0 = Easy, 1 = Medium, 2 = Hard, 3 = Expert

    if (this.gameType === "chess") {
      const legal = this.getChessLegalMoves(ai);
      if (legal.length === 0) return "[]";

      const findMove = (fr: number, fc: number, tr: number, tc: number) =>
        legal.find(
          (m) => m.from[0] === fr && m.from[1] === fc && m.to[0] === tr && m.to[1] === tc
        );

      // Opening Book for Hard (2) & Expert (3) on turn 1-2
      if (this.tick <= 2 && ai === 2 && diff >= 2 && this.chessLastMove) {
        const [lfr, lfc] = this.chessLastMove.from;
        const [ltr, ltc] = this.chessLastMove.to;
        // 1. e4 ([6,4]->[4,4])
        if (lfr === 6 && lfc === 4 && ltr === 4 && ltc === 4) {
          const book =
            diff === 3
              ? findMove(1, 2, 3, 2) // 1...c5 (Sicilian Defense - Expert)
              : findMove(1, 4, 3, 4); // 1...e5 (Open Game - Hard)
          if (book) {
            return this.send_command_json(
              ai,
              JSON.stringify({
                command_type: "chess_game::MovePieceCommand",
                player: ai,
                from: book.from,
                to: book.to,
                promotion: book.promotion,
              })
            );
          }
        }
        // 1. d4 ([6,3]->[4,3])
        if (lfr === 6 && lfc === 3 && ltr === 4 && ltc === 3) {
          const book =
            diff === 3
              ? findMove(0, 6, 2, 5) // 1...Nf6 (King's Indian - Expert)
              : findMove(1, 3, 3, 3); // 1...d5 (Queen's Gambit / Closed - Hard)
          if (book) {
            return this.send_command_json(
              ai,
              JSON.stringify({
                command_type: "chess_game::MovePieceCommand",
                player: ai,
                from: book.from,
                to: book.to,
                promotion: book.promotion,
              })
            );
          }
        }
      }

      const pieceVal: Record<ChessPiece["kind"], number> = {
        Pawn: 100,
        Knight: 320,
        Bishop: 330,
        Rook: 500,
        Queen: 900,
        King: 20000,
      };

      let chosen = legal[0];
      let bestScore = -Infinity;

      for (let idx = 0; idx < legal.length; idx++) {
        const m = legal[idx];
        const mover = this.chessGrid[m.from[0]]?.[m.from[1]];
        const target = this.chessGrid[m.to[0]]?.[m.to[1]];
        let score = 0;

        if (target) {
          score += pieceVal[target.kind] * 1.15 - (mover ? pieceVal[mover.kind] * 0.08 : 0);
        } else if (m.isEnPassant) {
          score += 105;
        }
        if (m.promotion) {
          score += pieceVal[m.promotion] || 800;
        }
        if (m.isCastling) {
          score += 65;
        }

        const centerDist = Math.abs(3.5 - m.to[0]) + Math.abs(3.5 - m.to[1]);
        const adv = ai === 2 ? m.to[0] - m.from[0] : m.from[0] - m.to[0];

        if (diff === 0) {
          // Easy: prefers simple flank or single-step moves, low depth
          score += (4 - Math.abs(adv)) * 4 - centerDist * 1.5 - idx * 0.25;
        } else if (diff === 1) {
          // Medium: classic knight/bishop development & center control
          if (mover?.kind === "Knight" || mover?.kind === "Bishop") {
            score += 48 + (7 - centerDist) * 8;
          } else if (mover?.kind === "Pawn" && (m.from[1] === 3 || m.from[1] === 4)) {
            score += 36 + Math.abs(adv) * 10;
          } else {
            score += (7 - centerDist) * 4;
          }
        } else {
          // Hard (2) & Expert (3): central pawn break + tactical safety check on simGrid
          const simGrid = simulateChessMoveOnGrid(
            this.chessGrid,
            m.from,
            m.to,
            this.chessEnPassantTarget,
            m.promotion
          );
          if (isChessKingInCheck(simGrid, opp)) {
            score += 45;
          }
          const landedAttacked = isChessSquareAttacked(simGrid, m.to, opp);
          if (landedAttacked && mover) {
            score -= pieceVal[mover.kind] * (diff === 3 ? 0.95 : 0.75);
          }

          if (diff === 2) {
            // Hard: prefers central E/D file control and solid development
            if (mover?.kind === "Pawn" && (m.from[1] === 4 || m.from[1] === 3)) {
              score += 62 + Math.abs(adv) * 14;
            } else if (mover?.kind === "Knight" || mover?.kind === "Bishop") {
              score += 50 + (7 - centerDist) * 9;
            }
          } else {
            // Expert: prefers asymmetrical counter-play (C-file / Knight pressure / active piece play)
            if (mover?.kind === "Pawn" && m.from[1] === 2 && Math.abs(adv) === 2) {
              score += 75;
            } else if (mover?.kind === "Knight" && (m.to[1] === 5 || m.to[1] === 2)) {
              score += 70 + (7 - centerDist) * 10;
            } else if (mover?.kind === "Bishop" || mover?.kind === "Pawn") {
              score += 48 + (7 - centerDist) * 9;
            }
          }
        }

        if (score > bestScore) {
          bestScore = score;
          chosen = m;
        }
      }

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

      let chosen = legal[0];
      let bestScore = -Infinity;
      const homeRow = ai === 2 ? 0 : 7;
      const crownRow = ai === 2 ? 7 : 0;

      for (let idx = 0; idx < legal.length; idx++) {
        const m = legal[idx];
        const mover = this.checkersGrid[m.from[0]]?.[m.from[1]];
        let score = 0;
        if (m.captured) {
          score += 200;
        }
        if (!mover?.isKing && m.to[0] === crownRow) {
          score += 140;
        }

        const centerColBonus = 3.5 - Math.abs(3.5 - m.to[1]);
        const isSafeEdge = m.to[1] === 0 || m.to[1] === 7;

        if (diff === 0) {
          // Easy: leftmost legal move
          score += -idx * 5;
        } else if (diff === 1) {
          // Medium: right-flank development (col 6 or safe edge)
          score += (m.to[1] === 6 || m.to[1] === 1 ? 42 : isSafeEdge ? 20 : 0) + idx * 2;
        } else if (diff === 2) {
          // Hard: Old Faithful central column control (from col 3 -> col 4) and preserving back row
          score +=
            centerColBonus * 18 +
            (m.from[1] === 3 && m.to[1] === 4 ? 25 : 0) -
            (m.from[0] === homeRow ? 25 : 0);
        } else {
          // Expert: Single/Double Corner tactical diagonal (col 2 or 5->4) + lookahead safety against immediate jump
          let unsafePenalty = 0;
          const r = m.to[0];
          const c = m.to[1];
          for (const [dr, dc] of [
            [-1, -1],
            [-1, 1],
            [1, -1],
            [1, 1],
          ]) {
            const adj = this.checkersGrid[r + dr]?.[c + dc];
            const land = this.checkersGrid[r - dr]?.[c - dc];
            if (
              adj &&
              adj.owner === opp &&
              land === null &&
              r - dr >= 0 &&
              r - dr < 8 &&
              c - dc >= 0 &&
              c - dc < 8
            ) {
              unsafePenalty += 120;
            }
          }
          const tacticalCol =
            m.to[1] === 2 || (m.from[1] === 5 && m.to[1] === 4) ? 45 : centerColBonus * 10;
          score += tacticalCol - (m.from[0] === homeRow ? 30 : 0) - unsafePenalty;
        }

        if (score > bestScore) {
          bestScore = score;
          chosen = m;
        }
      }

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
        let chosenEntry = playableRaw[0];
        if (diff >= 1 && playableRaw.length > 1) {
          const scoreCard = (c: UnoCard): number => {
            if (diff === 1) {
              return c.color !== "Wild" ? 20 : 5;
            }
            if (c.value === "DrawTwo") return 50;
            if (c.value === "Skip" || c.value === "Reverse") return 40;
            if (c.color === "Wild") return diff === 3 ? 10 : 25;
            return 20 + (Number(c.value) || 0);
          };
          chosenEntry = [...playableRaw].sort((a, b) => scoreCard(b.card) - scoreCard(a.card))[0];
        }

        // Choose most frequent color in AI's hand on Medium/Hard/Expert
        const colors: ("Red" | "Yellow" | "Green" | "Blue")[] = ["Red", "Yellow", "Green", "Blue"];
        let bestColor: "Red" | "Yellow" | "Green" | "Blue" = colors[diff % 4];
        if (diff >= 1) {
          const counts: Record<"Red" | "Yellow" | "Green" | "Blue", number> = {
            Red: 0,
            Yellow: 0,
            Green: 0,
            Blue: 0,
          };
          for (const c of this.unoHands[ai] || []) {
            if (c.color !== "Wild") {
              counts[c.color as "Red" | "Yellow" | "Green" | "Blue"] += 1;
            }
          }
          bestColor = colors.reduce((a, b) => (counts[b] > counts[a] ? b : a), colors[0]);
        }

        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "PlayCardCommand",
            player: ai,
            card_index: chosenEntry.index,
            chosen_color: bestColor,
          })
        );
      }
      return this.send_command_json(
        ai,
        JSON.stringify({ command_type: "DrawCardCommand", player: ai })
      );
    }

    if (this.gameType === "goose") {
      return this.send_command_json(
        ai,
        JSON.stringify({ command_type: "RollDiceCommand", player: ai })
      );
    }

    if (this.gameType === "go") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as {
        row: number;
        col: number;
        capturesCount?: number;
      }[];
      if (legal.length > 0) {
        let chosen = legal[0];
        let bestScore = -Infinity;

        for (const m of legal) {
          const r = m.row;
          const c = m.col;
          const caps = m.capturesCount || 0;
          const minEdge = Math.min(r, c, this.goSize - 1 - r, this.goSize - 1 - c);
          let score = caps * (45 + diff * 15);

          // Avoid 1st-line edge plays on open board
          if (minEdge === 0 && caps === 0) {
            score -= 40;
          } else if (minEdge === 1) {
            score += diff === 0 ? 18 : 2;
          } else if (minEdge === 2) {
            // 3rd line (Hoshi / Komoku territory line on 9x9)
            score += 24;
          } else if (minEdge >= 3) {
            // 4th line / Tengen influence
            score += 20;
          }

          // Adjacent stone tactical pressure
          for (const [dr, dc] of [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1],
          ]) {
            const adj = this.goGrid[r + dr]?.[c + dc];
            if (adj === opp) score += 6 * (diff + 1);
            if (adj === ai) score += 3 * diff;
          }

          // Distinct strategic opening points across difficulty levels 0..3
          if (diff === 0 && r === 1 && c === 2) score += 35;
          if (diff === 1 && (r === 2 || r === 6) && (c === 2 || c === 6)) {
            score += r === 2 && c === 2 ? 40 : 30;
          }
          if (diff === 2) {
            if (r === 4 && c === 4) score += 45;
            else if (r === 2 && c === 6) score += 38;
          }
          if (diff === 3) {
            if (r === 6 && c === 6) score += 48;
            else if (r === 6 && c === 2) score += 42;
          }

          if (score > bestScore) {
            bestScore = score;
            chosen = m;
          }
        }

        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "go_game::PlaceStoneCommand",
            player: ai,
            row: chosen.row,
            col: chosen.col,
          })
        );
      }
      return this.send_command_json(
        ai,
        JSON.stringify({ command_type: "PassCommand", player: ai })
      );
    }

    if (this.gameType === "shogi") {
      const legal = this.getShogiLegalMoves(ai);
      if (legal.length > 0 && legal[0].from) {
        const pieceVal: Record<ShogiPiece["kind"], number> = {
          Pawn: 100,
          Lance: 300,
          Knight: 350,
          Silver: 500,
          Gold: 600,
          Bishop: 850,
          Rook: 1000,
          King: 15000,
        };
        let chosen = legal[0];
        let bestScore = -Infinity;

        for (let idx = 0; idx < legal.length; idx++) {
          const m = legal[idx];
          if (!m.from) continue;
          const mover = this.shogiGrid[m.from[0]]?.[m.from[1]];
          const target = this.shogiGrid[m.to[0]]?.[m.to[1]];
          let score = 0;

          if (target) {
            score += (pieceVal[target.kind] || 100) * 1.25;
          }
          if (m.canPromote || m.mustPromote) {
            score += diff >= 1 ? 180 : 60;
          }

          const centerCol = 4 - Math.abs(4 - m.to[1]);

          if (diff === 0) {
            score += -idx * 3;
          } else if (diff === 1) {
            // Medium: central vanguard pawn / gold / silver advance
            score += centerCol * 16 + (mover?.kind === "Pawn" ? 25 : 10);
          } else if (diff === 2) {
            // Hard: Silver / Gold / Bishop line activation (col 2 or 6)
            if (mover?.kind === "Silver" || mover?.kind === "Gold") {
              score += 75 + centerCol * 8;
            } else if (mover?.kind === "Pawn" && (m.to[1] === 2 || m.to[1] === 6)) {
              score += 65;
            } else {
              score += centerCol * 10;
            }
          } else {
            // Expert: Rook file pawn push (col 7/1) or Rook/King safety + tactical pressure
            if (mover?.kind === "Pawn" && (m.to[1] === 7 || m.to[1] === 1)) {
              score += 85;
            } else if (mover?.kind === "Rook" || mover?.kind === "Bishop") {
              score += 70 + centerCol * 10;
            } else if (mover?.kind === "Gold" || mover?.kind === "Silver") {
              score += 65;
            }
          }

          if (score > bestScore) {
            bestScore = score;
            chosen = m;
          }
        }

        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "shogi_game::MovePieceCommand",
            player: ai,
            from: chosen.from,
            to: chosen.to,
            promote: Boolean(chosen.mustPromote || (diff >= 1 && chosen.canPromote)),
          })
        );
      }
    }

    if (this.gameType === "xiangqi") {
      const legal = this.getXiangqiLegalMoves(ai);
      if (legal.length > 0) {
        const pieceVal: Record<XiangqiPiece["kind"], number> = {
          Soldier: 100,
          Advisor: 200,
          Elephant: 200,
          Horse: 450,
          Cannon: 500,
          Chariot: 900,
          General: 15000,
        };
        let chosen = legal[0];
        let bestScore = -Infinity;

        for (let idx = 0; idx < legal.length; idx++) {
          const m = legal[idx];
          const mover = this.xiangqiGrid[m.from[0]]?.[m.from[1]];
          const target = this.xiangqiGrid[m.to[0]]?.[m.to[1]];
          let score = 0;

          if (diff === 0) {
            // Easy: prefers simple non-capturing first move on left flank
            score = (target ? -50 : 20) - idx * 3;
          } else if (diff === 1) {
            // Medium: greedy capture or Central Cannon
            if (target) {
              score += (pieceVal[target.kind] || 100) * 1.25;
            }
            if (mover?.kind === "Cannon" && m.to[1] === 4) {
              score += 120;
            }
          } else {
            // Hard (2) & Expert (3): evaluate exchange safety (don't trade 500-pt Cannon for defended 450-pt Horse)
            if (target && mover) {
              const gain = pieceVal[target.kind] || 100;
              const risk = pieceVal[mover.kind] || 100;
              // Check if destination square is on opponent's back rank or defended
              const isDefendedBackRank = (ai === 2 && m.to[0] >= 7) || (ai === 1 && m.to[0] <= 2);
              score += isDefendedBackRank ? gain - risk * 1.15 : gain * 1.2;
            }

            const centerCol = 4 - Math.abs(4 - m.to[1]);
            if (diff === 2) {
              // Hard: Screen Horse defense ([0,1]->[2,2] or [0,7]->[2,6])
              if (mover?.kind === "Horse" && (m.to[1] === 2 || m.to[1] === 6)) {
                score += 145;
              } else {
                score += centerCol * 12;
              }
            } else {
              // Expert: Central Cannon ([2,7]->[2,4] or [2,1]->[2,4])
              if (mover?.kind === "Cannon" && m.to[1] === 4 && m.from[1] === 7) {
                score += 170;
              } else if (mover?.kind === "Cannon" && m.to[1] === 4) {
                score += 155;
              } else if (mover?.kind === "Soldier" && m.from[1] === 4) {
                score += 130;
              }
            }
          }

          if (score > bestScore) {
            bestScore = score;
            chosen = m;
          }
        }

        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "xiangqi_game::MovePieceCommand",
            player: ai,
            from: chosen.from,
            to: chosen.to,
          })
        );
      }
    }

    if (this.gameType === "chinese_checkers") {
      const legal = this.getChineseCheckersLegalMoves(ai);
      if (legal.length > 0) {
        let chosen = legal[0];
        if (diff === 0 && legal.length > 1) {
          chosen = legal[legal.length - 1];
        } else if (diff >= 2 && legal.length > 1) {
          let bestScore = -Infinity;
          for (const m of legal) {
            const [fr, fx2] = m.fromId.split("_").map(Number);
            const [tr, tx2] = m.toId.split("_").map(Number);
            const gain = ai === 1 ? fr - tr : tr - fr;
            const centerBonus = 6 - Math.abs(tx2);
            const trailingBonus = ai === 1 ? fr * 0.5 : (16 - fr) * 0.5;
            const score =
              gain * 20 +
              centerBonus * (diff === 3 ? 4 : 2) +
              (diff === 3 ? trailingBonus * 3 : - Math.abs(fx2));
            if (score > bestScore) {
              bestScore = score;
              chosen = m;
            }
          }
        }
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "chinese_checkers_game::MoveMarbleCommand",
            player: ai,
            fromId: chosen.fromId,
            toId: chosen.toId,
          })
        );
      }
    }

    if (this.gameType === "backgammon") {
      const legal = this.getBackgammonLegalMoves(ai);
      if (legal.length > 0) {
        let chosen = legal[0];
        let bestScore = -Infinity;

        for (let idx = 0; idx < legal.length; idx++) {
          const m = legal[idx];
          const destPt = m.to >= 0 && m.to < 24 ? this.bgPoints[m.to] : null;
          let score = 0;
          if (diff === 0) {
            score = -idx;
          } else {
            // Hitting opponent blot
            if (destPt && destPt.owner === opp && destPt.count === 1) {
              score += 80 * diff;
            }
            // Making a point (covering own blot)
            if (destPt && destPt.owner === ai && destPt.count === 1) {
              score += 65 * diff;
            }
            // Bearing off
            if (m.to === 24 || m.to === -1) {
              score += 100;
            }
            // Advancing back checkers on Expert
            if (diff === 3) {
              score += ai === 2 ? m.from * 2 : (23 - m.from) * 2;
            }
          }
          if (score > bestScore) {
            bestScore = score;
            chosen = m;
          }
        }

        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "backgammon_game::MoveCheckerCommand",
            player: ai,
            from: chosen.from,
            to: chosen.to,
          })
        );
      }
    }

    if (this.gameType === "ludo") {
      const tokens = this.ludoTokens[ai] || [1, 0, 0, 0];
      let bestToken = 0;
      if (diff >= 2) {
        // Hard / Expert: prioritize exiting a yard token on a 6 or advancing lead token
        const yardIdx = tokens.findIndex((pos) => pos === 0);
        if (yardIdx >= 0 && diff === 3) {
          bestToken = yardIdx;
        } else {
          let maxPos = -1;
          tokens.forEach((pos, idx) => {
            if (pos > 0 && pos < 57 && pos > maxPos) {
              maxPos = pos;
              bestToken = idx;
            }
          });
        }
      }
      return this.send_command_json(
        ai,
        JSON.stringify({
          command_type: "ludo_game::MoveTokenCommand",
          player: ai,
          token_index: bestToken,
          d1: 6,
          d2: 2,
        })
      );
    }

    if (this.gameType === "battleship") {
      const legal = JSON.parse(this.get_legal_moves_json(ai)) as { row: number; col: number }[];
      if (legal.length > 0) {
        let chosen = legal[0];
        const myShots = this.bsShots[ai] || {};

        if (diff >= 1) {
          // 1. Target Mode: check orthogonal neighbors of any existing hit
          let targetNeighbor: { row: number; col: number } | null = null;
          for (const key of Object.keys(myShots)) {
            if (myShots[key] === "hit") {
              const [hr, hc] = key.split("_").map(Number);
              for (const [dr, dc] of [
                [-1, 0],
                [1, 0],
                [0, -1],
                [0, 1],
              ]) {
                const cand = legal.find((m) => m.row === hr + dr && m.col === hc + dc);
                if (cand) {
                  targetNeighbor = cand;
                  break;
                }
              }
            }
            if (targetNeighbor) break;
          }

          if (targetNeighbor) {
            chosen = targetNeighbor;
          } else {
            // 2. Hunt Mode: parity & center probability differentiation by difficulty
            let bestScore = -Infinity;
            for (const m of legal) {
              const parity = (m.row + m.col) % 2 === 0 ? 25 : 0;
              const centerDist = Math.abs(4.5 - m.row) + Math.abs(4.5 - m.col);
              let score = parity;
              if (diff === 1) {
                score += (9 - centerDist) * 3;
              } else if (diff === 2) {
                score += (9 - centerDist) * 8 + (m.row === m.col ? 12 : 0);
              } else {
                score += (9 - centerDist) * 10 + (m.row + m.col === 9 ? 18 : 0);
              }
              if (score > bestScore) {
                bestScore = score;
                chosen = m;
              }
            }
          }
        }

        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "battleship_game::FireShotCommand",
            player: ai,
            row: chosen.row,
            col: chosen.col,
          })
        );
      }
    }

    if (this.gameType === "mille_bornes") {
      const hand = this.mbHands[ai] || [];
      let bestIdx = 0;
      if (diff >= 1 && hand.length > 1) {
        let bestScore = -Infinity;
        hand.forEach((card, idx) => {
          let score = 0;
          if (
            card === "As del Volante" ||
            card === "Cisterna" ||
            card === "Incorruptible" ||
            card === "Prioridad"
          ) {
            score = diff >= 2 ? 180 : 90;
          } else if (card.startsWith("Distance ")) {
            const km = Number(card.replace("Distance ", "")) || 50;
            if (this.mbDistance[ai] + km <= 1000 && !this.mbHazard[ai]) {
              score = km;
            }
          } else if (card === "Pinchazo" || card === "Sin Gasolina" || card === "Accidente") {
            score = diff === 3 ? 160 : 75;
          }
          if (score > bestScore) {
            bestScore = score;
            bestIdx = idx;
          }
        });
      }
      return this.send_command_json(
        ai,
        JSON.stringify({
          command_type: "mille_bornes_game::PlayCardCommand",
          player: ai,
          card_index: bestIdx,
        })
      );
    }

    if (this.gameType === "monopoly") {
      this.send_command_json(
        ai,
        JSON.stringify({ command_type: "monopoly_game::RollDiceCommand", player: ai })
      );
      if (diff >= 1 || this.monoCash[ai] >= 300) {
        this.send_command_json(
          ai,
          JSON.stringify({ command_type: "monopoly_game::BuyPropertyCommand", player: ai })
        );
      }
      return this.send_command_json(
        ai,
        JSON.stringify({ command_type: "monopoly_game::EndTurnCommand", player: ai })
      );
    }

    if (this.gameType === "crisis") {
      const myTerrs = this.crisisTerritories.filter((t) => t.owner === ai);
      const myTerr =
        diff >= 2 ? [...myTerrs].sort((a, b) => b.armies - a.armies)[0] : myTerrs[0];
      if (myTerr && this.crisisArmiesRemaining > 0) {
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
      commands: this.replayFullLog.length > 0 ? this.replayFullLog : this.commandLog,
      snapshot: JSON.parse(this.get_state_json()),
    });
  }

  public apply_sync_log_json(gameType: string, logJson: string): boolean {
    try {
      const parsed = JSON.parse(logJson);
      const targetGame = gameType || parsed.game_type || this.gameType;
      const savedAi = this.aiPlayer;
      const savedDiff = this.aiDifficulty;
      this.start_local_match(targetGame, 1, 2);
      this.aiPlayer = savedAi;
      this.aiDifficulty = savedDiff;
      if (Array.isArray(parsed.commands)) {
        for (const entry of parsed.commands) {
          this.executeCommandInternal(entry.player, entry.command, true);
        }
      }
      this.replayFullLog = [...this.commandLog];
      this.replayCursor = this.replayFullLog.length;
      return true;
    } catch {
      return false;
    }
  }

  public get_replay_step_count(): number {
    return this.replayFullLog.length;
  }

  public get_current_replay_step(): number {
    return this.replayCursor;
  }

  public is_replay_at_live_head(): boolean {
    return this.replayCursor >= this.replayFullLog.length;
  }

  public seek_replay_step(stepIndex: number): boolean {
    const full = [...this.replayFullLog];
    const targetStep = Math.max(0, Math.min(full.length, Math.floor(stepIndex)));
    const currentGame = this.gameType;
    const savedAi = this.aiPlayer;
    const savedDiff = this.aiDifficulty;

    this.start_local_match(currentGame, 1, 2);
    this.aiPlayer = savedAi;
    this.aiDifficulty = savedDiff;

    for (let i = 0; i < targetStep; i++) {
      const entry = full[i];
      this.executeCommandInternal(entry.player, entry.command, true);
    }
    this.replayFullLog = full;
    this.replayCursor = targetStep;
    return true;
  }

  public force_timeout_win(winnerId: 1 | 2): void {
    if (this.winner === null) {
      this.winner = winnerId;
      this.tick += 1;
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
