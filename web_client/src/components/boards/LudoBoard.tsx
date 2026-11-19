import React, { useMemo, useState } from "react";
import { DiceRoller3D } from "../common/DiceRoller3D";

interface LudoBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const SAFE_STAR_STEPS = new Set([1, 9, 14, 22, 27, 35, 40, 48]);

/**
 * 52-cell clockwise outer perimeter path on the classic 15x15 Ludo Cross board.
 * Index 0 is Red's start square (row 6, col 1), matching step 1 for Player 1.
 * Index 26 is Yellow's start square (row 8, col 13), matching step 27 for Player 2.
 */
const OUTER_TRACK_52: [number, number][] = [
  // Left arm top row (moving right: indices 0..4)
  [6, 1],
  [6, 2],
  [6, 3],
  [6, 4],
  [6, 5],
  // Top arm left column (moving up: indices 5..10)
  [5, 6],
  [4, 6],
  [3, 6],
  [2, 6],
  [1, 6],
  [0, 6],
  // Top arm top turn (index 11)
  [0, 7],
  // Top arm right column (moving down: indices 12..17)
  [0, 8],
  [1, 8],
  [2, 8],
  [3, 8],
  [4, 8],
  [5, 8],
  // Right arm top row (moving right: indices 18..23)
  [6, 9],
  [6, 10],
  [6, 11],
  [6, 12],
  [6, 13],
  [6, 14],
  // Right arm right turn (index 24)
  [7, 14],
  // Right arm bottom row (moving left: indices 25..30)
  [8, 14],
  [8, 13],
  [8, 12],
  [8, 11],
  [8, 10],
  [8, 9],
  // Bottom arm right column (moving down: indices 31..36)
  [9, 8],
  [10, 8],
  [11, 8],
  [12, 8],
  [13, 8],
  [14, 8],
  // Bottom arm bottom turn (index 37)
  [14, 7],
  // Bottom arm left column (moving up: indices 38..43)
  [14, 6],
  [13, 6],
  [12, 6],
  [11, 6],
  [10, 6],
  [9, 6],
  // Left arm bottom row (moving left: indices 44..49)
  [8, 5],
  [8, 4],
  [8, 3],
  [8, 2],
  [8, 1],
  [8, 0],
  // Left arm left turn (index 50)
  [7, 0],
  // Left arm top-left corner before Red start (index 51)
  [6, 0],
];

// Home stretch lanes (steps 52..56)
const RED_HOME_LANE: [number, number][] = [
  [7, 1],
  [7, 2],
  [7, 3],
  [7, 4],
  [7, 5],
];

const BLUE_HOME_LANE: [number, number][] = [
  [13, 7],
  [12, 7],
  [11, 7],
  [10, 7],
  [9, 7],
];

// Base token slots (steps === 0) inside the 6x6 corner yards
const BASE_SLOTS: Record<1 | 2, [number, number][]> = {
  1: [
    [1, 1],
    [1, 4],
    [4, 1],
    [4, 4],
  ],
  2: [
    [10, 1],
    [10, 4],
    [13, 1],
    [13, 4],
  ],
};

// Goal slots inside the 3x3 center trophy area (steps === 57)
const GOAL_SLOTS: Record<1 | 2, [number, number]> = {
  1: [7, 6],
  2: [8, 7],
};

function getTokenGridCoord(player: 1 | 2, tokenIdx: number, steps: number): [number, number] {
  if (steps <= 0) {
    return BASE_SLOTS[player][tokenIdx] || BASE_SLOTS[player][0];
  }
  if (steps >= 57) {
    return GOAL_SLOTS[player];
  }
  if (steps >= 52) {
    const laneIdx = Math.min(4, steps - 52);
    return player === 1 ? RED_HOME_LANE[laneIdx] : BLUE_HOME_LANE[laneIdx];
  }
  // steps 1..51 on the 52-cell perimeter track
  // Note: To keep shared-step capture canonical with the engine (where both P1 and P2 compare `steps` 1..51),
  // we map step 1..51 directly onto OUTER_TRACK_52[(steps - 1) % 52].
  return OUTER_TRACK_52[(steps - 1) % 52];
}

