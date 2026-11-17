import React, { useState } from "react";
import { MonopolySpace } from "../../wasm_pkg";
import { DiceRoller3D } from "../common/DiceRoller3D";

interface MonopolyBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

export const MonopolyBoard: React.FC<MonopolyBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selectedSpaceIdx, setSelectedSpaceIdx] = useState<number>(0);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    spaces: MonopolySpace[];
    cash: Record<1 | 2, number>;
    pos: Record<1 | 2, number>;
    in_jail: Record<1 | 2, boolean>;
    dice: [number, number];
    auction_space: number | null;
    banner: string;
  };

  const currentSpace = state.spaces[state.pos[state.turn]] || state.spaces[0];
  const inspectedSpace = state.spaces[selectedSpaceIdx] || currentSpace;

  const handleRoll = (d1: number, d2: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "monopoly_game::RollDiceCommand",
        player: state.turn,
        d1,
        d2,
      })
    );
  };

  return (
    <div className="w-full max-w-6xl flex flex-col gap-6">
      {/* Top Economy HUD & 3D Dice */}
      <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800">
        <div className="flex flex-col gap-1">
          <div className="text-xs text-slate-400">
            Monopoly · 40 Propiedades, Casas/Hoteles Uniformes, Hipotecas y Alquileres
          </div>
          <h3 className="text-base font-bold text-white">{state.banner}</h3>
          <div className="flex flex-wrap items-center gap-4 text-xs font-mono text-slate-300 mt-1">
            <span>
              Jugador 1:{" "}
              <strong className="text-emerald-400">${state.cash[1]}</strong> (Casilla{" "}
              {state.pos[1]})
            </span>
            <span>·</span>
            <span>
              Jugador 2:{" "}
              <strong className="text-sky-400">${state.cash[2]}</strong> (Casilla{" "}
              {state.pos[2]})
            </span>
            {!isLocalTurnAllowed && state.winner === null && (
              <span className="text-amber-300">
                Esperando turno de J{state.turn} (Tú: J{localPlayerId})
              </span>
            )}
          </div>
        </div>

        <DiceRoller3D
          dice={state.dice}
          disabled={!isLocalTurnAllowed || state.winner !== null}
          onRoll={handleRoll}
        />
      </div>

      {/* Action Bar for Current / Selected Property */}
      <div className="flex flex-wrap items-center justify-between gap-3 p-4 rounded-xl bg-slate-900 border border-slate-800">
        <div className="text-xs text-slate-200 font-mono">
          Casilla Actual J{state.turn}:{" "}
          <strong className="text-white">{currentSpace.name}</strong> (Precio: $
          {currentSpace.price} · Alquiler base: ${currentSpace.rent})
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={
              !isLocalTurnAllowed ||
              currentSpace.price === 0 ||
              currentSpace.owner !== null
            }
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "monopoly_game::BuyPropertyCommand",
                  player: state.turn,
                })
              )
            }
            className="px-3.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Comprar Propiedad (${currentSpace.price})
          </button>

          <button
            type="button"
            disabled={!isLocalTurnAllowed || inspectedSpace.owner !== state.turn}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "monopoly_game::BuildHouseCommand",
                  player: state.turn,
                  space: inspectedSpace.index,
                })
              )
            }
            className="px-3.5 py-1.5 rounded-lg bg-sky-600 hover:bg-sky-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Construir Casa/Hotel ($50)
          </button>

          <button
            type="button"
            disabled={
              !isLocalTurnAllowed ||
              inspectedSpace.owner !== state.turn ||
              inspectedSpace.mortgaged
            }
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "monopoly_game::MortgagePropertyCommand",
                  player: state.turn,
                  space: inspectedSpace.index,
                })
              )
            }
            className="px-3.5 py-1.5 rounded-lg bg-amber-600 hover:bg-amber-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Hipotecar
          </button>

          <button
            type="button"
            disabled={!isLocalTurnAllowed}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "monopoly_game::EndTurnCommand",
                  player: state.turn,
                })
              )
            }
            className="px-3.5 py-1.5 rounded-lg bg-slate-700 hover:bg-slate-600 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Terminar Turno
          </button>
        </div>
      </div>

      {/* 40 Spaces Grid */}
      <div className="grid grid-cols-4 sm:grid-cols-8 lg:grid-cols-10 gap-2 p-4 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl">
        {state.spaces.map((sp) => {
          const p1Here = state.pos[1] === sp.index;
          const p2Here = state.pos[2] === sp.index;
          const isInspected = selectedSpaceIdx === sp.index;

          return (
            <button
              key={sp.index}
              type="button"
              onClick={() => setSelectedSpaceIdx(sp.index)}
              className={`h-24 p-2 rounded-xl border text-left flex flex-col justify-between transition-all cursor-pointer ${
                isInspected
                  ? "bg-slate-800 border-emerald-400 ring-1 ring-emerald-400"
                  : sp.owner === 1
                  ? "bg-rose-950/40 border-rose-700/70"
                  : sp.owner === 2
                  ? "bg-sky-950/40 border-sky-700/70"
                  : "bg-slate-950 border-slate-800 hover:border-slate-700"
              }`}
            >
              <div className="flex items-center justify-between w-full">
                <span className="text-[10px] font-mono text-slate-400">
                  #{sp.index}
                </span>
                {sp.houses > 0 && (
                  <span className="text-[10px] font-bold text-emerald-400">
                    🏠×{sp.houses}
                  </span>
                )}
              </div>

              <div className="text-[11px] font-semibold text-white leading-tight line-clamp-2">
                {sp.name}
              </div>

              <div className="flex items-center justify-between w-full">
                <span className="text-[10px] font-mono text-slate-400">
                  {sp.price > 0 ? `$${sp.price}` : ""}
                </span>
                <div className="flex items-center gap-1">
                  {p1Here && (
                    <span className="px-1 rounded bg-rose-500 text-[9px] font-bold text-white">
                      J1
                    </span>
                  )}
                  {p2Here && (
                    <span className="px-1 rounded bg-sky-500 text-[9px] font-bold text-white">
                      J2
                    </span>
                  )}
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};
