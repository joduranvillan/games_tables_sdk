# OpenTable Web Client (React 19 + TypeScript + Tailwind CSS + WebAssembly)

Cliente Web y Progressive Web App (PWA) oficial de **OpenTable SDK** para jugar, analizar y organizar torneos en los **14 juegos de mesa canónicos** compilados desde Rust a WebAssembly (`open_table_wasm`).

---

## 1. Garantía Funcional y Verificación Rápida

Para certificar que los **14 motores de juego**, los tableros SVG, la IA, el sistema ELO, los torneos, el analizador post-partida y el cliente Relay funcionan al 100%:

### Opción A — Desde la Terminal (Script Maestro E2E)

```bash
# Desde la raíz de games_tables_sdk/
bash tools/verify_web_client.sh
```

Este comando ejecuta:
1. Validación de tipos TypeScript (`tsc --noEmit`).
2. Las **6 suites de pruebas en Vitest** (`npm test`), incluyendo el autodiagnóstico de los 14 juegos.
3. El empaquetado de producción de la PWA (`npm run build`).
4. La verificación de la documentación de usuario y desarrollo (`docs/WEB_USER_GUIDE.md` y `docs/WEB_REACT_DEVELOPER_GUIDE.md`).

### Opción B — En Vivo desde la Interfaz Web

1. Inicia la aplicación (`npm run dev`).
2. Haz clic en el botón **`Diagnóstico E2E`** en la barra superior de herramientas.
3. Pulsa **`Ejecutar Diagnóstico Completo (14 Juegos)`** para auditar en tiempo real los 14 motores y exportar el reporte JSON.

---

## 2. Comandos de Desarrollo Local

```bash
# 1. Instalar dependencias
npm install

# 2. (Opcional) Compilar el binario Rust open_table_wasm a WebAssembly
bash ../tools/build_wasm.sh

# 3. Iniciar servidor de desarrollo (Vite en puerto 3000)
npm run dev

# 4. Ejecutar las 6 suites de regresión en Vitest
npm test

# 5. Generar bundle PWA de producción en dist/
npm run build
```

---

## 3. Estructura del Proyecto (`web_client/`)

- `src/App.tsx`: Shell principal con selector de los 14 juegos, selector de modo (`Hotseat Local`, `vs IA Rust`, `Online Relay / QR`, `Espectador`) y pestañas de navegación (`Tablero Activo`, `14 Juegos`, `Torneos`, `Ranking ELO`, `Analizador`, `Salas Online`, `Diagnóstico E2E`).
- `src/wasm_pkg/index.ts`: Puente `WasmGameBridge` que enlaza el binario `open_table_wasm_bg.wasm` y provee el motor isomórfico determinista para los 14 juegos.
- `src/bridge/relayClient.ts`: Cliente `RelayWebSocketClient` compatible con `open_table_relay` (salas de 6 caracteres, modo espectador, cola de Matchmaking por rango ELO, `SyncState` y chat).
- `src/components/boards/*Board.tsx`: Los 14 tableros vectoriales SVG interactivos (`ChessBoard`, `CheckersBoard`, `UnoBoard`, `GooseBoard`, `GoBoard`, `ShogiBoard`, `XiangqiBoard`, `ChineseCheckersBoard`, `BackgammonBoard`, `LudoBoard`, `BattleshipBoard`, `MilleBornesBoard`, `MonopolyBoard`, `CrisisBoard`).
- `src/components/common/`:
  - `TournamentClock.tsx`: Relojes FIDE (Blitz/Rapid con incremento Fischer) y Byo-yomi japonés.
  - `ReplayViewerBar.tsx`: Visor de repeticiones turno a turno e importación/exportación JSON.
  - `InteractiveTutorialPanel.tsx`: Guía de reglas y sugerencia de jugada legal en vivo para los 14 juegos.
  - `EloAndAchievementsPanel.tsx`: Ranking ELO FIDE ($K=32$), historial y 7 logros desbloqueables.
  - `TournamentManagerPanel.tsx`: Organizador de torneos Round-Robin (Tablas de Berger) y Eliminatoria Directa.
  - `MatchmakingQueuePanel.tsx`: Cola de Matchmaking automático por rango ELO ($\pm 100 \to \pm 400$).
  - `PostMatchAnalyzerPanel.tsx`: Analizador post-partida con curva SVG de ventaja ($[-100, +100]$) y clasificación de jugadas.
  - `ThemeAndAudioManager.tsx`: Temas visuales (*Piedra Oscura*, *Noche Profunda*, *Mesa Jade*), paleta daltónica *Okabe-Ito* y sintetizador Web Audio API.
  - `SystemDiagnosticsPanel.tsx`: Motor y panel de autodiagnóstico E2E en tiempo real de los 14 juegos.
  - `DocumentationCenterModal.tsx`: Centro interactivo de documentación de uso y desarrollo con buscador instantáneo.

---

## 4. Documentación Completa

- **Manual de Uso (Jugadores y Organizadores)**: [`../docs/WEB_USER_GUIDE.md`](../docs/WEB_USER_GUIDE.md)
- **Guía de Desarrollo Web (React + TypeScript + WASM)**: [`../docs/WEB_REACT_DEVELOPER_GUIDE.md`](../docs/WEB_REACT_DEVELOPER_GUIDE.md)
