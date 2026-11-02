# Guía del Desarrollador — Cómo Expandir OpenTable SDK (`DEVELOPER_GUIDE.md`)

Esta guía explica de forma concisa y con **ejemplos completos de código** cómo cualquier desarrollador puede:
1. **Crear un juego nuevo desde cero** (Motor Rust ECS + IA + Puente `OpenTableBridge` + Tablero Godot/Redot + Tests).
2. **Añadir una regla o variante configurable** a un juego existente sin romper replays ni compatibilidad.
3. **Implementar un nuevo transporte de red** sobre `RawByteLink` (Bluetooth, WebRTC, Steam Sockets).
4. **Empaquetar y auditar la suite** bajo licencia **`GPL-3.0-or-later`**.

---

## 1. Ejemplo Completo: Añadir un Juego Nuevo (Juego #14: *Nim Táctico*)

En **OpenTable SDK**, cada juego vive en su propio crate de Rust (`<juego>_game`) y se expone a Godot mediante `open_table_godot`.

### Paso 1.1: Estructura del Crate en Rust (`nim_game/src/lib.rs`)

Crea el directorio `nim_game/` y añádelo a `members` en el `Cargo.toml` raíz. Todo juego define cuatro piezas:
1. **`Resource` (Estado en `bevy_ecs::World`)**
2. **`Command` (`#[game_command]`)**
3. **`Event` (`#[game_event]`)**
4. **Validador en `RuleEngine` + `LegalMoveGenerator`**

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use bevy_ecs::prelude::*;
use open_table_core::{
    Command, EngineError, EngineResult, Event, EventVisibility, PlayerId, Resource as GameRes,
};
use open_table_engine::{LegalMoveGenerator, RuleEngine, TurnOrder};
use open_table_macros::{game_command, game_event, GameResource};
use serde::{Deserialize, Serialize};

/// 1. Estado del tablero almacenado como Resource en el World ECS
#[derive(Resource, GameResource, Debug, Clone, Serialize, Deserialize)]
pub struct NimBoard {
    pub heaps: [u8; 3],
    pub winner: Option<PlayerId>,
}

impl Default for NimBoard {
    fn default() -> Self {
        Self {
            heaps: [3, 5, 7],
            winner: None,
        }
    }
}

/// 2. Comando enviado por un jugador (serializable automáticamente con typetag)
#[game_command]
pub struct TakeTokensCommand {
    pub heap_index: usize,
    pub count: u8,
}

/// 3. Evento resultante emitido por el motor hacia todos los clientes
#[game_event]
pub struct TokensTakenEvent {
    pub player: PlayerId,
    pub heap_index: usize,
    pub count: u8,
    pub remaining_heaps: [u8; 3],
    pub winner: Option<PlayerId>,
}

/// 4. Generador de jugadas legales (usado por la UI y la IA)
pub struct NimLegalMoveGenerator;

impl LegalMoveGenerator for NimLegalMoveGenerator {
    fn get_legal_moves(&self, world: &World, player: PlayerId) -> Vec<Box<dyn Command>> {
        let Some(turn) = world.get_resource::<TurnOrder>() else {
            return vec![];
        };
        if turn.current() != Some(player) {
            return vec![];
        }
        let Some(board) = world.get_resource::<NimBoard>() else {
            return vec![];
        };
        if board.winner.is_some() {
            return vec![];
        }

        let mut moves: Vec<Box<dyn Command>> = Vec::new();
        for (idx, &tokens) in board.heaps.iter().enumerate() {
            for take in 1..=tokens {
                moves.push(Box::new(TakeTokensCommand {
                    heap_index: idx,
                    count: take,
                }));
            }
        }
        moves
    }
}

