use std::collections::HashMap;

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

use crate::card::{Card, Hazard, Safety};

pub const WIN_DISTANCE: u32 = 1000;
pub const TARGET_DISTANCE: u32 = WIN_DISTANCE;
pub const MAX_HAND_SIZE: usize = 6;

#[derive(GameResource)]
pub struct DeckResource {
    pub draw_pile: Vec<Card>,
    pub discard_pile: Vec<Card>,
    /// La mano de cada jugador. Privada: el `RuleEngine` nunca la expone
    /// completa en un evento público, solo confirma qué carta jugó
    /// alguien cuando corresponde (`DistancePlayedEvent`, etc.) — lo que
    /// queda en la mano sigue oculto.
    pub hands: HashMap<PlayerId, Vec<Card>>,
    pub distance: HashMap<PlayerId, u32>,
    pub hazard: HashMap<PlayerId, Option<Hazard>>,
    pub cards_200_played: HashMap<PlayerId, u8>,
    pub target_distance: u32,
}

impl Default for DeckResource {
    fn default() -> Self {
        Self {
            draw_pile: Vec::new(),
            discard_pile: Vec::new(),
            hands: HashMap::new(),
            distance: HashMap::new(),
            hazard: HashMap::new(),
            cards_200_played: HashMap::new(),
            target_distance: TARGET_DISTANCE,
        }
    }
}

/// Composición del mazo estándar:
/// - 25 km × 10, 50 km × 10, 75 km × 10, 100 km × 12, 200 km × 4 (total 46 cartas de distancia)
/// - Hazard/Remedy/Safety: según distribución estándar.
pub fn build_deck() -> Vec<Card> {
    let mut deck = Vec::new();
    for _ in 0..10 {
        deck.push(Card::Distance(25));
    }
    for _ in 0..10 {
        deck.push(Card::Distance(50));
    }
    for _ in 0..10 {
        deck.push(Card::Distance(75));
    }
    for _ in 0..12 {
        deck.push(Card::Distance(100));
    }
    for _ in 0..4 {
        deck.push(Card::Distance(200));
    }
    for hazard in [
        Hazard::FlatTire,
        Hazard::OutOfGas,
        Hazard::Accident,
        Hazard::SpeedLimit,
    ] {
        for _ in 0..3 {
            deck.push(Card::Hazard(hazard));
        }
        for _ in 0..3 {
            deck.push(Card::Remedy(hazard));
        }
    }
    deck.push(Card::Safety(Safety::RightOfWay));
    deck.push(Card::RightOfWay);
    deck
}
