import React, { useState } from "react";
import { XiangqiPiece } from "../../wasm_pkg";

interface XiangqiBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const XIANGQI_HANZI: Record<XiangqiPiece["kind"], [string, string]> = {
  General: ["帥", "將"],
  Advisor: ["仕", "士"],
  Elephant: ["相", "象"],
  Horse: ["傌", "馬"],
  Chariot: ["俥", "車"],
  Cannon: ["炮", "砲"],
  Soldier: ["兵", "卒"],
};

export const XiangqiBoard: React.FC<XiangqiBoardProps> = ({
  stateJson,
  legalMovesJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selected, setSelected] = useState<[number, number] | null>(null);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    grid: (XiangqiPiece | null)[][];
    banner: string;
  };

  const legalMoves = JSON.parse(legalMovesJson) as Array<{
    command_type: string;
    from: [number, number];
    to: [number, number];
  }>;

  const selectedTargets = selected
    ? legalMoves.filter(
        (m) => m.from[0] === selected[0] && m.from[1] === selected[1]
      )
    : [];

  const handlePointClick = (r: number, c: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    const pc = state.grid[r]?.[c];

    if (selected) {
      if (selected[0] === r && selected[1] === c) {
        setSelected(null);
        return;
      }
      if (pc && pc.owner === state.turn) {
        setSelected([r, c]);
        return;
      }
      onDispatchCommand(
        JSON.stringify({
          command_type: "xiangqi_game::MovePieceCommand",
          player: state.turn,
          from: selected,
          to: [r, c],
        })
      );
      setSelected(null);
      return;
    }

    if (pc && pc.owner === state.turn) {
      setSelected([r, c]);
    }
  };

  const isPalace = (r: number, c: number) =>
    c >= 3 && c <= 5 && ((r >= 0 && r <= 2) || (r >= 7 && r <= 9));

  return (
    <div className="w-full max-w-5xl flex flex-col lg:flex-row gap-8 items-start">
      {/* 9x10 Xiangqi Board with Chu He / Han Jie River */}
      <div className="p-5 rounded-2xl bg-amber-950/90 border-4 border-amber-700 shadow-2xl flex flex-col gap-1.5">
        {state.grid.map((row, r) => (
          <React.Fragment key={r}>
            {r === 5 && (
              <div className="py-1.5 px-4 my-0.5 rounded bg-sky-950/80 border border-sky-700/50 flex items-center justify-between text-xs font-bold tracking-widest text-sky-200">
                <span>楚 河 · RÍO CHU HE</span>
                <span>漢 界 · HAN JIE</span>
              </div>
            )}
            <div className="grid grid-cols-9 gap-1.5">
              {row.map((pc, c) => {
                const isSel = selected?.[0] === r && selected?.[1] === c;
                const isTarget = selectedTargets.some(
                  (m) => m.to[0] === r && m.to[1] === c
                );
                const palace = isPalace(r, c);
                return (
                  <button
                    key={`${r}_${c}`}
                    type="button"
                    onClick={() => handlePointClick(r, c)}
                    disabled={!isLocalTurnAllowed || state.winner !== null}
                    className={`relative w-10 h-10 sm:w-11 sm:h-11 rounded-lg border flex items-center justify-center transition-colors cursor-pointer ${
                      isSel
                        ? "bg-emerald-500/40 border-emerald-400"
                        : isTarget
                        ? "bg-emerald-800/60 border-emerald-400"
                        : palace
                        ? "bg-amber-900/80 border-amber-500/60"
                        : "bg-amber-950/70 border-amber-800/70 hover:bg-amber-900"
                    }`}
                  >
                    {pc && (
                      <span
                        className={`w-8 h-8 sm:w-9 sm:h-9 rounded-full border-2 flex items-center justify-center text-sm font-bold shadow ${
                          pc.owner === 1
                            ? "bg-amber-100 text-rose-700 border-rose-600"
                            : "bg-amber-100 text-slate-900 border-slate-800"
                        }`}
                      >
                        {XIANGQI_HANZI[pc.kind][pc.owner === 1 ? 0 : 1]}
                      </span>
                    )}
                    {isTarget && !pc && (
                      <span className="w-2.5 h-2.5 rounded-full bg-emerald-400" />
                    )}
                  </button>
                );
              })}
            </div>
          </React.Fragment>
        ))}
      </div>

      {/* Info & Controls */}
      <div className="flex-1 w-full p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
        <div>
          <div className="text-xs text-slate-400">
            Xiangqi (Ajedrez Chino) · Tablero 9×10, Palacios 3×3 y General Volador
          </div>
          <h3 className="text-lg font-bold text-white mt-0.5">
            {state.winner !== null
              ? `¡Victoria del Jugador ${state.winner}!`
              : `Turno de ${state.turn === 1 ? "Rojas (J1)" : "Negras (J2)"}`}
          </h3>
          <p className="text-xs text-slate-300 mt-1">{state.banner}</p>
          {!isLocalTurnAllowed && state.winner === null && (
            <p className="text-xs text-amber-300 mt-1">
              Esperando turno del Jugador {state.turn} (Tú: J{localPlayerId})
            </p>
          )}
        </div>

        <div className="pt-3 border-t border-slate-800">
          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "xiangqi_game::ResignCommand",
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
