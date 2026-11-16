import React, { useEffect, useRef, useState } from "react";
import { WasmGameBridge } from "./wasm_pkg";
import {
  getSavedRelayUrl,
  RelayConnectionState,
  RelayWebSocketClient,
  saveRelayUrl,
} from "./bridge/relayClient";
import { ChessBoard } from "./components/boards/ChessBoard";
import { CheckersBoard } from "./components/boards/CheckersBoard";
import { UnoBoard } from "./components/boards/UnoBoard";
import { GooseBoard } from "./components/boards/GooseBoard";
import {
  Bot,
  QrCode,
  RefreshCw,
  RotateCcw,
  Settings,
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
    phase: 2,
    blockLabel: "Fase 2A · Motor WASM listo",
    summary: "Tableros 9×9 / 13×13 / 19×19, Ko, Superko posicional, Handicap y Komi 6.5.",
  },
  {
    id: "shogi",
    title: "Shogi",
    crateName: "shogi_game",
    category: "Estrategia Oriental",
    phase: 2,
    blockLabel: "Fase 2A · Motor WASM listo",
    summary: "Reingreso de piezas capturadas (Komadai), Nifu, Uchifuzume y promoción FESA.",
  },
  {
    id: "xiangqi",
    title: "Xiangqi",
    crateName: "xiangqi_game",
    category: "Estrategia Oriental",
    phase: 2,
    blockLabel: "Fase 2A · Motor WASM listo",
    summary: "Tablero 9×10 con Río, Palacios diagonales, Cañones con pantalla y General Volador.",
  },
  {
    id: "chinese_checkers",
    title: "Damas Chinas",
    crateName: "chinese_checkers_game",
    category: "Estrategia Oriental",
    phase: 2,
    blockLabel: "Fase 2A · Motor WASM listo",
    summary: "Estrella hexagonal de 121 casillas para 2 a 6 jugadores con saltos en cadena.",
  },
  {
    id: "backgammon",
    title: "Backgammon",
    crateName: "backgammon_game",
    category: "Dados y Táctica",
    phase: 2,
    blockLabel: "Fase 2B · Motor WASM listo",
    summary: "24 picos, barra central, Bear-Off, tiradas dobles y cubo de doblaje (Doubling Cube).",
  },
  {
    id: "ludo",
    title: "Ludo",
    crateName: "ludo_game",
    category: "Dados y Carrera",
    phase: 2,
    blockLabel: "Fase 2B · Motor WASM listo",
    summary: "Circuito de 52 casillas + 5 de meta, 8 casillas seguras estrella y tirada extra.",
  },
  {
    id: "battleship",
    title: "Batalla Naval",
    crateName: "battleship_game",
    category: "Combate Táctico",
    phase: 2,
    blockLabel: "Fase 2B · Motor WASM listo",
    summary: "Doble cuadrícula 10×10, flota de 5 buques, ráfaga al impactar y revancha.",
  },
  {
    id: "mille_bornes",
    title: "Mil Millas",
    crateName: "mille_bornes_game",
    category: "Cartas y Carrera",
    phase: 2,
    blockLabel: "Fase 2C · Motor WASM listo",
    summary: "Ruta de 1000 km, 4 cartas de seguridad (Safeties) y reacción ¡Coup Fourré!.",
  },
  {
    id: "monopoly",
    title: "Monopoly",
    crateName: "monopoly_game",
    category: "Economía y Subastas",
    phase: 2,
    blockLabel: "Fase 2C · Motor WASM listo",
    summary: "40 casillas, Suerte/Arca, Subastas, Casas/Hoteles uniformes, Hipotecas y Trueques.",
  },
  {
    id: "crisis",
    title: "Crisis / TEG",
    crateName: "crisis_game",
    category: "Conquista Global",
    phase: 2,
    blockLabel: "Fase 2C · Motor WASM listo",
    summary: "30 territorios en 6 continentes, objetivos secretos, tarjetas y dados 3v3.",
  },
];

export type MatchMode = "hotseat" | "ai" | "online_relay";

export function computeIsLocalTurnAllowed(
  mode: MatchMode,
  currentTurn: number,
  localPlayerId: 1 | 2
): boolean {
  if (mode === "hotseat") return true;
  if (mode === "ai") return currentTurn === 1;
  return currentTurn === localPlayerId;
}

