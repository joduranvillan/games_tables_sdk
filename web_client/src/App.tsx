import React, { useEffect, useRef, useState } from "react";
import { WasmGameBridge } from "./wasm_pkg";
import {
  getSavedRelayUrl,
  MatchmakingQueueTicket,
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
import { MatchmakingQueuePanel } from "./components/common/MatchmakingQueuePanel";
import { PostMatchAnalyzerPanel } from "./components/common/PostMatchAnalyzerPanel";
import { SystemDiagnosticsPanel } from "./components/common/SystemDiagnosticsPanel";
import { DocumentationCenterModal } from "./components/common/DocumentationCenterModal";
import {
  CategorizedGameListContent,
  CategoryFilterId,
  filterAndGroupCatalogGames,
  GAME_CATEGORY_GROUPS,
  MobileBottomNav,
  MobileGameListDrawer,
} from "./components/common/GameListNavigation";
import {
  Activity,
  BarChart3,
  BookOpen,
  Bot,
  ChevronDown,
  Clock,
  Eye,
  History,
  Layers,
  Palette,
  QrCode,
  RefreshCw,
  RotateCcw,
  Search,
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
    | "play"
    | "catalog"
    | "tournaments"
    | "elo"
    | "analyzer"
    | "network"
    | "diagnostics"
  >("play");
  const [isDocsModalOpen, setIsDocsModalOpen] = useState<boolean>(false);
  const [isGameDrawerOpen, setIsGameDrawerOpen] = useState<boolean>(false);
  const [gameSearchQuery, setGameSearchQuery] = useState<string>("");
  const [gameCategoryFilter, setGameCategoryFilter] =
    useState<CategoryFilterId>("all");
  const [activeHudDrawer, setActiveHudDrawer] = useState<
    "none" | "clock" | "tutorial" | "replay" | "appearance"
  >("none");
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
  const [isQueuingMatchmaking, setIsQueuingMatchmaking] =
    useState<boolean>(false);
  const [activeQueueTicket, setActiveQueueTicket] =
    useState<MatchmakingQueueTicket | null>(null);

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
        onMatchmakingFound: (code, assignedPid, oppElo, oppName) => {
          setIsQueuingMatchmaking(false);
          setActiveQueueTicket(null);
          setRoomCode(code);
          setLocalNetworkPlayerId(assignedPid);
          setPeerEloInfo({ playerName: oppName, rating: oppElo });
          setMatchMode("online_relay");
          playProceduralSound("victory", themeConfig);
          setActiveTab("play");
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

  const handleStartMatchmakingQueue = (maxEloDelta: number) => {
    if (!relayRef.current) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "online_relay");
    const currentGameElo =
      eloProfile.statsByGame[selectedGameId]?.rating ?? eloProfile.globalRating;
    const ticket = relayRef.current.queueMatchmaking(
      selectedGameId,
      currentGameElo,
      maxEloDelta,
      eloProfile.playerName
    );
    setActiveQueueTicket(ticket);
    setIsQueuingMatchmaking(true);
    setRoomCode(ticket.roomCode);
    setQrSvg(
      bridgeRef.current.generate_join_qr_svg(
        ticket.roomCode,
        eloProfile.playerName,
        selectedGameId
      )
    );
  };

  const handleExpandMatchmakingTolerance = (newMaxDelta: number) => {
    relayRef.current?.expandMatchmakingTolerance(newMaxDelta);
    const updated = relayRef.current?.getActiveQueueTicket() ?? null;
    if (updated) {
      setActiveQueueTicket({ ...updated });
    }
  };

  const handleCancelMatchmakingQueue = () => {
    relayRef.current?.cancelMatchmaking();
    setIsQueuingMatchmaking(false);
    setActiveQueueTicket(null);
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
        className={`sticky top-0 z-30 flex items-center justify-between gap-4 sm:gap-8 px-4 sm:px-6 py-3 sm:py-4 border-b backdrop-blur-md ${currentTheme.headerBgClass}`}
      >
        <a
          href="#top"
          onClick={(e) => {
            e.preventDefault();
            setActiveTab("play");
          }}
          className="text-base sm:text-lg font-bold tracking-tight text-white font-display whitespace-nowrap shrink-0"
        >
          OpenTable Web
        </a>

        <nav className="hidden lg:flex items-center gap-6 text-sm font-medium text-slate-300">
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
            onClick={() => setActiveTab("network")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "network"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            Salas Online
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
            onClick={() => setActiveTab("analyzer")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "analyzer"
                ? "text-white underline underline-offset-8"
                : ""
            }`}
          >
            Analizador
          </button>
        </nav>

        <div className="flex items-center gap-2 sm:gap-3 shrink-0">
          <PWAInstallButton />
          <button
            type="button"
            onClick={() =>
              startGameSession(selectedGameId, matchMode, aiDifficulty)
            }
            className={`min-h-[40px] px-3.5 sm:px-4 py-2 text-xs font-semibold rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer ${currentTheme.accentBtnClass}`}
          >
            Reiniciar Partida
          </button>
        </div>
      </header>

      {/* Mobile & Tablet Game List Drawer (< 1024px) */}
      <MobileGameListDrawer
        isOpen={isGameDrawerOpen}
        onClose={() => setIsGameDrawerOpen(false)}
        catalog={CATALOG_14_GAMES}
        selectedGameId={selectedGameId}
        searchQuery={gameSearchQuery}
        categoryFilter={gameCategoryFilter}
        eloByGame={eloProfile.statsByGame}
        globalElo={eloProfile.globalRating}
        unlockedAchievementsCount={eloProfile.unlockedAchievements.length}
        totalAchievementsCount={ACHIEVEMENTS_CATALOG.length}
        onSearchChange={setGameSearchQuery}
        onCategoryFilterChange={setGameCategoryFilter}
        onSelectGame={(gid) => {
          startGameSession(gid, matchMode, aiDifficulty);
          setActiveTab("play");
        }}
        onOpenCatalogGrid={() => setActiveTab("catalog")}
        onOpenDiagnostics={() => setActiveTab("diagnostics")}
        onOpenDocs={() => setIsDocsModalOpen(true)}
      />

      {/* Responsive 2-Column Workspace Container (Desktop Sidebar + Main Content; Mobile Full-Width + Bottom Nav Padding) */}
      <main className="flex-1 max-w-[1440px] w-full mx-auto px-3 sm:px-6 pt-3 sm:pt-6 pb-20 lg:pb-8 flex flex-col lg:flex-row gap-5 lg:gap-6 items-start">
        {/* Persistent Categorized Game List Sidebar on Desktop (lg: >= 1024px) */}
        <aside
          aria-label="Lista de los 14 juegos por categoría"
          className="hidden lg:flex flex-col w-80 shrink-0 sticky top-20 max-h-[calc(100vh-6rem)] rounded-2xl bg-slate-900/90 border border-slate-800 overflow-hidden"
        >
          <CategorizedGameListContent
            catalog={CATALOG_14_GAMES}
            selectedGameId={selectedGameId}
            searchQuery={gameSearchQuery}
            categoryFilter={gameCategoryFilter}
            eloByGame={eloProfile.statsByGame}
            globalElo={eloProfile.globalRating}
            unlockedAchievementsCount={eloProfile.unlockedAchievements.length}
            totalAchievementsCount={ACHIEVEMENTS_CATALOG.length}
            onSearchChange={setGameSearchQuery}
            onCategoryFilterChange={setGameCategoryFilter}
            onSelectGame={(gid) => {
              startGameSession(gid, matchMode, aiDifficulty);
              setActiveTab("play");
            }}
            onOpenCatalogGrid={() => setActiveTab("catalog")}
            onOpenDiagnostics={() => setActiveTab("diagnostics")}
            onOpenDocs={() => setIsDocsModalOpen(true)}
          />
        </aside>

        {/* Primary Adaptive Content Column */}
        <div className="flex-1 min-w-0 w-full flex flex-col gap-4 sm:gap-5">
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

          {/* Mobile & Tablet Quick Bar: Active Game Switcher + Quick Secondary Views (< 1024px) */}
          <div className="lg:hidden flex flex-col gap-2.5">
            <div className="p-2.5 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-between gap-2">
              <button
                type="button"
                onClick={() => setIsGameDrawerOpen(true)}
                className="min-h-[44px] flex-1 px-3 py-1.5 rounded-xl bg-slate-950 hover:bg-slate-800 border border-slate-800 flex items-center justify-between gap-2 text-left transition-colors cursor-pointer"
              >
                <div className="min-w-0">
                  <div className="text-[11px] text-slate-400 truncate">
                    {activeGameMeta.category} · ELO{" "}
                    <span className="font-mono tabular-nums text-emerald-400 font-semibold">
                      {eloProfile.statsByGame[selectedGameId]?.rating ?? 1200}
                    </span>
                  </div>
                  <div className="text-sm font-bold text-white truncate">
                    {activeGameMeta.title}
                  </div>
                </div>
                <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-600/20 border border-emerald-500/40 text-emerald-300 text-xs font-semibold whitespace-nowrap shrink-0">
                  <Layers className="w-3.5 h-3.5" />
                  <span>Lista (14)</span>
                  <ChevronDown className="w-3.5 h-3.5" />
                </span>
              </button>

              <button
                type="button"
                onClick={() => setIsDocsModalOpen(true)}
                aria-label="Abrir Guía y Documentación"
                className="min-h-[44px] px-3 py-2 rounded-xl bg-slate-950 hover:bg-slate-800 border border-slate-800 text-sky-400 text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer"
              >
                <BookOpen className="w-4 h-4" />
                <span className="hidden sm:inline">Guía</span>
              </button>

              <button
                type="button"
                onClick={() => setActiveTab("diagnostics")}
                aria-label="Abrir Diagnóstico E2E"
                className={`min-h-[44px] px-3 py-2 rounded-xl border text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer ${
                  activeTab === "diagnostics"
                    ? "bg-emerald-600 text-white border-emerald-500"
                    : "bg-slate-950 hover:bg-slate-800 border-slate-800 text-emerald-400"
                }`}
              >
                <Activity className="w-4 h-4" />
                <span className="hidden sm:inline">E2E</span>
              </button>
            </div>

            {/* Sub-navigation bar when inside ELO / Analyzer / Diagnostics / Catalog on mobile/tablet */}
            {activeTab !== "play" && (
              <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
                <button
                  type="button"
                  onClick={() => setActiveTab("play")}
                  className="min-h-[38px] px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-semibold whitespace-nowrap shrink-0 cursor-pointer"
                >
                  ← Volver al Tablero ({activeGameMeta.title})
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab("catalog")}
                  className={`min-h-[38px] px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                    activeTab === "catalog"
                      ? "bg-white text-slate-950 font-semibold"
                      : "bg-slate-900 text-slate-300 border border-slate-800"
                  }`}
                >
                  Catálogo 14 Juegos
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab("elo")}
                  className={`min-h-[38px] px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                    activeTab === "elo"
                      ? "bg-white text-slate-950 font-semibold"
                      : "bg-slate-900 text-slate-300 border border-slate-800"
                  }`}
                >
                  Ranking ELO
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab("analyzer")}
                  className={`min-h-[38px] px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                    activeTab === "analyzer"
                      ? "bg-white text-slate-950 font-semibold"
                      : "bg-slate-900 text-slate-300 border border-slate-800"
                  }`}
                >
                  Analizador Post-Partida
                </button>
              </div>
            )}
          </div>

          {/* ACTIVE TAB: PLAY (Board-First Layout with Compact HUD & Collapsible Secondary Tools) */}
          {activeTab === "play" && (
            <section className="flex flex-col gap-3.5 sm:gap-4">
              {/* Compact Match HUD Header */}
              <div className="p-3.5 sm:p-4 rounded-2xl bg-slate-900/90 border border-slate-800 flex flex-col gap-3">
                {/* Row 1: Game Identity + Turn Status + Mode Segmented Switcher */}
                <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h1 className="text-lg sm:text-xl font-bold text-white font-display tracking-tight">
                        {activeGameMeta.title}
                      </h1>
                      <span
                        aria-hidden="true"
                        className="text-slate-600 hidden sm:inline"
                      >
                        ·
                      </span>
                      <span className="text-xs font-mono tabular-nums text-emerald-400 font-semibold">
                        Turno: Jugador {currentTurn}
                      </span>
                      {matchMode === "spectator" && (
                        <>
                          <span aria-hidden="true" className="text-slate-600">
                            ·
                          </span>
                          <span className="text-xs font-semibold text-amber-400">
                            Modo Espectador
                          </span>
                        </>
                      )}
                    </div>
                    <p className="text-xs text-slate-400 mt-0.5 line-clamp-1">
                      {activeGameMeta.summary} · Motor: {activeGameMeta.crateName}{" "}
                      (WASM)
                    </p>
                  </div>

                  {/* Match Mode Segmented Control */}
                  <div className="flex flex-wrap items-center gap-2 shrink-0">
                    <div className="grid grid-cols-2 sm:flex items-center gap-1 p-1 bg-slate-950 border border-slate-800 rounded-xl w-full sm:w-auto">
                      <button
                        type="button"
                        onClick={() => startGameSession(selectedGameId, "hotseat")}
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "hotseat"
                            ? "bg-emerald-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Users className="w-3.5 h-3.5 shrink-0" />
                        <span>Hotseat Local</span>
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          startGameSession(selectedGameId, "ai", aiDifficulty)
                        }
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "ai"
                            ? "bg-emerald-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Bot className="w-3.5 h-3.5 shrink-0" />
                        <span>vs IA Rust</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => setActiveTab("network")}
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "online_relay"
                            ? "bg-emerald-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Wifi className="w-3.5 h-3.5 shrink-0" />
                        <span>Online Relay / QR</span>
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          startGameSession(selectedGameId, "spectator")
                        }
                        className={`min-h-[38px] inline-flex items-center justify-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          matchMode === "spectator"
                            ? "bg-amber-600 text-white"
                            : "text-slate-300 hover:text-white"
                        }`}
                      >
                        <Eye className="w-3.5 h-3.5 shrink-0" />
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
                        className="min-h-[38px] px-3 py-1.5 rounded-xl text-xs font-medium bg-slate-950 border border-slate-800 text-slate-200"
                      >
                        <option value={0}>IA Fácil</option>
                        <option value={1}>IA Media</option>
                        <option value={2}>IA Difícil</option>
                        <option value={3}>IA Maestra</option>
                      </select>
                    )}
                  </div>
                </div>

                {/* Row 2: Collapsible Secondary Tool Toggles (Clock, Tutorial/IA, Replay, Appearance/Audio) */}
                <div className="pt-2.5 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() =>
                        setActiveHudDrawer((prev) =>
                          prev === "tutorial" ? "none" : "tutorial"
                        )
                      }
                      className={`min-h-[38px] inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        activeHudDrawer === "tutorial"
                          ? "bg-amber-500 text-slate-950 border-amber-400"
                          : "bg-slate-950 hover:bg-slate-800 text-amber-300 border-slate-800"
                      }`}
                    >
                      <BookOpen className="w-3.5 h-3.5" />
                      <span>Tutorial y Sugerencia</span>
                    </button>

                    <button
                      type="button"
                      onClick={() =>
                        setActiveHudDrawer((prev) =>
                          prev === "replay" ? "none" : "replay"
                        )
                      }
                      className={`min-h-[38px] inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        activeHudDrawer === "replay" || !isReplayAtLiveHead
                          ? "bg-emerald-600 text-white border-emerald-500"
                          : "bg-slate-950 hover:bg-slate-800 text-slate-300 border-slate-800"
                      }`}
                    >
                      <History className="w-3.5 h-3.5" />
                      <span className="font-mono tabular-nums">
                        Repeticiones ({replayCurrentStep}/{replayTotalSteps})
                      </span>
                    </button>

                    <button
                      type="button"
                      onClick={() =>
                        setActiveHudDrawer((prev) =>
                          prev === "clock" ? "none" : "clock"
                        )
                      }
                      className={`min-h-[38px] inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        activeHudDrawer === "clock" ||
                        clockState.preset !== "none"
                          ? "bg-emerald-600/25 text-emerald-300 border-emerald-500/50"
                          : "bg-slate-950 hover:bg-slate-800 text-slate-300 border-slate-800"
                      }`}
                    >
                      <Clock className="w-3.5 h-3.5" />
                      <span>
                        {clockState.preset === "none"
                          ? "Reloj de Torneo"
                          : "Reloj Activo"}
                      </span>
                    </button>

                    <button
                      type="button"
                      onClick={() =>
                        setActiveHudDrawer((prev) =>
                          prev === "appearance" ? "none" : "appearance"
                        )
                      }
                      className={`min-h-[38px] inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        activeHudDrawer === "appearance"
                          ? "bg-white text-slate-950 border-white"
                          : "bg-slate-950 hover:bg-slate-800 text-slate-300 border-slate-800"
                      }`}
                    >
                      <Palette className="w-3.5 h-3.5" />
                      <span>Tema y Audio</span>
                    </button>
                  </div>

                  {/* Online Relay Role Switcher when in Online or Spectator Mode */}
                  {(matchMode === "online_relay" ||
                    matchMode === "spectator") && (
                    <div className="flex flex-wrap items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-slate-950 border border-slate-800 text-xs">
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
                        className={`px-2 py-0.5 rounded font-semibold cursor-pointer ${
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
                        className={`px-2 py-0.5 rounded font-semibold cursor-pointer ${
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
                        className={`px-2 py-0.5 rounded font-semibold cursor-pointer ${
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

                {/* Collapsible Drawer: Clock (Always mounted if preset !== "none" so timer keeps ticking) */}
                {(activeHudDrawer === "clock" ||
                  clockState.preset !== "none") && (
                  <div className="pt-2 border-t border-slate-800/80">
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
                  </div>
                )}

                {/* Collapsible Drawer: Theme, Okabe-Ito & Procedural Audio */}
                {activeHudDrawer === "appearance" && (
                  <div className="pt-2 border-t border-slate-800/80">
                    <ThemeAndAudioToolbar
                      config={themeConfig}
                      onChange={setThemeConfig}
                    />
                  </div>
                )}

                {/* Collapsible Drawer: Interactive Tutorial & Live WASM Move Suggestion */}
                {activeHudDrawer === "tutorial" && (
                  <div className="pt-2 border-t border-slate-800/80">
                    <InteractiveTutorialPanel
                      gameId={selectedGameId}
                      currentTurn={(currentTurn === 2 ? 2 : 1) as 1 | 2}
                      legalMovesJson={legalMovesJson}
                      isLocalTurnAllowed={isLocalTurnAllowed}
                      onDispatchCommand={handleDispatchCommand}
                      hideToggleButton={true}
                      onClose={() => setActiveHudDrawer("none")}
                    />
                  </div>
                )}

                {/* Collapsible Drawer: Step-by-Step Replay Viewer & Save/Load JSON */}
                {(activeHudDrawer === "replay" || !isReplayAtLiveHead) && (
                  <div className="pt-2 border-t border-slate-800/80">
                    <ReplayViewerBar
                      currentStep={replayCurrentStep}
                      totalSteps={replayTotalSteps}
                      gameId={selectedGameId}
                      onSeekStep={handleSeekReplayStep}
                      onExportJson={() => bridgeRef.current.export_log_json()}
                      onImportJson={handleImportReplayJson}
                    />
                  </div>
                )}
              </div>

              {/* Active Game Board Viewport (Immediately visible above the fold on mobile, tablet & desktop) */}
              <div className="w-full overflow-x-auto">
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
              </div>

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

          {/* ACTIVE TAB: CATALOG (Categorized 14 Games View with Search & Filter) */}
          {activeTab === "catalog" && (
            <section className="flex flex-col gap-5">
              <div className="p-4 sm:p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-4">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div>
                    <h2 className="text-xl sm:text-2xl font-bold text-white font-display">
                      Catálogo de los 14 Juegos por Categoría
                    </h2>
                    <p className="text-xs sm:text-sm text-slate-400 mt-1">
                      Selecciona cualquier juego para abrir su tablero
                      interactivo WASM con tutorial guiado, reloj FIDE/Byo-yomi
                      y ranking ELO K=32.
                    </p>
                  </div>
                </div>

                {/* Search & Rapid Filter Bar */}
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
                  <div className="relative flex-1">
                    <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type="text"
                      value={gameSearchQuery}
                      onChange={(e) => setGameSearchQuery(e.target.value)}
                      placeholder="Buscar por nombre, categoría o regla canónica..."
                      className="w-full min-h-[42px] pl-10 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs sm:text-sm text-white placeholder:text-slate-500"
                    />
                  </div>

                  <div className="flex flex-wrap items-center gap-1.5 bg-slate-950 p-1.5 rounded-xl border border-slate-800">
                    <button
                      type="button"
                      onClick={() => setGameCategoryFilter("all")}
                      className={`min-h-[34px] px-3 py-1 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        gameCategoryFilter === "all"
                          ? "bg-emerald-600 text-white"
                          : "text-slate-400 hover:text-white"
                      }`}
                    >
                      Todos (14)
                    </button>
                    {GAME_CATEGORY_GROUPS.map((grp) => (
                      <button
                        key={grp.id}
                        type="button"
                        onClick={() => setGameCategoryFilter(grp.id)}
                        className={`min-h-[34px] px-3 py-1 rounded-lg text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                          gameCategoryFilter === grp.id
                            ? "bg-emerald-600 text-white"
                            : "text-slate-400 hover:text-white"
                        }`}
                      >
                        {grp.shortLabel}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {filterAndGroupCatalogGames(
                CATALOG_14_GAMES,
                gameSearchQuery,
                gameCategoryFilter
              ).map((section) => (
                <div key={section.groupId} className="flex flex-col gap-3">
                  <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                    <h3 className="text-base font-bold text-white font-display">
                      {section.groupLabel}
                    </h3>
                    <span className="text-xs text-slate-400 font-mono tabular-nums">
                      {section.games.length}{" "}
                      {section.games.length === 1 ? "juego" : "juegos"}
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3.5">
                    {section.games.map((item) => {
                      const idx =
                        CATALOG_14_GAMES.findIndex((g) => g.id === item.id) + 1;
                      const isCurrent = item.id === selectedGameId;
                      return (
                        <div
                          key={item.id}
                          className={`p-4 sm:p-5 rounded-2xl border flex flex-col justify-between gap-4 transition-colors ${
                            isCurrent
                              ? "bg-emerald-950/20 border-emerald-500/60"
                              : "bg-slate-900 border-slate-800"
                          }`}
                        >
                          <div>
                            <div className="text-xs text-slate-400">
                              {String(idx).padStart(2, "0")}. {item.category} ·{" "}
                              {item.crateName}
                            </div>
                            <h4 className="text-base font-semibold text-white mt-1">
                              {item.title}
                            </h4>
                            <p className="text-xs text-slate-300 mt-1.5 leading-relaxed">
                              {item.summary}
                            </p>
                          </div>

                          <div className="flex items-center justify-between pt-3 border-t border-slate-800">
                            <span className="text-xs text-slate-300 font-mono tabular-nums">
                              ELO:{" "}
                              <strong className="text-emerald-400">
                                {eloProfile.statsByGame[item.id]?.rating ??
                                  1200}
                              </strong>
                            </span>
                            <button
                              type="button"
                              onClick={() => {
                                startGameSession(
                                  item.id,
                                  matchMode,
                                  aiDifficulty
                                );
                                setActiveTab("play");
                              }}
                              className="min-h-[38px] px-4 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                            >
                              {isCurrent ? "En Tablero Activo" : "Jugar Ahora"}
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
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

          {activeTab === "analyzer" && (
            <PostMatchAnalyzerPanel
              activeGame={selectedGameId}
              activeGameTitle={activeGameMeta.title}
              activeExportLogJson={bridgeRef.current.export_log_json()}
              colorblindMode={themeConfig.okabeIto}
              onLoadReplayLogToBoard={(logJson) => {
                if (handleImportReplayJson(logJson)) {
                  setActiveTab("play");
                }
              }}
            />
          )}

          {activeTab === "network" && (
            <section className="flex flex-col gap-6">
              {/* Mobile/Desktop Return to Board Banner */}
              <div className="p-3.5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-wrap items-center justify-between gap-3">
                <div className="text-xs text-slate-300">
                  Juego seleccionado para sala o matchmaking:{" "}
                  <strong className="text-white">{activeGameMeta.title}</strong>{" "}
                  · ELO{" "}
                  <span className="font-mono tabular-nums text-emerald-400 font-semibold">
                    {eloProfile.statsByGame[selectedGameId]?.rating ?? 1200}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setIsGameDrawerOpen(true)}
                    className="lg:hidden min-h-[38px] px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
                  >
                    Cambiar Juego
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveTab("play")}
                    className="min-h-[38px] px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
                  >
                    Ver Tablero Activo
                  </button>
                </div>
              </div>

              <MatchmakingQueuePanel
                activeGame={selectedGameId}
                activeGameTitle={activeGameMeta.title}
                playerElo={
                  eloProfile.statsByGame[selectedGameId]?.rating ??
                  eloProfile.globalRating
                }
                playerName={eloProfile.playerName}
                isQueuing={isQueuingMatchmaking}
                activeTicket={activeQueueTicket}
                onStartQueue={handleStartMatchmakingQueue}
                onExpandQueueTolerance={handleExpandMatchmakingTolerance}
                onCancelQueue={handleCancelMatchmakingQueue}
                onQuickCalibratedAiMatch={(diff) => {
                  setAiDifficulty(diff);
                  startGameSession(selectedGameId, "ai", diff);
                  setActiveTab("play");
                }}
              />

              <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                <div className="p-5 sm:p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
                  <div>
                    <h2 className="text-lg sm:text-xl font-bold text-white font-display">
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
                        className="flex-1 min-w-[180px] min-h-[42px] px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-700 text-sm text-white font-mono"
                      />
                      <button
                        type="submit"
                        className="min-h-[42px] inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium cursor-pointer"
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
                        className="min-h-[42px] inline-flex items-center gap-1 px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs cursor-pointer"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        <span>Restaurar</span>
                      </button>
                    </div>
                  </form>

                  <div className="flex flex-wrap items-center gap-3 pt-1">
                    <button
                      type="button"
                      onClick={handleCreateRelayRoom}
                      className="min-h-[44px] inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors cursor-pointer"
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
                      className="min-h-[44px] inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 disabled:opacity-40 text-slate-200 text-xs font-medium border border-slate-700 transition-colors cursor-pointer"
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
                        className="min-h-[44px] px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-700 text-sm text-white font-mono uppercase"
                      />
                      <button
                        type="button"
                        onClick={handleJoinRelayRoom}
                        className="min-h-[44px] px-4 py-2 rounded-xl bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                      >
                        Unirse como J2
                      </button>
                      <button
                        type="button"
                        onClick={handleJoinAsSpectator}
                        className="min-h-[44px] inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-amber-600 hover:bg-amber-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>Observar (Espectador)</span>
                      </button>
                    </div>
                  </div>
                </div>

                {/* QR Code & Status Card */}
                <div className="p-5 sm:p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col items-center justify-center gap-4 text-center">
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
                    <div className="p-6 sm:p-8 rounded-xl border border-dashed border-slate-800 text-xs text-slate-400">
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

          {activeTab === "diagnostics" && (
            <SystemDiagnosticsPanel
              activeGameId={selectedGameId}
              relayState={relayState}
              onSelectGameAndPlay={(gid) => {
                startGameSession(gid, matchMode, aiDifficulty);
                setActiveTab("play");
              }}
              onOpenDocsModal={() => setIsDocsModalOpen(true)}
            />
          )}
        </div>
      </main>

      {/* Mobile & Tablet Fixed Bottom Touch Bar (< 1024px) */}
      <MobileBottomNav
        activeTab={activeTab}
        isGameDrawerOpen={isGameDrawerOpen}
        hasActiveRoomOrQueue={Boolean(roomCode) || isQueuingMatchmaking}
        onSelectTab={(tab) => {
          setIsGameDrawerOpen(false);
          setActiveTab(tab);
        }}
        onToggleGameDrawer={() => setIsGameDrawerOpen((prev) => !prev)}
      />

      <DocumentationCenterModal
        isOpen={isDocsModalOpen}
        onClose={() => setIsDocsModalOpen(false)}
      />
    </div>
  );
};

export default App;
