# Guía de Desarrollo Complementario para Web (React + TypeScript + WebAssembly)

Esta guía técnica documenta la arquitectura, los contratos de datos, el flujo de extensión de tableros SVG, el protocolo de red con `open_table_relay` y el pipeline de verificación y despliegue del cliente Web (`games_tables_sdk/web_client`) y su puente WebAssembly (`games_tables_sdk/open_table_wasm`).

---

## 1. Arquitectura General: React 19 + Puente Rust WASM + Motor Isomórfico TS

```
┌────────────────────────────────────────────────────────────────────────────┐
│                   React 19 + Tailwind CSS v4 (src/App.tsx)                 │
├──────────────────────────┬─────────────────────────┬───────────────────────┤
│ 14 Tableros SVG React    │ Ecosistema Competitivo  │ Transporte & Salud    │
│ src/components/boards/*  │ - EloAndAchievements    │ - RelayWebSocketClient│
│ - ChessBoard.tsx         │ - TournamentManager     │ - MatchmakingQueue    │
│ - CheckersBoard.tsx      │ - PostMatchAnalyzer     │ - RelayChatPanel      │
│ - ShogiBoard.tsx ...     │ - TournamentClock       │ - SystemDiagnostics   │
└────────────┬─────────────┴────────────┬────────────┴───────────┬───────────┘
             │                          │                        │
             ▼                          ▼                        ▼
┌────────────────────────────────────────────────────┐ ┌─────────────────────┐
│        WasmGameBridge (src/wasm_pkg/index.ts)      │ │  open_table_relay   │
│ - Contrato JSON unificado para los 14 juegos       │ │  (Servidor Rust WS) │
│ - Delegación a binario open_table_wasm_bg.wasm     │ │ - Salas 6 chars     │
│ - Fallback determinista isomórfico en TypeScript   │ │ - Matchmaking ELO   │
└────────────────────────┬───────────────────────────┘ └─────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────┐
│     open_table_wasm (open_table_wasm/src/lib.rs)   │
│ - #[wasm_bindgen] sobre open_table_engine::Session │
│ - Enlaza los 14 crates Rust (<juego>_game) + QR    │
└────────────────────────────────────────────────────┘
```

### Contrato de Métodos de `WasmGameBridge`

Tanto `open_table_wasm/src/lib.rs` (en Rust compilado a `wasm32-unknown-unknown`) como `web_client/src/wasm_pkg/index.ts` (en TypeScript) exponen exactamente la misma firma pública:

| Método | Firma | Propósito |
| :--- | :--- | :--- |
| `start_local_match` | `(game_type: string, p1: number, p2: number) => boolean` | Inicia una sesión local Hotseat o Relay para cualquiera de los 14 juegos. |
| `start_ai_match` | `(game_type: string, human_id: number, ai_id: number, difficulty: number) => boolean` | Inicia una sesión contra la IA (`difficulty`: `0` Fácil, `1` Media, `2` Difícil, `3` Maestra). En `battleship`, despliega automáticamente la flota de la IA. |
| `current_player` | `() => number` | Devuelve el identificador del jugador con el turno activo (`1` o `2`). |
| `current_tick` | `() => number` | Devuelve el número de tick/turno determinista de la sesión. |
| `get_state_json` | `() => string` | Serializa el estado completo del tablero actual en JSON canónico. |
| `get_legal_moves_json` | `(player_id: number) => string` | Devuelve la lista JSON de movimientos legales disponibles para `player_id`. |
| `send_command_json` | `(player_id: number, json_str: string) => string` | Valida y ejecuta un comando JSON sobre la sesión, registrando un nuevo paso en el historial de Replay. |
| `step_ai_if_needed` | `() => string` | Si es el turno de la IA, calcula y aplica `best_move` (incluyendo fases de dados o robo de cartas). |
| `export_log_json` | `() => string` | Exporta la secuencia completa de comandos y estados para Replay, Analizador o `SyncState`. |
| `apply_sync_log_json` | `(game_type: string, log_json: string) => boolean` | Reconstruye de forma determinista una sesión completa a partir de un log JSON exportado. |
| `generate_join_qr_svg` | `(join_code: string, host_name: string, game_type: string) => string` | Genera un código QR en SVG limpio para compartir salas Relay. |

---

## 2. Guía Paso a Paso: Cómo Crear o Extender Tableros SVG y Motores de Juego

### A. Flujo Unidireccional de Datos en los Tableros React

