# Manual de Uso — OpenTable Web & PWA (14 Juegos de Mesa Canónicos)

Bienvenido al manual oficial de uso de **OpenTable Web**, la aplicación progresiva (PWA) construida con **React 19, TypeScript, Tailwind CSS y WebAssembly (`open_table_wasm`)** que ejecuta los **14 motores de juegos de mesa canónicos** de OpenTable SDK directamente en el navegador.

---

## 1. Cómo Garantizar que la Aplicación Está 100% Funcional

Puedes comprobar la salud operativa de toda la aplicación en cualquier momento por dos vías:

### A. Desde la Interfaz Gráfica (En Vivo en el Navegador)
1. En la barra de herramientas superior (debajo de la cabecera principal), haz clic en el botón **`Diagnóstico E2E`**.
2. Pulsa **`Ejecutar Diagnóstico Completo (14 Juegos)`**.
3. El sistema instanciará en segundo plano los **14 motores de juego**, verificará:
   - Inicialización del tablero y turno inicial (`Jugador 1`).
   - Cálculo de jugadas legales (`get_legal_moves_json`).
   - Ejecución de un comando válido del Jugador 1 y respuesta automática de la IA (`step_ai_if_needed`).
   - Evaluación posicional normalizada ($[-100, +100]$) para el Analizador Post-Partida.
   - Exportación e importación determinista del registro de repetición (`export_log_json` / `apply_sync_log_json`).
   - Subsistemas del navegador: **ELO FIDE K=32**, **Torneos Berger/Knockout**, **LocalStorage**, **Web Audio API**, **Service Worker PWA** y **Relay WebSocket**.
4. Puedes descargar el certificado de verificación con el botón **`Exportar Reporte`** (`.json`).

### B. Desde la Terminal (Script de Garantía Funcional CLI)
Ejecuta el script maestro de verificación del cliente Web:

```bash
bash games_tables_sdk/tools/verify_web_client.sh
```

Este comando valida sin intervención manual:
1. Tipado estático de TypeScript (`tsc --noEmit`).
2. Las **6 suites automatizadas en Vitest** (regresión de los 14 juegos, Fases 3, 4 y 5, y autodiagnóstico E2E).
3. El empaquetado de producción de la PWA (`vite build`).
4. La presencia e integridad de la documentación de uso y desarrollo.

---

## 2. Modos de Juego Disponibles

Desde el selector de modo en la barra superior puedes alternar instantáneamente entre **4 modos de juego**:

| Modo | Descripción | Cuándo Usarlo |
| :--- | :--- | :--- |
| **Hotseat Local** | Dos jugadores humanos comparten la pantalla alternando turnos en el mismo dispositivo. | Partidas presenciales en tablet, portátil o escritorio. |
| **vs IA Rust** | Juegas como Jugador 1 contra el motor de IA determinista con **4 niveles de dificultad**: Fácil (`1000 ELO`), Media (`1200 ELO`), Difícil (`1450 ELO`) y Maestra (`1700 ELO`). | Entrenamiento individual o partidas rápidas sin conexión. |
| **Online Relay / QR** | Conecta con el servidor `open_table_relay` (o sincroniza pestañas locales via `BroadcastChannel`) mediante un código de sala de 6 caracteres y código QR SVG instantáneo. | Partidas multijugador en red local o internet (Cross-Play con Godot). |
| **Espectador** | Observa cualquier sala en vivo en modo de solo lectura con actualización automática del tablero y acceso al chat de sala. | Retransmisión de torneos o seguimiento de partidas de amigos. |

---

## 3. Cola de Matchmaking Automático por Rango ELO

En la pestaña **`Salas Online`**:

1. Revisa tu **ELO actual** para el juego seleccionado.
2. Elige la **Tolerancia ELO Inicial**:
   - `±100 ELO (Estricto)`: Busca rivales de nivel muy cercano.
   - `±200 ELO (Estándar)`: Balance óptimo entre velocidad y equilibrio competitivo.
   - `±400 ELO (Amplio)`: Emparejamiento rápido.
