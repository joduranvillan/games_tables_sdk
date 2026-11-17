import React, { useState } from "react";
import { Award, Download, RotateCcw, Trophy, Upload, Wifi } from "lucide-react";

export const ELO_PROFILE_STORAGE_KEY = "opentable.elo_profile";
export const BASE_ELO_RATING = 1200;
export const ELO_K_FACTOR = 32;

export const ALL_14_GAME_IDS = [
  "chess",
  "checkers",
  "uno",
  "goose",
  "go",
  "shogi",
  "xiangqi",
  "chinese_checkers",
  "backgammon",
  "ludo",
  "battleship",
  "mille_bornes",
  "monopoly",
  "crisis",
] as const;

export interface GameEloStats {
  gameId: string;
  rating: number;
  peakRating: number;
  wins: number;
  losses: number;
  draws: number;
  streak: number;
}

export interface MatchHistoryRecord {
  id: string;
  gameId: string;
  opponentLabel: string;
  opponentRating: number;
  outcome: "win" | "loss" | "draw";
  ratingBefore: number;
  ratingAfter: number;
  delta: number;
  timestamp: string;
}

export interface AchievementDefinition {
  id: string;
  title: string;
  description: string;
  category: "elo" | "mastery" | "tournament" | "diversity";
}

export const ACHIEVEMENTS_CATALOG: AchievementDefinition[] = [
  {
    id: "first_victory",
    title: "Primera Victoria",
    description: "Gana tu primera partida oficial en cualquiera de los 14 juegos.",
    category: "mastery",
  },
  {
    id: "win_streak_3",
    title: "Estratega Imparable",
    description: "Alcanza una racha de 3 victorias consecutivas en un mismo juego.",
    category: "mastery",
  },
  {
    id: "veteran_10_matches",
    title: "Veterano del Tablero",
    description: "Completa al menos 10 partidas oficiales registradas.",
    category: "diversity",
  },
  {
    id: "elo_1250",
    title: "Competidor de Club (1250+ ELO)",
    description: "Supera los 1250 puntos ELO en el ranking global o en un juego.",
    category: "elo",
  },
  {
    id: "elo_1400",
    title: "Gran Maestro de Mesa (1400+ ELO)",
    description: "Alcanza o supera los 1400 puntos ELO con fórmula K=32.",
    category: "elo",
  },
  {
    id: "polyglot_3_games",
    title: "Políglota Táctico",
    description: "Obtén al menos 1 victoria en 3 juegos distintos del catálogo.",
    category: "diversity",
  },
  {
    id: "explorer_5_games",
    title: "Explorador de los 14 Mundos",
    description: "Disputa partidas en al menos 5 juegos diferentes del SDK.",
    category: "diversity",
  },
  {
    id: "oriental_master",
    title: "Maestro Oriental",
    description: "Gana una partida en Go, Shogi, Xiangqi o Damas Chinas.",
    category: "mastery",
  },
  {
    id: "dice_commander",
    title: "Señor de los Dados 3D",
    description: "Triunfa en El Juego de la Oca, Backgammon o Ludo.",
    category: "mastery",
  },
  {
    id: "tycoon_tactician",
    title: "Magnate y Comandante",
    description: "Vence en Monopoly, Crisis / TEG o Batalla Naval.",
    category: "mastery",
  },
  {
    id: "beat_hard_ai",
    title: "Cazador de Silicio",
    description: "Derrota a la IA de Rust en dificultad Difícil (1400) o Maestra (1600).",
    category: "elo",
  },
  {
    id: "tournament_champion",
    title: "Campeón de Torneo",
    description: "Gana un torneo completo Round-Robin o de Eliminatoria Directa.",
    category: "tournament",
  },
];

export interface PlayerEloProfile {
  playerName: string;
  globalRating: number;
  peakGlobalRating: number;
  tournamentsWon: number;
  statsByGame: Record<string, GameEloStats>;
  unlockedAchievements: string[];
  recentMatches: MatchHistoryRecord[];
}

/**
 * Ecuación logística estándar FIDE / OpenTable (`K = 32`), idéntica a `open_table_engine::elo`.
 */