Todos los tableros en `web_client/src/components/boards/<Game>Board.tsx` son **componentes puros controlados por estado JSON**. Ningún componente de tablero muta reglas localmente; todo cambio pasa por `onDispatchCommand(cmdJson)`:

```tsx
export interface StandardBoardProps {
  stateJson: string;
  legalMovesJson: string;
  isLocalTurnAllowed: boolean;
  localPlayerId: 1 | 2;
  onDispatchCommand: (cmdJson: string) => void;
}
```

1. **Lectura del Estado**: El componente parsea `JSON.parse(stateJson)` y `JSON.parse(legalMovesJson)`.
2. **Resaltado de Jugadas Legales**: Cuando el usuario selecciona una pieza o casilla origen `(r, c)`, el tablero filtra `legalMoves` para iluminar únicamente los destinos válidos `(to_r, to_c)`.
3. **Bloqueo de Turno (`isLocalTurnAllowed`)**:
   - En modo `spectator` o cuando el visor de Replay está en un turno histórico (`!isReplayAtLiveHead`), `isLocalTurnAllowed` es `false` y el tablero bloquea cualquier disparo de comandos.
   - En modo `online_relay`, solo permite actuar cuando `currentTurn === localPlayerId`.
4. **Despacho del Comando**: Al confirmar la acción, el tablero llama a:
   ```ts
   onDispatchCommand(JSON.stringify({
     command_type: "MovePieceCommand",
     from: [fromRow, fromCol],
     to: [toRow, toCol],
   }));
   ```

### B. Checklist para Añadir o Extender un Juego

Si deseas extender un juego existente o incorporar una nueva variante:

1. **Motor Rust (`<juego>_game` y `open_table_wasm/src/lib.rs`)**:
   - Registra el constructor de sesión en `create_session_for_players` y el prefijo de comandos en `parse_command_json` dentro de `open_table_wasm/src/lib.rs`.
   - Añade la rama de IA en `step_ai_if_needed`.
2. **Puente Isomórfico (`web_client/src/wasm_pkg/index.ts`)**:
   - Asegúrate de que `resetGameState`, `get_legal_moves_json`, `send_command_json` y `step_ai_if_needed` manejen el `game_type` con el mismo contrato JSON.
3. **Componente de Tablero (`web_client/src/components/boards/<Juego>Board.tsx`)**:
   - Renderiza el tablero en SVG vectorial responsivo con etiquetas `aria-label` y soporte para el atributo global `[data-okabe-ito="true"]` si utiliza indicadores de color.
4. **Evaluador Posicional (`PostMatchAnalyzerPanel.tsx`)**:
   - Registra la función de evaluación normalizada ($[-100, +100]$) en `evaluateBoardAdvantageForPlayer1(gameType, state)`.
5. **Autodiagnóstico y Tests (`SystemDiagnosticsPanel.tsx` y `src/__tests__/`)**:
   - Añade el juego a la matriz de regresión para que tanto el Panel de Diagnóstico en vivo como Vitest lo verifiquen en cada commit.

---

## 3. Protocolo WebSocket Relay, Matchmaking ELO y Sincronización

El módulo `web_client/src/bridge/relayClient.ts` (`RelayWebSocketClient`) implementa el protocolo completo del servidor Rust `open_table_relay` (`open_table_relay/src/lib.rs` y `open_table_relay/src/room.rs`).

### A. Mensajes Cliente → Servidor (`RelayRequest`)

```json
// 1. Crear sala privada de 6 caracteres (asigna player_id: 1)
{ "action": "create" }

// 2. Unirse como Jugador 2 a una sala existente
{ "action": "join", "code": "AB12CD" }

// 3. Unirse como Espectador en vivo (solo lectura, player_id: 0)
{ "action": "spectate", "code": "AB12CD" }

// 4. Entrar en Cola de Matchmaking Automático con filtro por Rango ELO (Fase 5)
{
  "action": "queue",
  "game_type": "chess",
  "elo": 1248,
  "max_elo_delta": 200
}

// 5. Retransmitir comando, snapshot SyncState, ELO o mensaje de chat a la sala
{
  "action": "relay",
  "payload": "{\"kind\":\"command\",\"playerId\":1,\"cmdJson\":\"{...}\"}"
}
```

### B. Eventos Servidor → Cliente (`RelayResponse`)