/// 5. Registro de reglas en la sesión
pub fn register_nim_rules(world: &mut World, engine: &mut RuleEngine) {
    world.insert_resource(NimBoard::default());
    engine.set_legal_move_generator(NimLegalMoveGenerator);

    engine.add_rule(|world, player, command| {
        let Some(cmd) = command.as_any().downcast_ref::<TakeTokensCommand>() else {
            return Ok(None);
        };

        let mut board = world
            .get_resource_mut::<NimBoard>()
            .ok_or_else(|| EngineError::InvalidCommand("Tablero Nim no inicializado".into()))?;

        if board.winner.is_some() {
            return Err(EngineError::InvalidCommand("La partida ya ha finalizado".into()));
        }
        if cmd.heap_index >= 3 {
            return Err(EngineError::InvalidCommand("Índice de montón inválido (0..2)".into()));
        }
        if cmd.count == 0 || cmd.count > board.heaps[cmd.heap_index] {
            return Err(EngineError::InvalidCommand(
                "Cantidad de fichas inválida para este montón".into(),
            ));
        }

        board.heaps[cmd.heap_index] -= cmd.count;
        let all_empty = board.heaps.iter().all(|&h| h == 0);
        if all_empty {
            board.winner = Some(player);
        }

        let evt = TokensTakenEvent {
            player,
            heap_index: cmd.heap_index,
            count: cmd.count,
            remaining_heaps: board.heaps,
            winner: board.winner,
        };

        Ok(Some(vec![(Box::new(evt) as Box<dyn Event>, EventVisibility::Public)]))
    });
}
```

---

### Paso 1.2: Añadir Oponente de IA Determinista (`nim_game/src/ai.rs`)

Cada juego provee una función pura que inspecciona el estado (`&NimBoard`) y devuelve el mejor comando (`Option<TakeTokensCommand>`). En Nim, la estrategia óptima utiliza la suma XOR (*Nim-sum*):

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use crate::{NimBoard, TakeTokensCommand};

pub fn choose_best_nim_move(board: &NimBoard) -> Option<TakeTokensCommand> {
    let nim_sum = board.heaps[0] ^ board.heaps[1] ^ board.heaps[2];
    if nim_sum != 0 {
        for (idx, &h) in board.heaps.iter().enumerate() {
            let target = h ^ nim_sum;
            if target < h {
                return Some(TakeTokensCommand {
                    heap_index: idx,
                    count: h - target,
                });
            }
        }
    }
    // Si la posición es perdedora (nim_sum == 0), tomar 1 ficha del primer montón no vacío
    for (idx, &h) in board.heaps.iter().enumerate() {
        if h > 0 {
            return Some(TakeTokensCommand {
                heap_index: idx,
                count: 1,
            });
        }
    }
    None
}
```

---

### Paso 1.3: Exponer el Juego en `OpenTableBridge` (`open_table_godot/src/lib.rs`)

En `open_table_godot/src/lib.rs`, añade el método `#[func]` para inicializar la sesión y despachar eventos JSON hacia GDScript:

```rust
#[func]
pub fn start_local_match_nim(&mut self, p1: i64, p2: i64) {
    let players = vec![PlayerId(p1 as u64), PlayerId(p2 as u64)];
    let mut session = Session::new(players);
    nim_game::register_nim_rules(session.world_mut(), session.rule_engine_mut());
    self.mode = BridgeMode::Local(session);
}
```

---

### Paso 1.4: Crear el Tablero Visual en Godot / Redot (`godot_project/nim_board.gd`)

Para que el tablero se integre con el resto de la suite (reloj de turno compacto, menú desplegable superior derecho `GameAppMenu`, catálogo de reglas y soporte Redot strict):
- **Regla Redot Strict**: Nunca uses inferencia `:=` cuando el lado derecho devuelva `Variant` (ej. `JSON.parse_string()`, `.get()`, `.call()`, `arr[i]`). Declara el tipo explícito (`var data: Dictionary = ...`).
- **Sincronización**: Mantén copia idéntica en `godot_project/<juego>_board.gd` y `godot_project/scenes/<juego>_board.gd`.

```gdscript
extends Node2D

var bridge: OpenTableBridge
var turn_indicator: TurnIndicator
var status: Label
var current: int = 1
var winner: int = -1
var heaps: Array[int] = [3, 5, 7]

func _ready() -> void:
	status = Label.new()
	status.name = "Status"
	status.position = Vector2(280, -48)
	add_child(status)

	# Indicador de turno compacto + cronómetro MM:SS + GameAppMenu automático
	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.position = Vector2(12, -52)
	add_child(turn_indicator)

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	bridge.connect("event_json", _on_event_json)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("game_over", _on_game_over)

	_update_status()
	queue_redraw()

func take_from_heap(heap_idx: int, count: int) -> void:
	var payload: Dictionary = {
		"type": "TakeTokensCommand",
		"heap_index": heap_idx,
		"count": count
	}
	bridge.send_command_json(current, JSON.stringify(payload))

func _on_event_json(raw_json: String) -> void:
	var parsed: Variant = JSON.parse_string(raw_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ev: Dictionary = parsed as Dictionary
	if String(ev.get("type", "")) == "TokensTakenEvent":
		var rem: Array = ev.get("remaining_heaps", [3, 5, 7])
		for i in range(mini(3, rem.size())):
			heaps[i] = int(rem[i])
		current = 2 if current == 1 else 1
		_update_status()
		queue_redraw()

func _on_move_rejected(reason: String) -> void:
	if status != null:
		status.text = "Movimiento inválido: %s" % reason

func _on_game_over(win_id: int) -> void:
	winner = win_id
	_update_status()

func _update_status() -> void:
	if winner != -1:
		if status != null:
			status.text = "¡Ganó el Jugador %d!" % winner
		if turn_indicator != null:
			turn_indicator.stop_timer()
			turn_indicator.set_active(false)
	else:
		if status != null:
			status.text = ""
		if turn_indicator != null:
			var col: Color = Color.RED if current == 1 else Color.DODGER_BLUE
			turn_indicator.set_turn(current, "Jugador %d" % current, col)
			turn_indicator.set_active(true)
```