export function computeEloUpdate(
  ratingA: number,
  ratingB: number,
  scoreA: 1 | 0.5 | 0,
  kFactor: number = ELO_K_FACTOR
): { newRatingA: number; newRatingB: number; deltaA: number } {
  const expectedA = 1.0 / (1.0 + Math.pow(10.0, (ratingB - ratingA) / 400.0));
  const deltaA = Math.round(kFactor * (scoreA - expectedA));
  const newRatingA = Math.max(100, ratingA + deltaA);
  const newRatingB = Math.max(100, ratingB - deltaA);
  return { newRatingA, newRatingB, deltaA };
}

export function getAiCalibrationRating(difficulty: number): number {
  switch (difficulty) {
    case 0:
      return 1000;
    case 1:
      return 1200;
    case 2:
      return 1400;
    case 3:
      return 1600;
    default:
      return 1200;
  }
}

export function createInitialEloProfile(
  playerName: string = "Jugador Local"
): PlayerEloProfile {
  const statsByGame: Record<string, GameEloStats> = {};
  for (const gameId of ALL_14_GAME_IDS) {
    statsByGame[gameId] = {
      gameId,
      rating: BASE_ELO_RATING,
      peakRating: BASE_ELO_RATING,
      wins: 0,
      losses: 0,
      draws: 0,
      streak: 0,
    };
  }
  return {
    playerName,
    globalRating: BASE_ELO_RATING,
    peakGlobalRating: BASE_ELO_RATING,
    tournamentsWon: 0,
    statsByGame,
    unlockedAchievements: [],
    recentMatches: [],
  };
}

export function evaluateUnlockedAchievements(
  profile: PlayerEloProfile,
  lastMatch?: {
    gameId: string;
    outcome: "win" | "loss" | "draw";
    opponentRating: number;
  }
): string[] {
  const unlocked = new Set<string>(profile.unlockedAchievements);
  const statsList = Object.values(profile.statsByGame);

  const totalWins = statsList.reduce((acc, s) => acc + s.wins, 0);
  const totalMatches = statsList.reduce(
    (acc, s) => acc + s.wins + s.losses + s.draws,
    0
  );
  const gamesWithWin = statsList.filter((s) => s.wins > 0).length;
  const gamesPlayed = statsList.filter(
    (s) => s.wins + s.losses + s.draws > 0
  ).length;
  const maxGameRating = statsList.reduce(
    (max, s) => Math.max(max, s.rating),
    profile.globalRating
  );
  const maxStreak = statsList.reduce((max, s) => Math.max(max, s.streak), 0);

  if (totalWins >= 1) unlocked.add("first_victory");
  if (maxStreak >= 3) unlocked.add("win_streak_3");
  if (totalMatches >= 10) unlocked.add("veteran_10_matches");
  if (maxGameRating >= 1250 || profile.globalRating >= 1250) {
    unlocked.add("elo_1250");
  }
  if (maxGameRating >= 1400 || profile.globalRating >= 1400) {
    unlocked.add("elo_1400");
  }
  if (gamesWithWin >= 3) unlocked.add("polyglot_3_games");
  if (gamesPlayed >= 5) unlocked.add("explorer_5_games");

  const orientalGames = ["go", "shogi", "xiangqi", "chinese_checkers"];
  if (orientalGames.some((id) => (profile.statsByGame[id]?.wins ?? 0) > 0)) {
    unlocked.add("oriental_master");
  }

  const diceGames = ["goose", "backgammon", "ludo"];
  if (diceGames.some((id) => (profile.statsByGame[id]?.wins ?? 0) > 0)) {
    unlocked.add("dice_commander");
  }

  const strategyGames = ["monopoly", "crisis", "battleship"];
  if (strategyGames.some((id) => (profile.statsByGame[id]?.wins ?? 0) > 0)) {
    unlocked.add("tycoon_tactician");
  }

  if (
    lastMatch &&
    lastMatch.outcome === "win" &&
    lastMatch.opponentRating >= 1400
  ) {
    unlocked.add("beat_hard_ai");
  }

  if (profile.tournamentsWon >= 1) {
    unlocked.add("tournament_champion");
  }

  return Array.from(unlocked);
}