3. Pulsa **`Buscar Partida Online`**.
4. Si no aparece un oponente en los primeros 10 segundos, la ventana se expande automáticamente (`±100 → ±200 → ±400`) y se sincroniza con `open_table_relay`.
5. Si deseas jugar sin esperar a otro humano en línea, pulsa **`Jugar vs IA Calibrada Ahora`** para iniciar inmediatamente contra el nivel de IA que mejor se ajusta a tu ELO.

---

## 4. Organizador de Torneos y Ranking ELO FIDE ($K=32$)

### A. Pestaña `Torneos`
- **Formatos Soportados**:
  - **Liga Round-Robin (Tablas de Berger)**: Todos contra todos. Otorga `1.0` punto por victoria, `0.5` por empate y `0.0` por derrota, ordenando la clasificación por puntos, coeficiente **Sonneborn-Berger (SB)** y victorias.
  - **Eliminatoria Directa (Knockout)**: Cuadro eliminatorio con avance automático del ganador a la siguiente ronda hasta coronar al campeón.
- **Participantes Mixtos (2 a 8)**: Combina jugadores humanos y bots de IA de cualquier dificultad.
- **Integración con el Tablero**: Pulsa **`Jugar en Tablero`** en cualquier enfrentamiento pendiente para disputarlo en vivo; al concluir la partida, el ganador se registra automáticamente en el cuadro del torneo.

### B. Pestaña `Ranking ELO`
- Calcula la variación de rating tras cada partida con la fórmula oficial FIDE ($K=32$):
  $$E_A = \frac{1}{1 + 10^{(R_B - R_A)/400}}, \quad \Delta R = \text{round}(32 \times (S - E_A))$$
- Desbloquea automáticamente **7 logros competitivos** (*Primera Victoria*, *Racha Imparable*, *Conquistador Polivalente*, *Maestro Táctico 1300+*, *Gran Maestro 1500+*, *Vencedor de IA Maestra* y *Campeón de Torneo*).
- Permite **Exportar / Importar** tu perfil completo en JSON y **Sincronizar tu ELO** con la sala Relay activa.

---

## 5. Analizador Post-Partida y Visor de Repeticiones

### A. Pestaña `Analizador`
Evalúa todas las jugadas de la partida actual (o de una partida de demostración/JSON importado) para cualquiera de los **14 juegos**:
- **Gráfico SVG de Ventaja Posicional ($[-100, +100]$)**: Muestra la evolución de la ventaja turno a turno (valores positivos favorecen al Jugador 1; negativos al Jugador 2).
- **Clasificación Automática de Jugadas**:
  - `★ Óptima`: Ganancia neta $\ge +5$ puntos de ventaja.
  - `✓ Buena`: Mantiene la ventaja (pérdida $\le 4$ puntos).
  - `? Imprecisión`: Caída moderada de ventaja ($4 < \text{pérdida} < 15$).
  - `?? Error Crítico`: Caída severa de ventaja ($\ge 15$ puntos).
- Haz clic en cualquier punto de la gráfica o fila de la tabla y pulsa **`Cargar Estado de Este Turno en el Tablero Principal`** para explorar variantes desde esa posición.

### B. Barra de Replay en el Tablero Principal
Situada encima del tablero activo, permite desplazarse a cualquier paso (`|<<`, `<`, slider, `>`, `>>|`), exportar el historial completo a `.json` o cargar una partida guardada.

---

## 6. Guía Rápida de Controles de los 14 Juegos

