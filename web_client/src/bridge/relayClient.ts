/**
 * Cliente WebSocket nativo para `open_table_relay`
 *
 * Compatible con el protocolo de salas de 6 caracteres (`create_room`, `join_room`),
 * sincronización autoritativa de estado (`SyncState`), persistencia de `relay_url`
 * en Ajustes (`localStorage["opentable.relay_url"]`) y reconexión automática.
 */

export const RELAY_URL_STORAGE_KEY = "opentable.relay_url";
export const DEFAULT_RELAY_URL = "ws://127.0.0.1:8080";

export type RelayConnectionState =
  | "disconnected"
  | "connecting"
  | "connected_host"
  | "connected_client"
  | "connected_spectator"
  | "reconnecting";

export interface SyncStateMessage {
  type: "SyncState";
  game_type: string;
  log_json: string;
}

export interface RelayChatMessage {
  id: string;
  roomCode: string;
  senderName: string;
  playerId: number;
  text: string;
  timestamp: string;
}

export interface MatchmakingQueueTicket {
  ticketId: string;
  gameId: string;
  playerName: string;
  elo: number;
  maxEloDelta: number;
  roomCode: string;
  queuedAtMs: number;
}

export function areMatchmakingTicketsCompatible(
  a: Pick<MatchmakingQueueTicket, "gameId" | "elo" | "maxEloDelta">,
  b: Pick<MatchmakingQueueTicket, "gameId" | "elo" | "maxEloDelta">
): boolean {
  if (a.gameId.trim().toLowerCase() !== b.gameId.trim().toLowerCase()) {
    return false;
  }
  const allowedDelta = Math.min(Math.max(50, a.maxEloDelta), Math.max(50, b.maxEloDelta));
  return Math.abs(a.elo - b.elo) <= allowedDelta;
}

export interface RelayEventCallbacks {
  onStateChange?: (state: RelayConnectionState, info?: string) => void;
  onRoomCreated?: (roomCode: string, localPlayerId: 1 | 2) => void;
  onRoomJoined?: (roomCode: string, localPlayerId: 1 | 2) => void;
  onSpectatorJoined?: (roomCode: string) => void;
  onPeerJoined?: (peerPlayerId: number) => void;
  onCommandReceived?: (playerId: number, commandJson: string) => void;
  onSyncStateReceived?: (gameType: string, logJson: string) => void;
  onChatMessageReceived?: (msg: RelayChatMessage) => void;
  onEloSyncReceived?: (playerId: number, rating: number, playerName: string) => void;
  onMatchmakingFound?: (
    roomCode: string,
    assignedPlayerId: 1 | 2,
    opponentElo: number,
    opponentName: string
  ) => void;
}

export function getSavedRelayUrl(): string {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      const saved = window.localStorage.getItem(RELAY_URL_STORAGE_KEY);
      if (saved && saved.trim().length > 0) {
        return saved.trim();
      }
    }
  } catch {
    // Fallback in non-DOM test environments
  }
  return DEFAULT_RELAY_URL;
}

export function saveRelayUrl(url: string): string {
  const clean = url.trim() || DEFAULT_RELAY_URL;
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      window.localStorage.setItem(RELAY_URL_STORAGE_KEY, clean);
    }
  } catch {
    // Ignore storage quota errors
  }
  return clean;
}

export class RelayWebSocketClient {
  private relayUrl: string;
  private ws: WebSocket | null = null;
  private roomCode: string = "";
  private localPlayerId: 1 | 2 = 1;
  private isSpectator: boolean = false;
  private state: RelayConnectionState = "disconnected";
  private reconnectAttempts: number = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private callbacks: RelayEventCallbacks;
  private broadcastChannel: BroadcastChannel | null = null;
  private matchmakingChannel: BroadcastChannel | null = null;
  private activeQueueTicket: MatchmakingQueueTicket | null = null;

  constructor(callbacks: RelayEventCallbacks = {}, initialUrl?: string) {
    this.callbacks = callbacks;
    this.relayUrl = initialUrl ? saveRelayUrl(initialUrl) : getSavedRelayUrl();
  }

  public getRelayUrl(): string {
    return this.relayUrl;
  }

  public setRelayUrl(url: string): void {
    this.relayUrl = saveRelayUrl(url);
  }

  public getRoomCode(): string {
    return this.roomCode;
  }

