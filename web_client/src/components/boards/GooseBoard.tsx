import React from "react";
import { GoosePlayerState } from "../../wasm_pkg";
import { DiceRoller3D } from "../common/DiceRoller3D";

interface GooseBoardProps {
  stateJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const GOOSE_SET = new Set([5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59]);

/**
 * Generates an 8x8 concentric counterclockwise spiral layout starting at bottom-right (row 7, col 7 = square 0)
 * and spiraling inward to the central Garden of the Goose (square 63), matching the classic Spanish Juego de la Oca board.
 */
function buildSpiralGrid8x8(): number[][] {
  const grid: number[][] = Array.from({ length: 8 }, () =>
    Array.from({ length: 8 }, () => 0)
  );
  let top = 0;
  let bottom = 7;
  let left = 0;
  let right = 7;
  let sq = 0;

  while (top <= bottom && left <= right) {
    // 1. Bottom row: right -> left
    for (let c = right; c >= left && sq <= 63; c--) {
      grid[bottom][c] = sq++;
    }
    bottom--;

    // 2. Left column: bottom -> top
    for (let r = bottom; r >= top && sq <= 63; r--) {
      grid[r][left] = sq++;
    }
    left++;

    // 3. Top row: left -> right
    for (let c = left; c <= right && sq <= 63; c++) {
      grid[top][c] = sq++;
    }
    top++;

    // 4. Right column: top -> bottom
    for (let r = top; r <= bottom && sq <= 63; r++) {
      grid[r][right] = sq++;
    }
    right--;
  }

  return grid;
}

const SPIRAL_GRID_8X8 = buildSpiralGrid8x8();

interface SpecialSquareMeta {
  label: string;
  icon: string;
  ruleHint: string;
  bgTone: string;
}

function getSquareMeta(sq: number): SpecialSquareMeta {
  if (sq === 0) {
    return {
      label: "SALIDA",
      icon: "🪿🚩",
      ruleHint: "Casilla 0 · Lanza los dados para entrar al camino en espiral",
      bgTone: "bg-amber-200 border-amber-600 text-slate-950",
    };
  }
  if (sq === 63) {
    return {
      label: "JARDÍN DE LA OCA",
      icon: "🪿👑🏆",
      ruleHint: "Casilla 63 · ¡Meta! Llegada exacta (rebota si te pasas)",
      bgTone: "bg-gradient-to-br from-amber-200 via-yellow-300 to-emerald-300 border-emerald-700 text-slate-950 ring-2 ring-amber-500",
    };
  }
  if (GOOSE_SET.has(sq)) {
    return {
      label: "OCA",
      icon: "🪿",
      ruleHint: "«De oca a oca y tiro porque me toca»",
      bgTone: "bg-amber-300 border-amber-700 text-slate-950",
    };
  }
  if (sq === 6 || sq === 12) {
    return {
      label: "PUENTE",
      icon: "🌉",
      ruleHint: "«De puente a puente (6 ↔ 12) y tiro porque me lleva la corriente»",
      bgTone: "bg-sky-300 border-sky-700 text-slate-950",
    };
  }
  if (sq === 19) {
    return {
      label: "POSADA",
      icon: "🏠💤",
      ruleHint: "La Posada · Pierdes 1 turno descansando",
      bgTone: "bg-purple-200 border-purple-700 text-slate-950",
    };
  }
  if (sq === 26 || sq === 53) {
    return {
      label: "DADOS",
      icon: "🎲🎲",
      ruleHint: "«De dado a dado (26 ↔ 53) y tiro porque me ha tocado»",
      bgTone: "bg-emerald-300 border-emerald-700 text-slate-950",
    };
  }
  if (sq === 31) {
    return {
      label: "POZO",
      icon: "🪣🕳️",
      ruleHint: "El Pozo · Retenido hasta que otro jugador pase o te rescate",
      bgTone: "bg-orange-300 border-orange-800 text-slate-950",
    };
  }
  if (sq === 42) {
    return {
      label: "LABERINTO",
      icon: "🌿🌀",
      ruleHint: "El Laberinto · Retrocedes automáticamente a la casilla 30",
      bgTone: "bg-lime-300 border-lime-800 text-slate-950",
    };
  }
  if (sq === 52) {
    return {
      label: "CÁRCEL",
      icon: "⛓️🔒",
      ruleHint: "La Cárcel · Retenido durante 2 turnos",
      bgTone: "bg-rose-300 border-rose-800 text-slate-950",
    };
  }
  if (sq === 58) {
    return {
      label: "CALAVERA",
      icon: "💀⚡",
      ruleHint: "La Calavera · Vuelves a empezar desde la casilla 1",
      bgTone: "bg-rose-400 border-rose-950 text-slate-950",
    };
  }

  // Alternating pastel spiral path tiles matching the classic Spanish illustrated Oca board
  const palette = [
    "bg-[#fef9c3] border-[#0284c7] text-slate-900", // Warm Cream
    "bg-[#bae6fd] border-[#0369a1] text-slate-900", // Sky Blue
    "bg-[#fde047] border-[#0284c7] text-slate-900", // Sunny Yellow
  ];
  return {
    label: "",
    icon: "",
    ruleHint: `Casilla ${sq}`,
    bgTone: palette[sq % palette.length],
  };
}

export const GooseBoard: React.FC<GooseBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    players: Record<1 | 2, GoosePlayerState>;
    last_dice: [number, number];
    last_banner: string;
  };

  const handleRoll = (d1: number, d2: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "goose_game::RollDiceCommand",
        player: state.turn,
        d1,
        d2,
      })
    );
  };

  // Next directional arrow along the spiral (sq -> sq + 1)
  const coordOfSq = new Map<number, [number, number]>();
  SPIRAL_GRID_8X8.forEach((row, r) =>
    row.forEach((sq, c) => coordOfSq.set(sq, [r, c]))
  );

  const getSpiralArrow = (sq: number): string => {
    if (sq >= 63) return "🏁";
    const cur = coordOfSq.get(sq);
    const nxt = coordOfSq.get(sq + 1);
    if (!cur || !nxt) return "";
    const dr = nxt[0] - cur[0];
    const dc = nxt[1] - cur[1];
    if (dc === -1) return "←";
    if (dc === 1) return "→";
    if (dr === -1) return "↑";
    if (dr === 1) return "↓";
    return "";
  };

  return (
    <div className="w-full max-w-6xl flex flex-col gap-6">
      {/* Top Banner & 3D Dice Roller */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800 shadow-lg">
        <div className="flex flex-col gap-1">
          <div className="text-xs text-amber-300 font-semibold">
            🪿 El Juego de la Oca · Tablero Tradicional en Espiral (63 Casillas → Jardín Central)
          </div>
          <div className="text-sm sm:text-base font-bold text-white">
            {state.last_banner}
          </div>
          <div className="flex flex-wrap items-center gap-3 text-xs text-slate-300 mt-1 font-mono tabular-nums">
            <span className="px-2.5 py-1 rounded-lg bg-rose-950/70 border border-rose-500/50 text-rose-200">
              🪿 Jugador 1 (Rojo): Casilla{" "}
              <strong className="text-white">{state.players[1].square}/63</strong>
              {state.players[1].skipTurns > 0 && ` (Espera ${state.players[1].skipTurns}t)`}
              {state.players[1].inWell && " (En el Pozo)"}
            </span>
            <span className="px-2.5 py-1 rounded-lg bg-sky-950/70 border border-sky-500/50 text-sky-200">
              🪿 Jugador 2 (Azul): Casilla{" "}
              <strong className="text-white">{state.players[2].square}/63</strong>
              {state.players[2].skipTurns > 0 && ` (Espera ${state.players[2].skipTurns}t)`}
              {state.players[2].inWell && " (En el Pozo)"}
            </span>
            {!isLocalTurnAllowed && state.winner === null && (
              <span className="text-amber-300">
                Esperando turno del Jugador {state.turn} (Tú: J{localPlayerId})
              </span>
            )}
          </div>
        </div>

        <DiceRoller3D
          dice={state.last_dice}
          disabled={!isLocalTurnAllowed || state.winner !== null}
          onRoll={handleRoll}
        />
      </div>

      {/* Spiral Track Board matching traditional Spanish Juego de la Oca */}
      <div className="p-3 sm:p-5 rounded-3xl bg-gradient-to-br from-sky-700 via-sky-600 to-cyan-800 border-4 border-sky-300 shadow-2xl overflow-x-auto">
        <div className="min-w-[540px] grid grid-cols-8 gap-1.5 sm:gap-2">
          {SPIRAL_GRID_8X8.map((row, r) =>
            row.map((sq, c) => {
              const meta = getSquareMeta(sq);
              const p1Here = state.players[1].square === sq;
              const p2Here = state.players[2].square === sq;
              const arrow = getSpiralArrow(sq);

              return (
                <div
                  key={`${r}_${c}_${sq}`}
                  title={meta.ruleHint}
                  className={`relative h-16 sm:h-21 rounded-xl p-1.5 sm:p-2 border-2 flex flex-col justify-between shadow-md transition-transform ${
                    meta.bgTone
                  } ${p1Here || p2Here ? "ring-3 ring-slate-950 scale-[1.03] z-10" : ""}`}
                >
                  {/* Top Row: Square Number & Spiral Direction Arrow */}
                  <div className="flex items-center justify-between leading-none">
                    <span className="px-1.5 py-0.5 rounded-full bg-orange-600 text-white text-[10px] sm:text-xs font-extrabold font-mono shadow-xs">
                      {sq}
                    </span>
                    <span className="text-[10px] sm:text-xs font-extrabold text-sky-900 opacity-75">
                      {arrow}
                    </span>
                  </div>

                  {/* Middle Illustration & Label */}
                  <div className="flex flex-col items-center justify-center leading-tight my-auto">
                    {meta.icon && (
                      <span className="text-base sm:text-xl leading-none drop-shadow-xs">
                        {meta.icon}
                      </span>
                    )}
                    {meta.label && (
                      <span className="text-[8px] sm:text-[9px] font-black tracking-tight text-center uppercase text-slate-900 line-clamp-1">
                        {meta.label}
                      </span>
                    )}
                  </div>

                  {/* Bottom Row: Active Player Goose Tokens */}
                  <div className="flex items-center justify-center gap-1 min-h-[18px]">
                    {p1Here && (
                      <span
                        title="Jugador 1 (Oca Roja)"
                        className="px-1.5 py-0.5 rounded-full bg-rose-600 border-2 border-white text-[9px] sm:text-[10px] font-black text-white flex items-center gap-0.5 shadow"
                      >
                        <span>🪿1</span>
                      </span>
                    )}
                    {p2Here && (
                      <span
                        title="Jugador 2 (Oca Azul)"
                        className="px-1.5 py-0.5 rounded-full bg-blue-600 border-2 border-white text-[9px] sm:text-[10px] font-black text-white flex items-center gap-0.5 shadow"
                      >
                        <span>🪿2</span>
                      </span>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Classic Rules Legend Footer */}
        <div className="mt-4 pt-3 border-t border-sky-400/40 flex flex-wrap items-center justify-between gap-2 text-[11px] text-sky-100 font-medium">
          <span>🪿 <strong>Ocas:</strong> Salto a la siguiente Oca + Turno Extra</span>
          <span>🌉 <strong>Puentes (6↔12):</strong> Salto + Turno Extra</span>
          <span>🎲 <strong>Dados (26↔53):</strong> Salto + Turno Extra</span>
          <span>🏠 <strong>Posada (19):</strong> -1t · 🪣 <strong>Pozo (31)</strong> · 🌿 <strong>Laberinto (42→30)</strong> · ⛓️ <strong>Cárcel (52):</strong> -2t · 💀 <strong>Calavera (58→1)</strong></span>
        </div>
      </div>
    </div>
  );
};