export const App: React.FC = () => {
  const bridgeRef = useRef<WasmGameBridge>(new WasmGameBridge());
  const relayRef = useRef<RelayWebSocketClient | null>(null);

  const [activeTab, setActiveTab] = useState<"play" | "catalog" | "network" | "settings">("play");
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

  // Relay & QR state
  const [relayUrl, setRelayUrl] = useState<string>(() => getSavedRelayUrl());
  const [relayState, setRelayState] = useState<RelayConnectionState>("disconnected");
  const [relayStatusText, setRelayStatusText] = useState<string>(
    "Sin sala activa (Modo Local)"
  );
  const [roomCode, setRoomCode] = useState<string>("");
  const [joinCodeInput, setJoinCodeInput] = useState<string>("");
  const [qrSvg, setQrSvg] = useState<string>("");

  const syncFromBridge = () => {
    const turn = bridgeRef.current.current_player();
    setCurrentTurn(turn);
    setStateJson(bridgeRef.current.get_state_json());
    setLegalMovesJson(bridgeRef.current.get_legal_moves_json(turn));
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
            bridgeRef.current.generate_join_qr_svg(code, "WebHost", selectedGameId)
          );
        },
        onRoomJoined: (code, pid) => {
          setRoomCode(code);
          setLocalNetworkPlayerId(pid);
        },
        onPeerJoined: () => {
          const logJson = bridgeRef.current.export_log_json();
          client.sendSyncState(bridgeRef.current.get_current_game_type(), logJson);
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
    setSelectedGameId(gameId);
    setMatchMode(mode);
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
    const turnBefore = bridgeRef.current.current_player();
    bridgeRef.current.send_command_json(turnBefore, cmdJson);
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
        bridgeRef.current.step_ai_if_needed();
        syncFromBridge();
      }, 260);
    }
  };

  const handleCreateRelayRoom = () => {
    if (!relayRef.current) return;
    relayRef.current.setRelayUrl(relayUrl);
    startGameSession(selectedGameId, "online_relay");
    const code = relayRef.current.createRoom(selectedGameId);
    setRoomCode(code);
    setLocalNetworkPlayerId(1);
    setQrSvg(bridgeRef.current.generate_join_qr_svg(code, "WebHost", selectedGameId));
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

  const handleSaveSettings = (e: React.FormEvent) => {
    e.preventDefault();
    const cleaned = saveRelayUrl(relayUrl);
    setRelayUrl(cleaned);
    relayRef.current?.setRelayUrl(cleaned);
    setRelayStatusText(`URL de Relay guardada: ${cleaned}`);
  };

  const isLocalTurnAllowed = computeIsLocalTurnAllowed(
    matchMode,
    currentTurn,
    localNetworkPlayerId
  );

  const activeGameMeta =
    CATALOG_14_GAMES.find((g) => g.id === selectedGameId) || CATALOG_14_GAMES[0];

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      {/* Strict 3-Zone Top Bar Contract */}
      <header className="flex items-center justify-between gap-8 px-6 py-4 border-b border-slate-800 bg-slate-950/95">
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
              activeTab === "play" ? "text-white underline underline-offset-8" : ""
            }`}
          >
            Tablero Activo
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("catalog")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "catalog" ? "text-white underline underline-offset-8" : ""
            }`}
          >
            14 Juegos
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("network")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "network" ? "text-white underline underline-offset-8" : ""
            }`}
          >
            Salas Online y QR
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("settings")}
            className={`hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
              activeTab === "settings" ? "text-white underline underline-offset-8" : ""
            }`}
          >
            Ajustes Relay
          </button>
        </nav>

        <div className="flex items-center gap-3 shrink-0">
          <button
            type="button"
            onClick={() => startGameSession(selectedGameId, matchMode, aiDifficulty)}
            className="px-4 py-2 text-xs font-semibold text-white bg-emerald-600 rounded-lg hover:bg-emerald-500 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            Reiniciar Partida
          </button>
        </div>
      </header>

      {/* Main Content Container (1440px baseline) */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-6 py-8 flex flex-col gap-8">
        {/* Workspace Toolbar: Game Selector + Mode Selector + Network HUD */}
        <section className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4 pb-6 border-b border-slate-800">
          <div className="flex flex-wrap items-center gap-2">
            {CATALOG_14_GAMES.filter((g) => g.phase === 1).map((g) => (
              <button
                key={g.id}
                type="button"
                onClick={() => startGameSession(g.id, matchMode, aiDifficulty)}
                className={`px-3.5 py-2 rounded-lg text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
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
          <div className="flex flex-wrap items-center gap-2">
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
                onClick={() => startGameSession(selectedGameId, "ai", aiDifficulty)}
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
        </section>

        {/* Active Tab View */}
        {activeTab === "play" && (
          <section className="flex flex-col gap-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h1 className="text-2xl font-bold text-white font-display">
                  {activeGameMeta.title}
                </h1>
                <p className="text-xs text-slate-400 mt-1">
                  {activeGameMeta.summary} · Motor: {activeGameMeta.crateName} (WASM) ·
                  Turno actual: Jugador {currentTurn}
                </p>
              </div>

              {/* Online Relay Turn-Lock Controls when in Online Mode */}
              {matchMode === "online_relay" && (
                <div className="flex flex-wrap items-center gap-2 p-2.5 rounded-xl bg-slate-900 border border-slate-800 text-xs">
                  <span className="text-slate-300 font-mono">
                    Sala: <strong className="text-white">{roomCode || "LOCAL"}</strong>
                  </span>
                  <span aria-hidden="true">·</span>
                  <span className="text-slate-300">Rol Local:</span>
                  <button
                    type="button"
                    onClick={() => setLocalNetworkPlayerId(1)}
                    className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                      localNetworkPlayerId === 1
                        ? "bg-emerald-600 text-white"
                        : "bg-slate-800 text-slate-300"
                    }`}
                  >
                    Jugador 1 (Host)
                  </button>
                  <button
                    type="button"
                    onClick={() => setLocalNetworkPlayerId(2)}
                    className={`px-2.5 py-1 rounded font-semibold cursor-pointer ${
                      localNetworkPlayerId === 2
                        ? "bg-sky-600 text-white"
                        : "bg-slate-800 text-slate-300"
                    }`}
                  >
                    Jugador 2 (Cliente)
                  </button>
                </div>
              )}
            </div>

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
                isNetworkGame={matchMode === "online_relay"}
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
                <code>open_table_wasm</code>. En la Fase 1 están habilitados los 4
                tableros representativos en React y en la Fase 2 se conectan los 10
                tableros restantes.
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
                    <span className="text-xs text-slate-400">{item.blockLabel}</span>
                    {item.phase === 1 ? (
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
                    ) : (
                      <span className="text-xs text-slate-500 font-mono">
                        Fase 2
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {activeTab === "network" && (
          <section className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
              <div>
                <h2 className="text-xl font-bold text-white font-display">
                  Crear o Unirse a Sala Online Relay
                </h2>
                <p className="text-xs text-slate-400 mt-1">
                  Compatible con <code>open_table_relay</code> (Cross-Play entre
                  clientes Godot y clientes Web React) con envío automático de{" "}
                  <code>SyncState</code> y bloqueo de turno local.
                </p>
              </div>

              <div className="flex flex-col gap-2">
                <label className="text-xs font-medium text-slate-300">
                  URL del Servidor Relay WebSocket
                </label>
                <input
                  type="text"
                  value={relayUrl}
                  onChange={(e) => setRelayUrl(e.target.value)}
                  placeholder="ws://127.0.0.1:8080"
                  className="px-3.5 py-2 rounded-lg bg-slate-950 border border-slate-700 text-sm text-white font-mono"
                />
              </div>

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
                  onClick={() => relayRef.current?.simulateMicroDisconnectAndReconnect()}
                  disabled={!roomCode}
                  className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-40 text-slate-200 text-xs font-medium border border-slate-700 transition-colors cursor-pointer"
                >
                  <RefreshCw className="w-4 h-4" />
                  <span>Probar Reconexión Automática</span>
                </button>
              </div>

              <div className="border-t border-slate-800 pt-4 flex flex-col gap-3">
                <label className="text-xs font-medium text-slate-300">
                  Unirse con Código de 6 Caracteres (Cliente J2)
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    maxLength={8}
                    value={joinCodeInput}
                    onChange={(e) => setJoinCodeInput(e.target.value.toUpperCase())}
                    placeholder="Ej. AB12CD"
                    className="px-3.5 py-2 rounded-lg bg-slate-950 border border-slate-700 text-sm text-white font-mono uppercase"
                  />
                  <button
                    type="button"
                    onClick={handleJoinRelayRoom}
                    className="px-4 py-2 rounded-lg bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                  >
                    Unirse a Sala
                  </button>
                </div>
              </div>
            </div>

            {/* QR Code & Status Card */}
            <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col items-center justify-center gap-4 text-center">
              <div className="text-xs text-slate-400">
                Estado de Transporte: <strong className="text-white">{relayState}</strong>
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
                    <strong className="text-emerald-400 text-sm">{roomCode}</strong>
                  </div>
                </div>
              ) : (
                <div className="p-8 rounded-xl border border-dashed border-slate-800 text-xs text-slate-400">
                  Crea una sala online para generar el código QR instantáneo de
                  invitación.
                </div>
              )}
            </div>
          </section>
        )}

        {activeTab === "settings" && (
          <section className="max-w-xl p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col gap-5">
            <div className="flex items-center gap-2.5">
              <Settings className="w-5 h-5 text-emerald-400" />
              <h2 className="text-xl font-bold text-white font-display">
                Ajustes de Red y Servidor Relay
              </h2>
            </div>

            <form onSubmit={handleSaveSettings} className="flex flex-col gap-4">
              <div className="flex flex-col gap-1.5">
                <label className="text-xs font-medium text-slate-300">
                  URL del Servidor Relay WebSocket (Persistente en navegador)
                </label>
                <input
                  type="text"
                  value={relayUrl}
                  onChange={(e) => setRelayUrl(e.target.value)}
                  className="px-3.5 py-2 rounded-lg bg-slate-950 border border-slate-700 text-sm text-white font-mono"
                />
                <span className="text-[11px] text-slate-400">
                  Clave de almacenamiento: <code>opentable.relay_url</code> · Por
                  defecto: <code>ws://127.0.0.1:8080</code>
                </span>
              </div>

              <div className="flex items-center gap-3">
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors cursor-pointer"
                >
                  Guardar Configuración
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const def = saveRelayUrl("ws://127.0.0.1:8080");
                    setRelayUrl(def);
                    relayRef.current?.setRelayUrl(def);
                  }}
                  className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium transition-colors cursor-pointer"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  <span>Restaurar por defecto</span>
                </button>
              </div>
            </form>
          </section>
        )}
      </main>
    </div>
  );
};
export default App;