---

## 2. Ejemplo 2: Extender un Juego Existente con una Regla o Variante Opcional

Cuando quieras añadir una variante configurable (por ejemplo, `extra_turn_on_hit` en Batalla Naval o `SetKomiCommand` en Go) **sin romper las partidas estándar ni los tests existentes**:

1. **Añade el campo con valor por defecto canónico** en el `Resource` de configuración usando `#[serde(default)]`:
   ```rust
   #[derive(Resource, GameResource, Debug, Clone, Serialize, Deserialize)]
   pub struct BattleshipConfigResource {
       #[serde(default)]
       pub extra_turn_on_hit: bool, // false por defecto: preserva comportamiento clásico
   }
   ```
2. **Crea un comando específico de configuración** (`#[game_command]`) que solo sea válido antes del primer movimiento de la partida:
   ```rust
   #[game_command]
   pub struct SetBattleshipRulesCommand {
       pub extra_turn_on_hit: bool,
   }
   ```
3. **Agrega el caso de prueba en `tests/canonical_rules.rs`** verificando tanto el camino feliz como el rechazo (`Err(EngineError::InvalidCommand)`) si se intenta cambiar la regla a mitad de la partida.

---

## 3. Ejemplo 3: Crear un Nuevo Transporte de Red con `RawByteLink`

Si deseas transportar partidas sobre **WebRTC**, **Bluetooth Low Energy** o **Steam Networking Sockets**, no necesitas reescribir la lógica de sesiones, turnos ni reconexión. Basta con implementar las 4 funciones del trait `RawByteLink` de `open_table_transport_native_bridge`:

```rust
// SPDX-License-Identifier: GPL-3.0-or-later
use open_table_core::EngineResult;
use open_table_transport_native_bridge::{
    NativeClientTransport, NativeHostTransport, RawByteLink, RawLinkEvent,
};
use std::collections::VecDeque;

pub struct CustomWebRtcLink {
    inbox: VecDeque<(String, Vec<u8>)>,
    events: VecDeque<RawLinkEvent>,
}

impl RawByteLink for CustomWebRtcLink {
    fn send_raw(&mut self, peer_tag: &str, bytes: &[u8]) -> EngineResult<()> {
        // Enviar bytes por tu DataChannel de WebRTC o Steam Socket al peer_tag
        let _ = (peer_tag, bytes);
        Ok(())
    }

    fn broadcast_raw(&mut self, bytes: &[u8]) -> EngineResult<()> {
        // Difundir bytes a todos los peers conectados
        let _ = bytes;
        Ok(())
    }

    fn poll_raw_received(&mut self) -> Vec<(String, Vec<u8>)> {
        self.inbox.drain(..).collect()
    }

    fn poll_link_events(&mut self) -> Vec<RawLinkEvent> {
        self.events.drain(..).collect()
    }
}

// Al envolverlo en NativeHostTransport, obtienes gratis:
// - Handshake Join / Reconnect con tokens CSPRNG
// - Resincronización automática del historial de eventos al reconectar
pub fn create_webrtc_host(link: CustomWebRtcLink) -> NativeHostTransport<CustomWebRtcLink> {
    NativeHostTransport::new(link)
}
```

---

## 4. Verificación de Calidad, Paridad y Licenciamiento GPL-3.0

Antes de enviar un Pull Request o publicar una versión:

```bash
# 1. Ejecutar todos los tests unitarios y canónicos de los 22 crates de Rust
cargo test --workspace

# 2. Verificar 0 warnings de Clippy y compilación de documentación
cargo clippy --workspace --exclude open_table_godot -- -D warnings
cargo doc --workspace --exclude open_table_godot --no-deps

# 3. Ejecutar el validador estático Redot strict (paridad 13/13 tableros + 0 := en Variant)
#    y toda la batería de smoke tests de Godot/Redot
./tools/run_godot_tests.sh
```

### Checklist de Cumplimiento `GPL-3.0-or-later` para Distribución
- [x] Archivo [`LICENSE`](./LICENSE) en la raíz con el texto oficial de **GNU GPL v3.0** y la excepción de enlace para el runtime de Godot/Redot y plugins de plataforma.
- [x] Los 22 `Cargo.toml` del workspace declaran `license = "GPL-3.0-or-later"`.
- [x] `deny.toml` autoriza `GPL-3.0-or-later` junto con las licencias permisivas de las dependencias (`MIT`, `Apache-2.0`, `BSD-3-Clause`, `MPL-2.0`, `ISC`, `Unicode-3.0`, `Zlib`).
- [x] La pantalla in-game `credits_screen.gd` muestra tanto la licencia `GPL-3.0-or-later` del proyecto como los avisos de atribución de terceros.
