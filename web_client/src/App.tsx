import React, { useEffect, useRef, useState } from "react";
import { WasmGameBridge } from "./wasm_pkg";
import {
  getSavedRelayUrl,
  RelayChatMessage,
  RelayConnectionState,
  RelayWebSocketClient,
  saveRelayUrl,
} from "./bridge/relayClient";
import { ChessBoard } from "./components/boards/ChessBoard";
import { CheckersBoard } from "./components/boards/CheckersBoard";
import { UnoBoard } from "./components/boards/UnoBoard";
import { GooseBoard } from "./components/boards/GooseBoard";
import { GoBoard } from "./components/boards/GoBoard";
import { ShogiBoard } from "./components/boards/ShogiBoard";
import { XiangqiBoard } from "./components/boards/XiangqiBoard";
import { ChineseCheckersBoard } from "./components/boards/ChineseCheckersBoard";
import { BackgammonBoard } from "./components/boards/BackgammonBoard";
import { LudoBoard } from "./components/boards/LudoBoard";
import { BattleshipBoard } from "./components/boards/BattleshipBoard";
import { MilleBornesBoard } from "./components/boards/MilleBornesBoard";
import { MonopolyBoard } from "./components/boards/MonopolyBoard";
import { CrisisBoard } from "./components/boards/CrisisBoard";
import {
  applyClockMoveComplete,
  ClockPresetId,
  createInitialClockState,
  stepClockTick,
  TournamentClock,
  TournamentClockState,
} from "./components/common/TournamentClock";
import { ReplayViewerBar } from "./components/common/ReplayViewerBar";
import { InteractiveTutorialPanel } from "./components/common/InteractiveTutorialPanel";
import {
  OfflineIndicator,
  PWAInstallButton,
} from "./components/common/PWAInstallButton";
import {
  loadThemeAndAudioConfig,
  playProceduralSound,
  ThemeAndAudioConfig,
  ThemeAndAudioToolbar,
  VISUAL_THEMES,
} from "./components/common/ThemeAndAudioManager";
import {
  ACHIEVEMENTS_CATALOG,
  EloAndAchievementsPanel,
  getAiCalibrationRating,
  loadEloProfile,
  PlayerEloProfile,
  recordMatchInEloProfile,
  recordTournamentVictoryInProfile,
} from "./components/common/EloAndAchievementsPanel";
import {
  loadTournamentState,
  recordTournamentMatchResult,
  TournamentManagerPanel,
  TournamentMatchItem,
  TournamentState,
} from "./components/common/TournamentManagerPanel";
import { RelayChatPanel } from "./components/common/RelayChatPanel";
import {
  Bot,
  Eye,
  QrCode,
  RefreshCw,
  RotateCcw,
  Settings,
  Trophy,
  Users,
  Wifi,
} from "lucide-react";

interface GameCatalogItem {
  id: string;
  title: string;
  crateName: string;
  category: string;
  phase: 1 | 2;
  blockLabel: string;
  summary: string;
}

