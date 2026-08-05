use open_table_engine::prelude::*;
use open_table_macros::GameResource;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CardColor {
    Red, Yellow, Green, Blue, WildColor
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CardValue {
    Number(u8),
    Skip,
    Reverse,
    DrawTwo,
    Wild,
    WildDrawFour,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Card {
    pub color: CardColor,
    pub value: CardValue,
}

impl Card {
    pub fn new(color: CardColor, value: CardValue) -> Self {
        Self { color, value }
    }
}

#[derive(GameResource)]
pub struct UnoState {
    pub deck: Vec<Card>,
    pub discard_pile: Vec<Card>,
    pub hands: HashMap<PlayerId, Vec<Card>>,
    pub active_color: CardColor,
    pub draw_penalty: usize,
    pub wild_draw_four_illegal: bool,
}

impl UnoState {
    pub fn new(players: &[PlayerId], rng: &mut open_table_core::random::RandomService) -> Self {
        let mut deck = Vec::new();
        let colors = [CardColor::Red, CardColor::Yellow, CardColor::Green, CardColor::Blue];

        for &c in &colors {
            deck.push(Card::new(c, CardValue::Number(0)));
            for v in 1..=9 {
                deck.push(Card::new(c, CardValue::Number(v)));
                deck.push(Card::new(c, CardValue::Number(v)));
            }
            for _ in 0..2 {
                deck.push(Card::new(c, CardValue::Skip));
                deck.push(Card::new(c, CardValue::Reverse));
                deck.push(Card::new(c, CardValue::DrawTwo));
            }
        }

        for _ in 0..4 {
            deck.push(Card::new(CardColor::WildColor, CardValue::Wild));
            deck.push(Card::new(CardColor::WildColor, CardValue::WildDrawFour));
        }

        rng.shuffle(&mut deck);

        let mut hands = HashMap::new();
        for &p in players {
            let mut hand = Vec::new();
            for _ in 0..7 {
                hand.push(deck.pop().unwrap());
            }
            hands.insert(p, hand);
        }

        let mut discard_pile = Vec::new();
        // Make sure the first card is not a wild or action card for simplicity
        let mut first_card_idx = 0;
        for (i, card) in deck.iter().enumerate() {
            if let CardValue::Number(_) = card.value {
                first_card_idx = i;
                break;
            }
        }
        let first_card = deck.remove(first_card_idx);
        let active_color = first_card.color;
        discard_pile.push(first_card);

        Self {
            deck,
            discard_pile,
            hands,
            active_color,
            draw_penalty: 0,
            wild_draw_four_illegal: false,
        }
    }

    pub fn draw_cards(&mut self, player: PlayerId, count: usize, rng: &mut open_table_core::random::RandomService) -> Vec<Card> {
        let mut drawn = Vec::new();
        for _ in 0..count {
            if self.deck.is_empty() {
                if self.discard_pile.len() > 1 {
                    let top = self.discard_pile.pop().unwrap();
                    self.deck.append(&mut self.discard_pile);
                    rng.shuffle(&mut self.deck);
                    self.discard_pile.push(top);
                } else {
                    break; // No cards left anywhere
                }
            }
            if let Some(c) = self.deck.pop() {
                drawn.push(c);
            }
        }
        
        if let Some(hand) = self.hands.get_mut(&player) {
            hand.extend(drawn.clone());
        }
        
        drawn
    }

    pub fn is_playable(&self, card: &Card) -> bool {
        if self.draw_penalty > 0 {
            if let Some(top) = self.discard_pile.last() {
                if top.value == CardValue::DrawTwo {
                    return card.value == CardValue::DrawTwo || card.value == CardValue::WildDrawFour;
                } else if top.value == CardValue::WildDrawFour {
                    return card.value == CardValue::WildDrawFour;
                }
            }
            return false;
        }

        if card.color == CardColor::WildColor {
            return true;
        }
        if card.color == self.active_color {
            return true;
        }
        if let Some(top) = self.discard_pile.last() {
            if card.value == top.value {
                return true;
            }
        }
        false
    }
}