export const LudoBoard: React.FC<LudoBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selectedTokenIndex, setSelectedTokenIndex] = useState<number>(0);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    tokens: Record<1 | 2, number[]>;
    dice: [number, number];
    banner: string;
  };

  const handleRollAndAdvance = (d1: number, d2: number, forcedTokenIdx?: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    const idxToMove = forcedTokenIdx ?? selectedTokenIndex;
    onDispatchCommand(
      JSON.stringify({
        command_type: "ludo_game::MoveTokenCommand",
        player: state.turn,
        token_index: idxToMove,
        d1,
        d2,
      })
    );
  };

  // Map every (r, c) cell to any tokens currently standing on it
  const tokensByCell = useMemo(() => {
    const map = new Map<
      string,
      Array<{ player: 1 | 2; tokenIdx: number; steps: number }>
    >();
    ([1, 2] as const).forEach((pid) => {
      state.tokens[pid].forEach((steps, tIdx) => {
        const [r, c] = getTokenGridCoord(pid, tIdx, steps);
        const key = `${r}_${c}`;
        const list = map.get(key) || [];
        list.push({ player: pid, tokenIdx: tIdx, steps });
        map.set(key, list);
      });
    });
    return map;
  }, [state.tokens]);

  // Reverse lookup for outer track step number (1..52)
  const stepByCell = useMemo(() => {
    const map = new Map<string, number>();
    OUTER_TRACK_52.forEach(([r, c], idx) => {
      map.set(`${r}_${c}`, idx + 1);
    });
    return map;
  }, []);

  const renderYardBox = (
    title: string,
    bgClass: string,
    ringClass: string,
    player: 1 | 2 | null
  ) => {
    const tokens = player ? state.tokens[player] : [];
    return (
      <div
        className={`w-full h-full ${bgClass} p-2.5 sm:p-4 flex items-center justify-center border-2 border-slate-950`}
      >
        <div
          className={`w-full h-full rounded-full ${ringClass} border-4 border-black/25 p-2.5 sm:p-4 grid grid-cols-2 grid-rows-2 gap-2 sm:gap-3 place-items-center shadow-inner`}
        >
          {[0, 1, 2, 3].map((slotIdx) => {
            const isBaseHere = player !== null && tokens[slotIdx] === 0;
            const isSelected =
              player === state.turn && selectedTokenIndex === slotIdx;

            return (
              <button
                key={slotIdx}
                type="button"
                title={
                  player
                    ? `Jugador ${player} · Ficha #${slotIdx + 1}`
                    : `${title} (Decorativo 4 colores)`
                }
                disabled={!player || !isLocalTurnAllowed || state.turn !== player}
                onClick={() => {
                  if (player) {
                    setSelectedTokenIndex(slotIdx);
                  }
                }}
                className={`w-8 h-8 sm:w-11 sm:h-11 rounded-full bg-white border-2 border-slate-900 flex items-center justify-center shadow-md transition-transform ${
                  player ? "cursor-pointer" : "cursor-default"
                } ${isSelected ? "ring-4 ring-amber-400 scale-110" : ""}`}
              >
                {isBaseHere && (
                  <span
                    className={`w-6 h-6 sm:w-8 sm:h-8 rounded-full border-2 border-white shadow flex items-center justify-center text-[10px] sm:text-xs font-extrabold text-white ${
                      player === 1
                        ? "bg-gradient-to-br from-rose-400 to-red-700"
                        : "bg-gradient-to-br from-sky-400 to-blue-700"
                    }`}
                  >
                    #{slotIdx + 1}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>
    );
  };

  const renderTrackCell = (r: number, c: number) => {
    const key = `${r}_${c}`;
    const stepNum = stepByCell.get(key);
    const cellTokens = tokensByCell.get(key) || [];

    // Colored home lanes & start squares matching reference Ludo board
    const isRedLane = r === 7 && c >= 1 && c <= 5;
    const isGreenLane = c === 7 && r >= 1 && r <= 5;
    const isYellowLane = r === 7 && c >= 9 && c <= 13;
    const isBlueLane = c === 7 && r >= 9 && r <= 13;

    const isRedStart = r === 6 && c === 1;
    const isGreenStart = r === 1 && c === 8;
    const isYellowStart = r === 8 && c === 13;
    const isBlueStart = r === 13 && c === 6;

    const isSafeStar =
      (stepNum !== undefined && SAFE_STAR_STEPS.has(stepNum)) ||
      (r === 2 && c === 6) ||
      (r === 6 && c === 12) ||
      (r === 12 && c === 8) ||
      (r === 8 && c === 2);

    let bg = "bg-white text-slate-800";
    if (isRedLane || isRedStart) bg = "bg-red-600 text-white";
    else if (isGreenLane || isGreenStart) bg = "bg-emerald-600 text-white";
    else if (isYellowLane || isYellowStart) bg = "bg-amber-400 text-slate-950";
    else if (isBlueLane || isBlueStart) bg = "bg-blue-600 text-white";

    // Entry arrows on outer middle cells
    const entryArrow =
      r === 7 && c === 0
        ? "▶"
        : r === 0 && c === 7
        ? "▼"
        : r === 7 && c === 14
        ? "◀"
        : r === 14 && c === 7
        ? "▲"
        : null;

    return (
      <div
        key={key}
        className={`relative w-full h-full min-h-[22px] sm:min-h-[32px] border border-slate-950 flex items-center justify-center select-none ${bg}`}
      >
        {/* Step number or safe star */}
        {isSafeStar && cellTokens.length === 0 && (
          <span className="text-xs sm:text-base font-bold leading-none drop-shadow-xs">
            ★
          </span>
        )}
        {!isSafeStar && entryArrow && cellTokens.length === 0 && (
          <span className="text-[10px] sm:text-xs font-bold">{entryArrow}</span>
        )}
        {!isSafeStar && !entryArrow && stepNum && cellTokens.length === 0 && (
          <span className="text-[8px] sm:text-[9px] font-mono opacity-45">
            {stepNum}
          </span>
        )}

        {/* Active tokens on this track cell */}
        {cellTokens.length > 0 && (
          <div className="flex items-center justify-center -space-x-1.5 z-10">
            {cellTokens.map((tk) => {
              const isSelected =
                tk.player === state.turn && selectedTokenIndex === tk.tokenIdx;
              return (
                <button
                  key={`${tk.player}_${tk.tokenIdx}`}
                  type="button"
                  onClick={() => {
                    if (tk.player === state.turn) {
                      setSelectedTokenIndex(tk.tokenIdx);
                    }
                  }}
                  title={`J${tk.player} · Ficha #${tk.tokenIdx + 1} (Paso ${tk.steps}/57)`}
                  className={`w-5 h-5 sm:w-7 sm:h-7 rounded-full border-2 border-white shadow-md flex items-center justify-center text-[9px] sm:text-[11px] font-extrabold text-white cursor-pointer transition-transform ${
                    tk.player === 1
                      ? "bg-gradient-to-br from-rose-400 to-red-800"
                      : "bg-gradient-to-br from-sky-400 to-blue-800"
                  } ${isSelected ? "ring-3 ring-amber-300 scale-115 z-20" : ""}`}
                >
                  {tk.tokenIdx + 1}
                </button>
              );
            })}
          </div>
        )}
      </div>
    );
  };

  const p1GoalTokens = state.tokens[1]
    .map((steps, idx) => ({ steps, idx }))
    .filter((t) => t.steps >= 57);
  const p2GoalTokens = state.tokens[2]
    .map((steps, idx) => ({ steps, idx }))
    .filter((t) => t.steps >= 57);

  return (
    <div className="w-full max-w-6xl flex flex-col xl:flex-row gap-6 items-center xl:items-start">
      {/* Classic 15x15 Ludo Board matching user reference image */}
      <div className="p-2.5 sm:p-4 rounded-3xl bg-amber-100 border-8 border-slate-950 shadow-2xl w-full max-w-[560px] aspect-square">
        <div className="w-full h-full grid grid-cols-15 grid-rows-15 border-2 border-slate-950 bg-slate-950 overflow-hidden rounded-xl">
          {/* Top-Left 6x6 Red Yard (Player 1) */}
          <div className="col-start-1 col-end-7 row-start-1 row-end-7">
            {renderYardBox("Base Roja (J1)", "bg-red-600", "bg-red-400", 1)}
          </div>

          {/* Top Arm 3x6 (Cols 7..9, Rows 1..6) */}
          {Array.from({ length: 6 }, (_, r) =>
            [6, 7, 8].map((c) => (
              <div
                key={`top_${r}_${c}`}
                style={{ gridRow: r + 1, gridColumn: c + 1 }}
              >
                {renderTrackCell(r, c)}
              </div>
            ))
          )}

          {/* Top-Right 6x6 Green Yard */}
          <div className="col-start-10 col-end-16 row-start-1 row-end-7">
            {renderYardBox("Base Verde", "bg-emerald-600", "bg-emerald-400", null)}
          </div>

          {/* Left Arm 6x3 (Cols 1..6, Rows 7..9) */}
          {[6, 7, 8].map((r) =>
            Array.from({ length: 6 }, (_, c) => (
              <div
                key={`left_${r}_${c}`}
                style={{ gridRow: r + 1, gridColumn: c + 1 }}
              >
                {renderTrackCell(r, c)}
              </div>
            ))
          )}

          {/* Center 3x3 4-Color Diagonal Goal Triangles (Rows 7..9, Cols 7..9) */}
          <div className="col-start-7 col-end-10 row-start-7 row-end-10 relative border-2 border-slate-950 overflow-hidden">
            <svg viewBox="0 0 100 100" className="w-full h-full">
              {/* Top Green Triangle */}
              <polygon points="0,0 100,0 50,50" fill="#059669" stroke="#020617" strokeWidth="2" />
              {/* Right Yellow Triangle */}
              <polygon points="100,0 100,100 50,50" fill="#fbbf24" stroke="#020617" strokeWidth="2" />
              {/* Bottom Blue Triangle (Player 2 Goal) */}
              <polygon points="0,100 100,100 50,50" fill="#2563eb" stroke="#020617" strokeWidth="2" />
              {/* Left Red Triangle (Player 1 Goal) */}
              <polygon points="0,0 0,100 50,50" fill="#dc2626" stroke="#020617" strokeWidth="2" />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
              <span className="text-base sm:text-xl drop-shadow">🏆</span>
              <div className="flex gap-1 mt-0.5">
                {p1GoalTokens.map((t) => (
                  <span
                    key={`g1_${t.idx}`}
                    className="w-3.5 h-3.5 rounded-full bg-rose-600 border border-white text-[8px] font-bold text-white flex items-center justify-center"
                  >
                    {t.idx + 1}
                  </span>
                ))}
                {p2GoalTokens.map((t) => (
                  <span
                    key={`g2_${t.idx}`}
                    className="w-3.5 h-3.5 rounded-full bg-blue-600 border border-white text-[8px] font-bold text-white flex items-center justify-center"
                  >
                    {t.idx + 1}
                  </span>
                ))}
              </div>
            </div>
          </div>

          {/* Right Arm 6x3 (Cols 10..15, Rows 7..9) */}
          {[6, 7, 8].map((r) =>
            Array.from({ length: 6 }, (_, idx) => {
              const c = 9 + idx;
              return (
                <div
                  key={`right_${r}_${c}`}
                  style={{ gridRow: r + 1, gridColumn: c + 1 }}
                >
                  {renderTrackCell(r, c)}
                </div>
              );
            })
          )}

          {/* Bottom-Left 6x6 Blue Yard (Player 2) */}
          <div className="col-start-1 col-end-7 row-start-10 row-end-16">
            {renderYardBox("Base Azul (J2)", "bg-blue-600", "bg-blue-400", 2)}
          </div>

          {/* Bottom Arm 3x6 (Cols 7..9, Rows 10..15) */}
          {Array.from({ length: 6 }, (_, idx) => {
            const r = 9 + idx;
            return [6, 7, 8].map((c) => (
              <div
                key={`bot_${r}_${c}`}
                style={{ gridRow: r + 1, gridColumn: c + 1 }}
              >
                {renderTrackCell(r, c)}
              </div>
            ));
          })}

          {/* Bottom-Right 6x6 Yellow Yard */}
          <div className="col-start-10 col-end-16 row-start-10 row-end-16">
            {renderYardBox("Base Amarilla", "bg-amber-400", "bg-amber-300", null)}
          </div>
        </div>
      </div>

      {/* Controls, 3D Dice & Squad Selector */}
      <div className="flex-1 w-full flex flex-col gap-4">
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <div className="text-xs text-slate-400">
                Ludo Clásico 15×15 · 4 Bases, Estrellas Seguras (★) y Meta Exacta 57
              </div>
              <h3 className="text-base font-bold text-white mt-0.5">
                {state.banner}
              </h3>
              {!isLocalTurnAllowed && state.winner === null && (
                <span className="text-xs text-amber-300">
                  Esperando turno de J{state.turn} (Tú: J{localPlayerId})
                </span>
              )}
            </div>

            <DiceRoller3D
              dice={state.dice}
              disabled={!isLocalTurnAllowed || state.winner !== null}
              onRoll={(d1, d2) => handleRollAndAdvance(d1, d2)}
            />
          </div>

          <div className="text-xs text-slate-300 bg-slate-950 border border-slate-800 rounded-xl p-3">
            💡 <strong>Reglas Canónicas Ludo (Motor Rust):</strong> Las fichas en la base circular salen únicamente al obtener un <strong>6</strong>. Las casillas con estrella (<strong>★</strong>) protegen contra capturas. Capturar una ficha rival o sacar un 6 otorga turno extra.
          </div>
        </div>

        {/* Squad Token Selectors */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {([1, 2] as const).map((pid) => (
            <div
              key={pid}
              className={`p-4 rounded-2xl border flex flex-col gap-3 ${
                state.turn === pid
                  ? pid === 1
                    ? "bg-rose-950/35 border-rose-500/70"
                    : "bg-blue-950/35 border-blue-500/70"
                  : "bg-slate-900 border-slate-800"
              }`}
            >
              <div className="flex items-center justify-between">
                <h4 className="text-sm font-bold text-white flex items-center gap-2">
                  <span
                    className={`w-3.5 h-3.5 rounded-full border border-white ${
                      pid === 1 ? "bg-red-600" : "bg-blue-600"
                    }`}
                  />
                  <span>
                    Jugador {pid} ({pid === 1 ? "Rojo" : "Azul"})
                  </span>
                </h4>
                <span className="text-xs font-mono text-slate-400">
                  Ficha activa: #{selectedTokenIndex + 1}
                </span>
              </div>

              <div className="grid grid-cols-2 gap-2.5">
                {state.tokens[pid].map((steps, idx) => {
                  const isSafe = SAFE_STAR_STEPS.has(steps);
                  const isGoal = steps >= 57;
                  const isSelected =
                    state.turn === pid && selectedTokenIndex === idx;

                  return (
                    <button
                      key={idx}
                      type="button"
                      disabled={!isLocalTurnAllowed || state.turn !== pid}
                      onClick={() => setSelectedTokenIndex(idx)}
                      className={`p-2.5 rounded-xl border text-left flex flex-col gap-1.5 transition-all cursor-pointer ${
                        isSelected
                          ? "bg-emerald-950/80 border-emerald-400 ring-2 ring-emerald-400"
                          : "bg-slate-950 border-slate-800 hover:border-slate-700"
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-white">
                          Ficha #{idx + 1}
                        </span>
                        <span className="text-xs font-mono text-slate-300">
                          {steps}/57
                        </span>
                      </div>
                      <div className="text-[11px] text-slate-400 font-mono">
                        {isGoal
                          ? "🏆 En Meta"
                          : steps === 0
                          ? "⚪ En Base (Sale con 6)"
                          : isSafe
                          ? `★ Segura (Paso ${steps})`
                          : `Paso ${steps}`}
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
