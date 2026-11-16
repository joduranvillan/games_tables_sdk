import React, { useState } from "react";
import { DiceRoller3D } from "../common/DiceRoller3D";

interface LudoBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const SAFE_STAR_STEPS = new Set([1, 9, 14, 22, 27, 35, 40, 48]);

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

  const handleRollAndAdvance = (d1: number, d2: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "ludo_game::MoveTokenCommand",
        player: state.turn,
        token_index: selectedTokenIndex,
        d1,
        d2,
      })
    );
  };

  return (
    <div className="w-full max-w-5xl flex flex-col gap-6">
      {/* Header & 3D Dice */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800">
        <div className="flex flex-col gap-1">
          <div className="text-xs text-slate-400">
            Ludo · Circuito de 52 Casillas + 5 de Meta y 8 Casillas Estrella Seguras
          </div>
          <h3 className="text-base font-bold text-white">{state.banner}</h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <span className="text-xs text-amber-300">
              Esperando turno de J{state.turn} (Tú: J{localPlayerId})
            </span>
          )}
        </div>

        <DiceRoller3D
          dice={state.dice}
          disabled={!isLocalTurnAllowed || state.winner !== null}
          onRoll={handleRollAndAdvance}
        />
      </div>

      {/* Token Selector & Track Progress */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {([1, 2] as const).map((pid) => (
          <div
            key={pid}
            className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4"
          >
            <div className="flex items-center justify-between">
              <h4 className="text-sm font-bold text-white">
                Jugador {pid} ({pid === 1 ? "Escuadra Roja" : "Escuadra Azul"})
              </h4>
              <span className="text-xs font-mono text-slate-400">
                Meta: 57 pasos por ficha
              </span>
            </div>

            <div className="grid grid-cols-2 gap-3">
              {state.tokens[pid].map((steps, idx) => {
                const isSafe = SAFE_STAR_STEPS.has(steps);
                const isGoal = steps >= 57;
                const isSelected = state.turn === pid && selectedTokenIndex === idx;

                return (
                  <button
                    key={idx}
                    type="button"
                    disabled={!isLocalTurnAllowed || state.turn !== pid}
                    onClick={() => setSelectedTokenIndex(idx)}
                    className={`p-3.5 rounded-xl border text-left flex flex-col gap-2 transition-all cursor-pointer ${
                      isSelected
                        ? "bg-emerald-950/70 border-emerald-400 ring-2 ring-emerald-400"
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

                    <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                      <div
                        className={`h-full ${
                          pid === 1 ? "bg-rose-500" : "bg-sky-500"
                        }`}
                        style={{ width: `${Math.min(100, (steps / 57) * 100)}%` }}
                      />
                    </div>

                    <div className="text-[11px] text-slate-400 font-mono">
                      {isGoal
                        ? "🏁 En Meta"
                        : steps === 0
                        ? "En Base Inicial"
                        : isSafe
                        ? "★ Casilla Segura Estrella"
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
  );
};
