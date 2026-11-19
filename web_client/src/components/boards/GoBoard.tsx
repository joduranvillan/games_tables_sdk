import React, { useState } from "react";

interface GoBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

function getHoshiSet(size: 9 | 13 | 19): Set<string> {
  if (size === 9) {
    return new Set(["2_2", "2_6", "6_2", "6_6", "4_4"]);
  }
  if (size === 13) {
    return new Set([
      "3_3",
      "3_6",
      "3_9",
      "6_3",
      "6_6",
      "6_9",
      "9_3",
      "9_6",
      "9_9",
    ]);
  }
  return new Set([
    "3_3",
    "3_9",
    "3_15",
    "9_3",
    "9_9",
    "9_15",
    "15_3",
    "15_9",
    "15_15",
  ]);
}

export const GoBoard: React.FC<GoBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [showLiberties, setShowLiberties] = useState<boolean>(true);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    size: 9 | 13 | 19;
    grid: (0 | 1 | 2)[][];
    captures: Record<1 | 2, number>;
    passes: number;
    dead_stones: string[];
    handicap: number;
    scoring_phase: boolean;
    komi: number;
    liberties_by_cell?: Record<string, number>;
    last_move?: string | null;
    last_banner?: string | null;
  };

  const boardSize: 9 | 13 | 19 = state.size || 9;
  const hoshiSet = getHoshiSet(boardSize);

  const handleIntersectionClick = (r: number, c: number) => {
    if (state.winner !== null) return;
    if (state.scoring_phase) {
      if (state.grid[r]?.[c] !== 0) {
        onDispatchCommand(
          JSON.stringify({
            command_type: "go_game::MarkDeadCommand",
            player: state.turn,
            row: r,
            col: c,
          })
        );
      }
      return;
    }
    if (!isLocalTurnAllowed) return;
    if (state.grid[r]?.[c] !== 0) return;

    onDispatchCommand(
      JSON.stringify({
        command_type: "go_game::PlaceStoneCommand",
        player: state.turn,
        row: r,
        col: c,
      })
    );
  };

  const handleSetHandicap = (count: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "go_game::SetHandicapCommand",
        player: state.turn,
        handicap: count,
      })
    );
  };

  const handleSetBoardSize = (newSize: 9 | 13 | 19) => {
    if (!isLocalTurnAllowed) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "go_game::SetBoardSizeCommand",
        player: state.turn,
        size: newSize,
      })
    );
  };

  const cellSizeClass =
    boardSize === 9
      ? "w-9 h-9 sm:w-11 sm:h-11 rounded-lg"
      : boardSize === 13
      ? "w-6 h-6 sm:w-8 sm:h-8 rounded-md"
      : "w-4 h-4 sm:w-6 sm:h-6 rounded";

  const stoneSizeClass =
    boardSize === 9
      ? "w-7 h-7 sm:w-8 sm:h-8 text-xs"
      : boardSize === 13
      ? "w-5 h-5 sm:w-6 sm:h-6 text-[10px]"
      : "w-3.5 h-3.5 sm:w-5 sm:h-5 text-[9px]";

  const gridGapClass =
    boardSize === 9 ? "gap-1.5" : boardSize === 13 ? "gap-1" : "gap-0.5";

  return (
    <div className="w-full max-w-5xl flex flex-col lg:flex-row gap-6 lg:gap-8 items-start">
      {/* Dynamic Goban Canvas (9x9, 13x13, 19x19) */}
      <div className="p-3.5 sm:p-5 rounded-2xl bg-amber-200/95 border-4 border-amber-800 shadow-2xl overflow-x-auto max-w-full">
        <div
          className={`grid ${gridGapClass}`}
          style={{
            gridTemplateColumns: `repeat(${boardSize}, minmax(0, 1fr))`,
          }}
        >
          {state.grid.map((row, r) =>
            row.map((cell, c) => {
              const key = `${r}_${c}`;
              const isHoshi = hoshiSet.has(key);
              const isDead = state.dead_stones.includes(key);
              const isLastMove = state.last_move === key;
              const libertyCount = state.liberties_by_cell?.[key];
              const isAtari = cell !== 0 && libertyCount === 1 && !isDead;

              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => handleIntersectionClick(r, c)}
                  disabled={!isLocalTurnAllowed && !state.scoring_phase}
                  title={
                    cell !== 0 && libertyCount !== undefined
                      ? `Fila ${r + 1}, Col ${c + 1} · Libertades del grupo: ${libertyCount}${
                          isAtari ? " (¡ATARI!)" : ""
                        }`
                      : `Fila ${r + 1}, Col ${c + 1}`
                  }
                  className={`relative ${cellSizeClass} bg-amber-300/70 hover:bg-amber-400/70 border border-amber-700/60 flex items-center justify-center transition-colors cursor-pointer`}
                >
                  {cell === 0 && isHoshi && (
                    <span className="w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full bg-amber-950" />
                  )}
                  {cell === 1 && (
                    <span
                      className={`${stoneSizeClass} rounded-full bg-slate-950 border ${
                        isAtari
                          ? "border-rose-500 ring-2 ring-rose-500"
                          : isLastMove
                          ? "border-emerald-400 ring-2 ring-emerald-400"
                          : "border-slate-700"
                      } shadow-md flex items-center justify-center font-bold ${
                        isDead
                          ? "opacity-45 text-rose-400"
                          : isAtari
                          ? "text-rose-400"
                          : "text-slate-300"
                      }`}
                    >
                      {isDead
                        ? "✕"
                        : showLiberties && libertyCount !== undefined
                        ? libertyCount
                        : ""}
                    </span>
                  )}
                  {cell === 2 && (
                    <span
                      className={`${stoneSizeClass} rounded-full bg-white border ${
                        isAtari
                          ? "border-rose-600 ring-2 ring-rose-500"
                          : isLastMove
                          ? "border-emerald-500 ring-2 ring-emerald-500"
                          : "border-slate-300"
                      } shadow-md flex items-center justify-center font-bold ${
                        isDead
                          ? "opacity-45 text-rose-600"
                          : isAtari
                          ? "text-rose-600"
                          : "text-slate-700"
                      }`}
                    >
                      {isDead
                        ? "✕"
                        : showLiberties && libertyCount !== undefined
                        ? libertyCount
                        : ""}
                    </span>
                  )}
                </button>
              );
            })
          )}
        </div>
      </div>

      {/* Tournament Controls, Size Selector, Liberties & Territory Scoring */}
      <div className="flex-1 w-full p-4 sm:p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
        <div>
          <div className="text-xs text-slate-400">
            Go (Weiqi / Baduk) · Tablero {boardSize}×{boardSize} · Captura BFS de
            Cadenas
          </div>
          <h3 className="text-lg font-bold text-white mt-0.5">
            {state.winner !== null
              ? `Victoria del Jugador ${state.winner} (${
                  state.winner === 1 ? "Negras" : "Blancas + Komi"
                })`
              : state.scoring_phase
              ? "Fase de Conteo: Marca piedras muertas (✕) y confirma"
              : `Turno de ${state.turn === 1 ? "Negras (J1)" : "Blancas (J2)"}`}
          </h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <p className="text-xs text-amber-300 mt-1">
              Esperando turno del Jugador {state.turn} (Tú eres J{localPlayerId})
            </p>
          )}
        </div>

        {/* Live Capture / Ko / Suicide Rule Feedback Banner */}
        {state.last_banner && (
          <div
            className={`p-3 rounded-xl border text-xs font-medium ${
              state.last_banner.includes("Movimiento ilegal")
                ? "bg-rose-950/60 border-rose-500/60 text-rose-200"
                : state.last_banner.includes("Captura")
                ? "bg-emerald-950/60 border-emerald-500/60 text-emerald-200"
                : "bg-slate-950 border-slate-800 text-slate-300"
            }`}
          >
            {state.last_banner}
          </div>
        )}

        <div className="grid grid-cols-2 gap-3 text-xs font-mono">
          <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-slate-400">Negras (J1)</div>
            <div className="text-sm font-bold text-white mt-1">
              Capturas: {state.captures[1]} · Handicap: {state.handicap}
            </div>
          </div>
          <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-slate-400">Blancas (J2)</div>
            <div className="text-sm font-bold text-white mt-1">
              Capturas: {state.captures[2]} · Komi: +{state.komi}
            </div>
          </div>
        </div>

        {/* Board Size Selector (9x9, 13x13, 19x19) & Liberties Indicator Toggle */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-1">
          <div className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-slate-300">
              Tamaño del Goban:
            </span>
            <div className="flex items-center gap-1.5">
              {([9, 13, 19] as const).map((sz) => (
                <button
                  key={sz}
                  type="button"
                  disabled={!isLocalTurnAllowed}
                  onClick={() => handleSetBoardSize(sz)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-semibold cursor-pointer ${
                    boardSize === sz
                      ? "bg-emerald-600 text-white"
                      : "bg-slate-800 text-slate-300 hover:bg-slate-700"
                  }`}
                >
                  {sz}×{sz}
                </button>
              ))}
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-slate-300">
              Ayuda Visual de Cadenas:
            </span>
            <button
              type="button"
              onClick={() => setShowLiberties((prev) => !prev)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-colors cursor-pointer ${
                showLiberties
                  ? "bg-amber-500/20 border-amber-500/60 text-amber-300"
                  : "bg-slate-800 border-slate-700 text-slate-300"
              }`}
            >
              {showLiberties
                ? "Libertades y Atari (1): ON"
                : "Libertades y Atari: OFF"}
            </button>
          </div>
        </div>

        {/* Handicap Selector */}
        <div className="flex flex-col gap-2">
          <span className="text-xs font-medium text-slate-300">
            Handicap Inicial en Puntos Hoshi:
          </span>
          <div className="flex flex-wrap gap-2">
            {[0, 2, 3, 4].map((h) => (
              <button
                key={h}
                type="button"
                disabled={!isLocalTurnAllowed || state.winner !== null}
                onClick={() => handleSetHandicap(h)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold cursor-pointer ${
                  state.handicap === h
                    ? "bg-emerald-600 text-white"
                    : "bg-slate-800 text-slate-300 hover:bg-slate-700"
                }`}
              >
                {h === 0 ? "Sin Handicap" : `${h} Piedras`}
              </button>
            ))}
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-wrap gap-2 pt-2 border-t border-slate-800">
          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "go_game::PassCommand",
                  player: state.turn,
                })
              )
            }
            className="px-4 py-2 rounded-lg bg-amber-600 hover:bg-amber-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Pasar Turno ({state.passes}/2)
          </button>

          <button
            type="button"
            disabled={state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "go_game::ConfirmDeadCommand",
                  player: state.turn,
                })
              )
            }
            className="px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Confirmar Conteo y Komi 6.5
          </button>

          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "go_game::ResignCommand",
                  player: state.turn,
                })
              )
            }
            className="px-4 py-2 rounded-lg bg-rose-700 hover:bg-rose-600 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Rendirse
          </button>
        </div>
      </div>
    </div>
  );
};
