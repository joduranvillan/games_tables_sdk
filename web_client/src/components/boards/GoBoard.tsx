import React from "react";

interface GoBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const HOSHI_9 = new Set(["2_2", "2_6", "6_2", "6_6", "4_4"]);

export const GoBoard: React.FC<GoBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
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
  };

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

  return (
    <div className="w-full max-w-5xl flex flex-col lg:flex-row gap-8 items-start">
      {/* 9x9 Goban Canvas */}
      <div className="p-6 rounded-2xl bg-amber-200/95 border-4 border-amber-800 shadow-2xl">
        <div className="grid grid-cols-9 gap-1.5">
          {state.grid.map((row, r) =>
            row.map((cell, c) => {
              const key = `${r}_${c}`;
              const isHoshi = HOSHI_9.has(key);
              const isDead = state.dead_stones.includes(key);

              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => handleIntersectionClick(r, c)}
                  disabled={!isLocalTurnAllowed && !state.scoring_phase}
                  className="relative w-10 h-10 sm:w-12 sm:h-12 rounded-lg bg-amber-300/70 hover:bg-amber-400/70 border border-amber-700/60 flex items-center justify-center transition-colors cursor-pointer"
                >
                  {cell === 0 && isHoshi && (
                    <span className="w-2 h-2 rounded-full bg-amber-950" />
                  )}
                  {cell === 1 && (
                    <span
                      className={`w-8 h-8 sm:w-9 sm:h-9 rounded-full bg-slate-950 border border-slate-700 shadow-md flex items-center justify-center text-xs font-bold text-rose-400 ${
                        isDead ? "opacity-45" : ""
                      }`}
                    >
                      {isDead ? "✕" : ""}
                    </span>
                  )}
                  {cell === 2 && (
                    <span
                      className={`w-8 h-8 sm:w-9 sm:h-9 rounded-full bg-white border border-slate-300 shadow-md flex items-center justify-center text-xs font-bold text-rose-600 ${
                        isDead ? "opacity-45" : ""
                      }`}
                    >
                      {isDead ? "✕" : ""}
                    </span>
                  )}
                </button>
              );
            })
          )}
        </div>
      </div>

      {/* Tournament Controls & Territory Scoring */}
      <div className="flex-1 w-full p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
        <div>
          <div className="text-xs text-slate-400">Go (Weiqi / Baduk) · Tablero 9×9</div>
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