export const CATALOG_14_GAMES: GameCatalogItem[] = [
  {
    id: "chess",
    title: "Ajedrez",
    crateName: "chess_game",
    category: "Estrategia Clásica",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Enroque, captura al paso, coronación FIDE, detección de jaque y oferta de tablas.",
  },
  {
    id: "checkers",
    title: "Damas",
    crateName: "checkers_game",
    category: "Estrategia Clásica",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Captura obligatoria, saltos múltiples encadenados y coronación de Dama.",
  },
  {
    id: "uno",
    title: "UNO",
    crateName: "uno_game",
    category: "Cartas y Reacción",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Mazo de 108 cartas, comodines multicolor, grito ¡UNO! y penalidades acumulables.",
  },
  {
    id: "goose",
    title: "El Juego de la Oca",
    crateName: "goose_game",
    category: "Dados 3D y Recorrido",
    phase: 1,
    blockLabel: "Fase 1 · Activo en Web + WASM",
    summary: "Espiral de 63 casillas, 13 Ocas, Puentes, Posada, Pozo, Laberinto, Calavera y Dados 3D.",
  },
  {
    id: "go",
    title: "Go (Weiqi / Baduk)",
    crateName: "go_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Tableros 9×9 / 13×13 / 19×19, Ko, Superko posicional, Handicap y Komi 6.5.",
  },
  {
    id: "shogi",
    title: "Shogi",
    crateName: "shogi_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Reingreso de piezas capturadas (Komadai), Nifu, Uchifuzume y promoción FESA.",
  },
  {
    id: "xiangqi",
    title: "Xiangqi",
    crateName: "xiangqi_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Tablero 9×10 con Río, Palacios diagonales, Cañones con pantalla y General Volador.",
  },
  {
    id: "chinese_checkers",
    title: "Damas Chinas",
    crateName: "chinese_checkers_game",
    category: "Estrategia Oriental",
    phase: 1,
    blockLabel: "Fase 2A · Activo en Web + WASM",
    summary: "Estrella hexagonal de 121 casillas para 2 a 6 jugadores con saltos en cadena.",
  },
  {
    id: "backgammon",
    title: "Backgammon",
    crateName: "backgammon_game",
    category: "Dados y Táctica",
    phase: 1,
    blockLabel: "Fase 2B · Activo en Web + WASM",
    summary: "24 picos, barra central, Bear-Off, tiradas dobles y cubo de doblaje (Doubling Cube).",
  },
  {
    id: "ludo",
    title: "Ludo",
    crateName: "ludo_game",
    category: "Dados y Carrera",
    phase: 1,
    blockLabel: "Fase 2B · Activo en Web + WASM",
    summary: "Circuito de 52 casillas + 5 de meta, 8 casillas seguras estrella y tirada extra.",
  },
  {
    id: "battleship",
    title: "Batalla Naval",
    crateName: "battleship_game",
    category: "Combate Táctico",
    phase: 1,
    blockLabel: "Fase 2B · Activo en Web + WASM",
    summary: "Doble cuadrícula 10×10, flota de 5 buques, ráfaga al impactar y revancha.",
  },
  {
    id: "mille_bornes",
    title: "Mil Millas",
    crateName: "mille_bornes_game",
    category: "Cartas y Carrera",
    phase: 1,
    blockLabel: "Fase 2C · Activo en Web + WASM",
    summary: "Ruta de 1000 km, 4 cartas de seguridad (Safeties) y reacción ¡Coup Fourré!.",
  },
  {
    id: "monopoly",
    title: "Monopoly",
    crateName: "monopoly_game",
    category: "Economía y Subastas",
    phase: 1,
    blockLabel: "Fase 2C · Activo en Web + WASM",
    summary: "40 casillas, Suerte/Arca, Subastas, Casas/Hoteles uniformes, Hipotecas y Trueques.",
  },
  {
    id: "crisis",
    title: "Crisis / TEG",
    crateName: "crisis_game",
    category: "Conquista Global",
    phase: 1,
    blockLabel: "Fase 2C · Activo en Web + WASM",
    summary: "30 territorios en 6 continentes, objetivos secretos, tarjetas y dados 3v3.",
  },
];

export const GAME_TITLES_MAP: Record<string, string> = Object.fromEntries(
  CATALOG_14_GAMES.map((g) => [g.id, g.title])
);

export type MatchMode = "hotseat" | "ai" | "online_relay" | "spectator";

export function computeIsLocalTurnAllowed(
  mode: MatchMode,
  currentTurn: number,
  localPlayerId: 1 | 2,
  isReplayAtLiveHead: boolean = true
): boolean {
  if (!isReplayAtLiveHead) return false;
  if (mode === "spectator") return false;
  if (mode === "hotseat") return true;
  if (mode === "ai") return currentTurn === 1;
  return currentTurn === localPlayerId;
}