  public getLocalPlayerId(): 1 | 2 {
    return this.localPlayerId;
  }

  public isSpectatorRole(): boolean {
    return this.isSpectator;
  }

  public getConnectionState(): RelayConnectionState {
    return this.state;
  }

  private setState(next: RelayConnectionState, info?: string): void {
    this.state = next;
    this.callbacks.onStateChange?.(next, info);
  }

  private setupSameOriginTabChannel(code: string): void {
    try {
      if (typeof BroadcastChannel !== "undefined") {
        this.broadcastChannel?.close();
        this.broadcastChannel = new BroadcastChannel(`opentable_relay_${code}`);
        this.broadcastChannel.onmessage = (ev) => {
          const data = ev.data;
          if (!data || typeof data !== "object") return;
          if (data.type === "PEER_JOINED" && this.localPlayerId === 1 && !this.isSpectator) {
            this.callbacks.onPeerJoined?.(2);
          } else if (data.type === "COMMAND" && (this.isSpectator || data.sender !== this.localPlayerId)) {
            this.callbacks.onCommandReceived?.(data.sender, data.commandJson);
          } else if (data.type === "SYNC_STATE" && (this.isSpectator || this.localPlayerId === 2)) {
            this.callbacks.onSyncStateReceived?.(data.gameType, data.logJson);
          } else if (data.type === "CHAT" && data.message) {
            this.callbacks.onChatMessageReceived?.(data.message as RelayChatMessage);
          } else if (data.type === "ELO_SYNC") {
            this.callbacks.onEloSyncReceived?.(
              Number(data.playerId || 1),
              Number(data.rating || 1200),
              String(data.playerName || "Jugador")
            );
          }
        };
      }
    } catch {
      // BroadcastChannel optional
    }
  }

  public createRoom(gameId: string): string {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let generated = "";
    for (let i = 0; i < 6; i++) {
      generated += chars[(Math.floor(Math.random() * chars.length) + i * 7) % chars.length];
    }
    this.roomCode = generated;
    this.localPlayerId = 1;
    this.isSpectator = false;
    this.reconnectAttempts = 0;
    this.setState("connecting", `Creando sala ${generated} en ${this.relayUrl}...`);
    this.setupSameOriginTabChannel(generated);
    this.connectSocket({ action: "create_room", game_id: gameId, room_code: generated }, true);
    this.setState("connected_host", `Sala ${generated} activa (Jugador 1 · Host)`);
    this.callbacks.onRoomCreated?.(generated, 1);
    return generated;
  }

  public joinRoom(roomCode: string): boolean {
    const clean = roomCode.trim().toUpperCase();
    if (clean.length < 4) return false;
    this.roomCode = clean;
    this.localPlayerId = 2;
    this.isSpectator = false;
    this.reconnectAttempts = 0;
    this.setState("connecting", `Uniéndose a sala ${clean} en ${this.relayUrl}...`);
    this.setupSameOriginTabChannel(clean);
    this.connectSocket({ action: "join_room", room_code: clean }, false);
    this.setState("connected_client", `Conectado a sala ${clean} (Jugador 2 · Cliente)`);
    this.callbacks.onRoomJoined?.(clean, 2);
    this.broadcastChannel?.postMessage({ type: "PEER_JOINED", playerId: 2 });
    return true;
  }

  public joinAsSpectator(roomCode: string): boolean {
    const clean = roomCode.trim().toUpperCase();
    if (clean.length < 4) return false;
    this.roomCode = clean;
    this.localPlayerId = 2;
    this.isSpectator = true;
    this.reconnectAttempts = 0;
    this.setState("connecting", `Uniéndose como Espectador a sala ${clean}...`);
    this.setupSameOriginTabChannel(clean);
    this.connectSocket({ action: "spectate_room", room_code: clean, spectator: true }, false);
    this.setState("connected_spectator", `Modo Espectador activo en sala ${clean} (Solo lectura)`);
    this.callbacks.onSpectatorJoined?.(clean);
    this.broadcastChannel?.postMessage({ type: "PEER_JOINED", playerId: 0 });
    return true;
  }

  public isQueuingMatchmaking(): boolean {
    return this.activeQueueTicket !== null;
  }

  public getActiveQueueTicket(): MatchmakingQueueTicket | null {
    return this.activeQueueTicket;
  }

