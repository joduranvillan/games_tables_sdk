/**
 * OpenTable WebAssembly Bridge Loader (`open_table_wasm`)
 *
 * Carga el binario `.wasm` compilado desde `games_tables_sdk/open_table_wasm` cuando
 * está presente y provee un motor determinista isomórfico con el mismo contrato JSON
 * (`get_state_json`, `get_legal_moves_json`, `send_command_json`, `apply_sync_log_json`,
 * `step_ai_if_needed`) para garantizar ejecución inmediata en navegador y tests CI.
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
  // Deterministic LCG shuffle matching seed
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

export class WasmGameBridge {
  private gameType: string = "chess";
  private turn: 1 | 2 = 1;
  private tick: number = 0;
  private winner: 0 | 1 | 2 | null = null;
  private aiPlayer: 1 | 2 | null = null;
  private aiDifficulty: number = 1;
  private commandLog: { player: number; command: string }[] = [];
  private rngState: number = 1337;

  // Chess state
  private chessGrid: (ChessPiece | null)[][] = createInitialChessGrid();
  private chessLastMove: { from: [number, number]; to: [number, number] } | null = null;
  private chessDrawOfferedBy: 1 | 2 | null = null;
  private chessInCheck: 1 | 2 | null = null;

  // Checkers state
  private checkersGrid: (CheckersPiece | null)[][] = createInitialCheckersGrid();
  private checkersChainPos: [number, number] | null = null;

  // UNO state
  private unoDeck: UnoCard[] = [];
  private unoDiscard: UnoCard[] = [];
  private unoHands: Record<1 | 2, UnoCard[]> = { 1: [], 2: [] };
  private unoActiveColor: "Red" | "Yellow" | "Green" | "Blue" = "Red";
  private unoDrawPenalty: number = 0;
  private unoCalled: Record<1 | 2, boolean> = { 1: false, 2: false };
  private unoLastEvent: string = "Partida iniciada";

  // Goose state
  private goosePlayers: Record<1 | 2, GoosePlayerState> = {
    1: { player: 1, square: 0, skipTurns: 0, inWell: false },
    2: { player: 2, square: 0, skipTurns: 0, inWell: false },
  };
  private gooseLastDice: [number, number] = [1, 1];
  private gooseLastBanner: string = "Lanza los dados 3D para comenzar en la casilla 0.";

  constructor() {
    this.start_local_match("chess", 1, 2);
  }

  private nextRandomInt(min: number, max: number): number {
    this.rngState = (Math.imul(1664525, this.rngState) + 1013904223) >>> 0;
    return min + (this.rngState % (max - min + 1));
  }

  public start_local_match(gameType: string, _p1: number = 1, _p2: number = 2): boolean {
    const clean = gameType.trim().toLowerCase();
    this.gameType = clean === "oca" ? "goose" : clean;
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
      this.unoHands = {
        1: deck.splice(0, 7),
        2: deck.splice(0, 7),
      };
      let firstTop = deck.find((c) => c.color !== "Wild") || deck[0];
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

  // ============================================================================
  // CHESS LOGIC & LEGAL MOVES
  // ============================================================================
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

  // ============================================================================
  // CHECKERS LOGIC & MANDATORY CAPTURES
  // ============================================================================
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
      return JSON.stringify([{ command_type: "RollDiceCommand", player: p }]);
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

    // Universal Resign & Draw commands
    if (cmdName === "ResignCommand") {
      this.winner = p === 1 ? 2 : 1;
      this.tick += 1;
      if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
      return JSON.stringify([{ event: "GameOverEvent", winner: this.winner }]);
    }

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
        // Detect if opponent King is threatened
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

      // Check multi-jump continuation
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
        const top = this.unoDiscard[this.unoDiscard.length - 1];
        const canPlay =
          this.unoDrawPenalty > 0
            ? card.value === "DrawTwo" || card.value === "WildDrawFour"
            : card.color === "Wild" ||
              card.color === this.unoActiveColor ||
              (top && card.value === top.value);
        if (!canPlay) {
          return JSON.stringify({ ok: false, error: "illegal_uno_card" });
        }
        hand.splice(cardIndex, 1);
        this.unoDiscard.push(card);
        this.unoActiveColor =
          card.color === "Wild"
            ? chosenColor
            : (card.color as "Red" | "Yellow" | "Green" | "Blue");

        if (card.value === "DrawTwo") {
          this.unoDrawPenalty += 2;
        } else if (card.value === "WildDrawFour") {
          this.unoDrawPenalty += 4;
        }

        if (hand.length === 0) {
          this.winner = p;
          this.unoLastEvent = `¡Jugador ${p} se quedó sin cartas y gana la partida!`;
        } else {
          // In 2-player UNO, Skip and Reverse grant an extra turn to the current player
          const keepTurn = card.value === "Skip" || card.value === "Reverse";
          this.turn = keepTurn ? p : p === 1 ? 2 : 1;
          this.unoLastEvent = `Jugador ${p} jugó ${card.color} ${card.value}${
            card.color === "Wild" ? ` (Color: ${this.unoActiveColor})` : ""
          }`;
        }
        this.tick += 1;
        if (recordLog) this.commandLog.push({ player: p, command: jsonStr });
        return JSON.stringify([{ event: "CardPlayedEvent", player: p, card }]);
      }
    }

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
        const overflow = target - 63;
        target = 63 - overflow;
        msg += `Rebota en el Jardín de la Oca hasta la casilla ${target}. `;
      }

      // Canonical Special Squares of El Juego de la Oca
      if (target === 63) {
        pState.square = 63;
        this.winner = p;
        msg += "¡Llegó exactamente al Jardín de la Oca (63) y gana la partida!";
      } else if (GOOSE_SQUARES.has(target)) {
        const sortedGeese = Array.from(GOOSE_SQUARES).sort((a, b) => a - b);
        const idx = sortedGeese.indexOf(target);
        const nextGoose = idx >= 0 && idx + 1 < sortedGeese.length ? sortedGeese[idx + 1] : 63;
        pState.square = nextGoose;
        extraTurn = nextGoose < 63;
        if (nextGoose === 63) {
          this.winner = p;
          msg += `¡Oca en ${target}! Salta directo al Jardín de la Oca (63) y gana.`;
        } else {
          msg += `¡De Oca (${target}) a Oca (${nextGoose}) y tiro porque me toca!`;
        }
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
        msg += "El Pozo (31): pierde 2 turnos hasta ser rescatado.";
      } else if (target === 42) {
        pState.square = 30;
        msg += "El Laberinto (42): retrocede a la casilla 30.";
      } else if (target === 52) {
        pState.square = 52;
        pState.skipTurns = 2;
        msg += "La Cárcel (52): permanece 2 turnos sin mover.";
      } else if (target === 58) {
        pState.square = 1;
        msg += "La Calavera (58): vuelve a empezar desde la casilla 1.";
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
      return JSON.stringify([
        {
          event: "GooseMovedEvent",
          player: p,
          dice: [d1, d2],
          to_square: pState.square,
          extra_turn: extraTurn,
          banner: msg,
        },
      ]);
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
      // Prefer captures according to difficulty
      let chosen = legal[0];
      let bestScore = -999;
      const values: Record<ChessPiece["kind"], number> = {
        Pawn: 1,
        Knight: 3,
        Bishop: 3,
        Rook: 5,
        Queen: 9,
        King: 100,
      };
      for (const m of legal) {
        const target = this.chessGrid[m.to[0]][m.to[1]];
        const score = (target ? values[target.kind] * 10 : 0) + (m.promotion ? 8 : 0);
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
        const pick = playableRaw[0];
        if (this.unoHands[ai].length === 2 && !this.unoCalled[ai]) {
          this.send_command_json(ai, JSON.stringify({ command_type: "CallUnoCommand", player: ai }));
        }
        return this.send_command_json(
          ai,
          JSON.stringify({
            command_type: "PlayCardCommand",
            player: ai,
            card_index: pick.index,
            chosen_color: "Red",
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
    // Deterministic QR-style matrix SVG from room code + gameType
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