- `{"event": "created", "code": "AB12CD", "player_id": 1}`
- `{"event": "joined", "code": "AB12CD", "player_id": 2}`
- `{"event": "spectating", "code": "AB12CD"}`
- `{"event": "queued", "game_type": "chess"}`
- `{"event": "matched", "code": "X9M2K1", "player_id": 2}`
- `{"event": "peer_joined", "player_id": 2}` (Dispara el envío automático de `SyncState` con `export_log_json()` desde el Host).
- `{"event": "relayed", "from": 1, "payload": "..."}`

### C. Sobres Internos en `payload` (`RelayEnvelope`)

Para mantener compatibilidad total con `open_table_relay` sin alterar el framing del servidor, `RelayWebSocketClient` encapsula dentro de `payload` cuatro tipos de sobre JSON:
1. **`kind: "command"`**: `{ kind: "command", playerId, cmdJson }` — aplica el comando en el `WasmGameBridge` remoto.
2. **`kind: "sync_state"`**: `{ kind: "sync_state", gameType, logJson }` — sincroniza a jugadores recién conectados o espectadores tardíos mediante `apply_sync_log_json`.
3. **`kind: "chat"`**: `{ kind: "chat", message: { id, senderName, senderRole, text, timestamp } }` — alimenta el panel `RelayChatPanel`.
4. **`kind: "elo_sync"`**: `{ kind: "elo_sync", playerId, rating, playerName }` — muestra el ELO del rival en la sala y lo usa para el cálculo K=32 al terminar la partida.

---

## 4. Pipeline de Compilación `wasm-bindgen`, Testing Vitest y Despliegue PWA

### A. Compilación del Crate Rust `open_table_wasm`

El script `games_tables_sdk/tools/build_wasm.sh` (ejecutado también en `.github/workflows/ci.yml`, `release.yml` y `docs.yml`) compila los 14 motores de Rust a WebAssembly:

```bash
# 1. Compilar el binario .wasm en modo release
cargo build --manifest-path games_tables_sdk/open_table_wasm/Cargo.toml \
  --target wasm32-unknown-unknown --release

# 2. Generar bindings JS/TS para la web en web_client/public/wasm/
wasm-bindgen --target web \
  --out-dir games_tables_sdk/web_client/public/wasm \
  games_tables_sdk/open_table_wasm/target/wasm32-unknown-unknown/release/open_table_wasm.wasm
```

### B. Suites de Pruebas Automatizadas en Vitest (`web_client/src/__tests__/`)

Ejecuta `npm --prefix games_tables_sdk/web_client test` para correr las **6 suites de verificación**:

1. **`boards_14_games.test.tsx`**: Verifica el renderizado SVG y el despacho de una jugada legal en cada uno de los **14 tableros React**.
2. **`network_turn_lock_and_persistence.test.ts`**: Verifica el bloqueo de turnos en red (`computeIsLocalTurnAllowed`), modo espectador y reconexión.
3. **`phase3_features.test.ts`**: Verifica relojes de torneo FIDE/Byo-yomi, visor de repeticiones paso a paso y tutoriales interactivos.
4. **`phase4_ecosystem.test.ts`**: Verifica el motor ELO FIDE ($K=32$), los 7 logros, los torneos Round-Robin Berger y Eliminatoria Directa, temas Okabe-Ito y chat Relay.
5. **`phase5_matchmaking_and_analyzer.test.ts`**: Verifica la cola de Matchmaking por rango ELO y el Analizador Post-Partida ($[-100, +100]$) en los 14 juegos.
6. **`self_diagnostics_and_docs.test.ts`**: Verifica el motor de autodiagnóstico en vivo (`runFullSystemDiagnostics`) sobre los 14 juegos y la integridad del centro de documentación.

### C. Empaquetado PWA Offline y Despliegue en GitHub Pages

- **Service Worker y Manifiesto**:
  - `web_client/public/manifest.webmanifest` define iconos, colores y modo `standalone`.
  - `web_client/public/sw.js` implementa caché *Stale-While-Revalidate* para precachear el shell HTML/JS/CSS y el binario `.wasm`, permitiendo jugar los 14 juegos 100% offline.
- **Despliegue Continuo (`.github/workflows/docs.yml`)**:
  - En cada push a `main`, GitHub Actions compila `open_table_wasm`, construye `web_client/dist`, compila el libro `mdBook` (`docs/book`) junto con `cargo doc`, y publica la PWA en la raíz (`/`) de `gh-pages` y la documentación técnica en `/docs`.
