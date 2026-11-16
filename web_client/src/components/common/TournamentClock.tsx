import React, { useEffect } from "react";
import { Clock } from "lucide-react";

export type ClockPresetId = "none" | "blitz_3_2" | "rapid_10_0" | "byoyomi_5_30";

export interface TournamentClockState {
  preset: ClockPresetId;
  mainMs: Record<1 | 2, number>;
  incrementMs: number;
  byoyomiPeriods: Record<1 | 2, number>;
  byoyomiPeriodMs: number;
  byoyomiCurrentMs: Record<1 | 2, number>;
  flaggedWinner: 1 | 2 | null;
}

export function createInitialClockState(preset: ClockPresetId): TournamentClockState {
  if (preset === "blitz_3_2") {
    return {
      preset,
      mainMs: { 1: 180_000, 2: 180_000 },
      incrementMs: 2_000,
      byoyomiPeriods: { 1: 0, 2: 0 },
      byoyomiPeriodMs: 0,
      byoyomiCurrentMs: { 1: 0, 2: 0 },
      flaggedWinner: null,
    };
  }
  if (preset === "rapid_10_0") {
    return {
      preset,
      mainMs: { 1: 600_000, 2: 600_000 },
      incrementMs: 0,
      byoyomiPeriods: { 1: 0, 2: 0 },
      byoyomiPeriodMs: 0,
      byoyomiCurrentMs: { 1: 0, 2: 0 },
      flaggedWinner: null,
    };
  }
  if (preset === "byoyomi_5_30") {
    return {
      preset,
      mainMs: { 1: 300_000, 2: 300_000 },
      incrementMs: 0,
      byoyomiPeriods: { 1: 3, 2: 3 },
      byoyomiPeriodMs: 30_000,
      byoyomiCurrentMs: { 1: 30_000, 2: 30_000 },
      flaggedWinner: null,
    };
  }
  return {
    preset: "none",
    mainMs: { 1: 0, 2: 0 },
    incrementMs: 0,
    byoyomiPeriods: { 1: 0, 2: 0 },
    byoyomiPeriodMs: 0,
    byoyomiCurrentMs: { 1: 0, 2: 0 },
    flaggedWinner: null,
  };
}

export function applyClockMoveComplete(
  state: TournamentClockState,
  playerWhoMoved: 1 | 2
): TournamentClockState {
  if (state.preset === "none" || state.flaggedWinner !== null) return state;

  const nextMain = { ...state.mainMs };
  const nextByoCurrent = { ...state.byoyomiCurrentMs };

  if (state.incrementMs > 0) {
    nextMain[playerWhoMoved] += state.incrementMs;
  }
  if (
    state.preset === "byoyomi_5_30" &&
    nextMain[playerWhoMoved] === 0 &&
    state.byoyomiPeriods[playerWhoMoved] > 0
  ) {
    nextByoCurrent[playerWhoMoved] = state.byoyomiPeriodMs;
  }

  return {
    ...state,
    mainMs: nextMain,
    byoyomiCurrentMs: nextByoCurrent,
  };
}

export function stepClockTick(
  state: TournamentClockState,
  activeTurn: 1 | 2,
  deltaMs: number
): TournamentClockState {
  if (state.preset === "none" || state.flaggedWinner !== null || deltaMs <= 0) {
    return state;
  }

  const nextMain = { ...state.mainMs };
  const nextPeriods = { ...state.byoyomiPeriods };
  const nextByoCurrent = { ...state.byoyomiCurrentMs };
  let flaggedWinner: 1 | 2 | null = state.flaggedWinner;

  if (nextMain[activeTurn] > 0) {
    const rem = nextMain[activeTurn] - deltaMs;
    if (rem > 0) {
      nextMain[activeTurn] = rem;
    } else {
      const overflow = Math.abs(rem);
      nextMain[activeTurn] = 0;
      if (state.preset === "byoyomi_5_30" && nextPeriods[activeTurn] > 0) {
        nextByoCurrent[activeTurn] = Math.max(0, state.byoyomiPeriodMs - overflow);
      } else {
        flaggedWinner = activeTurn === 1 ? 2 : 1;
      }
    }
  } else if (state.preset === "byoyomi_5_30") {
    const remByo = nextByoCurrent[activeTurn] - deltaMs;
    if (remByo > 0) {
      nextByoCurrent[activeTurn] = remByo;
    } else {
      nextPeriods[activeTurn] -= 1;
      if (nextPeriods[activeTurn] > 0) {
        nextByoCurrent[activeTurn] = state.byoyomiPeriodMs;
      } else {
        nextByoCurrent[activeTurn] = 0;
        flaggedWinner = activeTurn === 1 ? 2 : 1;
      }
    }
  }

  return {
    ...state,
    mainMs: nextMain,
    byoyomiPeriods: nextPeriods,
    byoyomiCurrentMs: nextByoCurrent,
    flaggedWinner,
  };
}

export function formatClockMs(ms: number): string {
  const totalSec = Math.max(0, Math.ceil(ms / 1000));
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return `${String(min).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
}

interface TournamentClockProps {
  clockState: TournamentClockState;
  activeTurn: 1 | 2;
  isPaused: boolean;
  onPresetChange: (preset: ClockPresetId) => void;
  onTick: (deltaMs: number) => void;
}

export const TournamentClock: React.FC<TournamentClockProps> = ({
  clockState,
  activeTurn,
  isPaused,
  onPresetChange,
  onTick,
}) => {
  useEffect(() => {
    if (clockState.preset === "none" || isPaused || clockState.flaggedWinner !== null) {
      return;
    }
    const timer = setInterval(() => {
      onTick(1000);
    }, 1000);
    return () => clearInterval(timer);
  }, [clockState.preset, isPaused, clockState.flaggedWinner, activeTurn]);

  return (
    <div className="flex flex-wrap items-center gap-3 p-2.5 rounded-xl bg-slate-900 border border-slate-800">
      <div className="flex items-center gap-1.5 text-xs font-medium text-slate-300">
        <Clock className="w-3.5 h-3.5 text-emerald-400" />
        <select
          aria-label="Reloj de Torneo"
          value={clockState.preset}
          onChange={(e) => onPresetChange(e.target.value as ClockPresetId)}
          className="bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1 text-xs font-medium text-slate-200"
        >
          <option value="none">Reloj: Sin Límite</option>
          <option value="blitz_3_2">FIDE Blitz 3m + 2s</option>
          <option value="rapid_10_0">FIDE Rápido 10m + 0s</option>
          <option value="byoyomi_5_30">Byo-yomi 5m + 3×30s</option>
        </select>
      </div>

      {clockState.preset !== "none" && (
        <div className="flex items-center gap-2 text-xs font-mono tabular-nums">
          {([1, 2] as const).map((pid) => {
            const isTurn = activeTurn === pid && !isPaused;
            const inByo =
              clockState.preset === "byoyomi_5_30" && clockState.mainMs[pid] === 0;
            const displayTime = inByo
              ? `${formatClockMs(clockState.byoyomiCurrentMs[pid])} (${
                  clockState.byoyomiPeriods[pid]
                }×)`
              : formatClockMs(clockState.mainMs[pid]);

            return (
              <div
                key={pid}
                className={`px-3 py-1 rounded-lg border flex items-center gap-1.5 ${
                  isTurn
                    ? "bg-emerald-950/80 border-emerald-500 text-emerald-300 font-bold"
                    : "bg-slate-950 border-slate-800 text-slate-400"
                }`}
              >
                <span>J{pid}:</span>
                <span>{displayTime}</span>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
