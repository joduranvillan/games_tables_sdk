import React from "react";

interface MilleBornesBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}

const ALL_SAFETIES = [
  "Prioridad",
  "Cisterna",
  "Impinchable",
  "As del Volante",
] as const;

export const MilleBornesBoard: React.FC<MilleBornesBoardProps> = ({
  stateJson,
  isLocalTurnAllowed,
  localPlayerId,
  onDispatchCommand,
}) => {
  const state = JSON.parse(stateJson) as {
    turn: 1 | 2;
    winner: 0 | 1 | 2 | null;
    distance: Record<1 | 2, number>;
    hands: Record<1 | 2, string[]>;
    safeties: Record<1 | 2, string[]>;
    hazard: Record<1 | 2, string | null>;
    banner: string;
  };

  const handlePlayCard = (idx: number) => {
    if (!isLocalTurnAllowed || state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "mille_bornes_game::PlayCardCommand",
        player: state.turn,
        card_index: idx,
      })
    );
  };

  const handleCoupFourre = (safety: string) => {
    if (state.winner !== null) return;
    onDispatchCommand(
      JSON.stringify({
        command_type: "mille_bornes_game::CoupFourreCommand",
        player: state.turn,
        safety,
      })
    );
  };

  const activeHand = state.hands[state.turn] || [];

  return (
    <div className="w-full max-w-5xl flex flex-col gap-6">
      {/* Banner */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="text-xs text-slate-400">
            Mil Millas (Mille Bornes) · Ruta de 1000 km, Escudos y ¡Coup Fourré!
          </div>
          <h3 className="text-base font-bold text-white mt-0.5">{state.banner}</h3>
          {!isLocalTurnAllowed && state.winner === null && (
            <span className="text-xs text-amber-300">
              Esperando turno de J{state.turn} (Tú: J{localPlayerId})
            </span>
          )}
        </div>

        <button
          type="button"
          disabled={!isLocalTurnAllowed || state.winner !== null}
          onClick={() => handleCoupFourre("Prioridad")}
          className="px-4 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 disabled:opacity-40 text-slate-950 text-xs font-bold shadow cursor-pointer shrink-0"
        >
          ⚡ ¡Coup Fourré! (+100 km)
        </button>
      </div>

      {/* 1000 km Odometer Tableau for Both Players */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {([1, 2] as const).map((pid) => {
          const km = state.distance[pid];
          const haz = state.hazard[pid];
          return (
            <div
              key={pid}
              className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4"
            >
              <div className="flex items-center justify-between">
                <span className="text-sm font-bold text-white">
                  Vehículo Jugador {pid}
                </span>
                <span className="text-sm font-mono font-bold text-emerald-400">
                  {km} / 1000 km
                </span>
              </div>

              <div className="w-full h-3 rounded-full bg-slate-950 border border-slate-800 overflow-hidden">
                <div
                  className="h-full bg-emerald-500 transition-all"
                  style={{ width: `${Math.min(100, (km / 1000) * 100)}%` }}
                />
              </div>

              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-400">Estado de Ruta:</span>
                {haz ? (
                  <span className="px-2.5 py-0.5 rounded bg-rose-950 border border-rose-700 text-rose-300 font-semibold">
                    ⚠️ Peligro: {haz}
                  </span>
                ) : (
                  <span className="px-2.5 py-0.5 rounded bg-emerald-950 border border-emerald-700 text-emerald-300 font-semibold">
                    🟢 Vía Libre (Luz Verde)
                  </span>
                )}
              </div>

              {/* 4 Safeties Tableau */}
              <div className="grid grid-cols-2 gap-2 pt-2 border-t border-slate-800">
                {ALL_SAFETIES.map((sf) => {
                  const active = state.safeties[pid].includes(sf);
                  return (
                    <div
                      key={sf}
                      className={`px-2.5 py-1.5 rounded-lg border text-xs font-medium flex items-center justify-between ${
                        active
                          ? "bg-amber-500/20 border-amber-500/60 text-amber-200"
                          : "bg-slate-950 border-slate-800 text-slate-500"
                      }`}
                    >
                      <span>🛡️ {sf}</span>
                      <span>{active ? "ACTIVO" : "—"}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>

      {/* Active Player Hand */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-3">
        <div className="text-xs font-medium text-slate-300">
          Mano Activa del Jugador {state.turn} (Haz clic en una carta para jugarla):
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3">
          {activeHand.map((card, idx) => (
            <button
              key={`${card}_${idx}`}
              type="button"
              disabled={!isLocalTurnAllowed || state.winner !== null}
              onClick={() => handlePlayCard(idx)}
              className="h-24 p-3 rounded-xl bg-slate-950 hover:bg-emerald-950/60 border border-slate-700 hover:border-emerald-400 flex flex-col items-start justify-between text-left transition-all cursor-pointer"
            >
              <span className="text-[10px] font-mono text-slate-400">
                CARTA #{idx + 1}
              </span>
              <span className="text-xs font-bold text-white leading-snug">
                {card}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};