export function recordMatchInEloProfile(
  profile: PlayerEloProfile,
  gameId: string,
  outcome: "win" | "loss" | "draw",
  opponentRating: number = BASE_ELO_RATING,
  opponentLabel: string = "IA Media"
): { updatedProfile: PlayerEloProfile; newlyUnlocked: string[] } {
  const prevGameStats = profile.statsByGame[gameId] || {
    gameId,
    rating: BASE_ELO_RATING,
    peakRating: BASE_ELO_RATING,
    wins: 0,
    losses: 0,
    draws: 0,
    streak: 0,
  };

  const scoreA: 1 | 0.5 | 0 =
    outcome === "win" ? 1 : outcome === "draw" ? 0.5 : 0;

  const { newRatingA, deltaA } = computeEloUpdate(
    prevGameStats.rating,
    opponentRating,
    scoreA
  );
  const globalUpdate = computeEloUpdate(
    profile.globalRating,
    opponentRating,
    scoreA
  );

  const nextStreak = outcome === "win" ? prevGameStats.streak + 1 : 0;
  const nextGameStats: GameEloStats = {
    gameId,
    rating: newRatingA,
    peakRating: Math.max(prevGameStats.peakRating, newRatingA),
    wins: prevGameStats.wins + (outcome === "win" ? 1 : 0),
    losses: prevGameStats.losses + (outcome === "loss" ? 1 : 0),
    draws: prevGameStats.draws + (outcome === "draw" ? 1 : 0),
    streak: nextStreak,
  };

  const record: MatchHistoryRecord = {
    id: `m_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
    gameId,
    opponentLabel,
    opponentRating,
    outcome,
    ratingBefore: prevGameStats.rating,
    ratingAfter: newRatingA,
    delta: deltaA,
    timestamp: new Date().toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    }),
  };

  const draftProfile: PlayerEloProfile = {
    ...profile,
    globalRating: globalUpdate.newRatingA,
    peakGlobalRating: Math.max(
      profile.peakGlobalRating,
      globalUpdate.newRatingA
    ),
    statsByGame: {
      ...profile.statsByGame,
      [gameId]: nextGameStats,
    },
    recentMatches: [record, ...profile.recentMatches].slice(0, 25),
  };

  const nextAchievements = evaluateUnlockedAchievements(draftProfile, {
    gameId,
    outcome,
    opponentRating,
  });
  const newlyUnlocked = nextAchievements.filter(
    (id) => !profile.unlockedAchievements.includes(id)
  );

  const updatedProfile: PlayerEloProfile = {
    ...draftProfile,
    unlockedAchievements: nextAchievements,
  };

  saveEloProfile(updatedProfile);
  return { updatedProfile, newlyUnlocked };
}

export function recordTournamentVictoryInProfile(
  profile: PlayerEloProfile
): { updatedProfile: PlayerEloProfile; newlyUnlocked: string[] } {
  const draft: PlayerEloProfile = {
    ...profile,
    tournamentsWon: profile.tournamentsWon + 1,
  };
  const nextAchievements = evaluateUnlockedAchievements(draft);
  const newlyUnlocked = nextAchievements.filter(
    (id) => !profile.unlockedAchievements.includes(id)
  );
  const updatedProfile: PlayerEloProfile = {
    ...draft,
    unlockedAchievements: nextAchievements,
  };
  saveEloProfile(updatedProfile);
  return { updatedProfile, newlyUnlocked };
}

export function loadEloProfile(): PlayerEloProfile {
  const initial = createInitialEloProfile();
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      const raw = window.localStorage.getItem(ELO_PROFILE_STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed.globalRating === "number") {
          return {
            ...initial,
            ...parsed,
            statsByGame: {
              ...initial.statsByGame,
              ...(parsed.statsByGame || {}),
            },
          };
        }
      }
    }
  } catch {
    // Fallback to initial profile
  }
  return initial;
}

export function saveEloProfile(profile: PlayerEloProfile): PlayerEloProfile {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      window.localStorage.setItem(
        ELO_PROFILE_STORAGE_KEY,
        JSON.stringify(profile)
      );
    }
  } catch {
    // Ignore storage errors
  }
  return profile;
}

interface EloAndAchievementsPanelProps {
  profile: PlayerEloProfile;
  gameTitles: Record<string, string>;
  peerEloInfo?: { playerName: string; rating: number } | null;
  onUpdateProfile: (next: PlayerEloProfile) => void;
  onSyncEloToRelay?: () => void;
}

export const EloAndAchievementsPanel: React.FC<EloAndAchievementsPanelProps> = ({
  profile,
  gameTitles,
  peerEloInfo,
  onUpdateProfile,
  onSyncEloToRelay,
}) => {
  const [importJsonText, setImportJsonText] = useState<string>("");
  const [statusMsg, setStatusMsg] = useState<string>("");

  const totalMatches = Object.values(profile.statsByGame).reduce(
    (acc, s) => acc + s.wins + s.losses + s.draws,
    0
  );
  const totalWins = Object.values(profile.statsByGame).reduce(
    (acc, s) => acc + s.wins,
    0
  );

  const handleExportProfile = () => {
    const json = JSON.stringify(profile, null, 2);
    setImportJsonText(json);
    setStatusMsg("Perfil ELO exportado en el cuadro JSON inferior.");
  };

  const handleImportProfile = () => {
    try {
      const parsed = JSON.parse(importJsonText);
      if (!parsed || typeof parsed.globalRating !== "number") {
        setStatusMsg("JSON inválido: falta globalRating.");
        return;
      }
      const merged = saveEloProfile({
        ...createInitialEloProfile(),
        ...parsed,
      });
      onUpdateProfile(merged);
      setStatusMsg("Perfil ELO e insignias importados correctamente.");
    } catch {
      setStatusMsg("Error de sintaxis al importar el JSON del perfil.");
    }
  };

  return (
    <section className="flex flex-col gap-6">
      {/* Header & Global Rating Summary */}
      <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col lg:flex-row lg:items-center justify-between gap-6">
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2 text-xs text-slate-400">
            <span>Clasificación Oficial OpenTable</span>
            <span aria-hidden="true">·</span>
            <span>Fórmula FIDE K = 32</span>
            <span aria-hidden="true">·</span>
            <span>Persistencia Híbrida Local + Relay</span>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <h2 className="text-2xl font-bold text-white font-display">
              Perfil Competitivo: {profile.playerName}
            </h2>
            <input
              type="text"
              aria-label="Nombre del jugador"
              value={profile.playerName}
              onChange={(e) => {
                const next = saveEloProfile({
                  ...profile,
                  playerName: e.target.value,
                });
                onUpdateProfile(next);
              }}
              className="px-3 py-1 rounded-lg bg-slate-950 border border-slate-700 text-xs text-slate-200"
            />
          </div>
          {peerEloInfo && (
            <p className="text-xs text-emerald-400 font-mono tabular-nums">
              Rival conectado en Sala Relay: {peerEloInfo.playerName} (ELO{" "}
              {peerEloInfo.rating})
            </p>
          )}
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 shrink-0">
          <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-[11px] text-slate-400">ELO Global</div>
            <div className="text-xl font-bold text-emerald-400 font-mono tabular-nums mt-0.5">
              {profile.globalRating}
            </div>
          </div>
          <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-[11px] text-slate-400">Pico Histórico</div>
            <div className="text-xl font-bold text-white font-mono tabular-nums mt-0.5">
              {profile.peakGlobalRating}
            </div>
          </div>
          <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-[11px] text-slate-400">Victorias / Partidas</div>
            <div className="text-xl font-bold text-sky-400 font-mono tabular-nums mt-0.5">
              {totalWins} / {totalMatches}
            </div>
          </div>
          <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800">
            <div className="text-[11px] text-slate-400">Logros</div>
            <div className="text-xl font-bold text-amber-400 font-mono tabular-nums mt-0.5">
              {profile.unlockedAchievements.length} /{" "}
              {ACHIEVEMENTS_CATALOG.length}
            </div>
          </div>
        </div>
      </div>

      {/* Action Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          {onSyncEloToRelay && (
            <button
              type="button"
              onClick={() => {
                onSyncEloToRelay();
                setStatusMsg(
                  `ELO (${profile.globalRating}) sincronizado con la sala Relay activa.`
                );
              }}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors cursor-pointer"
            >
              <Wifi className="w-3.5 h-3.5" />
              <span>Sincronizar ELO con Sala Relay</span>
            </button>
          )}
          <button
            type="button"
            onClick={handleExportProfile}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium transition-colors cursor-pointer"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Exportar Perfil JSON</span>
          </button>
          <button
            type="button"
            onClick={() => {
              const reset = saveEloProfile(
                createInitialEloProfile(profile.playerName)
              );
              onUpdateProfile(reset);
              setStatusMsg("Estadísticas ELO y logros reiniciados a 1200.");
            }}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium transition-colors cursor-pointer"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Reiniciar ELO (1200)</span>
          </button>
        </div>

        {statusMsg && (
          <span className="text-xs text-emerald-400">{statusMsg}</span>
        )}
      </div>

      {/* Per-Game ELO Table (14 Games) */}
      <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
        <h3 className="text-lg font-bold text-white font-display">
          01. Clasificación ELO Desglosada en los 14 Juegos
        </h3>
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400">
                <th className="py-2.5 pr-4 font-medium">Juego</th>
                <th className="py-2.5 px-3 font-medium text-right">Rating ELO</th>
                <th className="py-2.5 px-3 font-medium text-right">Pico</th>
                <th className="py-2.5 px-3 font-medium text-right">Victorias</th>
                <th className="py-2.5 px-3 font-medium text-right">Empates</th>
                <th className="py-2.5 px-3 font-medium text-right">Derrotas</th>
                <th className="py-2.5 pl-3 font-medium text-right">Racha</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/70 font-mono tabular-nums">
              {ALL_14_GAME_IDS.map((gid) => {
                const st = profile.statsByGame[gid] || {
                  gameId: gid,
                  rating: BASE_ELO_RATING,
                  peakRating: BASE_ELO_RATING,
                  wins: 0,
                  losses: 0,
                  draws: 0,
                  streak: 0,
                };
                return (
                  <tr key={gid} className="hover:bg-slate-800/40">
                    <td className="py-2.5 pr-4 font-sans font-medium text-slate-200">
                      {gameTitles[gid] || gid}
                    </td>
                    <td className="py-2.5 px-3 text-right font-bold text-emerald-400">
                      {st.rating}
                    </td>
                    <td className="py-2.5 px-3 text-right text-slate-300">
                      {st.peakRating}
                    </td>
                    <td className="py-2.5 px-3 text-right text-slate-200">
                      {st.wins}
                    </td>
                    <td className="py-2.5 px-3 text-right text-slate-400">
                      {st.draws}
                    </td>
                    <td className="py-2.5 px-3 text-right text-slate-400">
                      {st.losses}
                    </td>
                    <td className="py-2.5 pl-3 text-right text-amber-400">
                      {st.streak}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Achievements Grid */}
      <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-bold text-white font-display">
            02. Catálogo de Logros Desbloqueables
          </h3>
          <span className="text-xs text-slate-400 font-mono tabular-nums">
            Desbloqueados: {profile.unlockedAchievements.length} /{" "}
            {ACHIEVEMENTS_CATALOG.length}
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3.5">
          {ACHIEVEMENTS_CATALOG.map((ach) => {
            const isUnlocked = profile.unlockedAchievements.includes(ach.id);
            return (
              <div
                key={ach.id}
                className={`p-4 rounded-xl border flex flex-col justify-between gap-2 transition-colors ${
                  isUnlocked
                    ? "bg-slate-950 border-emerald-700/70 text-slate-100"
                    : "bg-slate-950/50 border-slate-800 text-slate-400 opacity-75"
                }`}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2">
                    {isUnlocked ? (
                      <Trophy className="w-4 h-4 text-amber-400 shrink-0" />
                    ) : (
                      <Award className="w-4 h-4 text-slate-500 shrink-0" />
                    )}
                    <span className="text-sm font-semibold text-white">
                      {ach.title}
                    </span>
                  </div>
                  <span className="text-[11px] font-mono text-slate-400">
                    {isUnlocked ? "Desbloqueado" : "Pendiente"}
                  </span>
                </div>
                <p className="text-xs leading-relaxed">{ach.description}</p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Import / Export JSON Box */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <span className="text-xs font-semibold text-slate-300">
            Respaldo JSON del Perfil ELO y Logros
          </span>
          <button
            type="button"
            onClick={handleImportProfile}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition-colors cursor-pointer"
          >
            <Upload className="w-3.5 h-3.5" />
            <span>Importar JSON</span>
          </button>
        </div>
        <textarea
          rows={3}
          value={importJsonText}
          onChange={(e) => setImportJsonText(e.target.value)}
          placeholder='Pega aquí el respaldo JSON de tu perfil ELO o pulsa "Exportar Perfil JSON"...'
          className="w-full p-3 rounded-lg bg-slate-950 border border-slate-800 text-xs text-slate-200 font-mono"
        />
      </div>
    </section>
  );
};
