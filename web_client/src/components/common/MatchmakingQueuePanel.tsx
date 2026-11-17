import React, { useEffect, useState } from "react";
import { MatchmakingQueueTicket } from "../../bridge/relayClient";

export interface MatchmakingQueuePanelProps {
  activeGame: string;
  activeGameTitle: string;
  playerElo: number;
  playerName: string;
  isQueuing: boolean;
  activeTicket: MatchmakingQueueTicket | null;
  onStartQueue: (maxEloDelta: number) => void;
  onExpandQueueTolerance: (newMaxDelta: number) => void;
  onCancelQueue: () => void;
  onQuickCalibratedAiMatch: (targetDifficulty: 0 | 1 | 2 | 3) => void;
}

export const MATCHMAKING_TOLERANCE_PRESETS: { label: string; delta: number; desc: string }[] = [
  { label: "Estricto ±150", delta: 150, desc: "Rivales muy próximos a tu rating" },
  { label: "Estándar ±300", delta: 300, desc: "Balance óptimo entre espera y nivel" },
  { label: "Abierto ±800", delta: 800, desc: "Emparejamiento rápido global" },
];

export function selectCalibratedAiDifficultyForElo(elo: number): 0 | 1 | 2 | 3 {
  if (elo < 1100) return 0;
  if (elo < 1300) return 1;
  if (elo < 1500) return 2;
  return 3;
}

export const MatchmakingQueuePanel: React.FC<MatchmakingQueuePanelProps> = ({
  activeGameTitle,
  playerElo,
  playerName,
  isQueuing,
  activeTicket,
  onStartQueue,
  onExpandQueueTolerance,
  onCancelQueue,
  onQuickCalibratedAiMatch,
}) => {
  const [selectedDelta, setSelectedDelta] = useState<number>(150);
  const [elapsedSecs, setElapsedSecs] = useState<number>(0);

  useEffect(() => {
    if (!isQueuing || !activeTicket) {
      setElapsedSecs(0);
      return;
    }
    const interval = setInterval(() => {
      const secs = Math.max(0, Math.floor((Date.now() - activeTicket.queuedAtMs) / 1000));
      setElapsedSecs(secs);
      if (secs > 0 && secs % 5 === 0) {
        const expanded = Math.min(1000, selectedDelta + Math.floor(secs / 5) * 100);
        if (expanded > activeTicket.maxEloDelta) {
          onExpandQueueTolerance(expanded);
        }
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [isQueuing, activeTicket, selectedDelta, onExpandQueueTolerance]);

  const currentDelta = activeTicket ? activeTicket.maxEloDelta : selectedDelta;
  const minElo = Math.max(100, playerElo - currentDelta);
  const maxElo = playerElo + currentDelta;
  const calibratedAi = selectCalibratedAiDifficultyForElo(playerElo);

  return (
    <div className="bg-slate-900/90 border border-slate-800 rounded-xl p-4 space-y-3">
      <div className="flex items-center justify-between gap-2">
        <div>
          <h3 className="text-xs font-bold text-slate-200 tracking-wide">
            Cola de Matchmaking ELO Automático (Relay + Multi-Pestaña)
          </h3>
          <p className="text-[11px] text-slate-400">
            {activeGameTitle} · Rating actual:{" "}
            <span className="font-mono tabular-nums text-amber-400 font-semibold">
              {playerElo} ELO
            </span>
          </p>
        </div>
        <span className="text-[11px] font-mono tabular-nums text-slate-400">
          Rango [{minElo}–{maxElo}]
        </span>
      </div>

      {!isQueuing ? (
        <div className="space-y-2.5">
          <div className="grid grid-cols-3 gap-1.5 bg-slate-950 p-1 rounded-lg border border-slate-800">
            {MATCHMAKING_TOLERANCE_PRESETS.map((preset) => (
              <button
                key={preset.delta}
                type="button"
                onClick={() => setSelectedDelta(preset.delta)}
                title={preset.desc}
                className={`px-2 py-1.5 rounded text-[11px] font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                  selectedDelta === preset.delta
                    ? "bg-amber-500 text-slate-950 font-semibold"
                    : "text-slate-400 hover:text-slate-200"
                }`}
              >
                {preset.label}
              </button>
            ))}
          </div>

          <button
            type="button"
            onClick={() => onStartQueue(selectedDelta)}
            className="w-full py-2 px-3 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            Buscar Rival en Cola ELO ({playerElo} ±{selectedDelta})
          </button>
        </div>
      ) : (
        <div className="bg-slate-950 border border-emerald-500/40 rounded-lg p-3 space-y-2.5">
          <div className="flex items-center justify-between text-xs">
            <span className="text-emerald-300 font-semibold">
              Buscando oponente para {playerName}...
            </span>
            <span className="font-mono tabular-nums text-amber-300 font-bold">
              {String(Math.floor(elapsedSecs / 60)).padStart(2, "0")}:
              {String(elapsedSecs % 60).padStart(2, "0")}
            </span>
          </div>

          <div className="text-[11px] text-slate-400 flex items-center justify-between">
            <span>
              Sala reservada:{" "}
              <strong className="font-mono text-slate-200">{activeTicket?.roomCode}</strong>
            </span>
            <span className="font-mono tabular-nums">
              Ventana activa: ±{currentDelta} ELO
            </span>
          </div>

          <p className="text-[10px] text-slate-500 leading-relaxed">
            La ventana se amplía +100 ELO cada 5s. Si abres otra pestaña y entras en cola con rango compatible, se emparejarán automáticamente.
          </p>

          <div className="grid grid-cols-2 gap-2 pt-1">
            <button
              type="button"
              onClick={() => {
                onCancelQueue();
                onQuickCalibratedAiMatch(calibratedAi);
              }}
              className="py-1.5 px-2.5 bg-amber-500/20 hover:bg-amber-500/30 border border-amber-500/40 text-amber-300 rounded text-[11px] font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              Sparring IA Calibrada (Niv. {calibratedAi + 1})
            </button>
            <button
              type="button"
              onClick={onCancelQueue}
              className="py-1.5 px-2.5 bg-rose-950/70 hover:bg-rose-900/70 border border-rose-700/50 text-rose-200 rounded text-[11px] font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              Cancelar Cola
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