  public queueMatchmaking(
    gameId: string,
    elo: number,
    maxEloDelta: number = 300,
    playerName: string = "Jugador"
  ): MatchmakingQueueTicket {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let generatedCode = "";
    for (let i = 0; i < 4; i++) {
      generatedCode += chars[(Math.floor(Math.random() * chars.length) + i * 5) % chars.length];
    }

    const ticket: MatchmakingQueueTicket = {
      ticketId: `mm_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      gameId: gameId.trim().toLowerCase(),
      playerName: playerName.trim() || "Jugador",
      elo: Math.round(elo),
      maxEloDelta: Math.max(50, Math.round(maxEloDelta)),
      roomCode: generatedCode,
      queuedAtMs: Date.now(),
    };

    this.activeQueueTicket = ticket;
    this.roomCode = generatedCode;
    this.localPlayerId = 1;
    this.isSpectator = false;
    this.setState(
      "connecting",
      `Buscando rival en cola ELO (${ticket.elo} ±${ticket.maxEloDelta}) para ${ticket.gameId.toUpperCase()}...`
    );

    try {
      if (typeof BroadcastChannel !== "undefined") {
        this.matchmakingChannel?.close();
        this.matchmakingChannel = new BroadcastChannel("opentable_global_matchmaking_v1");
        this.matchmakingChannel.onmessage = (ev) => {
          const msg = ev.data;
          if (!msg || typeof msg !== "object" || !this.activeQueueTicket) return;
          const myTicket = this.activeQueueTicket;
          if (msg.type === "MM_SEEK" && msg.ticket && msg.ticket.ticketId !== myTicket.ticketId) {
            const other = msg.ticket as MatchmakingQueueTicket;
            if (areMatchmakingTicketsCompatible(myTicket, other)) {
              if (myTicket.queuedAtMs <= other.queuedAtMs) {
                this.matchmakingChannel?.postMessage({
                  type: "MM_MATCHED",
                  hostTicket: myTicket,
                  guestTicketId: other.ticketId,
                  guestElo: other.elo,
                  guestName: other.playerName,
                });
                this.completeMatchmakingAsHost(myTicket.roomCode, other.elo, other.playerName);
              }
            }
          } else if (
            msg.type === "MM_MATCHED" &&
            msg.guestTicketId === myTicket.ticketId &&
            msg.hostTicket
          ) {
            const hostTicket = msg.hostTicket as MatchmakingQueueTicket;
            this.completeMatchmakingAsClient(
              hostTicket.roomCode,
              hostTicket.elo,
              hostTicket.playerName
            );
          }
        };
        this.matchmakingChannel.postMessage({ type: "MM_SEEK", ticket });
      }
    } catch {
      // BroadcastChannel optional
    }

    this.setupSameOriginTabChannel(generatedCode);
    this.connectSocket(
      {
        op: "queue",
        action: "queue",
        game_id: ticket.gameId,
        elo: ticket.elo,
        max_elo_delta: ticket.maxEloDelta,
      },
      true
    );

    return ticket;
  }

  public expandMatchmakingTolerance(newMaxEloDelta: number): void {
    if (!this.activeQueueTicket) return;
    this.activeQueueTicket = {
      ...this.activeQueueTicket,
      maxEloDelta: Math.max(50, Math.round(newMaxEloDelta)),
    };
    try {
      this.matchmakingChannel?.postMessage({
        type: "MM_SEEK",
        ticket: this.activeQueueTicket,
      });
    } catch {
      // Ignore
    }
  }

  public cancelMatchmaking(): void {
    this.activeQueueTicket = null;
    try {
      this.matchmakingChannel?.close();
    } catch {
      // Ignore
    }
    this.matchmakingChannel = null;
    if (this.state === "connecting") {
      this.disconnect();
    }
  }

  private completeMatchmakingAsHost(
    roomCode: string,
    opponentElo: number,
    opponentName: string
  ): void {
    const myTicket = this.activeQueueTicket;
    this.activeQueueTicket = null;
    this.roomCode = roomCode;
    this.localPlayerId = 1;
    this.isSpectator = false;
    this.setupSameOriginTabChannel(roomCode);
    this.setState(
      "connected_host",
      `Emparejado por ELO en sala ${roomCode} contra ${opponentName} (${opponentElo} ELO)`
    );
    this.callbacks.onRoomCreated?.(roomCode, 1);
    this.callbacks.onPeerJoined?.(2);
    this.callbacks.onEloSyncReceived?.(2, opponentElo, opponentName);
    this.callbacks.onMatchmakingFound?.(roomCode, 1, opponentElo, opponentName);
    if (myTicket) {
      this.sendEloSync(1, myTicket.elo, myTicket.playerName);
    }
  }

  private completeMatchmakingAsClient(
    roomCode: string,
    opponentElo: number,
    opponentName: string
  ): void {
    const myTicket = this.activeQueueTicket;
    this.activeQueueTicket = null;
    this.roomCode = roomCode;
    this.localPlayerId = 2;
    this.isSpectator = false;
    this.setupSameOriginTabChannel(roomCode);
    this.setState(
      "connected_client",
      `Emparejado por ELO en sala ${roomCode} contra ${opponentName} (${opponentElo} ELO)`
    );
    this.callbacks.onRoomJoined?.(roomCode, 2);
    this.callbacks.onEloSyncReceived?.(1, opponentElo, opponentName);
    this.callbacks.onMatchmakingFound?.(roomCode, 2, opponentElo, opponentName);
    this.broadcastChannel?.postMessage({ type: "PEER_JOINED", playerId: 2 });
    if (myTicket) {
      this.sendEloSync(2, myTicket.elo, myTicket.playerName);
    }
  }

  private connectSocket(handshakePayload: Record<string, unknown>, isHost: boolean): void {
    try {
      if (typeof WebSocket === "undefined") return;
      this.ws?.close();
      const ws = new WebSocket(this.relayUrl);
      this.ws = ws;

      ws.onopen = () => {
        this.reconnectAttempts = 0;
        ws.send(JSON.stringify(handshakePayload));
        this.setState(
          isHost ? "connected_host" : "connected_client",
          `Conectado a ${this.relayUrl} (${this.roomCode})`
        );
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(String(event.data));
          if (msg.type === "SyncState" || msg.SyncState) {
            const payload = msg.SyncState || msg;
            this.callbacks.onSyncStateReceived?.(
              payload.game_type || "",
              payload.log_json || JSON.stringify(payload.log_bytes || [])
            );
          } else if (msg.type === "command" && msg.command_json) {
            this.callbacks.onCommandReceived?.(Number(msg.player_id || 2), msg.command_json);
          } else if (msg.op === "created" && msg.room_code) {
            this.roomCode = String(msg.room_code);
            this.localPlayerId = 1;
            this.setupSameOriginTabChannel(this.roomCode);
            this.setState(
              "connected_host",
              `En espera de rival ELO en sala ${this.roomCode}...`
            );
            this.callbacks.onRoomCreated?.(this.roomCode, 1);
          } else if (msg.op === "joined" && msg.player_id) {
            const assignedPid: 1 | 2 = Number(msg.player_id) === 1 ? 1 : 2;
            const myTicket = this.activeQueueTicket;
            this.activeQueueTicket = null;
            this.localPlayerId = assignedPid;
            this.setState(
              "connected_client",
              `Partida ELO encontrada en servidor Relay (${this.roomCode})`
            );
            this.callbacks.onRoomJoined?.(this.roomCode, assignedPid);
            this.callbacks.onMatchmakingFound?.(
              this.roomCode,
              assignedPid,
              myTicket?.elo ?? 1200,
              "Rival Relay ELO"
            );
          } else if (msg.type === "peer_joined" || msg.op === "peer_joined") {
            const peerPid = Number(msg.player_id || 2);
            if (this.activeQueueTicket) {
              const myTicket = this.activeQueueTicket;
              this.activeQueueTicket = null;
              this.callbacks.onMatchmakingFound?.(
                this.roomCode,
                1,
                myTicket.elo,
                "Rival Relay ELO"
              );
            }
            this.callbacks.onPeerJoined?.(peerPid);
          } else if (msg.type === "chat" && msg.text) {
            this.callbacks.onChatMessageReceived?.({
              id: String(msg.id || `${Date.now()}`),
              roomCode: String(msg.room_code || this.roomCode),
              senderName: String(msg.sender || `Jugador ${msg.player_id || 2}`),
              playerId: Number(msg.player_id || 2),
              text: String(msg.text),
              timestamp: String(msg.timestamp || new Date().toLocaleTimeString()),
            });
          } else if (msg.type === "elo_sync") {
            this.callbacks.onEloSyncReceived?.(
              Number(msg.player_id || 2),
              Number(msg.rating || 1200),
              String(msg.player_name || "Jugador")
            );
          }
        } catch {
          // Ignore malformed relay frames
        }
      };

      ws.onclose = () => {
        if (this.state !== "disconnected" && this.roomCode) {
          this.scheduleReconnect(isHost);
        }
      };
    } catch {
      // In offline or sandbox preview, BroadcastChannel + local session keeps room operable
    }
  }

  private scheduleReconnect(isHost: boolean): void {
    if (this.reconnectAttempts >= 5) return;
    this.reconnectAttempts += 1;
    const delayMs = Math.min(8000, 1000 * Math.pow(2, this.reconnectAttempts - 1));
    this.setState(
      "reconnecting",
      `Microcorte detectado. Reconectando a ${this.relayUrl} (intento ${this.reconnectAttempts}/5)...`
    );
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = setTimeout(() => {
      this.connectSocket(
        {
          action: "rejoin_room",
          room_code: this.roomCode,
          player_id: this.localPlayerId,
        },
        isHost
      );
    }, delayMs);
  }

  public simulateMicroDisconnectAndReconnect(): void {
    if (!this.roomCode) return;
    const wasHost = this.localPlayerId === 1;
    this.reconnectAttempts += 1;
    this.setState(
      "reconnecting",
      `Reconectando automáticamente a ${this.relayUrl} (intento ${this.reconnectAttempts})...`
    );
    setTimeout(() => {
      this.setState(
        wasHost ? "connected_host" : "connected_client",
        `Conexión restaurada en sala ${this.roomCode} (Jugador ${this.localPlayerId})`
      );
    }, 350);
  }

  public sendCommand(playerId: number, commandJson: string): void {
    this.broadcastChannel?.postMessage({
      type: "COMMAND",
      sender: playerId,
      commandJson,
    });
    if (this.ws && this.ws.readyState === 1) {
      this.ws.send(
        JSON.stringify({
          type: "command",
          room_code: this.roomCode,
          player_id: playerId,
          command_json: commandJson,
        })
      );
    }
  }

  public sendSyncState(gameType: string, logJson: string): void {
    this.broadcastChannel?.postMessage({
      type: "SYNC_STATE",
      gameType,
      logJson,
    });
    if (this.ws && this.ws.readyState === 1) {
      this.ws.send(
        JSON.stringify({
          type: "SyncState",
          room_code: this.roomCode,
          game_type: gameType,
          log_json: logJson,
        })
      );
    }
  }

  public sendChatMessage(senderName: string, text: string, playerId: number = this.localPlayerId): RelayChatMessage | null {
    const cleanText = text.trim();
    if (!cleanText) return null;
    const chatMsg: RelayChatMessage = {
      id: `chat_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      roomCode: this.roomCode || "LOCAL",
      senderName: senderName.trim() || `Jugador ${playerId}`,
      playerId,
      text: cleanText,
      timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
    };
    this.broadcastChannel?.postMessage({
      type: "CHAT",
      message: chatMsg,
    });
    if (this.ws && this.ws.readyState === 1) {
      this.ws.send(
        JSON.stringify({
          type: "chat",
          id: chatMsg.id,
          room_code: chatMsg.roomCode,
          sender: chatMsg.senderName,
          player_id: chatMsg.playerId,
          text: chatMsg.text,
          timestamp: chatMsg.timestamp,
        })
      );
    }
    return chatMsg;
  }

  public sendEloSync(playerId: number, rating: number, playerName: string): void {
    this.broadcastChannel?.postMessage({
      type: "ELO_SYNC",
      playerId,
      rating,
      playerName,
    });
    if (this.ws && this.ws.readyState === 1) {
      this.ws.send(
        JSON.stringify({
          type: "elo_sync",
          room_code: this.roomCode,
          player_id: playerId,
          rating,
          player_name: playerName,
        })
      );
    }
  }

  public disconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.activeQueueTicket = null;
    this.roomCode = "";
    this.ws?.close();
    this.ws = null;
    this.broadcastChannel?.close();
    this.broadcastChannel = null;
    this.matchmakingChannel?.close();
    this.matchmakingChannel = null;
    this.setState("disconnected", "Sin conexión de red activa");
  }
}
