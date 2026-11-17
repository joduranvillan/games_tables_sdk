import React, { useState } from "react";
import { DiceRoller3D } from "../common/DiceRoller3D";

interface BackgammonBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

export const BackgammonBoard: React.FC<BackgammonBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selectedPoint, setSelectedPoint] = useState<number | null>(null);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    points: { count: number; owner: 0 | 1 | 2 }[];
    bar: Record<1 | 2, number>;
    borne_off: Record<1 | 2, number>;
    dice: [number, number];
    cube_value: number;
    cube_offered_by: 1 | 2 | null;
  };

  const handleRoll = (d1: number, d2: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "backgammon_game::RollDiceCommand",
        player: state.turn,
        d1,
        d2,
      })
    );
  };

  const handlePointClick = (idx: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    const pt = state.points[idx];

    if (selectedPoint !== null) {
      if (selectedPoint === idx) {
        setSelectedPoint(null);
        return;
      }
      onDispatchCommand(
        JSON.stringify({
          command_type: "backgammon_game::MoveCheckerCommand",
          player: state.turn,
          from: selectedPoint,
          to: idx,
        })
      );
      setSelectedPoint(null);
      return;
    }

    if (pt && pt.owner === state.turn && pt.count > 0) {
      setSelectedPoint(idx);
    }
  };

  return (
    <div className="w-full max-w-5xl flex flex-col gap-6">
      {/* Top Bar: DiceRoller3D & Doubling Cube */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800">
        <div className="flex flex-col gap-1">
          <div className="text-xs text-slate-400">
            Backgammon · 24 Picos, Barra Central, Bear-Off y Cubo de Doblaje
          </div>
          <h3 className="text-base font-bold text-white">
            {state.winner !== null
              ? `¡Victoria del Jugador ${state.winner} (Cubo ×${state.cube_value})!`
              : `Turno del Jugador ${state.turn} · Cubo de Doblaje: ×${state.cube_value}`}
          </h3>
          <div className="flex flex-wrap items-center gap-4 text-xs text-slate-300 font-mono mt-1">
            <span>
              J1 Barra: {state.bar[1]} · Bear-Off: {state.borne_off[1]}/15
            </span>
            <span>·</span>
            <span>
              J2 Barra: {state.bar[2]} · Bear-Off: {state.borne_off[2]}/15
            </span>
            {!isLocalTurnAllowed && state.winner === null && (
              <span className="text-amber-300">
                Esperando turno de J{state.turn} (Tú: J{localPlayerId})
              </span>
            )}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <DiceRoller3D
            dice={state.dice}
            disabled={!isLocalTurnAllowed || state.winner !== null}
            onRoll={handleRoll}
          />
        </div>
      </div>

      {/* Doubling Cube Controls */}
      <div className="flex flex-wrap items-center justify-between gap-3 p-4 rounded-xl bg-slate-900 border border-slate-800">
        <div className="flex items-center gap-3">
          <span className="px-3 py-1.5 rounded-lg bg-amber-500/20 border border-amber-500/50 text-amber-300 text-xs font-mono font-bold">
            Cubo: ×{state.cube_value}
          </span>
          {state.cube_offered_by && (
            <span className="text-xs text-amber-300">
              Jugador {state.cube_offered_by} ofrece doblar la apuesta a ×
              {state.cube_value * 2}
            </span>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {!state.cube_offered_by ? (
            <button
              type="button"
              disabled={!isLocalTurnAllowed || state.winner !== null}
              onClick={() =>
                onDispatchCommand(
                  JSON.stringify({
                    command_type: "backgammon_game::OfferDoubleCommand",
                    player: state.turn,
                  })
                )
              }
              className="px-3.5 py-1.5 rounded-lg bg-amber-600 hover:bg-amber-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
            >
              Ofrecer Doblar (×{state.cube_value * 2})
            </button>
          ) : (
            <>
              <button
                type="button"
                onClick={() =>
                  onDispatchCommand(
                    JSON.stringify({
                      command_type: "backgammon_game::AcceptDoubleCommand",
                      player: state.turn,
                    })
                  )
                }
                className="px-3.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
              >
                Aceptar Doblaje
              </button>
              <button
                type="button"
                onClick={() =>
                  onDispatchCommand(
                    JSON.stringify({
                      command_type: "backgammon_game::RejectDoubleCommand",
                      player: state.turn,
                    })
                  )
                }
                className="px-3.5 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold cursor-pointer"
              >
                Rechazar
              </button>
            </>
          )}

          {selectedPoint !== null && (
            <button
              type="button"
              onClick={() => {
                onDispatchCommand(
                  JSON.stringify({
                    command_type: "backgammon_game::MoveCheckerCommand",
                    player: state.turn,
                    from: selectedPoint,
                    to: 24,
                  })
                );
                setSelectedPoint(null);
              }}
              className="px-3.5 py-1.5 rounded-lg bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold cursor-pointer"
            >
              Bear-Off (Retirar Ficha de Pico #{selectedPoint + 1})
            </button>
          )}
        </div>
      </div>

      {/* 24 Points Grid */}
      <div className="grid grid-cols-6 sm:grid-cols-12 gap-2 p-5 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl">
        {state.points.map((pt, idx) => {
          const isSel = selectedPoint === idx;
          return (
            <button
              key={idx}
              type="button"
              onClick={() => handlePointClick(idx)}
              disabled={!isLocalTurnAllowed || state.winner !== null}
              className={`h-28 rounded-xl p-2 border flex flex-col items-center justify-between transition-all cursor-pointer ${
                isSel
                  ? "bg-emerald-950 border-emerald-400 ring-2 ring-emerald-400"
                  : idx % 2 === 0
                  ? "bg-amber-950/50 border-amber-800/60 hover:bg-amber-900/50"
                  : "bg-slate-950 border-slate-800 hover:bg-slate-800"
              }`}
            >
              <span className="text-[10px] font-mono text-slate-400">#{idx + 1}</span>
              {pt.count > 0 ? (
                <div
                  className={`w-9 h-9 rounded-full border-2 flex items-center justify-center text-xs font-bold shadow ${
                    pt.owner === 1
                      ? "bg-rose-500 border-white text-white"
                      : "bg-sky-500 border-white text-white"
                  }`}
                >
                  {pt.count}
                </div>
              ) : (
                <span className="text-[10px] text-slate-600">·</span>
              )}
              <span className="text-[10px] font-mono text-slate-400">
                {pt.owner === 1 ? "J1" : pt.owner === 2 ? "J2" : ""}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
};