export const App: React.FC = () => {
  const bridgeRef = useRef<WasmGameBridge>(new WasmGameBridge());
  const relayRef = useRef<RelayWebSocketClient | null>(null);
  const matchOutcomeRecordedRef = useRef<boolean>(false);

  const [activeTab, setActiveTab] = useState<
    "play" | "catalog" | "tournaments" | "elo" | "network"
  >("play");
  const [selectedGameId, setSelectedGameId] = useState<string>("chess");
  const [matchMode, setMatchMode] = useState<MatchMode>("hotseat");
  const [aiDifficulty, setAiDifficulty] = useState<number>(1);

  const [stateJson, setStateJson] = useState<string>(() =>
    bridgeRef.current.get_state_json()
  );
  const [legalMovesJson, setLegalMovesJson] = useState<string>(() =>
    bridgeRef.current.get_legal_moves_json(1)
  );
  const [currentTurn, setCurrentTurn] = useState<number>(1);
  const [localNetworkPlayerId, setLocalNetworkPlayerId] = useState<1 | 2>(1);

  // Replay timeline state
  const [replayCurrentStep, setReplayCurrentStep] = useState<number>(0);
  const [replayTotalSteps, setReplayTotalSteps] = useState<number>(0);

  // Tournament Clock state
  const [clockState, setClockState] = useState<TournamentClockState>(() =>
    createInitialClockState("none")
  );

  // Phase 4: Theme & Audio state
  const [themeConfig, setThemeConfig] = useState<ThemeAndAudioConfig>(() =>
    loadThemeAndAudioConfig()
  );

  // Phase 4: ELO Profile & Achievements state
  const [eloProfile, setEloProfile] = useState<PlayerEloProfile>(() =>
    loadEloProfile()
  );
  const [recentAchievementBanner, setRecentAchievementBanner] = useState<
    string | null
  >(null);
  const [peerEloInfo, setPeerEloInfo] = useState<{
    playerName: string;
    rating: number;
  } | null>(null);

  // Phase 4: Tournament Organizer state
  const [tournamentState, setTournamentState] = useState<TournamentState>(() =>
    loadTournamentState("chess")
  );
  const [activeTournamentMatchId, setActiveTournamentMatchId] = useState<
    string | null
  >(null);

  // Relay & QR + Chat state
  const [relayUrl, setRelayUrl] = useState<string>(() => getSavedRelayUrl());
  const [relayState, setRelayState] =
    useState<RelayConnectionState>("disconnected");
  const [relayStatusText, setRelayStatusText] = useState<string>(
    "Sin sala activa (Modo Local)"
  );
  const [roomCode, setRoomCode] = useState<string>("");
  const [joinCodeInput, setJoinCodeInput] = useState<string>("");
  const [qrSvg, setQrSvg] = useState<string>("");
  const [chatMessages, setChatMessages] = useState<RelayChatMessage[]>([]);

  const checkAndRecordWinnerIfAny = (
    nextStateStr: string,
    gameId: string,
    mode: MatchMode,
    diff: number
  ) => {
    try {
      const parsed = JSON.parse(nextStateStr);
      const winner = parsed.winner ?? null;
      if (winner !== null && !matchOutcomeRecordedRef.current) {
        matchOutcomeRecordedRef.current = true;
        playProceduralSound("victory", themeConfig);

        const outcome: "win" | "loss" | "draw" =
          winner === 0
            ? "draw"
            : winner === localNetworkPlayerId
            ? "win"
            : "loss";
        const oppRating =
          mode === "ai"
            ? getAiCalibrationRating(diff)
            : peerEloInfo?.rating || 1200;
        const oppLabel =
          mode === "ai"
            ? `IA Nivel ${diff + 1}`
            : peerEloInfo?.playerName || "Oponente Local/Red";

        setEloProfile((prev) => {
          const { updatedProfile, newlyUnlocked } = recordMatchInEloProfile(
            prev,
            gameId,
            outcome,
            oppRating,
            oppLabel
          );
          if (newlyUnlocked.length > 0) {
            const firstTitle =
              ACHIEVEMENTS_CATALOG.find((a) => a.id === newlyUnlocked[0])
                ?.title || newlyUnlocked[0];
            setRecentAchievementBanner(`¡Logro desbloqueado: ${firstTitle}!`);
          }
          return updatedProfile;
        });

        if (activeTournamentMatchId) {
          setTournamentState((prevTour) => {
            const m = prevTour.matches.find(
              (item) => item.id === activeTournamentMatchId
            );
            if (!m) return prevTour;
            const winParticipantId =
              winner === 1
                ? m.player1Id
                : winner === 2
                ? m.player2Id
                : "draw";
            return recordTournamentMatchResult(
              prevTour,
              m.id,
              winParticipantId
            );
          });
        }
      }
    } catch {
      // Ignore parse error
    }
  };

  const syncFromBridge = () => {
    const turn = bridgeRef.current.current_player();
    const nextStateStr = bridgeRef.current.get_state_json();
    setCurrentTurn(turn);
    setStateJson(nextStateStr);
    setLegalMovesJson(bridgeRef.current.get_legal_moves_json(turn));
    setReplayCurrentStep(bridgeRef.current.get_current_replay_step());
    setReplayTotalSteps(bridgeRef.current.get_replay_step_count());
    checkAndRecordWinnerIfAny(
      nextStateStr,
      bridgeRef.current.get_current_game_type(),
      matchMode,
      aiDifficulty
    );
  };

  useEffect(() => {
    const client = new RelayWebSocketClient(
      {
        onStateChange: (st, info) => {
          setRelayState(st);
          if (info) setRelayStatusText(info);
        },
        onRoomCreated: (code, pid) => {
          setRoomCode(code);
          setLocalNetworkPlayerId(pid);
          setQrSvg(
            bridgeRef.current.generate_join_qr_svg(
              code,
              "WebHost",
              selectedGameId
            )
          );
        },
        onRoomJoined: (code, pid) => {
          setRoomCode(code);
          setLocalNetworkPlayerId(pid);
        },
        onSpectatorJoined: (code) => {
          setRoomCode(code);
          setMatchMode("spectator");
        },
        onPeerJoined: () => {
          const logJson = bridgeRef.current.export_log_json();
          client.sendSyncState(
            bridgeRef.current.get_current_game_type(),
            logJson
          );
        },
        onCommandReceived: (playerId, cmdJson) => {
          bridgeRef.current.send_command_json(playerId, cmdJson);
          syncFromBridge();
        },
        onSyncStateReceived: (gtype, logJson) => {
          if (bridgeRef.current.apply_sync_log_json(gtype, logJson)) {
            setSelectedGameId(bridgeRef.current.get_current_game_type());
            syncFromBridge();
          }
        },
        onChatMessageReceived: (msg) => {
          setChatMessages((prev) => [...prev, msg]);
        },
        onEloSyncReceived: (_pid, rating, playerName) => {
          setPeerEloInfo({ playerName, rating });
        },
      },
      relayUrl
    );
    relayRef.current = client;
    return () => {
      client.disconnect();
    };
  }, []);

  const startGameSession = (
    gameId: string,
    mode: MatchMode,
    diff: number = aiDifficulty
  ) => {
    matchOutcomeRecordedRef.current = false;
    setSelectedGameId(gameId);
    setMatchMode(mode);
    setClockState((prev) => createInitialClockState(prev.preset));
    if (mode === "ai") {
      bridgeRef.current.start_ai_match(gameId, 1, 2, diff);
      setLocalNetworkPlayerId(1);
    } else {
      bridgeRef.current.start_local_match(gameId, 1, 2);
      if (mode === "hotseat") {
        setLocalNetworkPlayerId(1);
      }
    }
    syncFromBridge();
  };

  const handleDispatchCommand = (cmdJson: string) => {
    const turnBefore = bridgeRef.current.current_player() as 1 | 2;
    bridgeRef.current.send_command_json(turnBefore, cmdJson);
    const turnAfter = bridgeRef.current.current_player() as 1 | 2;

    if (cmdJson.toLowerCase().includes("roll")) {
      playProceduralSound("dice_roll", themeConfig);
    } else if (
      selectedGameId === "uno" ||
      selectedGameId === "mille_bornes"
    ) {
      playProceduralSound("card_play", themeConfig);
    } else {
      playProceduralSound("move", themeConfig);
    }

    if (turnAfter !== turnBefore) {
      setClockState((prev) => applyClockMoveComplete(prev, turnBefore));
    }
    syncFromBridge();

    if (matchMode === "online_relay" && relayRef.current) {
      relayRef.current.sendCommand(turnBefore, cmdJson);
      if (localNetworkPlayerId === 1) {
        relayRef.current.sendSyncState(
          selectedGameId,
          bridgeRef.current.export_log_json()
        );
      }
    } else if (matchMode === "ai") {
      setTimeout(() => {
        const aiTurnBefore = bridgeRef.current.current_player() as 1 | 2;
        bridgeRef.current.step_ai_if_needed();
        const aiTurnAfter = bridgeRef.current.current_player() as 1 | 2;
        if (aiTurnAfter !== aiTurnBefore) {
          setClockState((prev) => applyClockMoveComplete(prev, aiTurnBefore));
        }
        syncFromBridge();
      }, 260);
    }
  };

  const handleClockTick = (deltaMs: number) => {
    setClockState((prev) => {
      const next = stepClockTick(
        prev,
        (currentTurn === 2 ? 2 : 1) as 1 | 2,
        deltaMs
      );
      if (next.flaggedWinner !== null && prev.flaggedWinner === null) {
        playProceduralSound("clock_alert", themeConfig);
        bridgeRef.current.force_timeout_win(next.flaggedWinner);
        syncFromBridge();
      }
      return next;
    });
  };

  const handleSeekReplayStep = (step: number) => {
    bridgeRef.current.seek_replay_step(step);
    syncFromBridge();
  };

  const handleImportReplayJson = (jsonStr: string): boolean => {
    const ok = bridgeRef.current.apply_sync_log_json("", jsonStr);
    if (ok) {
      setSelectedGameId(bridgeRef.current.get_current_game_type());
      syncFromBridge();
    }
    return ok;
  };

  const handleSendChatMessage = (text: string) => {
    const sent = relayRef.current?.sendChatMessage(
      eloProfile.playerName,
      text,
      localNetworkPlayerId
    );
    if (sent) {
      setChatMessages((prev) => [...prev, sent]);
    }
  };

  const handleLaunchTournamentMatch = (
    match: TournamentMatchItem,
    gameId: string
  ) => {
    setActiveTournamentMatchId(match.id);
    const p2 = tournamentState.participants.find(
      (p) => p.id === match.player2Id
    );
    const mode: MatchMode = p2?.kind === "ai" ? "ai" : "hotseat";
    const diff = p2?.aiDifficulty ?? 1;
    setAiDifficulty(diff);
    startGameSession(gameId, mode, diff);
    setActiveTab("play");
  };

  const handleCreateRelayRoom = () => {
    if (!relayRef.current) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "online_relay");
    const code = relayRef.current.createRoom(selectedGameId);
    setRoomCode(code);
    setLocalNetworkPlayerId(1);
    setQrSvg(
      bridgeRef.current.generate_join_qr_svg(code, "WebHost", selectedGameId)
    );
    setActiveTab("play");
  };

  const handleJoinRelayRoom = () => {
    if (!relayRef.current || joinCodeInput.trim().length < 4) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "online_relay");
    const ok = relayRef.current.joinRoom(joinCodeInput);
    if (ok) {
      setLocalNetworkPlayerId(2);
      setActiveTab("play");
    }
  };

  const handleJoinAsSpectator = () => {
    if (!relayRef.current || joinCodeInput.trim().length < 4) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "spectator");
    const ok = relayRef.current.joinAsSpectator(joinCodeInput);
    if (ok) {
      setActiveTab("play");
    }
  };

  const handleSaveSettings = (e: React.FormEvent) => {
    e.preventDefault();
    const cleaned = saveRelayUrl(relayUrl);
    setRelayUrl(cleaned);
    relayRef.current?.setRelayUrl(cleaned);
    setRelayStatusText(`URL de Relay guardada: ${cleaned}`);
  };

  const isReplayAtLiveHead = replayCurrentStep >= replayTotalSteps;
  const isLocalTurnAllowed = computeIsLocalTurnAllowed(
    matchMode,
    currentTurn,
    localNetworkPlayerId,
    isReplayAtLiveHead
  );

  const parsedStateWinner = (() => {
    try {
      return JSON.parse(stateJson).winner ?? null;
    } catch {
      return null;
    }
  })();

  const activeGameMeta =
    CATALOG_14_GAMES.find((g) => g.id === selectedGameId) ||
    CATALOG_14_GAMES[0];

  const currentTheme =
    VISUAL_THEMES[themeConfig.themeId] || VISUAL_THEMES.piedra_oscura;

  return (
    <div
      data-theme={themeConfig.themeId}
      data-okabe-ito={themeConfig.okabeIto ? "true" : "false"}
      className={`min-h-screen flex flex-col transition-colors ${currentTheme.rootBgClass}`}
    >
      <OfflineIndicator />

      {/* Strict 3-Zone Top Bar Contract */}
      <header
        className={`flex items-center justify-between gap-8 px-6 py-4 border-b ${currentTheme.headerBgClass}`}
      >
        <a
          href="#top"
          onClick={(e) => {
            e.preventDefault();
            setActiveTab("play");
          }}
          className="text-lg font-bold tracking-tight text-white font-display whitespace-nowrap shrink-0"
        >
          OpenTable Web
        </a>

        <nav className="hidden md:flex items-center gap-6 text-sm font-medium text-slate-300">
          <button
            type="button"
            onClick={() => setActiveTab("play")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "play"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            Tablero Activo
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("catalog")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "catalog"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            14 Juegos
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("tournaments")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "tournaments"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            Torneos
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("elo")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "elo"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            Ranking ELO
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("network")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "network"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            Salas Online
          </button>
        </nav>

        <div className="flex items-center gap-3 shrink-0">
          <PWAInstallButton />
          <button
            type="button"
            onClick={() =>
              startGameSession(selectedGameId, matchMode, aiDifficulty)
            }
            className={`px-4 py-2 text-xs font-semibold rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer ${currentTheme.accentBtnClass}`}
          >
            Reiniciar Partida
          </button>
        </div>
      </header>

      {/* Main Content Container (1440px baseline) */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-6 py-8 flex flex-col gap-6">
        {/* Achievement Toast if newly unlocked */}
        {recentAchievementBanner && (
          <div className="p-3.5 rounded-xl bg-slate-900 border border-amber-500/70 flex items-center justify-between gap-4 text-xs">
            <div className="flex items-center gap-2 text-amber-300 font-semibold">
              <Trophy className="w-4 h-4 shrink-0" />
              <span>{recentAchievementBanner}</span>
            </div>
            <button
              type="button"
              onClick={() => setRecentAchievementBanner(null)}
              className="text-slate-400 hover:text-white font-medium cursor-pointer"
            >
              Cerrar
            </button>
          </div>
        )}

        {/* Workspace Toolbar: Game Selector + Mode Selector + Theme/Audio */}
        <section className="flex flex-col gap-4 pb-5 border-b border-slate-800">
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
            <div className="flex flex-wrap items-center gap-1.5">
              {CATALOG_14_GAMES.map((g) => (
                <button
                  key={g.id}
                  type="button"
                  onClick={() =>
                    startGameSession(g.id, matchMode, aiDifficulty)
                  }
                  className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                    selectedGameId === g.id
                      ? "bg-white text-slate-950 shadow-xs"
                      : "bg-slate-900 text-slate-300 hover:bg-slate-800 border border-slate-800"
                  }`}
                >
                  {g.title}
                </button>
              ))}
            </div>

            {/* Mode Segmented Control */}
            <div className="flex flex-wrap items-center gap-2 shrink-0">
              <div className="flex items-center gap-1 p-1 bg-slate-900 border border-slate-800 rounded-lg">
                <button
                  type="button"
                  onClick={() => startGameSession(selectedGameId, "hotseat")}
                  className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                    matchMode === "hotseat"
                      ? "bg-emerald-600 text-white"
                      : "text-slate-300 hover:text-white"
                  }`}
                >
                  <Users className="w-3.5 h-3.5" />
                  <span>Hotseat Local</span>
                </button>
                <button
                  type="button"
                  onClick={() =>
                    startGameSession(selectedGameId, "ai", aiDifficulty)
                  }
                  className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                    matchMode === "ai"
                      ? "bg-emerald-600 text-white"
                      : "text-slate-300 hover:text-white"
                  }`}
                >
                  <Bot className="w-3.5 h-3.5" />
                  <span>vs IA Rust</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab("network")}
                  className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                    matchMode === "online_relay"
                      ? "bg-emerald-600 text-white"
                      : "text-slate-300 hover:text-white"
                  }`}
                >
                  <Wifi className="w-3.5 h-3.5" />
                  <span>Online Relay / QR</span>
                </button>
                <button
                  type="button"
                  onClick={() => startGameSession(selectedGameId, "spectator")}
                  className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                    matchMode === "spectator"
                      ? "bg-amber-600 text-white"
                      : "text-slate-300 hover:text-white"
                  }`}
                >
                  <Eye className="w-3.5 h-3.5" />
                  <span>Espectador</span>
                </button>
              </div>

              {matchMode === "ai" && (
                <select
                  aria-label="Dificultad de IA"
                  value={aiDifficulty}
                  onChange={(e) => {
                    const nextDiff = Number(e.target.value);
                    setAiDifficulty(nextDiff);
                    startGameSession(selectedGameId, "ai", nextDiff);
                  }}
                  className="px-3 py-2 rounded-lg text-xs font-medium bg-slate-900 border border-slate-800 text-slate-200"
                >
                  <option value={0}>IA Fácil</option>
                  <option value={1}>IA Media</option>
                  <option value={2}>IA Difícil</option>
                  <option value={3}>IA Maestra</option>
                </select>
              )}
            </div>
          </div>

          {/* Phase 4 Theme, Okabe-Ito & Procedural Audio Bar + ELO Summary */}
          <div className="flex flex-wrap items-center justify-between gap-3">
            <ThemeAndAudioToolbar
              config={themeConfig}
              onChange={setThemeConfig}
            />

            <div className="flex items-center gap-3 text-xs text-slate-300 font-mono tabular-nums">
              <span>
                ELO {activeGameMeta.title}:{" "}
                <strong className="text-emerald-400">
                  {eloProfile.statsByGame[selectedGameId]?.rating ?? 1200}
                </strong>
              </span>
              <span aria-hidden="true">·</span>
              <span>
                ELO Global:{" "}
                <strong className="text-white">
                  {eloProfile.globalRating}
                </strong>
              </span>
              <span aria-hidden="true">·</span>
              <span>
                Logros:{" "}
                <strong className="text-amber-400">
                  {eloProfile.unlockedAchievements.length}/
                  {ACHIEVEMENTS_CATALOG.length}
                </strong>
              </span>
            </div>
          </div>
        </section>

        {/* Active Tab View */}
        {activeTab === "play" && (
          <section className="flex flex-col gap-5">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold text-white font-display">
                  {activeGameMeta.title}
                </h1>
                <p className="text-xs text-slate-400 mt-1">
                  {activeGameMeta.summary} · Motor: {activeGameMeta.crateName}{" "}
                  (WASM) · Turno actual: Jugador {currentTurn}
                  {matchMode === "spectator" ? " · Modo Espectador" : ""}
                </p>
              </div>

              <div className="flex flex-wrap items-center gap-3">
                {/* Tournament Clock (FIDE / Byo-yomi) */}
                <TournamentClock
                  clockState={clockState}
                  activeTurn={(currentTurn === 2 ? 2 : 1) as 1 | 2}
                  isPaused={
                    parsedStateWinner !== null || !isReplayAtLiveHead
                  }
                  onPresetChange={(preset: ClockPresetId) =>
                    setClockState(createInitialClockState(preset))
                  }
                  onTick={handleClockTick}
                />

                {/* Online Relay Turn-Lock Controls when in Online or Spectator Mode */}
                {(matchMode === "online_relay" ||
                  matchMode === "spectator") && (
                  <div className="flex flex-wrap items-center gap-2 p-2.5 rounded-xl bg-slate-900 border border-slate-800 text-xs">
                    <span className="text-slate-300 font-mono">
                      Sala:{" "}
                      <strong className="text-white">
                        {roomCode || "LOCAL"}
                      </strong>
                    </span>
                    <span aria-hidden="true">·</span>
                    <button
                      type="button"
                      onClick={() => {
                        setMatchMode("online_relay");
                        setLocalNetworkPlayerId(1);
                      }}
                      className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                        matchMode === "online_relay" &&
                        localNetworkPlayerId === 1
                          ? "bg-emerald-600 text-white"
                          : "bg-slate-800 text-slate-300"
                      }`}
                    >
                      J1 (Host)
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setMatchMode("online_relay");
                        setLocalNetworkPlayerId(2);
                      }}
                      className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                        matchMode === "online_relay" &&
                        localNetworkPlayerId === 2
                          ? "bg-sky-600 text-white"
                          : "bg-slate-800 text-slate-300"
                      }`}
                    >
                      J2 (Cliente)
                    </button>
                    <button
                      type="button"
                      onClick={() => setMatchMode("spectator")}
                      className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                        matchMode === "spectator"
                          ? "bg-amber-600 text-white"
                          : "bg-slate-800 text-slate-300"
                      }`}
                    >
                      Espectador
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Interactive Tutorial Panel (14 Games + Live WASM Suggestion) */}
            <InteractiveTutorialPanel
              gameId={selectedGameId}
              currentTurn={(currentTurn === 2 ? 2 : 1) as 1 | 2}
              legalMovesJson={legalMovesJson}
              isLocalTurnAllowed={isLocalTurnAllowed}
              onDispatchCommand={handleDispatchCommand}
            />

            {/* Step-by-Step Replay Viewer & Save/Load JSON Bar */}
            <ReplayViewerBar
              currentStep={replayCurrentStep}
              totalSteps={replayTotalSteps}
              gameId={selectedGameId}
              onSeekStep={handleSeekReplayStep}
              onExportJson={() => bridgeRef.current.export_log_json()}
              onImportJson={handleImportReplayJson}
            />

            {selectedGameId === "chess" && (
              <ChessBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "checkers" && (
              <CheckersBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "uno" && (
              <UnoBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                isNetworkGame={
                  matchMode === "online_relay" || matchMode === "spectator"
                }
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "goose" && (
              <GooseBoard
                stateJson={stateJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "go" && (
              <GoBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "shogi" && (
              <ShogiBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "xiangqi" && (
              <XiangqiBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "chinese_checkers" && (
              <ChineseCheckersBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "backgammon" && (
              <BackgammonBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "ludo" && (
              <LudoBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "battleship" && (
              <BattleshipBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "mille_bornes" && (
              <MilleBornesBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "monopoly" && (
              <MonopolyBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {selectedGameId === "crisis" && (
              <CrisisBoard
                stateJson={stateJson}
                legalMovesJson={legalMovesJson}
                isLocalTurnAllowed={isLocalTurnAllowed}
                localPlayerId={localNetworkPlayerId}
                onDispatchCommand={handleDispatchCommand}
              />
            )}

            {/* Live Room Chat when in Online Relay or Spectator Mode */}
            {(matchMode === "online_relay" || matchMode === "spectator") && (
              <RelayChatPanel
                roomCode={roomCode}
                localPlayerName={eloProfile.playerName}
                localPlayerId={localNetworkPlayerId}
                messages={chatMessages}
                onSendMessage={handleSendChatMessage}
              />
            )}
          </section>
        )}

        {activeTab === "catalog" && (
          <section className="flex flex-col gap-6">
            <div>
              <h2 className="text-2xl font-bold text-white font-display">
                Catálogo de los 14 Juegos Canónicos (Rust → WebAssembly)
              </h2>
              <p className="text-sm text-slate-400 mt-1">
                Los 14 crates de Rust compilan sin cambios en{" "}
                <code>open_table_wasm</code> y cuentan con su tablero
                interactivo, tutorial guiado, reloj FIDE/Byo-yomi, visor de
                repeticiones, ranking ELO K=32 y modo torneo en React +
                Tailwind CSS.
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {CATALOG_14_GAMES.map((item, idx) => (
                <div
                  key={item.id}
                  className="p-5 rounded-xl bg-slate-900 border border-slate-800 flex flex-col justify-between gap-4"
                >
                  <div>
                    <div className="text-xs text-slate-400">
                      {String(idx + 1).padStart(2, "0")}. {item.category} ·{" "}
                      {item.crateName}
                    </div>
                    <h3 className="text-base font-semibold text-white mt-1">
                      {item.title}
                    </h3>
                    <p className="text-xs text-slate-300 mt-2 leading-relaxed">
                      {item.summary}
                    </p>
                  </div>

                  <div className="flex items-center justify-between pt-3 border-t border-slate-800">
                    <span className="text-xs text-slate-400 font-mono tabular-nums">
                      ELO: {eloProfile.statsByGame[item.id]?.rating ?? 1200}
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        startGameSession(item.id, matchMode, aiDifficulty);
                        setActiveTab("play");
                      }}
                      className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      Jugar Ahora
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {activeTab === "tournaments" && (
          <TournamentManagerPanel
            tournament={tournamentState}
            gameTitles={GAME_TITLES_MAP}
            activeMatchId={activeTournamentMatchId}
            onUpdateTournament={setTournamentState}
            onLaunchMatchOnBoard={handleLaunchTournamentMatch}
            onTournamentChampionCrowned={() => {
              playProceduralSound("victory", themeConfig);
              setEloProfile((prev) => {
                const { updatedProfile, newlyUnlocked } =
                  recordTournamentVictoryInProfile(prev);
                if (newlyUnlocked.length > 0) {
                  setRecentAchievementBanner(
                    "¡Logro desbloqueado: Campeón de Torneo!"
                  );
                }
                return updatedProfile;
              });
            }}
          />
        )}

        {activeTab === "elo" && (
          <EloAndAchievementsPanel
            profile={eloProfile}
            gameTitles={GAME_TITLES_MAP}
            peerEloInfo={peerEloInfo}
            onUpdateProfile={setEloProfile}
            onSyncEloToRelay={() => {
              relayRef.current?.sendEloSync(
                localNetworkPlayerId,
                eloProfile.globalRating,
                eloProfile.playerName
              );
            }}
          />
        )}

        {activeTab === "network" && (
          <section className="flex flex-col gap-8">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
                <div>
                  <h2 className="text-xl font-bold text-white font-display">
                    Crear o Unirse a Sala Online Relay (Jugador o Espectador)
                  </h2>
                  <p className="text-xs text-slate-400 mt-1">
                    Compatible con <code>open_table_relay</code> (Cross-Play
                    entre clientes Godot y clientes Web React) con envío
                    automático de <code>SyncState</code>, bloqueo de turno
                    local, sincronización ELO y chat en tiempo real.
                  </p>
                </div>

                <form
                  onSubmit={handleSaveSettings}
                  className="flex flex-col gap-2"
                >
                  <label className="text-xs font-medium text-slate-300">
                    URL del Servidor Relay WebSocket (Persistente)
                  </label>
                  <div className="flex flex-wrap items-center gap-2">
                    <input
                      type="text"
                      value={relayUrl}
                      onChange={(e) => setRelayUrl(e.target.value)}
                      placeholder="ws://127.0.0.1:8080"
                      className="flex-1 px-3.5 py-2 rounded-lg bg-slate-950 border border-slate-700 text-sm text-white font-mono"
                    />
                    <button
                      type="submit"
                      className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
                    >
                      <Settings className="w-3.5 h-3.5" />
                      <span>Guardar URL</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        const def = saveRelayUrl("ws://127.0.0.1:8080");
                        setRelayUrl(def);
                        relayRef.current?.setRelayUrl(def);
                      }}
                      className="inline-flex items-center gap-1 px-3 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs cursor-pointer"
                    >
                      <RotateCcw className="w-3.5 h-3.5" />
                      <span>Restaurar</span>
                    </button>
                  </div>
                </form>

                <div className="flex flex-wrap items-center gap-3 pt-2">
                  <button
                    type="button"
                    onClick={handleCreateRelayRoom}
                    className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors cursor-pointer"
                  >
                    <QrCode className="w-4 h-4" />
                    <span>Crear Sala Online (Host J1)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() =>
                      relayRef.current?.simulateMicroDisconnectAndReconnect()
                    }
                    disabled={!roomCode}
                    className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-40 text-slate-200 text-xs font-medium border border-slate-700 transition-colors cursor-pointer"
                  >
                    <RefreshCw className="w-4 h-4" />
                    <span>Probar Reconexión Automática</span>
                  </button>
                </div>

                <div className="border-t border-slate-800 pt-4 flex flex-col gap-3">
                  <label className="text-xs font-medium text-slate-300">
                    Unirse con Código de 6 Caracteres (Cliente J2 o Espectador)
                  </label>
                  <div className="flex flex-wrap items-center gap-2">
                    <input
                      type="text"
                      maxLength={8}
                      value={joinCodeInput}
                      onChange={(e) =>
                        setJoinCodeInput(e.target.value.toUpperCase())
                      }
                      placeholder="Ej. AB12CD"
                      className="px-3.5 py-2 rounded-lg bg-slate-950 border border-slate-700 text-sm text-white font-mono uppercase"
                    />
                    <button
                      type="button"
                      onClick={handleJoinRelayRoom}
                      className="px-4 py-2 rounded-lg bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      Unirse como J2
                    </button>
                    <button
                      type="button"
                      onClick={handleJoinAsSpectator}
                      className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-amber-600 hover:bg-amber-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      <span>Observar (Espectador)</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* QR Code & Status Card */}
              <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col items-center justify-center gap-4 text-center">
                <div className="text-xs text-slate-400">
                  Estado de Transporte:{" "}
                  <strong className="text-white">{relayState}</strong>
                </div>
                <div className="text-sm font-medium text-slate-200">
                  {relayStatusText}
                </div>

                {qrSvg ? (
                  <div className="flex flex-col items-center gap-3 mt-2">
                    <div
                      className="p-3 rounded-2xl bg-white shadow-lg"
                      dangerouslySetInnerHTML={{ __html: qrSvg }}
                    />
                    <div className="text-xs text-slate-300 font-mono">
                      Código de Sala:{" "}
                      <strong className="text-emerald-400 text-sm">
                        {roomCode}
                      </strong>
                    </div>
                  </div>
                ) : (
                  <div className="p-8 rounded-xl border border-dashed border-slate-800 text-xs text-slate-400">
                    Crea una sala online para generar el código QR instantáneo
                    de invitación.
                  </div>
                )}
              </div>
            </div>

            {/* Room Chat Panel */}
            <RelayChatPanel
              roomCode={roomCode}
              localPlayerName={eloProfile.playerName}
              localPlayerId={localNetworkPlayerId}
              messages={chatMessages}
              onSendMessage={handleSendChatMessage}
            />
          </section>
        )}
      </main>
    </div>
  );
};

export default App;