| # | Juego | Controles en el Tablero React | Reglas Especiales Activas |
| :-: | :--- | :--- | :--- |
| 01 | **Ajedrez** (`chess`) | Clic en pieza propia → clic en casilla iluminada. Selector emergente al coronar peón. | Enroque corto/largo, captura al paso (*en passant*), detección de jaque/mate y coronación FIDE. |
| 02 | **Damas** (`checkers`) | Clic en ficha propia → clic en diagonal iluminada. | Captura obligatoria, saltos múltiples y coronación a Dama (*King*). |
| 03 | **UNO** (`uno`) | Clic en carta compatible de tu mano, selector de color en comodines, botón `¡UNO!` y botón `Robar Carta`. | Mazo de 108 cartas, `+2`, `+4`, `Skip`, `Reverse` y penalización por no cantar UNO. |
| 04 | **El Juego de la Oca** (`goose`) | Botón `Lanzar Dado` (con animación de dado y avance automático por la espiral de 63 casillas). | Saltos *De Oca a Oca*, Puentes, Posada, Pozo, Laberinto (retroceso a 30), Calavera (vuelta a 1) y rebote en 63. |
| 05 | **Go** (`go`) | Clic en cualquier intersección libre del goban 9×9 o botón `Pasar Turno`. | Captura de cadenas sin libertades, prohibición de suicidio, regla de Ko y puntuación final con Komi 6.5. |
| 06 | **Shogi** (`shogi`) | Clic en pieza del tablero 9×9 o de tu banco de capturas (*Komadai*) → clic en casilla destino. | Reingreso de piezas capturadas (*Drop*), promoción en las 3 últimas filas, prohibición de *Nifu*. |
| 07 | **Xiangqi** (`xiangqi`) | Clic en pieza propia → clic en intersección destino iluminada en el tablero 9×10. | Río central (elefantes no cruzan, soldados avanzan lateralmente tras cruzar), Palacios 3×3, Cañón con pantalla y General Volador. |
| 08 | **Damas Chinas** (`chinese_checkers`) | Clic en canica propia → clic en casilla hexagonal destino en la estrella de 121 posiciones. | Movimiento adyacente y saltos encadenados sobre canicas propias o rivales hasta completar el triángulo opuesto. |
| 09 | **Backgammon** (`backgammon`) | Botón `Tirar Dados` → lista de movimientos legales de picos, barra o Bear-Off + Cubo de Doblaje. | 24 picos, capturas a la barra (*Blot*), reingreso obligatorio, tiradas dobles (4 movimientos) y *Bear-Off*. |
| 10 | **Ludo** (`ludo`) | Botón `Tirar Dado` → clic en la ficha elegible para salir de base (con un 6) o avanzar en el circuito. | Circuito de 52 casillas + pasillo de meta, 8 casillas seguras estrella, capturas y turno extra al sacar 6. |
| 11 | **Batalla Naval** (`battleship`) | Fase 1: Colocar los 5 buques (o despliegue rápido). Fase 2: Clic en coordenada de la cuadrícula de radar enemigo 10×10. | Flota canónica (Portaaviones 5, Acorazado 4, Crucero 3, Submarino 3, Destructor 2), detección de hundimiento y victoria al hundir los 17 segmentos. |
| 12 | **Mil Millas** (`mille_bornes`) | Clic en `Jugar` o `Descartar` sobre cada carta de tu mano de 6 cartas. | Cartas de distancia (25–200 km, límite de dos cartas de 200 km), ataques, defensas y las 4 cartas de Seguridad (*Safeties*) con *¡Coup Fourré!* (+100 km). |
| 13 | **Monopoly** (`monopoly`) | Botones contextuales: `Lanzar Dados y Avanzar`, `Comprar Propiedad`, `Construir Casa/Hotel` y `Terminar Turno`. | 40 casillas, cobro de $200 al pasar por Salida, alquileres escalados por casas/hotel, Cárcel, Impuestos, Suerte/Arca y bancarrota. |
| 14 | **Crisis / TEG** (`crisis`) | Botones de acción según la fase activa (`Reforzar Territorio`, `Atacar Frontera 3v3`, `Reagrupar` y `Avanzar Fase`). | Mapa de territorios interconectados en 6 continentes, bonificación por ejércitos, combate con dados ordenados y conquista territorial. |

---

## 7. Temas Visuales, Modo Daltónico Okabe-Ito, Audio e Instalación PWA

- **Selector de Tema**: En la barra superior puedes elegir entre **Piedra Oscura**, **Noche Profunda** y **Mesa Jade**.
- **Botón `Okabe-Ito (Daltónico)`**: Activa la paleta científica de alto contraste libre de ambigüedad rojo/verde en todos los tableros, relojes y gráficas del analizador.
- **Botón `Audio Web` + Control de Volumen**: Activa o silencia el sintetizador procedural Web Audio API.
- **Instalación Offline (PWA)**: Haz clic en **`Instalar App`** en la esquina superior derecha para instalar la aplicación en tu sistema operativo y jugar los 14 juegos sin conexión a internet.
