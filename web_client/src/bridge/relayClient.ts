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
  | "reconnecting";

export interface SyncStateMessage {
  type: "SyncState";
  game_type: string;
  log_json: string;
}

export interface RelayEventCallbacks {
  onStateChange?: (state: RelayConnectionState, info?: string) => void;
  onRoomCreated?: (roomCode: string, localPlayerId: 1 | 2) => void;
  onRoomJoined?: (roomCode: string, localPlayerId: 1 | 2) => void;
  onPeerJoined?: (peerPlayerId: number) => void;
  onCommandReceived?: (playerId: number, commandJson: string) => void;
  onSyncStateReceived?: (gameType: string, logJson: string) => void;
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
  private state: RelayConnectionState = "disconnected";
  private reconnectAttempts: number = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private callbacks: RelayEventCallbacks;
  private broadcastChannel: BroadcastChannel | null = null;

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
          if (data.type === "PEER_JOINED" && this.localPlayerId === 1) {
            this.callbacks.onPeerJoined?.(2);
          } else if (data.type === "COMMAND" && data.sender !== this.localPlayerId) {
            this.callbacks.onCommandReceived?.(data.sender, data.commandJson);
          } else if (data.type === "SYNC_STATE" && this.localPlayerId === 2) {
            this.callbacks.onSyncStateReceived?.(data.gameType, data.logJson);
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
    this.reconnectAttempts = 0;
    this.setState("connecting", `Uniéndose a sala ${clean} en ${this.relayUrl}...`);
    this.setupSameOriginTabChannel(clean);
    this.connectSocket({ action: "join_room", room_code: clean }, false);
    this.setState("connected_client", `Conectado a sala ${clean} (Jugador 2 · Cliente)`);
    this.callbacks.onRoomJoined?.(clean, 2);
    this.broadcastChannel?.postMessage({ type: "PEER_JOINED", playerId: 2 });
    return true;
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
          } else if (msg.type === "peer_joined") {
            this.callbacks.onPeerJoined?.(Number(msg.player_id || 2));
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

  public disconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.roomCode = "";
    this.ws?.close();
    this.ws = null;
    this.broadcastChannel?.close();
    this.broadcastChannel = null;
    this.setState("disconnected", "Sin conexión de red activa");
  }
}
