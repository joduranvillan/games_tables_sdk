//! Este test simula lo que pasaría con dos juegos completamente distintos
//! (uno de dados público, uno de cartas con mano oculta) usando el mismo
//! `open_table_core` sin que el core necesite saber que existen.

use open_table_core::prelude::*;
use serde::{Deserialize, Serialize};

// ---- Juego A: dados (información 100% pública) ----

#[derive(Debug, Clone, Serialize, Deserialize)]
struct RollDiceCommand {
    player: PlayerId,
}

#[typetag::serde]
impl Command for RollDiceCommand {
    fn clone_box(&self) -> Box<dyn Command> {
        Box::new(self.clone())
    }

    fn issuer(&self) -> Option<PlayerId> {
        Some(self.player)
    }

    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct DiceRolledEvent {
    player: PlayerId,
    value: u32,
}

#[typetag::serde]
impl Event for DiceRolledEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    // visibility() por defecto: Public. Todos ven el resultado del dado.
}

// ---- Juego B: cartas (información oculta) ----

#[derive(Debug, Clone, Serialize, Deserialize)]
struct DrawCardCommand {
    player: PlayerId,
}

#[typetag::serde]
impl Command for DrawCardCommand {
    fn clone_box(&self) -> Box<dyn Command> {
        Box::new(self.clone())
    }

    fn issuer(&self) -> Option<PlayerId> {
        Some(self.player)
    }

    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct CardDrawnEvent {
    player: PlayerId,
    card_name: String,
}

#[typetag::serde]
impl Event for CardDrawnEvent {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    fn visibility(&self) -> Visibility {
        // Solo el dueño ve qué carta le tocó.
        Visibility::Owner(self.player)
    }
}

#[test]
fn comandos_de_juegos_distintos_viajan_por_el_mismo_canal() {
    let alice = PlayerId(1);

    let envelope = CommandEnvelope {
        tick: Tick(3),
        payload: Box::new(RollDiceCommand { player: alice }),
    };

    // Serializa como lo haría el Transport real antes de mandarlo por red.
    // JSON a propósito (no MessagePack): en un juego de mesa el tráfico es
    // bajo y poder leer los mensajes en un log ayuda mucho a debuggear.
    let bytes = serde_json::to_vec(&envelope).expect("serializa");
    let decoded: CommandEnvelope = serde_json::from_slice(&bytes).expect("deserializa");

    assert_eq!(decoded.payload.issuer(), Some(alice));

    // Ahora un comando de OTRO juego, por el mismo tipo de sobre.
    let envelope_b = CommandEnvelope {
        tick: Tick(4),
        payload: Box::new(DrawCardCommand { player: alice }),
    };
    let bytes_b = serde_json::to_vec(&envelope_b).expect("serializa juego B");
    let decoded_b: CommandEnvelope = serde_json::from_slice(&bytes_b).expect("deserializa juego B");
    assert_eq!(decoded_b.payload.issuer(), Some(alice));
}

#[test]
fn visibilidad_filtra_eventos_de_informacion_oculta() {
    let alice = PlayerId(1);
    let bob = PlayerId(2);

    let public_event: Box<dyn Event> = Box::new(DiceRolledEvent {
        player: alice,
        value: 6,
    });
    assert!(public_event.visibility().includes(alice));
    assert!(public_event.visibility().includes(bob));

    let private_event: Box<dyn Event> = Box::new(CardDrawnEvent {
        player: alice,
        card_name: "As de espadas".to_string(),
    });
    assert!(private_event.visibility().includes(alice));
    assert!(!private_event.visibility().includes(bob));
}
