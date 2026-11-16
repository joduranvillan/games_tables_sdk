import React, { useState } from "react";
import { CrisisTerritory } from "../../wasm_pkg";

interface CrisisBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

export const CrisisBoard: React.FC<CrisisBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const [selectedAttackerId, setSelectedAttackerId] = useState<number | null>(null);

  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    territories: CrisisTerritory[];
    phase: "PlaceArmies" | "Attack" | "Fortify";
    armies_remaining: number;
    cards: Record<1 | 2, number>;
    banner: string;
  };

  const handleTerritoryClick = (terr: CrisisTerritory) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;

    if (state.phase === "PlaceArmies" && state.armies_remaining > 0) {
      if (terr.owner === state.turn) {
        onDispatchCommand(
          JSON.stringify({
            command_type: "crisis_game::PlaceArmiesCommand",
            player: state.turn,
            territory: terr.id,
            count: 1,
          })
        );
      }
      return;
    }

    if (terr.owner === state.turn) {
      setSelectedAttackerId(terr.id === selectedAttackerId ? null : terr.id);
    } else if (selectedAttackerId !== null) {
      onDispatchCommand(
        JSON.stringify({
          command_type: "crisis_game::AttackCommand",
          player: state.turn,
          from: selectedAttackerId,
          to: terr.id,
        })
      );
    }
  };

  return (
    <div className="w-full max-w-6xl flex flex-col gap-6">
      {/* Top Strategic HUD */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-5 rounded-2xl bg-slate-900 border border-slate-800">
        <div>
          <div className="text-xs text-slate-400">
            Crisis / TEG · 30 Territorios en 6 Continentes, Canje de Tarjetas y Combate 3v3
          </div>
          <h3 className="text-base font-bold text-white mt-0.5">{state.banner}</h3>
          <div className="flex flex-wrap items-center gap-4 text-xs font-mono text-slate-300 mt-1">
            <span>
              Fase Actual: <strong className="text-emerald-400">{state.phase}</strong>
            </span>
            <span>·</span>
            <span>
              Refuerzos disponibles:{" "}
              <strong className="text-white">{state.armies_remaining}</strong>
            </span>
            <span>·</span>
            <span>
              Tarjetas J1: {state.cards[1]} | J2: {state.cards[2]}
            </span>
            {!isLocalTurnAllowed && state.winner === null && (
              <span className="text-amber-300">
                Esperando turno de J{state.turn} (Tú: J{localPlayerId})
              </span>
            )}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={!isLocalTurnAllowed || state.cards[state.turn] < 3}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "crisis_game::ExchangeCardsCommand",
                  player: state.turn,
                })
              )
            }
            className="px-3.5 py-2 rounded-lg bg-amber-600 hover:bg-amber-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Canjear 3 Tarjetas (+6 Ejércitos)
          </button>

          <button
            type="button"
            disabled={!isLocalTurnAllowed}
            onClick={() =>
              onDispatchCommand(
                JSON.stringify({
                  command_type: "crisis_game::EndTurnCommand",
                  player: state.turn,
                })
              )
            }
            className="px-3.5 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white text-xs font-semibold cursor-pointer"
          >
            Finalizar Turno
          </button>
        </div>
      </div>

      {/* 30 Territories Strategic Map Grid */}
      <div className="grid grid-cols-2 sm:grid-cols-5 lg:grid-cols-6 gap-2.5 p-5 rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl">
        {state.territories.map((t) => {
          const isSelected = selectedAttackerId === t.id;
          return (
            <button
              key={t.id}
              type="button"
              onClick={() => handleTerritoryClick(t)}
              disabled={!isLocalTurnAllowed || state.winner !== null}
              className={`p-3 rounded-xl border text-left flex flex-col justify-between gap-2 transition-all cursor-pointer ${
                isSelected
                  ? "ring-2 ring-amber-400 border-amber-400 bg-slate-800"
                  : t.owner === 1
                  ? "bg-rose-950/50 border-rose-700/70 hover:bg-rose-900/50"
                  : "bg-sky-950/50 border-sky-700/70 hover:bg-sky-900/50"
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-mono text-slate-400">
                  {t.continent}
                </span>
                <span
                  className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${
                    t.owner === 1
                      ? "bg-rose-600 text-white"
                      : "bg-sky-600 text-white"
                  }`}
                >
                  J{t.owner}
                </span>
              </div>

              <div className="text-xs font-bold text-white">{t.name}</div>

              <div className="flex items-center justify-between text-xs font-mono">
                <span className="text-slate-400">Ejércitos:</span>
                <strong className="text-amber-300 text-sm">{t.armies}</strong>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};
